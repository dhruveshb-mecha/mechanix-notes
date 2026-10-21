import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:live_markdown_editor/live_markdown_editor.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/editor/bottom_bar/notes_text_link_control.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/editor/markdown_controller_provider.dart';
import 'package:widgets/widgets.dart';

class EditorBottomBar extends StatefulWidget {
  const EditorBottomBar({super.key});

  @override
  State<EditorBottomBar> createState() => _EditorBottomBarState();
}

class _EditorBottomBarState extends State<EditorBottomBar> {
  static const int _flagH1 = 1 << 0;
  static const int _flagH2 = 1 << 1;
  static const int _flagChecklist = 1 << 2;
  static const int _flagCode = 1 << 3;
  static const int _flagBold = 1 << 4;
  static const int _flagItalic = 1 << 5;
  static const int _flagStrikethrough = 1 << 6;
  static const int _flagBody = 1 << 7;

  static final _hPrefixRegex = RegExp(r'^#{1,6}\s+');
  static final _taskPrefixRegex = RegExp(r'^[-+*]\s+\[[ xX]\]\s+');
  static final _bulletPrefixRegex = RegExp(r'^[-+*]\s+');
  static final _orderedPrefixRegex = RegExp(r'^\d+[.)]\s+');
  static final _quotePrefixRegex = RegExp(r'^>\s+');

  MarkdownEditorController? _controller;
  int _currentMask = _flagBody;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newController = MarkdownControllerProvider.maybeOf(
      context,
    )?.controller;
    if (newController != _controller) {
      _controller?.removeListener(_onControllerChanged);
      _controller = newController;
      _controller?.addListener(_onControllerChanged);
      _currentMask = _computeStyleMask();
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    final newMask = _computeStyleMask();
    if (newMask != _currentMask) {
      setState(() {
        _currentMask = newMask;
      });
    }
  }

  static String _stripLinePrefix(String line) {
    return line
        .replaceFirst(_hPrefixRegex, '')
        .replaceFirst(_taskPrefixRegex, '')
        .replaceFirst(_bulletPrefixRegex, '')
        .replaceFirst(_orderedPrefixRegex, '')
        .replaceFirst(_quotePrefixRegex, '');
  }

  ({int lineStart, int lineEnd, String currentLine, int clampedCaret})
  _getLineInfo(MarkdownEditorController controller) {
    final text = controller.text;
    final sel = controller.selection;
    final caret = sel.isValid ? sel.start : 0;
    final clampedCaret = caret.clamp(0, text.length);

    final lineStart = clampedCaret == 0
        ? 0
        : text.lastIndexOf('\n', clampedCaret - 1) + 1;
    final nextNewline = text.indexOf('\n', clampedCaret);
    final lineEnd = nextNewline < 0 ? text.length : nextNewline;
    final currentLine = text.substring(lineStart, lineEnd);
    return (
      lineStart: lineStart,
      lineEnd: lineEnd,
      currentLine: currentLine,
      clampedCaret: clampedCaret,
    );
  }

  int _computeStyleMask() {
    final controller = _controller;
    if (controller == null) return _flagBody;

    final info = _getLineInfo(controller);
    final currentLine = info.currentLine;
    final clampedCaret = info.clampedCaret;
    final sel = controller.selection;
    final text = controller.text;

    final isH1 = currentLine.startsWith('# ') && !currentLine.startsWith('## ');
    final isH2 =
        currentLine.startsWith('## ') && !currentLine.startsWith('### ');
    final isChecklist =
        currentLine.trimLeft().startsWith('- [ ] ') ||
        currentLine.trimLeft().startsWith('- [x] ') ||
        currentLine.trimLeft().startsWith('- [X] ');

    var isCode = currentLine.trim().startsWith('```');
    final doc = controller.document;

    // Find the single containing block for the caret in one pass
    MarkdownBlockNode? activeBlock;
    for (final block in doc.blocks) {
      if (block.range.contains(clampedCaret)) {
        activeBlock = block;
        break;
      }
    }

    if (!isCode && activeBlock != null) {
      if (activeBlock.type == MarkdownBlockType.fencedCode ||
          activeBlock.type == MarkdownBlockType.indentedCode) {
        isCode = true;
      }
    }

    final isBody = !isH1 && !isH2 && !isChecklist && !isCode;

    // Evaluate selection delimiters once if text is selected
    String? selectedText;
    if (sel.isValid &&
        !sel.isCollapsed &&
        sel.start >= 0 &&
        sel.end <= text.length) {
      selectedText = text.substring(sel.start, sel.end);
    }

    bool hasDelim(String delim) {
      if (selectedText == null) return false;
      return selectedText.startsWith(delim) &&
          selectedText.endsWith(delim) &&
          selectedText.length >= delim.length * 2;
    }

    var isBold = hasDelim('**');
    var isItalic = hasDelim('*');
    var isStrikethrough = hasDelim('~~');

    // Single-pass inline node inspection on the active block only
    if (activeBlock != null) {
      for (final node in activeBlock.inlineNodes) {
        if (node.range.contains(clampedCaret)) {
          switch (node.type) {
            case MarkdownInlineType.bold:
              isBold = true;
            case MarkdownInlineType.italic:
              isItalic = true;
            case MarkdownInlineType.strikethrough:
              isStrikethrough = true;
            default:
              break;
          }
        }
      }
    }

    var mask = 0;
    if (isH1) mask |= _flagH1;
    if (isH2) mask |= _flagH2;
    if (isChecklist) mask |= _flagChecklist;
    if (isCode) mask |= _flagCode;
    if (isBold) mask |= _flagBold;
    if (isItalic) mask |= _flagItalic;
    if (isStrikethrough) mask |= _flagStrikethrough;
    if (isBody) mask |= _flagBody;
    return mask;
  }

