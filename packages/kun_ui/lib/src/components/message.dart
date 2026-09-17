import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:kun_ui_icons/kun_ui_icons.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../foundation/design.dart';
import '../foundation/focus_outline.dart';
import '../foundation/motion.dart';
import '../foundation/outer_shadow.dart';
import '../locale/messages.dart';
import '../theme/theme.dart';

part 'message_item.dart';

/// Web type `KunMessageType`.
enum KunMessageType {
  /// A warning toast.
  warn,

  /// A success toast.
  success,

  /// An error toast.
  error,

  /// An informational toast.
  info,
}

/// Web type `KunMessagePosition` (`top-center` → [topCenter], …).
enum KunMessagePosition {
  /// Web `top-center`.
  topCenter,

  /// Web `top-left`.
  topLeft,

  /// Web `top-right`.
  topRight,

  /// Web `bottom-center`.
  bottomCenter,

  /// Web `bottom-left`.
  bottomLeft,

  /// Web `bottom-right`.
  bottomRight,
}

/// Web `useKunMessage(message, type, duration, richText, position)`.
///
/// Needs no [BuildContext], so a repository or a notifier can call it. Returns
/// the toast's id, which is the existing id when an identical toast (same
/// [message], [type] and [position]) is already showing. A [duration] of zero
/// or less keeps the toast until it is closed. `richText` is not ported: it is
/// HTML.
///
/// Mount [KunMessageProvider] once around the app navigator. A call while
/// none is mounted still enters the store and prints once, in a debug build,
/// that the provider is missing.
String showKunMessage(
  String message,
  KunMessageType type, {
  Duration duration = const Duration(milliseconds: 3000),
  KunMessagePosition position = KunMessagePosition.topCenter,
}) {
  return _KunMessageStore.instance.show(
    message: message,
    type: type,
    duration: duration,
    position: position,
  );
}

/// Web `useKunMessageState().removeMessage(id)`.
///
/// Removes that toast with its leave animation. An unknown [id] does nothing.
void dismissKunMessage(String id) {
  _KunMessageStore.instance.dismiss(id);
}

/// Web `<KunMessageProvider />`.
///
/// Mount **once**, around the app's navigator:
///
/// ```dart
/// WidgetsApp(
///   builder: (BuildContext context, Widget? child) =>
///       KunMessageProvider(child: child!),
///   // MaterialApp.builder and CupertinoApp.builder are the same parameter.
/// )
/// ```
///
/// It must sit under [KunTheme] and inside the app shell, because it needs
/// [Directionality] and [MediaQuery]. Toasts then render above every route, a
/// [KunModal] included. The theme and language are the ones in force where
/// this provider sits.
///
/// Two mounted providers both render every toast, as on the web.
class KunMessageProvider extends StatefulWidget {
  /// Creates the toast host around [child].
  const KunMessageProvider({super.key, required this.child});

  /// The app tree the toasts float above, typically the navigator.
  final Widget child;

  @override
  State<KunMessageProvider> createState() => _KunMessageProviderState();
}

/// Clears the store and the one-time missing-host warning flag, for tests.
@visibleForTesting
void debugResetKunMessages() {
  _KunMessageStore.instance.reset();
}

class _KunMessageData {
  _KunMessageData({
    required this.id,
    required this.message,
    required this.type,
    required this.duration,
    required this.position,
    required this.count,
  });

  final String id;
  final String message;
  final KunMessageType type;
  Duration duration;
  final KunMessagePosition position;
  int count;
}

class _KunMessageStore extends ChangeNotifier {
  _KunMessageStore._();

  static final _KunMessageStore instance = _KunMessageStore._();

  static const int _maxVisiblePerPosition = 5;

  final List<_KunMessageData> messages = <_KunMessageData>[];
  int seed = 0;
  int hostCount = 0;
  bool warned = false;
  int generation = 0;

