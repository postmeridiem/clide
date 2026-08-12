import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:clide/builtin/claude/src/conversation_controller.dart';
import 'package:clide/builtin/claude/src/transcript_reader.dart';
import 'package:clide/builtin/claude/src/turn_signals.dart';
import 'package:clide/builtin/clide_companion/src/companion_popout.dart';
import 'package:clide/builtin/clide_companion/src/companion_usage_line.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/kernel_fixture.dart';

/// T-513's acceptance bar asks for golden coverage of the companion, and until
/// now it stopped at the ambient half — `clide_face_*` and `clide_strip_*`. The
/// popout is the surface someone reads when they have actually asked Clide
/// something, and it is where Epic E put the answer, his conversation and the
/// spend line. It had widget tests and no pixels.
///
/// Not routed through the shared `harness()`: that hands down an
/// `Overlay(canSizeOverlay)` under a zero-size MediaQuery, and the popout's
/// `Expanded` over a `ListView` needs bounded height or it throws. A tight tree
/// is the documented remedy.
Widget _host(KernelFixture f, Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: ClideKernel(
    services: f.services,
    child: ClideTheme(
      controller: f.services.theme,
      child: MediaQuery(
        data: const MediaQueryData(size: Size(900, 640)),
        child: SizedBox(width: 900, height: 640, child: child),
      ),
    ),
  ),
);

UserMessage _asked(String text) => UserMessage(uuid: 'u-$text', timestamp: DateTime(2026), isSidechain: false, text: '[direct] user: $text');

AssistantTextMessage _said(String face, String text) =>
    AssistantTextMessage(uuid: 'a-$text', timestamp: DateTime(2026), isSidechain: false, text: '[$face]\n$text');

/// The line has no background of its own — it sits on the popout's panel. Drawn
/// on anything else the golden would record muted text against a colour it will
/// never meet, which is the sort of golden that passes while the real surface
/// goes unreadable.
Widget _onPanel(Widget child) => Builder(
  builder: (context) => ColoredBox(
    color: ClideSettings.theme.of(context).surface.panelBackground,
    child: Align(
      alignment: Alignment.topLeft,
      child: Padding(padding: const EdgeInsets.all(12), child: child),
    ),
  ),
);

/// The measured figures (spike §9), so the line is drawn against numbers it
/// will really see — a total dominated by cache reads, and an output dominated
/// by thinking.
const _measured = TurnUsage(inputTokens: 20, outputTokens: 147, cacheCreationTokens: 16586, cacheReadTokens: 54482, thinkingTokens: 133, costUsd: 0.0393752);

void main() {
  late KernelFixture f;
  late StreamController<ConversationItem> stream;

  setUp(() async {
    f = await KernelFixture.create();
    stream = StreamController<ConversationItem>.broadcast();
  });

  tearDown(() async {
    await stream.close();
    await f.dispose();
  });

  goldenTest(
    'CompanionPopout — nothing said, and an exchange',
    fileName: 'clide_popout_states',
    builder: () => GoldenTestGroup(
      columns: 1,
      children: [
        GoldenTestScenario(
          name: 'empty',
          // "Nothing said yet" rather than a blank panel: an empty surface reads
          // as broken, and his silence is the ordinary state.
          child: _host(f, CompanionPopout(conversation: null, onDismiss: () {}, onAsk: (_) {})),
        ),
        GoldenTestScenario(
          name: 'exchange',
          // Latest last in the tree, latest first on screen (reverse: true). His
          // side carries the green edge, the developer's carries none — which is
          // the only thing distinguishing who spoke.
          child: _host(
            f,
            CompanionPopout(
              conversation: ConversationController(
                stream: stream.stream,
                seed: [
                  _asked('what did that mean?'),
                  _said('watching', 'The timeout was never the problem — the retry loop swallowed the first failure.'),
                  _asked('so the fix is upstream?'),
                  _said('concerned', 'One layer up, yes. Where the loop decides a failure is worth repeating.'),
                ],
              ),
              onDismiss: () {},
              onAsk: (_) {},
            ),
          ),
        ),
      ],
    ),
  );

  goldenTest(
    'CompanionUsageLine — the spend, with the split',
    fileName: 'clide_usage_line',
    builder: () => GoldenTestGroup(
      columns: 1,
      children: [
        GoldenTestScenario(
          name: 'measured',
          child: _host(f, _onPanel(const CompanionUsageLine(total: _measured, turns: 2))),
        ),
        GoldenTestScenario(
          name: 'nothing spent',
          // Draws nothing at all. A row of zeros would read as a broken
          // instrument rather than an idle one.
          child: _host(f, _onPanel(const CompanionUsageLine(total: TurnUsage(), turns: 0))),
        ),
      ],
    ),
  );
}
