import 'dart:convert';
import 'dart:io';

import 'package:mechanix_notes/core/exceptions/objectbox_exception.dart';
import 'package:mechanix_notes/core/utils/app_logger.dart';
import 'package:mechanix_notes/core/utils/constants.dart';
import 'package:mechanix_notes/features/notes/data/models/note_metadata.dart';
import 'package:mechanix_notes/features/notes/data/models/note_model.dart';
import 'package:mechanix_notes/features/notes/data/repository/note_repository.dart';
import 'package:mechanix_notes/features/notes/data/services/indexing_service.dart';
import 'package:mechanix_notes/features/notes/data/services/note_file_storage.dart';
import 'package:mechanix_notes/features/notes/data/services/note_tag_helper.dart';
import 'package:mechanix_notes/objectbox.g.dart' hide ObjectBoxException;

class NoteRepositoryImpl extends NoteRepository {
  static Store? _sharedStore;

  Store? _store;
  Box<NoteModel>? _box;
  final IndexingService _indexingService;
  final NoteFileStorage _fileStorage;

  NoteRepositoryImpl({
    Store? store,
    IndexingService? indexingService,
    NoteFileStorage? fileStorage,
  }) : _store = store,
       _indexingService = indexingService ?? IndexingService(),
       _fileStorage = fileStorage ?? NoteFileStorage();

  Box<NoteModel> get box {
    if (_box == null) {
      throw StateError(
        "Box is not initialized. Call ensureStoreConnected() first.",
      );
    }
    return _box!;
  }

  Future<void> ensureStoreConnected() async {
    if (_store != null && !_store!.isClosed()) return;

    if (_sharedStore != null && !_sharedStore!.isClosed()) {
      _store = _sharedStore;
      _box = _store!.box<NoteModel>();
      return;
    }

    try {
      await _initializeStore();
    } catch (e) {
      AppLogger.e('Failed to open ObjectBox store: $e');
      if (e is FileSystemException && e.message.contains('lock failed')) {
        throw ObjectBoxException("Failed to open ObjectBox store: $e");
      }
      rethrow;
    }

    try {
      await _indexingService.initialize();
    } catch (e) {
      AppLogger.e('Failed to initialize Tantivy: $e');
    }

    try {
      await _fileStorage.ensureDirectoryExists();
    } catch (e) {
      AppLogger.e('Failed to initialize note file directory: $e');
    }
  }

  Future<void> _initializeStore() async {
    try {
      final home = Platform.environment['HOME'];
      final appDir = Directory('$home${Constants.notesDbPath}');
      final exists = await appDir.exists();

      if (!exists) {
        await appDir.create(recursive: true);
      }

      if (_sharedStore != null && !_sharedStore!.isClosed()) {
        _store = _sharedStore;
      } else {
        _sharedStore = await openStore(
          maxDBSizeInKB: Constants.maxDBSizeInKB,
          directory: appDir.path,
        );
        _store = _sharedStore;
      }

      _box = _store!.box<NoteModel>();

      AppLogger.i('[NoteRepository] ObjectBox store opened at ${appDir.path}');
    } catch (e) {
      AppLogger.e('Failed to initialize ObjectBox store: $e');
      rethrow;
    }
  }

  static NoteMetaData _toMetaData(NoteModel note) => NoteMetaData(
    id: note.id,
    height: note.height,
    title: note.title,
    createdAt: note.createdAt,
    updatedAt: note.updatedAt,
    previewText: note.previewText,
    isPinned: note.isPinned,
  );

  @override
  Stream<List<NoteMetaData>> watchNotes() async* {
    await ensureStoreConnected();
    final queryBuilder = box.query()
      ..order(NoteModel_.isPinned, flags: Order.descending)
      ..order(NoteModel_.updatedAt, flags: Order.descending);
    yield* queryBuilder
        .watch(triggerImmediately: true)
        .asyncMap((query) async {
          final notes = await query.findAsync();
          return notes.map(_toMetaData).toList();
        });
  }

