/// Shared models + table geometry for the Claude meta sidebar's tabs.
/// Split out of claude_meta_sidebar.dart (T-395).
library;

import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

/// The shared label-column width + row pitch the Activity and Config tables
/// both use, so toggling between tabs keeps every value at the same x and y.
const double kMetaLabelColumnWidth = 110;
const double kMetaRowPitch = 4;

/// The sidebar's sub-tabs.
enum SidebarTab { activity, team, config }

// T-183: accordion sections for the Config tab.
enum ConfigSection { skills, agents, commands, hooks, permissions, mcpServers }

/// Permission kind for colour-coding in the Config tab (T-183).
enum ConfigPermKind { allow, ask, deny }

class MetaSection {
  const MetaSection(this.header, this.rows);
  final String header;
  final List<MetaRow> rows;
}

class MetaRow {
  const MetaRow(this.label, this.value, {this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;
}

/// The muted empty-state body shared by every tab.
Widget metaPlaceholder(String text) => Padding(
  padding: const EdgeInsets.all(12),
  child: ClideText(text, muted: true, fontSize: clideFontSmall),
);

/// Key→value sections on the shared table geometry (Activity + Config).
Widget buildMetaTable(SurfaceTokens tokens, List<MetaSection> sections) {
  final children = <Widget>[];
  for (var i = 0; i < sections.length; i++) {
    final s = sections[i];
    children.add(
      Padding(
        padding: EdgeInsets.only(top: i == 0 ? 0 : 16, bottom: 6),
        child: ClideText(s.header, fontSize: clideFontSmall, color: tokens.globalTextMuted),
      ),
    );
    for (final r in s.rows) {
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: kMetaRowPitch),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: kMetaLabelColumnWidth,
                child: ClideText(r.label, muted: true, fontSize: clideFontSmall),
              ),
              Expanded(
                child: ClideText(r.value, fontSize: clideFontSmall, color: r.valueColor ?? tokens.globalForeground),
              ),
            ],
          ),
        ),
      );
    }
  }
  return ListView(padding: const EdgeInsets.all(12), children: children);
}
