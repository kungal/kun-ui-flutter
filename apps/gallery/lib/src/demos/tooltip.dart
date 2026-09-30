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

Widget _target(String label) {
  return KunButton(
    onPressed: () {},
    variant: KunUIVariant.bordered,
    child: Text(label),
  );
}

Widget tooltipBasic(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunSpacing.unit * 4,
      children: <Widget>[
        _caption(
          context,
          'Hover or tab to the button. A tooltip opens on a pointer and on '
          'focus, never on a tap.',
        ),
        KunTooltip(text: 'Copy this link', child: _target('Share')),
      ],
    ),
  );
}

Widget tooltipPositions(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 14),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      spacing: KunSpacing.unit * 6,
      children: <Widget>[
        for (final KunTooltipPosition position in KunTooltipPosition.values)
          KunTooltip(
            text: 'On the ${position.name}',
            position: position,
            child: _target(position.name),
          ),
      ],
    ),
  );
}

Widget tooltipArrow(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 14),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunSpacing.unit * 6,
      children: <Widget>[
        _caption(context, 'A caret, and the rounding steps.'),
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: KunSpacing.unit * 4,
          children: <Widget>[
            for (final KunUIRounded rounded in KunUIRounded.values)
              KunTooltip(
                text: rounded.name,
                showArrow: true,
                rounded: rounded,
                position: KunTooltipPosition.bottom,
                child: _target(rounded.name),
              ),
          ],
        ),
      ],
    ),
  );
}

Widget tooltipDelays(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 14),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunSpacing.unit * 6,
      children: <Widget>[
        _caption(
          context,
          'The left one waits a second before opening; the right one lingers '
          'a second after the pointer leaves.',
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: KunSpacing.unit * 4,
          children: <Widget>[
            KunTooltip(
              text: 'Opened slowly',
              delayShow: const Duration(seconds: 1),
              child: _target('Slow to open'),
            ),
            KunTooltip(
              text: 'Closed slowly',
              delayHide: const Duration(seconds: 1),
              child: _target('Slow to close'),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget tooltipContent(BuildContext context) {
  final KunColorScheme scheme = KunTheme.of(context).colors;
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 14),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunSpacing.unit * 6,
      children: <Widget>[
        _caption(
          context,
          'A widget replaces the text in the panel. The text is still what a '
          'screen reader reads.',
        ),
        KunTooltip(
          text: 'Signed in as kun',
          position: KunTooltipPosition.right,
          content: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: KunSpacing.unit * 2,
            children: <Widget>[
              Icon(
                KunIcons.check,
                size: KunSpacing.unit * 4,
                color: scheme.primary.solid,
              ),
              const Text('Signed in as kun'),
            ],
          ),
          child: _target('Account'),
        ),
      ],
    ),
  );
}

Widget tooltipMobile(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 14),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunSpacing.unit * 6,
      children: <Widget>[
        _caption(
          context,
          'Narrow this page under 640px. The first tooltip stops opening, as '
          'the web hides it below the sm breakpoint; the second keeps going.',
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: KunSpacing.unit * 4,
          children: <Widget>[
            KunTooltip(
              text: 'Hidden on a narrow view',
              position: KunTooltipPosition.bottom,
              child: _target('Default'),
            ),
            KunTooltip(
              text: 'Shown at every width',
              position: KunTooltipPosition.bottom,
              hideOnMobile: false,
              child: _target('hideOnMobile: false'),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget tooltipShortcut(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 14),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunSpacing.unit * 6,
      children: <Widget>[
        _caption(
          context,
          'shortcut draws keycap keys after the text. Hover or focus a button.',
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: KunSpacing.unit,
          children: <Widget>[
            KunTooltip(
              text: 'Search',
              shortcut: 'Mod+K',
              child: KunButton(
                variant: KunUIVariant.light,
                color: KunUIColor.neutral,
                isIconOnly: true,
                semanticLabel: 'Search',
                onPressed: () {},
                child: const Icon(KunIcons.search),
              ),
            ),
            KunTooltip(
              text: 'Quote',
              shortcut: 'Q',
              child: KunButton(
                variant: KunUIVariant.light,
                color: KunUIColor.neutral,
                isIconOnly: true,
                semanticLabel: 'Quote',
                onPressed: () {},
                child: const Icon(KunIcons.quote),
              ),
            ),
            KunTooltip(
              text: 'Undo',
              shortcut: 'Mod+Z',
              child: KunButton(
                variant: KunUIVariant.light,
                color: KunUIColor.neutral,
                isIconOnly: true,
                semanticLabel: 'Undo',
                onPressed: () {},
                child: const Icon(KunIcons.rotateCcw),
              ),
            ),
            KunTooltip(
              text: 'Redo',
              shortcut: 'Mod+Shift+Z',
              child: KunButton(
                variant: KunUIVariant.light,
                color: KunUIColor.neutral,
                isIconOnly: true,
                semanticLabel: 'Redo',
                onPressed: () {},
                child: const Icon(KunIcons.rotateCw),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
