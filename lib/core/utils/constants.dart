class Constants {
  static const String tableName = "notesTablev1";
  static const int pageSize = 20;
  static const int minSearchQueryLength = 3;
  static const String notesDbPath = "/.config/mechanix_apps/notes/objectbox";
  static const String notesTantivyDbPath =
      "/.config/mechanix_apps/notes/tantivy";
  static const int noteTitleMaxLength = 40;
  static const int tantivyIndexContentMaxLength = 3000;
  static const int tantivyIndexContentMaxWords = 300;
  static const int searchResultLimit = 20;
  static const int maxDBSizeInKB = 15000; //15 mb
}
