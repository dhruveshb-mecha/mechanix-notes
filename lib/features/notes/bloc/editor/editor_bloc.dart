import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_notes/core/utils/app_logger.dart';
import 'package:mechanix_notes/core/utils/constants.dart';
import 'package:mechanix_notes/core/utils/enums.dart';
import 'package:mechanix_notes/core/utils/helper.dart';
import 'package:mechanix_notes/features/notes/data/models/note_model.dart';
import 'package:mechanix_notes/features/notes/data/repository/note_repository.dart';
import 'package:objectbox/objectbox.dart';
import 'package:uuid/uuid.dart';

part 'editor_event.dart';
part 'editor_state.dart';

class EditorBloc extends Bloc<EditorEvent, EditorState> {
  final NoteRepository _repository;

  EditorBloc(this._repository) : super(const EditorInitial()) {
    on<EditorInitialised>(_onInitialised);
    on<EditorSaveRequested>(_onSaveRequested, transformer: sequential());
    on<EditorAutoSaveRequested>(
      _onAutoSaveRequested,
      transformer: sequential(),
    );
    on<EditorPinToggled>(_onPinToggled, transformer: sequential());
  }

  // Event Handlers
  Future<void> _onInitialised(
    EditorInitialised event,
    Emitter<EditorState> emit,
  ) async {
    try {
      final isEditMode = event.noteId != null;

      if (isEditMode) {
        emit(
          EditorLoaded(
            noteId: event.noteId!,
            title: event.noteTitle ?? '',
            isContentLoading: true,
            isNewNote: false,
          ),
        );

        final note = await _repository.getNoteById(event.noteId!);

        if (note == null) {
          AppLogger.e('EditorBloc: Note not found for id ${event.noteId}');
          emit(const EditorFailure(ErrorCategory.noteNotFound));
          return;
        }

        final initialContent = note.content.trim().isEmpty
            ? '# '
            : note.content;

        AppLogger.i('EditorBloc: Content ready for ${event.noteId}');
        emit(
          EditorLoaded(
            noteId: note.id,
            title: event.noteTitle ?? note.title,
            markdownContent: initialContent,
            lastSavedContent: initialContent,
            lastSavedTitle: event.noteTitle ?? note.title,
            lastSavedIsPinned: note.isPinned,
            createdAt: note.createdAt,
            isContentLoading: false,
            isNewNote: false,
            isPinned: note.isPinned,
          ),
        );
      } else {
        final newId = const Uuid().v4();
        AppLogger.i('EditorBloc: Create mode — generated id $newId');

        emit(
          EditorLoaded(
            noteId: newId,
            title: '',
            markdownContent: '# ',
            lastSavedContent: '# ',
            lastSavedTitle: '',
            lastSavedIsPinned: false,
            createdAt: DateTime.now(),
            isContentLoading: false,
            isNewNote: true,
          ),
        );
      }
    } catch (e) {
      AppLogger.e('EditorBloc: Failed to load note: $e');
      emit(const EditorFailure(ErrorCategory.somethingWentWrong));
    }
  }

  Future<void> _onSaveRequested(
    EditorSaveRequested event,
    Emitter<EditorState> emit,
  ) async {
    final current = state;
    if (current is! EditorLoaded) return;

    try {
      final markdown = event.content;
      final plainText = (event.plainText ?? markdownToPlainText(markdown))
          .trim();

      final isEmpty = current.title.trim().isEmpty && plainText.isEmpty;

      if (isEmpty) {
        if (current.isNewNote) {
          AppLogger.i('EditorBloc: Discarding empty new note');
          emit(const EditorDiscarded());
        } else {
          AppLogger.i('EditorBloc: Deleting existing note because it is empty');
          emit(EditorDeleteRequest(current.noteId));
        }
        return;
      }

      NoteModel? existing;
      if (current.lastSavedContent.isEmpty) {
        existing = await _repository.getNoteById(current.noteId);
      }

      final note = buildNote(
        current: current,
        content: markdown,
        plainText: plainText,
        existing: existing,
      );

      // Check if content is unchanged using in-memory baseline
      if (!current.isNewNote) {
        final lastSavedContent = existing != null
            ? existing.content
            : current.lastSavedContent;
        final lastSavedTitle = existing != null
            ? existing.title
            : current.lastSavedTitle;
        final lastSavedIsPinned = existing != null
            ? existing.isPinned
            : current.lastSavedIsPinned;

        final isContentUnchanged = lastSavedContent == markdown;
        final isTitleUnchanged = lastSavedTitle == note.title;
        final isPinUnchanged = lastSavedIsPinned == note.isPinned;

        if (isContentUnchanged && isTitleUnchanged && isPinUnchanged) {
          AppLogger.i('EditorBloc: Discarding unchanged edit');
          emit(
            EditorDiscarded(noteId: current.isDirty ? current.noteId : null),
          );
          return;
        }
      }

      emit(current.copyWith(isSaving: true, title: note.title));

      await _repository.upsertNote(note);

      AppLogger.i('EditorBloc: Manual save success for ${current.noteId}');
      emit(EditorSaveSuccess(current.noteId));
    } on DbFullException catch (e) {
      AppLogger.e('EditorBloc: Manual save failed due to full database: $e');
      emit(const EditorFailure(ErrorCategory.storageFull));
    } catch (e) {
      AppLogger.e('EditorBloc: Manual save failed: $e');
      emit(const EditorFailure(ErrorCategory.failedToSaveNote));
    }
  }

