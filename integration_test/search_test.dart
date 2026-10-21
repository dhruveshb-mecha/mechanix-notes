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

  group('Search', () {
    final helper = IntegrationTestHelper();

    setUpAll(() async {
      await helper.setUp();
    });

    tearDownAll(() async {
      await helper.tearDown();
    });

    testWidgets('search FAB is disabled when there are no notes', (
      tester,
    ) async {
      app.main([]);
      await tester.pumpAndSettle();

      expect(IntegrationTestHelper.searchFab, findsOneWidget);

      final fab = tester.widget<FloatingActionButton>(
        IntegrationTestHelper.searchFab,
      );
      expect(fab.onPressed, isNull);

      await tester.tap(IntegrationTestHelper.searchFab);
      await tester.pumpAndSettle();

      expect(find.text('Type to search'), findsNothing);
      expect(find.text('Notes'), findsWidgets);
    });

    testWidgets('opens search and shows initial prompt', (tester) async {
      app.main([]);
      await tester.pumpAndSettle();

      final suffix = DateTime.now().millisecondsSinceEpoch;
      await IntegrationTestHelper.createNoteWithTitle(
        tester,
        'Search Setup $suffix',
      );

      await IntegrationTestHelper.openSearch(tester);

      expect(find.text('Type to search'), findsOneWidget);
      expect(find.text('Search in notes'), findsOneWidget);
      expect(IntegrationTestHelper.searchTextField, findsOneWidget);
    });

    testWidgets('finds a note by title', (tester) async {
      app.main([]);
      await tester.pumpAndSettle();

      final suffix = DateTime.now().millisecondsSinceEpoch;
      final title = 'UniqueAlphaTitle $suffix';

      await IntegrationTestHelper.createNoteWithTitle(tester, title);
      await IntegrationTestHelper.createNoteWithTitle(
        tester,
        'Other Note $suffix',
      );

      await IntegrationTestHelper.openSearch(tester);
      await IntegrationTestHelper.enterSearchQuery(tester, 'UniqueAlpha');

      expect(find.text(title), findsOneWidget);
      expect(find.text('Other Note $suffix'), findsNothing);
    });

    testWidgets('finds a note by body preview text', (tester) async {
      app.main([]);
      await tester.pumpAndSettle();

      final suffix = DateTime.now().millisecondsSinceEpoch;
      final title = 'Body Search Title $suffix';
      const bodySnippet = 'zzBodySnippetzz';

      await IntegrationTestHelper.createNoteWithTitle(
        tester,
        title,
        body: bodySnippet,
      );

      await IntegrationTestHelper.openSearch(tester);
      await IntegrationTestHelper.enterSearchQuery(tester, 'BodySnippet');

      expect(find.text(title), findsOneWidget);
    });

    testWidgets('search is case insensitive', (tester) async {
      app.main([]);
      await tester.pumpAndSettle();

      final suffix = DateTime.now().millisecondsSinceEpoch;
      final title = 'CamelCaseNote $suffix';

      await IntegrationTestHelper.createNoteWithTitle(tester, title);

      await IntegrationTestHelper.openSearch(tester);
      await IntegrationTestHelper.enterSearchQuery(tester, 'camelcasenote');

      expect(find.text(title), findsOneWidget);
    });

    testWidgets('shows no results message when nothing matches', (
      tester,
    ) async {
      app.main([]);
      await tester.pumpAndSettle();

      final suffix = DateTime.now().millisecondsSinceEpoch;
      await IntegrationTestHelper.createNoteWithTitle(
        tester,
        'Some Note $suffix',
      );

      await IntegrationTestHelper.openSearch(tester);
      await IntegrationTestHelper.enterSearchQuery(
        tester,
        'xyz_no_match_$suffix',
      );

      expect(find.text('No notes found'), findsOneWidget);
    });

    testWidgets('clearing query returns to initial search prompt', (
      tester,
    ) async {
      app.main([]);
      await tester.pumpAndSettle();

      final suffix = DateTime.now().millisecondsSinceEpoch;
      await IntegrationTestHelper.createNoteWithTitle(
        tester,
        'Clear Query Note $suffix',
      );

      await IntegrationTestHelper.openSearch(tester);
      await IntegrationTestHelper.enterSearchQuery(tester, 'Clear Query');
      expect(find.text('Clear Query Note $suffix'), findsOneWidget);

      await IntegrationTestHelper.clearSearchQuery(tester);

      expect(find.text('Type to search'), findsOneWidget);
      expect(find.text('Clear Query Note $suffix'), findsNothing);
    });

    testWidgets('closes search screen and returns to home', (tester) async {
      app.main([]);
      await tester.pumpAndSettle();

      final suffix = DateTime.now().millisecondsSinceEpoch;
      await IntegrationTestHelper.createNoteWithTitle(
        tester,
        'Close Search $suffix',
      );

      await IntegrationTestHelper.openSearch(tester);
      expect(find.text('Type to search'), findsOneWidget);

      await IntegrationTestHelper.closeSearchScreen(tester);

      expect(find.text('Notes'), findsWidgets);
      expect(find.text('Type to search'), findsNothing);
    });

    testWidgets('opens a note from search results and returns to search', (
      tester,
    ) async {
      app.main([]);
      await tester.pumpAndSettle();

      final suffix = DateTime.now().millisecondsSinceEpoch;
      final title = 'Open From Search $suffix';

      await IntegrationTestHelper.createNoteWithTitle(tester, title);

      await IntegrationTestHelper.openSearch(tester);
      await IntegrationTestHelper.enterSearchQuery(tester, 'Open From Search');

      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
      await IntegrationTestHelper.waitForEditor(tester);

      expect(find.text(title), findsWidgets);
      expect(find.byType(LiveMarkdownEditor), findsOneWidget);

      await tester.tap(
        IntegrationTestHelper.findImageAsset(NotesIcon.backIcon),
      );
      await tester.pumpAndSettle();

      expect(find.text('Type to search'), findsNothing);
      expect(find.text(title), findsOneWidget);
    });

    testWidgets('shows multiple matching notes', (tester) async {
      app.main([]);
      await tester.pumpAndSettle();

      final suffix = DateTime.now().millisecondsSinceEpoch;
      final title1 = 'FindMe One $suffix';
      final title2 = 'FindMe Two $suffix';

      await IntegrationTestHelper.createNoteWithTitle(tester, title1);
      await IntegrationTestHelper.createNoteWithTitle(tester, title2);
      await IntegrationTestHelper.createNoteWithTitle(
        tester,
        'Unrelated $suffix',
      );

      await IntegrationTestHelper.openSearch(tester);
      await IntegrationTestHelper.enterSearchQuery(tester, 'FindMe');

      expect(find.text(title1), findsOneWidget);
      expect(find.text(title2), findsOneWidget);
      expect(find.text('Unrelated $suffix'), findsNothing);
    });
  });
}
