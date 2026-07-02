import 'package:mechanix_notes/features/notes/data/models/note_metadata.dart';
import 'package:mechanix_notes/features/notes/data/models/note_model.dart';

abstract class NoteRepository {
  Future<List<NoteMetaData>> getNotes(int skip, int take);
  Future<NoteMetaData?> getNoteMetaData(String id);
  Future<NoteModel?> getNoteById(String id);
  Future<void> deleteNotes(List<String> ids);
  Future<void> upsertNote(NoteModel note);
  Future<List<NoteMetaData>> searchNotes(String query);
}
