/// Compact MESSAGES section for the Team cockpit sidebar (T-180, part 5).
///
/// Displays the live broker chat timeline as colour-coded rows and provides a
/// quick @-post composer. Tapping the pop-out icon opens the full chat pane
/// (`claude.team-chat` workspace tab).
///
/// Both this widget and [TeamChatPane] read from the same [TeamChatModel] —
/// there is one model, two surfaces.
library;

import 'dart:async';

import 'package:clide/builtin/claude/src/at_commands.dart';
import 'package:clide/builtin/claude/src/team_broker.dart' show TeamBroker, TeamMessage;
import 'package:clide/builtin/claude/src/team_chat_model.dart';
import 'package:clide/builtin/claude/src/team_panel_host.dart' show teamColor;
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/services.dart' show KeyDownEvent, LogicalKeyboardKey;
import 'package:flutter/widgets.dart';

/// Compact broker chat section embedded in the Team sidebar.
///
/// [model] is the shared [TeamChatModel] from the orchestrator.
/// [broker] is used to read the current roster for @-completion.
/// [onPopOut] is called when the user taps the pop-out icon to open the full
///   pane — the extension wires this to `panels.activateTab`.
class TeamChatSidebar extends StatefulWidget {
  const TeamChatSidebar({super.key, required this.model, required this.broker, required this.onPopOut});

  final TeamChatModel model;
  final TeamBroker broker;
  final VoidCallback onPopOut;

  @override
  State<TeamChatSidebar> createState() => _TeamChatSidebarState();
}

class _TeamChatSidebarState extends State<TeamChatSidebar> {
  StreamSubscription<void>? _sub;
  final _controller = TextEditingController();
  final _focusNode = FocusNode(debugLabel: 'team-chat-sidebar');
  List<String> _suggestions = const [];
  AtQuery? _activeQuery;

  @override
  void initState() {
    super.initState();
    _sub = widget.model.changes.listen((_) {
      if (mounted) setState(() {});
    });
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _controller.text;
    final cursor = _controller.selection.baseOffset;
    if (cursor < 0) {
      _updateSuggestions(null);
      return;
    }
    final q = activeAtQuery(text, cursor);
    if (q == null) {
      _updateSuggestions(null);
      return;
    }
    final names = widget.broker.members.map((m) => m.name).where((n) => n != 'user');
    final matches = filterAtNames(q.query, names);
    _updateSuggestions(matches.isEmpty ? null : matches, query: q);
  }

  void _updateSuggestions(List<String>? suggestions, {AtQuery? query}) {
    final newSuggestions = suggestions ?? const <String>[];
    if (newSuggestions == _suggestions && query == _activeQuery) return;
    setState(() {
      _suggestions = newSuggestions;
      _activeQuery = query;
    });
  }

  void _completeName(String name) {
    final q = _activeQuery;
    if (q == null) return;
    final result = completeAt(_controller.text, q, name);
    _controller.value = TextEditingValue(
      text: result.text,
      selection: TextSelection.collapsed(offset: result.cursor),
    );
    setState(() {
      _suggestions = const [];
      _activeQuery = null;
    });
  }

