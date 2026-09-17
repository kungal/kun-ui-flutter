import 'package:flutter/services.dart'
    show LengthLimitingTextInputFormatter, TextInputAction;
import 'package:flutter/widgets.dart';
import 'package:kun_ui_tokens/kun_ui_tokens.dart';

import '../foundation/control_metrics.dart';
import '../foundation/design.dart';
import '../foundation/field_ring.dart';
import '../theme/theme.dart';

/// A multi-line text field implementing the web `KunTextarea` contract.
///
/// The value is controlled like [KunInput]'s: pass [value] and rebuild with
/// what [onChanged] gives you (the web's `v-model`).
///
/// [maxHeight] is a pixel count because the web reads it with `parseInt`.
/// [maxLength] and the counter count user-perceived characters (Flutter's
/// [LengthLimitingTextInputFormatter] semantics) where the browser counts
/// UTF-16 code units, so an emoji the web counts as 2 counts as 1 here.
///
/// Like every Flutter text field, it needs an [Overlay] ancestor. The app's
/// [Navigator] carries one: `WidgetsApp` builds the navigator, or under
/// `WidgetsApp.router` the router delegate does.
class KunTextarea extends StatefulWidget {
  /// Creates a multi-line text field.
  const KunTextarea({
    super.key,
    this.value = '',
    this.onChanged,
    this.onFocus,
    this.onBlur,
    this.label,
    this.placeholder,
    this.description,
    this.error,
    this.color = KunUIColor.neutral,
    this.size = KunUISize.md,
    this.rounded,
    this.rows = 4,
    this.autoGrow = false,
    this.maxHeight,
    this.maxLength,
    this.showCharCount = false,
    this.disabled = false,
    this.readOnly = false,
    this.required = false,
    this.autofocus = false,
  })  : assert(rows > 0),
        assert(maxLength == null || maxLength > 0);

  /// The current text (web `modelValue`).
  final String value;

  /// Called on every edit (web `update:modelValue`).
  final ValueChanged<String>? onChanged;

  /// Called when the field takes focus.
  final VoidCallback? onFocus;

  /// Called when the field loses focus.
  final VoidCallback? onBlur;

  /// Label above the field.
  final String? label;

  /// Placeholder shown while the field is empty.
  final String? placeholder;

  /// Helper text below the field. Hidden while [error] is set.
  final String? description;

  /// Error message below the field. Also turns the border and ring `danger`.
  final String? error;

  /// Semantic color of the focus ring.
  final KunUIColor color;

  /// Padding and font size — the shared form-control scale.
  final KunUISize size;

  /// Corner radius. Left null it follows [KunThemeData.rounded].
  final KunUIRounded? rounded;

  /// Visible lines; the minimum when [autoGrow] is set.
  final int rows;

  /// Grows the field with its content, never shorter than [rows].
  final bool autoGrow;

  /// Cap on the box's outer height, in logical pixels. Read only when
  /// [autoGrow] is set.
  final double? maxHeight;

  /// Maximum user-perceived characters. Left null, the field takes any
  /// length.
  final int? maxLength;

  /// Shows the character count over the bottom-right of the field, as
  /// `length/maxLength` when [maxLength] is set.
  final bool showCharCount;

  /// Blocks editing and dims the field.
  final bool disabled;

  /// Focusable and selectable, not editable, and not dimmed (web `readonly`).
  final bool readOnly;

  /// Appends a `danger` asterisk to [label]. The field itself is not
  /// validated here — that is the form's job.
  final bool required;

  /// Takes focus on mount.
  final bool autofocus;

  @override
  State<KunTextarea> createState() => _KunTextareaState();
}

