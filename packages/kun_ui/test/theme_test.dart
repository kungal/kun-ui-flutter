import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';

void main() {
  testWidgets('KunTheme.of throws without an ancestor', (tester) async {
    late BuildContext captured;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          captured = context;
          return const SizedBox.shrink();
        },
      ),
    );
    expect(KunTheme.maybeOf(captured), isNull);
    expect(() => KunTheme.of(captured), throwsFlutterError);
  });

  testWidgets('KunTheme.of returns the provided data', (tester) async {
    final data = KunThemeData.dark(rounded: KunUIRounded.full);
    late KunThemeData resolved;
    await tester.pumpWidget(
      KunTheme(
        data: data,
        child: Builder(
          builder: (context) {
            resolved = KunTheme.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(resolved, data);
    expect(resolved.colors, same(KunColors.dark));
    expect(resolved.rounded, KunUIRounded.full);
  });

  testWidgets('KunTheme sets the ambient icon and text color', (tester) async {
    late Color? iconColor;
    await tester.pumpWidget(
      KunTheme(
        data: KunThemeData.light(),
        child: Builder(
          builder: (context) {
            iconColor = IconTheme.of(context).color;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(iconColor, KunColors.light.foreground);
  });

  testWidgets('KunTheme sets even leading distribution', (tester) async {
    await tester.pumpWidget(
      KunTheme(
        data: KunThemeData.light(),
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: Text('hello'),
        ),
      ),
    );
    expect(
      (tester.widget<RichText>(find.byType(RichText)).text as TextSpan)
          .style!
          .leadingDistribution,
      TextLeadingDistribution.even,
    );

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Text('hello'),
      ),
    );
    expect(
      (tester.widget<RichText>(find.byType(RichText)).text as TextSpan)
          .style!
          .leadingDistribution,
      isNot(TextLeadingDistribution.even),
    );
  });

  test('breakpoints resolve mobile-first at the web widths', () {
    const breakpoints = KunBreakpoints();
    expect(breakpoints.resolve(320), KunBreakpoint.base);
    expect(breakpoints.resolve(640), KunBreakpoint.sm);
    expect(breakpoints.resolve(767), KunBreakpoint.sm);
    expect(breakpoints.resolve(768), KunBreakpoint.md);
    expect(breakpoints.resolve(1024), KunBreakpoint.lg);
    expect(breakpoints.resolve(1280), KunBreakpoint.xl);
    expect(breakpoints.resolve(1536), KunBreakpoint.xxl);
  });

  for (final bool capture in [true, false]) {
    testWidgets(
      'a route ${capture ? 'sees' : 'misses'} the scopes where it was '
      'opened ${capture ? 'with' : 'without'} InheritedTheme.capture',
      (tester) async {
        late BuildContext opener;
        KunThemeData? theme;
        KunMessages? messages;
        KunUIConfig? config;
        const inner = KunUIConfig(userLinkTemplate: '/u/{id}');

        await tester.pumpWidget(
          KunTheme(
            data: KunThemeData.light(),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Navigator(
                onGenerateRoute: (settings) => PageRouteBuilder<void>(
                  pageBuilder: (context, _, __) => KunTheme(
                    data: KunThemeData.dark(),
                    child: KunMessagesScope(
                      messages: KunMessages.en,
                      child: KunUIConfigScope(
                        config: inner,
                        child: Builder(
                          builder: (context) {
                            opener = context;
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        final NavigatorState navigator = Navigator.of(opener);
        final CapturedThemes themes = InheritedTheme.capture(
          from: opener,
          to: navigator.context,
        );
        Widget probe(BuildContext context) {
          theme = KunTheme.of(context);
          messages = KunMessagesScope.of(context);
          config = KunUIConfigScope.of(context);
          return const SizedBox.shrink();
        }

        navigator.push(
          PageRouteBuilder<void>(
            pageBuilder: (context, _, __) => capture
                ? themes.wrap(Builder(builder: probe))
                : Builder(builder: probe),
          ),
        );
        await tester.pumpAndSettle();

        if (capture) {
          expect(theme!.brightness, Brightness.dark);
          expect(messages, same(KunMessages.en));
          expect(config, same(inner));
        } else {
          expect(theme!.brightness, Brightness.light);
          expect(messages, same(KunMessages.zhCN));
          expect(config, same(KunUIConfig.fallback));
        }
      },
    );
  }
}
