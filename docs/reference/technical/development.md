# 👨‍💻 개발 가이드

Flutter 보일러플레이트를 사용한 실제 개발 워크플로우를 안내합니다.

## 🎯 새로운 기능 추가하기

### 1. Feature 모듈 생성

```bash
# Fastlane으로 자동 생성 (권장)
fastlane create_feature name:product

# 생성되는 구조:
# lib/features/product/
#   ├── views/
#   │   └── product_view.dart
#   ├── view_models/
#   │   └── product_view_model.dart
#   ├── widgets/
#   └── models/
```

Fastlane이 자동으로 생성하는 내용:
- ✅ Feature 폴더 구조
- ✅ 기본 View 파일 (Riverpod 통합)
- ✅ 기본 ViewModel 파일 (Notifier)
- ✅ Provider 정의 및 설정
- ✅ 라우팅 추가 가이드 제공

### 2. Model 정의

```dart
// lib/data/generated/models/product.model.dart
class ProductModel {
  final String id;
  final String name;
  final double price;
  final String? description;
  final DateTime createdAt;
  
  ProductModel({
    required this.id,
    required this.name,
    required this.price,
    this.description,
    required this.createdAt,
  });
  
  Map<String, dynamic> toDatabaseMap() => {
    'id': id,
    'name': name,
    'price': price,
    'description': description,
    'created_at': createdAt.toIso8601String(),
  };
  
  factory ProductModel.fromDatabaseMap(Map<String, dynamic> map) => ProductModel(
    id: map['id'],
    name: map['name'],
    price: map['price']?.toDouble(),
    description: map['description'],
    createdAt: DateTime.parse(map['created_at']),
  );
}
```

### 3. Repository 구현

```dart
// lib/data/generated/repositories/product.repository.dart
class ProductRepository {
  static const String _tableName = 'products';
  final DatabaseDataSource _database;
  
  ProductRepository(this._database);
  
  Future<List<ProductModel>> getAllProducts() async {
    final results = await _database.findAll(_tableName);
    return results.map((data) => ProductModel.fromDatabaseMap(data)).toList();
  }
  
  Future<ProductModel?> getProductById(String id) async {
    final data = await _database.findOne(_tableName, where: {'id': id});
    return data != null ? ProductModel.fromDatabaseMap(data) : null;
  }
  
  Future<void> createProduct(ProductModel product) async {
    await _database.insert(_tableName, product.toDatabaseMap());
  }
}
```

### 4. ViewModel 작성

```dart
// lib/features/product/view_models/product_list_view_model.dart
class ProductListViewModel extends Notifier<AsyncValue<List<ProductModel>>> {
  ProductRepository get _repository => ref.read(productRepositoryProvider);
  
  @override
  AsyncValue<List<ProductModel>> build() {
    loadProducts();
    return const AsyncValue.loading();
  }
  
  Future<void> loadProducts() async {
    state = const AsyncValue.loading();
    try {
      final products = await _repository.getAllProducts();
      state = AsyncValue.data(products);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
  
  Future<void> addProduct(ProductModel product) async {
    try {
      await _repository.createProduct(product);
      await loadProducts(); // 리스트 새로고침
    } catch (e) {
      // 에러 처리
    }
  }
}

// Provider 정의
final productListViewModelProvider = 
  NotifierProvider<ProductListViewModel, AsyncValue<List<ProductModel>>>(
    ProductListViewModel.new,
  );
```

### 5. View 구현

```dart
// lib/features/product/views/product_list_view.dart
class ProductListView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsState = ref.watch(productListViewModelProvider);
    
    return Scaffold(
      appBar: AppBar(title: Text('Products')),
      body: productsState.when(
        data: (products) => ListView.builder(
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            return ListTile(
              title: Text(product.name),
              subtitle: Text('\$${product.price}'),
              onTap: () => context.push('/product/${product.id}'),
            );
          },
        ),
        loading: () => Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/product/add'),
        child: Icon(Icons.add),
      ),
    );
  }
}
```

## 🔄 상태 관리 패턴

### AsyncValue 사용

```dart
// Loading, Success, Error 상태 처리
productsState.when(
  data: (data) => ProductGrid(products: data),
  loading: () => LoadingIndicator(),
  error: (error, stack) => ErrorWidget(error),
);

// 부분 업데이트
productsState.whenOrNull(
  data: (data) => ProductGrid(products: data),
) ?? LoadingIndicator();
```

### Family Provider 패턴

```dart
// 파라미터가 있는 Provider
final productProvider = FutureProvider.family<ProductModel?, String>((ref, productId) async {
  final repository = ref.watch(productRepositoryProvider);
  return repository.getProductById(productId);
});

// 사용
final product = ref.watch(productProvider('product-123'));
```

### StateNotifier 패턴

```dart
class CartState {
  final List<CartItem> items;
  final double total;
  
  CartState({required this.items, required this.total});
}

class CartViewModel extends StateNotifier<CartState> {
  CartViewModel() : super(CartState(items: [], total: 0));
  
  void addItem(ProductModel product) {
    state = CartState(
      items: [...state.items, CartItem(product: product, quantity: 1)],
      total: state.total + product.price,
    );
  }
}
```

## 🧪 테스트 작성

### Fastlane으로 테스트 실행

```bash
# 모든 테스트 실행
fastlane test

# 커버리지 포함
fastlane test coverage:true

# 특정 테스트만 실행
fastlane test type:unit
fastlane test type:widget
fastlane test type:integration
```

### Unit Test

