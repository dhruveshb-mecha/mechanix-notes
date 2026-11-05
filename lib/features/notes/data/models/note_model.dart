import 'package:objectbox/objectbox.dart';

@Entity()
class NoteModel {
  @Id()
  int obxId;

  @Unique(onConflict: ConflictStrategy.replace)
  String id;

  @Index()
  String title;
  String content;

  @Property(type: PropertyType.date)
  DateTime createdAt;

  @Index()
  @Property(type: PropertyType.date)
  DateTime updatedAt;

  String plainText;
  String previewText;
  double height;

  @Index()
  bool isPinned;

  String? fileName;

  NoteModel({
    this.obxId = 0,
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    required this.plainText,
    required this.previewText,
    required this.height,
    this.isPinned = false,
    this.fileName,
  });
}
