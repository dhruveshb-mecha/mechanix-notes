import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_notes/core/utils/helper.dart';
import 'package:mechanix_notes/features/notes/data/services/note_tag_helper.dart';

void main() {
  group('NoteTagHelper Tests', () {
    const testId = '7b3f94e1-8899-4a21-9922-1234567890ab';

    test('appendTag appends tag with double newline to normal content', () {
      const content = '# Meeting Notes\n- Discuss project';
      final tagged = NoteTagHelper.appendTag(content, testId);

      expect(
        tagged,
        contains(
          '# Meeting Notes\n- Discuss project\n\n<!-- mechanix:id=$testId -->\n',
        ),
      );
    });

    test('appendTag works on empty content', () {
      final tagged = NoteTagHelper.appendTag('', testId);
      expect(tagged, equals('<!-- mechanix:id=$testId -->\n'));
    });

    test('appendTag replaces existing tag idempotently', () {
      const content = '# Title\n\n<!-- mechanix:id=old-id-123 -->\n';
      final tagged = NoteTagHelper.appendTag(content, testId);

      expect(tagged, equals('# Title\n\n<!-- mechanix:id=$testId -->\n'));
    });

    test('stripTag removes tag cleanly leaving original content', () {
      const content =
          '# Meeting Notes\n- Discuss project\n\n<!-- mechanix:id=$testId -->\n';
      final stripped = NoteTagHelper.stripTag(content);

      expect(stripped, equals('# Meeting Notes\n- Discuss project'));
    });

    test('extractId retrieves UUID correctly', () {
      const content = '# Meeting Notes\n- Item\n\n<!-- mechanix:id=$testId -->';
      expect(NoteTagHelper.extractId(content), equals(testId));
    });

    test('extractId returns null when no tag exists', () {
      const content = '# Meeting Notes\n- Just an ordinary markdown file';
      expect(NoteTagHelper.extractId(content), isNull);
    });

    test('markdownToPlainText strips HTML comments and mechanix tags', () {
      const content = '# Title\nBody text\n\n<!-- mechanix:id=$testId -->';
      final plain = markdownToPlainText(content);
      expect(plain.contains('mechanix:id'), isFalse);
      expect(plain.contains('<!--'), isFalse);
      expect(plain.trim(), equals('Title\nBody text'));
    });

    group('Tag Resiliency Tests', () {
      test(
        'extractId and stripTag succeed when external markdown editors append trailing text',
        () {
          const content =
              '# Project Overview\n- Requirements\n\n<!-- mechanix:id=$testId -->\n\nAppended by external editor\n';
          expect(NoteTagHelper.extractId(content), equals(testId));

          final stripped = NoteTagHelper.stripTag(content);
          expect(
            stripped,
            equals('# Project Overview\n- Requirements\n\nAppended by external editor'),
          );
        },
      );

      test(
        'extractId and stripTag succeed when file contains YAML frontmatter',
        () {
          const content =
              '---\ntitle: Project\ncreated_by: Obsidian\ntags: [review, notes]\n---\n# Project Overview\nSome body\n\n<!-- mechanix:id=$testId -->\n';
          expect(NoteTagHelper.extractId(content), equals(testId));

          final stripped = NoteTagHelper.stripTag(content);
          expect(
            stripped,
            equals(
              '---\ntitle: Project\ncreated_by: Obsidian\ntags: [review, notes]\n---\n# Project Overview\nSome body',
            ),
          );
        },
      );

      test(
        'extractId and stripTag succeed with both frontmatter and trailing content',
        () {
          const content =
              '---\ntitle: Note\n---\n# Body\n\n<!-- mechanix:id=$testId -->\n\nTrailing notes from external tool';
          expect(NoteTagHelper.extractId(content), equals(testId));

          final stripped = NoteTagHelper.stripTag(content);
          expect(
            stripped,
            equals('---\ntitle: Note\n---\n# Body\n\nTrailing notes from external tool'),
          );
        },
      );

      test(
        'appendTag replaces tag idempotently even if old tag is in the middle with trailing text',
        () {
          const content =
              '# Heading\n\n<!-- mechanix:id=old-id-123 -->\n\nExtra paragraph';
          final tagged = NoteTagHelper.appendTag(content, testId);

          expect(
            tagged,
            equals('# Heading\n\nExtra paragraph\n\n<!-- mechanix:id=$testId -->\n'),
          );
          expect(NoteTagHelper.extractId(tagged), equals(testId));
        },
      );
    });
  });
}
