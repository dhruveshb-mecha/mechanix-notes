import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:mechanix_notes/core/utils/enums.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_bloc.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_state.dart';
import 'package:mechanix_notes/features/notes/data/models/note_metadata.dart';
import 'package:mechanix_notes/features/notes/data/models/time_group.dart';
import 'package:mechanix_notes/features/notes/data/repository/note_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockNoteRepository extends Mock implements NoteRepository {}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en', null);
  });

  group('NotesBloc Boundary Clock & Time Grouping Tests', () {
    late MockNoteRepository repository;

    setUp(() {
      repository = MockNoteRepository();
    });

    NoteMetaData createNote({
      required String id,
      required DateTime updatedAt,
      bool isPinned = false,
    }) {
      return NoteMetaData(
        id: id,
        title: 'Note $id',
        previewText: 'Preview $id',
        updatedAt: updatedAt,
        createdAt: updatedAt,
        height: 200,
        isPinned: isPinned,
      );
    }

    test(
      'pinned note is placed in Pinned group regardless of clock time',
      () async {
        final fakeNow = DateTime(2026, 10, 1, 12, 0, 0);
        final note = createNote(
          id: 'pin-1',
          updatedAt: DateTime(2025, 1, 1),
          isPinned: true,
        );

        when(
          () => repository.getNotes(any(), any()),
        ).thenAnswer((_) async => [note]);

        final bloc = NotesBloc(
          noteRepository: repository,
          clock: () => fakeNow,
        );

        await expectLater(
          bloc.stream,
          emitsInOrder([
            isA<NotesState>().having((s) => s.isLoading, 'isLoading', true),
            isA<NotesState>().having(
              (s) => s.groupedNotes,
              'groupedNotes',
              containsAllInOrder([const TimeGroup(TimeCategory.pinned), note]),
            ),
          ]),
        );
      },
    );

    test(
      'recent: note updated < 2 hours ago is placed in Recent group',
      () async {
        final fakeNow = DateTime(2026, 10, 1, 12, 0, 0);
        final note1 = createNote(
          id: 'rec-1',
          updatedAt: DateTime(2026, 10, 1, 10, 30, 0), // 1.5 hours ago
        );

        when(
          () => repository.getNotes(any(), any()),
        ).thenAnswer((_) async => [note1]);

        final bloc = NotesBloc(
          noteRepository: repository,
          clock: () => fakeNow,
        );

        await expectLater(
          bloc.stream,
          emitsInOrder([
            isA<NotesState>().having((s) => s.isLoading, 'isLoading', true),
            isA<NotesState>().having(
              (s) => s.groupedNotes,
              'groupedNotes',
              containsAllInOrder([const TimeGroup(TimeCategory.recent), note1]),
            ),
          ]),
        );
      },
    );

    test('midnight crossing within 2 hours falls into Recent group', () async {
      // Clock is 00:30 on Oct 2, note was written at 23:30 on Oct 1 (1 hour ago)
      final fakeNow = DateTime(2026, 10, 2, 0, 30, 0);
      final note = createNote(
        id: 'midnight-recent',
        updatedAt: DateTime(2026, 10, 1, 23, 30, 0),
      );

      when(
        () => repository.getNotes(any(), any()),
      ).thenAnswer((_) async => [note]);

      final bloc = NotesBloc(noteRepository: repository, clock: () => fakeNow);

      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<NotesState>().having((s) => s.isLoading, 'isLoading', true),
          isA<NotesState>().having(
            (s) => s.groupedNotes,
            'groupedNotes',
            containsAllInOrder([const TimeGroup(TimeCategory.recent), note]),
          ),
        ]),
      );
    });

    test(
      'today: note updated same calendar day but >= 2 hours ago falls into Today group',
      () async {
        final fakeNow = DateTime(2026, 10, 1, 18, 0, 0);
        final note = createNote(
          id: 'today-note',
          updatedAt: DateTime(2026, 10, 1, 10, 0, 0), // 8 hours ago today
        );

        when(
          () => repository.getNotes(any(), any()),
        ).thenAnswer((_) async => [note]);

        final bloc = NotesBloc(
          noteRepository: repository,
          clock: () => fakeNow,
        );

        await expectLater(
          bloc.stream,
          emitsInOrder([
            isA<NotesState>().having((s) => s.isLoading, 'isLoading', true),
            isA<NotesState>().having(
              (s) => s.groupedNotes,
              'groupedNotes',
              containsAllInOrder([const TimeGroup(TimeCategory.today), note]),
            ),
          ]),
        );
      },
    );

    test(
      'week boundary: daysAgo = 7 is last7Days, daysAgo = 8 is lastMonth',
      () async {
        final fakeNow = DateTime(2026, 10, 15, 12, 0, 0);
        // exactly 7 days ago (Oct 8)
        final note7Days = createNote(
          id: 'note-7-days',
          updatedAt: DateTime(2026, 10, 8, 12, 0, 0),
        );
        // 8 days ago (Oct 7)
        final note8Days = createNote(
          id: 'note-8-days',
          updatedAt: DateTime(2026, 10, 7, 12, 0, 0),
        );

        when(
          () => repository.getNotes(any(), any()),
        ).thenAnswer((_) async => [note7Days, note8Days]);

        final bloc = NotesBloc(
          noteRepository: repository,
          clock: () => fakeNow,
        );

        await expectLater(
          bloc.stream,
          emitsInOrder([
            isA<NotesState>().having((s) => s.isLoading, 'isLoading', true),
            isA<NotesState>().having(
              (s) => s.groupedNotes,
              'groupedNotes',
              containsAllInOrder([
                const TimeGroup(TimeCategory.last7Days),
                note7Days,
                const TimeGroup(TimeCategory.lastMonth),
                note8Days,
              ]),
            ),
          ]),
        );
      },
    );

    test(
      'month boundary: daysAgo = 30 is lastMonth, daysAgo = 31 is custom',
      () async {
        final fakeNow = DateTime(2026, 10, 31, 12, 0, 0);
        // exactly 30 days ago (Oct 1)
        final note30Days = createNote(
          id: 'note-30-days',
          updatedAt: DateTime(2026, 10, 1, 12, 0, 0),
        );
        // 31 days ago (Sept 30)
        final note31Days = createNote(
          id: 'note-31-days',
          updatedAt: DateTime(2026, 9, 30, 12, 0, 0),
        );

        when(
          () => repository.getNotes(any(), any()),
        ).thenAnswer((_) async => [note30Days, note31Days]);

        final bloc = NotesBloc(
          noteRepository: repository,
          clock: () => fakeNow,
        );

        final expectedCustomLabel = DateFormat(
          "MMMM yyyy",
          "en",
        ).format(DateTime(2026, 9, 30));

        await expectLater(
          bloc.stream,
          emitsInOrder([
            isA<NotesState>().having((s) => s.isLoading, 'isLoading', true),
            isA<NotesState>().having(
              (s) => s.groupedNotes,
              'groupedNotes',
              containsAllInOrder([
                const TimeGroup(TimeCategory.lastMonth),
                note30Days,
                TimeGroup(TimeCategory.custom, expectedCustomLabel),
                note31Days,
              ]),
            ),
          ]),
        );
      },
    );

    test(
      'year transition: note from Dec 31 2025 viewed on Jan 1 2026 > 2 hours ago is last7Days',
      () async {
        final fakeNow = DateTime(2026, 1, 1, 12, 0, 0);
        final noteDec31 = createNote(
          id: 'note-dec31',
          updatedAt: DateTime(2025, 12, 31, 10, 0, 0), // 26 hours ago
        );

        when(
          () => repository.getNotes(any(), any()),
        ).thenAnswer((_) async => [noteDec31]);

        final bloc = NotesBloc(
          noteRepository: repository,
          clock: () => fakeNow,
        );

        await expectLater(
          bloc.stream,
          emitsInOrder([
            isA<NotesState>().having((s) => s.isLoading, 'isLoading', true),
            isA<NotesState>().having(
              (s) => s.groupedNotes,
              'groupedNotes',
              containsAllInOrder([
                const TimeGroup(TimeCategory.last7Days),
                noteDec31,
              ]),
            ),
          ]),
        );
      },
    );
  });
}
