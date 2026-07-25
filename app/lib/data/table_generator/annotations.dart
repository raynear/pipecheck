/// 테이블 생성을 위한 어노테이션 정의
library;

/// 테이블, 모델을 자동 생성하는 어노테이션
/// (Supabase SQL/RLS 생성은 P1-16.5a 철거와 함께 제거됨)
class GenerateTable {
  /// 테이블 이름 (기본값: 클래스명을 snake_case로 변환)
  final String? tableName;

  /// 타임스탬프 필드 자동 추가 여부
  final bool timestamps;

  /// 생성 경로 설정 (현재 미지원 - organize_files.dart 스크립트 사용)
  @Deprecated('build_runner 제약으로 미지원. organize_files.dart 스크립트를 사용하세요.')
  final OutputPaths paths;

  /// database.dart 자동 업데이트 여부
  final bool updateDatabase;

  /// repository_providers.dart 자동 업데이트 여부
  final bool updateProviders;

  const GenerateTable({
    this.tableName,
    this.timestamps = true,
    this.paths = const OutputPaths(),
    this.updateDatabase = true,
    this.updateProviders = true,
  });
}

/// 파일 생성 경로 설정
class OutputPaths {
  /// drift 테이블 생성 경로 (기본값: 같은 폴더)
  final String? driftPath;

  /// model 생성 경로 (기본값: 같은 폴더)
  final String? modelPath;

  /// repository 생성 경로 (기본값: 같은 폴더)
  final String? repositoryPath;

  const OutputPaths({
    this.driftPath,
    this.modelPath,
    this.repositoryPath,
  });
}

/// 필드 어노테이션들

/// Primary Key 지정
class PrimaryKey {
  /// ID 생성 전략
  final IdStrategy strategy;
  
  const PrimaryKey({
    this.strategy = IdStrategy.uuid,
  });
}

/// ID 생성 전략
enum IdStrategy {
  /// UUID v4 (gen_random_uuid())
  uuid,
  /// 자동 증가 정수
  autoIncrement,
  /// 수동 입력
  manual,
}

/// 외래 키 참조
class References {
  /// 참조할 테이블명
  final String table;
  
  /// 참조할 컬럼명 (기본값: id)
  final String column;
  
  /// CASCADE 옵션
  final CascadeOption onDelete;
  final CascadeOption onUpdate;
  
  const References(
    this.table, {
    this.column = 'id',
    this.onDelete = CascadeOption.restrict,
    this.onUpdate = CascadeOption.cascade,
  });
}

/// CASCADE 옵션
enum CascadeOption {
  cascade,
  restrict,
  setNull,
  setDefault,
}

/// 컬럼 제약사항
class Column {
  /// NULL 허용 여부
  final bool nullable;
  
  /// UNIQUE 제약
  final bool unique;
  
  /// 기본값
  final dynamic defaultValue;
  
  /// 컬럼 설명
  final String? description;
  
  /// 데이터베이스 컬럼명 (기본값: 필드명을 snake_case로 변환)
  final String? dbName;
  
  const Column({
    this.nullable = true,
    this.unique = false,
    this.defaultValue,
    this.description,
    this.dbName,
  });
}

/// 필수 필드 (nullable = false의 축약형)
class Required extends Column {
  const Required({
    super.unique = false,
    super.defaultValue,
    super.description,
    super.dbName,
  }) : super(nullable: false);
}

/// 인덱스 생성
class Index {
  /// 인덱스 이름
  final String? name;
  
  /// 복합 인덱스인 경우 다른 필드들
  final List<String> fields;
  
  /// UNIQUE 인덱스 여부
  final bool unique;
  
  const Index({
    this.name,
    this.fields = const [],
    this.unique = false,
  });
}

/// JSON 필드 (JSONB in PostgreSQL)
class JsonField extends Column {
  const JsonField({
    super.nullable = true,
    super.defaultValue = '{}',
    super.description,
    super.dbName,
  });
}

/// Enum 필드
class EnumField extends Column {
  /// Enum 타입명
  final Type enumType;

  const EnumField(
    this.enumType, {
    super.nullable = true,
    super.defaultValue,
    super.description,
    super.dbName,
  });
}