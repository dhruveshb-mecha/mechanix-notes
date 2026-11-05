import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_notes/core/utils/app_logger.dart';
import 'package:mechanix_notes/core/utils/constants.dart';
import 'package:mechanix_notes/features/notes/bloc/search/search_event.dart';
import 'package:mechanix_notes/features/notes/bloc/search/search_state.dart';
import 'package:mechanix_notes/features/notes/data/repository/note_repository.dart';

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  final NoteRepository noteRepository;

  SearchBloc({required this.noteRepository}) : super(const SearchState()) {
    on<SearchQueryChanged>(_onSearchQueryChanged, transformer: restartable());
    on<LoadMoreSearchResults>(
      _onLoadMoreSearchResults,
      transformer: droppable(),
    );
    on<ClearSearch>(_onClearSearch);
  }

  Future<void> _onSearchQueryChanged(
    SearchQueryChanged event,
    Emitter<SearchState> emit,
  ) async {
    final query = event.query.trim();
    if (query.length < Constants.minSearchQueryLength) {
      emit(const SearchState());
      return;
    }

    emit(
      state.copyWith(
        status: SearchStatus.loading,
        query: query,
        isLoadingMore: false,
      ),
    );
    AppLogger.i("Searching notes for query: $query");

    try {
      final ids = await noteRepository.searchNoteIds(query);
      final firstPage = await noteRepository.getNotesMetaData(_pageIds(ids, 0));

      AppLogger.i("Found ${ids.length} matching notes");

      emit(
        state.copyWith(
          status: SearchStatus.success,
          results: firstPage,
          resultIds: ids,
          hasMore: ids.length > Constants.pageSize,
          currentPage: 0,
          isLoadingMore: false,
        ),
      );
    } catch (e) {
      AppLogger.e("Error searching notes: $e");
      emit(state.copyWith(status: SearchStatus.failure, isLoadingMore: false));
    }
  }

  Future<void> _onLoadMoreSearchResults(
    LoadMoreSearchResults event,
    Emitter<SearchState> emit,
  ) async {
    if (state.isLoadingMore || !state.hasMore) return;

    AppLogger.i("Loading more search results");
    final ids = state.resultIds;
    final nextPage = state.currentPage + 1;
    final pageIds = _pageIds(ids, nextPage);

    if (pageIds.isEmpty) {
      emit(state.copyWith(hasMore: false));
      return;
    }

    emit(state.copyWith(isLoadingMore: true));

    try {
      final newBatch = await noteRepository.getNotesMetaData(pageIds);

      if (_isStale(ids)) return;

      emit(
        state.copyWith(
          results: [...state.results, ...newBatch],
          isLoadingMore: false,
          hasMore: (nextPage + 1) * Constants.pageSize < ids.length,
          currentPage: nextPage,
        ),
      );
    } catch (e) {
      AppLogger.e("Error loading more search results: $e");
      if (!_isStale(ids)) emit(state.copyWith(isLoadingMore: false));
    }
  }

  bool _isStale(List<String> ids) =>
      state.status != SearchStatus.success || !identical(state.resultIds, ids);

  static List<String> _pageIds(List<String> ids, int page) =>
      ids.skip(page * Constants.pageSize).take(Constants.pageSize).toList();

  void _onClearSearch(ClearSearch event, Emitter<SearchState> emit) {
    emit(const SearchState());
  }
}
