# Mechanix Notes

Notes application for Mechanix OS on Mecha Comet devices.

## Overview

Mechanix Notes is a fast, lightweight note-taking application built with Flutter for Mechanix OS. It combines the speed and responsiveness of a local database (**ObjectBox**) and a high-performance Rust full-text search engine (**Tantivy**) with the freedom and interoperability of storing notes as plain **Markdown (`.md`)** files on the filesystem.

---

## Key Features

- **Live Markdown Editor**: Native markdown writing experience with dedicated formatting controls for headings, bold, italic, strikethrough, unordered lists, links, blockquotes, and code blocks, along with undo and redo controls.
- **Plain Markdown Filesystem Storage**: Notes are saved directly as individual, human-readable `.md` files under `~/Documents/notes/` (or `$XDG_DOCUMENTS_DIR/notes`), with atomic writes, filename sanitization, and duplicate conflict handling.
- **Fast Full-Text Search**: Powered by Tantivy (Rust FFI via `flutter_tantivy`), indexing note titles and content (up to 3,000 characters per note) for instant search results.

---

## Install & Run Guide

### Pre-requisites

- [Flutter-eLinux SDK](https://github.com/flutter-elinux/flutter-elinux)
- [Dart SDK](https://dart.dev/get-dart)
- [Rust & Cargo](https://www.rust-lang.org/tools/install) (required for the Rust-based Tantivy search library)

### Steps to Run Notes App

1. Clone the repository:

```bash
git clone https://github.com/mecha-org/mechanix-notes
cd mechanix-notes
```

2. Install Flutter dependencies:

For flutter-elinux:

```bash
flutter-elinux pub get
```

3. Run the Application

### Run on eLinux

```bash
flutter-elinux run
```

---

## Testing

### Run Unit & BLoC Tests

```bash
flutter-elinux test
```

Or using standard Flutter:

```bash
flutter test
```

### Run Integration Tests

```bash
flutter-elinux test integration_test/<test-file-name>
```

---

## Cross-Compilation

### Cross-Building Tantivy for aarch64

To cross-compile the Tantivy library for `aarch64`:

```bash
export CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER=aarch64-linux-gnu-gcc
cargo build --release --target aarch64-unknown-linux-gnu
```

### Cross-Building the Application for arm64

To cross-build the application using the sysroot toolchain:

```bash
CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER=aarch64-linux-gnu-gcc \
flutter-elinux build elinux \
  --release \
  --target-arch=arm64 \
  --target-compiler-triple=aarch64-linux-gnu \
  --target-sysroot=/home/{user}/ubuntu22-arm64-sysroot
```

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for details on recent updates and releases.