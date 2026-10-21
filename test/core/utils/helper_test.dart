import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_notes/core/utils/helper.dart';

void main() {
  group('markdownToPlainText Tests', () {
    test('returns empty string for empty input', () {
      expect(markdownToPlainText(''), equals(''));
    });

    test('preserves snake_case identifiers without stripping underscores', () {
      const input =
          'Check my_variable_name and user_id_123 in parse_json_data.';
      final result = markdownToPlainText(input);
      expect(
        result,
        equals('Check my_variable_name and user_id_123 in parse_json_data.'),
      );
    });

    test('preserves uppercase constants with underscores', () {
      const input = 'Value of MAX_BUFFER_SIZE and DEFAULT_TIMEOUT_MS.';
      final result = markdownToPlainText(input);
      expect(
        result,
        equals('Value of MAX_BUFFER_SIZE and DEFAULT_TIMEOUT_MS.'),
      );
    });

    test('correctly strips standalone underscore italics', () {
      const input = 'This is _italic text_ and another _word_ here.';
      final result = markdownToPlainText(input);
      expect(result, equals('This is italic text and another word here.'));
    });

    test('correctly strips asterisk italics', () {
      const input = 'This is *italic text* and another *word* here.';
      final result = markdownToPlainText(input);
      expect(result, equals('This is italic text and another word here.'));
    });

    test('correctly strips bold text with asterisks and underscores', () {
      const input = 'This is **bold text** and __underscore bold__.';
      final result = markdownToPlainText(input);
      expect(result, equals('This is bold text and underscore bold.'));
    });

    test('correctly strips headers', () {
      const input = '# Header 1\n## Header 2\n### Header 3\nContent';
      final result = markdownToPlainText(input);
      expect(result.trim(), equals('Header 1\nHeader 2\nHeader 3\nContent'));
    });

    test('correctly strips links and images', () {
      const input =
          'Visit [Google](https://google.com) and view ![Logo](https://img.png).';
      final result = markdownToPlainText(input);
      expect(result, equals('Visit Google and view Logo.'));
    });

    test('correctly strips fenced and inline code', () {
      const input = '```dart\nfinal x = 42;\n```\nAlso `inline_code_call()`.';
      final result = markdownToPlainText(input);
      expect(result.trim(), equals('final x = 42;\nAlso inline_code_call().'));
    });

    test('correctly strips checklists, bullet lists, and ordered lists', () {
      const input =
          '- [ ] Todo item\n- [x] Done item\n* Bullet item\n1. Numbered item';
      final result = markdownToPlainText(input);
      expect(
        result.trim(),
        equals('Todo item\nDone item\nBullet item\nNumbered item'),
      );
    });

    test('correctly strips blockquotes and horizontal rules', () {
      const input = '> Quote line\n---\nNormal text';
      final result = markdownToPlainText(input);
      expect(
        result.replaceAll(RegExp(r'\n+'), '\n').trim(),
        equals('Quote line\nNormal text'),
      );
    });

    test('correctly strips strikethrough, highlights, and HTML comments', () {
      const input = '~~deleted~~ and ==highlighted== <!-- mechanix:id=123 -->';
      final result = markdownToPlainText(input);
      expect(result.trim(), equals('deleted and highlighted'));
    });
  });
}
