import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:mechanix_notes/core/utils/app_routes.dart';
import 'package:mechanix_notes/core/utils/icons.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_bloc.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_event.dart';
import 'package:mechanix_notes/features/notes/data/models/note_metadata.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/home/home_delete_sheet.dart';
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
    final title = note.title.isNotEmpty ? note.title : note.previewText;
    final supportingText =
        note.title.isNotEmpty &&
            note.previewText.isNotEmpty &&
            note.title != note.previewText
        ? note.previewText
        : null;
    final formattedDate = _formatDate(note.updatedAt);

    final Widget? leading;
    if (note.isPinned) {
      leading = ImageIcon(
        const AssetImage(NotesIcon.pinIcon),
        size: 20,
        color: context.colorScheme.primary,
      );
    } else {
      leading = null;
    }

    return MechanixSwipableListTile(
      key: ValueKey('note_tile_${note.id}'),
      variant: ListTileVariant.standard,
      labelText: title,
      extentRatio: 0.2,
      height: 50,
      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 14),
      supportingText: supportingText,
      trailingText: formattedDate,
      leading: leading,
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
            size: 20,
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
            size: 20,
          ),
          onPressed: () {
            if (onDelete != null) {
              onDelete!();
            } else {
              showModalBottomSheet(
                context: context,
                backgroundColor: context.colorScheme.surfaceContainer,
                builder: (sheetContext) => HomeDeleteSheet(
                  selectedCount: 1,
                  onDelete: () {
                    context.read<NotesBloc>().add(
                      DeleteNotes(noteIds: [note.id]),
                    );
                  },
                ),
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
