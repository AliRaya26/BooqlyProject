import 'package:flutter/material.dart';
import 'package:booqly/theme/theme_service.dart';

/// Segmented control for Light / Dark / System theme selection.
class ThemeModePicker extends StatelessWidget {
  const ThemeModePicker({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.instance.notifier,
      builder: (context, mode, _) {
        return SegmentedButton<ThemeMode>(
          segments: [
            ButtonSegment(
              value: ThemeMode.light,
              icon: Icon(ThemeService.instance.iconFor(ThemeMode.light)),
              label: const Text('Light'),
            ),
            ButtonSegment(
              value: ThemeMode.dark,
              icon: Icon(ThemeService.instance.iconFor(ThemeMode.dark)),
              label: const Text('Dark'),
            ),
            ButtonSegment(
              value: ThemeMode.system,
              icon: Icon(ThemeService.instance.iconFor(ThemeMode.system)),
              label: const Text('System'),
            ),
          ],
          selected: {mode},
          onSelectionChanged: (selection) {
            ThemeService.instance.setMode(selection.first);
          },
        );
      },
    );
  }
}
