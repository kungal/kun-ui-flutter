import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:kun_ui_icons/kun_ui_icons.dart';
import 'package:kun_ui_messages/kun_ui_messages.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../chat/entities.dart';
import '../chat/support.dart';
import '../chat/types.dart';
import '../config/config.dart';
import '../foundation/motion.dart';
import '../locale/messages.dart';
import '../theme/theme.dart';
import 'chat_shared.dart';

/// Web `useSpoilerContent.ts:30` `FPS`.
const int _kFps = 30;

/// Web `FRAME_MS`.
const double _kFrameMs = 1000 / _kFps;

/// Web `DENSITY`.
const double _kDensity = 0.08;

/// Web `MAX_PARTICLES`.
const int _kMaxParticles = 2500;

/// Web `FADE` seconds.
const double _kFade = 0.6;

/// Web `V_MIN`.
const double _kVMin = 2;

/// Web `V_MAX`.
const double _kVMax = 12;

/// IntersectionObserver `rootMargin` `120px`.
const double _kViewMargin = 120;

/// Web `ChatText.vue:83` copied-state timeout.
const Duration _kCopiedDuration = Duration(milliseconds: 2000);

/// Web `ChatText.vue:268` hidden spoiler tint.
const Color _kSpoilerTint = Color.fromRGBO(150, 150, 150, 0.18);

/// Web `ChatText.vue:274` hidden spoiler hover tint.
const Color _kSpoilerTintHover = Color.fromRGBO(150, 150, 150, 0.26);

/// Web `useSpoilerContent.ts:169`: the canvas's own grey, drawn over the
/// word boxes behind the particles at [_kTintAlpha].
const Color _kCanvasTint = Color.fromRGBO(150, 150, 150, 1);

/// Web `TINT_ALPHA`.
const double _kTintAlpha = 0.34;

/// Web `text-[0.9em]` on inline code.
const double _kCodeEm = 0.9;

/// Web `text-[0.85em]` on a pre body.
const double _kPreEm = 0.85;

/// Web `leading-5` on a pre body.
const double _kPreLeading = 20;

/// Web `border-l-[3px]` on a blockquote.
const double _kQuoteBorder = 3;

double _easeOutCubic(double t) {
  final double u = t - 1;
  return u * u * u + 1;
}

double _clamp01(double x) => x < 0 ? 0 : (x > 1 ? 1 : x);

double _trapezoid(double life, double a, double b, double t) {
  final double s = math.max(a, life - b);
  if (t < a) {
    return math.max(0, t / a);
  }
  if (t > s) {
    return math.max(0, 1 - (t - s) / (life - s));
  }
  return 1;
}

double _fadeFactor(
  double worldT,
  double? tStop,
  int idx,
  int n,
  double duration,
) {
  if (duration <= 0) {
    return 1;
  }
  final bool out = tStop != null && tStop <= worldT;
  final double startT = out ? tStop : 0;
  final double t = startT + ((2 / 3) * duration * idx) / n;
  final double fadeFor = (1 / 3) * duration;
  final double progress =
      out ? (worldT - t) / fadeFor : (fadeFor + t - worldT) / fadeFor;
  return _easeOutCubic(1 - _clamp01(progress));
}

class _SpoilerRect {
  const _SpoilerRect({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });
  final double x;
  final double y;
  final double w;
  final double h;

  Rect toRect() => Rect.fromLTWH(x, y, w, h);

  @override
  bool operator ==(Object other) =>
      other is _SpoilerRect &&
      other.x == x &&
      other.y == y &&
      other.w == w &&
      other.h == h;

  @override
  int get hashCode => Object.hash(x, y, w, h);
}

class _Particle {
  const _Particle({
    required this.rect,
    required this.x0,
    required this.y0,
    required this.vx,
    required this.vy,
    required this.life,
    required this.cycle,
    required this.phase,
    required this.size0,
    required this.light,
    required this.square,
  });
  final _SpoilerRect rect;
  final double x0;
  final double y0;
  final double vx;
  final double vy;
  final double life;
  final double cycle;
  final double phase;
  final double size0;
  final double light;
  final bool square;
}

class _SpoilerRange {
  const _SpoilerRange(this.start, this.end);
  final int start;
  final int end;
}

class _SpoilerPaintData {
  List<_SpoilerRect> rects = const <_SpoilerRect>[];
  List<_SpoilerRect> textRects = const <_SpoilerRect>[];
  List<_Particle> particles = const <_Particle>[];
  double clock = 0;
  double? tStop;

  void clear() {
    rects = const <_SpoilerRect>[];
    textRects = const <_SpoilerRect>[];
    particles = const <_Particle>[];
  }

  void reset() {
    clear();
    clock = 0;
    tStop = null;
  }
}

class _CodeChipPaintData {
  List<_SpoilerRect> rects = const <_SpoilerRect>[];
  Color? color;
}

List<Rect> _toRects(List<_SpoilerRect> rects) => <Rect>[
      for (final _SpoilerRect r in rects) r.toRect(),
    ];

List<_Particle> _seedParticles(List<_SpoilerRect> rects, math.Random random) {
  if (rects.isEmpty) {
    return const <_Particle>[];
  }
  double total = 0;
  final List<double> cum = <double>[];
  for (final _SpoilerRect r in rects) {
    total += r.w * r.h;
    cum.add(total);
  }
  final int count = math.min(
    _kMaxParticles,
    math.max(6, (total * _kDensity).round()),
  );
  return <_Particle>[
    for (int i = 0; i < count; i++) _oneParticle(rects, cum, total, random),
  ];
}

