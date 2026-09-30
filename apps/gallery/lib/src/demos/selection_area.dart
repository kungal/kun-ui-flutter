import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';

Widget selectionAreaBasic(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: _SelectionAreaBasic(),
  );
}

class _SelectionAreaBasic extends StatefulWidget {
  const _SelectionAreaBasic();

  @override
  State<_SelectionAreaBasic> createState() => _SelectionAreaBasicState();
}

class _SelectionAreaBasicState extends State<_SelectionAreaBasic> {
  String _selected = 'No selection.';
  String _status = 'Select text, click permalink, or right-click off a '
      'selection for Reply.';
  Offset? _menuAt;
  late final TapGestureRecognizer _permalink = TapGestureRecognizer()
    ..onTap = () => setState(() => _status = 'Opened permalink');

  static const List<KunContextMenuItem> _actions = <KunContextMenuItem>[
    KunContextMenuItem(key: 'reply', label: 'Reply', icon: KunIcons.reply),
    KunContextMenuItem(
      key: 'copy-link',
      label: 'Copy link',
      icon: KunIcons.copy,
    ),
  ];

  @override
  void dispose() {
    _permalink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    return KunContextMenu(
      visible: _menuAt != null,
      position: _menuAt ?? Offset.zero,
      items: _actions,
      onSelected: (KunContextMenuItem item) =>
          setState(() => _status = item.label),
      onClose: () => setState(() => _menuAt = null),
      child: SizedBox(
        width: KunSpacing.unit * 100,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            KunSelectionArea(
              onSelectionChanged: (content) {
                setState(() {
                  final String? text = content?.plainText;
                  _selected = (text == null || text.isEmpty)
                      ? 'No selection.'
                      : 'Selected: $text';
                });
              },
              onSecondaryTapOutsideSelection: (Offset at) => setState(() {
                _menuAt = at;
                _status = 'Object menu at ${at.dx.toStringAsFixed(0)}, '
                    '${at.dy.toStringAsFixed(0)}';
              }),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '今晚的帖子还是那句老话：把能抄的字留下来，其余的让应用自己决定。',
                    style: KunText.sm.copyWith(color: scheme.foreground),
                  ),
                  const SizedBox(height: KunSpacing.unit * 3),
                  Text.rich(
                    TextSpan(
                      style: KunText.sm.copyWith(color: scheme.foreground),
                      children: <InlineSpan>[
                        const TextSpan(
                          text:
                              'The gallery is the living documentation for every claimed widget. See the ',
                        ),
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
                  const SizedBox(height: KunSpacing.unit * 3),
                  KunButton(
                    size: KunUISize.sm,
                    variant: KunUIVariant.bordered,
                    onPressed: () => setState(() => _status = 'Pressed reply'),
                    child: const Text('Reply'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: KunSpacing.unit * 4),
            Text(
              _selected,
              style: KunText.xs.copyWith(color: scheme.foregroundMuted),
            ),
            const SizedBox(height: KunSpacing.unit),
            Text(
              _status,
              style: KunText.xs.copyWith(color: scheme.foregroundMuted),
            ),
          ],
        ),
      ),
    );
  }
}
