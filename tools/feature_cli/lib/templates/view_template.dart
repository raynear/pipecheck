String generateViewFile({
  required String pascalCase,
  required String snakeCase,
  required String camelCase,
  required bool withViewModel,
  required bool withModel,
}) {
  if (withViewModel) {
    return '''import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../view_models/${snakeCase}_view_model.dart';

class ${pascalCase}View extends ConsumerStatefulWidget {
  const ${pascalCase}View({super.key});

  @override
  ConsumerState<${pascalCase}View> createState() => _${pascalCase}ViewState();
}

class _${pascalCase}ViewState extends ConsumerState<${pascalCase}View> {
  @override
  void initState() {
    super.initState();
    // 초기화가 필요한 경우
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   ref.read(${camelCase}ViewModelProvider.notifier).initialize();
    // });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(${camelCase}ViewModelProvider);

    if (state.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(state.errorMessage!),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.read(${camelCase}ViewModelProvider.notifier).clearError();
                },
                child: Text('common.retry'.tr()),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('$pascalCase'),
      ),
      body: const Center(
        child: Text('$pascalCase View'),
      ),
    );
  }
}
''';
  } else {
    // Simple view without ViewModel
    return '''import 'package:flutter/material.dart';

class ${pascalCase}View extends StatelessWidget {
  const ${pascalCase}View({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('$pascalCase'),
      ),
      body: const Center(
        child: Text('$pascalCase View'),
      ),
    );
  }
}
''';
  }
}