  (String title, String previewText) _extractTitleAndPreview(
    String currentTitle,
    String plainText,
  ) {
    final trimmed = plainText.trim();
    if (trimmed.isEmpty) {
      return (currentTitle, '');
    }

    final lines = plainText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.length > 1) {
      final title = lines.first;
      final bodyText = lines.skip(1).join(' ');
      final preview = bodyText.length > Constants.notePreviewTextMaxLength
          ? bodyText.substring(0, Constants.notePreviewTextMaxLength)
          : bodyText;
      return (title, preview);
    }

    // Only 1 line of text:
    final singleLine = lines.first;
    if (currentTitle.isNotEmpty && currentTitle != singleLine) {
      final preview = singleLine.length > Constants.notePreviewTextMaxLength
          ? singleLine.substring(0, Constants.notePreviewTextMaxLength)
          : singleLine;
      return (currentTitle, preview);
    }

    final preview = singleLine.length > Constants.notePreviewTextMaxLength
        ? singleLine.substring(0, Constants.notePreviewTextMaxLength)
        : singleLine;
    return (singleLine, preview);
  }

  NoteModel buildNote({
    required EditorLoaded current,
    required String content,
    required String plainText,
    NoteModel? existing,
  }) {
    final now = DateTime.now();

    final (title, previewText) = _extractTitleAndPreview(
      current.title,
      plainText,
    );

    return NoteModel(
      id: current.noteId,
      title: title,
      content: content,
      plainText: plainText,
      previewText: previewText,
      height: _estimateHeight(plainText),
      createdAt: existing?.createdAt ?? current.createdAt ?? now,
      updatedAt: now,
      isPinned: current.isPinned,
    );
  }

  Future<void> _onAutoSaveRequested(
    EditorAutoSaveRequested event,
    Emitter<EditorState> emit,
  ) async {
    final current = state;
    if (current is! EditorLoaded) return;

    try {
      final markdown = event.content;
      final plainText = (event.plainText ?? markdownToPlainText(markdown))
          .trim();

      NoteModel? existing;
      if (current.lastSavedContent.isEmpty) {
        existing = await _repository.getNoteById(current.noteId);
      }

      final note = buildNote(
        current: current,
        content: markdown,
        plainText: plainText,
        existing: existing,
      );

      // Don't auto-save if nothing changed
      if (!current.isNewNote) {
        final lastSavedContent = existing != null
            ? existing.content
            : current.lastSavedContent;
        final lastSavedTitle = existing != null
            ? existing.title
            : current.lastSavedTitle;
        final lastSavedIsPinned = existing != null
            ? existing.isPinned
            : current.lastSavedIsPinned;

        final isContentUnchanged = lastSavedContent == markdown;
        final isTitleUnchanged = lastSavedTitle == note.title;
        final isPinUnchanged = lastSavedIsPinned == note.isPinned;

        if (isContentUnchanged && isTitleUnchanged && isPinUnchanged) {
          return;
        }
      }

      // Don't auto-save if new and empty
      if (current.isNewNote && note.title.trim().isEmpty && plainText.isEmpty) {
        return;
      }

      await _repository.upsertNote(note);

      AppLogger.i('EditorBloc: Auto-save success for ${current.noteId}');
      final latestState = state;
      if (latestState is! EditorLoaded) return;

      emit(
        latestState.copyWith(
          title: note.title,
          lastSavedContent: markdown,
          lastSavedTitle: note.title,
          lastSavedIsPinned: latestState.isPinned,
          createdAt: note.createdAt,
          isDirty: true,
          isNewNote: false,
        ),
      );
    } on DbFullException catch (e) {
      AppLogger.e('EditorBloc: Auto-save failed due to full database: $e');
      emit(const EditorFailure(ErrorCategory.storageFull));
    } catch (e) {
      AppLogger.e('EditorBloc: Auto-save failed: $e');
    }
  }

  Future<void> _onPinToggled(
    EditorPinToggled event,
    Emitter<EditorState> emit,
  ) async {
    final current = state;
    if (current is! EditorLoaded) return;
    final nextPinned = !current.isPinned;

    emit(
      current.copyWith(
        isPinned: nextPinned,
        lastSavedIsPinned: nextPinned,
        isDirty: true,
      ),
    );

    if (!current.isNewNote) {
      await _repository.togglePinNote(current.noteId);
    }
  }

  // Helper

  double _estimateHeight(String plainText) {
    const lineHeight = 24.0;
    const charsPerLine = 60;
    final lines = (plainText.length / charsPerLine).ceil().clamp(1, 20);
    return lines * lineHeight + 80;
  }
}
