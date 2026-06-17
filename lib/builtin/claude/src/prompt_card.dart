/// The interactive prompt surface for the stream-json control channel
/// (T-166, T-175, T-176, D-78): a permission Allow / Allow-and-remember / Deny /
/// Deny-and-simplify (T-311),
/// or an `AskUserQuestion` picker (single = bare; multi = stepper + review).
/// Rendered in the composer zone (not inline in the conversation) so
/// interaction and conversation widgets don't mix — the pane swaps it in for
/// the text input while a prompt is open. The decision is returned via
/// `onResolve`; the pane then removes the card.
///
/// Plain [ClideButton]s (Semantics buttons → keyboard/AT reachable), no
/// hover-revealed chrome that would fight the buttons.
library;

import 'dart:convert';

import 'package:clide/builtin/claude/src/stream_json_session.dart';
import 'package:clide/kernel/src/syntax/language_map.dart';
import 'package:clide/kernel/src/theme/controller.dart';
import 'package:clide/kernel/src/theme/tokens.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Sentinel option key for the always-present free-text "Other…" choice.
const _kOther = '\u0000other';

/// Preformatted note for the "Deny & simplify" permission option (T-311): deny
/// THIS action and ask Claude to reformulate it more simply, explicitly without
/// touching the permission surface (memories / settings).
const _kDenySimplifyNote =
    'Denied — this action is too complex for the permission system to approve cleanly. '
    'Please retry with a simpler, more granular approach (break it into smaller steps or use a plainer command) '
    'to avoid this permission prompt. This is a one-off for THIS action only: do not add a memory and do not '
    'change permission settings — just reformulate and try again. Do not narrate or explain the change; '
    'proceed silently with the simpler version.';

class ToolPromptCard extends StatefulWidget {
  const ToolPromptCard({super.key, required this.prompt, required this.onResolve});

  final ToolPrompt prompt;

  /// Called once with the user's decision; the card binds the prompt id.
  final void Function(String promptId, ToolDecision decision) onResolve;

  @override
  State<ToolPromptCard> createState() => _ToolPromptCardState();
}

class _ToolPromptCardState extends State<ToolPromptCard> {
  late List<_Question> _q;
  late List<Set<String>> _picked; // chosen labels (+ _kOther) per question
  late List<TextEditingController> _other; // free-text per question
  late List<TextEditingController> _qnote; // per-choice note per question
  final _note = TextEditingController(); // permission note
  int _step = 0; // current question; == _q.length → review

  @override
  void initState() {
    super.initState();
    _initForPrompt();
  }

  @override
  void didUpdateWidget(ToolPromptCard old) {
    super.didUpdateWidget(old);
    if (old.prompt.promptId != widget.prompt.promptId) {
      for (final c in _other) {
        c.dispose();
      }
      for (final c in _qnote) {
        c.dispose();
      }
      _note.clear();
      _initForPrompt();
    }
  }