  String show({
    required String message,
    required KunMessageType type,
    required Duration duration,
    required KunMessagePosition position,
  }) {
    assert(() {
      if (hostCount == 0 && !warned) {
        warned = true;
        debugPrint(
          '[KunMessage] no KunMessageProvider is mounted. Mount it once '
          'around the app navigator: WidgetsApp.builder: (context, child) => '
          'KunMessageProvider(child: child!). The toast is stored and will '
          'show when a provider mounts.',
        );
      }
      return true;
    }());

    for (final _KunMessageData existing in messages) {
      if (existing.message == message &&
          existing.type == type &&
          existing.position == position) {
        existing.count += 1;
        existing.duration = duration;
        notifyListeners();
        return existing.id;
      }
    }

    seed += 1;
    final _KunMessageData created = _KunMessageData(
      id: 'message_$seed',
      message: message,
      type: type,
      duration: duration,
      position: position,
      count: 1,
    );
    if (position._isTop) {
      messages.add(created);
    } else {
      messages.insert(0, created);
    }

    final List<_KunMessageData> same = <_KunMessageData>[
      for (final _KunMessageData item in messages)
        if (item.position == position) item,
    ];
    if (same.length > _maxVisiblePerPosition) {
      final _KunMessageData oldest = position._isTop ? same.first : same.last;
      messages.removeWhere((_KunMessageData item) => item.id == oldest.id);
    }

    notifyListeners();
    return created.id;
  }

  void dismiss(String id) {
    final int index =
        messages.indexWhere((_KunMessageData item) => item.id == id);
    if (index < 0) {
      return;
    }
    messages.removeAt(index);
    notifyListeners();
  }

  void reset() {
    messages.clear();
    seed = 0;
    warned = false;
    generation += 1;
    notifyListeners();
  }
}

class _KunMessageSlot {
  _KunMessageSlot(this.data);

  _KunMessageData data;
  bool leaving = false;
  bool thrown = false;
  Timer? removeTimer;

  void dispose() {
    removeTimer?.cancel();
  }
}

class _KunMessageProviderState extends State<KunMessageProvider> {
  final List<_KunMessageSlot> _slots = <_KunMessageSlot>[];
  int _generation = 0;

  _KunMessageStore get _store => _KunMessageStore.instance;

  @override
  void initState() {
    super.initState();
    _store.hostCount += 1;
    _store.addListener(_onStore);
    _generation = _store.generation;
    for (final _KunMessageData data in _store.messages) {
      _slots.add(_KunMessageSlot(data));
    }
  }

  @override
  void dispose() {
    _store.removeListener(_onStore);
    _store.hostCount -= 1;
    for (final _KunMessageSlot slot in _slots) {
      slot.dispose();
    }
    super.dispose();
  }

  void _onStore() {
    if (!mounted) {
      return;
    }
    if (_store.generation != _generation) {
      _generation = _store.generation;
      for (final _KunMessageSlot slot in _slots) {
        slot.dispose();
      }
      _slots
        ..clear()
        ..addAll(<_KunMessageSlot>[
          for (final _KunMessageData data in _store.messages)
            _KunMessageSlot(data),
        ]);
      setState(() {});
      return;
    }
    _syncSlots();
    setState(() {});
  }

  void _syncSlots() {
    final Set<String> liveIds = <String>{
      for (final _KunMessageData data in _store.messages) data.id,
    };
    final Map<String, _KunMessageSlot> byId = <String, _KunMessageSlot>{
      for (final _KunMessageSlot slot in _slots) slot.data.id: slot,
    };

    for (final _KunMessageSlot slot in List<_KunMessageSlot>.of(_slots)) {
      if (!liveIds.contains(slot.data.id) && !slot.leaving) {
        _beginLeave(slot);
      }
    }

    for (int i = 0; i < _store.messages.length; i++) {
      final _KunMessageData data = _store.messages[i];
      final _KunMessageSlot? existing = byId[data.id];
      if (existing != null) {
        existing.data = data;
        continue;
      }
      int insertAt = 0;
      if (i > 0) {
        final String prevId = _store.messages[i - 1].id;
        final int prevIndex = _slots.indexWhere(
          (_KunMessageSlot slot) => slot.data.id == prevId,
        );
        insertAt = prevIndex >= 0 ? prevIndex + 1 : _slots.length;
      }
      final _KunMessageSlot slot = _KunMessageSlot(data);
      _slots.insert(insertAt, slot);
      byId[data.id] = slot;
    }
  }

