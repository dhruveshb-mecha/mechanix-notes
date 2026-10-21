import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_markdown_editor/live_markdown_editor.dart';
import 'package:mechanix_notes/features/notes/bloc/editor/editor_bloc.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_bloc.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/editor/editor_top_bar.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/editor/markdown_controller_provider.dart';
import 'package:mechanix_notes/l10n/notes_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:widgets/widgets.dart';

class MockEditorBloc extends Mock implements EditorBloc {}

class MockNotesBloc extends Mock implements NotesBloc {}

void main() {
  setUpAll(() {
    registerFallbackValue(EditorSaveRequested(content: '', plainText: ''));
    registerFallbackValue(EditorPinToggled());
  });

  group('EditorTopBar Back Button Tests', () {
    late MockEditorBloc mockEditorBloc;
    late MockNotesBloc mockNotesBloc;
    late MarkdownEditorController markdownController;
    late FocusNode focusNode;

    setUp(() {
      mockEditorBloc = MockEditorBloc();
      mockNotesBloc = MockNotesBloc();
      markdownController = MarkdownEditorController();
      focusNode = FocusNode();

      when(() => mockEditorBloc.state).thenReturn(
        const EditorLoaded(
          noteId: 'test-note-1',
          title: 'Title',
          isNewNote: true,
        ),
      );
      when(() => mockEditorBloc.stream).thenAnswer((_) => const Stream.empty());
      when(() => mockNotesBloc.stream).thenAnswer((_) => const Stream.empty());
    });

    tearDown(() {
      markdownController.dispose();
      focusNode.dispose();
    });

    Widget buildTestWidget({bool withMarkdownController = true}) {
      final child = MultiBlocProvider(
        providers: [
          BlocProvider<EditorBloc>.value(value: mockEditorBloc),
          BlocProvider<NotesBloc>.value(value: mockNotesBloc),
        ],
        child: const Scaffold(appBar: EditorTopBar(), body: SizedBox()),
      );

      if (withMarkdownController) {
        return MaterialApp(
          theme: MechanixTheme.dark,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MarkdownControllerProvider(
            controller: markdownController,
            focusNode: focusNode,
            child: child,
          ),
        );
      }

      return MaterialApp(
        theme: MechanixTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      );
    }

    testWidgets(
      'tapping back button extracts Markdown content and plainText and dispatches EditorSaveRequested',
      (tester) async {
        markdownController.text = 'My note content\n';

        await tester.pumpWidget(buildTestWidget(withMarkdownController: true));

        // Find the back icon button (first MechanixIconButton)
        final backButton = find.byType(MechanixIconButton).first;
        expect(backButton, findsOneWidget);

        await tester.tap(backButton);
        await tester.pump();

        // Verify that EditorSaveRequested was dispatched with content and plain text
        verify(
          () => mockEditorBloc.add(
            any(
              that: isA<EditorSaveRequested>().having(
                (e) => e.content,
                'content',
                'My note content\n',
              ),
            ),
          ),
        ).called(1);
      },
    );

    testWidgets(
      'tapping back button without MarkdownControllerProvider falls back to Navigator.maybePop',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: MechanixTheme.dark,
            home: const Scaffold(body: Text('Home')),
            routes: {
              '/editor': (context) => MultiBlocProvider(
                providers: [
                  BlocProvider<EditorBloc>.value(value: mockEditorBloc),
                  BlocProvider<NotesBloc>.value(value: mockNotesBloc),
                ],
                child: const Scaffold(appBar: EditorTopBar(), body: SizedBox()),
              ),
            },
          ),
        );

        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        unawaited(navigator.pushNamed('/editor'));
        await tester.pumpAndSettle();

        final backButton = find.byType(MechanixIconButton).first;
        await tester.tap(backButton);
        await tester.pumpAndSettle();

        expect(find.byType(EditorTopBar), findsNothing);
        expect(find.text('Home'), findsOneWidget);
        verifyNever(() => mockEditorBloc.add(any()));
      },
    );

    testWidgets('tapping pin menu item dispatches EditorPinToggled', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(withMarkdownController: true));

      // Open menu (last MechanixIconButton)
      final menuButton = find.byType(MechanixIconButton).last;
      await tester.tap(menuButton);
      await tester.pumpAndSettle();

      // Find "Pin note" item
      final pinItem = find.text('Pin note');
      expect(pinItem, findsOneWidget);

      await tester.tap(pinItem);
      await tester.pumpAndSettle();

      verify(
        () => mockEditorBloc.add(any(that: isA<EditorPinToggled>())),
      ).called(1);
    });

    testWidgets(
      'more vert background color is surfaceContainer when menu is open, surfaceContainerLowest when closed',
      (tester) async {
        await tester.pumpWidget(buildTestWidget(withMarkdownController: true));

        final colorScheme = MechanixTheme.dark.colorScheme;
        final menuButtonFinder = find.byType(MechanixIconButton).last;

        // Initially closed: background color is surfaceContainerLowest (app bar color)
        expect(
          (tester.widget(menuButtonFinder) as MechanixIconButton).backgroundColor,
          equals(colorScheme.surfaceContainerLowest),
        );

        // Open menu
        await tester.tap(menuButtonFinder);
        await tester.pumpAndSettle();

        // While open: background color is surfaceContainer
        expect(
          (tester.widget(menuButtonFinder) as MechanixIconButton).backgroundColor,
          equals(colorScheme.surfaceContainer),
        );

        // Close menu by selecting an item
        final pinItem = find.text('Pin note');
        await tester.tap(pinItem);
        await tester.pumpAndSettle();

        // Closed: background color is back to surfaceContainerLowest
        expect(
          (tester.widget(menuButtonFinder) as MechanixIconButton).backgroundColor,
          equals(colorScheme.surfaceContainerLowest),
        );
      },
    );
  });
}
