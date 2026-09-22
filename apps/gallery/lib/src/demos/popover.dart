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

Widget _panel(BuildContext context, String title, {double width = 220}) {
  final KunColorScheme scheme = KunTheme.of(context).colors;
  return SizedBox(
    width: width,
    child: Padding(
      padding: const EdgeInsets.all(KunSpacing.unit * 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: KunSpacing.unit * 2,
        children: <Widget>[
          Text(
            title,
            style: KunText.sm.copyWith(fontWeight: KunFontWeights.semibold),
          ),
          Text(
            'A popover is a dialog anchored to its trigger. Focus moves in '
            'when it opens and goes back when it closes.',
            style: KunText.xs.copyWith(color: scheme.neutral.shade600),
          ),
        ],
      ),
    ),
  );
}

Widget popoverBasic(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunSpacing.unit * 4,
      children: <Widget>[
        _caption(
          context,
          'Click the trigger. Escape, a click outside and the Android back '
          'gesture all close it.',
        ),
        KunPopover(
          trigger: KunButton(onPressed: () {}, child: const Text('Details')),
          child: Builder(
            builder: (BuildContext context) => _panel(context, 'Details'),
          ),
        ),
      ],
    ),
  );
}

Widget popoverPositions(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 10),
    child: Wrap(
      spacing: KunSpacing.unit * 3,
      runSpacing: KunSpacing.unit * 3,
      children: <Widget>[
        for (final KunPopoverPosition position in KunPopoverPosition.values)
          KunPopover(
            position: position,
            trigger: KunButton(
              onPressed: () {},
              size: KunUISize.sm,
              variant: KunUIVariant.bordered,
              child: Text(position.name),
            ),
            child: Builder(
              builder: (BuildContext context) =>
                  _panel(context, position.name, width: 180),
            ),
          ),
      ],
    ),
  );
}

Widget popoverArrow(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 14),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunSpacing.unit * 6,
      children: <Widget>[
        _caption(
          context,
          'A caret points at the trigger. A panel with one is never capped and '
          'scrolled, because the caret sits half outside its edge.',
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: KunSpacing.unit * 4,
          children: <Widget>[
            for (final KunUIRounded rounded in <KunUIRounded>[
              KunUIRounded.none,
              KunUIRounded.md,
              KunUIRounded.lg,
            ])
              KunPopover(
                showArrow: true,
                rounded: rounded,
                position: KunPopoverPosition.bottom,
                trigger: KunButton(
                  onPressed: () {},
                  variant: KunUIVariant.bordered,
                  child: Text(rounded.name),
                ),
                child: Builder(
                  builder: (BuildContext context) =>
                      _panel(context, rounded.name, width: 200),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

Widget popoverHover(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunSpacing.unit * 4,
      children: <Widget>[
        _caption(
          context,
          'A menu bar: hovering opens after 100ms, moving between siblings '
          'switches instantly, and the pointer may cut the corner to reach a '
          'panel without it closing. A tap still works on a touch screen.',
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: KunSpacing.unit * 2,
          children: <Widget>[
            for (final String section in <String>['Games', 'Patches', 'About'])
              KunPopover(
                openOn: KunPopoverTrigger.hover,
                group: 'gallery-menu-bar',
                trigger: KunButton(
                  onPressed: () {},
                  variant: KunUIVariant.light,
                  child: Text(section),
                ),
                child: Builder(
                  builder: (BuildContext context) =>
                      _panel(context, section, width: 200),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

Widget popoverFixed(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunSpacing.unit * 4,
      children: <Widget>[
        _caption(
          context,
          'Both ask for the top. The first flips below because there is no '
          'room; the second is told not to, and runs off the top of the view.',
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: KunSpacing.unit * 4,
          children: <Widget>[
            KunPopover(
              position: KunPopoverPosition.topStart,
              trigger: KunButton(
                onPressed: () {},
                variant: KunUIVariant.bordered,
                child: const Text('autoPosition'),
              ),
              child: Builder(
                builder: (BuildContext context) =>
                    _panel(context, 'Flipped', width: 200),
              ),
            ),
            KunPopover(
              position: KunPopoverPosition.topStart,
              autoPosition: false,
              trigger: KunButton(
                onPressed: () {},
                variant: KunUIVariant.bordered,
                child: const Text('verbatim'),
              ),
              child: Builder(
                builder: (BuildContext context) =>
                    _panel(context, 'Verbatim', width: 200),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget popoverFullWidth(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunSpacing.unit * 4,
      children: <Widget>[
        _caption(context, 'The trigger fills its parent instead of its text.'),
        SizedBox(
          width: 320,
          child: KunPopover(
            fullWidth: true,
            trigger: KunButton(
              onPressed: () {},
              fullWidth: true,
              child: const Text('Pick a platform'),
            ),
            child: Builder(
              builder: (BuildContext context) =>
                  _panel(context, 'Platforms', width: 320),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget popoverControlled(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: _PopoverControlled(),
  );
}

class _PopoverControlled extends StatefulWidget {
  const _PopoverControlled();

  @override
  State<_PopoverControlled> createState() => _PopoverControlledState();
}

class _PopoverControlledState extends State<_PopoverControlled> {
  final KunPopoverController _controller = KunPopoverController();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunSpacing.unit * 4,
      children: <Widget>[
        _caption(context, 'Opened and closed from outside the popover.'),
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: KunSpacing.unit * 3,
          children: <Widget>[
            KunButton(
              onPressed: _controller.open,
              variant: KunUIVariant.bordered,
              child: const Text('Open'),
            ),
            KunButton(
              onPressed: _controller.close,
              variant: KunUIVariant.bordered,
              child: const Text('Close'),
            ),
            KunPopover(
              controller: _controller,
              trigger: KunButton(
                onPressed: () {},
                variant: KunUIVariant.light,
                child: const Text('Anchor'),
              ),
              child: Builder(
                builder: (BuildContext context) =>
                    _panel(context, 'Controlled'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
