import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';

void _press() {}

Widget buttonMatrix(BuildContext context) {
  return Padding(
    padding: EdgeInsets.all(KunCardPadding.lg.value),
    // A phone is narrower than the seven-colour matrix: at 1080px this
    // overflowed by 90px, where the same use case at 1440px in Chrome had
    // looked fine. The host already scrolls vertically, so a vertical
    // SingleChildScrollView here receives unbounded height, sizes to its
    // content and never scrolls. The remaining horizontal scroll keeps the
    // columns aligned across variants.
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: KunCardPadding.sm.value,
        children: [
          for (final variant in KunUIVariant.values)
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: KunCardPadding.sm.value,
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

Widget buttonSizes(BuildContext context) {
  return Padding(
    padding: EdgeInsets.all(KunCardPadding.lg.value),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      spacing: KunCardPadding.sm.value,
      children: [
        for (final size in KunUISize.values)
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: KunCardPadding.sm.value,
            children: [
              KunButton(
                size: size,
                onPressed: _press,
                child: Text(size.name),
              ),
              KunButton(
                size: size,
                icon: const Icon(KunIcons.plus),
                onPressed: _press,
                child: Text(size.name),
              ),
              KunButton(
                size: size,
                isIconOnly: true,
                semanticLabel: size.name,
                onPressed: _press,
                child: const Icon(KunIcons.plus),
              ),
            ],
          ),
      ],
    ),
  );
}

Widget buttonStates(BuildContext context) {
  return Padding(
    padding: EdgeInsets.all(KunCardPadding.lg.value),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunCardPadding.md.value,
      children: [
        const Text('loading'),
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: KunCardPadding.sm.value,
          children: const [
            KunButton(
              loading: true,
              onPressed: _press,
              child: Text('Save'),
            ),
            KunButton(
              onPressed: _press,
              child: Text('Save'),
            ),
          ],
        ),
        const Text('disabled'),
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: KunCardPadding.sm.value,
          children: const [
            KunButton(
              disabled: true,
              onPressed: _press,
              child: Text('Save'),
            ),
            KunButton(
              onPressed: _press,
              child: Text('Save'),
            ),
          ],
        ),
        const Text('fullWidth'),
        SizedBox(
          width: KunTheme.of(context).breakpoints.sm,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: KunCardPadding.sm.value,
            children: const [
              KunButton(
                fullWidth: true,
                onPressed: _press,
                child: Text('Save'),
              ),
              KunButton(
                onPressed: _press,
                child: Text('Save'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget buttonRounded(BuildContext context) {
  return Padding(
    padding: EdgeInsets.all(KunCardPadding.lg.value),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunCardPadding.md.value,
      children: [
        Text(
          'The theme-wide default is ${KunTheme.of(context).rounded.name}; each explicit value overrides it.',
        ),
        Wrap(
          spacing: KunCardPadding.md.value,
          runSpacing: KunCardPadding.md.value,
          children: [
            for (final KunUIRounded? rounded in <KunUIRounded?>[
              null,
              ...KunUIRounded.values,
            ])
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: KunCardPadding.sm.value,
                children: [
                  Text(
                    rounded == null ? 'null (follows the theme)' : rounded.name,
                  ),
                  KunButton(
                    rounded: rounded,
                    onPressed: _press,
                    child: const Text('Button'),
                  ),
                ],
              ),
          ],
        ),
      ],
    ),
  );
}