_Particle _oneParticle(
  List<_SpoilerRect> rects,
  List<double> cum,
  double total,
  math.Random random,
) {
  final double pick = random.nextDouble() * total;
  int lo = 0;
  int hi = cum.length - 1;
  while (lo < hi) {
    final int mid = (lo + hi) >> 1;
    if (cum[mid] < pick) {
      lo = mid + 1;
    } else {
      hi = mid;
    }
  }
  final _SpoilerRect rect = rects[lo];
  final double angle = random.nextDouble() * math.pi * 2;
  final double speed = _kVMin + random.nextDouble() * (_kVMax - _kVMin);
  final double life = 0.3 + random.nextDouble() * 1.2;
  final double cycle = life + random.nextDouble();
  final int ldir = random.nextDouble() < 0.5 ? -1 : 1;
  return _Particle(
    rect: rect,
    x0: random.nextDouble() * rect.w,
    y0: random.nextDouble() * rect.h,
    vx: math.cos(angle) * speed,
    vy: math.sin(angle) * speed,
    life: life,
    cycle: cycle,
    phase: random.nextDouble() * cycle,
    size0: 1 + random.nextDouble() * 0.6,
    light: math.max(
      8,
      math.min(92, 50 + ldir * (16 + random.nextDouble() * 30)),
    ),
    square: random.nextDouble() < 0.5,
  );
}

bool _treeHasSpoiler(List<KunChatTextNode> nodes) {
  for (final KunChatTextNode node in nodes) {
    if (node is KunChatEntityNode) {
      if (node.entity.type == KunChatEntityType.spoiler) {
        return true;
      }
      if (_treeHasSpoiler(node.children)) {
        return true;
      }
    }
  }
  return false;
}

int _spoilerMaskSize(String text, KunChatEntity entity) {
  final String slice = text.substring(
    entity.offset,
    entity.offset + entity.length,
  );
  return slice.runes.length.clamp(3, 12);
}

String _hiddenSpoilerLabel(List<KunChatTextNode> nodes, String reveal) {
  final StringBuffer buffer = StringBuffer();
  void write(List<KunChatTextNode> nodes) {
    for (final KunChatTextNode node in nodes) {
      switch (node) {
        case KunChatTextLeaf(:final text):
          buffer.write(text);
        case KunChatEntityNode(:final entity, :final children):
          if (entity.type == KunChatEntityType.spoiler) {
            buffer.write(reveal);
          } else {
            write(children);
          }
      }
    }
  }

  write(nodes);
  return buffer.toString();
}

/// Message text plus entities, rendered from [buildKunChatEntityTree].
class KunChatText extends StatefulWidget {
  /// Creates chat text.
  const KunChatText({
    super.key,
    required this.text,
    this.entities,
    this.preview = false,
    this.trailing,
    this.onLink,
    this.onMention,
  });

  /// Message text.
  final String text;

  /// Formatting ranges over [text], in UTF-16 code units.
  final List<KunChatEntity>? entities;

  /// One-line summary: blocks flatten inline, links are plain, spoilers are
  /// masked, nothing is tappable.
  final bool preview;

  /// An inline widget appended after the last character of the last inline
  /// paragraph, as a baseline-aligned [WidgetSpan].
  ///
  /// Not part of the web contract. [KunChatBubble] uses it for the invisible
  /// twin that reserves the meta's seat on the last line. Ignored when
  /// [preview] is true. If the message ends with a block (`pre` or
  /// `blockquote`), the span is a new paragraph after that block. It sits
  /// after every character, so paragraph offsets used by the spoiler and
  /// code-chip measurements stay the same.
  final Widget? trailing;

  /// A link was tapped. The default is [KunUIConfig.navigateTo] unless the
  /// listener calls [KunChatLinkEvent.preventDefault].
  final KunChatLinkCallback? onLink;

  /// A tap on a user: a mention, or a sender name. The default is
  /// navigating to [KunUIConfig.userLinkForId] unless prevented.
  final KunChatUserCallback? onMention;

  @override
  State<KunChatText> createState() => _KunChatTextState();

  /// Particle cover boxes after layout, in each inline run's coordinates.
  @visibleForTesting
  static List<Rect> debugSpoilerParticleBoxes(BuildContext context) {
    return _inlineStates(context)
        .expand((_ChatInlineState s) => s._particleRects)
        .toList();
  }

  /// Text boxes of every hidden spoiler run, from `getBoxesForSelection`.
  @visibleForTesting
  static List<Rect> debugSpoilerTextBoxes(BuildContext context) {
    return _inlineStates(context)
        .expand((_ChatInlineState s) => s._spoilerTextRects)
        .toList();
  }

  /// Boxes handed to the inline-code chip painter.
  @visibleForTesting
  static List<Rect> debugCodeChipBoxes(BuildContext context) {
    return _inlineStates(context)
        .expand((_ChatInlineState s) => s._codeChipRects)
        .toList();
  }

  /// Paragraph-local `[start, end)` ranges recorded for inline code chips.
  @visibleForTesting
  static List<(int, int)> debugCodeRanges(BuildContext context) {
    return _inlineStates(context)
        .expand(
          (_ChatInlineState s) =>
              s._codeRanges.map((_SpoilerRange r) => (r.start, r.end)),
        )
        .toList();
  }

