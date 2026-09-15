import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';

import 'navigator.dart';
import 'registry.dart';
import 'route.dart';

/// The gallery index: title, theme and language toggles, and a card per
/// component.
class GalleryIndex extends StatelessWidget {
  /// Creates the index for [route]'s theme and language.
  const GalleryIndex({required this.route, super.key});

  /// The current address; toggles and demo links copy its theme and language.
  final GalleryRoute route;

  @override
  Widget build(BuildContext context) {
    final KunThemeData theme = KunTheme.of(context);
    final bool isDark = route.theme == GalleryTheme.dark;
    final bool isEn = route.lang == KunMessages.en;
    final String themeLabel =
        isDark ? (isEn ? 'Light' : '浅色') : (isEn ? 'Dark' : '深色');
    final String langLabel = isEn ? KunMessages.zhCN.name : KunMessages.en.name;
    final TextStyle titleStyle =
        KunControlMetrics.of(KunUISize.xl).textStyle.copyWith(
              fontWeight: FontWeight.w600,
            );
    final TextStyle headerStyle =
        KunControlMetrics.of(KunUISize.lg).textStyle.copyWith(
              fontWeight: FontWeight.w600,
            );

    return ColoredBox(
      color: theme.colors.background,
      child: SizedBox.expand(
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              padding: EdgeInsets.all(KunCardPadding.lg.value),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: theme.breakpoints.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: KunCardPadding.md.value,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: KunCardPadding.sm.value,
                      runSpacing: KunCardPadding.sm.value,
                      children: [
                        Text('KunUI for Flutter', style: titleStyle),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          spacing: KunCardPadding.sm.value,
                          children: [
                            KunButton(
                              variant: KunUIVariant.bordered,
                              color: KunUIColor.neutral,
                              size: KunUISize.sm,
                              onPressed: () => GalleryNavigator.of(context).go(
                                route.copyWith(
                                  theme: isDark
                                      ? GalleryTheme.light
                                      : GalleryTheme.dark,
                                ),
                              ),
                              child: Text(themeLabel),
                            ),
                            KunButton(
                              variant: KunUIVariant.bordered,
                              color: KunUIColor.primary,
                              size: KunUISize.sm,
                              onPressed: () => GalleryNavigator.of(context).go(
                                route.copyWith(
                                  lang:
                                      isEn ? KunMessages.zhCN : KunMessages.en,
                                ),
                              ),
                              child: Text(langLabel),
                            ),
                          ],
                        ),
                      ],
                    ),
                    for (final GalleryComponent component in galleryComponents)
                      KunCard(
                        header: Row(
                          children: [
                            Expanded(
                              child: Text(component.name, style: headerStyle),
                            ),
                            KunChip(
                              child: Text('${component.demos.length}'),
                            ),
                          ],
                        ),
                        child: Wrap(
                          spacing: KunCardPadding.sm.value,
                          runSpacing: KunCardPadding.sm.value,
                          children: [
                            for (final GalleryDemo demo in component.demos)
                              KunButton(
                                variant: KunUIVariant.light,
                                size: KunUISize.sm,
                                onPressed: () =>
                                    GalleryNavigator.of(context).go(
                                  GalleryRoute(
                                    component: component.slug,
                                    demo: demo.slug,
                                    theme: route.theme,
                                    lang: route.lang,
                                  ),
                                ),
                                child: Text(demo.title),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
