import 'package:flutter/material.dart';

class SearchTextHighlighter {
  static TextSpan highlight({
    required String text,
    required String query,
    required TextStyle baseStyle,
    required TextStyle highlightStyle,
  }) {
    if (text.isEmpty) {
      return TextSpan(text: '', style: baseStyle);
    }

    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return TextSpan(text: text, style: baseStyle);
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = trimmedQuery.toLowerCase();

    final spans = <TextSpan>[];
    var start = 0;
    var index = lowerText.indexOf(lowerQuery, start);

    if (index == -1) {
      return TextSpan(text: text, style: baseStyle);
    }

    while (index != -1) {
      // Add unhighlighted span before the match
      if (index > start) {
        spans.add(
          TextSpan(text: text.substring(start, index), style: baseStyle),
        );
      }

      // Add highlighted matched span
      final matchEnd = index + lowerQuery.length;
      spans.add(
        TextSpan(text: text.substring(index, matchEnd), style: highlightStyle),
      );

      start = matchEnd;
      index = lowerText.indexOf(lowerQuery, start);
    }

    // Add remaining trailing unhighlighted text
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: baseStyle));
    }

    return TextSpan(children: spans);
  }
}