  /// Paragraph-local `[start, end)` ranges recorded for hidden spoilers.
  @visibleForTesting
  static List<(int, int)> debugSpoilerRanges(BuildContext context) {
    return _inlineStates(context)
        .expand(
          (_ChatInlineState s) =>
              s._ranges.map((_SpoilerRange r) => (r.start, r.end)),
        )
        .toList();
  }

  /// Seeded particles after measurement: origin and the box they occupy.
  @visibleForTesting
  static List<(Offset, Rect)> debugSpoilerParticles(BuildContext context) {
    return _inlineStates(context)
        .expand((_ChatInlineState s) => s._debugParticles)
        .toList();
  }
}

List<_ChatInlineState> _inlineStates(BuildContext context) {
  final List<_ChatInlineState> out = <_ChatInlineState>[];
  void visit(Element el) {
    if (el is StatefulElement && el.state is _ChatInlineState) {
      out.add(el.state as _ChatInlineState);
    }
    el.visitChildren(visit);
  }

  visit(context as Element);
  return out;
}

class _KunChatTextState extends State<KunChatText> {
  bool _revealed = false;
  int? _copiedAt;
  Timer? _copiedTimer;
  final FocusNode _spoilerFocus = FocusNode(debugLabel: 'KunChatText.spoiler');

  @override
  void didUpdateWidget(KunChatText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.entities != widget.entities) {
      _revealed = false;
      _copiedAt = null;
      _copiedTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _copiedTimer?.cancel();
    _spoilerFocus.dispose();
    super.dispose();
  }

  void _reveal() {
    if (_revealed || widget.preview) {
      return;
    }
    setState(() => _revealed = true);
  }

  void _copyPre(KunChatEntityNode node) {
    final KunChatEntity entity = node.entity;
    Clipboard.setData(
      ClipboardData(
        text: widget.text.substring(
          entity.offset,
          entity.offset + entity.length,
        ),
      ),
    );
    setState(() => _copiedAt = entity.offset);
    _copiedTimer?.cancel();
    _copiedTimer = Timer(_kCopiedDuration, () {
      if (mounted) {
        setState(() => _copiedAt = null);
      }
    });
  }

  void _handleLink(BuildContext context, String url) {
    final KunChatLinkEvent event = KunChatLinkEvent(url);
    widget.onLink?.call(event);
    if (!event.defaultPrevented) {
      KunUIConfigScope.of(context).navigateTo(context, url);
    }
  }

  void _handleMention(BuildContext context, String userId) {
    final KunChatUserEvent event = KunChatUserEvent(userId);
    widget.onMention?.call(event);
    if (!event.defaultPrevented) {
      final KunUIConfig config = KunUIConfigScope.of(context);
      config.navigateTo(context, config.userLinkForId(userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<KunChatTextNode> tree = buildKunChatEntityTree(
      widget.text,
      widget.entities,
    );
    if (widget.preview) {
      return _ChatInline(
        nodes: tree,
        source: widget.text,
        preview: true,
        revealed: true,
        onReveal: _reveal,
        onLink: _handleLink,
        onMention: _handleMention,
      );
    }
    final Widget? trailing = widget.trailing;
    final bool hiddenSpoilers = !_revealed && _treeHasSpoiler(tree);
    final List<Widget> children = <Widget>[];
    final List<KunChatTextNode> inline = <KunChatTextNode>[];
    void flushInline({Widget? trailing}) {
      if (inline.isEmpty && trailing == null) {
        return;
      }
      children.add(
        _ChatInline(
          nodes: List<KunChatTextNode>.from(inline),
          source: widget.text,
          preview: false,
          revealed: _revealed,
          onReveal: _reveal,
          onLink: _handleLink,
          onMention: _handleMention,
          trailing: trailing,
        ),
      );
      inline.clear();
    }

    for (final KunChatTextNode node in tree) {
      if (node is KunChatEntityNode &&
          kunChatBlockEntityTypes.contains(node.entity.type)) {
        flushInline();
        if (node.entity.type == KunChatEntityType.pre) {
          children.add(
            _ChatPre(
              node: node,
              source: widget.text,
              copied: _copiedAt == node.entity.offset,
              onCopy: () => _copyPre(node),
            ),
          );
        } else {
          children.add(
            _ChatQuote(
              child: _ChatInline(
                nodes: node.children,
                source: widget.text,
                preview: false,
                revealed: _revealed,
                onReveal: _reveal,
                onLink: _handleLink,
                onMention: _handleMention,
              ),
            ),
          );
        }
      } else {
        inline.add(node);
      }
    }
    if (inline.isNotEmpty) {
      flushInline(trailing: trailing);
    } else if (trailing != null) {
      flushInline(trailing: trailing);
    }

    Widget body = children.length == 1
        ? children.first
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: children,
          );

    if (hiddenSpoilers) {
      final String revealLabel = KunMessagesScope.of(context).spoiler.reveal;
      body = Focus(
        focusNode: _spoilerFocus,
        onKeyEvent: (FocusNode node, KeyEvent event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.space)) {
            _reveal();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Semantics(
          button: true,
          label: _hiddenSpoilerLabel(tree, revealLabel),
          onTap: _reveal,
          child: ExcludeSemantics(child: body),
        ),
      );
    }
    return body;
  }
}

class _ChatQuote extends StatelessWidget {
  const _ChatQuote({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: KunSpacing.unit),
      padding: const EdgeInsets.fromLTRB(
        KunSpacing.unit * 2.5,
        KunSpacing.unit * 0.5,
        KunSpacing.unit * 2,
        KunSpacing.unit * 0.5,
      ),
      decoration: BoxDecoration(
        color: scheme.primary.solid.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(KunRadius.sm),
          bottomRight: Radius.circular(KunRadius.sm),
        ),
        border: Border(
          left: BorderSide(color: scheme.primary.solid, width: _kQuoteBorder),
        ),
      ),
      child: child,
    );
  }
}

