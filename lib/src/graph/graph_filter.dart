/// Client-side filtering of a loaded [VaultGraph] (T-323): narrow to the notes
/// near the active one (depth-from-active), and/or by tag include/exclude.
///
/// Pure — the controller feeds in the already-queried tag map, so this runs
/// under `dart test`. The file glob is NOT here: a different glob is a
/// different file set, so it re-queries pql; these three refine what's already
/// loaded.
library;

import 'package:clide/src/graph/vault_graph.dart';

class GraphFilter {
  const GraphFilter({this.depth, this.includeTags = const {}, this.excludeTags = const {}});

  /// Hops from the active note to keep; null = the whole graph (no depth limit).
  final int? depth;

  /// Keep only notes tagged with at least one of these (empty = no filter).
  final Set<String> includeTags;

  /// Drop notes tagged with any of these.
  final Set<String> excludeTags;

  bool get isEmpty => depth == null && includeTags.isEmpty && excludeTags.isEmpty;

  GraphFilter copyWith({int? depth, bool clearDepth = false, Set<String>? includeTags, Set<String>? excludeTags}) =>
      GraphFilter(depth: clearDepth ? null : (depth ?? this.depth), includeTags: includeTags ?? this.includeTags, excludeTags: excludeTags ?? this.excludeTags);

  /// Apply this filter to [full], using [tagsByPath] for the tag predicates and
  /// [activePath] as the depth root. A depth filter with no active path (or one
  /// that isn't a node) yields an empty graph — there's no local graph to show.
  VaultGraph apply(VaultGraph full, {required Map<String, Set<String>> tagsByPath, String? activePath}) {
    if (isEmpty) return full;
    Set<String> tagsOf(String id) => tagsByPath[id] ?? const {};
    var keep = {for (final n in full.nodes) n.id};
    if (includeTags.isNotEmpty) {
      keep = keep.where((id) => tagsOf(id).any(includeTags.contains)).toSet();
    }
    if (excludeTags.isNotEmpty) {
      keep = keep.where((id) => !tagsOf(id).any(excludeTags.contains)).toSet();
    }
    if (depth != null) {
      keep = activePath == null ? <String>{} : keep.intersection(full.nodesWithin(activePath, depth!));
    }
    return full.subgraph(keep);
  }
}
