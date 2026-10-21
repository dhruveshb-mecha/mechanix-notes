# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0+1] - 2026-10-14

- **Live Markdown Editor**:
  - Replaced the Flutter Quill rich-text editor with a native live Markdown editor (`live_markdown_editor`).
  - Added markdown formatting toolbar controls for headings, bold, italics, strikethrough, links, blockquotes, and code blocks.
- **Plain Markdown Filesystem Storage**:
  - Migrated note content storage from database records to human-readable `.md` files in `~/Documents/notes` (or `$XDG_DOCUMENTS_DIR/notes`).
  - Added `NoteFileStorage` service supporting atomic writes (via temporary files), filename sanitization from note titles, and duplicate filename resolution.
  - Updated `NoteModel` in ObjectBox to store `fileName` mappings while keeping ObjectBox for fast metadata queries.
- **Fast Full-Text Search**:
  - Integrated Rust-based Tantivy search library via `flutter_tantivy` for indexed, instant full-text search across note titles and content.
- **Organization & Note Management**:
  - Added chronological note grouping (Today, Yesterday, Last 7 Days, This Month, Last Month, etc.).
  - Added note pinning support (`isPinned`) to keep important notes at the top.
  - Added swipe-to-delete action on note cards.
- **Localization**:
  - Added internationalization (`l10n`) infrastructure with English localization strings.
