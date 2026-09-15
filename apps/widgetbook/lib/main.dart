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
              name: 'KunCard',
              useCases: [
                WidgetbookUseCase(name: 'Playground', builder: _cardPlayground),
                WidgetbookUseCase(name: 'Tints', builder: (_) => _cardTints()),
              ],
            ),
            WidgetbookComponent(
              name: 'KunChip',
              useCases: [
                WidgetbookUseCase(name: 'Playground', builder: _chipPlayground),
                WidgetbookUseCase(
                    name: 'Matrix', builder: (_) => _chipMatrix()),
              ],
            ),
            WidgetbookComponent(
              name: 'KunInput',
              useCases: [
                WidgetbookUseCase(
                    name: 'Playground', builder: _inputPlayground),
                WidgetbookUseCase(name: 'Sizes', builder: (_) => _inputSizes()),
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
    // A phone is narrower than the seven-colour matrix: at 1080px this
    // overflowed by 90px, where the same use case at 1440px in Chrome had
    // looked fine. Scrolling the Column rather than each Row keeps the
    // columns aligned across variants.
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: [
          for (final variant in KunUIVariant.values)
            Row(
              mainAxisSize: MainAxisSize.min,
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
    ),
  );
}

Widget _cardPlayground(BuildContext context) {
  final padding = context.knobs.object.dropdown(
    label: 'padding',
    options: KunCardPadding.values,
    initialOption: KunCardPadding.lg,
    labelBuilder: (v) => v.name,
  );
  // objectOrNull, not object: `object.dropdown` returns `onKnobAdded(...)!`,
  // so a legitimately null value throws. null is the card's `background`.
  final color = context.knobs.objectOrNull.dropdown(
    label: 'color (null = background)',
    options: KunUIColor.values,
    labelBuilder: (v) => v.name,
    defaultToNull: true,
  );
  final rounded = context.knobs.objectOrNull.dropdown(
    label: 'rounded (null = theme)',
    options: KunUIRounded.values,
    labelBuilder: (v) => v.name,
    defaultToNull: true,
  );
  final bordered = context.knobs.boolean(label: 'bordered', initialValue: true);
  final clickable = context.knobs.boolean(label: 'clickable');
  final isHoverable = context.knobs.boolean(label: 'isHoverable');
  final isTransparent = context.knobs.boolean(label: 'isTransparent');
  return Builder(
    builder: (context) {
      final theme = KunTheme.of(context);
      return SizedBox(
        width: 360,
        child: KunCard(
          padding: padding,
          color: color,
          rounded: rounded,
          bordered: bordered,
          clickable: clickable,
          isHoverable: isHoverable,
          isTransparent: isTransparent,
          onTap: () {},
          header: Text(
            'Fate/stay night',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.colors.foreground,
            ),
          ),
          footer: Row(
            spacing: 8,
            children: [
              const KunChip(child: Text('TYPE-MOON')),
              const KunChip(color: KunUIColor.success, child: Text('已汉化')),
            ],
          ),
          child: Text(
            '卫宫士郎在圣杯战争中卷入了七位从者的厮杀。',
            style: TextStyle(color: theme.colors.content4),
          ),
        ),
      );
    },
  );
}