  void _initForPrompt() {
    _q = _parseQuestions(widget.prompt.input);
    _picked = List.generate(_q.length, (_) => <String>{});
    // Rebuild on text change so Submit/Next gating + nav ✓ re-evaluate as the
    // user types a free-text answer or note.
    _other = List.generate(_q.length, (_) => TextEditingController()..addListener(_rebuild));
    _qnote = List.generate(_q.length, (_) => TextEditingController()..addListener(_rebuild));
    _step = 0;
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _note.dispose();
    for (final c in _other) {
      c.dispose();
    }
    for (final c in _qnote) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    final (accent, label, children) = widget.prompt.isQuestion ? _question(tokens) : _permission(tokens);
    // Autofocus the card so number keys pick a button/option on appear (T-240).
    // _onKey self-guards via hasPrimaryFocus, so once the user clicks a note
    // field the digits type normally instead of triggering buttons.
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: tokens.panelBackground,
          border: Border(top: BorderSide(color: accent, width: 2)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClideText(label, fontSize: clideFontSmall, fontFamily: ClideSettings.fonts.monoOf(context), color: accent),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  // -- number-key + Enter shortcuts (T-240, CLI muscle memory) ---------------

  // Number-row digits and their numpad twins map to the same 1-9 selection,
  // so the shortcut works regardless of which key the user reaches for (T-310).
  static const _digitKeys = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.digit6,
    LogicalKeyboardKey.digit7,
    LogicalKeyboardKey.digit8,
    LogicalKeyboardKey.digit9,
  ];

  static const _numpadKeys = [
    LogicalKeyboardKey.numpad1,
    LogicalKeyboardKey.numpad2,
    LogicalKeyboardKey.numpad3,
    LogicalKeyboardKey.numpad4,
    LogicalKeyboardKey.numpad5,
    LogicalKeyboardKey.numpad6,
    LogicalKeyboardKey.numpad7,
    LogicalKeyboardKey.numpad8,
    LogicalKeyboardKey.numpad9,
  ];

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    // A note field has focus → let the digits type; only act for the card.
    if (!node.hasPrimaryFocus) return KeyEventResult.ignored;
    final hw = HardwareKeyboard.instance;
    if (hw.isControlPressed || hw.isAltPressed || hw.isMetaPressed) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.enter || e.logicalKey == LogicalKeyboardKey.numpadEnter) {
      return _activatePrimary() ? KeyEventResult.handled : KeyEventResult.ignored;
    }
    var i = _digitKeys.indexOf(e.logicalKey);
    if (i < 0) i = _numpadKeys.indexOf(e.logicalKey);
    if (i < 0) return KeyEventResult.ignored;
    return _activateNumber(i + 1) ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  /// The question whose options the number keys address, or null (permission is
  /// handled separately; the review step has no numbered options).
  int? _currentQuestion() {
    if (_q.isEmpty) return null;
    if (_q.length <= 1) return 0;
    return _step < _q.length ? _step : null;
  }

  bool _activateNumber(int n) {
    if (!widget.prompt.isQuestion) {
      final canRemember = widget.prompt.permissionSuggestions.isNotEmpty;
      if (n == 1) return _then(_permAllow);
      if (canRemember && n == 2) return _then(() => _permAllow(remember: true));
      if (n == (canRemember ? 3 : 2)) return _then(_permDeny);
      if (n == (canRemember ? 4 : 3)) return _then(_permDenySimplify);
      return false;
    }
    final qi = _currentQuestion();
    if (qi == null) return false;
    final q = _q[qi];
    final keys = [...q.options.map((o) => o.label), _kOther];
    if (n < 1 || n > keys.length) return false;
    _toggleOption(qi, keys[n - 1], q.multiSelect);
    return true;
  }

  /// Enter confirms the primary action: Allow (permission), or Submit / Next /
  /// Review for questions — only when the step is answerable.
  bool _activatePrimary() {
    if (!widget.prompt.isQuestion) return _then(_permAllow);
    if (_q.length <= 1) return (_q.isNotEmpty && _answer(0).isNotEmpty) ? _then(_submit) : false;
    if (_step >= _q.length) return _allAnswered ? _then(_submit) : false;
    return _answer(_step).isNotEmpty ? _then(() => setState(() => _step++)) : false;
  }

  bool _then(void Function() action) {
    action();
    return true;
  }

  // -- permission allow / allow-remember / deny ------------------------------

  String? _permNote() {
    final t = _note.text.trim();
    return t.isEmpty ? null : t;
  }

  void _permAllow({bool remember = false}) {
    final p = widget.prompt;
    widget.onResolve(p.promptId, AllowTool(p.input, updatedPermissions: remember ? p.permissionSuggestions : null, followUpNote: _permNote()));
  }

  void _permDeny() => widget.onResolve(widget.prompt.promptId, DenyTool(_permNote() ?? 'Denied by the user.'));

