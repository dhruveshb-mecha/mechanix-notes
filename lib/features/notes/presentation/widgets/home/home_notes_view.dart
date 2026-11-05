import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_bloc.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_state.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/home/home_empty_view.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/home/home_error_widget.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/home/home_list_view.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/home/home_loading_view.dart';

class HomeNotesView extends StatelessWidget {
  const HomeNotesView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotesBloc, NotesState>(
      buildWhen: (previous, current) =>
          previous.groupedNotes != current.groupedNotes ||
          previous.isLoading != current.isLoading ||
          previous.error != current.error,
      builder: (context, state) {
        if (state.isLoading) return const HomeLoadingView();
        if (state.error != null) {
          return HomeErrorView(error: state.error!);
        }
        if (state.groupedNotes.isEmpty) return const HomeEmptyView();
        return HomeListView(
          groupedNotes: state.groupedNotes,
          groupCounts: state.groupCounts,
        );
      },
    );
  }
}
