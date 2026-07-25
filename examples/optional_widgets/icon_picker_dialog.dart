import 'package:boilerplate/core/constants/icon_map.dart';
// import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:boilerplate/core/widgets/common/semantics.dart';
import 'package:flutter/material.dart';

class IconPickerDialog extends StatelessWidget {
  const IconPickerDialog({super.key});

  static Future<Map<String, String>?> show(BuildContext context) {
    return showDialog<Map<String, String>>(
      context: context,
      builder: (BuildContext context) => const IconPickerDialog(),
      useRootNavigator: true,
      useSafeArea: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    final size = MediaQuery.of(context).size;
    final isLargeScreen = size.width > 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: isLargeScreen ? 600 : size.width,
        height: size.height * (isLargeScreen ? 0.8 : 0.9),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16.0),
          child: Scaffold(
            appBar: AppBar(
              title: SText('Select an Icon'),
              backgroundColor: colorScheme.primary,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
              ),
            ),
            body: ListView.builder(
              itemCount: AppIcons.categorizedIcons.length,
              itemBuilder: (context, index) {
                String category = AppIcons.categorizedIcons.keys.elementAt(index);
                Map<String, IconData> icons = AppIcons.categorizedIcons[category]!;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SText(
                        category,
                        style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    GridView.count(
                      crossAxisCount: isLargeScreen ? 6 : 4,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: icons.entries.map((entry) {
                        return InkWell(
                          onTap: () {
                            Navigator.of(context).pop({
                              'category': category,
                              'name': entry.key,
                            });
                          },
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Icon(entry.value, size: isLargeScreen ? 48 : 40, color: colorScheme.primary),
                                const SizedBox(width: 10),
                              ]),
                              const SizedBox(height: 4),
                              SText(
                                entry.key,
                                textAlign: TextAlign.center,
                                style: textTheme.bodySmall,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
