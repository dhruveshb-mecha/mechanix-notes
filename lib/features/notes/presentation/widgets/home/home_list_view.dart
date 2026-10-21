import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_notes/core/utils/enums.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_bloc.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_event.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_state.dart';
import 'package:mechanix_notes/features/notes/data/models/note_metadata.dart';
import 'package:mechanix_notes/features/notes/data/models/time_group.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/home/home_group_label.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/home/home_note_card.dart';
import 'package:widgets/widgets.dart';

class HomeListView extends StatefulWidget {
  const HomeListView({super.key, required this.groupedNotes});

  final List<dynamic> groupedNotes;

  @override
  State<HomeListView> createState() => _HomeListViewState();
}

class _HomeListViewState extends State<HomeListView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    final position = _scrollController.position;
    // Trigger when within 200 px of the bottom
    if (position.pixels >= position.maxScrollExtent - 200) {
      final state = context.read<NotesBloc>().state;
      if (!state.isLoadingMore && state.hasMore) {
        context.read<NotesBloc>().add(LoadMoreNotes());
      }
    }
  }

  List<_HomeGroupSection> _groupNotes(List<dynamic> items) {
    final sections = <_HomeGroupSection>[];
    _HomeGroupSection? current;

    for (final item in items) {
      if (item is TimeGroup) {
        current = _HomeGroupSection(group: item, notes: []);
        sections.add(current);
      } else if (item is NoteMetaData) {
        if (current == null) {
          current = _HomeGroupSection(
            group: const TimeGroup(TimeCategory.recent),
            notes: [],
          );
          sections.add(current);
        }
        current.notes.add(item);
      }
    }
    return sections;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<NotesBloc, NotesState>(
      listenWhen: (prev, curr) => curr.isRefreshed,
      listener: (context, state) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      },
      child: BlocBuilder<NotesBloc, NotesState>(
        buildWhen: (prev, curr) => prev.groupedNotes != curr.groupedNotes,
        builder: (context, state) {
          final sections = _groupNotes(
            state.groupedNotes.isNotEmpty
                ? state.groupedNotes
                : widget.groupedNotes,
          );

          return Scrollbar(
            controller: _scrollController,
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
              ),
              child: MechanixSwipableList(
                child: ListView.builder(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: sections.length,
                  itemBuilder: (context, index) {
                    final section = sections[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: HomeGroupHeader(
                        key: ValueKey(
                          'header_${section.group.category}_${section.group.customLabel}',
                        ),
                        group: section.group,
                        count: section.notes.length,
                        isFirst: index == 0,
                        children: section.notes
                            .expand(
                              (note) => [
                                Padding(
                                  padding: const EdgeInsets.all(0),
                                  child: HomeNoteCard(
                                    key: ValueKey(
                                      '${section.group.category.name}_${note.id}',
                                    ),
                                    note: note,
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                            )
                            .toList(),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HomeGroupSection {
  final TimeGroup group;
  final List<NoteMetaData> notes;

  _HomeGroupSection({required this.group, required this.notes});
}
