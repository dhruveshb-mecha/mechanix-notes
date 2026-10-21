import 'package:flutter/material.dart';
import 'package:live_markdown_editor/live_markdown_editor.dart';
import 'package:mechanix_notes/core/utils/icons.dart';
import 'package:widgets/widgets.dart';

class EditorUndoRedoActions extends StatelessWidget {
  const EditorUndoRedoActions({super.key, this.controller});

  final MarkdownEditorController? controller;

  @override
  Widget build(BuildContext context) {
    if (controller == null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MechanixIconButton.standard(
            type: IconButtonType.rounded,
            onPressed: null,
            foregroundColor: context.colorScheme.onSurface,
            icon: const ImageIcon(AssetImage(NotesIcon.undoIcon)),
          ),
          MechanixIconButton.standard(
            type: IconButtonType.rounded,
            onPressed: null,
            foregroundColor: context.colorScheme.onSurface,
            icon: const ImageIcon(AssetImage(NotesIcon.redoIcon)),
          ),
        ],
      );
    }

    return ListenableBuilder(
      listenable: controller!,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MechanixIconButton.standard(
            type: IconButtonType.rounded,
            size: IconButtonSize.small,
            onPressed: controller!.canUndo ? controller!.undo : null,
            foregroundColor: controller!.canUndo
                ? context.colorScheme.onSurface
                : context.colorScheme.onSurfaceVariant,
            icon: Image.asset(
              NotesIcon.undoIcon,
              width: 19.5,
              height: 16.5,
              color: controller!.canUndo
                  ? context.colorScheme.onSurface
                  : context.colorScheme.onSurfaceVariant,
            ),
          ),
          MechanixIconButton.standard(
            type: IconButtonType.rounded,
            size: IconButtonSize.small,
            onPressed: controller!.canRedo ? controller!.redo : null,
            foregroundColor: controller!.canRedo
                ? context.colorScheme.onSurface
                : context.colorScheme.onSurfaceVariant,
            icon: Image.asset(
              NotesIcon.redoIcon,
              width: 19.5,
              height: 16.5,
              color: controller!.canRedo
                  ? context.colorScheme.onSurface
                  : context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
