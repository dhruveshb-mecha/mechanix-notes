import 'dart:io';
import 'package:mechanix_notes/core/utils/app_logger.dart';
import 'package:mechanix_notes/core/utils/constants.dart';
import 'package:mechanix_notes/features/notes/data/models/note_metadata.dart';
import 'package:mechanix_notes/features/notes/data/models/note_model.dart';
import 'package:mechanix_notes/features/notes/data/repository/note_repository.dart';
import 'package:mechanix_notes/features/notes/data/services/indexing_service.dart';
import 'package:mechanix_notes/objectbox.g.dart';

class NoteRepositoryImpl extends NoteRepository {
  Store? _store;
  Box<NoteModel>? _box;
  final IndexingService _indexingService;

  NoteRepositoryImpl({IndexingService? indexingService})
    : _indexingService = indexingService ?? IndexingService();

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
  }

  Future<void> _initializeStore() async {
    try {
      final home = Platform.environment['HOME'];
      final appDir = Directory('$home${Constants.notesDbPath}');
      final exists = await appDir.exists();

      if (!exists) {
        await appDir.create(recursive: true);
      }

      _store = await openStore(
        maxDBSizeInKB: Constants.maxDBSizeInKB,
        directory: appDir.path,
      );
      _box = _store!.box<NoteModel>();

      AppLogger.i('[NoteRepository] ObjectBox store opened at ${appDir.path}');
    } catch (e) {
      AppLogger.e('Failed to initialize ObjectBox store: $e');
      rethrow;
    }
  }

  @override
  Future<List<NoteMetaData>> getNotes(int skip, int take) async {
    try {
      await ensureStoreConnected();
      final queryBuilder = box.query()
        ..order(NoteModel_.updatedAt, flags: Order.descending);
      final query = queryBuilder.build();
      query.offset = skip;
      query.limit = take;

      final notes = query.find();
      query.close();

      if (notes.isEmpty) {
        AppLogger.i("No notes found");
        return [];
      }

      final metaDataList = notes.map((note) {
        return NoteMetaData(
          id: note.id,
          height: note.height,
          title: note.title,
          createdAt: note.createdAt,
          updatedAt: note.updatedAt,
          previewText: note.previewText,
        );
      }).toList();

      AppLogger.i(
        "Fetched notes page (skip: $skip, take: $take) → page size: ${metaDataList.length}",
      );
      return metaDataList;
    } catch (e) {
      AppLogger.e('Failed to fetch notes: $e');
      return [];
    }
  }

  @override
  Future<NoteMetaData?> getNoteMetaData(String id) async {
    try {
      await ensureStoreConnected();
      final query = box.query(NoteModel_.id.equals(id)).build();
      final note = query.findFirst();
      query.close();
      if (note != null) {
        return NoteMetaData(
          id: note.id,
          height: note.height,
          title: note.title,
          createdAt: note.createdAt,
          updatedAt: note.updatedAt,
          previewText: note.previewText,
        );
      }
      return null;
    } catch (e) {
      AppLogger.e('Failed to fetch note metadata by id: $e');
      return null;
    }
  }

  @override
  Future<NoteModel?> getNoteById(String id) async {
    try {
      await ensureStoreConnected();
      final query = box.query(NoteModel_.id.equals(id)).build();
      final note = query.findFirst();
      query.close();
      AppLogger.i(
        'NoteRepository: getNoteById($id) → ${note == null ? 'not found' : 'found'}',
      );
      return note;
    } catch (e) {
      AppLogger.e('NoteRepository: getNoteById failed: $e');
      return null;
    }
  }

  @override
  Future<void> deleteNotes(List<String> ids) async {
    try {
      await ensureStoreConnected();
      final query = box.query(NoteModel_.id.oneOf(ids)).build();
      final notesToDelete = query.find();
      query.close();
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
      box.put(note);
      await _indexingService.upsertNote(note.id, note.title, note.plainText);
      AppLogger.i(
        'NoteRepository: upsertNote(${note.id}) ${note.updatedAt} ${note.title} ✓',
      );
    } on DbFullException {
      rethrow;
    } on FileSystemException catch (e) {
      AppLogger.e(
        'NoteRepository: upsertNote failed due to index storage error: $e',
      );
      throw DbFullException('Storage is full: $e', 1018);
    } catch (e) {
      AppLogger.e('NoteRepository: upsertNote failed: $e');
    }
  }

  @override
  Future<List<NoteMetaData>> searchNotes(String query) async {
    try {
      await ensureStoreConnected();
      final ids = await _indexingService.search(query);
      if (ids.isEmpty) return [];

      final queryBuilder = box.query(NoteModel_.id.oneOf(ids));
      final q = queryBuilder.build();
      final dbNotes = q.find();
      q.close();

      final notesMap = {for (var note in dbNotes) note.id: note};
      final matchingNotes = <NoteMetaData>[];
      for (final id in ids) {
        final note = notesMap[id];
        if (note != null) {
          matchingNotes.add(
            NoteMetaData(
              id: note.id,
              height: note.height,
              title: note.title,
              createdAt: note.createdAt,
              updatedAt: note.updatedAt,
              previewText: note.previewText,
            ),
          );
        }
      }
      AppLogger.i(
        "Found ${matchingNotes.length} matching notes via IndexingService",
      );
      return matchingNotes;
    } catch (e) {
      AppLogger.e('Failed to search notes: $e');
      return [];
    }
  }
}
