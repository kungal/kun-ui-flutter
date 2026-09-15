import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';

/// Fills the viewport with the theme background and centres [child] in a
/// scrollable safe area — no chrome.
class DemoHost extends StatelessWidget {
  /// Creates a chrome-less host around [builder].
  const DemoHost({required this.builder, super.key});

  /// Builds the demo body.
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final KunThemeData theme = KunTheme.of(context);
    return ColoredBox(
      color: theme.colors.background,
      child: SizedBox.expand(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                    minWidth: constraints.maxWidth,
                  ),
                  child: Center(child: builder(context)),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Chrome-less centred text for a path that is not a known demo.
class UnknownDemoPage extends StatelessWidget {
  /// Creates the unknown-path page naming [path].
  const UnknownDemoPage({required this.path, super.key});

  /// The path as it appeared in the URL, including a leading slash.
  final String path;

  @override
  Widget build(BuildContext context) {
    final KunThemeData theme = KunTheme.of(context);
    return ColoredBox(
      color: theme.colors.background,
      child: SizedBox.expand(
        child: SafeArea(
          child: Center(child: Text('Unknown demo: $path')),
        ),
      ),
    );
  }
}
