part of 'chat_message_list.dart';

enum _FlatKind { day, unread, service, message }

class _FlatItem {
  const _FlatItem({
    required this.key,
    required this.kind,
    this.section,
    this.row,
  });

  final String key;
  final _FlatKind kind;
  final KunChatDaySection? section;
  final KunChatListRow? row;
}

class _MountedRow {
  _MountedRow({
    required this.key,
    required this.context,
    required this.seq,
    required this.fromOther,
    required this.kind,
    this.sectionKey,
  });

  final String key;
  final BuildContext context;
  final int? seq;
  final bool fromOther;
  final _FlatKind kind;
  final String? sectionKey;
}

class _MenuState {
  const _MenuState({
    required this.message,
    required this.own,
    required this.position,
    required this.actions,
  });

  final KunChatMessage message;
  final bool own;
  final Offset position;
  final List<KunChatMessageAction> actions;
}

class _KunChatMessageListState extends State<KunChatMessageList>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final ScrollController _scroll = ScrollController();
  final GlobalKey _centerKey = GlobalKey();
  final GlobalKey _scrollViewKey = GlobalKey();
  final Map<String, _MountedRow> _mounted = <String, _MountedRow>{};
  final Map<String, double> _heights = <String, double>{};
  final Map<String, BuildContext> _dayPills = <String, BuildContext>{};
  final Set<int> _visibleUnread = <int>{};

  late final AnimationController _fab;
  late final CurvedAnimation _fabCurve;
  late final AnimationController _flash;
  late final CurvedAnimation _flashCurve;
  KunChatMessageListController? _internalController;

  List<KunChatDaySection> _sections = const <KunChatDaySection>[];
  List<_FlatItem> _entries = const <_FlatItem>[];
  Map<String, int> _indexByKey = const <String, int>{};
  Map<int, String> _rowKeyBySeq = const <int, String>{};
  Map<String, KunChatListRow> _rowsByKey = const <String, KunChatListRow>{};
  List<KunChatMessage>? _groupedFor;
  int _groupedLength = 0;
  String? _groupedFirst;
  String? _groupedLast;
  String? _groupedUser;
  Duration? _groupedWindow;
  int? _groupedLastRead;

  bool _stuck = true;
  bool _positioned = false;
  bool _olderPending = false;
  bool _newerPending = false;
  bool _appResumed = true;
  bool _readScheduled = false;
  int _readUpTo = 0;
  String? _lastKey;
  bool _newerBefore = false;
  String? _focusKey;
  String? _highlightKey;
  String? _stickyDay;
  double _stickyPush = 0;
  _MenuState? _menu;
  String? _anchorKey;
  double? _anchorTop;
  bool _correctScheduled = false;
  bool _adjusting = false;

  KunChatMessageListController get _controller =>
      widget.controller ?? _internalController!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _internalController = KunChatMessageListController();
    }
    _controller._attach(this);
    _readUpTo = widget.lastReadSeq ?? 0;
    _newerBefore = widget.hasNewer;
    if (widget.messages.isNotEmpty) {
      _lastKey = kunChatMessageKey(widget.messages.last);
    }
    _fab = AnimationController(
      vsync: this,
      duration: KunDurations.base,
      reverseDuration: KunDurations.exit,
    );
    _fabCurve = CurvedAnimation(
      parent: _fab,
      curve: KunEasing.enter,
      reverseCurve: KunEasing.exit,
    );
    _flash = AnimationController(vsync: this, duration: _kFlash);
    _flashCurve = CurvedAnimation(parent: _flash, curve: _kFlashEase);
    _flash.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _highlightKey = null);
      }
    });
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addObserver(this);
    final AppLifecycleState? life = WidgetsBinding.instance.lifecycleState;
    _appResumed = life == null || life == AppLifecycleState.resumed;
    _regroup(force: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _positionInitially();
        _checkEdges();
        _syncFab();
        _scheduleRead();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fab.duration = kunMotion(context, KunDurations.base);
    _fab.reverseDuration = kunMotion(context, KunDurations.exit);
  }

  @override
  void didUpdateWidget(KunChatMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      if (oldWidget.controller != null) {
        oldWidget.controller!._detach(this);
      } else {
        _internalController?._detach(this);
        _internalController?.dispose();
        _internalController = null;
      }
      if (widget.controller == null) {
        _internalController = KunChatMessageListController();
      }
      _controller._attach(this);
      _controller._atBottom.value = _computeAtBottom();
    }
    if (oldWidget.lastReadSeq != widget.lastReadSeq &&
        widget.lastReadSeq != null &&
        widget.lastReadSeq! > _readUpTo) {
      _readUpTo = widget.lastReadSeq!;
    }
    final String? oldCid = oldWidget.messages.isEmpty
        ? null
        : oldWidget.messages.first.conversationId;
    final String? newCid =
        widget.messages.isEmpty ? null : widget.messages.first.conversationId;
    if (oldCid != null && newCid != oldCid) {
      _positioned = false;
      _lastKey = null;
      _readUpTo = widget.lastReadSeq ?? 0;
      _visibleUnread.clear();
      _stuck = true;
      _focusKey = null;
      _highlightKey = null;
      _menu = null;
      if (_scroll.hasClients) {
        _adjusting = true;
        _scroll.jumpTo(0);
        _adjusting = false;
      }
    }
    _pickAnchor();
    final String? prevLast = _lastKey;
    final bool newerBefore = _newerBefore;
    _regroup();
    _applyMessageDelta(
      prevLast: prevLast,
      newerBefore: newerBefore,
      oldCid: oldCid,
      newCid: newCid,
    );
    _newerBefore = widget.hasNewer;
    if (oldWidget.loadingOlder != widget.loadingOlder ||
        oldWidget.hasOlder != widget.hasOlder ||
        _edgeKey(oldWidget.messages, older: true) !=
            _edgeKey(widget.messages, older: true)) {
      _olderPending = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _checkEdges();
        }
      });
    }
    if (oldWidget.loadingNewer != widget.loadingNewer ||
        oldWidget.hasNewer != widget.hasNewer ||
        _edgeKey(oldWidget.messages, older: false) !=
            _edgeKey(widget.messages, older: false)) {
      _newerPending = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _checkEdges();
        }
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (!_positioned) {
        _positionInitially();
      }
      _measureHeights();
      _updateSticky();
      _syncFab();
      _scheduleRead();
      _checkEdges();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scroll.removeListener(_onScroll);
    _controller._detach(this);
    if (widget.controller == null) {
      _internalController?.dispose();
    }
    _flashCurve.dispose();
    _flash.dispose();
    _fabCurve.dispose();
    _fab.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appResumed = state == AppLifecycleState.resumed;
    if (_appResumed) {
      _scheduleRead();
    }
  }

  String _edgeKey(List<KunChatMessage> messages, {required bool older}) {
    if (messages.isEmpty) {
      return '';
    }
    return kunChatMessageKey(older ? messages.first : messages.last);
  }

  // A duplicate otherwise surfaces as the sliver's own
  // `indexOf(child) > index` assertion, which names no message.
  bool _debugAssertUniqueKeys(List<KunChatMessage> messages) {
    final Map<String, KunChatMessage> seen = <String, KunChatMessage>{};
    for (final KunChatMessage message in messages) {
      final String key = kunChatMessageKey(message);
      final KunChatMessage? earlier = seen[key];
      if (earlier != null) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary('KunChatMessageList.messages holds a message twice.'),
          ErrorDescription(
            'Messages seq ${earlier.seq} and seq ${message.seq} share the '
            'row key "$key" (client_message_id when set, else id).',
          ),
          ErrorHint(
            'Each message must appear once. A duplicate usually means a page '
            'was merged into the window twice, or a pending message was kept '
            'after the server confirmed it under the same client_message_id.',
          ),
        ]);
      }
      seen[key] = message;
    }
    return true;
  }

  void _regroup({bool force = false}) {
    final List<KunChatMessage> next = widget.messages;
    final String? first = next.isEmpty ? null : kunChatMessageKey(next.first);
    final String? last = next.isEmpty ? null : kunChatMessageKey(next.last);
    final bool changed = force ||
        !identical(_groupedFor, next) ||
        _groupedLength != next.length ||
        _groupedFirst != first ||
        _groupedLast != last ||
        _groupedUser != widget.currentUserId ||
        _groupedWindow != widget.groupWindow ||
        _groupedLastRead != widget.lastReadSeq;
    if (!changed) {
      return;
    }
    assert(_debugAssertUniqueKeys(next));
    KunChatMessageList.debugGroupComputations++;
    _sections = groupKunChatMessages(
      next,
      currentUserId: widget.currentUserId,
      lastReadSeq: widget.lastReadSeq,
      groupWindow: widget.groupWindow,
    );
    _groupedFor = next;
    _groupedLength = next.length;
    _groupedFirst = first;
    _groupedLast = last;
    _groupedUser = widget.currentUserId;
    _groupedWindow = widget.groupWindow;
    _groupedLastRead = widget.lastReadSeq;
    _rebuildEntries();
  }

  void _rebuildEntries() {
    final List<_FlatItem> items = <_FlatItem>[];
    final Map<String, int> indexByKey = <String, int>{};
    final Map<int, String> rowKeyBySeq = <int, String>{};
    final Map<String, KunChatListRow> rowsByKey = <String, KunChatListRow>{};
    for (int s = _sections.length - 1; s >= 0; s--) {
      final KunChatDaySection section = _sections[s];
      for (int r = section.rows.length - 1; r >= 0; r--) {
        final KunChatListRow row = section.rows[r];
        final _FlatKind kind = switch (row) {
          KunChatUnreadRow() => _FlatKind.unread,
          KunChatServiceRow() => _FlatKind.service,
          KunChatMessageRow() => _FlatKind.message,
        };
        items.add(
          _FlatItem(key: row.key, kind: kind, section: section, row: row),
        );
        if (row is! KunChatUnreadRow) {
          rowsByKey[row.key] = row;
          final List<KunChatMessage> members = row is KunChatMessageRow
              ? row.messages
              : <KunChatMessage>[(row as KunChatServiceRow).message];
          for (final KunChatMessage m in members) {
            if (m.seq > 0) {
              rowKeyBySeq[m.seq] = row.key;
            }
          }
        }
      }
      items.add(
        _FlatItem(
            key: 'day:${section.key}', kind: _FlatKind.day, section: section),
      );
    }
    for (int i = 0; i < items.length; i++) {
      indexByKey[items[i].key] = i;
    }
    _entries = items;
    _indexByKey = indexByKey;
    _rowKeyBySeq = rowKeyBySeq;
    _rowsByKey = rowsByKey;
  }

  void _applyMessageDelta({
    required String? prevLast,
    required bool newerBefore,
    required String? oldCid,
    required String? newCid,
  }) {
    final List<KunChatMessage> messages = widget.messages;
    final List<KunChatMessage> appended;
    if (prevLast == null || newerBefore) {
      appended = const <KunChatMessage>[];
    } else {
      final int prevIndex = messages.indexWhere(
        (KunChatMessage m) => kunChatMessageKey(m) == prevLast,
      );
      appended = prevIndex >= 0
          ? messages.sublist(prevIndex + 1)
          : const <KunChatMessage>[];
    }
    _lastKey = messages.isEmpty ? null : kunChatMessageKey(messages.last);

    if (oldCid != null && newCid != oldCid) {
      return;
    }

    if (!_positioned) {
      return;
    }

    if (appended.any(
      (KunChatMessage m) =>
          m.senderId == widget.currentUserId &&
          m.status == KunChatSendStatus.sending,
    )) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _scrollToBottom();
        }
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _correct();
        }
      });
    }

    final List<KunChatMessage> incoming = appended
        .where(
          (KunChatMessage m) =>
              m.senderId != widget.currentUserId &&
              m.kind == KunChatMessageKind.message,
        )
        .toList();
    if (incoming.length > _kAnnounceCap) {
      incoming.removeRange(0, incoming.length - _kAnnounceCap);
    }
    if (incoming.isNotEmpty) {
      final KunMessages catalog = KunMessagesScope.of(context);
      final Map<String, KunChatUser> users = kunChatUserMap(widget.users);
      for (final KunChatMessage m in incoming) {
        final String name = resolveKunChatUser(
          users,
          m.senderId,
          catalog,
        ).name;
        final String text = catalog.chat.senderPrefix(name: name) +
            kunChatPlainText(m, catalog);
        unawaited(
          SemanticsService.sendAnnouncement(
            View.of(context),
            text,
            Directionality.of(context),
          ),
        );
      }
    }
  }

  bool _computeAtBottom() {
    if (!_scroll.hasClients) {
      return true;
    }
    return _scroll.offset <= _kBottomThreshold;
  }

  void _onScroll() {
    if (_menu != null && !_adjusting) {
      _menu = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
        }
      });
    }
    final bool atBottom = _computeAtBottom();
    _stuck = atBottom && !widget.hasNewer;
    if (_controller._atBottom.value != atBottom) {
      _controller._atBottom.value = atBottom;
      _syncFab();
    }
    _pickAnchor();
    _checkEdges();
    _updateSticky();
    _scheduleRead();
  }

  void _syncFab() {
    final bool show = !_computeAtBottom() || widget.hasNewer;
    if (show) {
      if (_fab.status != AnimationStatus.forward &&
          _fab.status != AnimationStatus.completed) {
        _fab.forward();
      }
    } else {
      if (_fab.status != AnimationStatus.reverse &&
          _fab.status != AnimationStatus.dismissed) {
        _fab.reverse();
      }
    }
  }

  Rect? _viewportRect() {
    final BuildContext? ctx = _scrollViewKey.currentContext;
    if (ctx == null) {
      return null;
    }
    final RenderObject? object = ctx.findRenderObject();
    if (object is! RenderBox || !object.hasSize) {
      return null;
    }
    final Offset origin = object.localToGlobal(Offset.zero);
    return origin & object.size;
  }

  Rect? _boxOf(BuildContext? ctx) {
    if (ctx == null) {
      return null;
    }
    final RenderObject? object = ctx.findRenderObject();
    if (object is! RenderBox || !object.hasSize || !object.attached) {
      return null;
    }
    final Offset origin = object.localToGlobal(Offset.zero);
    return origin & object.size;
  }

  void _measureHeights() {
    for (final _MountedRow row in _mounted.values) {
      final Rect? box = _boxOf(row.context);
      if (box != null) {
        _heights[row.key] = box.height;
      }
    }
    for (final MapEntry<String, BuildContext> e in _dayPills.entries) {
      final Rect? box = _boxOf(e.value);
      if (box != null) {
        _heights['day:${e.key}'] = box.height;
      }
    }
  }

  void _pickAnchor() {
    final Rect? view = _viewportRect();
    if (view == null) {
      return;
    }
    String? found;
    double foundTop = double.negativeInfinity;
    for (final _MountedRow row in _mounted.values) {
      if (row.kind == _FlatKind.day) {
        continue;
      }
      final Rect? box = _boxOf(row.context);
      if (box == null) {
        continue;
      }
      if (box.top >= view.top && box.top < view.bottom && box.top >= foundTop) {
        foundTop = box.top;
        found = row.key;
      }
    }
    _anchorKey = found;
    _anchorTop = found == null ? null : foundTop;
  }

  void _scheduleCorrect() {
    if (_correctScheduled || !_positioned) {
      return;
    }
    _correctScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _correctScheduled = false;
      if (mounted) {
        _correct();
      }
    });
  }

  void _correct() {
    if (!_positioned) {
      return;
    }
    if (_stuck) {
      if (_scroll.hasClients && _scroll.offset != 0) {
        _adjusting = true;
        try {
          _scroll.jumpTo(0);
        } finally {
          _adjusting = false;
        }
      }
      _pickAnchor();
      return;
    }
    if (_anchorKey != null && _anchorTop != null) {
      final _MountedRow? row = _mounted[_anchorKey!];
      final Rect? box = _boxOf(row?.context);
      if (box != null && _scroll.hasClients) {
        final double delta = box.top - _anchorTop!;
        if (delta.abs() >= 0.5) {
          final double next = (_scroll.offset - delta).clamp(
            0.0,
            math.max(_scroll.position.maxScrollExtent, 0.0),
          );
          _adjusting = true;
          try {
            _scroll.jumpTo(next);
          } finally {
            _adjusting = false;
          }
        }
      }
    }
    _pickAnchor();
  }

  void _positionInitially() {
    if (_positioned || widget.messages.isEmpty) {
      return;
    }
    _positioned = true;
    final int? unreadIndex = _indexByKey['unread'];
    if (unreadIndex == null) {
      _stuck = !widget.hasNewer;
      _controller._atBottom.value = _computeAtBottom();
      _pickAnchor();
      return;
    }
    double unreadExtent = 0;
    for (int i = 0; i <= unreadIndex; i++) {
      unreadExtent += _heights[_entries[i].key] ?? _kIntrinsicRow;
    }
    final Rect? view = _viewportRect();
    final double viewH = view?.height ?? 0;
    if (viewH <= 0 || unreadExtent + _kUnreadTop <= viewH) {
      _stuck = !widget.hasNewer;
      _controller._atBottom.value = _computeAtBottom();
      _pickAnchor();
      return;
    }
    _stuck = false;
    _jumpToUnread();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _jumpToUnread();
          _pickAnchor();
        }
      });
    });
  }

  void _jumpToUnread() {
    final _MountedRow? row = _mounted['unread'];
    final Rect? box = _boxOf(row?.context);
    final Rect? view = _viewportRect();
    if (box == null || view == null || !_scroll.hasClients) {
      final int? index = _indexByKey['unread'];
      if (index != null && _scroll.hasClients) {
        _adjusting = true;
        _scroll.jumpTo(_estimateOffset(index));
        _adjusting = false;
      }
      return;
    }
    final double delta = box.top - view.top - _kUnreadTop;
    final double next = (_scroll.offset - delta).clamp(
      0.0,
      math.max(_scroll.position.maxScrollExtent, 0.0),
    );
    _adjusting = true;
    _scroll.jumpTo(next);
    _adjusting = false;
    _controller._atBottom.value = _computeAtBottom();
  }

  double _estimateOffset(int index) {
    double off = 0;
    if (widget.loadingNewer) {
      off += KunSpacing.unit * 3 * 2 + 20;
    }
    for (int i = 0; i < index && i < _entries.length; i++) {
      off += _heights[_entries[i].key] ?? _kIntrinsicRow;
    }
    return off;
  }

  bool _scrollToSeq(
    int seq, {
    required bool highlight,
    required bool animate,
  }) {
    final String? key = _rowKeyBySeq[seq];
    if (key == null) {
      return false;
    }
    final int? index = _indexByKey[key];
    if (index == null) {
      return false;
    }
    _stuck = false;
    void land({required bool smooth}) {
      if (!_scroll.hasClients) {
        return;
      }
      final _MountedRow? row = _mounted[key];
      final Rect? box = _boxOf(row?.context);
      final Rect? view = _viewportRect();
      double target = _estimateOffset(index);
      if (box != null && view != null) {
        final double offset = _offsetToShow(box, view, center: true);
        target = (_scroll.offset - offset).clamp(
          0.0,
          math.max(_scroll.position.maxScrollExtent, 0.0),
        );
      }
      if (smooth && !kunReducedMotion(context)) {
        unawaited(
          _scroll.animateTo(
            target,
            duration: kunMotion(context, KunDurations.base),
            curve: KunEasing.enter,
          ),
        );
      } else {
        _scroll.jumpTo(target);
      }
    }

    final Rect? view = _viewportRect();
    final double estimated = _estimateOffset(index);
    final double current = _scroll.hasClients ? _scroll.offset : 0;
    final bool far =
        view != null && (estimated - current).abs() > view.height * 2;
    if (far || !_mounted.containsKey(key)) {
      land(smooth: false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            land(smooth: false);
            _pickAnchor();
          }
        });
      });
    } else {
      land(smooth: animate);
    }
    if (highlight) {
      _highlightKey = key;
      _flash
        ..duration = _kFlash
        ..forward(from: 0);
      setState(() {});
    }
    _controller._atBottom.value = _computeAtBottom();
    return true;
  }

  double _offsetToShow(Rect row, Rect view, {required bool center}) {
    if (center && row.height <= view.height - 2 * _kJumpMargin) {
      return row.top - view.top - (view.height - row.height) / 2;
    }
    return row.top - view.top - _kJumpMargin;
  }

  void _scrollToBottom({bool animate = false}) {
    _stuck = !widget.hasNewer;
    if (!_scroll.hasClients) {
      return;
    }
    if (animate && !kunReducedMotion(context)) {
      unawaited(
        _scroll.animateTo(
          0,
          duration: kunMotion(context, KunDurations.base),
          curve: KunEasing.enter,
        ),
      );
    } else {
      _scroll.jumpTo(0);
    }
    _controller._atBottom.value = true;
    _syncFab();
    _pickAnchor();
  }

  void _checkEdges() {
    if (!_scroll.hasClients) {
      return;
    }
    final double offset = _scroll.offset;
    final double max = _scroll.position.maxScrollExtent;
    if (widget.hasOlder &&
        !widget.loadingOlder &&
        !_olderPending &&
        max - offset < _kEdgeMargin) {
      _olderPending = true;
      widget.onLoadOlder?.call();
    }
    if (widget.hasNewer &&
        !widget.loadingNewer &&
        !_newerPending &&
        offset < _kEdgeMargin) {
      _newerPending = true;
      widget.onLoadNewer?.call();
    }
  }

  void _scheduleRead() {
    if (_readScheduled) {
      return;
    }
    _readScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _readScheduled = false;
      if (mounted) {
        _flushRead();
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _flushRead() {
    if (!_appResumed) {
      return;
    }
    _collectVisible();
    if (_visibleUnread.isEmpty) {
      return;
    }
    final int max = _visibleUnread.reduce(math.max);
    _visibleUnread.clear();
    if (max > _readUpTo) {
      _readUpTo = max;
      widget.onRead?.call(max);
      setState(() {});
    }
  }

  void _collectVisible() {
    final Rect? view = _viewportRect();
    if (view == null) {
      return;
    }
    for (final _MountedRow row in _mounted.values) {
      if (!row.fromOther || row.seq == null || row.seq! <= _readUpTo) {
        continue;
      }
      final Rect? box = _boxOf(row.context);
      if (box != null && box.overlaps(view)) {
        _visibleUnread.add(row.seq!);
      }
    }
  }

  void _updateSticky() {
    final Rect? view = _viewportRect();
    if (view == null || _sections.isEmpty) {
      if (_stickyDay != null) {
        setState(() {
          _stickyDay = null;
          _stickyPush = 0;
        });
      }
      return;
    }
    const double stick = KunSpacing.unit * 2;
    String? current;
    double push = 0;
    for (int i = 0; i < _sections.length; i++) {
      final KunChatDaySection section = _sections[i];
      final Rect? pill = _boxOf(_dayPills[section.key]);
      final bool passed;
      if (pill != null) {
        passed = pill.top <= view.top + stick;
      } else {
        bool anyAbove = false;
        for (final _MountedRow row in _mounted.values) {
          if (row.sectionKey != section.key) {
            continue;
          }
          final Rect? box = _boxOf(row.context);
          if (box != null && box.top <= view.top + stick) {
            anyAbove = true;
            break;
          }
        }
        passed = anyAbove;
      }
      if (passed) {
        current = section.key;
      }
    }
    if (current != null) {
      final int index = _sections.indexWhere(
        (KunChatDaySection s) => s.key == current,
      );
      if (index >= 0 && index + 1 < _sections.length) {
        final Rect? pill = _boxOf(_dayPills[current]);
        final Rect? next = _boxOf(_dayPills[_sections[index + 1].key]);
        final double pillH =
            pill?.height ?? (KunText.xs.fontSize ?? 20) + KunSpacing.unit;
        if (next != null && next.top < view.top + stick + pillH) {
          push = next.top - (view.top + stick + pillH);
        }
      }
    }
    if (current != _stickyDay || push != _stickyPush) {
      setState(() {
        _stickyDay = current;
        _stickyPush = push;
      });
    }
  }

  void _registerRow(_MountedRow row) {
    _mounted[row.key] = row;
  }

  void _unregisterRow(String key, BuildContext context) {
    final _MountedRow? existing = _mounted[key];
    if (existing != null && identical(existing.context, context)) {
      _mounted.remove(key);
    }
  }

  void _registerDay(String key, BuildContext context) {
    _dayPills[key] = context;
  }

  void _unregisterDay(String key, BuildContext context) {
    if (identical(_dayPills[key], context)) {
      _dayPills.remove(key);
    }
  }

  String? get _activeKey {
    if (_focusKey != null && _rowsByKey.containsKey(_focusKey)) {
      return _focusKey;
    }
    for (final _FlatItem item in _entries) {
      if (item.kind == _FlatKind.message || item.kind == _FlatKind.service) {
        return item.key;
      }
    }
    return null;
  }

  List<String> get _focusableKeys {
    return <String>[
      for (final _FlatItem item in _entries)
        if (item.kind == _FlatKind.message || item.kind == _FlatKind.service)
          item.key,
    ];
  }

  void _moveFocus(_MoveFocusIntent intent) {
    final List<String> keys = _focusableKeys;
    if (keys.isEmpty) {
      return;
    }
    final String? current = _activeKey;
    int index = current == null ? 0 : keys.indexOf(current);
    if (index < 0) {
      index = 0;
    }
    if (intent.home) {
      index = keys.length - 1;
    } else if (intent.end) {
      index = 0;
    } else {
      index = (index - intent.delta).clamp(0, keys.length - 1);
    }
    final String next = keys[index];
    _focusKey = next;
    final _MountedRow? row = _mounted[next];
    if (row != null) {
      Focus.maybeOf(row.context)?.requestFocus();
    } else {
      final int? seq = _seqForKey(next);
      if (seq != null) {
        _scrollToSeq(seq, highlight: false, animate: false);
      }
    }
    setState(() {});
  }

  int? _seqForKey(String key) {
    final KunChatListRow? row = _rowsByKey[key];
    if (row is KunChatMessageRow) {
      return row.message.seq;
    }
    if (row is KunChatServiceRow) {
      return row.message.seq;
    }
    return null;
  }

  void _onReplyTap(int seq) {
    if (!_scrollToSeq(seq, highlight: true, animate: true)) {
      widget.onJump?.call(seq);
    }
  }

  void _openPhoto(KunChatMessageRow row, int photoIndex) {
    final List<KunChatMessage> rowPhotos = <KunChatMessage>[
      for (final KunChatMessage m in row.messages)
        if (m.media is KunChatPhoto) m,
    ];
    final KunChatMessage target =
        photoIndex >= 0 && photoIndex < rowPhotos.length
            ? rowPhotos[photoIndex]
            : row.message;
    final List<KunChatMessage> photos = <KunChatMessage>[
      for (final KunChatMessage m in widget.messages)
        if (m.media is KunChatPhoto) m,
    ];
    final int at = photos.indexWhere(
      (KunChatMessage m) => kunChatMessageKey(m) == kunChatMessageKey(target),
    );
    if (at < 0) {
      return;
    }
    final KunMessages catalog = KunMessagesScope.of(context);
    final Map<String, KunChatUser> users = kunChatUserMap(widget.users);
    showKunLightbox(
      context,
      images: <KunLightboxImage>[
        for (final KunChatMessage m in photos)
          KunLightboxImage(
            src: widget.resolveMediaUrl?.call(
                  m.media!,
                  KunChatMediaVariant.original,
                ) ??
                '',
            alt: catalog.chat.photoFrom(
              name: resolveKunChatUser(users, m.senderId, catalog).name,
            ),
          ),
      ],
      initialIndex: at,
    );
  }

  void _emitUser(KunChatUserEvent event) {
    widget.onUserTap?.call(event);
    if (!event.defaultPrevented) {
      final KunUIConfig config = KunUIConfigScope.of(context);
      config.navigateTo(context, config.userLinkForId(event.userId));
    }
  }

  KunChatBubblePosition _positionOf(KunChatMessageRow row) {
    if (row.groupStart && row.groupEnd) {
      return KunChatBubblePosition.single;
    }
    if (row.groupStart) {
      return KunChatBubblePosition.first;
    }
    if (row.groupEnd) {
      return KunChatBubblePosition.last;
    }
    return KunChatBubblePosition.middle;
  }

  KunChatSendStatus? _statusOf(KunChatMessageRow row) {
    if (!row.own) {
      return null;
    }
    final KunChatMessage m = row.messages.last;
    if (m.status != null) {
      return m.status;
    }
    return widget.peerReadSeq != null &&
            m.seq > 0 &&
            m.seq <= widget.peerReadSeq!
        ? KunChatSendStatus.read
        : KunChatSendStatus.sent;
  }

  int? _unreadSeq(KunChatListRow row) {
    final List<KunChatMessage> members = row is KunChatMessageRow
        ? row.messages
        : <KunChatMessage>[(row as KunChatServiceRow).message];
    if (row is KunChatMessageRow &&
        row.message.senderId == widget.currentUserId) {
      return null;
    }
    if (row is KunChatServiceRow &&
        row.message.senderId == widget.currentUserId) {
      return null;
    }
    int seq = 0;
    for (final KunChatMessage m in members) {
      if (m.seq > seq) {
        seq = m.seq;
      }
    }
    return seq > 0 ? seq : null;
  }

  List<KunChatMessageAction> _fallbackActions(
    KunChatMessage message,
    bool own,
  ) {
    return widget.actions?.call(message, own) ??
        const <KunChatMessageAction>[
          KunChatMessageAction.reply,
          KunChatMessageAction.copy,
        ];
  }

  void _openMenu({
    required KunChatMessageRow row,
    required Offset global,
  }) {
    final KunChatMessage message = row.message;
    final List<KunChatMessageAction> allowed = _fallbackActions(
      message,
      row.own,
    );
    final KunChatSendStatus? status = _statusOf(row);
    final List<KunChatMessageAction> actions = <KunChatMessageAction>[
      for (final KunChatMessageAction a in allowed)
        if (_keepAction(a, message, status)) a,
    ];
    setState(() {
      _menu = _MenuState(
        message: message,
        own: row.own,
        position: global,
        actions: actions,
      );
    });
  }

  bool _keepAction(
    KunChatMessageAction action,
    KunChatMessage message,
    KunChatSendStatus? status,
  ) {
    final String key = switch (action) {
      KunChatBuiltInAction(:final KunChatMessageActionKey key) => key.wireName,
      KunChatMessageMenuItem(:final String key) => key,
    };
    if (key == 'copy') {
      return message.text.isNotEmpty;
    }
    if (key == 'quote') {
      return false;
    }
    if (key == 'retry') {
      return status == KunChatSendStatus.failed;
    }
    return true;
  }

  void _menuAtRow(KunChatMessageRow row, BuildContext rowContext) {
    final Rect? box = _boxOf(rowContext);
    if (box == null) {
      return;
    }
    _openMenu(
      row: row,
      global: Offset(box.left + _kMenuAtRowX, box.bottom - _kMenuAtRowY),
    );
  }

  Future<void> _onMenuSelect(String action) async {
    final _MenuState? current = _menu;
    if (current == null) {
      return;
    }
    setState(() => _menu = null);
    if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: current.message.text));
      if (mounted) {
        showKunMessage(
          KunMessagesScope.of(context).chatMenu.copied,
          KunMessageType.success,
        );
      }
      widget.onAction?.call(action, current.message, null);
      return;
    }
    if (action == 'retry') {
      widget.onRetry?.call(current.message);
      return;
    }
    widget.onAction?.call(action, current.message, null);
  }

  void _onFab() {
    if (widget.hasNewer) {
      widget.onLatest?.call();
    } else {
      _scrollToBottom(animate: true);
    }
  }

  int get _fabCount {
    if (widget.unreadCount != null) {
      return widget.unreadCount!;
    }
    int count = 0;
    for (final KunChatMessage m in widget.messages) {
      if (m.senderId != widget.currentUserId && m.seq > _readUpTo) {
        count++;
      }
    }
    return count;
  }

  KunChatMessage? _resolveMessage(int seq) {
    for (final KunChatMessage m in widget.messages) {
      if (m.seq == seq) {
        return m;
      }
    }
    return null;
  }

  int? _findChildIndex(Key key) {
    if (key is! ValueKey<String>) {
      return null;
    }
    final String value = key.value;
    const String rowPrefix = 'KunChatMessageList.row.';
    const String dayPrefix = 'KunChatMessageList.day.';
    if (value.startsWith(rowPrefix)) {
      return _indexByKey[value.substring(rowPrefix.length)];
    }
    if (value.startsWith(dayPrefix)) {
      return _indexByKey['day:${value.substring(dayPrefix.length)}'];
    }
    if (value == 'KunChatMessageList.unread') {
      return _indexByKey['unread'];
    }
    return _indexByKey[value];
  }

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    final KunMessages catalog = KunMessagesScope.of(context);
    final String label = widget.semanticLabel ?? catalog.chat.messages;
    final Map<String, KunChatUser> users = kunChatUserMap(widget.users);
    String? stickyLabel;
    if (_stickyDay != null) {
      for (final KunChatDaySection section in _sections) {
        if (section.key == _stickyDay) {
          stickyLabel = formatKunChatDay(section.date, catalog.code, catalog);
          break;
        }
      }
    }
    return Semantics(
      role: SemanticsRole.region,
      label: label,
      explicitChildNodes: true,
      child: Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.arrowUp): _MoveFocusIntent(-1),
          SingleActivator(LogicalKeyboardKey.arrowDown): _MoveFocusIntent(1),
          SingleActivator(LogicalKeyboardKey.home): _MoveFocusIntent.home(),
          SingleActivator(LogicalKeyboardKey.end): _MoveFocusIntent.end(),
          SingleActivator(LogicalKeyboardKey.enter): ButtonActivateIntent(),
          SingleActivator(LogicalKeyboardKey.f10, shift: true):
              _OpenMenuIntent(),
          SingleActivator(LogicalKeyboardKey.contextMenu): _OpenMenuIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            _MoveFocusIntent: CallbackAction<_MoveFocusIntent>(
              onInvoke: (Intent intent) {
                _moveFocus(intent as _MoveFocusIntent);
                return null;
              },
            ),
            ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
              onInvoke: (Intent intent) {
                _openMenuForActive();
                return null;
              },
            ),
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (Intent intent) {
                _openMenuForActive();
                return null;
              },
            ),
            _OpenMenuIntent: CallbackAction<_OpenMenuIntent>(
              onInvoke: (Intent intent) {
                _openMenuForActive();
                return null;
              },
            ),
          },
          child: Focus(
            skipTraversal: true,
            child: Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.hardEdge,
              children: <Widget>[
                NotificationListener<Notification>(
                  onNotification: (Notification n) {
                    // Pointer-up with no movement lets the list's vertical
                    // drag win the arena as a zero-distance drag, which
                    // still dispatches ScrollStartNotification /
                    // ScrollEndNotification. The web closes the menu only
                    // when the list actually moves.
                    if (_menu != null &&
                        n is ScrollUpdateNotification &&
                        n.depth == 0 &&
                        (n.scrollDelta ?? 0) != 0 &&
                        !_adjusting) {
                      setState(() => _menu = null);
                    }
                    if (_menu != null &&
                        n is UserScrollNotification &&
                        n.direction != ScrollDirection.idle) {
                      setState(() => _menu = null);
                    }
                    if (n is SizeChangedLayoutNotification) {
                      _scheduleCorrect();
                    }
                    return false;
                  },
                  child: KeyedSubtree(
                    key: KunChatMessageList.scrollKey,
                    child: CustomScrollView(
                      key: _scrollViewKey,
                      controller: _scroll,
                      reverse: true,
                      center: _centerKey,
                      primary: false,
                      scrollCacheExtent: const ScrollCacheExtent.pixels(2500),
                      slivers: _slivers(scheme, catalog, users),
                    ),
                  ),
                ),
                if (stickyLabel != null)
                  Positioned(
                    top: KunSpacing.unit * 2 + _stickyPush,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: Center(
                        heightFactor: 1,
                        child: Semantics(
                          container: true,
                          child: _DayPill(
                            key: KunChatMessageList.stickyDayKey,
                            label: stickyLabel,
                            scheme: scheme,
                          ),
                        ),
                      ),
                    ),
                  ),
                _ScrollFab(
                  animation: _fabCurve,
                  count: _fabCount,
                  scheme: scheme,
                  catalog: catalog,
                  onPressed: _onFab,
                ),
                KunChatMessageMenu(
                  visible: _menu != null,
                  position: _menu?.position,
                  actions: _menu?.actions ?? const <KunChatMessageAction>[],
                  reactions: _menu != null &&
                          _menu!.message.kind == KunChatMessageKind.message
                      ? widget.reactionOptions
                      : const <KunChatReactionOption>[],
                  currentReaction: _menu?.message.reactions
                      .where((KunChatReaction r) => r.reacted)
                      .map((KunChatReaction r) => r.reaction)
                      .firstOrNull,
                  onClose: () => setState(() => _menu = null),
                  onReact: (String? reaction) {
                    final KunChatMessage? message = _menu?.message;
                    setState(() => _menu = null);
                    if (message != null) {
                      widget.onReact?.call(message, reaction);
                    }
                  },
                  onSelect: _onMenuSelect,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openMenuForActive() {
    final String? key = _activeKey;
    if (key == null) {
      return;
    }
    final KunChatListRow? row = _rowsByKey[key];
    final _MountedRow? mounted = _mounted[key];
    if (row is KunChatMessageRow && mounted != null) {
      _menuAtRow(row, mounted.context);
    }
  }

  List<Widget> _slivers(
    KunColorScheme scheme,
    KunMessages catalog,
    Map<String, KunChatUser> users,
  ) {
    return <Widget>[
      SliverToBoxAdapter(
        key: _centerKey,
        child: const SizedBox.shrink(),
      ),
      if (widget.footer != null) SliverToBoxAdapter(child: widget.footer),
      if (widget.loadingNewer)
        SliverToBoxAdapter(
          key: KunChatMessageList.newerSpinnerKey,
          child: _edgeSpinner(scheme, catalog),
        ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(vertical: KunSpacing.unit * 2),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
              return _buildEntry(_entries[index], scheme, catalog, users);
            },
            childCount: _entries.length,
            findChildIndexCallback: _findChildIndex,
            addAutomaticKeepAlives: false,
          ),
        ),
      ),
      if (widget.loadingOlder)
        SliverToBoxAdapter(
          key: KunChatMessageList.olderSpinnerKey,
          child: _edgeSpinner(scheme, catalog),
        ),
      if (!widget.hasOlder &&
          widget.messages.isNotEmpty &&
          widget.start != null)
        SliverToBoxAdapter(child: widget.start),
      if (widget.messages.isEmpty && !widget.loadingOlder)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: KunSpacing.unit * 10,
            ),
            child: DefaultTextStyle(
              style: KunText.sm.copyWith(color: scheme.neutral.shade500),
              textAlign: TextAlign.center,
              child: widget.empty ?? Text(catalog.chat.empty),
            ),
          ),
        ),
      const SliverToBoxAdapter(child: SizedBox(height: 1)),
    ];
  }

  Widget _edgeSpinner(KunColorScheme scheme, KunMessages catalog) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: KunSpacing.unit * 3),
      child: Center(
        child: IconTheme(
          data: IconThemeData(
            color: scheme.neutral.shade500,
            size: KunText.xl.fontSize,
          ),
          child: KunSpinner(
            size: KunText.xl.fontSize ?? 20,
            semanticLabel: catalog.chat.loading,
          ),
        ),
      ),
    );
  }

  Widget _buildEntry(
    _FlatItem item,
    KunColorScheme scheme,
    KunMessages catalog,
    Map<String, KunChatUser> users,
  ) {
    final Key sliverKey = switch (item.kind) {
      _FlatKind.day => KunChatMessageList.dayKey(item.section!.key),
      _FlatKind.unread => KunChatMessageList.unreadKey,
      _ => KunChatMessageList.rowKey(item.key),
    };
    return KeyedSubtree(
      key: sliverKey,
      child: SizeChangedLayoutNotifier(
        child: switch (item.kind) {
          _FlatKind.day => _DayInFlow(
              dayKey: item.section!.key,
              label: formatKunChatDay(
                item.section!.date,
                catalog.code,
                catalog,
              ),
              scheme: scheme,
              hidden: _stickyDay == item.section!.key,
              onRegister: _registerDay,
              onUnregister: _unregisterDay,
            ),
          _FlatKind.unread => _UnreadDivider(
              scheme: scheme,
              label: catalog.chat.unreadDivider,
              onRegister: (BuildContext ctx) {
                _registerRow(
                  _MountedRow(
                    key: 'unread',
                    context: ctx,
                    seq: null,
                    fromOther: false,
                    kind: _FlatKind.unread,
                    sectionKey: item.section?.key,
                  ),
                );
              },
              onUnregister: (BuildContext ctx) => _unregisterRow('unread', ctx),
            ),
          _FlatKind.service => _ServiceListRow(
              row: item.row! as KunChatServiceRow,
              scheme: scheme,
              users: widget.users,
              currentUserId: widget.currentUserId,
              resolveMessage: _resolveMessage,
              highlighted: _highlightKey == item.key,
              flash: _flashCurve,
              focused: _activeKey == item.key,
              skipTraversal: _activeKey != item.key,
              onRegister: (BuildContext ctx) {
                final KunChatServiceRow row = item.row! as KunChatServiceRow;
                _registerRow(
                  _MountedRow(
                    key: row.key,
                    context: ctx,
                    seq: _unreadSeq(row),
                    fromOther: row.message.senderId != widget.currentUserId,
                    kind: _FlatKind.service,
                    sectionKey: item.section?.key,
                  ),
                );
              },
              onUnregister: (BuildContext ctx) => _unregisterRow(item.key, ctx),
              onFocus: () => setState(() => _focusKey = item.key),
            ),
          _FlatKind.message => _MessageListRow(
              row: item.row! as KunChatMessageRow,
              kind: widget.kind,
              scheme: scheme,
              catalog: catalog,
              users: widget.users,
              userMap: users,
              currentUserId: widget.currentUserId,
              reactionOptions: widget.reactionOptions,
              resolveMediaUrl: widget.resolveMediaUrl,
              resolveMessage: _resolveMessage,
              swipeToReply: widget.swipeToReply,
              position: _positionOf(item.row! as KunChatMessageRow),
              status: _statusOf(item.row! as KunChatMessageRow),
              highlighted: _highlightKey == item.key,
              flash: _flashCurve,
              focused: _activeKey == item.key,
              skipTraversal: _activeKey != item.key,
              onRegister: (BuildContext ctx) {
                final KunChatMessageRow row = item.row! as KunChatMessageRow;
                _registerRow(
                  _MountedRow(
                    key: row.key,
                    context: ctx,
                    seq: _unreadSeq(row),
                    fromOther: !row.own,
                    kind: _FlatKind.message,
                    sectionKey: item.section?.key,
                  ),
                );
              },
              onUnregister: (BuildContext ctx) => _unregisterRow(item.key, ctx),
              onFocus: () => setState(() => _focusKey = item.key),
              onOpenMenu: (Offset global) => _openMenu(
                row: item.row! as KunChatMessageRow,
                global: global,
              ),
              onSwipeReply: () => widget.onAction?.call(
                'reply',
                (item.row! as KunChatMessageRow).message,
                null,
              ),
              onReplyTap: _onReplyTap,
              onReact: (String? reaction) => widget.onReact?.call(
                (item.row! as KunChatMessageRow).message,
                reaction,
              ),
              onRetry: () {
                final KunChatMessageRow row = item.row! as KunChatMessageRow;
                widget.onRetry?.call(row.messages.last);
              },
              onPhotoTap: (int index) =>
                  _openPhoto(item.row! as KunChatMessageRow, index),
              onUserTap: _emitUser,
              onMention: widget.onMention,
              onLink: widget.onLink,
            ),
        },
      ),
    );
  }
}
