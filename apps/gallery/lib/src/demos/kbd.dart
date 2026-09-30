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

Widget kbdBasic(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: Wrap(
      spacing: KunSpacing.unit * 4,
      runSpacing: KunSpacing.unit * 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: const <Widget>[
        KunKbd(keys: 'Mod+K'),
        KunKbd(keys: 'Shift+Mod+Z'),
        KunKbd(keys: 'Alt+ArrowUp'),
        KunKbd(keys: 'Mod+Enter'),
        KunKbd(child: Text('Esc')),
      ],
    ),
  );
}

Widget kbdInText(BuildContext context) {
  final TextStyle body = KunText.sm.copyWith(
    color: KunTheme.of(context).colors.neutral.shade700,
  );
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: DefaultTextStyle.merge(
      style: body,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: KunSpacing.unit * 2,
        children: <Widget>[
          _caption(
            context,
            'A key follows the text around it. The last line is text-base.',
          ),
          const Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(text: 'Press '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: KunKbd(keys: 'Mod+Enter'),
                ),
                TextSpan(text: ' to send, '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: KunKbd(keys: 'Shift+Enter'),
                ),
                TextSpan(text: ' for a new line.'),
              ],
            ),
          ),
          DefaultTextStyle.merge(
            style: KunText.base.copyWith(
              color: KunTheme.of(context).colors.neutral.shade700,
            ),
            child: const Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(text: 'The size follows the body: '),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: KunKbd(keys: 'Mod+Shift+P'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget kbdPlain(BuildContext context) {
  final KunColorScheme scheme = KunTheme.of(context).colors;
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunSpacing.unit * 4,
      children: <Widget>[
        _caption(context, 'Plain is the one-line form a menu uses.'),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: scheme.neutral.shade200),
            borderRadius: BorderRadius.circular(KunRadius.lg),
          ),
          child: SizedBox(
            width: KunSpacing.unit * 64,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _plainRow(scheme, 'Undo', 'Mod+Z', lined: true),
                _plainRow(scheme, 'Redo', 'Mod+Shift+Z', lined: true),
                _plainRow(scheme, 'Delete', 'Mod+Backspace', lined: false),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _plainRow(
  KunColorScheme scheme,
  String label,
  String keys, {
  required bool lined,
}) {
  return DecoratedBox(
    decoration: BoxDecoration(
      border: lined
          ? Border(bottom: BorderSide(color: scheme.neutral.shade200))
          : null,
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: KunSpacing.unit * 3,
        vertical: KunSpacing.unit * 2,
      ),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: KunText.sm)),
          KunKbd(keys: keys, variant: KunKbdVariant.plain),
        ],
      ),
    ),
  );
}

Widget kbdSearch(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunSpacing.unit * 4,
      children: <Widget>[
        _caption(context, 'A search trigger that shows its shortcut.'),
        SizedBox(
          width: KunSpacing.unit * 64,
          child: KunButton(
            variant: KunUIVariant.bordered,
            color: KunUIColor.neutral,
            fullWidth: true,
            onPressed: () {},
            child: const Row(
              children: <Widget>[
                Icon(KunIcons.search, size: KunSpacing.unit * 4),
                SizedBox(width: KunSpacing.unit * 2),
                Expanded(child: Text('Search games, topics, users')),
                KunKbd(keys: 'Mod+K'),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
