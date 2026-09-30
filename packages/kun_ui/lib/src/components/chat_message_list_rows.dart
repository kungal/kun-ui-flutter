part of 'chat_message_list.dart';

class _DayPill extends StatelessWidget {
  const _DayPill({
    super.key,
    required this.label,
    required this.scheme,
  });

  final String label;
  final KunColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.content1,
        borderRadius: BorderRadius.circular(KunRadius.full),
        boxShadow: KunShadows.sm,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: KunSpacing.unit * 3,
          vertical: KunSpacing.unit * 0.5,
        ),
        child: Text(
          label,
          style: KunText.xs.copyWith(
            color: scheme.neutral.shade600,
            fontWeight: KunFontWeights.medium,
          ),
        ),
      ),
    );
  }
}

class _DayInFlow extends StatefulWidget {
  const _DayInFlow({
    required this.dayKey,
    required this.label,
    required this.scheme,
    required this.hidden,
    required this.onRegister,
    required this.onUnregister,
  });

  final String dayKey;
  final String label;
  final KunColorScheme scheme;
  final bool hidden;
  final void Function(String key, BuildContext context) onRegister;
  final void Function(String key, BuildContext context) onUnregister;

  @override
  State<_DayInFlow> createState() => _DayInFlowState();
}

class _DayInFlowState extends State<_DayInFlow> {
  @override
  void initState() {
    super.initState();
    widget.onRegister(widget.dayKey, context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onRegister(widget.dayKey, context);
      }
    });
  }

  @override
  void didUpdateWidget(_DayInFlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dayKey != widget.dayKey) {
      oldWidget.onUnregister(oldWidget.dayKey, context);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onRegister(widget.dayKey, context);
      }
    });
  }

  @override
  void dispose() {
    widget.onUnregister(widget.dayKey, context);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: KunSpacing.unit * 1.5),
      child: Opacity(
        opacity: widget.hidden ? 0 : 1,
        child: Center(
          child: _DayPill(label: widget.label, scheme: widget.scheme),
        ),
      ),
    );
  }
}

class _UnreadDivider extends StatefulWidget {
  const _UnreadDivider({
    required this.scheme,
    required this.label,
    required this.onRegister,
    required this.onUnregister,
  });

  final KunColorScheme scheme;
  final String label;
  final ValueChanged<BuildContext> onRegister;
  final ValueChanged<BuildContext> onUnregister;

  @override
  State<_UnreadDivider> createState() => _UnreadDividerState();
}

class _UnreadDividerState extends State<_UnreadDivider> {
  @override
  void initState() {
    super.initState();
    widget.onRegister(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onRegister(context);
      }
    });
  }

  @override
  void didUpdateWidget(_UnreadDivider oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onRegister(context);
      }
    });
  }

  @override
  void dispose() {
    widget.onUnregister(context);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: widget.scheme.neutral.solid.withValues(alpha: _kUnreadFill),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: KunSpacing.unit),
        child: Text(
          widget.label,
          textAlign: TextAlign.center,
          style: KunText.xs.copyWith(
            color: widget.scheme.neutral.text,
            fontWeight: KunFontWeights.medium,
          ),
        ),
      ),
    );
  }
}

class _ServiceListRow extends StatefulWidget {
  const _ServiceListRow({
    required this.row,
    required this.scheme,
    required this.users,
    required this.currentUserId,
    required this.resolveMessage,
    required this.highlighted,
    required this.flash,
    required this.focused,
    required this.skipTraversal,
    required this.onRegister,
    required this.onUnregister,
    required this.onFocus,
  });

  final KunChatServiceRow row;
  final KunColorScheme scheme;
  final List<KunChatUser> users;
  final String currentUserId;
  final KunChatMessage? Function(int seq) resolveMessage;
  final bool highlighted;
  final Animation<double> flash;
  final bool focused;
  final bool skipTraversal;
  final ValueChanged<BuildContext> onRegister;
  final ValueChanged<BuildContext> onUnregister;
  final VoidCallback onFocus;

  @override
  State<_ServiceListRow> createState() => _ServiceListRowState();
}

