/// Builds the "pick up this ticket" prompt injected into Claude (T-327).
///
/// Takes a `pql.tickets.show` ticket map (the same fields the detail pane
/// renders) and renders it as markdown with a lead-in telling Claude to start
/// working it and how to finish: commit via `/git-commit`, leave it in `review`.
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

  // The lead-in states the whole loop, not just the start, so the ending isn't
  // improvised per session — and the ticket ends in `review`, not `done`: the
  // agent doesn't mark its own work complete, the user does after looking (T-543).
  final id = field('id') ?? '?';
  final buf = StringBuffer()
    ..writeln('Pick up and start working this ticket. Read it fully, then begin.')
    ..writeln()
    ..writeln('1. Set it to `in_progress` now (`pql ticket status $id in_progress`) and keep its status honest as the work moves.')
    ..writeln('2. When the work is done, commit it with `/git-commit`.')
    ..writeln('3. Then set the ticket to `review`, not `done` — the user marks it done after reviewing.')
    ..writeln('4. End with a two-sentence summary and ask the user to review it.')
    ..writeln()
    ..writeln('**$id — ${field('title') ?? ''}**');
  if (meta.isNotEmpty) buf.writeln(meta);
  final desc = field('description');
  if (desc != null) {
    buf
      ..writeln()
      ..writeln(desc);
  }
  return buf.toString().trimRight();
}
