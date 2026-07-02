import 'dart:convert';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_quill/flutter_quill.dart' show Document;
import 'package:mechanix_notes/core/utils/enums.dart';
import 'package:mechanix_notes/features/notes/bloc/editor/editor_bloc.dart';
import 'package:mechanix_notes/features/notes/data/models/note_model.dart';
import 'package:mechanix_notes/features/notes/data/repository/note_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:objectbox/objectbox.dart';

// ─── Mocks ────────────────────────────────────────────────────────────────────

class MockNoteRepository extends Mock implements NoteRepository {}

class FakeNoteModel extends Fake implements NoteModel {}

// ─── Helpers ─────────────────────────────────────────────────────────────────

const kTestNoteId = 'test-note-id-123';
const kTestTitle = 'Test Note Title';
const kEmptyDelta = '[{"insert":"\\n"}]';
const kSomeDelta = '[{"insert":"Hello World\\n"}]';
const kSomePlainText = 'Hello World\n';

NoteModel makeNote({
  String id = kTestNoteId,
  String title = kTestTitle,
  String content = kSomeDelta,
  String plainText = kSomePlainText,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final now = DateTime(2024, 1, 1);
  final previewText = plainText.length > 40
      ? plainText.trim().substring(0, 40)
      : plainText.trim();
  return NoteModel(
    id: id,
    title: title,
    content: content,
    plainText: plainText,
    previewText: previewText,
    height: 104.0,
    createdAt: createdAt ?? now,
    updatedAt: updatedAt ?? now,
  );
}

// ─── Main ─────────────────────────────────────────────────────────────────────

void main() {
  late MockNoteRepository repository;

  setUpAll(() {
    registerFallbackValue(FakeNoteModel());
  });

  setUp(() {
    repository = MockNoteRepository();
  });

  EditorBloc buildBloc() => EditorBloc(repository);

  // ════════════════════════════════════════════════════════════════════════════
  // Initial state
  // ════════════════════════════════════════════════════════════════════════════

  group('Initial state', () {
    test('is EditorInitial', () {
      expect(buildBloc().state, isA<EditorInitial>());
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // EditorInitialised — CREATE mode (no noteId)
  // ════════════════════════════════════════════════════════════════════════════

  group('EditorInitialised — create mode', () {
    blocTest<EditorBloc, EditorState>(
      'emits EditorLoaded with empty title, blank document, isNewNote=true',
      build: buildBloc,
      act: (bloc) => bloc.add(EditorInitialised()),
      expect: () => [
        isA<EditorLoaded>()
            .having((s) => s.title, 'title', '')
            .having((s) => s.isNewNote, 'isNewNote', true)
            .having((s) => s.isContentLoading, 'isContentLoading', false)
            .having((s) => s.quillDocument, 'quillDocument', isNotNull),
      ],
      verify: (_) => verifyNever(() => repository.getNoteById(any())),
    );

    blocTest<EditorBloc, EditorState>(
      'generated noteId is a valid non-empty UUID v4',
      build: buildBloc,
      act: (bloc) => bloc.add(EditorInitialised()),
      verify: (bloc) {
        final loaded = bloc.state as EditorLoaded;
        expect(loaded.noteId, isNotEmpty);
        final uuidRegex = RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          caseSensitive: false,
        );
        expect(uuidRegex.hasMatch(loaded.noteId), isTrue);
      },
    );

    blocTest<EditorBloc, EditorState>(
      'isDirty defaults to false in create mode',
      build: buildBloc,
      act: (bloc) => bloc.add(EditorInitialised()),
      verify: (bloc) {
        expect((bloc.state as EditorLoaded).isDirty, false);
      },
    );

    blocTest<EditorBloc, EditorState>(
      'activeToolbar defaults to none in create mode',
      build: buildBloc,
      act: (bloc) => bloc.add(EditorInitialised()),
      verify: (bloc) {
        expect((bloc.state as EditorLoaded).activeToolbar, EditorToolbar.none);
      },
    );
  });

  // ════════════════════════════════════════════════════════════════════════════
  // EditorInitialised — EDIT mode (noteId provided)
  // ════════════════════════════════════════════════════════════════════════════

  group('EditorInitialised — edit mode', () {
    blocTest<EditorBloc, EditorState>(
      'emits loading shell then EditorLoaded with note data',
      build: buildBloc,
      setUp: () {
        when(
          () => repository.getNoteById(kTestNoteId),
        ).thenAnswer((_) async => makeNote());
      },
      act: (bloc) => bloc.add(
        EditorInitialised(noteId: kTestNoteId, noteTitle: kTestTitle),
      ),
      wait: const Duration(milliseconds: 300),
      expect: () => [
        isA<EditorLoaded>()
            .having((s) => s.noteId, 'noteId', kTestNoteId)
            .having((s) => s.isContentLoading, 'isContentLoading', true)
            .having((s) => s.isNewNote, 'isNewNote', false),
        isA<EditorLoaded>()
            .having((s) => s.noteId, 'noteId', kTestNoteId)
            .having((s) => s.title, 'title', kTestTitle)
            .having((s) => s.isContentLoading, 'isContentLoading', false)
            .having((s) => s.quillDocument, 'quillDocument', isNotNull)
            .having((s) => s.isNewNote, 'isNewNote', false),
      ],
    );

    blocTest<EditorBloc, EditorState>(
      'uses noteTitle override instead of note.title when provided',
      build: buildBloc,
      setUp: () {
        when(
          () => repository.getNoteById(kTestNoteId),
        ).thenAnswer((_) async => makeNote(title: 'DB Title'));
      },
      act: (bloc) => bloc.add(
        EditorInitialised(noteId: kTestNoteId, noteTitle: 'Override Title'),
      ),
      wait: const Duration(milliseconds: 300),
      verify: (bloc) {
        final loaded = bloc.state as EditorLoaded;
        expect(loaded.title, 'Override Title');
      },
    );

    blocTest<EditorBloc, EditorState>(
      'falls back to note.title when noteTitle override is null',
      build: buildBloc,
      setUp: () {
        when(
          () => repository.getNoteById(kTestNoteId),
        ).thenAnswer((_) async => makeNote(title: 'DB Title'));
      },
      act: (bloc) => bloc.add(EditorInitialised(noteId: kTestNoteId)),
      wait: const Duration(milliseconds: 300),
      verify: (bloc) {
        final loaded = bloc.state as EditorLoaded;
        expect(loaded.title, 'DB Title');
      },
    );

    blocTest<EditorBloc, EditorState>(
      'emits EditorFailure with noteNotFound category when note is not found',
      build: buildBloc,
      setUp: () {
        when(
          () => repository.getNoteById(kTestNoteId),
        ).thenAnswer((_) async => null);
      },
      act: (bloc) => bloc.add(EditorInitialised(noteId: kTestNoteId)),
      // FIX: EditorFailure.error is an ErrorCategory, not a String message.
      // The first emit is the loading shell, second is the failure.
      expect: () => [
        isA<EditorLoaded>().having((s) => s.isContentLoading, 'loading', true),
        isA<EditorFailure>().having(
          (s) => s.error,
          'error',
          ErrorCategory.noteNotFound,
        ),
      ],
    );

    blocTest<EditorBloc, EditorState>(
      'emits EditorFailure with somethingWentWrong when getNoteMetaData throws',
      build: buildBloc,
      setUp: () {
        when(
          () => repository.getNoteById(kTestNoteId),
        ).thenThrow(Exception('DB crash'));
      },
      act: (bloc) => bloc.add(EditorInitialised(noteId: kTestNoteId)),
      expect: () => [
        isA<EditorLoaded>().having((s) => s.isContentLoading, 'loading', true),
        isA<EditorFailure>().having(
          (s) => s.error,
          'error',
          ErrorCategory.somethingWentWrong,
        ),
      ],
    );

    blocTest<EditorBloc, EditorState>(
      'handles malformed content JSON gracefully (falls back to empty doc)',
      build: buildBloc,
      setUp: () {
        when(
          () => repository.getNoteById(kTestNoteId),
        ).thenAnswer((_) async => makeNote(content: 'NOT_VALID_JSON'));
      },
      act: (bloc) => bloc.add(EditorInitialised(noteId: kTestNoteId)),
      wait: const Duration(milliseconds: 300),
      verify: (bloc) {
        expect(bloc.state, isA<EditorLoaded>());
        final loaded = bloc.state as EditorLoaded;
        expect(loaded.quillDocument, isNotNull);
      },
    );

    blocTest<EditorBloc, EditorState>(
      'handles non-List JSON content gracefully (falls back to empty doc)',
      build: buildBloc,
      setUp: () {
        when(
          () => repository.getNoteById(kTestNoteId),
        ).thenAnswer((_) async => makeNote(content: '{"key":"value"}'));
      },
      act: (bloc) => bloc.add(
        EditorInitialised(noteId: kTestNoteId, noteTitle: kTestTitle),
      ),
      wait: const Duration(milliseconds: 300),
      verify: (bloc) {
        expect(bloc.state, isA<EditorLoaded>());
        final loaded = bloc.state as EditorLoaded;
        expect(loaded.quillDocument, isNotNull);
        expect(loaded.isContentLoading, false);
      },
    );

    blocTest<EditorBloc, EditorState>(
      'getNoteMetaData is only called once per initialise in edit mode',
      build: buildBloc,
      setUp: () {
        when(
          () => repository.getNoteById(kTestNoteId),
        ).thenAnswer((_) async => makeNote());
      },
      act: (bloc) => bloc.add(EditorInitialised(noteId: kTestNoteId)),
      wait: const Duration(milliseconds: 300),
      verify: (_) =>
          verify(() => repository.getNoteById(kTestNoteId)).called(1),
    );
  });

  // ════════════════════════════════════════════════════════════════════════════
  // EditorTitleChanged
  // ════════════════════════════════════════════════════════════════════════════

  group('EditorTitleChanged', () {
    blocTest<EditorBloc, EditorState>(
      'updates title in EditorLoaded',
      build: buildBloc,
      seed: () => EditorLoaded(
        noteId: kTestNoteId,
        title: '',
        quillDocument: Document(),
        isNewNote: true,
      ),
      act: (bloc) => bloc.add(EditorTitleChanged('New Title')),
      expect: () => [
        isA<EditorLoaded>().having((s) => s.title, 'title', 'New Title'),
      ],
    );

    blocTest<EditorBloc, EditorState>(
      'is a no-op when state is not EditorLoaded',
      build: buildBloc,
      act: (bloc) => bloc.add(EditorTitleChanged('Ignored')),
      expect: () => [],
    );

    blocTest<EditorBloc, EditorState>(
      'handles empty string title',
      build: buildBloc,
      seed: () => EditorLoaded(
        noteId: kTestNoteId,
        title: 'Some Title',
        quillDocument: Document(),
        isNewNote: false,
      ),
      act: (bloc) => bloc.add(EditorTitleChanged('')),
      expect: () => [isA<EditorLoaded>().having((s) => s.title, 'title', '')],
    );

    blocTest<EditorBloc, EditorState>(
      'does not reset other fields when title changes',
      build: buildBloc,
      seed: () => EditorLoaded(
        noteId: kTestNoteId,
        title: 'Old',
        quillDocument: Document(),
        isNewNote: false,
        activeToolbar: EditorToolbar.textStyle,
      ),
      act: (bloc) => bloc.add(EditorTitleChanged('New')),
      verify: (bloc) {
        final s = bloc.state as EditorLoaded;
        expect(s.activeToolbar, EditorToolbar.textStyle);
        expect(s.isNewNote, false);
        expect(s.noteId, kTestNoteId);
      },
    );

    blocTest<EditorBloc, EditorState>(
      'multiple title changes only keeps last value',
      build: buildBloc,
      seed: () =>
          const EditorLoaded(noteId: kTestNoteId, title: '', isNewNote: true),
      act: (bloc) {
        bloc.add(EditorTitleChanged('A'));
        bloc.add(EditorTitleChanged('AB'));
        bloc.add(EditorTitleChanged('ABC'));
      },
      verify: (bloc) {
        expect((bloc.state as EditorLoaded).title, 'ABC');
      },
    );
  });

  // ════════════════════════════════════════════════════════════════════════════
  // EditorToolbarToggled
  // ════════════════════════════════════════════════════════════════════════════

  group('EditorToolbarToggled', () {
    blocTest<EditorBloc, EditorState>(
      'activates a toolbar when none is active',
      build: buildBloc,
      seed: () => const EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        activeToolbar: EditorToolbar.none,
        isNewNote: false,
      ),
      act: (bloc) => bloc.add(EditorToolbarToggled(EditorToolbar.textStyle)),
      expect: () => [
        isA<EditorLoaded>().having(
          (s) => s.activeToolbar,
          'toolbar',
          EditorToolbar.textStyle,
        ),
      ],
    );

    blocTest<EditorBloc, EditorState>(
      'closes toolbar when same toolbar toggled again',
      build: buildBloc,
      seed: () => const EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        activeToolbar: EditorToolbar.textStyle,
        isNewNote: false,
      ),
      act: (bloc) => bloc.add(EditorToolbarToggled(EditorToolbar.textStyle)),
      expect: () => [
        isA<EditorLoaded>().having(
          (s) => s.activeToolbar,
          'toolbar',
          EditorToolbar.none,
        ),
      ],
    );

    blocTest<EditorBloc, EditorState>(
      'switches from one toolbar to another',
      build: buildBloc,
      seed: () => const EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        activeToolbar: EditorToolbar.textStyle,
        isNewNote: false,
      ),
      act: (bloc) => bloc.add(EditorToolbarToggled(EditorToolbar.menu)),
      expect: () => [
        isA<EditorLoaded>().having(
          (s) => s.activeToolbar,
          'toolbar',
          EditorToolbar.menu,
        ),
      ],
    );

    for (final toolbar in EditorToolbar.values.where(
      (t) => t != EditorToolbar.none,
    )) {
      blocTest<EditorBloc, EditorState>(
        'can activate toolbar: $toolbar',
        build: buildBloc,
        seed: () => const EditorLoaded(
          noteId: kTestNoteId,
          title: kTestTitle,
          activeToolbar: EditorToolbar.none,
          isNewNote: false,
        ),
        act: (bloc) => bloc.add(EditorToolbarToggled(toolbar)),
        verify: (bloc) {
          expect((bloc.state as EditorLoaded).activeToolbar, toolbar);
        },
      );
    }

    blocTest<EditorBloc, EditorState>(
      'is a no-op when state is not EditorLoaded',
      build: buildBloc,
      act: (bloc) => bloc.add(EditorToolbarToggled(EditorToolbar.menu)),
      expect: () => [],
    );

    blocTest<EditorBloc, EditorState>(
      'toggling none toolbar when already none keeps it none',
      build: buildBloc,
      seed: () => const EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        activeToolbar: EditorToolbar.none,
        isNewNote: false,
      ),
      act: (bloc) => bloc.add(EditorToolbarToggled(EditorToolbar.none)),
      expect: () => <EditorState>[],
    );
  });

  // ════════════════════════════════════════════════════════════════════════════
  // EditorSaveRequested — new note
  // ════════════════════════════════════════════════════════════════════════════

  group('EditorSaveRequested — new note', () {
    blocTest<EditorBloc, EditorState>(
      'discards a new note that has empty title and empty body',
      build: buildBloc,
      setUp: () {
        when(() => repository.getNoteById(any())).thenAnswer((_) async => null);
      },
      seed: () => EditorLoaded(
        noteId: kTestNoteId,
        title: '',
        quillDocument: Document(),
        isNewNote: true,
      ),
      act: (bloc) => bloc.add(
        EditorSaveRequested(content: jsonDecode(kEmptyDelta), plainText: '   '),
      ),
      expect: () => [isA<EditorDiscarded>()],
      verify: (_) => verifyNever(() => repository.upsertNote(any())),
    );

    blocTest<EditorBloc, EditorState>(
      // FIX: The discarded state for new/empty has noteId=null per EditorDiscarded()
      'EditorDiscarded for empty new note has null noteId',
      build: buildBloc,
      setUp: () {
        when(() => repository.getNoteById(any())).thenAnswer((_) async => null);
      },
      seed: () => EditorLoaded(
        noteId: kTestNoteId,
        title: '',
        quillDocument: Document(),
        isNewNote: true,
      ),
      act: (bloc) => bloc.add(
        EditorSaveRequested(content: jsonDecode(kEmptyDelta), plainText: ''),
      ),
      verify: (bloc) {
        final s = bloc.state as EditorDiscarded;
        expect(s.noteId, isNull);
      },
    );

    blocTest<EditorBloc, EditorState>(
      'saves new note when title is non-empty even if body is blank',
      build: buildBloc,
      setUp: () {
        when(() => repository.getNoteById(any())).thenAnswer((_) async => null);
        when(() => repository.upsertNote(any())).thenAnswer((_) async {});
      },
      seed: () => EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        quillDocument: Document(),
        isNewNote: true,
      ),
      act: (bloc) => bloc.add(
        EditorSaveRequested(content: jsonDecode(kEmptyDelta), plainText: ''),
      ),
      expect: () => [
        isA<EditorLoaded>().having((s) => s.isSaving, 'isSaving', true),
        isA<EditorSaveSuccess>().having((s) => s.noteId, 'noteId', kTestNoteId),
      ],
      verify: (_) => verify(() => repository.upsertNote(any())).called(1),
    );

    blocTest<EditorBloc, EditorState>(
      'saves new note when body is non-empty even if title is blank',
      build: buildBloc,
      setUp: () {
        when(() => repository.getNoteById(any())).thenAnswer((_) async => null);
        when(() => repository.upsertNote(any())).thenAnswer((_) async {});
      },
      seed: () => EditorLoaded(
        noteId: kTestNoteId,
        title: '',
        quillDocument: Document(),
        isNewNote: true,
      ),
      act: (bloc) => bloc.add(
        EditorSaveRequested(
          content: jsonDecode(kSomeDelta),
          plainText: kSomePlainText,
        ),
      ),
      expect: () => [
        isA<EditorLoaded>().having((s) => s.isSaving, 'isSaving', true),
        isA<EditorSaveSuccess>(),
      ],
    );

    blocTest<EditorBloc, EditorState>(
      'calls upsertNote (not upsertNote) for a brand-new note',
      build: buildBloc,
      setUp: () {
        when(() => repository.getNoteById(any())).thenAnswer((_) async => null);
        when(() => repository.upsertNote(any())).thenAnswer((_) async {});
      },
      seed: () => EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        quillDocument: Document(),
        isNewNote: true,
      ),
      act: (bloc) => bloc.add(
        EditorSaveRequested(
          content: jsonDecode(kSomeDelta),
          plainText: kSomePlainText,
        ),
      ),
      verify: (_) {
        verify(() => repository.upsertNote(any())).called(1);
        verifyNever(() => repository.upsertNote(any()));
      },
    );

    blocTest<EditorBloc, EditorState>(
      'previewText is truncated to 40 chars for text longer than 40 chars',
      build: buildBloc,
      setUp: () {
        when(() => repository.getNoteById(any())).thenAnswer((_) async => null);
        when(
          () => repository.upsertNote(captureAny()),
        ).thenAnswer((_) async {});
      },
      seed: () => EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        quillDocument: Document(),
        isNewNote: true,
      ),
      act: (bloc) {
        final longText = 'A' * 200;
        bloc.add(
          EditorSaveRequested(
            content: jsonDecode(kSomeDelta),
            plainText: longText,
          ),
        );
      },
      verify: (_) {
        final captured = verify(
          () => repository.upsertNote(captureAny()),
        ).captured;
        final note = captured.first as NoteModel;
        expect(note.previewText.length, 40);
        expect(note.previewText, 'A' * 40);
      },
    );

    blocTest<EditorBloc, EditorState>(
      'does NOT truncate previewText when plainText is exactly 40 chars',
      build: buildBloc,
      setUp: () {
        when(() => repository.getNoteById(any())).thenAnswer((_) async => null);
        when(
          () => repository.upsertNote(captureAny()),
        ).thenAnswer((_) async {});
      },
      seed: () => EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        quillDocument: Document(),
        isNewNote: true,
      ),
      act: (bloc) {
        final exactText = 'A' * 40;
        bloc.add(
          EditorSaveRequested(
            content: jsonDecode(kSomeDelta),
            plainText: exactText,
          ),
        );
      },
      verify: (_) {
        final captured = verify(
          () => repository.upsertNote(captureAny()),
        ).captured;
        final note = captured.first as NoteModel;
        // length == 40, condition is > 40 so no truncation
        expect(note.previewText.length, 40);
        expect(note.previewText, 'A' * 40);
      },
    );

    blocTest<EditorBloc, EditorState>(
      'truncates previewText to 40 chars when plainText is 41 chars',
      build: buildBloc,
      setUp: () {
        when(() => repository.getNoteById(any())).thenAnswer((_) async => null);
        when(
          () => repository.upsertNote(captureAny()),
        ).thenAnswer((_) async {});
      },
      seed: () => EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        quillDocument: Document(),
        isNewNote: true,
      ),
      act: (bloc) {
        final justOver = 'A' * 41;
        bloc.add(
          EditorSaveRequested(
            content: jsonDecode(kSomeDelta),
            plainText: justOver,
          ),
        );
      },
      verify: (_) {
        final captured = verify(
          () => repository.upsertNote(captureAny()),
        ).captured;
        final note = captured.first as NoteModel;
        expect(note.previewText.length, 40);
        expect(note.previewText, 'A' * 40);
      },
    );

    blocTest<EditorBloc, EditorState>(
      // FIX: EditorFailure holds ErrorCategory, not a message string.
      'emits EditorFailure(failedToSaveNote) when upsertNote throws',
      build: buildBloc,
      setUp: () {
        when(() => repository.getNoteById(any())).thenAnswer((_) async => null);
        when(
          () => repository.upsertNote(any()),
        ).thenThrow(Exception('DB error'));
      },
      seed: () => EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        quillDocument: Document(),
        isNewNote: true,
      ),
      act: (bloc) => bloc.add(
        EditorSaveRequested(
          content: jsonDecode(kSomeDelta),
          plainText: kSomePlainText,
        ),
      ),
      expect: () => [
        isA<EditorLoaded>().having((s) => s.isSaving, 'isSaving', true),
        isA<EditorFailure>().having(
          (s) => s.error,
          'error',
          ErrorCategory.failedToSaveNote,
        ),
      ],
    );

    blocTest<EditorBloc, EditorState>(
      'emits EditorFailure(storageFull) when upsertNote throws DbFullException',
      build: buildBloc,
      setUp: () {
        when(() => repository.getNoteById(any())).thenAnswer((_) async => null);
        when(
          () => repository.upsertNote(any()),
        ).thenThrow(DbFullException('DB full', 1018));
      },
      seed: () => EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        quillDocument: Document(),
        isNewNote: true,
      ),
      act: (bloc) => bloc.add(
        EditorSaveRequested(
          content: jsonDecode(kSomeDelta),
          plainText: kSomePlainText,
        ),
      ),
      expect: () => [
        isA<EditorLoaded>().having((s) => s.isSaving, 'isSaving', true),
        isA<EditorFailure>().having(
          (s) => s.error,
          'error',
          ErrorCategory.storageFull,
        ),
      ],
    );

    blocTest<EditorBloc, EditorState>(
      // FIX: getNoteMetaData throws BEFORE isSaving is emitted — no loading state.
      'emits EditorFailure when getNoteMetaData throws during save (no isSaving emit)',
      build: buildBloc,
      setUp: () {
        when(
          () => repository.getNoteById(any()),
        ).thenThrow(Exception('DB connection lost'));
      },
      seed: () => EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        quillDocument: Document(),
        isNewNote: true,
      ),
      act: (bloc) => bloc.add(
        EditorSaveRequested(
          content: jsonDecode(kSomeDelta),
          plainText: kSomePlainText,
        ),
      ),
      expect: () => [
        isA<EditorFailure>().having(
          (s) => s.error,
          'error',
          ErrorCategory.failedToSaveNote,
        ),
      ],
      verify: (_) => verifyNever(() => repository.upsertNote(any())),
    );

    blocTest<EditorBloc, EditorState>(
      'height is correct for short single-line text (1 line → 104.0)',
      build: buildBloc,
      setUp: () {
        when(() => repository.getNoteById(any())).thenAnswer((_) async => null);
        when(
          () => repository.upsertNote(captureAny()),
        ).thenAnswer((_) async {});
      },
      seed: () => EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        quillDocument: Document(),
        isNewNote: true,
      ),
      act: (bloc) {
        // 5 chars → ceil(5/60) = 1 line → 1*24 + 80 = 104
        bloc.add(
          EditorSaveRequested(
            content: jsonDecode(kSomeDelta),
            plainText: 'Short',
          ),
        );
      },
      verify: (_) {
        final captured = verify(
          () => repository.upsertNote(captureAny()),
        ).captured;
        final note = captured.first as NoteModel;
        expect(note.height, 104.0);
      },
    );

    blocTest<EditorBloc, EditorState>(
      'height clamp lower bound: empty plainText → 1 line → 104.0',
      build: buildBloc,
      setUp: () {
        when(() => repository.getNoteById(any())).thenAnswer((_) async => null);
        when(
          () => repository.upsertNote(captureAny()),
        ).thenAnswer((_) async {});
      },
      seed: () => EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle, // non-empty title so note is not discarded
        quillDocument: Document(),
        isNewNote: true,
      ),
      act: (bloc) {
        // 0 chars → ceil(0/60)=0 → clamp(1,20)=1 → 1*24+80=104
        bloc.add(
          EditorSaveRequested(content: jsonDecode(kEmptyDelta), plainText: ''),
        );
      },
      verify: (_) {
        final captured = verify(
          () => repository.upsertNote(captureAny()),
        ).captured;
        final note = captured.first as NoteModel;
        expect(note.height, 104.0);
      },
    );

    blocTest<EditorBloc, EditorState>(
      'height steps at 60/61 char boundary (1 line → 104.0, 2 lines → 128.0)',
      build: buildBloc,
      setUp: () {
        when(() => repository.getNoteById(any())).thenAnswer((_) async => null);
        when(
          () => repository.upsertNote(captureAny()),
        ).thenAnswer((_) async {});
      },
      seed: () => EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        quillDocument: Document(),
        isNewNote: true,
      ),
      act: (bloc) {
        // 60 chars → ceil(60/60)=1 → 104; then 61 chars → ceil(61/60)=2 → 128
        bloc.add(
          EditorSaveRequested(
            content: jsonDecode(kSomeDelta),
            plainText: 'A' * 60,
          ),
        );
      },
      verify: (_) {
        final captured = verify(
          () => repository.upsertNote(captureAny()),
        ).captured;
        final note = captured.first as NoteModel;
        expect(note.height, 104.0); // exactly 1 line
      },
    );

    blocTest<EditorBloc, EditorState>(
      'NoteModel.id in saved note matches current.noteId',
      build: buildBloc,
      setUp: () {
        when(() => repository.getNoteById(any())).thenAnswer((_) async => null);
        when(
          () => repository.upsertNote(captureAny()),
        ).thenAnswer((_) async {});
      },
      seed: () => EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        quillDocument: Document(),
        isNewNote: true,
      ),
      act: (bloc) => bloc.add(
        EditorSaveRequested(
          content: jsonDecode(kSomeDelta),
          plainText: kSomePlainText,
        ),
      ),
      verify: (_) {
        final captured = verify(
          () => repository.upsertNote(captureAny()),
        ).captured;
        final note = captured.first as NoteModel;
        expect(note.id, kTestNoteId);
      },
    );

    blocTest<EditorBloc, EditorState>(
      'height steps to 2 lines at 61 chars (128.0)',
      build: buildBloc,
      setUp: () {
        when(() => repository.getNoteById(any())).thenAnswer((_) async => null);
        when(
          () => repository.upsertNote(captureAny()),
        ).thenAnswer((_) async {});
      },
      seed: () => EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        quillDocument: Document(),
        isNewNote: true,
      ),
      act: (bloc) {
        // 61 chars → ceil(61/60)=2 → 2*24+80=128
        bloc.add(
          EditorSaveRequested(
            content: jsonDecode(kSomeDelta),
            plainText: 'A' * 61,
          ),
        );
      },
      verify: (_) {
        final captured = verify(
          () => repository.upsertNote(captureAny()),
        ).captured;
        final note = captured.first as NoteModel;
        expect(note.height, 128.0);
      },
    );

    blocTest<EditorBloc, EditorState>(
      'height is clamped at 20 lines for very long text (560.0)',
      build: buildBloc,
      setUp: () {
        when(() => repository.getNoteById(any())).thenAnswer((_) async => null);
        when(
          () => repository.upsertNote(captureAny()),
        ).thenAnswer((_) async {});
      },
      seed: () => EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        quillDocument: Document(),
        isNewNote: true,
      ),
      act: (bloc) {
        // 60*21 = 1260 chars → ceil(1260/60) = 21 → clamped to 20 → 20*24+80=560
        final longText = 'A' * (60 * 21);
        bloc.add(
          EditorSaveRequested(
            content: jsonDecode(kSomeDelta),
            plainText: longText,
          ),
        );
      },
      verify: (_) {
        final captured = verify(
          () => repository.upsertNote(captureAny()),
        ).captured;
        final note = captured.first as NoteModel;
        expect(note.height, 560.0);
      },
    );

    blocTest<EditorBloc, EditorState>(
      'is a no-op when state is not EditorLoaded',
      build: buildBloc,
      act: (bloc) => bloc.add(
        EditorSaveRequested(
          content: jsonDecode(kSomeDelta),
          plainText: kSomePlainText,
        ),
      ),
      expect: () => [],
    );
  });

  // ════════════════════════════════════════════════════════════════════════════
  // EditorSaveRequested — existing note
  // ════════════════════════════════════════════════════════════════════════════

  group('EditorSaveRequested — existing note', () {
    blocTest<EditorBloc, EditorState>(
      'discards when nothing changed (isDirty=false → noteId is null in EditorDiscarded)',
      build: buildBloc,
      setUp: () {
        when(() => repository.getNoteById(kTestNoteId)).thenAnswer(
          (_) async => makeNote(title: kTestTitle, content: kSomeDelta),
        );
      },
      seed: () => EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        quillDocument: Document(),
        isNewNote: false,
        // isDirty defaults to false
      ),
      act: (bloc) => bloc.add(
        EditorSaveRequested(
          content: jsonDecode(kSomeDelta),
          plainText: kSomePlainText,
        ),
      ),
      // FIX: bloc emits EditorDiscarded(noteId: null) because isDirty is false
      expect: () => [
        isA<EditorDiscarded>().having((s) => s.noteId, 'noteId', isNull),
      ],
      verify: (_) {
        verifyNever(() => repository.upsertNote(any()));
        verifyNever(() => repository.upsertNote(any()));
      },
    );

    blocTest<EditorBloc, EditorState>(
      'discards with noteId when isDirty=true and content unchanged',
      build: buildBloc,
      setUp: () {
        when(() => repository.getNoteById(kTestNoteId)).thenAnswer(
          (_) async => makeNote(title: kTestTitle, content: kSomeDelta),
        );
      },
      seed: () => EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        quillDocument: Document(),
        isNewNote: false,
        isDirty: true, // was auto-saved previously
      ),
      act: (bloc) => bloc.add(
        EditorSaveRequested(
          content: jsonDecode(kSomeDelta),
          plainText: kSomePlainText,
        ),
      ),
      // FIX: bloc emits EditorDiscarded(noteId: current.noteId) when isDirty=true
      expect: () => [
        isA<EditorDiscarded>().having((s) => s.noteId, 'noteId', kTestNoteId),
      ],
    );

    blocTest<EditorBloc, EditorState>(
      'calls upsertNote when title changed',
      build: buildBloc,
      setUp: () {
        when(() => repository.getNoteById(kTestNoteId)).thenAnswer(
          (_) async => makeNote(title: 'Old Title', content: kSomeDelta),
        );
        when(() => repository.upsertNote(any())).thenAnswer((_) async {});
      },
      seed: () => EditorLoaded(
        noteId: kTestNoteId,
        title: 'New Title',
        quillDocument: Document(),
        isNewNote: false,
      ),
      act: (bloc) => bloc.add(
        EditorSaveRequested(
          content: jsonDecode(kSomeDelta),
          plainText: kSomePlainText,
        ),
      ),
      expect: () => [
        isA<EditorLoaded>().having((s) => s.isSaving, 'isSaving', true),
        isA<EditorSaveSuccess>(),
      ],
      verify: (_) {
        verify(() => repository.upsertNote(any())).called(1);
        verifyNever(() => repository.upsertNote(any()));
      },
    );

    blocTest<EditorBloc, EditorState>(
      'calls upsertNote when content changed',
      build: buildBloc,
      setUp: () {
        when(() => repository.getNoteById(kTestNoteId)).thenAnswer(
          (_) async => makeNote(title: kTestTitle, content: kEmptyDelta),
        );
        when(() => repository.upsertNote(any())).thenAnswer((_) async {});
      },
      seed: () => EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        quillDocument: Document(),
        isNewNote: false,
      ),
      act: (bloc) => bloc.add(
        EditorSaveRequested(
          content: jsonDecode(kSomeDelta),
          plainText: kSomePlainText,
        ),
      ),
      expect: () => [
        isA<EditorLoaded>().having((s) => s.isSaving, 'isSaving', true),
        isA<EditorSaveSuccess>(),
      ],
      verify: (_) => verify(() => repository.upsertNote(any())).called(1),
    );

    blocTest<EditorBloc, EditorState>(
      'preserves original createdAt when updating',
      build: buildBloc,
      setUp: () {
        final original = makeNote(createdAt: DateTime(2020, 6, 15));
        when(
          () => repository.getNoteById(kTestNoteId),
        ).thenAnswer((_) async => original);
        when(
          () => repository.upsertNote(captureAny()),
        ).thenAnswer((_) async {});
      },
      seed: () => EditorLoaded(
        noteId: kTestNoteId,
        title: 'Different Title',
        quillDocument: Document(),
        isNewNote: false,
      ),
      act: (bloc) => bloc.add(
        EditorSaveRequested(
          content: jsonDecode(kSomeDelta),
          plainText: kSomePlainText,
        ),
      ),
      verify: (_) {
        final captured = verify(
          () => repository.upsertNote(captureAny()),
        ).captured;
        final saved = captured.first as NoteModel;
        expect(saved.createdAt, DateTime(2020, 6, 15));
      },
    );

    blocTest<EditorBloc, EditorState>(
      'updatedAt is newer than createdAt after update',
      build: buildBloc,
      setUp: () {
        final original = makeNote(createdAt: DateTime(2020, 1, 1));
        when(
          () => repository.getNoteById(kTestNoteId),
        ).thenAnswer((_) async => original);
        when(
          () => repository.upsertNote(captureAny()),
        ).thenAnswer((_) async {});
      },
      seed: () => EditorLoaded(
        noteId: kTestNoteId,
        title: 'Updated',
        quillDocument: Document(),
        isNewNote: false,
      ),
      act: (bloc) => bloc.add(
        EditorSaveRequested(
          content: jsonDecode(kSomeDelta),
          plainText: kSomePlainText,
        ),
      ),
      verify: (_) {
        final captured = verify(
          () => repository.upsertNote(captureAny()),
        ).captured;
        final saved = captured.first as NoteModel;
        expect(saved.updatedAt.isAfter(saved.createdAt), isTrue);
      },
    );

    blocTest<EditorBloc, EditorState>(
      'emits EditorFailure(failedToSaveNote) when upsertNote throws',
      build: buildBloc,
      setUp: () {
        when(
          () => repository.getNoteById(kTestNoteId),
        ).thenAnswer((_) async => makeNote(title: 'Old', content: kEmptyDelta));
        when(
          () => repository.upsertNote(any()),
        ).thenThrow(Exception('Network error'));
      },
      seed: () => EditorLoaded(
        noteId: kTestNoteId,
        title: 'New',
        quillDocument: Document(),
        isNewNote: false,
      ),
      act: (bloc) => bloc.add(
        EditorSaveRequested(
          content: jsonDecode(kSomeDelta),
          plainText: kSomePlainText,
        ),
      ),
      expect: () => [
        isA<EditorLoaded>().having((s) => s.isSaving, 'isSaving', true),
        isA<EditorFailure>().having(
          (s) => s.error,
          'error',
          ErrorCategory.failedToSaveNote,
        ),
      ],
    );

    blocTest<EditorBloc, EditorState>(
      'emits EditorFailure when getNoteMetaData throws during existing note save',
      build: buildBloc,
      setUp: () {
        when(
          () => repository.getNoteById(any()),
        ).thenThrow(Exception('Timeout'));
      },
      seed: () => EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        quillDocument: Document(),
        isNewNote: false,
      ),
      act: (bloc) => bloc.add(
        EditorSaveRequested(
          content: jsonDecode(kSomeDelta),
          plainText: kSomePlainText,
        ),
      ),
      expect: () => [
        isA<EditorFailure>().having(
          (s) => s.error,
          'error',
          ErrorCategory.failedToSaveNote,
        ),
      ],
    );

    blocTest<EditorBloc, EditorState>(
      'calls upsertNote when isNewNote=false but note no longer exists in DB',
      build: buildBloc,
      setUp: () {
        when(
          () => repository.getNoteById(kTestNoteId),
        ).thenAnswer((_) async => null);
        when(() => repository.upsertNote(any())).thenAnswer((_) async {});
      },
      seed: () => EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        quillDocument: Document(),
        isNewNote: false,
      ),
      act: (bloc) => bloc.add(
        EditorSaveRequested(
          content: jsonDecode(kSomeDelta),
          plainText: kSomePlainText,
        ),
      ),
      expect: () => [
        isA<EditorLoaded>().having((s) => s.isSaving, 'isSaving', true),
        isA<EditorSaveSuccess>(),
      ],
      verify: (_) {
        verify(() => repository.upsertNote(any())).called(1);
        verifyNever(() => repository.upsertNote(any()));
      },
    );

    blocTest<EditorBloc, EditorState>(
      'emits EditorDeleteRequest when existing note is saved with empty content',
      build: buildBloc,
      setUp: () {
        when(
          () => repository.getNoteById(kTestNoteId),
        ).thenAnswer((_) async => makeNote());
      },
      seed: () => EditorLoaded(
        noteId: kTestNoteId,
        title: '',
        quillDocument: Document(),
        isNewNote: false,
      ),
      act: (bloc) => bloc.add(
        EditorSaveRequested(content: jsonDecode(kEmptyDelta), plainText: ''),
      ),
      expect: () => [
        isA<EditorDeleteRequest>().having(
          (s) => s.noteId,
          'noteId',
          kTestNoteId,
        ),
      ],
      verify: (_) {
        verifyNever(() => repository.upsertNote(any()));
        verifyNever(() => repository.upsertNote(any()));
      },
    );
  });

  // ════════════════════════════════════════════════════════════════════════════
  // EditorAutoSaveRequested
  // ════════════════════════════════════════════════════════════════════════════

  group('EditorAutoSaveRequested', () {
    blocTest<EditorBloc, EditorState>(
      'is a no-op when state is not EditorLoaded',
      build: buildBloc,
      act: (bloc) => bloc.add(
        EditorAutoSaveRequested(
          content: jsonDecode(kSomeDelta),
          plainText: kSomePlainText,
        ),
      ),
      expect: () => [],
    );

    blocTest<EditorBloc, EditorState>(
      'skips auto-save when new note is empty (title and body both blank)',
      build: buildBloc,
      setUp: () {
        when(() => repository.getNoteById(any())).thenAnswer((_) async => null);
      },
      seed: () => EditorLoaded(
        noteId: kTestNoteId,
        title: '',
        quillDocument: Document(),
        isNewNote: true,
      ),
      act: (bloc) => bloc.add(
        EditorAutoSaveRequested(
          content: jsonDecode(kEmptyDelta),
          plainText: '   ',
        ),
      ),
      expect: () => [],
      verify: (_) => verifyNever(() => repository.upsertNote(any())),
    );

    blocTest<EditorBloc, EditorState>(
      'skips auto-save when content is unchanged for an existing note',
      build: buildBloc,
      setUp: () {
        when(() => repository.getNoteById(kTestNoteId)).thenAnswer(
          (_) async => makeNote(title: kTestTitle, content: kSomeDelta),
        );
      },
      seed: () => EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        quillDocument: Document(),
        isNewNote: false,
      ),
      act: (bloc) => bloc.add(
        EditorAutoSaveRequested(
          content: jsonDecode(kSomeDelta),
          plainText: kSomePlainText,
        ),
      ),
      expect: () => [],
      verify: (_) => verifyNever(() => repository.upsertNote(any())),
    );

    blocTest<EditorBloc, EditorState>(
      'creates note on first auto-save of a new note with content',
      build: buildBloc,
      setUp: () {
        when(() => repository.getNoteById(any())).thenAnswer((_) async => null);
        when(() => repository.upsertNote(any())).thenAnswer((_) async {});
      },
      seed: () => EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        quillDocument: Document(),
        isNewNote: true,
      ),
      act: (bloc) => bloc.add(
        EditorAutoSaveRequested(
          content: jsonDecode(kSomeDelta),
          plainText: kSomePlainText,
        ),
      ),
      verify: (_) {
        verify(() => repository.upsertNote(any())).called(1);
        verifyNever(() => repository.upsertNote(any()));
      },
    );

    blocTest<EditorBloc, EditorState>(
      'sets isDirty=true after first auto-save',
      build: buildBloc,
      setUp: () {
        when(() => repository.getNoteById(any())).thenAnswer((_) async => null);
        when(() => repository.upsertNote(any())).thenAnswer((_) async {});
      },
      seed: () => EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        quillDocument: Document(),
        isNewNote: true,
      ),
      act: (bloc) => bloc.add(
        EditorAutoSaveRequested(
          content: jsonDecode(kSomeDelta),
          plainText: kSomePlainText,
        ),
      ),
      expect: () => [
        isA<EditorLoaded>().having((s) => s.isDirty, 'isDirty', true),
      ],
    );

    blocTest<EditorBloc, EditorState>(
      'flips isNewNote from true to false after first successful auto-save',
      build: buildBloc,
      setUp: () {
        when(() => repository.getNoteById(any())).thenAnswer((_) async => null);
        when(() => repository.upsertNote(any())).thenAnswer((_) async {});
      },
      seed: () => EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        quillDocument: Document(),
        isNewNote: true,
      ),
      act: (bloc) => bloc.add(
        EditorAutoSaveRequested(
          content: jsonDecode(kSomeDelta),
          plainText: kSomePlainText,
        ),
      ),
      // FIX: bloc does copyWith(isNewNote: current.isNewNote ? false : current.isNewNote)
      expect: () => [
        isA<EditorLoaded>().having((s) => s.isNewNote, 'isNewNote', false),
      ],
    );

    blocTest<EditorBloc, EditorState>(
      'updates existing note on subsequent auto-save when content changed',
      build: buildBloc,
      setUp: () {
        when(() => repository.getNoteById(kTestNoteId)).thenAnswer(
          (_) async => makeNote(title: kTestTitle, content: kEmptyDelta),
        );
        when(() => repository.upsertNote(any())).thenAnswer((_) async {});
      },
      seed: () => EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        quillDocument: Document(),
        isNewNote: false,
      ),
      act: (bloc) => bloc.add(
        EditorAutoSaveRequested(
          content: jsonDecode(kSomeDelta),
          plainText: kSomePlainText,
        ),
      ),
      verify: (_) {
        verify(() => repository.upsertNote(any())).called(1);
        verifyNever(() => repository.upsertNote(any()));
      },
    );

    blocTest<EditorBloc, EditorState>(
      'updates existing note when title changed during auto-save',
      build: buildBloc,
      setUp: () {
        when(() => repository.getNoteById(kTestNoteId)).thenAnswer(
          (_) async => makeNote(title: 'Old Title', content: kSomeDelta),
        );
        when(() => repository.upsertNote(any())).thenAnswer((_) async {});
      },
      seed: () => EditorLoaded(
        noteId: kTestNoteId,
        title: 'New Title',
        quillDocument: Document(),
        isNewNote: false,
      ),
      act: (bloc) => bloc.add(
        EditorAutoSaveRequested(
          content: jsonDecode(kSomeDelta),
          plainText: kSomePlainText,
        ),
      ),
      verify: (_) => verify(() => repository.upsertNote(any())).called(1),
    );

    blocTest<EditorBloc, EditorState>(
      'does NOT emit any state when auto-save fails (silent failure)',
      build: buildBloc,
      setUp: () {
        when(() => repository.getNoteById(any())).thenAnswer((_) async => null);
        when(
          () => repository.upsertNote(any()),
        ).thenThrow(Exception('Network error'));
      },
      seed: () => EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        quillDocument: Document(),
        isNewNote: true,
      ),
      act: (bloc) => bloc.add(
        EditorAutoSaveRequested(
          content: jsonDecode(kSomeDelta),
          plainText: kSomePlainText,
        ),
      ),
      // FIX: bloc catches error silently — no EditorFailure emitted for auto-save
      expect: () => [],
    );

    blocTest<EditorBloc, EditorState>(
      'auto-save preserves original createdAt for existing note',
      build: buildBloc,
      setUp: () {
        final original = makeNote(createdAt: DateTime(2021, 3, 10));
        when(
          () => repository.getNoteById(kTestNoteId),
        ).thenAnswer((_) async => original);
        when(
          () => repository.upsertNote(captureAny()),
        ).thenAnswer((_) async {});
      },
      seed: () => EditorLoaded(
        noteId: kTestNoteId,
        title: 'Changed Title',
        quillDocument: Document(),
        isNewNote: false,
      ),
      act: (bloc) => bloc.add(
        EditorAutoSaveRequested(
          content: jsonDecode(kSomeDelta),
          plainText: kSomePlainText,
        ),
      ),
      verify: (_) {
        final captured = verify(
          () => repository.upsertNote(captureAny()),
        ).captured;
        final saved = captured.first as NoteModel;
        expect(saved.createdAt, DateTime(2021, 3, 10));
      },
    );

    blocTest<EditorBloc, EditorState>(
      'previewText truncated at 40 chars during auto-save',
      build: buildBloc,
      setUp: () {
        when(() => repository.getNoteById(any())).thenAnswer((_) async => null);
        when(
          () => repository.upsertNote(captureAny()),
        ).thenAnswer((_) async {});
      },
      seed: () => EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        quillDocument: Document(),
        isNewNote: true,
      ),
      act: (bloc) {
        final longText = 'B' * 100;
        bloc.add(
          EditorAutoSaveRequested(
            content: jsonDecode(kSomeDelta),
            plainText: longText,
          ),
        );
      },
      verify: (_) {
        final captured = verify(
          () => repository.upsertNote(captureAny()),
        ).captured;
        final note = captured.first as NoteModel;
        expect(note.previewText.length, 40);
        expect(note.previewText, 'B' * 40);
      },
    );

    blocTest<EditorBloc, EditorState>(
      'auto-saves new note with non-empty title but empty body',
      build: buildBloc,
      setUp: () {
        when(() => repository.getNoteById(any())).thenAnswer((_) async => null);
        when(() => repository.upsertNote(any())).thenAnswer((_) async {});
      },
      seed: () => EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle, // title present
        quillDocument: Document(),
        isNewNote: true,
      ),
      act: (bloc) => bloc.add(
        EditorAutoSaveRequested(
          content: jsonDecode(kEmptyDelta),
          plainText:
              '', // empty body — but title is non-empty so skip guard doesn't fire
        ),
      ),
      // The skip guard is: isNewNote && title.trim().isEmpty && plainText.trim().isEmpty
      // title is non-empty → guard is false → save proceeds
      verify: (_) => verify(() => repository.upsertNote(any())).called(1),
    );

    blocTest<EditorBloc, EditorState>(
      'auto-save is silent when getNoteMetaData throws (no state emitted, no crash)',
      build: buildBloc,
      setUp: () {
        when(
          () => repository.getNoteById(any()),
        ).thenThrow(Exception('Connection reset'));
      },
      seed: () => EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        quillDocument: Document(),
        isNewNote: false,
      ),
      act: (bloc) => bloc.add(
        EditorAutoSaveRequested(
          content: jsonDecode(kSomeDelta),
          plainText: kSomePlainText,
        ),
      ),
      // catch(e) block logs and returns — no EditorFailure, no crash
      expect: () => [],
      verify: (_) => verifyNever(() => repository.upsertNote(any())),
    );

    blocTest<EditorBloc, EditorState>(
      'isNewNote stays false after auto-save when already false',
      build: buildBloc,
      setUp: () {
        when(
          () => repository.getNoteById(kTestNoteId),
        ).thenAnswer((_) async => makeNote(content: kEmptyDelta));
        when(() => repository.upsertNote(any())).thenAnswer((_) async {});
      },
      seed: () => EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        quillDocument: Document(),
        isNewNote: false,
        isDirty: false,
      ),
      act: (bloc) => bloc.add(
        EditorAutoSaveRequested(
          content: jsonDecode(kSomeDelta),
          plainText: kSomePlainText,
        ),
      ),
      verify: (bloc) {
        final s = bloc.state as EditorLoaded;
        expect(s.isNewNote, false);
        expect(s.isDirty, true);
      },
    );
  });

  // ════════════════════════════════════════════════════════════════════════════
  // EditorLoaded.copyWith — unit tests
  // ════════════════════════════════════════════════════════════════════════════

  group('EditorLoaded.copyWith', () {
    final base = EditorLoaded(
      noteId: kTestNoteId,
      title: kTestTitle,
      quillDocument: Document(),
      isContentLoading: false,
      isSaving: false,
      activeToolbar: EditorToolbar.none,
      isNewNote: false,
    );

    test('returns identical values when nothing overridden', () {
      final copy = base.copyWith();
      expect(copy.noteId, base.noteId);
      expect(copy.title, base.title);
      expect(copy.isContentLoading, base.isContentLoading);
      expect(copy.isSaving, base.isSaving);
      expect(copy.activeToolbar, base.activeToolbar);
      expect(copy.isNewNote, base.isNewNote);
    });

    test('overrides only supplied fields', () {
      final copy = base.copyWith(title: 'Changed', isSaving: true);
      expect(copy.title, 'Changed');
      expect(copy.isSaving, true);
      expect(copy.noteId, base.noteId);
      expect(copy.activeToolbar, base.activeToolbar);
    });

    test('can set activeToolbar to every enum value', () {
      for (final t in EditorToolbar.values) {
        final copy = base.copyWith(activeToolbar: t);
        expect(copy.activeToolbar, t);
      }
    });

    test('isDirty defaults to false and can be toggled via copyWith', () {
      expect(base.isDirty, false);
      final dirty = base.copyWith(isDirty: true);
      expect(dirty.isDirty, true);
    });

    test('quillDocument can be replaced via copyWith', () {
      final newDoc = Document();
      final copy = base.copyWith(quillDocument: newDoc);
      expect(copy.quillDocument, newDoc);
    });

    test('isContentLoading can be toggled via copyWith', () {
      final loading = base.copyWith(isContentLoading: true);
      expect(loading.isContentLoading, true);
    });

    test('isNewNote can be toggled via copyWith', () {
      final asNew = base.copyWith(isNewNote: true);
      expect(asNew.isNewNote, true);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // Edge cases & sequential event chains
  // ════════════════════════════════════════════════════════════════════════════

  group('Edge cases', () {
    blocTest<EditorBloc, EditorState>(
      'title → toolbar toggle → save flows correctly in sequence',
      build: buildBloc,
      setUp: () {
        when(() => repository.getNoteById(any())).thenAnswer((_) async => null);
        when(() => repository.upsertNote(any())).thenAnswer((_) async {});
      },
      seed: () => EditorLoaded(
        noteId: kTestNoteId,
        title: '',
        quillDocument: Document(),
        isNewNote: true,
      ),
      act: (bloc) async {
        bloc.add(EditorTitleChanged('Chained Title'));
        bloc.add(EditorToolbarToggled(EditorToolbar.options));
        bloc.add(
          EditorSaveRequested(
            content: jsonDecode(kSomeDelta),
            plainText: kSomePlainText,
          ),
        );
      },
      expect: () => [
        isA<EditorLoaded>().having((s) => s.title, 'title', 'Chained Title'),
        isA<EditorLoaded>().having(
          (s) => s.activeToolbar,
          'toolbar',
          EditorToolbar.options,
        ),
        isA<EditorLoaded>().having((s) => s.isSaving, 'isSaving', true),
        isA<EditorSaveSuccess>(),
      ],
    );

    blocTest<EditorBloc, EditorState>(
      'auto-save then manual save calls upsertNote on second save',
      build: buildBloc,
      setUp: () {
        when(
          () => repository.getNoteById(kTestNoteId),
        ).thenAnswer((_) async => null);
        when(() => repository.upsertNote(any())).thenAnswer((_) async {});
        when(() => repository.upsertNote(any())).thenAnswer((_) async {});
      },
      seed: () => EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        quillDocument: Document(),
        isNewNote: true,
      ),
      act: (bloc) async {
        // First: auto-save creates the note
        bloc.add(
          EditorAutoSaveRequested(
            content: jsonDecode(kSomeDelta),
            plainText: kSomePlainText,
          ),
        );
        await Future<void>.delayed(Duration.zero);

        // Now stub getNoteMetaData to return the note that was just "created"
        when(
          () => repository.getNoteById(kTestNoteId),
        ).thenAnswer((_) async => makeNote());

        // Second: manual save — content is same so it discards
        bloc.add(
          EditorSaveRequested(
            content: jsonDecode(kSomeDelta),
            plainText: kSomePlainText,
          ),
        );
      },
      verify: (_) {
        verify(() => repository.upsertNote(any())).called(1);
      },
    );

    blocTest<EditorBloc, EditorState>(
      'second save after create calls upsertNote only once (re-init simulated)',
      build: buildBloc,
      setUp: () {
        when(() => repository.getNoteById(any())).thenAnswer((_) async => null);
        when(() => repository.upsertNote(any())).thenAnswer((_) async {});
        when(() => repository.upsertNote(any())).thenAnswer((_) async {});
      },
      act: (bloc) async {
        bloc.emit(
          EditorLoaded(
            noteId: kTestNoteId,
            title: kTestTitle,
            quillDocument: Document(),
            isNewNote: true,
          ),
        );

        bloc.add(
          EditorSaveRequested(
            content: jsonDecode(kSomeDelta),
            plainText: kSomePlainText,
          ),
        );

        await Future<void>.delayed(Duration.zero);

        when(
          () => repository.getNoteById(kTestNoteId),
        ).thenAnswer((_) async => makeNote());

        bloc.add(EditorInitialised(noteId: kTestNoteId, noteTitle: kTestTitle));
      },
      wait: const Duration(milliseconds: 300),
      verify: (_) {
        verify(() => repository.upsertNote(any())).called(1);
      },
    );

    blocTest<EditorBloc, EditorState>(
      'events after EditorFailure are ignored if state is not EditorLoaded',
      build: buildBloc,
      seed: () => const EditorFailure(ErrorCategory.somethingWentWrong),
      act: (bloc) {
        bloc.add(EditorTitleChanged('Should be ignored'));
        bloc.add(EditorToolbarToggled(EditorToolbar.menu));
      },
      expect: () => [],
    );
  });
}