  /// Deny carrying a preformatted "this was too complex — retry simpler" note
  /// (T-311). The "do not add a memory / change settings" clause keeps Claude
  /// from trying to "fix" the permission surface instead of reformulating; the
  /// user's own typed note, if any, is appended rather than discarded.
  void _permDenySimplify() {
    final user = _permNote();
    final note = user == null ? _kDenySimplifyNote : '$_kDenySimplifyNote\n\nUser note: $user';
    // Quiet: the user deliberately chose this, so its denial folds rather than
    // shouting as a red error (T-340).
    widget.onResolve(widget.prompt.promptId, DenyTool(note, quiet: true));
  }

  (Color, String, List<Widget>) _permission(SurfaceTokens tokens) {
    final p = widget.prompt;
    final canRemember = p.permissionSuggestions.isNotEmpty;
    return (
      tokens.statusWarning,
      'permission · ${p.displayName}',
      [
        // Claude's description for Write/Edit is often just the file_path,
        // which the body already shows via _pathLine — suppress in that case
        // so we don't render the same path twice.
        if (p.description != null && p.description!.isNotEmpty && p.description != p.input['file_path'])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ClideText(p.description!, fontSize: clideFontMeta, color: tokens.globalForeground),
          ),
        // Show what's being permitted — capped + scrollable so a long command
        // or file body is visible but doesn't swamp the composer zone (D-78).
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 200),
          child: SingleChildScrollView(child: _inputBody(tokens, ClideSettings.fonts.monoOf(context), p)),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ClideButton(label: '1. Allow', variant: ClideButtonVariant.primary, onPressed: () => _permAllow()),
            if (canRemember) ClideButton(label: "2. Allow & don't ask again", onPressed: () => _permAllow(remember: true)),
            ClideButton(label: '${canRemember ? '3' : '2'}. Deny', onPressed: _permDeny),
            ClideButton(
              label: '${canRemember ? '4' : '3'}. Deny & simplify',
              tooltip: 'Deny and ask Claude to retry this action in a simpler format — complex interactions don\'t work well with the permission system.',
              onPressed: _permDenySimplify,
            ),
          ],
        ),
        const SizedBox(height: 10),
        _NoteField(controller: _note, placeholder: 'add a note (optional) — sent to Claude'),
      ],
    );
  }

  /// Render the tool input in the shape that best fits the tool. Delegates to
  /// the shared top-level helpers (also used by ConversationView — T-168).
  Widget _inputBody(SurfaceTokens tokens, String mono, ToolPrompt p) => toolInputBody(tokens, p.toolName, p.input, mono);

  // -- AskUserQuestion: single = bare, multi = stepper + review --------------

  (Color, String, List<Widget>) _question(SurfaceTokens tokens) {
    if (_q.length <= 1) {
      return (
        tokens.statusInfo,
        'question',
        [
          if (_q.isNotEmpty) _questionBody(tokens, 0),
          const SizedBox(height: 6),
          Row(
            children: [
              ClideButton(label: 'Submit', variant: ClideButtonVariant.primary, onPressed: (_q.isNotEmpty && _answer(0).isNotEmpty) ? _submit : null),
              const Spacer(),
              _chatInstead(tokens),
            ],
          ),
        ],
      );
    }
    if (_step >= _q.length) {
      return (
        tokens.statusInfo,
        'review',
        [
          ClideText('Review your answers', color: tokens.globalForeground, fontSize: clideFontBody),
          const SizedBox(height: 8),
          for (var i = 0; i < _q.length; i++) _reviewRow(tokens, i),
          const SizedBox(height: 6),
          Row(
            children: [
              ClideButton(label: '‹ Back', onPressed: () => setState(() => _step = _q.length - 1)),
              const SizedBox(width: 8),
              ClideButton(label: 'Submit answers', variant: ClideButtonVariant.primary, onPressed: _allAnswered ? _submit : null),
            ],
          ),
        ],
      );
    }
    final answered = _answer(_step).isNotEmpty;
    final last = _step == _q.length - 1;
    return (
      tokens.statusInfo,
      'question',
      [
        _navBar(tokens),
        const SizedBox(height: 10),
        _questionBody(tokens, _step),
        const SizedBox(height: 6),
        Row(
          children: [
            if (_step > 0) ...[ClideButton(label: '‹ Back', onPressed: () => setState(() => _step--)), const SizedBox(width: 8)],
            ClideButton(label: last ? 'Review ›' : 'Next ›', variant: ClideButtonVariant.primary, onPressed: answered ? () => setState(() => _step++) : null),
            const Spacer(),
            _chatInstead(tokens),
          ],
        ),
      ],
    );
  }

  Widget _navBar(SurfaceTokens tokens) {
    final chips = <Widget>[ClideText('‹', color: tokens.globalTextMuted, fontSize: 15)];
    for (var i = 0; i < _q.length; i++) {
      final head = _q[i].header.isEmpty ? 'Q${i + 1}' : _q[i].header;
      final done = _answer(i).isNotEmpty;
      final text = '${i + 1} · $head${done ? ' ✓' : ''}';
      if (i == _step) {
        chips.add(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: tokens.globalFocus.withValues(alpha: 0.18),
              border: Border.all(color: tokens.statusInfo),
              borderRadius: BorderRadius.circular(4),
            ),
            child: ClideText(text, fontSize: clideFontMeta, fontFamily: ClideSettings.fonts.monoOf(context), color: tokens.globalForeground),
          ),
        );
      } else {
        chips.add(
          ClideText(
            text,
            fontSize: clideFontMeta,
            fontFamily: ClideSettings.fonts.monoOf(context),
            color: done ? tokens.statusSuccess : tokens.globalTextMuted,
          ),
        );
      }
    }
    chips.add(ClideText('Review', fontSize: clideFontMeta, fontFamily: ClideSettings.fonts.monoOf(context), color: tokens.globalTextMuted));
    chips.add(ClideText('›', color: tokens.globalTextMuted, fontSize: 15));
    return Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: chips);
  }

  Widget _reviewRow(SurfaceTokens tokens, int qi) {
    final head = _q[qi].header.isEmpty ? 'Q${qi + 1}' : _q[qi].header;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: ClideText(head, fontSize: clideFontMeta, color: tokens.globalTextMuted),
          ),
          Expanded(
            child: ClideText('→ ${_answer(qi)}', fontSize: clideFontSmall, color: tokens.globalForeground),
          ),
        ],
      ),
    );
  }

  Widget _questionBody(SurfaceTokens tokens, int qi) {
    final q = _q[qi];
    final hasOther = _picked[qi].contains(_kOther);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (q.header.isNotEmpty)
          ClideText(q.header.toUpperCase(), fontSize: clideFontMeta, fontFamily: ClideSettings.fonts.monoOf(context), color: tokens.globalTextMuted),
        Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 6),
          child: ClideText(q.question, color: tokens.globalForeground),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var oi = 0; oi < q.options.length; oi++)
              _optButton(qi, q.options[oi].label, q.options[oi].label, q.multiSelect, q.options[oi].description, oi + 1),
            _optButton(qi, _kOther, 'Other…', q.multiSelect, '', q.options.length + 1),
          ],
        ),
        if (hasOther) ...[const SizedBox(height: 8), _NoteField(controller: _other[qi], placeholder: 'type your answer…')],
        const SizedBox(height: 8),
        _NoteField(controller: _qnote[qi], placeholder: '+ note (optional)'),
      ],
    );
  }

  Widget _optButton(int qi, String key, String label, bool multi, String description, int number) {
    final sel = _picked[qi].contains(key);
    return ClideButton(
      label: '$number. ${sel ? '●' : '○'} $label',
      variant: sel ? ClideButtonVariant.primary : ClideButtonVariant.subtle,
      tooltip: description.isNotEmpty ? description : null,
      onPressed: () => _toggleOption(qi, key, multi),
    );
  }

  void _toggleOption(int qi, String key, bool multi) {
    setState(() {
      final s = _picked[qi];
      if (multi) {
        s.contains(key) ? s.remove(key) : s.add(key);
      } else {
        s
          ..clear()
          ..add(key);
      }
    });
  }

  Widget _chatInstead(SurfaceTokens tokens) {
    return ClideButton(
      label: 'chat instead',
      variant: ClideButtonVariant.subtle,
      onPressed: () => widget.onResolve(widget.prompt.promptId, const DenyTool('User chose to chat instead.')),
    );
  }

  bool get _allAnswered => List.generate(_q.length, _answer).every((a) => a.isNotEmpty);

  /// The answer string for question [qi]: chosen labels (+ free-text), with an
  /// optional note appended (D-78 — answers are question-text → string).
  String _answer(int qi) {
    final parts = _picked[qi].where((l) => l != _kOther).toList();
    if (_picked[qi].contains(_kOther)) {
      final t = _other[qi].text.trim();
      if (t.isNotEmpty) parts.add(t);
    }
    var ans = parts.join(', ');
    final note = _qnote[qi].text.trim();
    if (note.isNotEmpty) ans = ans.isEmpty ? note : '$ans — $note';
    return ans;
  }

  void _submit() {
    final answers = <String, String>{};
    for (var i = 0; i < _q.length; i++) {
      answers[_q[i].question] = _answer(i);
    }
    widget.onResolve(widget.prompt.promptId, AllowTool({...widget.prompt.input, 'answers': answers}));
  }
}

