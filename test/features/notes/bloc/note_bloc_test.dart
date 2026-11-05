import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mechanix_notes/core/exceptions/objectbox_exception.dart';
import 'package:mechanix_notes/core/utils/enums.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_bloc.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_event.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_state.dart';
import 'package:mechanix_notes/features/notes/data/models/note_metadata.dart';
import 'package:mechanix_notes/features/notes/data/models/note_model.dart';
import 'package:mechanix_notes/features/notes/data/models/time_group.dart';
import 'package:mechanix_notes/features/notes/data/repository/note_repository.dart';

// ---------------------------------------------------------------------------
// Fake repository: in-memory notes, sorted and watched like the ObjectBox query
// ---------------------------------------------------------------------------

class FakeNoteRepository implements NoteRepository {
  final Map<String, NoteMetaData> _notes = {};
  final _changes = StreamController<void>.broadcast();
  Object? watchError;
  Object? deleteError;
  int watchCount = 0;
  final List<List<String>> deletedBatches = [];

  FakeNoteRepository([Iterable<NoteMetaData> notes = const []]) {
    for (final n in notes) {
      _notes[n.id] = n;
    }
  }

  List<NoteMetaData> get sorted => _notes.values.toList()
    ..sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });

  List<String> get sortedIds => sorted.map((n) => n.id).toList();

  void save(NoteMetaData note) {
    _notes[note.id] = note;
    _changes.add(null);
  }

  void remove(String id) {
    _notes.remove(id);
    _changes.add(null);
  }

  @override
  Stream<List<NoteMetaData>> watchNotes() async* {
    watchCount++;
    if (watchError != null) throw watchError!;
    yield sorted;
    yield* _changes.stream.map((_) => sorted);
  }

  @override
  Future<void> deleteNotes(List<String> ids) async {
    if (deleteError != null) throw deleteError!;
    deletedBatches.add(ids);
    ids.forEach(_notes.remove);
    _changes.add(null);
  }

  @override
  Future<bool> togglePinNote(String id) async {
    final n = _notes[id]!;
    save(note(n.id, n.updatedAt, pinned: !n.isPinned));
    return !n.isPinned;
  }

  @override
  Future<NoteModel?> getNoteById(String id) async => null;

  @override
  Future<void> upsertNote(NoteModel note) async {}

  @override
  Future<List<String>> searchNoteIds(String query) async => [];

  @override
  Future<List<NoteMetaData>> getNotesMetaData(List<String> ids) async => [];

  @override
  Future<void> close() async {}
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

final base = DateTime(2026, 10, 26, 12);

NoteMetaData note(String id, DateTime updatedAt, {bool pinned = false}) =>
    NoteMetaData(
      id: id,
      title: 'Note $id',
      previewText: 'Preview $id',
      createdAt: updatedAt,
      updatedAt: updatedAt,
      height: 0,
      isPinned: pinned,
    );

/// [count] notes, n0 newest, each 3 hours older than the previous one.
List<NoteMetaData> notesSpacedBy3h(int count) => List.generate(
  count,
  (i) => note('n$i', base.subtract(Duration(hours: i * 3))),
);

List<String> visibleIds(NotesBloc bloc) =>
    bloc.state.groupedNotes.whereType<NoteMetaData>().map((n) => n.id).toList();

List<TimeCategory> categories(NotesBloc bloc) => bloc.state.groupedNotes
    .whereType<TimeGroup>()
    .map((g) => g.category)
    .toList();

NotesBloc buildBloc(FakeNoteRepository repo, {DateTime Function()? clock}) =>
    NotesBloc(noteRepository: repo, clock: clock ?? () => base);

