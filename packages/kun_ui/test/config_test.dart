import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';

Future<BuildContext> pumpContext(WidgetTester tester,
    {KunUIConfig? config}) async {
  late BuildContext captured;
  final Widget probe = Builder(
    builder: (context) {
      captured = context;
      return const SizedBox.shrink();
    },
  );
  await tester.pumpWidget(
    config == null ? probe : KunUIConfigScope(config: config, child: probe),
  );
  return captured;
}

void main() {
  testWidgets('without a scope the web defaults apply', (tester) async {
    final context = await pumpContext(tester);
    final config = KunUIConfigScope.of(context);
    expect(config, same(KunUIConfig.fallback));
    expect(config.navigate, isNull);
    expect(config.userLinkTemplate, '/user/{id}/info');
    expect(config.avatarFallbackPool, isEmpty);
    expect(config.imageProvider('https://a.test/x.webp'), isA<NetworkImage>());
  });

  testWidgets('the closest scope wins', (tester) async {
    const outer = KunUIConfig(userLinkTemplate: '/outer/{id}');
    const inner = KunUIConfig(userLinkTemplate: '/inner/{id}');
    late KunUIConfig resolved;
    await tester.pumpWidget(
      KunUIConfigScope(
        config: outer,
        child: KunUIConfigScope(
          config: inner,
          child: Builder(
            builder: (context) {
              resolved = KunUIConfigScope.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    expect(resolved, same(inner));
  });

  test('userLinkFor fills the first {id}, as the web replace does', () {
    expect(KunUIConfig.fallback.userLinkFor(42), '/user/42/info');
    expect(
      const KunUIConfig(userLinkTemplate: '/u/{id}/{id}').userLinkFor(7),
      '/u/7/{id}',
    );
  });

  test('the fallback pick matches the web hash', () {
    // Indices computed by ui-core's pickAvatarFallback over a 7-entry pool.
    const pool = ['p0', 'p1', 'p2', 'p3', 'p4', 'p5', 'p6'];
    const expected = <String, String>{
      '': 'p0',
      'a': 'p6',
      'Alice': 'p4',
      'Bob': 'p3',
      'Carol': 'p0',
      '鲲': 'p4',
      'kun鲲😀': 'p0',
      'the quick brown fox jumps over the lazy dog 0123456789': 'p0',
    };
    for (final MapEntry<String, String> entry in expected.entries) {
      expect(kunPickAvatarFallback(entry.key, pool), entry.value,
          reason: entry.key);
    }
    // Over 5 entries the first seed catches a signed hash (its web hash,
    // 3214970577, is above 2^31) and the second an unmasked one.
    const five = ['q0', 'q1', 'q2', 'q3', 'q4'];
    expect(kunPickAvatarFallback('kun鲲😀', five), 'q2');
    expect(
      kunPickAvatarFallback(
          'the quick brown fox jumps over the lazy dog 0123456789', five),
      'q2',
    );
    expect(kunPickAvatarFallback('Alice', const []), isNull);
  });

  testWidgets('navigateTo hands the href to navigate', (tester) async {
    final calls = <String>[];
    late BuildContext seen;
    final config = KunUIConfig(
      navigate: (context, href) {
        seen = context;
        calls.add(href);
      },
    );
    final context = await pumpContext(tester, config: config);
    await KunUIConfigScope.of(context).navigateTo(context, '/topic/1');
    expect(calls, ['/topic/1']);
    expect(seen, same(context));
  });

  testWidgets('navigateTo without navigate reports once and does nothing',
      (tester) async {
    final printed = <String>[];
    final context = await pumpContext(tester);
    final DebugPrintCallback original = debugPrint;
    debugPrint = (message, {wrapWidth}) => printed.add(message ?? '');
    try {
      await KunUIConfig.fallback.navigateTo(context, '/a');
      await KunUIConfig.fallback.navigateTo(context, '/b');
    } finally {
      debugPrint = original;
    }
    expect(printed, hasLength(1));
    expect(printed.single, contains('"/a"'));
    expect(printed.single, contains('KunUIConfig.navigate'));
  });

  testWidgets('an equal config does not notify dependents', (tester) async {
    var builds = 0;
    Widget tree(KunUIConfig config) => KunUIConfigScope(
          config: config,
          child: const _Dependent(),
        );
    _Dependent.onBuild = () => builds++;
    addTearDown(() => _Dependent.onBuild = null);

    await tester.pumpWidget(tree(KunUIConfig(avatarFallbackPool: ['x'])));
    expect(builds, 1);
    await tester.pumpWidget(tree(KunUIConfig(avatarFallbackPool: ['x'])));
    expect(builds, 1);
    await tester.pumpWidget(tree(KunUIConfig(avatarFallbackPool: ['y'])));
    expect(builds, 2);
  });

  test('copyWith replaces only what it is given', () {
    const base = KunUIConfig(userLinkTemplate: '/u/{id}');
    final copy = base.copyWith(avatarFallbackPool: const ['z']);
    expect(copy.userLinkTemplate, '/u/{id}');
    expect(copy.avatarFallbackPool, ['z']);
    expect(copy, isNot(base));
    expect(base.copyWith(), base);
  });
}

class _Dependent extends StatelessWidget {
  const _Dependent();

  static VoidCallback? onBuild;

  @override
  Widget build(BuildContext context) {
    KunUIConfigScope.of(context);
    onBuild?.call();
    return const SizedBox.shrink();
  }
}