// -- shared tool-input rendering (used by ToolPromptCard + ConversationView) --

/// Render [input] for [toolName] in the most informative shape: Bash → shell
/// code block; Write → path + content; Edit/MultiEdit → before/after diff;
/// Read/Grep/LS → path/pattern; anything else → indented JSON.
///
/// Shared between [ToolPromptCard] (permission prompt body) and the
/// [ConversationView] tool-use card bodies (T-168).
Widget toolInputBody(SurfaceTokens tokens, String toolName, Map<String, dynamic> input, String mono) {
  switch (toolName) {
    case 'Bash':
      return toolBashBody(tokens, input);
    case 'Write':
      return toolWriteBody(tokens, input, mono);
    case 'Edit':
    case 'MultiEdit':
      return toolEditBody(tokens, input, mono);
    case 'Read':
    case 'Grep':
    case 'LS':
      return toolReadLikeBody(tokens, toolName, input, mono);
    default:
      return ClideCodeBlock(source: const JsonEncoder.withIndent('  ').convert(input), language: 'json');
  }
}

/// Bash tool body: the command as a shell code block, with optional background
/// / timeout annotations.
Widget toolBashBody(SurfaceTokens tokens, Map<String, dynamic> input) {
  final cmd = (input['command'] as String? ?? '').trimRight();
  final notes = <String>[if (input['run_in_background'] == true) 'background', if (input['timeout'] is num) 'timeout ${input['timeout']}ms'];
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      ClideCodeBlock(source: cmd, language: 'bash'),
      if (notes.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: ClideText(notes.join(' · '), fontSize: clideFontMeta, color: tokens.globalTextMuted),
        ),
    ],
  );
}

