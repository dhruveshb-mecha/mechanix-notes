import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_notes/core/utils/icons.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/editor/editor_button.dart';
import 'package:flutter_quill/flutter_quill.dart' show QuillEditor;
import 'package:mechanix_notes/features/notes/data/repository/note_repository.dart';
import 'package:mechanix_notes/features/notes/data/repository/note_repository_impl.dart';

class IntegrationTestHelper {
  NoteRepository? noteRepository;

  Future<void> setUp() async {
    noteRepository = NoteRepositoryImpl();
  }

  Future<void> tearDown() async {
    if (noteRepository != null) {
      try {
        final notes = await noteRepository!.getNotes(0, 1000);
        if (notes.isNotEmpty) {
          await noteRepository!.deleteNotes(notes.map((n) => n.id).toList());
        }
      } catch (_) {}
    }
  }

  static Finder findEditorButton(String asset) {
    return find
        .byWidgetPredicate(
          (widget) => widget is EditorButton && widget.asset == asset,
        )
        .last;
  }

  static Finder findImageAsset(String asset) {
    return find
        .byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName == asset,
        )
        .last;
  }

  static Future<void> waitForEditor(WidgetTester tester) async {
    int retry = 0;
    while (find.byType(TextField).evaluate().isEmpty && retry < 15) {
      await tester.pump(const Duration(milliseconds: 200));
      retry++;
    }
  }

  static Future<void> enterQuillText(WidgetTester tester, String text) async {
    final quillEditorFinder = find.byType(QuillEditor);
    try {
      await tester.enterText(quillEditorFinder, text);
    } catch (e) {
      final editorWidget = tester.widget<QuillEditor>(quillEditorFinder);
      editorWidget.controller.document.insert(0, text);
    }
  }

  // -------------------------------------------------------------------------
  // Search helpers
  // -------------------------------------------------------------------------

  static Finder get searchFab => find.byWidgetPredicate(
    (widget) => widget is FloatingActionButton && widget.heroTag == 'search',
  );

  static Finder get searchTextField => find.byWidgetPredicate(
    (widget) =>
        widget is TextField && widget.decoration?.hintText == 'Search in notes',
  );

  static Finder get searchCancelButton => find.byIcon(Icons.cancel);

  /// Creates a note with [title], waits for autosave, and returns to home.
  static Future<void> createNoteWithTitle(
    WidgetTester tester,
    String title, {
    String? body,
  }) async {
    await tester.tap(findImageAsset(NotesIcon.createIcon));
    await tester.pumpAndSettle();
    await waitForEditor(tester);

    await tester.enterText(find.byType(TextField).first, title);
    await tester.pump(const Duration(milliseconds: 500));

    if (body != null) {
      await enterQuillText(tester, body);
      await tester.pump(const Duration(milliseconds: 500));
    }

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    await tester.tap(findImageAsset(NotesIcon.backIcon));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  static Future<void> openSearch(WidgetTester tester) async {
    await tester.tap(searchFab);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// Types in the search field and waits for the 400 ms debounce.
  static Future<void> enterSearchQuery(
    WidgetTester tester,
    String query,
  ) async {
    await tester.enterText(searchTextField, query);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  }

  static Future<void> clearSearchQuery(WidgetTester tester) async {
    await tester.tap(searchCancelButton);
    await tester.pumpAndSettle();
  }

  static Future<void> closeSearchScreen(WidgetTester tester) async {
    await tester.tap(searchCancelButton);
    await tester.pumpAndSettle();
  }
}
