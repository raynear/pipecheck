import 'package:boilerplate/core/widgets/error/error_widget.dart';
import 'package:boilerplate/core/widgets/feedback/empty_state.dart';
import 'package:boilerplate/core/widgets/loading/loading_indicator.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Riverpod `AsyncValue<T>`를 로딩/에러/빈/데이터 4상태로 일관 렌더한다 (P2-23c).
///
/// 기존에 따로 흩어져 있던 위젯 3종([LoadingIndicator]·[AppErrorWidget]·
/// [EmptyState])을 한 진입점으로 합성해, 화면마다 `value.when(...)` 보일러플레이트를
/// 반복하지 않게 한다. 기본 위젯은 디자인 시스템(context.colors 등)을 쓰므로
/// `ProviderScope` 하위에서만 렌더된다(앱 전역이 이미 ProviderScope).
///
/// ```dart
/// AsyncValueView<List<Todo>>(
///   value: ref.watch(todosProvider),
///   onRetry: () => ref.invalidate(todosProvider),
///   isEmpty: (todos) => todos.isEmpty,
///   data: (todos) => TodoList(todos),
/// )
/// ```
///
/// i18n: 기본 빈/에러 카피는 하드코딩 한국어 — P2-23d 스윕에서 번역 키로 전환.
/// 그 전에도 호출부가 [empty]/[errorMessage]로 직접 문구를 줄 수 있다.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    this.onRetry,
    this.loading,
    this.errorBuilder,
    this.empty,
    this.isEmpty,
    this.errorMessage,
    this.skipLoadingOnRefresh = true,
    this.skipLoadingOnReload = false,
  });

  /// 렌더할 비동기 값.
  final AsyncValue<T> value;

  /// 데이터 상태 빌더.
  final Widget Function(T data) data;

  /// 에러 상태 재시도 콜백 — 있으면 기본 [AppErrorWidget]에 재시도 버튼이 붙는다.
  final VoidCallback? onRetry;

  /// 커스텀 로딩 위젯(미지정 시 [LoadingIndicator]).
  final Widget? loading;

  /// 커스텀 에러 빌더(미지정 시 [AppErrorWidget]).
  final Widget Function(Object error, StackTrace stackTrace)? errorBuilder;

  /// 커스텀 빈-상태 위젯(미지정 + [isEmpty]가 true면 기본 [EmptyState]).
  final Widget? empty;

  /// 데이터가 "비었는지" 판정(예: 리스트 isEmpty). null이면 빈-상태를 쓰지 않는다.
  final bool Function(T data)? isEmpty;

  /// 에러 → 표시 메시지 매핑(미지정 시 기본 문구). 상세는 항상 error.toString().
  final String Function(Object error)? errorMessage;

  /// 새로고침(refresh/invalidate) 중 로딩 스피너를 건너뛸지 — riverpod 기본과 동일.
  final bool skipLoadingOnRefresh;

  /// watch 재빌드(reload) 중 로딩 스피너를 건너뛸지 — riverpod 기본과 동일.
  final bool skipLoadingOnReload;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: skipLoadingOnRefresh,
      skipLoadingOnReload: skipLoadingOnReload,
      data: (d) {
        if (isEmpty != null && isEmpty!(d)) {
          return empty ?? EmptyState(title: 'async.empty'.tr());
        }
        return data(d);
      },
      loading: () => loading ?? const LoadingIndicator(),
      error: (e, stack) {
        if (errorBuilder != null) return errorBuilder!(e, stack);
        return AppErrorWidget(
          message: errorMessage?.call(e) ?? 'async.error'.tr(),
          details: e.toString(),
          onRetry: onRetry,
        );
      },
    );
  }
}
