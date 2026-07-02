import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_notes/core/exceptions/objectbox_exception.dart';
import 'package:mechanix_notes/core/utils/constants.dart';
import 'package:mechanix_notes/core/utils/enums.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_event.dart';
import 'package:mechanix_notes/features/notes/data/models/time_group.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_bloc.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_state.dart';
import 'package:mechanix_notes/features/notes/data/models/note_metadata.dart';
import 'package:mechanix_notes/features/notes/data/repository/note_repository.dart';
import 'package:intl/date_symbol_data_local.dart';

class MockNoteRepository extends Mock implements NoteRepository {
  @override
  Future<List<NoteMetaData>> getNotes(int skip, int take) async {
    final dynamic raw = super.noSuchMethod(
      Invocation.method(#getNotes, [skip, take]),
    );
    if (raw == null) {
      return [];
    }
    final List<NoteMetaData> allNotes = await (raw as Future<List<NoteMetaData>>);
    
    var result = allNotes;
    if (skip < result.length) {
      result = result.skip(skip).toList();
    } else {
      result = [];
    }
    result = result.take(take).toList();
    return result;
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates a [NoteMetaData] with a [updatedAt] offset from now.
NoteMetaData makeNote({required String id, required DateTime updatedAt}) =>
    NoteMetaData(
      id: id,
      updatedAt: updatedAt,
      title: 'Note $id',
      height: 0,
      createdAt: DateTime.now(),
      previewText: 'Preview $id',
    );

/// Returns the list of [NoteMetaData] objects extracted from a flattened list.
List<NoteMetaData> extractNotes(List<Object> grouped) =>
    grouped.whereType<NoteMetaData>().toList();

List<TimeGroup> extractTimeGroups(List<Object> grouped) =>
    grouped.whereType<TimeGroup>().toList();

/// Returns the [TimeCategory] values of all [TimeGroup]s in a flattened list.
List<TimeCategory> extractCategories(List<Object> grouped) =>
    extractTimeGroups(grouped).map((g) => g.category).toList();

/// Returns true when the flattened list contains a [TimeGroup] with the given
/// [TimeCategory].
bool hasCategory(List<Object> grouped, TimeCategory category) =>
    extractCategories(grouped).contains(category);

// ---------------------------------------------------------------------------
// Test data factories
// ---------------------------------------------------------------------------

final now = DateTime.now();

final today = DateTime(now.year, now.month, now.day);
final thisMonthStart = DateTime(now.year, now.month, 1);

NoteMetaData recentNote(String id) =>
    makeNote(id: id, updatedAt: now.subtract(const Duration(minutes: 10)));

NoteMetaData todayNote(String id) =>
    makeNote(id: id, updatedAt: now.subtract(const Duration(hours: 3)));

NoteMetaData yesterdayNote(String id) =>
    makeNote(id: id, updatedAt: today.subtract(const Duration(days: 1)));

/// Exactly 3 calendar days ago — always within the last7Days window (1–7 days).
NoteMetaData thisWeekNote(String id) =>
    makeNote(id: id, updatedAt: now.subtract(const Duration(days: 3)));

/// Exactly 6 calendar days ago — still within the bloc's ≤7-day last7Days window.
NoteMetaData lastWeekNote(String id) =>
    makeNote(id: id, updatedAt: now.subtract(const Duration(days: 6)));

NoteMetaData thisMonthNote(String id) {
  final candidate = thisMonthStart;
  return makeNote(id: id, updatedAt: candidate);
}

/// A note exactly 25 days old — always within the lastMonth window (>7 days, ≤30 days).
NoteMetaData lastMonthNote(String id) =>
    makeNote(id: id, updatedAt: now.subtract(const Duration(days: 25)));

NoteMetaData olderNote(String id) =>
    makeNote(id: id, updatedAt: DateTime(now.year - 2, 1, 15));

/// Builds a list of [count] notes all updated recently.
List<NoteMetaData> buildNoteList(int count) => List.generate(
  count,
  (i) => makeNote(
    id: 'note_$i',
    updatedAt: now.subtract(Duration(minutes: i + 1)),
  ),
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockNoteRepository mockRepo;

  setUp(() {
    mockRepo = MockNoteRepository();
    initializeDateFormatting('en');
  });

  // ── Constructor ──────────────────────────────────────────────────────────

  group('NotesBloc – constructor', () {
    test('initial state is default NotesState', () {
      when(() => mockRepo.getNotes(any(), any())).thenAnswer((_) async => []);
      final bloc = NotesBloc(noteRepository: mockRepo);
      expect(bloc.state, const NotesState());
      bloc.close();
    });

    test('dispatches LoadNotes on creation', () async {
      when(() => mockRepo.getNotes(any(), any())).thenAnswer((_) async => []);
      final bloc = NotesBloc(noteRepository: mockRepo);
      await bloc.stream.first;
      verify(() => mockRepo.getNotes(any(), any())).called(1);
      await bloc.close();
    });
  });

  // ── LoadNotes – success ───────────────────────────────────────────────────

  group('LoadNotes – success', () {
    blocTest<NotesBloc, NotesState>(
      'emits [loading, loaded] with empty list when repository returns nothing',
      build: () {
        when(() => mockRepo.getNotes(any(), any())).thenAnswer((_) async => []);
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 2,
      act: (bloc) => bloc.add(LoadNotes()),
      expect: () => [
        isA<NotesState>().having((s) => s.isLoading, 'isLoading', true),
        isA<NotesState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.notes, 'notes', isEmpty)
            .having((s) => s.groupedNotes, 'groupedNotes', isEmpty)
            .having((s) => s.hasMore, 'hasMore', false)
            .having((s) => s.error, 'error', isNull),
      ],
    );

    blocTest<NotesBloc, NotesState>(
      'emits loaded state with correct notes when count ≤ pageSize',
      build: () {
        final notes = buildNoteList(5);
        when(() => mockRepo.getNotes(any(), any())).thenAnswer((_) async => notes);
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 2,
      act: (bloc) => bloc.add(LoadNotes()),
      expect: () => [
        isA<NotesState>().having((s) => s.isLoading, 'isLoading', true),
        isA<NotesState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.notes.length, 'notes.length', 5)
            .having((s) => s.hasMore, 'hasMore', false)
            .having((s) => s.currentPage, 'currentPage', 0),
      ],
    );

    blocTest<NotesBloc, NotesState>(
      'sets hasMore=true when total notes exceed pageSize',
      build: () {
        final notes = buildNoteList(Constants.pageSize + 5);
        when(() => mockRepo.getNotes(any(), any())).thenAnswer((_) async => notes);
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 2,
      act: (bloc) => bloc.add(LoadNotes()),
      expect: () => [
        isA<NotesState>().having((s) => s.isLoading, 'isLoading', true),
        isA<NotesState>()
            .having((s) => s.hasMore, 'hasMore', true)
            .having(
              (s) => s.notes.length,
              'notes.length',
              Constants.pageSize,
            ),
      ],
    );

    blocTest<NotesBloc, NotesState>(
      'resets currentPage to 0 on fresh load',
      build: () {
        when(
          () => mockRepo.getNotes(any(), any()),
        ).thenAnswer((_) async => buildNoteList(3));
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 2,
      act: (bloc) => bloc.add(LoadNotes()),
      expect: () => [
        isA<NotesState>(),
        isA<NotesState>().having((s) => s.currentPage, 'currentPage', 0),
      ],
    );

    blocTest<NotesBloc, NotesState>(
      'clears previous error on successful reload',
      build: () {
        when(() => mockRepo.getNotes(any(), any())).thenAnswer((_) async => []);
        return NotesBloc(noteRepository: mockRepo);
      },
      seed: () => const NotesState(
        error: ErrorCategory.failedToLoadNotes,
        isLoading: false,
        hasMore: false,
      ),
      skip: 2,
      act: (bloc) => bloc.add(LoadNotes()),
      expect: () => [
        isA<NotesState>()
            .having((s) => s.isLoading, 'isLoading', true)
            .having((s) => s.error, 'error', isNull),
        isA<NotesState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.error, 'error', isNull),
      ],
    );

    blocTest<NotesBloc, NotesState>(
      'groupedNotes contains exactly pageSize notes when total > pageSize',
      build: () {
        final notes = buildNoteList(Constants.pageSize + 10);
        when(() => mockRepo.getNotes(any(), any())).thenAnswer((_) async => notes);
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 2,
      act: (bloc) => bloc.add(LoadNotes()),
      verify: (bloc) {
        final visibleNotes = extractNotes(bloc.state.groupedNotes);
        expect(visibleNotes.length, Constants.pageSize);
      },
    );

    blocTest<NotesBloc, NotesState>(
      'stores only first page of notes in state.notes when total exceeds pageSize',
      build: () {
        final notes = buildNoteList(Constants.pageSize + 10);
        when(() => mockRepo.getNotes(any(), any())).thenAnswer((_) async => notes);
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 2,
      act: (bloc) => bloc.add(LoadNotes()),
      verify: (bloc) {
        expect(bloc.state.notes.length, Constants.pageSize);
      },
    );
  });

  // ── LoadNotes – failure ───────────────────────────────────────────────────

  group('LoadNotes – failure', () {
    blocTest<NotesBloc, NotesState>(
      'emits error state when repository throws',
      build: () {
        when(() => mockRepo.getNotes(any(), any())).thenThrow(Exception('db error'));
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 2,
      act: (bloc) => bloc.add(LoadNotes()),
      expect: () => [
        isA<NotesState>().having((s) => s.isLoading, 'isLoading', true),
        isA<NotesState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.error, 'error', isNotNull)
            .having((s) => s.notes, 'notes', isEmpty),
      ],
    );

    blocTest<NotesBloc, NotesState>(
      'emits failedToLoadNotes error category on generic exception',
      build: () {
        when(() => mockRepo.getNotes(any(), any())).thenThrow(Exception('any'));
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 2,
      act: (bloc) => bloc.add(LoadNotes()),
      expect: () => [
        isA<NotesState>(),
        isA<NotesState>().having(
          (s) => s.error,
          'error',
          ErrorCategory.failedToLoadNotes,
        ),
      ],
    );

    blocTest<NotesBloc, NotesState>(
      'emits appAlreadyRunning error when ObjectBoxException is thrown',
      build: () {
        when(() => mockRepo.getNotes(any(), any())).thenThrow(ObjectBoxException());
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 2,
      act: (bloc) => bloc.add(LoadNotes()),
      expect: () => [
        isA<NotesState>(),
        isA<NotesState>().having(
          (s) => s.error,
          'error',
          ErrorCategory.appAlreadyRunning,
        ),
      ],
    );

    blocTest<NotesBloc, NotesState>(
      'notes remain empty after failed load',
      build: () {
        when(() => mockRepo.getNotes(any(), any())).thenThrow(Exception('any'));
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 2,
      act: (bloc) => bloc.add(LoadNotes()),
      verify: (bloc) {
        expect(bloc.state.notes, isEmpty);
        expect(bloc.state.groupedNotes, isEmpty);
      },
    );
  });

  // ── Grouping / time labels ────────────────────────────────────────────────

  group('_buildFlattenedNotes – time groups', () {
    blocTest<NotesBloc, NotesState>(
      'assigns TimeCategory.recent for a note updated less than 2 hours ago',
      build: () {
        when(
          () => mockRepo.getNotes(any(), any()),
        ).thenAnswer((_) async => [recentNote('r1')]);
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 1,
      act: (bloc) => bloc.add(LoadNotes()),
      verify: (bloc) {
        expect(
          hasCategory(bloc.state.groupedNotes, TimeCategory.recent),
          isTrue,
        );
      },
    );

    blocTest<NotesBloc, NotesState>(
      'assigns TimeCategory.today for a note updated earlier today (≥2 h ago)',
      build: () {
        when(
          () => mockRepo.getNotes(any(), any()),
        ).thenAnswer((_) async => [todayNote('t1')]);
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 1,
      act: (bloc) => bloc.add(LoadNotes()),
      verify: (bloc) {
        expect(
          hasCategory(bloc.state.groupedNotes, TimeCategory.today),
          isTrue,
        );
      },
    );

    blocTest<NotesBloc, NotesState>(
      'assigns TimeCategory.last7Days for a note updated yesterday',
      build: () {
        when(
          () => mockRepo.getNotes(any(), any()),
        ).thenAnswer((_) async => [yesterdayNote('y1')]);
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 1,
      act: (bloc) => bloc.add(LoadNotes()),
      verify: (bloc) {
        expect(
          hasCategory(bloc.state.groupedNotes, TimeCategory.last7Days),
          isTrue,
        );
      },
    );

    blocTest<NotesBloc, NotesState>(
      'assigns TimeCategory.last7Days for a note from this week',
      build: () {
        when(
          () => mockRepo.getNotes(any(), any()),
        ).thenAnswer((_) async => [thisWeekNote('w1')]);
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 1,
      act: (bloc) => bloc.add(LoadNotes()),
      verify: (bloc) {
        expect(
          hasCategory(bloc.state.groupedNotes, TimeCategory.last7Days),
          isTrue,
        );
      },
    );

    blocTest<NotesBloc, NotesState>(
      'assigns TimeCategory.last7Days for a note 6 days ago',
      build: () {
        when(
          () => mockRepo.getNotes(any(), any()),
        ).thenAnswer((_) async => [lastWeekNote('lw1')]);
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 1,
      act: (bloc) => bloc.add(LoadNotes()),
      verify: (bloc) {
        expect(
          hasCategory(bloc.state.groupedNotes, TimeCategory.last7Days),
          isTrue,
        );
      },
    );

    blocTest<NotesBloc, NotesState>(
      'assigns TimeCategory.lastMonth or last7Days for a note from this month start',
      build: () {
        when(
          () => mockRepo.getNotes(any(), any()),
        ).thenAnswer((_) async => [thisMonthNote('tm1')]);
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 2,
      act: (bloc) => bloc.add(LoadNotes()),
      verify: (bloc) {
        final categories = extractCategories(bloc.state.groupedNotes);
        expect(
          categories.any(
            (c) => c == TimeCategory.lastMonth || c == TimeCategory.last7Days,
          ),
          isTrue,
        );
      },
    );

    blocTest<NotesBloc, NotesState>(
      'assigns TimeCategory.lastMonth for a note from last month',
      build: () {
        when(
          () => mockRepo.getNotes(any(), any()),
        ).thenAnswer((_) async => [lastMonthNote('lm1')]);
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 1,
      act: (bloc) => bloc.add(LoadNotes()),
      verify: (bloc) {
        expect(
          hasCategory(bloc.state.groupedNotes, TimeCategory.lastMonth),
          isTrue,
        );
      },
    );

    blocTest<NotesBloc, NotesState>(
      'assigns TimeCategory.custom for a note older than 30 days',
      build: () {
        when(
          () => mockRepo.getNotes(any(), any()),
        ).thenAnswer((_) async => [olderNote('o1')]);
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 1,
      act: (bloc) => bloc.add(LoadNotes()),
      verify: (bloc) {
        expect(
          hasCategory(bloc.state.groupedNotes, TimeCategory.custom),
          isTrue,
        );
      },
    );

    blocTest<NotesBloc, NotesState>(
      'custom TimeGroup has a non-null customLabel formatted as "MMMM yyyy"',
      build: () {
        when(
          () => mockRepo.getNotes(any(), any()),
        ).thenAnswer((_) async => [olderNote('o1')]);
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 1,
      act: (bloc) => bloc.add(LoadNotes()),
      verify: (bloc) {
        final customGroups = extractTimeGroups(
          bloc.state.groupedNotes,
        ).where((g) => g.category == TimeCategory.custom).toList();
        expect(customGroups, isNotEmpty);
        expect(customGroups.first.customLabel, isNotNull);
        expect(
          customGroups.first.customLabel,
          matches(RegExp(r'^[A-Za-z]+ \d{4}$')),
        );
      },
    );

    blocTest<NotesBloc, NotesState>(
      'does NOT repeat the same TimeGroup for consecutive notes in the same group',
      build: () {
        when(() => mockRepo.getNotes(any(), any())).thenAnswer(
          (_) async => [recentNote('r1'), recentNote('r2'), recentNote('r3')],
        );
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 1,
      act: (bloc) => bloc.add(LoadNotes()),
      verify: (bloc) {
        final groups = extractTimeGroups(bloc.state.groupedNotes);
        final recentCount = groups
            .where((g) => g.category == TimeCategory.recent)
            .length;
        expect(recentCount, 1);
      },
    );

    blocTest<NotesBloc, NotesState>(
      'inserts a new TimeGroup when the time category changes across notes',
      build: () {
        when(
          () => mockRepo.getNotes(any(), any()),
        ).thenAnswer((_) async => [recentNote('r1'), lastMonthNote('lm1')]);
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 1,
      act: (bloc) => bloc.add(LoadNotes()),
      verify: (bloc) {
        final categories = extractCategories(bloc.state.groupedNotes);
        expect(categories, contains(TimeCategory.recent));
        expect(categories, contains(TimeCategory.lastMonth));
        expect(categories.length, 2);
      },
    );

    blocTest<NotesBloc, NotesState>(
      'flattened list alternates TimeGroups and NoteMetaData in correct order',
      build: () {
        when(
          () => mockRepo.getNotes(any(), any()),
        ).thenAnswer((_) async => [recentNote('r1'), lastMonthNote('lm1')]);
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 1,
      act: (bloc) => bloc.add(LoadNotes()),
      verify: (bloc) {
        final grouped = bloc.state.groupedNotes;
        // Expected: [TimeGroup, NoteMetaData, TimeGroup, NoteMetaData]
        expect(grouped[0], isA<TimeGroup>());
        expect(grouped[1], isA<NoteMetaData>());
        expect(grouped[2], isA<TimeGroup>());
        expect(grouped[3], isA<NoteMetaData>());
      },
    );

    blocTest<NotesBloc, NotesState>(
      'single note produces exactly one TimeGroup and one NoteMetaData',
      build: () {
        when(
          () => mockRepo.getNotes(any(), any()),
        ).thenAnswer((_) async => [recentNote('r1')]);
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 1,
      act: (bloc) => bloc.add(LoadNotes()),
      verify: (bloc) {
        expect(bloc.state.groupedNotes.length, 2);
        expect(bloc.state.groupedNotes[0], isA<TimeGroup>());
        expect(bloc.state.groupedNotes[1], isA<NoteMetaData>());
      },
    );
  });

  // ── LoadMoreNotes – success ───────────────────────────────────────────────

  group('LoadMoreNotes – success', () {
    blocTest<NotesBloc, NotesState>(
      'sets hasMore=true when total notes exceed pageSize',
      build: () {
        final notes = buildNoteList(Constants.pageSize + 5);
        when(() => mockRepo.getNotes(any(), any())).thenAnswer((_) async => notes);
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 2,
      act: (bloc) => bloc.add(LoadNotes()),
      expect: () => [
        isA<NotesState>().having((s) => s.isLoading, 'isLoading', true),
        isA<NotesState>()
            .having((s) => s.hasMore, 'hasMore', true)
            .having(
              (s) => s.notes.length,
              'notes.length',
              Constants.pageSize,
            ),
      ],
    );

    blocTest<NotesBloc, NotesState>(
      'increments currentPage after loading more',
      build: () {
        final notes = buildNoteList(Constants.pageSize * 2);
        when(() => mockRepo.getNotes(any(), any())).thenAnswer((_) async => notes);
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 2,
      act: (bloc) => bloc.add(LoadMoreNotes()),
      expect: () => [
        isA<NotesState>(),
        isA<NotesState>().having((s) => s.currentPage, 'currentPage', 1),
      ],
    );

    blocTest<NotesBloc, NotesState>(
      'sets hasMore=true when another full page is available',
      build: () {
        final notes = buildNoteList(Constants.pageSize * 2);
        when(() => mockRepo.getNotes(any(), any())).thenAnswer((_) async => notes);
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 2,
      act: (bloc) => bloc.add(LoadMoreNotes()),
      expect: () => [
        isA<NotesState>(),
        isA<NotesState>().having((s) => s.hasMore, 'hasMore', true),
      ],
    );

    blocTest<NotesBloc, NotesState>(
      'does not duplicate the section TimeGroup when new batch is in the same group',
      build: () {
        final notes = buildNoteList(Constants.pageSize + 5);
        when(() => mockRepo.getNotes(any(), any())).thenAnswer((_) async => notes);
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 2,
      act: (bloc) => bloc.add(LoadMoreNotes()),
      verify: (bloc) {
        final groups = extractTimeGroups(bloc.state.groupedNotes);
        final recentCount = groups
            .where((g) => g.category == TimeCategory.recent)
            .length;
        expect(recentCount, 1);
      },
    );

    blocTest<NotesBloc, NotesState>(
      'appends new notes to groupedNotes after load more',
      build: () {
        final notes = buildNoteList(Constants.pageSize + 5);
        when(() => mockRepo.getNotes(any(), any())).thenAnswer((_) async => notes);
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 2,
      act: (bloc) => bloc.add(LoadMoreNotes()),
      verify: (bloc) {
        final visibleNotes = extractNotes(bloc.state.groupedNotes);
        expect(visibleNotes.length, Constants.pageSize + 5);
      },
    );

    blocTest<NotesBloc, NotesState>(
      'sets hasMore=false when last batch is smaller than pageSize',
      build: () {
        // pageSize + 3 means second batch has only 3 notes (< pageSize)
        final notes = buildNoteList(Constants.pageSize + 3);
        when(() => mockRepo.getNotes(any(), any())).thenAnswer((_) async => notes);
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 2,
      act: (bloc) => bloc.add(LoadMoreNotes()),
      verify: (bloc) {
        expect(bloc.state.hasMore, isFalse);
      },
    );
  });

  // ── LoadMoreNotes – no-op conditions ─────────────────────────────────────

  group('LoadMoreNotes – no-op conditions', () {
    blocTest<NotesBloc, NotesState>(
      'sets hasMore=true when total notes exceed pageSize',
      build: () {
        final notes = buildNoteList(25);
        when(() => mockRepo.getNotes(any(), any())).thenAnswer((_) async => notes);
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 2,
      act: (bloc) => bloc.add(LoadNotes()),
      expect: () => [
        isA<NotesState>().having((s) => s.isLoading, 'isLoading', true),
        isA<NotesState>()
            .having((s) => s.hasMore, 'hasMore', true)
            .having((s) => s.notes.length, 'notes.length', Constants.pageSize),
      ],
    );

    blocTest<NotesBloc, NotesState>(
      'ignores concurrent LoadMoreNotes while already loading more',
      build: () {
        final notes = buildNoteList(Constants.pageSize * 3);
        when(() => mockRepo.getNotes(any(), any())).thenAnswer((_) async => notes);
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 2,
      act: (bloc) async {
        bloc.add(LoadMoreNotes());
        bloc.add(LoadMoreNotes());
      },
      verify: (bloc) {
        expect(bloc.state.currentPage, 2);
      },
    );

    blocTest<NotesBloc, NotesState>(
      'emits hasMore=false and isLoadingMore=false when new batch is empty',
      build: () {
        final notes = buildNoteList(Constants.pageSize);
        when(() => mockRepo.getNotes(any(), any())).thenAnswer((_) async => notes);
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 2,
      act: (bloc) => bloc.add(LoadMoreNotes()),
      expect: () => [
        isA<NotesState>().having((s) => s.isLoadingMore, 'isLoadingMore', true),
        isA<NotesState>()
            .having((s) => s.isLoadingMore, 'isLoadingMore', false)
            .having((s) => s.hasMore, 'hasMore', false),
      ],
    );
  });

  // ── LoadMoreNotes – failure ───────────────────────────────────────────────

  group('LoadMoreNotes – failure', () {
    blocTest<NotesBloc, NotesState>(
      'emits isLoadingMore=false on exception without changing existing notes',
      build: () {
        final notes = buildNoteList(Constants.pageSize + 1);
        when(() => mockRepo.getNotes(any(), any())).thenAnswer((_) async => notes);
        return NotesBloc(noteRepository: mockRepo);
      },
      seed: () => NotesState(
        notes: buildNoteList(Constants.pageSize + 1),
        groupedNotes: [
          const TimeGroup(TimeCategory.recent),
          ...buildNoteList(Constants.pageSize),
        ],
        isLoading: false,
        hasMore: true,
        currentPage: 0,
      ),
      skip: 2,
      act: (bloc) {
        bloc.add(LoadMoreNotes());
      },
      expect: () => [
        isA<NotesState>().having((s) => s.isLoadingMore, 'isLoadingMore', true),
        isA<NotesState>().having(
          (s) => s.isLoadingMore,
          'isLoadingMore',
          false,
        ),
      ],
    );
  });

  // ── RefreshNote ───────────────────────────────────────────────────────────

  group('RefreshNote', () {
    blocTest<NotesBloc, NotesState>(
      'moves the refreshed note to the top of state.notes',
      build: () {
        final notes = buildNoteList(3);
        when(() => mockRepo.getNotes(any(), any())).thenAnswer((_) async => notes);
        when(() => mockRepo.getNoteMetaData('note_2')).thenAnswer(
          (_) async => makeNote(
            id: 'note_2',
            updatedAt: now.subtract(const Duration(minutes: 1)),
          ),
        );
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 2,
      act: (bloc) => bloc.add(RefreshNote(noteId: 'note_2')),
      verify: (bloc) {
        expect(bloc.state.notes.first.id, 'note_2');
      },
    );

    blocTest<NotesBloc, NotesState>(
      'removes the old entry of the refreshed note from state.notes',
      build: () {
        final notes = buildNoteList(3);
        when(() => mockRepo.getNotes(any(), any())).thenAnswer((_) async => notes);
        when(() => mockRepo.getNoteMetaData('note_1')).thenAnswer(
          (_) async => makeNote(
            id: 'note_1',
            updatedAt: now.subtract(const Duration(minutes: 1)),
          ),
        );
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 2,
      act: (bloc) => bloc.add(RefreshNote(noteId: 'note_1')),
      verify: (bloc) {
        final ids = bloc.state.notes.map((n) => n.id).toList();
        expect(ids.where((id) => id == 'note_1').length, 1);
      },
    );

    blocTest<NotesBloc, NotesState>(
      'sets isRefreshed=true after refresh completes',
      build: () {
        final notes = buildNoteList(3);
        when(() => mockRepo.getNotes(any(), any())).thenAnswer((_) async => notes);
        when(() => mockRepo.getNoteMetaData('note_0')).thenAnswer(
          (_) async => makeNote(
            id: 'note_0',
            updatedAt: now.subtract(const Duration(minutes: 1)),
          ),
        );
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 2,
      act: (bloc) => bloc.add(RefreshNote(noteId: 'note_0')),
      verify: (bloc) {
        expect(bloc.state.isRefreshed, isTrue);
      },
    );

    blocTest<NotesBloc, NotesState>(
      'resets currentPage to 0 after refresh',
      build: () {
        final notes = buildNoteList(3);
        when(() => mockRepo.getNotes(any(), any())).thenAnswer((_) async => notes);
        when(() => mockRepo.getNoteMetaData('note_0')).thenAnswer(
          (_) async => makeNote(
            id: 'note_0',
            updatedAt: now.subtract(const Duration(minutes: 1)),
          ),
        );
        return NotesBloc(noteRepository: mockRepo);
      },
      seed: () => NotesState(
        notes: buildNoteList(3),
        groupedNotes: const [],
        currentPage: 2,
        hasMore: false,
      ),
      skip: 2,
      act: (bloc) => bloc.add(RefreshNote(noteId: 'note_0')),
      verify: (bloc) {
        expect(bloc.state.currentPage, 0);
      },
    );

    blocTest<NotesBloc, NotesState>(
      'does nothing when repository returns null for the note',
      build: () {
        final notes = buildNoteList(3);
        when(() => mockRepo.getNotes(any(), any())).thenAnswer((_) async => notes);
        when(
          () => mockRepo.getNoteMetaData('missing'),
        ).thenAnswer((_) async => null);
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 2,
      act: (bloc) => bloc.add(RefreshNote(noteId: 'missing')),
      expect: () => [],
    );

    blocTest<NotesBloc, NotesState>(
      'does not crash when repository throws during refresh',
      build: () {
        final notes = buildNoteList(3);
        when(() => mockRepo.getNotes(any(), any())).thenAnswer((_) async => notes);
        when(
          () => mockRepo.getNoteMetaData(any()),
        ).thenThrow(Exception('fetch error'));
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 2,
      act: (bloc) => bloc.add(RefreshNote(noteId: 'note_0')),
      // Exception is caught; no new state emitted
      expect: () => [],
    );

    blocTest<NotesBloc, NotesState>(
      'only refreshes notes in TimeCategory.recent group',
      build: () {
        // Note with an old update time goes to lastMonth, not recent
        final oldNote = lastMonthNote('old_note');
        when(() => mockRepo.getNotes(any(), any())).thenAnswer((_) async => [oldNote]);
        when(
          () => mockRepo.getNoteMetaData('old_note'),
        ).thenAnswer((_) async => oldNote);
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 2,
      act: (bloc) => bloc.add(RefreshNote(noteId: 'old_note')),
      // Non-recent notes are skipped; no state change
      expect: () => [],
    );
  });

  // ── DeleteNotes ───────────────────────────────────────────────────────────

  group('DeleteNotes', () {
    blocTest<NotesBloc, NotesState>(
      'removes deleted note ids from state.notes',
      build: () {
        final notes = buildNoteList(5);
        when(() => mockRepo.getNotes(any(), any())).thenAnswer((_) async => notes);
        when(
          () => mockRepo.deleteNotes(['note_0', 'note_1']),
        ).thenAnswer((_) async {});
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 2,
      act: (bloc) => bloc.add(DeleteNotes(noteIds: ['note_0', 'note_1'])),
      verify: (bloc) {
        final ids = bloc.state.notes.map((n) => n.id).toList();
        expect(ids, isNot(contains('note_0')));
        expect(ids, isNot(contains('note_1')));
        expect(ids.length, 3);
      },
    );

    blocTest<NotesBloc, NotesState>(
      'sets isRefreshed=true after deletion',
      build: () {
        final notes = buildNoteList(3);
        when(() => mockRepo.getNotes(any(), any())).thenAnswer((_) async => notes);
        when(() => mockRepo.deleteNotes(any())).thenAnswer((_) async {});
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 2,
      act: (bloc) => bloc.add(DeleteNotes(noteIds: ['note_0'])),
      verify: (bloc) {
        expect(bloc.state.isRefreshed, isTrue);
      },
    );

    blocTest<NotesBloc, NotesState>(
      'clears selectedNotes after deletion',
      build: () {
        final notes = buildNoteList(3);
        when(() => mockRepo.getNotes(any(), any())).thenAnswer((_) async => notes);
        when(() => mockRepo.deleteNotes(any())).thenAnswer((_) async {});
        return NotesBloc(noteRepository: mockRepo);
      },
      seed: () => NotesState(
        notes: buildNoteList(3),
        groupedNotes: const [],
        selectedNotes: const ['note_0'],
        isSelectionMode: true,
      ),
      skip: 2,
      act: (bloc) => bloc.add(DeleteNotes(noteIds: ['note_0'])),
      verify: (bloc) {
        expect(bloc.state.selectedNotes, isEmpty);
        expect(bloc.state.isSelectionMode, isFalse);
      },
    );

    blocTest<NotesBloc, NotesState>(
      'uses selectedNotes from state when isSelectionMode is true',
      build: () {
        final notes = buildNoteList(5);
        when(() => mockRepo.getNotes(any(), any())).thenAnswer((_) async => notes);
        when(
          () => mockRepo.deleteNotes(['note_0', 'note_1']),
        ).thenAnswer((_) async {});
        return NotesBloc(noteRepository: mockRepo);
      },
      seed: () => NotesState(
        notes: buildNoteList(5),
        groupedNotes: const [],
        selectedNotes: const ['note_0', 'note_1'],
        isSelectionMode: true,
      ),
      skip: 2,
      act: (bloc) =>
          bloc.add(DeleteNotes()), // no noteIds; should use selectedNotes
      verify: (bloc) {
        final ids = bloc.state.notes.map((n) => n.id).toList();
        expect(ids, isNot(contains('note_0')));
        expect(ids, isNot(contains('note_1')));
      },
    );

    blocTest<NotesBloc, NotesState>(
      'does nothing when selectedNotes is empty and event.noteIds is null',
      build: () {
        final notes = buildNoteList(3);
        when(() => mockRepo.getNotes(any(), any())).thenAnswer((_) async => notes);
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 2,
      act: (bloc) => bloc.add(DeleteNotes()),
      // isRefreshed:false is emitted but deduplicated by Equatable against
      // the already-false loaded state, so no new state propagates.
      expect: () => [],
    );

    blocTest<NotesBloc, NotesState>(
      'emits failedToDeleteNotes error when repository throws',
      build: () {
        final notes = buildNoteList(3);
        when(() => mockRepo.getNotes(any(), any())).thenAnswer((_) async => notes);
        when(
          () => mockRepo.deleteNotes(any()),
        ).thenThrow(Exception('db error'));
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 2,
      act: (bloc) => bloc.add(DeleteNotes(noteIds: ['note_0'])),
      verify: (bloc) {
        expect(bloc.state.error, ErrorCategory.failedToDeleteNotes);
      },
    );

    blocTest<NotesBloc, NotesState>(
      'resets currentPage to 0 and rebuilds groupedNotes after deletion',
      build: () {
        final notes = buildNoteList(5);
        when(() => mockRepo.getNotes(any(), any())).thenAnswer((_) async => notes);
        when(() => mockRepo.deleteNotes(any())).thenAnswer((_) async {});
        return NotesBloc(noteRepository: mockRepo);
      },
      seed: () => NotesState(
        notes: buildNoteList(5),
        groupedNotes: const [],
        currentPage: 2,
        isSelectionMode: false,
      ),
      skip: 2,
      act: (bloc) => bloc.add(DeleteNotes(noteIds: ['note_0'])),
      verify: (bloc) {
        expect(bloc.state.currentPage, 0);
        expect(bloc.state.groupedNotes, isNotEmpty);
      },
    );
  });

  // ── ToggleSelectionMode ───────────────────────────────────────────────────

  group('ToggleSelectionMode', () {
    blocTest<NotesBloc, NotesState>(
      'turns selection mode ON when it was OFF',
      build: () {
        when(() => mockRepo.getNotes(any(), any())).thenAnswer((_) async => []);
        return NotesBloc(noteRepository: mockRepo);
      },
      seed: () => const NotesState(isSelectionMode: false),
      skip: 2,
      act: (bloc) => bloc.add(ToggleSelectionMode()),
      verify: (bloc) {
        expect(bloc.state.isSelectionMode, isTrue);
      },
    );

    blocTest<NotesBloc, NotesState>(
      'turns selection mode OFF when it was ON and clears selectedNotes',
      build: () {
        when(() => mockRepo.getNotes(any(), any())).thenAnswer((_) async => []);
        return NotesBloc(noteRepository: mockRepo);
      },
      seed: () => const NotesState(
        isSelectionMode: true,
        selectedNotes: ['note_0', 'note_1'],
      ),
      skip: 2,
      act: (bloc) => bloc.add(ToggleSelectionMode()),
      verify: (bloc) {
        expect(bloc.state.isSelectionMode, isFalse);
        expect(bloc.state.selectedNotes, isEmpty);
      },
    );

    blocTest<NotesBloc, NotesState>(
      'toggling twice returns to the original state',
      build: () {
        when(() => mockRepo.getNotes(any(), any())).thenAnswer((_) async => []);
        return NotesBloc(noteRepository: mockRepo);
      },
      seed: () => const NotesState(isSelectionMode: false),
      act: (bloc) {
        bloc.add(ToggleSelectionMode());
        bloc.add(ToggleSelectionMode());
      },
      verify: (bloc) {
        expect(bloc.state.isSelectionMode, isFalse);
        expect(bloc.state.selectedNotes, isEmpty);
      },
    );
  });

  // ── ToggleNoteSelection ───────────────────────────────────────────────────

  group('ToggleNoteSelection', () {
    blocTest<NotesBloc, NotesState>(
      'adds a note to selectedNotes when it was not selected',
      build: () {
        when(() => mockRepo.getNotes(any(), any())).thenAnswer((_) async => []);
        return NotesBloc(noteRepository: mockRepo);
      },
      seed: () => const NotesState(isSelectionMode: true, selectedNotes: []),
      skip: 2,
      act: (bloc) => bloc.add(ToggleNoteSelection(noteId: 'note_0')),
      verify: (bloc) {
        expect(bloc.state.selectedNotes, contains('note_0'));
      },
    );

    blocTest<NotesBloc, NotesState>(
      'removes a note from selectedNotes when it was already selected',
      build: () {
        when(() => mockRepo.getNotes(any(), any())).thenAnswer((_) async => []);
        return NotesBloc(noteRepository: mockRepo);
      },
      seed: () =>
          const NotesState(isSelectionMode: true, selectedNotes: ['note_0']),
      skip: 2,
      act: (bloc) => bloc.add(ToggleNoteSelection(noteId: 'note_0')),
      verify: (bloc) {
        expect(bloc.state.selectedNotes, isNot(contains('note_0')));
      },
    );

    blocTest<NotesBloc, NotesState>(
      'activates selection mode when first note is selected',
      build: () {
        when(() => mockRepo.getNotes(any(), any())).thenAnswer((_) async => []);
        return NotesBloc(noteRepository: mockRepo);
      },
      seed: () => const NotesState(isSelectionMode: false, selectedNotes: []),
      skip: 2,
      act: (bloc) => bloc.add(ToggleNoteSelection(noteId: 'note_0')),
      verify: (bloc) {
        expect(bloc.state.isSelectionMode, isTrue);
        expect(bloc.state.selectedNotes, contains('note_0'));
      },
    );

    blocTest<NotesBloc, NotesState>(
      'can select multiple distinct notes',
      build: () {
        when(() => mockRepo.getNotes(any(), any())).thenAnswer((_) async => []);
        return NotesBloc(noteRepository: mockRepo);
      },
      seed: () => const NotesState(isSelectionMode: true, selectedNotes: []),
      act: (bloc) {
        bloc.add(ToggleNoteSelection(noteId: 'note_0'));
        bloc.add(ToggleNoteSelection(noteId: 'note_1'));
        bloc.add(ToggleNoteSelection(noteId: 'note_2'));
      },
      verify: (bloc) {
        expect(
          bloc.state.selectedNotes,
          containsAll(['note_0', 'note_1', 'note_2']),
        );
        expect(bloc.state.selectedNotes.length, 3);
      },
    );

    blocTest<NotesBloc, NotesState>(
      'selecting and deselecting the same note leaves selectedNotes empty',
      build: () {
        when(() => mockRepo.getNotes(any(), any())).thenAnswer((_) async => []);
        return NotesBloc(noteRepository: mockRepo);
      },
      seed: () => const NotesState(isSelectionMode: true, selectedNotes: []),
      act: (bloc) {
        bloc.add(ToggleNoteSelection(noteId: 'note_0'));
        bloc.add(ToggleNoteSelection(noteId: 'note_0'));
      },
      verify: (bloc) {
        expect(bloc.state.selectedNotes, isEmpty);
      },
    );
  });

  // ── SelectAllNotes ────────────────────────────────────────────────────────

  group('SelectAllNotes', () {
    blocTest<NotesBloc, NotesState>(
      'selects all visible (paginated) notes and sets isSelectionMode=true',
      build: () {
        // 3 notes — constructor's LoadNotes loads them all into groupedNotes
        when(
          () => mockRepo.getNotes(any(), any()),
        ).thenAnswer((_) async => buildNoteList(3));
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 2, // skip constructor loading + loaded states
      act: (bloc) => bloc.add(SelectAllNotes()),
      verify: (bloc) {
        expect(bloc.state.isSelectionMode, isTrue);
        expect(bloc.state.selectedNotes.length, 3);
      },
    );

    blocTest<NotesBloc, NotesState>(
      'deselects all notes when all are already selected (toggle off)',
      build: () {
        when(
          () => mockRepo.getNotes(any(), any()),
        ).thenAnswer((_) async => buildNoteList(3));
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 2,
      act: (bloc) async {
        // First select all, then select all again to toggle off
        bloc.add(SelectAllNotes());
        await Future<void>.delayed(Duration.zero);
        bloc.add(SelectAllNotes());
      },
      verify: (bloc) {
        expect(bloc.state.isSelectionMode, isFalse);
        expect(bloc.state.selectedNotes, isEmpty);
      },
    );

    blocTest<NotesBloc, NotesState>(
      'selects only notes visible in groupedNotes, not all state.notes',
      build: () {
        // pageSize + 5 notes: constructor loads first pageSize into groupedNotes,
        // remaining 5 stay in state.notes but are not visible yet
        when(
          () => mockRepo.getNotes(any(), any()),
        ).thenAnswer((_) async => buildNoteList(Constants.pageSize + 5));
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 2,
      act: (bloc) => bloc.add(SelectAllNotes()),
      verify: (bloc) {
        // Only the pageSize visible notes should be selected
        expect(bloc.state.selectedNotes.length, Constants.pageSize);
      },
    );
  });

  // ── ClearSelection ────────────────────────────────────────────────────────

  group('ClearSelection', () {
    blocTest<NotesBloc, NotesState>(
      'clears selectedNotes and sets isSelectionMode=false',
      build: () {
        when(
          () => mockRepo.getNotes(any(), any()),
        ).thenAnswer((_) async => buildNoteList(3));
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 2,
      act: (bloc) async {
        // Select all first, then clear
        bloc.add(SelectAllNotes());
        await Future<void>.delayed(Duration.zero);
        bloc.add(ClearSelection());
      },
      verify: (bloc) {
        expect(bloc.state.isSelectionMode, isFalse);
        expect(bloc.state.selectedNotes, isEmpty);
      },
    );

    blocTest<NotesBloc, NotesState>(
      'is a no-op when selection is already empty',
      build: () {
        when(() => mockRepo.getNotes(any(), any())).thenAnswer((_) async => []);
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 2,
      act: (bloc) => bloc.add(ClearSelection()),
      // Already empty selection — Equatable deduplicates the identical state
      verify: (bloc) {
        expect(bloc.state.isSelectionMode, isFalse);
        expect(bloc.state.selectedNotes, isEmpty);
      },
    );

    blocTest<NotesBloc, NotesState>(
      'does not affect notes or groupedNotes',
      build: () {
        when(
          () => mockRepo.getNotes(any(), any()),
        ).thenAnswer((_) async => buildNoteList(3));
        return NotesBloc(noteRepository: mockRepo);
      },
      skip: 2,
      act: (bloc) async {
        // Select a note first, then clear — notes/groupedNotes must stay intact
        bloc.add(ToggleNoteSelection(noteId: 'note_0'));
        await Future<void>.delayed(Duration.zero);
        bloc.add(ClearSelection());
      },
      verify: (bloc) {
        expect(bloc.state.notes.length, 3);
        // groupedNotes = 1 TimeGroup + 3 NoteMetaData
        expect(bloc.state.groupedNotes.length, 4);
      },
    );
  });

  // ── NotesState: copyWith / equality ──────────────────────────────────────

  group('NotesState', () {
    test('copyWith returns updated copy without mutating original', () {
      const original = NotesState(currentPage: 0, hasMore: true);
      final updated = original.copyWith(currentPage: 1, hasMore: false);

      expect(original.currentPage, 0);
      expect(original.hasMore, true);
      expect(updated.currentPage, 1);
      expect(updated.hasMore, false);
    });

    test('two states with same values are equal (Equatable)', () {
      const a = NotesState(currentPage: 1, isLoading: false);
      const b = NotesState(currentPage: 1, isLoading: false);
      expect(a, equals(b));
    });

    test('pageSize constant is 20', () {
      expect(Constants.pageSize, 20);
    });

    test('default localized is "en"', () {
      expect(const NotesState().localized, 'en');
    });

    test('copyWith with no arguments returns an equal state', () {
      const state = NotesState(currentPage: 3, isLoading: true, hasMore: true);
      // error is always null in copyWith when not supplied — known behaviour
      final copy = state.copyWith();
      expect(copy.currentPage, state.currentPage);
      expect(copy.isLoading, state.isLoading);
      expect(copy.hasMore, state.hasMore);
    });

    test('isRefreshed defaults to false in copyWith when not supplied', () {
      // copyWith always sets isRefreshed to false when not provided
      const state = NotesState(isRefreshed: true);
      final copy = state.copyWith();
      expect(copy.isRefreshed, isFalse);
    });

    test('error is always cleared in copyWith when not provided', () {
      // The copyWith implementation passes `error` directly (not ??),
      // so omitting it resets to null — document this behaviour.
      const state = NotesState(error: ErrorCategory.failedToLoadNotes);
      final copy = state.copyWith(); // no error argument
      expect(copy.error, isNull);
    });

    test('copyWith preserves selectedNotes when not overridden', () {
      const state = NotesState(selectedNotes: ['a', 'b']);
      final copy = state.copyWith(currentPage: 1);
      expect(copy.selectedNotes, ['a', 'b']);
    });

    test('two states with different currentPage are not equal', () {
      const a = NotesState(currentPage: 0);
      const b = NotesState(currentPage: 1);
      expect(a, isNot(equals(b)));
    });
  });
}
