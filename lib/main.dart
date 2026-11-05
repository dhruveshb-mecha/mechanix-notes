import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_common/mechanix_common.dart';
import 'package:mechanix_notes/core/utils/app_routes.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_bloc.dart';
import 'package:mechanix_notes/features/notes/data/repository/note_repository.dart';
import 'package:mechanix_notes/features/notes/data/repository/note_repository_impl.dart';
import 'package:mechanix_notes/features/notes/presentation/screens/editor.dart';
import 'package:mechanix_notes/features/notes/presentation/screens/home.dart';
import 'package:mechanix_notes/features/notes/presentation/screens/search.dart';
import 'package:mechanix_notes/l10n/notes_localizations.dart';
import 'package:widgets/widgets.dart';

void main(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();

  final _ = args.isNotEmpty ? args.first : null;
  MechanixApp.registerSingleton('MechanixNotes', (path) {});

  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<NoteRepository>(
          create: (_) => NoteRepositoryImpl(),
          dispose: (repository) => repository.close(),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) =>
                NotesBloc(noteRepository: context.read<NoteRepository>()),
          ),
        ],
        child: const NotesApp(),
      ),
    ),
  );
}

class NotesApp extends StatelessWidget {
  const NotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Enable it to check run time fps with show_fps dependency
    // final showFps = Platform.environment['SHOW_FPS'] == 'true';

    return MechanixTheme(
      builder: (context, theme, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          // builder: showFps
          //     ? (context, child) {
          //         return ShowFPS(
          //           visible: showFps,
          //           showChart: false,
          //           child: child!,
          //         );
          //       }
          //     : null,
          themeMode: ThemeMode.dark,
          darkTheme: theme.dark.copyWith(
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
              },
            ),
          ),
          theme: theme.light.copyWith(
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
              },
            ),
          ),
          home: child,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routes: {
            AppRoutes.noteEditor: (context) => const EditorScreen(),
            AppRoutes.search: (context) => const SearchScreen(),
          },
        );
      },
      child: const HomeScreen(),
    );
  }
}