/// Write tool body: the file path + content with syntax highlighting.
Widget toolWriteBody(SurfaceTokens tokens, Map<String, dynamic> input, String mono) {
  final path = input['file_path'] as String? ?? '';
  final content = input['content'] as String? ?? '';
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      if (path.isNotEmpty) toolPathLine(tokens, path, mono),
      ClideCodeBlock(source: content, language: grammarForPath(path)),
    ],
  );
}

/// Edit / MultiEdit tool body: before/after diff view.
Widget toolEditBody(SurfaceTokens tokens, Map<String, dynamic> input, String mono) {
  final path = input['file_path'] as String? ?? '';
  final oldStr = input['old_string'] as String? ?? '';
  final newStr = input['new_string'] as String? ?? '';
  final lang = grammarForPath(path);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      if (path.isNotEmpty) toolPathLine(tokens, path, mono),
      ClideText('— before', fontSize: clideFontMeta, color: tokens.globalTextMuted, fontFamily: mono),
      const SizedBox(height: 4),
      ClideCodeBlock(source: oldStr, language: lang),
      const SizedBox(height: 8),
      ClideText('+ after', fontSize: clideFontMeta, color: tokens.globalTextMuted, fontFamily: mono),
      const SizedBox(height: 4),
      ClideCodeBlock(source: newStr, language: lang),
    ],
  );
}

