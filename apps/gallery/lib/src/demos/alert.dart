import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';

Widget _caption(BuildContext context, String text) {
  final KunColorScheme scheme = KunTheme.of(context).colors;
  return Text(
    text,
    style: KunText.xs.copyWith(color: scheme.neutral.shade500),
  );
}

Widget alertBasic(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: _AlertBasic(),
  );
}

Widget alertTypes(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: _AlertTypes(),
  );
}

Widget alertOptions(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: _AlertOptions(),
  );
}

Widget alertReplace(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: _AlertReplace(),
  );
}

class _AlertBasic extends StatelessWidget {
  const _AlertBasic();

  @override
  Widget build(BuildContext context) {
    return KunButton(
      color: KunUIColor.danger,
      onPressed: () async {
        final bool ok = await showKunAlert(
          context,
          title: 'Delete item?',
          message: 'This action cannot be undone.',
        );
        showKunMessage(
          ok ? 'Confirmed' : 'Cancelled',
          ok ? KunMessageType.success : KunMessageType.info,
        );
      },
      child: const Text('Confirm dialog'),
    );
  }
}

class _AlertTypes extends StatefulWidget {
  const _AlertTypes();

  @override
  State<_AlertTypes> createState() => _AlertTypesState();
}

class _AlertTypesState extends State<_AlertTypes> {
  bool? _last;

  Future<void> _open(KunAlertType type) async {
    final bool ok = await showKunAlert(
      context,
      title: type.name,
      message: 'A ${type.name} confirm.',
      type: type,
    );
    setState(() => _last = ok);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: KunSpacing.unit * 2,
      children: <Widget>[
        Wrap(
          spacing: KunSpacing.unit * 2,
          runSpacing: KunSpacing.unit * 2,
          children: <Widget>[
            KunButton(
              onPressed: () => _open(KunAlertType.info),
              child: const Text('info'),
            ),
            KunButton(
              color: KunUIColor.warning,
              onPressed: () => _open(KunAlertType.warning),
              child: const Text('warning'),
            ),
            KunButton(
              color: KunUIColor.danger,
              onPressed: () => _open(KunAlertType.danger),
              child: const Text('danger'),
            ),
          ],
        ),
        _caption(context, 'last: ${_last ?? '—'}'),
      ],
    );
  }
}

class _AlertOptions extends StatefulWidget {
  const _AlertOptions();

  @override
  State<_AlertOptions> createState() => _AlertOptionsState();
}

class _AlertOptionsState extends State<_AlertOptions> {
  String _last = '—';

  Future<void> _run(String name, Future<bool> Function() open) async {
    final bool ok = await open();
    setState(() => _last = '$name: $ok');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: KunSpacing.unit * 2,
      children: <Widget>[
        Wrap(
          spacing: KunSpacing.unit * 2,
          runSpacing: KunSpacing.unit * 2,
          children: <Widget>[
            KunButton(
              variant: KunUIVariant.bordered,
              onPressed: () => _run(
                'No cancel',
                () => showKunAlert(
                  context,
                  title: 'Heads up',
                  message: 'No way back.',
                  showCancel: false,
                  confirmText: 'Got it',
                ),
              ),
              child: const Text('No cancel'),
            ),
            KunButton(
              variant: KunUIVariant.bordered,
              onPressed: () => _run(
                'Custom labels',
                () => showKunAlert(
                  context,
                  title: 'Delete item?',
                  message: 'This action cannot be undone.',
                  confirmText: 'Delete',
                  cancelText: 'Keep',
                ),
              ),
              child: const Text('Custom labels'),
            ),
            KunButton(
              variant: KunUIVariant.bordered,
              onPressed: () => _run(
                'Colour override',
                () => showKunAlert(
                  context,
                  title: 'Save?',
                  message: 'Keep the draft.',
                  confirmColor: KunUIColor.success,
                ),
              ),
              child: const Text('Colour override'),
            ),
            KunButton(
              variant: KunUIVariant.bordered,
              onPressed: () => _run(
                'No title',
                () => showKunAlert(
                  context,
                  message: 'A message only.',
                ),
              ),
              child: const Text('No title'),
            ),
            KunButton(
              variant: KunUIVariant.bordered,
              onPressed: () => _run(
                'Long title',
                () => showKunAlert(
                  context,
                  title:
                      'A title long enough to reach the close button on the panel',
                  message: 'See the heading.',
                ),
              ),
              child: const Text('Long title'),
            ),
          ],
        ),
        _caption(context, _last),
      ],
    );
  }
}

class _AlertReplace extends StatefulWidget {
  const _AlertReplace();

  @override
  State<_AlertReplace> createState() => _AlertReplaceState();
}

class _AlertReplaceState extends State<_AlertReplace> {
  String _last = '—';

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: KunSpacing.unit * 2,
      children: <Widget>[
        KunButton(
          onPressed: () {
            final Future<bool> first = showKunAlert(
              context,
              title: 'First',
              message: 'This one is replaced.',
            );
            first.then((bool value) {
              if (mounted) {
                setState(() => _last = 'first: $value');
              }
            });
            Future<void>.delayed(const Duration(milliseconds: 1500), () {
              if (!context.mounted) {
                return;
              }
              showKunAlert(
                context,
                title: 'Second',
                message: 'The replacement.',
              );
            });
          },
          child: const Text('Replace after 1.5s'),
        ),
        _caption(context, _last),
      ],
    );
  }
}
