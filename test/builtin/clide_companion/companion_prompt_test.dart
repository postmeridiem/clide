import 'package:clide/builtin/clide_companion/src/face_state.dart';
import 'package:clide/builtin/clide_companion/src/prompt/companion_prompt.dart';
import 'package:clide/builtin/clide_companion/src/prompt/companion_reply.dart';
import 'package:clide/builtin/clide_companion/src/prompt/digest_lines.dart';
import 'package:test/test.dart';

/// T-532 — the prompt, the lines we send, and the replies we get back.
///
/// Prompt text has no compiler and no type system, so these assert the parts
/// that CAN be checked: that nothing is left unfilled, that the vocabulary is
/// derived rather than duplicated, and — the load-bearing half — that a
/// malformed reply can never put scaffolding in Clide's mouth.
void main() {
  group('composing the system prompt', () {
    const brief = 'Watch. {about}\nReply in {language}.\nFaces: {faces}';

    test('every placeholder is filled', () {
      final out = composeSystemPrompt(brief: brief, localeSuffix: 'en_us', name: 'Jeroen', about: 'I care about tests.');

      expect(out, isNot(contains(kAboutPlaceholder)));
      expect(out, isNot(contains(kLanguagePlaceholder)));
      expect(out, isNot(contains(kFacesPlaceholder)));
      expect(out, isNot(contains('{')), reason: 'an unfilled placeholder eventually surfaces inside a reply');
    });

    test('the face vocabulary comes from the enum, not a second list', () {
      // The failure this prevents is silent: a mood the painter can draw but the
      // model was never offered, or worse the reverse.
      final out = composeSystemPrompt(brief: brief, localeSuffix: 'en_us');
      for (final f in kDeclarableFaces) {
        expect(out, contains('[${f.name}]'), reason: '${f.name} is declarable but was not offered');
      }
    });

    test('mechanical states are never offered', () {
      // He cannot know his own process died, so inviting him to say so invites
      // a lie.
      final out = composeSystemPrompt(brief: brief, localeSuffix: 'en_us');
      for (final f in [FaceState.error, FaceState.speaking, FaceState.effort, FaceState.listening, FaceState.pensive]) {
        expect(out, isNot(contains('[${f.name}]')), reason: '${f.name} is driven by his session, not chosen');
      }
    });

    test('authoring notes never reach him', () async {
      // Caught on the first live launch: the shipped brief opens with an HTML
      // comment explaining the file — ticket numbers, the fallback chain, "tuned
      // over 109 turns" — and all of it was going into the system prompt, four
      // paragraphs above the rule forbidding him to mention any of it.
      const withNote = '<!-- T-532: why this file exists, and how it was tuned -->\nWatch. {about} {language} {faces}';
      final out = composeSystemPrompt(brief: withNote, localeSuffix: 'en_us');

      expect(out, isNot(contains('T-532')));
      expect(out, isNot(contains('<!--')));
      expect(out, startsWith('Watch.'));
    });

    test('a multi-line note is stripped whole, not line by line', () {
      const withNote = '<!--\nline one\nline two\n-->\nWatch. {about} {language} {faces}';
      expect(composeSystemPrompt(brief: withNote, localeSuffix: 'en_us'), isNot(contains('line two')));
    });

    test('the language is named, not tagged', () {
      expect(composeSystemPrompt(brief: brief, localeSuffix: 'nl_nl'), contains('Reply in Dutch.'));
      expect(composeSystemPrompt(brief: brief, localeSuffix: 'en_us'), contains('Reply in English.'));
    });

    test('an unknown locale falls back to its tag rather than to nothing', () {
      expect(composeSystemPrompt(brief: brief, localeSuffix: 'fr_fr'), contains('Reply in fr_fr.'));
    });

    test('no name and no description yields no personal section at all', () {
      // "The developer is called the user" is worse than silence.
      final out = composeSystemPrompt(brief: brief, localeSuffix: 'en_us');
      expect(out, isNot(contains('Who you are watching')));
      expect(out, startsWith('Watch. \n'));
    });

    test('a description is quoted, so it reads as theirs', () {
      final out = composeSystemPrompt(brief: brief, localeSuffix: 'en_us', about: 'I hate flaky tests.');
      expect(out, contains('> I hate flaky tests.'));
    });

    test('the name is given but explicitly not for using', () {
      final out = composeSystemPrompt(brief: brief, localeSuffix: 'en_us', name: 'Jeroen');
      expect(out, contains('Jeroen'));
      expect(out, contains('you do not use it'), reason: 'a companion who says your name back sounds like a salesperson');
    });
  });

  group('the lines we send', () {
    test('an exchange carries both halves with neutral labels', () {
      final line = observedExchange(prompt: 'add a check', reply: 'Added.');
      expect(line, '[observed] user: add a check\n[observed] claude: Added.');
    });

    test('no name ever appears in a transcript line', () {
      // The name lives in the system prompt once. Repeating it per line is both
      // wasteful and, in his mouth, faintly creepy.
      final line = observedExchange(prompt: 'hi', reply: 'hello')!;
      expect(line, contains('user:'));
      expect(line, isNot(contains('Jeroen')));
    });

    test('an empty exchange is not a line at all', () {
      // Absence is silence: every line sent is an invitation to reply, so a line
      // describing nothing invites a remark about nothing.
      expect(observedExchange(prompt: '', reply: ''), isNull);
      expect(observedExchange(prompt: '  ', reply: '\n'), isNull);
    });

    test('half an exchange sends only the half that exists', () {
      expect(observedExchange(prompt: 'thinking out loud', reply: ''), '[observed] user: thinking out loud');
    });

    test('each kind of line is tagged distinctly', () {
      expect(directQuestion('what did that mean?'), startsWith('[direct] user:'));
      expect(eventNotice('the turn failed'), startsWith('[event]'));
      expect(lifecycleNotice('something changed'), startsWith('[notice]'));
    });

    test('the detach notice is warm and says what was lost', () {
      final n = detachedNotice(const Duration(minutes: 20));
      expect(n, startsWith('[notice]'));
      expect(n, contains('about 20 minutes'));
      expect(n, contains('missed'), reason: 'the useful part is the gap in what he knows, not that time passed');
      expect(n, contains('watching again'));
    });

    test('a detach duration is rounded, never zero', () {
      expect(detachedNotice(Duration.zero), contains('a minute or two'));
      expect(detachedNotice(const Duration(seconds: 90)), contains('a minute or two'));
      expect(detachedNotice(const Duration(hours: 3)), contains('about 3 hours'));
      expect(detachedNotice(const Duration(days: 2)), contains('a long while'));
    });
  });

  group('parsing his reply', () {
    test('a face and a remark', () {
      final r = parseCompanionReply('[unimpressed]\nThe hook was being annoying about something.');
      expect(r.face, FaceState.unimpressed);
      expect(r.say, 'The hook was being annoying about something.');
      expect(r.speaks, isTrue);
    });

    test('a face alone is silence, and silence is a complete answer', () {
      final r = parseCompanionReply('[idle]');
      expect(r.face, FaceState.idle);
      expect(r.say, isEmpty);
      expect(r.speaks, isFalse);
    });

    test('leading whitespace and a missing newline are tolerated', () {
      expect(parseCompanionReply('  [tired] long day').say, 'long day');
      expect(parseCompanionReply('  [tired] long day').face, FaceState.tired);
    });

    test('case is not worth losing a good reply over', () {
      expect(parseCompanionReply('[Concerned]\nthat again').face, FaceState.concerned);
    });

    group('the kill condition', () {
      test('an unreadable face keeps the previous expression rather than resetting', () {
        // Null means "leave what is on screen". A snap to neutral is a glitch
        // the user can see; an unchanged face is indistinguishable from having
        // nothing new to feel.
        expect(parseCompanionReply('just some prose').face, isNull);
      });

      test('an invented mood is dropped, not rendered and not shown as text', () {
        final r = parseCompanionReply('[ecstatic]\nnice one');
        expect(r.face, isNull, reason: 'the vocabulary is closed — an unknown name is no answer');
        expect(r.say, 'nice one', reason: 'and the tag must not survive into the bubble');
      });

      test('a mechanical state he is not allowed to claim is refused', () {
        expect(parseCompanionReply('[error]\nI died').face, isNull);
      });

      test('a JSON envelope never reaches the bubble', () {
        // The shape the rejected design would have produced. Cheap to strip, and
        // catastrophic if it lands in his mouth.
        final r = parseCompanionReply('[idle]\n{"mood": "idle", "say": "hello"}');
        expect(r.say, isNot(contains('{"mood"')));
      });

      test('a fenced block is unwrapped', () {
        final r = parseCompanionReply('[amused]\n```\nthat is a good one\n```');
        expect(r.say, 'that is a good one');
      });

      test('a stray second face tag is stripped from the text', () {
        final r = parseCompanionReply('[watching]\nstill here\n[idle]');
        expect(r.face, FaceState.watching);
        expect(r.say, 'still here');
      });

      test('garbage is silence, not an error and not visible', () {
        final r = parseCompanionReply('');
        expect(r.face, isNull);
        expect(r.speaks, isFalse);
      });

      test('a runaway reply is capped rather than allowed to fill the strip', () {
        final long = List.filled(200, 'word').join(' ');
        final r = parseCompanionReply('[idle]\n$long');
        expect(r.say.length, lessThanOrEqualTo(kMaxRemarkChars + 1));
        expect(r.say, endsWith('…'));
      });
    });
  });

  group('the face table covers the vocabulary', () {
    test('every state has a drawing recipe', () {
      // specFor is exhaustive by the compiler; this asserts the specs are real
      // rather than accidentally sharing one.
      for (final f in FaceState.values) {
        expect(specFor(f).eyes, isNotEmpty, reason: '${f.name} has no eyes');
      }
    });

    test('every glyph is one the fonts are known to carry', () {
      // The guard that has already caught this twice — katakana rain, then a
      // kaomoji hidden in rage.
      for (final f in FaceState.values) {
        final spec = specFor(f);
        for (final ch in '${spec.eyes}${spec.mouth}'.split('')) {
          expect(kVerifiedFaceGlyphs, contains(ch), reason: '${f.name} uses an unverified glyph: $ch');
        }
      }
    });

    test('no two states draw identically', () {
      // A duplicate is a state the user can never distinguish, which is the same
      // as not having it.
      final seen = <String, String>{};
      for (final f in FaceState.values) {
        final spec = specFor(f);
        final key = '${spec.eyes}|${spec.mouth}|${spec.jitter}|${spec.talkCycle}|${spec.thoughtDots}';
        expect(seen.containsKey(key), isFalse, reason: '${f.name} draws the same as ${seen[key]}');
        seen[key] = f.name;
      }
    });
  });
}
