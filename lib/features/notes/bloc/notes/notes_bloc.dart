import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:mechanix_notes/core/exceptions/objectbox_exception.dart';
import 'package:mechanix_notes/core/utils/app_logger.dart';
import 'package:mechanix_notes/core/utils/constants.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_event.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_state.dart';
import 'package:mechanix_notes/features/notes/data/models/note_metadata.dart';
import 'package:mechanix_notes/features/notes/data/models/time_group.dart';
import 'package:mechanix_notes/features/notes/data/repository/note_repository.dart';
import 'package:mechanix_notes/core/utils/enums.dart';

class NotesBloc extends Bloc<NotesEvent, NotesState> {
  final NoteRepository noteRepository;

  NotesBloc({required this.noteRepository}) : super(const NotesState()) {
    on<LoadNotes>(_loadNotes);
    on<LoadMoreNotes>(_loadMoreNotes);
    on<RefreshNote>(_refreshNote);
    on<DeleteNotes>(_deleteNotes);
    on<ToggleSelectionMode>(_toggleSelectionMode);
    on<ToggleNoteSelection>(_toggleNoteSelection);
    on<SelectAllNotes>(_selectAllNotes);
    on<ClearSelection>(_clearSelection);

    add(LoadNotes());
  }

  Future<void> _loadNotes(LoadNotes event, Emitter<NotesState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));
    AppLogger.i("Loading notes");

    try {
      final firstPage = await noteRepository.getNotes(
        0,
        Constants.pageSize,
      );
      final flattened = _buildFlattenedNotes(firstPage);
      final hasMore = firstPage.length == Constants.pageSize;
      AppLogger.i(
        "Notes loaded — showing ${firstPage.length}, hasMore: $hasMore",
      );
      emit(
        state.copyWith(
          notes: firstPage,
          groupedNotes: flattened,
          isLoading: false,
          hasMore: hasMore,
          currentPage: 0,
        ),
      );
    } on ObjectBoxException catch (e) {
      AppLogger.e("App already running: $e");
      emit(
        state.copyWith(
          isLoading: false,
          error: ErrorCategory.appAlreadyRunning,
        ),
      );
    } catch (e) {
      AppLogger.e("Error loading notes: $e");
      emit(
        state.copyWith(
          isLoading: false,
          error: ErrorCategory.failedToLoadNotes,
        ),
      );
    }
  }

  Future<void> _loadMoreNotes(
    LoadMoreNotes event,
    Emitter<NotesState> emit,
  ) async {
    try {
      if (state.isLoadingMore || !state.hasMore) return;
      AppLogger.i("Loading more notes");
      emit(state.copyWith(isLoadingMore: true));
      
      final currentCount = state.groupedNotes.whereType<NoteMetaData>().length;

      final newBatch = await noteRepository.getNotes(
        currentCount,
        Constants.pageSize,
      );

      if (newBatch.isEmpty) {
        emit(state.copyWith(isLoadingMore: false, hasMore: false));
        return;
      }

      final lastNote = state.groupedNotes.whereType<NoteMetaData>().last;
      final lastGroup = _getTimeGroupForNote(lastNote);
      final newEntries = _buildFlattenedNotes(
        newBatch,
        existingGroup: lastGroup,
      );

      emit(
        state.copyWith(
          notes: [...state.notes, ...newBatch],
          groupedNotes: [...state.groupedNotes, ...newEntries],
          isLoadingMore: false,
          hasMore: newBatch.length == Constants.pageSize,
          currentPage: state.currentPage + 1,
        ),
      );
    } catch (e) {
      AppLogger.e("Error loading more notes: $e");
      emit(state.copyWith(isLoadingMore: false));
    }
  }

  List<Object> _buildFlattenedNotes(
    List<NoteMetaData> notes, {
    TimeGroup? existingGroup,
  }) {
    if (notes.isEmpty) return [];

    final List<Object> flattened = [];
    TimeGroup? currentGroup = existingGroup;

    for (final note in notes) {
      final group = _getTimeGroupForNote(note);
      if (group != currentGroup) {
        flattened.add(group);
        currentGroup = group;
      }
      flattened.add(note);
    }

    return flattened;
  }

  /// Reloads the edited note
  Future<void> _refreshNote(RefreshNote event, Emitter<NotesState> emit) async {
    try {
      AppLogger.i("Refreshing note ${event.noteId}");
      final updatedNote = await noteRepository.getNoteMetaData(event.noteId);
      if (updatedNote == null) return;
      final group = _getTimeGroupForNote(updatedNote);

      if (group.category != TimeCategory.recent) return;
      emit(state.copyWith(isRefreshed: false));

      // Remove old entry and insert updated note at top (most recently updated)
      final updatedNotes = [
        updatedNote,
        ...state.notes.where((n) => n.id != event.noteId),
      ];

      // Reset pagination to first page only
      final firstPage = updatedNotes.take(Constants.pageSize).toList();
      final flattened = _buildFlattenedNotes(firstPage);
      final hasMore = updatedNotes.length > Constants.pageSize;

      AppLogger.i("Refreshing note completed ");

      emit(
        state.copyWith(
          notes: updatedNotes,
          groupedNotes: flattened,
          hasMore: hasMore,
          currentPage: 0,
          isRefreshed: true,
        ),
      );
    } catch (e) {
      AppLogger.e("Error refreshing note: $e");
    }
  }

  Future<void> _deleteNotes(DeleteNotes event, Emitter<NotesState> emit) async {
    try {
      emit(state.copyWith(isRefreshed: false));

      final selectedNotes = state.isSelectionMode
          ? List<String>.from(state.selectedNotes)
          : event.noteIds ?? [];

      AppLogger.i("Deleting notes: total notes ${state.notes.length}");

      if (selectedNotes.isEmpty) return;

      await noteRepository.deleteNotes(selectedNotes);
      final updatedNotes = state.notes
          .where((n) => !selectedNotes.contains(n.id))
          .toList();

      final firstPage = updatedNotes.take(Constants.pageSize).toList();
      final flattened = _buildFlattenedNotes(firstPage);
      final hasMore = updatedNotes.length > Constants.pageSize;

      AppLogger.i("Notes deleted — ${updatedNotes.length} notes remaining");

      emit(
        state.copyWith(
          notes: updatedNotes,
          groupedNotes: flattened,
          hasMore: hasMore,
          currentPage: 0,
          selectedNotes: const [],
          isSelectionMode: false,
          isRefreshed: true,
        ),
      );
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
    final paginatedNoteIds = state.groupedNotes
        .whereType<NoteMetaData>()
        .map((n) => n.id)
        .toList();
    if (state.selectedNotes.length == paginatedNoteIds.length) {
      emit(state.copyWith(selectedNotes: const [], isSelectionMode: false));
    } else {
      emit(
        state.copyWith(selectedNotes: paginatedNoteIds, isSelectionMode: true),
      );
    }
  }

  void _clearSelection(ClearSelection event, Emitter<NotesState> emit) {
    emit(state.copyWith(selectedNotes: const [], isSelectionMode: false));
  }

  TimeGroup _getTimeGroupForNote(NoteMetaData note) {
    final now = DateTime.now();
    final updated = note.updatedAt;
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(updated.year, updated.month, updated.day);
    final daysAgo = today.difference(dateOnly).inDays;
    final hoursAgo = now.difference(updated).inHours;

    final group = switch (true) {
      _ when hoursAgo < 2 => const TimeGroup(TimeCategory.recent),
      _ when daysAgo == 0 => const TimeGroup(TimeCategory.today),
      _ when daysAgo <= 7 => const TimeGroup(TimeCategory.last7Days),
      _ when daysAgo <= 30 => const TimeGroup(TimeCategory.lastMonth),
      _ => TimeGroup(
        TimeCategory.custom,
        DateFormat("MMMM yyyy", state.localized).format(updated),
      ),
    };

    AppLogger.i(
      "Time group for note ${note.id}: ${group.category} ${group.customLabel} $updated",
    );
    return group;
  }
}
