import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mechanix_notes/main.dart' as app;
import 'package:mechanix_notes/core/utils/icons.dart';
import 'test_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Performance Tests', () {
    final helper = IntegrationTestHelper();

    setUpAll(() async {
      await helper.setUp();
    });

    tearDownAll(() async {
      await helper.tearDown();
    });

    testWidgets('App Startup and List Load', (tester) async {
      app.main([]);
      await tester.pumpAndSettle();

      expect(find.text('Notes'), findsWidgets);
    });

    testWidgets('Editor Typing Performance', (tester) async {
      app.main([]);
      await tester.pumpAndSettle();

      await tester.tap(
        IntegrationTestHelper.findImageAsset(NotesIcon.createIcon),
      );
      await tester.pumpAndSettle();
      await IntegrationTestHelper.waitForEditor(tester);

      final titleField = find.byType(TextField).first;

      // Type continuously and pump
      final now = DateTime.now().millisecondsSinceEpoch;
      for (int i = 0; i < 20; i++) {
        await tester.enterText(titleField, 'Typing $i $now');
        await tester.pump(const Duration(milliseconds: 100));
      }

      await IntegrationTestHelper.enterQuillText(
        tester,
        'Continuous quill typing',
      );
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

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
  });
}
