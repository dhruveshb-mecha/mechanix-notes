import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_notes/core/utils/constants.dart';
import 'package:mechanix_notes/features/notes/data/services/indexing_service.dart';

void main() {
  group('IndexingService.truncateContent', () {
    test('returns original string when under both limits', () {
      const input = 'This is a short note.';
      final result = IndexingService.truncateContent(input);
      expect(result, equals(input));
    });

    test('truncates to character limit when words are long but characters exceed limit', () {
      // 100 words of 40 characters each = 4000 characters.
      // Since 100 words < 300 words, but 4000 characters > 3000 characters,
      // it should truncate to exactly 3000 characters.
      final word = 'a' * 40;
      final input = List.generate(100, (_) => word).join(' ');

      final result = IndexingService.truncateContent(input);

      expect(result.length, equals(Constants.tantivyIndexContentMaxLength));
      expect(result, equals(input.substring(0, Constants.tantivyIndexContentMaxLength)));
    });

    test('truncates to word limit when words exceed limit but characters are under limit', () {
      // 400 words of 2 characters each = 800 characters (+ spaces = ~1200 characters).
      // Since 400 words > 300 words, but ~1200 characters < 3000 characters,
      // it should truncate to exactly 300 words.
      final wordsList = List.generate(400, (index) => 'w$index');
      final input = wordsList.join(' ');

      final result = IndexingService.truncateContent(input);

      // It should match the first 300 words joined by spaces
      final expected = wordsList.take(300).join(' ');
      expect(result, equals(expected));
      
      // Verify word count of the result is exactly 300
      final resultWords = RegExp(r'\S+').allMatches(result).length;
      expect(resultWords, equals(Constants.tantivyIndexContentMaxWords));
    });

    test('whichever comes first - word limit comes first', () {
      // 500 words of 4 characters each = 2000 characters (+ spaces = ~2500 characters).
      // 300 words would be ~1500 characters.
      // Here, 300 words (~1500 chars) comes before 3000 characters.
      // So it should truncate at 300 words.
      final wordsList = List.generate(500, (_) => 'word');
      final input = wordsList.join(' ');

      final result = IndexingService.truncateContent(input);

      final expected = wordsList.take(300).join(' ');
      expect(result, equals(expected));
      expect(result.length, lessThan(Constants.tantivyIndexContentMaxLength));
    });

    test('whichever comes first - character limit comes first', () {
      // 500 words of 10 characters each = 5000 characters.
      // 300 words would be 3000 characters (+ 299 spaces = 3299 characters).
      // So the 300th word ends at character 3299.
      // Here, the 3000 character limit comes before the 300 word limit.
      // So it should truncate at exactly 3000 characters.
      final wordsList = List.generate(500, (_) => 'abcdefghij'); // 10 chars each
      final input = wordsList.join(' ');

      final result = IndexingService.truncateContent(input);

      expect(result.length, equals(Constants.tantivyIndexContentMaxLength));
      expect(result, equals(input.substring(0, Constants.tantivyIndexContentMaxLength)));
    });

    test('preserves exact spacing and formatting for truncated text', () {
      // 301 words separated by newlines and extra spaces.
      final wordsList = List.generate(300, (index) => 'w$index');
      final input = '${wordsList.join('\n\n')}   extra_word';

      final result = IndexingService.truncateContent(input);

      // The 300th word is w299.
      // Result should be exactly everything up to the end of w299, preserving newlines.
      final expected = wordsList.join('\n\n');
      expect(result, equals(expected));
    });
  });
}
