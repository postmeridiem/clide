/// Tests for the ClaudeConversation bus-addressing constants. The
/// TranscriptPublisher class this file used to cover was removed in the
/// T-385 dead-code sweep (no production constructor calls since the
/// stream-json pivot, D-77).
library;

import 'package:clide/builtin/claude/src/transcript_publisher.dart';
import 'package:clide/builtin/claude/src/transcript_reader.dart';
import 'package:test/test.dart';

void main() {
  group('ClaudeConversation addressing', () {
    test('sessionChannel + teammateChannel namespace by id', () {
      expect(ClaudeConversation.sessionChannel('abc-123'), 'conversation/abc-123');
      expect(ClaudeConversation.teammateChannel('coder@team-x'), 'conversation/coder@team-x');
    });

    test('memberStatusData encodes agentId + present status fields (T-157)', () {
      final full = ClaudeConversation.memberStatusData(
        'coder@team-x',
        const SessionStatus(model: 'claude-opus-4-7', permissionMode: 'plan', contextTokens: 21000),
      );
      expect(full, {'agentId': 'coder@team-x', 'model': 'claude-opus-4-7', 'permissionMode': 'plan', 'contextTokens': 21000});
      // Absent fields are omitted (only agentId is always present).
      expect(ClaudeConversation.memberStatusData('a', const SessionStatus()), {'agentId': 'a'});
    });
  });
}
