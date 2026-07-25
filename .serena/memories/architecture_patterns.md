# Architecture Patterns

## Overall Architecture
Clean Architecture + MVVM 패턴

```
┌─────────────────────────────────────────┐
│              Presentation               │
│   (Views, ViewModels, Widgets)          │
├─────────────────────────────────────────┤
│               Domain                    │
│   (Entities, Use Cases, Interfaces)     │
├─────────────────────────────────────────┤
│                Data                     │
│ (Repositories, DataSources, Models)     │
├─────────────────────────────────────────┤
│             External Services           │
│  (Firebase, Supabase, APIs, Storage)    │
└─────────────────────────────────────────┘
```

## State Management (Riverpod 3.0)

### Provider Types
- `@riverpod` - 자동 생성 Provider
- `FutureProvider` - 비동기 데이터
- `StreamProvider` - 스트림 데이터
- `StateNotifierProvider` - 복잡한 상태 (레거시)
- `NotifierProvider` - 복잡한 상태 (신규, 권장)

### Usage Pattern
```dart
// ViewModel 정의
@riverpod
class FeatureViewModel extends _$FeatureViewModel {
  @override
  FeatureState build() => FeatureState.initial();
  
  Future<void> fetchData() async { ... }
}

// View에서 사용
class FeatureView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(featureViewModelProvider);  // 상태 구독
    final vm = ref.read(featureViewModelProvider.notifier);  // 메서드 호출
    ...
  }
}
```

## Data Layer

### Repository Pattern
```dart
// 인터페이스 정의 (domain)
abstract class FeatureRepository {
  Future<List<FeatureModel>> getAll();
  Future<FeatureModel?> getById(String id);
  Future<void> create(FeatureModel item);
  Future<void> update(FeatureModel item);
  Future<void> delete(String id);
}

// 구현 (data)
class FeatureRepositoryImpl implements FeatureRepository {
  final AppDatabase _db;
  FeatureRepositoryImpl(this._db);
  
  @override
  Future<List<FeatureModel>> getAll() async { ... }
}
```

### Database (Drift)
```dart
// 테이블 정의
class FeatureTable extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
```

## Routing (GoRouter)

```dart
GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeView(),
    ),
    GoRoute(
      path: '/feature/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return FeatureDetailView(id: id);
      },
    ),
  ],
);
```

## Feature Flag Pattern

```dart
// AppFeatureConfig 사용
if (AppFeatureConfig.isAdsEnabled) {
  AdService.showBannerAd();
}

// 조건부 초기화
void initServices() async {
  if (AppFeatureConfig.isFirebaseEnabled) {
    await FirebaseService.initialize();
  }
  if (AppFeatureConfig.isSupabaseDatabaseEnabled) {
    await SupabaseService.initialize();
  }
}
```

## Service Layer Pattern

```dart
// Singleton 서비스
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();
  
  static Future<void> initialize() async { ... }
  static void logEvent(String name, Map<String, dynamic> params) { ... }
}

// Provider를 통한 서비스 주입
@riverpod
FeatureService featureService(FeatureServiceRef ref) {
  return FeatureService();
}
```

## Error Handling

```dart
// core/error_handler.dart 사용
try {
  await someOperation();
} catch (e, stackTrace) {
  ErrorHandler.handleError(e, stackTrace);
}
```

## Design System

- `core/design/` 디렉토리에 테마, 색상, 타이포그래피 정의
- `flex_color_scheme` 패키지로 테마 관리
- `google_fonts` 패키지로 폰트 관리
