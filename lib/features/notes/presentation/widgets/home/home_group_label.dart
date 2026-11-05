import 'package:flutter/material.dart';
import 'package:mechanix_notes/core/utils/enums.dart';
import 'package:mechanix_notes/core/utils/helper.dart';
import 'package:mechanix_notes/features/notes/data/models/time_group.dart';
import 'package:widgets/widgets.dart';

class HomeGroupHeader extends StatelessWidget {
  const HomeGroupHeader({
    super.key,
    required this.group,
    this.count,
    this.isFirst = false,
    this.initiallyExpanded = true,
    this.onExpansionChanged,
    this.children = const <Widget>[],
  });

  final TimeGroup group;
  final int? count;
  final bool isFirst;
  final bool initiallyExpanded;
  final ValueChanged<bool>? onExpansionChanged;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final title = getLocalizedLabelForTimeNotes(context, group);
    final isRecent = group.category == TimeCategory.recent;
    final countVal = count ?? children.length;
    final countStr = countVal.toString().padLeft(2, '0');

    return MechanixExpandableListTile(
      key: ValueKey('tile_${group.category}_${group.customLabel}'),
      expandedContentGap: 0,
      label: SizedBox(
        height: 50,
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const MechanixDivider(space: 0),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.textTheme.headlineSmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                    fontSize: 20,
                    fontFamily: MechanixFontFamily.geist,
                  ),
                ),
                if (!isRecent && countVal > 0) ...[
                  const SizedBox(width: 8),
                  Transform.translate(
                    offset: const Offset(0, 3),
                    child: Text(
                      '[$countStr]',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const MechanixDivider(space: 0),
          ],
        ),
      ),
      height: 50,
      showAccordionButton: false,
      backgroundColor: context.colorScheme.surfaceContainerLowest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
      initiallyExpanded: initiallyExpanded,
      onExpansionChanged: onExpansionChanged,
      childrenPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      children: children,
    );
  }
}
