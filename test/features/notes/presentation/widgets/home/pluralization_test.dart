import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_notes/l10n/notes_localizations.dart';

void main() {
  group('Localization Pluralization Tests', () {
    Widget buildLocaleApp({required Widget Function(AppLocalizations l10n) builder}) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context)!;
              return builder(l10n);
            },
          ),
        ),
      );
    }

    testWidgets('notesSelected pluralization for 0, 1, and N notes', (tester) async {
      late String zeroSelected;
      late String oneSelected;
      late String multipleSelected;

      await tester.pumpWidget(
        buildLocaleApp(
          builder: (l10n) {
            zeroSelected = l10n.notesSelected(0);
            oneSelected = l10n.notesSelected(1);
            multipleSelected = l10n.notesSelected(5);
            return Text('$zeroSelected | $oneSelected | $multipleSelected');
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(zeroSelected, '0 notes selected');
      expect(oneSelected, '1 note selected');
      expect(multipleSelected, '5 notes selected');
    });

    testWidgets('deleteNotePromptTitle pluralization for 1 and N notes', (tester) async {
      late String singlePrompt;
      late String multiplePrompt;

      await tester.pumpWidget(
        buildLocaleApp(
          builder: (l10n) {
            singlePrompt = l10n.deleteNotePromptTitle(1);
            multiplePrompt = l10n.deleteNotePromptTitle(4);
            return Text('$singlePrompt | $multiplePrompt');
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(singlePrompt, 'Delete 1 note?');
      expect(multiplePrompt, 'Delete 4 notes?');
    });

    testWidgets('deleteNotePromptSubtitle pluralization for 1 and N notes', (tester) async {
      late String singleSubtitle;
      late String multipleSubtitle;

      await tester.pumpWidget(
        buildLocaleApp(
          builder: (l10n) {
            singleSubtitle = l10n.deleteNotePromptSubtitle(1);
            multipleSubtitle = l10n.deleteNotePromptSubtitle(10);
            return Text('$singleSubtitle | $multipleSubtitle');
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(
        singleSubtitle,
        'This note will be permanently deleted and cannot be recovered.',
      );
      expect(
        multipleSubtitle,
        'These notes will be permanently deleted and cannot be recovered.',
      );
    });

    testWidgets('minutesAgo and hoursAgo formatting', (tester) async {
      late String oneMin;
      late String manyMin;
      late String oneHour;
      late String manyHours;

      await tester.pumpWidget(
        buildLocaleApp(
          builder: (l10n) {
            oneMin = l10n.minutesAgo(1);
            manyMin = l10n.minutesAgo(25);
            oneHour = l10n.hoursAgo(1);
            manyHours = l10n.hoursAgo(6);
            return Text('$oneMin | $manyMin | $oneHour | $manyHours');
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(oneMin, '1 m ago');
      expect(manyMin, '25 m ago');
      expect(oneHour, '1 h ago');
      expect(manyHours, '6 h ago');
    });
  });
}
