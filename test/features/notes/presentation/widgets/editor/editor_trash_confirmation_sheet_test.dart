import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_notes/features/notes/bloc/editor/editor_bloc.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_bloc.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_event.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/editor/editor_top_bar.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/editor/editor_trash_confirmation_sheet.dart';
import 'package:mocktail/mocktail.dart';
import 'package:widgets/widgets.dart';

class MockEditorBloc extends Mock implements EditorBloc {}

class MockNotesBloc extends Mock implements NotesBloc {}

void main() {
  setUpAll(() {
    registerFallbackValue(DeleteNotes(noteIds: const []));
  });

  group('EditorTrashConfirmationSheet Widget Tests', () {
    testWidgets('renders confirmation title and CANCEL and TRASH buttons', (
      tester,
    ) async {
      var cancelled = false;
      var confirmed = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: MechanixTheme.dark,
          home: Scaffold(
            body: EditorTrashConfirmationSheet(
              onCancel: () => cancelled = true,
              onConfirm: () => confirmed = true,
            ),
          ),
        ),
      );

      expect(
        find.text('Do you want to move this note to trash?'),
        findsOneWidget,
      );
      expect(find.text('CANCEL'), findsOneWidget);
      expect(find.text('TRASH'), findsOneWidget);
      expect(find.byType(MechanixButton), findsWidgets);

      await tester.tap(find.text('CANCEL'));
      await tester.pump();
      expect(cancelled, isTrue);
      expect(confirmed, isFalse);

      await tester.tap(find.text('TRASH'));
      await tester.pump();
      expect(confirmed, isTrue);
    });

    testWidgets('EditorTrashConfirmationSheet.show opens MechanixBottomSheet', (
      tester,
    ) async {
      var confirmed = false;
      var cancelled = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: MechanixTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    EditorTrashConfirmationSheet.show(
                      context: context,
                      onConfirm: () => confirmed = true,
                      onCancel: () => cancelled = true,
                    );
                  },
                  child: const Text('Open Sheet'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(
        find.text('Do you want to move this note to trash?'),
        findsOneWidget,
      );
      expect(find.text('CANCEL'), findsOneWidget);
      expect(find.text('TRASH'), findsOneWidget);

      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();

      expect(cancelled, isTrue);
      expect(confirmed, isFalse);
      expect(
        find.text('Do you want to move this note to trash?'),
        findsNothing,
      );
    });
  });

  group('EditorTopBar Move to Trash Flow Tests', () {
    late MockEditorBloc mockEditorBloc;
    late MockNotesBloc mockNotesBloc;

    setUp(() {
      mockEditorBloc = MockEditorBloc();
      mockNotesBloc = MockNotesBloc();

      when(() => mockEditorBloc.state).thenReturn(
        const EditorLoaded(
          noteId: 'test-note-123',
          title: 'Test Note',
          isNewNote: false,
        ),
      );
      when(() => mockEditorBloc.stream).thenAnswer((_) => const Stream.empty());
      when(() => mockNotesBloc.stream).thenAnswer((_) => const Stream.empty());
    });

    Widget buildEditorTopBar() {
      return MaterialApp(
        theme: MechanixTheme.dark,
        home: MultiBlocProvider(
          providers: [
            BlocProvider<EditorBloc>.value(value: mockEditorBloc),
            BlocProvider<NotesBloc>.value(value: mockNotesBloc),
          ],
          child: const Scaffold(appBar: EditorTopBar(), body: SizedBox()),
        ),
      );
    }

    testWidgets(
      'tapping Move to trash opens confirmation sheet and CANCEL dismisses without delete',
      (tester) async {
        await tester.pumpWidget(buildEditorTopBar());

        // Open menu
        await tester.tap(find.byType(MechanixIconButton).last);
        await tester.pumpAndSettle();

        expect(find.text('Move to trash'), findsOneWidget);

        // Tap "Move to trash"
        await tester.tap(find.text('Move to trash'));
        await tester.pumpAndSettle();

        // Confirmation bottom sheet is now displayed
        expect(
          find.text('Do you want to move this note to trash?'),
          findsOneWidget,
        );
        expect(find.text('CANCEL'), findsOneWidget);
        expect(find.text('TRASH'), findsOneWidget);

        // Tap CANCEL
        await tester.tap(find.text('CANCEL'));
        await tester.pumpAndSettle();

        // Sheet is dismissed
        expect(
          find.text('Do you want to move this note to trash?'),
          findsNothing,
        );
        verifyNever(() => mockNotesBloc.add(any()));
      },
    );

    testWidgets('tapping TRASH in confirmation sheet triggers DeleteNotes', (
      tester,
    ) async {
      await tester.pumpWidget(buildEditorTopBar());

      // Open menu
      await tester.tap(find.byType(MechanixIconButton).last);
      await tester.pumpAndSettle();

      // Tap "Move to trash"
      await tester.tap(find.text('Move to trash'));
      await tester.pumpAndSettle();

      // Confirmation bottom sheet is displayed
      expect(
        find.text('Do you want to move this note to trash?'),
        findsOneWidget,
      );

      // Tap TRASH
      await tester.tap(find.text('TRASH'));
      await tester.pumpAndSettle();

      // Verify DeleteNotes was dispatched
      verify(
        () => mockNotesBloc.add(
          any(
            that: isA<DeleteNotes>().having((e) => e.noteIds, 'noteIds', [
              'test-note-123',
            ]),
          ),
        ),
      ).called(1);
    });
  });
}