class _ChatPre extends StatefulWidget {
  const _ChatPre({
    required this.node,
    required this.source,
    required this.copied,
    required this.onCopy,
  });

  final KunChatEntityNode node;
  final String source;
  final bool copied;
  final VoidCallback onCopy;

  @override
  State<_ChatPre> createState() => _ChatPreState();
}

class _ChatPreState extends State<_ChatPre> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    final KunMessages messages = KunMessagesScope.of(context);
    final double base =
        DefaultTextStyle.of(context).style.fontSize ?? KunText.base.fontSize!;
    final String language = widget.node.entity.language ?? '';
    final String body = widget.source.substring(
      widget.node.entity.offset,
      widget.node.entity.offset + widget.node.entity.length,
    );
    return Container(
      margin: const EdgeInsets.symmetric(vertical: KunSpacing.unit),
      decoration: BoxDecoration(
        color: scheme.neutral.solid.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(KunRadius.md),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            height: KunSpacing.unit * 7,
            child: Padding(
              padding: const EdgeInsets.only(
                left: KunSpacing.unit * 3,
                right: KunSpacing.unit,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      language,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KunText.xs.copyWith(
                        color: scheme.foregroundMuted,
                        fontWeight: KunFontWeights.medium,
                      ),
                    ),
                  ),
                  MouseRegion(
                    onEnter: (_) => setState(() => _hover = true),
                    onExit: (_) => setState(() => _hover = false),
                    child: GestureDetector(
                      onTap: widget.onCopy,
                      child: Semantics(
                        button: true,
                        label: widget.copied
                            ? messages.copy.copied
                            : messages.spoiler.copyCode,
                        child: SizedBox(
                          width: KunSpacing.unit * 6,
                          height: KunSpacing.unit * 6,
                          child: Icon(
                            widget.copied ? KunIcons.check : KunIcons.copy,
                            size: KunText.sm.fontSize,
                            color: _hover
                                ? scheme.foreground
                                : scheme.neutral.shade500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(
              KunSpacing.unit * 3,
              0,
              KunSpacing.unit * 3,
              KunSpacing.unit * 2,
            ),
            child: Text(
              body,
              softWrap: false,
              style: TextStyle(
                fontFamily: KunFontFamilies.mono,
                fontFamilyFallback: KunFontFamilies.monoFallback,
                fontSize: base * _kPreEm,
                height: _kPreLeading / (base * _kPreEm),
                leadingDistribution: TextLeadingDistribution.even,
                color: scheme.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatInline extends StatefulWidget {
  const _ChatInline({
    required this.nodes,
    required this.source,
    required this.preview,
    required this.revealed,
    required this.onReveal,
    required this.onLink,
    required this.onMention,
    this.trailing,
  });

  final List<KunChatTextNode> nodes;
  final String source;
  final bool preview;
  final bool revealed;
  final VoidCallback onReveal;
  final void Function(BuildContext context, String url) onLink;
  final void Function(BuildContext context, String userId) onMention;
  final Widget? trailing;

  @override
  State<_ChatInline> createState() => _ChatInlineState();
}

class _ChatInlineState extends State<_ChatInline>
    with SingleTickerProviderStateMixin {
  final GlobalKey _textKey = GlobalKey();
  final List<GestureRecognizer> _recognizers = <GestureRecognizer>[];
  final Set<int> _hovered = <int>{};
  final ValueNotifier<int> _repaint = ValueNotifier<int>(0);
  final math.Random _random = math.Random();
  final _SpoilerPaintData _spoilerPaint = _SpoilerPaintData();
  final _CodeChipPaintData _chipPaint = _CodeChipPaintData();

  Ticker? _ticker;
  double? _lastFrame;
  List<_SpoilerRange> _ranges = const <_SpoilerRange>[];
  List<_SpoilerRange> _codeRanges = const <_SpoilerRange>[];
  bool _hoverSpoiler = false;

  bool get _hidden => !widget.preview && !widget.revealed;

  bool get _wantSpoiler => _hidden && _ranges.isNotEmpty;

  bool get _wantCode => _codeRanges.isNotEmpty;

  List<Rect> get _particleRects => _toRects(_spoilerPaint.rects);

  List<Rect> get _spoilerTextRects => _toRects(_spoilerPaint.textRects);

  List<Rect> get _codeChipRects => _toRects(_chipPaint.rects);

  List<(Offset, Rect)> get _debugParticles => <(Offset, Rect)>[
        for (final _Particle p in _spoilerPaint.particles)
          (Offset(p.rect.x + p.x0, p.rect.y + p.y0), p.rect.toRect()),
      ];

  @override
  void initState() {
    super.initState();
    PaintingBinding.instance.systemFonts.addListener(_onSystemFonts);
  }

  @override
  void didUpdateWidget(_ChatInline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _spoilerPaint.reset();
      _chipPaint.rects = const <_SpoilerRect>[];
      _lastFrame = null;
    }
    if (oldWidget.revealed != widget.revealed && widget.revealed) {
      _beginReveal();
    }
  }

  @override
  void dispose() {
    PaintingBinding.instance.systemFonts.removeListener(_onSystemFonts);
    _ticker?.dispose();
    _repaint.dispose();
    _disposeRecognizers();
    super.dispose();
  }

  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _measure();
      }
    });
  }

  void _onSystemFonts() {
    if (mounted) {
      _scheduleMeasure();
    }
  }

  void _disposeRecognizers() {
    for (final GestureRecognizer recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  void _recycleRecognizers() {
    final List<GestureRecognizer> old = List<GestureRecognizer>.from(
      _recognizers,
    );
    _recognizers.clear();
    if (old.isEmpty) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final GestureRecognizer recognizer in old) {
        recognizer.dispose();
      }
    });
  }

  TapGestureRecognizer _tap(VoidCallback onTap) {
    final TapGestureRecognizer recognizer = TapGestureRecognizer()
      ..onTap = onTap;
    _recognizers.add(recognizer);
    return recognizer;
  }

  void _beginReveal() {
    if (kunReducedMotion(context) || _spoilerPaint.particles.isEmpty) {
      _ticker?.stop();
      _spoilerPaint.clear();
      _spoilerPaint.tStop = null;
      _repaint.value++;
      return;
    }
    _spoilerPaint.tStop = _spoilerPaint.clock;
    _ticker?.start();
  }

  bool _isInView() {
    final RenderObject? ro = context.findRenderObject();
    if (ro is! RenderBox || !ro.hasSize || !ro.attached) {
      return false;
    }
    final Offset origin = ro.localToGlobal(Offset.zero);
    final Rect widgetRect = origin & ro.size;
    final Size screen = MediaQuery.sizeOf(context);
    final Rect inflated = Rect.fromLTWH(
      -_kViewMargin,
      -_kViewMargin,
      screen.width + _kViewMargin * 2,
      screen.height + _kViewMargin * 2,
    );
    return widgetRect.overlaps(inflated);
  }

  void _onTick(Duration elapsed) {
    final double now = elapsed.inMicroseconds / 1e6;
    if (_lastFrame != null && (now - _lastFrame!) * 1000 < _kFrameMs) {
      return;
    }
    _spoilerPaint.clock += _lastFrame == null ? 0 : now - _lastFrame!;
    _lastFrame = now;
    if (_isInView()) {
      _measure();
      _repaint.value++;
    }
    final double? tStop = _spoilerPaint.tStop;
    if (tStop != null && _spoilerPaint.clock > tStop + _kFade) {
      _ticker?.stop();
      _spoilerPaint.clear();
      _repaint.value++;
    } else if (_spoilerPaint.particles.isEmpty &&
        _spoilerPaint.tStop == null &&
        elapsed.inMilliseconds >= 2000) {
      _ticker?.stop();
    }
  }

  RenderParagraph? _paragraph() {
    final RenderObject? root = _textKey.currentContext?.findRenderObject();
    if (root is RenderParagraph) {
      return root;
    }
    RenderParagraph? found;
    void visit(RenderObject child) {
      if (found != null) {
        return;
      }
      if (child is RenderParagraph) {
        found = child;
        return;
      }
      child.visitChildren(visit);
    }

    root?.visitChildren(visit);
    return found;
  }

  Offset _paintOrigin(RenderParagraph paragraph) {
    for (RenderObject? node = paragraph; node != null; node = node.parent) {
      if (node is RenderCustomPaint) {
        return paragraph.localToGlobal(Offset.zero, ancestor: node);
      }
    }
    final RenderObject? host = context.findRenderObject();
    if (host is RenderBox && host.hasSize && host.attached) {
      return host.globalToLocal(paragraph.localToGlobal(Offset.zero));
    }
    return Offset.zero;
  }

  List<_SpoilerRect> _boxesFor(
    RenderParagraph paragraph,
    int start,
    int end,
    Offset origin, {
    required bool words,
  }) {
    final List<_SpoilerRect> rects = <_SpoilerRect>[];
    void add(int a, int b) {
      if (a >= b) {
        return;
      }
      final List<TextBox> boxes = paragraph.getBoxesForSelection(
        TextSelection(baseOffset: a, extentOffset: b),
      );
      for (final TextBox tb in boxes) {
        final double w = tb.right - tb.left;
        final double h = tb.bottom - tb.top;
        if (w < 0.5 || h < 0.5) {
          continue;
        }
        rects.add(
          _SpoilerRect(
            x: tb.left + origin.dx,
            y: tb.top + origin.dy,
            w: w,
            h: h,
          ),
        );
      }
    }

    final String text = paragraph.text.toPlainText(
      includeSemanticsLabels: false,
      includePlaceholders: false,
    );
    if (start < 0 || end < 0 || start >= text.length) {
      return rects;
    }
    final int hi = math.min(end, text.length);
    if (!words) {
      add(start, hi);
      return rects;
    }
    final String slice = text.substring(start, hi);
    for (final RegExpMatch match in RegExp(r'\S+').allMatches(slice)) {
      final int a = start + match.start;
      add(a, a + match.group(0)!.length);
    }
    if (rects.isEmpty) {
      add(start, hi);
    }
    return rects;
  }

  List<_SpoilerRect> _boxesForRanges(
    RenderParagraph paragraph,
    List<_SpoilerRange> ranges,
    Offset origin, {
    required bool words,
  }) {
    final List<_SpoilerRect> out = <_SpoilerRect>[];
    for (final _SpoilerRange range in ranges) {
      out.addAll(
        _boxesFor(paragraph, range.start, range.end, origin, words: words),
      );
    }
    return out;
  }

  void _ensureTicker() {
    if (kunReducedMotion(context)) {
      return;
    }
    _ticker ??= createTicker(_onTick);
    if (!_ticker!.isTicking) {
      _lastFrame = null;
      _ticker!.start();
    }
  }

  void _measure() {
    if (!_wantSpoiler && !_wantCode) {
      return;
    }
    final RenderParagraph? paragraph = _paragraph();
    if (paragraph == null) {
      return;
    }
    final Offset origin = _paintOrigin(paragraph);

    if (_wantSpoiler) {
      final List<_SpoilerRect> textRects = _boxesForRanges(
        paragraph,
        _ranges,
        origin,
        words: false,
      );
      final List<_SpoilerRect> wordRects = _boxesForRanges(
        paragraph,
        _ranges,
        origin,
        words: true,
      );
      _spoilerPaint.textRects = textRects;
      final List<_SpoilerRect> seedRects =
          wordRects.isEmpty ? textRects : wordRects;
      if (_spoilerPaint.tStop == null) {
        if (!listEquals(_spoilerPaint.rects, seedRects)) {
          _spoilerPaint.particles = _seedParticles(seedRects, _random);
        }
        _spoilerPaint.rects = seedRects;
      }
      if (_spoilerPaint.particles.isNotEmpty && _spoilerPaint.tStop == null) {
        _ensureTicker();
      }
    }

    if (_wantCode) {
      _chipPaint.rects = _boxesForRanges(
        paragraph,
        _codeRanges,
        origin,
        words: false,
      );
      if (!_wantSpoiler) {
        _ensureTicker();
      }
    }
    _repaint.value++;
  }

  @override
  Widget build(BuildContext context) {
    _recycleRecognizers();
    final KunColorScheme scheme = KunTheme.of(context).colors;
    final TextStyle inherited = DefaultTextStyle.of(context).style;
    final TextStyle base = inherited.copyWith(
      color: inherited.color ?? scheme.foreground,
    );
    _ranges = <_SpoilerRange>[];
    _codeRanges = <_SpoilerRange>[];
    int cursor = 0;
    final List<InlineSpan> spans = _buildNodes(
      context,
      widget.nodes,
      base,
      scheme,
      inSpoiler: false,
      cursor: (int delta) => cursor += delta,
      cursorValue: () => cursor,
    );
    final Widget? trailing = widget.trailing;
    if (trailing != null) {
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: trailing,
        ),
      );
    }

    _chipPaint.color = scheme.neutral.solid.withValues(alpha: 0.2);

    if (_wantSpoiler || _wantCode) {
      _scheduleMeasure();
    } else if (!_hidden && _spoilerPaint.tStop == null) {
      _ticker?.stop();
    }

    Widget child = Text.rich(
      key: _textKey,
      TextSpan(style: base, children: spans),
      maxLines: widget.preview ? 1 : null,
      overflow: widget.preview ? TextOverflow.ellipsis : TextOverflow.clip,
      softWrap: !widget.preview,
      textAlign: TextAlign.start,
      textWidthBasis:
          widget.preview ? TextWidthBasis.parent : TextWidthBasis.longestLine,
    );

    if (_wantSpoiler || _wantCode) {
      child = CustomPaint(
        painter: _wantCode
            ? _CodeChipPainter(data: _chipPaint, listenable: _repaint)
            : null,
        foregroundPainter: _wantSpoiler
            ? _SpoilerPainter(data: _spoilerPaint, listenable: _repaint)
            : null,
        child: child,
      );
    }

    if (!_wantSpoiler) {
      return child;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hoverSpoiler = true),
      onExit: (_) => setState(() => _hoverSpoiler = false),
      cursor: SystemMouseCursors.click,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerUp: (_) {
          if (_hidden) {
            widget.onReveal();
          }
        },
        child: child,
      ),
    );
  }

  List<InlineSpan> _buildNodes(
    BuildContext context,
    List<KunChatTextNode> nodes,
    TextStyle style,
    KunColorScheme scheme, {
    required bool inSpoiler,
    required void Function(int delta) cursor,
    required int Function() cursorValue,
  }) {
    final List<InlineSpan> out = <InlineSpan>[];
    for (final KunChatTextNode node in nodes) {
      if (node is KunChatTextLeaf) {
        String text = node.text;
        if (widget.preview) {
          text = text.replaceAll('\n', ' ');
        }
        out.add(TextSpan(text: text, style: style));
        cursor(text.length);
        continue;
      }
      final KunChatEntityNode entityNode = node as KunChatEntityNode;
      out.addAll(
        _buildEntity(
          context,
          entityNode,
          style,
          scheme,
          inSpoiler: inSpoiler,
          cursor: cursor,
          cursorValue: cursorValue,
        ),
      );
    }
    return out;
  }

  List<InlineSpan> _buildEntity(
    BuildContext context,
    KunChatEntityNode node,
    TextStyle style,
    KunColorScheme scheme, {
    required bool inSpoiler,
    required void Function(int delta) cursor,
    required int Function() cursorValue,
  }) {
    final KunChatEntity entity = node.entity;
    List<InlineSpan> children({TextStyle? next, bool spoiler = false}) {
      return _buildNodes(
        context,
        node.children,
        next ?? style,
        scheme,
        inSpoiler: spoiler || inSpoiler,
        cursor: cursor,
        cursorValue: cursorValue,
      );
    }

    switch (entity.type) {
      case KunChatEntityType.bold:
        return children(
          next: style.copyWith(fontWeight: KunFontWeights.semibold),
        );
      case KunChatEntityType.italic:
        return children(next: style.copyWith(fontStyle: FontStyle.italic));
      case KunChatEntityType.underline:
        return children(
          next: style.copyWith(
            decoration: TextDecoration.underline,
            decorationColor: style.color,
          ),
        );
      case KunChatEntityType.strikethrough:
        return children(
          next: style.copyWith(
            decoration: TextDecoration.lineThrough,
            decorationColor: style.color,
          ),
        );
      case KunChatEntityType.code:
        final int start = cursorValue();
        final List<InlineSpan> inner = children(
          next: _codeStyle(style, scheme, inSpoiler: inSpoiler),
        );
        if (!(_hidden && inSpoiler)) {
          _codeRanges = <_SpoilerRange>[
            ..._codeRanges,
            _SpoilerRange(start, cursorValue()),
          ];
        }
        return inner;
      case KunChatEntityType.pre:
        if (widget.preview) {
          return children(
            next: _codeStyle(style, scheme, inSpoiler: inSpoiler),
          );
        }
        return children();
      case KunChatEntityType.blockquote:
        return children();
      case KunChatEntityType.spoiler:
        if (widget.preview) {
          final int size = _spoilerMaskSize(widget.source, entity);
          final String mask = '⠿' * size;
          cursor(mask.length);
          return <InlineSpan>[
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: ExcludeSemantics(
                child: Text(
                  mask,
                  style: style.copyWith(
                    color: (style.color ?? scheme.foreground).withValues(
                      alpha: 0.55,
                    ),
                    letterSpacing:
                        -0.05 * (style.fontSize ?? KunText.base.fontSize!),
                  ),
                ),
              ),
            ),
          ];
        }
        final int start = cursorValue();
        final Color? tint = _hidden
            ? (_hoverSpoiler ? _kSpoilerTintHover : _kSpoilerTint)
            : null;
        final TextStyle hiddenStyle = _hidden
            ? style.copyWith(
                color: (style.color ?? scheme.foreground).withValues(alpha: 0),
                backgroundColor: tint,
              )
            : style;
        final List<InlineSpan> inner = children(
          next: hiddenStyle,
          spoiler: true,
        );
        _ranges = <_SpoilerRange>[
          ..._ranges,
          _SpoilerRange(start, cursorValue()),
        ];
        return <InlineSpan>[TextSpan(style: hiddenStyle, children: inner)];
      case KunChatEntityType.textLink:
        return _linkSpans(
          context,
          node,
          kunChatSafeUrl(entity.url ?? ''),
          style,
          scheme,
          inSpoiler: inSpoiler,
          cursor: cursor,
          cursorValue: cursorValue,
        );
      case KunChatEntityType.url:
        return _linkSpans(
          context,
          node,
          kunChatSafeUrl(
            widget.source.substring(
              entity.offset,
              entity.offset + entity.length,
            ),
          ),
          style,
          scheme,
          inSpoiler: inSpoiler,
          cursor: cursor,
          cursorValue: cursorValue,
        );
      case KunChatEntityType.mention:
        return _mentionSpans(
          context,
          node,
          style,
          scheme,
          inSpoiler: inSpoiler,
          cursor: cursor,
          cursorValue: cursorValue,
        );
    }
  }

  TextStyle _codeStyle(
    TextStyle style,
    KunColorScheme scheme, {
    required bool inSpoiler,
  }) {
    final double size = (style.fontSize ?? KunText.base.fontSize!) * _kCodeEm;
    return style.copyWith(
      fontSize: size,
      fontFamily: KunFontFamilies.mono,
      fontFamilyFallback: KunFontFamilies.monoFallback,
      color: _hidden && inSpoiler
          ? (style.color ?? scheme.foreground).withValues(alpha: 0)
          : style.color,
    );
  }

  List<InlineSpan> _linkSpans(
    BuildContext context,
    KunChatEntityNode node,
    String? href,
    TextStyle style,
    KunColorScheme scheme, {
    required bool inSpoiler,
    required void Function(int delta) cursor,
    required int Function() cursorValue,
  }) {
    final bool tappable =
        !widget.preview && href != null && !(_hidden && inSpoiler);
    final bool hovered = _hovered.contains(node.entity.offset);
    final TextStyle linkStyle = style.copyWith(
      color: tappable || (!widget.preview && href != null)
          ? scheme.primary.text
          : style.color,
      decoration: tappable || (!widget.preview && href != null)
          ? TextDecoration.underline
          : style.decoration,
      decorationColor: !tappable
          ? style.decorationColor
          : hovered
              ? scheme.primary.text
              : scheme.primary.text.withValues(alpha: 0.4),
    );
    if (!tappable) {
      return _buildNodes(
        context,
        node.children,
        widget.preview ? style : linkStyle,
        scheme,
        inSpoiler: inSpoiler,
        cursor: cursor,
        cursorValue: cursorValue,
      );
    }
    final GestureRecognizer tap = _tap(() => widget.onLink(context, href));
    return _withTap(
      _buildNodes(
        context,
        node.children,
        linkStyle,
        scheme,
        inSpoiler: inSpoiler,
        cursor: cursor,
        cursorValue: cursorValue,
      ),
      tap,
      hoverKey: node.entity.offset,
    );
  }

  List<InlineSpan> _mentionSpans(
    BuildContext context,
    KunChatEntityNode node,
    TextStyle style,
    KunColorScheme scheme, {
    required bool inSpoiler,
    required void Function(int delta) cursor,
    required int Function() cursorValue,
  }) {
    final String? id = node.entity.userId;
    final bool tappable = !widget.preview &&
        id != null &&
        id.isNotEmpty &&
        !(_hidden && inSpoiler);
    final bool hovered = _hovered.contains(node.entity.offset);
    final TextStyle mentionStyle = style.copyWith(
      fontWeight: KunFontWeights.medium,
      color: tappable ? scheme.primary.text : style.color,
      decoration:
          tappable && hovered ? TextDecoration.underline : TextDecoration.none,
      decorationColor: scheme.primary.text,
    );
    if (!tappable) {
      return _buildNodes(
        context,
        node.children,
        mentionStyle,
        scheme,
        inSpoiler: inSpoiler,
        cursor: cursor,
        cursorValue: cursorValue,
      );
    }
    final GestureRecognizer tap = _tap(() => widget.onMention(context, id));
    return _withTap(
      _buildNodes(
        context,
        node.children,
        mentionStyle,
        scheme,
        inSpoiler: inSpoiler,
        cursor: cursor,
        cursorValue: cursorValue,
      ),
      tap,
      hoverKey: node.entity.offset,
    );
  }

  List<InlineSpan> _withTap(
    List<InlineSpan> spans,
    GestureRecognizer tap, {
    required int hoverKey,
  }) {
    // A recognizer on a textless wrapper has empty boxes, so
    // RenderParagraph skips the link node in assembleSemanticsNode.
    void onEnter(PointerEnterEvent _) {
      setState(() => _hovered.add(hoverKey));
    }

    void onExit(PointerExitEvent _) {
      setState(() => _hovered.remove(hoverKey));
    }

    List<InlineSpan> apply(List<InlineSpan> spans) {
      return <InlineSpan>[
        for (final InlineSpan span in spans)
          if (span is TextSpan)
            TextSpan(
              text: span.text,
              style: span.style,
              recognizer: span.recognizer ?? tap,
              mouseCursor: SystemMouseCursors.click,
              onEnter: span.onEnter ?? onEnter,
              onExit: span.onExit ?? onExit,
              children: span.children == null ? null : apply(span.children!),
            )
          else
            span,
      ];
    }

    return apply(spans);
  }
}