  void _submit(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return;
    final parsed = parseAtTag(text);
    widget.model.postAsUser(parsed.body.isEmpty ? text : parsed.body, toName: parsed.recipient);
    _controller.clear();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
      setState(() {
        _suggestions = const [];
        _activeQuery = null;
      });
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    final messages = widget.model.messages;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header row with pop-out icon.
        Row(
          children: [
            Expanded(
              child: ClideText('MESSAGES', fontSize: clideFontSmall, color: tokens.globalTextMuted),
            ),
            Semantics(
              button: true,
              label: 'Open full chat pane',
              excludeSemantics: true,
              onTap: widget.onPopOut,
              child: ClideTappable(
                tooltip: 'Open full chat',
                onTap: widget.onPopOut,
                builder: (ctx, hovered, _) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                  child: ClideIcon(PhosphorIcons.byName('arrows-out-simple'), size: 10, color: hovered ? tokens.globalForeground : tokens.globalTextMuted),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Last 5 messages (compact feed).
        if (messages.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: ClideText('No messages yet.', muted: true, fontSize: clideFontSmall),
          )
        else
          for (final msg in messages.length > 5 ? messages.sublist(messages.length - 5) : messages)
            _ChatRow(key: ValueKey(msg.at.microsecondsSinceEpoch), message: msg, tokens: tokens),
        const SizedBox(height: 6),
        // Quick-post composer.
        ClideTypeahead(
          suggestions: _suggestions,
          onSelect: _completeName,
          formatLabel: (n) => '@$n',
          child: Focus(
            onKeyEvent: _handleKeyEvent,
            child: _ChatInputField(controller: _controller, focusNode: _focusNode, tokens: tokens, onSubmit: _submit, placeholder: '@name or @team …'),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Full team chat pane (workspace tab)
// ---------------------------------------------------------------------------

/// Full-height broker chat pane opened as a workspace tab (T-180).
///
/// Reads from the same [TeamChatModel] as [TeamChatSidebar]. Supports the
/// interrupt tickbox and full @-completion.
class TeamChatPane extends StatefulWidget {
  const TeamChatPane({super.key, required this.model, required this.broker});

  final TeamChatModel model;
  final TeamBroker broker;

  @override
  State<TeamChatPane> createState() => _TeamChatPaneState();
}

class _TeamChatPaneState extends State<TeamChatPane> {
  StreamSubscription<void>? _sub;
  final _controller = TextEditingController();
  final _focusNode = FocusNode(debugLabel: 'team-chat-pane');
  final _scrollController = ScrollController();
  List<String> _suggestions = const [];
  AtQuery? _activeQuery;
  bool _interrupt = false;

  @override
  void initState() {
    super.initState();
    _sub = widget.model.changes.listen((_) {
      if (mounted) {
        setState(() {});
        // Scroll to bottom on new message.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 120), curve: Curves.easeOut);
          }
        });
      }
    });
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _controller.text;
    final cursor = _controller.selection.baseOffset;
    if (cursor < 0) {
      _updateSuggestions(null);
      return;
    }
    final q = activeAtQuery(text, cursor);
    if (q == null) {
      _updateSuggestions(null);
      return;
    }
    final names = widget.broker.members.map((m) => m.name).where((n) => n != 'user');
    final matches = filterAtNames(q.query, names);
    _updateSuggestions(matches.isEmpty ? null : matches, query: q);
  }

  void _updateSuggestions(List<String>? suggestions, {AtQuery? query}) {
    final newSuggestions = suggestions ?? const <String>[];
    if (newSuggestions == _suggestions && query == _activeQuery) return;
    setState(() {
      _suggestions = newSuggestions;
      _activeQuery = query;
    });
  }

  void _completeName(String name) {
    final q = _activeQuery;
    if (q == null) return;
    final result = completeAt(_controller.text, q, name);
    _controller.value = TextEditingValue(
      text: result.text,
      selection: TextSelection.collapsed(offset: result.cursor),
    );
    setState(() {
      _suggestions = const [];
      _activeQuery = null;
    });
  }

  void _submit(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return;
    final parsed = parseAtTag(text);
    widget.model.postAsUser(parsed.body.isEmpty ? text : parsed.body, toName: parsed.recipient, interrupt: _interrupt);
    _controller.clear();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
      setState(() {
        _suggestions = const [];
        _activeQuery = null;
      });
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    final messages = widget.model.messages;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Pane header.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: tokens.panelBorder)),
          ),
          child: ClideText('Team Chat', fontSize: clideFontSmall, color: tokens.globalTextMuted),
        ),
        // Timeline.
        Expanded(
          child: messages.isEmpty
              ? Center(child: ClideText('No messages yet.', muted: true, fontSize: clideFontSmall))
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (_, i) => _ChatRow(key: ValueKey(messages[i].at.microsecondsSinceEpoch), message: messages[i], tokens: tokens),
                ),
        ),
        // Composer + interrupt tickbox.
        Container(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: tokens.panelBorder)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Interrupt tickbox.
              GestureDetector(
                onTap: () => setState(() => _interrupt = !_interrupt),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Semantics(
                        checked: _interrupt,
                        label: 'Interrupt target session',
                        excludeSemantics: true,
                        onTap: () => setState(() => _interrupt = !_interrupt),
                        child: Container(
                          width: 12,
                          height: 12,
                          margin: const EdgeInsets.only(right: 5),
                          decoration: BoxDecoration(
                            color: _interrupt ? tokens.globalFocus.withAlpha(40) : const Color(0x00000000),
                            border: Border.all(color: _interrupt ? tokens.globalFocus : tokens.globalTextMuted, width: 1),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: _interrupt ? Center(child: ClideIcon(PhosphorIcons.byName('check'), size: 9, color: tokens.globalFocus)) : null,
                        ),
                      ),
                      ClideText('Interrupt', fontSize: clideFontSmall, color: _interrupt ? tokens.globalForeground : tokens.globalTextMuted),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // Input field.
              ClideTypeahead(
                suggestions: _suggestions,
                onSelect: _completeName,
                formatLabel: (n) => '@$n',
                child: Focus(
                  onKeyEvent: _handleKeyEvent,
                  child: _ChatInputField(controller: _controller, focusNode: _focusNode, tokens: tokens, onSubmit: _submit, placeholder: '@name or @team …'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared sub-widgets
// ---------------------------------------------------------------------------

/// One chat row: colour-coded sender chip + optional `to` label + message text.
class _ChatRow extends StatelessWidget {
  const _ChatRow({super.key, required this.message, required this.tokens});

  final TeamMessage message;
  final SurfaceTokens tokens;

  @override
  Widget build(BuildContext context) {
    final senderColor = _senderColor(message.from, tokens);
    final toLabel = message.broadcast
        ? '→ all'
        : message.to != null
        ? '→ ${message.to}'
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Colour-coded sender chip.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            margin: const EdgeInsets.only(right: 5, top: 1),
            decoration: BoxDecoration(color: senderColor.withAlpha(30), borderRadius: BorderRadius.circular(2)),
            child: ClideText(message.from, fontSize: clideFontSmall, color: senderColor),
          ),
          if (toLabel != null)
            Padding(
              padding: const EdgeInsets.only(right: 5, top: 1),
              child: ClideText(toLabel, fontSize: clideFontSmall, color: tokens.globalTextMuted),
            ),
          Expanded(
            child: ClideText(message.text, fontSize: clideFontSmall, color: tokens.globalForeground),
          ),
        ],
      ),
    );
  }

  Color _senderColor(String from, SurfaceTokens tokens) {
    // User is always the focus colour.
    if (from == 'user') return tokens.globalFocus;
    // Agents use teamColor by name (same logic as the roster dot).
    return teamColor(from.toLowerCase(), fallback: tokens.globalForeground);
  }
}

/// Inline text input for the chat composer.
class _ChatInputField extends StatelessWidget {
  const _ChatInputField({required this.controller, required this.focusNode, required this.tokens, required this.onSubmit, required this.placeholder});

  final TextEditingController controller;
  final FocusNode focusNode;
  final SurfaceTokens tokens;
  final void Function(String text) onSubmit;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: tokens.panelBackground,
        border: Border.all(color: tokens.panelBorder),
        borderRadius: BorderRadius.circular(3),
      ),
      child: EditableText(
        controller: controller,
        focusNode: focusNode,
        style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: clideFontSmall, color: tokens.globalForeground, height: 1.4),
        cursorColor: tokens.globalFocus,
        backgroundCursorColor: tokens.globalTextMuted,
        onSubmitted: onSubmit,
      ),
    );
  }
}
