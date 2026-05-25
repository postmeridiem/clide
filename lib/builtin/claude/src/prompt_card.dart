/// The interactive prompt surface for the stream-json control channel
/// (T-166, D-78): a permission Allow/Deny for a gated tool, or an
/// `AskUserQuestion` option picker. Rendered in the composer zone (not inline
/// in the conversation) so interaction and conversation widgets don't mix —
/// the pane swaps it in for the text input while a prompt is open. The decision
/// is returned via [onResolve]; the pane then removes the card.
///
/// Plain [ClideButton]s (Semantics buttons → keyboard/AT reachable), no
/// hover-revealed chrome that would fight the buttons.
library;

import 'package:clide/builtin/claude/src/stream_json_session.dart';
import 'package:clide/kernel/src/theme/controller.dart';
import 'package:clide/kernel/src/theme/tokens.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

class ToolPromptCard extends StatefulWidget {
  const ToolPromptCard({super.key, required this.prompt, required this.onResolve});

  final ToolPrompt prompt;

  /// Called once with the user's decision; the card binds the prompt id.
  final void Function(String promptId, ToolDecision decision) onResolve;

  @override
  State<ToolPromptCard> createState() => _ToolPromptCardState();
}

class _ToolPromptCardState extends State<ToolPromptCard> {
  // AskUserQuestion: per-question chosen option labels (set = multi-select).
  late List<Set<String>> _picked = List.generate(_questions.length, (_) => <String>{});

  List<_Question> get _questions => _parseQuestions(widget.prompt.input);

  @override
  void didUpdateWidget(ToolPromptCard old) {
    super.didUpdateWidget(old);
    // A different prompt rotated into the same slot — reset selections.
    if (old.prompt.promptId != widget.prompt.promptId) {
      _picked = List.generate(_questions.length, (_) => <String>{});
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    final isQuestion = widget.prompt.isQuestion;
    final accent = isQuestion ? tokens.statusInfo : tokens.statusWarning;
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
          ClideText(
            isQuestion ? 'question' : 'permission · ${widget.prompt.displayName}',
            fontSize: clideFontSmall,
            fontFamily: clideMonoFamily,
            color: accent,
          ),
          const SizedBox(height: 8),
          if (isQuestion) ..._questionBody(tokens) else ..._permissionBody(tokens),
        ],
      ),
    );
  }

  // -- permission allow/deny -------------------------------------------------

  List<Widget> _permissionBody(SurfaceTokens tokens) {
    final desc = widget.prompt.description;
    return [
      if (desc != null && desc.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ClideText(desc, fontSize: clideFontMeta, color: tokens.globalForeground),
        ),
      Row(
        children: [
          ClideButton(
            label: 'Allow',
            variant: ClideButtonVariant.primary,
            onPressed: () => widget.onResolve(widget.prompt.promptId, AllowTool(widget.prompt.input)),
          ),
          const SizedBox(width: 8),
          ClideButton(
            label: 'Deny',
            onPressed: () => widget.onResolve(widget.prompt.promptId, const DenyTool('Denied by the user.')),
          ),
        ],
      ),
    ];
  }

  // -- AskUserQuestion option picker ----------------------------------------

  List<Widget> _questionBody(SurfaceTokens tokens) {
    final questions = _questions;
    final answered = questions.asMap().entries.every((e) => _picked[e.key].isNotEmpty);
    return [
      for (final (qi, q) in questions.indexed) _questionBlock(tokens, qi, q),
      const SizedBox(height: 6),
      ClideButton(
        label: 'Submit',
        variant: ClideButtonVariant.primary,
        onPressed: answered ? () => _submitAnswers(questions) : null,
      ),
    ];
  }

  Widget _questionBlock(SurfaceTokens tokens, int qi, _Question q) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
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
              for (final opt in q.options)
                ClideButton(
                  label: _picked[qi].contains(opt.label) ? '● ${opt.label}' : '○ ${opt.label}',
                  variant: _picked[qi].contains(opt.label) ? ClideButtonVariant.primary : ClideButtonVariant.subtle,
                  tooltip: opt.description.isNotEmpty ? opt.description : null,
                  onPressed: () => _toggle(qi, q, opt.label),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _toggle(int qi, _Question q, String label) {
    setState(() {
      final sel = _picked[qi];
      if (q.multiSelect) {
        sel.contains(label) ? sel.remove(label) : sel.add(label);
      } else {
        sel
          ..clear()
          ..add(label);
      }
    });
  }

  void _submitAnswers(List<_Question> questions) {
    // answers: question text → chosen label(s), comma-separated for multi (D-78).
    final answers = <String, String>{};
    for (final (qi, q) in questions.indexed) {
      answers[q.question] = _picked[qi].join(', ');
    }
    widget.onResolve(widget.prompt.promptId, AllowTool({...widget.prompt.input, 'answers': answers}));
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