class _ServiceListRowState extends State<_ServiceListRow> {
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    widget.onRegister(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onRegister(context);
      }
    });
  }

  @override
  void didUpdateWidget(_ServiceListRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.row.key != widget.row.key) {
      oldWidget.onUnregister(context);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onRegister(context);
      }
    });
  }

  @override
  void dispose() {
    widget.onUnregister(context);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      skipTraversal: widget.skipTraversal,
      onFocusChange: (bool focused) {
        setState(() => _hasFocus = focused);
        if (focused) {
          widget.onFocus();
        }
      },
      child: AnimatedBuilder(
        animation: widget.flash,
        builder: (BuildContext context, Widget? child) {
          return _RowChrome(
            scheme: widget.scheme,
            highlighted: widget.highlighted,
            flash: widget.flash.value,
            focused: widget.focused &&
                _hasFocus &&
                FocusManager.instance.highlightMode ==
                    FocusHighlightMode.traditional,
            padding: const EdgeInsets.symmetric(
              vertical: KunSpacing.unit * 1.5,
            ),
            child: child!,
          );
        },
        child: KunChatBubble(
          message: widget.row.message,
          users: widget.users,
          currentUserId: widget.currentUserId,
          resolveMessage: widget.resolveMessage,
        ),
      ),
    );
  }
}

class _MessageListRow extends StatefulWidget {
  const _MessageListRow({
    required this.row,
    required this.kind,
    required this.scheme,
    required this.catalog,
    required this.users,
    required this.userMap,
    required this.currentUserId,
    required this.reactionOptions,
    required this.resolveMediaUrl,
    required this.resolveMessage,
    required this.swipeToReply,
    required this.position,
    required this.status,
    required this.highlighted,
    required this.flash,
    required this.focused,
    required this.skipTraversal,
    required this.onRegister,
    required this.onUnregister,
    required this.onFocus,
    required this.onOpenMenu,
    required this.onSwipeReply,
    required this.onReplyTap,
    required this.onReact,
    required this.onRetry,
    required this.onPhotoTap,
    required this.onUserTap,
    required this.onMention,
    required this.onLink,
  });

  final KunChatMessageRow row;
  final KunChatKind kind;
  final KunColorScheme scheme;
  final KunMessages catalog;
  final List<KunChatUser> users;
  final Map<String, KunChatUser> userMap;
  final String currentUserId;
  final List<KunChatReactionOption> reactionOptions;
  final KunChatMediaUrlResolver? resolveMediaUrl;
  final KunChatMessage? Function(int seq) resolveMessage;
  final bool swipeToReply;
  final KunChatBubblePosition position;
  final KunChatSendStatus? status;
  final bool highlighted;
  final Animation<double> flash;
  final bool focused;
  final bool skipTraversal;
  final ValueChanged<BuildContext> onRegister;
  final ValueChanged<BuildContext> onUnregister;
  final VoidCallback onFocus;
  final ValueChanged<Offset> onOpenMenu;
  final VoidCallback onSwipeReply;
  final ValueChanged<int> onReplyTap;
  final ValueChanged<String?> onReact;
  final VoidCallback onRetry;
  final ValueChanged<int> onPhotoTap;
  final KunChatUserCallback onUserTap;
  final KunChatUserCallback? onMention;
  final KunChatLinkCallback? onLink;

  @override
  State<_MessageListRow> createState() => _MessageListRowState();
}

