import 'package:flutter/widgets.dart';
import 'package:kun_ui/kun_ui.dart';

import 'navigator.dart';
import 'registry.dart';
import 'registry.g.dart';
import 'route.dart';

/// The gallery index: title, the theme, language and corner-radius controls,
/// and a card per component.
class GalleryIndex extends StatelessWidget {
  /// Creates the index for [route]'s theme and language.
  const GalleryIndex({required this.route, super.key});

  /// The current address; the controls and every demo link carry its theme,
  /// language and corner radius forward.
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
                        Wrap(
                          spacing: KunCardPadding.sm.value,
                          runSpacing: KunCardPadding.sm.value,
                          crossAxisAlignment: WrapCrossAlignment.center,
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
                            Text(
                              'rounded',
                              style: KunControlMetrics.of(KunUISize.sm)
                                  .textStyle
                                  .copyWith(
                                    color: theme.colors.neutral.shade600,
                                  ),
                            ),
                            for (final KunUIRounded value
                                in KunUIRounded.values)
                              KunButton(
                                variant: value == route.rounded
                                    ? KunUIVariant.solid
                                    : KunUIVariant.bordered,
                                color: value == route.rounded
                                    ? KunUIColor.primary
                                    : KunUIColor.neutral,
                                size: KunUISize.sm,
                                onPressed: () =>
                                    GalleryNavigator.of(context).go(
                                  route.copyWith(rounded: value),
                                ),
                                child: Text(value.name),
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
                                    rounded: route.rounded,
                                  ),
                                ),
                                child: Text(demo.title),
                              ),
                          ],
                        ),
                      ),
                    if (galleryUnbuiltComponents.isNotEmpty)
                      Text(
                        'Claimed in the contract, not yet in the gallery: ${galleryUnbuiltComponents.join(', ')}',
                        style: KunControlMetrics.of(KunUISize.sm)
                            .textStyle
                            .copyWith(
                              color: theme.colors.neutral.shade600,
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
