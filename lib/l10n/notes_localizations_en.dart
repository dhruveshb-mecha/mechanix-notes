// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'notes_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get notes => 'Notes';

  @override
  String get last7Days => 'Last 7 Days';

  @override
  String get failedToLoadNotes => 'Failed to load notes. Please try again.';

  @override
  String get failedToDeleteNotes => 'Failed to delete notes. Please try again.';

  @override
  String get appAlreadyRunning =>
      'Another instance of the app is already running.';

  @override
  String get noteNotFound => 'Note not found';

  @override
  String get noNotesFound => 'No notes found';

  @override
  String get recent => 'Recent';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get thisWeek => 'This Week';

  @override
  String get lastWeek => 'Last Week';

  @override
  String get thisMonth => 'This Month';

  @override
  String get lastMonth => 'Last Month';

  @override
  String get startWriting => 'Start writing…';

  @override
  String get title => 'Title';

  @override
  String get undo => 'Undo';

  @override
  String get redo => 'Redo';

  @override
  String get somethingWentWrong => 'Something went wrong';

  @override
  String get goBack => 'Go Back';

  @override
  String deleteNotePrompt(String noteTitle) {
    return 'Delete \'$noteTitle\'?';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get saveChanges => 'Save changes';

  @override
  String get deleteNoteSubtitle =>
      'This note will be permanently deleted and cannot be recovered.';

  @override
  String get delete => 'Delete';

  @override
  String notesSelected(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notes selected',
      one: '1 note selected',
    );
    return '$_temp0';
  }

  @override
  String deleteNotePromptTitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete $count notes?',
      one: 'Delete 1 note?',
    );
    return '$_temp0';
  }

  @override
  String deleteNotePromptSubtitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'These notes will be permanently deleted and cannot be recovered.',
      one: 'This note will be permanently deleted and cannot be recovered.',
    );
    return '$_temp0';
  }

  @override
  String get justNow => 'Just now';

  @override
  String minutesAgo(num count) {
    return '$count m ago';
  }

  @override
  String hoursAgo(num count) {
    return '$count h ago';
  }

  @override
  String get failedToSaveNote => 'Failed to save note';

  @override
  String get storageFull => 'Storage is full';
}
