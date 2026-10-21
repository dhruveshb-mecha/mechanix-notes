part of 'editor_bloc.dart';

sealed class EditorState extends Equatable {
  const EditorState();

  @override
  List<Object?> get props => [];
}

final class EditorInitial extends EditorState {
  const EditorInitial();
}

final class EditorLoaded extends EditorState {
  final String noteId;
  final String title;
  final String markdownContent;
  final String lastSavedContent;
  final String lastSavedTitle;
  final bool lastSavedIsPinned;
  final DateTime? createdAt;
  final bool isContentLoading;
  final bool isSaving;
  final bool isNewNote;
  final bool isDirty;
  final bool isPinned;

  const EditorLoaded({
    required this.noteId,
    required this.title,
    this.markdownContent = '',
    this.lastSavedContent = '',
    this.lastSavedTitle = '',
    this.lastSavedIsPinned = false,
    this.createdAt,
    this.isContentLoading = false,
    this.isSaving = false,
    this.isNewNote = false,
    this.isDirty = false,
    this.isPinned = false,
  });

  EditorLoaded copyWith({
    String? noteId,
    String? title,
    String? markdownContent,
    String? lastSavedContent,
    String? lastSavedTitle,
    bool? lastSavedIsPinned,
    DateTime? createdAt,
    bool? isContentLoading,
    bool? isSaving,
    bool? isNewNote,
    bool? isDirty,
    bool? isPinned,
  }) {
    return EditorLoaded(
      noteId: noteId ?? this.noteId,
      title: title ?? this.title,
      markdownContent: markdownContent ?? this.markdownContent,
      lastSavedContent: lastSavedContent ?? this.lastSavedContent,
      lastSavedTitle: lastSavedTitle ?? this.lastSavedTitle,
      lastSavedIsPinned: lastSavedIsPinned ?? this.lastSavedIsPinned,
      createdAt: createdAt ?? this.createdAt,
      isContentLoading: isContentLoading ?? this.isContentLoading,
      isSaving: isSaving ?? this.isSaving,
      isNewNote: isNewNote ?? this.isNewNote,
      isDirty: isDirty ?? this.isDirty,
      isPinned: isPinned ?? this.isPinned,
    );
  }

  @override
  List<Object?> get props => [
    noteId,
    title,
    markdownContent,
    lastSavedContent,
    lastSavedTitle,
    lastSavedIsPinned,
    createdAt,
    isContentLoading,
    isSaving,
    isNewNote,
    isDirty,
    isPinned,
  ];
}

final class EditorFailure extends EditorState {
  final ErrorCategory error;

  const EditorFailure(this.error);

  @override
  List<Object?> get props => [error];
}

final class EditorSaveSuccess extends EditorState {
  final String noteId;

  const EditorSaveSuccess(this.noteId);

  @override
  List<Object?> get props => [noteId];
}

final class EditorDeleteRequest extends EditorState {
  final String noteId;

  const EditorDeleteRequest(this.noteId);

  @override
  List<Object?> get props => [noteId];
}

final class EditorDiscarded extends EditorState {
  final String? noteId;

  const EditorDiscarded({this.noteId});

  @override
  List<Object?> get props => [noteId];
}