  @override
  Future<NoteModel?> getNoteById(String id) async {
    try {
      await ensureStoreConnected();
      final query = box.query(NoteModel_.id.equals(id)).build();
      final note = query.findFirst();
      query.close();
      if (note == null) {
        AppLogger.i('NoteRepository: getNoteById($id) → not found');
        return null;
      }

      // 1. Try reading using fileName
      String? markdown;
      final fileToRead = note.fileName;
      if (fileToRead != null && fileToRead.isNotEmpty) {
        markdown = await _fileStorage.readNoteContent(fileToRead);
      }

      // 2. Fallback: try resolving by title (e.g. if saved under title directly)
      if (markdown == null) {
        final titleFileName =
            '${NoteFileStorage.sanitizeFileName(note.title)}.md';
        if (await _fileStorage.noteFileExists(titleFileName)) {
          markdown = await _fileStorage.readNoteContent(titleFileName);
          if (markdown != null) {
            note.fileName = titleFileName;
            box.put(note);
          }
        }
      }

      // 3. Fallback: Auto-heal by searching directory for embedded tag <!-- mechanix:id=id -->
      if (markdown == null) {
        final matchingFile = await _findNoteFileByIdTag(note.id);
        if (matchingFile != null) {
          markdown = matchingFile.content;
          note.fileName = matchingFile.fileName;
          final cleanContent = NoteTagHelper.stripTag(markdown);
          final lines = cleanContent
              .split('\n')
              .map((l) => l.trim())
              .where((l) => l.isNotEmpty)
              .toList();
          if (lines.isNotEmpty) {
            final firstLineTitle = lines.first
                .replaceAll(RegExp(r'^#+\s*'), '')
                .trim();
            if (firstLineTitle.isNotEmpty) {
              note.title = firstLineTitle;
            }
          }
          box.put(note);
          AppLogger.i(
            'NoteRepository: Auto-healed note ${note.id} to filename ${matchingFile.fileName}',
          );
        }
      }

      // 4. Return note with clean (stripped) content for editor and UI
      if (markdown != null) {
        note.content = NoteTagHelper.stripTag(markdown);
      } else if (note.fileName != null) {
        note.content = '';
      }

      AppLogger.i('NoteRepository: getNoteById($id) → found');
      return note;
    } catch (e) {
      AppLogger.e('NoteRepository: getNoteById failed: $e');
      return null;
    }
  }

  /// Reads at most [maxBytes] from the end of [file] and decodes as UTF-8. without reading entire file contents into memory.
  Future<String?> _readTailString(File file, [int maxBytes = 1024]) async {
    RandomAccessFile? raf;
    try {
      final length = await file.length();
      if (length == 0) return '';
      raf = await file.open(mode: FileMode.read);
      final readLength = length < maxBytes ? length : maxBytes;
      await raf.setPosition(length - readLength);
      final bytes = await raf.read(readLength);
      return utf8.decode(bytes, allowMalformed: true);
    } catch (e) {
      return null;
    } finally {
      await raf?.close();
    }
  }

  /// Scans the notes directory for a .md file containing an embedded tag matching [noteId].
  Future<({String fileName, String content})?> _findNoteFileByIdTag(
    String noteId,
  ) async {
    try {
      final dir = _fileStorage.directory;
      if (!await dir.exists()) return null;

      final entities = await dir.list().toList();
      for (final entity in entities) {
        if (entity is File && entity.path.endsWith('.md')) {
          final fileName = entity.uri.pathSegments.last;
          if (fileName.startsWith('..tmp_')) continue;

          final tail = await _readTailString(entity);
          if (tail != null && tail.contains('mechanix:id')) {
            final extractedId = NoteTagHelper.extractId(tail);
            if (extractedId == noteId) {
              final content = await entity.readAsString();
              return (fileName: fileName, content: content);
            }
          }
        }
      }
    } catch (e) {
      AppLogger.e(
        'NoteRepository: _findNoteFileByIdTag failed for $noteId: $e',
      );
    }
    return null;
  }

