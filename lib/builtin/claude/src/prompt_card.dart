/// The interactive prompt surface for the stream-json control channel
/// (T-166, T-175, T-176, D-78): a permission Allow / Allow-and-remember / Deny,
/// or an `AskUserQuestion` picker (single = bare; multi = stepper + review).
/// Rendered in the composer zone (not inline in the conversation) so
/// interaction and conversation widgets don't mix — the pane swaps it in for
/// the text input while a prompt is open. The decision is returned via
/// [onResolve]; the pane then removes the card.
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
import 'package:flutter/widgets.dart';

/// Sentinel option key for the always-present free-text "Other…" choice.
const _kOther = '\u0000other';

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
    return Container(
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
          ClideText(label, fontSize: clideFontSmall, fontFamily: clideMonoFamily, color: accent),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  // -- permission allow / allow-remember / deny ------------------------------

  (Color, String, List<Widget>) _permission(SurfaceTokens tokens) {
    final p = widget.prompt;
    final canRemember = p.permissionSuggestions.isNotEmpty;
    String? note() {
      final t = _note.text.trim();
      return t.isEmpty ? null : t;
    }

    void allow({bool remember = false}) => widget.onResolve(
          p.promptId,
          AllowTool(p.input, updatedPermissions: remember ? p.permissionSuggestions : null, followUpNote: note()),
        );
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
          child: SingleChildScrollView(child: _inputBody(tokens, p)),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ClideButton(label: 'Allow', variant: ClideButtonVariant.primary, onPressed: () => allow()),
            if (canRemember) ClideButton(label: "Allow & don't ask again", onPressed: () => allow(remember: true)),
            ClideButton(label: 'Deny', onPressed: () => widget.onResolve(p.promptId, DenyTool(note() ?? 'Denied by the user.'))),
          ],
        ),
        const SizedBox(height: 10),
        _NoteField(controller: _note, placeholder: 'add a note (optional) — sent to Claude'),
      ],
    );
  }

  /// Render the tool input in the shape that best fits the tool. Delegates to
  /// the shared top-level helpers (also used by ConversationView — T-168).
  Widget _inputBody(SurfaceTokens tokens, ToolPrompt p) => toolInputBody(tokens, p.toolName, p.input);

  // -- AskUserQuestion: single = bare, multi = stepper + review --------------

  (Color, String, List<Widget>) _question(SurfaceTokens tokens) {
    if (_q.length <= 1) {
      return (
        tokens.statusInfo,
        'question',
        [
          if (_q.isNotEmpty) _questionBody(tokens, 0),
          const SizedBox(height: 6),
          Row(children: [
            ClideButton(label: 'Submit', variant: ClideButtonVariant.primary, onPressed: (_q.isNotEmpty && _answer(0).isNotEmpty) ? _submit : null),
            const Spacer(),
            _chatInstead(tokens),
          ]),
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
          Row(children: [
            ClideButton(label: '‹ Back', onPressed: () => setState(() => _step = _q.length - 1)),
            const SizedBox(width: 8),
            ClideButton(label: 'Submit answers', variant: ClideButtonVariant.primary, onPressed: _allAnswered ? _submit : null),
          ]),
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
        Row(children: [
          if (_step > 0) ...[
            ClideButton(label: '‹ Back', onPressed: () => setState(() => _step--)),
            const SizedBox(width: 8),
          ],
          ClideButton(
            label: last ? 'Review ›' : 'Next ›',
            variant: ClideButtonVariant.primary,
            onPressed: answered ? () => setState(() => _step++) : null,
          ),
          const Spacer(),
          _chatInstead(tokens),
        ]),
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
        chips.add(Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
              color: tokens.globalFocus.withValues(alpha: 0.18), border: Border.all(color: tokens.statusInfo), borderRadius: BorderRadius.circular(4)),
          child: ClideText(text, fontSize: clideFontMeta, fontFamily: clideMonoFamily, color: tokens.globalForeground),
        ));
      } else {
        chips.add(ClideText(text, fontSize: clideFontMeta, fontFamily: clideMonoFamily, color: done ? tokens.statusSuccess : tokens.globalTextMuted));
      }
    }
    chips.add(ClideText('Review', fontSize: clideFontMeta, fontFamily: clideMonoFamily, color: tokens.globalTextMuted));
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
          SizedBox(width: 110, child: ClideText(head, fontSize: clideFontMeta, color: tokens.globalTextMuted)),
          Expanded(child: ClideText('→ ${_answer(qi)}', fontSize: clideFontSmall, color: tokens.globalForeground)),
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
        if (q.header.isNotEmpty) ClideText(q.header.toUpperCase(), fontSize: clideFontMeta, fontFamily: clideMonoFamily, color: tokens.globalTextMuted),
        Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 6),
          child: ClideText(q.question, color: tokens.globalForeground),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final opt in q.options) _optButton(qi, opt.label, opt.label, q.multiSelect, opt.description),
            _optButton(qi, _kOther, 'Other…', q.multiSelect, ''),
          ],
        ),
        if (hasOther) ...[
          const SizedBox(height: 8),
          _NoteField(controller: _other[qi], placeholder: 'type your answer…'),
        ],
        const SizedBox(height: 8),
        _NoteField(controller: _qnote[qi], placeholder: '+ note (optional)'),
      ],
    );
  }

  Widget _optButton(int qi, String key, String label, bool multi, String description) {
    final sel = _picked[qi].contains(key);
    return ClideButton(
      label: '${sel ? '●' : '○'} $label',
      variant: sel ? ClideButtonVariant.primary : ClideButtonVariant.subtle,
      tooltip: description.isNotEmpty ? description : null,
      onPressed: () => setState(() {
        final s = _picked[qi];
        if (multi) {
          s.contains(key) ? s.remove(key) : s.add(key);
        } else {
          s
            ..clear()
            ..add(key);
        }
      }),
    );
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
Widget toolInputBody(SurfaceTokens tokens, String toolName, Map<String, dynamic> input) {
  switch (toolName) {
    case 'Bash':
      return toolBashBody(tokens, input);
    case 'Write':
      return toolWriteBody(tokens, input);
    case 'Edit':
    case 'MultiEdit':
      return toolEditBody(tokens, input);
    case 'Read':
    case 'Grep':
    case 'LS':
      return toolReadLikeBody(tokens, toolName, input);
    default:
      return ClideCodeBlock(source: const JsonEncoder.withIndent('  ').convert(input), language: 'json');
  }
}

/// Bash tool body: the command as a shell code block, with optional background
/// / timeout annotations.
Widget toolBashBody(SurfaceTokens tokens, Map<String, dynamic> input) {
  final cmd = (input['command'] as String? ?? '').trimRight();
  final notes = <String>[
    if (input['run_in_background'] == true) 'background',
    if (input['timeout'] is num) 'timeout ${input['timeout']}ms',
  ];
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
Widget toolWriteBody(SurfaceTokens tokens, Map<String, dynamic> input) {
  final path = input['file_path'] as String? ?? '';
  final content = input['content'] as String? ?? '';
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      if (path.isNotEmpty) toolPathLine(tokens, path),
      ClideCodeBlock(source: content, language: grammarForPath(path)),
    ],
  );
}

