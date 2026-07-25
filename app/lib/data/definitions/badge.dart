import 'package:pipecheck/data/table_generator/annotations.dart';

enum BadgeType { achievementCount, consecutive, total, first, special, retry }

@GenerateTable(
  tableName: 'badge',
  timestamps: true,
  paths: OutputPaths(
    modelPath: 'data/models',
    repositoryPath: 'data/repositories',
    driftPath: 'data/database/tables',
  ),
  updateDatabase: true,
  updateProviders: true,
)
class Badge {
  @PrimaryKey(strategy: IdStrategy.autoIncrement)
  final int? id;

  @Required()
  final String badgeId;

  @Required()
  final String title;

  @Required()
  final String description;

  @Required()
  final String iconPath;

  @Column(nullable: true)
  final DateTime? earnedDate;

  @Column(defaultValue: false)
  final bool isAchieved;

  @Required()
  final BadgeType type;

  @Required()
  final String condition;

  Badge({
    this.id,
    required this.badgeId,
    required this.title,
    required this.description,
    required this.iconPath,
    this.earnedDate,
    this.isAchieved = false,
    required this.type,
    required this.condition,
  });
}
