import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';

Widget _caption(BuildContext context, String text) {
  return Text(
    text,
    style: KunText.sm.copyWith(
      color: KunTheme.of(context).colors.neutral.shade600,
    ),
  );
}

Widget _page(BuildContext context, String caption, List<Widget> children) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: KunSpacing.unit * 5,
      children: <Widget>[_caption(context, caption), ...children],
    ),
  );
}

Widget progressBasic(BuildContext context) {
  return _page(
    context,
    'value against max, rounded to a whole percent — the same number a '
    'screen reader hears.',
    <Widget>[
      const KunProgress(value: 0),
      const KunProgress(value: 33.4, showLabel: true),
      const KunProgress(value: 100, showLabel: true),
      const KunProgress(value: 30, max: 60, showLabel: true),
    ],
  );
}

Widget progressVariants(BuildContext context) {
  return _page(context, 'solid, gradient, striped and the ring.', <Widget>[
    const KunProgress(value: 65, showLabel: true),
    const KunProgress(
      value: 65,
      variant: KunProgressVariant.gradient,
      showLabel: true,
    ),
    const KunProgress(
      value: 65,
      variant: KunProgressVariant.striped,
      showLabel: true,
    ),
    const Align(
      alignment: AlignmentDirectional.centerStart,
      child: KunProgress(
        value: 65,
        variant: KunProgressVariant.circle,
        showLabel: true,
      ),
    ),
  ]);
}

Widget progressSizes(BuildContext context) {
  return _page(context, 'The web h-1 to h-5.', <Widget>[
    for (final KunUISize size in KunUISize.values) ...<Widget>[
      Text(size.name, style: KunText.xs),
      KunProgress(value: 60, size: size),
    ],
  ]);
}

Widget progressColors(BuildContext context) {
  return _page(context, 'Every hue, with the label on the bar.', <Widget>[
    for (final KunUIColor color in KunUIColor.values)
      KunProgress(value: 70, color: color, showLabel: true),
  ]);
}

Widget progressRounded(BuildContext context) {
  return _page(
    context,
    'The rounding steps. A full bar is a pill at any thickness.',
    <Widget>[
      for (final KunUIRounded rounded in KunUIRounded.values) ...<Widget>[
        Text(rounded.name, style: KunText.xs),
        KunProgress(value: 45, size: KunUISize.lg, rounded: rounded),
      ],
    ],
  );
}

Widget progressIndeterminate(BuildContext context) {
  return _page(
    context,
    'Progress is unknown: the bar sweeps and the ring spins, and neither '
    'reports a value.',
    <Widget>[
      const KunProgress(indeterminate: true),
      const KunProgress(
        indeterminate: true,
        variant: KunProgressVariant.gradient,
        size: KunUISize.lg,
      ),
      const Align(
        alignment: AlignmentDirectional.centerStart,
        child: KunProgress(
          indeterminate: true,
          variant: KunProgressVariant.circle,
        ),
      ),
    ],
  );
}
