import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mechanix_notes/main.dart' as app;
import 'package:mechanix_notes/core/utils/icons.dart';
import 'test_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Edge Cases Tests', () {
    final helper = IntegrationTestHelper();

    setUpAll(() async {
      await helper.setUp();
    });

    tearDownAll(() async {
      await helper.tearDown();
    });

    testWidgets('Very Long Title', (tester) async {
      app.main([]);
      await tester.pumpAndSettle();

      await tester.tap(
        IntegrationTestHelper.findImageAsset(NotesIcon.createIcon),
      );
      await tester.pumpAndSettle();
      await IntegrationTestHelper.waitForEditor(tester);

      final titleField = find.byType(TextField).first;
      final longTitle = 'A' * 200;
      await tester.enterText(titleField, longTitle);

      // Wait debounce
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Back
      await tester.tap(
        IntegrationTestHelper.findImageAsset(NotesIcon.backIcon),
      );
      await tester.pumpAndSettle();

      // Verify no overflow by pumping
      expect(find.text('Notes'), findsWidgets);
    });

    testWidgets('Very Long Content', (tester) async {
      app.main([]);
      await tester.pumpAndSettle();

      await tester.tap(
        IntegrationTestHelper.findImageAsset(NotesIcon.createIcon),
      );
      await tester.pumpAndSettle();
      await IntegrationTestHelper.waitForEditor(tester);

      final longContent = 'B' * 1000;
      await IntegrationTestHelper.enterQuillText(tester, longContent);

      // Wait debounce
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Back
      await tester.tap(
        IntegrationTestHelper.findImageAsset(NotesIcon.backIcon),
      );
      await tester.pumpAndSettle();

      expect(find.text('Notes'), findsWidgets);
    });

    testWidgets('Empty Note Handling', (tester) async {
      app.main([]);
      await tester.pumpAndSettle();

      await tester.tap(
        IntegrationTestHelper.findImageAsset(NotesIcon.createIcon),
      );
      await tester.pumpAndSettle();
      await IntegrationTestHelper.waitForEditor(tester);

      // Leave empty and go back immediately or after debounce
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      await tester.tap(
        IntegrationTestHelper.findImageAsset(NotesIcon.backIcon),
      );
      await tester.pumpAndSettle();

      expect(find.text('Notes'), findsWidgets);
    });

    testWidgets('Rapid Open/Close', (tester) async {
      app.main([]);
      await tester.pumpAndSettle();

      for (int i = 0; i < 3; i++) {
        await tester.tap(
          IntegrationTestHelper.findImageAsset(NotesIcon.createIcon),
        );
        await tester.pumpAndSettle();
        await IntegrationTestHelper.waitForEditor(tester);

        await tester.tap(
          IntegrationTestHelper.findImageAsset(NotesIcon.backIcon),
        );
        await tester.pumpAndSettle();
      }

      expect(find.text('Notes'), findsWidgets);
    });
  });
}
