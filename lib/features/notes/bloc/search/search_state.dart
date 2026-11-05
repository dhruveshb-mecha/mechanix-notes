import 'package:equatable/equatable.dart';
import 'package:mechanix_notes/features/notes/data/models/note_metadata.dart';

enum SearchStatus { initial, loading, success, failure }

class SearchState extends Equatable {
  final SearchStatus status;
  final List<NoteMetaData> results;

  /// Ids of every note matching [query], most relevant first. Only the pages
  /// up to [currentPage] are loaded into [results].
  final List<String> resultIds;
  final String query;
  final bool hasMore;
  final int currentPage;
  final bool isLoadingMore;

  const SearchState({
    this.status = SearchStatus.initial,
    this.results = const [],
    this.resultIds = const [],
    this.query = '',
    this.hasMore = false,
    this.currentPage = 0,
    this.isLoadingMore = false,
  });

  SearchState copyWith({
    SearchStatus? status,
    List<NoteMetaData>? results,
    List<String>? resultIds,
    String? query,
    bool? hasMore,
    int? currentPage,
    bool? isLoadingMore,
  }) {
    return SearchState(
      status: status ?? this.status,
      results: results ?? this.results,
      resultIds: resultIds ?? this.resultIds,
      query: query ?? this.query,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [
    status,
    results,
    resultIds,
    query,
    hasMore,
    currentPage,
    isLoadingMore,
  ];
}
