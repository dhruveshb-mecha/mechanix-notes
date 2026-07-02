import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mechanix_notes/features/notes/data/models/note_model.dart';
import 'package:mechanix_notes/features/notes/data/repository/note_repository_impl.dart';
import 'package:mechanix_notes/features/notes/data/services/indexing_service.dart';
import 'package:mechanix_notes/objectbox.g.dart';
import 'package:objectbox/objectbox.dart';

// ---------------------------------------------------------------------------
// Mocks & Fakes
// ---------------------------------------------------------------------------

class MockBox extends Mock implements Box<NoteModel> {}
class MockQueryBuilder extends Mock implements QueryBuilder<NoteModel> {}
class MockQuery extends Mock implements Query<NoteModel> {}
class MockIndexingService extends Mock implements IndexingService {}

class FakeQueryProperty extends Fake implements QueryProperty<NoteModel, Object?> {}
class FakeQueryPropertyDateTime extends Fake implements QueryProperty<NoteModel, DateTime> {}
class FakeQueryPropertyInt extends Fake implements QueryProperty<NoteModel, int> {}
class FakeQueryPropertyString extends Fake implements QueryProperty<NoteModel, String> {}
class FakeCondition extends Fake implements Condition<NoteModel> {}

// ---------------------------------------------------------------------------
// Testable subclass – lets us inject a fake Box without touching Store/Platform globals
// ---------------------------------------------------------------------------

class TestableNoteRepositoryImpl extends NoteRepositoryImpl {
  final Box<NoteModel> fakeBox;
  bool ensureStoreCalled = false;

  TestableNoteRepositoryImpl(this.fakeBox, IndexingService indexingService)
      : super(indexingService: indexingService);

  /// Override the getter so the implementation uses our fake box.
  @override
  Box<NoteModel> get box => fakeBox;

  /// Skip real ObjectBox store initialization in tests.
  @override
  Future<void> ensureStoreConnected() async {
    ensureStoreCalled = true;
  }
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
  late TestableNoteRepositoryImpl repository;

  setUpAll(() {
    registerFallbackValue(NoteModel(
      id: '',
      title: '',
      content: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      plainText: '',
      previewText: '',
      height: 0.0,
    ));
    registerFallbackValue(FakeQueryProperty());
    registerFallbackValue(FakeQueryPropertyDateTime());
    registerFallbackValue(FakeQueryPropertyInt());
    registerFallbackValue(FakeQueryPropertyString());
    registerFallbackValue(FakeCondition());
    registerFallbackValue(const <int>[]);
  });

  setUp(() {
    mockBox = MockBox();
    mockQueryBuilder = MockQueryBuilder();
    mockQuery = MockQuery();
    mockIndexingService = MockIndexingService();
    repository = TestableNoteRepositoryImpl(mockBox, mockIndexingService);

    // Setup default indexing stubs
    when(() => mockIndexingService.initialize()).thenAnswer((_) async {});
    when(() => mockIndexingService.upsertNote(any(), any(), any())).thenAnswer((_) async {});
    when(() => mockIndexingService.deleteNotesBatch(any())).thenAnswer((_) async {});
    when(() => mockIndexingService.search(any())).thenAnswer((_) async => []);

    // Setup default query builder stubbing
    when(() => mockBox.query(any())).thenReturn(mockQueryBuilder);
    when(() => mockBox.query(null)).thenReturn(mockQueryBuilder);
    when(() => mockBox.query()).thenReturn(mockQueryBuilder);
    
    when(() => mockQueryBuilder.order<DateTime>(any(), flags: any(named: 'flags'))).thenReturn(mockQueryBuilder);
    when(() => mockQueryBuilder.order<int>(any(), flags: any(named: 'flags'))).thenReturn(mockQueryBuilder);
    when(() => mockQueryBuilder.order<String>(any(), flags: any(named: 'flags'))).thenReturn(mockQueryBuilder);
    when(() => mockQueryBuilder.order(any(), flags: any(named: 'flags'))).thenReturn(mockQueryBuilder);
    
    when(() => mockQueryBuilder.build()).thenReturn(mockQuery);
    when(() => mockQuery.close()).thenAnswer((_) {});
  });

