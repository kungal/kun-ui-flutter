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

Widget dividerBasic(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: KunSpacing.unit * 6,
      children: <Widget>[
        _caption(context, 'A plain rule, and one with a label in the middle.'),
        const KunDivider(),
        const KunDivider(child: Text('or')),
      ],
    ),
  );
}

Widget dividerOrientation(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: KunSpacing.unit * 6,
      children: <Widget>[
        _caption(
          context,
          'A vertical rule needs a bounded height, as a horizontal one needs '
          'a bounded width.',
        ),
        SizedBox(
          height: 120,
          child: Row(
            children: <Widget>[
              const Expanded(child: Center(child: Text('left'))),
              const KunDivider(
                orientation: KunDividerOrientation.vertical,
              ),
              const Expanded(child: Center(child: Text('right'))),
            ],
          ),
        ),
        SizedBox(
          height: 160,
          child: KunDivider(
            orientation: KunDividerOrientation.vertical,
            color: KunUIColor.primary,
            child: const Text('or'),
          ),
        ),
      ],
    ),
  );
}

Widget dividerStyles(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: KunSpacing.unit * 5,
      children: <Widget>[
        _caption(
          context,
          'Every hue is drawn at 20%; neutral takes the shared border token. '
          'A dashed rule keeps a whole number of dashes, as the browser does.',
        ),
        for (final KunUIColor color in KunUIColor.values) ...<Widget>[
          Text(color.name, style: KunText.xs),
          KunDivider(color: color),
          KunDivider(
            color: color,
            borderStyle: KunDividerBorderStyle.dashed,
          ),
        ],
      ],
    ),
  );
}
