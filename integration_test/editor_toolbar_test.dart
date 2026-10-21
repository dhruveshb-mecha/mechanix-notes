import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mechanix_notes/main.dart' as app;
import 'package:mechanix_notes/core/utils/icons.dart';
import 'test_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Editor Toolbar Tests', () {
    final helper = IntegrationTestHelper();

    setUpAll(() async {
      await helper.setUp();
    });

    tearDownAll(() async {
      await helper.tearDown();
    });

    testWidgets('Text Formatting Toolbar Actions', (tester) async {
      app.main([]);
      await tester.pumpAndSettle();

      await tester.tap(
        IntegrationTestHelper.findImageAsset(NotesIcon.createIcon),
      );
      await tester.pumpAndSettle();
      await IntegrationTestHelper.waitForEditor(tester);

      // Open text toolbar
      await tester.tap(
        IntegrationTestHelper.findEditorButton(NotesIcon.textstyleIcon),
      );
      await tester.pumpAndSettle();

      // Bold Formatting
      await tester.tap(
        IntegrationTestHelper.findEditorButton(NotesIcon.boldIcon),
      );
      await tester.pumpAndSettle();
      await IntegrationTestHelper.enterQuillText(tester, 'Bold Text ');
      await tester.pumpAndSettle();
      // Deselect Bold
      await tester.tap(
        IntegrationTestHelper.findEditorButton(NotesIcon.boldIcon),
      );
      await tester.pumpAndSettle();

      // Italic Formatting
      await tester.tap(
        IntegrationTestHelper.findEditorButton(NotesIcon.italicIcon),
      );
      await tester.pumpAndSettle();
      await IntegrationTestHelper.enterQuillText(tester, 'Italic Text ');
      await tester.pumpAndSettle();

      // Underline Formatting
      await tester.tap(
        IntegrationTestHelper.findEditorButton(NotesIcon.underlineIcon),
      );
      await tester.pumpAndSettle();

      // Heading H1
      await tester.tap(
        IntegrationTestHelper.findEditorButton(NotesIcon.h1Icon),
      );
      await tester.pumpAndSettle();

      // Heading H2
      await tester.tap(
        IntegrationTestHelper.findEditorButton(NotesIcon.h2Icon),
      );
      await tester.pumpAndSettle();

      // Wait debounce to save
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Navigate back
      await tester.tap(
        IntegrationTestHelper.findImageAsset(NotesIcon.backIcon),
      );
      await tester.pumpAndSettle();
    });

    testWidgets('Paragraph Toolbar Actions', (tester) async {
      app.main([]);
      await tester.pumpAndSettle();

      await tester.tap(
        IntegrationTestHelper.findImageAsset(NotesIcon.createIcon),
      );
      await tester.pumpAndSettle();
      await IntegrationTestHelper.waitForEditor(tester);

      // Open text toolbar to access paragraph icon
      await tester.tap(
        IntegrationTestHelper.findEditorButton(NotesIcon.textstyleIcon),
      );
      await tester.pumpAndSettle();

      // Tap paragraph icon
      await tester.tap(
        IntegrationTestHelper.findEditorButton(NotesIcon.paragraphIcon),
      );
      await tester.pumpAndSettle();

      // Note: Paragraph toolbar might have list icons (bullet, ordered).
      // Assuming NotesIcon.listIcon is bullet list and NotesIcon.todoIcon is todo list.
      // Adjust if they have specific numbered list icons.

      // Open menu toolbar
      await tester.tap(
        IntegrationTestHelper.findEditorButton(NotesIcon.menuIcon),
      );
      await tester.pumpAndSettle();

      // Bullet List
      await tester.tap(
        IntegrationTestHelper.findEditorButton(NotesIcon.listIcon),
      );
      await tester.pumpAndSettle();

      // Switch back to text toolbar for code block
      await tester.tap(
        IntegrationTestHelper.findEditorButton(NotesIcon.textstyleIcon),
      );
      await tester.pumpAndSettle();

      // Check if code block exists
      await tester.tap(
        IntegrationTestHelper.findEditorButton(NotesIcon.codeBlockIcon),
      );
      await tester.pumpAndSettle();

      // Wait debounce to save
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Navigate back
      await tester.tap(
        IntegrationTestHelper.findImageAsset(NotesIcon.backIcon),
      );
      await tester.pumpAndSettle();
    });

    testWidgets('Undo / Redo', (tester) async {
      app.main([]);
      await tester.pumpAndSettle();

      await tester.tap(
        IntegrationTestHelper.findImageAsset(NotesIcon.createIcon),
      );
      await tester.pumpAndSettle();
      await IntegrationTestHelper.waitForEditor(tester);

      final titleField = find.byType(TextField).first;
      final uniqueTitle =
          'Undo Test Note ${DateTime.now().millisecondsSinceEpoch}';
      await tester.enterText(titleField, uniqueTitle);

      await IntegrationTestHelper.enterQuillText(tester, 'Content to undo');
      await tester.pumpAndSettle();

      // Undo
      await tester.tap(
        IntegrationTestHelper.findImageAsset(NotesIcon.undoIcon),
      );
      await tester.pumpAndSettle();

      // Redo
      await tester.tap(
        IntegrationTestHelper.findImageAsset(NotesIcon.redoIcon),
      );
      await tester.pumpAndSettle();

      // Wait debounce to save
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Navigate back
      await tester.tap(
        IntegrationTestHelper.findImageAsset(NotesIcon.backIcon),
      );
      await tester.pumpAndSettle();

      expect(find.text(uniqueTitle), findsOneWidget);
    });
  });
}
