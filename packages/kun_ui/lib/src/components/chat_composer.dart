import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:kun_ui_icons/kun_ui_icons.dart';
import 'package:kun_ui_messages/kun_ui_messages.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../chat/constants.dart';
import '../chat/markdown.dart';
import '../chat/support.dart';
import '../chat/types.dart';
import '../foundation/motion.dart';
import '../foundation/tap_target.dart';
import '../foundation/text_selection.dart';
import '../locale/messages.dart';
import '../theme/theme.dart';
import 'chat_text.dart';

/// Web `ChatComposer.vue:99` — the counter appears in the last 200.
const int _kCounterFrom = 200;

/// Web `size-16` attachment thumbnail.
const double _kThumbSize = KunSpacing.unit * 16;

/// Web `h-1` progress track.
const double _kProgressHeight = KunSpacing.unit;

/// A photo listed on [KunChatComposer] while the app uploads it.
///
/// [image] replaces the web's object-URL `url`: a Flutter app already holds
/// bytes or a file, not a blob URL.
@immutable
class KunChatAttachment {
  /// Creates an attachment chip.
  const KunChatAttachment({
    required this.key,
    this.image,
    this.name,
    this.progress,
    this.error = false,
  });

  /// Identifies the chip to [KunChatComposer.onRemoveAttachment] and
  /// [KunChatComposer.onRetryAttachment].
  final String key;

  /// Thumbnail. Null draws an empty well.
  final ImageProvider? image;

  /// File name, used as the image's accessible name.
  final String? name;

  /// Upload progress from 0 to 1; omitted when unknown or done.
  final double? progress;

  /// The upload failed: the chip is a retry button.
  final bool error;

  @override
  bool operator ==(Object other) =>
      other is KunChatAttachment &&
      other.key == key &&
      other.image == image &&
      other.name == name &&
      other.progress == progress &&
      other.error == error;

  @override
  int get hashCode => Object.hash(key, image, name, progress, error);
}

/// The message input: auto-growing text, reply / quote / edit bar, and an
/// attachment strip.
///
/// The web takes files from a hidden `<input type=file>`, from paste and
/// from drop. Flutter has no framework file picker, and clipboard images
/// and file drop need plugins, which this library does not take. The
/// paperclip button fires [onAttach] so the **app** can open its own picker
/// and pass the results back through [attachments]. Paste of images and
/// drag-and-drop are not implemented; the locale `dropHint` string is
/// unused.
///
/// The value is controlled like [KunTextarea]: pass [value] and rebuild
/// with what [onChanged] gives you (the web's `v-model`). A [controller]
/// is the alternative when the caller needs the selection. Like every
/// Flutter text field, it needs an [Overlay] ancestor.
class KunChatComposer extends StatefulWidget {
  /// Creates a chat composer.
  const KunChatComposer({
    super.key,
    this.value = '',
    this.onChanged,
    this.replyTo,
    this.onReplyToChanged,
    this.quote,
    this.onQuoteChanged,
    this.editing,
    this.onEditingChanged,
    this.attachments = const <KunChatAttachment>[],
    this.disabled = false,
    this.disabledText = '',
    this.maxRows = 8,
    this.maxLength = kunChatTextLimit,
    this.placeholder,
    this.users = const <KunChatUser>[],
    this.enterToSend,
    this.onSend,
    this.onEdit,
    this.onEditLast,
    this.onAttach,
    this.onRemoveAttachment,
    this.onRetryAttachment,
    this.onTyping,
    this.prefix,
    this.suffix,
    this.controller,
    this.focusNode,
    this.contentInsertionConfiguration,
  })  : assert(maxRows > 0),
        assert(maxLength > 0),
        assert(
          controller == null || value == '',
          'Pass the text through the controller instead of [value].',
        );

  /// The input as typed, shortcuts included (web `modelValue`).
  final String value;

  /// Called on every committed edit (web `update:modelValue`).
  final ValueChanged<String>? onChanged;

  /// The message being replied to. Cleared on send and on cancel.
  final KunChatMessage? replyTo;

  /// Called when the reply is consumed or cancelled (web `update:replyTo`).
  final ValueChanged<KunChatMessage?>? onReplyToChanged;

  /// The quoted part of [replyTo], from the message menu's quote.
  final KunChatReplyQuote? quote;

