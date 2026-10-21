import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_notes/features/notes/bloc/search/search_bloc.dart';
import 'package:mechanix_notes/features/notes/bloc/search/search_state.dart';
import 'package:mechanix_notes/features/notes/data/models/note_metadata.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/search/search_list_view.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/search/search_message_view.dart';
import 'package:mechanix_notes/l10n/notes_localizations.dart';

/// The container widget displaying the results, empty state, or loading state
/// based on the current [SearchBloc] state.
class SearchList extends StatelessWidget {
  const SearchList({
    super.key,
    required this.query,
    this.emptyMessage,
    this.onResultSelected,
  });

  /// The active query string.
  final String query;

  /// Message to show when no matches are found.
  final String? emptyMessage;

  /// Callback when a note result is tapped.
  final ValueChanged<NoteMetaData>? onResultSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final resolvedEmptyMessage =
        emptyMessage ?? l10n?.noNotesFound ?? 'No notes found';

    return BlocBuilder<SearchBloc, SearchState>(
      builder: (context, state) {
        // Active, empty query state: clean slate waiting for input
        if (state.status == SearchStatus.initial || query.trim().isEmpty) {
          return const SizedBox.shrink();
        }

        // Loading state
        if (state.status == SearchStatus.loading && state.results.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        // Error state
        if (state.status == SearchStatus.failure) {
          return SearchMessageView.centered(
            message:
                l10n?.failedToPerformSearch ?? 'Failed to perform search',
            isError: true,
          );
        }

        // Active, query with no matches
        if (state.results.isEmpty) {
          return SearchMessageView(message: resolvedEmptyMessage);
        }

        // Active, query with matches
        return SearchListView(query: query, onResultSelected: onResultSelected);
      },
    );
  }
}
