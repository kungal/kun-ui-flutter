import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';

void _press() {}

Widget cardAnatomy(BuildContext context) {
  final KunThemeData theme = KunTheme.of(context);
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: SizedBox(
      width: 360,
      child: KunCard(
        header: const Text('header'),
        cover: ColoredBox(
          color: theme.colors.neutral.shade200,
          child: const SizedBox(
            height: 120,
            child: Center(child: Text('cover')),
          ),
        ),
        footer: const Row(
          mainAxisSize: MainAxisSize.min,
          spacing: KunSpacing.unit * 3,
          children: [
            KunButton(
              onPressed: _press,
              child: Text('Save'),
            ),
            KunButton(
              variant: KunUIVariant.bordered,
              color: KunUIColor.neutral,
              onPressed: _press,
              child: Text('Cancel'),
            ),
          ],
        ),
        child: const Text(
          'The body is the default slot. A card is a raised surface; these four slots are what it is made of.',
        ),
      ),
    ),
  );
}

Widget cardTints(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      spacing: KunSpacing.unit * 3,
      children: [
        for (final KunUIColor? color in <KunUIColor?>[
          null,
          ...KunUIColor.values,
        ])
          SizedBox(
            width: 320,
            child: KunCard(
              color: color,
              padding: KunCardPadding.md,
              child: Text(color?.name ?? 'background'),
            ),
          ),
      ],
    ),
  );
}

Widget cardSurfaces(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      spacing: KunSpacing.unit * 5,
      children: [
        for (final bool isTransparent in <bool>[false, true])
          for (final bool bordered in <bool>[true, false])
            SizedBox(
              width: 320,
              child: KunCard(
                bordered: bordered,
                isTransparent: isTransparent,
                child: Text(
                  '${bordered ? 'bordered' : 'unbordered'}, '
                  '${isTransparent ? 'transparent' : 'raised'}',
                ),
              ),
            ),
      ],
    ),
  );
}

Widget cardPadding(BuildContext context) {
  final KunThemeData theme = KunTheme.of(context);
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      spacing: KunSpacing.unit * 5,
      children: [
        for (final KunCardPadding padding in KunCardPadding.values)
          SizedBox(
            width: 320,
            child: KunCard(
              padding: padding,
              child: ColoredBox(
                color: theme.colors.neutral.shade200,
                child: Padding(
                  padding: const EdgeInsets.all(KunSpacing.unit * 3),
                  child: Text(padding.name),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

Widget cardInteractive(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: KunSpacing.unit * 5,
        children: [
          SizedBox(
            width: 240,
            child: KunCard(
              onTap: _press,
              child: Text('plain'),
            ),
          ),
          SizedBox(
            width: 240,
            child: KunCard(
              isHoverable: true,
              onTap: _press,
              child: Text('isHoverable'),
            ),
          ),
          SizedBox(
            width: 240,
            child: KunCard(
              clickable: true,
              onTap: _press,
              child: Text('clickable'),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget cardRounded(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunSpacing.unit * 5,
      children: [
        Text(
          'The theme-wide default is ${KunTheme.of(context).rounded.name}; each explicit value overrides it.',
        ),
        Wrap(
          spacing: KunSpacing.unit * 5,
          runSpacing: KunSpacing.unit * 5,
          children: [
            for (final KunUIRounded? rounded in <KunUIRounded?>[
              null,
              ...KunUIRounded.values,
            ])
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: KunSpacing.unit * 3,
                children: [
                  Text(
                    rounded == null ? 'null (follows the theme)' : rounded.name,
                  ),
                  SizedBox(
                    width: 240,
                    child: KunCard(
                      rounded: rounded,
                      padding: KunCardPadding.md,
                      child: const Text('Card'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    ),
  );
}