class _KunTextareaState extends State<KunTextarea>
    implements TextSelectionGestureDetectorBuilderDelegate {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late final TextSelectionGestureDetectorBuilder
      _selectionGestureDetectorBuilder;
  bool _focused = false;

  @override
  final GlobalKey<EditableTextState> editableTextKey =
      GlobalKey<EditableTextState>();

  @override
  bool get forcePressEnabled => false;

  @override
  bool get selectionEnabled => !widget.disabled;

  bool get _hasError => widget.error?.isNotEmpty ?? false;

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
  void didUpdateWidget(KunTextarea oldWidget) {
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
    } else if (!widget.readOnly) {
      editableTextKey.currentState?.requestKeyboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = KunTheme.of(context);
    final scheme = theme.colors;
    final metrics = KunControlMetrics.of(widget.size);
    final radius = BorderRadius.circular(
      (widget.rounded ?? theme.rounded).radius,
    );
    final danger = KunUIColor.danger.scaleOf(scheme);
    final ringColor =
        _hasError ? danger.solid : widget.color.scaleOf(scheme).solid;
    final textColor =
        widget.disabled ? scheme.neutral.shade500 : scheme.foreground;
    final textStyle = metrics.textStyle.copyWith(color: textColor);

    final placeholder = widget.value.isEmpty &&
            (widget.placeholder?.isNotEmpty ?? false)
        ? Positioned.fill(
            child: IgnorePointer(
              child: ClipRect(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    widget.placeholder!,
                    style: textStyle.copyWith(color: scheme.neutral.shade400),
                  ),
                ),
              ),
            ),
          )
        : null;

    final inner = Stack(
      children: [
        if (placeholder != null) placeholder,
        TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: textColor),
          duration: KunDurations.fast,
          curve: KunEasing.standard,
          builder: (context, color, child) {
            return EditableText(
              key: editableTextKey,
              controller: _controller,
              focusNode: _focusNode,
              style: metrics.textStyle.copyWith(color: color),
              cursorColor: scheme.foreground,
              backgroundCursorColor: scheme.neutral.shade300,
              selectionColor:
                  widget.color.scaleOf(scheme).solid.withValues(alpha: 0.2),
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              minLines: widget.rows,
              maxLines: widget.autoGrow ? null : widget.rows,
              readOnly: widget.disabled || widget.readOnly,
              autofocus: widget.autofocus,
              inputFormatters: [
                LengthLimitingTextInputFormatter(widget.maxLength),
              ],
              onChanged: widget.onChanged,
              rendererIgnoresPointer: true,
              // EditableText swaps the inherited behavior for one with
              // scrollbars whenever it is multiline, so a ScrollConfiguration
              // above it hides nothing.
              scrollBehavior: ScrollConfiguration.of(context)
                  .copyWith(scrollbars: false, overscroll: false),
            );
          },
        ),
      ],
    );

    Widget box = TweenAnimationBuilder<BoxShadow>(
      tween: KunFieldRingTween(
        end: kunFieldRing(ringColor, visible: _focused && !widget.disabled),
      ),
      duration: KunDurations.fast,
      curve: KunEasing.standard,
      builder: (context, ring, child) {
        return Container(
          constraints: widget.autoGrow && widget.maxHeight != null
              ? BoxConstraints(maxHeight: widget.maxHeight!)
              : null,
          padding: EdgeInsets.symmetric(
            horizontal: metrics.horizontalPadding,
            vertical: metrics.verticalPadding,
          ),
          decoration: BoxDecoration(
            color: scheme.content1,
            border: Border.all(
              color: _hasError ? danger.shade300 : scheme.neutral.shade100,
            ),
            borderRadius: radius,
            boxShadow: [
              ring,
              if (!widget.disabled) ...KunShadows.sm,
            ],
          ),
          child: child,
        );
      },
      child: inner,
    );

    if (widget.disabled) {
      box = Opacity(opacity: 0.6, child: box);
    }

    Widget field = Stack(
      children: [
        box,
        if (widget.showCharCount)
          Positioned(
            right: KunSpacing.unit * 2,
            bottom: KunSpacing.unit * 2,
            child: IgnorePointer(
              child: Text(
                widget.maxLength == null
                    ? '${widget.value.characters.length}'
                    : '${widget.value.characters.length}/${widget.maxLength}',
                style: KunText.xs.copyWith(color: scheme.neutral.shade500),
              ),
            ),
          ),
      ],
    );

    // See KunInput: without enabled: true, Flutter web renders the field as
    // a disabled <textarea> once accessibility is on.
    field = Semantics(
      enabled: !widget.disabled,
      onTap: widget.disabled || widget.readOnly ? null : _handleSemanticsTap,
      onFocus: widget.disabled ? null : _handleSemanticsFocus,
      child: TextFieldTapRegion(
        child: widget.disabled
            ? IgnorePointer(child: field)
            : _selectionGestureDetectorBuilder.buildGestureDetector(
                behavior: HitTestBehavior.translucent,
                child: field,
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
                  if (widget.required) ...[
                    const TextSpan(text: ' '),
                    const WidgetSpan(
                      child: SizedBox(width: KunSpacing.unit),
                    ),
                    TextSpan(
                      text: '*',
                      style: TextStyle(color: danger.solid),
                    ),
                  ],
                ],
              ),
              style: KunText.sm.copyWith(
                fontWeight: FontWeight.w500,
                color: scheme.neutral.shade700,
              ),
            ),
            const SizedBox(height: KunSpacing.unit),
          ],
          field,
          if (_hasError) ...[
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
