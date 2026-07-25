import 'package:pipecheck/core/services/privacy_consent_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:pipecheck/core/widgets/common/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Simple privacy consent bottom sheet
class PrivacyConsentDialog extends ConsumerStatefulWidget {
  const PrivacyConsentDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      builder: (_) => const PrivacyConsentDialog(),
    );
  }

  @override
  ConsumerState<PrivacyConsentDialog> createState() => _PrivacyConsentDialogState();
}

class _PrivacyConsentDialogState extends ConsumerState<PrivacyConsentDialog> {
  bool _analytics = false;
  bool _ads = false;
  bool _crash = false;

  void _setAll(bool value) {
    setState(() {
      _analytics = value;
      _ads = value;
      _crash = value;
    });
  }

  Future<void> _save() async {
    await ref.read(privacyConsentProvider.notifier).updateConsent(
      analyticsConsent: _analytics,
      adConsent: _ads,
      crashReportingConsent: _crash,
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SText('privacy_consent.title',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            SText('privacy_consent.description'),
            const SizedBox(height: 24),
            _ConsentItem(
              title: 'privacy_consent.analytics.title'.tr(),
              description: 'privacy_consent.analytics.description'.tr(),
              value: _analytics,
              onChanged: (v) => setState(() => _analytics = v),
            ),
            _ConsentItem(
              title: 'privacy_consent.ads.title'.tr(),
              description: 'privacy_consent.ads.description'.tr(),
              value: _ads,
              onChanged: (v) => setState(() => _ads = v),
            ),
            _ConsentItem(
              title: 'privacy_consent.crash.title'.tr(),
              description: 'privacy_consent.crash.description'.tr(),
              value: _crash,
              onChanged: (v) => setState(() => _crash = v),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      _setAll(false);
                      _save();
                    },
                    child: SText('common.rejectAll'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      _setAll(true);
                      _save();
                    },
                    child: SText('common.agreeAll'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConsentItem extends StatelessWidget {
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ConsentItem({
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
