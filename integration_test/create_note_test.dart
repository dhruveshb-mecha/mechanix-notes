import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:live_markdown_editor/live_markdown_editor.dart'
    show LiveMarkdownEditor;
import 'package:mechanix_notes/core/utils/icons.dart';
import 'package:mechanix_notes/main.dart' as app;

import 'test_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Create Note', () {
    final helper = IntegrationTestHelper();

    setUpAll(() async {
      await helper.setUp();
    });

    tearDownAll(() async {
      await helper.tearDown();
    });

    testWidgets('Create Empty Note', (tester) async {
      app.main([]);
      await tester.pumpAndSettle();

      await tester.tap(
        IntegrationTestHelper.findImageAsset(NotesIcon.createIcon),
      );
      await tester.pumpAndSettle();
      await IntegrationTestHelper.waitForEditor(tester);

      expect(find.byType(TextField).first, findsOneWidget); // Title field
      expect(find.byType(LiveMarkdownEditor), findsOneWidget); // Content editor

      // Navigation back
      await tester.tap(
        IntegrationTestHelper.findImageAsset(NotesIcon.backIcon),
      );
      await tester.pumpAndSettle();
    });

    testWidgets('Create Note With Title Only', (tester) async {
      app.main([]);
      await tester.pumpAndSettle();

      await tester.tap(
        IntegrationTestHelper.findImageAsset(NotesIcon.createIcon),
      );
      await tester.pumpAndSettle();
      await IntegrationTestHelper.waitForEditor(tester);

      final titleField = find.byType(TextField).first;
      final uniqueTitle =
          'Test Title Only ${DateTime.now().millisecondsSinceEpoch}';
      await tester.enterText(titleField, uniqueTitle);
      await tester.pump(const Duration(milliseconds: 500));

      // Stop typing for 2 seconds (wait for auto-save debounce)
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      await tester.tap(
        IntegrationTestHelper.findImageAsset(NotesIcon.backIcon),
      );
      await tester.pumpAndSettle();

      expect(find.text(uniqueTitle), findsOneWidget);
    });

    testWidgets('Create Note With Content Only', (tester) async {
      app.main([]);
      await tester.pumpAndSettle();

      await tester.tap(
        IntegrationTestHelper.findImageAsset(NotesIcon.createIcon),
      );
      await tester.pumpAndSettle();
      await IntegrationTestHelper.waitForEditor(tester);

      final uniqueContent =
          'Test Content Only ${DateTime.now().millisecondsSinceEpoch}';
      await IntegrationTestHelper.enterQuillText(tester, uniqueContent);
      await tester.pump(const Duration(milliseconds: 500));

      // Wait for debounce
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      await tester.tap(
        IntegrationTestHelper.findImageAsset(NotesIcon.backIcon),
      );
      await tester.pumpAndSettle();

      expect(find.text(uniqueContent), findsWidgets);
    });

    testWidgets('Create Note With Title + Content', (tester) async {
      app.main([]);
      await tester.pumpAndSettle();

      await tester.tap(
        IntegrationTestHelper.findImageAsset(NotesIcon.createIcon),
      );
      await tester.pumpAndSettle();
      await IntegrationTestHelper.waitForEditor(tester);

      final titleField = find.byType(TextField).first;
      final uniqueTitle =
          'Test Title Mixed ${DateTime.now().millisecondsSinceEpoch}';
      await tester.enterText(titleField, uniqueTitle);
      await tester.pump(const Duration(milliseconds: 500));

      await IntegrationTestHelper.enterQuillText(tester, 'Test Content Mixed');
      await tester.pump(const Duration(milliseconds: 500));

      // Wait for debounce
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      await tester.tap(
        IntegrationTestHelper.findImageAsset(NotesIcon.backIcon),
      );
      await tester.pumpAndSettle();

      expect(find.text(uniqueTitle), findsOneWidget);
    });
  });
}
