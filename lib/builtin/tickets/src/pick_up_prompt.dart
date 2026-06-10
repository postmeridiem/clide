/// Builds the "pick up this ticket" prompt injected into Claude (T-327).
///
/// Takes a `pql.tickets.show` ticket map (the same fields the detail pane
/// renders) and renders it as markdown with a one-line lead-in telling Claude
/// to start working it.
library;

String pickUpPrompt(Map<String, Object?> ticket) {
  String? field(String key) {
    final v = ticket[key];
    final s = v is String ? v.trim() : null;
    return (s == null || s.isEmpty) ? null : s;
  }

  final meta = <String>[
    if (field('type') != null) field('type')!,
    if (field('status') != null) field('status')!,
    if (field('priority') != null) field('priority')!,
    if (field('parent_id') != null) 'parent ${field('parent_id')}',
    if (field('decision_ref') != null) field('decision_ref')!,
    if (field('assigned_to') != null) '@${field('assigned_to')}',
  ].join(' · ');

  final buf = StringBuffer()
    ..writeln('Pick up and start working this ticket. Read it fully, then begin.')
    ..writeln()
    ..writeln('**${field('id') ?? '?'} — ${field('title') ?? ''}**');
  if (meta.isNotEmpty) buf.writeln(meta);
  final desc = field('description');
  if (desc != null) {
    buf
      ..writeln()
      ..writeln(desc);
  }
  return buf.toString().trimRight();
}