  @override
  Future<void> deleteNotes(List<String> ids) async {
    try {
      await ensureStoreConnected();
      final query = box.query(NoteModel_.id.oneOf(ids)).build();
      final notesToDelete = query.find();
      query.close();

      for (final note in notesToDelete) {
        final fileToDelete = note.fileName;
        if (fileToDelete != null && fileToDelete.isNotEmpty) {
          await _fileStorage.deleteNoteFile(fileToDelete);
        } else {
          final titleFileName =
              '${NoteFileStorage.sanitizeFileName(note.title)}.md';
          await _fileStorage.deleteNoteFile(titleFileName);
        }
      }

      if (notesToDelete.isNotEmpty) {
        box.removeMany(notesToDelete.map((n) => n.obxId).toList());
      }
      await _indexingService.deleteNotesBatch(ids);
      AppLogger.i('NoteRepository: deleteNotes(${ids.length})');
    } catch (e) {
      AppLogger.e('NoteRepository: deleteNotes failed: $e');
    }
  }

  @override
  Future<void> upsertNote(NoteModel note) async {
    try {
      await ensureStoreConnected();
      final query = box.query(NoteModel_.id.equals(note.id)).build();
      final existing = query.findFirst();
      query.close();
      if (existing != null) {
        note.obxId = existing.obxId;
      }

      final currentFileName = existing?.fileName;

      final cleanMarkdown = NoteTagHelper.stripTag(note.content);
      final taggedMarkdown = NoteTagHelper.appendTag(cleanMarkdown, note.id);
      final savedFileName = await _fileStorage.writeNoteContent(
        title: note.title,
        markdown: taggedMarkdown,
        currentFileName: currentFileName,
      );

      // Store fileName in ObjectBox; content and plain text live only in the
      // .md file and the search index, so keep them out of the database
      final plainText = note.plainText;
      note.fileName = savedFileName;
      note.content = '';
      note.plainText = '';
      box.put(note);

      // Restore clean markdown and plain text in in-memory note instance
      note.content = cleanMarkdown;
      note.plainText = plainText;

      await _indexingService.upsertNote(note.id, note.title, note.plainText);
      AppLogger.i(
        'NoteRepository: upsertNote(${note.id}) ${note.updatedAt} ${note.title} saved to $savedFileName ✓',
      );
    } on DbFullException {
      rethrow;
    } on FileSystemException catch (e) {
      AppLogger.e(
        'NoteRepository: upsertNote failed due to filesystem error: $e',
      );
      if (e.osError?.errorCode == 28) {
        throw DbFullException('Storage is full: $e', 1018);
      }
      rethrow;
    } catch (e) {
      AppLogger.e('NoteRepository: upsertNote failed: $e');
      rethrow;
    }
  }

  @override
  Future<List<String>> searchNoteIds(String query) async {
    try {
      await ensureStoreConnected();
      final ids = await _indexingService.search(query);
      AppLogger.i("Found ${ids.length} matching note ids via IndexingService");
      return ids;
    } catch (e) {
      AppLogger.e('Failed to search notes: $e');
      return [];
    }
  }

  @override
  Future<List<NoteMetaData>> getNotesMetaData(List<String> ids) async {
    if (ids.isEmpty) return [];
    try {
      await ensureStoreConnected();
      final q = box.query(NoteModel_.id.oneOf(ids)).build();
      final dbNotes = await q.findAsync();
      q.close();

      // Restore the caller's order (search relevance); oneOf does not keep it
      final notesMap = {for (var note in dbNotes) note.id: note};
      return [
        for (final id in ids)
          if (notesMap[id] case final note?) _toMetaData(note),
      ];
    } catch (e) {
      AppLogger.e('Failed to load notes metadata: $e');
      return [];
    }
  }

  @override
  Future<bool> togglePinNote(String id) async {
    try {
      await ensureStoreConnected();
      final query = box.query(NoteModel_.id.equals(id)).build();
      final note = query.findFirst();
      query.close();

      if (note != null) {
        note.isPinned = !note.isPinned;
        box.put(note);
        AppLogger.i('NoteRepository: togglePinNote($id) → ${note.isPinned}');
        return note.isPinned;
      }
      return false;
    } catch (e) {
      AppLogger.e('NoteRepository: togglePinNote failed: $e');
      return false;
    }
  }

  @override
  Future<void> close() async {
    if (_sharedStore != null && !_sharedStore!.isClosed()) {
      _sharedStore!.close();
      _sharedStore = null;
    }
    _store = null;
    _box = null;
  }
}
