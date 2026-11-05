import 'package:equatable/equatable.dart';
import 'package:mechanix_notes/features/notes/data/models/note_metadata.dart';
import 'package:mechanix_notes/features/notes/data/models/time_group.dart';
import 'package:mechanix_notes/core/utils/enums.dart';

class NotesState extends Equatable {
  /// All notes, pinned first and then most recently updated.
  final List<NoteMetaData> notes;

  /// [notes] flattened with [TimeGroup] headers, in display order.
  final List<Object> groupedNotes;

  /// Number of notes under each header in [groupedNotes].
  final Map<TimeGroup, int> groupCounts;
  final bool isLoading;
  final ErrorCategory? error;
  final String localized;
  final bool isSelectionMode;
  final List<String> selectedNotes;

  const NotesState({
    this.notes = const [],
    this.groupedNotes = const [],
    this.groupCounts = const {},
    this.isLoading = true,
    this.error,
    this.localized = 'en',
    this.isSelectionMode = false,
    this.selectedNotes = const [],
  });

  NotesState copyWith({
    List<NoteMetaData>? notes,
    List<Object>? groupedNotes,
    Map<TimeGroup, int>? groupCounts,
    bool? isLoading,
    ErrorCategory? error,
    String? localized,
    bool? isSelectionMode,
    List<String>? selectedNotes,
  }) {
    return NotesState(
      notes: notes ?? this.notes,
      groupedNotes: groupedNotes ?? this.groupedNotes,
      groupCounts: groupCounts ?? this.groupCounts,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      localized: localized ?? this.localized,
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
      selectedNotes: selectedNotes ?? this.selectedNotes,
    );
  }

  @override
  List<Object?> get props => [
    notes,
    groupedNotes,
    groupCounts,
    isLoading,
    error,
    localized,
    isSelectionMode,
    selectedNotes,
  ];
}
