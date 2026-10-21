import 'package:flutter/material.dart';
import 'package:mechanix_notes/core/utils/icons.dart';
import 'package:widgets/widgets.dart';

/// Defines the active mode in [NotesTextLinkControl].
enum NotesBottomBarMode { text, link }

class NotesTextLinkControl extends StatefulWidget {
  const NotesTextLinkControl({
    super.key,
    this.mode,
    this.initialMode = NotesBottomBarMode.text,
    this.onModeChanged,
    this.onTextContextualPressed,
    this.isTextContextualActive = false,
    this.onH2Pressed,
    this.isH2Active = false,
    this.onBodyPressed,
    this.isBodyActive = false,
    this.onBoldPressed,
    this.isBoldActive = false,
    this.onItalicPressed,
    this.isItalicActive = false,
    this.onUnderlinePressed,
    this.isUnderlineActive = false,
    this.onStrikethroughPressed,
    this.isStrikethroughActive = false,
    this.onChecklistPressed,
    this.isChecklistActive = false,
    this.onLinkContextualPressed,
    this.onCodePressed,
    this.isCodeActive = false,
    this.size = IconButtonSize.small,
    this.enabled = true,
  });

  /// The active mode when controlled externally (optional).
  final NotesBottomBarMode? mode;

  /// The initial mode when uncontrolled. Defaults to [NotesBottomBarMode.text].
  final NotesBottomBarMode initialMode;

  /// Callback fired when the user toggles between Text and Link modes.
  final ValueChanged<NotesBottomBarMode>? onModeChanged;

  /// Callback when the Text contextual button is tapped.
  final VoidCallback? onTextContextualPressed;

  /// Whether the Text contextual (H1) format is currently active.
  final bool isTextContextualActive;

  /// Callback when the H2 button is tapped.
  final VoidCallback? onH2Pressed;

  /// Whether the H2 format is currently active.
  final bool isH2Active;

  /// Callback when the Body (Normal text) button is tapped.
  final VoidCallback? onBodyPressed;

  /// Whether Normal text / paragraph format is currently active.
  final bool isBodyActive;

  /// Callback when the Bold button is tapped.
  final VoidCallback? onBoldPressed;

  /// Whether Bold formatting is currently active.
  final bool isBoldActive;

  /// Callback when the Italic button is tapped.
  final VoidCallback? onItalicPressed;

  /// Whether Italic formatting is currently active.
  final bool isItalicActive;

  /// Callback when the Underline button is tapped.
  final VoidCallback? onUnderlinePressed;

  /// Whether Underline formatting is currently active.
  final bool isUnderlineActive;

  /// Callback when the Strikethrough button is tapped.
  final VoidCallback? onStrikethroughPressed;

  /// Whether Strikethrough formatting is currently active.
  final bool isStrikethroughActive;

  /// Callback when the Checklist button is tapped.
  final VoidCallback? onChecklistPressed;

  /// Whether Checklist formatting is currently active.
  final bool isChecklistActive;

  /// Callback when the Link contextual button is tapped.
  final VoidCallback? onLinkContextualPressed;

  /// Callback when the Code block button is tapped.
  final VoidCallback? onCodePressed;

  /// Whether Code block format is currently active.
  final bool isCodeActive;

  /// Sizing scale for the icon buttons. Defaults to [IconButtonSize.small].
  final IconButtonSize size;

  /// Whether the controls are enabled. Defaults to `true`.
  final bool enabled;

  @override
  State<NotesTextLinkControl> createState() => _NotesTextLinkControlState();
}

class _NotesTextLinkControlState extends State<NotesTextLinkControl> {
  late NotesBottomBarMode _uncontrolledMode;

  NotesBottomBarMode get _effectiveMode => widget.mode ?? _uncontrolledMode;

  @override
  void initState() {
    super.initState();
    _uncontrolledMode = widget.initialMode;
  }

