import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:mechanix_notes/core/utils/app_routes.dart';
import 'package:mechanix_notes/core/utils/icons.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_bloc.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_event.dart';
import 'package:mechanix_notes/features/notes/data/models/note_metadata.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/editor/editor_trash_confirmation_sheet.dart';
import 'package:widgets/widgets.dart';

class HomeNoteCard extends StatelessWidget {
  final NoteMetaData note;
  final VoidCallback? onTap;
  final VoidCallback? onPin;
  final VoidCallback? onDelete;

  const HomeNoteCard({
    super.key,
    required this.note,
    this.onTap,
    this.onPin,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final title = note.title.isNotEmpty ? note.title : '';
    final supportingText = note.previewText.isNotEmpty
        ? note.previewText
        : null;
    final formattedDate = _formatDate(note.updatedAt);

    final leadingWidgets = [
      if (note.isPinned)
        Container(
          margin: const EdgeInsets.only(right: 4),
          child: ImageIcon(
            const AssetImage(NotesIcon.pinIcon),
            size: 20,
            color: context.colorScheme.primary,
          ),
        ),
    ];

    return MechanixSwipableListTile(
      key: ValueKey('note_tile_${note.id}'),
      variant: ListTileVariant.standard,
      labelText: title,
      extentRatio: 0.23,
      height: 50,
      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 14),
      supportingText: supportingText,
      trailingText: formattedDate,
      leadingWidgets: leadingWidgets,
      showLeading: note.isPinned,
      theme: ListTileThemeDataConfig(
        labelStyle: TextStyle(color: context.colorScheme.onSurface),
        supportingTextStyle: TextStyle(
          color: context.colorScheme.onSurfaceVariant,
        ),
      ),
      onTap:
          onTap ??
          () => Navigator.pushNamed(
            context,
            AppRoutes.noteEditor,
            arguments: {'noteId': note.id, 'noteTitle': note.title},
          ),
      actions: [
        MechanixIconButton.filled(
          key: ValueKey('pin_action_${note.id}'),
          type: IconButtonType.rounded,
          size: IconButtonSize.medium,
          backgroundColor: context.colorScheme.secondary,
          borderColor: Colors.transparent,
          borderWidth: 0,
          icon: ImageIcon(
            const AssetImage(NotesIcon.pinIcon),
            color: note.isPinned
                ? context.colorScheme.primary
                : context.colorScheme.onSurface,
            size: 18,
          ),
          onPressed: () {
            if (onPin != null) {
              onPin!();
            } else {
              context.read<NotesBloc>().add(TogglePinNote(noteId: note.id));
            }
          },
        ),
        MechanixIconButton.filled(
          key: ValueKey('delete_action_${note.id}'),
          type: IconButtonType.rounded,
          size: IconButtonSize.medium,
          backgroundColor: context.colorScheme.secondary,
          borderColor: Colors.transparent,
          borderWidth: 0,
          icon: ImageIcon(
            const AssetImage(NotesIcon.trashIcon),
            color: context.colorScheme.error,
            size: 18,
          ),
          onPressed: () {
            if (onDelete != null) {
              onDelete!();
            } else {
              EditorTrashConfirmationSheet.show(
                context: context,
                onConfirm: () {
                  context.read<NotesBloc>().add(
                    DeleteNotes(noteIds: [note.id]),
                  );
                },
              );
            }
          },
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (now.year != date.year) {
      return DateFormat('dd MMM yy').format(date).toUpperCase();
    }
    return DateFormat('dd MMM').format(date).toUpperCase();
  }
}
