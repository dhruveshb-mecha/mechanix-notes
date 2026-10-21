import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mechanix_notes/main.dart' as app;
import 'package:mechanix_notes/core/utils/icons.dart';
import 'test_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Notes List Screen', () {
    final helper = IntegrationTestHelper();

    setUpAll(() async {
      await helper.setUp();
    });

    tearDownAll(() async {
      await helper.tearDown();
    });

    testWidgets('Initial Load', (tester) async {
      app.main([]);
      await tester.pumpAndSettle();

      // “Notes” title is visible
      expect(find.text('Notes'), findsWidgets);

      // Floating add button is visible
      expect(
        IntegrationTestHelper.findImageAsset(NotesIcon.createIcon),
        findsOneWidget,
      );

      // Grid icon is visible (Not yet implemented in UI)
      // expect(IntegrationTestHelper.findImageAsset(NotesIcon.gridIcon), findsOneWidget);

      // Search button is visible (Commented out in UI)
      // expect(IntegrationTestHelper.findImageAsset(NotesIcon.searchIcon), findsOneWidget);
    });
  });
}
