import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/search/search_bar.dart';
import 'package:mechanix_notes/l10n/notes_localizations.dart';
import 'package:widgets/widgets.dart';

void main() {
  group('SearchAppBar Localization Tests', () {
    late TextEditingController controller;
    late FocusNode focusNode;

    setUp(() {
      controller = TextEditingController();
      focusNode = FocusNode();
    });

    tearDown(() {
      controller.dispose();
      focusNode.dispose();
    });

    Widget buildTestWidget({
      bool isSearchActive = false,
      Widget? title,
      String? searchHint,
    }) {
      return MaterialApp(
        theme: MechanixTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          appBar: SearchAppBar(
            isSearchActive: isSearchActive,
            controller: controller,
            focusNode: focusNode,
            title: title,
            searchHint: searchHint,
          ),
          body: const SizedBox(),
        ),
      );
    }

    testWidgets('renders localized NOTES title when collapsed', (tester) async {
      await tester.pumpWidget(buildTestWidget(isSearchActive: false));
      await tester.pumpAndSettle();

      expect(find.text('NOTES'), findsOneWidget);
    });

    testWidgets('renders localized SEARCH NOTE hint in active search mode', (tester) async {
      await tester.pumpWidget(buildTestWidget(isSearchActive: true));
      await tester.pumpAndSettle();

      expect(find.text('SEARCH NOTE'), findsOneWidget);
    });
  });
}