class _MessageListRowState extends State<_MessageListRow>
    with SingleTickerProviderStateMixin {
  bool _hasFocus = false;

  int? _pointer;
  Offset _origin = Offset.zero;
  _PressMode _mode = _PressMode.pending;
  double _dx = 0;
  Timer? _pressTimer;
  ScrollHoldController? _hold;
  AnimationController? _spring;

  @override
  void initState() {
    super.initState();
    widget.onRegister(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onRegister(context);
      }
    });
  }

  @override
  void didUpdateWidget(_MessageListRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.row.key != widget.row.key) {
      oldWidget.onUnregister(context);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onRegister(context);
      }
    });
  }

  @override
  void dispose() {
    _pressTimer?.cancel();
    _hold?.cancel();
    _spring?.dispose();
    widget.onUnregister(context);
    super.dispose();
  }

  bool _isTouch(PointerDeviceKind kind) =>
      kind == PointerDeviceKind.touch || kind == PointerDeviceKind.stylus;

  bool _hitsHorizontalScroller(Offset global) {
    bool found = false;
    void visit(Element el) {
      if (found) {
        return;
      }
      if (el.widget is Scrollable) {
        final Scrollable scrollable = el.widget as Scrollable;
        if (axisDirectionToAxis(scrollable.axisDirection) == Axis.horizontal) {
          final RenderObject? object = el.renderObject;
          if (object is RenderBox && object.hasSize && object.attached) {
            final Offset origin = object.localToGlobal(Offset.zero);
            if ((origin & object.size).contains(global)) {
              found = true;
              return;
            }
          }
        }
      }
      el.visitChildren(visit);
    }

    context.visitChildElements(visit);
    return found;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (!_isTouch(event.kind)) {
      return;
    }
    _pointer = event.pointer;
    _origin = event.position;
    _mode = _PressMode.pending;
    _dx = 0;
    _pressTimer?.cancel();
    _pressTimer = Timer(_kLongPress, () {
      if (!mounted || _mode != _PressMode.pending) {
        return;
      }
      kunLongPressFeedback(context);
      widget.onOpenMenu(_origin);
      _mode = _PressMode.menu;
      _pointer = null;
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _pointer) {
      return;
    }
    final double dx = event.position.dx - _origin.dx;
    final double dy = event.position.dy - _origin.dy;
    if (_mode == _PressMode.pending) {
      if (dx.abs() > _kPressSlop || dy.abs() > _kPressSlop) {
        _pressTimer?.cancel();
      }
      final bool canSwipe = widget.swipeToReply &&
          _origin.dx > _kEdgeGuard &&
          !_hitsHorizontalScroller(_origin);
      if (dy.abs() > _kAxisLock) {
        _mode = _PressMode.scroll;
      } else if (canSwipe && -dx > _kAxisLock && dx.abs() > dy.abs()) {
        _mode = _PressMode.swipe;
        _hold = Scrollable.maybeOf(context)?.position.hold(() {});
      }
    }
    if (_mode != _PressMode.swipe) {
      return;
    }
    setState(() {
      _dx = math.min(_kSwipeMax, math.max(0, -dx));
    });
  }

  void _onPointerUp(PointerUpEvent event) {
    _endPress(event.pointer, reply: true);
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _endPress(event.pointer, reply: false);
  }

  void _endPress(int pointer, {required bool reply}) {
    _pressTimer?.cancel();
    if (pointer != _pointer) {
      return;
    }
    final double dx = _dx;
    final _PressMode mode = _mode;
    _pointer = null;
    _hold?.cancel();
    _hold = null;
    if (mode != _PressMode.swipe) {
      _mode = _PressMode.pending;
      return;
    }
    if (reply && dx >= _kSwipeTrigger) {
      widget.onSwipeReply();
    }
    _animateBack();
  }

  void _animateBack() {
    _spring?.dispose();
    final double begin = _dx;
    final AnimationController controller = AnimationController(
      vsync: this,
      duration: kunMotion(context, KunDurations.base),
    );
    _spring = controller;
    final Animation<double> curved = CurvedAnimation(
      parent: controller,
      curve: KunEasing.enter,
    );
    controller.addListener(() {
      setState(() {
        _dx = begin * (1 - curved.value);
      });
    });
    controller.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() {
          _dx = 0;
          _mode = _PressMode.pending;
        });
      }
    });
    controller.forward();
  }

  void _openMenuAtRow() {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return;
    }
    final Offset origin = box.localToGlobal(Offset.zero);
    widget.onOpenMenu(
      Offset(
        origin.dx + _kMenuAtRowX,
        origin.dy + box.size.height - _kMenuAtRowY,
      ),
    );
  }

  Map<CustomSemanticsAction, VoidCallback> _menuActions() {
    return <CustomSemanticsAction, VoidCallback>{
      CustomSemanticsAction(label: widget.catalog.chatMenu.label):
          _openMenuAtRow,
    };
  }

  @override
  Widget build(BuildContext context) {
    final KunChatMessageRow row = widget.row;
    final bool group = widget.kind == KunChatKind.group && !row.own;
    final KunChatResolvedUser sender = resolveKunChatUser(
      widget.userMap,
      row.message.senderId,
      widget.catalog,
    );
    final double hPad =
        MediaQuery.sizeOf(context).width >= KunTheme.of(context).breakpoints.sm
            ? KunSpacing.unit * 3
            : KunSpacing.unit * 2;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        // Any TapGestureRecognizer gets a semantics tap action, onTap or not.
        excludeFromSemantics: true,
        onSecondaryTapUp: (TapUpDetails details) {
          widget.onOpenMenu(details.globalPosition);
        },
        child: Focus(
          skipTraversal: widget.skipTraversal,
          onFocusChange: (bool focused) {
            setState(() => _hasFocus = focused);
            if (focused) {
              widget.onFocus();
            }
          },
          child: AnimatedBuilder(
            animation: widget.flash,
            builder: (BuildContext context, Widget? child) {
              return _RowChrome(
                scheme: widget.scheme,
                highlighted: widget.highlighted,
                flash: widget.flash.value,
                focused: widget.focused &&
                    _hasFocus &&
                    FocusManager.instance.highlightMode ==
                        FocusHighlightMode.traditional,
                padding: EdgeInsets.fromLTRB(
                  hPad,
                  0,
                  hPad,
                  row.groupEnd ? KunSpacing.unit * 2 : KunSpacing.unit * 0.5,
                ),
                child: child!,
              );
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Transform.translate(
                  offset: Offset(-_dx, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: row.own
                        ? MainAxisAlignment.end
                        : MainAxisAlignment.start,
                    children: <Widget>[
                      if (group)
                        SizedBox(
                          width: KunSpacing.unit * 8,
                          child: row.groupEnd
                              ? _AvatarTap(
                                  sender: sender,
                                  onTap: () => widget.onUserTap(
                                    KunChatUserEvent(row.message.senderId),
                                  ),
                                )
                              : null,
                        ),
                      if (group) const SizedBox(width: KunSpacing.unit * 2),
                      Flexible(
                        child: Align(
                          alignment: row.own
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          widthFactor: 1,
                          child: KunChatBubble(
                            message: row.message,
                            album:
                                row.messages.length > 1 ? row.messages : null,
                            own: row.own,
                            users: widget.users,
                            currentUserId: widget.currentUserId,
                            showSender: widget.kind == KunChatKind.group &&
                                !row.own &&
                                row.groupStart,
                            position: widget.position,
                            status: widget.status,
                            reactionOptions: widget.reactionOptions,
                            resolveMediaUrl: widget.resolveMediaUrl,
                            resolveMessage: widget.resolveMessage,
                            semanticActions: _menuActions(),
                            lightbox: false,
                            onReplyTap: widget.onReplyTap,
                            onReact: widget.onReact,
                            onRetry: widget.onRetry,
                            onPhotoTap: widget.onPhotoTap,
                            onUserTap: widget.onUserTap,
                            onMention: widget.onMention,
                            onLink: widget.onLink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.swipeToReply)
                  Positioned(
                    right: KunSpacing.unit * 3,
                    top: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: math.min(1, _dx / _kSwipeTrigger),
                        child: Align(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: widget.scheme.neutral.solid.withValues(
                                alpha: _kSwipeIconFill,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: SizedBox(
                              width: KunSpacing.unit * 8,
                              height: KunSpacing.unit * 8,
                              child: Icon(
                                KunIcons.reply,
                                size: KunText.base.fontSize,
                                color: widget.scheme.foreground,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _PressMode { pending, swipe, scroll, menu }

class _AvatarTap extends StatelessWidget {
  const _AvatarTap({required this.sender, required this.onTap});

  final KunChatResolvedUser sender;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Widget avatar = KunAvatar(
      user: sender.avatarUser,
      isNavigation: false,
    );
    if (sender.deleted) {
      return avatar;
    }
    return Semantics(
      button: true,
      label: sender.name,
      child: GestureDetector(
        onTap: onTap,
        child: avatar,
      ),
    );
  }
}

class _RowChrome extends StatelessWidget {
  const _RowChrome({
    required this.scheme,
    required this.highlighted,
    required this.flash,
    required this.focused,
    required this.padding,
    required this.child,
  });

  final KunColorScheme scheme;
  final bool highlighted;
  final double flash;
  final bool focused;
  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool reduce = kunReducedMotion(context);
    Color? color;
    if (focused) {
      color = scheme.primary.solid.withValues(alpha: _kFocusFill);
    }
    if (highlighted && !reduce) {
      final double hold = flash <= 0.2 ? 1 : (1 - (flash - 0.2) / 0.8);
      final Color flashColor = scheme.primary.shade500.withValues(
        alpha: _kFlashAlpha * hold,
      );
      color = color == null ? flashColor : Color.alphaBlend(flashColor, color);
    }
    Widget painted = Padding(padding: padding, child: child);
    if (color != null) {
      painted = ColoredBox(color: color, child: painted);
    }
    if (highlighted && reduce) {
      painted = DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(
            color: scheme.primary.shade500.withValues(
              alpha: _kFlashOutlineAlpha,
            ),
            width: _kFlashOutline,
          ),
        ),
        child: painted,
      );
    }
    return painted;
  }
}

class _ScrollFab extends StatelessWidget {
  const _ScrollFab({
    required this.animation,
    required this.count,
    required this.scheme,
    required this.catalog,
    required this.onPressed,
  });

  final Animation<double> animation;
  final int count;
  final KunColorScheme scheme;
  final KunMessages catalog;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final String label = count > 0
        ? catalog.chat.scrollToBottomUnread(count: count)
        : catalog.chat.scrollToBottom;
    final Size drawn = Size.square(KunSpacing.unit * 10);
    final EdgeInsets outset = kunTapTargetOutset(context, drawn);
    return Positioned(
      right: math.max(0, KunSpacing.unit * 3 - outset.right),
      bottom: math.max(0, KunSpacing.unit * 3 - outset.bottom),
      child: AnimatedBuilder(
        animation: animation,
        builder: (BuildContext context, Widget? child) {
          return IgnorePointer(
            ignoring: animation.value == 0,
            child: FadeTransition(
              opacity: animation,
              child: Transform.translate(
                offset: Offset(
                  0,
                  KunSpacing.unit * 2 * (1 - animation.value),
                ),
                child: child,
              ),
            ),
          );
        },
        child: Semantics(
          container: true,
          button: true,
          label: label,
          onTap: onPressed,
          excludeSemantics: true,
          child: KunTapTarget(
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                excludeFromSemantics: true,
                onTap: onPressed,
                child: DecoratedBox(
                  key: KunChatMessageList.fabKey,
                  decoration: BoxDecoration(
                    color: scheme.content1,
                    shape: BoxShape.circle,
                    boxShadow: KunShadows.md,
                  ),
                  child: SizedBox(
                    width: KunSpacing.unit * 10,
                    height: KunSpacing.unit * 10,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: <Widget>[
                        Icon(
                          KunIcons.chevronDown,
                          size: KunText.xl.fontSize,
                          color: scheme.neutral.shade600,
                        ),
                        if (count > 0)
                          Positioned(
                            top: -KunSpacing.unit * 1.5,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: scheme.primary.solid,
                                borderRadius: BorderRadius.circular(
                                  KunRadius.full,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: KunSpacing.unit * 1.5,
                                ),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    minWidth: KunSpacing.unit * 5,
                                  ),
                                  child: Text(
                                    count > _kFabBadgeCap ? '999+' : '$count',
                                    textAlign: TextAlign.center,
                                    style: KunText.xs.copyWith(
                                      color: scheme.primary.onSolid,
                                      fontWeight: KunFontWeights.medium,
                                      height: 20 / 12,
                                      fontFeatures: const <FontFeature>[
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
