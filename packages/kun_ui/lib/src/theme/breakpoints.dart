import 'package:flutter/widgets.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

/// The responsive breakpoints, as widths in logical pixels.
///
/// The defaults are [KunBreakpointWidths] — the exact widths the web layer's
/// `sm:`/`md:`/… classes switch at — so a layout that changes at `md` on the
/// web changes at the same width here.
@immutable
class KunBreakpoints {
  /// Creates the breakpoint set; defaults are the web's.
  const KunBreakpoints({
    this.sm = KunBreakpointWidths.sm,
    this.md = KunBreakpointWidths.md,
    this.lg = KunBreakpointWidths.lg,
    this.xl = KunBreakpointWidths.xl,
    this.xxl = KunBreakpointWidths.xl2,
  });

  /// Tailwind `sm`.
  final double sm;

  /// Tailwind `md`.
  final double md;

  /// Tailwind `lg`.
  final double lg;

  /// Tailwind `xl`.
  final double xl;

  /// Tailwind `2xl` (`xxl` — a Dart identifier cannot start with a digit).
  final double xxl;

  /// The widest breakpoint [width] clears, or [KunBreakpoint.base] below
  /// [sm] — mirroring how the web's mobile-first classes cascade.
  KunBreakpoint resolve(double width) {
    if (width >= xxl) return KunBreakpoint.xxl;
    if (width >= xl) return KunBreakpoint.xl;
    if (width >= lg) return KunBreakpoint.lg;
    if (width >= md) return KunBreakpoint.md;
    if (width >= sm) return KunBreakpoint.sm;
    return KunBreakpoint.base;
  }

  @override
  bool operator ==(Object other) =>
      other is KunBreakpoints &&
      other.sm == sm &&
      other.md == md &&
      other.lg == lg &&
      other.xl == xl &&
      other.xxl == xxl;

  @override
  int get hashCode => Object.hash(sm, md, lg, xl, xxl);
}

/// The named breakpoint tiers, mobile-first like the web's.
enum KunBreakpoint {
  /// Below `sm` — the unprefixed web styles.
  base,

  /// ≥ 640 by default.
  sm,

  /// ≥ 768 by default.
  md,

  /// ≥ 1024 by default.
  lg,

  /// ≥ 1280 by default.
  xl,

  /// ≥ 1536 by default (web `2xl`).
  xxl,
}
