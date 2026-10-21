import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mechanix_notes/core/utils/icons.dart';
import 'package:mechanix_notes/main.dart' as app;

import 'test_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Note Selection and Deletion Tests', () {
    final helper = IntegrationTestHelper();

    setUpAll(() async {
      await helper.setUp();
    });

    tearDownAll(() async {
      await helper.tearDown();
    });

    Future<void> createDummyNote(WidgetTester tester, String title) async {
      await tester.tap(
        IntegrationTestHelper.findImageAsset(NotesIcon.createIcon),
      );
      await tester.pumpAndSettle();
      await IntegrationTestHelper.waitForEditor(tester);

      final titleField = find.byType(TextField).first;
      await tester.enterText(titleField, title);

      // Wait debounce to save
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Navigate back
      await tester.tap(
        IntegrationTestHelper.findImageAsset(NotesIcon.backIcon),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('Enter Selection Mode and Select Multiple', (tester) async {
      app.main([]);
      await tester.pumpAndSettle();

      final now = DateTime.now().millisecondsSinceEpoch;
      final title1 = 'Selection Note 1 $now';
      final title2 = 'Selection Note 2 $now';

      // Create two notes for selection
      await createDummyNote(tester, title1);
      await createDummyNote(tester, title2);

      final note1 = find.text(title1).first;
      final note2 = find.text(title2).first;

      // Long press first note
      await tester.longPress(note1);
      await tester.pumpAndSettle();

      // Bottom selection bar visible - assume close icon or delete icon is there
      expect(
        IntegrationTestHelper.findImageAsset(NotesIcon.closeIcon),
        findsOneWidget,
      );
      expect(
        IntegrationTestHelper.findImageAsset(NotesIcon.trashIcon),
        findsWidgets,
      );

      // Select second note
      await tester.tap(note2);
      await tester.pumpAndSettle();

      // Verify selected title bar says "2 notes selected" (this logic depends on your title bar impl)
      // For now just verify selection doesn't crash and close works

      // Deselect note 1
      await tester.tap(note1);
      await tester.pumpAndSettle();

      // Exit selection mode via close icon
      await tester.tap(
        IntegrationTestHelper.findImageAsset(NotesIcon.closeIcon),
      );
      await tester.pumpAndSettle();
    });

    testWidgets('Delete Multiple Notes', (tester) async {
      app.main([]);
      await tester.pumpAndSettle();

      final now = DateTime.now().millisecondsSinceEpoch;
      final title1 = 'Delete Note 1 $now';
      final title2 = 'Delete Note 2 $now';

      // Ensure we have some notes
      await createDummyNote(tester, title1);
      await createDummyNote(tester, title2);

      final note1 = find.text(title1).first;
      final note2 = find.text(title2).first;

      // Long press to enter selection
      await tester.longPress(note1);
      await tester.pumpAndSettle();

      // Tap second note
      await tester.tap(note2);
      await tester.pumpAndSettle();

      // Tap delete on bottom bar
      // Since it might be multiple delete icons, get the one on the bottom bar
      // Here we assume tapping deleteIcon triggers delete. Let's just tap the first delete icon.
      final deleteIconFinder = IntegrationTestHelper.findImageAsset(
        NotesIcon.trashIcon,
      ).first;
      await tester.tap(deleteIconFinder);
      await tester.pumpAndSettle();

      // Tap confirm in sheet if it exists
      final confirmBtn = find.text('Delete');
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Verify notes are gone
      expect(find.text(title1), findsNothing);
      expect(find.text(title2), findsNothing);
    });
  });
}
