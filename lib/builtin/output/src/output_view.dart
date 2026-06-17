/// The Output tab of the bottom dock (T-54 / D-87): a read-only, filterable,
/// auto-scrolling view of the [LogRing].
library;

import 'package:clide/kernel/kernel.dart';
import 'package:clide/kernel/src/log_ring.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

import 'output_controller.dart';

class OutputView extends StatefulWidget {
  const OutputView({super.key, required this.ring, this.initialLevel, this.onMinLevelChanged});

  /// The retained log buffer to render. The view owns a controller over it
  /// but never the ring itself (the app owns that).
  final LogRing ring;

  /// Initial verbosity (the kernel logger's current level) + the sink that
  /// applies a chip change to the kernel + persists it (T-433).
  final LogLevel? initialLevel;
  final void Function(LogLevel)? onMinLevelChanged;

  @override
  State<OutputView> createState() => _OutputViewState();
}

class _OutputViewState extends State<OutputView> {
  late final OutputController _c = OutputController(widget.ring, initialLevel: widget.initialLevel, onMinLevelChanged: widget.onMinLevelChanged);
  final ScrollController _scroll = ScrollController();

  /// Follow the tail until the user scrolls up; resumes when they return to
  /// the bottom.
  bool _following = true;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onChange);
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final atBottom = _scroll.offset >= _scroll.position.maxScrollExtent - 8;
    if (atBottom != _following) setState(() => _following = atBottom);
  }

  void _onChange() {
    if (_following) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });
    }
  }

  void _jumpToLatest() {
    setState(() => _following = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _c
      ..removeListener(_onChange)
      ..dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final tokens = ClideSettings.theme.of(context).surface;
        final rows = _c.filtered;
        return Semantics(
          label: 'output log',
          container: true,
          explicitChildNodes: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(tokens),
              Expanded(
                child: rows.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: ClideText(widget.ring.isEmpty ? 'No output yet.' : 'No output matches the filter.', muted: true),
                      )
                    : Stack(
                        children: [
                          SingleChildScrollView(
                            controller: _scroll,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: [for (final r in rows) _LogRow(record: r)],
                            ),
                          ),
                          if (!_following) Positioned(right: 12, bottom: 8, child: _JumpPill(onTap: _jumpToLatest)),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _header(SurfaceTokens tokens) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.panelBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ClideFilterBox(address: 'output.panel', hint: 'Filter…', onChanged: _c.setText),
          ),
          const SizedBox(width: 8),
          _Chip(label: 'Level: ${_c.minLevel.name}', onTap: () => _c.setMinLevel(LogLevel.values[(_c.minLevel.index + 1) % LogLevel.values.length])),
          const SizedBox(width: 6),
          _Chip(label: 'Source: ${_c.source ?? 'all'}', onTap: _cycleSource),
          const SizedBox(width: 6),
          _Chip(label: 'Clear', onTap: _c.clear),
        ],
      ),
    );
  }

  void _cycleSource() {
    final options = <String?>[null, ...widget.ring.sources];
    final i = options.indexOf(_c.source);
    _c.setSource(options[(i + 1) % options.length]);
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              border: Border.all(color: tokens.panelBorder),
              borderRadius: BorderRadius.circular(4),
            ),
            child: ClideText(label, fontSize: clideFontCaption, color: tokens.globalTextMuted),
          ),
        ),
      ),
    );
  }
}

class _JumpPill extends StatelessWidget {
  const _JumpPill({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
    return Semantics(
      button: true,
      label: 'jump to latest',
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: tokens.panelHeader,
              border: Border.all(color: tokens.globalFocus),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClideText('Jump to latest ↓', fontSize: clideFontCaption, color: tokens.globalFocus),
          ),
        ),
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.record});
  final LogRecord record;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
    final fg = _levelColor(record.level, tokens);
    final t = record.timestamp;
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    final ss = t.second.toString().padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClideText('$hh:$mm:$ss', fontSize: clideFontMono, color: tokens.globalTextMuted, fontFamily: ClideSettings.fonts.monoOf(context)),
          const SizedBox(width: 8),
          SizedBox(
            width: 48,
            child: ClideText(record.level.name.toUpperCase(), fontSize: clideFontMono, color: fg, fontFamily: ClideSettings.fonts.monoOf(context)),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 92,
            child: ClideText(
              record.source,
              fontSize: clideFontMono,
              color: tokens.globalTextMuted,
              fontFamily: ClideSettings.fonts.monoOf(context),
              maxLines: 1,
              overflow: TextOverflow.clip,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClideText(record.message, fontSize: clideFontMono, color: fg, fontFamily: ClideSettings.fonts.monoOf(context)),
          ),
        ],
      ),
    );
  }

  Color _levelColor(LogLevel level, SurfaceTokens tokens) => switch (level) {
    LogLevel.error => tokens.statusError,
    LogLevel.warn => tokens.statusWarning,
    LogLevel.info => tokens.globalForeground,
    LogLevel.debug || LogLevel.trace => tokens.globalTextMuted,
  };
}