  void _handleModeSelected(NotesBottomBarMode newMode) {
    if (!widget.enabled || _effectiveMode == newMode) return;

    if (widget.mode == null) {
      setState(() {
        _uncontrolledMode = newMode;
      });
    }
    widget.onModeChanged?.call(newMode);
  }

  @override
  Widget build(BuildContext context) {
    final isTextMode = _effectiveMode == NotesBottomBarMode.text;
    VoidCallback? onPressed(VoidCallback? callback) =>
        widget.enabled ? callback : null;

    return SizedBox(
      height: 48,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ModeToggleGroup(
            key: const Key('notes_mode_toggle_group'),
            isTextMode: isTextMode,
            size: widget.size,
            enabled: widget.enabled,
            onModeSelected: _handleModeSelected,
          ),
          if (isTextMode) ...[
            _ContextualButton(
              buttonKey: const Key('notes_text_contextual_button'),
              isSelected: widget.isTextContextualActive,
              selectedForegroundColor: context.colorScheme.onSecondaryContainer,
              size: widget.size,
              icon: Image.asset(NotesIcon.h1Icon, height: 15, width: 20),
              onPressed: onPressed(widget.onTextContextualPressed),
            ),
            _ContextualButton(
              buttonKey: const Key('notes_text_h2_button'),
              isSelected: widget.isH2Active,
              selectedForegroundColor: context.colorScheme.onSecondaryContainer,
              size: widget.size,
              icon: Image.asset(NotesIcon.h2Icon, height: 13, width: 20),
              onPressed: onPressed(widget.onH2Pressed),
            ),
            _ContextualButton(
              buttonKey: const Key('notes_text_body_button'),
              isSelected: widget.isBodyActive,
              size: widget.size,
              icon: Image.asset(NotesIcon.textstyleIcon, height: 11, width: 13),
              onPressed: onPressed(widget.onBodyPressed),
            ),
            _ContextualButton(
              buttonKey: const Key('notes_text_bold_button'),
              isSelected: widget.isBoldActive,
              size: widget.size,
              icon: Image.asset(NotesIcon.boldIcon, height: 16, width: 13),
              onPressed: onPressed(widget.onBoldPressed),
            ),
            _ContextualButton(
              buttonKey: const Key('notes_text_italic_button'),
              isSelected: widget.isItalicActive,
              size: widget.size,
              icon: Image.asset(NotesIcon.italicIcon, height: 15, width: 13.5),
              onPressed: onPressed(widget.onItalicPressed),
            ),
            _ContextualButton(
              buttonKey: const Key('notes_text_underline_button'),
              isSelected: widget.isUnderlineActive,
              size: widget.size,
              icon: Image.asset(
                NotesIcon.underlineIcon,
                height: 17.25,
                width: 13.5,
              ),
              onPressed: onPressed(widget.onUnderlinePressed),
            ),
            _ContextualButton(
              buttonKey: const Key('notes_text_strikethrough_button'),
              isSelected: widget.isStrikethroughActive,
              size: widget.size,
              icon: Image.asset(
                NotesIcon.strikethroughIcon,
                height: 16.5,
                width: 18,
              ),
              onPressed: onPressed(widget.onStrikethroughPressed),
            ),
          ] else ...[
            // TODO: This feature is not implemented
            // _ContextualButton(
            //   buttonKey: const Key('notes_link_image_button'),
            //   size: widget.size,
            //   icon: const ImageIcon(AssetImage(NotesIcon.imageIcon), size: 16),
            //   onPressed: onPressed(widget.onLinkContextualPressed),
            // ),
            // _ContextualButton(
            //   buttonKey: const Key('notes_link_file_button'),
            //   size: widget.size,
            //   icon: const ImageIcon(AssetImage(NotesIcon.fileIcon), size: 16),
            //   onPressed: null,
            // ),
            _ContextualButton(
              buttonKey: const Key('notes_link_code_button'),
              isSelected: widget.isCodeActive,
              size: widget.size,
              icon: const ImageIcon(AssetImage(NotesIcon.codeBlockIcon)),
              onPressed: onPressed(widget.onCodePressed),
            ),
            _ContextualButton(
              buttonKey: const Key('notes_link_checklist_button'),
              isSelected: widget.isChecklistActive,
              size: widget.size,
              icon: const ImageIcon(AssetImage(NotesIcon.todoIcon)),
              onPressed: onPressed(widget.onChecklistPressed),
            ),
            // TODO: This feature is not implemented
            // _ContextualButton(
            //   buttonKey: const Key('notes_link_music_button'),
            //   size: widget.size,
            //   icon: const ImageIcon(AssetImage(NotesIcon.musicIcon), size: 16),
            //   onPressed: null,
            // ),
          ],
        ],
      ),
    );
  }
}

