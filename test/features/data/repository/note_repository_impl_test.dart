import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_notes/core/exceptions/objectbox_exception.dart';
import 'package:mechanix_notes/features/notes/data/models/note_model.dart';
import 'package:mechanix_notes/features/notes/data/repository/note_repository_impl.dart';
import 'package:mechanix_notes/features/notes/data/services/indexing_service.dart';
import 'package:mechanix_notes/features/notes/data/services/note_file_storage.dart';
import 'package:mechanix_notes/objectbox.g.dart' hide ObjectBoxException;
import 'package:mocktail/mocktail.dart';

// ---------------------------------------------------------------------------
// Mocks & Fakes
// ---------------------------------------------------------------------------

class MockBox extends Mock implements Box<NoteModel> {}

class MockQueryBuilder extends Mock implements QueryBuilder<NoteModel> {}

class MockQuery extends Mock implements Query<NoteModel> {}

class MockIndexingService extends Mock implements IndexingService {}

class FakeQueryProperty extends Fake
    implements QueryProperty<NoteModel, Object?> {}

class FakeQueryPropertyDateTime extends Fake
    implements QueryProperty<NoteModel, DateTime> {}

class FakeQueryPropertyInt extends Fake
    implements QueryProperty<NoteModel, int> {}

class FakeQueryPropertyString extends Fake
    implements QueryProperty<NoteModel, String> {}

class FakeQueryPropertyBool extends Fake
    implements QueryProperty<NoteModel, bool> {}

class FakeCondition extends Fake implements Condition<NoteModel> {}

// ---------------------------------------------------------------------------
// Testable subclass – lets us inject a fake Box without touching Store/Platform globals
// ---------------------------------------------------------------------------

class TestableNoteRepositoryImpl extends NoteRepositoryImpl {
  final Box<NoteModel> fakeBox;
  bool ensureStoreCalled = false;

  TestableNoteRepositoryImpl(
    this.fakeBox,
    IndexingService indexingService, {
    super.fileStorage,
  }) : super(indexingService: indexingService);

  /// Override the getter so the implementation uses our fake box.
  @override
  Box<NoteModel> get box => fakeBox;

  /// Skip real ObjectBox store initialization in tests.
  @override
  Future<void> ensureStoreConnected() async {
    ensureStoreCalled = true;
  }
}

class _FailingStoreRepository extends TestableNoteRepositoryImpl {
  _FailingStoreRepository(super.fakeBox, super.indexingService);