/// The list on screen must be exactly the notes in the repository, in order,
/// with no duplicates.
void expectInSync(NotesBloc bloc, FakeNoteRepository repo) {
  expect(visibleIds(bloc), repo.sortedIds);
  expect(bloc.state.notes.map((n) => n.id).toList(), repo.sortedIds);
}

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  late FakeNoteRepository repo;
  late NotesBloc bloc;

  tearDown(() => bloc.close());

  group('LoadNotes', () {
    test('starts loading and subscribes once on creation', () async {
      repo = FakeNoteRepository(notesSpacedBy3h(3));
      bloc = buildBloc(repo);
      expect(bloc.state.isLoading, isTrue);

      await pumpEventQueue();

      expect(repo.watchCount, 1);
      expect(bloc.state.isLoading, isFalse);
      expectInSync(bloc, repo);
    });

    test('emits an empty, loaded state when there are no notes', () async {
      repo = FakeNoteRepository();
      bloc = buildBloc(repo);
      await pumpEventQueue();

      expect(bloc.state.isLoading, isFalse);
      expect(bloc.state.notes, isEmpty);
      expect(bloc.state.groupedNotes, isEmpty);
      expect(bloc.state.error, isNull);
    });

    test('maps a locked store to appAlreadyRunning', () async {
      repo = FakeNoteRepository()..watchError = ObjectBoxException('locked');
      bloc = buildBloc(repo);
      await pumpEventQueue();

      expect(bloc.state.isLoading, isFalse);
      expect(bloc.state.error, ErrorCategory.appAlreadyRunning);
    });

    test('maps other errors to failedToLoadNotes', () async {
      repo = FakeNoteRepository()..watchError = Exception('boom');
      bloc = buildBloc(repo);
      await pumpEventQueue();

      expect(bloc.state.error, ErrorCategory.failedToLoadNotes);
    });

    test('LoadNotes after an error resubscribes and recovers', () async {
      repo = FakeNoteRepository(notesSpacedBy3h(2))
        ..watchError = Exception('boom');
      bloc = buildBloc(repo);
      await pumpEventQueue();
      expect(bloc.state.error, ErrorCategory.failedToLoadNotes);

      repo.watchError = null;
      bloc.add(LoadNotes());
      await pumpEventQueue();

      expect(repo.watchCount, 2);
      expect(bloc.state.error, isNull);
      expectInSync(bloc, repo);
    });
  });

  group('time groups', () {
    test('assigns each note to the right group, in order', () async {
      repo = FakeNoteRepository([
        note('recent', base.subtract(const Duration(minutes: 30))),
        note('today', base.subtract(const Duration(hours: 5))),
        note('yesterday', base.subtract(const Duration(days: 1))),
        note('week', base.subtract(const Duration(days: 5))),
        note('month', base.subtract(const Duration(days: 20))),
        note('older', DateTime(2025, 3, 10)),
      ]);
      bloc = buildBloc(repo);
      await pumpEventQueue();

      expect(categories(bloc), [
        TimeCategory.recent,
        TimeCategory.today,
        TimeCategory.yesterday,
        TimeCategory.last7Days,
        TimeCategory.lastMonth,
        TimeCategory.custom,
      ]);
      expect(
        bloc.state.groupedNotes.whereType<TimeGroup>().last.customLabel,
        'March 2025',
      );
    });

    test('pinned notes come first, once, under a single header', () async {
      repo = FakeNoteRepository([
        note('r1', base),
        note('p1', DateTime(2024, 1, 1), pinned: true),
        note('p2', base.subtract(const Duration(days: 3)), pinned: true),
      ]);
      bloc = buildBloc(repo);
      await pumpEventQueue();

      expect(
        bloc.state.groupedNotes.first,
        const TimeGroup(TimeCategory.pinned),
      );
      expect(categories(bloc), [TimeCategory.pinned, TimeCategory.recent]);
      expect(visibleIds(bloc), ['p2', 'p1', 'r1']);
    });

    test('counts the notes in each group', () async {
      repo = FakeNoteRepository([
        note('p1', base, pinned: true),
        note('r1', base),
        note('r2', base.subtract(const Duration(minutes: 30))),
        note('y1', base.subtract(const Duration(days: 1))),
      ]);
      bloc = buildBloc(repo);
      await pumpEventQueue();

      expect(bloc.state.groupCounts, {
        const TimeGroup(TimeCategory.pinned): 1,
        const TimeGroup(TimeCategory.recent): 2,
        const TimeGroup(TimeCategory.yesterday): 1,
      });
    });

    test(
      'groups are recomputed against the clock on the next change',
      () async {
        var now = base;
        repo = FakeNoteRepository([note('a', base)]);
        bloc = buildBloc(repo, clock: () => now);
        await pumpEventQueue();
        expect(categories(bloc), [TimeCategory.recent]);

        now = base.add(const Duration(days: 1));
        repo.save(note('b', now));
        await pumpEventQueue();

        expect(categories(bloc), [TimeCategory.recent, TimeCategory.yesterday]);
        expect(visibleIds(bloc), ['b', 'a']);
      },
    );
  });

  // The list must match the repository after every kind of change and at every
  // size. These used to fail with offset pagination (missing notes after
  // create/edit/delete, stale pin state, duplicates during a page load).
  for (final count in [10, 20, 1000]) {
    group('live updates with $count notes', () {
      setUp(() async {
        repo = FakeNoteRepository(notesSpacedBy3h(count));
        bloc = buildBloc(repo);
        await pumpEventQueue();
      });

      test('shows every note on load', () {
        expect(bloc.state.notes, hasLength(count));
        expectInSync(bloc, repo);
      });

      test('a new note appears at the top and none go missing', () async {
        repo.save(note('new', base.add(const Duration(minutes: 1))));
        await pumpEventQueue();

        expect(visibleIds(bloc).first, 'new');
        expect(bloc.state.notes, hasLength(count + 1));
        expectInSync(bloc, repo);
      });

      test('an edited older note moves to the top', () async {
        final old = 'n${count - 1}';
        repo.save(note(old, base.add(const Duration(minutes: 1))));
        await pumpEventQueue();

        expect(visibleIds(bloc).first, old);
        expectInSync(bloc, repo);
      });

      test('DeleteNotes removes only the deleted notes', () async {
        bloc.add(DeleteNotes(noteIds: ['n1', 'n2', 'n3']));
        await pumpEventQueue();

        expect(bloc.state.notes, hasLength(count - 3));
        expect(visibleIds(bloc), isNot(contains('n2')));
        expectInSync(bloc, repo);
      });

      test('pinning and unpinning an older note updates the list', () async {
        final old = 'n${count - 1}';
        bloc.add(TogglePinNote(noteId: old));
        await pumpEventQueue();
        expect(visibleIds(bloc).first, old);
        expect(categories(bloc).first, TimeCategory.pinned);

        // Unpinned elsewhere (e.g. from the editor) without editing it
        await repo.togglePinNote(old);
        await pumpEventQueue();
        expect(categories(bloc), isNot(contains(TimeCategory.pinned)));
        expect(visibleIds(bloc).last, old);
        expectInSync(bloc, repo);
      });

      test('a burst of changes ends in a consistent list', () async {
        for (var i = 0; i < 5; i++) {
          repo.save(note('burst$i', base.add(Duration(minutes: i + 1))));
        }
        repo.remove('n0');
        repo.save(note('n5', base.add(const Duration(minutes: 10))));
        await repo.togglePinNote('n${count - 1}');
        await pumpEventQueue();

        expect(
          visibleIds(bloc).toSet(),
          hasLength(visibleIds(bloc).length),
          reason: 'no duplicates',
        );
        expectInSync(bloc, repo);
      });
    });
  }

  group('DeleteNotes', () {
    setUp(() async {
      repo = FakeNoteRepository(notesSpacedBy3h(5));
      bloc = buildBloc(repo);
      await pumpEventQueue();
    });

    test('deletes the selected notes when no ids are given', () async {
      bloc
        ..add(ToggleNoteSelection(noteId: 'n0'))
        ..add(ToggleNoteSelection(noteId: 'n1'))
        ..add(DeleteNotes());
      await pumpEventQueue();

      expect(repo.deletedBatches, [
        ['n0', 'n1'],
      ]);
      expect(bloc.state.selectedNotes, isEmpty);
      expect(bloc.state.isSelectionMode, isFalse);
      expectInSync(bloc, repo);
    });

    test('explicit ids win over the current selection', () async {
      bloc
        ..add(ToggleNoteSelection(noteId: 'n0'))
        ..add(DeleteNotes(noteIds: ['n4']));
      await pumpEventQueue();

      expect(repo.deletedBatches, [
        ['n4'],
      ]);
    });

    test('does nothing when there is nothing to delete', () async {
      bloc.add(DeleteNotes());
      await pumpEventQueue();

      expect(repo.deletedBatches, isEmpty);
    });

    test('reports failedToDeleteNotes when the repository throws', () async {
      repo.deleteError = Exception('disk');
      bloc.add(DeleteNotes(noteIds: ['n0']));
      await pumpEventQueue();

      expect(bloc.state.error, ErrorCategory.failedToDeleteNotes);
    });
  });

  group('selection', () {
    setUp(() async {
      repo = FakeNoteRepository(notesSpacedBy3h(30));
      bloc = buildBloc(repo);
      await pumpEventQueue();
    });

    test('ToggleSelectionMode toggles and clears the selection', () async {
      bloc
        ..add(ToggleNoteSelection(noteId: 'n0'))
        ..add(ToggleSelectionMode());
      await pumpEventQueue();

      expect(bloc.state.isSelectionMode, isFalse);
      expect(bloc.state.selectedNotes, isEmpty);
    });

    test(
      'ToggleNoteSelection adds, removes and enters selection mode',
      () async {
        bloc.add(ToggleNoteSelection(noteId: 'n0'));
        await pumpEventQueue();
        expect(bloc.state.selectedNotes, ['n0']);
        expect(bloc.state.isSelectionMode, isTrue);

        bloc.add(ToggleNoteSelection(noteId: 'n0'));
        await pumpEventQueue();
        expect(bloc.state.selectedNotes, isEmpty);
      },
    );

    test('SelectAllNotes selects every note, then toggles off', () async {
      bloc.add(SelectAllNotes());
      await pumpEventQueue();
      expect(bloc.state.selectedNotes, hasLength(30));

      bloc.add(SelectAllNotes());
      await pumpEventQueue();
      expect(bloc.state.selectedNotes, isEmpty);
      expect(bloc.state.isSelectionMode, isFalse);
    });

    test('ClearSelection resets selection', () async {
      bloc
        ..add(ToggleNoteSelection(noteId: 'n0'))
        ..add(ClearSelection());
      await pumpEventQueue();

      expect(bloc.state.selectedNotes, isEmpty);
      expect(bloc.state.isSelectionMode, isFalse);
    });

    test('a note deleted elsewhere drops out of the selection', () async {
      bloc
        ..add(ToggleNoteSelection(noteId: 'n0'))
        ..add(ToggleNoteSelection(noteId: 'n1'));
      await pumpEventQueue();

      repo.remove('n0');
      await pumpEventQueue();

      expect(bloc.state.selectedNotes, ['n1']);
    });
  });

  group('NotesState', () {
    test('defaults to loading with no notes', () {
      const state = NotesState();
      expect(state.isLoading, isTrue);
      expect(state.notes, isEmpty);
      expect(state.localized, 'en');
    });

    test('copyWith keeps unspecified fields and clears error', () {
      const state = NotesState(
        isLoading: false,
        error: ErrorCategory.failedToLoadNotes,
        selectedNotes: ['a'],
      );
      final copy = state.copyWith(isSelectionMode: true);

      expect(copy.isLoading, isFalse);
      expect(copy.selectedNotes, ['a']);
      expect(copy.isSelectionMode, isTrue);
      expect(copy.error, isNull);
    });

    test('states with equal values are equal', () {
      expect(const NotesState(), const NotesState());
      expect(const NotesState(), isNot(const NotesState(isLoading: false)));
    });
  });
}
