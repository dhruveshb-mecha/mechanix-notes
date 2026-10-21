import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:mechanix_notes/features/notes/bloc/search/search_bloc.dart';
import 'package:mechanix_notes/features/notes/bloc/search/search_event.dart';
import 'package:mechanix_notes/features/notes/bloc/search/search_state.dart';
import 'package:mechanix_notes/features/notes/data/models/note_metadata.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/search/search_text_highlighter.dart';
import 'package:widgets/widgets.dart';

/// A scrollable list of search results with infinite scroll pagination.
class SearchListView extends StatefulWidget {
  const SearchListView({super.key, required this.query, this.onResultSelected});

  /// The active search query used for highlighting.
  final String query;

  /// Callback when a note result is tapped.
  final ValueChanged<NoteMetaData>? onResultSelected;

  @override
  State<SearchListView> createState() => _SearchListViewState();
}

class _SearchListViewState extends State<SearchListView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      final state = context.read<SearchBloc>().state;
      if (!state.isLoadingMore && state.hasMore) {
        context.read<SearchBloc>().add(LoadMoreSearchResults());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocSelector<SearchBloc, SearchState, List<NoteMetaData>>(
      selector: (state) => state.results,
      builder: (context, results) {
        return Scrollbar(
          controller: _scrollController,
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
            ),
            child: ListView.builder(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 24),
              itemCount: results.length,
              itemBuilder: (context, index) {
                final note = results[index];
                return SearchResultTile(
                  note: note,
                  query: widget.query,
                  onResultSelected: widget.onResultSelected,
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class SearchResultTile extends StatelessWidget {
  const SearchResultTile({
    super.key,
    required this.note,
    required this.query,
    this.onResultSelected,
  });

  final NoteMetaData note;
  final String query;
  final ValueChanged<NoteMetaData>? onResultSelected;

  @override
  Widget build(BuildContext context) {
    final displayTitle = note.title.isNotEmpty ? note.title : note.previewText;

    final subtitle =
        note.title.isNotEmpty &&
            note.previewText.isNotEmpty &&
            note.title != note.previewText
        ? note.previewText
        : null;

    final formattedDate = _formatDate(note.updatedAt);

    final titleStyle =
        (context.textTheme.titleLarge ??
                const TextStyle(fontSize: 20, height: 26 / 20))
            .copyWith(
              color: context.colorScheme.onSurface,
              fontWeight: FontWeight.w400,
            );

    final highlightStyle = titleStyle.copyWith(
      color: context.colorScheme.primary,
    );

    return MechanixListTile(
      variant: ListTileVariant.standard,
      label: Text.rich(
        SearchTextHighlighter.highlight(
          text: displayTitle,
          query: query,
          baseStyle: titleStyle,
          highlightStyle: highlightStyle,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      supportingText: subtitle,
      trailingText: formattedDate,
      trailingTextColor: context.colorScheme.onSurfaceVariant,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 32.0,
        vertical: 8.0,
      ),
      onTap: onResultSelected != null ? () => onResultSelected!(note) : null,
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (now.year != date.year) {
      return DateFormat('dd MMM yy').format(date).toUpperCase();
    }
    return DateFormat('dd MMM').format(date).toUpperCase();
  }
}
