import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_notes/features/notes/bloc/search/search_bloc.dart';
import 'package:mechanix_notes/features/notes/bloc/search/search_event.dart';
import 'package:mechanix_notes/features/notes/bloc/search/search_state.dart';
import 'package:mechanix_notes/features/notes/data/models/note_metadata.dart';
import 'package:mechanix_notes/features/notes/data/repository/note_repository.dart';
import 'package:mechanix_notes/features/notes/presentation/screens/search.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/search/search_message_view.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/search/search_view.dart';
import 'package:mechanix_notes/l10n/notes_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:widgets/widgets.dart';

class MockNoteRepository extends Mock implements NoteRepository {}

class MockSearchBloc extends MockBloc<SearchEvent, SearchState>
    implements SearchBloc {}

void main() {
  late MockNoteRepository mockRepository;
  late MockSearchBloc mockSearchBloc;

  setUp(() {
    mockRepository = MockNoteRepository();
    mockSearchBloc = MockSearchBloc();
  });

  Widget buildAppWithRepository({Widget? child}) {
    return RepositoryProvider<NoteRepository>.value(
      value: mockRepository,
      child: MaterialApp(
        theme: MechanixTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child ?? const SearchScreen(),
      ),
    );
  }

  Widget buildAppWithBloc({required Widget child}) {
    return BlocProvider<SearchBloc>.value(
      value: mockSearchBloc,
      child: MaterialApp(
        theme: MechanixTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );
  }

  NoteMetaData createNote({
    required String id,
    required String title,
    String preview = '',
    DateTime? updatedAt,
  }) {
    return NoteMetaData(
      id: id,
      title: title,
      previewText: preview,
      updatedAt: updatedAt ?? DateTime(2026, 10, 1),
      createdAt: DateTime(2026, 10, 1),
      height: 200,
    );
  }

  group('SearchScreen & SearchView Widget Tests', () {
    testWidgets(
      'renders search text field initially focused and in clean state',
      (tester) async {
        when(
          () => mockRepository.searchNotes(any()),
        ).thenAnswer((_) async => []);

        await tester.pumpWidget(buildAppWithRepository());
        await tester.pumpAndSettle();

        expect(find.byType(TextField), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byType(SearchMessageView), findsNothing);
      },
    );

    testWidgets(
      'typing search query dispatches search and shows loading and results',
      (tester) async {
        final note = createNote(
          id: '1',
          title: 'Buy Groceries',
          preview: 'Milk, Eggs',
        );
        when(
          () => mockRepository.searchNotes('Groceries'),
        ).thenAnswer((_) async => [note]);

        await tester.pumpWidget(buildAppWithRepository());
        await tester.pumpAndSettle();

        final textField = find.byType(TextField);
        await tester.enterText(textField, 'Groceries');

        // Wait for debounce (250ms)
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        verify(() => mockRepository.searchNotes('Groceries')).called(1);
        expect(find.text('Buy Groceries'), findsOneWidget);
      },
    );

    testWidgets(
      'shows loading spinner when status is loading with empty results',
      (tester) async {
        when(() => mockSearchBloc.state).thenReturn(
          const SearchState(status: SearchStatus.loading, results: []),
        );

        await tester.pumpWidget(buildAppWithBloc(child: const SearchView()));
        // Don't pumpAndSettle as circular progress indicator animates continuously
        await tester.pump();

        // Enter a query so that SearchList does not show SizedBox.shrink
        final textField = find.byType(TextField);
        await tester.enterText(textField, 'test');
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      },
    );

    testWidgets('shows error message when status is failure', (tester) async {
      when(() => mockSearchBloc.state).thenReturn(
        const SearchState(status: SearchStatus.failure, results: []),
      );

      await tester.pumpWidget(buildAppWithBloc(child: const SearchView()));
      await tester.pump();

      final textField = find.byType(TextField);
      await tester.enterText(textField, 'error_query');
      await tester.pump();

      expect(find.byType(SearchMessageView), findsOneWidget);
      expect(find.text('Failed to perform search'), findsOneWidget);
    });

    testWidgets('shows empty results view when query has no matches', (
      tester,
    ) async {
      when(() => mockSearchBloc.state).thenReturn(
        const SearchState(status: SearchStatus.success, results: []),
      );

      await tester.pumpWidget(buildAppWithBloc(child: const SearchView()));
      await tester.pump();

      final textField = find.byType(TextField);
      await tester.enterText(textField, 'unmatched');
      await tester.pump();

      expect(find.byType(SearchMessageView), findsOneWidget);
      expect(find.text('No note found'), findsOneWidget);
    });

    testWidgets('renders results with TextSpan highlighting on matching text', (
      tester,
    ) async {
      final note = createNote(
        id: '1',
        title: 'Flutter Testing',
        preview: 'Widget and unit',
      );
      when(
        () => mockSearchBloc.state,
      ).thenReturn(SearchState(status: SearchStatus.success, results: [note]));

      await tester.pumpWidget(buildAppWithBloc(child: const SearchView()));
      await tester.pump();

      // Set the query in the search bar so SearchView passes it to SearchList
      final textField = find.byType(TextField);
      await tester.enterText(textField, 'Testing');
      await tester.pump();

      expect(find.text('Widget and unit'), findsOneWidget);

      // Verify Text.rich with TextSpan styling
      bool foundHighlightedSpan = false;
      final richTextWidgets = tester.widgetList<RichText>(
        find.byType(RichText),
      );

      for (final richText in richTextWidgets) {
        richText.text.visitChildren((InlineSpan span) {
          if (span is TextSpan && span.text == 'Testing') {
            foundHighlightedSpan = true;
            expect(span.style?.color, isNotNull);
            return false; // stop visiting
          }
          return true;
        });
        if (foundHighlightedSpan) break;
      }

      expect(
        foundHighlightedSpan,
        isTrue,
        reason: 'Highlighted TextSpan for "Testing" not found',
      );
    });

    testWidgets('tapping search result invokes onResultSelected callback', (
      tester,
    ) async {
      final note = createNote(
        id: '1',
        title: 'Selectable Note',
        preview: 'Tap me',
      );
      when(
        () => mockSearchBloc.state,
      ).thenReturn(SearchState(status: SearchStatus.success, results: [note]));

      NoteMetaData? selectedNote;

      await tester.pumpWidget(
        buildAppWithBloc(
          child: SearchView(onResultSelected: (n) => selectedNote = n),
        ),
      );
      await tester.pump();

      final textField = find.byType(TextField);
      await tester.enterText(textField, 'Selectable');
      await tester.pump();

      await tester.tap(find.text('Tap me'));
      await tester.pumpAndSettle();

      expect(selectedNote, equals(note));
    });
  });
}
