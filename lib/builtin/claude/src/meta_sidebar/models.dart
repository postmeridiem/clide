/// Shared models + table geometry for the Claude meta sidebar's tabs.
/// Split out of claude_meta_sidebar.dart (T-395).
library;

import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

/// The shared label-column width + row pitch the Activity and Config tables
/// both use, so toggling between tabs keeps every value at the same x and y.
const double kMetaLabelColumnWidth = 110;
const double kMetaRowPitch = 6;

/// Type scale for the sidebar tables (T-414 styling pass): labels/values read
/// at meta size (13) — the old 12px-everything read as bland and cramped.
const double kMetaFont = clideFontMeta;

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
  child: ClideText(text, muted: true, fontSize: kMetaFont),
);

/// Small-caps section header (mono, uppercase) — the same treatment the settings
/// overlay uses (settings_category_view `_SectionCard`), so the Claude meta
/// sidebar and the settings modal read as one card system (T-158 facelift).
Widget metaSectionHeader(BuildContext context, SurfaceTokens tokens, String label) => Padding(
  padding: const EdgeInsets.only(left: 2, bottom: 6),
  child: ClideText(label.toUpperCase(), fontSize: clideFontCaption, color: tokens.sidebarSectionHeader, fontFamily: ClideSettings.fonts.monoOf(context)),
);

/// An elevated card (the settings card surface) wrapping divider-separated
/// [rows]: `panelHeader` fill, `dividerColor` hairline border, 6px radius.
Widget metaCard(SurfaceTokens tokens, List<Widget> rows) => ClideSurface(
  color: tokens.panelHeader,
  border: tokens.dividerColor,
  borderRadius: BorderRadius.circular(6),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < rows.length; i++) ...[if (i > 0) const ClideDivider(), rows[i]],
    ],
  ),
);

/// One label→value row sized for the card interior — the shared label column
/// then the value, uniform with the settings field rows.
Widget metaCardRow(SurfaceTokens tokens, MetaRow r) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: kMetaLabelColumnWidth,
        child: ClideText(r.label, muted: true, fontSize: kMetaFont),
      ),
      Expanded(
        child: ClideText(r.value, fontSize: kMetaFont, color: r.valueColor ?? tokens.globalForeground),
      ),
    ],
  ),
);

/// Key→value sections rendered as carded blocks (Activity + Config).
Widget buildMetaTable(BuildContext context, SurfaceTokens tokens, List<MetaSection> sections) =>
    ListView(padding: const EdgeInsets.all(12), children: metaTableChildren(context, tokens, sections));

/// The carded sections without the enclosing ListView, for tabs that compose
/// extra widgets around them (the Activity tab's control strip, T-415): a
/// small-caps header above an elevated card of label→value rows.
List<Widget> metaTableChildren(BuildContext context, SurfaceTokens tokens, List<MetaSection> sections) {
  final children = <Widget>[];
  for (var i = 0; i < sections.length; i++) {
    final s = sections[i];
    children.add(
      Padding(
        padding: EdgeInsets.only(top: i == 0 ? 0 : 16),
        child: metaSectionHeader(context, tokens, s.header),
      ),
    );
    children.add(metaCard(tokens, [for (final r in s.rows) metaCardRow(tokens, r)]));
  }
  return children;
}
