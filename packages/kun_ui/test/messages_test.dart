import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kun_ui/kun_ui.dart';

void main() {
  testWidgets('with no scope the catalog is the built-in zh-CN default',
      (tester) async {
    late KunMessages resolved;

    await tester.pumpWidget(
      Builder(
        builder: (context) {
          resolved = KunMessagesScope.of(context);
          return const SizedBox.shrink();
        },
      ),
    );

    expect(resolved.code, KunMessages.zhCN.code);
  });

  testWidgets('the nearest scope wins', (tester) async {
    late KunMessages outer;
    late KunMessages inner;

    await tester.pumpWidget(
      KunMessagesScope(
        messages: KunMessages.en,
        child: Builder(
          builder: (context) {
            outer = KunMessagesScope.of(context);
            return KunMessagesScope(
              messages: KunMessages.zhCN,
              child: Builder(
                builder: (context) {
                  inner = KunMessagesScope.of(context);
                  return const SizedBox.shrink();
                },
              ),
            );
          },
        ),
      ),
    );

    expect(outer.code, KunMessages.en.code);
    expect(inner.code, KunMessages.zhCN.code);
  });
}
