import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';

Widget pageTransitions(BuildContext context) {
  final KunColorScheme scheme = KunTheme.of(context).colors;
  return SizedBox(
    width: 360,
    height: 640,
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: scheme.border),
        borderRadius: BorderRadius.circular(KunRadius.lg),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(KunRadius.lg),
        child: const _TransitionsPhone(),
      ),
    ),
  );
}

class _TransitionsPhone extends StatefulWidget {
  const _TransitionsPhone();

  @override
  State<_TransitionsPhone> createState() => _TransitionsPhoneState();
}

class _TransitionsPhoneState extends State<_TransitionsPhone> {
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return NavigatorPopHandler(
      onPopWithResult: (Object? result) {
        _navKey.currentState?.maybePop(result);
      },
      child: Navigator(
        key: _navKey,
        onGenerateRoute: (RouteSettings settings) {
          return KunPageRoute<void>(
            settings: settings,
            transition: KunPageTransition.none,
            builder: (BuildContext context) => const _TransitionsHome(),
          );
        },
      ),
    );
  }
}

class _TransitionsHome extends StatelessWidget {
  const _TransitionsHome();

  void _push(BuildContext context, KunPageTransition transition, String label) {
    Navigator.of(context).push(
      KunPageRoute<void>(
        transition: transition,
        builder: (BuildContext context) => _TransitionPage(label: label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return KunScaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: KunSpacing.unit * 3,
          children: <Widget>[
            KunButton(
              onPressed: () => _push(
                context,
                KunPageTransition.platform,
                '平台默认',
              ),
              child: const Text('平台默认'),
            ),
            KunButton(
              onPressed: () => _push(
                context,
                KunPageTransition.fade,
                '淡入',
              ),
              child: const Text('淡入'),
            ),
            KunButton(
              onPressed: () => _push(
                context,
                KunPageTransition.slide,
                '滑入',
              ),
              child: const Text('滑入'),
            ),
            KunButton(
              onPressed: () => _push(
                context,
                KunPageTransition.none,
                '无动画',
              ),
              child: const Text('无动画'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransitionPage extends StatelessWidget {
  const _TransitionPage({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return KunScaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: KunSpacing.unit * 4,
          children: <Widget>[
            Text(label, style: KunText.xl),
            KunButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('返回'),
            ),
          ],
        ),
      ),
    );
  }
}
