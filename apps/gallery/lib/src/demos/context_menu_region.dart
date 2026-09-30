import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';

const List<KunMenuEntry> _actions = <KunMenuEntry>[
  KunContextMenuItem(key: 'reply', label: 'Reply', icon: KunIcons.reply),
  KunContextMenuItem(key: 'quote', label: 'Quote', icon: KunIcons.quote),
  KunContextMenuItem(key: 'copy', label: 'Copy text', icon: KunIcons.copy),
  KunMenuSeparator(),
  KunContextMenuItem(
    key: 'report',
    label: 'Report',
    icon: KunIcons.flag,
    color: KunUIColor.warning,
  ),
];

Widget contextMenuRegionBasic(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: _ReplyCard(),
  );
}

class _ReplyCard extends StatefulWidget {
  const _ReplyCard();

  @override
  State<_ReplyCard> createState() => _ReplyCardState();
}

class _ReplyCardState extends State<_ReplyCard> {
  final GlobalKey<KunContextMenuRegionState> _region =
      GlobalKey<KunContextMenuRegionState>();
  late final TapGestureRecognizer _permalink = TapGestureRecognizer()
    ..onTap = () => setState(() => _last = 'Opened permalink');
  String _last = 'Right-click the card, long-press, or use the ⋯ menu.';

  @override
  void dispose() {
    _permalink.dispose();
    super.dispose();
  }

  void _choose(KunContextMenuItem item) {
    setState(() => _last = 'Last chosen: ${item.label}');
  }

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunSpacing.unit * 4,
      children: <Widget>[
        SizedBox(
          width: KunSpacing.unit * 100,
          child: KunCard(
            padding: KunCardPadding.md,
            child: KunContextMenuRegion(
              key: _region,
              items: _actions,
              semanticActionLabel: 'Open message actions',
              onSelected: _choose,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: KunSpacing.unit * 3,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Haru',
                          style: KunText.sm.copyWith(
                            color: scheme.foreground,
                            fontWeight: KunFontWeights.medium,
                          ),
                        ),
                      ),
                      Text(
                        '#12',
                        style: KunText.xs.copyWith(
                          color: scheme.foregroundMuted,
                        ),
                      ),
                    ],
                  ),
                  KunSelectionArea(
                    onSecondaryTapOutsideSelection: (Offset at) =>
                        _region.currentState!.openAt(at),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: KunSpacing.unit * 2,
                      children: <Widget>[
                        Text(
                          'The gallery is the living documentation for every '
                          'claimed widget. A reply is not a button, but it '
                          'still owns a command menu.',
                          style: KunText.sm.copyWith(color: scheme.foreground),
                        ),
                        Text.rich(
                          TextSpan(
                            style:
                                KunText.sm.copyWith(color: scheme.foreground),
                            children: <InlineSpan>[
                              const TextSpan(text: 'See the '),
                              TextSpan(
                                text: 'permalink',
                                style: KunText.sm.copyWith(
                                  color: scheme.primary.solid,
                                  fontWeight: KunFontWeights.medium,
                                ),
                                recognizer: _permalink,
                              ),
                              const TextSpan(text: ' for the source thread.'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    spacing: KunSpacing.unit * 2,
                    children: <Widget>[
                      KunButton(
                        size: KunUISize.sm,
                        variant: KunUIVariant.light,
                        color: KunUIColor.neutral,
                        icon: const Icon(KunIcons.heart),
                        onPressed: () => setState(() => _last = 'Pressed like'),
                        child: const Text('Like'),
                      ),
                      KunButton(
                        size: KunUISize.sm,
                        variant: KunUIVariant.light,
                        color: KunUIColor.neutral,
                        icon: const Icon(KunIcons.reply),
                        onPressed: () =>
                            setState(() => _last = 'Pressed reply'),
                        child: const Text('Reply'),
                      ),
                      const Spacer(),
                      KunDropdown(
                        items: _actions,
                        onSelected: _choose,
                        trigger: KunButton(
                          size: KunUISize.sm,
                          variant: KunUIVariant.light,
                          color: KunUIColor.neutral,
                          isIconOnly: true,
                          semanticLabel: 'More actions',
                          onPressed: null,
                          child: Text(
                            '⋯',
                            style: KunText.lg.copyWith(
                              color: scheme.foreground,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Text(
          _last,
          style: KunText.xs.copyWith(color: scheme.foregroundMuted),
        ),
      ],
    );
  }
}