class _ModeToggleGroup extends StatelessWidget {
  const _ModeToggleGroup({
    super.key,
    required this.isTextMode,
    required this.size,
    required this.enabled,
    required this.onModeSelected,
  });

  final bool isTextMode;
  final IconButtonSize size;
  final bool enabled;
  final ValueChanged<NotesBottomBarMode> onModeSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.colorScheme.surfaceContainerHigh,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        spacing: 0,
        children: [
          // Text mode toggle button
          MechanixIconButton.filled(
            key: const Key('notes_text_toggle'),
            isSelected: isTextMode,
            type: IconButtonType.square,
            size: IconButtonSize.xSmall,
            icon: Image.asset(
              NotesIcon.textModeIcon,
              height: 12.5,
              width: 12.5,
            ),
            foregroundColor: context.colorScheme.onSurface,
            backgroundColor: context.colorScheme.surfaceContainerHigh,
            borderWidth: 0,
            onPressed: enabled
                ? () => onModeSelected(NotesBottomBarMode.text)
                : null,
          ),
          // Link mode toggle button
          MechanixIconButton.filled(
            key: const Key('notes_link_toggle'),
            isSelected: !isTextMode,
            type: IconButtonType.square,
            size: IconButtonSize.xSmall,
            foregroundColor: context.colorScheme.onSurface,
            backgroundColor: context.colorScheme.surfaceContainerHigh,
            icon: const Icon(Icons.attach_file_rounded, size: 15),
            borderWidth: 0,
            onPressed: enabled
                ? () => onModeSelected(NotesBottomBarMode.link)
                : null,
          ),
        ],
      ),
    );
  }
}

class _ContextualButton extends StatelessWidget {
  const _ContextualButton({
    required this.buttonKey,
    required this.icon,
    required this.onPressed,
    this.isSelected = false,
    required this.size,
    this.selectedForegroundColor,
  });

  final Key buttonKey;
  final Widget icon;
  final VoidCallback? onPressed;
  final bool isSelected;
  final IconButtonSize size;
  final Color? selectedForegroundColor;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final effectiveSelectedFg = selectedForegroundColor ?? scheme.onSurface;

    Widget effectiveIcon = icon;
    if (icon is Image) {
      final img = icon as Image;
      effectiveIcon = Image(
        image: img.image,
        width: img.width,
        height: img.height,
        color: isSelected ? effectiveSelectedFg : scheme.onSurfaceVariant,
        fit: img.fit,
      );
    }

    return MechanixIconButton.standard(
      key: buttonKey,
      isSelected: isSelected,
      type: IconButtonType.square,
      size: IconButtonSize.small,
      icon: effectiveIcon,
      backgroundColor: Colors.transparent,
      foregroundColor: scheme.onSurfaceVariant,
      selectedBackgroundColor: scheme.onSurfaceVariant.withValues(alpha: 0.08),
      selectedForegroundColor: effectiveSelectedFg,
      onPressed: onPressed,
    );
  }
}
