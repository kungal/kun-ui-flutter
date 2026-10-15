import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'command_palette.dart';

/// One [HardwareKeyboard] handler shared by every [KunCommandSearch] and
/// [KunCommandPalette].
///
/// On the web a visible search listens in the capture phase and
/// `preventDefault`s, so a palette on the same page stands down. Flutter's
/// [HardwareKeyboard] runs every handler, so "already consumed" is
/// invisible unless one coordinator asks in order: eligible searches first,
/// then palettes.
class KunCommandShortcutCoordinator {
  KunCommandShortcutCoordinator._();

  /// The process-wide coordinator. One handler is installed while any
  /// client is registered.
  static final KunCommandShortcutCoordinator instance =
      KunCommandShortcutCoordinator._();

  final List<KunCommandShortcutRegistration> _searches =
      <KunCommandShortcutRegistration>[];
  final List<KunCommandShortcutRegistration> _palettes =
      <KunCommandShortcutRegistration>[];
  bool _installed = false;

  /// Registers a [KunCommandSearch]. Asked before any palette.
  KunCommandShortcutRegistration registerSearch({
    required KunCommandShortcut Function() shortcut,
    required bool Function() eligible,
    required VoidCallback activate,
  }) {
    final KunCommandShortcutRegistration registration =
        KunCommandShortcutRegistration._(
      coordinator: this,
      shortcut: shortcut,
      eligible: eligible,
      activate: activate,
    );
    _searches.add(registration);
    _install();
    return registration;
  }

  /// Registers a [KunCommandPalette]. Asked after every eligible search.
  KunCommandShortcutRegistration registerPalette({
    required KunCommandShortcut Function() shortcut,
    required bool Function() eligible,
    required VoidCallback activate,
  }) {
    final KunCommandShortcutRegistration registration =
        KunCommandShortcutRegistration._(
      coordinator: this,
      shortcut: shortcut,
      eligible: eligible,
      activate: activate,
    );
    _palettes.add(registration);
    _install();
    return registration;
  }

  void _unregister(KunCommandShortcutRegistration registration) {
    _searches.remove(registration);
    _palettes.remove(registration);
    if (_searches.isEmpty && _palettes.isEmpty) {
      _uninstall();
    }
  }

  void _install() {
    if (_installed) {
      return;
    }
    HardwareKeyboard.instance.addHandler(_onKey);
    _installed = true;
  }

  void _uninstall() {
    if (!_installed) {
      return;
    }
    HardwareKeyboard.instance.removeHandler(_onKey);
    _installed = false;
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return false;
    }
    if (event.logicalKey == LogicalKeyboardKey.controlLeft ||
        event.logicalKey == LogicalKeyboardKey.controlRight ||
        event.logicalKey == LogicalKeyboardKey.metaLeft ||
        event.logicalKey == LogicalKeyboardKey.metaRight ||
        event.logicalKey == LogicalKeyboardKey.control ||
        event.logicalKey == LogicalKeyboardKey.meta) {
      return false;
    }
    if (!HardwareKeyboard.instance.isControlPressed &&
        !HardwareKeyboard.instance.isMetaPressed) {
      return false;
    }
    final String label = event.logicalKey.keyLabel.toLowerCase();
    if (label.isEmpty) {
      return false;
    }
    for (final KunCommandShortcutRegistration client in _searches) {
      if (_matches(client, label) && client._eligible()) {
        client._activate();
        return true;
      }
    }
    for (final KunCommandShortcutRegistration client in _palettes) {
      if (_matches(client, label) && client._eligible()) {
        client._activate();
        return true;
      }
    }
    return false;
  }

  bool _matches(KunCommandShortcutRegistration client, String label) {
    final String? character = client._shortcut().character;
    return character != null && character == label;
  }
}

/// A [KunCommandShortcutCoordinator] registration. Call [unregister] from
/// [State.dispose].
class KunCommandShortcutRegistration {
  KunCommandShortcutRegistration._({
    required KunCommandShortcutCoordinator coordinator,
    required KunCommandShortcut Function() shortcut,
    required bool Function() eligible,
    required VoidCallback activate,
  })  : _coordinator = coordinator,
        _shortcut = shortcut,
        _eligible = eligible,
        _activate = activate;

  final KunCommandShortcutCoordinator _coordinator;
  final KunCommandShortcut Function() _shortcut;
  final bool Function() _eligible;
  final VoidCallback _activate;

  /// Removes this client. Safe to call twice.
  void unregister() => _coordinator._unregister(this);
}