  /// Called when the quote is consumed or cancelled (web `update:quote`).
  final ValueChanged<KunChatReplyQuote?>? onQuoteChanged;

  /// The message being edited. Setting it puts the message in the input
  /// (the draft is kept aside and comes back when editing ends); [onEdit]
  /// fires instead of [onSend].
  final KunChatMessage? editing;

  /// Called when editing starts or ends (web `update:editing`).
  final ValueChanged<KunChatMessage?>? onEditingChanged;

  /// Photos being uploaded for this message, shown above the input.
  final List<KunChatAttachment> attachments;

  /// Replace the input row with [disabledText]. The reply/edit bar and
  /// attachment strip stay interactive, as on the web.
  final bool disabled;

  /// Why sending is not possible, shown in place of the input.
  final String disabledText;

  /// Growth limit of the input, in lines, before it scrolls.
  final int maxRows;

  /// Longest message, counted on the parsed text. The counter shows in the
  /// last 200. Defaults to [kunChatTextLimit].
  final int maxLength;

  /// Placeholder text. Defaults to the locale `chatComposer.placeholder`.
  final String? placeholder;

  /// Users, to name whoever a reply is to.
  final List<KunChatUser> users;

  /// Enter sends and Shift+Enter inserts a newline when true. Ctrl/Meta+Enter
  /// sends and Enter inserts a newline when false. Null (the web's `'auto'`):
  /// on Android and iOS Enter inserts a newline and the send button sends;
  /// elsewhere it behaves like true.
  final bool? enterToSend;

  /// Send a new message. The input is cleared and the reply consumed.
  final ValueChanged<KunChatFormattedText>? onSend;

  /// Save an edit of [target]. Editing ends and the draft comes back.
  final void Function(KunChatFormattedText message, KunChatMessage target)?
      onEdit;

  /// ↑ in an empty input: start editing the viewer's last message, as
  /// Telegram Desktop does.
  final VoidCallback? onEditLast;

  /// The paperclip was pressed (web `attach`). The app opens its own picker
  /// and lists the results in [attachments]; this library does not pick
  /// files.
  final VoidCallback? onAttach;

  /// The × of an attachment was clicked.
  final ValueChanged<String>? onRemoveAttachment;

  /// A failed attachment was clicked: upload it again.
  final ValueChanged<String>? onRetryAttachment;

  /// The user is typing: at most once per [kunChatTypingInterval], never
  /// while editing.
  final VoidCallback? onTyping;

  /// Before the input, after the attach button, e.g. an emoji button.
  final Widget? prefix;

  /// After the input, before the send button.
  final Widget? suffix;

  /// Holds the text in place of [value], for a caller that edits it
  /// programmatically. The caller owns the controller and disposes it.
  final TextEditingController? controller;

  /// Lets the caller move focus to the field. The caller owns the node
  /// and disposes it.
  final FocusNode? focusNode;

  /// Lets Gboard insert images, GIFs and stickers through `commitContent`.
  /// Flutter-only: on the web the browser handles paste and insertion. Null
  /// changes nothing.
  final ContentInsertionConfiguration? contentInsertionConfiguration;

  @override
  State<KunChatComposer> createState() => _KunChatComposerState();
}

