# Mechanix Notes

Notes App for the Mechanix OS

## Overview

Mechanix Notes is a simple and lightweight note-taking application built with Flutter for Mecha Comet devices. It provides an easy way to create, edit, and manage notes with a clean and user-friendly interface.

---

## Install Guide

### Pre-requisites

- [Flutter-Elinux SDK](https://github.com/flutter-elinux/flutter-elinux)
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

## Testing

### Run Unit & BLoC Tests

```bash
flutter-elinux test
```

### Run Integration Tests

```bash
flutter-elinux test integration_test/<test-file-name>
```

## Key Features

- **Create Notes**: Quickly create and save notes.
- **Edit Notes**: Update existing notes anytime.
- **Delete Notes**: Remove unwanted notes easily.
- **Search Notes**: Find notes instantly with search functionality (indexes notes using Tantivy with a maximum character support of 1000 characters per note).
- **Persistent Storage**: Notes are stored locally on the device.
- **Clean UI**: Minimal and user-friendly interface optimized for Mechanix OS.
- **Rich Text Support**: Basic text formatting support for better note organization.

---

## TODO
- Handle disk storage errors during indexing.

### Cross-Building Tantivy for aarch64

For cross compile Tantivy library for aarch64

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