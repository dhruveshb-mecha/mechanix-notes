import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mechanix_notes/core/utils/icons.dart';
import 'package:mechanix_notes/main.dart' as app;

import 'test_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Delete Note Tests', () {
    final helper = IntegrationTestHelper();

    setUpAll(() async {
      await helper.setUp();
    });

    tearDownAll(() async {
      await helper.tearDown();
    });

    testWidgets('Delete Single Note from Home', (tester) async {
      app.main([]);
      await tester.pumpAndSettle();

      final uniqueTitle =
          'Delete Me Note ${DateTime.now().millisecondsSinceEpoch}';

      // Create a note
      await tester.tap(
        IntegrationTestHelper.findImageAsset(NotesIcon.createIcon),
      );
      await tester.pumpAndSettle();
      await IntegrationTestHelper.waitForEditor(tester);

      final titleField = find.byType(TextField).first;
      await tester.enterText(titleField, uniqueTitle);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Tap back to save and go to home
      await tester.tap(
        IntegrationTestHelper.findEditorButton(NotesIcon.backIcon),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Verify note exists on home
      expect(find.text(uniqueTitle), findsOneWidget);

      // Long press to select
      await tester.longPress(find.text(uniqueTitle));
      await tester.pumpAndSettle();

      // Tap delete icon in bottom bar
      await tester.tap(
        IntegrationTestHelper.findImageAsset(NotesIcon.trashIcon),
      );
      await tester.pumpAndSettle();

      // Confirm delete
      final confirmBtn = find.text('Delete');
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Verify note is gone
      expect(find.text(uniqueTitle), findsNothing);
    });

    testWidgets('Delete Cancel Flow', (tester) async {
      app.main([]);
      await tester.pumpAndSettle();

      final uniqueTitle =
          'Do Not Delete Note ${DateTime.now().millisecondsSinceEpoch}';

      // Create a note
      await tester.tap(
        IntegrationTestHelper.findImageAsset(NotesIcon.createIcon),
      );
      await tester.pumpAndSettle();
      await IntegrationTestHelper.waitForEditor(tester);

      final titleField = find.byType(TextField).first;
      await tester.enterText(titleField, uniqueTitle);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Tap back to save and go to home
      await tester.tap(
        IntegrationTestHelper.findEditorButton(NotesIcon.backIcon),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Verify note exists on home
      expect(find.text(uniqueTitle), findsOneWidget);

      // Long press to select
      await tester.longPress(find.text(uniqueTitle));
      await tester.pumpAndSettle();

      // Tap delete icon in bottom bar
      await tester.tap(
        IntegrationTestHelper.findImageAsset(NotesIcon.trashIcon),
      );
      await tester.pumpAndSettle();

      // Tap cancel in sheet
      final cancelBtn = find.text('Cancel');
      expect(cancelBtn, findsOneWidget);
      await tester.tap(cancelBtn);
      await tester.pumpAndSettle();

      // Verify note is still there
      expect(find.text(uniqueTitle), findsOneWidget);
    });
  });
}
