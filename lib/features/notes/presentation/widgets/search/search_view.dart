import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_notes/core/utils/app_routes.dart';
import 'package:mechanix_notes/features/notes/bloc/search/search_bloc.dart';
import 'package:mechanix_notes/features/notes/bloc/search/search_event.dart';
import 'package:mechanix_notes/features/notes/data/models/note_metadata.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/search/search_bar.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/search/search_list.dart';

/// The core Search View widget controlling the search workflow, debouncing,
/// transitions between collapsed and active modes, and rendering results.
class SearchView extends StatefulWidget {
  const SearchView({
    super.key,
    this.emptyMessage,
    this.onResultSelected,
    this.onClose,
  });

  /// Text shown when no search results match.
  final String? emptyMessage;

  /// Optional callback invoked when a result is tapped.
  final ValueChanged<NoteMetaData>? onResultSelected;

  /// Optional callback when search mode is closed.
  final VoidCallback? onClose;

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  static const Duration _debounceDuration = Duration(milliseconds: 250);

  late final TextEditingController _searchController;
  late final FocusNode _focusNode;
  bool _isSearchActive = true;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _focusNode = FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    setState(() {}); // Re-render to reflect empty/active query state
    _debounceTimer?.cancel();

    // Instant clear when query is cleared or empty (bypass debounce)
    if (query.trim().isEmpty) {
      context.read<SearchBloc>().add(ClearSearch());
      return;
    }

    _debounceTimer = Timer(_debounceDuration, () {
      if (!mounted) return;
      context.read<SearchBloc>().add(SearchQueryChanged(query: query));
    });
  }

  void _onSubmitted(String query) {
    _debounceTimer?.cancel();
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      context.read<SearchBloc>().add(ClearSearch());
    } else {
      context.read<SearchBloc>().add(SearchQueryChanged(query: trimmed));
    }
  }

  void _onClear() {
    _debounceTimer?.cancel();
    _searchController.clear();
    setState(() {});
    context.read<SearchBloc>().add(ClearSearch());
  }

  void _onClose() {
    _debounceTimer?.cancel();
    if (widget.onClose != null) {
      widget.onClose!();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _isSearchActive = false;
        _searchController.clear();
      });
      context.read<SearchBloc>().add(ClearSearch());
    }
  }

  void _onSearchIconTap() {
    setState(() {
      _isSearchActive = true;
    });
    _focusNode.requestFocus();
  }

  void _handleResultSelected(NoteMetaData note) {
    if (widget.onResultSelected != null) {
      widget.onResultSelected!(note);
      return;
    }

    Navigator.pushNamed(
      context,
      AppRoutes.noteEditor,
      arguments: {'noteId': note.id, 'noteTitle': note.title},
    ).then((_) {
      if (mounted && _searchController.text.isNotEmpty) {
        final searchBloc = context.read<SearchBloc>();
        final currentQuery = searchBloc.state.query.isNotEmpty
            ? searchBloc.state.query
            : _searchController.text.trim();
        searchBloc.add(SearchQueryChanged(query: currentQuery));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_searchController.text.isNotEmpty) {
          _onClear();
        } else if (_isSearchActive) {
          _onClose();
        } else if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      },
      child: SafeArea(
        child: Column(
          children: [
            SearchAppBar(
              isSearchActive: _isSearchActive,
              controller: _searchController,
              focusNode: _focusNode,
              onQueryChanged: _onQueryChanged,
              onSubmitted: _onSubmitted,
              onClear: _onClear,
              onClose: _onClose,
              onSearchIconTap: _onSearchIconTap,
            ),
            Expanded(
              child: _isSearchActive
                  ? SearchList(
                      query: _searchController.text,
                      emptyMessage: widget.emptyMessage,
                      onResultSelected: _handleResultSelected,
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
