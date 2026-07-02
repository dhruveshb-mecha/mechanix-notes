import 'dart:async';
import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:mechanix_notes/core/utils/app_logger.dart';
import 'package:mechanix_notes/core/utils/constants.dart';
import 'package:mechanix_notes/core/utils/helper.dart';
import 'package:mechanix_notes/features/notes/data/models/note_model.dart';
import 'package:mechanix_notes/features/notes/data/repository/note_repository.dart';
import 'package:objectbox/objectbox.dart';
import 'package:uuid/uuid.dart';
import 'package:mechanix_notes/core/utils/enums.dart';
part 'editor_event.dart';
part 'editor_state.dart';

class EditorBloc extends Bloc<EditorEvent, EditorState> {
  final NoteRepository _repository;

  EditorBloc(this._repository) : super(const EditorInitial()) {
    on<EditorInitialised>(_onInitialised);
    on<EditorTitleChanged>(_onTitleChanged);
    on<EditorToolbarToggled>(_onToolbarToggled);
    on<EditorSaveRequested>(_onSaveRequested);
    on<EditorAutoSaveRequested>(_onAutoSaveRequested);
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

        final quillDoc = await compute(decodeDocumentInIsolate, note.content);

        AppLogger.i('EditorBloc: Content ready for ${event.noteId}');
        emit(
          EditorLoaded(
            noteId: note.id,
            title: event.noteTitle ?? note.title,
            quillDocument: quillDoc,
            isContentLoading: false,
            isNewNote: false,
          ),
        );
      } else {
        final newId = const Uuid().v4();
        AppLogger.i('EditorBloc: Create mode — generated id $newId');

        emit(
          EditorLoaded(
            noteId: newId,
            title: '',
            quillDocument: Document(),
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

  void _onTitleChanged(EditorTitleChanged event, Emitter<EditorState> emit) {
    final current = state;
    if (current is! EditorLoaded) return;
    emit(current.copyWith(title: event.title));
  }

  void _onToolbarToggled(
    EditorToolbarToggled event,
    Emitter<EditorState> emit,
  ) {
    final current = state;
    if (current is! EditorLoaded) return;
    final next = current.activeToolbar == event.toolbar
        ? EditorToolbar.none
        : event.toolbar;
    emit(current.copyWith(activeToolbar: next));
  }

  Future<void> _onSaveRequested(
    EditorSaveRequested event,
    Emitter<EditorState> emit,
  ) async {
    final current = state;
    if (current is! EditorLoaded) return;

    try {
      final existing = await _repository.getNoteById(current.noteId);
      final deltaJson = jsonEncode(event.content);

      final isEmpty =
          current.title.trim().isEmpty && event.plainText.trim().isEmpty;

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

      // Check if content is unchanged
      if (existing != null) {
        if (existing.title == current.title && existing.content == deltaJson) {
          AppLogger.i('EditorBloc: Discarding unchanged edit');
          emit(
            EditorDiscarded(noteId: current.isDirty ? current.noteId : null),
          );
          return;
        }
      }

      emit(current.copyWith(isSaving: true));

      final note = buildNote(
        current: current,
        deltaJson: deltaJson,
        plainText: event.plainText,
        existing: existing,
      );

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

  NoteModel buildNote({
    required EditorLoaded current,
    required String deltaJson,
    required String plainText,
    NoteModel? existing,
  }) {
    final now = DateTime.now();

    final trimmedText = plainText.trim();
    final previewText = trimmedText.length > Constants.noteTitleMaxLength
        ? trimmedText.substring(0, Constants.noteTitleMaxLength)
        : trimmedText;

    return NoteModel(
      id: current.noteId,
      title: current.title,
      content: deltaJson,
      plainText: plainText,
      previewText: previewText,
      height: _estimateHeight(plainText),
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
  }

  Future<void> _onAutoSaveRequested(
    EditorAutoSaveRequested event,
    Emitter<EditorState> emit,
  ) async {
    final current = state;
    if (current is! EditorLoaded) return;

    try {
      final existing = await _repository.getNoteById(current.noteId);
      final deltaJson = jsonEncode(event.content);

      // Don't auto-save if nothing changed
      if (existing != null &&
          existing.title == current.title &&
          existing.content == deltaJson) {
        return;
      }

      // Don't auto-save if new and empty
      if (current.isNewNote &&
          current.title.trim().isEmpty &&
          event.plainText.trim().isEmpty) {
        return;
      }

      final note = buildNote(
        current: current,
        deltaJson: deltaJson,
        plainText: event.plainText,
        existing: existing,
      );

      await _repository.upsertNote(note);

      AppLogger.i('EditorBloc: Auto-save success for ${current.noteId}');
      emit(
        current.copyWith(
          isDirty: true,
          isNewNote: current.isNewNote ? false : current.isNewNote,
        ),
      );
    } on DbFullException catch (e) {
      AppLogger.e('EditorBloc: Auto-save failed due to full database: $e');
      emit(const EditorFailure(ErrorCategory.storageFull));
    } catch (e) {
      AppLogger.e('EditorBloc: Auto-save failed: $e');
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
