import 'package:flutter/widgets.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../foundation/design.dart';
import '../foundation/tap_target.dart';
import 'breakpoints.dart';

/// The KunUI theme configuration.
///
/// KunUI deliberately does not hang off Material's `ThemeData` (the modern
/// independent design systems on Flutter — forui, shadcn_ui — do the same):
/// KunUI is its own design language, not a Material skin, and its widgets
/// must work under any app shell. [KunTheme] is the only ancestor they need.
@immutable
class KunThemeData {
  /// Creates a theme with every field given explicitly.
  const KunThemeData({
    required this.colors,
    required this.brightness,
    this.rounded = KunUIRounded.md,
    this.breakpoints = const KunBreakpoints(),
    this.tapTargetSize = KunTapTargetSize.adaptive,
    this.enableFeedback = true,
  });

  /// The light theme — the generated scheme the web ships on `:root`.
  factory KunThemeData.light({
    KunUIRounded rounded = KunUIRounded.md,
    KunBreakpoints breakpoints = const KunBreakpoints(),
    KunTapTargetSize tapTargetSize = KunTapTargetSize.adaptive,
    bool enableFeedback = true,
  }) =>
      KunThemeData(
        colors: KunColors.light,
        brightness: Brightness.light,
        rounded: rounded,
        breakpoints: breakpoints,
        tapTargetSize: tapTargetSize,
        enableFeedback: enableFeedback,
      );

  /// The dark theme — the generated scheme the web ships on `.kun-dark-mode`.
  factory KunThemeData.dark({
    KunUIRounded rounded = KunUIRounded.md,
    KunBreakpoints breakpoints = const KunBreakpoints(),
    KunTapTargetSize tapTargetSize = KunTapTargetSize.adaptive,
    bool enableFeedback = true,
  }) =>
      KunThemeData(
        colors: KunColors.dark,
        brightness: Brightness.dark,
        rounded: rounded,
        breakpoints: breakpoints,
        tapTargetSize: tapTargetSize,
        enableFeedback: enableFeedback,
      );

  /// The generated color scheme ([KunColors.light] or [KunColors.dark]
  /// unless the app supplies a custom one).
  final KunColorScheme colors;

  /// Which mode [colors] was built for.
  final Brightness brightness;

  /// The app-wide default corner rounding, taken by every component whose
  /// `rounded` parameter is left null — one knob squares or rounds every
  /// KunUI surface at once, exactly like the web's `config.rounded`.
  final KunUIRounded rounded;

  /// The responsive breakpoints.
  final KunBreakpoints breakpoints;

  /// How much room a pressable control claims beyond what it draws. The
  /// default, [KunTapTargetSize.adaptive], meets the platform's minimum
  /// touch target on phones and keeps the web's sizes on desktop.
  final KunTapTargetSize tapTargetSize;

  /// Whether KunUI widgets emit the platform's haptic (and, on a long
  /// press, acoustic) feedback. Modeled on Material's per-widget
  /// `enableFeedback`. Defaults to true. When false, none of
  /// [KunPressable.onLongPress], a [KunSwitch] the user toggles,
  /// [KunRefreshIndicator] becoming armed from a pull, or
  /// [KunContextMenuRegion]'s long press fire.
  ///
  /// [EditableText] and [SelectableRegion] already call
  /// [Feedback.forLongPress] and `HapticFeedback.selectionClick`
  /// themselves (`widgets/text_selection.dart:2761`,
  /// `widgets/selectable_region.dart:1006`). This flag cannot reach those.
  final bool enableFeedback;

  /// A copy with the given fields replaced.
  KunThemeData copyWith({
    KunColorScheme? colors,
    Brightness? brightness,
    KunUIRounded? rounded,
    KunBreakpoints? breakpoints,
    KunTapTargetSize? tapTargetSize,
    bool? enableFeedback,
  }) =>
      KunThemeData(
        colors: colors ?? this.colors,
        brightness: brightness ?? this.brightness,
        rounded: rounded ?? this.rounded,
        breakpoints: breakpoints ?? this.breakpoints,
        tapTargetSize: tapTargetSize ?? this.tapTargetSize,
        enableFeedback: enableFeedback ?? this.enableFeedback,
      );

  @override
  bool operator ==(Object other) =>
      other is KunThemeData &&
      identical(other.colors, colors) &&
      other.brightness == brightness &&
      other.rounded == rounded &&
      other.breakpoints == breakpoints &&
      other.tapTargetSize == tapTargetSize &&
      other.enableFeedback == enableFeedback;

  @override
  int get hashCode => Object.hash(
        colors,
        brightness,
        rounded,
        breakpoints,
        tapTargetSize,
        enableFeedback,
      );
}

/// Provides a [KunThemeData] to every KunUI widget below it.
///
/// Wrap the app (or the KunUI subtree) once:
///
/// ```dart
/// KunTheme(
///   data: KunThemeData.light(),
///   child: const App(),
/// )
/// ```
///
/// Besides exposing [KunThemeData], it sets the ambient text color and
/// [IconTheme] to the scheme's foreground — the Flutter analogue of the web
/// setting `color` on the page root and icons inheriting `currentColor`. It
/// also sets the ambient [TextStyle.leadingDistribution] to
/// [TextLeadingDistribution.even], which is how CSS places every line, so
/// text in the subtree that sets a `height` sits in its line box where the
/// browser would put it rather than lower. It paints no background: put
/// `KunTheme.of(context).colors.background` behind your page yourself.
///
/// The theme is an [InheritedTheme], so [InheritedTheme.capture] carries it
/// into a route or overlay opened from below it.
class KunTheme extends StatelessWidget {
  /// Provides [data] to the subtree under [child].
  const KunTheme({required this.data, required this.child, super.key});

  /// The theme configuration.
  final KunThemeData data;

  /// The subtree the theme applies to.
  final Widget child;

  /// The [KunThemeData] of the closest [KunTheme] ancestor.
  ///
  /// Throws a [FlutterError] when there is none: a missing theme is an
  /// integration mistake, and a silent fallback would ship the wrong colors.
  static KunThemeData of(BuildContext context) {
    final data = maybeOf(context);
    if (data == null) {
      throw FlutterError(
        'KunTheme.of() was called with a context that has no KunTheme '
        'ancestor.\nWrap the app (or the KunUI subtree) in '
        'KunTheme(data: KunThemeData.light(), child: ...).',
      );
    }
    return data;
  }

  /// Like [of], but returns null instead of throwing.
  static KunThemeData? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_InheritedKunTheme>()?.data;

  @override
  Widget build(BuildContext context) => _InheritedKunTheme(
        data: data,
        child: DefaultTextStyle.merge(
          style: TextStyle(
            color: data.colors.foreground,
            leadingDistribution: TextLeadingDistribution.even,
          ),
          child: IconTheme.merge(
            data: IconThemeData(color: data.colors.foreground),
            child: child,
          ),
        ),
      );
}

class _InheritedKunTheme extends InheritedTheme {
  const _InheritedKunTheme({required this.data, required super.child});

  final KunThemeData data;

  @override
  Widget wrap(BuildContext context, Widget child) =>
      _InheritedKunTheme(data: data, child: child);

  @override
  bool updateShouldNotify(_InheritedKunTheme oldWidget) =>
      data != oldWidget.data;
}
