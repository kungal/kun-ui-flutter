import 'package:flutter/widgets.dart';
import 'package:kun_ui_icons/kun_ui_icons.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../foundation/control_metrics.dart';
import '../foundation/design.dart';
import '../foundation/field_ring.dart';
import '../foundation/motion.dart';
import '../locale/messages.dart';
import '../theme/theme.dart';

/// What a [KunInput] accepts — the web's `type` attribute, as the closed set
/// the port answers for.
enum KunInputType {
  /// Free text.
  text,

  /// Obscured text, with an optional reveal toggle.
  password,

  /// An email address.
  email,

  /// A number.
  number,

  /// A phone number.
  tel,

  /// A URL.
  url,

  /// A search term.
  search;

  /// The soft keyboard this type asks for.
  TextInputType get keyboardType => switch (this) {
        KunInputType.text || KunInputType.password => TextInputType.text,
        KunInputType.email => TextInputType.emailAddress,
        KunInputType.number => TextInputType.number,
        KunInputType.tel => TextInputType.phone,
        KunInputType.url => TextInputType.url,
        KunInputType.search => TextInputType.text,
      };
}

/// A single-line text field.
///
/// Implements the web `KunInput` contract: the shared control size scale (an
/// input lines up with a button of the same [size]), an optional [label] with
/// a required marker, helper text, an error message that takes the field's
/// border and ring to `danger`, [prefix]/[suffix] widgets, a clear button and
/// a password reveal toggle.
///
/// The value is controlled: pass [value] and rebuild with what [onChanged]
/// gives you (the web's `v-model`).
///
/// The web positions [prefix] and [suffix] absolutely and pads the text away
/// from them with a fixed ladder (`pl-10`, `pr-10`/`pr-[4.5rem]`/`pr-28`);
/// a [Row] does that structurally, so the text cannot slide under them at any
/// widget width. The geometry matches the web's for the 16px icons the ladder
/// was sized around.
///
/// Like every Flutter text field, it needs an [Overlay] ancestor. The app's
/// [Navigator] carries one: `WidgetsApp` builds the navigator, or under
/// `WidgetsApp.router` the router delegate does.
class KunInput extends StatefulWidget {
  /// Creates a text field.
  const KunInput({
    super.key,
    this.value = '',
    this.onChanged,
    this.onFocus,
    this.onBlur,
    this.onClear,
    this.prefix,
    this.suffix,
    this.label,
    this.placeholder,
    this.description,
    this.error,
    this.type = KunInputType.text,
    this.color = KunUIColor.neutral,
    this.size = KunUISize.md,
    this.rounded,
    this.disabled = false,
    this.required = false,
    this.isInvalid = false,
    this.isClearable = false,
    this.revealPassword = false,
    this.autofocus = false,
  });

  /// The current text (web `modelValue`).
  final String value;

  /// Called on every edit (web `update:modelValue`).
  final ValueChanged<String>? onChanged;

  /// Called when the field takes focus.
  final VoidCallback? onFocus;

  /// Called when the field loses focus.
  final VoidCallback? onBlur;

  /// Called when the clear button empties the field, after [onChanged].
  final VoidCallback? onClear;

  /// Rendered inside the field, before the text (web slot `prefix`).
  final Widget? prefix;

  /// Rendered inside the field, after the text and before the clear and
  /// reveal buttons (web slot `suffix`).
  final Widget? suffix;

  /// Label above the field.
  final String? label;

  /// Placeholder shown while the field is empty.
  final String? placeholder;

  /// Helper text below the field. Hidden while [error] is set.
  final String? description;

  /// Error message below the field. Also turns the border and ring `danger`.
  final String? error;

  /// What the field accepts.
  final KunInputType type;

  /// Semantic color of the focus ring.
  final KunUIColor color;

  /// Height, padding and font size — the shared form-control scale.
  final KunUISize size;

  /// Corner radius. Left null it follows [KunThemeData.rounded].
  final KunUIRounded? rounded;

  /// Blocks editing and dims the field.
  final bool disabled;

  /// Appends a `danger` asterisk to [label]. The field itself is not
  /// validated here — that is the form's job.
  final bool required;

  /// Marks the field invalid without an [error] message.
  final bool isInvalid;

  /// Shows a clear button while the field is non-empty.
  final bool isClearable;

