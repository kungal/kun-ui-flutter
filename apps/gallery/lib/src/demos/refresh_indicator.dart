import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';

Widget refreshIndicatorList(BuildContext context) {
  return const SizedBox(
    width: 360,
    height: 640,
    child: _PullToRefreshDemo(),
  );
}

class _PullToRefreshDemo extends StatefulWidget {
  const _PullToRefreshDemo();

  @override
  State<_PullToRefreshDemo> createState() => _PullToRefreshDemoState();
}

class _PullToRefreshDemoState extends State<_PullToRefreshDemo> {
  int _count = 0;

  Future<void> _onRefresh() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        _count += 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(KunSpacing.unit * 4),
          child: Text(
            'Refreshed $_count times',
            style: KunText.sm.copyWith(color: scheme.neutral.shade600),
          ),
        ),
        Expanded(
          child: KunRefreshIndicator(
            onRefresh: _onRefresh,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: 20,
              itemBuilder: (BuildContext context, int index) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(
                    KunSpacing.unit * 4,
                    KunSpacing.unit * 2,
                    KunSpacing.unit * 4,
                    KunSpacing.unit * 2,
                  ),
                  child: KunCard(
                    padding: KunCardPadding.md,
                    child: Text('Item ${index + 1}'),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