Widget _cardTints() {
  return Builder(
    builder: (context) {
      final theme = KunTheme.of(context);
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            for (final color in <KunUIColor?>[null, ...KunUIColor.values])
              SizedBox(
                width: 320,
                child: KunCard(
                  color: color,
                  padding: KunCardPadding.md,
                  child: Text(
                    color?.name ?? 'background',
                    style: TextStyle(color: theme.colors.foreground),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

Widget _chipPlayground(BuildContext context) {
  final label = context.knobs.string(label: 'Label', initialValue: '全年龄');
  final variant = context.knobs.object.dropdown(
    label: 'variant',
    options: KunUIVariant.values,
    initialOption: KunUIVariant.flat,
    labelBuilder: (v) => v.name,
  );
  final color = context.knobs.object.dropdown(
    label: 'color',
    options: KunUIColor.values,
    labelBuilder: (v) => v.name,
  );
  final size = context.knobs.object.dropdown(
    label: 'size',
    options: KunUISize.values,
    initialOption: KunUISize.sm,
    labelBuilder: (v) => v.name,
  );
  final closable = context.knobs.boolean(label: 'closable');
  final disabled = context.knobs.boolean(label: 'disabled');
  return KunChip(
    variant: variant,
    color: color,
    size: size,
    closable: closable,
    disabled: disabled,
    onClose: () {},
    child: Text(label),
  );
}

Widget _chipMatrix() {
  return SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    // A phone is narrower than the seven-colour matrix: at 1080px this
    // overflowed by 90px, where the same use case at 1440px in Chrome had
    // looked fine. Scrolling the Column rather than each Row keeps the
    // columns aligned across variants.
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: [
          for (final variant in KunUIVariant.values)
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                for (final color in KunUIColor.values)
                  KunChip(
                    variant: variant,
                    color: color,
                    child: Text(color.name),
                  ),
              ],
            ),
        ],
      ),
    ),
  );
}

Widget _inputPlayground(BuildContext context) {
  final label = context.knobs.string(label: 'label', initialValue: '用户名');
  final placeholder =
      context.knobs.string(label: 'placeholder', initialValue: '请输入');
  final description =
      context.knobs.string(label: 'description', initialValue: '');
  final error = context.knobs.string(label: 'error', initialValue: '');
  final type = context.knobs.object.dropdown(
    label: 'type',
    options: KunInputType.values,
    labelBuilder: (v) => v.name,
  );
  final color = context.knobs.object.dropdown(
    label: 'color',
    options: KunUIColor.values,
    labelBuilder: (v) => v.name,
  );
  final size = context.knobs.object.dropdown(
    label: 'size',
    options: KunUISize.values,
    initialOption: KunUISize.md,
    labelBuilder: (v) => v.name,
  );
  final required = context.knobs.boolean(label: 'required');
  final disabled = context.knobs.boolean(label: 'disabled');
  final isInvalid = context.knobs.boolean(label: 'isInvalid');
  final isClearable =
      context.knobs.boolean(label: 'isClearable', initialValue: true);
  final revealPassword =
      context.knobs.boolean(label: 'revealPassword', initialValue: true);
  final withPrefix = context.knobs.boolean(label: 'prefix');
  return SizedBox(
    width: 360,
    child: _InputHost(
      label: label,
      placeholder: placeholder,
      description: description,
      error: error,
      type: type,
      color: color,
      size: size,
      required: required,
      disabled: disabled,
      isInvalid: isInvalid,
      isClearable: isClearable,
      revealPassword: revealPassword,
      prefix: withPrefix ? const Icon(KunIcons.search, size: 16) : null,
    ),
  );
}

/// KunInput is controlled — the gallery needs somewhere to hold the value.
class _InputHost extends StatefulWidget {
  const _InputHost({
    required this.label,
    required this.placeholder,
    required this.description,
    required this.error,
    required this.type,
    required this.color,
    required this.size,
    required this.required,
    required this.disabled,
    required this.isInvalid,
    required this.isClearable,
    required this.revealPassword,
    this.prefix,
  });

  final String label;
  final String placeholder;
  final String description;
  final String error;
  final KunInputType type;
  final KunUIColor color;
  final KunUISize size;
  final bool required;
  final bool disabled;
  final bool isInvalid;
  final bool isClearable;
  final bool revealPassword;
  final Widget? prefix;

  @override
  State<_InputHost> createState() => _InputHostState();
}

class _InputHostState extends State<_InputHost> {
  String _value = '';

  @override
  Widget build(BuildContext context) {
    return KunInput(
      value: _value,
      onChanged: (v) => setState(() => _value = v),
      label: widget.label,
      placeholder: widget.placeholder,
      description: widget.description,
      error: widget.error,
      type: widget.type,
      color: widget.color,
      size: widget.size,
      required: widget.required,
      disabled: widget.disabled,
      isInvalid: widget.isInvalid,
      isClearable: widget.isClearable,
      revealPassword: widget.revealPassword,
      prefix: widget.prefix,
    );
  }
}

Widget _inputSizes() {
  return SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 16,
      children: [
        for (final size in KunUISize.values)
          SizedBox(
            width: 360,
            child: Row(
              spacing: 12,
              children: [
                Expanded(
                  child: KunInput(size: size, placeholder: size.name),
                ),
                KunButton(
                    size: size, onPressed: () {}, child: const Text('GO')),
                KunButton(
                  size: size,
                  isIconOnly: true,
                  semanticLabel: 'search',
                  onPressed: () {},
                  child: const Icon(KunIcons.search),
                ),
              ],
            ),
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
