import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/search/search_text_highlighter.dart';

void main() {
  group('SearchTextHighlighter Unit Tests', () {
    const baseStyle = TextStyle(color: Colors.white, fontSize: 16);
    const highlightStyle = TextStyle(color: Colors.blue, fontSize: 16);

    test('returns empty span with baseStyle when text is empty', () {
      final span = SearchTextHighlighter.highlight(
        text: '',
        query: 'test',
        baseStyle: baseStyle,
        highlightStyle: highlightStyle,
      );

      expect(span.text, '');
      expect(span.style, baseStyle);
      expect(span.children, isNull);
    });

    test('returns unhighlighted full text when query is empty or whitespace', () {
      final emptySpan = SearchTextHighlighter.highlight(
        text: 'Hello World',
        query: '',
        baseStyle: baseStyle,
        highlightStyle: highlightStyle,
      );
      expect(emptySpan.text, 'Hello World');
      expect(emptySpan.style, baseStyle);
      expect(emptySpan.children, isNull);

      final whitespaceSpan = SearchTextHighlighter.highlight(
        text: 'Hello World',
        query: '   ',
        baseStyle: baseStyle,
        highlightStyle: highlightStyle,
      );
      expect(whitespaceSpan.text, 'Hello World');
      expect(whitespaceSpan.style, baseStyle);
      expect(whitespaceSpan.children, isNull);
    });

    test('returns unhighlighted full text when query is not found', () {
      final span = SearchTextHighlighter.highlight(
        text: 'Flutter Development',
        query: 'Kotlin',
        baseStyle: baseStyle,
        highlightStyle: highlightStyle,
      );

      expect(span.text, 'Flutter Development');
      expect(span.style, baseStyle);
      expect(span.children, isNull);
    });

    test('highlights single match with case-insensitivity preserving original text casing', () {
      final span = SearchTextHighlighter.highlight(
        text: 'Flutter is awesome',
        query: 'flutter',
        baseStyle: baseStyle,
        highlightStyle: highlightStyle,
      );

      expect(span.children, isNotNull);
      final children = span.children!.cast<TextSpan>();
      expect(children.length, 2);

      // Matched portion: 'Flutter'
      expect(children[0].text, 'Flutter');
      expect(children[0].style, highlightStyle);

      // Remaining portion: ' is awesome'
      expect(children[1].text, ' is awesome');
      expect(children[1].style, baseStyle);
    });

    test('highlights match in middle and at end of text', () {
      final span = SearchTextHighlighter.highlight(
        text: 'Welcome to Flutter!',
        query: 'to',
        baseStyle: baseStyle,
        highlightStyle: highlightStyle,
      );

      expect(span.children, isNotNull);
      final children = span.children!.cast<TextSpan>();
      expect(children.length, 3);

      expect(children[0].text, 'Welcome ');
      expect(children[0].style, baseStyle);

      expect(children[1].text, 'to');
      expect(children[1].style, highlightStyle);

      expect(children[2].text, ' Flutter!');
      expect(children[2].style, baseStyle);
    });

    test('highlights multiple occurrences of the query', () {
      final span = SearchTextHighlighter.highlight(
        text: 'apple banana apple orange apple',
        query: 'apple',
        baseStyle: baseStyle,
        highlightStyle: highlightStyle,
      );

      expect(span.children, isNotNull);
      final children = span.children!.cast<TextSpan>();
      // [apple (hl), ' banana ' (base), apple (hl), ' orange ' (base), apple (hl)]
      expect(children.length, 5);

      expect(children[0].text, 'apple');
      expect(children[0].style, highlightStyle);

      expect(children[1].text, ' banana ');
      expect(children[1].style, baseStyle);

      expect(children[2].text, 'apple');
      expect(children[2].style, highlightStyle);

      expect(children[3].text, ' orange ');
      expect(children[3].style, baseStyle);

      expect(children[4].text, 'apple');
      expect(children[4].style, highlightStyle);
    });

    test('handles special regex characters in query safely without regex errors', () {
      const specialCharacters = r'[](){}.*+?^$|\';
      const text = 'Testing special chars: $specialCharacters end.';

      for (final char in specialCharacters.split('')) {
        final span = SearchTextHighlighter.highlight(
          text: text,
          query: char,
          baseStyle: baseStyle,
          highlightStyle: highlightStyle,
        );

        expect(span.children, isNotNull);
        final matches = span.children!
            .cast<TextSpan>()
            .where((s) => s.style == highlightStyle)
            .toList();
        expect(matches.isNotEmpty, isTrue, reason: 'Failed for char: $char');
        expect(matches.first.text, char);
      }
    });

    test('highlights when entire string matches query', () {
      final span = SearchTextHighlighter.highlight(
        text: 'EXACT',
        query: 'exact',
        baseStyle: baseStyle,
        highlightStyle: highlightStyle,
      );

      expect(span.children, isNotNull);
      final children = span.children!.cast<TextSpan>();
      expect(children.length, 1);
      expect(children[0].text, 'EXACT');
      expect(children[0].style, highlightStyle);
    });
  });
}
