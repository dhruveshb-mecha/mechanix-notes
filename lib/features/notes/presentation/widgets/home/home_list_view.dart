import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SliverLayoutDimensions;
import 'package:mechanix_notes/features/notes/data/models/note_metadata.dart';
import 'package:mechanix_notes/features/notes/data/models/time_group.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/home/home_group_label.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/home/home_note_card.dart';
import 'package:widgets/widgets.dart';

const double _cardGap = 16;
const double _sectionGap = 24;

/// Gap between an expanded group header and its first note.
const double _headerGap = 12;

/// Rendered height of [HomeNoteCard] and [HomeGroupHeader]: their 50px tile
@visibleForTesting
const double homeTileHeight = 52;

class HomeListView extends StatefulWidget {
  const HomeListView({
    super.key,
    required this.groupedNotes,
    required this.groupCounts,
  });

  /// Flattened [TimeGroup] headers and [NoteMetaData] notes, in display order.
  final List<dynamic> groupedNotes;

  /// Number of notes under each header in [groupedNotes].
  final Map<TimeGroup, int> groupCounts;

  @override
  State<HomeListView> createState() => _HomeListViewState();
}

class _HomeListViewState extends State<HomeListView> {
  final ScrollController _scrollController = ScrollController();
  final Set<TimeGroup> _collapsedGroups = {};

  /// [HomeListView.groupedNotes] without the notes of collapsed groups.
  late List<dynamic> _items = widget.groupedNotes;

  /// Item index by key, built only when the list asks for it after a change.
  Map<Key, int>? _indexByKey;

  @override
  void didUpdateWidget(HomeListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.groupedNotes != widget.groupedNotes) _updateItems();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _updateItems() {
    _indexByKey = null;
    if (_collapsedGroups.isEmpty) {
      _items = widget.groupedNotes;
      return;
    }

    final items = <dynamic>[];
    TimeGroup? group;
    for (final item in widget.groupedNotes) {
      if (item is TimeGroup) {
        group = item;
        items.add(item);
      } else if (!_collapsedGroups.contains(group)) {
        items.add(item);
      }
    }
    _items = items;
  }

  void _onExpansionChanged(TimeGroup group, bool isExpanded) {
    setState(() {
      if (isExpanded) {
        _collapsedGroups.remove(group);
      } else {
        _collapsedGroups.add(group);
      }
      _updateItems();
    });
  }

  static Key _keyFor(Object item) => item is NoteMetaData
      ? ValueKey<String>(item.id)
      : ValueKey<TimeGroup>(item as TimeGroup);

  /// Exact item heights let the list jump straight to any offset
  /// instead of building every item in between, and keep the scrollbar thumb's size and position accurate.
  double _itemExtent(int index, SliverLayoutDimensions dimensions) {
    final item = _items[index];
    if (item is TimeGroup) {
      return homeTileHeight +
          _GroupHeaderItem.bottomGap(
            isCollapsed: _collapsedGroups.contains(item),
            count: widget.groupCounts[item] ?? 0,
          );
    }
    return homeTileHeight +
        _NoteItem.bottomGap(isLastInGroup: _isLastInGroup(index));
  }

  bool _isLastInGroup(int index) =>
      index == _items.length - 1 || _items[index + 1] is TimeGroup;

  /// Lets the list keep each item's state (swipe, expansion) when notes move,
  int? _findChildIndex(Key key) {
    final indexByKey = _indexByKey ??= {
      for (var i = 0; i < _items.length; i++) _keyFor(_items[i]): i,
    };
    return indexByKey[key];
  }

  @override
  Widget build(BuildContext context) {
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
            itemCount: _items.length,
            findChildIndexCallback: _findChildIndex,
            itemExtentBuilder: _itemExtent,
            itemBuilder: (context, index) {
              final item = _items[index];
              if (item is TimeGroup) {
                return _GroupHeaderItem(
                  key: _keyFor(item),
                  group: item,
                  count: widget.groupCounts[item] ?? 0,
                  isCollapsed: _collapsedGroups.contains(item),
                  onExpansionChanged: _onExpansionChanged,
                );
              }
              return _NoteItem(
                key: _keyFor(item),
                note: item as NoteMetaData,
                isLastInGroup: _isLastInGroup(index),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _GroupHeaderItem extends StatelessWidget {
  const _GroupHeaderItem({
    super.key,
    required this.group,
    required this.count,
    required this.isCollapsed,
    required this.onExpansionChanged,
  });

  final TimeGroup group;
  final int count;
  final bool isCollapsed;
  final void Function(TimeGroup group, bool isExpanded) onExpansionChanged;

  static double bottomGap({required bool isCollapsed, required int count}) =>
      (isCollapsed ? 0 : _headerGap) +
      (isCollapsed || count == 0 ? _sectionGap : 0);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: bottomGap(isCollapsed: isCollapsed, count: count),
      ),
      child: HomeGroupHeader(
        group: group,
        count: count,
        initiallyExpanded: !isCollapsed,
        onExpansionChanged: (isExpanded) =>
            onExpansionChanged(group, isExpanded),
      ),
    );
  }
}

class _NoteItem extends StatelessWidget {
  const _NoteItem({super.key, required this.note, required this.isLastInGroup});

  final NoteMetaData note;
  final bool isLastInGroup;

  static double bottomGap({required bool isLastInGroup}) =>
      isLastInGroup ? _cardGap + _sectionGap : _cardGap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        10,
        0,
        10,
        bottomGap(isLastInGroup: isLastInGroup),
      ),
      child: HomeNoteCard(note: note),
    );
  }
}
