import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_notes/features/notes/data/services/note_file_storage.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late NoteFileStorage storage;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('note_file_storage_test_');
    storage = NoteFileStorage(notesDirectory: tempDir);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('sanitizeFileName', () {
    test('cleans leading hashes and whitespace', () {
      expect(NoteFileStorage.sanitizeFileName('# My Note'), 'My Note');
      expect(NoteFileStorage.sanitizeFileName('### Deep Heading'), 'Deep Heading');
    });

    test('replaces illegal characters with underscores', () {
      expect(
        NoteFileStorage.sanitizeFileName('What/is:this*file?'),
        'What_is_this_file',
      );
    });

    test('falls back to notes when title is empty or only special characters', () {
      expect(NoteFileStorage.sanitizeFileName(''), 'notes');
      expect(NoteFileStorage.sanitizeFileName('    '), 'notes');
      expect(NoteFileStorage.sanitizeFileName('###'), 'notes');
      expect(NoteFileStorage.sanitizeFileName('...'), 'notes');
    });

    test('clamps long title to 100 characters', () {
      final longTitle = 'a' * 150;
      final sanitized = NoteFileStorage.sanitizeFileName(longTitle);
      expect(sanitized.length, 100);
    });
  });

  group('resolveFileName and collision handling', () {
    test('resolves simple title to filename with .md', () async {
      final filename = await storage.resolveFileName(title: 'Grocery List');
      expect(filename, 'Grocery List.md');
    });

    test('resolves empty title to notes.md', () async {
      final filename = await storage.resolveFileName(title: '');
      expect(filename, 'notes.md');
    });

    test('increments counter when collision exists with different note', () async {
      File(p.join(tempDir.path, 'notes.md')).writeAsStringSync('existing');
      final firstCollision = await storage.resolveFileName(title: '');
      expect(firstCollision, 'notes (1).md');

      File(p.join(tempDir.path, 'notes (1).md')).writeAsStringSync('existing 2');
      final secondCollision = await storage.resolveFileName(title: '');
      expect(secondCollision, 'notes (2).md');
    });

    test('retains currentFileName when title has not changed', () async {
      File(p.join(tempDir.path, 'notes (1).md')).writeAsStringSync('mine');
      final result = await storage.resolveFileName(
        title: '',
        currentFileName: 'notes (1).md',
      );
      expect(result, 'notes (1).md');
    });
  });

  group('writeNoteContent & readNoteContent', () {
    test('writes content atomically and reads back accurately', () async {
      const content = '# Title\n\n- [ ] Task 1\n- [x] Task 2\n\n```dart\nvar x = 1;\n```';
      final fileName = await storage.writeNoteContent(
        title: 'Title',
        markdown: content,
      );

      expect(fileName, 'Title.md');
      final file = File(p.join(tempDir.path, fileName));
      expect(file.existsSync(), isTrue);

      final read = await storage.readNoteContent(fileName);
      expect(read, content);
    });

    test('renames file when title changes and removes old file', () async {
      final oldFileName = await storage.writeNoteContent(
        title: 'Old Title',
        markdown: 'Content 1',
      );
      expect(File(p.join(tempDir.path, oldFileName)).existsSync(), isTrue);

      final newFileName = await storage.writeNoteContent(
        title: 'New Title',
        markdown: 'Content 2',
        currentFileName: oldFileName,
      );

      expect(newFileName, 'New Title.md');
      expect(File(p.join(tempDir.path, oldFileName)).existsSync(), isFalse);
      expect(File(p.join(tempDir.path, newFileName)).existsSync(), isTrue);
      expect(await storage.readNoteContent(newFileName), 'Content 2');
    });

    test('overwrites existing file when content changes under same title', () async {
      final fileName1 = await storage.writeNoteContent(
        title: 'Shopping',
        markdown: 'Milk',
      );
      final fileName2 = await storage.writeNoteContent(
        title: 'Shopping',
        markdown: 'Milk, Bread',
        currentFileName: fileName1,
      );

      expect(fileName1, fileName2);
      expect(await storage.readNoteContent(fileName2), 'Milk, Bread');
    });
  });

  group('deleteNoteFile', () {
    test('deletes existing file', () async {
      final fileName = await storage.writeNoteContent(
        title: 'To Delete',
        markdown: 'bye',
      );
      expect(await storage.noteFileExists(fileName), isTrue);

      await storage.deleteNoteFile(fileName);
      expect(await storage.noteFileExists(fileName), isFalse);
    });

    test('concurrent writes to same note succeed without ENOENT temp collision', () async {
      final futures = Future.wait([
        storage.writeNoteContent(title: 'Concurrent Note', markdown: 'Write 1'),
        storage.writeNoteContent(title: 'Concurrent Note', markdown: 'Write 2'),
        storage.writeNoteContent(title: 'Concurrent Note', markdown: 'Write 3'),
      ]);

      final results = await futures;
      expect(results.length, 3);
      for (final name in results) {
        expect(await storage.noteFileExists(name), isTrue);
      }
    });
  });
}
