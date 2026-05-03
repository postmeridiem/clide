import 'dart:ui' show Color;

class TicketTypeColors {
  const TicketTypeColors({
    required this.initiative,
    required this.epic,
    required this.story,
    required this.task,
    required this.bug,
  });

  final Color initiative;
  final Color epic;
  final Color story;
  final Color task;
  final Color bug;

  Color forType(String? type) => switch (type) {
        'initiative' => initiative,
        'epic' => epic,
        'story' => story,
        'task' => task,
        'bug' => bug,
        _ => task,
      };

  static const dark = TicketTypeColors(
    initiative: Color(0xFFC792EA),
    epic: Color(0xFF78A0F8),
    story: Color(0xFF7DD3A8),
    task: Color(0xFF78809C),
    bug: Color(0xFFE87D7D),
  );

  static const light = TicketTypeColors(
    initiative: Color(0xFF7B2CB0),
    epic: Color(0xFF2962B8),
    story: Color(0xFF1D7A4E),
    task: Color(0xFF5A6070),
    bug: Color(0xFFC03030),
  );

  static TicketTypeColors forTheme({required bool dark}) => dark ? TicketTypeColors.dark : TicketTypeColors.light;
}
