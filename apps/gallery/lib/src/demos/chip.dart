import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';

void _press() {}

Widget chipMatrix(BuildContext context) {
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
          for (final KunUIVariant variant in KunUIVariant.values)
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                for (final KunUIColor color in KunUIColor.values)
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

Widget chipSizes(BuildContext context) {
  return Padding(
    padding: EdgeInsets.all(KunCardPadding.lg.value),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      spacing: KunCardPadding.sm.value,
      children: [
        for (final KunUISize size in KunUISize.values)
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: KunCardPadding.sm.value,
            children: [
              KunChip(
                size: size,
                child: Text(size.name),
              ),
              KunButton(
                size: size,
                onPressed: _press,
                child: Text(size.name),
              ),
            ],
          ),
      ],
    ),
  );
}

Widget chipParts(BuildContext context) {
  return Padding(
    padding: EdgeInsets.all(KunCardPadding.lg.value),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunCardPadding.md.value,
      children: const [
        Text('start'),
        KunChip(
          start: Icon(KunIcons.circleCheck),
        ),
        Text('start + label'),
        KunChip(
          start: Icon(KunIcons.circleCheck),
          child: Text('label'),
        ),
        Text('label + closable'),
        KunChip(
          closable: true,
          child: Text('label'),
        ),
        Text('start + label + closable + end'),
        KunChip(
          start: Icon(KunIcons.circleCheck),
          closable: true,
          end: Icon(KunIcons.externalLink),
          child: Text('label'),
        ),
        Text('disabled, closable'),
        KunChip(
          disabled: true,
          closable: true,
          child: Text('label'),
        ),
      ],
    ),
  );
}

Widget chipDismiss(BuildContext context) {
  return Padding(
    padding: EdgeInsets.all(KunCardPadding.lg.value),
    child: const _ChipDismiss(),
  );
}

class _ChipDismiss extends StatefulWidget {
  const _ChipDismiss();

  @override
  State<_ChipDismiss> createState() => _ChipDismissState();
}

class _ChipDismissState extends State<_ChipDismiss> {
  List<KunUIColor> _tags = List<KunUIColor>.of(KunUIColor.values);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: KunCardPadding.md.value,
      children: [
        Wrap(
          spacing: KunCardPadding.sm.value,
          runSpacing: KunCardPadding.sm.value,
          children: [
            for (final KunUIColor color in _tags)
              KunChip(
                color: color,
                closable: true,
                onClose: () => setState(() {
                  _tags =
                      _tags.where((KunUIColor tag) => tag != color).toList();
                }),
                child: Text(color.name),
              ),
          ],
        ),
        KunButton(
          onPressed: () => setState(() {
            _tags = List<KunUIColor>.of(KunUIColor.values);
          }),
          child: const Text('Reset'),
        ),
      ],
    );
  }
}
