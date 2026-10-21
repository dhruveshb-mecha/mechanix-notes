abstract class NotesEvent {}

class LoadNotes extends NotesEvent {}

class LoadMoreNotes extends NotesEvent {}

class RefreshNote extends NotesEvent {
  final String noteId;
  RefreshNote({required this.noteId});
}

class DeleteNotes extends NotesEvent {
  final List<String>? noteIds;
  DeleteNotes({this.noteIds});
}

class ToggleSelectionMode extends NotesEvent {}

class ToggleNoteSelection extends NotesEvent {
  final String noteId;
  ToggleNoteSelection({required this.noteId});
}

class SelectAllNotes extends NotesEvent {}

class ClearSelection extends NotesEvent {}

class TogglePinNote extends NotesEvent {
  final String noteId;
  TogglePinNote({required this.noteId});
}
