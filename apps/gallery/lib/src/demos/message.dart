import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';

Widget _caption(BuildContext context, String text) {
  final KunColorScheme scheme = KunTheme.of(context).colors;
  return Text(
    text,
    style: KunText.xs.copyWith(color: scheme.neutral.shade500),
  );
}

Widget messageTypes(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: Wrap(
      spacing: KunSpacing.unit * 2,
      runSpacing: KunSpacing.unit * 2,
      children: <Widget>[
        KunButton(
          color: KunUIColor.success,
          onPressed: _saved,
          child: Text('success'),
        ),
        KunButton(
          color: KunUIColor.danger,
          onPressed: _failed,
          child: Text('error'),
        ),
        KunButton(
          color: KunUIColor.warning,
          onPressed: _careful,
          child: Text('warn'),
        ),
        KunButton(
          color: KunUIColor.info,
          onPressed: _headsUp,
          child: Text('info'),
        ),
      ],
    ),
  );
}

void _saved() => showKunMessage('Saved!', KunMessageType.success);
void _failed() => showKunMessage('Something failed', KunMessageType.error);
void _careful() => showKunMessage('Careful…', KunMessageType.warn);
void _headsUp() => showKunMessage('Heads up', KunMessageType.info);

Widget messagePositions(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: Wrap(
      spacing: KunSpacing.unit * 2,
      runSpacing: KunSpacing.unit * 2,
      children: <Widget>[
        for (final KunMessagePosition position in KunMessagePosition.values)
          KunButton(
            variant: KunUIVariant.bordered,
            onPressed: () => showKunMessage(
              position.name,
              KunMessageType.info,
              position: position,
            ),
            child: Text(position.name),
          ),
      ],
    ),
  );
}

Widget messagePersistent(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: _MessagePersistent(),
  );
}

Widget messageDedup(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      spacing: KunSpacing.unit * 2,
      children: <Widget>[
        const KunButton(
          color: KunUIColor.success,
          onPressed: _saved,
          child: Text('Saved!'),
        ),
        _caption(context, 'Press it repeatedly'),
      ],
    ),
  );
}

Widget messageBurst(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      spacing: KunSpacing.unit * 2,
      children: <Widget>[
        const KunButton(
          onPressed: _burst,
          child: Text('Show seven'),
        ),
        _caption(context, 'Five remain'),
      ],
    ),
  );
}

void _burst() {
  for (int i = 1; i <= 7; i++) {
    showKunMessage(
      'Toast $i',
      KunMessageType.info,
      position: KunMessagePosition.topRight,
    );
  }
}

Widget messageOverModal(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: _MessageOverModal(),
  );
}

class _MessagePersistent extends StatefulWidget {
  const _MessagePersistent();

  @override
  State<_MessagePersistent> createState() => _MessagePersistentState();
}

class _MessagePersistentState extends State<_MessagePersistent> {
  String? _id;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: KunSpacing.unit * 2,
      runSpacing: KunSpacing.unit * 2,
      children: <Widget>[
        KunButton(
          color: KunUIColor.warning,
          onPressed: () {
            _id = showKunMessage(
              'Sticky',
              KunMessageType.warn,
              duration: Duration.zero,
            );
          },
          child: const Text('Show sticky'),
        ),
        KunButton(
          variant: KunUIVariant.bordered,
          onPressed: () {
            final String? id = _id;
            if (id != null) {
              dismissKunMessage(id);
            }
          },
          child: const Text('Dismiss sticky'),
        ),
      ],
    );
  }
}

class _MessageOverModal extends StatefulWidget {
  const _MessageOverModal();

  @override
  State<_MessageOverModal> createState() => _MessageOverModalState();
}

class _MessageOverModalState extends State<_MessageOverModal> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        KunButton(
          onPressed: () => setState(() => _open = true),
          child: const Text('Open modal'),
        ),
        KunModal(
          value: _open,
          onChanged: (bool value) => setState(() => _open = value),
          title: 'Modal',
          child: KunButton(
            onPressed: () => showKunMessage(
              'Over a modal',
              KunMessageType.info,
            ),
            child: const Text('Show toast'),
          ),
        ),
      ],
    );
  }
}
