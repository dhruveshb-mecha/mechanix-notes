import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_notes/features/notes/bloc/editor/editor_bloc.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_bloc.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_event.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/editor/editor_view.dart';
import 'package:mechanix_notes/l10n/notes_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:widgets/widgets.dart';

class MockEditorBloc extends Mock implements EditorBloc {}

class MockNotesBloc extends Mock implements NotesBloc {}

void main() {
  setUpAll(() {
    registerFallbackValue(DeleteNotes(noteIds: const []));
    registerFallbackValue(EditorSaveRequested(content: '', plainText: ''));
  });

  group('EditorView Back Navigation & PopScope Tests', () {
    late MockEditorBloc mockEditorBloc;
    late MockNotesBloc mockNotesBloc;
    late StreamController<EditorState> editorStateController;

    setUp(() {
      mockEditorBloc = MockEditorBloc();
      mockNotesBloc = MockNotesBloc();
      editorStateController = StreamController<EditorState>.broadcast();

      when(
        () => mockEditorBloc.stream,
      ).thenAnswer((_) => editorStateController.stream);
      when(() => mockNotesBloc.stream).thenAnswer((_) => const Stream.empty());
    });

    tearDown(() {
      editorStateController.close();
    });

    Widget buildTestWidget({required NavigatorObserver observer}) {
      when(() => mockEditorBloc.state).thenReturn(
        const EditorLoaded(
          noteId: 'test-note-1',
          title: 'Hello',
          markdownContent: 'Hello world\n',
          isNewNote: false,
          isContentLoading: false,
        ),
      );

      return MaterialApp(
        theme: MechanixTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        navigatorObservers: [observer],
        home: const Scaffold(body: Text('HomeScreen')),
        routes: {
          '/editor': (context) => MultiBlocProvider(
            providers: [
              BlocProvider<EditorBloc>.value(value: mockEditorBloc),
              BlocProvider<NotesBloc>.value(value: mockNotesBloc),
            ],
            child: const EditorView(),
          ),
        },
      );
    }

    testWidgets(
      'EditorSaveSuccess pops route without notifying NotesBloc',
      (tester) async {
        final mockObserver = MockNavigatorObserver();
        await tester.pumpWidget(buildTestWidget(observer: mockObserver));

        // Navigate to editor
        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        unawaited(navigator.pushNamed('/editor'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(EditorView), findsOneWidget);

        // Emit EditorSaveSuccess
        editorStateController.add(const EditorSaveSuccess('test-note-1'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));

        // The notes list updates itself from the repository
        verifyNever(() => mockNotesBloc.add(any()));

        // Verify editor is popped and HomeScreen is visible
        expect(find.byType(EditorView), findsNothing);
        expect(find.text('HomeScreen'), findsOneWidget);
      },
    );

    testWidgets(
      'EditorDiscarded with noteId pops route without notifying NotesBloc',
      (tester) async {
        final mockObserver = MockNavigatorObserver();
        await tester.pumpWidget(buildTestWidget(observer: mockObserver));

        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        unawaited(navigator.pushNamed('/editor'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));

        // Emit EditorDiscarded with noteId
        editorStateController.add(const EditorDiscarded(noteId: 'test-note-1'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));

        verifyNever(() => mockNotesBloc.add(any()));

        expect(find.byType(EditorView), findsNothing);
      },
    );

    testWidgets(
      'EditorDiscarded without noteId pops route without notifying NotesBloc',
      (tester) async {
        final mockObserver = MockNavigatorObserver();
        await tester.pumpWidget(buildTestWidget(observer: mockObserver));

        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        unawaited(navigator.pushNamed('/editor'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));

        // Emit EditorDiscarded with null noteId
        editorStateController.add(const EditorDiscarded(noteId: null));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));

        verifyNever(() => mockNotesBloc.add(any()));
        expect(find.byType(EditorView), findsNothing);
      },
    );

    testWidgets(
      'invoking pop on route triggers PopScope _saveAndExit and dispatches EditorSaveRequested',
      (tester) async {
        final mockObserver = MockNavigatorObserver();
        await tester.pumpWidget(buildTestWidget(observer: mockObserver));

        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        unawaited(navigator.pushNamed('/editor'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));

        // Attempt to pop the route (simulating Android back gesture/button)
        await navigator.maybePop();
        await tester.pump();

        // Verify that EditorSaveRequested was dispatched
        verify(
          () => mockEditorBloc.add(
            any(
              that: isA<EditorSaveRequested>().having(
                (e) => e.content,
                'content',
                'Hello world\n',
              ),
            ),
          ),
        ).called(1);
      },
    );
  });
}

class MockNavigatorObserver extends Mock implements NavigatorObserver {}
