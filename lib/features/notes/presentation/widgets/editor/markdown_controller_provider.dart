import 'package:flutter/widgets.dart';
import 'package:live_markdown_editor/live_markdown_editor.dart';

/// A widget that provides a [MarkdownEditorController] and [FocusNode] to its children.
class MarkdownControllerProvider extends InheritedWidget {
  final MarkdownEditorController controller;
  final FocusNode focusNode;

  const MarkdownControllerProvider({
    super.key,
    required this.controller,
    required this.focusNode,
    required super.child,
  });

  /// Returns the nearest [MarkdownControllerProvider] ancestor.
  /// Throws a [FlutterError] if none is found (fail-fast in debug).
  static MarkdownControllerProvider of(BuildContext context) {
    final result = context
        .dependOnInheritedWidgetOfExactType<MarkdownControllerProvider>();
    assert(
      result != null,
      'No MarkdownControllerProvider found in context.\n'
      'Make sure EditorScreen (or a parent) wraps its subtree with '
      'MarkdownControllerProvider.',
    );
    return result!;
  }

  /// Returns null if no [MarkdownControllerProvider] is found.
  /// Prefer [of] inside the editor subtree; use this only for optional access.
  static MarkdownControllerProvider? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<MarkdownControllerProvider>();
  }

  @override
  bool updateShouldNotify(MarkdownControllerProvider oldWidget) =>
      controller != oldWidget.controller || focusNode != oldWidget.focusNode;
}
