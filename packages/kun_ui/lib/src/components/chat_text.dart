import 'dart:async';
import 'dart:math' as math;

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

/// Web `TINT_ALPHA`.
const double _kTintAlpha = 0.34;

/// Web `V_MIN`.
const double _kVMin = 2;

/// Web `V_MAX`.
const double _kVMax = 12;

/// Web `devicePixelRatio` cap.
const double _kDprCap = 2;

/// IntersectionObserver `rootMargin` `120px`.
const double _kViewMargin = 120;

/// Web `ChatText.vue:83` copied-state timeout.
const Duration _kCopiedDuration = Duration(milliseconds: 2000);

/// Web `ChatText.vue:268` hidden spoiler tint.
const Color _kSpoilerTint = Color.fromRGBO(150, 150, 150, 0.18);

/// Web `ChatText.vue:274` hidden spoiler hover tint.
const Color _kSpoilerTintHover = Color.fromRGBO(150, 150, 150, 0.26);

/// Web `useSpoilerContent.ts:169` canvas tint grey.
const int _kParticleTint = 150;

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
  final int count =
      math.min(_kMaxParticles, math.max(6, (total * _kDensity).round()));
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
    light:
        math.max(8, math.min(92, 50 + ldir * (16 + random.nextDouble() * 30))),
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
  final String slice =
      text.substring(entity.offset, entity.offset + entity.length);
  return slice.runes.length.clamp(3, 12);
}