  @override
  Future<void> ensureStoreConnected() async =>
      throw ObjectBoxException('lock failed');
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

NoteModel _makeNote({
  required String id,
  required String title,
  String previewText = '',
  double height = 200,
  DateTime? createdAt,
  DateTime? updatedAt,
  bool isPinned = false,
}) {
  final now = DateTime.now();
  return NoteModel(
    id: id,
    title: title,
    content: 'content',
    plainText: 'plainText',
    previewText: previewText,
    height: height,
    createdAt: createdAt ?? now,
    updatedAt: updatedAt ?? now,
    isPinned: isPinned,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockBox mockBox;
  late MockQueryBuilder mockQueryBuilder;
  late MockQuery mockQuery;
  late MockIndexingService mockIndexingService;
  late NoteFileStorage fileStorage;
  late Directory tempDir;
  late TestableNoteRepositoryImpl repository;

  setUpAll(() {
    registerFallbackValue(
      NoteModel(
        id: '',
        title: '',
        content: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        plainText: '',
        previewText: '',
        height: 0.0,
      ),
    );
    registerFallbackValue(FakeQueryProperty());
    registerFallbackValue(FakeQueryPropertyDateTime());
    registerFallbackValue(FakeQueryPropertyInt());
    registerFallbackValue(FakeQueryPropertyString());
    registerFallbackValue(FakeQueryPropertyBool());
    registerFallbackValue(FakeCondition());
    registerFallbackValue(const <int>[]);
  });

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('note_repo_impl_test_');
    fileStorage = NoteFileStorage(notesDirectory: tempDir);
    mockBox = MockBox();
    mockQueryBuilder = MockQueryBuilder();
    mockQuery = MockQuery();
    mockIndexingService = MockIndexingService();
    repository = TestableNoteRepositoryImpl(
      mockBox,
      mockIndexingService,
      fileStorage: fileStorage,
    );

    // Setup default indexing stubs
    when(() => mockIndexingService.initialize()).thenAnswer((_) async {});
    when(
      () => mockIndexingService.upsertNote(any(), any(), any()),
    ).thenAnswer((_) async {});
    when(
      () => mockIndexingService.deleteNotesBatch(any()),
    ).thenAnswer((_) async {});
    when(() => mockIndexingService.search(any())).thenAnswer((_) async => []);

    // Setup default query builder stubbing
    when(() => mockBox.query(any())).thenReturn(mockQueryBuilder);
    when(() => mockBox.query(null)).thenReturn(mockQueryBuilder);
    when(() => mockBox.query()).thenReturn(mockQueryBuilder);

    when(
      () => mockQueryBuilder.order<DateTime>(any(), flags: any(named: 'flags')),
    ).thenReturn(mockQueryBuilder);
    when(
      () => mockQueryBuilder.order<int>(any(), flags: any(named: 'flags')),
    ).thenReturn(mockQueryBuilder);
    when(
      () => mockQueryBuilder.order<String>(any(), flags: any(named: 'flags')),
    ).thenReturn(mockQueryBuilder);
    when(
      () => mockQueryBuilder.order<bool>(any(), flags: any(named: 'flags')),
    ).thenReturn(mockQueryBuilder);
    when(
      () => mockQueryBuilder.order(any(), flags: any(named: 'flags')),
    ).thenReturn(mockQueryBuilder);

    when(() => mockQueryBuilder.build()).thenReturn(mockQuery);
    when(() => mockQuery.close()).thenAnswer((_) {});
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  // -------------------------------------------------------------------------
  // watchNotes
  // -------------------------------------------------------------------------

  group('watchNotes', () {
    test('emits mapped metadata on every query change', () async {
      final changes = StreamController<Query<NoteModel>>();
      when(
        () => mockQueryBuilder.watch(triggerImmediately: true),
      ).thenAnswer((_) => changes.stream);

      final note1 = _makeNote(id: '1', title: 'Note 1');
      final note2 = _makeNote(id: '2', title: 'Note 2');
      final emitted = <List<String>>[];
      final sub = repository.watchNotes().listen(
        (notes) => emitted.add(notes.map((n) => n.id).toList()),
      );
      await pumpEventQueue();

      when(() => mockQuery.findAsync()).thenAnswer((_) async => [note1]);
      changes.add(mockQuery);
      await pumpEventQueue();
      when(() => mockQuery.findAsync()).thenAnswer((_) async => [note2, note1]);
      changes.add(mockQuery);
      await pumpEventQueue();

      expect(emitted, [
        ['1'],
        ['2', '1'],
      ]);
      expect(repository.ensureStoreCalled, isTrue);
      verify(
        () => mockQueryBuilder.order(
          NoteModel_.isPinned,
          flags: Order.descending,
        ),
      ).called(1);
      verify(
        () => mockQueryBuilder.order(
          NoteModel_.updatedAt,
          flags: Order.descending,
        ),
      ).called(1);

      await sub.cancel();
      await changes.close();
    });

    test('maps NoteModel fields to NoteMetaData', () async {
      final createdAt = DateTime(2024, 1, 1);
      final updatedAt = DateTime(2024, 6, 1);
      final note = _makeNote(
        id: 'abc',
        title: 'My Note',
        previewText: 'Some preview',
        height: 300,
        createdAt: createdAt,
        updatedAt: updatedAt,
        isPinned: true,
      );
      when(
        () => mockQueryBuilder.watch(triggerImmediately: true),
      ).thenAnswer((_) => Stream.value(mockQuery));
      when(() => mockQuery.findAsync()).thenAnswer((_) async => [note]);

      final meta = (await repository.watchNotes().first).single;

      expect(meta.id, 'abc');
      expect(meta.title, 'My Note');
      expect(meta.previewText, 'Some preview');
      expect(meta.height, 300);
      expect(meta.createdAt, createdAt);
      expect(meta.updatedAt, updatedAt);
      expect(meta.isPinned, isTrue);
    });

    test('forwards store errors to the listener', () async {
      final failing = _FailingStoreRepository(mockBox, mockIndexingService);

      await expectLater(
        failing.watchNotes(),
        emitsError(isA<ObjectBoxException>()),
      );
    });
  });

  // -------------------------------------------------------------------------
  // getNoteById
  // -------------------------------------------------------------------------

  group('getNoteById', () {
    test('returns NoteModel by id correctly', () async {
      final note = _makeNote(id: 'solo', title: 'Solo Note');
      when(() => mockQuery.findFirst()).thenReturn(note);

      final result = await repository.getNoteById('solo');

      expect(result, isNotNull);
      expect(result!.id, equals('solo'));
    });
  });

  // -------------------------------------------------------------------------
  // deleteNotes & upsertNote
  // -------------------------------------------------------------------------

  group('deleteNotes & upsertNote', () {
    test('deleteNotes calls removeMany with correct obxIds', () async {
      final note1 = _makeNote(id: '1', title: 'Note 1')..obxId = 10;
      final note2 = _makeNote(id: '2', title: 'Note 2')..obxId = 20;

      when(() => mockQuery.find()).thenReturn([note1, note2]);
      when(() => mockBox.removeMany(any())).thenReturn(2);

      await repository.deleteNotes(['1', '2']);

      verify(() => mockBox.removeMany([10, 20])).called(1);
    });

    test('upsertNote puts note and updates obxId if existing', () async {
      final note = _makeNote(id: '1', title: 'New Title');
      final existing = _makeNote(id: '1', title: 'Old Title')..obxId = 42;

      when(() => mockQuery.findFirst()).thenReturn(existing);
      when(() => mockBox.put(any())).thenReturn(42);

      await repository.upsertNote(note);

      expect(note.obxId, 42);
      verify(() => mockBox.put(note)).called(1);
    });

    test(
      'upsertNote keeps content and plain text out of the database',
      () async {
        final note = _makeNote(id: '1', title: 'Title')
          ..content = '# Title\nbody'
          ..plainText = 'Title body';
        String? storedContent;
        String? storedPlainText;

        when(() => mockQuery.findFirst()).thenReturn(null);
        when(() => mockBox.put(any())).thenAnswer((inv) {
          final stored = inv.positionalArguments.first as NoteModel;
          storedContent = stored.content;
          storedPlainText = stored.plainText;
          return 1;
        });

        await repository.upsertNote(note);

        expect(storedContent, isEmpty);
        expect(storedPlainText, isEmpty);
        expect(note.plainText, 'Title body');
        verify(
          () => mockIndexingService.upsertNote('1', 'Title', 'Title body'),
        ).called(1);
      },
    );

    test(
      'upsertNote propagates DbFullException when writing to box fails',
      () async {
        final note = _makeNote(id: '1', title: 'New Title');
        when(() => mockQuery.findFirst()).thenReturn(null);
        when(
          () => mockBox.put(any()),
        ).thenThrow(DbFullException('Disk full', 1018));

        expect(
          () => repository.upsertNote(note),
          throwsA(isA<DbFullException>()),
        );
      },
    );

    test(
      'upsertNote writes full markdown to .md file and stores filename in Box',
      () async {
        final note = _makeNote(id: 'save-test', title: 'File Test');
        note.content = '# Custom Markdown\n\n- item 1\n- item 2';

        when(() => mockQuery.findFirst()).thenReturn(null);
        when(() => mockBox.put(any())).thenReturn(1);

        await repository.upsertNote(note);

        expect(note.fileName, 'File Test.md');
        expect(await fileStorage.noteFileExists('File Test.md'), isTrue);
        final savedMarkdown = await fileStorage.readNoteContent('File Test.md');
        expect(
          savedMarkdown,
          '# Custom Markdown\n\n- item 1\n- item 2\n\n<!-- mechanix:id=save-test -->\n',
        );
        expect(note.content, '# Custom Markdown\n\n- item 1\n- item 2');
      },
    );

    test(
      'getNoteById reads full markdown from .md file using fileName and strips tag',
      () async {
        await fileStorage.writeNoteContent(
          title: 'Open Test',
          markdown: '# Loaded from file\n\n<!-- mechanix:id=open-test -->\n',
        );

        final noteInDb = _makeNote(id: 'open-test', title: 'Open Test');
        noteInDb.fileName = 'Open Test.md';

        when(() => mockQuery.findFirst()).thenReturn(noteInDb);

        final result = await repository.getNoteById('open-test');

        expect(result, isNotNull);
        expect(result!.content, '# Loaded from file');
      },
    );

    test(
      'getNoteById auto-heals filename when file was renamed on disk with matching embedded tag',
      () async {
        // File renamed externally on disk to 'Renamed File.md'
        await fileStorage.writeNoteContent(
          title: 'Renamed File',
          markdown:
              '# Renamed Title\n\nContent\n\n<!-- mechanix:id=heal-test -->\n',
        );

        // ObjectBox still has old fileName 'Old File.md'
        final noteInDb = _makeNote(id: 'heal-test', title: 'Old Title');
        noteInDb.fileName = 'Old File.md';

        when(() => mockQuery.findFirst()).thenReturn(noteInDb);
        when(() => mockBox.put(any())).thenReturn(1);

        final result = await repository.getNoteById('heal-test');

        expect(result, isNotNull);
        expect(result!.fileName, 'Renamed File.md');
        expect(result.title, 'Renamed Title');
        expect(result.content, '# Renamed Title\n\nContent');
      },
    );

    test(
      'getNoteById auto-heals filename when file is larger than 1KB and tag is at the tail',
      () async {
        // Large content > 2KB
        final largeBody = 'A' * 2500;
        await fileStorage.writeNoteContent(
          title: 'Large File',
          markdown:
              '# Large Note\n\n$largeBody\n\n<!-- mechanix:id=large-heal -->\n',
        );

        final noteInDb = _makeNote(id: 'large-heal', title: 'Large Note');
        noteInDb.fileName = 'Missing File.md';

        when(() => mockQuery.findFirst()).thenReturn(noteInDb);
        when(() => mockBox.put(any())).thenReturn(1);

        final result = await repository.getNoteById('large-heal');

        expect(result, isNotNull);
        expect(result!.fileName, 'Large File.md');
        expect(result.title, 'Large Note');
        expect(result.content, '# Large Note\n\n$largeBody');
      },
    );

    test('deleteNotes deletes corresponding .md file using fileName', () async {
      final fileName = await fileStorage.writeNoteContent(
        title: 'To Be Deleted',
        markdown: 'bye',
      );
      expect(await fileStorage.noteFileExists(fileName), isTrue);

      final note = _makeNote(id: 'del-1', title: 'To Be Deleted');
      note.fileName = fileName;
      note.obxId = 99;

      when(() => mockQuery.find()).thenReturn([note]);
      when(() => mockBox.removeMany(any())).thenReturn(1);

      await repository.deleteNotes(['del-1']);

      expect(await fileStorage.noteFileExists(fileName), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // searchNoteIds / getNotesMetaData
  // -------------------------------------------------------------------------

  group('searchNoteIds', () {
    test('returns ids from the index in relevance order', () async {
      when(
        () => mockIndexingService.search('match'),
      ).thenAnswer((_) async => ['2', '1']);

      final result = await repository.searchNoteIds('match');

      expect(result, ['2', '1']);
      verifyNever(() => mockBox.query(any()));
    });
  });

  group('getNotesMetaData', () {
    test('returns notes in the order of the given ids', () async {
      final note1 = _makeNote(id: '1', title: 'first');
      final note2 = _makeNote(id: '2', title: 'second');
      when(() => mockQuery.findAsync()).thenAnswer((_) async => [note1, note2]);

      final result = await repository.getNotesMetaData(['2', '1']);

      expect(result.map((n) => n.id), ['2', '1']);
      verify(() => mockQuery.close()).called(1);
    });

    test('skips ids with no stored note', () async {
      final note1 = _makeNote(id: '1', title: 'first');
      when(() => mockQuery.findAsync()).thenAnswer((_) async => [note1]);

      final result = await repository.getNotesMetaData(['gone', '1']);

      expect(result.map((n) => n.id), ['1']);
    });

    test('does not query the box for an empty id list', () async {
      final result = await repository.getNotesMetaData([]);

      expect(result, isEmpty);
      verifyNever(() => mockBox.query(any()));
    });
  });

  // -------------------------------------------------------------------------
  // togglePinNote
  // -------------------------------------------------------------------------

  group('togglePinNote', () {
    test('toggles note from false to true', () async {
      final note = _makeNote(id: '1', title: 'Note 1', isPinned: false);
      when(() => mockQuery.findFirst()).thenReturn(note);
      when(() => mockBox.put(any())).thenReturn(1);

      final result = await repository.togglePinNote('1');

      expect(result, isTrue);
      expect(note.isPinned, isTrue);
      verify(() => mockBox.put(note)).called(1);
    });

    test('toggles note from true to false', () async {
      final note = _makeNote(id: '2', title: 'Note 2', isPinned: true);
      when(() => mockQuery.findFirst()).thenReturn(note);
      when(() => mockBox.put(any())).thenReturn(1);

      final result = await repository.togglePinNote('2');

      expect(result, isFalse);
      expect(note.isPinned, isFalse);
      verify(() => mockBox.put(note)).called(1);
    });

    test('returns false when note is not found', () async {
      when(() => mockQuery.findFirst()).thenReturn(null);

      final result = await repository.togglePinNote('unknown');

      expect(result, isFalse);
      verifyNever(() => mockBox.put(any()));
    });
  });

  group('close', () {
    test('closes store and completes without error', () async {
      await expectLater(repository.close(), completes);
    });
  });
}
