/// A/B 테스트 엔진 (앱-무관).
///
/// 앱은 [ExperimentSpec]를 구현한 실험 레지스트리(enum)와 [ABTestConfig]를
/// 주입해 [ABTestService]를 구성한다. 자세한 운영 가이드는 `docs/AB_TEST_GUIDE.md`.
library;

export 'src/ab_test_config.dart';
export 'src/ab_test_service.dart';
export 'src/experiment_spec.dart';
