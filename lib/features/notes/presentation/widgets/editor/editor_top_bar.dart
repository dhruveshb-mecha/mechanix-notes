import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_notes/core/utils/icons.dart';
import 'package:mechanix_notes/features/notes/bloc/editor/editor_bloc.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_bloc.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_event.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/editor/editor_trash_confirmation_sheet.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/editor/markdown_controller_provider.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/editor/topbar/editor_undo_redo_actions.dart';
import 'package:mechanix_notes/l10n/notes_localizations.dart';
import 'package:widgets/widgets.dart';

class EditorTopBar extends StatelessWidget implements PreferredSizeWidget {
  const EditorTopBar({super.key});

  @override
  Size get preferredSize =>
      const MechanixAppBar(toolbarHeight: 73).preferredSize;

  void _handleBack(BuildContext context) {
    final controller = MarkdownControllerProvider.maybeOf(context)?.controller;
    if (controller != null) {
      final markdown = controller.text;
      context.read<EditorBloc>().add(EditorSaveRequested(content: markdown));
    } else {
      Navigator.maybePop(context);
    }
  }

  void _showTrashConfirmationSheet(BuildContext context) {
    final editorBloc = context.read<EditorBloc>();
    final notesBloc = context.read<NotesBloc>();
    final navigator = Navigator.of(context);

    EditorTrashConfirmationSheet.show(
      context: context,
      onConfirm: () {
        final editorState = editorBloc.state;
        String? noteId;
        if (editorState is EditorLoaded && !editorState.isNewNote) {
          noteId = editorState.noteId;
        } else if (editorState is EditorSaveSuccess) {
          noteId = editorState.noteId;
        }

        if (noteId != null) {
          notesBloc.add(DeleteNotes(noteIds: [noteId]));
        }
        navigator.pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = MarkdownControllerProvider.maybeOf(context)?.controller;

    return MechanixAppBar(
      backgroundColor: context.colorScheme.surfaceContainerLowest,
      toolbarHeight: 73,
      leading: MechanixIconButton.standard(
        type: IconButtonType.rounded,
        size: IconButtonSize.small,
        onPressed: () => _handleBack(context),
        foregroundColor: context.colorScheme.onSurface,
        icon: Image.asset(NotesIcon.backIcon, width: 9, height: 16.5),
      ),
      actions: [
        EditorUndoRedoActions(controller: controller),
        BlocBuilder<EditorBloc, EditorState>(
          buildWhen: (prev, curr) {
            final prevPinned = prev is EditorLoaded && prev.isPinned;
            final currPinned = curr is EditorLoaded && curr.isPinned;
            return prevPinned != currPinned;
          },
          builder: (context, state) {
            final isPinned = state is EditorLoaded && state.isPinned;
            final l10n = AppLocalizations.of(context);

            return MechanixMenu<String>(
              alignment: MechanixMenuAlignment.end,
              offset: const Offset(0, 4),
              width: 208,
              style: const MenuThemeDataConfig(borderRadius: BorderRadius.zero),
              anchorBuilder: (context, controller, child) {
                return MechanixIconButton.standard(
                  type: IconButtonType.rounded,
                  size: IconButtonSize.small,
                  onPressed: controller.toggle,
                  foregroundColor: context.colorScheme.onSurface,
                  backgroundColor: controller.isOpen
                      ? context.colorScheme.surfaceContainer
                      : context.colorScheme.surfaceContainerLowest,
                  icon: Image.asset(
                    NotesIcon.moreVertIcon,
                    width: 2.25,
                    height: 15,
                  ),
                );
              },
              entries: [
                MechanixMenuItem<String>(
                  value: 'pin',
                  labelText: isPinned
                      ? (l10n?.unpinNote ?? 'Unpin note')
                      : (l10n?.pinNote ?? 'Pin note'),

                  trailing: Image.asset(
                    NotesIcon.pinIcon,
                    width: 15,
                    height: 17,
                  ),
                  onTap: () {
                    context.read<EditorBloc>().add(EditorPinToggled());
                  },
                ),
                MechanixMenuItem<String>(
                  value: 'trash',
                  label: Text(
                    l10n?.moveToTrash ?? 'Move to trash',
                    style: context.textTheme.titleSmall?.copyWith(
                      color: context.colorScheme.error,
                    ),
                  ),
                  trailing: Image.asset(
                    NotesIcon.trashIcon,
                    width: 15,
                    height: 16.25,
                  ),
                  onTap: () => _showTrashConfirmationSheet(context),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
