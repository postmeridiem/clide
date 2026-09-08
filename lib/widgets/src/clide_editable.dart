/// The clide text input (D-109).
///
/// `EditableText` is the widgets-layer text primitive, and it is deliberately
/// bare: Material's `TextField` is what normally supplies the selection colour,
/// the drag / double-tap-word / triple-tap-line selection gestures, and the
/// context menu. clide ships no Material ([D-43]), so this supplies them —
/// and is what every clide text input is built on. No bare `EditableText`
/// under `lib/`; a test enforces that.
///
/// Two Flutter details drive the shape here, both silent when got wrong:
///
///  * `EditableText` passes `selectionColor` straight through with **no**
///    `DefaultSelectionStyle` fallback, so leaving it null renders selection
///    invisible rather than defaulted. It defaults to the `selectionBackground`
///    token here.
///  * Setting `selectionControls` to anything that does not mix in
///    `TextSelectionHandleControls` makes `contextMenuBuilder` **ignored** for
///    backwards compatibility. So this passes none — which is also what a
///    desktop wants, since handles are a touch affordance.
library;

import 'package:clide/widgets/src/clide_context_menu.dart';
import 'package:clide/widgets/src/clide_settings.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// A themed, selectable, right-clickable [EditableText].
///
/// The constructor mirrors the `EditableText` properties clide actually uses,
/// so migrating a call site is a rename plus deleting its `selectionColor`
/// workaround (if it had one).
class ClideEditable extends StatefulWidget {
  const ClideEditable({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.style,
    required this.cursorColor,
    required this.backgroundCursorColor,
    this.selectionColor,
    this.maxLines = 1,
    this.minLines,
    this.expands = false,
    this.readOnly = false,
    this.showCursor,
    this.autofocus = false,
    this.obscureText = false,
    this.keyboardType,
    this.textAlign = TextAlign.start,
    this.textInputAction,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final TextStyle style;
  final Color cursorColor;
  final Color backgroundCursorColor;

  /// Selection highlight. Defaults to the `selectionBackground` theme token.
  final Color? selectionColor;

  final int? maxLines;
  final int? minLines;
  final bool expands;
  final bool readOnly;
  final bool? showCursor;
  final bool autofocus;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextAlign textAlign;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<ClideEditable> createState() => _ClideEditableState();
}

class _ClideEditableState extends State<ClideEditable> implements TextSelectionGestureDetectorBuilderDelegate {
  @override
  final GlobalKey<EditableTextState> editableTextKey = GlobalKey<EditableTextState>();

  /// Force press is an iOS pressure gesture; on desktop it must be off or the
  /// builder waits on a gesture that never arrives.
  @override
  bool get forcePressEnabled => false;

  @override
  bool get selectionEnabled => !widget.obscureText;

  late final TextSelectionGestureDetectorBuilder _gestures = TextSelectionGestureDetectorBuilder(delegate: this);

  Widget _contextMenu(BuildContext context, EditableTextState state) {
    return ClideContextMenuSurface(
      globalPosition: state.contextMenuAnchors.primaryAnchor,
      entries: clideContextMenuEntries(context, state.contextMenuButtonItems),
      onClose: state.hideToolbar,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
    return _gestures.buildGestureDetector(
      behavior: HitTestBehavior.deferToChild,
      child: EditableText(
        key: editableTextKey,
        controller: widget.controller,
        focusNode: widget.focusNode,
        style: widget.style,
        cursorColor: widget.cursorColor,
        backgroundCursorColor: widget.backgroundCursorColor,
        selectionColor: widget.selectionColor ?? tokens.selectionBackground,
        maxLines: widget.maxLines,
        minLines: widget.minLines,
        expands: widget.expands,
        readOnly: widget.readOnly,
        showCursor: widget.showCursor,
        autofocus: widget.autofocus,
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        textAlign: widget.textAlign,
        textInputAction: widget.textInputAction,
        inputFormatters: widget.inputFormatters,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        // The gesture detector above owns pointer handling; leaving the
        // renderer's own tap recogniser live would double-handle taps.
        rendererIgnoresPointer: true,
        contextMenuBuilder: _contextMenu,
      ),
    );
  }
}