  /// For [KunInputType.password]: shows an eye toggle that reveals the text.
  final bool revealPassword;

  /// Takes focus on mount.
  final bool autofocus;

  @override
  State<KunInput> createState() => _KunInputState();
}

class _KunInputState extends State<KunInput>
    implements TextSelectionGestureDetectorBuilderDelegate {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late final TextSelectionGestureDetectorBuilder
      _selectionGestureDetectorBuilder;
  bool _focused = false;
  bool _revealed = false;

  @override
  final GlobalKey<EditableTextState> editableTextKey =
      GlobalKey<EditableTextState>();

  @override
  bool get forcePressEnabled => false;

  @override
  bool get selectionEnabled => !widget.disabled;

  bool get _invalid => (widget.error?.isNotEmpty ?? false) || widget.isInvalid;
  bool get _isPassword => widget.type == KunInputType.password;
  bool get _showClear =>
      widget.isClearable && !widget.disabled && widget.value.isNotEmpty;
  bool get _showReveal =>
      _isPassword && widget.revealPassword && !widget.disabled;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode = FocusNode()..addListener(_handleFocusChange);
    _focusNode.canRequestFocus = !widget.disabled;
    _selectionGestureDetectorBuilder =
        TextSelectionGestureDetectorBuilder(delegate: this);
  }

  @override
  void didUpdateWidget(KunInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    _focusNode.canRequestFocus = !widget.disabled;
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus == _focused) return;
    setState(() => _focused = _focusNode.hasFocus);
    (_focused ? widget.onFocus : widget.onBlur)?.call();
  }

  void _handleSemanticsTap() {
    if (!_controller.selection.isValid) {
      _controller.selection =
          TextSelection.collapsed(offset: _controller.text.length);
    }
    editableTextKey.currentState?.requestKeyboard();
  }

  void _handleSemanticsFocus() {
    if (!_focusNode.hasFocus) {
      _focusNode.requestFocus();
    } else {
      editableTextKey.currentState?.requestKeyboard();
    }
  }

  void _clear() {
    widget.onChanged?.call('');
    widget.onClear?.call();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = KunTheme.of(context);
    final scheme = theme.colors;
    final metrics = KunControlMetrics.of(widget.size);
    final radius = BorderRadius.circular(
      (widget.rounded ?? theme.rounded).radius,
    );
    final messages = KunMessagesScope.of(context);
    final danger = KunUIColor.danger.scaleOf(scheme);
    final ringColor = (_invalid ? danger : widget.color.scaleOf(scheme)).solid;

    final trailing = <Widget>[
      if (widget.suffix != null) widget.suffix!,
      if (_showClear)
        _KunInputIconButton(
          icon: KunIcons.circleX,
          semanticLabel: messages.input.clear,
          scheme: scheme,
          onPressed: _clear,
        ),
      if (_showReveal)
        _KunInputIconButton(
          icon: _revealed ? KunIcons.eyeOff : KunIcons.eye,
          semanticLabel:
              _revealed ? messages.input.hide : messages.input.reveal,
          scheme: scheme,
          onPressed: () => setState(() => _revealed = !_revealed),
        ),
    ];

    final textStyle = metrics.textStyle.copyWith(color: scheme.foreground);

    final editable = EditableText(
      key: editableTextKey,
      controller: _controller,
      focusNode: _focusNode,
      style: textStyle,
      cursorColor: scheme.foreground,
      backgroundCursorColor: scheme.neutral.shade300,
      // The library's established tint alpha — the same 20% the `light` and
      // `flat` variants use. The web leaves selection to the browser, so
      // there is no upstream token to translate.
      selectionColor: widget.color.scaleOf(scheme).solid.withValues(alpha: 0.2),
      keyboardType: widget.type.keyboardType,
      obscureText: _isPassword && !_revealed,
      readOnly: widget.disabled,
      autofocus: widget.autofocus,
      maxLines: 1,
      onChanged: widget.onChanged,
      rendererIgnoresPointer: true,
    );

    final field = Row(
      children: [
        if (widget.prefix != null) ...[
          widget.prefix!,
          // web pl-10, less pl-3 and the size-4 icon
          const SizedBox(width: KunSpacing.unit * (10 - 3 - 4)),
        ],
        Expanded(
          child: Stack(
            children: [
              if (widget.value.isEmpty &&
                  (widget.placeholder?.isNotEmpty ?? false))
                Positioned.fill(
                  child: IgnorePointer(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.placeholder!,
                        style:
                            textStyle.copyWith(color: scheme.neutral.shade400),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              editable,
            ],
          ),
        ),
        if (trailing.isNotEmpty) ...[
          const SizedBox(width: KunSpacing.unit * 3),
          for (var i = 0; i < trailing.length; i++) ...[
            if (i > 0) const SizedBox(width: KunSpacing.unit),
            trailing[i],
          ],
        ],
      ],
    );

    Widget box = TweenAnimationBuilder<BoxShadow>(
      tween: KunFieldRingTween(
        end: kunFieldRing(ringColor, visible: _focused && !widget.disabled),
      ),
      duration: kunMotion(context, KunDurations.fast),
      curve: KunEasing.standard,
      builder: (context, ring, child) {
        return Container(
          padding: EdgeInsets.fromLTRB(
            widget.prefix != null
                ? KunSpacing.unit * 3
                : metrics.horizontalPadding,
            metrics.verticalPadding,
            trailing.isNotEmpty
                ? KunSpacing.unit * 3
                : metrics.horizontalPadding,
            metrics.verticalPadding,
          ),
          decoration: BoxDecoration(
            color: scheme.content1,
            border: Border.all(
              color: _invalid ? danger.shade300 : scheme.neutral.shade100,
            ),
            borderRadius: radius,
            boxShadow: [
              ring,
              ...KunShadows.sm,
            ],
          ),
          child: child,
        );
      },
      child: field,
    );

    if (widget.disabled) {
      box = Opacity(opacity: 0.6, child: box);
    }

    // Flutter web renders a text field whose semantics node does not say
    // it is enabled as a disabled <input>, so with accessibility on nothing
    // could be typed. Material's TextField sets the same three properties.
    box = Semantics(
      enabled: !widget.disabled,
      onTap: widget.disabled ? null : _handleSemanticsTap,
      onFocus: widget.disabled ? null : _handleSemanticsFocus,
      child: TextFieldTapRegion(
        child: widget.disabled
            ? IgnorePointer(child: box)
            : _selectionGestureDetectorBuilder.buildGestureDetector(
                behavior: HitTestBehavior.translucent,
                child: box,
              ),
      ),
    );

    return MouseRegion(
      cursor: widget.disabled
          ? SystemMouseCursors.forbidden
          : SystemMouseCursors.text,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.label?.isNotEmpty ?? false) ...[
            Text.rich(
              TextSpan(
                text: widget.label,
                children: [
                  if (widget.required)
                    TextSpan(
                      text: ' *',
                      style: TextStyle(color: danger.solid),
                    ),
                ],
              ),
              style: KunText.sm.copyWith(
                fontWeight: FontWeight.w500,
                color: scheme.neutral.shade700,
              ),
            ),
            const SizedBox(height: KunSpacing.unit),
          ],
          box,
          if (widget.error?.isNotEmpty ?? false) ...[
            const SizedBox(height: KunSpacing.unit),
            Text(
              widget.error!,
              style: KunText.sm.copyWith(color: danger.solid),
            ),
          ] else if (widget.description?.isNotEmpty ?? false) ...[
            const SizedBox(height: KunSpacing.unit),
            Text(
              widget.description!,
              style: KunText.sm.copyWith(color: scheme.neutral.shade500),
            ),
          ],
        ],
      ),
    );
  }
}

/// A trailing control inside the field: the neutral 400 shade at rest,
/// deepening to 600 under the pointer (web `text-default-400
/// hover:text-default-600`). Not in the tab order, as on the web.
class _KunInputIconButton extends StatefulWidget {
  const _KunInputIconButton({
    required this.icon,
    required this.semanticLabel,
    required this.scheme,
    required this.onPressed,
  });

  final IconData icon;
  final String semanticLabel;
  final KunColorScheme scheme;
  final VoidCallback onPressed;

  @override
  State<_KunInputIconButton> createState() => _KunInputIconButtonState();
}

class _KunInputIconButtonState extends State<_KunInputIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: Icon(
            widget.icon,
            size: KunSpacing.unit * 4,
            color: _hovered
                ? widget.scheme.neutral.shade600
                : widget.scheme.neutral.shade400,
          ),
        ),
      ),
    );
  }
}
