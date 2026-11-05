abstract class NotesEvent {}

/// Starts watching the notes in the repository. The list then stays up to
/// date on its own whenever a note is created, edited, pinned or deleted.
class LoadNotes extends NotesEvent {}

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