class _SpoilerPainter extends CustomPainter {
  _SpoilerPainter({required this.data, required Listenable listenable})
      : super(repaint: listenable);

  final _SpoilerPaintData data;

  @override
  void paint(Canvas canvas, Size size) {
    final List<_SpoilerRect> rects = data.rects;
    final List<_Particle> particles = data.particles;
    if (rects.isEmpty) {
      return;
    }
    final double t = data.clock;
    final double? tStop = data.tStop;
    final double tintFade = tStop != null
        ? _clamp01(1 - (t - tStop) / _kFade)
        : _clamp01(t / (_kFade * 0.5));
    if (tintFade > 0) {
      final Paint tint = Paint()
        ..color = _kCanvasTint.withValues(alpha: _kTintAlpha * tintFade);
      for (final _SpoilerRect rect in rects) {
        canvas.drawRect(rect.toRect(), tint);
      }
    }
    final int n = particles.length;
    for (int i = 0; i < n; i++) {
      final _Particle p = particles[i];
      if (tStop != null &&
          ((tStop + p.phase) / p.cycle).floor() <
              ((t + p.phase) / p.cycle).floor()) {
        continue;
      }
      final double fade = _fadeFactor(t, tStop, i, n, _kFade);
      if (fade <= 0) {
        continue;
      }
      final double lt = math.min(p.life, (t + p.phase) % p.cycle);
      final double alpha = fade * (1 - lt / p.life);
      if (alpha <= 0.01) {
        continue;
      }
      final double sz = fade * p.size0 * _trapezoid(p.life, 0.15, 0.3, lt);
      if (sz <= 0) {
        continue;
      }
      final _SpoilerRect rect = p.rect;
      final double x =
          rect.x + (((p.x0 + p.vx * lt) % rect.w) + rect.w) % rect.w;
      final double y =
          rect.y + (((p.y0 + p.vy * lt) % rect.h) + rect.h) % rect.h;
      final int channel = (p.light * 255 / 100).round().clamp(0, 255);
      final Paint paint = Paint()
        ..color = Color.fromRGBO(
          channel,
          channel,
          channel,
          alpha > 1 ? 1 : alpha,
        );
      if (p.square) {
        canvas.drawRect(Rect.fromLTWH(x, y, sz, sz), paint);
      } else {
        canvas.drawCircle(Offset(x, y), sz / 2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SpoilerPainter oldDelegate) {
    return oldDelegate.data != data;
  }
}

class _CodeChipPainter extends CustomPainter {
  _CodeChipPainter({required this.data, required Listenable listenable})
      : super(repaint: listenable);

  final _CodeChipPaintData data;

  @override
  void paint(Canvas canvas, Size size) {
    final Color? color = data.color;
    if (color == null || data.rects.isEmpty) {
      return;
    }
    final Paint fill = Paint()..color = color;
    final Radius radius = const Radius.circular(KunRounded.sm);
    for (final _SpoilerRect rect in data.rects) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            rect.x - KunSpacing.unit * 0.5,
            rect.y - 1,
            rect.x + rect.w + KunSpacing.unit * 0.5,
            rect.y + rect.h + 1,
          ),
          radius,
        ),
        fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CodeChipPainter oldDelegate) {
    return oldDelegate.data != data;
  }
}
