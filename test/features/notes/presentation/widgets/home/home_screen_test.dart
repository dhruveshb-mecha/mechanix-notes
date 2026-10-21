import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_notes/core/utils/enums.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_bloc.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_event.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_state.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/home/home_delete_sheet.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/home/home_empty_view.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/home/home_error_widget.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/home/home_loading_view.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/home/home_notes_view.dart';
import 'package:mechanix_notes/l10n/notes_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:widgets/widgets.dart';

class MockNotesBloc extends MockBloc<NotesEvent, NotesState> implements NotesBloc {}

void main() {
  late MockNotesBloc mockNotesBloc;

  setUp(() {
    mockNotesBloc = MockNotesBloc();
  });

  Widget buildAppWithNotesBloc({required Widget child}) {
    return BlocProvider<NotesBloc>.value(
      value: mockNotesBloc,
      child: MaterialApp(
        theme: MechanixTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );
  }

  group('HomeScreen & HomeNotesView Widget Tests', () {
    testWidgets('renders HomeLoadingView when state.isLoading is true', (tester) async {
      when(() => mockNotesBloc.state).thenReturn(
        const NotesState(isLoading: true, groupedNotes: []),
      );

      await tester.pumpWidget(buildAppWithNotesBloc(child: const HomeNotesView()));
      await tester.pump();

      expect(find.byType(HomeLoadingView), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders HomeEmptyView when state has no notes and not loading', (tester) async {
      when(() => mockNotesBloc.state).thenReturn(
        const NotesState(isLoading: false, groupedNotes: []),
      );

      await tester.pumpWidget(buildAppWithNotesBloc(child: const HomeNotesView()));
      await tester.pump();

      expect(find.byType(HomeEmptyView), findsOneWidget);
    });

    testWidgets('renders HomeErrorView with localized message when error is failedToLoadNotes', (tester) async {
      when(() => mockNotesBloc.state).thenReturn(
        const NotesState(
          isLoading: false,
          error: ErrorCategory.failedToLoadNotes,
          groupedNotes: [],
        ),
      );

      await tester.pumpWidget(buildAppWithNotesBloc(child: const HomeNotesView()));
      await tester.pump();

      expect(find.byType(HomeErrorView), findsOneWidget);
      expect(find.text('Failed to load notes. Please try again.'), findsOneWidget);
    });

    testWidgets('renders HomeErrorView with localized message when error is appAlreadyRunning', (tester) async {
      when(() => mockNotesBloc.state).thenReturn(
        const NotesState(
          isLoading: false,
          error: ErrorCategory.appAlreadyRunning,
          groupedNotes: [],
        ),
      );

      await tester.pumpWidget(buildAppWithNotesBloc(child: const HomeNotesView()));
      await tester.pump();

      expect(find.byType(HomeErrorView), findsOneWidget);
      expect(find.text('Another instance of the app is already running.'), findsOneWidget);
    });
  });

  group('HomeDeleteSheet Widget Tests', () {
    testWidgets('renders singular title and subtitle when selectedCount is 1', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: MechanixTheme.dark,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: HomeDeleteSheet(
              selectedCount: 1,
              onDelete: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Delete 1 note?'), findsOneWidget);
      expect(
        find.text('This note will be permanently deleted and cannot be recovered.'),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('renders plural title and subtitle when selectedCount is 3', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: MechanixTheme.dark,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: HomeDeleteSheet(
              selectedCount: 3,
              onDelete: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Delete 3 notes?'), findsOneWidget);
      expect(
        find.text('These notes will be permanently deleted and cannot be recovered.'),
        findsOneWidget,
      );
    });

    testWidgets('tapping DELETE triggers onDelete callback', (tester) async {
      bool deleted = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: MechanixTheme.dark,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: HomeDeleteSheet(
              selectedCount: 2,
              onDelete: () => deleted = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(deleted, isTrue);
    });

    testWidgets('tapping Cancel or close icon dismisses modal sheet', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: MechanixTheme.dark,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (_) => HomeDeleteSheet(
                        selectedCount: 1,
                        onDelete: () {},
                      ),
                    );
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open sheet
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeDeleteSheet), findsOneWidget);

      // Tap cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeDeleteSheet), findsNothing);
    });
  });
}
