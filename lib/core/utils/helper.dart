import 'package:flutter/material.dart';
import 'package:mechanix_notes/core/utils/enums.dart';
import 'package:mechanix_notes/features/notes/data/models/time_group.dart';
import 'package:mechanix_notes/l10n/notes_localizations.dart';

String getLocalizedLabelForTimeNotes(BuildContext context, TimeGroup group) {
  switch (group.category) {
    case TimeCategory.pinned:
      return AppLocalizations.of(context)!.pinned;
    case TimeCategory.recent:
      return AppLocalizations.of(context)!.recent;
    case TimeCategory.today:
      return AppLocalizations.of(context)!.today;
    case TimeCategory.yesterday:
      return AppLocalizations.of(context)!.yesterday;
    case TimeCategory.last7Days:
      return AppLocalizations.of(context)!.last7Days;
    case TimeCategory.thisWeek:
      return AppLocalizations.of(context)!.thisWeek;
    case TimeCategory.lastWeek:
      return AppLocalizations.of(context)!.lastWeek;
    case TimeCategory.thisMonth:
      return AppLocalizations.of(context)!.thisMonth;
    case TimeCategory.lastMonth:
      return AppLocalizations.of(context)!.lastMonth;
    case TimeCategory.custom:
      return group.customLabel ?? '';
  }
}

String localizeError(BuildContext context, ErrorCategory error) {
  switch (error) {
    case ErrorCategory.noteNotFound:
      return AppLocalizations.of(context)!.noteNotFound;
    case ErrorCategory.somethingWentWrong:
      return AppLocalizations.of(context)!.somethingWentWrong;
    case ErrorCategory.failedToSaveNote:
      return AppLocalizations.of(context)!.failedToSaveNote;
    case ErrorCategory.storageFull:
      return AppLocalizations.of(context)!.storageFull;
    case ErrorCategory.failedToLoadNotes:
      return AppLocalizations.of(context)!.failedToLoadNotes;
    case ErrorCategory.failedToDeleteNotes:
      return AppLocalizations.of(context)!.failedToDeleteNotes;
    case ErrorCategory.appAlreadyRunning:
      return AppLocalizations.of(context)!.appAlreadyRunning;
    case ErrorCategory.unknown:
      return AppLocalizations.of(context)!.somethingWentWrong;
  }
}

final _htmlCommentRegex = RegExp(r'<!--[\s\S]*?-->');
final _codeBlockRegex = RegExp(r'```[^\n]*\n([\s\S]*?)\n```');
final _taskListRegex = RegExp(r'^\s*[-+*]\s+\[[ xX]\]\s+', multiLine: true);
final _unorderedListRegex = RegExp(r'^\s*[-+*]\s+', multiLine: true);
final _orderedListRegex = RegExp(r'^\s*\d+[.)]\s+', multiLine: true);
final _blockquoteRegex = RegExp(r'^\s*>\s*', multiLine: true);
final _headerRegex = RegExp(r'^\s*#{1,6}\s+', multiLine: true);
final _imageRegex = RegExp(r'!\[([^\]]*)\]\([^)]*\)');
final _linkRegex = RegExp(r'\[([^\]]+)\]\([^)]*\)');
final _boldAsteriskRegex = RegExp(r'\*\*(.*?)\*\*');
final _boldUnderscoreRegex = RegExp(r'(?<!\w)__(.+?)__(?!\w)');
final _italicAsteriskRegex = RegExp(r'(?<!\*)\*(?!\s)(.*?)(?<!\s)\*(?!\*)');
final _italicUnderscoreRegex = RegExp(r'(?<!\w)_(?!\s)(.*?)(?<!\s)_(?!\w)');
final _strikethroughRegex = RegExp(r'~~(.*?)~~');
final _highlightRegex = RegExp(r'==(.*?)==');
final _inlineCodeRegex = RegExp(r'`([^`]+)`');
final _horizontalRuleRegex = RegExp(r'^\s*([-*_]){3,}\s*$', multiLine: true);

/// Strips common Markdown formatting tokens to produce clean plain text
/// suitable for search indexing (Tantivy) and preview text.
String markdownToPlainText(String markdown) {
  if (markdown.isEmpty) return '';

  var text = markdown;
  // Remove HTML comments (including mechanix:id tags)
  text = text.replaceAll(_htmlCommentRegex, '');
  // Remove fenced code blocks completely or keep inner text
  text = text.replaceAllMapped(_codeBlockRegex, (m) => m[1] ?? '');
  // Remove task list markers `- [ ] ` and `- [x] `
  text = text.replaceAll(_taskListRegex, '');
  // Remove unordered list markers `* `, `- `, `+ `
  text = text.replaceAll(_unorderedListRegex, '');
  // Remove ordered list markers `1. `
  text = text.replaceAll(_orderedListRegex, '');
  // Remove blockquote markers `> `
  text = text.replaceAll(_blockquoteRegex, '');
  // Remove headers `# `, `## `, etc.
  text = text.replaceAll(_headerRegex, '');
  // Remove images `![alt](url)` -> `alt`
  text = text.replaceAllMapped(_imageRegex, (m) => m[1] ?? '');
  // Remove links `[text](url)` -> `text`
  text = text.replaceAllMapped(_linkRegex, (m) => m[1] ?? '');
  // Remove bold `**text**` and `__text__`
  text = text.replaceAllMapped(_boldAsteriskRegex, (m) => m[1] ?? '');
  text = text.replaceAllMapped(_boldUnderscoreRegex, (m) => m[1] ?? '');
  // Remove italic `*text*` and `_text_` (preserving snake_case identifiers)
  text = text.replaceAllMapped(_italicAsteriskRegex, (m) => m[1] ?? '');
  text = text.replaceAllMapped(_italicUnderscoreRegex, (m) => m[1] ?? '');
  // Remove strikethrough `~~text~~`
  text = text.replaceAllMapped(_strikethroughRegex, (m) => m[1] ?? '');
  // Remove highlight `==text==`
  text = text.replaceAllMapped(_highlightRegex, (m) => m[1] ?? '');
  // Remove inline code
  text = text.replaceAllMapped(_inlineCodeRegex, (m) => m[1] ?? '');
  // Remove horizontal rules
  text = text.replaceAll(_horizontalRuleRegex, '');

  return text;
}
