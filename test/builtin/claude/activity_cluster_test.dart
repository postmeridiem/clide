/// Unit tests for the activity-card grouping pass (T-230).
library;

import 'package:clide/builtin/claude/src/activity_cluster.dart';
import 'package:clide/builtin/claude/src/transcript_reader.dart';
import 'package:test/test.dart';

var _n = 0;
final _ts = DateTime.utc(2026, 1, 1);

UserMessage _user([String t = 'hi']) => UserMessage(uuid: 'u${_n++}', timestamp: _ts, isSidechain: false, text: t);
AssistantTextMessage _prose([String t = 'sure']) => AssistantTextMessage(uuid: 'a${_n++}', timestamp: _ts, isSidechain: false, text: t);
AssistantThinkingMessage _think() => AssistantThinkingMessage(uuid: 't${_n++}', timestamp: _ts, isSidechain: false, thinking: '…');
AssistantToolUse _tool(String id, String name) =>
    AssistantToolUse(uuid: 'tu${_n++}', timestamp: _ts, isSidechain: false, toolUseId: id, name: name, input: const {});
ToolResultMessage _result(String id, {bool isError = false}) =>
    ToolResultMessage(uuid: 'r${_n++}', timestamp: _ts, isSidechain: false, toolUseId: id, content: '', isError: isError);

void main() {
  group('groupConversation', () {
    test('L1: a tool call + result fold into one cluster between sticky prose', () {
      final groups = groupConversation([_user(), _tool('1', 'Bash'), _result('1'), _prose()], FoldLevel.tools);
      expect(groups, hasLength(3));
      expect(groups[0], isA<StickyItem>());
      expect(groups[1], isA<FoldedCluster>());
      expect((groups[1] as FoldedCluster).items, hasLength(2)); // tool + result, in order
      expect(groups[2], isA<StickyItem>());
    });

    test('a sticky message seals the cluster and starts a new one after it', () {
      final groups = groupConversation([_tool('1', 'Bash'), _result('1'), _prose(), _tool('2', 'Bash'), _result('2')], FoldLevel.tools);
      expect(groups.map((g) => g.runtimeType.toString()), ['FoldedCluster', 'StickyItem', 'FoldedCluster']);
    });

    test('L1: diffs (Edit/Write) and thinking stay first-class', () {
      final groups = groupConversation([_think(), _tool('1', 'Edit'), _result('1')], FoldLevel.tools);
      // none fold at L1 → three sticky items, no cluster
      expect(groups.every((g) => g is StickyItem), isTrue);
      expect(groups, hasLength(3));
    });

    test('L2: thinking folds, diffs still first-class', () {
      final folded = groupConversation([_think(), _tool('1', 'Bash'), _result('1')], FoldLevel.thinking);
      expect(folded, hasLength(1));
      expect((folded.single as FoldedCluster).items, hasLength(3)); // think + tool + result

      final diff = groupConversation([_tool('1', 'Write'), _result('1')], FoldLevel.thinking);
      expect(diff.every((g) => g is StickyItem), isTrue);
    });

    test('L3: everything except user/prose folds, including diffs and thinking', () {
      final groups = groupConversation([_think(), _tool('1', 'Edit'), _result('1'), _tool('2', 'Bash'), _result('2')], FoldLevel.everything);
      expect(groups, hasLength(1));
      expect((groups.single as FoldedCluster).items, hasLength(5));
    });

    test('a failed result surfaces (sticky) and breaks the cluster', () {
      final groups = groupConversation([
        _tool('1', 'Bash'),
        _result('1', isError: true),
        _tool('2', 'Bash'),
        _result('2'),
      ], FoldLevel.tools);
      // [Folded([tool1]), Sticky(errorResult), Folded([tool2,result2])]
      expect(groups, hasLength(3));
      expect((groups[0] as FoldedCluster).items, hasLength(1));
      expect(groups[1], isA<StickyItem>());
      expect((groups[1] as StickyItem).item, isA<ToolResultMessage>());
      expect((groups[2] as FoldedCluster).items, hasLength(2));
    });

    test('switching level re-groups the same transcript', () {
      final items = [_tool('1', 'Bash'), _result('1'), _think()];
      expect(groupConversation(items, FoldLevel.tools).whereType<FoldedCluster>().single.items, hasLength(2));
      expect(groupConversation(items, FoldLevel.thinking).whereType<FoldedCluster>().single.items, hasLength(3));
    });

    test('empty input yields no groups', () {
      expect(groupConversation(const [], FoldLevel.tools), isEmpty);
    });
  });
}
