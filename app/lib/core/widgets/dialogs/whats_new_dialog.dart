import 'package:flutter/material.dart';
import 'package:pipecheck/core/widgets/common/semantics.dart';

/// 업데이트 후 '새로운 기능' 안내 다이얼로그 (P2-24).
///
/// 내용은 i18n `whatsNew.title`/`whatsNew.body` — 앱이 릴리즈마다 갱신한다.
/// 표시 여부(마이너 이상 버전 업)는 `WhatsNewService`가 결정한다.
class WhatsNewDialog {
  const WhatsNewDialog._();

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: SText('whatsNew.title'),
        content: SingleChildScrollView(
          child: SText('whatsNew.body'),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: SText('whatsNew.gotIt'),
          ),
        ],
      ),
    );
  }
}
