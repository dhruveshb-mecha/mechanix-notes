import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:live_markdown_editor/live_markdown_editor.dart'
    show LiveMarkdownEditor;
import 'package:mechanix_notes/core/utils/icons.dart';
import 'package:mechanix_notes/features/notes/data/repository/note_repository.dart';
import 'package:mechanix_notes/features/notes/data/repository/note_repository_impl.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/editor/editor_button.dart';
import 'package:mechanix_notes/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Comprehensive End-to-end test', () {
    late NoteRepository noteRepository;

    setUpAll(() async {
      noteRepository = NoteRepositoryImpl();
    });

    tearDownAll(() async {
      try {
        final notes = await noteRepository.watchNotes().first;
        if (notes.isNotEmpty) {
          await noteRepository.deleteNotes(notes.map((n) => n.id).toList());
        }
      } catch (_) {}
      try {
        await noteRepository.close();
      } catch (_) {}
    });

    // Helper to find EditorButton by asset
    Finder findEditorButton(String asset) {
      return find
          .byWidgetPredicate(
            (widget) => widget is EditorButton && widget.asset == asset,
          )
          .last;
    }

    // Helper to find Image by asset
    Finder findImageAsset(String asset) {
      return find
          .byWidgetPredicate(
            (widget) =>
                widget is Image &&
                widget.image is AssetImage &&
                (widget.image as AssetImage).assetName == asset,
          )
          .last;
    }

    // Helper to wait for the editor to be ready
    Future<void> waitForEditor(WidgetTester tester) async {
      int retry = 0;
      while (find.byType(TextField).evaluate().isEmpty && retry < 15) {
        await tester.pump(const Duration(milliseconds: 200));
        retry++;
      }
    }

    testWidgets('Full Note Lifecycle: Create, Format, Manual Save, Delete', (
      tester,
    ) async {
      final uniqueTitle =
          'Lifecycle Test Note ${DateTime.now().millisecondsSinceEpoch}';

      app.main([]);
      await tester.pumpAndSettle();

      // 1. Create
      await tester.tap(findImageAsset(NotesIcon.createIcon));
      await tester.pumpAndSettle();
      await waitForEditor(tester);

      // 2. Title
      final titleField = find.byType(TextField).first;
      await tester.enterText(titleField, uniqueTitle);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // 3. Content
      final liveEditorFinder = find.byType(LiveMarkdownEditor);
      await tester.tap(liveEditorFinder);
      await tester.pumpAndSettle();
      final editorWidget = tester.widget<LiveMarkdownEditor>(liveEditorFinder);
      editorWidget.controller.text = 'Lifecycle content';
      await tester.pumpAndSettle();

      // 4. Formatting
      await tester.tap(findEditorButton(NotesIcon.textstyleIcon));
      await tester.pumpAndSettle();
      await tester.tap(findEditorButton(NotesIcon.boldIcon));
      await tester.pumpAndSettle();
      await tester.tap(findEditorButton(NotesIcon.italicIcon));
      await tester.pumpAndSettle();
      await tester.tap(findEditorButton(NotesIcon.codeBlockIcon));
      await tester.pumpAndSettle();

      // 5. Manual Save
      await tester.tap(findEditorButton(NotesIcon.backIcon));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.text(uniqueTitle), findsOneWidget);

      // 7. Delete
      await tester.longPress(find.text(uniqueTitle));
      await tester.pumpAndSettle();
      await tester.tap(findImageAsset(NotesIcon.trashIcon));
      await tester.pumpAndSettle();
      final confirmBtn = find.text('Delete');
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // 8. Verify Gone
      expect(find.text(uniqueTitle), findsNothing);
    });

    // testWidgets('Auto-save scenario', (tester) async {
    //   app.main();
    //   await tester.pumpAndSettle();

    //   await tester.tap(findImageAsset(NotesIcon.createIcon));
    //   await tester.pumpAndSettle();
    //   await waitForEditor(tester);

    //   await tester.enterText(find.byType(TextField).first, 'Auto-save Test');
    //   await tester.pump(const Duration(milliseconds: 500));

    //   final quillEditorFinder = find.byType(QuillEditor);
    //   try {
    //     await tester.enterText(quillEditorFinder, 'Auto-save content');
    //   } catch (e) {
    //     final editorWidget = tester.widget<QuillEditor>(quillEditorFinder);
    //     editorWidget.controller.document.insert(0, 'Auto-save content');
    //   }

    //   await tester.pump(const Duration(seconds: 3));
    //   await tester.pumpAndSettle();

    //   await tester.tap(findEditorButton(NotesIcon.backIcon));
    //   await tester.pumpAndSettle();
    //   await tester.pump(const Duration(seconds: 1));
    //   await tester.pumpAndSettle();

    //   expect(find.text('Auto-save Test'), findsOneWidget);
    // });
  });
}
