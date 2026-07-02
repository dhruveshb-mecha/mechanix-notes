import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:mechanix_notes/core/utils/app_logger.dart';
import 'package:mechanix_notes/features/notes/data/models/time_group.dart';
import 'package:mechanix_notes/l10n/notes_localizations.dart';
import 'package:mechanix_notes/core/utils/enums.dart';

String getLocalizedLabelForTimeNotes(BuildContext context, TimeGroup group) {
  switch (group.category) {
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

/// Converts Quill JSON string into a Document object.
Document decodeDocumentInIsolate(String contentJson) {
  try {
    final List<dynamic> deltaList = jsonDecode(contentJson) as List<dynamic>;
    return Document.fromJson(deltaList);
  } catch (e) {
    AppLogger.e('Failed to decode document: $e');
    return Document();
  }
}