/// Message text plus entities, rendered from [buildKunChatEntityTree].
class KunChatText extends StatefulWidget {
  /// Creates chat text.
  const KunChatText({
    super.key,
    required this.text,
    this.entities,
    this.preview = false,
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

  /// A link was tapped. The default is [KunUIConfig.navigateTo] unless the
  /// listener calls [KunChatLinkEvent.preventDefault].
  final KunChatLinkCallback? onLink;

  /// A mention was tapped. The default is navigating to
  /// [KunUIConfig.userLinkForId] unless prevented.
  final KunChatMentionCallback? onMention;

  @override
  State<KunChatText> createState() => _KunChatTextState();
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
        text:
            widget.text.substring(entity.offset, entity.offset + entity.length),
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
    final KunChatMentionEvent event = KunChatMentionEvent(userId);
    widget.onMention?.call(event);
    if (!event.defaultPrevented) {
      final KunUIConfig config = KunUIConfigScope.of(context);
      config.navigateTo(context, config.userLinkForId(userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<KunChatTextNode> tree =
        buildKunChatEntityTree(widget.text, widget.entities);
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
    final bool hiddenSpoilers = !_revealed && _treeHasSpoiler(tree);
    final List<Widget> children = <Widget>[];
    final List<KunChatTextNode> inline = <KunChatTextNode>[];
    void flushInline() {
      if (inline.isEmpty) {
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
    flushInline();

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
          label: revealLabel,
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
                        color: scheme.neutral.shade500,
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
  });

  final List<KunChatTextNode> nodes;
  final String source;
  final bool preview;
  final bool revealed;
  final VoidCallback onReveal;
  final void Function(BuildContext context, String url) onLink;
  final void Function(BuildContext context, String userId) onMention;

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

  Ticker? _ticker;
  double _clock = 0;
  double? _lastFrame;
  double? _tStop;
  List<_SpoilerRect> _rects = const <_SpoilerRect>[];
  List<_Particle> _particles = const <_Particle>[];
  List<_SpoilerRange> _ranges = const <_SpoilerRange>[];
  bool _hoverSpoiler = false;
  bool _measured = false;

  bool get _hidden => !widget.preview && !widget.revealed;

  @override
  void didUpdateWidget(_ChatInline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revealed != widget.revealed && widget.revealed) {
      _beginReveal();
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _repaint.dispose();
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final GestureRecognizer recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  void _recycleRecognizers() {
    final List<GestureRecognizer> old =
        List<GestureRecognizer>.from(_recognizers);
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
    if (kunReducedMotion(context) || _particles.isEmpty) {
      _ticker?.stop();
      _particles = const <_Particle>[];
      _rects = const <_SpoilerRect>[];
      _tStop = null;
      _repaint.value++;
      return;
    }
    _tStop = _clock;
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
    _clock += _lastFrame == null ? 0 : now - _lastFrame!;
    _lastFrame = now;
    if (_isInView()) {
      _repaint.value++;
    }
    if (_tStop != null && _clock > _tStop! + _kFade) {
      _ticker?.stop();
      _particles = const <_Particle>[];
      _rects = const <_SpoilerRect>[];
      _repaint.value++;
    }
  }

  RenderParagraph? _paragraph() {
    final BuildContext? ctx = _textKey.currentContext;
    if (ctx == null) {
      return null;
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

    final RenderObject? root = ctx.findRenderObject();
    if (root is RenderParagraph) {
      return root;
    }
    root?.visitChildren(visit);
    return found;
  }

  void _measure() {
    if (!_hidden || _ranges.isEmpty) {
      return;
    }
    final RenderParagraph? paragraph = _paragraph();
    if (paragraph == null) {
      return;
    }
    final List<_SpoilerRect> rects = <_SpoilerRect>[];
    final Offset origin = paragraph.localToGlobal(Offset.zero);
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    final Offset localOrigin =
        box == null ? Offset.zero : box.globalToLocal(origin);
    final String text = paragraph.text.toPlainText();
    for (final _SpoilerRange range in _ranges) {
      if (range.start >= text.length || range.end > text.length) {
        continue;
      }
      final String slice = text.substring(range.start, range.end);
      for (final RegExpMatch match in RegExp(r'\S+').allMatches(slice)) {
        final int start = range.start + match.start;
        final int end = start + match.group(0)!.length;
        final List<TextBox> boxes = paragraph.getBoxesForSelection(
          TextSelection(baseOffset: start, extentOffset: end),
        );
        for (final TextBox tb in boxes) {
          final double w = tb.right - tb.left;
          final double h = tb.bottom - tb.top;
          if (w < 0.5 || h < 0.5) {
            continue;
          }
          rects.add(
            _SpoilerRect(
              x: tb.left + localOrigin.dx,
              y: tb.top + localOrigin.dy,
              w: w,
              h: h,
            ),
          );
        }
      }
    }
    _rects = rects;
    _particles = _seedParticles(rects, _random);
    _measured = true;
    if (!kunReducedMotion(context) && _particles.isNotEmpty && _tStop == null) {
      _ticker ??= createTicker(_onTick);
      if (!_ticker!.isTicking) {
        _lastFrame = null;
        _ticker!.start();
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

    if (_hidden && _ranges.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _measure();
        }
      });
    } else if (!_hidden) {
      if (_tStop == null) {
        _ticker?.stop();
      }
    }

    final TextAlign align = TextAlign.start;
    final TextSpan root = TextSpan(style: base, children: spans);
    final Widget text = widget.preview
        ? Text.rich(
            key: _textKey,
            root,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            textAlign: align,
          )
        : Text.rich(
            key: _textKey,
            root,
            softWrap: true,
            textAlign: align,
          );

    if (!_hidden || _ranges.isEmpty) {
      return text;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hoverSpoiler = true),
      onExit: (_) => setState(() => _hoverSpoiler = false),
      cursor: SystemMouseCursors.click,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerUp: (PointerUpEvent event) {
          if (_hidden) {
            widget.onReveal();
          }
        },
        child: Stack(
          children: <Widget>[
            text,
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _SpoilerPainter(
                    rects: _rects,
                    particles: _particles,
                    clock: _clock,
                    tStop: _tStop,
                    hover: _hoverSpoiler,
                    measured: _measured,
                    dpr: math.min(
                      MediaQuery.devicePixelRatioOf(context),
                      _kDprCap,
                    ),
                    listenable: _repaint,
                  ),
                ),
              ),
            ),
          ],
        ),
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
        out.add(
          TextSpan(
            text: text,
            style: style,
          ),
        );
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
            next: style.copyWith(fontWeight: KunFontWeights.semibold));
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
        return children(
          next: _codeStyle(style, scheme, inSpoiler: inSpoiler),
        );
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
                    color: (style.color ?? scheme.foreground)
                        .withValues(alpha: 0.55),
                    letterSpacing:
                        -0.05 * (style.fontSize ?? KunText.base.fontSize!),
                  ),
                ),
              ),
            ),
          ];
        }
        final int start = cursorValue();
        final TextStyle hiddenStyle = _hidden
            ? style.copyWith(
                color: (style.color ?? scheme.foreground).withValues(alpha: 0),
              )
            : style;
        final List<InlineSpan> inner =
            children(next: hiddenStyle, spoiler: true);
        _ranges = <_SpoilerRange>[
          ..._ranges,
          _SpoilerRange(start, cursorValue())
        ];
        return inner;
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
            widget.source
                .substring(entity.offset, entity.offset + entity.length),
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
      backgroundColor: scheme.neutral.solid.withValues(alpha: 0.2),
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
          ? scheme.primary.shade600
          : style.color,
      decoration: tappable || (!widget.preview && href != null)
          ? TextDecoration.underline
          : style.decoration,
      decorationColor: !tappable
          ? style.decorationColor
          : hovered
              ? scheme.primary.shade600
              : scheme.primary.shade600.withValues(alpha: 0.4),
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
    return <InlineSpan>[
      TextSpan(
        style: linkStyle,
        recognizer: _tap(() => widget.onLink(context, href)),
        mouseCursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered.add(node.entity.offset)),
        onExit: (_) => setState(() => _hovered.remove(node.entity.offset)),
        children: _buildNodes(
          context,
          node.children,
          linkStyle,
          scheme,
          inSpoiler: inSpoiler,
          cursor: cursor,
          cursorValue: cursorValue,
        ),
      ),
    ];
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
      color: tappable ? scheme.primary.shade600 : style.color,
      decoration:
          tappable && hovered ? TextDecoration.underline : TextDecoration.none,
      decorationColor: scheme.primary.shade600,
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
    return <InlineSpan>[
      TextSpan(
        style: mentionStyle,
        recognizer: _tap(() => widget.onMention(context, id)),
        mouseCursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered.add(node.entity.offset)),
        onExit: (_) => setState(() => _hovered.remove(node.entity.offset)),
        children: _buildNodes(
          context,
          node.children,
          mentionStyle,
          scheme,
          inSpoiler: inSpoiler,
          cursor: cursor,
          cursorValue: cursorValue,
        ),
      ),
    ];
  }
}