  static void _replaceLine(
    MarkdownEditorController controller,
    int lineStart,
    int lineEnd,
    String newLine,
    int clampedCaret,
  ) {
    final text = controller.text;
    final newText = text.replaceRange(lineStart, lineEnd, newLine);
    final delta = newLine.length - (lineEnd - lineStart);
    final newCaret = math.max(
      0,
      math.min(clampedCaret + delta, newText.length),
    );
    controller.applyEditingValue(
      TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newCaret),
      ),
    );
  }

  static void _replaceRange(
    MarkdownEditorController controller,
    int start,
    int end,
    String replacement,
  ) {
    final text = controller.text;
    final newText = text.replaceRange(start, end, replacement);
    controller.applyEditingValue(
      TextEditingValue(
        text: newText,
        selection: TextSelection(
          baseOffset: start,
          extentOffset: start + replacement.length,
        ),
      ),
    );
  }

  void _toggleHeader(int level) {
    final provider = MarkdownControllerProvider.maybeOf(context);
    if (provider == null) return;
    final controller = provider.controller;
    final info = _getLineInfo(controller);
    final isH1Active = (_currentMask & _flagH1) != 0;
    final isH2Active = (_currentMask & _flagH2) != 0;

    final prefix = '${'#' * level} ';
    if ((level == 1 && isH1Active) || (level == 2 && isH2Active)) {
      _replaceLine(
        controller,
        info.lineStart,
        info.lineEnd,
        _stripLinePrefix(info.currentLine),
        info.clampedCaret,
      );
    } else {
      final clean = _stripLinePrefix(info.currentLine);
      _replaceLine(
        controller,
        info.lineStart,
        info.lineEnd,
        '$prefix$clean',
        info.clampedCaret,
      );
    }
    provider.focusNode.requestFocus();
  }

  void _clearToParagraph() {
    final provider = MarkdownControllerProvider.maybeOf(context);
    if (provider == null) return;
    final controller = provider.controller;
    final info = _getLineInfo(controller);
    _replaceLine(
      controller,
      info.lineStart,
      info.lineEnd,
      _stripLinePrefix(info.currentLine),
      info.clampedCaret,
    );
    provider.focusNode.requestFocus();
  }

  void _toggleChecklist() {
    final provider = MarkdownControllerProvider.maybeOf(context);
    if (provider == null) return;
    final controller = provider.controller;
    final info = _getLineInfo(controller);
    final isChecklistActive = (_currentMask & _flagChecklist) != 0;

    if (isChecklistActive) {
      _replaceLine(
        controller,
        info.lineStart,
        info.lineEnd,
        _stripLinePrefix(info.currentLine),
        info.clampedCaret,
      );
    } else {
      final clean = _stripLinePrefix(info.currentLine);
      _replaceLine(
        controller,
        info.lineStart,
        info.lineEnd,
        '- [ ] $clean',
        info.clampedCaret,
      );
    }
    provider.focusNode.requestFocus();
  }

  void _toggleInline(String delimiter, MarkdownCommand command) {
    final provider = MarkdownControllerProvider.maybeOf(context);
    if (provider == null) return;
    final controller = provider.controller;
    final sel = controller.selection;
    final text = controller.text;

    if (sel.isValid && !sel.isCollapsed && sel.end <= text.length) {
      final selectedText = text.substring(sel.start, sel.end);
      final dLen = delimiter.length;
      if (selectedText.startsWith(delimiter) &&
          selectedText.endsWith(delimiter) &&
          selectedText.length >= 2 * dLen) {
        final unwrapped = selectedText.substring(
          dLen,
          selectedText.length - dLen,
        );
        _replaceRange(controller, sel.start, sel.end, unwrapped);
        provider.focusNode.requestFocus();
        return;
      }
    }
    controller.execute(command);
    provider.focusNode.requestFocus();
  }

  void _toggleCodeBlock() {
    final provider = MarkdownControllerProvider.maybeOf(context);
    if (provider == null) return;
    provider.controller.execute(MarkdownCommand.fencedCode);
    provider.focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final provider = MarkdownControllerProvider.maybeOf(context);

    Widget content;
    if (provider == null) {
      content = const NotesTextLinkControl();
    } else {
      content = NotesTextLinkControl(
        isTextContextualActive: (_currentMask & _flagH1) != 0,
        onTextContextualPressed: () => _toggleHeader(1),
        isH2Active: (_currentMask & _flagH2) != 0,
        onH2Pressed: () => _toggleHeader(2),
        isBodyActive: (_currentMask & _flagBody) != 0,
        onBodyPressed: _clearToParagraph,
        isBoldActive: (_currentMask & _flagBold) != 0,
        onBoldPressed: () => _toggleInline('**', MarkdownCommand.bold),
        isItalicActive: (_currentMask & _flagItalic) != 0,
        onItalicPressed: () => _toggleInline('*', MarkdownCommand.italic),
        isUnderlineActive: false,
        onUnderlinePressed: null,
        isStrikethroughActive: (_currentMask & _flagStrikethrough) != 0,
        onStrikethroughPressed: () =>
            _toggleInline('~~', MarkdownCommand.strikethrough),
        isChecklistActive: (_currentMask & _flagChecklist) != 0,
        onChecklistPressed: _toggleChecklist,
        isCodeActive: (_currentMask & _flagCode) != 0,
        onCodePressed: _toggleCodeBlock,
      );
    }

    return RepaintBoundary(
      child: Container(
        height: 56,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: context.colorScheme.surfaceContainer,

          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: content,
      ),
    );
  }
}
