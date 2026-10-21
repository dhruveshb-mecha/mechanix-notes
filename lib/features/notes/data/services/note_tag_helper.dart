class NoteTagHelper {
  static final RegExp _tagRegex = RegExp(
    r'(?:\r?\n)*<!--\s*mechanix:id=([^\s>]+)\s*-->',
  );

  /// Appends the hidden identity tag to the end of the markdown content.
  /// If an existing tag is already present, it is replaced with the given [noteId].
  static String appendTag(String markdown, String noteId) {
    final stripped = stripTag(markdown).trimRight();
    if (stripped.isEmpty) {
      return '<!-- mechanix:id=$noteId -->\n';
    }
    return '$stripped\n\n<!-- mechanix:id=$noteId -->\n';
  }

  /// Strips the hidden identity tag from markdown before displaying in the editor
  /// or calculating previews.
  static String stripTag(String markdown) {
    return markdown.replaceAll(_tagRegex, '').trimRight();
  }

  /// Extracts the embedded note ID from the markdown content if present.
  static String? extractId(String markdown) {
    final match = _tagRegex.firstMatch(markdown);
    return match?.group(1);
  }
}
