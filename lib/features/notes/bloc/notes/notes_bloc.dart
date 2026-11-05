import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:mechanix_notes/core/exceptions/objectbox_exception.dart';
import 'package:mechanix_notes/core/utils/app_logger.dart';
import 'package:mechanix_notes/core/utils/enums.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_event.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_state.dart';
import 'package:mechanix_notes/features/notes/data/models/note_metadata.dart';
import 'package:mechanix_notes/features/notes/data/models/time_group.dart';
import 'package:mechanix_notes/features/notes/data/repository/note_repository.dart';

class NotesBloc extends Bloc<NotesEvent, NotesState> {
  final NoteRepository noteRepository;
  final DateTime Function() clock;

  NotesBloc({required this.noteRepository, DateTime Function()? clock})
    : clock = clock ?? DateTime.now,
      super(const NotesState()) {
    on<LoadNotes>(_loadNotes, transformer: restartable());
    on<DeleteNotes>(_deleteNotes);
    on<ToggleSelectionMode>(_toggleSelectionMode);
    on<ToggleNoteSelection>(_toggleNoteSelection);
    on<SelectAllNotes>(_selectAllNotes);
    on<ClearSelection>(_clearSelection);
    on<TogglePinNote>(_togglePinNote);

    add(LoadNotes());
  }

  Future<void> _loadNotes(LoadNotes event, Emitter<NotesState> emit) async {
    emit(state.copyWith(isLoading: true));

    await emit.forEach<List<NoteMetaData>>(
      noteRepository.watchNotes(),
      onData: (notes) {
        final (groupedNotes, groupCounts) = _buildFlattenedNotes(notes);
        return state.copyWith(
          notes: notes,
          groupedNotes: groupedNotes,
          groupCounts: groupCounts,
          isLoading: false,
          selectedNotes: _existingSelection(notes),
        );
      },
      onError: (e, _) {
        AppLogger.e("Error loading notes: $e");
        return state.copyWith(
          isLoading: false,
          error: e is ObjectBoxException
              ? ErrorCategory.appAlreadyRunning
              : ErrorCategory.failedToLoadNotes,
        );
      },
    );
  }

  /// Drops selected ids whose notes no longer exist.
  List<String> _existingSelection(List<NoteMetaData> notes) {
    if (state.selectedNotes.isEmpty) return state.selectedNotes;
    final ids = notes.map((n) => n.id).toSet();
    return state.selectedNotes.where(ids.contains).toList();
  }

  /// Returns the notes with a [TimeGroup] header before each group, and the
  /// number of notes in each group.
  (List<Object>, Map<TimeGroup, int>) _buildFlattenedNotes(
    List<NoteMetaData> notes,
  ) {
    final List<Object> flattened = [];
    final Map<TimeGroup, int> counts = {};
    final now = clock();
    final today = DateTime(now.year, now.month, now.day);
    final monthYear = DateFormat("MMMM yyyy", state.localized);
    TimeGroup? currentGroup;

    // Notes arrive pinned first, then by updatedAt descending, so each group
    // is contiguous
    for (final note in notes) {
      final group = note.isPinned
          ? const TimeGroup(TimeCategory.pinned)
          : _getTimeGroupForNote(note, now, today, monthYear);
      if (group != currentGroup) {
        flattened.add(group);
        currentGroup = group;
      }
      flattened.add(note);
      counts[group] = (counts[group] ?? 0) + 1;
    }

    return (flattened, counts);
  }

  Future<void> _togglePinNote(
    TogglePinNote event,
    Emitter<NotesState> emit,
  ) async {
    try {
      await noteRepository.togglePinNote(event.noteId);
    } catch (e) {
      AppLogger.e("Error toggling pin note: $e");
    }
  }

  Future<void> _deleteNotes(DeleteNotes event, Emitter<NotesState> emit) async {
    try {
      final ids = event.noteIds ?? List<String>.from(state.selectedNotes);
      if (ids.isEmpty) return;

      AppLogger.i("Deleting ${ids.length} notes");
      await noteRepository.deleteNotes(ids);

      emit(state.copyWith(selectedNotes: const [], isSelectionMode: false));
    } catch (e) {
      AppLogger.e("Error deleting notes: $e");
      emit(state.copyWith(error: ErrorCategory.failedToDeleteNotes));
    }
  }

  void _toggleSelectionMode(
    ToggleSelectionMode event,
    Emitter<NotesState> emit,
  ) {
    emit(
      state.copyWith(
        isSelectionMode: !state.isSelectionMode,
        selectedNotes: state.isSelectionMode ? const [] : state.selectedNotes,
      ),
    );
  }

  void _toggleNoteSelection(
    ToggleNoteSelection event,
    Emitter<NotesState> emit,
  ) {
    final selected = List<String>.from(state.selectedNotes);
    if (selected.contains(event.noteId)) {
      selected.remove(event.noteId);
    } else {
      selected.add(event.noteId);
    }

    final isSelectionMode = state.isSelectionMode || selected.isNotEmpty;

    emit(
      state.copyWith(selectedNotes: selected, isSelectionMode: isSelectionMode),
    );
  }

  void _selectAllNotes(SelectAllNotes event, Emitter<NotesState> emit) {
    final allNoteIds = state.notes.map((n) => n.id).toList();
    if (state.selectedNotes.length == allNoteIds.length) {
      emit(state.copyWith(selectedNotes: const [], isSelectionMode: false));
    } else {
      emit(state.copyWith(selectedNotes: allNoteIds, isSelectionMode: true));
    }
  }

  void _clearSelection(ClearSelection event, Emitter<NotesState> emit) {
    emit(state.copyWith(selectedNotes: const [], isSelectionMode: false));
  }

  TimeGroup _getTimeGroupForNote(
    NoteMetaData note,
    DateTime now,
    DateTime today,
    DateFormat monthYear,
  ) {
    final updated = note.updatedAt;
    final dateOnly = DateTime(updated.year, updated.month, updated.day);
    final daysAgo = today.difference(dateOnly).inDays;
    final hoursAgo = now.difference(updated).inHours;

    return switch (true) {
      _ when hoursAgo < 2 => const TimeGroup(TimeCategory.recent),
      _ when daysAgo == 0 => const TimeGroup(TimeCategory.today),
      _ when daysAgo == 1 => const TimeGroup(TimeCategory.yesterday),
      _ when daysAgo <= 7 => const TimeGroup(TimeCategory.last7Days),
      _ when daysAgo <= 30 => const TimeGroup(TimeCategory.lastMonth),
      _ => TimeGroup(TimeCategory.custom, monthYear.format(updated)),
    };
  }
}
