import 'package:flutter/material.dart';
import 'package:widgets/widgets.dart';

/// Renders status, error, or empty messages within search.
class SearchMessageView extends StatelessWidget {
  final String message;
  final bool isError;
  final AlignmentGeometry alignment;
  final EdgeInsetsGeometry padding;

  const SearchMessageView({
    super.key,
    required this.message,
    this.isError = false,
    this.alignment = Alignment.topLeft,
    this.padding = const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
  });

  const SearchMessageView.centered({
    super.key,
    required this.message,
    this.isError = false,
  }) : alignment = Alignment.center,
       padding = EdgeInsets.zero;

  @override
  Widget build(BuildContext context) {
    final textColor = isError
        ? context.colorScheme.error
        : context.colorScheme.onSurfaceVariant.withValues(alpha: 0.7);

    return Align(
      alignment: alignment,
      child: Padding(
        padding: padding,
        child: Text(
          message,
          style:
              (context.textTheme.titleMedium ?? const TextStyle(fontSize: 18))
                  .copyWith(color: textColor, fontWeight: FontWeight.w400),
        ),
      ),
    );
  }
}