/// Edit / MultiEdit tool body: before/after diff view.
Widget toolEditBody(SurfaceTokens tokens, Map<String, dynamic> input) {
  final path = input['file_path'] as String? ?? '';
  final oldStr = input['old_string'] as String? ?? '';
  final newStr = input['new_string'] as String? ?? '';
  final lang = grammarForPath(path);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      if (path.isNotEmpty) toolPathLine(tokens, path),
      ClideText('— before', fontSize: clideFontMeta, color: tokens.globalTextMuted, fontFamily: clideMonoFamily),
      const SizedBox(height: 4),
      ClideCodeBlock(source: oldStr, language: lang),
      const SizedBox(height: 8),
      ClideText('+ after', fontSize: clideFontMeta, color: tokens.globalTextMuted, fontFamily: clideMonoFamily),
      const SizedBox(height: 4),
      ClideCodeBlock(source: newStr, language: lang),
    ],
  );
}

/// Read / Grep / LS body: show the file path or pattern as a one-liner label
/// so the card stays compact. These tools produce the interesting output in the
/// result card rather than their input.
Widget toolReadLikeBody(SurfaceTokens tokens, String toolName, Map<String, dynamic> input) {
  final path = input['file_path'] ?? input['path'] ?? input['pattern'] ?? '';
  final extra = <String>[];
  if (toolName == 'Grep') {
    final pat = input['pattern'] as String?;
    if (pat != null && pat.isNotEmpty) extra.add('"$pat"');
  }
  final label = [path.toString(), ...extra].where((s) => s.isNotEmpty).join('  ');
  return ClideText(
    label.isNotEmpty ? label : toolName,
    fontSize: clideFontMeta,
    fontFamily: clideMonoFamily,
    color: tokens.globalForeground,
  );
}

/// A muted file path line, shared across tool bodies.
Widget toolPathLine(SurfaceTokens tokens, String path) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ClideText(path, fontSize: clideFontMeta, fontFamily: clideMonoFamily, color: tokens.globalTextMuted),
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
            builder: (_, v, __) => v.text.isEmpty ? ClideText(widget.placeholder, muted: true, fontSize: clideFontSmall) : const SizedBox.shrink(),
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
        _Question(
          q['question'] as String? ?? '',
          q['header'] as String? ?? '',
          q['multiSelect'] as bool? ?? false,
          [
            for (final o in (q['options'] as List? ?? const []))
              if (o is Map) _Option(o['label'] as String? ?? '', o['description'] as String? ?? ''),
          ],
        ),
  ];
}
