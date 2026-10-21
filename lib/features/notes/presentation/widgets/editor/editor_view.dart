import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:live_markdown_editor/live_markdown_editor.dart';
import 'package:mechanix_notes/core/utils/helper.dart';
import 'package:mechanix_notes/features/notes/bloc/editor/editor_bloc.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_bloc.dart';
import 'package:mechanix_notes/features/notes/bloc/notes/notes_event.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/editor/editor_bottom_bar.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/editor/editor_content.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/editor/editor_top_bar.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/editor/markdown_controller_provider.dart';
import 'package:mechanix_notes/l10n/notes_localizations.dart';
import 'package:widgets/widgets.dart';

class EditorView extends StatefulWidget {
  const EditorView({super.key});

  @override
  State<EditorView> createState() => _EditorViewState();
}

class _EditorViewState extends State<EditorView> {
  MarkdownEditorController? _controller;
  late final FocusNode _focusNode;
  bool _canPop = false;
  bool _isSavingAndExiting = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    final currentState = context.read<EditorBloc>().state;
    if (currentState is EditorLoaded && !currentState.isContentLoading) {
      _controller = MarkdownEditorController(
        text: currentState.markdownContent,
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _initController(String markdown) {
    setState(() {
      _controller?.dispose();
      _controller = MarkdownEditorController(text: markdown);
    });
  }

  void _saveAndExit() {
    if (_isSavingAndExiting) return;
    _isSavingAndExiting = true;
    if (_controller != null) {
      final markdown = _controller!.text;
      context.read<EditorBloc>().add(EditorSaveRequested(content: markdown));
    } else {
      _canPop = true;
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<EditorBloc, EditorState>(
      // listener for states
      listener: (context, state) {
        if (state is EditorLoaded &&
            !state.isContentLoading &&
            _controller == null) {
          _initController(state.markdownContent);
        }
        if (state is EditorDiscarded) {
          if (state.noteId != null) {
            context.read<NotesBloc>().add(RefreshNote(noteId: state.noteId!));
          }
          _canPop = true;
          Navigator.of(context).pop();
        }
        if (state is EditorSaveSuccess) {
          context.read<NotesBloc>().add(RefreshNote(noteId: state.noteId));
          _canPop = true;
          Navigator.of(context).pop();
        }
        if (state is EditorDeleteRequest) {
          context.read<NotesBloc>().add(DeleteNotes(noteIds: [state.noteId]));
          _canPop = true;
          Navigator.of(context).pop();
        }
        if (state is EditorFailure) {
          _isSavingAndExiting = false;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(localizeError(context, state.error))),
          );
        }
      },
      // builder
      builder: (context, state) {
        if (state is EditorInitial) {
          return Scaffold(
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerLowest,

            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (state is EditorLoaded ||
            state is EditorSaveSuccess ||
            state is EditorDiscarded ||
            state is EditorDeleteRequest) {
          final shell = Scaffold(
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerLowest,

            appBar: const EditorTopBar(),
            body: _controller == null
                ? const Center(child: CircularProgressIndicator())
                : const Stack(
                    children: [
                      Positioned.fill(child: EditorContent()),
                      Positioned(
                        left: 26,
                        right: 26,
                        bottom: 20,
                        child: SafeArea(
                          top: false,
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: EditorBottomBar(),
                          ),
                        ),
                      ),
                    ],
                  ),
          );

          final wrappedShell = PopScope(
            canPop: _canPop,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) return;
              _saveAndExit();
            },
            child: shell,
          );

          if (_controller != null) {
            return MarkdownControllerProvider(
              controller: _controller!,
              focusNode: _focusNode,
              child: wrappedShell,
            );
          }

          return wrappedShell;
        }

        if (state is EditorFailure) {
          return Scaffold(
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerLowest,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: context.colorScheme.error,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    localizeError(context, state.error),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      backgroundColor: context.colorScheme.error,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      AppLocalizations.of(context)!.goBack,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
          body: const Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}