  // -------------------------------------------------------------------------
  // getNotes
  // -------------------------------------------------------------------------

  group('getNotes', () {
    test('returns empty list when box is empty', () async {
      when(() => mockQuery.find()).thenReturn([]);

      final result = await repository.getNotes(0, 10);

      expect(result, isEmpty);
      expect(repository.ensureStoreCalled, isTrue);
    });

    test('returns NoteMetaData list when box has notes', () async {
      final now = DateTime.now();
      final note1 = _makeNote(
        id: '1',
        title: 'Note 1',
        previewText: 'Preview 1',
        height: 150,
        updatedAt: now.subtract(const Duration(hours: 1)),
      );
      final note2 = _makeNote(
        id: '2',
        title: 'Note 2',
        previewText: 'Preview 2',
        height: 200,
        updatedAt: now,
      );

      when(() => mockQuery.find()).thenReturn([note1, note2]);

      final result = await repository.getNotes(0, 10);

      expect(result, hasLength(2));
      expect(result.map((n) => n.id), containsAll(['1', '2']));
    });

    test('maps NoteModel fields to NoteMetaData correctly', () async {
      final createdAt = DateTime(2024, 1, 1);
      final updatedAt = DateTime(2024, 6, 1);

      final note = _makeNote(
        id: 'abc',
        title: 'My Note',
        previewText: 'Some preview',
        height: 300,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      when(() => mockQuery.find()).thenReturn([note]);

      final result = await repository.getNotes(0, 10);

      expect(result, hasLength(1));
      final meta = result.first;
      expect(meta.id, equals('abc'));
      expect(meta.title, equals('My Note'));
      expect(meta.previewText, equals('Some preview'));
      expect(meta.height, equals(300));
      expect(meta.createdAt, equals(createdAt));
      expect(meta.updatedAt, equals(updatedAt));
    });

    test('orders query by updatedAt in descending order', () async {
      when(() => mockQuery.find()).thenReturn([]);

      await repository.getNotes(0, 10);

      verify(() => mockQueryBuilder.order(NoteModel_.updatedAt, flags: Order.descending)).called(1);
    });

    test('returns empty list and does not throw on exception', () async {
      when(() => mockQuery.find()).thenThrow(Exception('ObjectBox error'));

      final result = await repository.getNotes(0, 10);

      expect(result, isEmpty);
    });

    test('calls ensureStoreConnected before accessing box', () async {
      when(() => mockQuery.find()).thenReturn([]);

      await repository.getNotes(0, 10);

      expect(repository.ensureStoreCalled, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // getNoteById & getNoteMetaData
  // -------------------------------------------------------------------------

  group('getNoteById & getNoteMetaData', () {
    test('returns metadata of single note by id correctly', () async {
      final note = _makeNote(id: 'solo', title: 'Solo Note');
      when(() => mockQuery.findFirst()).thenReturn(note);

      final result = await repository.getNoteMetaData('solo');

      expect(result, isNotNull);
      expect(result!.id, equals('solo'));
    });

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

    test('upsertNote propagates DbFullException when writing to box fails', () async {
      final note = _makeNote(id: '1', title: 'New Title');
      when(() => mockQuery.findFirst()).thenReturn(null);
      when(() => mockBox.put(any())).thenThrow(DbFullException('Disk full', 1018));

      expect(() => repository.upsertNote(note), throwsA(isA<DbFullException>()));
    });
  });

  // -------------------------------------------------------------------------
  // searchNotes
  // -------------------------------------------------------------------------

  group('searchNotes', () {
    test('queries box with title and preview text contains', () async {
      final note1 = _makeNote(id: '1', title: 'matching title');
      final note2 = _makeNote(id: '2', title: 'other', previewText: 'matching preview');

      when(() => mockIndexingService.search('match')).thenAnswer((_) async => ['1', '2']);
      when(() => mockQuery.find()).thenReturn([note1, note2]);

      final result = await repository.searchNotes('match');

      expect(result, hasLength(2));
      expect(result.map((n) => n.id), containsAll(['1', '2']));
    });
  });
}
