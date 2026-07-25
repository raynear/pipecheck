import 'package:boilerplate/data/table_generator/annotations.dart';

enum AuthStatus { loading, authenticated, unauthenticated }

@GenerateTable(
  tableName: 'user',
  timestamps: true,
  paths: OutputPaths(
    modelPath: 'data/models',
    repositoryPath: 'data/repositories',
    driftPath: 'data/database/tables',
  ),
  updateDatabase: true,
  updateProviders: true,
)
class User {
  @PrimaryKey(strategy: IdStrategy.uuid)
  final String id;

  @Required()
  final String email;

  @Column(nullable: true)
  final String? name;

  @Column(nullable: true)
  final String? profileImageUrl;

  @Column(defaultValue: false)
  final bool isEmailVerified;

  @Column(nullable: true)
  final DateTime? lastLoginAt;

  @Column(nullable: true)
  final String? metadata; // JSON 데이터 저장용

  @Column(defaultValue: false)
  final bool isDeleted;

  @Column(nullable: true)
  final DateTime? deletedAt;

  User({
    required this.id,
    required this.email,
    this.name,
    this.profileImageUrl,
    this.isEmailVerified = false,
    this.lastLoginAt,
    this.metadata,
    this.isDeleted = false,
    this.deletedAt,
  });
}
