import 'package:boilerplate/core/widgets/buttons/adaptive_button.dart';
import 'package:boilerplate/core/widgets/buttons/icon_buttons.dart';
import 'package:boilerplate/core/widgets/loading/loading_indicator.dart';
import 'package:boilerplate/core/widgets/navigation/adaptive_app_bar.dart';
import 'package:boilerplate/features/home/view_models/home_view_model.dart';
import 'package:flutter/material.dart';
import 'package:boilerplate/core/widgets/common/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 홈 화면 뷰
///
/// 앱의 메인 화면으로 도메인 액션 패턴을 활용한 상태 관리 예시를 보여줍니다.
///
/// 주요 기능:
/// - 이메일 인증 처리
/// - 로그아웃 기능
/// - 에러 메시지 표시
/// - 로딩 상태 관리
///
/// 성능 최적화:
/// - Consumer 위젯을 사용하여 필요한 부분만 재빌드
/// - select를 통해 특정 상태 변경만 감지
/// - 정적 컨텐츠는 const로 선언하여 재빌드 방지
///
/// 도메인 액션 패턴:
/// - 하나의 메서드 호출로 여러 작업을 동시에 처리
/// - DB 업데이트, 알림 설정, 스낵바 표시 등이 자동으로 처리됨
class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AdaptiveAppBar(
        title: Consumer(
          builder: (context, ref, child) {
            // Only rebuild title when title changes
            final title = ref.watch(
              homeViewModelProvider.select((state) => state.title),
            );
            return Text(title);
          },
        ),
        actions: [
          // 로그아웃 버튼
          Consumer(
            builder: (context, ref, child) {
              return AdaptiveIconButton(
                icon: Icons.logout,
                onPressed: () {
                  // 도메인 액션 사용 - 로그아웃
                  ref.read(homeViewModelProvider.notifier).signOut();
                },
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 로딩 상태 - Only rebuild when isLoading changes
            Consumer(
              builder: (context, ref, child) {
                final isLoading = ref.watch(
                  homeViewModelProvider.select((state) => state.isLoading),
                );
                return isLoading ? const LoadingIndicator() : const SizedBox.shrink();
              },
            ),

            // 에러 메시지 - Only rebuild when errorMessage changes
            Consumer(
              builder: (context, ref, child) {
                final errorMessage = ref.watch(
                  homeViewModelProvider.select((state) => state.errorMessage),
                );
                if (errorMessage == null) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    color: Colors.red.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        errorMessage,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ),
                );
              },
            ),

            // 이메일 인증 버튼 - Only rebuild when isLoading changes
            Consumer(
              builder: (context, ref, child) {
                final isLoading = ref.watch(
                  homeViewModelProvider.select((state) => state.isLoading),
                );

                // Show button only when not loading
                if (isLoading) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: AdaptiveButton(
                    label: '',
                    onPressed: () {
                      // 도메인 액션 사용 - 이메일 인증
                      // 이 한 줄로:
                      // 1. DB에서 사용자 정보 업데이트
                      // 2. 이메일 인증 배지 부여
                      // 3. 축하 알림 발송
                      // 4. 성공 스낵바 표시
                      ref.read(homeViewModelProvider.notifier).verifyUserEmail();
                    },
                    variant: ButtonVariant.primary,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.email),
                        const SizedBox(width: 8),
                        SText('home.verifyEmail'),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // 설명 텍스트 - Static content, no rebuild needed
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SText('home.domainActionExample',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SText('home.domainActionEmail',
                      ),
                      SText('home.domainActionLogout',
                      ),
                      const SizedBox(height: 8),
                      SText('home.domainActionNote',
                        style: const TextStyle(fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
