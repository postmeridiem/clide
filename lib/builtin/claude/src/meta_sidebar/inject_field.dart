/// Inline text input for injecting a message into a session (T-171).
/// Submits on Enter; Cancel is handled by the parent's icon button.
/// Split out of claude_meta_sidebar.dart (T-395).
library;

import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

class InjectTextField extends StatelessWidget {
  const InjectTextField({super.key, required this.controller, required this.tokens, required this.onSubmit});

  final TextEditingController controller;
  final SurfaceTokens tokens;
  final void Function(String text) onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: tokens.panelBackground,
        border: Border.all(color: tokens.panelBorder),
        borderRadius: BorderRadius.circular(3),
      ),
      child: EditableText(
        controller: controller,
        focusNode: FocusNode(debugLabel: 'inject-${controller.hashCode}')..requestFocus(),
        style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: clideFontSmall, color: tokens.globalForeground, height: 1.4),
        cursorColor: tokens.globalFocus,
        backgroundCursorColor: tokens.globalTextMuted,
        onSubmitted: onSubmit,
      ),
    );
  }
}
