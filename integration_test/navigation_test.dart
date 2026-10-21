import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mechanix_notes/main.dart' as app;
import 'package:mechanix_notes/core/utils/icons.dart';
import 'test_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Navigation Tests', () {
    final helper = IntegrationTestHelper();

    setUpAll(() async {
      await helper.setUp();
    });

    tearDownAll(() async {
      await helper.tearDown();
    });

    testWidgets('Open Existing Note and Back Navigation', (tester) async {
      app.main([]);
      await tester.pumpAndSettle();

      // Create a note first
      await tester.tap(
        IntegrationTestHelper.findImageAsset(NotesIcon.createIcon),
      );
      await tester.pumpAndSettle();
      await IntegrationTestHelper.waitForEditor(tester);

      final titleField = find.byType(TextField).first;
      final uniqueTitle =
          'Navigation Note ${DateTime.now().millisecondsSinceEpoch}';
      await tester.enterText(titleField, uniqueTitle);

      // Wait debounce to save
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Navigate back
      await tester.tap(
        IntegrationTestHelper.findImageAsset(NotesIcon.backIcon),
      );
      await tester.pumpAndSettle();

      // Open the existing note
      final existingNote = find.text(uniqueTitle).first;
      await tester.tap(existingNote);
      await tester.pumpAndSettle();
      await IntegrationTestHelper.waitForEditor(tester);

      // Verify correct note opened
      expect(find.text(uniqueTitle), findsWidgets);

      // Navigate back again
      await tester.tap(
        IntegrationTestHelper.findImageAsset(NotesIcon.backIcon),
      );
      await tester.pumpAndSettle();

      // Return to notes list
      expect(find.text('Notes'), findsWidgets);
    });

    testWidgets('Unsaved Typing + Back', (tester) async {
      app.main([]);
      await tester.pumpAndSettle();

      await tester.tap(
        IntegrationTestHelper.findImageAsset(NotesIcon.createIcon),
      );
      await tester.pumpAndSettle();
      await IntegrationTestHelper.waitForEditor(tester);

      final titleField = find.byType(TextField).first;
      final uniqueTitle =
          'Unsaved Note ${DateTime.now().millisecondsSinceEpoch}';
      await tester.enterText(titleField, uniqueTitle);

      // Immediately go back before debounce
      await tester.tap(
        IntegrationTestHelper.findImageAsset(NotesIcon.backIcon),
      );
      await tester.pumpAndSettle();

      // Depend on implementation whether it's saved or not. We'll just verify no crash
      expect(find.text('Notes'), findsWidgets);
    });
  });
}
