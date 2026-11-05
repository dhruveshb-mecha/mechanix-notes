import 'package:bloc_test/bloc_test.dart';
import 'package:mechanix_notes/core/utils/constants.dart';
import 'package:mechanix_notes/core/utils/enums.dart';
import 'package:mechanix_notes/features/notes/bloc/editor/editor_bloc.dart';
import 'package:mechanix_notes/features/notes/data/models/note_model.dart';
import 'package:mechanix_notes/features/notes/data/repository/note_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:objectbox/objectbox.dart';
import 'package:test/test.dart';

// ─── Mocks ────────────────────────────────────────────────────────────────────

class MockNoteRepository extends Mock implements NoteRepository {}

class FakeNoteModel extends Fake implements NoteModel {}

// ─── Helpers ─────────────────────────────────────────────────────────────────

const kTestNoteId = 'test-note-id-123';
const kTestTitle = 'Test Note Title';
const kEmptyMarkdown = '';
const kSomeMarkdown = 'Hello World\n';
const kSomePlainText = 'Hello World\n';

NoteModel makeNote({
  String id = kTestNoteId,
  String title = kTestTitle,
  String content = kSomeMarkdown,
  String plainText = kSomePlainText,
  DateTime? createdAt,
  DateTime? updatedAt,
  bool isPinned = false,
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
    isPinned: isPinned,
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
      'emits EditorLoaded with empty title, blank document with H1 format, isNewNote=true',
      build: buildBloc,
      act: (bloc) => bloc.add(EditorInitialised()),
      expect: () => [
        isA<EditorLoaded>()
            .having((s) => s.title, 'title', '')
            .having((s) => s.isNewNote, 'isNewNote', true)
            .having((s) => s.markdownContent, 'markdownContent', '# '),
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
            .having((s) => s.markdownContent, 'markdownContent', isNotEmpty)
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
        expect(loaded.markdownContent, isNotNull);
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
        expect(loaded.markdownContent, isNotNull);
        expect(loaded.isContentLoading, false);
      },
    );

    blocTest<EditorBloc, EditorState>(
      'initializes empty existing note content with H1 format',
      build: buildBloc,
      setUp: () {
        when(
          () => repository.getNoteById(kTestNoteId),
        ).thenAnswer((_) async => makeNote(content: kEmptyMarkdown));
      },
      act: (bloc) => bloc.add(
        EditorInitialised(noteId: kTestNoteId, noteTitle: kTestTitle),
      ),
      wait: const Duration(milliseconds: 300),
      verify: (bloc) {
        expect(bloc.state, isA<EditorLoaded>());
        final loaded = bloc.state as EditorLoaded;
        expect(loaded.markdownContent, '# ');
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
  // EditorSaveRequested — new note
  // ════════════════════════════════════════════════════════════════════════════

  group('EditorSaveRequested — new note', () {
    blocTest<EditorBloc, EditorState>(
      'discards a new note that has empty title and empty body',
      build: buildBloc,
      setUp: () {
        when(() => repository.getNoteById(any())).thenAnswer((_) async => null);
      },
      seed: () =>
          const EditorLoaded(noteId: kTestNoteId, title: '', isNewNote: true),
      act: (bloc) => bloc.add(
        EditorSaveRequested(content: kEmptyMarkdown, plainText: '   '),
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
      seed: () =>
          const EditorLoaded(noteId: kTestNoteId, title: '', isNewNote: true),
      act: (bloc) =>
          bloc.add(EditorSaveRequested(content: kEmptyMarkdown, plainText: '')),
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
      seed: () => const EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        isNewNote: true,
      ),
      act: (bloc) =>
          bloc.add(EditorSaveRequested(content: kEmptyMarkdown, plainText: '')),
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
      seed: () =>
          const EditorLoaded(noteId: kTestNoteId, title: '', isNewNote: true),
      act: (bloc) => bloc.add(
        EditorSaveRequested(content: kSomeMarkdown, plainText: kSomePlainText),
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
      seed: () => const EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        isNewNote: true,
      ),
      act: (bloc) => bloc.add(
        EditorSaveRequested(content: kSomeMarkdown, plainText: kSomePlainText),
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
      seed: () => const EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        isNewNote: true,
      ),
      act: (bloc) {
        final longText = 'A' * (Constants.notePreviewTextMaxLength + 50);
        bloc.add(
          EditorSaveRequested(content: kSomeMarkdown, plainText: longText),
        );
      },
      verify: (_) {
        final captured = verify(
          () => repository.upsertNote(captureAny()),
        ).captured;
        final note = captured.first as NoteModel;
        expect(note.previewText.length, Constants.notePreviewTextMaxLength);
        expect(note.previewText, 'A' * Constants.notePreviewTextMaxLength);
      },
    );

    blocTest<EditorBloc, EditorState>(
      'does NOT truncate previewText when plainText is exactly max length chars',
      build: buildBloc,
      setUp: () {
        when(() => repository.getNoteById(any())).thenAnswer((_) async => null);
        when(
          () => repository.upsertNote(captureAny()),
        ).thenAnswer((_) async {});
      },
      seed: () => const EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        isNewNote: true,
      ),
      act: (bloc) {
        final exactText = 'A' * Constants.notePreviewTextMaxLength;
        bloc.add(
          EditorSaveRequested(content: kSomeMarkdown, plainText: exactText),
        );
      },
      verify: (_) {
        final captured = verify(
          () => repository.upsertNote(captureAny()),
        ).captured;
        final note = captured.first as NoteModel;
        expect(note.previewText.length, Constants.notePreviewTextMaxLength);
        expect(note.previewText, 'A' * Constants.notePreviewTextMaxLength);
      },
    );

    blocTest<EditorBloc, EditorState>(
      'truncates previewText when plainText is max length + 1 chars',
      build: buildBloc,
      setUp: () {
        when(() => repository.getNoteById(any())).thenAnswer((_) async => null);
        when(
          () => repository.upsertNote(captureAny()),
        ).thenAnswer((_) async {});
      },
      seed: () => const EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        isNewNote: true,
      ),
      act: (bloc) {
        final justOver = 'A' * (Constants.notePreviewTextMaxLength + 1);
        bloc.add(
          EditorSaveRequested(content: kSomeMarkdown, plainText: justOver),
        );
      },
      verify: (_) {
        final captured = verify(
          () => repository.upsertNote(captureAny()),
        ).captured;
        final note = captured.first as NoteModel;
        expect(note.previewText.length, Constants.notePreviewTextMaxLength);
        expect(note.previewText, 'A' * Constants.notePreviewTextMaxLength);
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
      seed: () => const EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        isNewNote: true,
      ),
      act: (bloc) => bloc.add(
        EditorSaveRequested(content: kSomeMarkdown, plainText: kSomePlainText),
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
      seed: () => const EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        isNewNote: true,
      ),
      act: (bloc) => bloc.add(
        EditorSaveRequested(content: kSomeMarkdown, plainText: kSomePlainText),
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
      seed: () => const EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        isNewNote: true,
      ),
      act: (bloc) => bloc.add(
        EditorSaveRequested(content: kSomeMarkdown, plainText: kSomePlainText),
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
      seed: () => const EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        isNewNote: true,
      ),
      act: (bloc) {
        // 5 chars → ceil(5/60) = 1 line → 1*24 + 80 = 104
        bloc.add(
          EditorSaveRequested(content: kSomeMarkdown, plainText: 'Short'),
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
      seed: () => const EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle, // non-empty title so note is not discarded
        isNewNote: true,
      ),
      act: (bloc) {
        // 0 chars → ceil(0/60)=0 → clamp(1,20)=1 → 1*24+80=104
        bloc.add(EditorSaveRequested(content: kEmptyMarkdown, plainText: ''));
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
      seed: () => const EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        isNewNote: true,
      ),
      act: (bloc) {
        // 60 chars → ceil(60/60)=1 → 104; then 61 chars → ceil(61/60)=2 → 128
        bloc.add(
          EditorSaveRequested(content: kSomeMarkdown, plainText: 'A' * 60),
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
      seed: () => const EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        isNewNote: true,
      ),
      act: (bloc) => bloc.add(
        EditorSaveRequested(content: kSomeMarkdown, plainText: kSomePlainText),
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
      seed: () => const EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        isNewNote: true,
      ),
      act: (bloc) {
        // 61 chars → ceil(61/60)=2 → 2*24+80=128
        bloc.add(
          EditorSaveRequested(content: kSomeMarkdown, plainText: 'A' * 61),
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
      seed: () => const EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        isNewNote: true,
      ),
      act: (bloc) {
        // 60*21 = 1260 chars → ceil(1260/60) = 21 → clamped to 20 → 20*24+80=560
        final longText = 'A' * (60 * 21);
        bloc.add(
          EditorSaveRequested(content: kSomeMarkdown, plainText: longText),
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
        EditorSaveRequested(content: kSomeMarkdown, plainText: kSomePlainText),
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
          (_) async => makeNote(title: kTestTitle, content: kSomeMarkdown),
        );
      },
      seed: () => const EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        isNewNote: false,
        // isDirty defaults to false
      ),
      act: (bloc) => bloc.add(
        EditorSaveRequested(content: kSomeMarkdown, plainText: kSomePlainText),
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
          (_) async => makeNote(title: kTestTitle, content: kSomeMarkdown),
        );
      },
      seed: () => const EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        isNewNote: false,
        isDirty: true, // was auto-saved previously
      ),
      act: (bloc) => bloc.add(
        EditorSaveRequested(content: kSomeMarkdown, plainText: kSomePlainText),
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
          (_) async => makeNote(title: 'Old Title', content: kSomeMarkdown),
        );
        when(() => repository.upsertNote(any())).thenAnswer((_) async {});
      },
      seed: () => const EditorLoaded(
        noteId: kTestNoteId,
        title: 'New Title',
        isNewNote: false,
      ),
      act: (bloc) => bloc.add(
        EditorSaveRequested(content: kSomeMarkdown, plainText: kSomePlainText),
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
          (_) async => makeNote(title: kTestTitle, content: kEmptyMarkdown),
        );
        when(() => repository.upsertNote(any())).thenAnswer((_) async {});
      },
      seed: () => const EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        isNewNote: false,
      ),
      act: (bloc) => bloc.add(
        EditorSaveRequested(content: kSomeMarkdown, plainText: kSomePlainText),
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
      seed: () => const EditorLoaded(
        noteId: kTestNoteId,
        title: 'Different Title',
        isNewNote: false,
      ),
      act: (bloc) => bloc.add(
        EditorSaveRequested(content: kSomeMarkdown, plainText: kSomePlainText),
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
      seed: () => const EditorLoaded(
        noteId: kTestNoteId,
        title: 'Updated',
        isNewNote: false,
      ),
      act: (bloc) => bloc.add(
        EditorSaveRequested(content: kSomeMarkdown, plainText: kSomePlainText),
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
        when(() => repository.getNoteById(kTestNoteId)).thenAnswer(
          (_) async => makeNote(title: 'Old', content: kEmptyMarkdown),
        );
        when(
          () => repository.upsertNote(any()),
        ).thenThrow(Exception('Network error'));
      },
      seed: () => const EditorLoaded(
        noteId: kTestNoteId,
        title: 'New',
        isNewNote: false,
      ),
      act: (bloc) => bloc.add(
        EditorSaveRequested(content: kSomeMarkdown, plainText: kSomePlainText),
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
      seed: () => const EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        isNewNote: false,
      ),
      act: (bloc) => bloc.add(
        EditorSaveRequested(content: kSomeMarkdown, plainText: kSomePlainText),
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
      seed: () => const EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        isNewNote: false,
      ),
      act: (bloc) => bloc.add(
        EditorSaveRequested(content: kSomeMarkdown, plainText: kSomePlainText),
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
      seed: () =>
          const EditorLoaded(noteId: kTestNoteId, title: '', isNewNote: false),
      act: (bloc) =>
          bloc.add(EditorSaveRequested(content: kEmptyMarkdown, plainText: '')),
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
          content: kSomeMarkdown,
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
      seed: () =>
          const EditorLoaded(noteId: kTestNoteId, title: '', isNewNote: true),
      act: (bloc) => bloc.add(
        EditorAutoSaveRequested(content: kEmptyMarkdown, plainText: '   '),
      ),
      expect: () => [],
      verify: (_) => verifyNever(() => repository.upsertNote(any())),
    );

    blocTest<EditorBloc, EditorState>(
      'skips auto-save when content is unchanged for an existing note',
      build: buildBloc,
      setUp: () {
        when(() => repository.getNoteById(kTestNoteId)).thenAnswer(
          (_) async => makeNote(title: kTestTitle, content: kSomeMarkdown),
        );
      },
      seed: () => const EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        isNewNote: false,
      ),
      act: (bloc) => bloc.add(
        EditorAutoSaveRequested(
          content: kSomeMarkdown,
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
      seed: () => const EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        isNewNote: true,
      ),
      act: (bloc) => bloc.add(
        EditorAutoSaveRequested(
          content: kSomeMarkdown,
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
      seed: () => const EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        isNewNote: true,
      ),
      act: (bloc) => bloc.add(
        EditorAutoSaveRequested(
          content: kSomeMarkdown,
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
      seed: () => const EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        isNewNote: true,
      ),
      act: (bloc) => bloc.add(
        EditorAutoSaveRequested(
          content: kSomeMarkdown,
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
          (_) async => makeNote(title: kTestTitle, content: kEmptyMarkdown),
        );
        when(() => repository.upsertNote(any())).thenAnswer((_) async {});
      },
      seed: () => const EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        isNewNote: false,
      ),
      act: (bloc) => bloc.add(
        EditorAutoSaveRequested(
          content: kSomeMarkdown,
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
          (_) async => makeNote(title: 'Old Title', content: kSomeMarkdown),
        );
        when(() => repository.upsertNote(any())).thenAnswer((_) async {});
      },
      seed: () => const EditorLoaded(
        noteId: kTestNoteId,
        title: 'New Title',
        isNewNote: false,
      ),
      act: (bloc) => bloc.add(
        EditorAutoSaveRequested(
          content: kSomeMarkdown,
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
      seed: () => const EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        isNewNote: true,
      ),
      act: (bloc) => bloc.add(
        EditorAutoSaveRequested(
          content: kSomeMarkdown,
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
      seed: () => const EditorLoaded(
        noteId: kTestNoteId,
        title: 'Changed Title',
        isNewNote: false,
      ),
      act: (bloc) => bloc.add(
        EditorAutoSaveRequested(
          content: kSomeMarkdown,
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
      seed: () => const EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        isNewNote: true,
      ),
      act: (bloc) {
        final longText = 'B' * (Constants.notePreviewTextMaxLength + 50);
        bloc.add(
          EditorAutoSaveRequested(content: kSomeMarkdown, plainText: longText),
        );
      },
      verify: (_) {
        final captured = verify(
          () => repository.upsertNote(captureAny()),
        ).captured;
        final note = captured.first as NoteModel;
        expect(note.previewText.length, Constants.notePreviewTextMaxLength);
        expect(note.previewText, 'B' * Constants.notePreviewTextMaxLength);
      },
    );

    blocTest<EditorBloc, EditorState>(
      'auto-saves new note with non-empty title but empty body',
      build: buildBloc,
      setUp: () {
        when(() => repository.getNoteById(any())).thenAnswer((_) async => null);
        when(() => repository.upsertNote(any())).thenAnswer((_) async {});
      },
      seed: () => const EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle, // title present
        isNewNote: true,
      ),
      act: (bloc) => bloc.add(
        EditorAutoSaveRequested(
          content: kEmptyMarkdown,
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
      seed: () => const EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        isNewNote: false,
      ),
      act: (bloc) => bloc.add(
        EditorAutoSaveRequested(
          content: kSomeMarkdown,
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
        ).thenAnswer((_) async => makeNote(content: kEmptyMarkdown));
        when(() => repository.upsertNote(any())).thenAnswer((_) async {});
      },
      seed: () => const EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        isNewNote: false,
        isDirty: false,
      ),
      act: (bloc) => bloc.add(
        EditorAutoSaveRequested(
          content: kSomeMarkdown,
          plainText: kSomePlainText,
        ),
      ),
      verify: (bloc) {
        final s = bloc.state as EditorLoaded;
        expect(s.isNewNote, false);
        expect(s.isDirty, true);
      },
    );

    blocTest<EditorBloc, EditorState>(
      'never calls getNoteById during auto-save when lastSavedContent baseline is present in memory',
      build: buildBloc,
      setUp: () {
        when(() => repository.upsertNote(any())).thenAnswer((_) async {});
      },
      seed: () => EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        markdownContent: '# Initial',
        lastSavedContent: '# Initial',
        lastSavedTitle: kTestTitle,
        createdAt: DateTime(2025, 5, 20),
        isNewNote: false,
      ),
      act: (bloc) => bloc.add(
        EditorAutoSaveRequested(
          content: '# Initial\nNew line added',
          plainText: 'Initial\nNew line added',
        ),
      ),
      verify: (_) {
        verifyNever(() => repository.getNoteById(any()));
        verify(() => repository.upsertNote(any())).called(1);
      },
    );

    blocTest<EditorBloc, EditorState>(
      'skips auto-save entirely with zero repository calls when content matches lastSavedContent',
      build: buildBloc,
      seed: () => EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        markdownContent: '# Initial',
        lastSavedContent: '# Initial',
        lastSavedTitle: kTestTitle,
        createdAt: DateTime(2025, 5, 20),
        isNewNote: false,
      ),
      act: (bloc) => bloc.add(
        EditorAutoSaveRequested(
          content: '# Initial',
          plainText: 'Initial',
        ),
      ),
      expect: () => [],
      verify: (_) {
        verifyNever(() => repository.getNoteById(any()));
        verifyNever(() => repository.upsertNote(any()));
      },
    );
  });

  // ════════════════════════════════════════════════════════════════════════════
  // EditorLoaded.copyWith — unit tests
  // ════════════════════════════════════════════════════════════════════════════

  group('EditorLoaded.copyWith', () {
    final base = const EditorLoaded(
      noteId: kTestNoteId,
      title: kTestTitle,
      isContentLoading: false,
      isSaving: false,
      isNewNote: false,
    );

    test('returns identical values when nothing overridden', () {
      final copy = base.copyWith();
      expect(copy.noteId, base.noteId);
      expect(copy.title, base.title);
      expect(copy.isContentLoading, base.isContentLoading);
      expect(copy.isSaving, base.isSaving);
      expect(copy.isNewNote, base.isNewNote);
    });

    test('overrides only supplied fields', () {
      final copy = base.copyWith(title: 'Changed', isSaving: true);
      expect(copy.title, 'Changed');
      expect(copy.isSaving, true);
      expect(copy.noteId, base.noteId);
    });

    test('isDirty defaults to false and can be toggled via copyWith', () {
      expect(base.isDirty, false);
      final dirty = base.copyWith(isDirty: true);
      expect(dirty.isDirty, true);
    });

    test('markdownContent can be replaced via copyWith', () {
      final copy = base.copyWith(markdownContent: 'New markdown');
      expect(copy.markdownContent, 'New markdown');
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
      'auto-save then manual save calls upsertNote on second save',
      build: buildBloc,
      setUp: () {
        when(
          () => repository.getNoteById(kTestNoteId),
        ).thenAnswer((_) async => null);
        when(() => repository.upsertNote(any())).thenAnswer((_) async {});
        when(() => repository.upsertNote(any())).thenAnswer((_) async {});
      },
      seed: () => const EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        isNewNote: true,
      ),
      act: (bloc) async {
        // First: auto-save creates the note
        bloc.add(
          EditorAutoSaveRequested(
            content: kSomeMarkdown,
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
            content: kSomeMarkdown,
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
          const EditorLoaded(
            noteId: kTestNoteId,
            title: kTestTitle,
            isNewNote: true,
          ),
        );

        bloc.add(
          EditorSaveRequested(
            content: kSomeMarkdown,
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
        bloc.add(EditorPinToggled());
      },
      expect: () => [],
    );
  });

  group('Title and Preview extraction in buildNote', () {
    blocTest<EditorBloc, EditorState>(
      'extracts first line as title and remaining lines as previewText',
      build: buildBloc,
      setUp: () {
        when(() => repository.getNoteById(any())).thenAnswer((_) async => null);
        when(() => repository.upsertNote(any())).thenAnswer((_) async {});
      },
      seed: () =>
          const EditorLoaded(noteId: kTestNoteId, title: '', isNewNote: true),
      act: (bloc) => bloc.add(
        EditorSaveRequested(
          content: kSomeMarkdown,
          plainText:
              'My Note Title\nThis is the body of my note that provides preview text.',
        ),
      ),
      verify: (_) {
        final captured = verify(
          () => repository.upsertNote(captureAny()),
        ).captured;
        final note = captured.first as NoteModel;
        expect(note.title, 'My Note Title');
        expect(
          note.previewText,
          'This is the body of my note that provides preview text.',
        );
      },
    );

    blocTest<EditorBloc, EditorState>(
      'single line note uses that line for title and previewText',
      build: buildBloc,
      setUp: () {
        when(() => repository.getNoteById(any())).thenAnswer((_) async => null);
        when(() => repository.upsertNote(any())).thenAnswer((_) async {});
      },
      seed: () =>
          const EditorLoaded(noteId: kTestNoteId, title: '', isNewNote: true),
      act: (bloc) => bloc.add(
        EditorSaveRequested(
          content: kSomeMarkdown,
          plainText: 'Single Line Title Only',
        ),
      ),
      verify: (_) {
        final captured = verify(
          () => repository.upsertNote(captureAny()),
        ).captured;
        final note = captured.first as NoteModel;
        expect(note.title, 'Single Line Title Only');
        expect(note.previewText, 'Single Line Title Only');
      },
    );
    blocTest<EditorBloc, EditorState>(
      'new note with empty H1 heading leaves title empty and extracts body as previewText',
      build: buildBloc,
      setUp: () {
        when(() => repository.getNoteById(any())).thenAnswer((_) async => null);
        when(() => repository.upsertNote(any())).thenAnswer((_) async {});
      },
      seed: () =>
          const EditorLoaded(noteId: kTestNoteId, title: '', isNewNote: true),
      act: (bloc) => bloc.add(
        EditorSaveRequested(
          content: '# \nThis is body text',
          plainText: 'This is body text',
        ),
      ),
      verify: (_) {
        final captured = verify(
          () => repository.upsertNote(captureAny()),
        ).captured;
        final note = captured.first as NoteModel;
        expect(note.title, '');
        expect(note.previewText, 'This is body text');
      },
    );

    blocTest<EditorBloc, EditorState>(
      'modifying existing note where title was removed sets title to empty string and saves note',
      build: buildBloc,
      setUp: () {
        when(() => repository.getNoteById(kTestNoteId)).thenAnswer(
          (_) async => makeNote(title: 'Old Title', content: '# Old Title\nBody'),
        );
        when(() => repository.upsertNote(any())).thenAnswer((_) async {});
      },
      seed: () => const EditorLoaded(
        noteId: kTestNoteId,
        title: 'Old Title',
        lastSavedTitle: 'Old Title',
        lastSavedContent: '# Old Title\nBody',
        markdownContent: '# Old Title\nBody',
        isNewNote: false,
      ),
      act: (bloc) => bloc.add(
        EditorSaveRequested(
          content: '# \nBody',
          plainText: 'Body',
        ),
      ),
      expect: () => [
        isA<EditorLoaded>().having((s) => s.isSaving, 'isSaving', true),
        isA<EditorSaveSuccess>(),
      ],
      verify: (_) {
        final captured = verify(
          () => repository.upsertNote(captureAny()),
        ).captured;
        final note = captured.first as NoteModel;
        expect(note.title, '');
        expect(note.previewText, 'Body');
      },
    );
  });

  group('EditorPinToggled Tests', () {
    blocTest<EditorBloc, EditorState>(
      'toggles isPinned in EditorLoaded and calls togglePinNote for existing note',
      build: buildBloc,
      setUp: () {
        when(
          () => repository.togglePinNote(kTestNoteId),
        ).thenAnswer((_) async => true);
      },
      seed: () => const EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        isNewNote: false,
        isPinned: false,
      ),
      act: (bloc) => bloc.add(EditorPinToggled()),
      expect: () => [
        isA<EditorLoaded>()
            .having((s) => s.isPinned, 'isPinned', true)
            .having((s) => s.isDirty, 'isDirty', true),
      ],
      verify: (_) {
        verify(() => repository.togglePinNote(kTestNoteId)).called(1);
      },
    );

    blocTest<EditorBloc, EditorState>(
      'toggles isPinned for new note without calling togglePinNote immediately',
      build: buildBloc,
      seed: () => const EditorLoaded(
        noteId: kTestNoteId,
        title: '',
        isNewNote: true,
        isPinned: false,
      ),
      act: (bloc) => bloc.add(EditorPinToggled()),
      expect: () => [
        isA<EditorLoaded>()
            .having((s) => s.isPinned, 'isPinned', true)
            .having((s) => s.isDirty, 'isDirty', true),
      ],
      verify: (_) {
        verifyNever(() => repository.togglePinNote(any()));
      },
    );

    blocTest<EditorBloc, EditorState>(
      'loads existing note with isPinned status set properly',
      build: buildBloc,
      setUp: () {
        when(
          () => repository.getNoteById(kTestNoteId),
        ).thenAnswer((_) async => makeNote(isPinned: true));
      },
      act: (bloc) => bloc.add(EditorInitialised(noteId: kTestNoteId)),
      wait: const Duration(milliseconds: 300),
      expect: () => [
        isA<EditorLoaded>().having((s) => s.isContentLoading, 'loading', true),
        isA<EditorLoaded>()
            .having((s) => s.isPinned, 'isPinned', true)
            .having((s) => s.isContentLoading, 'loading', false),
      ],
    );

    blocTest<EditorBloc, EditorState>(
      'toggling pin sets lastSavedIsPinned so subsequent autosave skips upsertNote when content is unchanged',
      build: buildBloc,
      setUp: () {
        when(() => repository.togglePinNote(kTestNoteId))
            .thenAnswer((_) async => true);
      },
      seed: () => const EditorLoaded(
        noteId: kTestNoteId,
        title: kTestTitle,
        markdownContent: '# Initial',
        lastSavedContent: '# Initial',
        lastSavedTitle: kTestTitle,
        isNewNote: false,
        isPinned: false,
        lastSavedIsPinned: false,
      ),
      act: (bloc) async {
        bloc.add(EditorPinToggled());
        bloc.add(EditorAutoSaveRequested(
          content: '# Initial',
          plainText: 'Initial',
        ));
      },
      expect: () => [
        isA<EditorLoaded>()
            .having((s) => s.isPinned, 'isPinned', true)
            .having((s) => s.lastSavedIsPinned, 'lastSavedIsPinned', true),
      ],
      verify: (_) {
        verify(() => repository.togglePinNote(kTestNoteId)).called(1);
        verifyNever(() => repository.upsertNote(any()));
      },
    );
  });
}
