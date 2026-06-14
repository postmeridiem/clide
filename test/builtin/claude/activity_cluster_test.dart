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
AssistantToolUse _edit(String id, String path, {String name = 'Edit'}) =>
    AssistantToolUse(uuid: 'tu${_n++}', timestamp: _ts, isSidechain: false, toolUseId: id, name: name, input: {'file_path': path});
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
      final groups = groupConversation([_tool('1', 'Bash'), _result('1', isError: true), _tool('2', 'Bash'), _result('2')], FoldLevel.tools);
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

    test('a Workflow run stays first-class even at L3, never folded (T-416)', () {
      // At every fold level the Workflow tool-use owns its own card so the live
      // run card can render — it must not fold into a generic Activity cluster.
      for (final level in FoldLevel.values) {
        final groups = groupConversation([_tool('1', 'Workflow'), _result('1')], level);
        expect(groups.first, isA<StickyItem>(), reason: '$level');
        expect((groups.first as StickyItem).item, isA<AssistantToolUse>(), reason: '$level');
      }
    });

    test('an image card stays first-class even at L3 (everything)', () {
      final img = ImageMessage(uuid: 'i${_n++}', timestamp: _ts, isSidechain: false, path: '/abs/shot.png');
      final groups = groupConversation([_tool('1', 'Bash'), _result('1'), img], FoldLevel.everything);
      // The tool + result fold; the image is sticky and seals the cluster.
      expect(groups.map((g) => g.runtimeType.toString()), ['FoldedCluster', 'StickyItem']);
      expect((groups[1] as StickyItem).item, isA<ImageMessage>());
    });
  });

  group('fold-level persistence helpers (T-235)', () {
    test('foldLevelFromName parses known names, defaults to L1 (tools)', () {
      expect(foldLevelFromName('none'), FoldLevel.none);
      expect(foldLevelFromName('tools'), FoldLevel.tools);
      expect(foldLevelFromName('thinking'), FoldLevel.thinking);
      expect(foldLevelFromName('everything'), FoldLevel.everything);
      expect(foldLevelFromName(null), FoldLevel.tools);
      expect(foldLevelFromName('bogus'), FoldLevel.tools);
    });

    test('nextFoldLevel cycles none → tools → thinking → everything → none', () {
      expect(nextFoldLevel(FoldLevel.none), FoldLevel.tools);
      expect(nextFoldLevel(FoldLevel.tools), FoldLevel.thinking);
      expect(nextFoldLevel(FoldLevel.thinking), FoldLevel.everything);
      expect(nextFoldLevel(FoldLevel.everything), FoldLevel.none);
    });
  });

  group('editFilePath', () {
    test('reads the file of an edit tool-use; null otherwise', () {
      expect(editFilePath(_edit('1', '/a/b.dart')), '/a/b.dart');
      expect(editFilePath(_edit('1', '/a/b.dart', name: 'Write')), '/a/b.dart');
      expect(editFilePath(_tool('1', 'Bash')), isNull); // not a diff tool
      expect(editFilePath(_tool('1', 'Edit')), isNull); // diff tool, but no file_path
      expect(editFilePath(_prose()), isNull);
    });
  });

  group('coalesceEditRuns (T-296)', () {
    test('consecutive same-file edits bundle into one EditRun', () {
      final out = coalesceEditRuns([StickyItem(_edit('1', '/a')), StickyItem(_edit('2', '/a')), StickyItem(_edit('3', '/a'))]);
      expect(out, hasLength(1));
      expect(out.single, isA<EditRun>());
      final run = out.single as EditRun;
      expect(run.edits, hasLength(3));
      expect(run.filePath, '/a');
    });

    test('a lone edit stays a StickyItem (not a one-item run)', () {
      final out = coalesceEditRuns([StickyItem(_edit('1', '/a')), StickyItem(_prose())]);
      expect(out.first, isA<StickyItem>());
      expect((out.first as StickyItem).item, isA<AssistantToolUse>());
    });

    test('a different file starts a new run', () {
      final out = coalesceEditRuns([StickyItem(_edit('1', '/a')), StickyItem(_edit('2', '/a')), StickyItem(_edit('3', '/b')), StickyItem(_edit('4', '/b'))]);
      expect(out.map((g) => g.runtimeType.toString()), ['EditRun', 'EditRun']);
      expect((out[0] as EditRun).filePath, '/a');
      expect((out[1] as EditRun).filePath, '/b');
    });

    test('an interleaving non-edit group splits the run (the worked example)', () {
      // 3 edits to /a, a folded Read cluster, then 7 edits to /a → [3 edits][cluster][7 edits].
      final groups = <RenderGroup>[
        for (var i = 0; i < 3; i++) StickyItem(_edit('a$i', '/a')),
        FoldedCluster([_tool('r', 'Read'), _result('r')]),
        for (var i = 0; i < 7; i++) StickyItem(_edit('b$i', '/a')),
      ];
      final out = coalesceEditRuns(groups);
      expect(out.map((g) => g.runtimeType.toString()), ['EditRun', 'FoldedCluster', 'EditRun']);
      expect((out[0] as EditRun).edits, hasLength(3));
      expect((out[2] as EditRun).edits, hasLength(7));
    });

    test('a sticky non-edit between edits breaks the run', () {
      final out = coalesceEditRuns([StickyItem(_edit('1', '/a')), StickyItem(_prose()), StickyItem(_edit('2', '/a'))]);
      // edit (lone) → sticky, prose → sticky, edit (lone) → sticky.
      expect(out.map((g) => g.runtimeType.toString()), ['StickyItem', 'StickyItem', 'StickyItem']);
    });
  });

  group('agent spawns are their own card (T-342)', () {
    test('two consecutive Agent spawns yield two separate cards, not one cluster', () {
      final groups = groupConversation([_tool('1', 'Task'), _tool('2', 'Task')], FoldLevel.tools);
      expect(groups, hasLength(2));
      expect(groups.every((g) => g is StickyItem), isTrue);
    });

    test('an agent spawn breaks an Activity cluster of sibling tools', () {
      final groups = groupConversation([_tool('1', 'Bash'), _result('1'), _tool('2', 'Task'), _tool('3', 'Bash'), _result('3')], FoldLevel.tools);
      expect(groups.map((g) => g.runtimeType.toString()), ['FoldedCluster', 'StickyItem', 'FoldedCluster']);
      expect(((groups[1] as StickyItem).item as AssistantToolUse).name, 'Task');
    });

    test("the SDK 'Agent' tool is treated as an agent spawn too", () {
      expect(groupConversation([_tool('1', 'Agent')], FoldLevel.tools).single, isA<StickyItem>());
    });

    test('agents stay first-class even at L3 (everything), so parallel agents never merge', () {
      final groups = groupConversation([_tool('1', 'Task'), _tool('2', 'Task')], FoldLevel.everything);
      expect(groups, hasLength(2));
      expect(groups.every((g) => g is StickyItem), isTrue);
    });

    test('regression: consecutive Bash calls still form one Activity cluster', () {
      final groups = groupConversation([_tool('1', 'Bash'), _result('1'), _tool('2', 'Bash'), _result('2')], FoldLevel.tools);
      expect(groups, hasLength(1));
      expect((groups.single as FoldedCluster).items, hasLength(4));
    });
  });
}
