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

Widget _content(BuildContext context) {
  final KunColorScheme scheme = KunTheme.of(context).colors;
  return KunCard(
    child: Padding(
      padding: const EdgeInsets.all(KunSpacing.unit * 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: KunSpacing.unit * 2,
        children: <Widget>[
          Text(
            'A patch everyone is waiting for',
            style: KunText.base.copyWith(fontWeight: KunFontWeights.semibold),
          ),
          Text(
            'The content stays in place under the veil, dimmed, so the page '
            'does not jump when the request lands.',
            style: KunText.sm.copyWith(color: scheme.neutral.shade600),
          ),
        ],
      ),
    ),
  );
}

Widget loadingBasic(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunSpacing.unit * 4,
      children: <Widget>[
        _caption(
          context,
          'On its own: the bundled mascot and the locale line, with no '
          'network request.',
        ),
        const KunLoading(),
      ],
    ),
  );
}

Widget loadingSpinner(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunSpacing.unit * 5,
      children: <Widget>[
        _caption(
          context,
          'The compact form, for a loading state beside a button or in a '
          'table cell.',
        ),
        for (final KunUISize size in KunUISize.values)
          KunLoading(spinner: true, size: size, description: size.name),
      ],
    ),
  );
}

Widget loadingDescription(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(KunSpacing.unit * 6),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunSpacing.unit * 5,
      children: <Widget>[
        _caption(context, 'Your own line replaces the locale default.'),
        const KunLoading(spinner: true, description: 'Fetching patches…'),
        const KunLoading(description: 'Almost there'),
      ],
    ),
  );
}

Widget loadingVeil(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(KunSpacing.unit * 6),
    child: _LoadingVeil(),
  );
}

class _LoadingVeil extends StatefulWidget {
  const _LoadingVeil();

  @override
  State<_LoadingVeil> createState() => _LoadingVeilState();
}

class _LoadingVeilState extends State<_LoadingVeil> {
  bool _loading = true;
  bool _spinner = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: KunSpacing.unit * 4,
      children: <Widget>[
        _caption(
          context,
          'With content, it is a veil over it rather than a replacement.',
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: KunSpacing.unit * 3,
          children: <Widget>[
            KunButton(
              onPressed: () => setState(() => _loading = !_loading),
              variant: KunUIVariant.bordered,
              child: Text(_loading ? 'Finish' : 'Load again'),
            ),
            KunSwitch(
              value: _spinner,
              onChanged: (bool value) => setState(() => _spinner = value),
              label: 'Compact',
            ),
          ],
        ),
        KunLoading(
          loading: _loading,
          spinner: _spinner,
          child: _content(context),
        ),
      ],
    );
  }
}
