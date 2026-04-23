import 'dart:async';

import 'package:clide/builtin/markdown/src/markdown_viewer.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

class MarkdownExtension extends ClideExtension {
  @override
  String get id => 'builtin.markdown';
  @override
  String get title => 'Markdown';
  @override
  String get version => '0.3.0';
  @override
  List<String> get dependsOn => const [];

  StreamSubscription<Message>? _sub;

  @override
  List<ContributionPoint> get contributions => [
        TabContribution(
          id: 'markdown.viewer',
          slot: Slots.contextPanel,
          title: 'Markdown',
          icon: PhosphorIcons.fileText,
          build: (_) => const MarkdownViewer(),
        ),
      ];

  @override
  Future<void> activate(ClideExtensionContext ctx) async {
    _sub = ctx.messages.subscribe(publisher: id, channel: 'selection').listen((msg) {
      final path = msg.data['path'] as String?;
      if (path == null) return;
      ctx.panels.activateTab(Slots.contextPanel, 'markdown.viewer');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ctx.messages.publish(id, 'load', {'path': path});
      });
    });
  }

  @override
  Future<void> deactivate() async => _sub?.cancel();
}
