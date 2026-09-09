import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';
import 'package:widgetbook/widgetbook.dart';

void main() {
  runApp(const WidgetbookApp());
}

class WidgetbookApp extends StatelessWidget {
  const WidgetbookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Widgetbook.material(
      addons: [
        ThemeAddon<KunThemeData>(
          themes: [
            WidgetbookTheme(name: 'Light', data: KunThemeData.light()),
            WidgetbookTheme(name: 'Dark', data: KunThemeData.dark()),
          ],
          themeBuilder: (context, theme, child) => KunTheme(
            data: theme,
            child: ColoredBox(
              color: theme.colors.background,
              child: Center(child: child),
            ),
          ),
        ),
      ],
      directories: [
        WidgetbookFolder(
          name: 'Foundation',
          children: [
            WidgetbookComponent(
              name: 'Colors',
              useCases: [
                WidgetbookUseCase(name: 'Scheme', builder: (_) => _colorGrid()),
              ],
            ),
          ],
        ),
        WidgetbookFolder(
          name: 'Components',
          children: [
            WidgetbookComponent(
              name: 'KunButton',
              useCases: [
                WidgetbookUseCase(
                    name: 'Playground', builder: _buttonPlayground),
                WidgetbookUseCase(
                    name: 'Matrix', builder: (_) => _buttonMatrix()),
              ],
            ),
            WidgetbookComponent(
              name: 'KunSpinner',
              useCases: [
                WidgetbookUseCase(name: 'Sizes', builder: (_) => _spinnerRow()),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

Widget _buttonPlayground(BuildContext context) {
  final label = context.knobs.string(label: 'Label', initialValue: 'Save');
  final variant = context.knobs.object.dropdown(
    label: 'variant',
    options: KunUIVariant.values,
    labelBuilder: (v) => v.name,
  );
  final color = context.knobs.object.dropdown(
    label: 'color',
    options: KunUIColor.values,
    initialOption: KunUIColor.primary,
    labelBuilder: (v) => v.name,
  );
  final size = context.knobs.object.dropdown(
    label: 'size',
    options: KunUISize.values,
    initialOption: KunUISize.md,
    labelBuilder: (v) => v.name,
  );
  final disabled = context.knobs.boolean(label: 'disabled');
  final loading = context.knobs.boolean(label: 'loading');
  final withIcon = context.knobs.boolean(label: 'icon');
  return KunButton(
    variant: variant,
    color: color,
    size: size,
    disabled: disabled,
    loading: loading,
    icon: withIcon ? const Icon(KunIcons.plus) : null,
    onPressed: () {},
    child: Text(label),
  );
}

Widget _buttonMatrix() {
  return SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 12,
      children: [
        for (final variant in KunUIVariant.values)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 12,
            children: [
              for (final color in KunUIColor.values)
                KunButton(
                  variant: variant,
                  color: color,
                  onPressed: () {},
                  child: Text(color.name),
                ),
            ],
          ),
      ],
    ),
  );
}

Widget _spinnerRow() {
  return const Row(
    mainAxisAlignment: MainAxisAlignment.center,
    spacing: 24,
    children: [
      KunSpinner(size: 14),
      KunSpinner(size: 24),
      KunSpinner(size: 48),
    ],
  );
}

Widget _colorGrid() {
  return Builder(
    builder: (context) {
      final theme = KunTheme.of(context);
      final scales = {
        'primary': theme.colors.primary,
        'secondary': theme.colors.secondary,
        'success': theme.colors.success,
        'warning': theme.colors.warning,
        'danger': theme.colors.danger,
        'info': theme.colors.info,
        'neutral': theme.colors.neutral,
      };
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            for (final entry in scales.entries)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 4,
                children: [
                  SizedBox(
                    width: 80,
                    child: Text(
                      entry.key,
                      style: TextStyle(color: theme.colors.foreground),
                    ),
                  ),
                  for (final color in [
                    entry.value.shade50,
                    entry.value.shade100,
                    entry.value.shade200,
                    entry.value.shade300,
                    entry.value.shade400,
                    entry.value.shade500,
                    entry.value.shade600,
                    entry.value.shade700,
                    entry.value.shade800,
                    entry.value.shade900,
                    entry.value.shade950,
                  ])
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(KunRadius.sm),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Container(
                    width: 64,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: entry.value.solid,
                      borderRadius: BorderRadius.circular(KunRadius.sm),
                    ),
                    child: Text(
                      'solid',
                      style: TextStyle(color: entry.value.onSolid),
                    ),
                  ),
                ],
              ),
          ],
        ),
      );
    },
  );
}
