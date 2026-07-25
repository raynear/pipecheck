import 'package:pipecheck/data/table_generator/annotations.dart';

/// 태그 모델
@GenerateTable()
class Tag {
  @PrimaryKey()
  final String id;

  @Required()
  @Column(unique: true)
  final String name;

  @Column(nullable: true)
  final String? description;

  @Column(defaultValue: '#000000')
  final String color;

  @Column(defaultValue: 0)
  final int usageCount;

  Tag({
    required this.id,
    required this.name,
    this.description,
    this.color = '#000000',
    this.usageCount = 0,
  });
}
