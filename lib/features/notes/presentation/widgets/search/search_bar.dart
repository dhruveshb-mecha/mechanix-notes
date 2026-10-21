import 'package:flutter/material.dart';
import 'package:mechanix_notes/core/utils/icons.dart';
import 'package:mechanix_notes/l10n/notes_localizations.dart';
import 'package:widgets/widgets.dart';

class SearchAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SearchAppBar({
    super.key,
    required this.isSearchActive,
    required this.controller,
    required this.focusNode,
    this.title,
    this.searchHint,
    this.onQueryChanged,
    this.onSubmitted,
    this.onSearchIconTap,
    this.onClear,
    this.onClose,
    this.autofocus = true,
    this.searchWidget,
    this.searchDecoration,
  });

  /// Optional custom search widget to override the default search widget.
  final Widget? searchWidget;

  /// Optional decoration for the search widget container.
  final Decoration? searchDecoration;

  /// Whether the app bar is in active search mode.
  final bool isSearchActive;

  /// Text controller for the search input.
  final TextEditingController controller;

  /// Focus node for the search input.
  final FocusNode focusNode;

  /// Title displayed in the collapsed state.
  final Widget? title;

  /// Placeholder hint text in active search mode.
  final String? searchHint;

  /// Called when the search query text changes.
  final ValueChanged<String>? onQueryChanged;

  /// Called when the search query is submitted.
  final ValueChanged<String>? onSubmitted;

  /// Called when the search icon in collapsed mode is tapped.
  final VoidCallback? onSearchIconTap;

  /// Called when the clear (X) button is pressed while text is present.
  final VoidCallback? onClear;

  /// Called when closing the search mode.
  final VoidCallback? onClose;

  /// Whether the search field should autofocus when entering active mode.
  final bool autofocus;

  static final Size _preferredSize = const MechanixAppBar.small().preferredSize;

  @override
  Size get preferredSize => _preferredSize;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final effectiveTitle =
        title ?? Text((l10n?.notes ?? 'Notes').toUpperCase());
    final effectiveSearchHint =
        searchHint ?? (l10n?.searchNote ?? 'Search note').toUpperCase();

    if (!isSearchActive) {
      final searchAction = MechanixIconButton.standard(
        icon: Image.asset(NotesIcon.searchIcon, width: 20, height: 20),
        onPressed: () {
          focusNode.requestFocus();
          onSearchIconTap?.call();
        },
      );

      return MechanixAppBar.small(
        title: effectiveTitle,
        actions: [searchAction],
        backgroundColor: context.colorScheme.surfaceContainerLowest,
      );
    }

    final colorScheme = context.colorScheme;
    final textTheme = context.textTheme;

    return MechanixAppBar.search(
      primary: false,
      automaticallyImplyLeading: false,
      backgroundColor: colorScheme.surfaceContainerLowest,
      searchWidget:
          searchWidget ??
          Container(
            height: 44,
            decoration: searchDecoration,
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Image.asset(
                  NotesIcon.searchIcon,
                  color: colorScheme.onSurfaceVariant,
                  width: 19.5,
                  height: 19.5,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    autofocus: autofocus,
                    textInputAction: TextInputAction.search,
                    autocorrect: false,
                    onChanged: onQueryChanged,
                    onSubmitted: onSubmitted,
                    cursorColor: colorScheme.primary,
                    style: textTheme.headlineSmall?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      fillColor: Colors.transparent,
                      hintText: effectiveSearchHint,
                      hintStyle: textTheme.headlineSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                MechanixIconButton.standard(
                  icon: Image.asset(
                    NotesIcon.closeIcon,
                    color: colorScheme.onSurface,
                    width: 15,
                    height: 15,
                  ),
                  onPressed: () {
                    if (controller.text.isNotEmpty) {
                      controller.clear();
                      focusNode.requestFocus();
                      if (onClear != null) {
                        onClear?.call();
                      } else {
                        onQueryChanged?.call('');
                      }
                    } else {
                      onClose?.call();
                    }
                  },
                ),
              ],
            ),
          ),
    );
  }
}
