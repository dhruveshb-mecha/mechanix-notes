enum TimeCategory {
  recent,
  today,
  yesterday,
  last7Days,
  thisWeek,
  lastWeek,
  thisMonth,
  lastMonth,
  custom,
}

enum ErrorCategory {
  noteNotFound,
  somethingWentWrong,
  failedToSaveNote,
  storageFull,
  failedToLoadNotes,
  failedToDeleteNotes,
  appAlreadyRunning,
  unknown,
}

enum EditorToolbar { none, textStyle, menu, options }
