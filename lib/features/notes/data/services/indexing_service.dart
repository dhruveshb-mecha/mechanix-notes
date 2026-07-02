import 'dart:io';
import 'package:flutter_tantivy/flutter_tantivy.dart';
import 'package:mechanix_notes/core/utils/app_logger.dart';
import 'package:mechanix_notes/core/utils/constants.dart';

class IndexingService {
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await RustLib.init();
      final home = Platform.environment['HOME'];
      final indexDir = Directory('$home${Constants.notesTantivyDbPath}');
      AppLogger.d('[IndexingService] Init: ${indexDir.path}');
      if (!await indexDir.exists()) {
        await indexDir.create(recursive: true);
      }
      initTantivy(dirPath: indexDir.path);
      _initialized = true;
      AppLogger.d('[IndexingService] Ready');
    } catch (e) {
      AppLogger.e('[IndexingService] Init failed: $e');
      rethrow;
    }
  }

  /// Limits content to the maximum characters and words allowed for indexing.
  static String truncateContent(String plainText) {
    String truncatedPlainText = plainText;
    if (truncatedPlainText.length > Constants.tantivyIndexContentMaxLength) {
      truncatedPlainText = truncatedPlainText.substring(
        0,
        Constants.tantivyIndexContentMaxLength,
      );
      AppLogger.d(
        '[IndexingService] Char limit: ${plainText.length} -> ${truncatedPlainText.length}',
      );
    }
    final wordMatches = RegExp(r'\S+').allMatches(truncatedPlainText);
    if (wordMatches.length > Constants.tantivyIndexContentMaxWords) {
      final endOfMaxWords = wordMatches
          .elementAt(Constants.tantivyIndexContentMaxWords - 1)
          .end;
      truncatedPlainText = truncatedPlainText.substring(0, endOfMaxWords);
      AppLogger.d(
        '[IndexingService] Word limit: ${wordMatches.length} -> ${Constants.tantivyIndexContentMaxWords}',
      );
    }
    return truncatedPlainText;
  }

  Future<void> upsertNote(String id, String title, String plainText) async {
    try {
      if (!_initialized) {
        await initialize();
      }
      AppLogger.d('[IndexingService] Upsert: id=$id');
      final truncatedPlainText = truncateContent(plainText);
      await updateDocument(
        doc: Document(id: id, title: title, content: truncatedPlainText),
      );
    } catch (e) {
      AppLogger.e('[IndexingService] Upsert failed ($id): $e');
    }
  }

  Future<void> deleteNotesBatch(List<String> ids) async {
    try {
      if (!_initialized) {
        await initialize();
      }
      AppLogger.d('[IndexingService] Delete: $ids');
      await deleteDocumentsBatch(ids: ids);
    } catch (e) {
      AppLogger.e('[IndexingService] Delete failed: $e');
    }
  }

  /// Performs a full-text search against the Tantivy index, returning matching document IDs in order of relevance.
  Future<List<String>> search(
    String query, {
    int limit = Constants.searchResultLimit,
  }) async {
    try {
      if (!_initialized) {
        await initialize();
      }
      final cleanQuery = query.trim();
      if (cleanQuery.isEmpty) return [];

      final results = await searchDocuments(
        query: cleanQuery,
        topK: BigInt.from(limit),
      );

      AppLogger.d(
        '[IndexingService] Search: "$cleanQuery" -> ${results.length}',
      );

      return results.map((r) => r.doc.id).toSet().toList();
    } catch (e) {
      AppLogger.e('[IndexingService] Search failed ($query): $e');
      return [];
    }
  }
}