```dart
// test/repositories/product_repository_test.dart
void main() {
  group('ProductRepository', () {
    late ProductRepository repository;
    late MockDatabaseDataSource mockDatabase;
    
    setUp(() {
      mockDatabase = MockDatabaseDataSource();
      repository = ProductRepository(mockDatabase);
    });
    
    test('getAllProducts returns list of products', () async {
      when(mockDatabase.findAll('products')).thenAnswer(
        (_) async => [
          {'id': '1', 'name': 'Product 1', 'price': 10.0},
          {'id': '2', 'name': 'Product 2', 'price': 20.0},
        ],
      );
      
      final products = await repository.getAllProducts();
      
      expect(products.length, 2);
      expect(products[0].name, 'Product 1');
    });
  });
}
```

### Widget Test

```dart
// test/features/product/product_list_view_test.dart
void main() {
  testWidgets('ProductListView displays products', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productListViewModelProvider.overrideWith((ref) {
            return ProductListViewModel(MockProductRepository());
          }),
        ],
        child: MaterialApp(home: ProductListView()),
      ),
    );
    
    await tester.pumpAndSettle();
    
    expect(find.text('Product 1'), findsOneWidget);
    expect(find.text('Product 2'), findsOneWidget);
  });
}
```

## 🔥 Hot Reload 최적화

### Provider 새로고침

```dart
// 개발 중 Provider 강제 새로고침
ref.invalidate(productListViewModelProvider);

// 특정 상황에서만 새로고침
ref.refresh(productListViewModelProvider);
```

### 개발 도구 활용

```dart
// lib/main.dart
void main() {
  if (kDebugMode) {
    // 개발 모드 설정
    ProviderScope.debugShowInternalState = true;
  }
  
  runApp(
    ProviderScope(
      observers: [if (kDebugMode) LoggerObserver()],
      child: MyApp(),
    ),
  );
}
```

## 🐛 디버깅 팁

### 로깅 설정

```dart
// lib/core/utils/logger.dart
class AppLogger {
  static void log(String message, {LogLevel level = LogLevel.info}) {
    if (kDebugMode) {
      final timestamp = DateTime.now().toIso8601String();
      debugPrint('[$timestamp] [${level.name}] $message');
    }
  }
}

// 사용 예시
AppLogger.log('Product loaded: ${product.id}');
```

### Provider 디버깅

```dart
class LoggerObserver extends ProviderObserver {
  @override
  void didUpdateProvider(
    ProviderBase provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    debugPrint('Provider ${provider.name ?? provider.runtimeType} updated');
  }
}
```

## 📝 코드 생성

### Fastlane으로 코드 생성 관리

```bash
# 코드 생성 실행 (build_runner)
fastlane codegen

# 프로젝트 정리 후 재생성
fastlane clean
fastlane codegen
```

### 수동으로 Build Runner 사용

```bash
# 한 번 실행
cd app
dart run build_runner build

# 파일 변경 감지 모드
dart run build_runner watch

# 충돌 해결
dart run build_runner build --delete-conflicting-outputs
```

### Freezed 모델 생성

```dart
// lib/models/user.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

@freezed
class User with _$User {
  factory User({
    required String id,
    required String email,
    String? name,
  }) = _User;
  
  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}
```

## 🎨 UI 컴포넌트 재사용

### 공통 위젯

```dart
// lib/core/widgets/common/loading_button.dart
class LoadingButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;
  final String text;
  
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      child: isLoading 
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(text),
    );
  }
}
```

## 📱 플랫폼별 코드

```dart
// 플랫폼 체크
if (Platform.isIOS) {
  // iOS 전용 코드
} else if (Platform.isAndroid) {
  // Android 전용 코드
}

// 조건부 import
import 'package:my_app/platform/platform_interface.dart'
  if (dart.library.io) 'package:my_app/platform/mobile.dart'
  if (dart.library.js) 'package:my_app/platform/web.dart';
```

## 🚀 성능 최적화

### Lazy Loading

```dart
// 필요할 때만 로드
final productDetailsProvider = FutureProvider.autoDispose.family<ProductModel, String>(
  (ref, productId) async {
    final repository = ref.watch(productRepositoryProvider);
    return repository.getProductById(productId);
  },
);
```

### 이미지 최적화

```dart
// 캐시된 네트워크 이미지
CachedNetworkImage(
  imageUrl: product.imageUrl,
  placeholder: (context, url) => CircularProgressIndicator(),
  errorWidget: (context, url, error) => Icon(Icons.error),
);
```

## 🚀 Fastlane 개발 명령어 모음

### 일일 개발 워크플로우

```bash
# 아침 시작 시
fastlane validate       # 프로젝트 상태 확인
fastlane clean         # 캐시 정리
fastlane run_app       # 개발 서버 시작

# 기능 개발
fastlane create_feature name:awesome_feature  # 새 기능 모듈 생성
fastlane codegen       # 코드 생성
fastlane test          # 테스트 실행

# 커밋 전
fastlane test coverage:true  # 커버리지 확인
fastlane bump_version type:patch  # 버전 업데이트

# 환경 전환 (별도 명령 없음 — env 산출물은 ./build · ./run gen-env가 debug/profile/release로 자동 생성)
fastlane firebase_config  # Firebase 설정 업데이트
```

### 디버깅 및 문제 해결

```bash
# SHA-1 fingerprint 확인 (Firebase 연동)
fastlane sha1

# 프로젝트 정보 확인
fastlane info

# 설정 검증
fastlane validate
```

## 📚 다음 단계

- [프로젝트 설정](./setup.md)
- [배포 가이드](./deployment.md)