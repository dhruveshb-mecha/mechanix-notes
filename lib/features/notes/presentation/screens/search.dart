import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_notes/features/notes/bloc/search/search_bloc.dart';
import 'package:mechanix_notes/features/notes/data/models/note_metadata.dart';
import 'package:mechanix_notes/features/notes/data/repository/note_repository.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/search/search_view.dart';
import 'package:widgets/widgets.dart';

/// The top-level search screen providing [SearchBloc] and hosting [SearchView].
class SearchScreen extends StatelessWidget {
  const SearchScreen({
    super.key,
    this.emptyMessage,
    this.onResultSelected,
  });

  /// Custom empty state message when no notes match.
  final String? emptyMessage;

  /// Optional callback invoked when a result note is tapped.
  final ValueChanged<NoteMetaData>? onResultSelected;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          SearchBloc(noteRepository: context.read<NoteRepository>()),
      child: Scaffold(
        backgroundColor: context.colorScheme.surfaceContainerLowest,
        body: SearchView(
          emptyMessage: emptyMessage,
          onResultSelected: onResultSelected,
        ),
      ),
    );
  }
}