  void _beginLeave(_KunMessageSlot slot) {
    if (slot.leaving) {
      return;
    }
    final Duration collapse = kunMotion(context, KunDurations.base);
    final Duration visual = slot.thrown
        ? kunMotion(context, KunDurations.exit)
        : kunMotion(context, KunDurations.base);
    final Duration wait = collapse >= visual ? collapse : visual;
    if (wait <= Duration.zero) {
      slot.dispose();
      _slots.remove(slot);
      return;
    }
    slot.leaving = true;
    _scheduleRemove(slot, wait);
  }

  void _scheduleRemove(_KunMessageSlot slot, Duration wait) {
    slot.removeTimer?.cancel();
    slot.removeTimer = Timer(wait, () {
      if (!mounted || !_slots.contains(slot)) {
        return;
      }
      setState(() {
        _slots.remove(slot);
        slot.dispose();
      });
    });
  }

  void _requestDismiss(_KunMessageSlot slot, {required bool thrown}) {
    if (thrown) {
      slot.thrown = true;
    }
    dismissKunMessage(slot.data.id);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        widget.child,
        for (final KunMessagePosition position in KunMessagePosition.values)
          _buildPosition(context, position),
      ],
    );
  }

  Widget _buildPosition(BuildContext context, KunMessagePosition position) {
    final MediaQueryData media = MediaQuery.of(context);
    final double pad = KunSpacing.unit * 4;
    final double containerWidth = math.min(
      media.size.width,
      KunContainerWidths.sm,
    );
    final double contentWidth = math.max(0.0, containerWidth - pad * 2);
    final double left = switch (position) {
      KunMessagePosition.topLeft ||
      KunMessagePosition.bottomLeft =>
        media.viewPadding.left + pad * 2,
      KunMessagePosition.topRight ||
      KunMessagePosition.bottomRight =>
        media.size.width - media.viewPadding.right - containerWidth,
      KunMessagePosition.topCenter ||
      KunMessagePosition.bottomCenter =>
        (media.size.width - containerWidth) / 2 + pad,
    };
    final double? top =
        position._isTop ? media.viewPadding.top + pad * 2 : null;
    final double? bottom = position._isTop
        ? null
        : media.viewPadding.bottom + media.viewInsets.bottom + pad * 2;
    final List<_KunMessageSlot> slots = <_KunMessageSlot>[
      for (final _KunMessageSlot slot in _slots)
        if (slot.data.position == position) slot,
    ];
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      width: contentWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final _KunMessageSlot slot in slots)
            AnimatedAlign(
              key: ValueKey<String>(slot.data.id),
              duration: kunMotion(context, KunDurations.base),
              curve: KunEasing.emphasized,
              alignment: position._isTop
                  ? Alignment.topCenter
                  : Alignment.bottomCenter,
              heightFactor: slot.leaving ? 0.0 : 1.0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _KunMessageToast(
                    id: slot.data.id,
                    message: slot.data.message,
                    type: slot.data.type,
                    duration: slot.data.duration,
                    position: slot.data.position,
                    count: slot.data.count,
                    leaving: slot.leaving,
                    throwLeaving: slot.thrown,
                    onRequestDismiss: ({required bool thrown}) {
                      _requestDismiss(slot, thrown: thrown);
                    },
                  ),
                  const IgnorePointer(
                    child: SizedBox(height: KunSpacing.unit * 3),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

extension on KunMessagePosition {
  bool get _isTop =>
      this == KunMessagePosition.topCenter ||
      this == KunMessagePosition.topLeft ||
      this == KunMessagePosition.topRight;
}