class _KunChatComposerState extends State<KunChatComposer>
    implements TextSelectionGestureDetectorBuilderDelegate {
  TextEditingController? _controller;
  FocusNode? _focusNode;
  late final TextSelectionGestureDetectorBuilder
      _selectionGestureDetectorBuilder;
  late String _reported;
  bool _wasComposing = false;
  bool _showSelectionHandles = false;
  bool _focused = false;
  bool _syncing = false;
  String? _stash;
  bool _typingReady = true;
  Timer? _typingTimer;

  TextEditingController get _effectiveController =>
      widget.controller ?? _controller!;

  FocusNode get _effectiveFocusNode =>
      widget.focusNode ?? (_focusNode ??= FocusNode());

  @override
  final GlobalKey<EditableTextState> editableTextKey =
      GlobalKey<EditableTextState>();

  @override
  bool get forcePressEnabled => false;

  @override
  bool get selectionEnabled => !widget.disabled;

  bool get _isComposing {
    final TextRange composing = _effectiveController.value.composing;
    return composing.isValid && !composing.isCollapsed;
  }

  bool get _sendsOnEnter {
    final bool? enterToSend = widget.enterToSend;
    if (enterToSend != null) {
      return enterToSend;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return false;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return true;
    }
  }

  String get _text => _effectiveController.text;

  int _lengthOf(String raw) {
    if (raw.length <= widget.maxLength - _kCounterFrom) {
      return raw.length;
    }
    return parseKunChatMarkdown(raw.trim()).text.length;
  }

  int get _remaining => widget.maxLength - _lengthOf(_text);

  bool get _showCounter => _remaining <= _kCounterFrom;

  bool get _canSend {
    if (widget.disabled || _remaining < 0) {
      return false;
    }
    if (_text.trim().isNotEmpty) {
      return true;
    }
    return widget.editing == null && widget.attachments.isNotEmpty;
  }

  bool get _barVisible =>
      widget.editing != null || widget.replyTo != null || widget.quote != null;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _reported = widget.value;
      _createLocalController();
    } else {
      _reported = widget.controller!.text;
      widget.controller!.addListener(_handleControllerChanged);
    }
    _effectiveFocusNode.canRequestFocus = !widget.disabled;
    _effectiveFocusNode.onKeyEvent = _onKeyEvent;
    _effectiveFocusNode.addListener(_handleFocusChange);
    _selectionGestureDetectorBuilder = TextSelectionGestureDetectorBuilder(
      delegate: this,
    );
    if (widget.editing != null) {
      _applyEditing(widget.editing!, duringBuild: true);
    }
  }

  void _createLocalController([TextEditingValue? value]) {
    assert(_controller == null);
    _controller = value == null
        ? TextEditingController(text: widget.value)
        : TextEditingController.fromValue(value);
    _controller!.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(KunChatComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller == null && oldWidget.controller != null) {
      oldWidget.controller!.removeListener(_handleControllerChanged);
      _createLocalController(oldWidget.controller!.value);
    } else if (widget.controller != null && oldWidget.controller == null) {
      _controller!.removeListener(_handleControllerChanged);
      _controller!.dispose();
      _controller = null;
      widget.controller!.addListener(_handleControllerChanged);
    } else if (widget.controller != oldWidget.controller) {
      oldWidget.controller!.removeListener(_handleControllerChanged);
      widget.controller!.addListener(_handleControllerChanged);
    }

    if (widget.controller != oldWidget.controller) {
      _reported = _effectiveController.text;
    }

    if (widget.focusNode != oldWidget.focusNode) {
      (oldWidget.focusNode ?? _focusNode)?.onKeyEvent = null;
      (oldWidget.focusNode ?? _focusNode)?.removeListener(_handleFocusChange);
      _effectiveFocusNode.onKeyEvent = _onKeyEvent;
      _effectiveFocusNode.addListener(_handleFocusChange);
      _focused = _effectiveFocusNode.hasFocus;
    }
    _effectiveFocusNode.canRequestFocus = !widget.disabled;

    if (widget.controller == null &&
        oldWidget.controller == null &&
        widget.editing == null) {
      _reported = widget.value;
      if (!_isComposing && widget.value != _effectiveController.text) {
        _effectiveController.value = TextEditingValue(
          text: widget.value,
          selection: TextSelection.collapsed(offset: widget.value.length),
        );
      }
    }

    if (widget.editing != oldWidget.editing) {
      final KunChatMessage? next = widget.editing;
      if (next != null) {
        _applyEditing(next, duringBuild: true);
      } else if (_stash != null) {
        final String restored = _stash!;
        _stash = null;
        _setText(restored, duringBuild: true);
      }
    }

    if (widget.replyTo != null && widget.replyTo != oldWidget.replyTo) {
      _effectiveFocusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _effectiveFocusNode.onKeyEvent = null;
    _effectiveFocusNode.removeListener(_handleFocusChange);
    _focusNode?.dispose();
    _effectiveController.removeListener(_handleControllerChanged);
    _controller?.dispose();
    super.dispose();
  }

  void _commit(String text) {
    if (text == _reported) {
      return;
    }
    _reported = text;
    widget.onChanged?.call(text);
  }

  void _setText(String text, {bool duringBuild = false}) {
    _syncing = true;
    _effectiveController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _syncing = false;
    if (duringBuild) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _commit(text);
        }
      });
    } else {
      _commit(text);
    }
  }

  void _applyEditing(KunChatMessage next, {required bool duringBuild}) {
    _stash ??= _text;
    _setText(
      formatKunChatMarkdown(next.text, next.entities),
      duringBuild: duringBuild,
    );
    if (duringBuild) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _effectiveFocusNode.requestFocus();
        }
      });
    } else {
      _effectiveFocusNode.requestFocus();
    }
  }

  void _handleChanged(String text) {
    if (_syncing || _isComposing) {
      return;
    }
    _commit(text);
    _onUserTyping();
  }

  void _handleControllerChanged() {
    final bool composing = _isComposing;
    if (_wasComposing && !composing) {
      _commit(_effectiveController.text);
    }
    _wasComposing = composing;
    if (mounted) {
      setState(() {});
    }
  }

  void _handleFocusChange() {
    if (_effectiveFocusNode.hasFocus == _focused) {
      return;
    }
    setState(() => _focused = _effectiveFocusNode.hasFocus);
  }

  void _onUserTyping() {
    if (widget.editing != null || !_typingReady || _text.isEmpty) {
      return;
    }
    _typingReady = false;
    widget.onTyping?.call();
    _typingTimer?.cancel();
    _typingTimer = Timer(kunChatTypingInterval, () {
      _typingReady = true;
    });
  }

  void _insertNewline() {
    final TextEditingValue value = _effectiveController.value;
    final TextSelection selection = value.selection;
    if (!selection.isValid) {
      return;
    }
    final String next = value.text.replaceRange(
      selection.start,
      selection.end,
      '\n',
    );
    _effectiveController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: selection.start + 1),
    );
    _commit(next);
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    if (_isComposing) {
      return KeyEventResult.ignored;
    }
    final LogicalKeyboardKey key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      final bool send = _sendsOnEnter
          ? !HardwareKeyboard.instance.isShiftPressed
          : HardwareKeyboard.instance.isControlPressed ||
              HardwareKeyboard.instance.isMetaPressed;
      if (send) {
        _submit();
        return KeyEventResult.handled;
      }
      if (_sendsOnEnter && HardwareKeyboard.instance.isShiftPressed) {
        _insertNewline();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.escape && _barVisible) {
      _cancelBar();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp &&
        _text.isEmpty &&
        widget.editing == null) {
      widget.onEditLast?.call();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _submit() {
    if (!_canSend) {
      return;
    }
    final KunChatFormattedText message = parseKunChatMarkdown(_text.trim());
    final KunChatMessage? editing = widget.editing;
    if (editing != null) {
      widget.onEdit?.call(message, editing);
      widget.onEditingChanged?.call(null);
    } else {
      widget.onSend?.call(message);
      _setText('');
      widget.onReplyToChanged?.call(null);
      widget.onQuoteChanged?.call(null);
    }
    _effectiveFocusNode.requestFocus();
  }

  void _cancelBar() {
    if (widget.editing != null) {
      widget.onEditingChanged?.call(null);
    } else {
      widget.onReplyToChanged?.call(null);
      widget.onQuoteChanged?.call(null);
    }
    _effectiveFocusNode.requestFocus();
  }

  bool _shouldShowSelectionHandles(SelectionChangedCause? cause) {
    if (!_selectionGestureDetectorBuilder.shouldShowSelectionToolbar ||
        !_selectionGestureDetectorBuilder.shouldShowSelectionHandles) {
      return false;
    }
    if (cause == SelectionChangedCause.keyboard) {
      return false;
    }
    if (widget.disabled) {
      return false;
    }
    if (cause == SelectionChangedCause.longPress ||
        cause == SelectionChangedCause.stylusHandwriting) {
      return true;
    }
    return _effectiveController.text.isNotEmpty;
  }

  void _handleSelectionChanged(
    TextSelection selection,
    SelectionChangedCause? cause,
  ) {
    final bool willShow = _shouldShowSelectionHandles(cause);
    if (willShow != _showSelectionHandles) {
      setState(() => _showSelectionHandles = willShow);
    }
    if (cause == SelectionChangedCause.longPress) {
      editableTextKey.currentState?.bringIntoView(selection.extent);
    }
    final bool desktop = switch (defaultTargetPlatform) {
      TargetPlatform.macOS ||
      TargetPlatform.linux ||
      TargetPlatform.windows =>
        true,
      TargetPlatform.iOS ||
      TargetPlatform.fuchsia ||
      TargetPlatform.android =>
        false,
    };
    if (desktop && cause == SelectionChangedCause.drag) {
      editableTextKey.currentState?.hideToolbar();
    }
  }

  void _handleSelectionHandleTapped() {
    if (_effectiveController.selection.isCollapsed) {
      editableTextKey.currentState?.toggleToolbar();
    }
  }

  void _handleSemanticsTap() {
    if (!_effectiveController.selection.isValid) {
      _effectiveController.selection = TextSelection.collapsed(
        offset: _effectiveController.text.length,
      );
    }
    editableTextKey.currentState?.requestKeyboard();
  }

  void _handleSemanticsFocus() {
    if (!_effectiveFocusNode.hasFocus) {
      _effectiveFocusNode.requestFocus();
    } else {
      editableTextKey.currentState?.requestKeyboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    final KunMessages messages = KunMessagesScope.of(context);
    final KunChatComposerStrings strings = messages.chatComposer;
    final String placeholder = widget.placeholder ?? strings.placeholder;
    final Color fieldFill = _focused
        ? scheme.neutral.solid.withValues(alpha: 0.15)
        : scheme.neutral.solid.withValues(alpha: 0.1);
    final TextStyle fieldStyle = KunText.base.copyWith(
      color: scheme.foreground,
    );

    Widget? field;
    if (!widget.disabled) {
      final Widget placeholderLayer = Positioned.fill(
        child: IgnorePointer(
          child: ClipRect(
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _effectiveController,
              builder: (
                BuildContext context,
                TextEditingValue value,
                Widget? child,
              ) {
                return value.text.isEmpty ? child! : const SizedBox.shrink();
              },
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  placeholder,
                  style: fieldStyle.copyWith(color: scheme.foregroundMuted),
                ),
              ),
            ),
          ),
        ),
      );

      Widget input = Stack(
        children: <Widget>[
          placeholderLayer,
          EditableText(
            key: editableTextKey,
            controller: _effectiveController,
            focusNode: _effectiveFocusNode,
            style: fieldStyle,
            cursorColor: scheme.foreground,
            backgroundCursorColor: scheme.neutral.shade300,
            selectionColor: scheme.primary.solid.withValues(alpha: 0.2),
            keyboardType: TextInputType.multiline,
            textInputAction:
                _sendsOnEnter ? TextInputAction.send : TextInputAction.newline,
            minLines: 1,
            maxLines: widget.maxRows,
            autofocus: false,
            showSelectionHandles: _showSelectionHandles,
            selectionControls: KunTextSelectionControls(
              handleColor: scheme.primary.solid,
            ),
            contextMenuBuilder: kunTextSelectionContextMenu,
            onSelectionChanged: _handleSelectionChanged,
            onSelectionHandleTapped: _handleSelectionHandleTapped,
            onChanged: _handleChanged,
            contentInsertionConfiguration: widget.contentInsertionConfiguration,
            onSubmitted: (_) {
              if (!_isComposing && _sendsOnEnter) {
                _submit();
              }
            },
            rendererIgnoresPointer: true,
            scrollBehavior: ScrollConfiguration.of(context)
                .copyWith(scrollbars: false, overscroll: false),
          ),
        ],
      );

      input = KunTapBand(
        background: AnimatedContainer(
          duration: kunMotion(context, KunDefaultTransition.duration),
          curve: KunDefaultTransition.curve,
          decoration: BoxDecoration(
            color: fieldFill,
            borderRadius: BorderRadius.circular(KunRadius.lg),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: KunSpacing.unit * 3,
            vertical: KunSpacing.unit * 2,
          ),
          child: input,
        ),
      );

      input = Semantics(
        enabled: true,
        label: placeholder,
        hint: _showCounter
            ? (_remaining < 0
                ? strings.overLimit(count: -_remaining)
                : strings.remaining(count: _remaining))
            : null,
        onTap: _handleSemanticsTap,
        onFocus: _handleSemanticsFocus,
        child: TextFieldTapRegion(
          child: _selectionGestureDetectorBuilder.buildGestureDetector(
            behavior: HitTestBehavior.translucent,
            child: MouseRegion(cursor: SystemMouseCursors.text, child: input),
          ),
        ),
      );

      field = input;
    }

    return ColoredBox(
      color: scheme.content1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: scheme.neutral.solid.withValues(alpha: 0.2)),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: KunSpacing.unit * 2,
            vertical: KunSpacing.unit * 2,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (_barVisible) _buildBar(scheme, messages),
              if (widget.attachments.isNotEmpty)
                _buildAttachments(scheme, strings),
              if (widget.disabled)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KunSpacing.unit * 3,
                    vertical: KunSpacing.unit * 2.5,
                  ),
                  child: Text(
                    widget.disabledText,
                    textAlign: TextAlign.center,
                    style: KunText.sm.copyWith(color: scheme.foregroundMuted),
                  ),
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    if (widget.editing == null)
                      _ComposerIconButton(
                        semanticLabel: strings.attach,
                        icon: KunIcons.paperclip,
                        onPressed: widget.onAttach,
                      ),
                    if (widget.prefix != null) widget.prefix!,
                    Expanded(child: field!),
                    if (widget.suffix != null) widget.suffix!,
                    if (_showCounter) _buildCounter(scheme, strings),
                    _ComposerIconButton(
                      semanticLabel:
                          widget.editing != null ? strings.save : strings.send,
                      icon: widget.editing != null
                          ? KunIcons.check
                          : KunIcons.sendHorizontal,
                      enabled: _canSend,
                      active: _canSend,
                      onPressed: _canSend ? _submit : null,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBar(KunColorScheme scheme, KunMessages messages) {
    final KunChatComposerStrings strings = messages.chatComposer;
    final KunChatMessage? message = widget.editing ?? widget.replyTo;
    final bool quoting = widget.quote != null && widget.editing == null;
    final IconData icon = widget.editing != null
        ? KunIcons.pencil
        : quoting
            ? KunIcons.quote
            : KunIcons.reply;
    final String title;
    if (widget.editing != null) {
      title = strings.editing;
    } else {
      final String name = widget.replyTo == null
          ? ''
          : resolveKunChatUser(
              kunChatUserMap(widget.users),
              widget.replyTo!.senderId,
              messages,
            ).name;
      title =
          quoting ? strings.quoteFrom(name: name) : strings.replyTo(name: name);
    }
    final String bodyText =
        quoting ? widget.quote!.text : (message?.text ?? '');
    final List<KunChatEntity> bodyEntities = quoting
        ? widget.quote!.entities
        : (message?.entities ?? const <KunChatEntity>[]);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KunSpacing.unit,
        0,
        KunSpacing.unit,
        KunSpacing.unit * 2,
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: KunText.xl.fontSize, color: scheme.primary.solid),
          const SizedBox(width: KunSpacing.unit * 2),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: scheme.primary.solid, width: 2),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.only(left: KunSpacing.unit * 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KunText.sm.copyWith(
                        color: scheme.primary.text,
                        fontWeight: KunFontWeights.semibold,
                      ),
                    ),
                    DefaultTextStyle.merge(
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KunText.sm.copyWith(
                        color: scheme.neutral.shade600,
                      ),
                      child: bodyText.isNotEmpty
                          ? KunChatText(
                              text: bodyText,
                              entities: bodyEntities,
                              preview: true,
                            )
                          : Text(kunChatMediaLabel(message?.media, messages)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _ComposerIconButton(
            size: KunSpacing.unit * 8,
            semanticLabel: widget.editing != null
                ? strings.cancelEdit
                : strings.cancelReply,
            icon: KunIcons.x,
            onPressed: _cancelBar,
          ),
        ],
      ),
    );
  }

  Widget _buildAttachments(
    KunColorScheme scheme,
    KunChatComposerStrings strings,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KunSpacing.unit,
        0,
        KunSpacing.unit,
        KunSpacing.unit * 2,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            for (int i = 0; i < widget.attachments.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: KunSpacing.unit * 2),
              _AttachmentChip(
                attachment: widget.attachments[i],
                retryLabel: strings.retryAttachment,
                removeLabel: strings.removeAttachment,
                onRetry: widget.onRetryAttachment,
                onRemove: widget.onRemoveAttachment,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCounter(KunColorScheme scheme, KunChatComposerStrings strings) {
    final int remaining = _remaining;
    final Color color =
        remaining < 0 ? scheme.danger.solid : scheme.foregroundMuted;
    final String description = remaining < 0
        ? strings.overLimit(count: -remaining)
        : strings.remaining(count: remaining);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KunSpacing.unit),
      child: Semantics(
        label: description,
        container: true,
        child: ExcludeSemantics(
          child: Text(
            '$remaining',
            style: KunText.xs.copyWith(
              color: color,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}

class _ComposerIconButton extends StatefulWidget {
  const _ComposerIconButton({
    required this.icon,
    required this.semanticLabel,
    this.onPressed,
    this.enabled = true,
    this.active = false,
    this.size = KunSpacing.unit * 10,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final bool enabled;
  final bool active;
  final double size;

  @override
  State<_ComposerIconButton> createState() => _ComposerIconButtonState();
}

class _ComposerIconButtonState extends State<_ComposerIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final KunColorScheme scheme = KunTheme.of(context).colors;
    final Color iconColor = !widget.enabled
        ? scheme.neutral.shade400
        : widget.active
            ? scheme.primary.solid
            : _hovered
                ? scheme.foreground
                : scheme.neutral.shade500;
    final Color? splash = !widget.enabled
        ? null
        : widget.active
            ? (_hovered ? scheme.primary.solid.withValues(alpha: 0.15) : null)
            : (_hovered ? scheme.neutral.solid.withValues(alpha: 0.2) : null);

    return Semantics(
      container: true,
      button: true,
      enabled: widget.enabled,
      label: widget.semanticLabel,
      onTap: widget.enabled ? widget.onPressed : null,
      child: KunTapTarget(
        child: MouseRegion(
          cursor: widget.enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTap: widget.enabled ? widget.onPressed : null,
            child: AnimatedContainer(
              duration: kunMotion(context, KunDefaultTransition.duration),
              curve: KunDefaultTransition.curve,
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(color: splash, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Icon(
                widget.icon,
                size: KunText.xl.fontSize,
                color: iconColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AttachmentChip extends StatefulWidget {
  const _AttachmentChip({
    required this.attachment,
    required this.retryLabel,
    required this.removeLabel,
    required this.onRetry,
    required this.onRemove,
  });

  final KunChatAttachment attachment;
  final String retryLabel;
  final String removeLabel;
  final ValueChanged<String>? onRetry;
  final ValueChanged<String>? onRemove;

  @override
  State<_AttachmentChip> createState() => _AttachmentChipState();
}

class _AttachmentChipState extends State<_AttachmentChip> {
  @override
  Widget build(BuildContext context) {
    final KunChatAttachment attachment = widget.attachment;
    final double? progress = attachment.progress;
    return ClipRRect(
      borderRadius: BorderRadius.circular(KunRadius.md),
      child: SizedBox(
        width: _kThumbSize,
        height: _kThumbSize,
        child: ColoredBox(
          color:
              KunTheme.of(context).colors.neutral.solid.withValues(alpha: 0.2),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (attachment.image != null)
                Image(
                  image: attachment.image!,
                  fit: BoxFit.cover,
                  semanticLabel: attachment.name ?? '',
                  errorBuilder: _emptyOnError,
                ),
              if (progress != null && progress < 1 && !attachment.error)
                Positioned(
                  left: KunSpacing.unit,
                  right: KunSpacing.unit,
                  bottom: KunSpacing.unit,
                  height: _kProgressHeight,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(KunRadius.full),
                    child: ColoredBox(
                      color: KunColors.black.withValues(alpha: 0.3),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: progress.clamp(0.0, 1.0),
                          heightFactor: 1,
                          child: ColoredBox(
                            color: KunTheme.of(context).colors.primary.solid,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (attachment.error)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => widget.onRetry?.call(attachment.key),
                  child: Semantics(
                    button: true,
                    label: widget.retryLabel,
                    child: ColoredBox(
                      color: KunColors.black.withValues(alpha: 0.45),
                      child: Icon(
                        KunIcons.rotateCw,
                        size: KunText.xl.fontSize,
                        color: KunColors.white,
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: KunSpacing.unit * 0.5,
                right: KunSpacing.unit * 0.5,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => widget.onRemove?.call(attachment.key),
                  child: Semantics(
                    button: true,
                    label: widget.removeLabel,
                    child: Container(
                      width: KunSpacing.unit * 5,
                      height: KunSpacing.unit * 5,
                      decoration: BoxDecoration(
                        color: KunColors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        KunIcons.x,
                        size: KunText.xs.fontSize,
                        color: KunColors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Without an errorBuilder a failed image paints Flutter's debug error box,
// exception text included, and that text reaches the semantics tree.
Widget _emptyOnError(BuildContext context, Object error, StackTrace? stack) =>
    const SizedBox.shrink();
