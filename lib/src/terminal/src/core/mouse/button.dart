// Based on xterm.dart v4.0.0 by xuty (MIT). See LICENSE in this directory.

enum TerminalMouseButton {
  left(id: 0),

  middle(id: 1),

  right(id: 2),

  wheelUp(id: 64, isWheel: true),

  wheelDown(id: 65, isWheel: true),

  wheelLeft(id: 66, isWheel: true),

  wheelRight(id: 67, isWheel: true);

  /// The id that is used to report a button press or release to the terminal.
  ///
  /// Wheel buttons 4-7 are reported like buttons 1-4 with 64 added (xterm
  /// ctlseqs): 64 up, 65 down, 66 left, 67 right. The upstream values (64+4…)
  /// set the Shift bit too, so every scroll reached vim/tmux as Shift+wheel
  /// (T-628).
  final int id;

  /// Whether this button is a mouse wheel button.
  final bool isWheel;

  const TerminalMouseButton({required this.id, this.isWheel = false});
}