class _SpoilerPainter extends CustomPainter {
  _SpoilerPainter({
    required this.rects,
    required this.particles,
    required this.clock,
    required this.tStop,
    required this.hover,
    required this.measured,
    required this.dpr,
    required Listenable listenable,
  }) : super(repaint: listenable);

  final List<_SpoilerRect> rects;
  final List<_Particle> particles;
  final double clock;
  final double? tStop;
  final bool hover;
  final bool measured;
  final double dpr;

  @override
  void paint(Canvas canvas, Size size) {
    if (!measured || rects.isEmpty) {
      final Paint fill = Paint()
        ..color = hover ? _kSpoilerTintHover : _kSpoilerTint;
      canvas.drawRect(Offset.zero & size, fill);
      return;
    }
    final double t = clock;
    final int n = particles.length;
    final double tintFade = tStop != null
        ? _clamp01(1 - (t - tStop!) / _kFade)
        : _clamp01(t / (_kFade * 0.5));
    if (tintFade > 0) {
      final Paint tint = Paint()
        ..color = Color.fromRGBO(
          _kParticleTint,
          _kParticleTint,
          _kParticleTint,
          _kTintAlpha * tintFade,
        );
      for (final _SpoilerRect rect in rects) {
        canvas.drawRect(Rect.fromLTWH(rect.x, rect.y, rect.w, rect.h), tint);
      }
    }
    for (int i = 0; i < n; i++) {
      final _Particle p = particles[i];
      if (tStop != null &&
          ((tStop! + p.phase) / p.cycle).floor() <
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
        ..color =
            Color.fromRGBO(channel, channel, channel, alpha > 1 ? 1 : alpha);
      if (p.square) {
        canvas.drawRect(Rect.fromLTWH(x, y, sz, sz), paint);
      } else {
        canvas.drawCircle(Offset(x, y), sz / 2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SpoilerPainter oldDelegate) {
    return oldDelegate.clock != clock ||
        oldDelegate.tStop != tStop ||
        oldDelegate.hover != hover ||
        oldDelegate.measured != measured ||
        !identical(oldDelegate.particles, particles);
  }
}
