import 'dart:io';

import 'package:mechanix_notes/core/utils/app_logger.dart';
import 'package:mechanix_notes/core/utils/constants.dart';
import 'package:path/path.dart' as p;

class NoteFileStorage {
  static int _tempCounter = 0;
  final Directory _directory;

  NoteFileStorage({Directory? notesDirectory})
    : _directory = notesDirectory ?? _resolveDefaultDirectory();

  Directory get directory => _directory;

  static Directory _resolveDefaultDirectory() {
    final customDocs = Platform.environment['DOCUMENTS_DIR'];
    if (customDocs != null && customDocs.isNotEmpty) {
      return Directory(p.join(customDocs, Constants.notesSubDir));
    }

    final xdgDocs = Platform.environment['XDG_DOCUMENTS_DIR'];
    if (xdgDocs != null && xdgDocs.isNotEmpty) {
      return Directory(p.join(xdgDocs, Constants.notesSubDir));
    }

    final home = Platform.environment['HOME'];
    if (home != null && home.isNotEmpty) {
      return Directory(p.join(home, 'Documents', Constants.notesSubDir));
    }

    return Directory(
      p.join(Directory.current.path, 'Documents', Constants.notesSubDir),
    );
  }

  /// Ensures that the target notes directory exists.
  Future<void> ensureDirectoryExists() async {
    try {
      if (!await _directory.exists()) {
        await _directory.create(recursive: true);
        AppLogger.i('[NoteFileStorage] Created directory: ${_directory.path}');
      }
    } catch (e) {
      AppLogger.e('[NoteFileStorage] Failed to create directory: $e');
      rethrow;
    }
  }

  /// Sanitizes note title for safe use as a filename on Linux filesystems.
  static String sanitizeFileName(String title) {
    var sanitized = title.trim();

    // Remove markdown heading tokens if present
    sanitized = sanitized.replaceAll(RegExp(r'^#+\s*'), '');

    // Replace illegal characters (\ / : * ? " < > | and control characters)
    sanitized = sanitized.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_');

    // Replace multiple spaces or underscores with a single space
    sanitized = sanitized.replaceAll(RegExp(r'\s+'), ' ');
    sanitized = sanitized.replaceAll(RegExp(r'_+'), '_');

    // Remove leading and trailing dots, spaces, underscores
    sanitized = sanitized.replaceAll(RegExp(r'^[._\s]+|[._\s]+$'), '');

    // Limit length to 100 characters to prevent filesystem limits
    if (sanitized.length > 100) {
      sanitized = sanitized.substring(0, 100).trim();
    }

    if (sanitized.isEmpty) {
      return Constants.defaultNoteFileName;
    }

    return sanitized;
  }

  /// Resolves a unique filename for a note.
  /// If [currentFileName] matches the base title, it is retained.
  /// If a collision exists, increments with `(1)`, `(2)`, etc.
  Future<String> resolveFileName({
    required String title,
    String? currentFileName,
  }) async {
    final baseName = sanitizeFileName(title);

    // If currentFileName already belongs to this note and starts with baseName
    if (currentFileName != null && currentFileName.isNotEmpty) {
      final currentBase = p.withoutExtension(currentFileName);
      // Exactly matches baseName or is a numbered variant of baseName (e.g. "Title (1)")
      final isExactMatch = currentBase == baseName;
      final isNumberedMatch = RegExp(
        '^${RegExp.escape(baseName)} \\(\\d+\\)\$',
      ).hasMatch(currentBase);

      if (isExactMatch || isNumberedMatch) {
        return currentFileName;
      }
    }

    // Try baseName.md
    final initialCandidate = '$baseName.md';
    if (initialCandidate == currentFileName) {
      return initialCandidate;
    }

    if (!await noteFileExists(initialCandidate)) {
      return initialCandidate;
    }

    // If initialCandidate exists and does not belong to this note, try numbered variants
    var counter = 1;
    while (true) {
      final candidate = '$baseName ($counter).md';
      if (candidate == currentFileName) {
        return candidate;
      }
      if (!await noteFileExists(candidate)) {
        return candidate;
      }
      counter++;
    }
  }

  /// Writes note Markdown content atomically using a temporary file and atomic rename.
  /// If [currentFileName] is provided and differs from the newly resolved filename,
  /// the old file is safely deleted.
  Future<String> writeNoteContent({
    required String title,
    required String markdown,
    String? currentFileName,
  }) async {
    await ensureDirectoryExists();

    final targetFileName = await resolveFileName(
      title: title,
      currentFileName: currentFileName,
    );

    final targetPath = p.join(_directory.path, targetFileName);
    final uniqueSuffix =
        '${DateTime.now().microsecondsSinceEpoch}_${++_tempCounter}';
    final tempPath = p.join(
      _directory.path,
      '..tmp_${p.withoutExtension(targetFileName)}_$uniqueSuffix.md',
    );

    final tempFile = File(tempPath);
    try {
      // 1. Atomic write: write to temp file and flush
      await tempFile.writeAsString(markdown, flush: true);

      // 2. Atomic rename
      await tempFile.rename(targetPath);

      AppLogger.i('[NoteFileStorage] Saved note to $targetFileName');

      // 3. Clean up previous file if filename changed (due to title rename)
      if (currentFileName != null &&
          currentFileName.isNotEmpty &&
          currentFileName != targetFileName) {
        await deleteNoteFile(currentFileName);
        AppLogger.i(
          '[NoteFileStorage] Renamed note: removed old file $currentFileName',
        );
      }

      return targetFileName;
    } catch (e) {
      AppLogger.e(
        '[NoteFileStorage] Failed to write note to $targetFileName: $e',
      );
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
      rethrow;
    }
  }

  /// Reads Markdown content for the given [fileName].
  /// Returns null if the file does not exist.
  Future<String?> readNoteContent(String fileName) async {
    try {
      final file = File(p.join(_directory.path, fileName));
      if (!await file.exists()) {
        AppLogger.d('[NoteFileStorage] File not found: $fileName');
        return null;
      }
      return await file.readAsString();
    } catch (e) {
      AppLogger.e('[NoteFileStorage] Failed to read note $fileName: $e');
      rethrow;
    }
  }

  /// Safely deletes the given [fileName] and any leftover temporary file.
  Future<void> deleteNoteFile(String fileName) async {
    try {
      final file = File(p.join(_directory.path, fileName));
      if (await file.exists()) {
        await file.delete();
        AppLogger.i('[NoteFileStorage] Deleted file: $fileName');
      }

      final tempFile = File(p.join(_directory.path, '..tmp_$fileName'));
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    } catch (e) {
      AppLogger.e('[NoteFileStorage] Failed to delete file $fileName: $e');
    }
  }

  /// Checks if a note file with [fileName] exists.
  Future<bool> noteFileExists(String fileName) async {
    final file = File(p.join(_directory.path, fileName));
    return await file.exists();
  }
}
