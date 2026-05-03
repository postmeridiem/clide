import 'dart:ui' show Color;

class DecisionTypeColors {
  const DecisionTypeColors({
    required this.confirmed,
    required this.question,
    required this.rejected,
  });

  final Color confirmed;
  final Color question;
  final Color rejected;

  Color forType(String? type) => switch (type) {
        'confirmed' => confirmed,
        'question' => question,
        'rejected' => rejected,
        _ => confirmed,
      };

  static const dark = DecisionTypeColors(
    confirmed: Color(0xFF7DD3A8),
    question: Color(0xFFE6C370),
    rejected: Color(0xFFE87D7D),
  );

  static const light = DecisionTypeColors(
    confirmed: Color(0xFF1D7A4E),
    question: Color(0xFFB08A20),
    rejected: Color(0xFFC03030),
  );

  static DecisionTypeColors forTheme({required bool dark}) => dark ? DecisionTypeColors.dark : DecisionTypeColors.light;
}