/// Read / Grep / LS body: show the file path or pattern as a one-liner label
/// so the card stays compact. These tools produce the interesting output in the
/// result card rather than their input.
Widget toolReadLikeBody(SurfaceTokens tokens, String toolName, Map<String, dynamic> input, String mono) {
  final path = input['file_path'] ?? input['path'] ?? input['pattern'] ?? '';
  final extra = <String>[];
  if (toolName == 'Grep') {
    final pat = input['pattern'] as String?;
    if (pat != null && pat.isNotEmpty) extra.add('"$pat"');
  }
  final label = [path.toString(), ...extra].where((s) => s.isNotEmpty).join('  ');
  return ClideText(label.isNotEmpty ? label : toolName, fontSize: clideFontMeta, fontFamily: mono, color: tokens.globalForeground);
}

/// A muted file path line, shared across tool bodies.
Widget toolPathLine(SurfaceTokens tokens, String path, String mono) => Padding(
  padding: const EdgeInsets.only(bottom: 6),
  child: ClideText(path, fontSize: clideFontMeta, fontFamily: mono, color: tokens.globalTextMuted),
);

// -- shared note / free-text field -------------------------------------------

/// A no-Material single-ish-line text field (D-7) with a muted placeholder,
/// reused for permission notes and AskUserQuestion free-text.
class _NoteField extends StatefulWidget {
  const _NoteField({required this.controller, required this.placeholder});
  final TextEditingController controller;
  final String placeholder;
  @override
  State<_NoteField> createState() => _NoteFieldState();
}

class _NoteFieldState extends State<_NoteField> {
  final _focus = FocusNode();
  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: tokens.globalBackground,
        border: Border.all(color: tokens.panelBorder),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Stack(
        children: [
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: widget.controller,
            builder: (_, v, _) => v.text.isEmpty ? ClideText(widget.placeholder, muted: true, fontSize: clideFontSmall) : const SizedBox.shrink(),
          ),
          EditableText(
            controller: widget.controller,
            focusNode: _focus,
            style: TextStyle(fontSize: clideFontSmall, color: tokens.globalForeground, height: 1.3),
            cursorColor: tokens.globalFocus,
            backgroundCursorColor: tokens.globalTextMuted,
            maxLines: 3,
            minLines: 1,
          ),
        ],
      ),
    );
  }
}

// -- AskUserQuestion input parsing -------------------------------------------

class _Question {
  _Question(this.question, this.header, this.multiSelect, this.options);
  final String question;
  final String header;
  final bool multiSelect;
  final List<_Option> options;
}

class _Option {
  _Option(this.label, this.description);
  final String label;
  final String description;
}

List<_Question> _parseQuestions(Map<String, dynamic> input) {
  final raw = input['questions'];
  if (raw is! List) return const [];
  return [
    for (final q in raw)
      if (q is Map)
        _Question(q['question'] as String? ?? '', q['header'] as String? ?? '', q['multiSelect'] as bool? ?? false, [
          for (final o in (q['options'] as List? ?? const []))
            if (o is Map) _Option(o['label'] as String? ?? '', o['description'] as String? ?? ''),
        ]),
  ];
}
