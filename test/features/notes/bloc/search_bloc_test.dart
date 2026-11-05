import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_notes/core/utils/constants.dart';
import 'package:mechanix_notes/features/notes/bloc/search/search_bloc.dart';
import 'package:mechanix_notes/features/notes/bloc/search/search_event.dart';
import 'package:mechanix_notes/features/notes/bloc/search/search_state.dart';
import 'package:mechanix_notes/features/notes/data/models/note_metadata.dart';
import 'package:mechanix_notes/features/notes/data/repository/note_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockNoteRepository extends Mock implements NoteRepository {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

NoteMetaData makeNote({required String id, String title = 'Note'}) =>
    NoteMetaData(
      id: id,
      title: title,
      updatedAt: DateTime(2024, 6, 1),
      height: 0,
      createdAt: DateTime(2024, 1, 1),
      previewText: 'Preview $id',
    );

List<NoteMetaData> buildNoteList(int count) =>
    List.generate(count, (i) => makeNote(id: 'note_$i', title: 'Note $i'));

List<String> idsOf(List<NoteMetaData> notes) =>
    notes.map((n) => n.id).toList();

Matcher stateMatching({
  SearchStatus? status,
  String? query,
  int? resultsLength,
  int? idsLength,
  bool? hasMore,
  int? currentPage,
  bool? isLoadingMore,
}) {
  return predicate<SearchState>((s) {
    if (status != null && s.status != status) return false;
    if (query != null && s.query != query) return false;
    if (resultsLength != null && s.results.length != resultsLength) {
      return false;
    }
    if (idsLength != null &&
        s.resultIds.length != idsLength) {
      return false;
    }
    if (hasMore != null && s.hasMore != hasMore) return false;
    if (currentPage != null && s.currentPage != currentPage) return false;
    if (isLoadingMore != null && s.isLoadingMore != isLoadingMore) return false;
    return true;
  }, 'SearchState matches expected fields');
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockNoteRepository mockRepo;

  setUpAll(() {
    registerFallbackValue(<String>[]);
  });

  setUp(() {
    mockRepo = MockNoteRepository();
    when(() => mockRepo.getNotesMetaData(any())).thenAnswer(
      (invocation) async => [
        for (final id in invocation.positionalArguments.first as List<String>)
          makeNote(id: id),
      ],
    );
  });

  SearchBloc buildBloc() => SearchBloc(noteRepository: mockRepo);

  // ── Constructor ──────────────────────────────────────────────────────────

  group('SearchBloc – constructor', () {
    test('initial state is default SearchState', () {
      final bloc = buildBloc();
      expect(bloc.state, const SearchState());
      bloc.close();
    });

    test('initial state has SearchStatus.initial', () {
      final bloc = buildBloc();
      expect(bloc.state.status, SearchStatus.initial);
      bloc.close();
    });
  });

  // ── Search events ────────────────────────────────────────────────────────

  group('SearchEvent', () {
    test('SearchQueryChanged stores query', () {
      final event = SearchQueryChanged(query: 'flutter');
      expect(event.query, 'flutter');
    });

    test('LoadMoreSearchResults is instantiable', () {
      expect(LoadMoreSearchResults(), isA<LoadMoreSearchResults>());
    });

    test('ClearSearch is instantiable', () {
      expect(ClearSearch(), isA<ClearSearch>());
    });
  });

  // ── SearchQueryChanged – empty query ─────────────────────────────────────

  group('SearchQueryChanged – empty query', () {
    blocTest<SearchBloc, SearchState>(
      'resets to initial state when query is empty',
      build: buildBloc,
      act: (bloc) => bloc.add(SearchQueryChanged(query: '')),
      expect: () => [const SearchState()],
      verify: (_) {
        verifyNever(() => mockRepo.searchNoteIds(any()));
      },
    );

    blocTest<SearchBloc, SearchState>(
      'resets to initial state when query is only whitespace',
      build: buildBloc,
      act: (bloc) => bloc.add(SearchQueryChanged(query: '   ')),
      expect: () => [const SearchState()],
      verify: (_) {
        verifyNever(() => mockRepo.searchNoteIds(any()));
      },
    );

    blocTest<SearchBloc, SearchState>(
      'resets to initial state when query is tabs and newlines only',
      build: buildBloc,
      act: (bloc) => bloc.add(SearchQueryChanged(query: '\t\n  \n')),
      expect: () => [const SearchState()],
      verify: (_) {
        verifyNever(() => mockRepo.searchNoteIds(any()));
      },
    );

    blocTest<SearchBloc, SearchState>(
      'clears previous success state when query becomes empty',
      build: buildBloc,
      seed: () => SearchState(
        status: SearchStatus.success,
        query: 'old',
        results: buildNoteList(5),
        resultIds: idsOf(buildNoteList(5)),
        hasMore: true,
        currentPage: 2,
        isLoadingMore: false,
      ),
      act: (bloc) => bloc.add(SearchQueryChanged(query: '')),
      expect: () => [const SearchState()],
    );

    blocTest<SearchBloc, SearchState>(
      'clears failure state when query becomes empty',
      build: buildBloc,
      seed: () =>
          const SearchState(status: SearchStatus.failure, query: 'failed'),
      act: (bloc) => bloc.add(SearchQueryChanged(query: '')),
      expect: () => [const SearchState()],
    );
  });

  // ── SearchQueryChanged – success ─────────────────────────────────────────

  group('SearchQueryChanged – success', () {
    blocTest<SearchBloc, SearchState>(
      'emits [loading, success] with matching results',
      build: () {
        final notes = buildNoteList(3);
        when(
          () => mockRepo.searchNoteIds('test'),
        ).thenAnswer((_) async => idsOf(notes));
        return buildBloc();
      },
      act: (bloc) => bloc.add(SearchQueryChanged(query: 'test')),
      expect: () => [
        stateMatching(
          status: SearchStatus.loading,
          query: 'test',
          resultsLength: 0,
          idsLength: 0,
        ),
        stateMatching(
          status: SearchStatus.success,
          query: 'test',
          resultsLength: 3,
          idsLength: 3,
          hasMore: false,
          currentPage: 0,
          isLoadingMore: false,
        ),
      ],
      verify: (_) {
        verify(() => mockRepo.searchNoteIds('test')).called(1);
      },
    );

    blocTest<SearchBloc, SearchState>(
      'emits success with empty results when repository returns nothing',
      build: () {
        when(
          () => mockRepo.searchNoteIds('none'),
        ).thenAnswer((_) async => idsOf([]));
        return buildBloc();
      },
      act: (bloc) => bloc.add(SearchQueryChanged(query: 'none')),
      expect: () => [
        stateMatching(status: SearchStatus.loading, query: 'none'),
        stateMatching(
          status: SearchStatus.success,
          query: 'none',
          resultsLength: 0,
          idsLength: 0,
          hasMore: false,
          currentPage: 0,
        ),
      ],
    );

    blocTest<SearchBloc, SearchState>(
      'trims query before calling repository',
      build: () {
        when(
          () => mockRepo.searchNoteIds('hello'),
        ).thenAnswer((_) async => idsOf([]));
        return buildBloc();
      },
      act: (bloc) => bloc.add(SearchQueryChanged(query: '  hello  ')),
      expect: () => [
        stateMatching(status: SearchStatus.loading, query: 'hello'),
        stateMatching(status: SearchStatus.success, query: 'hello'),
      ],
      verify: (_) {
        verify(() => mockRepo.searchNoteIds('hello')).called(1);
      },
    );

    blocTest<SearchBloc, SearchState>(
      'sets hasMore=false when results equal pageSize exactly',
      build: () {
        final notes = buildNoteList(Constants.pageSize);
        when(
          () => mockRepo.searchNoteIds('exact'),
        ).thenAnswer((_) async => idsOf(notes));
        return buildBloc();
      },
      act: (bloc) => bloc.add(SearchQueryChanged(query: 'exact')),
      expect: () => [
        isA<SearchState>(),
        stateMatching(
          status: SearchStatus.success,
          resultsLength: Constants.pageSize,
          idsLength: Constants.pageSize,
          hasMore: false,
        ),
      ],
    );

    blocTest<SearchBloc, SearchState>(
      'sets hasMore=true when results are exactly pageSize + 1',
      build: () {
        final notes = buildNoteList(Constants.pageSize + 1);
        when(
          () => mockRepo.searchNoteIds('plusone'),
        ).thenAnswer((_) async => idsOf(notes));
        return buildBloc();
      },
      act: (bloc) => bloc.add(SearchQueryChanged(query: 'plusone')),
      expect: () => [
        isA<SearchState>(),
        stateMatching(
          status: SearchStatus.success,
          resultsLength: Constants.pageSize,
          idsLength: Constants.pageSize + 1,
          hasMore: true,
        ),
      ],
    );

    blocTest<SearchBloc, SearchState>(
      'sets hasMore=true when total results exceed pageSize',
      build: () {
        final notes = buildNoteList(Constants.pageSize + 5);
        when(
          () => mockRepo.searchNoteIds('query'),
        ).thenAnswer((_) async => idsOf(notes));
        return buildBloc();
      },
      act: (bloc) => bloc.add(SearchQueryChanged(query: 'query')),
      expect: () => [
        isA<SearchState>(),
        stateMatching(
          status: SearchStatus.success,
          resultsLength: Constants.pageSize,
          idsLength: Constants.pageSize + 5,
          hasMore: true,
        ),
      ],
    );

    blocTest<SearchBloc, SearchState>(
      'first page contains the first pageSize notes from repository',
      build: () {
        final notes = buildNoteList(Constants.pageSize + 2);
        when(
          () => mockRepo.searchNoteIds('ids'),
        ).thenAnswer((_) async => idsOf(notes));
        return buildBloc();
      },
      act: (bloc) => bloc.add(SearchQueryChanged(query: 'ids')),
      verify: (bloc) {
        final ids = bloc.state.results.map((n) => n.id).toList();
        expect(ids.first, 'note_0');
        expect(ids.last, 'note_${Constants.pageSize - 1}');
        expect(ids.length, Constants.pageSize);
      },
    );

    blocTest<SearchBloc, SearchState>(
      'replaces previous search results on a new successful query',
      build: () {
        when(
          () => mockRepo.searchNoteIds('new'),
        ).thenAnswer((_) async => idsOf([makeNote(id: 'fresh')]));
        return buildBloc();
      },
      seed: () => SearchState(
        status: SearchStatus.success,
        query: 'old',
        results: buildNoteList(3),
        resultIds: idsOf(buildNoteList(3)),
        hasMore: false,
        currentPage: 1,
      ),
      act: (bloc) => bloc.add(SearchQueryChanged(query: 'new')),
      verify: (bloc) {
        expect(bloc.state.results.single.id, 'fresh');
        expect(bloc.state.resultIds.single, 'fresh');
        expect(bloc.state.query, 'new');
      },
    );

    blocTest<SearchBloc, SearchState>(
      'resets currentPage to 0 on a fresh search',
      build: () {
        when(
          () => mockRepo.searchNoteIds('new'),
        ).thenAnswer((_) async => idsOf([]));
        return buildBloc();
      },
      seed: () => const SearchState(
        status: SearchStatus.success,
        query: 'old',
        currentPage: 3,
        hasMore: true,
      ),
      act: (bloc) => bloc.add(SearchQueryChanged(query: 'new')),
      expect: () => [isA<SearchState>(), stateMatching(currentPage: 0)],
    );

    blocTest<SearchBloc, SearchState>(
      'emits loading before repository returns',
      build: () {
        when(() => mockRepo.searchNoteIds('slow')).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return idsOf(buildNoteList(1));
        });
        return buildBloc();
      },
      act: (bloc) => bloc.add(SearchQueryChanged(query: 'slow')),
      wait: const Duration(milliseconds: 100),
      expect: () => [
        stateMatching(status: SearchStatus.loading, query: 'slow'),
        stateMatching(status: SearchStatus.success, resultsLength: 1),
      ],
    );

    blocTest<SearchBloc, SearchState>(
      'recovers to success after a previous failure',
      build: () {
        when(
          () => mockRepo.searchNoteIds('okay'),
        ).thenAnswer((_) async => idsOf(buildNoteList(2)));
        return buildBloc();
      },
      seed: () =>
          const SearchState(status: SearchStatus.failure, query: 'fail'),
      act: (bloc) => bloc.add(SearchQueryChanged(query: 'okay')),
      expect: () => [
        stateMatching(status: SearchStatus.loading, query: 'okay'),
        stateMatching(
          status: SearchStatus.success,
          query: 'okay',
          resultsLength: 2,
        ),
      ],
    );

    blocTest<SearchBloc, SearchState>(
      'resets isLoadingMore on a fresh search',
      build: () {
        when(
          () => mockRepo.searchNoteIds('query'),
        ).thenAnswer((_) async => idsOf([]));
        return buildBloc();
      },
      seed: () =>
          const SearchState(status: SearchStatus.success, isLoadingMore: true),
      act: (bloc) => bloc.add(SearchQueryChanged(query: 'query')),
      expect: () => [
        stateMatching(status: SearchStatus.loading, isLoadingMore: false),
        stateMatching(status: SearchStatus.success, isLoadingMore: false),
      ],
    );

    blocTest<SearchBloc, SearchState>(
      'resets isLoadingMore when search fails',
      build: () {
        when(
          () => mockRepo.searchNoteIds('fail'),
        ).thenThrow(Exception('db error'));
        return buildBloc();
      },
      seed: () =>
          const SearchState(status: SearchStatus.success, isLoadingMore: true),
      act: (bloc) => bloc.add(SearchQueryChanged(query: 'fail')),
      expect: () => [
        stateMatching(status: SearchStatus.loading, isLoadingMore: false),
        stateMatching(status: SearchStatus.failure, isLoadingMore: false),
      ],
    );
  });

  // ── SearchQueryChanged – failure ─────────────────────────────────────────

  group('SearchQueryChanged – failure', () {
    blocTest<SearchBloc, SearchState>(
      'emits [loading, failure] when repository throws',
      build: () {
        when(
          () => mockRepo.searchNoteIds('fail'),
        ).thenThrow(Exception('db error'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(SearchQueryChanged(query: 'fail')),
      expect: () => [
        stateMatching(status: SearchStatus.loading, query: 'fail'),
        stateMatching(status: SearchStatus.failure, query: 'fail'),
      ],
    );

    blocTest<SearchBloc, SearchState>(
      'keeps query from the failed search attempt',
      build: () {
        when(
          () => mockRepo.searchNoteIds('fail'),
        ).thenThrow(Exception('db error'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(SearchQueryChanged(query: 'fail')),
      verify: (bloc) {
        expect(bloc.state.query, 'fail');
      },
    );

    blocTest<SearchBloc, SearchState>(
      'preserves stale results from prior success when new search fails',
      build: () {
        when(
          () => mockRepo.searchNoteIds('fail'),
        ).thenThrow(Exception('db error'));
        return buildBloc();
      },
      seed: () => SearchState(
        status: SearchStatus.success,
        query: 'old',
        results: buildNoteList(4),
        resultIds: idsOf(buildNoteList(4)),
      ),
      act: (bloc) => bloc.add(SearchQueryChanged(query: 'fail')),
      verify: (bloc) {
        expect(bloc.state.status, SearchStatus.failure);
        expect(bloc.state.results.length, 4);
        expect(bloc.state.query, 'fail');
      },
    );

    blocTest<SearchBloc, SearchState>(
      'does not call repository again after failure without a new event',
      build: () {
        when(
          () => mockRepo.searchNoteIds('fail'),
        ).thenThrow(Exception('db error'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(SearchQueryChanged(query: 'fail')),
      verify: (_) {
        verify(() => mockRepo.searchNoteIds('fail')).called(1);
      },
    );
  });

  // ── LoadMoreSearchResults – success ──────────────────────────────────────

  group('LoadMoreSearchResults – success', () {
    blocTest<SearchBloc, SearchState>(
      'emits isLoadingMore true then false while appending',
      build: buildBloc,
      seed: () {
        final all = buildNoteList(Constants.pageSize + 5);
        return SearchState(
          status: SearchStatus.success,
          query: 'query',
          results: all.take(Constants.pageSize).toList(),
          resultIds: idsOf(all),
          hasMore: true,
        );
      },
      act: (bloc) => bloc.add(LoadMoreSearchResults()),
      expect: () => [
        stateMatching(isLoadingMore: true),
        stateMatching(
          isLoadingMore: false,
          resultsLength: Constants.pageSize + 5,
          currentPage: 1,
          hasMore: false,
        ),
      ],
    );

    blocTest<SearchBloc, SearchState>(
      'appends the correct next batch of note ids',
      build: buildBloc,
      seed: () {
        final all = buildNoteList(Constants.pageSize + 3);
        return SearchState(
          status: SearchStatus.success,
          query: 'query',
          results: all.take(Constants.pageSize).toList(),
          resultIds: idsOf(all),
          hasMore: true,
        );
      },
      act: (bloc) => bloc.add(LoadMoreSearchResults()),
      verify: (bloc) {
        final ids = bloc.state.results.map((n) => n.id).toList();
        expect(ids[Constants.pageSize], 'note_${Constants.pageSize}');
        expect(ids.last, 'note_${Constants.pageSize + 2}');
        expect(ids.first, 'note_0');
      },
    );

    blocTest<SearchBloc, SearchState>(
      'sets hasMore=false when last batch is smaller than pageSize',
      build: buildBloc,
      seed: () {
        final all = buildNoteList(Constants.pageSize + 3);
        return SearchState(
          status: SearchStatus.success,
          query: 'query',
          results: all.take(Constants.pageSize).toList(),
          resultIds: idsOf(all),
          hasMore: true,
        );
      },
      act: (bloc) => bloc.add(LoadMoreSearchResults()),
      verify: (bloc) {
        expect(bloc.state.results.length, Constants.pageSize + 3);
        expect(bloc.state.hasMore, isFalse);
      },
    );

    blocTest<SearchBloc, SearchState>(
      'keeps hasMore=true when another full page remains',
      build: buildBloc,
      seed: () {
        final all = buildNoteList(Constants.pageSize * 3);
        return SearchState(
          status: SearchStatus.success,
          query: 'query',
          results: all.take(Constants.pageSize).toList(),
          resultIds: idsOf(all),
          hasMore: true,
        );
      },
      act: (bloc) => bloc.add(LoadMoreSearchResults()),
      expect: () => [
        isA<SearchState>(),
        stateMatching(
          resultsLength: Constants.pageSize * 2,
          currentPage: 1,
          hasMore: true,
        ),
      ],
    );

    blocTest<SearchBloc, SearchState>(
      'loads all pages when LoadMoreSearchResults is dispatched repeatedly',
      build: buildBloc,
      seed: () {
        final all = buildNoteList(Constants.pageSize * 3);
        return SearchState(
          status: SearchStatus.success,
          query: 'query',
          results: all.take(Constants.pageSize).toList(),
          resultIds: idsOf(all),
          hasMore: true,
        );
      },
      act: (bloc) async {
        bloc.add(LoadMoreSearchResults());
        await bloc.stream.firstWhere((s) => !s.isLoadingMore);
        bloc.add(LoadMoreSearchResults());
      },
      verify: (bloc) {
        expect(bloc.state.results.length, Constants.pageSize * 3);
        expect(bloc.state.currentPage, 2);
        expect(bloc.state.hasMore, isFalse);
        expect(bloc.state.isLoadingMore, isFalse);
      },
    );

    blocTest<SearchBloc, SearchState>(
      'handles pageSize + 1 notes across two load-more dispatches',
      build: buildBloc,
      seed: () {
        final all = buildNoteList(Constants.pageSize + 1);
        return SearchState(
          status: SearchStatus.success,
          query: 'query',
          results: all.take(Constants.pageSize).toList(),
          resultIds: idsOf(all),
          hasMore: true,
        );
      },
      act: (bloc) => bloc.add(LoadMoreSearchResults()),
      verify: (bloc) {
        expect(bloc.state.results.length, Constants.pageSize + 1);
        expect(bloc.state.hasMore, isFalse);
        expect(bloc.state.results.last.id, 'note_${Constants.pageSize}');
      },
    );
  });

  // ── Page hydration ───────────────────────────────────────────────────────

  group('Page hydration', () {
    blocTest<SearchBloc, SearchState>(
      'search hydrates only the first page of matching ids',
      build: () {
        when(
          () => mockRepo.searchNoteIds('many'),
        ).thenAnswer((_) async => idsOf(buildNoteList(1000)));
        return buildBloc();
      },
      act: (bloc) => bloc.add(SearchQueryChanged(query: 'many')),
      verify: (bloc) {
        final requested =
            verify(
                  () => mockRepo.getNotesMetaData(captureAny()),
                ).captured.single
                as List<String>;
        expect(requested, idsOf(buildNoteList(Constants.pageSize)));
        expect(bloc.state.resultIds, hasLength(1000));
        expect(bloc.state.results, hasLength(Constants.pageSize));
      },
    );

    blocTest<SearchBloc, SearchState>(
      'load more hydrates exactly the next page of ids',
      build: buildBloc,
      seed: () {
        final all = buildNoteList(Constants.pageSize * 3);
        return SearchState(
          status: SearchStatus.success,
          query: 'query',
          results: all.take(Constants.pageSize).toList(),
          resultIds: idsOf(all),
          hasMore: true,
        );
      },
      act: (bloc) => bloc.add(LoadMoreSearchResults()),
      verify: (_) {
        final requested =
            verify(
                  () => mockRepo.getNotesMetaData(captureAny()),
                ).captured.single
                as List<String>;
        expect(requested.first, 'note_${Constants.pageSize}');
        expect(requested.last, 'note_${Constants.pageSize * 2 - 1}');
      },
    );

    blocTest<SearchBloc, SearchState>(
      'counts pages by ids so missing notes do not shift later pages',
      build: () {
        // Every note in the second page is missing from the database
        when(() => mockRepo.getNotesMetaData(any())).thenAnswer((_) async => []);
        return buildBloc();
      },
      seed: () {
        final all = buildNoteList(Constants.pageSize * 3);
        return SearchState(
          status: SearchStatus.success,
          query: 'query',
          results: all.take(Constants.pageSize).toList(),
          resultIds: idsOf(all),
          hasMore: true,
        );
      },
      act: (bloc) => bloc.add(LoadMoreSearchResults()),
      verify: (bloc) {
        expect(bloc.state.results, hasLength(Constants.pageSize));
        expect(bloc.state.currentPage, 1);
        expect(bloc.state.hasMore, isTrue);
      },
    );

    blocTest<SearchBloc, SearchState>(
      'drops a load-more page that resolves after a new search started',
      build: () {
        final pendingPage = Completer<List<NoteMetaData>>();
        when(
          () => mockRepo.getNotesMetaData(any(that: isNotEmpty)),
        ).thenAnswer((_) => pendingPage.future);
        when(() => mockRepo.searchNoteIds('next')).thenAnswer((_) async {
          pendingPage.complete([makeNote(id: 'stale')]);
          return [];
        });
        return buildBloc();
      },
      seed: () {
        final all = buildNoteList(Constants.pageSize * 2);
        return SearchState(
          status: SearchStatus.success,
          query: 'query',
          results: all.take(Constants.pageSize).toList(),
          resultIds: idsOf(all),
          hasMore: true,
        );
      },
      act: (bloc) async {
        bloc.add(LoadMoreSearchResults());
        await bloc.stream.firstWhere((s) => s.isLoadingMore);
        bloc.add(SearchQueryChanged(query: 'next'));
      },
      // The new search's success replaces results anyway, so check every
      // emitted state for the stale page, not just the final one
      expect: () => everyElement(
        predicate<SearchState>(
          (s) => s.results.every((n) => n.id != 'stale'),
          'has no stale results',
        ),
      ),
      verify: (bloc) {
        expect(bloc.state.query, 'next');
      },
    );
  });

  // ── LoadMoreSearchResults – empty batch ──────────────────────────────────

  group('LoadMoreSearchResults – empty batch', () {
    blocTest<SearchBloc, SearchState>(
      'sets hasMore=false without loading when no ids remain',
      build: buildBloc,
      seed: () {
        final all = buildNoteList(Constants.pageSize);
        return SearchState(
          status: SearchStatus.success,
          query: 'query',
          results: all,
          resultIds: idsOf(all),
          hasMore: true,
        );
      },
      act: (bloc) => bloc.add(LoadMoreSearchResults()),
      expect: () => [
        stateMatching(
          isLoadingMore: false,
          hasMore: false,
          resultsLength: Constants.pageSize,
        ),
      ],
      verify: (_) {
        verifyNever(() => mockRepo.getNotesMetaData(any()));
      },
    );
  });

  // ── LoadMoreSearchResults – no-op ────────────────────────────────────────

  group('LoadMoreSearchResults – no-op', () {
    blocTest<SearchBloc, SearchState>(
      'does nothing from initial state',
      build: buildBloc,
      act: (bloc) => bloc.add(LoadMoreSearchResults()),
      expect: () => [],
    );

    blocTest<SearchBloc, SearchState>(
      'does nothing when hasMore is false',
      build: buildBloc,
      seed: () => SearchState(
        status: SearchStatus.success,
        query: 'query',
        results: buildNoteList(3),
        resultIds: idsOf(buildNoteList(3)),
        hasMore: false,
      ),
      act: (bloc) => bloc.add(LoadMoreSearchResults()),
      expect: () => [],
    );

    blocTest<SearchBloc, SearchState>(
      'does nothing when already loading more',
      build: buildBloc,
      seed: () => SearchState(
        status: SearchStatus.success,
        query: 'query',
        results: buildNoteList(Constants.pageSize + 5),
        resultIds: idsOf(buildNoteList(Constants.pageSize + 5)),
        hasMore: true,
        isLoadingMore: true,
      ),
      act: (bloc) => bloc.add(LoadMoreSearchResults()),
      expect: () => [],
    );

    blocTest<SearchBloc, SearchState>(
      'does nothing after all results are already loaded',
      build: buildBloc,
      seed: () {
        final all = buildNoteList(Constants.pageSize + 2);
        return SearchState(
          status: SearchStatus.success,
          query: 'query',
          results: all,
          resultIds: idsOf(all),
          hasMore: false,
        );
      },
      act: (bloc) => bloc.add(LoadMoreSearchResults()),
      expect: () => [],
    );
  });

  // ── ClearSearch ──────────────────────────────────────────────────────────

  group('ClearSearch', () {
    blocTest<SearchBloc, SearchState>(
      'resets success state to initial',
      build: buildBloc,
      seed: () => SearchState(
        status: SearchStatus.success,
        query: 'test',
        results: buildNoteList(5),
        resultIds: idsOf(buildNoteList(5)),
        hasMore: true,
        currentPage: 1,
      ),
      act: (bloc) => bloc.add(ClearSearch()),
      expect: () => [const SearchState()],
    );

    blocTest<SearchBloc, SearchState>(
      'resets failure state to initial',
      build: buildBloc,
      seed: () =>
          const SearchState(status: SearchStatus.failure, query: 'fail'),
      act: (bloc) => bloc.add(ClearSearch()),
      expect: () => [const SearchState()],
    );

    blocTest<SearchBloc, SearchState>(
      'resets loading state to initial',
      build: buildBloc,
      seed: () =>
          const SearchState(status: SearchStatus.loading, query: 'pending'),
      act: (bloc) => bloc.add(ClearSearch()),
      expect: () => [const SearchState()],
    );

    blocTest<SearchBloc, SearchState>(
      'resets state when isLoadingMore is true',
      build: buildBloc,
      seed: () => SearchState(
        status: SearchStatus.success,
        query: 'query',
        results: buildNoteList(25),
        resultIds: idsOf(buildNoteList(25)),
        hasMore: true,
        isLoadingMore: true,
      ),
      act: (bloc) => bloc.add(ClearSearch()),
      expect: () => [const SearchState()],
    );

    blocTest<SearchBloc, SearchState>(
      'second ClearSearch from initial emits nothing (Equatable dedup)',
      build: buildBloc,
      act: (bloc) {
        bloc.add(ClearSearch());
        bloc.add(ClearSearch());
      },
      expect: () => [const SearchState()],
      verify: (bloc) {
        expect(bloc.state, const SearchState());
      },
    );
  });

  // ── Integration-style flows ──────────────────────────────────────────────

  group('SearchBloc – event sequences', () {
    blocTest<SearchBloc, SearchState>(
      'search → load more → clear returns to initial',
      build: () {
        final all = buildNoteList(Constants.pageSize + 2);
        when(
          () => mockRepo.searchNoteIds('flow'),
        ).thenAnswer((_) async => idsOf(all));
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(SearchQueryChanged(query: 'flow'));
        await bloc.stream.firstWhere((s) => s.status == SearchStatus.success);
        bloc.add(LoadMoreSearchResults());
        await bloc.stream.firstWhere(
          (s) => !s.isLoadingMore && s.hasMore == false,
        );
        bloc.add(ClearSearch());
      },
      verify: (bloc) {
        expect(bloc.state, const SearchState());
      },
    );

    blocTest<SearchBloc, SearchState>(
      'search → clear → empty query keeps initial state',
      build: () {
        when(
          () => mockRepo.searchNoteIds('abc'),
        ).thenAnswer((_) async => idsOf(buildNoteList(1)));
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(SearchQueryChanged(query: 'abc'));
        await bloc.stream.firstWhere((s) => s.status == SearchStatus.success);
        bloc.add(ClearSearch());
        bloc.add(SearchQueryChanged(query: ''));
      },
      verify: (bloc) {
        expect(bloc.state, const SearchState());
      },
    );
  });

  // ── SearchState ──────────────────────────────────────────────────────────

  group('SearchState', () {
    test('pageSize constant is 20', () {
      expect(Constants.pageSize, 20);
    });

    test('default constructor values', () {
      const state = SearchState();
      expect(state.status, SearchStatus.initial);
      expect(state.results, isEmpty);
      expect(state.resultIds, isEmpty);
      expect(state.query, isEmpty);
      expect(state.hasMore, isFalse);
      expect(state.currentPage, 0);
      expect(state.isLoadingMore, isFalse);
    });

    test('SearchStatus contains all expected values', () {
      expect(SearchStatus.values, containsAll(SearchStatus.values));
      expect(SearchStatus.values.length, 4);
    });

    test('copyWith updates each field independently', () {
      const original = SearchState();
      final note = makeNote(id: 'x');

      expect(
        original.copyWith(status: SearchStatus.loading).status,
        SearchStatus.loading,
      );
      expect(original.copyWith(results: [note]).results, [note]);
      expect(original.copyWith(resultIds: [note.id]).resultIds, [note.id]);
      expect(original.copyWith(query: 'query').query, 'query');
      expect(original.copyWith(hasMore: true).hasMore, isTrue);
      expect(original.copyWith(currentPage: 2).currentPage, 2);
      expect(original.copyWith(isLoadingMore: true).isLoadingMore, isTrue);
    });

    test('copyWith preserves unspecified fields', () {
      const original = SearchState(
        status: SearchStatus.success,
        query: 'keep',
        currentPage: 2,
      );
      final copy = original.copyWith(hasMore: true);
      expect(copy.status, SearchStatus.success);
      expect(copy.query, 'keep');
      expect(copy.currentPage, 2);
      expect(copy.hasMore, isTrue);
    });

    test('two states with same values are equal (Equatable)', () {
      const a = SearchState(status: SearchStatus.success, query: 'query');
      const b = SearchState(status: SearchStatus.success, query: 'query');
      expect(a, equals(b));
    });

    test('states differ when status differs', () {
      const a = SearchState(status: SearchStatus.initial);
      const b = SearchState(status: SearchStatus.loading);
      expect(a, isNot(equals(b)));
    });

    test('states differ when results differ', () {
      final a = SearchState(results: [makeNote(id: '1')]);
      final b = SearchState(results: [makeNote(id: '2')]);
      expect(a, isNot(equals(b)));
    });

    test('states differ when resultIds differ', () {
      const a = SearchState(resultIds: ['1']);
      const b = SearchState(resultIds: ['2']);
      expect(a, isNot(equals(b)));
    });

    test('states differ when query differs', () {
      const a = SearchState(query: 'abc');
      const b = SearchState(query: 'b');
      expect(a, isNot(equals(b)));
    });

    test('states differ when hasMore differs', () {
      const a = SearchState(hasMore: false);
      const b = SearchState(hasMore: true);
      expect(a, isNot(equals(b)));
    });

    test('states differ when currentPage differs', () {
      const a = SearchState(currentPage: 0);
      const b = SearchState(currentPage: 1);
      expect(a, isNot(equals(b)));
    });

    test('states differ when isLoadingMore differs', () {
      const a = SearchState(isLoadingMore: false);
      const b = SearchState(isLoadingMore: true);
      expect(a, isNot(equals(b)));
    });

    test('props includes all fields', () {
      final note = makeNote(id: '1');
      final state = SearchState(
        status: SearchStatus.success,
        results: [note],
        resultIds: idsOf([note]),
        query: 'query',
        hasMore: true,
        currentPage: 1,
        isLoadingMore: true,
      );
      expect(state.props.length, 7);
    });
  });
}
