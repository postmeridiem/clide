INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7MFNNCC0MMY2TCNRM', 'status', 'backlog', 'done', NULL, '2026-06-01 06:49:47', '2026-06-01 06:49:47', '2026-06-01 06:49:47', NULL, 'd01cd9475509936871f5e07807a097d4', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4M2Z9YZ0SA81E5Q08', 'status', 'backlog', 'done', NULL, '2026-06-01 07:08:16', '2026-06-01 07:08:16', '2026-06-01 07:08:16', NULL, 'ae07d922d86b83eea2fbb963bbcb6d92', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7G8QBJ2PNQ0VREN24', 'status', 'backlog', 'done', NULL, '2026-06-01 10:45:14', '2026-06-01 10:45:14', '2026-06-01 10:45:14', NULL, '1037eb231ea647a4e17aea463f708b32', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM6NTYAB8K6T50F8W00', 'status', 'backlog', 'done', NULL, '2026-06-01 10:45:14', '2026-06-01 10:45:14', '2026-06-01 10:45:14', NULL, '8fe7feadcc03bb1e3ceeaeca835361c1', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM6HQXNNF05GXWK7BWM', 'status', 'backlog', 'done', NULL, '2026-06-01 11:31:39', '2026-06-01 11:31:39', '2026-06-01 11:31:39', NULL, 'd4ad9825be347244bc6624b52d76f34c', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM68APBCQTMGJAZ2B9C', 'status', 'backlog', 'in_progress', NULL, '2026-06-01 11:38:40', '2026-06-01 11:38:40', '2026-06-01 11:38:40', NULL, '7609e453ad138021a14142027f2f9194', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM68APBCQTMGJAZ2B9C', 'status', 'in_progress', 'done', NULL, '2026-06-01 12:35:04', '2026-06-01 12:35:04', '2026-06-01 12:35:04', NULL, '25b0507cee1798ad969ed31b7e498bff', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4RAKSX59W1HJCZ1M8', 'status', 'backlog', 'done', NULL, '2026-06-01 14:04:24', '2026-06-01 14:04:24', '2026-06-01 14:04:24', NULL, '8be6673880b1cc36c8e0199ca088ae27', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM57GY6PTG78SD3961M', 'status', 'backlog', 'in_progress', NULL, '2026-06-01 14:27:48', '2026-06-01 14:27:48', '2026-06-01 14:27:48', NULL, 'f7ab0f672fac7ca65089062bf84f7a68', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM57GY6PTG78SD3961M', 'status', 'in_progress', 'done', NULL, '2026-06-01 14:45:39', '2026-06-01 14:45:39', '2026-06-01 14:45:39', NULL, 'a1942351599d79a7a3a17ca1119f38ca', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7G8QBJ2PNQ0VREN24', 'description', 'Opening a file in the editor (the reader''s edit pencil, a non-.md file-tree click, a decision''s edit) calls editor.open and the daemon opens the buffer, but the editor pane never appears in the workspace slot above the Claude pane. Root cause: EditorExtension contributes a workspace tab (editor.active, priority 80) but has no activate() that reveals/activates it. editor.opened is emitted on the DaemonBus, but the EditorController that handles it only exists once EditorView is mounted — and nothing ever activates the editor tab to mount it. Fix: add EditorExtension.activate() subscribing to the editor.opened / editor.active-changed DaemonEvents and calling panels.activateTab(Slots.workspace, ''editor.active''). EditorView.hydrate() already pulls the active buffer on mount, so reveal-then-hydrate avoids any publish/subscribe race.', 'Opening a file in the editor (the reader''s edit pencil, a non-.md file-tree click, a decision''s edit) calls editor.open and the daemon opens the buffer, but the editor pane never appears in the workspace slot above the Claude pane. Root cause: EditorExtension contributes a workspace tab (editor.active, priority 80) but has no activate() that reveals/activates it. editor.opened is emitted on the DaemonBus, but the EditorController that handles it only exists once EditorView is mounted — and nothing ever activates the editor tab to mount it. Fix: add EditorExtension.activate() subscribing to the editor.opened / editor.active-changed DaemonEvents and calling panels.activateTab(Slots.workspace, ''editor.active''). EditorView.hydrate() already pulls the active buffer on mount, so reveal-then-hydrate avoids any publish/subscribe race.

Reopened fix (2026-06-01): the original fix called panels.activateTab(Slots.workspace, ''editor.active''), but _WorkspaceSlot renders its editor split off arrangement.editorOpen, NOT the active tab — so the editor never appeared. Real fix: EditorExtension.activate now calls arrangement.openEditor() on editor.opened / active-changed(non-null) and closeEditor() on active-changed(null). Test asserts arrangement.editorOpen.', NULL, '2026-06-01 16:36:38', '2026-06-01 16:36:38', '2026-06-01 16:36:38', NULL, 'f726405105c00c3b78d27ea41dbddb69', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM643F7Z648KNFPT7GR', 'status', 'backlog', 'done', NULL, '2026-06-01 16:48:56', '2026-06-01 16:48:56', '2026-06-01 16:48:56', NULL, '6e7ea043976756151dce11d92afe46eb', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5A3984KFPD4NKRG6M', 'status', 'backlog', 'done', NULL, '2026-06-01 16:48:56', '2026-06-01 16:48:56', '2026-06-01 16:48:56', NULL, 'b7ac3a9ef35ca1e86e9f4b7d1c5a716a', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5V7GHH42RHV04DPTR', 'description', 'Ship a Vim-compatible keybinding preset with modal editing support (normal/insert/visual modes). Maps Vim motions and commands to clide editor and navigation actions. Users select it in settings.

**Unblocked by T-117 (2026-05-17):** the keystroke mapper layer is in place; modal Vim presets are more involved than the VS Code preset (T-64) because modes need to be expressed as scope flags (`vim.normal`, `vim.insert`, `vim.visual`) that the when-clause grammar can branch on. Implementation work:

1. Author `assets/keymaps/vim.yaml` using the typed Intents + `command:<id>` bindings.
2. Add a small mode-tracking service that publishes `vim.<mode>` scope flags via `KeymapService.setScopeFlag`.
3. Bind `Esc` to mode-reset → normal; `i` (when `vim.normal`) → enter insert; etc.

**Acceptance:**
1. `assets/keymaps/vim.yaml` ships covering the documented Vim default keybindings for editor / navigation / panes.
2. `KeymapService.setPreset("vim")` + the mode-tracking service together produce correct mode transitions.
3. A regression test exercises a representative motion (`j` → cursor down) and a mode change (`i` → insert).', 'Ship a Vim-compatible keybinding preset with modal editing support (normal/insert/visual modes). Maps Vim motions and commands to clide editor and navigation actions. Users select it in settings.

**Unblocked by T-117 (2026-05-17):** the keystroke mapper layer is in place; modal Vim presets are more involved than the VS Code preset (T-64) because modes need to be expressed as scope flags (`vim.normal`, `vim.insert`, `vim.visual`) that the when-clause grammar can branch on. Implementation work:

1. Author `assets/keymaps/vim.yaml` using the typed Intents + `command:<id>` bindings.
2. Add a small mode-tracking service that publishes `vim.<mode>` scope flags via `KeymapService.setScopeFlag`.
3. Bind `Esc` to mode-reset → normal; `i` (when `vim.normal`) → enter insert; etc.

**Acceptance:**
1. `assets/keymaps/vim.yaml` ships covering the documented Vim default keybindings for editor / navigation / panes.
2. `KeymapService.setPreset("vim")` + the mode-tracking service together produce correct mode transitions.
3. A regression test exercises a representative motion (`j` → cursor down) and a mode change (`i` → insert).

Refinement (2026-06-01): scoped Vim-first for a Vim-power-user demo this weekend. ''Author a YAML file'' was wrong — T-117 shipped single-chord resolution + scope flags + when-clauses only. Decomposed into children: T-204 (fix dead default preset — live bug), T-205 (key-sequence + count resolution), T-206 (modal editor motion/edit intents), T-207 (Vim mode service + status indicator). T-65 itself becomes assets/keymaps/vim.yaml + regression tests once children land. T-64/T-66 deferred (single-chord, easy; T-205 hands JetBrains shift+shift later). Foundation is shared, not Vim-only.', NULL, '2026-06-01 18:49:02', '2026-06-01 18:49:02', '2026-06-01 18:49:02', NULL, 'afdcc3d8c3172572295bda81d14d57c3', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM65R8CNFNE1MA5GGR0', 'status', 'backlog', 'in_progress', NULL, '2026-06-01 18:49:17', '2026-06-01 18:49:17', '2026-06-01 18:49:17', NULL, 'd1d00e87c8a85caf4423088b1f878986', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM65R8CNFNE1MA5GGR0', 'status', 'in_progress', 'done', NULL, '2026-06-01 18:51:08', '2026-06-01 18:51:08', '2026-06-01 18:51:08', NULL, '0eb0b244f4042b1c824377cd1c1f6ee2', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM6M83TTXHRXESFZY14', 'status', 'backlog', 'in_progress', NULL, '2026-06-01 18:51:08', '2026-06-01 18:51:08', '2026-06-01 18:51:08', NULL, '916d8491cc454c7d44a104d3b812508e', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM6M83TTXHRXESFZY14', 'status', 'in_progress', 'done', NULL, '2026-06-01 18:59:19', '2026-06-01 18:59:19', '2026-06-01 18:59:19', NULL, 'b22efca89b75981440429ab2ea7b3145', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4PH1J6ENYT4PJZRHG', 'status', 'backlog', 'in_progress', NULL, '2026-06-01 19:07:16', '2026-06-01 19:07:16', '2026-06-01 19:07:16', NULL, '0431c8509983a583f02561f9a2a98584', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4PH1J6ENYT4PJZRHG', 'status', 'in_progress', 'done', NULL, '2026-06-01 19:12:01', '2026-06-01 19:12:01', '2026-06-01 19:12:01', NULL, 'e7711ec17cf8ce4889d9add12fe0ec78', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5REFZXMY8ESWN0Z90', 'status', 'backlog', 'in_progress', NULL, '2026-06-01 19:16:58', '2026-06-01 19:16:58', '2026-06-01 19:16:58', NULL, '8706054876918dcd7b72d627ad5a0886', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5REFZXMY8ESWN0Z90', 'status', 'in_progress', 'done', NULL, '2026-06-01 19:27:18', '2026-06-01 19:27:18', '2026-06-01 19:27:18', NULL, '0c14bf0e4b32866f53fddea3a4d39874', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5V7GHH42RHV04DPTR', 'status', 'backlog', 'in_progress', NULL, '2026-06-01 19:29:15', '2026-06-01 19:29:15', '2026-06-01 19:29:15', NULL, '40a6c8cde0f6e877c94789be50d6072e', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4C2PSN2GVJY9JDSZG', 'status', 'backlog', 'in_progress', NULL, '2026-06-03 08:57:22', '2026-06-03 08:57:22', '2026-06-03 08:57:22', NULL, '187776e23e5382336dca17791c1b91ad', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM48QJV4N7J62436GC0', 'status', 'backlog', 'in_progress', NULL, '2026-06-03 08:57:22', '2026-06-03 08:57:22', '2026-06-03 08:57:22', NULL, '4fbd68d687c6114c261d72d01694c130', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7171NRB1T82TGP5RG', 'status', 'backlog', 'in_progress', NULL, '2026-06-03 08:57:22', '2026-06-03 08:57:22', '2026-06-03 08:57:22', NULL, 'bb31db8ac05e0781039b5f2723f52900', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM48QJV4N7J62436GC0', 'status', 'in_progress', 'done', NULL, '2026-06-03 09:00:37', '2026-06-03 09:00:37', '2026-06-03 09:00:37', NULL, '35bb14c9f80fb36fa2d7decd958a588f', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4C2PSN2GVJY9JDSZG', 'status', 'in_progress', 'done', NULL, '2026-06-03 09:00:37', '2026-06-03 09:00:37', '2026-06-03 09:00:37', NULL, '6bd82e40072507fa0e384385c54d7569', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7171NRB1T82TGP5RG', 'status', 'in_progress', 'done', NULL, '2026-06-03 09:00:37', '2026-06-03 09:00:37', '2026-06-03 09:00:37', NULL, 'afa0e367a353939ab53a9b6d5407c16e', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM54WTNQDMYT0AVR4WM', 'status', 'backlog', 'in_progress', NULL, '2026-06-03 09:02:26', '2026-06-03 09:02:26', '2026-06-03 09:02:26', NULL, 'b8797e42960837b03a01d99703ad4e9e', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM54WTNQDMYT0AVR4WM', 'description', 'Gap 5 from self-analysis.md — foundational. Two distinct ''Claude inside clide'' stories with different gaps: (A) the clide-HOSTED stream-json session (D-77/D-78) — the user''s primary Claude pane, which itself needs `clide` on PATH to drive the surrounding IDE; (B) an EXTERNAL agent (e.g. a Claude Code harness, TERM_PROGRAM=zed as observed) driving via `clide ...` IPC, which clide cannot fully observe because plain file reads / `make test` / `git` bypass clide. Decide the intended model — hosted, external, or both — and record it under governance/ (claim via `pql decisions claim`). Gates how Epic B bootstraps and how Epic C frames observability.', 'Gap 5 from self-analysis.md — foundational. Two distinct ''Claude inside clide'' stories with different gaps: (A) the clide-HOSTED stream-json session (D-77/D-78) — the user''s primary Claude pane, which itself needs `clide` on PATH to drive the surrounding IDE; (B) an EXTERNAL agent (e.g. a Claude Code harness, TERM_PROGRAM=zed as observed) driving via `clide ...` IPC, which clide cannot fully observe because plain file reads / `make test` / `git` bypass clide. Decide the intended model — hosted, external, or both — and record it under governance/ (claim via `pql decisions claim`). Gates how Epic B bootstraps and how Epic C frames observability.

Resolved (2026-06-03): recorded as D-83. Decision — clide commits to BOTH agent models with the clide-HOSTED stream-json session (D-77/D-78) as the PRIMARY dogfood target (the one clide spawns, so the one Epic B/T-214 bootstraps: CLIDE_SOCK/CLIDE_WORKSPACE + PATH + context note + Bash(clide *) allow rule), and the EXTERNAL CLI driver (D-68) as a first-class but SECONDARY, best-effort integration (manual install via T-212; no promise to observe its non-clide tool use). Epic C/T-218 parity is scoped to clide''s own surfaces reflected through the CLI in both directions; an external agent''s side-channel reads/tests/git are out of parity scope.', NULL, '2026-06-03 09:05:48', '2026-06-03 09:05:48', '2026-06-03 09:05:48', NULL, 'a4f8bca0289b2780e9f33e8e06526d18', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM54WTNQDMYT0AVR4WM', 'status', 'in_progress', 'done', NULL, '2026-06-03 09:05:50', '2026-06-03 09:05:50', '2026-06-03 09:05:50', NULL, '6d719202dfc0f7ede73f662877866339', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4TP6KXTB1GHKBW1G4', 'status', 'backlog', 'in_progress', NULL, '2026-06-03 09:09:43', '2026-06-03 09:09:43', '2026-06-03 09:09:43', NULL, '0ac74e2c7e822baccd7c3ece16e7d45a', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7WYF8ESBSGAQF1S48', 'status', 'backlog', 'in_progress', NULL, '2026-06-03 09:09:43', '2026-06-03 09:09:43', '2026-06-03 09:09:43', NULL, '4e2c7153e283f0adae41bf07065f52d2', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM51CNEJP52P79RDVJW', 'status', 'backlog', 'in_progress', NULL, '2026-06-03 09:09:43', '2026-06-03 09:09:43', '2026-06-03 09:09:43', NULL, '7d241cc8007d77fae8b9e16831cbab0f', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4TP6KXTB1GHKBW1G4', 'status', 'in_progress', 'done', NULL, '2026-06-03 09:18:28', '2026-06-03 09:18:28', '2026-06-03 09:18:28', NULL, '200a9081bd33a4605032d41299d0c941', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM51CNEJP52P79RDVJW', 'status', 'in_progress', 'done', NULL, '2026-06-03 09:18:28', '2026-06-03 09:18:28', '2026-06-03 09:18:28', NULL, '2f7785e83b6d61ac50f496c63c08ed9f', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7WYF8ESBSGAQF1S48', 'status', 'in_progress', 'done', NULL, '2026-06-03 09:18:28', '2026-06-03 09:18:28', '2026-06-03 09:18:28', NULL, '41464449dc880ed73c650939c86dea8d', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM78J2H2S0R79SSSPW8', 'status', 'backlog', 'done', NULL, '2026-06-03 09:18:38', '2026-06-03 09:18:38', '2026-06-03 09:18:38', NULL, 'a2404bd89e073a8d1de6ddc0cfdf1ed1', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM6EGSD0SB7NYNSP1BM', 'status', 'backlog', 'in_progress', NULL, '2026-06-03 09:27:42', '2026-06-03 09:27:42', '2026-06-03 09:27:42', NULL, '0308666b00afe834a02b5609cf60bb0d', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM6Y5SET5WGSS2W78F8', 'status', 'backlog', 'in_progress', NULL, '2026-06-03 09:27:42', '2026-06-03 09:27:42', '2026-06-03 09:27:42', NULL, '1619d3e444a106191b1cfda6ba904d9a', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM6GJRWZVHZF24TPPS4', 'status', 'backlog', 'ready', NULL, '2026-06-03 09:45:20', '2026-06-03 09:45:20', '2026-06-03 09:45:20', NULL, '973b1a79789f833bb05211bf7a2b4ee3', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7XZQJAK31WRVQ0HGW', 'parent_id', NULL, 'T-229', NULL, '2026-06-03 09:51:40', '2026-06-03 09:51:40', '2026-06-03 09:51:40', NULL, '050fec48818561926864cde99393b993', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7SA9TEX5CNMTG67MW', 'parent_id', 'T-132', 'T-229', NULL, '2026-06-03 09:51:40', '2026-06-03 09:51:40', '2026-06-03 09:51:40', NULL, '531388662e6a061043a78e1686d6b6df', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5PFAYE4XH7WV6VDW8', 'parent_id', NULL, 'T-229', NULL, '2026-06-03 09:51:40', '2026-06-03 09:51:40', '2026-06-03 09:51:40', NULL, '9f2293a98e0b87246feaac42f150a826', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7XZQJAK31WRVQ0HGW', 'status', 'backlog', 'in_progress', NULL, '2026-06-03 09:54:14', '2026-06-03 09:54:14', '2026-06-03 09:54:14', NULL, 'ca8dd4bb0889d0ff8d8592ddc1d6cde0', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7XZQJAK31WRVQ0HGW', 'status', 'in_progress', 'done', NULL, '2026-06-03 10:02:02', '2026-06-03 10:02:02', '2026-06-03 10:02:02', NULL, 'a61466ef8c2a93b46b35daacc65139af', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7SA9TEX5CNMTG67MW', 'status', 'backlog', 'in_progress', NULL, '2026-06-03 10:02:02', '2026-06-03 10:02:02', '2026-06-03 10:02:02', NULL, 'c74a338b9ca8abc44e5757385f182117', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5PFAYE4XH7WV6VDW8', 'status', 'backlog', 'in_progress', NULL, '2026-06-03 10:05:55', '2026-06-03 10:05:55', '2026-06-03 10:05:55', NULL, '3d9ffdedd706c9d22a8a1b5ed3d79368', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7SA9TEX5CNMTG67MW', 'status', 'in_progress', 'done', NULL, '2026-06-03 10:05:55', '2026-06-03 10:05:55', '2026-06-03 10:05:55', NULL, 'b18f69871ba45d519a33aaddb77ea445', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5PFAYE4XH7WV6VDW8', 'status', 'in_progress', 'done', NULL, '2026-06-03 10:09:26', '2026-06-03 10:09:26', '2026-06-03 10:09:26', NULL, '7854c38c9e89ea8dd00b01feb717123d', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM68T660K07YH3X5DH0', 'status', 'backlog', 'done', NULL, '2026-06-03 10:09:26', '2026-06-03 10:09:26', '2026-06-03 10:09:26', NULL, '8b19904e021d0fddd1b9e66c5e7afdd8', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM6Y5SET5WGSS2W78F8', 'status', 'in_progress', 'done', NULL, '2026-06-03 10:31:10', '2026-06-03 10:31:10', '2026-06-03 10:31:10', NULL, '7e93a13c82485ac3c85432616f7fc3ae', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM6EGSD0SB7NYNSP1BM', 'description', 'For UI-driven (non-IPC) opens and focus changes, mirror the active file + selection into EditorRegistry (lib/src/editor/registry.dart, read by editor_commands.dart:120/136) so `editor active` / `editor list` track what the user is actually looking at, not only IPC-opened buffers. Acceptance: focusing/opening a file in the GUI is reflected in `clide editor active`.', 'For UI-driven (non-IPC) opens and focus changes, mirror the active file + selection into EditorRegistry (lib/src/editor/registry.dart, read by editor_commands.dart:120/136) so `editor active` / `editor list` track what the user is actually looking at, not only IPC-opened buffers. Acceptance: focusing/opening a file in the GUI is reflected in `clide editor active`.

Resolved (2026-06-03): done by prior editor work, not new code. Verified by reading the flow: openWorkspaceFile (file_open.dart) routes non-.md opens through the editor.open IPC verb -> EditorRegistry.open -> _setActive, so file-tree/quick-open opens already populate ''editor active''/''editor list''; tab switches go through editor.activate; and editor_view._onTextChanged pushes editor.set-content on caret-only moves too (its guard skips only when BOTH text and selection are unchanged), so selection is reflected. The probe saw editor active=null only because no code file was open (just the Claude pane / a markdown reader) -- correct, not a gap. The genuine remainder -- the read-only markdown/decisions READER''s currently-viewed file (routed via the D-81 ReaderNav bus, not editor.open, and rightly NOT an EditorRegistry buffer) -- is folded into T-221 (clide status: focused file + selection). Editor-reflects-opens claim is code-read, to be confirmed on the next live run.', NULL, '2026-06-03 10:59:22', '2026-06-03 10:59:22', '2026-06-03 10:59:22', NULL, 'd1839e13b815c81ca14968e9380e2da4', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM6EGSD0SB7NYNSP1BM', 'status', 'in_progress', 'done', NULL, '2026-06-03 10:59:25', '2026-06-03 10:59:25', '2026-06-03 10:59:25', NULL, 'd71b7b9293734e4022bd942fd2cb2cf2', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM758PXMJH16PA3JHFW', 'description', 'Gap 6. Add a `status` command to the dispatcher (currently unknown -> exit 3) returning a single snapshot: active pane, focused file + selection, git summary, layout — the natural first call an agent makes to orient. Acceptance: `clide status` returns a structured snapshot with exit 0. Depends on the pane/editor registries (C1/C2) for its pane and file fields.', 'Gap 6. Add a `status` command to the dispatcher (currently unknown -> exit 3) returning a single snapshot: active pane, focused file + selection, git summary, layout — the natural first call an agent makes to orient. Acceptance: `clide status` returns a structured snapshot with exit 0. Depends on the pane/editor registries (C1/C2) for its pane and file fields.

Scope addition (2026-06-03, from T-220): clide status must surface the focused file + selection from BOTH the editor (EditorRegistry.active, already populated) AND the read-only markdown/decisions reader''s current file (D-81 ReaderNav), since viewer files rightly do not live in EditorRegistry. So ''focused file'' = whichever of {active editor buffer, active reader doc} the user is currently looking at. Pane field comes from the T-219 view-pane snapshot; git summary from git.status; layout from the arrangement.', NULL, '2026-06-03 10:59:31', '2026-06-03 10:59:31', '2026-06-03 10:59:31', NULL, '589b102131052de0cf8eeaabfeef3cb6', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM758PXMJH16PA3JHFW', 'status', 'backlog', 'in_progress', NULL, '2026-06-03 11:17:49', '2026-06-03 11:17:49', '2026-06-03 11:17:49', NULL, 'e62ce5f754be4992321967879bcf8152', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM6GJRWZVHZF24TPPS4', 'status', 'ready', 'in_progress', NULL, '2026-06-03 11:38:13', '2026-06-03 11:38:13', '2026-06-03 11:38:13', NULL, '60597124c6a7f8deea5263098811234e', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM6GJRWZVHZF24TPPS4', 'description', 'Gap found while dogfooding (2026-06-03): the Claude pane shows the permission mode in its status line (permissionModeLabel, claude_status.dart:44) but has NO quick way to CHANGE it, unlike the CLI where Shift+Tab cycles work modes (plan / read / edit / yolo == plan, default, acceptEdits, bypassPermissions). Today the only interactive setter is the team meta-sidebar per-agent control (claude_meta_sidebar.dart:342); the primary pane has none. There is a command claude.agent.set-permission-mode <sessionId> <mode> (extension.dart:148) but it needs an explicit id + explicit mode, and there is no ''cycle'' verb. setPermissionMode() over the stream-json control channel already works (stream_json_session.dart:671, D-78). Scope: (1) add a mode-cycle action that targets the focused/primary session and advances the safe trio default -> acceptEdits -> plan -> default (bypassPermissions only via a confirmed/explicit path, per the T-181 footgun guard); (2) bind it to Shift+Tab INTERCEPTED at the focused Claude composer -- note shift+tab is globally focus.previous (default.yaml:31), so this needs consumer-level interception like the Vim editor (D-82), falling back to focus traversal elsewhere; (3) make the status-line mode label a clickable badge that cycles on click (the ''cockpit badge'' the stream_json_session comment already promises at line 668-669). Relates to T-181, D-77/D-78, D-82.', 'Gap found while dogfooding (2026-06-03): the Claude pane shows the permission mode in its status line (permissionModeLabel, claude_status.dart:44) but has NO quick way to CHANGE it, unlike the CLI where Shift+Tab cycles work modes (plan / read / edit / yolo == plan, default, acceptEdits, bypassPermissions). Today the only interactive setter is the team meta-sidebar per-agent control (claude_meta_sidebar.dart:342); the primary pane has none. There is a command claude.agent.set-permission-mode <sessionId> <mode> (extension.dart:148) but it needs an explicit id + explicit mode, and there is no ''cycle'' verb. setPermissionMode() over the stream-json control channel already works (stream_json_session.dart:671, D-78). Scope: (1) add a mode-cycle action that targets the focused/primary session and advances the safe trio default -> acceptEdits -> plan -> default (bypassPermissions only via a confirmed/explicit path, per the T-181 footgun guard); (2) bind it to Shift+Tab INTERCEPTED at the focused Claude composer -- note shift+tab is globally focus.previous (default.yaml:31), so this needs consumer-level interception like the Vim editor (D-82), falling back to focus traversal elsewhere; (3) make the status-line mode label a clickable badge that cycles on click (the ''cockpit badge'' the stream_json_session comment already promises at line 668-669). Relates to T-181, D-77/D-78, D-82.

Refinement (2026-06-03): Shift+Tab is REJECTED as the trigger — Tab/Shift+Tab are real a11y focus-traversal intents (focus.next/focus.previous) since T-204, so hijacking Shift+Tab would break keyboard navigation. Instead: (a) Ctrl/Cmd+M cycles, intercepted at the focused Claude composer (so it targets that pane''s session, no global ''find focused session'' needed); (b) the status-line mode label becomes a FOCUSABLE button — cycles on click and on Enter/Space when focused (a11y-native, Tab reaches it); (c) a ''Claude: Cycle permission mode'' palette command. Safe trio default->acceptEdits->plan->default; bypassPermissions only via explicit confirmed path.', NULL, '2026-06-03 11:38:13', '2026-06-03 11:38:13', '2026-06-03 11:38:13', NULL, '770abc73c9c46301ac5f88da05e58742', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM67ET3VQP90WRXVSMG', 'status', 'done', 'in_progress', NULL, '2026-06-03 11:38:13', '2026-06-03 11:38:13', '2026-06-03 11:38:13', NULL, 'ace0fa6e21b83ac23c1046c0a20572a9', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM67ET3VQP90WRXVSMG', 'status', 'in_progress', 'done', NULL, '2026-06-03 11:41:17', '2026-06-03 11:41:17', '2026-06-03 11:41:17', NULL, 'a954ee95cfbb232e73107dd38a39f533', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM67ET3VQP90WRXVSMG', 'description', 'Per-agent permission-mode control in the cockpit roster (extends T-171). Each roster row shows a mode badge (D default / A acceptEdits / P plan). Click cycles the SAFE trio default -> acceptEdits -> plan and sends set_permission_mode to that agent session (a confirmed stream-json control subtype). bypassPermissions is a footgun, so it is reachable only on SHIFT-click (behind a confirm), and the tooltip documents both behaviours. Acceptance: clicking the badge cycles the safe modes and the session receives set_permission_mode; shift-click can reach bypass behind a confirm; the badge reflects the live mode (T-157 status); tooltip explains click vs shift-click; widget + transport tests. Wireframe: docs/design/wireframes/claude-prompts/05-team-cockpit-sidebar.png. Blocked by T-169 (orchestrator).', 'Per-agent permission-mode control in the cockpit roster (extends T-171). Each roster row shows a mode badge (D default / A acceptEdits / P plan). Click cycles the SAFE trio default -> acceptEdits -> plan and sends set_permission_mode to that agent session (a confirmed stream-json control subtype). bypassPermissions is a footgun, so it is reachable only on SHIFT-click (behind a confirm), and the tooltip documents both behaviours. Acceptance: clicking the badge cycles the safe modes and the session receives set_permission_mode; shift-click can reach bypass behind a confirm; the badge reflects the live mode (T-157 status); tooltip explains click vs shift-click; widget + transport tests. Wireframe: docs/design/wireframes/claude-prompts/05-team-cockpit-sidebar.png. Blocked by T-169 (orchestrator).

Verified done (2026-06-03): the cockpit per-agent permission-mode cycle badge is implemented and wired in claude_meta_sidebar.dart — _PermissionModeBadge (safe cycle default->acceptEdits->plan, Shift-click bypass behind a confirm, live mode from SessionStatus). No further work; closing. The primary-pane equivalent is T-226.', NULL, '2026-06-03 11:41:17', '2026-06-03 11:41:17', '2026-06-03 11:41:17', NULL, 'eb80295065cb5e3fcb8bfcbc346e6774', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM6GJRWZVHZF24TPPS4', 'status', 'in_progress', 'done', NULL, '2026-06-03 11:45:56', '2026-06-03 11:45:56', '2026-06-03 11:45:56', NULL, 'fb9d92168548d7f2530ad4b90410e194', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM758PXMJH16PA3JHFW', 'status', 'in_progress', 'done', NULL, '2026-06-03 11:50:02', '2026-06-03 11:50:02', '2026-06-03 11:50:02', NULL, '45affa5ad9b05a3d510b3b5433a7bcf5', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7AMEYEBTF8YGJ4BVG', 'status', 'backlog', 'done', NULL, '2026-06-03 11:50:08', '2026-06-03 11:50:08', '2026-06-03 11:50:08', NULL, '6a100bfce5f8800ac6c963ccc89e21d0', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM6GJRWZVHZF24TPPS4', 'status', 'done', 'done', NULL, '2026-06-03 11:50:23', '2026-06-03 11:50:23', '2026-06-03 11:50:23', NULL, '08a641c9a728aae240e84d837412dafb', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM427BVZYN6MD7ZZX74', 'status', 'backlog', 'in_progress', NULL, '2026-06-03 13:21:05', '2026-06-03 13:21:05', '2026-06-03 13:21:05', NULL, '98e2b543462f5539cde6c4b324e56a2c', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5GH6VP8TZA95NMYK0', 'status', 'backlog', 'ready', NULL, '2026-06-03 13:23:43', '2026-06-03 13:23:43', '2026-06-03 13:23:43', NULL, '9553d7677bf355d235e0cf7258ec39dd', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5JR6QZDMKE167C4MR', 'status', 'backlog', 'ready', NULL, '2026-06-03 13:24:18', '2026-06-03 13:24:18', '2026-06-03 13:24:18', NULL, '8994ae3199b15e8ee6a87be2dafbf3e7', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM427BVZYN6MD7ZZX74', 'status', 'in_progress', 'done', NULL, '2026-06-03 13:30:05', '2026-06-03 13:30:05', '2026-06-03 13:30:05', NULL, 'af6cdaa34ddfc160531feac4a04607b5', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM78Q3VYWSE830CTVB4', 'description', 'VS Code-style: the GUI offers to install the `clide` shell command on PATH, for users who run the .app without `make install`. A command + command-palette entry that copies/symlinks the bundled C client to a PATH dir and reports success/failure. Acceptance: invoking it makes `clide` resolve on PATH from a fresh shell.', 'VS Code-style: the GUI offers to install the `clide` shell command on PATH, for users who run the .app without `make install`. A command + command-palette entry that copies/symlinks the bundled C client to a PATH dir and reports success/failure. Acceptance: invoking it makes `clide` resolve on PATH from a fresh shell.

Refinement (2026-06-03, from live dogfooding): scope should include PROACTIVE detection on launch, not just a palette command. When the clide IDE starts in a repo, check whether ''clide'' resolves on PATH AND points to the C client (not a stale symlink to the GUI bundle runner) -- we hit exactly this: ~/.local/bin/clide was a May-6 symlink to ~/.local/lib/clide/clide (the Flutter GUI), so a bare ''clide pane list'' launched a second app instead of querying. If missing or stale, prompt/offer to install (copy the bundled C client to a PATH dir, VS Code ''Install code command'' style) and report success. This is what lets a fresh agent actually reach the CLI (D-83 names the hosted session primary, but an external agent benefits too). Detecting ''stale GUI symlink'' specifically: the target should be an ELF/Mach-O executable, not a symlink into the bundle. Alternative path the user raised: instead of/alongside this, make the /ide MCP surface reachable (T-225) -- but CLI is primary per D-68.', NULL, '2026-06-03 13:33:43', '2026-06-03 13:33:43', '2026-06-03 13:33:43', NULL, 'e144d47ac16f8badb7f35b086d0686f4', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5BJCK5YG3R0NEEF70', 'status', 'backlog', 'in_progress', NULL, '2026-06-03 13:35:22', '2026-06-03 13:35:22', '2026-06-03 13:35:22', NULL, '41afdaa7ca24597e843fc8ec43f02e61', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5BJCK5YG3R0NEEF70', 'description', 'Major dogfood finding (2026-06-03), verified live: parameterized subsystem commands are NOT reachable from the clide CLI. The C client sends raw argv; parseArgv (lib/src/cli/argv_to_request.dart) turns ''clide editor open X'' into args={positional:[X]} (also flags:{}, passthrough:[]). But the typed handlers read NAMED top-level keys: editor.open reads args[''path''] (editor_commands.dart:64), files.read reads args[''path''], pane.close/editor.activate read args[''id''], etc. Nothing maps positional/flags -> those names, so every arg-taking verb returns ''X is required'' from the CLI. Confirmed: ''clide editor open pubspec.yaml'' and ''--path=pubspec.yaml'' both -> ''path is required''; ''clide files read pubspec.yaml'' -> ''files.read requires a path''. grep shows ONLY the new ui_command.dart reads args[''positional'']. Net: an external agent can OBSERVE (no-arg reads: status, git status, files root, pane list, editor active) but cannot DRIVE anything parameterized -- undercutting CLI-first (D-1) and the D-6 parity premise behind the whole T-208 initiative. Needs a decision on the mapping contract: most ergonomic is a per-command POSITIONAL/flag schema declared where the handler registers (extends the co-registered schema of D-74) so ''clide editor open <path>'' binds positional[0]->path; alternative is lifting --flags into top-level named args. Then either remap in argv_dispatch/parseArgv before dispatch, or have handlers read a normalized accessor. High priority: this is the gating bug for ''Give Claude hands''.', 'Major dogfood finding (2026-06-03), verified live: parameterized subsystem commands are NOT reachable from the clide CLI. The C client sends raw argv; parseArgv (lib/src/cli/argv_to_request.dart) turns ''clide editor open X'' into args={positional:[X]} (also flags:{}, passthrough:[]). But the typed handlers read NAMED top-level keys: editor.open reads args[''path''] (editor_commands.dart:64), files.read reads args[''path''], pane.close/editor.activate read args[''id''], etc. Nothing maps positional/flags -> those names, so every arg-taking verb returns ''X is required'' from the CLI. Confirmed: ''clide editor open pubspec.yaml'' and ''--path=pubspec.yaml'' both -> ''path is required''; ''clide files read pubspec.yaml'' -> ''files.read requires a path''. grep shows ONLY the new ui_command.dart reads args[''positional'']. Net: an external agent can OBSERVE (no-arg reads: status, git status, files root, pane list, editor active) but cannot DRIVE anything parameterized -- undercutting CLI-first (D-1) and the D-6 parity premise behind the whole T-208 initiative. Needs a decision on the mapping contract: most ergonomic is a per-command POSITIONAL/flag schema declared where the handler registers (extends the co-registered schema of D-74) so ''clide editor open <path>'' binds positional[0]->path; alternative is lifting --flags into top-level named args. Then either remap in argv_dispatch/parseArgv before dispatch, or have handlers read a normalized accessor. High priority: this is the gating bug for ''Give Claude hands''.

Resolved (2026-06-03): NO new mechanism or decision needed -- the contract already existed. D-74''s CommandSchema.normalize (lib/src/ipc/command_schema.dart) already folds the argv shape {positional,flags} into named args using a declared positional ordering, and the dispatcher already runs normalize+validate. The arg-taking commands simply never registered a schema (adoption is opt-in per D-74). Fix = adopt it: added positional schemas (non-required, so missing-arg errors stay as handlers produce them; only effect is positional->named mapping + numeric coercion of line/cols/rows) to editor.open/activate/read/save/close, files.read/ls, pane.close/focus/resize/write. Handlers unchanged. Tests: CLI-shape ({positional:[...]}) dispatch now binds (editor/pane/files command tests). DEFERRED (still named-arg only; in-process UI works, CLI-arg niche): editor.insert/replace-selection/set-selection/set-content (content/selection encoding + active-buffer fallback make positional ambiguous), pane.spawn (argv is a list, not scalar positional), git.* arg verbs (agents use plain git; D-83 external-agent scope). NOTE: takes effect on app RESTART, not hot reload -- the dispatcher is built once at boot.', NULL, '2026-06-03 13:41:38', '2026-06-03 13:41:38', '2026-06-03 13:41:38', NULL, '00f04276595d3ca0eacea70ace311514', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5BJCK5YG3R0NEEF70', 'status', 'in_progress', 'done', NULL, '2026-06-03 13:41:42', '2026-06-03 13:41:42', '2026-06-03 13:41:42', NULL, '7af8d830470a89fef73b0ca8341cceff', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM492DTRZJK9CGQPGDC', 'status', 'backlog', 'ready', NULL, '2026-06-03 14:25:47', '2026-06-03 14:25:47', '2026-06-03 14:25:47', NULL, 'e3619215908a44a1d821ae9c0935649b', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5JR6QZDMKE167C4MR', 'status', 'ready', 'in_progress', NULL, '2026-06-03 14:27:26', '2026-06-03 14:27:26', '2026-06-03 14:27:26', NULL, '4c3010b9a2f5f653efe8ea06ad644457', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5GH6VP8TZA95NMYK0', 'status', 'ready', 'in_progress', NULL, '2026-06-03 14:27:26', '2026-06-03 14:27:26', '2026-06-03 14:27:26', NULL, '5c31029277155620830aa75e3fb14224', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM492DTRZJK9CGQPGDC', 'status', 'ready', 'in_progress', NULL, '2026-06-03 14:27:26', '2026-06-03 14:27:26', '2026-06-03 14:27:26', NULL, '9692b5e80c02c9a55ed66de8875f8714', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5JR6QZDMKE167C4MR', 'status', 'in_progress', 'done', NULL, '2026-06-03 14:56:07', '2026-06-03 14:56:07', '2026-06-03 14:56:07', NULL, '5df5897d91f2310e585ec8df8507b02c', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM492DTRZJK9CGQPGDC', 'status', 'in_progress', 'done', NULL, '2026-06-03 15:04:07', '2026-06-03 15:04:07', '2026-06-03 15:04:07', NULL, '28d42a5626ada0071e158767c9223017', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5GH6VP8TZA95NMYK0', 'description', 'The Claude pane renders every transcript item as its own row, so a heavy agent turn becomes a wall of tool-call/result rows (Bash <cmd> / Bash · result {…} / ''completed with no output'') that buries the messages that matter (user + Claude prose). Wireframe: docs/design/wireframes/claude/meta-activity-card.png.

Fold runs of consecutive ''meta'' items into one live, collapsible activity card:
- The card shows the MOST RECENT meta line as a live ticker and updates in place as new ones stream in — a running ''what''s happening now''. A step count (''14 steps'') sits on the right.
- Collapsed by default; click the chevron to expand the full list of folded steps, click to re-collapse.
- ''Sticky'' items never fold — they render first-class. A sticky item SEALS the current card and a new cluster begins after it. A cluster = one unbroken run of foldable items between two sticky items.

Taxonomy over the sealed ConversationItem set (transcript_reader.dart): UserMessage, AssistantTextMessage, AssistantThinkingMessage, AssistantToolUse, ToolResultMessage.
- Always sticky: UserMessage, AssistantTextMessage. Permission/AskUserQuestion prompts already live in the interaction zone (D-78) and are inherently sticky / cluster-breaking — no change, but note they break the run too.
- Foldable: AssistantToolUse + its paired ToolResultMessage (pairing already exists via toolUseById, T-168).

Refinement decisions (2026-06-03, user):
1. WHAT FOLDS is a 3-level setting (conservative → aggressive); DEFAULT = level 1. Build the foldable predicate so all three are switchable:
   - L1 (default): fold tool calls + results only; diffs (Edit/Write results) AND AssistantThinkingMessage stay first-class/sticky.
   - L2: also fold thinking; diffs stay sticky.
   - L3: fold everything except UserMessage + AssistantTextMessage (incl. diffs + thinking).
2. ERRORS: a failed/error ToolResultMessage SURFACES — treated as sticky, stays visible and breaks the cluster (see wireframe state B). Start here; the user noted some non-fatal errors are themselves clutter, so expect to tune which errors surface vs. fold.
3. DEFAULT/RUN STATE: always collapsed, showing the last line + step count, with the ticker updating live. NO setting. (Rejected auto-expanding the in-flight cluster: it scrolls the last useful sticky message out of view during long runs and only collapses when done — worst timing. Collapsed-with-live-ticker keeps the last sticky message anchored while preserving the motion/dynamism.)

Implementation home: a ''collapse adjacent foldable items'' grouping pass over ConversationController.items, consumed by ConversationView; the card is a new conversation_card variant. Keep it accessible (keyboard expand/collapse + semantics: announce step count and collapsed/expanded state). 

Acceptance:
1. Consecutive foldable items collapse into one card; the collapsed card shows the latest line + a live-updating step count.
2. A sticky message (user / Claude prose / surfaced error / interaction-zone prompt) seals the card and starts a new cluster after it.
3. Expanding shows every folded step (tool call + result pairs) in order; collapsing returns to the one-line view.
4. The foldable level is a setting (default L1: diffs + thinking stay first-class); switching levels re-groups the transcript.
5. Failed tool results surface as their own (sticky) row and break the cluster.
6. Keyboard + screen-reader accessible (expand/collapse, step count announced).', 'The Claude pane renders every transcript item as its own row, so a heavy agent turn becomes a wall of tool-call/result rows (Bash <cmd> / Bash · result {…} / ''completed with no output'') that buries the messages that matter (user + Claude prose). Wireframe: docs/design/wireframes/claude/meta-activity-card.png.

Fold runs of consecutive ''meta'' items into one live, collapsible activity card:
- The card shows the MOST RECENT meta line as a live ticker and updates in place as new ones stream in — a running ''what''s happening now''. A step count (''14 steps'') sits on the right.
- Collapsed by default; click the chevron to expand the full list of folded steps, click to re-collapse.
- ''Sticky'' items never fold — they render first-class. A sticky item SEALS the current card and a new cluster begins after it. A cluster = one unbroken run of foldable items between two sticky items.

Taxonomy over the sealed ConversationItem set (transcript_reader.dart): UserMessage, AssistantTextMessage, AssistantThinkingMessage, AssistantToolUse, ToolResultMessage.
- Always sticky: UserMessage, AssistantTextMessage. Permission/AskUserQuestion prompts already live in the interaction zone (D-78) and are inherently sticky / cluster-breaking — no change, but note they break the run too.
- Foldable: AssistantToolUse + its paired ToolResultMessage (pairing already exists via toolUseById, T-168).

Refinement decisions (2026-06-03, user):
1. WHAT FOLDS is a 3-level setting (conservative → aggressive); DEFAULT = level 1. Build the foldable predicate so all three are switchable:
   - L1 (default): fold tool calls + results only; diffs (Edit/Write results) AND AssistantThinkingMessage stay first-class/sticky.
   - L2: also fold thinking; diffs stay sticky.
   - L3: fold everything except UserMessage + AssistantTextMessage (incl. diffs + thinking).
2. ERRORS: a failed/error ToolResultMessage SURFACES — treated as sticky, stays visible and breaks the cluster (see wireframe state B). Start here; the user noted some non-fatal errors are themselves clutter, so expect to tune which errors surface vs. fold.
3. DEFAULT/RUN STATE: always collapsed, showing the last line + step count, with the ticker updating live. NO setting. (Rejected auto-expanding the in-flight cluster: it scrolls the last useful sticky message out of view during long runs and only collapses when done — worst timing. Collapsed-with-live-ticker keeps the last sticky message anchored while preserving the motion/dynamism.)

Implementation home: a ''collapse adjacent foldable items'' grouping pass over ConversationController.items, consumed by ConversationView; the card is a new conversation_card variant. Keep it accessible (keyboard expand/collapse + semantics: announce step count and collapsed/expanded state). 

Acceptance:
1. Consecutive foldable items collapse into one card; the collapsed card shows the latest line + a live-updating step count.
2. A sticky message (user / Claude prose / surfaced error / interaction-zone prompt) seals the card and starts a new cluster after it.
3. Expanding shows every folded step (tool call + result pairs) in order; collapsing returns to the one-line view.
4. The foldable level is a setting (default L1: diffs + thinking stay first-class); switching levels re-groups the transcript.
5. Failed tool results surface as their own (sticky) row and break the cluster.
6. Keyboard + screen-reader accessible (expand/collapse, step count announced).

Implemented (2026-06-03): pure grouping in activity_cluster.dart (groupConversation + FoldLevel none/tools/thinking/everything + RenderGroup StickyItem/FoldedCluster), fully unit-tested. Activity card + grouping wired into conversation_view.dart (collapsed live ticker of the latest step + step count; click/Enter expands to the folded steps in order; Semantics announces count + expanded/collapsed). Default level = L1 (tools): tool calls+results fold; user/Claude prose, FAILED results (sticky, surfaced), diffs (Edit/Write), and thinking stay first-class. Added FoldLevel.none (no folding) used by the existing item-level renderer tests. DEFERRED (acceptance 4''s persistence): the fold level is a switchable ConversationView parameter (proven by tests; none/L1/L2/L3 re-group) but is NOT yet wired to a persisted user setting + a UI control — the live pane uses the L1 default. Follow-up: read it from settings (ctx.settings) + a control to change it. Did NOT match the wireframe pixel-for-pixel; functional shape per the refinement decisions.', NULL, '2026-06-03 15:17:10', '2026-06-03 15:17:10', '2026-06-03 15:17:10', NULL, 'e320516c4fee5c1d23de4772712a6fe6', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5GH6VP8TZA95NMYK0', 'status', 'in_progress', 'done', NULL, '2026-06-03 15:17:33', '2026-06-03 15:17:33', '2026-06-03 15:17:33', NULL, '45157bbf9208bebe5bb78b5650fc259c', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM46ANXPW02XGD3D3NG', 'status', 'backlog', 'in_progress', NULL, '2026-06-03 15:43:55', '2026-06-03 15:43:55', '2026-06-03 15:43:55', NULL, 'f4802b804089ec788e4c87ee78d34aee', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM46ANXPW02XGD3D3NG', 'status', 'in_progress', 'done', NULL, '2026-06-03 21:11:32', '2026-06-03 21:11:32', '2026-06-03 21:11:32', NULL, '9a06d177b18f27eaf0f1b6dfd935db42', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM46ANXPW02XGD3D3NG', 'status', 'done', 'done', NULL, '2026-06-03 21:29:47', '2026-06-03 21:29:47', '2026-06-03 21:29:47', NULL, '5c6c0567db81e42c9272a491d615aee6', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM46ANXPW02XGD3D3NG', 'description', 'User feedback on the T-234 status-bar theme popover (screenshot 2026-06-03): (1) the menu order looks random — the -hc variants are interleaved. (2) Hide all the high-contrast theme entries and replace them with a single ''[ ] High contrast'' checkbox at the top; toggling it applies the -hc sibling of the chosen base theme. (3) Widen the popover so long names (''Catppuccin Mocha'') don''t wrap; rows ellipsize. (4) The status-bar items (''application ok'' + theme switcher) float in the middle (boxed into the workspace column between the per-column bottom rails) instead of hugging the window''s right edge — align them right. (5) Replace the swatch dot on the trigger with a Phosphor icon (palette, 0xe6c8, already in the registry — paint-roller has no registered codepoint). Apply the -hc-as-checkbox + sort to the modal picker_view too for consistency. Helpers: base = name without -hc/-cb; show base themes only; resolve(base, hc) -> base+''-hc'' if it exists.', 'User feedback on the T-234 status-bar theme popover (screenshot 2026-06-03): (1) the menu order looks random — the -hc variants are interleaved. (2) Hide all the high-contrast theme entries and replace them with a single ''[ ] High contrast'' checkbox at the top; toggling it applies the -hc sibling of the chosen base theme. (3) Widen the popover so long names (''Catppuccin Mocha'') don''t wrap; rows ellipsize. (4) The status-bar items (''application ok'' + theme switcher) float in the middle (boxed into the workspace column between the per-column bottom rails) instead of hugging the window''s right edge — align them right. (5) Replace the swatch dot on the trigger with a Phosphor icon (palette, 0xe6c8, already in the registry — paint-roller has no registered codepoint). Apply the -hc-as-checkbox + sort to the modal picker_view too for consistency. Helpers: base = name without -hc/-cb; show base themes only; resolve(base, hc) -> base+''-hc'' if it exists.

Done (2026-06-03): popover collapses -hc into a ''High contrast'' toggle, lists base themes sorted by display name, widened to 280 with ellipsis, palette icon on the trigger, lowercased bar label; status bar split so the global right group (tool status + theme switcher) hugs the window''s right edge past the context rail (643417e), keeping the 3-rail structure. Pure theme_families helpers unit-tested + popover widget tests. DEFERRED: applying the same -hc-toggle + sort to the modal picker_view (ctrl+k) for consistency — minor, follow-up.', NULL, '2026-06-03 21:29:47', '2026-06-03 21:29:47', '2026-06-03 21:29:47', NULL, 'e92a06a4035a0eb5984ea80b84a9b106', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5BWXW61EVYGMZD47G', 'status', 'in_progress', 'done', NULL, '2026-06-04 12:00:09', '2026-06-04 12:00:09', '2026-06-04 12:00:09', NULL, '0b5b1c74b5a43d83d7a7109695f6b267', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4W624VD4JW1GHDHAR', 'status', 'in_progress', 'done', NULL, '2026-06-04 12:00:09', '2026-06-04 12:00:09', '2026-06-04 12:00:09', NULL, '875e34a0516f4797988ecb4152e797ff', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5ABRPK2SPW8VY7RP4', 'status', 'in_progress', 'done', NULL, '2026-06-04 12:00:09', '2026-06-04 12:00:09', '2026-06-04 12:00:09', NULL, '8813d96e9fdde24a1107a2788f7b0995', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5V7GHH42RHV04DPTR', 'status', 'in_progress', 'done', NULL, '2026-06-04 12:00:09', '2026-06-04 12:00:09', '2026-06-04 12:00:09', NULL, '9122fa1a1ad891b12102022c38203b25', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM56FKPV4WSPWA0KMB4', 'status', 'in_progress', 'done', NULL, '2026-06-04 12:00:09', '2026-06-04 12:00:09', '2026-06-04 12:00:09', NULL, '989cb032dc8c8f5a2fd85de7e0927b1e', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5QJC039TMDF5JGMXC', 'description', 'Muscle-memory gap from the Claude Code CLI: in clide''s interaction-zone prompts (D-78), the user reaches for number keys 1/2/3 to pick a button but has to click. Map number keys (1..N) to the visible buttons/options, and PREFIX each button label with its number for discoverability (CLI shows ''1. Allow / 2. ... / 3. No'').\n\nSurface: ToolPromptCard in lib/builtin/claude/src/prompt_card.dart. Two modes:\n- PERMISSION (_permission, ~line 119): buttons Allow (primary) / ''Allow & don''t ask again'' (only when permissionSuggestions present) / Deny. Map 1=Allow, 2=''Allow & don''t ask again'' (when shown) else Deny, 3=Deny when the middle one is shown. Match the CLI''s ordering/numbering.\n- ASKUSERQUESTION (_question / _optButton, ~line 280/294): each option per question gets a number (1..N) that selects (single) or toggles (multiSelect) it; keep Enter for Submit/Next and Esc/back as-is. Prefix option labels with the number alongside the existing radio/checkbox glyph (the ''○/●'' in _optButton).\n\nKEY CAVEAT (do this right): the prompt card hosts a free-text note field (_NoteField) and AskUserQuestion ''Other'' free-text. Number keys MUST NOT be captured while focus is in a text field (otherwise typing ''1'' triggers a button). Gate the shortcut on focus not being in an editable, i.e. intercept at the prompt''s Focus/FocusScope and bail when a text field has focus — same consumer-interception discipline as D-82 (Vim) / the editor. Keep the ClideButtons (clicks + AT) intact; the number key is an additional accelerator. Accessibility: include the number in the button''s semantics label.\n\nAcceptance: with a permission prompt or AskUserQuestion open and focus not in a text field, pressing 1/2/3 (and up to N for question options) activates the matching button/option; labels are number-prefixed; typing in a note/Other field is unaffected; mouse + screen-reader paths still work.', 'Muscle-memory gap from the Claude Code CLI: in clide''s interaction-zone prompts (D-78), the user reaches for number keys 1/2/3 to pick a button but has to click. Map number keys (1..N) to the visible buttons/options, and PREFIX each button label with its number for discoverability (CLI shows ''1. Allow / 2. ... / 3. No'').\n\nSurface: ToolPromptCard in lib/builtin/claude/src/prompt_card.dart. Two modes:\n- PERMISSION (_permission, ~line 119): buttons Allow (primary) / ''Allow & don''t ask again'' (only when permissionSuggestions present) / Deny. Map 1=Allow, 2=''Allow & don''t ask again'' (when shown) else Deny, 3=Deny when the middle one is shown. Match the CLI''s ordering/numbering.\n- ASKUSERQUESTION (_question / _optButton, ~line 280/294): each option per question gets a number (1..N) that selects (single) or toggles (multiSelect) it; keep Enter for Submit/Next and Esc/back as-is. Prefix option labels with the number alongside the existing radio/checkbox glyph (the ''○/●'' in _optButton).\n\nKEY CAVEAT (do this right): the prompt card hosts a free-text note field (_NoteField) and AskUserQuestion ''Other'' free-text. Number keys MUST NOT be captured while focus is in a text field (otherwise typing ''1'' triggers a button). Gate the shortcut on focus not being in an editable, i.e. intercept at the prompt''s Focus/FocusScope and bail when a text field has focus — same consumer-interception discipline as D-82 (Vim) / the editor. Keep the ClideButtons (clicks + AT) intact; the number key is an additional accelerator. Accessibility: include the number in the button''s semantics label.\n\nAcceptance: with a permission prompt or AskUserQuestion open and focus not in a text field, pressing 1/2/3 (and up to N for question options) activates the matching button/option; labels are number-prefixed; typing in a note/Other field is unaffected; mouse + screen-reader paths still work.

Refinement (2026-06-05, user): match the Claude Code CLI''s actual behavior for the text-field interaction. The number key triggers the button/option shortcut when it would be the FIRST character typed -- i.e. focus is NOT in a text field, OR focus IS in the note/Other field but that field is currently EMPTY. Once the field has any content, digits type normally (no shortcut). This supersedes the earlier ''never capture digits while a text field has focus'' gate: it''s better because focus often defaults into the (empty) note field, so the shortcut still fires there (muscle-memory case) while a digit mid-note still types. Implementation: intercept the digit at the prompt focus scope; consume+activate only when the focused editable (if any) is empty, else let it through to type. The CLI exhibits this exact ''footgun'' (digit-as-first-char in an empty field acts as the choice) and we intentionally mirror it.', NULL, '2026-06-05 09:40:57', '2026-06-05 09:40:57', '2026-06-05 09:40:57', NULL, '14ab9c3fceabd48bab7c461051ca8ab5', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5F4D2Q363QF7V40K8', 'status', 'backlog', 'in_progress', NULL, '2026-06-05 09:45:51', '2026-06-05 09:45:51', '2026-06-05 09:45:51', NULL, '10b4a203cccc9b0fed0804704eb857ac', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5F4D2Q363QF7V40K8', 'description', 'Unresolved after T-237 (commits 643417e then reverted by dc84f4c). GOAL: in the single bottom status bar, left items (git branch ''main'', skills count) sit flush-LEFT and the global right group (ipc ''application ok'' + theme switcher) sits flush-RIGHT of the CENTER (workspace) block — NOT the window edge, and NOT two separate left-aligned columns. Keep the 3-rail bottom bar (sidebar rail | workspace status | context tab-rail). CURRENT STATE (dc84f4c): StatusbarHost is a single Container(Row[ ...left, Spacer(), ...right ]) with NO alignment, sitting in Expanded(StatusbarHost()) inside the bottom-bar Row (app.dart ~261). In theory the Spacer should right-align the right group within the workspace Expanded; in practice (verified live by the user, even after a hot RESTART) the right group does NOT hug the center block''s right edge. ATTEMPTS THAT FAILED: (a) removing ''alignment: Alignment.center'' from the StatusbarHost Container; (b) splitting into two hosts and trailing the right group past the context rail (overshot to the window edge — wrong). LEAD / NEXT STEP: instrument the actual constraints rather than guess. Prime suspect: the OUTER Column at app.dart ~214 has NO crossAxisAlignment (defaults to center), so the bottom-bar Container may receive LOOSE width and size to its content, collapsing the Spacer (right group ends up adjacent to the left group, both effectively left-aligned). Try CrossAxisAlignment.stretch on that Column (or give the status Container an explicit full width), and confirm Expanded(StatusbarHost) actually receives a bounded full-workspace width. A widget/integration test asserting the right group''s x-offset == workspace-region right edge would lock it. Files: lib/app.dart (StatusbarHost + the bottom-bar Row + the outer Column).', 'Unresolved after T-237 (commits 643417e then reverted by dc84f4c). GOAL: in the single bottom status bar, left items (git branch ''main'', skills count) sit flush-LEFT and the global right group (ipc ''application ok'' + theme switcher) sits flush-RIGHT of the CENTER (workspace) block — NOT the window edge, and NOT two separate left-aligned columns. Keep the 3-rail bottom bar (sidebar rail | workspace status | context tab-rail). CURRENT STATE (dc84f4c): StatusbarHost is a single Container(Row[ ...left, Spacer(), ...right ]) with NO alignment, sitting in Expanded(StatusbarHost()) inside the bottom-bar Row (app.dart ~261). In theory the Spacer should right-align the right group within the workspace Expanded; in practice (verified live by the user, even after a hot RESTART) the right group does NOT hug the center block''s right edge. ATTEMPTS THAT FAILED: (a) removing ''alignment: Alignment.center'' from the StatusbarHost Container; (b) splitting into two hosts and trailing the right group past the context rail (overshot to the window edge — wrong). LEAD / NEXT STEP: instrument the actual constraints rather than guess. Prime suspect: the OUTER Column at app.dart ~214 has NO crossAxisAlignment (defaults to center), so the bottom-bar Container may receive LOOSE width and size to its content, collapsing the Spacer (right group ends up adjacent to the left group, both effectively left-aligned). Try CrossAxisAlignment.stretch on that Column (or give the status Container an explicit full width), and confirm Expanded(StatusbarHost) actually receives a bounded full-workspace width. A widget/integration test asserting the right group''s x-offset == workspace-region right edge would lock it. Files: lib/app.dart (StatusbarHost + the bottom-bar Row + the outer Column).

FIXED (2026-06-05): root cause confirmed by probe at 3440px width — the bottom bar used Row[ ...left (incl. a Flexible flex:1 loose item, the Claude status marquee), Spacer(), ...right ]. The Spacer (Expanded, flex:1) and the left flex:1 item SPLIT the free space 50/50, so the Spacer only pushed the right group by HALF the free space. That drift is proportional to width: tiny at 1200px (why probes/normal screens looked fine), ~1500px at 3440px (the right group floated to mid-bar) — hence ''only on ultrawide''. Probe: OLD R.right=1934 at a 3440 edge; NEW R.right=3440. FIX (app.dart StatusbarHost): explicit two-column layout — left group wrapped in Expanded(Row[...]) so it absorbs ALL free space (flex item flexes within it), right group trails at intrinsic width → hugs the workspace block''s right edge by construction, width-independent. Regression test test/app_statusbar_test.dart asserts the right group at width-8 for BOTH 600px and 3440px. Full fast suite green.', NULL, '2026-06-05 10:02:12', '2026-06-05 10:02:12', '2026-06-05 10:02:12', NULL, '1c7d83b62aa242a2cc67715225a7cf1b', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5F4D2Q363QF7V40K8', 'status', 'in_progress', 'done', NULL, '2026-06-05 10:02:12', '2026-06-05 10:02:12', '2026-06-05 10:02:12', NULL, 'bdd320e30b5741955925e68a87a6c705', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM66TK8TQ1X5T9GK6V0', 'status', 'backlog', 'ready', NULL, '2026-06-05 11:04:12', '2026-06-05 11:04:12', '2026-06-05 11:04:12', NULL, 'bc94db15c95b740f2ca3f0c0d3921542', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5YYY4FVPX9KRVHCMC', 'status', 'backlog', 'ready', NULL, '2026-06-05 11:04:25', '2026-06-05 11:04:25', '2026-06-05 11:04:25', NULL, '7012c8f3ef5f83bc114211666e6763dd', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM41S6RRTMTY9TYZA50', 'status', 'backlog', 'ready', NULL, '2026-06-05 12:15:59', '2026-06-05 12:15:59', '2026-06-05 12:15:59', NULL, '8e598b3ac94c0759219816735f773964', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM41S6RRTMTY9TYZA50', 'status', 'ready', 'in_progress', NULL, '2026-06-05 13:07:20', '2026-06-05 13:07:20', '2026-06-05 13:07:20', NULL, '97e0697ae51d47c730e6636b87693a58', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM41S6RRTMTY9TYZA50', 'description', 'T-115 follow-up: tap-driven widget test for sticky-startup toggle.

Adding a tap-driven (or even render-only) test that pumps WelcomeView with a non-empty recents list hangs the Flutter test runner until timeout.

Investigation 2026-05-22 (narrowed the cause):
- The hang is SYNCHRONOUS: `flutter test --timeout 45s` never fires; only an external `timeout` kills it. So the Dart isolate event loop is blocked, not awaiting.
- Reduced to a minimal repro: pumping two NESTED ClideTappable widgets under the shared test harness (test/helpers/widget_harness.dart) hangs. A SINGLE ClideTappable (as in _ActionRow) renders fine — that is why all existing WelcomeView tests pass (empty recents = no nested tappable). The recents path nests one: _RecentRow is a ClideTappable whose subtree contains _StickyToggle (a Semantics-wrapped ClideTappable).
- The shared harness uses `Overlay(canSizeOverlay: true)` over a zero-size `MediaQuery`, which triggers an intrinsic-sizing pass. Strongly suspect the nested ClideTappable (Focus + MouseRegion + GestureDetector + DecoratedBox stack) diverges under intrinsic dimension computation.
- Workarounds that did NOT help: setting tester.view.physicalSize; wrapping in SizedBox; wrapping in Center+SizedBox; a custom bounded MediaQuery harness (that custom harness hung even on a single tappable — likely its own confound, do not reuse it).
- The prior ClideTooltip/MouseRegion-timer hypothesis is WRONG: the recents widgets pass no tooltip to ClideTappable, so no ClideTooltip is built, and _StickyToggle uses Semantics(tooltip:) (metadata only, no widget/timer).

Next steps:
- Decide whether this is a real ClideTappable bug (nested tappables would also hang the live app welcome screen with recents) or strictly a canSizeOverlay-intrinsic-sizing test artifact. Check the running app: open welcome with >=1 recent project and confirm it does NOT hang. If the app is fine, the fix is harness-side (give WelcomeView tight constraints so no intrinsic pass), and the shared harness or a welcome-specific harness needs adjusting. If the app DOES hang, ClideTappable has a real nested-layout bug — fix it (likely in lib/widgets/src/clide_tappable.dart intrinsic/layout handling) and this becomes higher priority.
- Once unblocked, this also unblocks lib/builtin/welcome/src/welcome_view.dart coverage (74 uncovered lines, the dominant lib/builtin/ gap toward the T-89 95% target).

ProjectManager sticky-startup logic is already covered by test/kernel/src/project_test.dart (14 cases).', 'T-115 follow-up: tap-driven widget test for sticky-startup toggle.

Adding a tap-driven (or even render-only) test that pumps WelcomeView with a non-empty recents list hangs the Flutter test runner until timeout.

Investigation 2026-05-22 (narrowed the cause):
- The hang is SYNCHRONOUS: `flutter test --timeout 45s` never fires; only an external `timeout` kills it. So the Dart isolate event loop is blocked, not awaiting.
- Reduced to a minimal repro: pumping two NESTED ClideTappable widgets under the shared test harness (test/helpers/widget_harness.dart) hangs. A SINGLE ClideTappable (as in _ActionRow) renders fine — that is why all existing WelcomeView tests pass (empty recents = no nested tappable). The recents path nests one: _RecentRow is a ClideTappable whose subtree contains _StickyToggle (a Semantics-wrapped ClideTappable).
- The shared harness uses `Overlay(canSizeOverlay: true)` over a zero-size `MediaQuery`, which triggers an intrinsic-sizing pass. Strongly suspect the nested ClideTappable (Focus + MouseRegion + GestureDetector + DecoratedBox stack) diverges under intrinsic dimension computation.
- Workarounds that did NOT help: setting tester.view.physicalSize; wrapping in SizedBox; wrapping in Center+SizedBox; a custom bounded MediaQuery harness (that custom harness hung even on a single tappable — likely its own confound, do not reuse it).
- The prior ClideTooltip/MouseRegion-timer hypothesis is WRONG: the recents widgets pass no tooltip to ClideTappable, so no ClideTooltip is built, and _StickyToggle uses Semantics(tooltip:) (metadata only, no widget/timer).

Next steps:
- Decide whether this is a real ClideTappable bug (nested tappables would also hang the live app welcome screen with recents) or strictly a canSizeOverlay-intrinsic-sizing test artifact. Check the running app: open welcome with >=1 recent project and confirm it does NOT hang. If the app is fine, the fix is harness-side (give WelcomeView tight constraints so no intrinsic pass), and the shared harness or a welcome-specific harness needs adjusting. If the app DOES hang, ClideTappable has a real nested-layout bug — fix it (likely in lib/widgets/src/clide_tappable.dart intrinsic/layout handling) and this becomes higher priority.
- Once unblocked, this also unblocks lib/builtin/welcome/src/welcome_view.dart coverage (74 uncovered lines, the dominant lib/builtin/ gap toward the T-89 95% target).

ProjectManager sticky-startup logic is already covered by test/kernel/src/project_test.dart (14 cases).

ROOT CAUSE FOUND + FIXED (2026-06-05). The strand is NOT nested ClideTappable / intrinsic sizing (that prior hypothesis is disproven: seeding an EMPTY recents list — no rows, no nested tappables — also hangs, while rendering real recent rows seeded correctly passes). Real cause: SettingsStore.set does real file I/O (writeAsString); awaiting settings.set + project.loadRecents INSIDE the testWidgets body runs that I/O in fake-async, which traps the completion callback so the await never returns (a +0 strand only SIGKILL clears). FIX: seed recents via tester.runAsync(() async {...}) (real event loop), then pump in a tight bounded tree (not the shared harness, whose unbounded width is a separate WelcomeView layout hazard). test/builtin/welcome/widget_test.dart now has working recents render + sticky-toggle + open-recent tests; the skip is removed. Harness lesson recorded.', NULL, '2026-06-05 13:08:02', '2026-06-05 13:08:02', '2026-06-05 13:08:02', NULL, '8459f860f51ab035507cd3a99e869989', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM41S6RRTMTY9TYZA50', 'status', 'in_progress', 'done', NULL, '2026-06-05 13:08:05', '2026-06-05 13:08:05', '2026-06-05 13:08:05', NULL, '9102b9fb80d116f4443fe4b478003a08', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM66TK8TQ1X5T9GK6V0', 'description', 'Diff view currently contributes to workspace. Spec doesn''t place it. Likely belongs in context panel (viewer) or as an editor overlay. Depends on Q-27.', 'Diff view currently contributes to workspace. Spec doesn''t place it. Likely belongs in context panel (viewer) or as an editor overlay. Depends on Q-27.

DECIDED 2026-06-05 (D-84): diff view = editor-mode surface, inline above Claude (NOT a workspace tab, NOT a context-panel viewer), spawned from the git sidebar. Rationale: a diff is a review+intervention surface needing room for hunk stage/discard and conflict-resolution widgets — too cramped for the ~420px context panel; the middle column above Claude gives space while keeping Claude''s prompt bar fixed (D-47/D-49). This decision ticket is satisfied; the actual re-placement (generalize the editor-mode slot to host a diff, wire git-sidebar spawn, build resolution widgets) is a follow-up implementation story.', NULL, '2026-06-05 15:14:18', '2026-06-05 15:14:18', '2026-06-05 15:14:18', NULL, 'f963b14dc689b03e3e6bf53bfd5f7d73', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM66TK8TQ1X5T9GK6V0', 'status', 'ready', 'done', NULL, '2026-06-05 15:17:09', '2026-06-05 15:17:09', '2026-06-05 15:17:09', NULL, '71c38038b7804fb5afd636c27de1a53c', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5WT3BHB8JZY77G5AW', 'description', NULL, 'Implements D-84. Today the diff view is a workspace TAB (lib/builtin/diff/src/extension.dart, slot: Slots.workspace) — remove that. Instead: (1) generalize the editor-mode surface (currently hosts the single inline editor in _WorkspaceSlot, app.dart, gated by arrangement.editorOpen/editorRatio) so it can host EITHER the editor or a diff (mutually exclusive in that slot, like the viewer<->editor swap in D-49); (2) selecting a changed file in the git sidebar opens its diff in that above-Claude surface; (3) the diff keeps Claude''s prompt bar fixed (D-47) and gets a draggable divider like the editor. Acceptance: diff no longer appears as a workspace tab; clicking a file in the git panel opens its diff above Claude; closing it (Ctrl/Cmd+W) returns to Claude full-height; coexists with the editor by swap, not both at once. Hunk stage/discard + conflict-resolution widgets can be a further follow-up. Tests: arrangement state for the diff surface; git-sidebar -> diff open wiring; widget render.', NULL, '2026-06-05 15:17:09', '2026-06-05 15:17:09', '2026-06-05 15:17:09', NULL, 'fe174b3a1ef5357f0c527d6209f4c671', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5YYY4FVPX9KRVHCMC', 'description', 'Non-modal toast notifications for operation feedback (git push succeeded, extension activated, update available, errors). Slide in from bottom-right or top-right, auto-dismiss after timeout, manually dismissable. Queue multiple toasts. Severity levels map to status tokens (success/warning/error/info).', 'Non-modal toast notifications for operation feedback (git push succeeded, extension activated, update available, errors). Slide in from bottom-right or top-right, auto-dismiss after timeout, manually dismissable. Queue multiple toasts. Severity levels map to status tokens (success/warning/error/info).

REFINED 2026-06-05. Build (bottom-right, system + proof emitter):
- kernel ToastService (ChangeNotifier): show(message, {severity, duration}) -> id, dismiss(id), queue of active toasts, per-toast auto-dismiss Timer (default ~4s; errors longer/sticky), cancel on manual dismiss. ToastSeverity {success, warning, error, info}.
- ClideToast widget (custom, NO Material per D-7): severity accent from status tokens (statusSuccess/Warning/Error/info), message text, dismiss affordance (x / Esc-less, click); slide+fade in from bottom-right, auto slide-out.
- ToastOverlay: mounted in the app-root Stack (app.dart) alongside ClidePalette/QuickOpenOverlay, anchored bottom-right; stacks multiple toasts vertically; animates enter/exit.
- a11y: Semantics liveRegion for the message + labelled dismiss; keyboard-dismissable.
- Proof emitter: git push success/failure raises a toast (wire in the git command path). Broad wiring (extension activated, update available, generic errors) = follow-up tickets.
- Tests: ToastService queue + auto-dismiss (fakeAsync timers) + severity mapping; ClideToast render per severity; a11y contract; overlay mount.', NULL, '2026-06-05 15:17:36', '2026-06-05 15:17:36', '2026-06-05 15:17:36', NULL, '210739d5d63388a41de15b8e3bc6dfc7', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5YYY4FVPX9KRVHCMC', 'status', 'ready', 'in_progress', NULL, '2026-06-05 15:17:36', '2026-06-05 15:17:36', '2026-06-05 15:17:36', NULL, 'aed11ee397b37d20662eabf1741fc4db', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5KYAV8TMH3Y3FPRSR', 'status', 'backlog', 'ready', NULL, '2026-06-05 15:21:04', '2026-06-05 15:21:04', '2026-06-05 15:21:04', NULL, 'f7966535989e601c2d724e65701f8191', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4KPN4VK4EZP013NNG', 'description', NULL, 'When a Claude Code session hits context compaction, the Claude pane gives no signal that anything is happening: the conversation surface shows no in-pane indicator and the status bar shows no progress. From the user''s side the pane just appears to stall until compaction finishes and the next response streams in.

Expected: compaction is a visible, first-class state.
- In-pane: a clear "Compacting context…" affordance on the conversation surface (e.g. a transient status card / banner in the live-status line from T-168) so it''s obvious the session is busy, not wedged.
- Status bar: a progress indicator in the focus-driven Claude slot (T-150) reflecting the active compaction, consistent with the long-running-operation pattern in T-59.

Implementation notes:
- Source the state from the stream-json event stream (T-164/T-165), not transcript tailing — identify the compaction signal (system/compact_boundary or equivalent event) and thread it through the conversation controller into both the in-pane live-status line and the status-bar slot.
- Clear the indicator when compaction completes and normal streaming resumes.

Acceptance: triggering /compact (or an auto-compaction) shows an in-pane "compacting" indicator and a status-bar progress affordance for the duration, both of which clear when it finishes; covered by a unit test against a canned event fixture containing the compaction event.', NULL, '2026-06-05 15:24:35', '2026-06-05 15:24:35', '2026-06-05 15:24:35', NULL, 'd752e15e3e771292aa0084dc91181318', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5YYY4FVPX9KRVHCMC', 'status', 'in_progress', 'done', NULL, '2026-06-05 21:12:23', '2026-06-05 21:12:23', '2026-06-05 21:12:23', NULL, 'd9a116530e54d9766adb050be6db160d', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM66DNEK5FS9C0T4J5R', 'status', 'backlog', 'done', NULL, '2026-06-05 21:24:52', '2026-06-05 21:24:52', '2026-06-05 21:24:52', NULL, 'c089018f0a5131bc60a2c4b467dac861', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM66DNEK5FS9C0T4J5R', 'description', NULL, 'Implements the agent/CLI drive-half of T-50 (parity, like ui.open/T-231): clide ui toast "message" [--severity success|warning|error|info] [--duration MS]. Registered as ui.toast in lib/src/daemon/ui_command.dart; publishes {message,severity,durationMs?} on the kernel MessageBus ''toast'' channel (literal kept Flutter-free), which the ToastService consumes. Lets a hosted Claude session (or any script) surface ''done/failed'' on the user''s screen. Validates message-required, severity, integer duration; toolError when no live GUI. Tested in test/daemon/ui_command_test.dart. NOTE: a running GUI must be rebuilt to pick this up.', NULL, '2026-06-05 21:24:52', '2026-06-05 21:24:52', '2026-06-05 21:24:52', NULL, 'cb7834de6d3591d77a66d288e125097f', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM6DH7C6GQN9WNKQNXR', 'description', NULL, '`clide pane list` reports every GUI tab (T-219, D-83) but only its generic chrome: `id`, `title`, `active`, `visible`. For the context-slot detail panes the title is a static word — `tickets.detail` → "Ticket", `decisions.detail` → "Decision", `editor.active` → "Editor" — so the CLI cannot tell *which* ticket / decision / file the pane currently shows. The loaded subject lives in the view''s reader-nav state and never reaches the wire.

Concrete failure: with a ticket open in the right-hand context pane, there is no `clide` verb that answers "what ticket am I looking at". `pane list` shows `{"id":"tickets.detail","title":"Ticket","active":true}` and stops there. This breaks D-6 parity — the UI surfaces the open ticket; the CLI can''t observe it.

Fix: give `ViewPane` (lib/src/panes/view_pane.dart) an optional `subject` (and/or `subtitle`) field and have `snapshotViewPanes` (lib/kernel/src/panels/view_pane_snapshot.dart) populate it from the active reader-nav selection for detail panes — `tickets.detail` → `T-NNN`, `decisions.detail` → `D-NNN`, `editor.active` → the file path. Serialise it in `ViewPane.toJson` so `pane list` carries it. Keep ViewPane Flutter-free (it must stay usable under `dart test`); read the selection in the kernel-side snapshot, not in the value object.

Acceptance: with a ticket open in the context pane, `clide pane list` returns that pane with its loaded id (e.g. `"subject":"T-244"`); same for an open decision and an open editor file; panes with no subject omit the field; covered by a unit test over a snapshot with a populated reader-nav selection.', NULL, '2026-06-05 21:29:50', '2026-06-05 21:29:50', '2026-06-05 21:29:50', NULL, 'bd7e5281457bb9cd90e25fb210313296', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM6QCYT7JBF352YVJ48', 'description', NULL, 'The `clide` CLI does not honor the `CLIDE_SOCK` env var — it auto-discovers a running instance instead. Proof: with `CLIDE_SOCK=/run/user/1000/clide/DOES_NOT_EXIST.sock`, `clide version` still returns `{"version":"2.1.0"}` from the live app. Separately, the runtime socket dir accumulates orphaned socket files: `/run/user/1000/clide/` held two `.sock` entries while only one GUI process (the `build/linux/x64/debug/bundle/clide` bundle) was running, so a previous run''s socket was never cleaned up.

Why it matters: today (single instance) it''s harmless, but it''s a latent split-brain + observability hole. If two clide instances are ever live on the same machine, the CLI attaches to whichever discovery resolves first, with (a) no way to target a specific instance and (b) no way to find out which one you''re talking to. Combined with the stale-socket litter, `clide` could silently drive the wrong window. This is a D-6 surface gap — the CLI must be able to address the same instance the user is in.

Fix (scope to confirm):
- Honor `CLIDE_SOCK` when set (explicit target beats discovery); error clearly if that socket is dead rather than silently falling back.
- Clean up orphaned/stale socket files on app startup (and on clean shutdown) — detect a dead listener and unlink before binding a new hash.
- Add a way to enumerate/identify live instances (e.g. a `clide instances` verb, or include the instance id/socket path + pid in `clide version`) so a human or agent can pick the right one.

Acceptance: a bogus `CLIDE_SOCK` fails loudly instead of returning data from a different instance; a valid `CLIDE_SOCK` pins the CLI to that instance; startup leaves exactly one live socket for one running app (no orphan accumulation); there is a CLI affordance to list/identify running instances.', NULL, '2026-06-05 21:30:04', '2026-06-05 21:30:04', '2026-06-05 21:30:04', NULL, '453237303b4ea9c6a396f9f0ad23280a', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5F4D2Q363QF7V40K8', 'status', 'in_progress', 'done', NULL, '2026-06-06 06:44:40', '2026-06-06 06:44:40', '2026-06-06 06:44:40', NULL, '4b87229500c5bf1514d4eb4835f9da82', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5F2GC0ABFFVAH34EC', 'status', 'backlog', 'in_progress', NULL, '2026-06-06 06:51:47', '2026-06-06 06:51:47', '2026-06-06 06:51:47', NULL, '9c1ed7e465d7c41078928c3fce667668', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM70TW38E78FFXDHYAC', 'description', NULL, 'Create a `/clide` skill (none exists today — only legacy templates under legacy/clide/templates/skills/) that advertises the clide CLI surface to Claude so new affordances become discoverable.

Problem: my knowledge of the clide surface comes from a hand-curated session blurb. There is no runtime discovery — `clide help` is a stub, `clide <subsystem>` with no verb just prints `usage:`, and the dispatcher''s registered command table (e.g. pane_commands.dart) is never exposed. D-6 guarantees a verb EXISTS for every UI action, but parity != discoverability: a correctly-registered verb is still unreachable if nothing tells me it''s there.

Scope:
- Self-description first (prereq for a non-rotting skill): add a discovery verb that reflects the live dispatcher registry — e.g. `clide capabilities` (machine-readable JSON: subsystems -> verbs -> arg schema) and/or flesh out `clide help` to enumerate subsystems/verbs. Sourced from the registry so it never drifts.
- `/clide` SKILL.md: trigger description always visible to Claude; body points at the discovery verb rather than hard-coding a verb list, plus conventions (slots: sidebar/workspace/context, pane kinds, focus/spawn/close/write/resize). Thin and always-correct.

This is what makes T-249 (image viewer) and future panels reachable by Claude the moment they register — no skill edit per panel.

Refs: D-6 (CLI/event-surface parity). Related: T-249.', NULL, '2026-06-06 07:21:30', '2026-06-06 07:21:30', '2026-06-06 07:21:30', NULL, 'b08b5ff7848bfe37cb507d261ed5fa63', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7JXD3FKW91934D0W0', 'description', NULL, 'Add an image-viewer card to the Claude conversation log, with the CLI verb that drives it (D-6 parity).

Scope:
- Conversation card: render an image inline in the Claude conversation widget — clide-owned rendering (no opinionated package), display-only per D-78 (no inline interactive controls; any controls belong in the interaction zone). Respect theme tokens / ui-design.
- Plumbing: a `clide` verb to show an image in the log (e.g. `clide image show <path>` or via the pane subsystem), accepting a workspace path; define accepted formats (PNG/JPEG/...), path resolution (workspace-relative), and sizing/scaling behavior.
- Parity (D-6): the verb is the CLI counterpart of the card; ensure it registers in the dispatcher so it shows up in the discovery verb from T-248.

Dependency: pairs with T-248 — without the /clide skill + discovery verb, Claude won''t know this card/verb exists even once shipped. Build the plumbing here; T-248 makes it discoverable.

Refs: D-6 (parity), D-78 (interaction zone, display-only conversation widgets). Related: T-248.', NULL, '2026-06-06 07:21:36', '2026-06-06 07:21:36', '2026-06-06 07:21:36', NULL, '63ed4e687ffb9dd923ba3fe0e4a428ec', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM70TW38E78FFXDHYAC', 'status', 'backlog', 'ready', NULL, '2026-06-06 07:22:48', '2026-06-06 07:22:48', '2026-06-06 07:22:48', NULL, '74e5e7966bc30bb36c2c657c04ba0e6a', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7JXD3FKW91934D0W0', 'status', 'backlog', 'ready', NULL, '2026-06-06 07:22:48', '2026-06-06 07:22:48', '2026-06-06 07:22:48', NULL, '9799cee0cac8cb51d8aa0bf66f76351c', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5F2GC0ABFFVAH34EC', 'description', 'T-237 redesigned the status-bar theme POPOVER (theme_status_item.dart): base themes only, sorted by display name, a ''High contrast'' toggle that applies the -hc sibling, palette icon. The MODAL picker (picker_view.dart, opened by theme.pick / ctrl+k) still lists every theme including the -hc rows in available order. For consistency, apply the same treatment to picker_view: use the theme_families helpers (baseThemes / isHcName / resolveThemeName, already built + unit-tested in lib/builtin/theme_picker/src/theme_families.dart) to show base themes sorted, with a High contrast checkbox at the top. Low priority — the modal works; this is consistency polish.', 'T-237 redesigned the status-bar theme POPOVER (theme_status_item.dart): base themes only, sorted by display name, a ''High contrast'' toggle that applies the -hc sibling, palette icon. The MODAL picker (picker_view.dart, opened by theme.pick / ctrl+k) still lists every theme including the -hc rows in available order. For consistency, apply the same treatment to picker_view: use the theme_families helpers (baseThemes / isHcName / resolveThemeName, already built + unit-tested in lib/builtin/theme_picker/src/theme_families.dart) to show base themes sorted, with a High contrast checkbox at the top. Low priority — the modal works; this is consistency polish.

DONE (2026-06-06). Re-scoped per user: instead of just applying the -hc-checkbox+sort polish to the theme modal, the modal was PROMOTED to a general Settings modal (picker_view.dart -> settings_view.dart, ThemePickerView -> SettingsView). ctrl+k / theme.pick now opens Settings, whose only section today is Appearance: base themes (sorted) + a High contrast toggle, reusing the theme_families helpers (shared with the status-bar popover, T-237). Command id kept as theme.pick (welcome link + tests reference it); retitled ''Settings...''. Extensible: more sections later (or split to a builtin/settings extension when it grows). Tests in test/builtin/theme_picker/widget_test.dart (base-only list, hc toggle applies sibling). NOTE: status-bar popover (T-237) was already done — that is what the user saw ''done in the ui''.', NULL, '2026-06-06 07:24:00', '2026-06-06 07:24:00', '2026-06-06 07:24:00', NULL, '0bb9be512fd59f90b2d893f4241cb096', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5F2GC0ABFFVAH34EC', 'status', 'in_progress', 'done', NULL, '2026-06-06 07:24:00', '2026-06-06 07:24:00', '2026-06-06 07:24:00', NULL, '95c12acd291bb53b28c0669a04c894f0', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4BVE5EYM92CWGSXA4', 'description', NULL, 'Symptom: the permission-mode badge in the Claude status line does nothing visible when clicked, and Ctrl/Cmd+M (cycle mode, T-226) likewise appears to do nothing. Either the mode isn''t actually changing, or — more likely — it changes in the Claude process but the status-bar tracker is never updated.

Likely root cause (confirmed by reading the code): the cycle is fire-and-forget with no status feedback.
- Composer Ctrl/Cmd+M -> widget.onCycleMode -> _ClaudePaneState._cycleMode (lib/builtin/claude/src/claude_pane.dart:302) -> s.setPermissionMode(nextSafePermissionMode(...)).
- The badge click path (_ModeBadge.onCycle) routes to the same _cycleMode, so both symptoms share one cause.
- StreamJsonSession.setPermissionMode (lib/builtin/claude/src/stream_json_session.dart:671) only writes a `set_permission_mode` control_request to the process. It does NOT optimistically update `_status` nor emit on `_statusCtl`.
- `_status.permissionMode` is only ever set from a `system/init` event via `_statusFromEvent` (stream_json_session.dart:567-571). A set_permission_mode control_request returns a control_response, which is not folded into status — so `_status` never re-emits, the badge label (claude_pane.dart:105-122, driven by `_status` over statusStream) is stale, and the UI looks dead.

So the status bar / badge value is not updated on change — matching the reported hypothesis.

Fix direction:
- Optimistically merge the new mode into `_status` and emit on `_statusCtl` immediately after writing the control_request (mirror how other state transitions surface), and/or handle the `control_response` for set_permission_mode and reconcile from it.
- Separately verify the control_request is actually honored by the Claude process (the ''they don''t work'' branch) — if the response reports failure, surface it rather than silently assuming success.

Acceptance:
- Clicking the badge and pressing Ctrl/Cmd+M both visibly cycle default -> accept-edits -> plan -> default in the status line.
- The displayed mode reflects the session''s actual mode (reconciled from the response / next init), not just an optimistic guess.
- Regression test at the session level: setPermissionMode emits an updated SessionStatus on statusStream.

Refs: T-226 (interactive mode badge + Ctrl/Cmd+M), T-181 (bypassPermissions behind confirmed path — keep excluded from the safe cycle), D-78 (interaction-zone / display-only conventions).', NULL, '2026-06-06 07:31:06', '2026-06-06 07:31:06', '2026-06-06 07:31:06', NULL, '5f293364d4b8cc2ea694e594007b1bc5', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4BVE5EYM92CWGSXA4', 'status', 'backlog', 'ready', NULL, '2026-06-06 07:32:57', '2026-06-06 07:32:57', '2026-06-06 07:32:57', NULL, '9622e6e1c057e278f1f355fddd7c22d9', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5KYAV8TMH3Y3FPRSR', 'description', 'D-48 names `⌘P` (fuzzy file open) and `⌘⇧P` (command palette) as the canonical keyboard navigation. The command palette overlay/widget exists; the keybinding is not yet wired.

**Progress (2026-05-17, T-117):** The keymap layer now binds `ctrl+shift+p` / `meta+shift+p` to `PaletteOpenIntent` in `assets/keymaps/default.yaml`. The intent resolves end-to-end through `KeymapService.resolveEvent` → `Actions.maybeInvoke`. **Still pending**: an `Actions` provider somewhere in the tree that handles `PaletteOpenIntent` by calling `kernel.palette.open()`, plus the arrow-key / Escape / Enter handlers on `ClidePalette` itself. Those land as part of T-100 (palette keyboard nav).

**Acceptance:**
- `⌘⇧P` (`Ctrl+Shift+P` on Linux, follows the kernel keymap normalization) opens the command palette overlay over the active workspace.
- Esc dismisses; Enter runs the highlighted command; arrow keys move the highlight.
- Commands listed are everything registered via `CommandContribution` across all activated extensions.
- Fuzzy match against command title; recent / pinned commands float to the top.

**Implementation hints:**
- Slot exists: `Slots.commandPalette` is reserved (lib/kernel/src/panels/slot_id.dart).
- Bindings live in the keymap (T-117) — not in `lib/kernel/src/commands/keybindings.dart` (that file is legacy).
- The overlay should not shift layout (D-48 chrome budget — no layout shift on palette open).', 'D-48 names `⌘P` (fuzzy file open) and `⌘⇧P` (command palette) as the canonical keyboard navigation. The command palette overlay/widget exists; the keybinding is not yet wired.

**Progress (2026-05-17, T-117):** The keymap layer now binds `ctrl+shift+p` / `meta+shift+p` to `PaletteOpenIntent` in `assets/keymaps/default.yaml`. The intent resolves end-to-end through `KeymapService.resolveEvent` → `Actions.maybeInvoke`. **Still pending**: an `Actions` provider somewhere in the tree that handles `PaletteOpenIntent` by calling `kernel.palette.open()`, plus the arrow-key / Escape / Enter handlers on `ClidePalette` itself. Those land as part of T-100 (palette keyboard nav).

**Acceptance:**
- `⌘⇧P` (`Ctrl+Shift+P` on Linux, follows the kernel keymap normalization) opens the command palette overlay over the active workspace.
- Esc dismisses; Enter runs the highlighted command; arrow keys move the highlight.
- Commands listed are everything registered via `CommandContribution` across all activated extensions.
- Fuzzy match against command title; recent / pinned commands float to the top.

**Implementation hints:**
- Slot exists: `Slots.commandPalette` is reserved (lib/kernel/src/panels/slot_id.dart).
- Bindings live in the keymap (T-117) — not in `lib/kernel/src/commands/keybindings.dart` (that file is legacy).
- The overlay should not shift layout (D-48 chrome budget — no layout shift on palette open).

DONE (2026-06-06). Keybinding + nav were already wired (T-117 binds ctrl/meta+shift+p -> PaletteOpenIntent; _RootShell handles it -> palette.open(); T-100 added arrow/Enter/Esc nav + selected-index). Remaining acceptance implemented now: (1) FUZZY match — PaletteController.filtered() uses a shared subsequence matcher (lib/kernel/src/fuzzy.dart, extracted from quick_open so both share one source of truth), ranked best-score-first; (2) RECENCY — invoked commands float to the top on empty filter and break fuzzy-score ties (in-session MRU). DEFERRED: ''pinned'' commands + cross-session recency persistence need a pin affordance + settings storage — filed as a follow-up. Tests: test/kernel/src/commands/palette_test.dart + test/kernel/src/fuzzy_test.dart.', NULL, '2026-06-06 07:40:43', '2026-06-06 07:40:43', '2026-06-06 07:40:43', NULL, '3169ee6fdb1c4c2c0243b6b5708166aa', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5KYAV8TMH3Y3FPRSR', 'status', 'ready', 'done', NULL, '2026-06-06 07:40:43', '2026-06-06 07:40:43', '2026-06-06 07:40:43', NULL, 'ad3e8ce905d36af8e853d9097f3d1609', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4BVE5EYM92CWGSXA4', 'status', 'ready', 'done', NULL, '2026-06-06 07:49:08', '2026-06-06 07:49:08', '2026-06-06 07:49:08', NULL, '2f7a63272c39b62e02adb8355ac73d36', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM70TW38E78FFXDHYAC', 'status', 'ready', 'done', NULL, '2026-06-06 07:57:16', '2026-06-06 07:57:16', '2026-06-06 07:57:16', NULL, '2929c0012d12a978d20507b6289d4347', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7XMQ44AVCAARQZX14', 'status', 'backlog', 'ready', NULL, '2026-06-06 08:06:55', '2026-06-06 08:06:55', '2026-06-06 08:06:55', NULL, '2154d682e253c8d82a5baee32ccf8c20', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4QYYKHPQ03H3QD61W', 'status', 'backlog', 'in_progress', NULL, '2026-06-06 08:12:45', '2026-06-06 08:12:45', '2026-06-06 08:12:45', NULL, '043bc847ebe807e4a470d21b2daaaa7e', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7XMQ44AVCAARQZX14', 'status', 'ready', 'in_progress', NULL, '2026-06-06 08:12:45', '2026-06-06 08:12:45', '2026-06-06 08:12:45', NULL, '783dc9628035b4a7b15b1d7518447bf6', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM70TW38E78FFXDHYAC', 'description', 'Create a `/clide` skill (none exists today — only legacy templates under legacy/clide/templates/skills/) that advertises the clide CLI surface to Claude so new affordances become discoverable.

Problem: my knowledge of the clide surface comes from a hand-curated session blurb. There is no runtime discovery — `clide help` is a stub, `clide <subsystem>` with no verb just prints `usage:`, and the dispatcher''s registered command table (e.g. pane_commands.dart) is never exposed. D-6 guarantees a verb EXISTS for every UI action, but parity != discoverability: a correctly-registered verb is still unreachable if nothing tells me it''s there.

Scope:
- Self-description first (prereq for a non-rotting skill): add a discovery verb that reflects the live dispatcher registry — e.g. `clide capabilities` (machine-readable JSON: subsystems -> verbs -> arg schema) and/or flesh out `clide help` to enumerate subsystems/verbs. Sourced from the registry so it never drifts.
- `/clide` SKILL.md: trigger description always visible to Claude; body points at the discovery verb rather than hard-coding a verb list, plus conventions (slots: sidebar/workspace/context, pane kinds, focus/spawn/close/write/resize). Thin and always-correct.

This is what makes T-249 (image viewer) and future panels reachable by Claude the moment they register — no skill edit per panel.

Refs: D-6 (CLI/event-surface parity). Related: T-249.', 'Create a `/clide` skill (none exists today — only legacy templates under legacy/clide/templates/skills/) that advertises the clide CLI surface to Claude so new affordances become discoverable.

Problem: my knowledge of the clide surface comes from a hand-curated session blurb. There is no runtime discovery — `clide help` is a stub, `clide <subsystem>` with no verb just prints `usage:`, and the dispatcher''s registered command table (e.g. pane_commands.dart) is never exposed. D-6 guarantees a verb EXISTS for every UI action, but parity != discoverability: a correctly-registered verb is still unreachable if nothing tells me it''s there.

Scope:
- Self-description first (prereq for a non-rotting skill): add a discovery verb that reflects the live dispatcher registry — e.g. `clide capabilities` (machine-readable JSON: subsystems -> verbs -> arg schema) and/or flesh out `clide help` to enumerate subsystems/verbs. Sourced from the registry so it never drifts.
- `/clide` SKILL.md: trigger description always visible to Claude; body points at the discovery verb rather than hard-coding a verb list, plus conventions (slots: sidebar/workspace/context, pane kinds, focus/spawn/close/write/resize). Thin and always-correct.

This is what makes T-249 (image viewer) and future panels reachable by Claude the moment they register — no skill edit per panel.

Refs: D-6 (CLI/event-surface parity). Related: T-249.

RE-SCOPE (2026-06-06, from T-208 completeness review): partly overtaken by reality — do NOT build from scratch.
- The `clide capabilities` verb already EXISTS in code: registered in lib/src/daemon/dispatcher.dart:12 (built-in) and as an umbrella command in lib/src/cli/argv_to_request.dart:28. Its handler (_capabilities, dispatcher.dart:86) enumerates the live registry with arg schemas — so the non-rotting design is already implemented server-side.
- A `/clide` skill is ALSO already present this session (other ongoing work), and it instructs agents to "Start with `clide capabilities` to enumerate the live tool surface."
- BUT: against the live instance, `clide capabilities` returns a usage stub at exit 0 (`usage: clide capabilities <verb> [args...]`) instead of the command table — i.e. the discoverability entry point the skill advertises is currently DEAD. Likely a stale running build or a C-client umbrella mismatch (native/clide-cli/clide.c forwards argv but the live server treats `capabilities` as a subsystem needing a verb).

New scope for this ticket:
1. Verify/fix the live `clide capabilities` path end-to-end (rebuild/restart vs real wiring gap in the C client / server umbrella handling). Acceptance: `clide capabilities` returns the JSON command table against a running instance.
2. Reconcile with the already-shipped `/clide` skill rather than authoring anew — confirm it points at the working verb and covers the conventions.
Net: this is now a verify-and-reconcile task, not a build-from-scratch one. Related: T-249, T-208.', NULL, '2026-06-06 08:12:53', '2026-06-06 08:12:53', '2026-06-06 08:12:53', NULL, 'a8e6b6c8c4b66c575bf0fa125406dbab', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM70TW38E78FFXDHYAC', 'status', 'done', 'review', NULL, '2026-06-06 08:14:01', '2026-06-06 08:14:01', '2026-06-06 08:14:01', NULL, 'f7a8ffee6531ed6f6646855335cb1631', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7JXD3FKW91934D0W0', 'status', 'ready', 'done', NULL, '2026-06-06 08:21:40', '2026-06-06 08:21:40', '2026-06-06 08:21:40', NULL, '2731b543315820500f0456dec9144c0d', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM70TW38E78FFXDHYAC', 'status', 'review', 'done', NULL, '2026-06-06 08:31:25', '2026-06-06 08:31:25', '2026-06-06 08:31:25', NULL, 'd44a8900af4cb745252d71d996e80db4', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5NEXC0P46NJHACNM0', 'status', 'backlog', 'in_progress', NULL, '2026-06-06 08:33:42', '2026-06-06 08:33:42', '2026-06-06 08:33:42', NULL, '1ba6fe86835b5c6a53c17e111d70fab6', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5NEXC0P46NJHACNM0', 'status', 'in_progress', 'done', NULL, '2026-06-06 08:50:12', '2026-06-06 08:50:12', '2026-06-06 08:50:12', NULL, '932999018f2d5f258a734fb521c9ea3f', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5NEXC0P46NJHACNM0', 'status', 'done', 'in_progress', NULL, '2026-06-06 09:04:03', '2026-06-06 09:04:03', '2026-06-06 09:04:03', NULL, 'f3c5361ca5ea98f01575790cb9eefbeb', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5NEXC0P46NJHACNM0', 'status', 'in_progress', 'done', NULL, '2026-06-06 09:20:02', '2026-06-06 09:20:02', '2026-06-06 09:20:02', NULL, '1c96df771c2b4ee65728028de006085f', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM42VPM50VKAWXBCAM8', 'description', NULL, 'The Claude conversation panel detects URLs and colorizes them, but they are not interactive. Make detected links clickable (a plain click, or control/cmd-click) so they are handed off to the OS URL opener.

## Behaviour
- Click (or ctrl/cmd-click) on a colorized link opens it via the OS default handler.
- Hover affordance (cursor change / underline) so it reads as clickable.
- Keep the existing colorization.

## Notes
- Honour user/Claude parity (D-6) where relevant.
- Use the platform URL launcher; avoid pulling in an opinionated package if a thin native/url_launcher shim already exists in the tree.
- Guard against non-http schemes / malformed URLs.', NULL, '2026-06-06 09:33:01', '2026-06-06 09:33:01', '2026-06-06 09:33:01', NULL, 'e9ae63ee723e46643f5b2c0456e12900', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM61SRVBDRFFN2S80T4', 'description', NULL, 'When the user pastes an image, the conversation panel echoes back the file path as plain text (e.g. @/home/.../paste-<ts>.png). We now have an image viewer card — render the pasted image inline using that card instead of (or in addition to) the bare path.

## Behaviour
- Detect a pasted-image path in the conversation stream and render the image viewer card.
- Still surface the file path (e.g. as a caption / subtitle on the card) so it can be copied/referenced.
- Reuse the existing image viewer card component rather than building a new one.

## Notes
- Applies to the Claude conversation panel rendering path.
- Consider failure cases: missing/deleted file, non-image paste, very large images.', NULL, '2026-06-06 09:33:04', '2026-06-06 09:33:04', '2026-06-06 09:33:04', NULL, 'ce15a7fb32f8d4cd997d179bb7d58319', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM78Q3VYWSE830CTVB4', 'status', 'backlog', 'in_progress', NULL, '2026-06-06 09:43:49', '2026-06-06 09:43:49', '2026-06-06 09:43:49', NULL, '2453ca10f223362581a2205ea46ed5d0', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM63WP564EZRERJHVCM', 'description', NULL, '## Problem

While a Claude turn is in flight, the composer swaps in a static, muted
`running…` label next to the Stop button (`lib/builtin/claude/src/claude_composer.dart:486`,
shown when `widget.busy && widget.onInterrupt != null`). It''s gray, motionless,
and a little lifeless — it gives no sense that anything is actually happening.

## Goal

Make the in-flight indicator feel alive:

1. **Animation.** Add subtle motion — e.g. an animated ellipsis (`running` → `running.`
   → `running..` → `running...`), a shimmer/pulse on the text, or a small spinner glyph.
   Custom-painted / token-driven per the "own the rendering stack" guardrail; no
   opinionated animation packages.
2. **Rotating status verbs.** Cycle through playful gerunds the way the Claude Code CLI
   does (e.g. "Clauding…", "Flibbertigibbeting…", "Pondering…", "Conjuring…"). Pick a
   word from a curated list and rotate it every few seconds while the turn runs.

## Open question — can we reuse the CLI''s words?

The Claude Code CLI ships its own list of these status verbs. Before hand-rolling our
own, check whether that list is something we''re allowed to reuse / surface (licensing,
where it lives, whether stream-json exposes the current one). If we can''t pull the CLI''s
list, ship our own curated, on-brand list instead. Document the decision.

## Notes / constraints

- Respect reduced-motion / accessibility settings — animation must be disable-able and
  the a11y semantics should still read sensibly (the Stop button already carries the
  interrupt hint).
- Use theme tokens for color; keep it muted/tasteful, not distracting.
- Touch point today is the `widget.busy` branch in `claude_composer.dart`; consider
  whether the rotating-word state belongs there or in the session/orchestrator layer.
- Add a widget/golden test for the animated states (bounded pumps — no real timers).', NULL, '2026-06-06 09:57:12', '2026-06-06 09:57:12', '2026-06-06 09:57:12', NULL, 'ba353c0ca89d203805c4b72dfe2ba359', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM78Q3VYWSE830CTVB4', 'status', 'in_progress', 'done', NULL, '2026-06-06 10:02:03', '2026-06-06 10:02:03', '2026-06-06 10:02:03', NULL, 'fda523ee07c6aec223b8b9f3f4a5048a', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4QYYKHPQ03H3QD61W', 'status', 'in_progress', 'done', NULL, '2026-06-06 10:02:06', '2026-06-06 10:02:06', '2026-06-06 10:02:06', NULL, 'b53bbacef5897da88d1327c0c381d3fa', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM72ACQSDBJTKRBC58W', 'description', 'Return all events since a cursor plus a new cursor, alongside the existing stream (T-129). Acceptance: `clide events --since <c>` returns events + next-cursor with exit 0; repeated calls neither drop nor duplicate. Coordinate the cursor/persistence design with open questions Q-2 (event back-pressure) and Q-3 (event persistence + audit) — this dovetails with both.', 'Return all events since a cursor plus a new cursor, alongside the existing stream (T-129). Acceptance: `clide events --since <c>` returns events + next-cursor with exit 0; repeated calls neither drop nor duplicate. Coordinate the cursor/persistence design with open questions Q-2 (event back-pressure) and Q-3 (event persistence + audit) — this dovetails with both.

Refinement (2026-06-06): blockers resolved. Q-2 + Q-3 closed by D-85 (event bus delivery). Design is now fixed: serve --since from a bounded in-memory ring keyed by a monotonic cursor; return events-after-cursor + next-cursor, and a gap marker (per-subscriber dropped-count) when the requested cursor has aged out so callers detect loss rather than silently miss events. Back-pressure is drop-oldest (producer never blocks, subscribers never killed). No on-disk persistence in v1. Ready to implement.', NULL, '2026-06-06 10:24:57', '2026-06-06 10:24:57', '2026-06-06 10:24:57', NULL, '7df5c81270c33469ed7eafc5d49f496a', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5DYC7CRP8TMHADW8W', 'description', 'Gap 6 from self-analysis.md. The MCP SSE server (T-130, D-68) is live but mcp__ide__* tools are not exposed to an external agent out of the box, and getDiagnostics/executeCode were noted as stubs. The CLI path is the priority (Epics A-C); MCP follows. Decide + wire the minimal reachable MCP surface, or explicitly defer with a note. Relates to open question Q-32 (minimum MCP tool surface).', 'Gap 6 from self-analysis.md. The MCP SSE server (T-130, D-68) is live but mcp__ide__* tools are not exposed to an external agent out of the box, and getDiagnostics/executeCode were noted as stubs. The CLI path is the priority (Epics A-C); MCP follows. Decide + wire the minimal reachable MCP surface, or explicitly defer with a note. Relates to open question Q-32 (minimum MCP tool surface).

Refinement (2026-06-06): tool-surface question resolved. Q-32 closed by D-86 — expose the full mcp__clide__* namespace, but GENERATE tools/list from the co-registered command registry (D-74) that already feeds the CLI + palette, so there is no hand-maintained second surface; add a per-command MCP opt-out for poor-fit verbs (long-lived streams, UI-side-effecting). Transport stays SSE-only per D-73 (Q-33 re-confirmed, not reopened). Remaining stubs to make real: getDiagnostics + executeCode. Scope is now: registry->MCP tool-definition adapter (arg-schema -> JSON-Schema), served over the existing SSE transport.', NULL, '2026-06-06 10:25:02', '2026-06-06 10:25:02', '2026-06-06 10:25:02', NULL, 'cd82bcfcee3505798a084a326fc2cd3c', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4K2AAPK52Y8BEJ3YR', 'description', NULL, '**Symptom:** In the editor with the Vim preset active, pressing `Esc` to leave insert/visual mode and return to normal mode closes the current file/pane instead of switching modes.

**Repro:**
1. Select the Vim keybinding preset (T-65).
2. Open a file in the editor pane; enter insert mode (`i`).
3. Press `Esc`.

**Expected:** Editor returns to Vim normal mode (`-- NORMAL --`), file/pane stays open. This is T-207''s contract: `Esc -> normal from any mode`.

**Actual:** The file/pane closes.

**Root-cause hypothesis:** `assets/keymaps/default.yaml:26-27` binds `escape -> intent: dismiss` with NO `when:` clause, so it matches globally. The Vim mode-reset binding (`assets/keymaps/vim.yaml:69-71`, `escape -> command:vim.mode.normal`, gated `when: vim.insert || vim.visual`) is being out-resolved or shadowed by the unconditional `dismiss`, which falls through to closing the active pane/file when no overlay is open. Either the Vim preset still inherits an unconditional dismiss-on-escape, or the when-clause resolver lets the unguarded binding win over the more-specific scoped one for the same chord.

**Likely fix direction:**
- Ensure the keymap resolver prefers the more-specific `when`-scoped binding over an unconditional one for the same chord, and/or gate the global `dismiss`-on-escape so it does not fire when `editor.focused && (vim.insert || vim.visual)`.
- Sanity-check that `dismiss` should close a pane/file at all here — closing the active file on a bare Esc is surprising even outside Vim.

**Related:** epic T-65 (Vim preset), T-207 (Vim mode service owns Esc -> normal), T-205 / T-117 (key-sequence resolution + when-clauses).
**Files:** `assets/keymaps/default.yaml`, `assets/keymaps/vim.yaml`, `lib/builtin/editor/src/editor_view.dart`, `lib/kernel/src/keymap/`.', NULL, '2026-06-06 14:01:03', '2026-06-06 14:01:03', '2026-06-06 14:01:03', NULL, '01f136ca149c821a56a37d36821fd959', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4K2AAPK52Y8BEJ3YR', 'status', 'backlog', 'in_progress', NULL, '2026-06-06 18:44:58', '2026-06-06 18:44:58', '2026-06-06 18:44:58', NULL, 'd1ce20399e57562703a5f061d9a8e012', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4K2AAPK52Y8BEJ3YR', 'status', 'in_progress', 'done', NULL, '2026-06-06 18:58:25', '2026-06-06 18:58:25', '2026-06-06 18:58:25', NULL, '968e8833c027634439b39dc6c6f57ff1', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5DYC7CRP8TMHADW8W', 'status', 'backlog', 'in_progress', NULL, '2026-06-06 19:06:30', '2026-06-06 19:06:30', '2026-06-06 19:06:30', NULL, '6fd4f5a99810ca96fa7db1de1c1511ed', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM72ACQSDBJTKRBC58W', 'status', 'backlog', 'in_progress', NULL, '2026-06-06 19:06:30', '2026-06-06 19:06:30', '2026-06-06 19:06:30', NULL, '873de3e88de3b6d9bd74c96753af3568', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5KYAV8TMH3Y3FPRSR', 'status', 'ready', 'done', NULL, '2026-06-06 19:06:30', '2026-06-06 19:06:30', '2026-06-06 19:06:30', NULL, 'e3c10829d6afbf5d2682ef9e0df257a8', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM72ACQSDBJTKRBC58W', 'status', 'in_progress', 'done', NULL, '2026-06-06 19:24:44', '2026-06-06 19:24:44', '2026-06-06 19:24:44', NULL, '3138697fe1501716a729fd70ce390099', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM620F5ENRYNT9S0JDW', 'status', 'backlog', 'done', NULL, '2026-06-06 19:24:44', '2026-06-06 19:24:44', '2026-06-06 19:24:44', NULL, '5abe1c20278eb488c1e743769be37542', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5DYC7CRP8TMHADW8W', 'status', 'in_progress', 'done', NULL, '2026-06-06 19:37:47', '2026-06-06 19:37:47', '2026-06-06 19:37:47', NULL, '1e98081ef3b9dca916bf47fcef83aa9e', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM6S7KHYPE9W7S1JHZ8', 'status', 'backlog', 'in_progress', NULL, '2026-06-06 19:45:03', '2026-06-06 19:45:03', '2026-06-06 19:45:03', NULL, '2aa119d66370d885457a7687ade45723', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM6S7KHYPE9W7S1JHZ8', 'status', 'in_progress', 'done', NULL, '2026-06-06 19:53:07', '2026-06-06 19:53:07', '2026-06-06 19:53:07', NULL, '0f6ef4536136a8b715e1a0f06e999ae0', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7XMQ44AVCAARQZX14', 'status', 'in_progress', 'done', NULL, '2026-06-06 19:53:07', '2026-06-06 19:53:07', '2026-06-06 19:53:07', NULL, 'c8767f309187c2af7dcbc185ff808356', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7GCVGCH9RMGYHENCC', 'status', 'backlog', 'ready', NULL, '2026-06-06 20:00:45', '2026-06-06 20:00:45', '2026-06-06 20:00:45', NULL, 'b0c8f6f0883b0737db525a3d08010afd', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7GCVGCH9RMGYHENCC', 'description', 'Bottom panel or context tab showing daemon logs, build output, extension logs, and pql sync output. Filterable by source. Auto-scrolls to latest. Useful for debugging extension and IPC issues.', 'Bottom panel or context tab showing daemon logs, build output, extension logs, and pql sync output. Filterable by source. Auto-scrolls to latest. Useful for debugging extension and IPC issues.

UX design (2026-06-06, D-87): the panel is a bottom OUTPUT DOCK, read-only, two tabs — Output (the Logger stream, filter by source/level/text, auto-scroll) + Problems (moved out of the sidebar; no duplication). Toggled by a single status-bar widget that REPLACES the app-status indicator (merged health+log: green check when clean, warn/error counts when not, chevron for open state) — opens with click or Cmd/Ctrl+J. Needs a bounded in-memory ring sink on the Logger (no history today). Layout amends D-47 (dock pushes Claude up, capped so Claude stays >=50%). Terminal is NOT in the dock — kept first-class in the editor pane, tracked by T-258. Resolves Q-28. Wireframe: docs/design/wireframes/output-dock/.', NULL, '2026-06-06 20:56:04', '2026-06-06 20:56:04', '2026-06-06 20:56:04', NULL, '8e9ea74ba5a360b0211ae1b3898d60df', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5JK0RHMRAH47K8ND4', 'status', 'backlog', 'review', NULL, '2026-06-06 20:56:20', '2026-06-06 20:56:20', '2026-06-06 20:56:20', NULL, 'c4bb10f75b8ac6ab0bb472fe4e5bff74', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4QW8VH454J8V3E174', 'status', 'backlog', 'ready', NULL, '2026-06-06 21:00:34', '2026-06-06 21:00:34', '2026-06-06 21:00:34', NULL, '6f96d3cc06ca1d904ae02910499d1e36', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7GCVGCH9RMGYHENCC', 'status', 'ready', 'in_progress', NULL, '2026-06-06 21:07:50', '2026-06-06 21:07:50', '2026-06-06 21:07:50', NULL, '15e3a73b9493513a9e2e3eadb1ec414e', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5JK0RHMRAH47K8ND4', 'description', 'Parse file references from Claude output. Swap viewer content when right panel is open. Badge on spine when collapsed. Live-sync viewer when editing .md.', 'When an editor is open in edit mode on a renderable doc (.md), the right-hand context panel auto-opens a read-only view that mirrors the buffer and updates live as the user types (D-50 behavior 4). If the editor is on a non-renderable file, no auto-viewer (D-50 behavior 5, already holds).

Wiring sketch: EditorRegistry already emits editor.opened / editor.active-changed / editor.edited (lib/src/editor/registry.dart:85). The markdown reader (lib/builtin/markdown/src/markdown_viewer.dart) currently pulls content once via files.read with no subscription. The live-sync work is: (1) on editor.opened for a renderable file, auto-activate the markdown reader in the context panel; (2) subscribe the reader to editor.edited and re-render from the in-memory buffer rather than re-reading disk; (3) read-only — no edit affordances in the mirror.

HISTORY: T-36 originally bundled four D-50 clauses (parse Claude''s output for file references, swap the open viewer, badge the spine when collapsed, live-sync). The give-clide-hands push (T-208) superseded the first three: instead of clide scraping the terminal for references, the agent explicitly drives the reader via `clide ui open markdown <path>` (T-231) and ui.open -> diff (T-233). The spine badge was dropped (the open is now an intentional agent act, not a passive notification). Re-scoped 2026-06-06 to the one UI-owned piece that give-clide-hands did not deliver: the live-sync read-mirror. Re-homed from T-7 (Tier 5 canvas/graph, a mis-parent) to T-259 (interaction model). See the D-50 amendment.', NULL, '2026-06-06 21:14:16', '2026-06-06 21:14:16', '2026-06-06 21:14:16', NULL, '94a5b6a263c0d1ba8922a753db4434c5', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5JK0RHMRAH47K8ND4', 'title', 'Context auto-behavior: right panel reacts to Claude references', 'Live-sync read-mirror: context panel tracks the open editor buffer', NULL, '2026-06-06 21:14:16', '2026-06-06 21:14:16', '2026-06-06 21:14:16', NULL, 'ed09e0656722f18cfa69461f3ed2af9d', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5JK0RHMRAH47K8ND4', 'parent_id', 'T-7', 'T-259', NULL, '2026-06-06 21:14:19', '2026-06-06 21:14:19', '2026-06-06 21:14:19', NULL, '828d07396d886d58d6cf09902d9b6e9a', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5JK0RHMRAH47K8ND4', 'status', 'review', 'backlog', NULL, '2026-06-06 21:14:22', '2026-06-06 21:14:22', '2026-06-06 21:14:22', NULL, '38410b8cab1366094cac896ff6ff1257', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM63WP564EZRERJHVCM', 'status', 'backlog', 'ready', NULL, '2026-06-06 21:43:40', '2026-06-06 21:43:40', '2026-06-06 21:43:40', NULL, '51798182bc568f87d420859e4389a4f0', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7GCVGCH9RMGYHENCC', 'status', 'in_progress', 'done', NULL, '2026-06-07 08:03:17', '2026-06-07 08:03:17', '2026-06-07 08:03:17', NULL, '6b1cfe3dd2263ea586eee797748dfc0a', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4QW8VH454J8V3E174', 'status', 'ready', 'in_progress', NULL, '2026-06-07 08:07:42', '2026-06-07 08:07:42', '2026-06-07 08:07:42', NULL, '54492c75e5f9415a70de079767bc00fe', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4QW8VH454J8V3E174', 'status', 'in_progress', 'done', NULL, '2026-06-07 08:32:36', '2026-06-07 08:32:36', '2026-06-07 08:32:36', NULL, '96c3f6af3d4274629ec0d2b1809b3cb8', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM71P14PAF7K4QE61G0', 'description', 'Today a Claude tool call renders as TWO stacked cards in the conversation log: the tool-use card (e.g. "Write <path>" with a collapsible call body) and a separate success/result card ("Write · result / File created successfully..."). Collapse the successful pair into ONE card; failure keeps the current two-card interaction.

Current code: lib/builtin/claude/src/conversation_view.dart — _toolUse (~L294) renders AssistantToolUse, _toolResult (~L329) renders ToolResultMessage; the two ConversationItems are linked by toolUseId (ToolResultMessage.isError marks failure). ConversationCard header is built in lib/builtin/claude/src/conversation_card.dart _header (~L200). Builds on T-168 (per-tool body rendering).

Desired behavior (success):
- One card per successful tool call — the tool-use card. The standalone success result card is suppressed (folded in), not rendered separately.
- A success-green check mark sits at the RIGHT END of the card header row (reuse tokens.statusSuccess + a check glyph: PhosphorIcons.check or CheckIcon). No new theme tokens.
- Collapsed by default: header shows the existing summary + the check. Expanding the card reveals the CALL segment (the input — path / diff / command, as today) and, BELOW it, the RESULT segment (the swallowed output). This applies to ALL tools, not just Write/Edit: for Bash/Read/Grep/LS the real output relocates into the expandable body so nothing is lost; for Write/Edit the trivial confirmation folds in the same way.
- Render the result segment as an inline ClideCodeBlock (lib/widgets/src/clide_code_block.dart) WITH editor syntax colorization. ClideCodeBlock already colorizes via TreeSitterService when handed a language — so the work is inferring/passing the right language per tool: Read → from the file extension/path (language_map.grammarForPath), Bash → bash, Grep/LS/others → text fallback. Where a path is available, prefer it so highlighting matches the editor.

Desired behavior (failure) — UNCHANGED:
- Leave the current interaction as-is: the tool-use card plus the prominent red "· error" result card (borderColor statusError, expanded-by-default). Optionally show a red status mark on the tool-use header for symmetry, but do NOT fold the error into one card.

What to build:
1. ConversationCard: a trailing header status slot (e.g. status: success|error|none) rendered in _header between the Spacer/summary and the hover action buttons.
2. ConversationCard: support a second body segment so an expanded card can show CALL then RESULT with a clear visual separator / sub-label (e.g. a divider or a muted "result" label) so the user can tell the call from its output.
3. conversation_view: a result-by-toolUseId lookup (reverse of the existing toolUseById) so a tool-use card knows its outcome; on a successful pair, stamp the check + fold the result body and SUPPRESS the standalone success ToolResultMessage from the rendered list. Errors render both cards as today.
4. Per-tool result language inference for the folded code block.

Edge cases to handle:
- In-flight tool-use with no result yet: render the call card as today (no check, no folded result); status/result appear once the result arrives.
- Orphan result with no paired tool-use: keep rendering it standalone.
- Permission-resolved tool-use cards (conversation_view.dart ~L297, already green/red bordered + collapsed): reconcile so the merged-card + check treatment is consistent and not duplicated with the existing border-outcome styling.
- Result items may not be strictly adjacent to their tool-use in the list; suppression must be keyed by toolUseId, not list position.

Tests: unit/widget coverage for the merged success card (collapsed shows check; expanded shows call + colorized result), language inference per tool, the unchanged error path, and the in-flight/orphan cases. Add a golden for the merged success card.

Refs: D-78 (interaction zone / display-only conversation widgets). Builds on T-168 (per-tool tool-use/result body rendering).', 'Today a Claude tool call renders as TWO stacked cards in the conversation log: the tool-use card (e.g. "Write <path>" with a collapsible call body) and a separate success/result card ("Write · result / File created successfully..."). Collapse the successful pair into ONE card; failure keeps the current two-card interaction.

Current code: lib/builtin/claude/src/conversation_view.dart — _toolUse (~L294) renders AssistantToolUse, _toolResult (~L329) renders ToolResultMessage; the two ConversationItems are linked by toolUseId (ToolResultMessage.isError marks failure). ConversationCard header is built in lib/builtin/claude/src/conversation_card.dart _header (~L200). Builds on T-168 (per-tool body rendering).

Desired behavior (success):
- One card per successful tool call — the tool-use card. The standalone success result card is suppressed (folded in), not rendered separately.
- A success-green check mark sits at the RIGHT END of the card header row (reuse tokens.statusSuccess + a check glyph: PhosphorIcons.check or CheckIcon). No new theme tokens.
- Collapsed by default: header shows the existing summary + the check. Expanding the card reveals the CALL segment (the input — path / diff / command, as today) and, BELOW it, the RESULT segment (the swallowed output). This applies to ALL tools, not just Write/Edit: for Bash/Read/Grep/LS the real output relocates into the expandable body so nothing is lost; for Write/Edit the trivial confirmation folds in the same way.
- Render the result segment as an inline ClideCodeBlock (lib/widgets/src/clide_code_block.dart) WITH editor syntax colorization. ClideCodeBlock already colorizes via TreeSitterService when handed a language — so the work is inferring/passing the right language per tool: Read → from the file extension/path (language_map.grammarForPath), Bash → bash, Grep/LS/others → text fallback. Where a path is available, prefer it so highlighting matches the editor.

Desired behavior (failure) — UNCHANGED:
- Leave the current interaction as-is: the tool-use card plus the prominent red "· error" result card (borderColor statusError, expanded-by-default). Optionally show a red status mark on the tool-use header for symmetry, but do NOT fold the error into one card.

What to build:
1. ConversationCard: a trailing header status slot (e.g. status: success|error|none) rendered in _header between the Spacer/summary and the hover action buttons.
2. ConversationCard: support a second body segment so an expanded card can show CALL then RESULT with a clear visual separator / sub-label (e.g. a divider or a muted "result" label) so the user can tell the call from its output.
3. conversation_view: a result-by-toolUseId lookup (reverse of the existing toolUseById) so a tool-use card knows its outcome; on a successful pair, stamp the check + fold the result body and SUPPRESS the standalone success ToolResultMessage from the rendered list. Errors render both cards as today.
4. Per-tool result language inference for the folded code block.

Edge cases to handle:
- In-flight tool-use with no result yet: render the call card as today (no check, no folded result); status/result appear once the result arrives.
- Orphan result with no paired tool-use: keep rendering it standalone.
- Permission-resolved tool-use cards (conversation_view.dart ~L297, already green/red bordered + collapsed): reconcile so the merged-card + check treatment is consistent and not duplicated with the existing border-outcome styling.
- Result items may not be strictly adjacent to their tool-use in the list; suppression must be keyed by toolUseId, not list position.

Tests: unit/widget coverage for the merged success card (collapsed shows check; expanded shows call + colorized result), language inference per tool, the unchanged error path, and the in-flight/orphan cases. Add a golden for the merged success card.

Refs: D-78 (interaction zone / display-only conversation widgets). Builds on T-168 (per-tool tool-use/result body rendering).

IMPLEMENTATION NOTES (from streamlining analysis):

C — Error-card symmetry decision: this ticket merges only SUCCESS into the tool card; the error path intentionally stays a separate prominent red "· error" card (conversation_view.dart ~L337) for failure visibility. Decide explicitly: keep that asymmetry (success folds, failure stays two-card) OR also stamp a red status mark on the tool-use header for visual symmetry while still keeping the separate red card. Default leaning: keep the separate red card; optionally add the red header mark.

D — Activity-cluster coupling: activity_cluster.groupConversation currently folds a tool CALL and its RESULT as TWO separate foldable items into a cluster (activity_cluster.dart ~L100-109, classifying each by toolUseId). Once this ticket makes call+result a single self-contained card, the grouping pass must treat the tool call as ONE unit (its result is part of the card, no longer a separate foldable item) or the result will double-render (once folded into the card, once as a cluster item). Update _isFoldable / the pairing logic accordingly and add a test that a merged tool card is not double-counted.', NULL, '2026-06-07 08:40:45', '2026-06-07 08:40:45', '2026-06-07 08:40:45', NULL, 'ce5df7afb04b516724c06e891f9ca0a4', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7XXSERDHKR0EEH3N4', 'description', 'When Claude launches a sub-agent (the Agent/Task tool), the sub-agent conversation runs as a SIDECHAIN. The prompt Claude wrote for that sub-agent comes through the transcript as a UserMessage with isSidechain=true but injected=false. The conversation view does not look at isSidechain, so it renders that prompt with the blue "you" label exactly like real user input — FALSELY implying the user sent it. It sits as a standalone block below the Agent tool-use card. This is misleading: the user did not write that prompt.

Confirmed facts from the code: every transcript envelope carries BOTH isSidechain AND parentUuid (transcript_reader.dart ~L547 parses isSidechain but never USES it; parentUuid is dropped entirely). The Agent/Task tool-use is rendered by _toolUse in lib/builtin/claude/src/conversation_view.dart (only AskUserQuestion is special-cased today). The "you" vs "context" label is chosen in conversation_view.dart (~L200): UserMessage with injected=true → "context" (muted); else → "you" (blue, tokens.globalFocus). isSidechain is currently never read by any rendering/grouping logic.

Design (confirmed with user):
1. Never label a sidechain prompt "you". A UserMessage with isSidechain=true is an AGENT PROMPT, not user input — label it "agent prompt" with muted / de-emphasized styling (same precedent as injected "context" messages, D-78). Never the blue "you" treatment.
2. Fold the prompt INTO the Agent tool-use card above it, COLLAPSED BY DEFAULT. The Agent card becomes the container that owns its prompt: expand the card to reveal the prompt; collapsed (default) it is hidden. The standalone prompt block is SUPPRESSED from the list — same fold-a-standalone-item-into-its-card pattern as T-262.
3. Prompt folds into the CALL, not the results. Only the prompt folds into the collapsed Agent call card. The sub-agent work (its thinking / tool calls / results) stays VISIBLE as the results chain after the call — not buried. Shape: [collapsed Agent call, owning the prompt] then [the run results], with no misleading "you" block anywhere. Agent prompts are valuable enough to keep with the call rather than fold into the subsequent results chain.
4. Link the prompt to the RIGHT Agent card via parentUuid. Parse parentUuid (currently dropped) so each sidechain prompt attaches to its spawning Agent tool-use. This matters when several agents run in parallel in one turn — a positional "nearest preceding Agent" heuristic would misattach; the parent link is the robust route. Heuristic only as a fallback when the link cannot be resolved.

Touch points:
- transcript_reader.dart: capture parentUuid from the envelope and expose it on ConversationItem (it is present in the JSONL, just not parsed).
- conversation_view.dart: relabel sidechain UserMessage to "agent prompt" (stop the "you" path); fold it into the Agent card body; special-case the Agent/Task tool name (today only AskUserQuestion is special-cased); suppress the standalone block.
- activity_cluster.dart: ensure the suppressed prompt is not double-counted in grouping; leave the sidechain results in the chain.

Edge cases:
- Parallel agents in one turn → each prompt attaches to its own card (the reason for parentUuid).
- Orphan prompt (no resolvable parent) → still render as "agent prompt", muted/collapsed, never "you".
- Nested / background sub-agents.

Tests: unit/widget coverage for sidechain-prompt relabel (never "you"), folding into the Agent card (collapsed hides, expand reveals), suppression of the standalone block, parentUuid attachment with parallel agents, and the orphan fallback. Add a golden for the Agent card with a folded prompt.

Refs: D-78 (interaction zone / display-only conversation widgets; injected/context muting precedent). Related: T-262 (fold-standalone-item-into-its-card pattern).', 'When Claude launches a sub-agent (the Agent/Task tool), the sub-agent conversation runs as a SIDECHAIN. The prompt Claude wrote for that sub-agent comes through the transcript as a UserMessage with isSidechain=true but injected=false. The conversation view does not look at isSidechain, so it renders that prompt with the blue "you" label exactly like real user input — FALSELY implying the user sent it. It sits as a standalone block below the Agent tool-use card. This is misleading: the user did not write that prompt.

Confirmed facts from the code: every transcript envelope carries BOTH isSidechain AND parentUuid (transcript_reader.dart ~L547 parses isSidechain but never USES it; parentUuid is dropped entirely). The Agent/Task tool-use is rendered by _toolUse in lib/builtin/claude/src/conversation_view.dart (only AskUserQuestion is special-cased today). The "you" vs "context" label is chosen in conversation_view.dart (~L200): UserMessage with injected=true → "context" (muted); else → "you" (blue, tokens.globalFocus). isSidechain is currently never read by any rendering/grouping logic.

Design (confirmed with user):
1. Never label a sidechain prompt "you". A UserMessage with isSidechain=true is an AGENT PROMPT, not user input — label it "agent prompt" with muted / de-emphasized styling (same precedent as injected "context" messages, D-78). Never the blue "you" treatment.
2. Fold the prompt INTO the Agent tool-use card above it, COLLAPSED BY DEFAULT. The Agent card becomes the container that owns its prompt: expand the card to reveal the prompt; collapsed (default) it is hidden. The standalone prompt block is SUPPRESSED from the list — same fold-a-standalone-item-into-its-card pattern as T-262.
3. Prompt folds into the CALL, not the results. Only the prompt folds into the collapsed Agent call card. The sub-agent work (its thinking / tool calls / results) stays VISIBLE as the results chain after the call — not buried. Shape: [collapsed Agent call, owning the prompt] then [the run results], with no misleading "you" block anywhere. Agent prompts are valuable enough to keep with the call rather than fold into the subsequent results chain.
4. Link the prompt to the RIGHT Agent card via parentUuid. Parse parentUuid (currently dropped) so each sidechain prompt attaches to its spawning Agent tool-use. This matters when several agents run in parallel in one turn — a positional "nearest preceding Agent" heuristic would misattach; the parent link is the robust route. Heuristic only as a fallback when the link cannot be resolved.

Touch points:
- transcript_reader.dart: capture parentUuid from the envelope and expose it on ConversationItem (it is present in the JSONL, just not parsed).
- conversation_view.dart: relabel sidechain UserMessage to "agent prompt" (stop the "you" path); fold it into the Agent card body; special-case the Agent/Task tool name (today only AskUserQuestion is special-cased); suppress the standalone block.
- activity_cluster.dart: ensure the suppressed prompt is not double-counted in grouping; leave the sidechain results in the chain.

Edge cases:
- Parallel agents in one turn → each prompt attaches to its own card (the reason for parentUuid).
- Orphan prompt (no resolvable parent) → still render as "agent prompt", muted/collapsed, never "you".
- Nested / background sub-agents.

Tests: unit/widget coverage for sidechain-prompt relabel (never "you"), folding into the Agent card (collapsed hides, expand reveals), suppression of the standalone block, parentUuid attachment with parallel agents, and the orphan fallback. Add a golden for the Agent card with a folded prompt.

Refs: D-78 (interaction zone / display-only conversation widgets; injected/context muting precedent). Related: T-262 (fold-standalone-item-into-its-card pattern).

IMPLEMENTATION NOTE (E — Agent-card layered ordering, from streamlining analysis):

With this ticket (fold prompt) and T-262 (merge success result) both landing, the Agent/Task card ends up owning multiple segments: the tool INPUT, the folded PROMPT, and — via T-262 — the sub-agents final returned RESULT (the Task ToolResultMessage). Define a deliberate layered order when expanded (e.g. call/input → prompt → returned result) with clear sub-labels/dividers so the Agent card stays readable and does not become a kitchen sink. Coordinate with T-262 (result merge) and T-264 (nesting the whole run): the nested run region vs the returned-result segment must not duplicate the sub-agent output.', NULL, '2026-06-07 08:40:49', '2026-06-07 08:40:49', '2026-06-07 08:40:49', NULL, '6c5fa64d1114b050708456bd650e2213', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7XXSERDHKR0EEH3N4', 'parent_id', NULL, 'T-267', NULL, '2026-06-07 08:43:00', '2026-06-07 08:43:00', '2026-06-07 08:43:00', NULL, '0d2ee5d7b3d6623a90e36ccaca03916d', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5YYMMKFD5Z8WG9F60', 'parent_id', NULL, 'T-267', NULL, '2026-06-07 08:43:00', '2026-06-07 08:43:00', '2026-06-07 08:43:00', NULL, '223065799d6e12580c20492ea0233057', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM45HHRBCRMV2166Y6M', 'parent_id', NULL, 'T-267', NULL, '2026-06-07 08:43:00', '2026-06-07 08:43:00', '2026-06-07 08:43:00', NULL, '517313811d3de674226344c51953e787', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM71P14PAF7K4QE61G0', 'parent_id', NULL, 'T-267', NULL, '2026-06-07 08:43:00', '2026-06-07 08:43:00', '2026-06-07 08:43:00', NULL, '694c1016bf75a0104bef6ab9e152a9d6', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4Q1Q97CHA0XNK2G4W', 'parent_id', NULL, 'T-267', NULL, '2026-06-07 08:43:00', '2026-06-07 08:43:00', '2026-06-07 08:43:00', NULL, 'b94daf10a59ddbb4bacec73eb5ccb716', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM63WP564EZRERJHVCM', 'description', '## Problem

While a Claude turn is in flight, the composer swaps in a static, muted
`running…` label next to the Stop button (`lib/builtin/claude/src/claude_composer.dart:486`,
shown when `widget.busy && widget.onInterrupt != null`). It''s gray, motionless,
and a little lifeless — it gives no sense that anything is actually happening.

## Goal

Make the in-flight indicator feel alive:

1. **Animation.** Add subtle motion — e.g. an animated ellipsis (`running` → `running.`
   → `running..` → `running...`), a shimmer/pulse on the text, or a small spinner glyph.
   Custom-painted / token-driven per the "own the rendering stack" guardrail; no
   opinionated animation packages.
2. **Rotating status verbs.** Cycle through playful gerunds the way the Claude Code CLI
   does (e.g. "Clauding…", "Flibbertigibbeting…", "Pondering…", "Conjuring…"). Pick a
   word from a curated list and rotate it every few seconds while the turn runs.

## Open question — can we reuse the CLI''s words?

The Claude Code CLI ships its own list of these status verbs. Before hand-rolling our
own, check whether that list is something we''re allowed to reuse / surface (licensing,
where it lives, whether stream-json exposes the current one). If we can''t pull the CLI''s
list, ship our own curated, on-brand list instead. Document the decision.

## Notes / constraints

- Respect reduced-motion / accessibility settings — animation must be disable-able and
  the a11y semantics should still read sensibly (the Stop button already carries the
  interrupt hint).
- Use theme tokens for color; keep it muted/tasteful, not distracting.
- Touch point today is the `widget.busy` branch in `claude_composer.dart`; consider
  whether the rotating-word state belongs there or in the session/orchestrator layer.
- Add a widget/golden test for the animated states (bounded pumps — no real timers).', '## Problem

While a Claude turn is in flight, the composer swaps in a static, muted
`running…` label next to the Stop button (`lib/builtin/claude/src/claude_composer.dart:486`,
shown when `widget.busy && widget.onInterrupt != null`). It''s gray, motionless,
and a little lifeless — it gives no sense that anything is actually happening.

## Goal

Make the in-flight indicator feel alive:

1. **Animation.** Add subtle motion — e.g. an animated ellipsis (`running` → `running.`
   → `running..` → `running...`), a shimmer/pulse on the text, or a small spinner glyph.
   Custom-painted / token-driven per the "own the rendering stack" guardrail; no
   opinionated animation packages.
2. **Rotating status verbs.** Cycle through playful gerunds the way the Claude Code CLI
   does (e.g. "Clauding…", "Flibbertigibbeting…", "Pondering…", "Conjuring…"). Pick a
   word from a curated list and rotate it every few seconds while the turn runs.

## Open question — can we reuse the CLI''s words?

The Claude Code CLI ships its own list of these status verbs. Before hand-rolling our
own, check whether that list is something we''re allowed to reuse / surface (licensing,
where it lives, whether stream-json exposes the current one). If we can''t pull the CLI''s
list, ship our own curated, on-brand list instead. Document the decision.

## Notes / constraints

- Respect reduced-motion / accessibility settings — animation must be disable-able and
  the a11y semantics should still read sensibly (the Stop button already carries the
  interrupt hint).
- Use theme tokens for color; keep it muted/tasteful, not distracting.
- Touch point today is the `widget.busy` branch in `claude_composer.dart`; consider
  whether the rotating-word state belongs there or in the session/orchestrator layer.
- Add a widget/golden test for the animated states (bounded pumps — no real timers).

Refinement (2026-06-07): open question resolved — ship OUR OWN curated verb list, do not reuse the CLI''s. Rationale: the spinner words are a TUI cosmetic not surfaced by the stream-json control protocol (so there''s nothing to read live), and extracting Anthropic''s bundled list is a licensing gray area. A clide-owned list aligns with ''own the rendering stack'' and D-75 (isolate/version-pin CC coupling). State lives in the WIDGET layer (a RunningIndicator in lib/builtin/claude/), not the orchestrator — it''s ephemeral UI. Animation via AnimationController (no Timers, so tests use bounded pumps); reduced-motion (MediaQuery.disableAnimations) shows a static verb. Ready to implement.', NULL, '2026-06-07 08:44:32', '2026-06-07 08:44:32', '2026-06-07 08:44:32', NULL, '420aecd96d2137e5ed9c09ebae4c6c38', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM63WP564EZRERJHVCM', 'status', 'ready', 'in_progress', NULL, '2026-06-07 08:44:32', '2026-06-07 08:44:32', '2026-06-07 08:44:32', NULL, 'fc3d71b83ffcc1a213a2f0a74219bffc', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM45HHRBCRMV2166Y6M', 'description', 'DESIGN DISCUSSION PENDING — do not build until T-262/T-263/T-264/T-265 settle. Captured from user feedback; the interaction model needs a design pass first.

Problem: the current activity card (lib/builtin/claude/src/conversation_view.dart _ActivityCard ~L427, grouping in activity_cluster.dart) is a COLLAPSER HEADER that, when expanded, reveals the subsequent cards rendered below it. Two issues:
1. Model: it reads as a header-plus-loose-cards rather than a single container. Proposal: make it a HOLDER CARD that visually CONTAINS its sub-cards, where clicking anywhere in the card space (the holder) toggles collapse/expand — the whole card is the affordance, not just a small caret/header at the top.
2. Scroll race: when a holder card is actively being written to (a live agent turn), the view keeps auto-scrolling to the bottom (conversation_view._onChanged ~L119 jumps to maxScrollExtent on every change). The collapse control lives at the TOP of the card, so the user gets into a scrolling race trying to reach it while new content keeps yanking the viewport down. The collapse affordance must remain reachable during live writes — e.g. card-space toggle (so any visible part of the holder toggles it), a sticky/pinned control, and/or pausing autoscroll on user interaction.

Likely scope (to be refined after the design discussion):
- Re-model _ActivityCard as a container that wraps its children rather than a header followed by siblings.
- Make the whole holder card the collapse/expand hit target (ClideTappable over the card body), keeping keyboard + AT semantics.
- Resolve the autoscroll-vs-reach-the-control conflict (sticky control, whole-card toggle, and/or suspend tail-follow on user scroll/interaction).

This interacts with T-264 (nesting a whole sub-agent run is itself a holder/container) — settle the container model once so the agent-run region and the activity card share it.

Refs: D-78. Related: T-230 (activity card), T-264 (nested agent run), T-262, T-263.', 'Restyle the activity card (and, via a shared primitive, the nested sub-agent run from T-264) so a folded run reads as ONE container that holds its sub-cards, with a reachable collapse/expand affordance that survives live writes.

DESIGN RESOLVED (with user) — supersedes the earlier design-pending note.

1. HOLDER = a shared container primitive. Extract one container widget (e.g. a ClideHolderCard / conversation-level container) that renders a titled/attributed frame WRAPPING its child sub-cards. Both the activity card (_ActivityCard, lib/builtin/claude/src/conversation_view.dart ~L427) and the nested sub-agent run (T-264) consume it, so the container model is settled once. NOTE: this makes T-266 a DEPENDENCY of T-264 (the shared primitive must exist before the agent-run nesting can consume it) — update epic T-267 sequencing: T-266''s primitive lands before/with T-264, no longer strictly last.

2. Toggle = the HOLDER BACKGROUND, not the children. Clicking the container''s own background/chrome (its padding, the gaps between sub-cards, its gutter — any region NOT covered by a child) toggles collapse/expand. Crucially:
- Taps on a child sub-card lying on top of the background MUST NOT toggle the holder. Child cards opaquely consume their own hit region across their FULL bounds (including their body), so a click on a sub-card interacts with that card, never the holder.
- The copy button (and any child control / ClideTappable) keeps its own interaction — never swallowed by the holder toggle.
- Implementation: a background gesture target behind the children that only fires for hits the children do not consume (HitTestBehavior; children opaque over their bounds). No whole-card overlay that would intercept child taps.

3. Autoscroll stays ALWAYS-FOLLOW. Keep the current tail-follow (conversation_view._onChanged ~L119 jumps to maxScrollExtent on every change). Reachability of the collapse control no longer depends on getting to a top header: because the toggle is the ever-present holder BACKGROUND, a click on whatever background area is currently in view (near the latest content while following) collapses the holder — ending the race. Once collapsed the card shrinks to its ticker, so the scroll-yank stops.

4. Keep the collapsed ticker. Collapsed (default) still shows the one-line live ticker (latest step) + step count, as today. Expanded shows the contained sub-cards.

5. Accessibility (obligation): a background tap is not keyboard/AT reachable on its own, so keep an EXPLICIT focusable, Enter/Space-activatable collapse control (e.g. the ticker row remains a Semantics button / a focusable caret) in addition to the background-click affordance. Announce expanded/collapsed + step count (as _ActivityCard does today).

Touch points:
- New shared container primitive (extracted from _ActivityCard).
- conversation_view.dart: _ActivityCard adopts the primitive; background-toggle wiring; ensure child ConversationCards opaquely consume their bounds so they do not bubble taps to the holder.
- T-264 consumes the same primitive for the nested agent run.

Edge cases:
- A holder whose child is itself collapsible (a tool card): tapping the child''s caret/body toggles the CHILD, never the holder.
- Text selection inside a child (ClideSelectionArea wraps the list): selection drags on child bodies must not be hijacked by the holder toggle — another reason the holder responds only to its own background, and only to taps (not drags).
- Empty / single-item holder.

Tests: holder background tap toggles; tap on a child sub-card does NOT toggle the holder; copy button still copies (not swallowed); keyboard/AT path toggles via the explicit control; collapsed ticker + step count preserved. Add a golden for the holder container (collapsed + expanded).

Refs: D-78. Provides the shared container consumed by T-264. Related: T-230 (activity card), T-262 / T-263 / T-265. Parent: T-267.', NULL, '2026-06-07 08:48:47', '2026-06-07 08:48:47', '2026-06-07 08:48:47', NULL, '55264f40c2a84b70cfc8b2d006644423', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7ZGZ9GQ5W1MKV00Y4', 'description', 'Home for the cohesive set of work that streamlines how the Claude conversation log renders, so a heavy agent turn reads clearly and nothing is mislabeled or duplicated. Three recurring moves bind these tickets: (1) FOLD a redundant standalone item into its owning card (success result → tool card; agent prompt → agent card); (2) fix MISLEADING ATTRIBUTION (sub-agent prompt shown as "you"; sub-agent prose shown as "claude"); (3) settle the CONTAINER / interaction model (holder card that contains sub-cards, nested agent run, autoscroll-vs-reach-the-control).

Common substrate across the children: the flat ConversationItem list and its renderers in lib/builtin/claude/src/conversation_view.dart, the pure grouping pass in activity_cluster.dart, the ConversationCard template in conversation_card.dart, and the so-far-unused ConversationItem.isSidechain / parentUuid transcript fields (transcript_reader.dart).

Children: T-262 (merge tool-call + success result into one card with header status check), T-263 (fold sub-agent prompt into the Agent card; relabel you → agent prompt), T-264 (nest the whole sub-agent run under its Agent card via parentUuid), T-265 (relabel sidechain assistant prose/thinking — agent, not claude), T-266 (restyle activity/holder card as a container of sub-cards + fix the collapse-control scroll race). Sequencing: T-262/T-263 first, T-264/T-265 build the sidechain story, T-266 settles the shared container model last.

Refs: D-78 (interaction zone / display-only conversation widgets). Built on T-168 (per-tool body rendering) and T-230 (activity card).', 'Home for the cohesive set of work that streamlines how the Claude conversation log renders, so a heavy agent turn reads clearly and nothing is mislabeled or duplicated. Three recurring moves bind these tickets: (1) FOLD a redundant standalone item into its owning card (success result → tool card; agent prompt → agent card); (2) fix MISLEADING ATTRIBUTION (sub-agent prompt shown as "you"; sub-agent prose shown as "claude"); (3) settle the CONTAINER / interaction model (holder card that contains sub-cards, nested agent run, autoscroll-vs-reach-the-control).

Common substrate across the children: the flat ConversationItem list and its renderers in lib/builtin/claude/src/conversation_view.dart, the pure grouping pass in activity_cluster.dart, the ConversationCard template in conversation_card.dart, and the so-far-unused ConversationItem.isSidechain / parentUuid transcript fields (transcript_reader.dart).

Children: T-262 (merge tool-call + success result into one card with header status check), T-263 (fold sub-agent prompt into the Agent card; relabel you → agent prompt), T-264 (nest the whole sub-agent run under its Agent card via parentUuid), T-265 (relabel sidechain assistant prose/thinking — agent, not claude), T-266 (restyle activity/holder card as a container of sub-cards + fix the collapse-control scroll race). Sequencing: T-262/T-263 first, T-264/T-265 build the sidechain story, T-266 settles the shared container model last.

Refs: D-78 (interaction zone / display-only conversation widgets). Built on T-168 (per-tool body rendering) and T-230 (activity card).

SEQUENCING UPDATE (after T-266 refinement): the shared container/holder primitive now lives in T-266 and is CONSUMED by T-264 (nested agent run), so T-266 is no longer "last" — its primitive lands before/with T-264. T-264 is now blocked by T-266. Revised order: T-262 / T-263 (fold success result, fold agent prompt) → T-266 (shared holder/container primitive + activity-card restyle) → T-264 (nest the whole agent run on that primitive) → T-265 (relabel sidechain prose) can land anytime alongside.', NULL, '2026-06-07 08:49:16', '2026-06-07 08:49:16', '2026-06-07 08:49:16', NULL, 'c298fbc83059f3d273cef241597df2b1', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM63WP564EZRERJHVCM', 'status', 'in_progress', 'done', NULL, '2026-06-07 08:51:08', '2026-06-07 08:51:08', '2026-06-07 08:51:08', NULL, '1c60d10586ea686fabb448e72e0a2d79', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM74JAV0MJMB4VQNTRG', 'status', 'backlog', 'done', NULL, '2026-06-07 09:36:59', '2026-06-07 09:36:59', '2026-06-07 09:36:59', NULL, '698f4b77d20b3c6d7a7df7741ec054d3', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM6P9YQ5V7WS6RFJNHW', 'status', 'backlog', 'done', NULL, '2026-06-07 09:51:32', '2026-06-07 09:51:32', '2026-06-07 09:51:32', NULL, '16c545fabac310e2c03c13575fd785f0', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM551VZ2NYV6PD0XQRC', 'status', 'backlog', 'ready', NULL, '2026-06-07 10:03:36', '2026-06-07 10:03:36', '2026-06-07 10:03:36', NULL, 'bac535db2b0406292ac10ba1c90d91af', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM40JE9MZZWCXC91THG', 'status', 'backlog', 'done', NULL, '2026-06-07 10:43:18', '2026-06-07 10:43:18', '2026-06-07 10:43:18', NULL, '5330cc7897890a6032fc222f792dc259', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM551VZ2NYV6PD0XQRC', 'description', 'Add a Zed-style application menu integrated into the hat bar: File, Edit, Selection, View, Help/About. Rendered as custom Flutter widgets (no native menu bar — we own the chrome per D-7). Menus expose the same commands registered in the command palette with their keybindings shown inline. Submenus for View should include panel toggles, zoom, focus mode. About opens a modal with version, license, and links.', 'Add a Zed-style application menu integrated into the hat bar: File, Edit, Selection, View, Help/About. Rendered as custom Flutter widgets (no native menu bar — we own the chrome per D-7). Menus expose the same commands registered in the command palette with their keybindings shown inline. Submenus for View should include panel toggles, zoom, focus mode. About opens a modal with version, license, and links.

## Refinement (decisions, 2026-06-07)

**v1 scope:** File, View, Help/About only. Edit and Selection are deferred to follow-ups [[T-271]] (Edit) and [[T-272]] (Selection) — both blocked on this story, since they need focused-surface command routing.
- View submenu: panel toggles, zoom, focus mode.
- Help: About modal (version, license, links).

**Command mapping (hybrid):** A hand-authored menu tree defines curated placement — ordering, grouping, separators, and which commands sit where. Any registered command not explicitly placed auto-fills from the command registry (by category) into the matching submenu / an overflow section, so newly registered commands surface without manual wiring. Each item''s title + keybinding are pulled from the registry.

**Context behavior:** Items reflect the focused surface; inapplicable items render disabled (greyed), not hidden. Mainly exercised once Edit/Selection land, but View/File items honor it too where relevant.

**Keyboard / a11y:** Full keyboard support — Alt+mnemonic opens a menu, arrow-key navigation within, Enter activates, Esc / click-away closes. Must meet the a11y contract (keyboard nav + semantics).', NULL, '2026-06-07 10:43:22', '2026-06-07 10:43:22', '2026-06-07 10:43:22', NULL, '5c601de01c18e6a2173c503d0e0fb4c4', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM551VZ2NYV6PD0XQRC', 'status', 'ready', 'done', NULL, '2026-06-07 15:40:06', '2026-06-07 15:40:06', '2026-06-07 15:40:06', NULL, 'a1ffa40ddf5216c02291ee63fb968969', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7ZGZ9GQ5W1MKV00Y4', 'status', 'backlog', 'ready', NULL, '2026-06-07 16:25:28', '2026-06-07 16:25:28', '2026-06-07 16:25:28', NULL, '0e2661a8a87c59ee3518bc5dc05bc934', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7ZGZ9GQ5W1MKV00Y4', 'status', 'ready', 'in_progress', NULL, '2026-06-07 17:22:06', '2026-06-07 17:22:06', '2026-06-07 17:22:06', NULL, 'f1faae99292a583bfc9024fd301f583b', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM71P14PAF7K4QE61G0', 'status', 'backlog', 'in_progress', NULL, '2026-06-07 17:23:39', '2026-06-07 17:23:39', '2026-06-07 17:23:39', NULL, '16d80211bbafa711b80b4cc2330ff3d2', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM71P14PAF7K4QE61G0', 'status', 'in_progress', 'done', NULL, '2026-06-07 17:41:11', '2026-06-07 17:41:11', '2026-06-07 17:41:11', NULL, 'b4cd35786f4d22bc1020dd0b02c2d372', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7XXSERDHKR0EEH3N4', 'status', 'backlog', 'in_progress', NULL, '2026-06-08 06:53:38', '2026-06-08 06:53:38', '2026-06-08 06:53:38', NULL, 'cff556a456f675bd41eb127ce02eb108', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5W6VN98RQM6S22X28', 'parent_id', NULL, 'T-276', NULL, '2026-06-08 07:46:46', '2026-06-08 07:46:46', '2026-06-08 07:46:46', NULL, '66e1bb30391f9c6224bd944301fb844d', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM55CV3VDYS88VBJZ60', 'parent_id', NULL, 'T-276', NULL, '2026-06-08 07:46:46', '2026-06-08 07:46:46', '2026-06-08 07:46:46', NULL, '7fc1b8a8ef580b47e634e6ee2b710ddd', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5AAA9WW54JGP83HGW', 'parent_id', NULL, 'T-276', NULL, '2026-06-08 07:46:46', '2026-06-08 07:46:46', '2026-06-08 07:46:46', NULL, 'be1e98024ab2f03928aec37d266040f1', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5TWC00GW0P3X02HZW', 'description', 'Ongoing umbrella for small, standalone UI polish, cosmetic tweaks, and visual/interaction bug fixes that don''t belong to a feature epic — color/token corrections, control placement, status surfaces, micro-interactions, and the wireframes that frame them. Children are independently shippable; the epic stays open as a rolling home for this class of work.', 'Ongoing umbrella for small, standalone UI polish, cosmetic tweaks, and visual/interaction bug fixes that don''t belong to a feature epic — color/token corrections, control placement, status surfaces, micro-interactions, and the wireframes that frame them. Children are independently shippable; the epic stays open as a rolling home for this class of work.

**PERMANENT — never close.** This is a standing rolling tracker for loose UI/UX work and bugs, not a deliverable epic. It stays open indefinitely; only its children are completed/closed. Do not mark T-276 done even when all current children are closed — new tweaks/fixes get filed here on an ongoing basis.', NULL, '2026-06-08 07:53:32', '2026-06-08 07:53:32', '2026-06-08 07:53:32', NULL, '6a31f771212b13b5e38a8d3df74dc8a1', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM60PAS5RJ55CZGPM1G', 'description', 'clide doesn''t surface pql ticket labels, so a rolling ''UI tweaks'' tracker has to be modeled as an epic (T-276) instead of a label — which is the cleaner primitive. Make labels first-class in the tickets UI so a label can BE the tracker.

Scope:
- Render a ticket''s labels on its card and detail view in the tickets panel (builtin/tickets) — small chips/pills, ui-design tokens, no hardcoded hex.
- A label navigator: filter/group the board by label (a sidepane affordance or a filter control on the tickets panel) so ''show me everything labelled ui-tweak'' is one click. Reuse the existing filter-box / MessageBus addressability (T-270) where it fits.
- Read labels via the pql wrapper only (D-3 — wrap, don''t duplicate); pql already supports  + labels on records.
- CLI/UI parity (D-6): label add/remove + filter should have a clide verb counterpart.

Once this lands, loose UI/UX work + bugs can move from the T-276 tracker-epic to a label (e.g. ''ui-tweak''); note that migration as a follow-up, don''t auto-close T-276 (it''s marked never-close).

Relevant: lib/builtin/tickets/, lib/src/pql/ (pql wrapper), pql / label fields.', 'clide doesn''t surface pql ticket labels, so a rolling ''UI tweaks'' tracker has to be modeled as an epic (T-276) instead of a label — which is the cleaner primitive. Make labels first-class in the tickets UI so a label can BE the tracker.

Scope:
- Render a ticket''s labels on its card and detail view in the tickets panel (lib/builtin/tickets) — small chips/pills, ui-design tokens, no hardcoded hex.
- A label navigator: filter/group the board by label (a sidepane affordance or a filter control on the tickets panel) so ''show me everything labelled ui-tweak'' is one click. Reuse the existing filter-box / MessageBus addressability (T-270) where it fits.
- Read/write labels via the pql wrapper only (D-3 — wrap, don''t duplicate); pql already supports the ''ticket label'' verb and exposes labels on records.
- CLI/UI parity (D-6): label add/remove + filter should each have a clide verb counterpart.

Once this lands, loose UI/UX work + bugs can move from the T-276 tracker-epic to a label (e.g. ''ui-tweak''); file that migration as a follow-up — do NOT auto-close T-276 (it''s marked never-close).

Relevant: lib/builtin/tickets/, lib/src/pql/ (pql wrapper), and pql''s ''ticket label'' / ''ticket list'' label fields.', NULL, '2026-06-08 08:34:24', '2026-06-08 08:34:24', '2026-06-08 08:34:24', NULL, '6dec8b27eed6dc7ed86047c39a363912', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM60PAS5RJ55CZGPM1G', 'parent_id', NULL, 'T-276', NULL, '2026-06-08 08:34:47', '2026-06-08 08:34:47', '2026-06-08 08:34:47', NULL, '3d746f1dbcc965d98a7d04b7398c90c5', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7XXSERDHKR0EEH3N4', 'status', 'in_progress', 'done', NULL, '2026-06-08 08:45:23', '2026-06-08 08:45:23', '2026-06-08 08:45:23', NULL, '9a57241efcf29530ce0fb548b73b476c', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM45HHRBCRMV2166Y6M', 'status', 'backlog', 'in_progress', NULL, '2026-06-08 08:47:43', '2026-06-08 08:47:43', '2026-06-08 08:47:43', NULL, '6c4bf58a2d2ac4e46737b9e6cd5d5a9d', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM45HHRBCRMV2166Y6M', 'status', 'in_progress', 'done', NULL, '2026-06-08 09:04:12', '2026-06-08 09:04:12', '2026-06-08 09:04:12', NULL, 'd5dded000a54cf6db5418b3525f967db', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5YYMMKFD5Z8WG9F60', 'status', 'backlog', 'in_progress', NULL, '2026-06-08 09:07:02', '2026-06-08 09:07:02', '2026-06-08 09:07:02', NULL, 'e944f09acd2bd2b6d4ccb01b09e63f8b', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5YYMMKFD5Z8WG9F60', 'status', 'in_progress', 'done', NULL, '2026-06-08 09:25:50', '2026-06-08 09:25:50', '2026-06-08 09:25:50', NULL, 'ec67ba8741c18305514d9e81f40fbbfb', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4Q1Q97CHA0XNK2G4W', 'status', 'backlog', 'in_progress', NULL, '2026-06-08 09:27:49', '2026-06-08 09:27:49', '2026-06-08 09:27:49', NULL, 'd29fe012fff5678f99fe0917363fdfad', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4Q1Q97CHA0XNK2G4W', 'status', 'in_progress', 'done', NULL, '2026-06-08 10:09:14', '2026-06-08 10:09:14', '2026-06-08 10:09:14', NULL, '80ca7819edb9316a2f01c39249905376', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7ZGZ9GQ5W1MKV00Y4', 'status', 'in_progress', 'done', NULL, '2026-06-08 10:09:21', '2026-06-08 10:09:21', '2026-06-08 10:09:21', NULL, '751ea8ae1f3b8faef968556fb089d5c9', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM55CV3VDYS88VBJZ60', 'status', 'backlog', 'ready', NULL, '2026-06-08 10:26:11', '2026-06-08 10:26:11', '2026-06-08 10:26:11', NULL, '2be4726345e4db30d17f7285f08bd59d', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5YNEQM1WY25BV7TD8', 'description', NULL, 'Pre-existing (reproduces at base commit 3a78dfa, predates the T-267 conversation-rendering epic). The widget test `test/app_test.dart` › "Open Folder on a non-repo path surfaces the ''no git repo'' dialog" times out after 10 minutes; teardown is wedged on `_RawReceivePort._handleMessage`.

Bisected (each a 45s-timeout repro, all on this box):
- A bare `Process.run` inside `tester.runAsync` (no app, no extensions) hangs → `Process.run`-in-`runAsync` leaks its exit ReceivePort here.
- `pumpApp` + empty `runAsync`, and `pumpApp` + a 1.5s real delay → both PASS (boot + runAsync alone is fine).
- The full openFolder tap flow hangs even when project validation is stubbed to a synchronous, pure-Dart `.git` walk (no subprocess) AND `runAsync` is removed — so the wedge is not solely the git subprocess; something in the booted-app + extensions + open-folder command path holds a native port that teardown waits on forever.

Quarantined with `skip:` so the suite/gate stays green. Real fix: find the leaked native async resource (likely a Process/Isolate/FakeDaemonClient port reachable from the open-folder command or app boot under the test harness) and ensure it''s drained/cancelled before teardown — or drive the "no git repo" assertion without booting the resource. Then remove the skip.', NULL, '2026-06-08 11:29:33', '2026-06-08 11:29:33', '2026-06-08 11:29:33', NULL, '1f99f25c756004f2d368ef61b00c0da6', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM55CV3VDYS88VBJZ60', 'status', 'ready', 'done', NULL, '2026-06-08 11:44:27', '2026-06-08 11:44:27', '2026-06-08 11:44:27', NULL, '45834ee4b421914db5fe8d7bfa72568d', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM59DG2WADJ9A0JFD1W', 'status', 'backlog', 'ready', NULL, '2026-06-08 11:47:56', '2026-06-08 11:47:56', '2026-06-08 11:47:56', NULL, '6602a5dca91f8ef4e762f326032767fc', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM59DG2WADJ9A0JFD1W', 'status', 'ready', 'done', NULL, '2026-06-08 11:49:36', '2026-06-08 11:49:36', '2026-06-08 11:49:36', NULL, '08fa6a8e6fffcb665c51cbb7a8c93604', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM6K1QRC911JMQ9C960', 'description', 'Surfaced 2026-06-08 while chasing a --resume hang in the Claude pane (T-274 diagnostic line). The specific corrupted-transcript repro may turn out to be a one-off, but the code trace found two real latent gaps that make a resume hang unrecoverable regardless of root cause.

(a) No timeout / no fallback on the init-event wait.
On spawn the orchestrator listens for the session_id from claude''s init event (StreamJsonSession sessionIdResolved -> session_orchestrator.dart ~257) with NO timeout. If ''claude --resume <id>'' never emits an init event (hangs), the listener never fires: the pane shows ''resumed · <id>'' + running indicator forever, the process is never killed, and there is no fallback to a fresh --session-id spawn. Unrecoverable without killing the process / restarting clide.

(b) Resume is decided by file existence, not resumable content.
claude_pane.dart ~279: ''final resume = await File(transcriptFile).exists();'' — resume=true purely because the .jsonl exists. A metadata-only transcript (only system / permission-mode / attachment records; parseTranscriptChunk().items returns []) yields resume=true with zero seeded items. So clide passes --resume against a functionally empty session, the diagnostic logs ''fresh session (no history)'' (it keys off seeded count, not the resume flag — itself misleading), and if that resume hangs there is no fallback per (a).

Acceptance:
1. If a --resume spawn yields no init event within a short timeout (e.g. 10-30s), fall back to a fresh --session-id spawn (or surface a recoverable error with a retry affordance) — the pane must never spin forever with no recovery.
2. Don''t pass --resume for a transcript that has no resumable conversation items: validate parsed item count (not just file existence) before choosing --resume vs --session-id, and/or detect-and-repair a metadata-only transcript.
3. The T-274 diagnostic log reflects the actual spawn mode (resume vs fresh), not just seeded-item count.
4. Tests: (i) fake process that never emits init -> pane falls back / surfaces error within the timeout; (ii) metadata-only transcript -> spawn chooses fresh, not --resume.

Cross-refs: T-274 (resumed-session status bar empty), T-167/T-185 (resume/fork session id capture), D-77, claude_pane.dart:279/300-308, session_orchestrator.dart:240/257.', 'Surfaced 2026-06-08 while chasing a --resume hang in the Claude pane (T-274 diagnostic line). The specific corrupted-transcript repro may turn out to be a one-off, but the code trace found two real latent gaps that make a resume hang unrecoverable regardless of root cause.

(a) No timeout / no fallback on the init-event wait.
On spawn the orchestrator listens for the session_id from claude''s init event (StreamJsonSession sessionIdResolved -> session_orchestrator.dart ~257) with NO timeout. If ''claude --resume <id>'' never emits an init event (hangs), the listener never fires: the pane shows ''resumed · <id>'' + running indicator forever, the process is never killed, and there is no fallback to a fresh --session-id spawn. Unrecoverable without killing the process / restarting clide.

(b) Resume is decided by file existence, not resumable content.
claude_pane.dart ~279: ''final resume = await File(transcriptFile).exists();'' — resume=true purely because the .jsonl exists. A metadata-only transcript (only system / permission-mode / attachment records; parseTranscriptChunk().items returns []) yields resume=true with zero seeded items. So clide passes --resume against a functionally empty session, the diagnostic logs ''fresh session (no history)'' (it keys off seeded count, not the resume flag — itself misleading), and if that resume hangs there is no fallback per (a).

Acceptance:
1. If a --resume spawn yields no init event within a short timeout (e.g. 10-30s), fall back to a fresh --session-id spawn (or surface a recoverable error with a retry affordance) — the pane must never spin forever with no recovery.
2. Don''t pass --resume for a transcript that has no resumable conversation items: validate parsed item count (not just file existence) before choosing --resume vs --session-id, and/or detect-and-repair a metadata-only transcript.
3. The T-274 diagnostic log reflects the actual spawn mode (resume vs fresh), not just seeded-item count.
4. Tests: (i) fake process that never emits init -> pane falls back / surfaces error within the timeout; (ii) metadata-only transcript -> spawn chooses fresh, not --resume.

Cross-refs: T-274 (resumed-session status bar empty), T-167/T-185 (resume/fork session id capture), D-77, claude_pane.dart:279/300-308, session_orchestrator.dart:240/257.

UPDATE 2026-06-08: the active hang did NOT reproduce — clide is running fine inside the 31b214bd primary session (this very session resumes cleanly). So the original break was a one-off (likely the single corrupted transcript), not a live resume bug. This ticket stands as defensive hardening only: the two gaps (no init-event timeout/fallback; resume keyed off file-exists not content) are real but latent — they''d only bite again if a resume genuinely stalls or a metadata-only transcript appears. Lowering to low priority.', NULL, '2026-06-08 13:44:57', '2026-06-08 13:44:57', '2026-06-08 13:44:57', NULL, '53d61af5561611d655fcee6eeb0ce208', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7W2MWZ45YNK7TJGC4', 'status', 'backlog', 'ready', NULL, '2026-06-08 13:48:31', '2026-06-08 13:48:31', '2026-06-08 13:48:31', NULL, '2bf8f6c9f94877217f737d3354d4dbff', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM6A6A56VFSVRRBKMP0', 'status', 'backlog', 'ready', NULL, '2026-06-08 13:48:42', '2026-06-08 13:48:42', '2026-06-08 13:48:42', NULL, 'c297bea78881a8738f24fb3313453294', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM6A6A56VFSVRRBKMP0', 'status', 'ready', 'in_progress', NULL, '2026-06-08 13:49:32', '2026-06-08 13:49:32', '2026-06-08 13:49:32', NULL, '0d0c6f8d18e9d59100387427018c5f49', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7W2MWZ45YNK7TJGC4', 'status', 'ready', 'in_progress', NULL, '2026-06-08 13:49:32', '2026-06-08 13:49:32', '2026-06-08 13:49:32', NULL, '440309f1ae2191f822fbcb79bd6dc9b2', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5AAA9WW54JGP83HGW', 'status', 'backlog', 'ready', NULL, '2026-06-08 14:12:26', '2026-06-08 14:12:26', '2026-06-08 14:12:26', NULL, '137d4e3cae7c30bc903e4eb059712c77', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM6A6A56VFSVRRBKMP0', 'status', 'in_progress', 'done', NULL, '2026-06-08 14:12:46', '2026-06-08 14:12:46', '2026-06-08 14:12:46', NULL, '7880cf5180b7600fc4ca7673ceb6865d', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4KFHAS1WZFGBJ6JN4', 'status', 'backlog', 'in_progress', NULL, '2026-06-08 14:55:51', '2026-06-08 14:55:51', '2026-06-08 14:55:51', NULL, '367a474aebf7e34a1cb5f2fad404113a', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4KFHAS1WZFGBJ6JN4', 'status', 'in_progress', 'done', NULL, '2026-06-08 14:57:15', '2026-06-08 14:57:15', '2026-06-08 14:57:15', NULL, '8a3454fab8ee7165408de4d35ea45880', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM6GZ55VD4SAZZ6XXP4', 'status', 'backlog', 'in_progress', NULL, '2026-06-08 15:22:35', '2026-06-08 15:22:35', '2026-06-08 15:22:35', NULL, '648f507b573971c2ce0dffab325f219b', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM6GZ55VD4SAZZ6XXP4', 'status', 'in_progress', 'done', NULL, '2026-06-08 15:37:29', '2026-06-08 15:37:29', '2026-06-08 15:37:29', NULL, '9d9a58f785a610aa8bd4ce1850328f04', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7W2MWZ45YNK7TJGC4', 'status', 'in_progress', 'done', NULL, '2026-06-08 15:42:01', '2026-06-08 15:42:01', '2026-06-08 15:42:01', NULL, '39d714d44f8a897420d248a9b245c868', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5AAA9WW54JGP83HGW', 'status', 'ready', 'in_progress', NULL, '2026-06-08 15:45:13', '2026-06-08 15:45:13', '2026-06-08 15:45:13', NULL, '6e6b49a52ee640d74a171dcc8524bdcd', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5AAA9WW54JGP83HGW', 'parent_id', 'T-276', 'T-286', NULL, '2026-06-08 16:30:47', '2026-06-08 16:30:47', '2026-06-08 16:30:47', NULL, '6750d8892dd9b437fb7cafbed811fa90', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5AAA9WW54JGP83HGW', 'status', 'in_progress', 'done', NULL, '2026-06-08 16:52:13', '2026-06-08 16:52:13', '2026-06-08 16:52:13', NULL, '2e092a257808514fe2b6e43888748024', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5R93N5J6RNVTBRB28', 'status', 'backlog', 'ready', NULL, '2026-06-08 17:34:29', '2026-06-08 17:34:29', '2026-06-08 17:34:29', NULL, '55ba9ff47275418cf9238495c02d1dd0', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5R93N5J6RNVTBRB28', 'status', 'ready', 'in_progress', NULL, '2026-06-08 17:34:31', '2026-06-08 17:34:31', '2026-06-08 17:34:31', NULL, 'b568ce91cc9623a1ffc58c1874a36109', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5E41Q8TX8X55X4MZ0', 'status', 'backlog', 'ready', NULL, '2026-06-08 17:37:13', '2026-06-08 17:37:13', '2026-06-08 17:37:13', NULL, 'f561a5bc9500193fbf0f74b89b4aa95f', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4501EBPDFDH84RJ5G', 'description', 'Follow-up to the D-88 sweep. The primitive (ClideAnchoredOverlay + ClideMenu) shipped and the menu bar (T-286) + T-275 picker are migrated. The theme-picker migration was attempted and REVERTED after hitting two real blockers that affect all the remaining anchored surfaces; resolve these first, then migrate theme picker, @-mention typeahead, slash typeahead, and quick-open.

Blockers found (theme picker attempt):
1. Focus-capture race. ClideAnchoredOverlay.captureFocus does a post-frame _scope.requestFocus(); ClideMenu also autofocuses its own node. Depending on mount timing (e.g. an extra ListenableBuilder wrapper) the scope wins and STEALS focus from ClideMenu''s node, so arrow/enter never reach the menu (Esc still works only via the ancestor fallback). Menu bar happens to win the race; the theme popover loses. Fix the primitive''s focus model so content''s own focus node reliably ends up focused (e.g. don''t force scope focus; or make the scope delegate to the autofocus child deterministically), then re-verify menu bar + anchored tests.
2. Follower content is not reliably mouse-tappable in the widget-test harness. The shared harness() uses Overlay(canSizeOverlay) + a zero-size MediaQuery, so an anchored follower positions the panel off-screen (observed tap offsets like (680,-45) and (680,654)) and tester.tap misses. Also autoFlip reads MediaQuery.size (zero in harness) so it can''t flip. Mitigations: have autoFlip use View.physicalSize (more correct anyway); position content without the inner Align (the panel shrink-wraps); and in tests drive selection via keyboard (as menu_bar does) or provide a real viewport. Consider a test helper for anchored-overlay content.

Then migrate, one surface per commit, keeping each existing test green (theme_picker widget_test, team_chat_sidebar_test, claude_composer_test, quick_open_overlay_test). Quick-open is centered (no follower) and the weakest-fit — it only needs the lifecycle wrapper; migrate last or skip.

Refs: D-88, T-286, T-275 (done), menu bar (done, commit e1d51eb).', 'Follow-up to the D-88 sweep. The primitive (ClideAnchoredOverlay + ClideMenu) shipped and the menu bar (T-286) + T-275 picker are migrated. The theme-picker migration was attempted and REVERTED after hitting two real blockers that affect all the remaining anchored surfaces; resolve these first, then migrate theme picker, @-mention typeahead, slash typeahead, and quick-open.

Blockers found (theme picker attempt):
1. Focus-capture race. ClideAnchoredOverlay.captureFocus does a post-frame _scope.requestFocus(); ClideMenu also autofocuses its own node. Depending on mount timing (e.g. an extra ListenableBuilder wrapper) the scope wins and STEALS focus from ClideMenu''s node, so arrow/enter never reach the menu (Esc still works only via the ancestor fallback). Menu bar happens to win the race; the theme popover loses. Fix the primitive''s focus model so content''s own focus node reliably ends up focused (e.g. don''t force scope focus; or make the scope delegate to the autofocus child deterministically), then re-verify menu bar + anchored tests.
2. Follower content is not reliably mouse-tappable in the widget-test harness. The shared harness() uses Overlay(canSizeOverlay) + a zero-size MediaQuery, so an anchored follower positions the panel off-screen (observed tap offsets like (680,-45) and (680,654)) and tester.tap misses. Also autoFlip reads MediaQuery.size (zero in harness) so it can''t flip. Mitigations: have autoFlip use View.physicalSize (more correct anyway); position content without the inner Align (the panel shrink-wraps); and in tests drive selection via keyboard (as menu_bar does) or provide a real viewport. Consider a test helper for anchored-overlay content.

Then migrate, one surface per commit, keeping each existing test green (theme_picker widget_test, team_chat_sidebar_test, claude_composer_test, quick_open_overlay_test). Quick-open is centered (no follower) and the weakest-fit — it only needs the lifecycle wrapper; migrate last or skip.

Refs: D-88, T-286, T-275 (done), menu bar (done, commit e1d51eb).

RE-SCOPE (2026-06-08, per D-88 amendment): the goal is NOT ''migrate everything onto ClideMenu''. The shared base is ClideAnchoredOverlay; content matches the surface:
- ClideMenu stays scoped to selectable-list menus (menu bar + permission picker — done).
- Add a NEW shared content component ClideTypeahead for the slash + @ typeaheads (near-duplicate caret-anchored completion surfaces) — they share this, not ClideMenu. This dedups two hand-rolls.
- Quick-open keeps bespoke content (centred filter + fuzzy + two-column rows); uses ClideAnchoredOverlay base only. Weakest fit; last or skip.
- Theme picker: its own small toggle+list content on the base (or ClideMenu if it cleanly fits).
Order: (1) fix the base blockers — focus capture racing content autofocus, and follower content untappable in the canSizeOverlay/zero-MediaQuery test harness (use View size for autoFlip; add a test path for anchored content) — with tests; THEN (2) ClideTypeahead + migrate slash + @; (3) theme picker; (4) quick-open last.', NULL, '2026-06-08 20:12:31', '2026-06-08 20:12:31', '2026-06-08 20:12:31', NULL, 'cd71f1fce9071ab191adc7f2c573fb21', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4501EBPDFDH84RJ5G', 'description', 'Follow-up to the D-88 sweep. The primitive (ClideAnchoredOverlay + ClideMenu) shipped and the menu bar (T-286) + T-275 picker are migrated. The theme-picker migration was attempted and REVERTED after hitting two real blockers that affect all the remaining anchored surfaces; resolve these first, then migrate theme picker, @-mention typeahead, slash typeahead, and quick-open.

Blockers found (theme picker attempt):
1. Focus-capture race. ClideAnchoredOverlay.captureFocus does a post-frame _scope.requestFocus(); ClideMenu also autofocuses its own node. Depending on mount timing (e.g. an extra ListenableBuilder wrapper) the scope wins and STEALS focus from ClideMenu''s node, so arrow/enter never reach the menu (Esc still works only via the ancestor fallback). Menu bar happens to win the race; the theme popover loses. Fix the primitive''s focus model so content''s own focus node reliably ends up focused (e.g. don''t force scope focus; or make the scope delegate to the autofocus child deterministically), then re-verify menu bar + anchored tests.
2. Follower content is not reliably mouse-tappable in the widget-test harness. The shared harness() uses Overlay(canSizeOverlay) + a zero-size MediaQuery, so an anchored follower positions the panel off-screen (observed tap offsets like (680,-45) and (680,654)) and tester.tap misses. Also autoFlip reads MediaQuery.size (zero in harness) so it can''t flip. Mitigations: have autoFlip use View.physicalSize (more correct anyway); position content without the inner Align (the panel shrink-wraps); and in tests drive selection via keyboard (as menu_bar does) or provide a real viewport. Consider a test helper for anchored-overlay content.

Then migrate, one surface per commit, keeping each existing test green (theme_picker widget_test, team_chat_sidebar_test, claude_composer_test, quick_open_overlay_test). Quick-open is centered (no follower) and the weakest-fit — it only needs the lifecycle wrapper; migrate last or skip.

Refs: D-88, T-286, T-275 (done), menu bar (done, commit e1d51eb).

RE-SCOPE (2026-06-08, per D-88 amendment): the goal is NOT ''migrate everything onto ClideMenu''. The shared base is ClideAnchoredOverlay; content matches the surface:
- ClideMenu stays scoped to selectable-list menus (menu bar + permission picker — done).
- Add a NEW shared content component ClideTypeahead for the slash + @ typeaheads (near-duplicate caret-anchored completion surfaces) — they share this, not ClideMenu. This dedups two hand-rolls.
- Quick-open keeps bespoke content (centred filter + fuzzy + two-column rows); uses ClideAnchoredOverlay base only. Weakest fit; last or skip.
- Theme picker: its own small toggle+list content on the base (or ClideMenu if it cleanly fits).
Order: (1) fix the base blockers — focus capture racing content autofocus, and follower content untappable in the canSizeOverlay/zero-MediaQuery test harness (use View size for autoFlip; add a test path for anchored content) — with tests; THEN (2) ClideTypeahead + migrate slash + @; (3) theme picker; (4) quick-open last.', 'Follow-up to the D-88 sweep. The primitive (ClideAnchoredOverlay + ClideMenu) shipped and the menu bar (T-286) + T-275 picker are migrated. The theme-picker migration was attempted and REVERTED after hitting two real blockers that affect all the remaining anchored surfaces; resolve these first, then migrate theme picker, @-mention typeahead, slash typeahead, and quick-open.

Blockers found (theme picker attempt):
1. Focus-capture race. ClideAnchoredOverlay.captureFocus does a post-frame _scope.requestFocus(); ClideMenu also autofocuses its own node. Depending on mount timing (e.g. an extra ListenableBuilder wrapper) the scope wins and STEALS focus from ClideMenu''s node, so arrow/enter never reach the menu (Esc still works only via the ancestor fallback). Menu bar happens to win the race; the theme popover loses. Fix the primitive''s focus model so content''s own focus node reliably ends up focused (e.g. don''t force scope focus; or make the scope delegate to the autofocus child deterministically), then re-verify menu bar + anchored tests.
2. Follower content is not reliably mouse-tappable in the widget-test harness. The shared harness() uses Overlay(canSizeOverlay) + a zero-size MediaQuery, so an anchored follower positions the panel off-screen (observed tap offsets like (680,-45) and (680,654)) and tester.tap misses. Also autoFlip reads MediaQuery.size (zero in harness) so it can''t flip. Mitigations: have autoFlip use View.physicalSize (more correct anyway); position content without the inner Align (the panel shrink-wraps); and in tests drive selection via keyboard (as menu_bar does) or provide a real viewport. Consider a test helper for anchored-overlay content.

Then migrate, one surface per commit, keeping each existing test green (theme_picker widget_test, team_chat_sidebar_test, claude_composer_test, quick_open_overlay_test). Quick-open is centered (no follower) and the weakest-fit — it only needs the lifecycle wrapper; migrate last or skip.

Refs: D-88, T-286, T-275 (done), menu bar (done, commit e1d51eb).

RE-SCOPE (2026-06-08, per D-88 amendment): the goal is NOT ''migrate everything onto ClideMenu''. The shared base is ClideAnchoredOverlay; content matches the surface:
- ClideMenu stays scoped to selectable-list menus (menu bar + permission picker — done).
- Add a NEW shared content component ClideTypeahead for the slash + @ typeaheads (near-duplicate caret-anchored completion surfaces) — they share this, not ClideMenu. This dedups two hand-rolls.
- Quick-open keeps bespoke content (centred filter + fuzzy + two-column rows); uses ClideAnchoredOverlay base only. Weakest fit; last or skip.
- Theme picker: its own small toggle+list content on the base (or ClideMenu if it cleanly fits).
Order: (1) fix the base blockers — focus capture racing content autofocus, and follower content untappable in the canSizeOverlay/zero-MediaQuery test harness (use View size for autoFlip; add a test path for anchored content) — with tests; THEN (2) ClideTypeahead + migrate slash + @; (3) theme picker; (4) quick-open last.

DONE: Sweep complete. Base blockers fixed (View-size autoFlip; follower drops Align so it hit-tests; tests use anchoredHarness). Migrated: ClideTypeahead + slash + @-mention typeaheads (live ValueNotifier-bridged suggestions); theme picker onto ClideMenu (HC toggle = keepOpenOnSelect item). Quick-open deliberately NOT migrated — persistent centred widget sharing neither ClideMenu nor anchoring; rationale in D-88 closing amendment.', NULL, '2026-06-09 06:18:55', '2026-06-09 06:18:55', '2026-06-09 06:18:55', NULL, '820fe7f1d764b7707f531d4216578b3a', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4501EBPDFDH84RJ5G', 'status', 'backlog', 'done', NULL, '2026-06-09 06:19:01', '2026-06-09 06:19:01', '2026-06-09 06:19:01', NULL, 'b9a0ef09f741bddcb1cfb52c17645f56', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5R93N5J6RNVTBRB28', 'description', 'Extract a clide-owned anchored-popover + menu widget primitive (lib/widgets/, no Material) and migrate every anchored surface onto it. Nine surfaces hand-roll the same anchored-overlay + row-list + barrier + keyboard-nav pattern. Two layers: ClideAnchoredOverlay (positioning/lifecycle: LayerLink/follower or centered, barrier, Esc, focus capture, autoFlip) + ClideMenu / ClideMenuListController (rows + reusable nav). Modal DialogRouter pickers (session/project/branch) stay modal. Built on T-275''s permission-mode picker first, then migrate menu bar, theme picker, @-mention, slash typeahead, quick-open. See decision (architecture domain) + plan. Children: primitive, T-275 picker, one per migration.', 'Extract a clide-owned anchored-popover + menu widget primitive (lib/widgets/, no Material) and migrate every anchored surface onto it. Nine surfaces hand-roll the same anchored-overlay + row-list + barrier + keyboard-nav pattern. Two layers: ClideAnchoredOverlay (positioning/lifecycle: LayerLink/follower or centered, barrier, Esc, focus capture, autoFlip) + ClideMenu / ClideMenuListController (rows + reusable nav). Modal DialogRouter pickers (session/project/branch) stay modal. Built on T-275''s permission-mode picker first, then migrate menu bar, theme picker, @-mention, slash typeahead, quick-open. See decision (architecture domain) + plan. Children: primitive, T-275 picker, one per migration.

DONE: Primitive (ClideAnchoredOverlay + ClideMenu + ClideMenuListController + ClideTypeahead) shipped and exported. Migrated: T-275 permission picker, menu bar, theme picker (ClideMenu), @-mention + slash typeaheads (ClideTypeahead). Quick-open intentionally left bespoke (centred persistent widget, no shared shape) — see D-88 closing amendment. Modal session/project/branch pickers stay on DialogRouter by design.', NULL, '2026-06-09 06:19:33', '2026-06-09 06:19:33', '2026-06-09 06:19:33', NULL, 'c919a01c49bf8be33ba2e1cf5c3a7111', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5R93N5J6RNVTBRB28', 'status', 'in_progress', 'done', NULL, '2026-06-09 06:19:36', '2026-06-09 06:19:36', '2026-06-09 06:19:36', NULL, '7f0dc7f8b224b31b585d5d2a49f88df6', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM50BPNDT50PM24ZVA4', 'status', 'backlog', 'ready', NULL, '2026-06-09 06:33:31', '2026-06-09 06:33:31', '2026-06-09 06:33:31', NULL, 'a9788029757cd116218c5a4f1f47c927', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5E41Q8TX8X55X4MZ0', 'status', 'ready', 'in_progress', NULL, '2026-06-09 06:34:31', '2026-06-09 06:34:31', '2026-06-09 06:34:31', NULL, 'd179dce4eb30e804056b7a49596134c2', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5E41Q8TX8X55X4MZ0', 'description', 'When a file is opened in the editor, read .editorconfig from the workspace root and apply: indent_style, indent_size, max_line_length (ruler/wrap guide), end_of_line, trim_trailing_whitespace, insert_final_newline. Parse the INI format ourselves (small, no dep). Glob matching per the EditorConfig spec.', 'When a file is opened in the editor, read .editorconfig from the workspace root and apply: indent_style, indent_size, max_line_length (ruler/wrap guide), end_of_line, trim_trailing_whitespace, insert_final_newline. Parse the INI format ourselves (small, no dep). Glob matching per the EditorConfig spec.

DONE: The editor honours .editorconfig end-to-end. New source-agnostic EditorSettings model (editor_settings.dart) + composition seam (editor_settings_resolver.dart); .editorconfig demoted to a source (editorconfig.dart, own INI parser + glob matcher, root/nearest-wins precedence, no deps). Registry resolves on open and re-resolves open buffers when a .editorconfig is saved in-app (editor.settings-changed; a save hook, not an fs-watch). Editor: Tab/Shift+Tab indent + max_line_length ruler; save applies end_of_line/trim_trailing_whitespace/insert_final_newline. Follow-ups: T-290 (edit from settings panel), T-291 (external fs-watch). 100% coverage on new model/resolver/parser.', NULL, '2026-06-09 10:46:41', '2026-06-09 10:46:41', '2026-06-09 10:46:41', NULL, '88ea41d16ef29fe640e57f05dca084c2', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5E41Q8TX8X55X4MZ0', 'status', 'in_progress', 'done', NULL, '2026-06-09 10:46:41', '2026-06-09 10:46:41', '2026-06-09 10:46:41', NULL, '96346570173938ba2b7112497db1210e', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM50BPNDT50PM24ZVA4', 'status', 'ready', 'in_progress', NULL, '2026-06-09 14:59:45', '2026-06-09 14:59:45', '2026-06-09 14:59:45', NULL, 'af89fd8ae447a5052eaeb7b9375590cf', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM50BPNDT50PM24ZVA4', 'status', 'in_progress', 'done', NULL, '2026-06-09 15:03:23', '2026-06-09 15:03:23', '2026-06-09 15:03:23', NULL, '60faf709c9ae2ac315fb9a5331fdcca7', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM50BPNDT50PM24ZVA4', 'description', 'Two issues in the Claude composer slash-command typeahead (T-152/T-153, lib/builtin/claude/src/slash_commands.dart + claude_composer.dart):

1. Typing a ''-'' character breaks the typeahead. Many command names contain hyphens (e.g. clear-context-style names, custom commands), but typing ''-'' appears to drop/empty the suggestion list or mis-parse the active query. Suspect activeSlashQuery''s token run or filterSlashCommands prefix matching not handling ''-'' (or the composer treating ''-'' as a boundary).

2. Tab to accept the highlighted suggestion responds flakily — sometimes it completes, sometimes nothing happens. Suspect a focus/key-handling race between the composer''s key handler and the typeahead overlay, or Tab being consumed by focus traversal before the accept intent fires.

Repro: open the composer, type ''/'' then a command fragment; (a) include a ''-'' and watch the list; (b) arrow-select an item and press Tab repeatedly.

Acceptance: ''-'' is treated as a normal command-name character (suggestions keep filtering through hyphens); Tab reliably completes the highlighted suggestion every time (insert via completeSlash). Add/extend unit tests in slash_commands_test.dart for hyphenated queries and a composer widget test for Tab-accept.', 'Two issues in the Claude composer slash-command typeahead (T-152/T-153, lib/builtin/claude/src/slash_commands.dart + claude_composer.dart):

1. Typing a ''-'' character breaks the typeahead. Many command names contain hyphens (e.g. clear-context-style names, custom commands), but typing ''-'' appears to drop/empty the suggestion list or mis-parse the active query. Suspect activeSlashQuery''s token run or filterSlashCommands prefix matching not handling ''-'' (or the composer treating ''-'' as a boundary).

2. Tab to accept the highlighted suggestion responds flakily — sometimes it completes, sometimes nothing happens. Suspect a focus/key-handling race between the composer''s key handler and the typeahead overlay, or Tab being consumed by focus traversal before the accept intent fires.

Repro: open the composer, type ''/'' then a command fragment; (a) include a ''-'' and watch the list; (b) arrow-select an item and press Tab repeatedly.

Acceptance: ''-'' is treated as a normal command-name character (suggestions keep filtering through hyphens); Tab reliably completes the highlighted suggestion every time (insert via completeSlash). Add/extend unit tests in slash_commands_test.dart for hyphenated queries and a composer widget test for Tab-accept.

RESOLVED by the D-88 ClideTypeahead migration (T-286), verified 2026-06-09. Root cause of both symptoms was the OLD hand-rolled overlay, not the pure helpers (activeSlashQuery/filterSlashCommands always handled ''-''): (1) the old overlay didn''t narrow live as you typed, so a ''-'' looked like it emptied/broke the list; (2) the old focus model raced Tab. Post-migration the popover narrows live (ValueNotifier) and the field keeps focus (captureFocus:false), so ''-'' filters normally and Tab reliably completes. Confirmed bare ''-'' is NOT a keybinding (zoom is ctrl/meta+minus). Added regression tests: hyphen cases in slash_commands_test; composer widget test typing through a hyphen + Tab-accept. Commit d8b9a41.', NULL, '2026-06-09 15:03:23', '2026-06-09 15:03:23', '2026-06-09 15:03:23', NULL, 'bce323a83d11cce9aa109b64b723a609', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4BD8PXDRHBF001200', 'status', 'backlog', 'in_progress', NULL, '2026-06-09 15:03:37', '2026-06-09 15:03:37', '2026-06-09 15:03:37', NULL, '6e3a604a8718416923865ef53bec19bc', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4BD8PXDRHBF001200', 'status', 'in_progress', 'done', NULL, '2026-06-09 15:09:05', '2026-06-09 15:09:05', '2026-06-09 15:09:05', NULL, '38a4f5c2f60bd3bcfabb99869c0deba0', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4BD8PXDRHBF001200', 'description', 'test/pty/session_test.dart:47 ''write sends keystrokes to child'' (and its sibling pty integration tests) intermittently fail when run in a large parallel pool — observed twice during T-29: once in a bare ''flutter test --coverage'' (whole suite, max parallelism + coverage instrumentation) and once mid pre-push gate (''+570 -1''). Passes reliably in isolation and via the gate''s SERIAL test-core pass (''dart test test/pty'', +571 ok), so it is not a logic bug.

Root cause: these tests spawn a real /bin/sh via NativePty and wait on the reader ISOLATE to deliver bytes. Under heavy CPU contention the reader isolate is starved and the 20s ioTimeout (test/helpers/timeouts.dart) elapses before the shell''s first byte / echo response is delivered. Already hardened once (T-108 swapped wall-clock sleeps for event-driven waits; first-byte Completer + 25ms-poll _waitForBuffer), but the isolate-scheduling assumption still breaks under load.

These tests are tagged ''pty'' and are meant to run in the gate''s serial pass. Fix options: (a) ensure the parallel coverage pass EXCLUDES tag:pty (run pty only in the serial pass) so they never compete for isolate scheduling — verify ci/test.sh / dart_test.yaml tag routing; (b) harden against isolate starvation (e.g. give the reader isolate priority, or assert on delivery via a more robust signal); (c) document that ''flutter test --coverage'' over the whole tree is not a supported invocation (use make test + the gate). Prefer (a). Refs: T-108, T-96 (reader-isolate hangs), T-192 (gate parallel/serial passes), D-23 (test pyramid).', 'test/pty/session_test.dart:47 ''write sends keystrokes to child'' (and its sibling pty integration tests) intermittently fail when run in a large parallel pool — observed twice during T-29: once in a bare ''flutter test --coverage'' (whole suite, max parallelism + coverage instrumentation) and once mid pre-push gate (''+570 -1''). Passes reliably in isolation and via the gate''s SERIAL test-core pass (''dart test test/pty'', +571 ok), so it is not a logic bug.

Root cause: these tests spawn a real /bin/sh via NativePty and wait on the reader ISOLATE to deliver bytes. Under heavy CPU contention the reader isolate is starved and the 20s ioTimeout (test/helpers/timeouts.dart) elapses before the shell''s first byte / echo response is delivered. Already hardened once (T-108 swapped wall-clock sleeps for event-driven waits; first-byte Completer + 25ms-poll _waitForBuffer), but the isolate-scheduling assumption still breaks under load.

These tests are tagged ''pty'' and are meant to run in the gate''s serial pass. Fix options: (a) ensure the parallel coverage pass EXCLUDES tag:pty (run pty only in the serial pass) so they never compete for isolate scheduling — verify ci/test.sh / dart_test.yaml tag routing; (b) harden against isolate starvation (e.g. give the reader isolate priority, or assert on delivery via a more robust signal); (c) document that ''flutter test --coverage'' over the whole tree is not a supported invocation (use make test + the gate). Prefer (a). Refs: T-108, T-96 (reader-isolate hangs), T-192 (gate parallel/serial passes), D-23 (test pyramid).

FIXED 2026-06-09 (commit 0231cb4). Root cause: ci/test_core.sh ran ''dart test test/ipc test/pty ... test/pql'' in the DEFAULT parallel pool, so test/pty''s real-PTY tests contended for fds+CPU with the other core suites and the reader isolate was starved. (ci/test.sh already isolated pty via --concurrency=1 --tags pty; test_core.sh was the gap.) My manual ''flutter test --coverage'' repro was a separate wrong-invocation artifact — the flutter runner can''t reliably deliver the PTY master fd, which is why the gate excludes pty from the flutter pool entirely.) Fix: test_core.sh now runs a serial ''--concurrency=1 --tags pty'' pass + a parallel ''--exclude-tags pty'' pass, mirroring ci/test.sh. Verified: pty pass +5 stable across repeated runs; full core +571 unchanged. Option (a) from the ticket.', NULL, '2026-06-09 15:09:05', '2026-06-09 15:09:05', '2026-06-09 15:09:05', NULL, '9182c7efd54567ce5dc158eb0d01d137', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4GN07FN8GAXZ20YAR', 'status', 'backlog', 'ready', NULL, '2026-06-09 15:10:57', '2026-06-09 15:10:57', '2026-06-09 15:10:57', NULL, 'c7f6e34ce3fd1a90a22d758f573f2676', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM42WW0SY3XEXKE8PK8', 'status', 'backlog', 'ready', NULL, '2026-06-09 15:13:06', '2026-06-09 15:13:06', '2026-06-09 15:13:06', NULL, '0c5e9a67ba3131bef2e761a8db3cb753', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM61SRVBDRFFN2S80T4', 'status', 'backlog', 'ready', NULL, '2026-06-09 15:13:25', '2026-06-09 15:13:25', '2026-06-09 15:13:25', NULL, 'f4fbca5fcde6b9589ae5aad230b08a47', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM61SRVBDRFFN2S80T4', 'description', 'When the user pastes an image, the conversation panel echoes back the file path as plain text (e.g. @/home/.../paste-<ts>.png). We now have an image viewer card — render the pasted image inline using that card instead of (or in addition to) the bare path.

## Behaviour
- Detect a pasted-image path in the conversation stream and render the image viewer card.
- Still surface the file path (e.g. as a caption / subtitle on the card) so it can be copied/referenced.
- Reuse the existing image viewer card component rather than building a new one.

## Notes
- Applies to the Claude conversation panel rendering path.
- Consider failure cases: missing/deleted file, non-image paste, very large images.', 'When the user pastes an image, the conversation panel echoes back the file path as plain text (e.g. @/home/.../paste-<ts>.png). We now have an image viewer card — render the pasted image inline using that card instead of (or in addition to) the bare path.

## Behaviour
- Detect a pasted-image path in the conversation stream and render the image viewer card.
- Still surface the file path (e.g. as a caption / subtitle on the card) so it can be copied/referenced.
- Reuse the existing image viewer card component rather than building a new one.

## Notes
- Applies to the Claude conversation panel rendering path.
- Consider failure cases: missing/deleted file, non-image paste, very large images.

CANCELLED as a duplicate of T-236 (2026-06-09). T-236 is the concrete spec for rendering pasted @path images inline in the Claude conversation; its scope now includes T-254''s path-as-caption nuance. Implement under T-236.', NULL, '2026-06-09 15:14:46', '2026-06-09 15:14:46', '2026-06-09 15:14:46', NULL, '6faa9d5cb777b2aa1d0a996c8f542c26', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4GN07FN8GAXZ20YAR', 'description', 'When a user message contains a pasted-screenshot reference — an @<path> token pointing at an image (the composer''s ComposerAttachment.pathToken format, e.g. @/home/<user>/.cache/clide/pasted/paste-<ts>.png, see screenshot) — the conversation log renders it as the raw path string. Show it as an inline THUMBNAIL instead.

The composer already renders pre-send attachments as Image.file thumbnail chips (clipboard_paste.dart + claude_composer _chip); this carries that into the post-send message log (UserMessage rendering in conversation_view/conversation_card).

Scope:
- When rendering UserMessage text, detect @<path> tokens; for image paths (reuse the extension check behind _looksLikeImage: .png/.jpg/.jpeg/.gif/.webp/.bmp), render a bounded Image.file thumbnail in place of the bare token. Surrounding prose still renders normally; a message can carry multiple tokens.
- Click/activate the thumbnail to open the full-size image (a preview dialog). Keyboard-operable + a11y label (filename).
- Graceful fallback: a missing/unreadable file (pasted temp files can be cleaned up) degrades to a small placeholder or the path text via Image.file errorBuilder — never a crash/exception.
- Non-image @path tokens MAY render as a file chip (filename + icon) like the composer, but image thumbnails are the focus.
- Note: Image.file reads the path directly via dart:io, so this is NOT gated by the files.read allow-list (D-80) — the cache dir is outside the workspace and that''s fine for display.
- Display-only: the text actually sent to Claude is unchanged; this only affects rendering.

Acceptance:
1. A user message with an @<path> image token shows an inline thumbnail in the log (not the raw path).
2. Clicking/activating the thumbnail opens the full image.
3. A missing/unreadable referenced file degrades to a placeholder (or the path text), no exception.
4. Prose and any non-image @path tokens around it still render readably; multiple tokens in one message all resolve.
5. The message content delivered to Claude is unchanged (render-only). Relates to T-142 (paste attachments).', 'When a user message contains a pasted-screenshot reference — an @<path> token pointing at an image (the composer''s ComposerAttachment.pathToken format, e.g. @/home/<user>/.cache/clide/pasted/paste-<ts>.png, see screenshot) — the conversation log renders it as the raw path string. Show it as an inline THUMBNAIL instead.

The composer already renders pre-send attachments as Image.file thumbnail chips (clipboard_paste.dart + claude_composer _chip); this carries that into the post-send message log (UserMessage rendering in conversation_view/conversation_card).

Scope:
- When rendering UserMessage text, detect @<path> tokens; for image paths (reuse the extension check behind _looksLikeImage: .png/.jpg/.jpeg/.gif/.webp/.bmp), render a bounded Image.file thumbnail in place of the bare token. Surrounding prose still renders normally; a message can carry multiple tokens.
- Click/activate the thumbnail to open the full-size image (a preview dialog). Keyboard-operable + a11y label (filename).
- Graceful fallback: a missing/unreadable file (pasted temp files can be cleaned up) degrades to a small placeholder or the path text via Image.file errorBuilder — never a crash/exception.
- Non-image @path tokens MAY render as a file chip (filename + icon) like the composer, but image thumbnails are the focus.
- Note: Image.file reads the path directly via dart:io, so this is NOT gated by the files.read allow-list (D-80) — the cache dir is outside the workspace and that''s fine for display.
- Display-only: the text actually sent to Claude is unchanged; this only affects rendering.

Acceptance:
1. A user message with an @<path> image token shows an inline thumbnail in the log (not the raw path).
2. Clicking/activating the thumbnail opens the full image.
3. A missing/unreadable referenced file degrades to a placeholder (or the path text), no exception.
4. Prose and any non-image @path tokens around it still render readably; multiple tokens in one message all resolve.
5. The message content delivered to Claude is unchanged (render-only). Relates to T-142 (paste attachments).

MERGED T-254 (duplicate) into this ticket. Extra nuance carried over from T-254: keep the file path available (e.g. as a small caption/subtitle under the thumbnail, or via the lightbox) so it can still be copied/referenced. Reuse the existing inline image card + lightbox (T-252) rather than a new component.', NULL, '2026-06-09 15:14:46', '2026-06-09 15:14:46', '2026-06-09 15:14:46', NULL, '76b992a5d460e81ec313ae6154dea1f6', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM61SRVBDRFFN2S80T4', 'status', 'ready', 'cancelled', NULL, '2026-06-09 15:14:46', '2026-06-09 15:14:46', '2026-06-09 15:14:46', NULL, 'de7af22be9beaa7c28d65a5fdde3ca8e', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM61SRVBDRFFN2S80T4', 'status', 'cancelled', 'ready', NULL, '2026-06-09 15:15:18', '2026-06-09 15:15:18', '2026-06-09 15:15:18', NULL, '3478f18c0380519c915fa463bc12289f', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4GN07FN8GAXZ20YAR', 'description', 'When a user message contains a pasted-screenshot reference — an @<path> token pointing at an image (the composer''s ComposerAttachment.pathToken format, e.g. @/home/<user>/.cache/clide/pasted/paste-<ts>.png, see screenshot) — the conversation log renders it as the raw path string. Show it as an inline THUMBNAIL instead.

The composer already renders pre-send attachments as Image.file thumbnail chips (clipboard_paste.dart + claude_composer _chip); this carries that into the post-send message log (UserMessage rendering in conversation_view/conversation_card).

Scope:
- When rendering UserMessage text, detect @<path> tokens; for image paths (reuse the extension check behind _looksLikeImage: .png/.jpg/.jpeg/.gif/.webp/.bmp), render a bounded Image.file thumbnail in place of the bare token. Surrounding prose still renders normally; a message can carry multiple tokens.
- Click/activate the thumbnail to open the full-size image (a preview dialog). Keyboard-operable + a11y label (filename).
- Graceful fallback: a missing/unreadable file (pasted temp files can be cleaned up) degrades to a small placeholder or the path text via Image.file errorBuilder — never a crash/exception.
- Non-image @path tokens MAY render as a file chip (filename + icon) like the composer, but image thumbnails are the focus.
- Note: Image.file reads the path directly via dart:io, so this is NOT gated by the files.read allow-list (D-80) — the cache dir is outside the workspace and that''s fine for display.
- Display-only: the text actually sent to Claude is unchanged; this only affects rendering.

Acceptance:
1. A user message with an @<path> image token shows an inline thumbnail in the log (not the raw path).
2. Clicking/activating the thumbnail opens the full image.
3. A missing/unreadable referenced file degrades to a placeholder (or the path text), no exception.
4. Prose and any non-image @path tokens around it still render readably; multiple tokens in one message all resolve.
5. The message content delivered to Claude is unchanged (render-only). Relates to T-142 (paste attachments).

MERGED T-254 (duplicate) into this ticket. Extra nuance carried over from T-254: keep the file path available (e.g. as a small caption/subtitle under the thumbnail, or via the lightbox) so it can still be copied/referenced. Reuse the existing inline image card + lightbox (T-252) rather than a new component.', 'When a user message contains a pasted-screenshot reference — an @<path> token pointing at an image (the composer''s ComposerAttachment.pathToken format, e.g. @/home/<user>/.cache/clide/pasted/paste-<ts>.png, see screenshot) — the conversation log renders it as the raw path string. Show it as an inline THUMBNAIL instead.

The composer already renders pre-send attachments as Image.file thumbnail chips (clipboard_paste.dart + claude_composer _chip); this carries that into the post-send message log (UserMessage rendering in conversation_view/conversation_card).

Scope:
- When rendering UserMessage text, detect @<path> tokens; for image paths (reuse the extension check behind _looksLikeImage: .png/.jpg/.jpeg/.gif/.webp/.bmp), render a bounded Image.file thumbnail in place of the bare token. Surrounding prose still renders normally; a message can carry multiple tokens.
- Click/activate the thumbnail to open the full-size image (a preview dialog). Keyboard-operable + a11y label (filename).
- Graceful fallback: a missing/unreadable file (pasted temp files can be cleaned up) degrades to a small placeholder or the path text via Image.file errorBuilder — never a crash/exception.
- Non-image @path tokens MAY render as a file chip (filename + icon) like the composer, but image thumbnails are the focus.
- Note: Image.file reads the path directly via dart:io, so this is NOT gated by the files.read allow-list (D-80) — the cache dir is outside the workspace and that''s fine for display.
- Display-only: the text actually sent to Claude is unchanged; this only affects rendering.

Acceptance:
1. A user message with an @<path> image token shows an inline thumbnail in the log (not the raw path).
2. Clicking/activating the thumbnail opens the full image.
3. A missing/unreadable referenced file degrades to a placeholder (or the path text), no exception.
4. Prose and any non-image @path tokens around it still render readably; multiple tokens in one message all resolve.
5. The message content delivered to Claude is unchanged (render-only). Relates to T-142 (paste attachments).

MERGED T-254 (duplicate) into this ticket. Extra nuance carried over from T-254: keep the file path available (e.g. as a small caption/subtitle under the thumbnail, or via the lightbox) so it can still be copied/referenced. Reuse the existing inline image card + lightbox (T-252) rather than a new component.

RETRACTED the earlier ''merged T-254'' note — T-236 and T-254 are distinct tickets (per user); disregard that note. T-236 stays scoped to its own description.', NULL, '2026-06-09 15:15:18', '2026-06-09 15:15:18', '2026-06-09 15:15:18', NULL, '5047d91e71c748a7a9c2e1ad29c636c4', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM61SRVBDRFFN2S80T4', 'description', 'When the user pastes an image, the conversation panel echoes back the file path as plain text (e.g. @/home/.../paste-<ts>.png). We now have an image viewer card — render the pasted image inline using that card instead of (or in addition to) the bare path.

## Behaviour
- Detect a pasted-image path in the conversation stream and render the image viewer card.
- Still surface the file path (e.g. as a caption / subtitle on the card) so it can be copied/referenced.
- Reuse the existing image viewer card component rather than building a new one.

## Notes
- Applies to the Claude conversation panel rendering path.
- Consider failure cases: missing/deleted file, non-image paste, very large images.

CANCELLED as a duplicate of T-236 (2026-06-09). T-236 is the concrete spec for rendering pasted @path images inline in the Claude conversation; its scope now includes T-254''s path-as-caption nuance. Implement under T-236.', 'When the user pastes an image, the conversation panel echoes back the file path as plain text (e.g. @/home/.../paste-<ts>.png). We now have an image viewer card — render the pasted image inline using that card instead of (or in addition to) the bare path.

## Behaviour
- Detect a pasted-image path in the conversation stream and render the image viewer card.
- Still surface the file path (e.g. as a caption / subtitle on the card) so it can be copied/referenced.
- Reuse the existing image viewer card component rather than building a new one.

## Notes
- Applies to the Claude conversation panel rendering path.
- Consider failure cases: missing/deleted file, non-image paste, very large images.

CANCELLED as a duplicate of T-236 (2026-06-09). T-236 is the concrete spec for rendering pasted @path images inline in the Claude conversation; its scope now includes T-254''s path-as-caption nuance. Implement under T-236.

RETRACTED the cancellation — NOT a duplicate of T-236 (per user, 2026-06-09). Both stay open. T-254 remains its own ticket.', NULL, '2026-06-09 15:15:18', '2026-06-09 15:15:18', '2026-06-09 15:15:18', NULL, '51620d0b6f97ab50c29fc12ad0a9632d', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM72SHY93S36VM9G6D8', 'description', 'Design and add collapse/expand controls for the left sidebar and the right context pane, along the lines of the reference screenshot (green arrows mark the two intended affordance locations — bottom-left of the sidebar and bottom-right of the context pane).

Scope of this ticket: set up a Frame0 mock to talk through the design before implementing.

Open questions to resolve in the mock:
- Affordance placement: footer/status-bar anchored (as the screenshot arrows suggest) vs. pane-edge chevron.
- Collapsed state: fully hidden vs. thin rail with a re-expand handle.
- Iconography (chevron direction) and hover/active states.
- Whether sidebar and context pane share one control pattern (parity) or differ.
- Keyboard/CLI parity (D-6): each collapse action needs a clide verb.

Deliverable: Frame0 wireframe(s) of collapsed + expanded states for both panes, reviewed before any code.', 'Design and add collapse/expand controls for the left sidebar and the right context pane, along the lines of the reference screenshot (green arrows mark the two intended affordance locations — bottom-left of the sidebar and bottom-right of the context pane).

Scope of this ticket: set up a Frame0 mock to talk through the design before implementing.

Open questions to resolve in the mock:
- Affordance placement: footer/status-bar anchored (as the screenshot arrows suggest) vs. pane-edge chevron.
- Collapsed state: fully hidden vs. thin rail with a re-expand handle.
- Iconography (chevron direction) and hover/active states.
- Whether sidebar and context pane share one control pattern (parity) or differ.
- Keyboard/CLI parity (D-6): each collapse action needs a clide verb.

Deliverable: Frame0 wireframe(s) of collapsed + expanded states for both panes, reviewed before any code.

DESIGN DIRECTION (settled): anchor both toggles on the OUTER EDGES of the center (Claude conversation) pane — one on the left edge controlling the sidebar, one on the right edge controlling the context pane. The control stays fixed on the center-pane edge whether the adjacent pane is open or collapsed, so a single button both collapses an open pane and re-opens a collapsed one (chevron flips direction). This avoids needing a separate "re-expand" handle on the collapsed pane.

Implications for the mock:
- Collapsed pane can be fully hidden (no thin rail needed) since the re-open control lives on the center edge.
- Sidebar and context pane share one mirrored control pattern (parity).
- Chevron direction reflects state: points outward to expand, inward to collapse.', NULL, '2026-06-09 15:21:37', '2026-06-09 15:21:37', '2026-06-09 15:21:37', NULL, '674ce50eb5d3471f5c024942badb8c1a', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM72SHY93S36VM9G6D8', 'description', 'Design and add collapse/expand controls for the left sidebar and the right context pane, along the lines of the reference screenshot (green arrows mark the two intended affordance locations — bottom-left of the sidebar and bottom-right of the context pane).

Scope of this ticket: set up a Frame0 mock to talk through the design before implementing.

Open questions to resolve in the mock:
- Affordance placement: footer/status-bar anchored (as the screenshot arrows suggest) vs. pane-edge chevron.
- Collapsed state: fully hidden vs. thin rail with a re-expand handle.
- Iconography (chevron direction) and hover/active states.
- Whether sidebar and context pane share one control pattern (parity) or differ.
- Keyboard/CLI parity (D-6): each collapse action needs a clide verb.

Deliverable: Frame0 wireframe(s) of collapsed + expanded states for both panes, reviewed before any code.

DESIGN DIRECTION (settled): anchor both toggles on the OUTER EDGES of the center (Claude conversation) pane — one on the left edge controlling the sidebar, one on the right edge controlling the context pane. The control stays fixed on the center-pane edge whether the adjacent pane is open or collapsed, so a single button both collapses an open pane and re-opens a collapsed one (chevron flips direction). This avoids needing a separate "re-expand" handle on the collapsed pane.

Implications for the mock:
- Collapsed pane can be fully hidden (no thin rail needed) since the re-open control lives on the center edge.
- Sidebar and context pane share one mirrored control pattern (parity).
- Chevron direction reflects state: points outward to expand, inward to collapse.', 'Design and add collapse/expand controls for the left sidebar and the right context pane, along the lines of the reference screenshot (green arrows mark the two intended affordance locations — bottom-left of the sidebar and bottom-right of the context pane).

Scope of this ticket: set up a Frame0 mock to talk through the design before implementing.

Open questions to resolve in the mock:
- Affordance placement: footer/status-bar anchored (as the screenshot arrows suggest) vs. pane-edge chevron.
- Collapsed state: fully hidden vs. thin rail with a re-expand handle.
- Iconography (chevron direction) and hover/active states.
- Whether sidebar and context pane share one control pattern (parity) or differ.
- Keyboard/CLI parity (D-6): each collapse action needs a clide verb.

Deliverable: Frame0 wireframe(s) of collapsed + expanded states for both panes, reviewed before any code.

DESIGN DIRECTION (settled): anchor both toggles on the OUTER EDGES of the center (Claude conversation) pane — one on the left edge controlling the sidebar, one on the right edge controlling the context pane. The control stays fixed on the center-pane edge whether the adjacent pane is open or collapsed, so a single button both collapses an open pane and re-opens a collapsed one (chevron flips direction). This avoids needing a separate "re-expand" handle on the collapsed pane.

Implications for the mock:
- Collapsed pane can be fully hidden (no thin rail needed) since the re-open control lives on the center edge.
- Sidebar and context pane share one mirrored control pattern (parity).
- Chevron direction reflects state: points outward to expand, inward to collapse.

IMPLEMENTATION NOTE: the collapse logic already exists — no new toggle behaviour needed. Commands `sidebar.collapse` (ctrl+shift+1) and `context.collapse` (ctrl+shift+3) are registered in lib/builtin/default_layout/src/extension.dart, exposed in the command palette + menubar, and call arrangement.toggleCollapsed(Slots.sidebar|contextPanel), returning isCollapsed (D-051, D-054).

So this ticket is scoped to the VISUAL AFFORDANCE only:
- Add the two edge-anchored toggle buttons on the center (Claude) pane''s outer edges.
- On click, invoke the existing `sidebar.collapse` / `context.collapse` commands (do NOT reimplement collapse).
- Read arrangement.isCollapsed(...) to flip the chevron direction per state.
- D-6 CLI/keyboard parity is already satisfied by the existing commands; this adds the mouse affordance.

Mock: docs/design/wireframes/hud/pane-collapse-toggles.{json,png} — State A (open) + State B (collapsed).', NULL, '2026-06-09 15:24:00', '2026-06-09 15:24:00', '2026-06-09 15:24:00', NULL, 'bf8f7751e6379b8a3fc57cdab29566fc', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM72SHY93S36VM9G6D8', 'description', 'Design and add collapse/expand controls for the left sidebar and the right context pane, along the lines of the reference screenshot (green arrows mark the two intended affordance locations — bottom-left of the sidebar and bottom-right of the context pane).

Scope of this ticket: set up a Frame0 mock to talk through the design before implementing.

Open questions to resolve in the mock:
- Affordance placement: footer/status-bar anchored (as the screenshot arrows suggest) vs. pane-edge chevron.
- Collapsed state: fully hidden vs. thin rail with a re-expand handle.
- Iconography (chevron direction) and hover/active states.
- Whether sidebar and context pane share one control pattern (parity) or differ.
- Keyboard/CLI parity (D-6): each collapse action needs a clide verb.

Deliverable: Frame0 wireframe(s) of collapsed + expanded states for both panes, reviewed before any code.

DESIGN DIRECTION (settled): anchor both toggles on the OUTER EDGES of the center (Claude conversation) pane — one on the left edge controlling the sidebar, one on the right edge controlling the context pane. The control stays fixed on the center-pane edge whether the adjacent pane is open or collapsed, so a single button both collapses an open pane and re-opens a collapsed one (chevron flips direction). This avoids needing a separate "re-expand" handle on the collapsed pane.

Implications for the mock:
- Collapsed pane can be fully hidden (no thin rail needed) since the re-open control lives on the center edge.
- Sidebar and context pane share one mirrored control pattern (parity).
- Chevron direction reflects state: points outward to expand, inward to collapse.

IMPLEMENTATION NOTE: the collapse logic already exists — no new toggle behaviour needed. Commands `sidebar.collapse` (ctrl+shift+1) and `context.collapse` (ctrl+shift+3) are registered in lib/builtin/default_layout/src/extension.dart, exposed in the command palette + menubar, and call arrangement.toggleCollapsed(Slots.sidebar|contextPanel), returning isCollapsed (D-051, D-054).

So this ticket is scoped to the VISUAL AFFORDANCE only:
- Add the two edge-anchored toggle buttons on the center (Claude) pane''s outer edges.
- On click, invoke the existing `sidebar.collapse` / `context.collapse` commands (do NOT reimplement collapse).
- Read arrangement.isCollapsed(...) to flip the chevron direction per state.
- D-6 CLI/keyboard parity is already satisfied by the existing commands; this adds the mouse affordance.

Mock: docs/design/wireframes/hud/pane-collapse-toggles.{json,png} — State A (open) + State B (collapsed).', 'Design and add collapse/expand controls for the left sidebar and the right context pane, along the lines of the reference screenshot (green arrows mark the two intended affordance locations — bottom-left of the sidebar and bottom-right of the context pane).

Scope of this ticket: set up a Frame0 mock to talk through the design before implementing.

Open questions to resolve in the mock:
- Affordance placement: footer/status-bar anchored (as the screenshot arrows suggest) vs. pane-edge chevron.
- Collapsed state: fully hidden vs. thin rail with a re-expand handle.
- Iconography (chevron direction) and hover/active states.
- Whether sidebar and context pane share one control pattern (parity) or differ.
- Keyboard/CLI parity (D-6): each collapse action needs a clide verb.

Deliverable: Frame0 wireframe(s) of collapsed + expanded states for both panes, reviewed before any code.

DESIGN DIRECTION (settled): anchor both toggles on the OUTER EDGES of the center (Claude conversation) pane — one on the left edge controlling the sidebar, one on the right edge controlling the context pane. The control stays fixed on the center-pane edge whether the adjacent pane is open or collapsed, so a single button both collapses an open pane and re-opens a collapsed one (chevron flips direction). This avoids needing a separate "re-expand" handle on the collapsed pane.

Implications for the mock:
- Collapsed pane can be fully hidden (no thin rail needed) since the re-open control lives on the center edge.
- Sidebar and context pane share one mirrored control pattern (parity).
- Chevron direction reflects state: points outward to expand, inward to collapse.

IMPLEMENTATION NOTE: the collapse logic already exists — no new toggle behaviour needed. Commands `sidebar.collapse` (ctrl+shift+1) and `context.collapse` (ctrl+shift+3) are registered in lib/builtin/default_layout/src/extension.dart, exposed in the command palette + menubar, and call arrangement.toggleCollapsed(Slots.sidebar|contextPanel), returning isCollapsed (D-051, D-054).

So this ticket is scoped to the VISUAL AFFORDANCE only:
- Add the two edge-anchored toggle buttons on the center (Claude) pane''s outer edges.
- On click, invoke the existing `sidebar.collapse` / `context.collapse` commands (do NOT reimplement collapse).
- Read arrangement.isCollapsed(...) to flip the chevron direction per state.
- D-6 CLI/keyboard parity is already satisfied by the existing commands; this adds the mouse affordance.

Mock: docs/design/wireframes/hud/pane-collapse-toggles.{json,png} — State A (open) + State B (collapsed).

PLACEMENT REVISED: toggles do NOT float vertically-centered on the pane edges. They live in the BOTTOM STATUS BAR. Each toggle is horizontally pinned to the center pane''s left/right edge, so when a pane collapses the toggle slides along the status bar to that end (open: at the inner pane boundary; collapsed: at the far status-bar end — matching where the reference-screenshot arrows pointed). Still mirrored left/right for parity; chevron flips per isCollapsed. Buttons invoke the existing sidebar.collapse / context.collapse commands.

Mock updated: docs/design/wireframes/hud/pane-collapse-toggles.{json,png}.', NULL, '2026-06-09 15:28:16', '2026-06-09 15:28:16', '2026-06-09 15:28:16', NULL, 'f415ce161a4fe67f8c24f4f6573a762a', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM72SHY93S36VM9G6D8', 'description', 'Design and add collapse/expand controls for the left sidebar and the right context pane, along the lines of the reference screenshot (green arrows mark the two intended affordance locations — bottom-left of the sidebar and bottom-right of the context pane).

Scope of this ticket: set up a Frame0 mock to talk through the design before implementing.

Open questions to resolve in the mock:
- Affordance placement: footer/status-bar anchored (as the screenshot arrows suggest) vs. pane-edge chevron.
- Collapsed state: fully hidden vs. thin rail with a re-expand handle.
- Iconography (chevron direction) and hover/active states.
- Whether sidebar and context pane share one control pattern (parity) or differ.
- Keyboard/CLI parity (D-6): each collapse action needs a clide verb.

Deliverable: Frame0 wireframe(s) of collapsed + expanded states for both panes, reviewed before any code.

DESIGN DIRECTION (settled): anchor both toggles on the OUTER EDGES of the center (Claude conversation) pane — one on the left edge controlling the sidebar, one on the right edge controlling the context pane. The control stays fixed on the center-pane edge whether the adjacent pane is open or collapsed, so a single button both collapses an open pane and re-opens a collapsed one (chevron flips direction). This avoids needing a separate "re-expand" handle on the collapsed pane.

Implications for the mock:
- Collapsed pane can be fully hidden (no thin rail needed) since the re-open control lives on the center edge.
- Sidebar and context pane share one mirrored control pattern (parity).
- Chevron direction reflects state: points outward to expand, inward to collapse.

IMPLEMENTATION NOTE: the collapse logic already exists — no new toggle behaviour needed. Commands `sidebar.collapse` (ctrl+shift+1) and `context.collapse` (ctrl+shift+3) are registered in lib/builtin/default_layout/src/extension.dart, exposed in the command palette + menubar, and call arrangement.toggleCollapsed(Slots.sidebar|contextPanel), returning isCollapsed (D-051, D-054).

So this ticket is scoped to the VISUAL AFFORDANCE only:
- Add the two edge-anchored toggle buttons on the center (Claude) pane''s outer edges.
- On click, invoke the existing `sidebar.collapse` / `context.collapse` commands (do NOT reimplement collapse).
- Read arrangement.isCollapsed(...) to flip the chevron direction per state.
- D-6 CLI/keyboard parity is already satisfied by the existing commands; this adds the mouse affordance.

Mock: docs/design/wireframes/hud/pane-collapse-toggles.{json,png} — State A (open) + State B (collapsed).

PLACEMENT REVISED: toggles do NOT float vertically-centered on the pane edges. They live in the BOTTOM STATUS BAR. Each toggle is horizontally pinned to the center pane''s left/right edge, so when a pane collapses the toggle slides along the status bar to that end (open: at the inner pane boundary; collapsed: at the far status-bar end — matching where the reference-screenshot arrows pointed). Still mirrored left/right for parity; chevron flips per isCollapsed. Buttons invoke the existing sidebar.collapse / context.collapse commands.

Mock updated: docs/design/wireframes/hud/pane-collapse-toggles.{json,png}.', 'Design and add collapse/expand controls for the left sidebar and the right context pane, along the lines of the reference screenshot (green arrows mark the two intended affordance locations — bottom-left of the sidebar and bottom-right of the context pane).

Scope of this ticket: set up a Frame0 mock to talk through the design before implementing.

Open questions to resolve in the mock:
- Affordance placement: footer/status-bar anchored (as the screenshot arrows suggest) vs. pane-edge chevron.
- Collapsed state: fully hidden vs. thin rail with a re-expand handle.
- Iconography (chevron direction) and hover/active states.
- Whether sidebar and context pane share one control pattern (parity) or differ.
- Keyboard/CLI parity (D-6): each collapse action needs a clide verb.

Deliverable: Frame0 wireframe(s) of collapsed + expanded states for both panes, reviewed before any code.

DESIGN DIRECTION (settled): anchor both toggles on the OUTER EDGES of the center (Claude conversation) pane — one on the left edge controlling the sidebar, one on the right edge controlling the context pane. The control stays fixed on the center-pane edge whether the adjacent pane is open or collapsed, so a single button both collapses an open pane and re-opens a collapsed one (chevron flips direction). This avoids needing a separate "re-expand" handle on the collapsed pane.

Implications for the mock:
- Collapsed pane can be fully hidden (no thin rail needed) since the re-open control lives on the center edge.
- Sidebar and context pane share one mirrored control pattern (parity).
- Chevron direction reflects state: points outward to expand, inward to collapse.

IMPLEMENTATION NOTE: the collapse logic already exists — no new toggle behaviour needed. Commands `sidebar.collapse` (ctrl+shift+1) and `context.collapse` (ctrl+shift+3) are registered in lib/builtin/default_layout/src/extension.dart, exposed in the command palette + menubar, and call arrangement.toggleCollapsed(Slots.sidebar|contextPanel), returning isCollapsed (D-051, D-054).

So this ticket is scoped to the VISUAL AFFORDANCE only:
- Add the two edge-anchored toggle buttons on the center (Claude) pane''s outer edges.
- On click, invoke the existing `sidebar.collapse` / `context.collapse` commands (do NOT reimplement collapse).
- Read arrangement.isCollapsed(...) to flip the chevron direction per state.
- D-6 CLI/keyboard parity is already satisfied by the existing commands; this adds the mouse affordance.

Mock: docs/design/wireframes/hud/pane-collapse-toggles.{json,png} — State A (open) + State B (collapsed).

PLACEMENT REVISED: toggles do NOT float vertically-centered on the pane edges. They live in the BOTTOM STATUS BAR. Each toggle is horizontally pinned to the center pane''s left/right edge, so when a pane collapses the toggle slides along the status bar to that end (open: at the inner pane boundary; collapsed: at the far status-bar end — matching where the reference-screenshot arrows pointed). Still mirrored left/right for parity; chevron flips per isCollapsed. Buttons invoke the existing sidebar.collapse / context.collapse commands.

Mock updated: docs/design/wireframes/hud/pane-collapse-toggles.{json,png}.

APPROVED (2026-06-09): pinned-to-edge status-bar placement confirmed by user. Design is settled; ready for implementation.', NULL, '2026-06-09 15:29:08', '2026-06-09 15:29:08', '2026-06-09 15:29:08', NULL, '25d8d4bf9893db066dd16e5d06a10968', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM72SHY93S36VM9G6D8', 'status', 'backlog', 'ready', NULL, '2026-06-09 15:29:11', '2026-06-09 15:29:11', '2026-06-09 15:29:11', NULL, 'a60a2682884dc0534ff386a4f029c97c', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM72SHY93S36VM9G6D8', 'description', 'Design and add collapse/expand controls for the left sidebar and the right context pane, along the lines of the reference screenshot (green arrows mark the two intended affordance locations — bottom-left of the sidebar and bottom-right of the context pane).

Scope of this ticket: set up a Frame0 mock to talk through the design before implementing.

Open questions to resolve in the mock:
- Affordance placement: footer/status-bar anchored (as the screenshot arrows suggest) vs. pane-edge chevron.
- Collapsed state: fully hidden vs. thin rail with a re-expand handle.
- Iconography (chevron direction) and hover/active states.
- Whether sidebar and context pane share one control pattern (parity) or differ.
- Keyboard/CLI parity (D-6): each collapse action needs a clide verb.

Deliverable: Frame0 wireframe(s) of collapsed + expanded states for both panes, reviewed before any code.

DESIGN DIRECTION (settled): anchor both toggles on the OUTER EDGES of the center (Claude conversation) pane — one on the left edge controlling the sidebar, one on the right edge controlling the context pane. The control stays fixed on the center-pane edge whether the adjacent pane is open or collapsed, so a single button both collapses an open pane and re-opens a collapsed one (chevron flips direction). This avoids needing a separate "re-expand" handle on the collapsed pane.

Implications for the mock:
- Collapsed pane can be fully hidden (no thin rail needed) since the re-open control lives on the center edge.
- Sidebar and context pane share one mirrored control pattern (parity).
- Chevron direction reflects state: points outward to expand, inward to collapse.

IMPLEMENTATION NOTE: the collapse logic already exists — no new toggle behaviour needed. Commands `sidebar.collapse` (ctrl+shift+1) and `context.collapse` (ctrl+shift+3) are registered in lib/builtin/default_layout/src/extension.dart, exposed in the command palette + menubar, and call arrangement.toggleCollapsed(Slots.sidebar|contextPanel), returning isCollapsed (D-051, D-054).

So this ticket is scoped to the VISUAL AFFORDANCE only:
- Add the two edge-anchored toggle buttons on the center (Claude) pane''s outer edges.
- On click, invoke the existing `sidebar.collapse` / `context.collapse` commands (do NOT reimplement collapse).
- Read arrangement.isCollapsed(...) to flip the chevron direction per state.
- D-6 CLI/keyboard parity is already satisfied by the existing commands; this adds the mouse affordance.

Mock: docs/design/wireframes/hud/pane-collapse-toggles.{json,png} — State A (open) + State B (collapsed).

PLACEMENT REVISED: toggles do NOT float vertically-centered on the pane edges. They live in the BOTTOM STATUS BAR. Each toggle is horizontally pinned to the center pane''s left/right edge, so when a pane collapses the toggle slides along the status bar to that end (open: at the inner pane boundary; collapsed: at the far status-bar end — matching where the reference-screenshot arrows pointed). Still mirrored left/right for parity; chevron flips per isCollapsed. Buttons invoke the existing sidebar.collapse / context.collapse commands.

Mock updated: docs/design/wireframes/hud/pane-collapse-toggles.{json,png}.

APPROVED (2026-06-09): pinned-to-edge status-bar placement confirmed by user. Design is settled; ready for implementation.', 'Design and add collapse/expand controls for the left sidebar and the right context pane, along the lines of the reference screenshot (green arrows mark the two intended affordance locations — bottom-left of the sidebar and bottom-right of the context pane).

Scope of this ticket: set up a Frame0 mock to talk through the design before implementing.

Open questions to resolve in the mock:
- Affordance placement: footer/status-bar anchored (as the screenshot arrows suggest) vs. pane-edge chevron.
- Collapsed state: fully hidden vs. thin rail with a re-expand handle.
- Iconography (chevron direction) and hover/active states.
- Whether sidebar and context pane share one control pattern (parity) or differ.
- Keyboard/CLI parity (D-6): each collapse action needs a clide verb.

Deliverable: Frame0 wireframe(s) of collapsed + expanded states for both panes, reviewed before any code.

DESIGN DIRECTION (settled): anchor both toggles on the OUTER EDGES of the center (Claude conversation) pane — one on the left edge controlling the sidebar, one on the right edge controlling the context pane. The control stays fixed on the center-pane edge whether the adjacent pane is open or collapsed, so a single button both collapses an open pane and re-opens a collapsed one (chevron flips direction). This avoids needing a separate "re-expand" handle on the collapsed pane.

Implications for the mock:
- Collapsed pane can be fully hidden (no thin rail needed) since the re-open control lives on the center edge.
- Sidebar and context pane share one mirrored control pattern (parity).
- Chevron direction reflects state: points outward to expand, inward to collapse.

IMPLEMENTATION NOTE: the collapse logic already exists — no new toggle behaviour needed. Commands `sidebar.collapse` (ctrl+shift+1) and `context.collapse` (ctrl+shift+3) are registered in lib/builtin/default_layout/src/extension.dart, exposed in the command palette + menubar, and call arrangement.toggleCollapsed(Slots.sidebar|contextPanel), returning isCollapsed (D-051, D-054).

So this ticket is scoped to the VISUAL AFFORDANCE only:
- Add the two edge-anchored toggle buttons on the center (Claude) pane''s outer edges.
- On click, invoke the existing `sidebar.collapse` / `context.collapse` commands (do NOT reimplement collapse).
- Read arrangement.isCollapsed(...) to flip the chevron direction per state.
- D-6 CLI/keyboard parity is already satisfied by the existing commands; this adds the mouse affordance.

Mock: docs/design/wireframes/hud/pane-collapse-toggles.{json,png} — State A (open) + State B (collapsed).

PLACEMENT REVISED: toggles do NOT float vertically-centered on the pane edges. They live in the BOTTOM STATUS BAR. Each toggle is horizontally pinned to the center pane''s left/right edge, so when a pane collapses the toggle slides along the status bar to that end (open: at the inner pane boundary; collapsed: at the far status-bar end — matching where the reference-screenshot arrows pointed). Still mirrored left/right for parity; chevron flips per isCollapsed. Buttons invoke the existing sidebar.collapse / context.collapse commands.

Mock updated: docs/design/wireframes/hud/pane-collapse-toggles.{json,png}.

APPROVED (2026-06-09): pinned-to-edge status-bar placement confirmed by user. Design is settled; ready for implementation.

PLACEMENT FINAL (supersedes "pinned-to-edge"): toggles are FIXED at the far-left and far-right ends of the bottom status bar in every state. They do not slide with the pane edge. Position is constant (muscle memory; always where the reference-screenshot arrows pointed); only the chevron flips per isCollapsed. Left end = sidebar toggle, right end = context toggle. Mirrored for parity. Buttons invoke the existing sidebar.collapse / context.collapse commands.

Mock updated: docs/design/wireframes/hud/pane-collapse-toggles.{json,png}.', NULL, '2026-06-09 15:30:16', '2026-06-09 15:30:16', '2026-06-09 15:30:16', NULL, '240bef9edb3bf7d0d695673085f9498a', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM72SHY93S36VM9G6D8', 'description', 'Design and add collapse/expand controls for the left sidebar and the right context pane, along the lines of the reference screenshot (green arrows mark the two intended affordance locations — bottom-left of the sidebar and bottom-right of the context pane).

Scope of this ticket: set up a Frame0 mock to talk through the design before implementing.

Open questions to resolve in the mock:
- Affordance placement: footer/status-bar anchored (as the screenshot arrows suggest) vs. pane-edge chevron.
- Collapsed state: fully hidden vs. thin rail with a re-expand handle.
- Iconography (chevron direction) and hover/active states.
- Whether sidebar and context pane share one control pattern (parity) or differ.
- Keyboard/CLI parity (D-6): each collapse action needs a clide verb.

Deliverable: Frame0 wireframe(s) of collapsed + expanded states for both panes, reviewed before any code.

DESIGN DIRECTION (settled): anchor both toggles on the OUTER EDGES of the center (Claude conversation) pane — one on the left edge controlling the sidebar, one on the right edge controlling the context pane. The control stays fixed on the center-pane edge whether the adjacent pane is open or collapsed, so a single button both collapses an open pane and re-opens a collapsed one (chevron flips direction). This avoids needing a separate "re-expand" handle on the collapsed pane.

Implications for the mock:
- Collapsed pane can be fully hidden (no thin rail needed) since the re-open control lives on the center edge.
- Sidebar and context pane share one mirrored control pattern (parity).
- Chevron direction reflects state: points outward to expand, inward to collapse.

IMPLEMENTATION NOTE: the collapse logic already exists — no new toggle behaviour needed. Commands `sidebar.collapse` (ctrl+shift+1) and `context.collapse` (ctrl+shift+3) are registered in lib/builtin/default_layout/src/extension.dart, exposed in the command palette + menubar, and call arrangement.toggleCollapsed(Slots.sidebar|contextPanel), returning isCollapsed (D-051, D-054).

So this ticket is scoped to the VISUAL AFFORDANCE only:
- Add the two edge-anchored toggle buttons on the center (Claude) pane''s outer edges.
- On click, invoke the existing `sidebar.collapse` / `context.collapse` commands (do NOT reimplement collapse).
- Read arrangement.isCollapsed(...) to flip the chevron direction per state.
- D-6 CLI/keyboard parity is already satisfied by the existing commands; this adds the mouse affordance.

Mock: docs/design/wireframes/hud/pane-collapse-toggles.{json,png} — State A (open) + State B (collapsed).

PLACEMENT REVISED: toggles do NOT float vertically-centered on the pane edges. They live in the BOTTOM STATUS BAR. Each toggle is horizontally pinned to the center pane''s left/right edge, so when a pane collapses the toggle slides along the status bar to that end (open: at the inner pane boundary; collapsed: at the far status-bar end — matching where the reference-screenshot arrows pointed). Still mirrored left/right for parity; chevron flips per isCollapsed. Buttons invoke the existing sidebar.collapse / context.collapse commands.

Mock updated: docs/design/wireframes/hud/pane-collapse-toggles.{json,png}.

APPROVED (2026-06-09): pinned-to-edge status-bar placement confirmed by user. Design is settled; ready for implementation.

PLACEMENT FINAL (supersedes "pinned-to-edge"): toggles are FIXED at the far-left and far-right ends of the bottom status bar in every state. They do not slide with the pane edge. Position is constant (muscle memory; always where the reference-screenshot arrows pointed); only the chevron flips per isCollapsed. Left end = sidebar toggle, right end = context toggle. Mirrored for parity. Buttons invoke the existing sidebar.collapse / context.collapse commands.

Mock updated: docs/design/wireframes/hud/pane-collapse-toggles.{json,png}.', 'Design and add collapse/expand controls for the left sidebar and the right context pane, along the lines of the reference screenshot (green arrows mark the two intended affordance locations — bottom-left of the sidebar and bottom-right of the context pane).

Scope of this ticket: set up a Frame0 mock to talk through the design before implementing.

Open questions to resolve in the mock:
- Affordance placement: footer/status-bar anchored (as the screenshot arrows suggest) vs. pane-edge chevron.
- Collapsed state: fully hidden vs. thin rail with a re-expand handle.
- Iconography (chevron direction) and hover/active states.
- Whether sidebar and context pane share one control pattern (parity) or differ.
- Keyboard/CLI parity (D-6): each collapse action needs a clide verb.

Deliverable: Frame0 wireframe(s) of collapsed + expanded states for both panes, reviewed before any code.

DESIGN DIRECTION (settled): anchor both toggles on the OUTER EDGES of the center (Claude conversation) pane — one on the left edge controlling the sidebar, one on the right edge controlling the context pane. The control stays fixed on the center-pane edge whether the adjacent pane is open or collapsed, so a single button both collapses an open pane and re-opens a collapsed one (chevron flips direction). This avoids needing a separate "re-expand" handle on the collapsed pane.

Implications for the mock:
- Collapsed pane can be fully hidden (no thin rail needed) since the re-open control lives on the center edge.
- Sidebar and context pane share one mirrored control pattern (parity).
- Chevron direction reflects state: points outward to expand, inward to collapse.

IMPLEMENTATION NOTE: the collapse logic already exists — no new toggle behaviour needed. Commands `sidebar.collapse` (ctrl+shift+1) and `context.collapse` (ctrl+shift+3) are registered in lib/builtin/default_layout/src/extension.dart, exposed in the command palette + menubar, and call arrangement.toggleCollapsed(Slots.sidebar|contextPanel), returning isCollapsed (D-051, D-054).

So this ticket is scoped to the VISUAL AFFORDANCE only:
- Add the two edge-anchored toggle buttons on the center (Claude) pane''s outer edges.
- On click, invoke the existing `sidebar.collapse` / `context.collapse` commands (do NOT reimplement collapse).
- Read arrangement.isCollapsed(...) to flip the chevron direction per state.
- D-6 CLI/keyboard parity is already satisfied by the existing commands; this adds the mouse affordance.

Mock: docs/design/wireframes/hud/pane-collapse-toggles.{json,png} — State A (open) + State B (collapsed).

PLACEMENT REVISED: toggles do NOT float vertically-centered on the pane edges. They live in the BOTTOM STATUS BAR. Each toggle is horizontally pinned to the center pane''s left/right edge, so when a pane collapses the toggle slides along the status bar to that end (open: at the inner pane boundary; collapsed: at the far status-bar end — matching where the reference-screenshot arrows pointed). Still mirrored left/right for parity; chevron flips per isCollapsed. Buttons invoke the existing sidebar.collapse / context.collapse commands.

Mock updated: docs/design/wireframes/hud/pane-collapse-toggles.{json,png}.

APPROVED (2026-06-09): pinned-to-edge status-bar placement confirmed by user. Design is settled; ready for implementation.

PLACEMENT FINAL (supersedes "pinned-to-edge"): toggles are FIXED at the far-left and far-right ends of the bottom status bar in every state. They do not slide with the pane edge. Position is constant (muscle memory; always where the reference-screenshot arrows pointed); only the chevron flips per isCollapsed. Left end = sidebar toggle, right end = context toggle. Mirrored for parity. Buttons invoke the existing sidebar.collapse / context.collapse commands.

Mock updated: docs/design/wireframes/hud/pane-collapse-toggles.{json,png}.

SPACE NOTE: the status bar already hosts content at both ends (left: branch / skills count; right: Output / terminal). Fixed-end toggles therefore share that space. Resolution: reserve the OUTERMOST ~24px cell at each end for the toggle and shift the existing status items inward by that width — a constant reservation, not a dynamic fight (the toggle never moves or grows). The mock reflects this: status text begins after the left toggle and ends before the right toggle.', NULL, '2026-06-09 15:30:41', '2026-06-09 15:30:41', '2026-06-09 15:30:41', NULL, '817cb40d9b8f5d92a00e453d1747b7a2', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM72SHY93S36VM9G6D8', 'description', 'Design and add collapse/expand controls for the left sidebar and the right context pane, along the lines of the reference screenshot (green arrows mark the two intended affordance locations — bottom-left of the sidebar and bottom-right of the context pane).

Scope of this ticket: set up a Frame0 mock to talk through the design before implementing.

Open questions to resolve in the mock:
- Affordance placement: footer/status-bar anchored (as the screenshot arrows suggest) vs. pane-edge chevron.
- Collapsed state: fully hidden vs. thin rail with a re-expand handle.
- Iconography (chevron direction) and hover/active states.
- Whether sidebar and context pane share one control pattern (parity) or differ.
- Keyboard/CLI parity (D-6): each collapse action needs a clide verb.

Deliverable: Frame0 wireframe(s) of collapsed + expanded states for both panes, reviewed before any code.

DESIGN DIRECTION (settled): anchor both toggles on the OUTER EDGES of the center (Claude conversation) pane — one on the left edge controlling the sidebar, one on the right edge controlling the context pane. The control stays fixed on the center-pane edge whether the adjacent pane is open or collapsed, so a single button both collapses an open pane and re-opens a collapsed one (chevron flips direction). This avoids needing a separate "re-expand" handle on the collapsed pane.

Implications for the mock:
- Collapsed pane can be fully hidden (no thin rail needed) since the re-open control lives on the center edge.
- Sidebar and context pane share one mirrored control pattern (parity).
- Chevron direction reflects state: points outward to expand, inward to collapse.

IMPLEMENTATION NOTE: the collapse logic already exists — no new toggle behaviour needed. Commands `sidebar.collapse` (ctrl+shift+1) and `context.collapse` (ctrl+shift+3) are registered in lib/builtin/default_layout/src/extension.dart, exposed in the command palette + menubar, and call arrangement.toggleCollapsed(Slots.sidebar|contextPanel), returning isCollapsed (D-051, D-054).

So this ticket is scoped to the VISUAL AFFORDANCE only:
- Add the two edge-anchored toggle buttons on the center (Claude) pane''s outer edges.
- On click, invoke the existing `sidebar.collapse` / `context.collapse` commands (do NOT reimplement collapse).
- Read arrangement.isCollapsed(...) to flip the chevron direction per state.
- D-6 CLI/keyboard parity is already satisfied by the existing commands; this adds the mouse affordance.

Mock: docs/design/wireframes/hud/pane-collapse-toggles.{json,png} — State A (open) + State B (collapsed).

PLACEMENT REVISED: toggles do NOT float vertically-centered on the pane edges. They live in the BOTTOM STATUS BAR. Each toggle is horizontally pinned to the center pane''s left/right edge, so when a pane collapses the toggle slides along the status bar to that end (open: at the inner pane boundary; collapsed: at the far status-bar end — matching where the reference-screenshot arrows pointed). Still mirrored left/right for parity; chevron flips per isCollapsed. Buttons invoke the existing sidebar.collapse / context.collapse commands.

Mock updated: docs/design/wireframes/hud/pane-collapse-toggles.{json,png}.

APPROVED (2026-06-09): pinned-to-edge status-bar placement confirmed by user. Design is settled; ready for implementation.

PLACEMENT FINAL (supersedes "pinned-to-edge"): toggles are FIXED at the far-left and far-right ends of the bottom status bar in every state. They do not slide with the pane edge. Position is constant (muscle memory; always where the reference-screenshot arrows pointed); only the chevron flips per isCollapsed. Left end = sidebar toggle, right end = context toggle. Mirrored for parity. Buttons invoke the existing sidebar.collapse / context.collapse commands.

Mock updated: docs/design/wireframes/hud/pane-collapse-toggles.{json,png}.

SPACE NOTE: the status bar already hosts content at both ends (left: branch / skills count; right: Output / terminal). Fixed-end toggles therefore share that space. Resolution: reserve the OUTERMOST ~24px cell at each end for the toggle and shift the existing status items inward by that width — a constant reservation, not a dynamic fight (the toggle never moves or grows). The mock reflects this: status text begins after the left toggle and ends before the right toggle.', 'Design and add collapse/expand controls for the left sidebar and the right context pane, along the lines of the reference screenshot (green arrows mark the two intended affordance locations — bottom-left of the sidebar and bottom-right of the context pane).

Scope of this ticket: set up a Frame0 mock to talk through the design before implementing.

Open questions to resolve in the mock:
- Affordance placement: footer/status-bar anchored (as the screenshot arrows suggest) vs. pane-edge chevron.
- Collapsed state: fully hidden vs. thin rail with a re-expand handle.
- Iconography (chevron direction) and hover/active states.
- Whether sidebar and context pane share one control pattern (parity) or differ.
- Keyboard/CLI parity (D-6): each collapse action needs a clide verb.

Deliverable: Frame0 wireframe(s) of collapsed + expanded states for both panes, reviewed before any code.

DESIGN DIRECTION (settled): anchor both toggles on the OUTER EDGES of the center (Claude conversation) pane — one on the left edge controlling the sidebar, one on the right edge controlling the context pane. The control stays fixed on the center-pane edge whether the adjacent pane is open or collapsed, so a single button both collapses an open pane and re-opens a collapsed one (chevron flips direction). This avoids needing a separate "re-expand" handle on the collapsed pane.

Implications for the mock:
- Collapsed pane can be fully hidden (no thin rail needed) since the re-open control lives on the center edge.
- Sidebar and context pane share one mirrored control pattern (parity).
- Chevron direction reflects state: points outward to expand, inward to collapse.

IMPLEMENTATION NOTE: the collapse logic already exists — no new toggle behaviour needed. Commands `sidebar.collapse` (ctrl+shift+1) and `context.collapse` (ctrl+shift+3) are registered in lib/builtin/default_layout/src/extension.dart, exposed in the command palette + menubar, and call arrangement.toggleCollapsed(Slots.sidebar|contextPanel), returning isCollapsed (D-051, D-054).

So this ticket is scoped to the VISUAL AFFORDANCE only:
- Add the two edge-anchored toggle buttons on the center (Claude) pane''s outer edges.
- On click, invoke the existing `sidebar.collapse` / `context.collapse` commands (do NOT reimplement collapse).
- Read arrangement.isCollapsed(...) to flip the chevron direction per state.
- D-6 CLI/keyboard parity is already satisfied by the existing commands; this adds the mouse affordance.

Mock: docs/design/wireframes/hud/pane-collapse-toggles.{json,png} — State A (open) + State B (collapsed).

PLACEMENT REVISED: toggles do NOT float vertically-centered on the pane edges. They live in the BOTTOM STATUS BAR. Each toggle is horizontally pinned to the center pane''s left/right edge, so when a pane collapses the toggle slides along the status bar to that end (open: at the inner pane boundary; collapsed: at the far status-bar end — matching where the reference-screenshot arrows pointed). Still mirrored left/right for parity; chevron flips per isCollapsed. Buttons invoke the existing sidebar.collapse / context.collapse commands.

Mock updated: docs/design/wireframes/hud/pane-collapse-toggles.{json,png}.

APPROVED (2026-06-09): pinned-to-edge status-bar placement confirmed by user. Design is settled; ready for implementation.

PLACEMENT FINAL (supersedes "pinned-to-edge"): toggles are FIXED at the far-left and far-right ends of the bottom status bar in every state. They do not slide with the pane edge. Position is constant (muscle memory; always where the reference-screenshot arrows pointed); only the chevron flips per isCollapsed. Left end = sidebar toggle, right end = context toggle. Mirrored for parity. Buttons invoke the existing sidebar.collapse / context.collapse commands.

Mock updated: docs/design/wireframes/hud/pane-collapse-toggles.{json,png}.

SPACE NOTE: the status bar already hosts content at both ends (left: branch / skills count; right: Output / terminal). Fixed-end toggles therefore share that space. Resolution: reserve the OUTERMOST ~24px cell at each end for the toggle and shift the existing status items inward by that width — a constant reservation, not a dynamic fight (the toggle never moves or grows). The mock reflects this: status text begins after the left toggle and ends before the right toggle.

GLYPH DECISION: use Phosphor caret-line icons (chevron + edge line), which read as "collapse to the edge":
- caret-line-left  -> 0xe132 (CaretLineLeft)
- caret-line-right -> 0xe130 (CaretLineRight)
The glyphs already ship in assets/fonts/phosphor (codepoints.csv lines 150-151) — no new dependency. Add two consts to lib/widgets/src/icons/phosphor.dart (PhosphorIcons.caretLineLeft / caretLineRight) during implementation. Chevron-line direction flips per isCollapsed.', NULL, '2026-06-09 15:33:14', '2026-06-09 15:33:14', '2026-06-09 15:33:14', NULL, 'bef1363660f958fbda57d1a1ab2c3600', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM72SHY93S36VM9G6D8', 'description', 'Design and add collapse/expand controls for the left sidebar and the right context pane, along the lines of the reference screenshot (green arrows mark the two intended affordance locations — bottom-left of the sidebar and bottom-right of the context pane).

Scope of this ticket: set up a Frame0 mock to talk through the design before implementing.

Open questions to resolve in the mock:
- Affordance placement: footer/status-bar anchored (as the screenshot arrows suggest) vs. pane-edge chevron.
- Collapsed state: fully hidden vs. thin rail with a re-expand handle.
- Iconography (chevron direction) and hover/active states.
- Whether sidebar and context pane share one control pattern (parity) or differ.
- Keyboard/CLI parity (D-6): each collapse action needs a clide verb.

Deliverable: Frame0 wireframe(s) of collapsed + expanded states for both panes, reviewed before any code.

DESIGN DIRECTION (settled): anchor both toggles on the OUTER EDGES of the center (Claude conversation) pane — one on the left edge controlling the sidebar, one on the right edge controlling the context pane. The control stays fixed on the center-pane edge whether the adjacent pane is open or collapsed, so a single button both collapses an open pane and re-opens a collapsed one (chevron flips direction). This avoids needing a separate "re-expand" handle on the collapsed pane.

Implications for the mock:
- Collapsed pane can be fully hidden (no thin rail needed) since the re-open control lives on the center edge.
- Sidebar and context pane share one mirrored control pattern (parity).
- Chevron direction reflects state: points outward to expand, inward to collapse.

IMPLEMENTATION NOTE: the collapse logic already exists — no new toggle behaviour needed. Commands `sidebar.collapse` (ctrl+shift+1) and `context.collapse` (ctrl+shift+3) are registered in lib/builtin/default_layout/src/extension.dart, exposed in the command palette + menubar, and call arrangement.toggleCollapsed(Slots.sidebar|contextPanel), returning isCollapsed (D-051, D-054).

So this ticket is scoped to the VISUAL AFFORDANCE only:
- Add the two edge-anchored toggle buttons on the center (Claude) pane''s outer edges.
- On click, invoke the existing `sidebar.collapse` / `context.collapse` commands (do NOT reimplement collapse).
- Read arrangement.isCollapsed(...) to flip the chevron direction per state.
- D-6 CLI/keyboard parity is already satisfied by the existing commands; this adds the mouse affordance.

Mock: docs/design/wireframes/hud/pane-collapse-toggles.{json,png} — State A (open) + State B (collapsed).

PLACEMENT REVISED: toggles do NOT float vertically-centered on the pane edges. They live in the BOTTOM STATUS BAR. Each toggle is horizontally pinned to the center pane''s left/right edge, so when a pane collapses the toggle slides along the status bar to that end (open: at the inner pane boundary; collapsed: at the far status-bar end — matching where the reference-screenshot arrows pointed). Still mirrored left/right for parity; chevron flips per isCollapsed. Buttons invoke the existing sidebar.collapse / context.collapse commands.

Mock updated: docs/design/wireframes/hud/pane-collapse-toggles.{json,png}.

APPROVED (2026-06-09): pinned-to-edge status-bar placement confirmed by user. Design is settled; ready for implementation.

PLACEMENT FINAL (supersedes "pinned-to-edge"): toggles are FIXED at the far-left and far-right ends of the bottom status bar in every state. They do not slide with the pane edge. Position is constant (muscle memory; always where the reference-screenshot arrows pointed); only the chevron flips per isCollapsed. Left end = sidebar toggle, right end = context toggle. Mirrored for parity. Buttons invoke the existing sidebar.collapse / context.collapse commands.

Mock updated: docs/design/wireframes/hud/pane-collapse-toggles.{json,png}.

SPACE NOTE: the status bar already hosts content at both ends (left: branch / skills count; right: Output / terminal). Fixed-end toggles therefore share that space. Resolution: reserve the OUTERMOST ~24px cell at each end for the toggle and shift the existing status items inward by that width — a constant reservation, not a dynamic fight (the toggle never moves or grows). The mock reflects this: status text begins after the left toggle and ends before the right toggle.

GLYPH DECISION: use Phosphor caret-line icons (chevron + edge line), which read as "collapse to the edge":
- caret-line-left  -> 0xe132 (CaretLineLeft)
- caret-line-right -> 0xe130 (CaretLineRight)
The glyphs already ship in assets/fonts/phosphor (codepoints.csv lines 150-151) — no new dependency. Add two consts to lib/widgets/src/icons/phosphor.dart (PhosphorIcons.caretLineLeft / caretLineRight) during implementation. Chevron-line direction flips per isCollapsed.', 'Design and add collapse/expand controls for the left sidebar and the right context pane, along the lines of the reference screenshot (green arrows mark the two intended affordance locations — bottom-left of the sidebar and bottom-right of the context pane).

Scope of this ticket: set up a Frame0 mock to talk through the design before implementing.

Open questions to resolve in the mock:
- Affordance placement: footer/status-bar anchored (as the screenshot arrows suggest) vs. pane-edge chevron.
- Collapsed state: fully hidden vs. thin rail with a re-expand handle.
- Iconography (chevron direction) and hover/active states.
- Whether sidebar and context pane share one control pattern (parity) or differ.
- Keyboard/CLI parity (D-6): each collapse action needs a clide verb.

Deliverable: Frame0 wireframe(s) of collapsed + expanded states for both panes, reviewed before any code.

DESIGN DIRECTION (settled): anchor both toggles on the OUTER EDGES of the center (Claude conversation) pane — one on the left edge controlling the sidebar, one on the right edge controlling the context pane. The control stays fixed on the center-pane edge whether the adjacent pane is open or collapsed, so a single button both collapses an open pane and re-opens a collapsed one (chevron flips direction). This avoids needing a separate "re-expand" handle on the collapsed pane.

Implications for the mock:
- Collapsed pane can be fully hidden (no thin rail needed) since the re-open control lives on the center edge.
- Sidebar and context pane share one mirrored control pattern (parity).
- Chevron direction reflects state: points outward to expand, inward to collapse.

IMPLEMENTATION NOTE: the collapse logic already exists — no new toggle behaviour needed. Commands `sidebar.collapse` (ctrl+shift+1) and `context.collapse` (ctrl+shift+3) are registered in lib/builtin/default_layout/src/extension.dart, exposed in the command palette + menubar, and call arrangement.toggleCollapsed(Slots.sidebar|contextPanel), returning isCollapsed (D-051, D-054).

So this ticket is scoped to the VISUAL AFFORDANCE only:
- Add the two edge-anchored toggle buttons on the center (Claude) pane''s outer edges.
- On click, invoke the existing `sidebar.collapse` / `context.collapse` commands (do NOT reimplement collapse).
- Read arrangement.isCollapsed(...) to flip the chevron direction per state.
- D-6 CLI/keyboard parity is already satisfied by the existing commands; this adds the mouse affordance.

Mock: docs/design/wireframes/hud/pane-collapse-toggles.{json,png} — State A (open) + State B (collapsed).

PLACEMENT REVISED: toggles do NOT float vertically-centered on the pane edges. They live in the BOTTOM STATUS BAR. Each toggle is horizontally pinned to the center pane''s left/right edge, so when a pane collapses the toggle slides along the status bar to that end (open: at the inner pane boundary; collapsed: at the far status-bar end — matching where the reference-screenshot arrows pointed). Still mirrored left/right for parity; chevron flips per isCollapsed. Buttons invoke the existing sidebar.collapse / context.collapse commands.

Mock updated: docs/design/wireframes/hud/pane-collapse-toggles.{json,png}.

APPROVED (2026-06-09): pinned-to-edge status-bar placement confirmed by user. Design is settled; ready for implementation.

PLACEMENT FINAL (supersedes "pinned-to-edge"): toggles are FIXED at the far-left and far-right ends of the bottom status bar in every state. They do not slide with the pane edge. Position is constant (muscle memory; always where the reference-screenshot arrows pointed); only the chevron flips per isCollapsed. Left end = sidebar toggle, right end = context toggle. Mirrored for parity. Buttons invoke the existing sidebar.collapse / context.collapse commands.

Mock updated: docs/design/wireframes/hud/pane-collapse-toggles.{json,png}.

SPACE NOTE: the status bar already hosts content at both ends (left: branch / skills count; right: Output / terminal). Fixed-end toggles therefore share that space. Resolution: reserve the OUTERMOST ~24px cell at each end for the toggle and shift the existing status items inward by that width — a constant reservation, not a dynamic fight (the toggle never moves or grows). The mock reflects this: status text begins after the left toggle and ends before the right toggle.

GLYPH DECISION: use Phosphor caret-line icons (chevron + edge line), which read as "collapse to the edge":
- caret-line-left  -> 0xe132 (CaretLineLeft)
- caret-line-right -> 0xe130 (CaretLineRight)
The glyphs already ship in assets/fonts/phosphor (codepoints.csv lines 150-151) — no new dependency. Add two consts to lib/widgets/src/icons/phosphor.dart (PhosphorIcons.caretLineLeft / caretLineRight) during implementation. Chevron-line direction flips per isCollapsed.

RESOLUTION (2026-06-09): considered moving the re-open control into the center (pane edge or center status segment) to dodge the end-of-bar space contention; user chose to KEEP TOGGLES FIXED AT THE STATUS-BAR ENDS (best muscle memory). Final design = v3 mock: caret-line glyphs at fixed far-left/far-right status-bar cells (~24px reserved, side items shifted in), chevron-line flips per isCollapsed, firing existing sidebar.collapse / context.collapse. Design fully settled; ready to implement.', NULL, '2026-06-09 15:34:11', '2026-06-09 15:34:11', '2026-06-09 15:34:11', NULL, '194a6e362e707647b03610226991cdf1', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM42WW0SY3XEXKE8PK8', 'status', 'ready', 'done', NULL, '2026-06-09 15:36:15', '2026-06-09 15:36:15', '2026-06-09 15:36:15', NULL, '4daeb008d8c9b1f137995c7eef7d133d', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM42WW0SY3XEXKE8PK8', 'description', 'Picking a theme (status-bar switcher T-234, or the Settings modal) applies live but is never saved, so every reload resets to the first bundled theme. The choice should persist PER REPO.

Root cause: ThemeController.select() (lib/kernel/src/theme/controller.dart:43) only mutates _currentName + notifies — no persistence. It is constructed in facade.dart:160 as ThemeController(bundled: bundledThemes) with no initialName, so on boot it always falls back to bundled.first.

Infra already exists — no new store needed: SettingsStore (lib/kernel/src/settings.dart) has a PROJECT scope that persists to <repo>/.clide/settings.yaml via ''project.*'' keys, and ProjectManager.openProject() already calls settings.setProjectDir() on open (project.dart:130), which loads that file.

Proposed fix:
1. PERSIST on change — wire a listener on ThemeController (in facade.dart, where both theme + settings exist) that writes the current theme to settings whenever currentName changes; use project scope (''project.theme'') when a repo is open. currentName already encodes the high-contrast variant (resolveThemeName -> ''<base>-hc''), so the HC toggle persists for free.
2. RESTORE on load — the project dir is set AFTER boot, so restoration must hook project-open (ProjectManager.openProject / settings.setProjectDir), not just construction: when a project opens, read ''project.theme'' and, if present + known, theme.select() it. Guard ArgumentError for a theme that is no longer bundled (fall back to default, don''t throw).

Open question: app-scoped fallback. Persist project-scoped per the report; optionally also write ''app.theme'' as the global default so a brand-new repo inherits the last choice instead of bundled.first. Decide during implementation.

Acceptance: pick a theme (incl. the High-contrast toggle) -> restart -> same theme restored for that repo; two repos keep independent choices; with no repo open, the app default applies; a saved theme that no longer exists degrades to the default without throwing.

Tests: SettingsStore round-trips ''project.theme''; opening a project applies the saved theme to the controller; select() persists; unknown saved theme falls back. Refs: T-234 (theme switcher), T-288/D-88 (picker), SettingsStore, ProjectManager.', 'Picking a theme (status-bar switcher T-234, or the Settings modal) applies live but is never saved, so every reload resets to the first bundled theme. The choice should persist PER REPO.

Root cause: ThemeController.select() (lib/kernel/src/theme/controller.dart:43) only mutates _currentName + notifies — no persistence. It is constructed in facade.dart:160 as ThemeController(bundled: bundledThemes) with no initialName, so on boot it always falls back to bundled.first.

Infra already exists — no new store needed: SettingsStore (lib/kernel/src/settings.dart) has a PROJECT scope that persists to <repo>/.clide/settings.yaml via ''project.*'' keys, and ProjectManager.openProject() already calls settings.setProjectDir() on open (project.dart:130), which loads that file.

Proposed fix:
1. PERSIST on change — wire a listener on ThemeController (in facade.dart, where both theme + settings exist) that writes the current theme to settings whenever currentName changes; use project scope (''project.theme'') when a repo is open. currentName already encodes the high-contrast variant (resolveThemeName -> ''<base>-hc''), so the HC toggle persists for free.
2. RESTORE on load — the project dir is set AFTER boot, so restoration must hook project-open (ProjectManager.openProject / settings.setProjectDir), not just construction: when a project opens, read ''project.theme'' and, if present + known, theme.select() it. Guard ArgumentError for a theme that is no longer bundled (fall back to default, don''t throw).

Open question: app-scoped fallback. Persist project-scoped per the report; optionally also write ''app.theme'' as the global default so a brand-new repo inherits the last choice instead of bundled.first. Decide during implementation.

Acceptance: pick a theme (incl. the High-contrast toggle) -> restart -> same theme restored for that repo; two repos keep independent choices; with no repo open, the app default applies; a saved theme that no longer exists degrades to the default without throwing.

Tests: SettingsStore round-trips ''project.theme''; opening a project applies the saved theme to the controller; select() persists; unknown saved theme falls back. Refs: T-234 (theme switcher), T-288/D-88 (picker), SettingsStore, ProjectManager.

FIXED 2026-06-09 (this commit). Added lib/kernel/src/theme/theme_persistence.dart + wireThemePersistence() in facade. Decision on the open question: persist BOTH project.theme (per-repo, in .clide/settings.yaml) AND app.theme (global default) — so a themed repo keeps its choice, an unthemed/new repo inherits the last global choice, and the HC variant persists (name encodes -hc). Restore prefers project over app; unknown theme is ignored (no throw). Tests: test/kernel/src/theme_persistence_test.dart (6 cases — persist app/project, HC, restore-on-open, boot restore, unknown fallback). All green.', NULL, '2026-06-09 15:36:15', '2026-06-09 15:36:15', '2026-06-09 15:36:15', NULL, '767b65a07e73e6a0299fe19d7851b8c2', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM63TRGBFRWK9W2WA98', 'description', 'When Claude makes multiple subsequent edits to the SAME file, bundle them into a single collapsed holder card instead of rendering each edit as its own card — mirroring how we already fold meta/activity runs.

Behaviour:
- Detect a run of consecutive edits targeting the same file_path and group them into one ClideHolderCard (the shared container from T-266; see _ActivityCard in lib/builtin/claude/src/conversation_view.dart:681).
- Collapsed (default): one-line ticker of the latest edit + a count label.
- Show the count as "# edits" (e.g. "3 edits" / "1 edit"), NOT "# steps". The existing activity card uses stepLabel = ''$count steps'' at conversation_view.dart:683; this run wants an edits-flavoured label.
- Expanded: every individual edit, each with its full report — bundle, do NOT drop or summarise away any information. All per-edit detail must remain reachable on expand.

Notes:
- Reuse the existing ClideHolderCard / folding machinery rather than building a new card.
- Grouping breaks when the file_path changes or a non-edit step interleaves (consecutive-same-file only), matching the ''subsequent edits to the same file'' wording.
- Parity with the existing meta/activity folding (T-230) — same collapse/expand affordance, just an edits-labelled run.', 'When Claude makes multiple subsequent edits to the SAME file, bundle them into a single collapsed holder card instead of rendering each edit as its own card — mirroring how we already fold meta/activity runs.

Behaviour:
- Detect a run of consecutive edits targeting the same file_path and group them into one ClideHolderCard (the shared container from T-266; see _ActivityCard in lib/builtin/claude/src/conversation_view.dart:681).
- Collapsed (default): one-line ticker of the latest edit + a count label.
- Show the count as "# edits" (e.g. "3 edits" / "1 edit"), NOT "# steps". The existing activity card uses stepLabel = ''$count steps'' at conversation_view.dart:683; this run wants an edits-flavoured label.
- Expanded: every individual edit, each with its full report — bundle, do NOT drop or summarise away any information. All per-edit detail must remain reachable on expand.

Notes:
- Reuse the existing ClideHolderCard / folding machinery rather than building a new card.
- Grouping breaks when the file_path changes or a non-edit step interleaves (consecutive-same-file only), matching the ''subsequent edits to the same file'' wording.
- Parity with the existing meta/activity folding (T-230) — same collapse/expand affordance, just an edits-labelled run.

WORKED EXAMPLE (from user screenshot, clide_markdown.dart run): the current stream renders 11 stacked cards — 3x "Edit clide_markdown.dart", then a folded "Read … 2 steps" holder, then 7x "Edit clide_markdown.dart". With this feature it collapses to THREE cards:
- [3 edits]  (the first edit run)
- [2 steps]  (the existing Read holder — unchanged; this is what splits the edit run)
- [7 edits]  (the second edit run)
Confirms the split rule: an interleaving non-edit step (here the folded Read run) breaks the consecutive-same-file edit grouping into two separate edit cards. Same-file edits with nothing between them collapse into one "# edits" card.', NULL, '2026-06-09 15:45:12', '2026-06-09 15:45:12', '2026-06-09 15:45:12', NULL, 'b7535e024ee171cb46ae7bad08d23092', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM63TRGBFRWK9W2WA98', 'description', 'When Claude makes multiple subsequent edits to the SAME file, bundle them into a single collapsed holder card instead of rendering each edit as its own card — mirroring how we already fold meta/activity runs.

Behaviour:
- Detect a run of consecutive edits targeting the same file_path and group them into one ClideHolderCard (the shared container from T-266; see _ActivityCard in lib/builtin/claude/src/conversation_view.dart:681).
- Collapsed (default): one-line ticker of the latest edit + a count label.
- Show the count as "# edits" (e.g. "3 edits" / "1 edit"), NOT "# steps". The existing activity card uses stepLabel = ''$count steps'' at conversation_view.dart:683; this run wants an edits-flavoured label.
- Expanded: every individual edit, each with its full report — bundle, do NOT drop or summarise away any information. All per-edit detail must remain reachable on expand.

Notes:
- Reuse the existing ClideHolderCard / folding machinery rather than building a new card.
- Grouping breaks when the file_path changes or a non-edit step interleaves (consecutive-same-file only), matching the ''subsequent edits to the same file'' wording.
- Parity with the existing meta/activity folding (T-230) — same collapse/expand affordance, just an edits-labelled run.

WORKED EXAMPLE (from user screenshot, clide_markdown.dart run): the current stream renders 11 stacked cards — 3x "Edit clide_markdown.dart", then a folded "Read … 2 steps" holder, then 7x "Edit clide_markdown.dart". With this feature it collapses to THREE cards:
- [3 edits]  (the first edit run)
- [2 steps]  (the existing Read holder — unchanged; this is what splits the edit run)
- [7 edits]  (the second edit run)
Confirms the split rule: an interleaving non-edit step (here the folded Read run) breaks the consecutive-same-file edit grouping into two separate edit cards. Same-file edits with nothing between them collapse into one "# edits" card.', 'When Claude makes multiple subsequent edits to the SAME file, bundle them into a single collapsed holder card instead of rendering each edit as its own card — mirroring how we already fold meta/activity runs.

Behaviour:
- Detect a run of consecutive edits targeting the same file_path and group them into one ClideHolderCard (the shared container from T-266; see _ActivityCard in lib/builtin/claude/src/conversation_view.dart:681).
- Collapsed (default): one-line ticker of the latest edit + a count label.
- Show the count as "# edits" (e.g. "3 edits" / "1 edit"), NOT "# steps". The existing activity card uses stepLabel = ''$count steps'' at conversation_view.dart:683; this run wants an edits-flavoured label.
- Expanded: every individual edit, each with its full report — bundle, do NOT drop or summarise away any information. All per-edit detail must remain reachable on expand.

Notes:
- Reuse the existing ClideHolderCard / folding machinery rather than building a new card.
- Grouping breaks when the file_path changes or a non-edit step interleaves (consecutive-same-file only), matching the ''subsequent edits to the same file'' wording.
- Parity with the existing meta/activity folding (T-230) — same collapse/expand affordance, just an edits-labelled run.

WORKED EXAMPLE (from user screenshot, clide_markdown.dart run): the current stream renders 11 stacked cards — 3x "Edit clide_markdown.dart", then a folded "Read … 2 steps" holder, then 7x "Edit clide_markdown.dart". With this feature it collapses to THREE cards:
- [3 edits]  (the first edit run)
- [2 steps]  (the existing Read holder — unchanged; this is what splits the edit run)
- [7 edits]  (the second edit run)
Confirms the split rule: an interleaving non-edit step (here the folded Read run) breaks the consecutive-same-file edit grouping into two separate edit cards. Same-file edits with nothing between them collapse into one "# edits" card.

STATUS INDICATOR (live tick reuse): the bundled edits card carries ONE header status indicator that reuses the existing per-step success tick, driven by the latest edit''s state:
- edit in flight  -> spinner
- edit completed  -> success check (the current green tick)
- next edit starts -> back to spinner
- ...repeat, settling on check when the final edit in the run completes (or the error glyph if one fails).
So the collapsed card''s indicator animates spinner<->check as the run grows, rather than showing a static tick. Each individual edit keeps its own tick in the expanded list (unchanged); this is the aggregate indicator on the holder header/ticker. Mirror the same treatment for the existing "# steps" activity card if it doesn''t already do this.', NULL, '2026-06-09 15:46:02', '2026-06-09 15:46:02', '2026-06-09 15:46:02', NULL, 'ac4da1997b2c2cba25b78ed97ba9e9be', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4GN07FN8GAXZ20YAR', 'status', 'ready', 'done', NULL, '2026-06-09 15:55:06', '2026-06-09 15:55:06', '2026-06-09 15:55:06', NULL, '2453f53a89cda92cea0734929c9d1a81', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM61SRVBDRFFN2S80T4', 'description', 'When the user pastes an image, the conversation panel echoes back the file path as plain text (e.g. @/home/.../paste-<ts>.png). We now have an image viewer card — render the pasted image inline using that card instead of (or in addition to) the bare path.

## Behaviour
- Detect a pasted-image path in the conversation stream and render the image viewer card.
- Still surface the file path (e.g. as a caption / subtitle on the card) so it can be copied/referenced.
- Reuse the existing image viewer card component rather than building a new one.

## Notes
- Applies to the Claude conversation panel rendering path.
- Consider failure cases: missing/deleted file, non-image paste, very large images.

CANCELLED as a duplicate of T-236 (2026-06-09). T-236 is the concrete spec for rendering pasted @path images inline in the Claude conversation; its scope now includes T-254''s path-as-caption nuance. Implement under T-236.

RETRACTED the cancellation — NOT a duplicate of T-236 (per user, 2026-06-09). Both stay open. T-254 remains its own ticket.', 'When the user pastes an image, the conversation panel echoes back the file path as plain text (e.g. @/home/.../paste-<ts>.png). We now have an image viewer card — render the pasted image inline using that card instead of (or in addition to) the bare path.

## Behaviour
- Detect a pasted-image path in the conversation stream and render the image viewer card.
- Still surface the file path (e.g. as a caption / subtitle on the card) so it can be copied/referenced.
- Reuse the existing image viewer card component rather than building a new one.

## Notes
- Applies to the Claude conversation panel rendering path.
- Consider failure cases: missing/deleted file, non-image paste, very large images.

CANCELLED as a duplicate of T-236 (2026-06-09). T-236 is the concrete spec for rendering pasted @path images inline in the Claude conversation; its scope now includes T-254''s path-as-caption nuance. Implement under T-236.

RETRACTED the cancellation — NOT a duplicate of T-236 (per user, 2026-06-09). Both stay open. T-254 remains its own ticket.

DONE 2026-06-09 — satisfied by D-89 together with T-236. The lightbox-expansion + path-retention (filename a11y label / unchanged copyText) intent from T-254 is delivered by the shared ImageThumbnail → lightbox; the chosen presentation is inline (not a separate card) per the user. See T-236 / D-89 / commit.', NULL, '2026-06-09 15:55:06', '2026-06-09 15:55:06', '2026-06-09 15:55:06', NULL, '592144661bfd762b61789f05d958cdd4', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4GN07FN8GAXZ20YAR', 'description', 'When a user message contains a pasted-screenshot reference — an @<path> token pointing at an image (the composer''s ComposerAttachment.pathToken format, e.g. @/home/<user>/.cache/clide/pasted/paste-<ts>.png, see screenshot) — the conversation log renders it as the raw path string. Show it as an inline THUMBNAIL instead.

The composer already renders pre-send attachments as Image.file thumbnail chips (clipboard_paste.dart + claude_composer _chip); this carries that into the post-send message log (UserMessage rendering in conversation_view/conversation_card).

Scope:
- When rendering UserMessage text, detect @<path> tokens; for image paths (reuse the extension check behind _looksLikeImage: .png/.jpg/.jpeg/.gif/.webp/.bmp), render a bounded Image.file thumbnail in place of the bare token. Surrounding prose still renders normally; a message can carry multiple tokens.
- Click/activate the thumbnail to open the full-size image (a preview dialog). Keyboard-operable + a11y label (filename).
- Graceful fallback: a missing/unreadable file (pasted temp files can be cleaned up) degrades to a small placeholder or the path text via Image.file errorBuilder — never a crash/exception.
- Non-image @path tokens MAY render as a file chip (filename + icon) like the composer, but image thumbnails are the focus.
- Note: Image.file reads the path directly via dart:io, so this is NOT gated by the files.read allow-list (D-80) — the cache dir is outside the workspace and that''s fine for display.
- Display-only: the text actually sent to Claude is unchanged; this only affects rendering.

Acceptance:
1. A user message with an @<path> image token shows an inline thumbnail in the log (not the raw path).
2. Clicking/activating the thumbnail opens the full image.
3. A missing/unreadable referenced file degrades to a placeholder (or the path text), no exception.
4. Prose and any non-image @path tokens around it still render readably; multiple tokens in one message all resolve.
5. The message content delivered to Claude is unchanged (render-only). Relates to T-142 (paste attachments).

MERGED T-254 (duplicate) into this ticket. Extra nuance carried over from T-254: keep the file path available (e.g. as a small caption/subtitle under the thumbnail, or via the lightbox) so it can still be copied/referenced. Reuse the existing inline image card + lightbox (T-252) rather than a new component.

RETRACTED the earlier ''merged T-254'' note — T-236 and T-254 are distinct tickets (per user); disregard that note. T-236 stays scoped to its own description.', 'When a user message contains a pasted-screenshot reference — an @<path> token pointing at an image (the composer''s ComposerAttachment.pathToken format, e.g. @/home/<user>/.cache/clide/pasted/paste-<ts>.png, see screenshot) — the conversation log renders it as the raw path string. Show it as an inline THUMBNAIL instead.

The composer already renders pre-send attachments as Image.file thumbnail chips (clipboard_paste.dart + claude_composer _chip); this carries that into the post-send message log (UserMessage rendering in conversation_view/conversation_card).

Scope:
- When rendering UserMessage text, detect @<path> tokens; for image paths (reuse the extension check behind _looksLikeImage: .png/.jpg/.jpeg/.gif/.webp/.bmp), render a bounded Image.file thumbnail in place of the bare token. Surrounding prose still renders normally; a message can carry multiple tokens.
- Click/activate the thumbnail to open the full-size image (a preview dialog). Keyboard-operable + a11y label (filename).
- Graceful fallback: a missing/unreadable file (pasted temp files can be cleaned up) degrades to a small placeholder or the path text via Image.file errorBuilder — never a crash/exception.
- Non-image @path tokens MAY render as a file chip (filename + icon) like the composer, but image thumbnails are the focus.
- Note: Image.file reads the path directly via dart:io, so this is NOT gated by the files.read allow-list (D-80) — the cache dir is outside the workspace and that''s fine for display.
- Display-only: the text actually sent to Claude is unchanged; this only affects rendering.

Acceptance:
1. A user message with an @<path> image token shows an inline thumbnail in the log (not the raw path).
2. Clicking/activating the thumbnail opens the full image.
3. A missing/unreadable referenced file degrades to a placeholder (or the path text), no exception.
4. Prose and any non-image @path tokens around it still render readably; multiple tokens in one message all resolve.
5. The message content delivered to Claude is unchanged (render-only). Relates to T-142 (paste attachments).

MERGED T-254 (duplicate) into this ticket. Extra nuance carried over from T-254: keep the file path available (e.g. as a small caption/subtitle under the thumbnail, or via the lightbox) so it can still be copied/referenced. Reuse the existing inline image card + lightbox (T-252) rather than a new component.

RETRACTED the earlier ''merged T-254'' note — T-236 and T-254 are distinct tickets (per user); disregard that note. T-236 stays scoped to its own description.

DONE 2026-06-09 — implemented as the hybrid (D-89): inline thumbnail in the message prose that opens the lightbox on click/Enter. New ImageThumbnail + openImageLightbox (lib/builtin/claude/src/image_thumbnail.dart); ClideMarkdown gained an onImageToken WidgetSpan seam. Missing file → placeholder; multiple tokens; non-image @path stays text; render-only (copyText unchanged). Composer chips reuse the same 44px thumbnail. Tests: image_thumbnail_test + conversation_view_test cases. Closes alongside T-254.', NULL, '2026-06-09 15:55:06', '2026-06-09 15:55:06', '2026-06-09 15:55:06', NULL, '8585bb4d9f6890c70777706d4225cef1', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM61SRVBDRFFN2S80T4', 'status', 'ready', 'done', NULL, '2026-06-09 15:55:06', '2026-06-09 15:55:06', '2026-06-09 15:55:06', NULL, '862cc2b139b96265c8d8d693f581e943', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM6RXN6HW6XTEHKYQDG', 'status', 'backlog', 'ready', NULL, '2026-06-09 16:01:58', '2026-06-09 16:01:58', '2026-06-09 16:01:58', NULL, '1caefc65216b108ebf53b512c21997a8', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM63TRGBFRWK9W2WA98', 'status', 'backlog', 'ready', NULL, '2026-06-09 16:02:14', '2026-06-09 16:02:14', '2026-06-09 16:02:14', NULL, '1ccbef8e24e7315c9f907940a2a6db1c', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM63TRGBFRWK9W2WA98', 'status', 'ready', 'done', NULL, '2026-06-09 16:34:46', '2026-06-09 16:34:46', '2026-06-09 16:34:46', NULL, '1ff5b1a09d01bbc6bf265c33dbdb8025', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM72SHY93S36VM9G6D8', 'status', 'ready', 'done', NULL, '2026-06-09 16:34:46', '2026-06-09 16:34:46', '2026-06-09 16:34:46', NULL, '550373b90ef92ee9bf9b298f303f3bef', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM6RXN6HW6XTEHKYQDG', 'description', 'When the bottom input area changes height, the conversation view does not re-scroll to the new viewport bottom, so the last bit of content is left hidden behind the newly-sized box.

Trigger: anything that resizes the bottom interaction zone (D-78) — e.g. opening a permission dialog or the AskUserQuestion UI, which replace/expand the composer. The taller box shrinks the conversation viewport from the bottom, but the scroll offset isn''t adjusted, so content that was at the bottom edge is now occluded.

Expected: when the interaction zone grows, the conversation re-anchors so the previously-visible bottom content stays visible above the box (preserve bottom-anchoring / keep the tail in view). Symmetric on shrink — no leftover gap when the box collapses back.

Repro:
1. Scroll the Claude conversation to the bottom (tail in view).
2. Trigger a permission prompt or AskUserQuestion (interaction zone expands).
3. Observed: a strip of the last message/card is hidden behind the enlarged input box.
4. Expected: view scrolls so that content remains fully visible above the box.

Notes:
- Likely the scroll controller doesn''t react to the composer/interaction-zone height change (no re-scroll on viewport-inset/size change). Audit the conversation view''s scroll handling around interaction-zone show/hide (D-78) and on keyboard/box resize.
- Affects the Claude conversation panel.', 'When the bottom input area changes height, the conversation view does not re-scroll to the new viewport bottom, so the last bit of content is left hidden behind the newly-sized box.

Trigger: anything that resizes the bottom interaction zone (D-78) — e.g. opening a permission dialog or the AskUserQuestion UI, which replace/expand the composer. The taller box shrinks the conversation viewport from the bottom, but the scroll offset isn''t adjusted, so content that was at the bottom edge is now occluded.

Expected: when the interaction zone grows, the conversation re-anchors so the previously-visible bottom content stays visible above the box (preserve bottom-anchoring / keep the tail in view). Symmetric on shrink — no leftover gap when the box collapses back.

Repro:
1. Scroll the Claude conversation to the bottom (tail in view).
2. Trigger a permission prompt or AskUserQuestion (interaction zone expands).
3. Observed: a strip of the last message/card is hidden behind the enlarged input box.
4. Expected: view scrolls so that content remains fully visible above the box.

Notes:
- Likely the scroll controller doesn''t react to the composer/interaction-zone height change (no re-scroll on viewport-inset/size change). Audit the conversation view''s scroll handling around interaction-zone show/hide (D-78) and on keyboard/box resize.
- Affects the Claude conversation panel.

DONE 2026-06-09 (commit). conversation_view tracks at-bottom + a LayoutBuilder re-jumps to the tail when the viewport height changes (interaction-zone resize, D-78), only when pinned. Tests: conversation_scroll_test.', NULL, '2026-06-09 16:34:46', '2026-06-09 16:34:46', '2026-06-09 16:34:46', NULL, '8c8361c593bce055c595ee3d6eca594c', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM63TRGBFRWK9W2WA98', 'description', 'When Claude makes multiple subsequent edits to the SAME file, bundle them into a single collapsed holder card instead of rendering each edit as its own card — mirroring how we already fold meta/activity runs.

Behaviour:
- Detect a run of consecutive edits targeting the same file_path and group them into one ClideHolderCard (the shared container from T-266; see _ActivityCard in lib/builtin/claude/src/conversation_view.dart:681).
- Collapsed (default): one-line ticker of the latest edit + a count label.
- Show the count as "# edits" (e.g. "3 edits" / "1 edit"), NOT "# steps". The existing activity card uses stepLabel = ''$count steps'' at conversation_view.dart:683; this run wants an edits-flavoured label.
- Expanded: every individual edit, each with its full report — bundle, do NOT drop or summarise away any information. All per-edit detail must remain reachable on expand.

Notes:
- Reuse the existing ClideHolderCard / folding machinery rather than building a new card.
- Grouping breaks when the file_path changes or a non-edit step interleaves (consecutive-same-file only), matching the ''subsequent edits to the same file'' wording.
- Parity with the existing meta/activity folding (T-230) — same collapse/expand affordance, just an edits-labelled run.

WORKED EXAMPLE (from user screenshot, clide_markdown.dart run): the current stream renders 11 stacked cards — 3x "Edit clide_markdown.dart", then a folded "Read … 2 steps" holder, then 7x "Edit clide_markdown.dart". With this feature it collapses to THREE cards:
- [3 edits]  (the first edit run)
- [2 steps]  (the existing Read holder — unchanged; this is what splits the edit run)
- [7 edits]  (the second edit run)
Confirms the split rule: an interleaving non-edit step (here the folded Read run) breaks the consecutive-same-file edit grouping into two separate edit cards. Same-file edits with nothing between them collapse into one "# edits" card.

STATUS INDICATOR (live tick reuse): the bundled edits card carries ONE header status indicator that reuses the existing per-step success tick, driven by the latest edit''s state:
- edit in flight  -> spinner
- edit completed  -> success check (the current green tick)
- next edit starts -> back to spinner
- ...repeat, settling on check when the final edit in the run completes (or the error glyph if one fails).
So the collapsed card''s indicator animates spinner<->check as the run grows, rather than showing a static tick. Each individual edit keeps its own tick in the expanded list (unchanged); this is the aggregate indicator on the holder header/ticker. Mirror the same treatment for the existing "# steps" activity card if it doesn''t already do this.', 'When Claude makes multiple subsequent edits to the SAME file, bundle them into a single collapsed holder card instead of rendering each edit as its own card — mirroring how we already fold meta/activity runs.

Behaviour:
- Detect a run of consecutive edits targeting the same file_path and group them into one ClideHolderCard (the shared container from T-266; see _ActivityCard in lib/builtin/claude/src/conversation_view.dart:681).
- Collapsed (default): one-line ticker of the latest edit + a count label.
- Show the count as "# edits" (e.g. "3 edits" / "1 edit"), NOT "# steps". The existing activity card uses stepLabel = ''$count steps'' at conversation_view.dart:683; this run wants an edits-flavoured label.
- Expanded: every individual edit, each with its full report — bundle, do NOT drop or summarise away any information. All per-edit detail must remain reachable on expand.

Notes:
- Reuse the existing ClideHolderCard / folding machinery rather than building a new card.
- Grouping breaks when the file_path changes or a non-edit step interleaves (consecutive-same-file only), matching the ''subsequent edits to the same file'' wording.
- Parity with the existing meta/activity folding (T-230) — same collapse/expand affordance, just an edits-labelled run.

WORKED EXAMPLE (from user screenshot, clide_markdown.dart run): the current stream renders 11 stacked cards — 3x "Edit clide_markdown.dart", then a folded "Read … 2 steps" holder, then 7x "Edit clide_markdown.dart". With this feature it collapses to THREE cards:
- [3 edits]  (the first edit run)
- [2 steps]  (the existing Read holder — unchanged; this is what splits the edit run)
- [7 edits]  (the second edit run)
Confirms the split rule: an interleaving non-edit step (here the folded Read run) breaks the consecutive-same-file edit grouping into two separate edit cards. Same-file edits with nothing between them collapse into one "# edits" card.

STATUS INDICATOR (live tick reuse): the bundled edits card carries ONE header status indicator that reuses the existing per-step success tick, driven by the latest edit''s state:
- edit in flight  -> spinner
- edit completed  -> success check (the current green tick)
- next edit starts -> back to spinner
- ...repeat, settling on check when the final edit in the run completes (or the error glyph if one fails).
So the collapsed card''s indicator animates spinner<->check as the run grows, rather than showing a static tick. Each individual edit keeps its own tick in the expanded list (unchanged); this is the aggregate indicator on the holder header/ticker. Mirror the same treatment for the existing "# steps" activity card if it doesn''t already do this.

DONE 2026-06-09 (commit). coalesceEditRuns folds consecutive same-file edits into one ''# edits'' ClideHolderCard; aggregate live status via new ClideStatusIndicator (running/success/error) + ClideSpinner (logo-mark, 3D Y rotation, reduced-motion aware), shared with the activity card. Per user: spinner is a self-contained component (not built on ConversationCard''s mark) with an AnimatedSwitcher seam for a richer spinner→check transition later. Tests: activity_cluster_test (coalesce), conversation_view_test (edits card), clide_status_indicator_test.', NULL, '2026-06-09 16:34:46', '2026-06-09 16:34:46', '2026-06-09 16:34:46', NULL, 'd4aed0a994dbdc503811e7c309e96f7c', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM6RXN6HW6XTEHKYQDG', 'status', 'ready', 'done', NULL, '2026-06-09 16:34:46', '2026-06-09 16:34:46', '2026-06-09 16:34:46', NULL, 'ed7b38da5bfea63147029d903cc57728', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM72SHY93S36VM9G6D8', 'description', 'Design and add collapse/expand controls for the left sidebar and the right context pane, along the lines of the reference screenshot (green arrows mark the two intended affordance locations — bottom-left of the sidebar and bottom-right of the context pane).

Scope of this ticket: set up a Frame0 mock to talk through the design before implementing.

Open questions to resolve in the mock:
- Affordance placement: footer/status-bar anchored (as the screenshot arrows suggest) vs. pane-edge chevron.
- Collapsed state: fully hidden vs. thin rail with a re-expand handle.
- Iconography (chevron direction) and hover/active states.
- Whether sidebar and context pane share one control pattern (parity) or differ.
- Keyboard/CLI parity (D-6): each collapse action needs a clide verb.

Deliverable: Frame0 wireframe(s) of collapsed + expanded states for both panes, reviewed before any code.

DESIGN DIRECTION (settled): anchor both toggles on the OUTER EDGES of the center (Claude conversation) pane — one on the left edge controlling the sidebar, one on the right edge controlling the context pane. The control stays fixed on the center-pane edge whether the adjacent pane is open or collapsed, so a single button both collapses an open pane and re-opens a collapsed one (chevron flips direction). This avoids needing a separate "re-expand" handle on the collapsed pane.

Implications for the mock:
- Collapsed pane can be fully hidden (no thin rail needed) since the re-open control lives on the center edge.
- Sidebar and context pane share one mirrored control pattern (parity).
- Chevron direction reflects state: points outward to expand, inward to collapse.

IMPLEMENTATION NOTE: the collapse logic already exists — no new toggle behaviour needed. Commands `sidebar.collapse` (ctrl+shift+1) and `context.collapse` (ctrl+shift+3) are registered in lib/builtin/default_layout/src/extension.dart, exposed in the command palette + menubar, and call arrangement.toggleCollapsed(Slots.sidebar|contextPanel), returning isCollapsed (D-051, D-054).

So this ticket is scoped to the VISUAL AFFORDANCE only:
- Add the two edge-anchored toggle buttons on the center (Claude) pane''s outer edges.
- On click, invoke the existing `sidebar.collapse` / `context.collapse` commands (do NOT reimplement collapse).
- Read arrangement.isCollapsed(...) to flip the chevron direction per state.
- D-6 CLI/keyboard parity is already satisfied by the existing commands; this adds the mouse affordance.

Mock: docs/design/wireframes/hud/pane-collapse-toggles.{json,png} — State A (open) + State B (collapsed).

PLACEMENT REVISED: toggles do NOT float vertically-centered on the pane edges. They live in the BOTTOM STATUS BAR. Each toggle is horizontally pinned to the center pane''s left/right edge, so when a pane collapses the toggle slides along the status bar to that end (open: at the inner pane boundary; collapsed: at the far status-bar end — matching where the reference-screenshot arrows pointed). Still mirrored left/right for parity; chevron flips per isCollapsed. Buttons invoke the existing sidebar.collapse / context.collapse commands.

Mock updated: docs/design/wireframes/hud/pane-collapse-toggles.{json,png}.

APPROVED (2026-06-09): pinned-to-edge status-bar placement confirmed by user. Design is settled; ready for implementation.

PLACEMENT FINAL (supersedes "pinned-to-edge"): toggles are FIXED at the far-left and far-right ends of the bottom status bar in every state. They do not slide with the pane edge. Position is constant (muscle memory; always where the reference-screenshot arrows pointed); only the chevron flips per isCollapsed. Left end = sidebar toggle, right end = context toggle. Mirrored for parity. Buttons invoke the existing sidebar.collapse / context.collapse commands.

Mock updated: docs/design/wireframes/hud/pane-collapse-toggles.{json,png}.

SPACE NOTE: the status bar already hosts content at both ends (left: branch / skills count; right: Output / terminal). Fixed-end toggles therefore share that space. Resolution: reserve the OUTERMOST ~24px cell at each end for the toggle and shift the existing status items inward by that width — a constant reservation, not a dynamic fight (the toggle never moves or grows). The mock reflects this: status text begins after the left toggle and ends before the right toggle.

GLYPH DECISION: use Phosphor caret-line icons (chevron + edge line), which read as "collapse to the edge":
- caret-line-left  -> 0xe132 (CaretLineLeft)
- caret-line-right -> 0xe130 (CaretLineRight)
The glyphs already ship in assets/fonts/phosphor (codepoints.csv lines 150-151) — no new dependency. Add two consts to lib/widgets/src/icons/phosphor.dart (PhosphorIcons.caretLineLeft / caretLineRight) during implementation. Chevron-line direction flips per isCollapsed.

RESOLUTION (2026-06-09): considered moving the re-open control into the center (pane edge or center status segment) to dodge the end-of-bar space contention; user chose to KEEP TOGGLES FIXED AT THE STATUS-BAR ENDS (best muscle memory). Final design = v3 mock: caret-line glyphs at fixed far-left/far-right status-bar cells (~24px reserved, side items shifted in), chevron-line flips per isCollapsed, firing existing sidebar.collapse / context.collapse. Design fully settled; ready to implement.', 'Design and add collapse/expand controls for the left sidebar and the right context pane, along the lines of the reference screenshot (green arrows mark the two intended affordance locations — bottom-left of the sidebar and bottom-right of the context pane).

Scope of this ticket: set up a Frame0 mock to talk through the design before implementing.

Open questions to resolve in the mock:
- Affordance placement: footer/status-bar anchored (as the screenshot arrows suggest) vs. pane-edge chevron.
- Collapsed state: fully hidden vs. thin rail with a re-expand handle.
- Iconography (chevron direction) and hover/active states.
- Whether sidebar and context pane share one control pattern (parity) or differ.
- Keyboard/CLI parity (D-6): each collapse action needs a clide verb.

Deliverable: Frame0 wireframe(s) of collapsed + expanded states for both panes, reviewed before any code.

DESIGN DIRECTION (settled): anchor both toggles on the OUTER EDGES of the center (Claude conversation) pane — one on the left edge controlling the sidebar, one on the right edge controlling the context pane. The control stays fixed on the center-pane edge whether the adjacent pane is open or collapsed, so a single button both collapses an open pane and re-opens a collapsed one (chevron flips direction). This avoids needing a separate "re-expand" handle on the collapsed pane.

Implications for the mock:
- Collapsed pane can be fully hidden (no thin rail needed) since the re-open control lives on the center edge.
- Sidebar and context pane share one mirrored control pattern (parity).
- Chevron direction reflects state: points outward to expand, inward to collapse.

IMPLEMENTATION NOTE: the collapse logic already exists — no new toggle behaviour needed. Commands `sidebar.collapse` (ctrl+shift+1) and `context.collapse` (ctrl+shift+3) are registered in lib/builtin/default_layout/src/extension.dart, exposed in the command palette + menubar, and call arrangement.toggleCollapsed(Slots.sidebar|contextPanel), returning isCollapsed (D-051, D-054).

So this ticket is scoped to the VISUAL AFFORDANCE only:
- Add the two edge-anchored toggle buttons on the center (Claude) pane''s outer edges.
- On click, invoke the existing `sidebar.collapse` / `context.collapse` commands (do NOT reimplement collapse).
- Read arrangement.isCollapsed(...) to flip the chevron direction per state.
- D-6 CLI/keyboard parity is already satisfied by the existing commands; this adds the mouse affordance.

Mock: docs/design/wireframes/hud/pane-collapse-toggles.{json,png} — State A (open) + State B (collapsed).

PLACEMENT REVISED: toggles do NOT float vertically-centered on the pane edges. They live in the BOTTOM STATUS BAR. Each toggle is horizontally pinned to the center pane''s left/right edge, so when a pane collapses the toggle slides along the status bar to that end (open: at the inner pane boundary; collapsed: at the far status-bar end — matching where the reference-screenshot arrows pointed). Still mirrored left/right for parity; chevron flips per isCollapsed. Buttons invoke the existing sidebar.collapse / context.collapse commands.

Mock updated: docs/design/wireframes/hud/pane-collapse-toggles.{json,png}.

APPROVED (2026-06-09): pinned-to-edge status-bar placement confirmed by user. Design is settled; ready for implementation.

PLACEMENT FINAL (supersedes "pinned-to-edge"): toggles are FIXED at the far-left and far-right ends of the bottom status bar in every state. They do not slide with the pane edge. Position is constant (muscle memory; always where the reference-screenshot arrows pointed); only the chevron flips per isCollapsed. Left end = sidebar toggle, right end = context toggle. Mirrored for parity. Buttons invoke the existing sidebar.collapse / context.collapse commands.

Mock updated: docs/design/wireframes/hud/pane-collapse-toggles.{json,png}.

SPACE NOTE: the status bar already hosts content at both ends (left: branch / skills count; right: Output / terminal). Fixed-end toggles therefore share that space. Resolution: reserve the OUTERMOST ~24px cell at each end for the toggle and shift the existing status items inward by that width — a constant reservation, not a dynamic fight (the toggle never moves or grows). The mock reflects this: status text begins after the left toggle and ends before the right toggle.

GLYPH DECISION: use Phosphor caret-line icons (chevron + edge line), which read as "collapse to the edge":
- caret-line-left  -> 0xe132 (CaretLineLeft)
- caret-line-right -> 0xe130 (CaretLineRight)
The glyphs already ship in assets/fonts/phosphor (codepoints.csv lines 150-151) — no new dependency. Add two consts to lib/widgets/src/icons/phosphor.dart (PhosphorIcons.caretLineLeft / caretLineRight) during implementation. Chevron-line direction flips per isCollapsed.

RESOLUTION (2026-06-09): considered moving the re-open control into the center (pane edge or center status segment) to dodge the end-of-bar space contention; user chose to KEEP TOGGLES FIXED AT THE STATUS-BAR ENDS (best muscle memory). Final design = v3 mock: caret-line glyphs at fixed far-left/far-right status-bar cells (~24px reserved, side items shifted in), chevron-line flips per isCollapsed, firing existing sidebar.collapse / context.collapse. Design fully settled; ready to implement.

DONE 2026-06-09 (commit). Fixed ~24px caret-line toggles bookend the status bar (StatusbarHost), flip chevron per arrangement.isCollapsed, fire existing sidebar.collapse/context.collapse. Visual affordance only. Tests: app_collapse_toggle_test + updated app_statusbar_test.', NULL, '2026-06-09 16:34:46', '2026-06-09 16:34:46', '2026-06-09 16:34:46', NULL, 'ef47660ba615407e22a179e30866d85a', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7W0NPAEG3KWNFY9DR', 'status', 'backlog', 'ready', NULL, '2026-06-09 16:54:28', '2026-06-09 16:54:28', '2026-06-09 16:54:28', NULL, '7cfb52c0de285d0cf5230a72b27dfd35', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM531VE0C6N36AT12SR', 'status', 'backlog', 'ready', NULL, '2026-06-09 16:55:49', '2026-06-09 16:55:49', '2026-06-09 16:55:49', NULL, 'f9fadc88a5e4ee925e7972f3389bcd16', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM53HQD6YV754GKBA60', 'status', 'backlog', 'done', NULL, '2026-06-09 16:56:55', '2026-06-09 16:56:55', '2026-06-09 16:56:55', NULL, 'fb4a56615b5e1e64c5cf6d12d9a3ee60', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4AE2GEF6BXSGKRMGC', 'status', 'backlog', 'ready', NULL, '2026-06-09 16:57:16', '2026-06-09 16:57:16', '2026-06-09 16:57:16', NULL, '8bba7559aeefd3fcdccacc7f7fa7a09b', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4BRWWPB4R06Q31XV0', 'status', 'backlog', 'ready', NULL, '2026-06-09 16:57:23', '2026-06-09 16:57:23', '2026-06-09 16:57:23', NULL, 'ddb373332db2254e04fdda13cca96f94', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5QJC039TMDF5JGMXC', 'status', 'backlog', 'ready', NULL, '2026-06-09 16:57:35', '2026-06-09 16:57:35', '2026-06-09 16:57:35', NULL, '5501d1a65c21a3448d0ce1a1522cc90d', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM42VPM50VKAWXBCAM8', 'status', 'backlog', 'ready', NULL, '2026-06-09 16:58:12', '2026-06-09 16:58:12', '2026-06-09 16:58:12', NULL, '6277911a72c6774b5692c9af3a2402c5', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7W0NPAEG3KWNFY9DR', 'status', 'ready', 'in_progress', NULL, '2026-06-09 17:06:47', '2026-06-09 17:06:47', '2026-06-09 17:06:47', NULL, '03f03880fba3cfc2ddb335cde60b2dfb', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7W0NPAEG3KWNFY9DR', 'description', 'Replace the terminal-based Claude pane with native rendering driven by Claude Code''s transcript JSONL (with cross-widget text selection), and surface experimental tmux agent teams (lead + teammates) as tiled native panels plus a team-meta sidebar. The terminal is retained only as a general IDE tool.

Why:
1. No cross-widget text selection/copy in clide''s native widgets today (regression vs a terminal).
2. PTY/TUI rendering is the fragile, OS-variant part of the Claude pane.
3. Claude Code''s experimental tmux team mode (lead + N teammates, each a tmux pane) is the flagship capability to surface as real GUI panels, not scraped TUI.

Direction: run Claude headless in tmux; render its conversation natively from the transcript JSONL; lead panel (left, with composer) + teammate tiles (right) in a responsive auto-wrap grid (1->2->3 cols); team-meta sidebar with roster + token budget.

Principle: Claude-centric first, CLI-first (D-6) a strong second. Accept isolated, version-pinned coupling to Claude Code internal contracts where it serves the Claude integration; preserve CLI/event surfaces where sensible.

Acceptance: all child tickets done; D-record landed; Claude pane renders natively with working select+copy and no terminal; a tmux team surfaces as lead + auto-wrapping teammate tiles + meta sidebar; all fragile CC-internals parsing isolated and version-pinned.

Source: plan iridescent-tinkering-umbrella (2026-05-22), grounded in an-idea.md + read-only validation of the transcript schema this session.', 'Replace the terminal-based Claude pane with native rendering driven by Claude Code''s transcript JSONL (with cross-widget text selection), and surface experimental tmux agent teams (lead + teammates) as tiled native panels plus a team-meta sidebar. The terminal is retained only as a general IDE tool.

Why:
1. No cross-widget text selection/copy in clide''s native widgets today (regression vs a terminal).
2. PTY/TUI rendering is the fragile, OS-variant part of the Claude pane.
3. Claude Code''s experimental tmux team mode (lead + N teammates, each a tmux pane) is the flagship capability to surface as real GUI panels, not scraped TUI.

Direction: run Claude headless in tmux; render its conversation natively from the transcript JSONL; lead panel (left, with composer) + teammate tiles (right) in a responsive auto-wrap grid (1->2->3 cols); team-meta sidebar with roster + token budget.

Principle: Claude-centric first, CLI-first (D-6) a strong second. Accept isolated, version-pinned coupling to Claude Code internal contracts where it serves the Claude integration; preserve CLI/event surfaces where sensible.

Acceptance: all child tickets done; D-record landed; Claude pane renders natively with working select+copy and no terminal; a tmux team surfaces as lead + auto-wrapping teammate tiles + meta sidebar; all fragile CC-internals parsing isolated and version-pinned.

Source: plan iridescent-tinkering-umbrella (2026-05-22), grounded in an-idea.md + read-only validation of the transcript schema this session.

STATUS CORRECTED (2026-06-09): not superseded — substantially DELIVERED. 32/34 children done; the native Claude pane (transcript rendering, select/copy, no terminal), tmux team tiles + meta sidebar, composer, and D-75 all shipped. Re-flagged from ''ready'' (misleading — no startable work) to in_progress. Remaining, both non-blocking, kept under this epic: T-158 (team/account token budget — blocked on upstream /usage exposure) and T-235 (persist activity-card fold level, T-230 follow-up). Close when those land.', NULL, '2026-06-09 17:06:47', '2026-06-09 17:06:47', '2026-06-09 17:06:47', NULL, '1d1c8e343c2faf4f4ec24bd8abdf91c7', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7D5DMYF5X92Q55CBW', 'description', 'Follow-up to T-230. The activity-card fold level is implemented as a switchable ConversationView.foldLevel parameter (FoldLevel none/tools/thinking/everything; groupConversation re-groups per level, unit-tested), but the live Claude pane currently uses the L1 default with no way for the user to change it. Finish acceptance #4: (1) read the fold level from a persisted user setting (via ctx.settings / the kernel settings service — see how other builtins read settings), defaulting to L1; (2) add a control to change it (e.g. a command ''claude.activity.fold-level'' cycling none->L1->L2->L3, and/or an entry in the Claude/settings UI); (3) thread it into the ConversationView built in claude_pane.dart (and team_panel_host.dart). The grouping + card + a11y are already done in activity_cluster.dart + conversation_view.dart.', 'Follow-up to T-230. The activity-card fold level is implemented as a switchable ConversationView.foldLevel parameter (FoldLevel none/tools/thinking/everything; groupConversation re-groups per level, unit-tested), but the live Claude pane currently uses the L1 default with no way for the user to change it. Finish acceptance #4: (1) read the fold level from a persisted user setting (via ctx.settings / the kernel settings service — see how other builtins read settings), defaulting to L1; (2) add a control to change it (e.g. a command ''claude.activity.fold-level'' cycling none->L1->L2->L3, and/or an entry in the Claude/settings UI); (3) thread it into the ConversationView built in claude_pane.dart (and team_panel_host.dart). The grouping + card + a11y are already done in activity_cluster.dart + conversation_view.dart.

DONE 2026-06-09. Persisted app-scoped setting kActivityFoldLevelKey (app.claude.activityFoldLevel); command claude.activity.fold-level cycles none→tools→thinking→everything (foldLevelFromName/nextFoldLevel in activity_cluster.dart); ClaudePane + team_panel_host read the setting and re-fold live via the settings notifier. Tests: foldLevelFromName/nextFoldLevel in activity_cluster_test.', NULL, '2026-06-09 17:16:33', '2026-06-09 17:16:33', '2026-06-09 17:16:33', NULL, 'b9f41312692ede5ad66e99200c785b91', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM62FKQQD0B9B80PFY4', 'parent_id', 'T-132', NULL, NULL, '2026-06-09 17:16:34', '2026-06-09 17:16:34', '2026-06-09 17:16:34', NULL, '1077ce81ca0eb879dcd1a6445d3de6e6', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM62FKQQD0B9B80PFY4', 'description', 'Show the account/subscription usage budget (5-hour + weekly limits, % used, reset times) in the Claude meta sidebar (T-141). BLOCKED: this data is not programmatically exposed under subscription (OAuth) auth as of claude 2.1.150 — verified empirically + via docs (2026-05-23). /usage is TUI-only (headless ''claude -p /usage'' returns only a one-liner); stats-cache.json has activity counts only; the stream-json rate_limit_event is undocumented + needs a billed turn; ''claude auth status --json'' shows plan only. A ''claude usage --json'' + a /v1/organizations/{org}/usage/subscription endpoint are an OPEN, unshipped feature request (GitHub anthropics/claude-code#44328). Revisit when #44328 ships or an API-key usage path exists. See project memory ''claude-usage-budget-not-exposed''.', 'Show the account/subscription usage budget (5-hour + weekly limits, % used, reset times) in the Claude meta sidebar (T-141). BLOCKED: this data is not programmatically exposed under subscription (OAuth) auth as of claude 2.1.150 — verified empirically + via docs (2026-05-23). /usage is TUI-only (headless ''claude -p /usage'' returns only a one-liner); stats-cache.json has activity counts only; the stream-json rate_limit_event is undocumented + needs a billed turn; ''claude auth status --json'' shows plan only. A ''claude usage --json'' + a /v1/organizations/{org}/usage/subscription endpoint are an OPEN, unshipped feature request (GitHub anthropics/claude-code#44328). Revisit when #44328 ships or an API-key usage path exists. See project memory ''claude-usage-budget-not-exposed''.

2026-06-09: detached from T-132 (which is otherwise complete) and made the RESOLVER ticket for Q-34 (how + when to surface the budget given upstream doesn''t expose it). Stays in the backlog; revisit when a viable data path lands (upstream claude usage --json / endpoint per anthropics/claude-code#44328, or an API-key usage path).', NULL, '2026-06-09 17:16:34', '2026-06-09 17:16:34', '2026-06-09 17:16:34', NULL, '504b382920e7b07cafc1da32738625c6', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7D5DMYF5X92Q55CBW', 'status', 'backlog', 'done', NULL, '2026-06-09 17:16:34', '2026-06-09 17:16:34', '2026-06-09 17:16:34', NULL, 'cbab9b537913971dba5e335d55928673', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7W0NPAEG3KWNFY9DR', 'description', 'Replace the terminal-based Claude pane with native rendering driven by Claude Code''s transcript JSONL (with cross-widget text selection), and surface experimental tmux agent teams (lead + teammates) as tiled native panels plus a team-meta sidebar. The terminal is retained only as a general IDE tool.

Why:
1. No cross-widget text selection/copy in clide''s native widgets today (regression vs a terminal).
2. PTY/TUI rendering is the fragile, OS-variant part of the Claude pane.
3. Claude Code''s experimental tmux team mode (lead + N teammates, each a tmux pane) is the flagship capability to surface as real GUI panels, not scraped TUI.

Direction: run Claude headless in tmux; render its conversation natively from the transcript JSONL; lead panel (left, with composer) + teammate tiles (right) in a responsive auto-wrap grid (1->2->3 cols); team-meta sidebar with roster + token budget.

Principle: Claude-centric first, CLI-first (D-6) a strong second. Accept isolated, version-pinned coupling to Claude Code internal contracts where it serves the Claude integration; preserve CLI/event surfaces where sensible.

Acceptance: all child tickets done; D-record landed; Claude pane renders natively with working select+copy and no terminal; a tmux team surfaces as lead + auto-wrapping teammate tiles + meta sidebar; all fragile CC-internals parsing isolated and version-pinned.

Source: plan iridescent-tinkering-umbrella (2026-05-22), grounded in an-idea.md + read-only validation of the transcript schema this session.

STATUS CORRECTED (2026-06-09): not superseded — substantially DELIVERED. 32/34 children done; the native Claude pane (transcript rendering, select/copy, no terminal), tmux team tiles + meta sidebar, composer, and D-75 all shipped. Re-flagged from ''ready'' (misleading — no startable work) to in_progress. Remaining, both non-blocking, kept under this epic: T-158 (team/account token budget — blocked on upstream /usage exposure) and T-235 (persist activity-card fold level, T-230 follow-up). Close when those land.', 'Replace the terminal-based Claude pane with native rendering driven by Claude Code''s transcript JSONL (with cross-widget text selection), and surface experimental tmux agent teams (lead + teammates) as tiled native panels plus a team-meta sidebar. The terminal is retained only as a general IDE tool.

Why:
1. No cross-widget text selection/copy in clide''s native widgets today (regression vs a terminal).
2. PTY/TUI rendering is the fragile, OS-variant part of the Claude pane.
3. Claude Code''s experimental tmux team mode (lead + N teammates, each a tmux pane) is the flagship capability to surface as real GUI panels, not scraped TUI.

Direction: run Claude headless in tmux; render its conversation natively from the transcript JSONL; lead panel (left, with composer) + teammate tiles (right) in a responsive auto-wrap grid (1->2->3 cols); team-meta sidebar with roster + token budget.

Principle: Claude-centric first, CLI-first (D-6) a strong second. Accept isolated, version-pinned coupling to Claude Code internal contracts where it serves the Claude integration; preserve CLI/event surfaces where sensible.

Acceptance: all child tickets done; D-record landed; Claude pane renders natively with working select+copy and no terminal; a tmux team surfaces as lead + auto-wrapping teammate tiles + meta sidebar; all fragile CC-internals parsing isolated and version-pinned.

Source: plan iridescent-tinkering-umbrella (2026-05-22), grounded in an-idea.md + read-only validation of the transcript schema this session.

STATUS CORRECTED (2026-06-09): not superseded — substantially DELIVERED. 32/34 children done; the native Claude pane (transcript rendering, select/copy, no terminal), tmux team tiles + meta sidebar, composer, and D-75 all shipped. Re-flagged from ''ready'' (misleading — no startable work) to in_progress. Remaining, both non-blocking, kept under this epic: T-158 (team/account token budget — blocked on upstream /usage exposure) and T-235 (persist activity-card fold level, T-230 follow-up). Close when those land.

CLOSED 2026-06-09: all doable work delivered (native Claude pane, transcript rendering, select/copy, no terminal, tmux team tiles + meta sidebar, composer, activity-card folding incl. the persisted fold level T-235, D-75). The one blocked item — account/team token budget — was detached (T-158) and reframed as Q-34 (how + when to surface it given upstream doesn''t expose the data); T-158 is the resolver, parked in the backlog. Nothing actionable remains under this epic.', NULL, '2026-06-09 17:23:25', '2026-06-09 17:23:25', '2026-06-09 17:23:25', NULL, '749ec9a3224d1ae1c9661a37c05da4da', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7W0NPAEG3KWNFY9DR', 'status', 'in_progress', 'done', NULL, '2026-06-09 17:23:25', '2026-06-09 17:23:25', '2026-06-09 17:23:25', NULL, 'eadab6091961f410df29809647ee6574', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7F2TBJJV1F2KP7XR8', 'parent_id', NULL, 'T-276', NULL, '2026-06-09 20:02:53', '2026-06-09 20:02:53', '2026-06-09 20:02:53', NULL, '9a44220eef05245a83e53df6d32f9a13', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7F2TBJJV1F2KP7XR8', 'description', NULL, 'Make file-path references rendered in the Claude conversation pane clickable: clicking a path opens that file in the editor.

**Behavior**
- Detect references to files in the workspace as the conversation markdown is rendered — bare paths (`lib/app.dart`), `file:line` forms (`lib/app.dart:42`, clickable per CLAUDE.md), and likely inline-code spans / markdown links pointing at repo paths.
- Resolve against the workspace root (CLIDE_WORKSPACE / git repo root). Only linkify paths that exist in the repo to avoid false positives on prose.
- On click, open in the editor — same path as `clide editor open <path>` — and jump to the line when a `:line` suffix is present.

**Notes / constraints**
- Markdown rendering is clide-owned custom CustomPaint/widgets (not a package), so detection + hit-testing lands in the conversation/markdown render path.
- Honors User/Claude parity (D-6): the click maps to the existing `clide editor open` verb.
- Open questions to settle during design: how aggressive path detection should be (existence check vs. heuristic), handling of non-existent / external paths, and visual affordance (underline/hover) for a linkified ref.', NULL, '2026-06-09 20:03:08', '2026-06-09 20:03:08', '2026-06-09 20:03:08', NULL, '5e7b2e6008889f0624ed204c97fc718b', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM6048VEGFDNEBHFMM4', 'parent_id', NULL, 'T-276', NULL, '2026-06-09 20:04:31', '2026-06-09 20:04:31', '2026-06-09 20:04:31', NULL, '818820d6c1dc1b3b8d0c60096d0025f4', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM6048VEGFDNEBHFMM4', 'description', NULL, 'When file paths to files inside the current repo appear in the Claude conversation, show them relative to the repo root rather than as absolute paths.

**DESIGN OPEN — needs discussion before implementation.** The exact presentation is undecided.

**Intent**
- Paths that resolve inside the workspace (CLIDE_WORKSPACE / git repo root) should read as repo-relative (e.g. `lib/app.dart` instead of `/var/mnt/data/projects/clide/lib/app.dart`).
- Goal is readability — strip the absolute prefix that''s noise for in-repo files.

**Open questions to settle in discussion**
- Visual treatment: silently rewrite the displayed text? show relative with the absolute available on hover/tooltip? a leading marker (e.g. `./` or a repo-root glyph)?
- Scope: only linkified/recognized refs (ties to T-300), or any path-looking token in the rendered output?
- Out-of-repo / absolute paths: leave untouched, or abbreviate (e.g. `~`)?
- Interaction with copy: does copying yield the relative or the original absolute path?
- Does this happen at render time only, or is the underlying text also normalized?

**Related**
- Pairs with T-300 (clickable file references) — same conversation/markdown render path; likely share path-detection + workspace-root resolution.', NULL, '2026-06-09 20:04:54', '2026-06-09 20:04:54', '2026-06-09 20:04:54', NULL, '8ecbd1bca77bd64222112c780fa216b4', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4AE2GEF6BXSGKRMGC', 'description', NULL, 'VERIFIED DONE 2026-06-09: failures-only is the default reporter across all gate scripts — ci/test.sh (REPORTER var, used in every flutter/dart test invocation), ci/test_core.sh, ci/test_a11y.sh — each with a TEST_REPORTER=expanded escape hatch for debugging. No work remaining.', NULL, '2026-06-09 20:07:29', '2026-06-09 20:07:29', '2026-06-09 20:07:29', NULL, '29dd32588e4378ba0d0f4ba0ac104bfd', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4AE2GEF6BXSGKRMGC', 'status', 'ready', 'done', NULL, '2026-06-09 20:07:30', '2026-06-09 20:07:30', '2026-06-09 20:07:30', NULL, '23b91495413b8ba1b00291c6f22541d8', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM42VPM50VKAWXBCAM8', 'status', 'ready', 'done', NULL, '2026-06-09 20:17:04', '2026-06-09 20:17:04', '2026-06-09 20:17:04', NULL, '3c82a7b65e8d1c68ea241aa9a0a4e6dd', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM42VPM50VKAWXBCAM8', 'description', 'The Claude conversation panel detects URLs and colorizes them, but they are not interactive. Make detected links clickable (a plain click, or control/cmd-click) so they are handed off to the OS URL opener.

## Behaviour
- Click (or ctrl/cmd-click) on a colorized link opens it via the OS default handler.
- Hover affordance (cursor change / underline) so it reads as clickable.
- Keep the existing colorization.

## Notes
- Honour user/Claude parity (D-6) where relevant.
- Use the platform URL launcher; avoid pulling in an opinionated package if a thin native/url_launcher shim already exists in the tree.
- Guard against non-http schemes / malformed URLs.', 'The Claude conversation panel detects URLs and colorizes them, but they are not interactive. Make detected links clickable (a plain click, or control/cmd-click) so they are handed off to the OS URL opener.

## Behaviour
- Click (or ctrl/cmd-click) on a colorized link opens it via the OS default handler.
- Hover affordance (cursor change / underline) so it reads as clickable.
- Keep the existing colorization.

## Notes
- Honour user/Claude parity (D-6) where relevant.
- Use the platform URL launcher; avoid pulling in an opinionated package if a thin native/url_launcher shim already exists in the tree.
- Guard against non-http schemes / malformed URLs.

DONE 2026-06-09. http(s) links in the conversation open via OsBridge.openURL on click (hover underline + pointer); non-http inert. ClideMarkdown gained an onLinkTap hook + _urlLinkSpan; the 3 inline-interaction callbacks were bundled into ClideMarkdownHooks (single threaded param) — also fixed links/images only working in some markdown contexts. Tests: clide_markdown_test.', NULL, '2026-06-09 20:17:04', '2026-06-09 20:17:04', '2026-06-09 20:17:04', NULL, 'bcf049444a57e41061b1b9adeeb7b058', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7H8JWCP59WQVD0FW4', 'parent_id', NULL, 'T-8', NULL, '2026-06-09 20:24:57', '2026-06-09 20:24:57', '2026-06-09 20:24:57', NULL, 'd7dfe7ec18b8657bf2ca96f2ca0d75f2', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7H8JWCP59WQVD0FW4', 'description', NULL, 'Design the app''s settings screen as a Frame0 wireframe before building `builtin.settings-ui` (see Tier 6 epic T-8). Output is a wireframe to align on layout/IA, not implementation.

**Deliverable**
- Frame0 wireframe authored via the frame0-wireframe skill: local JSON source-of-truth synced to Frame0, exported for review.
- Covers the settings screen shell + at least one fully-rendered category so the form-field patterns are concrete.

**Scope to frame (from T-8)**
- Schema-driven panel: form fields keyed off the schema each subsystem registers against the kernel SettingsStore; edits write back to `.clide/settings.yaml`.
- Navigation/IA: how categories are grouped and selected (sidebar list? sections? search?).
- Field types to mock: toggle, enum/select (e.g. keymap preset), text/number, and a ''opens external file'' affordance (e.g. editor `.editorconfig` per T-290).
- Known consumers to account for: keymap preset switching (T-115/T-64/T-65/T-66), editor settings (T-290), activity fold level (T-183), theme picker (Tier 6 theming UI).

**Open design questions for the wireframe to answer**
- Settings as a full-screen view, a pane/tab, or a modal?
- Per-project (`.clide/settings.yaml`) vs. user-global scope — shown together or switched?
- Search/filter across all settings.
- How schema-driven fields render labels, help text, defaults, and reset.

**Constraints**
- Follow clide visual language — pull theme tokens / control geometry from the ui-design skill so the wireframe maps cleanly to real widgets (no Material/Cupertino).

This is the design step; implementation of the actual settings UI is separate child work under T-8.', NULL, '2026-06-09 20:25:49', '2026-06-09 20:25:49', '2026-06-09 20:25:49', NULL, '1d0b97bd0ad807733f995ee05eb9d2f2', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM6SK3D1QYACBPHHBZ0', 'description', 'On Linux desktop startup, two GLib-GIO-CRITICAL warnings fire to stderr:

  GLib-GIO-CRITICAL: GFileInfo created without standard::size
  file ../gio/gfileinfo.c: line 1865 (g_file_info_get_size): should not be reached

Repro: launch the app (make run / flutter run) on Linux. The pair fires early in boot — right after the primary pane binds its session and before the IPC server starts listening (observed ~0.3s apart, e.g. 15:53:15.570 and 15:53:15.832), on every launch.

Cause: some code path calls g_file_info_get_size() on a GFileInfo that was created/queried WITHOUT requesting the G_FILE_ATTRIBUTE_STANDARD_SIZE (''standard::size'') attribute. A grep of clide''s own code (lib/, linux/runner/, native/) finds no direct g_file_info / g_file_query_info usage, so it is most likely inside GTK/GLib itself or a Flutter Linux plugin''s file enumeration (icon/thumbnail/mime probe, path lookups), not clide Dart/C++. The GTK file-chooser in linux/runner/clide_app.cc is on-demand only, so it is not the trigger (the warnings fire at boot).

Impact: low — console noise at CRITICAL level; no observed functional breakage. But a size query that ''should not be reached'' may be reading a bogus/zero size somewhere worth confirming.

Investigation: run with G_DEBUG=fatal-warnings (or gdb break on g_log/g_logv) to capture the stack at the warning and identify the library/plugin frame; check whether a Flutter plugin (file_selector, path_provider, url_launcher) or GTK icon/mime loading is responsible. If upstream/GTK, document + suppress-from-our-side or pin; if a plugin, file upstream.

Env: Fedora, GTK Linux embedder, flutter run.', 'On Linux desktop startup, two GLib-GIO-CRITICAL warnings fire to stderr:

  GLib-GIO-CRITICAL: GFileInfo created without standard::size
  file ../gio/gfileinfo.c: line 1865 (g_file_info_get_size): should not be reached

Repro: launch the app (make run / flutter run) on Linux. The pair fires early in boot — right after the primary pane binds its session and before the IPC server starts listening (observed ~0.3s apart, e.g. 15:53:15.570 and 15:53:15.832), on every launch.

Cause: some code path calls g_file_info_get_size() on a GFileInfo that was created/queried WITHOUT requesting the G_FILE_ATTRIBUTE_STANDARD_SIZE (''standard::size'') attribute. A grep of clide''s own code (lib/, linux/runner/, native/) finds no direct g_file_info / g_file_query_info usage, so it is most likely inside GTK/GLib itself or a Flutter Linux plugin''s file enumeration (icon/thumbnail/mime probe, path lookups), not clide Dart/C++. The GTK file-chooser in linux/runner/clide_app.cc is on-demand only, so it is not the trigger (the warnings fire at boot).

Impact: low — console noise at CRITICAL level; no observed functional breakage. But a size query that ''should not be reached'' may be reading a bogus/zero size somewhere worth confirming.

Investigation: run with G_DEBUG=fatal-warnings (or gdb break on g_log/g_logv) to capture the stack at the warning and identify the library/plugin frame; check whether a Flutter plugin (file_selector, path_provider, url_launcher) or GTK icon/mime loading is responsible. If upstream/GTK, document + suppress-from-our-side or pin; if a plugin, file upstream.

Env: Fedora, GTK Linux embedder, flutter run.

UPDATE (2026-06-09): also fires MID-SESSION, not only at boot — contradicts the "fires early in boot, on every launch" framing above. Observed log: app booted 16:47:01, but the GLib-GIO-CRITICAL pair fired at 18:51:07.841 / 18:51:08.190 (~2h into the session), near pane/session activity. So the trigger is more likely a file-info code path tied to a user action or background file enumeration than pure startup. Re-scope the investigation to capture the stack when it fires mid-session (G_DEBUG=fatal-warnings / gdb break on g_log) rather than only at boot.', NULL, '2026-06-09 20:26:44', '2026-06-09 20:26:44', '2026-06-09 20:26:44', NULL, '4cdfa1f8240ffeba7dd710712405f482', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5QJC039TMDF5JGMXC', 'status', 'ready', 'done', NULL, '2026-06-09 20:27:17', '2026-06-09 20:27:17', '2026-06-09 20:27:17', NULL, '894a8c8c0863f2abe160f610a2f85215', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5QJC039TMDF5JGMXC', 'description', 'Muscle-memory gap from the Claude Code CLI: in clide''s interaction-zone prompts (D-78), the user reaches for number keys 1/2/3 to pick a button but has to click. Map number keys (1..N) to the visible buttons/options, and PREFIX each button label with its number for discoverability (CLI shows ''1. Allow / 2. ... / 3. No'').\n\nSurface: ToolPromptCard in lib/builtin/claude/src/prompt_card.dart. Two modes:\n- PERMISSION (_permission, ~line 119): buttons Allow (primary) / ''Allow & don''t ask again'' (only when permissionSuggestions present) / Deny. Map 1=Allow, 2=''Allow & don''t ask again'' (when shown) else Deny, 3=Deny when the middle one is shown. Match the CLI''s ordering/numbering.\n- ASKUSERQUESTION (_question / _optButton, ~line 280/294): each option per question gets a number (1..N) that selects (single) or toggles (multiSelect) it; keep Enter for Submit/Next and Esc/back as-is. Prefix option labels with the number alongside the existing radio/checkbox glyph (the ''○/●'' in _optButton).\n\nKEY CAVEAT (do this right): the prompt card hosts a free-text note field (_NoteField) and AskUserQuestion ''Other'' free-text. Number keys MUST NOT be captured while focus is in a text field (otherwise typing ''1'' triggers a button). Gate the shortcut on focus not being in an editable, i.e. intercept at the prompt''s Focus/FocusScope and bail when a text field has focus — same consumer-interception discipline as D-82 (Vim) / the editor. Keep the ClideButtons (clicks + AT) intact; the number key is an additional accelerator. Accessibility: include the number in the button''s semantics label.\n\nAcceptance: with a permission prompt or AskUserQuestion open and focus not in a text field, pressing 1/2/3 (and up to N for question options) activates the matching button/option; labels are number-prefixed; typing in a note/Other field is unaffected; mouse + screen-reader paths still work.

Refinement (2026-06-05, user): match the Claude Code CLI''s actual behavior for the text-field interaction. The number key triggers the button/option shortcut when it would be the FIRST character typed -- i.e. focus is NOT in a text field, OR focus IS in the note/Other field but that field is currently EMPTY. Once the field has any content, digits type normally (no shortcut). This supersedes the earlier ''never capture digits while a text field has focus'' gate: it''s better because focus often defaults into the (empty) note field, so the shortcut still fires there (muscle-memory case) while a digit mid-note still types. Implementation: intercept the digit at the prompt focus scope; consume+activate only when the focused editable (if any) is empty, else let it through to type. The CLI exhibits this exact ''footgun'' (digit-as-first-char in an empty field acts as the choice) and we intentionally mirror it.', 'Muscle-memory gap from the Claude Code CLI: in clide''s interaction-zone prompts (D-78), the user reaches for number keys 1/2/3 to pick a button but has to click. Map number keys (1..N) to the visible buttons/options, and PREFIX each button label with its number for discoverability (CLI shows ''1. Allow / 2. ... / 3. No'').\n\nSurface: ToolPromptCard in lib/builtin/claude/src/prompt_card.dart. Two modes:\n- PERMISSION (_permission, ~line 119): buttons Allow (primary) / ''Allow & don''t ask again'' (only when permissionSuggestions present) / Deny. Map 1=Allow, 2=''Allow & don''t ask again'' (when shown) else Deny, 3=Deny when the middle one is shown. Match the CLI''s ordering/numbering.\n- ASKUSERQUESTION (_question / _optButton, ~line 280/294): each option per question gets a number (1..N) that selects (single) or toggles (multiSelect) it; keep Enter for Submit/Next and Esc/back as-is. Prefix option labels with the number alongside the existing radio/checkbox glyph (the ''○/●'' in _optButton).\n\nKEY CAVEAT (do this right): the prompt card hosts a free-text note field (_NoteField) and AskUserQuestion ''Other'' free-text. Number keys MUST NOT be captured while focus is in a text field (otherwise typing ''1'' triggers a button). Gate the shortcut on focus not being in an editable, i.e. intercept at the prompt''s Focus/FocusScope and bail when a text field has focus — same consumer-interception discipline as D-82 (Vim) / the editor. Keep the ClideButtons (clicks + AT) intact; the number key is an additional accelerator. Accessibility: include the number in the button''s semantics label.\n\nAcceptance: with a permission prompt or AskUserQuestion open and focus not in a text field, pressing 1/2/3 (and up to N for question options) activates the matching button/option; labels are number-prefixed; typing in a note/Other field is unaffected; mouse + screen-reader paths still work.

Refinement (2026-06-05, user): match the Claude Code CLI''s actual behavior for the text-field interaction. The number key triggers the button/option shortcut when it would be the FIRST character typed -- i.e. focus is NOT in a text field, OR focus IS in the note/Other field but that field is currently EMPTY. Once the field has any content, digits type normally (no shortcut). This supersedes the earlier ''never capture digits while a text field has focus'' gate: it''s better because focus often defaults into the (empty) note field, so the shortcut still fires there (muscle-memory case) while a digit mid-note still types. Implementation: intercept the digit at the prompt focus scope; consume+activate only when the focused editable (if any) is empty, else let it through to type. The CLI exhibits this exact ''footgun'' (digit-as-first-char in an empty field acts as the choice) and we intentionally mirror it.

DONE 2026-06-09. ToolPromptCard: number keys pick the matching button/option (labels prefixed 1./2./3.), Enter confirms the primary action. Permission 1=Allow / 2=Allow&remember(if offered) else Deny / 3=Deny; AskUserQuestion 1..N select+toggle options + Other. Card autofocuses; _onKey self-guards on hasPrimaryFocus so a focused note field types digits normally. Permission/option actions shared between buttons + keys. Tests: prompt_card_test number-key group + updated label finders.', NULL, '2026-06-09 20:27:17', '2026-06-09 20:27:17', '2026-06-09 20:27:17', NULL, 'c05ca703a5a99d070e1eca42d853370f', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM531VE0C6N36AT12SR', 'status', 'ready', 'done', NULL, '2026-06-09 20:34:30', '2026-06-09 20:34:30', '2026-06-09 20:34:30', NULL, '6dd8b5ff2ee01ab1eac6aa74c08d4186', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM531VE0C6N36AT12SR', 'description', 'Lesson from T-239: a width-PROPORTIONAL layout bug (status-bar right group drifting to mid-bar via a Spacer-vs-flex split) was invisible at the default 800px flutter_test surface and at 1200px, but glaring at 3440px. clide is an IDE — ultrawide (3440, 5120, ultrawide+vertical splits) is a VERY common real screen size, so width-sensitive layout that only ever gets tested at 800px hides exactly this class of bug.\n\nScope: review the widget/golden suite and add ultrawide coverage where layout is width-sensitive. Candidates: the bottom status bar (done — test/app_statusbar_test.dart now covers 600 + 3440), panel/slot layout + drag-resize (lib/app.dart RootLayout, SlotHost), tab strips (overflow/scroll at wide), ClideMarquee (T-160 — only tested narrow; also check it doesn''t mis-behave wide), conversation view / activity card, the command palette + quick-open overlays (max-width/centering on wide), modal pickers, status items.\n\nApproach: (1) add a shared test helper to pump at a given surface width via tester.view.physicalSize (note: a wide SizedBox under the default 800px surface is CLAMPED — must set view.physicalSize, see test/app_statusbar_test.dart pumpAt). (2) For layout-sensitive widgets, assert key positions/no-overflow at BOTH a normal and an ultrawide width. (3) Don''t blanket-add to every test — target width-sensitive layout (Row/Spacer/Expanded/Flexible/Align, max-width caps, centering). Note any widget that SHOULD cap/center on ultrawide (readability) vs fill. Relates to Q-26 (small-screen layout) — same responsive concern at the other end.', 'Lesson from T-239: a width-PROPORTIONAL layout bug (status-bar right group drifting to mid-bar via a Spacer-vs-flex split) was invisible at the default 800px flutter_test surface and at 1200px, but glaring at 3440px. clide is an IDE — ultrawide (3440, 5120, ultrawide+vertical splits) is a VERY common real screen size, so width-sensitive layout that only ever gets tested at 800px hides exactly this class of bug.\n\nScope: review the widget/golden suite and add ultrawide coverage where layout is width-sensitive. Candidates: the bottom status bar (done — test/app_statusbar_test.dart now covers 600 + 3440), panel/slot layout + drag-resize (lib/app.dart RootLayout, SlotHost), tab strips (overflow/scroll at wide), ClideMarquee (T-160 — only tested narrow; also check it doesn''t mis-behave wide), conversation view / activity card, the command palette + quick-open overlays (max-width/centering on wide), modal pickers, status items.\n\nApproach: (1) add a shared test helper to pump at a given surface width via tester.view.physicalSize (note: a wide SizedBox under the default 800px surface is CLAMPED — must set view.physicalSize, see test/app_statusbar_test.dart pumpAt). (2) For layout-sensitive widgets, assert key positions/no-overflow at BOTH a normal and an ultrawide width. (3) Don''t blanket-add to every test — target width-sensitive layout (Row/Spacer/Expanded/Flexible/Align, max-width caps, centering). Note any widget that SHOULD cap/center on ultrawide (readability) vs fill. Relates to Q-26 (small-screen layout) — same responsive concern at the other end.

DONE 2026-06-09. Added the reusable setSurfaceSize(tester, width) helper to test/helpers/widget_harness.dart (the foundation the ticket asked for). Ultrawide (3440) cases added on the flagged width-sensitive surfaces: ClideMarquee (was narrow-only — now verified static when a line fits a wide slot) and the quick-open palette (verified width-capped, not stretched). Status bar already covers 600+3440 (T-239). AUDIT NOTES on the rest: overlays/pickers use fixed-width panels (ClideMenu/quick-open 480, anchored popovers) so they''re inherently capped/centered; tab strips (MultitabPane) and status items overflow only when NARROW (a small-screen concern, Q-26), not wide; RootLayout slots are explicit fixed/flex widths with drag-resize. The helper is now in place for any future width-sensitive widget. Not exhaustive by design (audit + reusable tooling + the high-risk surfaces).', NULL, '2026-06-09 20:34:30', '2026-06-09 20:34:30', '2026-06-09 20:34:30', NULL, 'f81c453978dfa298dfb66a17a39a6264', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4BRWWPB4R06Q31XV0', 'status', 'ready', 'done', NULL, '2026-06-09 20:41:22', '2026-06-09 20:41:22', '2026-06-09 20:41:22', NULL, '9a195bdb92b08e8a05c5ea8ab0792278', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4BRWWPB4R06Q31XV0', 'description', 'Register clide:// protocol handler. Support clide://open?path=/repo/file.md&line=42 for external tools to open files at specific locations. Useful for CI links, error reports, and cross-tool integration.', 'Register clide:// protocol handler. Support clide://open?path=/repo/file.md&line=42 for external tools to open files at specific locations. Useful for CI links, error reports, and cross-tool integration.

DONE (Linux) 2026-06-09. clide://open?path=&line= → editor.open via parseArgv, routed through the existing CLI→IPC path into the running window (single-instance for free). Parser validates action/path/line; tests in argv_to_request_test. Scheme registered: linux/clide.desktop (x-scheme-handler/clide, Exec already %U) + macOS Info.plist CFBundleURLTypes. Linux works end-to-end. macOS URL DELIVERY (AppDelegate openURLs → method channel → Dart) deferred to T-303 — needs a macOS machine to verify, not shipped blind.', NULL, '2026-06-09 20:41:22', '2026-06-09 20:41:22', '2026-06-09 20:41:22', NULL, 'ca04430461aeac7583a044f10aa57469', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4BRWWPB4R06Q31XV0', 'description', 'Register clide:// protocol handler. Support clide://open?path=/repo/file.md&line=42 for external tools to open files at specific locations. Useful for CI links, error reports, and cross-tool integration.

DONE (Linux) 2026-06-09. clide://open?path=&line= → editor.open via parseArgv, routed through the existing CLI→IPC path into the running window (single-instance for free). Parser validates action/path/line; tests in argv_to_request_test. Scheme registered: linux/clide.desktop (x-scheme-handler/clide, Exec already %U) + macOS Info.plist CFBundleURLTypes. Linux works end-to-end. macOS URL DELIVERY (AppDelegate openURLs → method channel → Dart) deferred to T-303 — needs a macOS machine to verify, not shipped blind.', 'Register clide:// protocol handler. Support clide://open?path=/repo/file.md&line=42 for external tools to open files at specific locations. Useful for CI links, error reports, and cross-tool integration.

DONE (Linux) 2026-06-09. clide://open?path=&line= → editor.open via parseArgv, routed through the existing CLI→IPC path into the running window (single-instance for free). Parser validates action/path/line; tests in argv_to_request_test. Scheme registered: linux/clide.desktop (x-scheme-handler/clide, Exec already %U) + macOS Info.plist CFBundleURLTypes. Linux works end-to-end. macOS URL DELIVERY (AppDelegate openURLs → method channel → Dart) deferred to T-303 — needs a macOS machine to verify, not shipped blind.

SECURITY REDESIGN 2026-06-09 (D-90): per user, the clide:// surface is now paranoid. The link no longer translates to a command in parseArgv — it routes the raw URL to a new builtin.deeplink handler gated by a DEFAULT-DENY allowlist (kDeepLinkSafeActions = {open} only — run/git/write/passthrough rejected) AND a mandatory confirmation prompt (''an external link wants to: … allow?'') before any action. The generic CLI-passthrough idea is deliberately NOT shipped (it would make a webpage a remote control); each new action is an explicit allowlist + handler addition. Tests: deep_link_test (allowlist boundary), extension_test (gating).', NULL, '2026-06-09 20:57:53', '2026-06-09 20:57:53', '2026-06-09 20:57:53', NULL, 'aee84cbde5ade207d02379c497eed4ed', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM6SK3D1QYACBPHHBZ0', 'status', 'backlog', 'ready', NULL, '2026-06-09 21:04:10', '2026-06-09 21:04:10', '2026-06-09 21:04:10', NULL, '9004651246035582806f204f61b20e91', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM6SK3D1QYACBPHHBZ0', 'status', 'ready', 'in_progress', NULL, '2026-06-09 21:04:33', '2026-06-09 21:04:33', '2026-06-09 21:04:33', NULL, 'bff9123dd5b8658d12afdf3d87bfc71f', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM6SK3D1QYACBPHHBZ0', 'description', 'On Linux desktop startup, two GLib-GIO-CRITICAL warnings fire to stderr:

  GLib-GIO-CRITICAL: GFileInfo created without standard::size
  file ../gio/gfileinfo.c: line 1865 (g_file_info_get_size): should not be reached

Repro: launch the app (make run / flutter run) on Linux. The pair fires early in boot — right after the primary pane binds its session and before the IPC server starts listening (observed ~0.3s apart, e.g. 15:53:15.570 and 15:53:15.832), on every launch.

Cause: some code path calls g_file_info_get_size() on a GFileInfo that was created/queried WITHOUT requesting the G_FILE_ATTRIBUTE_STANDARD_SIZE (''standard::size'') attribute. A grep of clide''s own code (lib/, linux/runner/, native/) finds no direct g_file_info / g_file_query_info usage, so it is most likely inside GTK/GLib itself or a Flutter Linux plugin''s file enumeration (icon/thumbnail/mime probe, path lookups), not clide Dart/C++. The GTK file-chooser in linux/runner/clide_app.cc is on-demand only, so it is not the trigger (the warnings fire at boot).

Impact: low — console noise at CRITICAL level; no observed functional breakage. But a size query that ''should not be reached'' may be reading a bogus/zero size somewhere worth confirming.

Investigation: run with G_DEBUG=fatal-warnings (or gdb break on g_log/g_logv) to capture the stack at the warning and identify the library/plugin frame; check whether a Flutter plugin (file_selector, path_provider, url_launcher) or GTK icon/mime loading is responsible. If upstream/GTK, document + suppress-from-our-side or pin; if a plugin, file upstream.

Env: Fedora, GTK Linux embedder, flutter run.

UPDATE (2026-06-09): also fires MID-SESSION, not only at boot — contradicts the "fires early in boot, on every launch" framing above. Observed log: app booted 16:47:01, but the GLib-GIO-CRITICAL pair fired at 18:51:07.841 / 18:51:08.190 (~2h into the session), near pane/session activity. So the trigger is more likely a file-info code path tied to a user action or background file enumeration than pure startup. Re-scope the investigation to capture the stack when it fires mid-session (G_DEBUG=fatal-warnings / gdb break on g_log) rather than only at boot.', 'On Linux desktop startup, two GLib-GIO-CRITICAL warnings fire to stderr:

  GLib-GIO-CRITICAL: GFileInfo created without standard::size
  file ../gio/gfileinfo.c: line 1865 (g_file_info_get_size): should not be reached

Repro: launch the app (make run / flutter run) on Linux. The pair fires early in boot — right after the primary pane binds its session and before the IPC server starts listening (observed ~0.3s apart, e.g. 15:53:15.570 and 15:53:15.832), on every launch.

Cause: some code path calls g_file_info_get_size() on a GFileInfo that was created/queried WITHOUT requesting the G_FILE_ATTRIBUTE_STANDARD_SIZE (''standard::size'') attribute. A grep of clide''s own code (lib/, linux/runner/, native/) finds no direct g_file_info / g_file_query_info usage, so it is most likely inside GTK/GLib itself or a Flutter Linux plugin''s file enumeration (icon/thumbnail/mime probe, path lookups), not clide Dart/C++. The GTK file-chooser in linux/runner/clide_app.cc is on-demand only, so it is not the trigger (the warnings fire at boot).

Impact: low — console noise at CRITICAL level; no observed functional breakage. But a size query that ''should not be reached'' may be reading a bogus/zero size somewhere worth confirming.

Investigation: run with G_DEBUG=fatal-warnings (or gdb break on g_log/g_logv) to capture the stack at the warning and identify the library/plugin frame; check whether a Flutter plugin (file_selector, path_provider, url_launcher) or GTK icon/mime loading is responsible. If upstream/GTK, document + suppress-from-our-side or pin; if a plugin, file upstream.

Env: Fedora, GTK Linux embedder, flutter run.

UPDATE (2026-06-09): also fires MID-SESSION, not only at boot — contradicts the "fires early in boot, on every launch" framing above. Observed log: app booted 16:47:01, but the GLib-GIO-CRITICAL pair fired at 18:51:07.841 / 18:51:08.190 (~2h into the session), near pane/session activity. So the trigger is more likely a file-info code path tied to a user action or background file enumeration than pure startup. Re-scope the investigation to capture the stack when it fires mid-session (G_DEBUG=fatal-warnings / gdb break on g_log) rather than only at boot.

RESOLVED (2026-06-09).

Root cause CONFIRMED by reproducer: the Open Workspace folder picker. `gtk_file_chooser_dialog_new(..., SELECT_FOLDER, ...)` at linux/runner/clide_app.cc:222 builds a GtkPlacesSidebar that enumerates bookmarks/recent and internally creates GFileInfo objects WITHOUT G_FILE_ATTRIBUTE_STANDARD_SIZE, then calls g_file_info_get_size() on them — GTK''s own bug. A standalone repro (gtk3, SELECT_FOLDER dialog, auto-cancel) emitted the exact warning pair ~0.3s apart, matching the user''s mid-session log (18:51:07.841 / 18:51:08.190). The original "fires at boot" framing was wrong; the picker is opened on demand. Ruled OUT the T-138 clipboard channel: gtk_clipboard_wait_for_uris/wait_for_image emit nothing for text/image/file-uri clipboard states under G_DEBUG=fatal-warnings.

No public GTK API exists to fix at source (the sidebar''s enumeration is private; can''t inject the missing attribute).

Fix (both, per user direction):
1. Switched pickDirectory to GtkFileChooserNative — portal-backed, runs out-of-process in sandboxed/Flatpak builds so the noise never enters our process; nicer Wayland picker. (Verified: outside a sandbox GtkFileChooserNative falls back to the in-process chooser and STILL warns on this box — portal is only used under Flatpak/snap or GTK_USE_PORTAL=1.)
2. Added clide_gio_log_filter in clide_app.cc, installed via g_log_set_handler("GLib-GIO", CRITICAL, ...) in clide_app_startup. Drops ONLY messages containing "g_file_info_get_size" or "without standard::size"; forwards every other GLib-GIO log to the default handler. This is the universal fix (works in every run mode).

Verification: standalone reproducer with both the native chooser AND the filter — size warnings gone, an unrelated GLib-GIO CRITICAL still passes through (filter is scoped, not a blanket mute). `make build-linux` green. CHANGELOG updated under Fixed.', NULL, '2026-06-09 21:21:04', '2026-06-09 21:21:04', '2026-06-09 21:21:04', NULL, '0b6444210390483f0e12a042efd5e3f1', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM6SK3D1QYACBPHHBZ0', 'status', 'in_progress', 'done', NULL, '2026-06-09 21:21:08', '2026-06-09 21:21:08', '2026-06-09 21:21:08', NULL, 'd22822fc67f1dc3e1d63c924b6fe91fd', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM50S6WRD81V3Z0NH1M', 'status', 'backlog', 'ready', NULL, '2026-06-09 21:21:30', '2026-06-09 21:21:30', '2026-06-09 21:21:30', NULL, '80c5f5e2ca71bc6146c769b93cfdc8e9', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM50S6WRD81V3Z0NH1M', 'status', 'ready', 'in_progress', NULL, '2026-06-09 21:22:26', '2026-06-09 21:22:26', '2026-06-09 21:22:26', NULL, '8c699e741fba562a14ec7fe5ebd4695e', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4KS233FGZE9H7ABWR', 'parent_id', NULL, 'T-276', NULL, '2026-06-09 21:22:31', '2026-06-09 21:22:31', '2026-06-09 21:22:31', NULL, 'b70cdfeb0ac73677be0a6d190ee88376', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4KS233FGZE9H7ABWR', 'description', NULL, 'The logo-mark spinner shown on in-progress activity/holder cards in the Claude conversation is too small to read as a spinner — it reads as a static speck. Enlarge it so the running state is legible at a glance.

**Where**
- `ClideSpinner` (lib/widgets/src/clide_spinner.dart) — defaults to size 14; renders the logo SVG at width/height = size.
- `ClideStatusIndicator` (lib/widgets/src/clide_status_indicator.dart) — default size 14; maps running→ClideSpinner, success→check, error→cross at the same size.
- Call sites: holder_card.dart:117 and :199 pass `size: 12` — the small value the user is seeing.

**Direction (settle in review)**
- Bump the spinner size on the activity cards (the `size: 12` call sites, and/or the indicator default) to something clearly legible — pull a concrete value from the ui-design control-geometry tokens rather than a magic number.
- Keep the running spinner, success check, and error cross visually balanced at the new size (they share `size`), so the card doesn''t jump when the state settles.
- Check the other ClideSpinner/StatusIndicator consumers (status surfaces) so the bump doesn''t bloat unrelated spots — may warrant sizing the cards explicitly rather than changing the shared default.

**Acceptance**
- The in-progress spinner on conversation activity cards is comfortably distinguishable as a spinning indicator; success/error glyphs stay aligned at the same footprint.', NULL, '2026-06-09 21:22:44', '2026-06-09 21:22:44', '2026-06-09 21:22:44', NULL, '71233a6425b5734391c4d315579d2c64', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5YNEQM1WY25BV7TD8', 'status', 'backlog', 'ready', NULL, '2026-06-09 21:32:29', '2026-06-09 21:32:29', '2026-06-09 21:32:29', NULL, 'b6690849ecbdddf638c67dfa82192a3f', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM50S6WRD81V3Z0NH1M', 'status', 'in_progress', 'done', NULL, '2026-06-09 21:36:05', '2026-06-09 21:36:05', '2026-06-09 21:36:05', NULL, 'c494cd6008aa55db47c5f372ab52c5b2', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5YNEQM1WY25BV7TD8', 'status', 'ready', 'done', NULL, '2026-06-09 21:42:59', '2026-06-09 21:42:59', '2026-06-09 21:42:59', NULL, '73d904ce53c8f0d5adbb6e724d47f885', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB16FJ7KXGFHQXEG88MYRFTG', 'description', 'Group/tool collapser cards (ClideHolderCard vs ConversationCard) handle collapse + visuals inconsistently; extract one shared collapser primitive with a color property, fixed-width counter slot, and the status icon hard against the card edge.', 'Group/tool collapser cards (ClideHolderCard vs ConversationCard) handle collapse + visuals inconsistently; extract one shared collapser primitive with a color property, fixed-width counter slot, and the status icon hard against the card edge.

## Bug / discrepancy

There are two collapser-card families with inconsistent collapse handling and
"card within card" chrome:

- **`ClideHolderCard`** (lib/builtin/claude/src/holder_card.dart, T-266) — the
  group container for Activity (`_ActivityCard`) and Edits (`_EditRunCard`).
  Collapse = ticker row + frame background + a header caret. Header order:
  `[chevron] summary … [status] [count]`. Status indicator sits INBOARD, left
  of the count label. Border/text hardcoded to `panelBorder` / `globalTextMuted`
  (no color knob).
- **`ConversationCard`** (lib/builtin/claude/src/conversation_card.dart, T-262)
  — the per-tool merged card. Collapse = a single leading caret only (no
  background/ticker). Header order: `[caret] label summary/spacer [status]
  [actions]`. Has `borderColor` + `accent`.

So the toggle is attached differently, the status mark sits in a different
place, the counter has no fixed slot, and color customization exists on one but
not the other. They should grab the SAME widget (each its own instance — NOT
collapsing across types).

## Proposal — one `ClideCollapserCard` primitive

Both families render through a single collapser primitive. Requirements:

1. **`color` property** drives the border AND the label/text color, so each
   instance keeps its visual identity (activity = muted, edits = accent,
   error = red, sub-agent, …) through one widget. Default = panelBorder/muted.
2. **Fixed-width counter slot** — the `N steps` / `N edits` count lives in a
   right-aligned fixed-width slot so it (and the trailing status icon) never
   shift as the number grows or the status appears/changes.
3. **Status icon hard against the card edge** — flip the current
   `[count][status]` to `[status]` against the right edge with the counter
   inboard of it. The chevron already hugs the LEFT edge. Rule: both icons hug
   the card edges; text sits inboard.
4. **Consistent collapse/expand attachment** across both uses (keep the
   group-container background-tap-to-collapse for the tail-follow case, D-78,
   but the visible control + header layout are identical).
5. Status glyphs: `ClideRunStatus` running (logo-mark spinner ◐) / success ✓ /
   error ✕, reusing ClideStatusIndicator.

Nested sub-cards render the SAME primitive (card-within-card consistency).

## Scope

- New `ClideCollapserCard` in lib/widgets/src/ (exported from widgets.dart).
- Migrate `ClideHolderCard` (Activity/Edits) and `ConversationCard` (merged
  tool card) onto it; keep per-type content/labels.
- Hold visual fidelity via goldens (conversation_card_goldens_test,
  ClideHolderCard golden) + a11y (expanded/collapsed semantics, focusable
  toggle).

## Wireframe

docs/design/wireframes/cards/collapser-card.json (+ .png) — collapsed (3 color
variants), expanded with nested sub-cards, annotated for the counter slot +
edge-anchored icons.', NULL, '2026-06-10 08:16:05', '2026-06-10 08:16:05', '2026-06-10 08:16:05', NULL, 'fe6c300aa083f7faa80d3d78bd1ba0bf', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB16FJ7KXGFHQXEG88MYRFTG', 'description', 'Group/tool collapser cards (ClideHolderCard vs ConversationCard) handle collapse + visuals inconsistently; extract one shared collapser primitive with a color property, fixed-width counter slot, and the status icon hard against the card edge.

## Bug / discrepancy

There are two collapser-card families with inconsistent collapse handling and
"card within card" chrome:

- **`ClideHolderCard`** (lib/builtin/claude/src/holder_card.dart, T-266) — the
  group container for Activity (`_ActivityCard`) and Edits (`_EditRunCard`).
  Collapse = ticker row + frame background + a header caret. Header order:
  `[chevron] summary … [status] [count]`. Status indicator sits INBOARD, left
  of the count label. Border/text hardcoded to `panelBorder` / `globalTextMuted`
  (no color knob).
- **`ConversationCard`** (lib/builtin/claude/src/conversation_card.dart, T-262)
  — the per-tool merged card. Collapse = a single leading caret only (no
  background/ticker). Header order: `[caret] label summary/spacer [status]
  [actions]`. Has `borderColor` + `accent`.

So the toggle is attached differently, the status mark sits in a different
place, the counter has no fixed slot, and color customization exists on one but
not the other. They should grab the SAME widget (each its own instance — NOT
collapsing across types).

## Proposal — one `ClideCollapserCard` primitive

Both families render through a single collapser primitive. Requirements:

1. **`color` property** drives the border AND the label/text color, so each
   instance keeps its visual identity (activity = muted, edits = accent,
   error = red, sub-agent, …) through one widget. Default = panelBorder/muted.
2. **Fixed-width counter slot** — the `N steps` / `N edits` count lives in a
   right-aligned fixed-width slot so it (and the trailing status icon) never
   shift as the number grows or the status appears/changes.
3. **Status icon hard against the card edge** — flip the current
   `[count][status]` to `[status]` against the right edge with the counter
   inboard of it. The chevron already hugs the LEFT edge. Rule: both icons hug
   the card edges; text sits inboard.
4. **Consistent collapse/expand attachment** across both uses (keep the
   group-container background-tap-to-collapse for the tail-follow case, D-78,
   but the visible control + header layout are identical).
5. Status glyphs: `ClideRunStatus` running (logo-mark spinner ◐) / success ✓ /
   error ✕, reusing ClideStatusIndicator.

Nested sub-cards render the SAME primitive (card-within-card consistency).

## Scope

- New `ClideCollapserCard` in lib/widgets/src/ (exported from widgets.dart).
- Migrate `ClideHolderCard` (Activity/Edits) and `ConversationCard` (merged
  tool card) onto it; keep per-type content/labels.
- Hold visual fidelity via goldens (conversation_card_goldens_test,
  ClideHolderCard golden) + a11y (expanded/collapsed semantics, focusable
  toggle).

## Wireframe

docs/design/wireframes/cards/collapser-card.json (+ .png) — collapsed (3 color
variants), expanded with nested sub-cards, annotated for the counter slot +
edge-anchored icons.', 'Unify the conversation-panel collapsible cards onto one ClideCollapserCard primitive, and share card spacing across all card categories. Supersedes ClideHolderCard (T-266) and the collapse logic in ConversationCard (T-262) for the tool path.

## Conversation-panel card model (agreed 2026-06-10)

### Shared spacing — constants, NOT a shared wrapper
All card categories share a small set of spacing CONSTANTS (inter-card bottom gap, inner padding, corner radius). NOT a forced common wrapper widget — each category is its own widget; they just pull the same spacing tokens so the stream reads as one consistent rhythm.

### Three card categories
1. **Dialog cards** — carry the side stripe marking who is speaking (user / Claude / agent). Prose / attribution. Not collapsible. (Today: ConversationCard stripe variant.)
2. **Simple cards** — a single item shown fully open in the stream, never collapses (e.g. the image-show card; more to come). Standalone display: no chevron, no status chrome.
3. **Collapsibles** — the unified collapser. Covers edits, bash, task updates, runs — every tool use. Behaves like the bash card should:
   - The whole card is clickable to collapse/expand.
   - Collapsed: title = the echoed last content line (like bash now) + an item count + aggregate status (spinner / check / cross).
   - Expanded: an inner canvas holding the nested item card(s), each item in its own inner card.
   - A single item still gets its own inner card inside the collapser when open, and pushes its status / count / last-line up to the collapser header.
   - Inner item cards ALSO show their own per-item status (check / cross / spinner) when expanded; the collapser header carries the aggregate.
   - Chrome (per the wireframe): `color` (outer border + chevron / label / text), fixed-width counter slot, status icon hard against the right edge, chevron hard against the left edge.

## Scope
- New `ClideCollapserCard` in lib/widgets/ (exported from widgets.dart) — the category-3 primitive: a list of 1..N inner item cards, collapsed ticker <-> expanded inner canvas, color / fixed-counter / edge-status / edge-chevron chrome, background + caret toggle (D-78 tail-follow), aggregate status + count + echoed-title computed from the items.
- Shared card-spacing constants consumed by all three categories.
- ALL tool uses render as collapsers — single ones as a 1-item list (Bash, Read, Edit, Task, edits runs, activity runs, etc.).
- Inner item cards: content + their own per-item status; no own collapse; no stripe.
- Dialog cards (1) and simple cards (2) are NOT pulled into the collapser — they only adopt the shared spacing constants (keep stripe / inner config).

## Verify
- Goldens regenerated (holder_card, conversation_card_merged) + a11y (expanded / collapsed semantics, focusable toggle).
- Wireframe: docs/design/wireframes/cards/collapser-card.{json,png}.
- After landing: update the ui-design skill''s conversation-panel guidance to describe the three card categories + the collapser.
', NULL, '2026-06-10 08:43:03', '2026-06-10 08:43:03', '2026-06-10 08:43:03', NULL, '15f42c1d62be96cf45d583bf3ac704cd', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM42WW0SY3XEXKE8PK8', 'status', 'ready', 'done', NULL, '2026-06-10 08:57:51', '2026-06-10 08:57:51', '2026-06-10 08:57:51', NULL, '248034327b78f2dec7d43564ccc01b18', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5E41Q8TX8X55X4MZ0', 'status', 'in_progress', 'done', NULL, '2026-06-10 08:57:51', '2026-06-10 08:57:51', '2026-06-10 08:57:51', NULL, '26b3a60618574a2ef4e947cc1e4a221e', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM61SRVBDRFFN2S80T4', 'status', 'ready', 'done', NULL, '2026-06-10 08:57:51', '2026-06-10 08:57:51', '2026-06-10 08:57:51', NULL, 'c51669ac4ba92aed8a72728bf08ea6e0', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4GN07FN8GAXZ20YAR', 'status', 'ready', 'done', NULL, '2026-06-10 08:57:51', '2026-06-10 08:57:51', '2026-06-10 08:57:51', NULL, 'd5c50f178f76cccba89ad44a62af29de', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM531VE0C6N36AT12SR', 'status', 'ready', 'done', NULL, '2026-06-10 08:57:51', '2026-06-10 08:57:51', '2026-06-10 08:57:51', NULL, 'dd13cc3149df6c1dc2d27e53fce878c1', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4BD8PXDRHBF001200', 'status', 'in_progress', 'done', NULL, '2026-06-10 08:57:51', '2026-06-10 08:57:51', '2026-06-10 08:57:51', NULL, 'f4a1697c1c839dc92d6bedc2cd86d997', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM42VPM50VKAWXBCAM8', 'status', 'ready', 'done', NULL, '2026-06-10 08:57:51', '2026-06-10 08:57:51', '2026-06-10 08:57:51', NULL, 'fe6d00feb488f12fd0931852b2e66236', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB16FJ7KXGFHQXEG88MYRFTG', 'status', 'backlog', 'in_progress', NULL, '2026-06-10 09:13:08', '2026-06-10 09:13:08', '2026-06-10 09:13:08', NULL, '56fbf20da154b3465d3d2e7dcc87dfc9', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB16FJ7KXGFHQXEG88MYRFTG', 'status', 'in_progress', 'done', NULL, '2026-06-10 09:39:52', '2026-06-10 09:39:52', '2026-06-10 09:39:52', NULL, '5f059718e9cf548a13a9d141970ccd2e', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB170DJA02EH2E8HMH7X7SS4', 'status', 'backlog', 'done', NULL, '2026-06-10 09:41:52', '2026-06-10 09:41:52', '2026-06-10 09:41:52', NULL, '67000e62833f645575e2b557a711d292', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7H8JWCP59WQVD0FW4', 'status', 'backlog', 'ready', NULL, '2026-06-10 09:42:26', '2026-06-10 09:42:26', '2026-06-10 09:42:26', NULL, '4dc40a53e7b803afd26d2334adc708b6', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB1XDWKQ594ET4GDYEFK5ZJ4', 'description', 'Add a fourth option to the Claude permission prompt card (lib/builtin/claude/src/prompt_card.dart) alongside Allow / Allow & don''t ask again / Deny.

WHAT IT DOES
A deny that carries a preformatted follow-up note telling Claude the action was too complex for the permission system and to retry in a simpler format. Implemented as a _permDeny variant that passes a fixed note into DenyTool (today _permDeny uses _permNote() ?? ''Denied by the user.'' at prompt_card.dart:202). The user''s own note field, if filled, should still be respected — append it to / combine with the preformatted text rather than discard it.

LABEL: ''Deny & simplify'' (working label; placed after Deny).
TOOLTIP: ClideButton already supports  (clide_button.dart:26) — add a mouseover explaining the behavior, e.g. ''Deny and ask Claude to retry this action in a simpler format — complex interactions don''t work well with the permission system.''

PREFORMATTED DENY NOTE (workshop wording, starting point):
"Denied — this action is too complex for the permission system to approve cleanly. Please retry with a simpler, more granular approach (break it into smaller steps or use a plainer command) to avoid this permission prompt. This is a one-off for THIS action only: do not add a memory and do not change permission settings — just reformulate and try again."
The ''do not add a memory / do not change permission settings'' clause is deliberate: without it Claude tends to ''fix'' the permission system (writing memories, rewriting permission config), which means continuous fiddling with a surface we don''t want it touching.

NUMBER-KEY SLOT
_activateNumber (prompt_card.dart:161-164) maps 1=Allow, 2=Allow&remember (when canRemember), 3/2=Deny. Add the new option as the next index (4 when canRemember, else 3). Keep Deny as its own option; the new one is additive. Update the digit/numpad shortcut mapping accordingly (see also T-310 numpad parity).

DESIGN NOTE — escalation behavior
The deny note enters the conversation and stays in context, so repeated use within one session compounds (Claude leans progressively harder toward simpler formats). That''s largely the intended escalating pressure, but the note is phrased as a one-shot ''retry THIS action'' rather than a standing rule to limit over-correction. Worth watching in testing whether repeated denials over-bias toward trivial formats.

ACCEPTANCE
- A fourth button ''Deny & simplify'' appears on the permission card with a tooltip.
- Activating it resolves the prompt as a deny whose note is the preformatted retry-simpler text (with the user''s typed note appended when present).
- The note explicitly tells Claude not to add a memory or change permission settings.
- Number-row and numpad digit shortcuts address the new option in the correct slot.
- Widget test covers the new button resolving to a DenyTool with the expected note.', 'Add a fourth option to the Claude permission prompt card (lib/builtin/claude/src/prompt_card.dart) alongside Allow / Allow & don''t ask again / Deny.

WHAT IT DOES
A deny that carries a preformatted follow-up note telling Claude the action was too complex for the permission system and to retry in a simpler format. Implemented as a _permDeny variant that passes a fixed note into DenyTool (today _permDeny uses _permNote() ?? ''Denied by the user.'' at prompt_card.dart:202). The user''s own note field, if filled, should still be respected — append it to / combine with the preformatted text rather than discard it.

LABEL: ''Deny & simplify'' (working label; placed after Deny).
TOOLTIP: ClideButton already supports  (clide_button.dart:26) — add a mouseover explaining the behavior, e.g. ''Deny and ask Claude to retry this action in a simpler format — complex interactions don''t work well with the permission system.''

PREFORMATTED DENY NOTE (workshop wording, starting point):
"Denied — this action is too complex for the permission system to approve cleanly. Please retry with a simpler, more granular approach (break it into smaller steps or use a plainer command) to avoid this permission prompt. This is a one-off for THIS action only: do not add a memory and do not change permission settings — just reformulate and try again."
The ''do not add a memory / do not change permission settings'' clause is deliberate: without it Claude tends to ''fix'' the permission system (writing memories, rewriting permission config), which means continuous fiddling with a surface we don''t want it touching.

NUMBER-KEY SLOT
_activateNumber (prompt_card.dart:161-164) maps 1=Allow, 2=Allow&remember (when canRemember), 3/2=Deny. Add the new option as the next index (4 when canRemember, else 3). Keep Deny as its own option; the new one is additive. Update the digit/numpad shortcut mapping accordingly (see also T-310 numpad parity).

DESIGN NOTE — escalation behavior
The deny note enters the conversation and stays in context, so repeated use within one session compounds (Claude leans progressively harder toward simpler formats). That''s largely the intended escalating pressure, but the note is phrased as a one-shot ''retry THIS action'' rather than a standing rule to limit over-correction. Worth watching in testing whether repeated denials over-bias toward trivial formats.

ACCEPTANCE
- A fourth button ''Deny & simplify'' appears on the permission card with a tooltip.
- Activating it resolves the prompt as a deny whose note is the preformatted retry-simpler text (with the user''s typed note appended when present).
- The note explicitly tells Claude not to add a memory or change permission settings.
- Number-row and numpad digit shortcuts address the new option in the correct slot.
- Widget test covers the new button resolving to a DenyTool with the expected note.

CLARIFICATION (the TOOLTIP line above lost a word to shell escaping): ClideButton already exposes a tooltip parameter (clide_button.dart:17,26,42) — pass tooltip on the new button for the mouseover; no widget change needed.', NULL, '2026-06-10 09:56:24', '2026-06-10 09:56:24', '2026-06-10 09:56:24', NULL, 'f4fa8bc5799ef68d14512e128c03d1ba', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB1SJKA7KRCQMZE41SPQG780', 'status', 'backlog', 'ready', NULL, '2026-06-10 10:01:09', '2026-06-10 10:01:09', '2026-06-10 10:01:09', NULL, '7ed94c6ae98bb9f7a2e3a843512c47bd', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB1SJKA7KRCQMZE41SPQG780', 'status', 'ready', 'done', NULL, '2026-06-10 10:07:19', '2026-06-10 10:07:19', '2026-06-10 10:07:19', NULL, '15b320f72bf2a7bec603482d4b980bf6', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB1ZFJK6J2GSV4SA69QF730C', 'status', 'backlog', 'ready', NULL, '2026-06-10 10:08:59', '2026-06-10 10:08:59', '2026-06-10 10:08:59', NULL, 'e240ed5c41e787235e004fc193df9163', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB16YM1Y910T07Y1Y22MGTEM', 'status', 'backlog', 'ready', NULL, '2026-06-10 10:09:11', '2026-06-10 10:09:11', '2026-06-10 10:09:11', NULL, '4cc7018105565dc1ab774296d7bdf4ac', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7H8JWCP59WQVD0FW4', 'description', 'Design the app''s settings screen as a Frame0 wireframe before building `builtin.settings-ui` (see Tier 6 epic T-8). Output is a wireframe to align on layout/IA, not implementation.

**Deliverable**
- Frame0 wireframe authored via the frame0-wireframe skill: local JSON source-of-truth synced to Frame0, exported for review.
- Covers the settings screen shell + at least one fully-rendered category so the form-field patterns are concrete.

**Scope to frame (from T-8)**
- Schema-driven panel: form fields keyed off the schema each subsystem registers against the kernel SettingsStore; edits write back to `.clide/settings.yaml`.
- Navigation/IA: how categories are grouped and selected (sidebar list? sections? search?).
- Field types to mock: toggle, enum/select (e.g. keymap preset), text/number, and a ''opens external file'' affordance (e.g. editor `.editorconfig` per T-290).
- Known consumers to account for: keymap preset switching (T-115/T-64/T-65/T-66), editor settings (T-290), activity fold level (T-183), theme picker (Tier 6 theming UI).

**Open design questions for the wireframe to answer**
- Settings as a full-screen view, a pane/tab, or a modal?
- Per-project (`.clide/settings.yaml`) vs. user-global scope — shown together or switched?
- Search/filter across all settings.
- How schema-driven fields render labels, help text, defaults, and reset.

**Constraints**
- Follow clide visual language — pull theme tokens / control geometry from the ui-design skill so the wireframe maps cleanly to real widgets (no Material/Cupertino).

This is the design step; implementation of the actual settings UI is separate child work under T-8.', 'Design the app''s settings screen as a Frame0 wireframe before building `builtin.settings-ui` (see Tier 6 epic T-8). Output is a wireframe to align on layout/IA, not implementation.

**Deliverable**
- Frame0 wireframe authored via the frame0-wireframe skill: local JSON source-of-truth synced to Frame0, exported for review.
- Covers the settings screen shell + at least one fully-rendered category so the form-field patterns are concrete.

**Scope to frame (from T-8)**
- Schema-driven panel: form fields keyed off the schema each subsystem registers against the kernel SettingsStore; edits write back to `.clide/settings.yaml`.
- Navigation/IA: how categories are grouped and selected (sidebar list? sections? search?).
- Field types to mock: toggle, enum/select (e.g. keymap preset), text/number, and a ''opens external file'' affordance (e.g. editor `.editorconfig` per T-290).
- Known consumers to account for: keymap preset switching (T-115/T-64/T-65/T-66), editor settings (T-290), activity fold level (T-183), theme picker (Tier 6 theming UI).

**Open design questions for the wireframe to answer**
- Settings as a full-screen view, a pane/tab, or a modal?
- Per-project (`.clide/settings.yaml`) vs. user-global scope — shown together or switched?
- Search/filter across all settings.
- How schema-driven fields render labels, help text, defaults, and reset.

**Constraints**
- Follow clide visual language — pull theme tokens / control geometry from the ui-design skill so the wireframe maps cleanly to real widgets (no Material/Cupertino).

This is the design step; implementation of the actual settings UI is separate child work under T-8.

## Scope-tag icon decision (review, 2026-06-10)

The per-field scope tag is an ICON, not a text label (space + cognitive load).
Chosen trio (location→global reach ladder), keeping the colour coding + a
tooltip with the word for clarity/a11y; tapping opens the scope menu:

- Project (this repo)  = `folder`        0xe24a  (teal)   — already wired
- Always (all clide)   = `globe`         0xe288  (amber)  — add const
- Default (unset)      = `circle-dashed` 0xe602  (grey)   — add const

Alternatives considered: house (warmer home↔world pair), user-circle (mirrors
the real .clide vs ~/.clide files), gear (collides with "settings"). Note that
every Phosphor glyph already renders via PhosphorIconPainter(0xNNNN); only named
consts need adding. Preview/picking is blocked on a native glyph card (see the
new ticket) — goldens render the font as Ahem boxes.', NULL, '2026-06-10 10:20:48', '2026-06-10 10:20:48', '2026-06-10 10:20:48', NULL, '14f95d56a8f037f285dc4cbeb1ae7504', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB234WP4Y6Q16A0HFW8BSXMG', 'description', 'A conversation-pane card that renders Phosphor glyphs by name/codepoint, so icons can be previewed and picked in the live pane.', 'A conversation-pane card that renders Phosphor glyphs by name/codepoint, so icons can be previewed and picked in the live pane.

## Why

Picking icons (e.g. the settings scope tags, T-302) needs to SEE real glyphs.
Frame0 can''t render Phosphor (private-use codepoints, no font) and golden tests
render the font as Ahem boxes (only painter_bold_metrics loads a real font), so
preview only works where the app has the font — a native card is the vehicle.

## Deliverable

A conversation-pane card (peer of the image card, T-249/T-252) that renders a
grid of Phosphor glyphs with their name + codepoint, driven by the clide CLI —
e.g. `clide icon show <name|0xNNNN ...>` or `clide glyphs [filter]` (D-6 parity).
Uses the already-bundled Phosphor.ttf via PhosphorIconPainter.

## Notes / scope

- Every glyph already renders via `PhosphorIconPainter(0xNNNN)`; the 49 named
  consts in lib/widgets/src/icons/phosphor.dart are curated sugar. We do NOT
  need to bulk-add all ~1512 consts for availability.
- OPTIONAL behind this card: generate the full name→codepoint set (from
  .claude/skills/ui-design/references/phosphor-glyphs.md, 1512 entries) so glyphs
  are discoverable by name — but only if the card makes them browsable; weigh
  against clide''s curated/minimal philosophy.
- The card is display-only (D-78); a click could copy the codepoint/name.
- Surfaced 2026-06-10 while choosing settings scope icons (T-302).', NULL, '2026-06-10 10:21:09', '2026-06-10 10:21:09', '2026-06-10 10:21:09', NULL, '1ea34a81269e81267f69a993eabf4002', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7H8JWCP59WQVD0FW4', 'status', 'ready', 'done', NULL, '2026-06-10 10:21:48', '2026-06-10 10:21:48', '2026-06-10 10:21:48', NULL, '37b28095fb8c93b3e3319402eae91173', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB23Z52EVGQ4ZDAQ5BVAJ13R', 'status', 'backlog', 'ready', NULL, '2026-06-10 10:29:08', '2026-06-10 10:29:08', '2026-06-10 10:29:08', NULL, '7c78be9c5f8508b9e8ec788b0f34d95a', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB234WP4Y6Q16A0HFW8BSXMG', 'status', 'backlog', 'ready', NULL, '2026-06-10 10:38:06', '2026-06-10 10:38:06', '2026-06-10 10:38:06', NULL, '9ea7fb36b62a72a630cbe9c58a54521d', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB234WP4Y6Q16A0HFW8BSXMG', 'description', 'A conversation-pane card that renders Phosphor glyphs by name/codepoint, so icons can be previewed and picked in the live pane.

## Why

Picking icons (e.g. the settings scope tags, T-302) needs to SEE real glyphs.
Frame0 can''t render Phosphor (private-use codepoints, no font) and golden tests
render the font as Ahem boxes (only painter_bold_metrics loads a real font), so
preview only works where the app has the font — a native card is the vehicle.

## Deliverable

A conversation-pane card (peer of the image card, T-249/T-252) that renders a
grid of Phosphor glyphs with their name + codepoint, driven by the clide CLI —
e.g. `clide icon show <name|0xNNNN ...>` or `clide glyphs [filter]` (D-6 parity).
Uses the already-bundled Phosphor.ttf via PhosphorIconPainter.

## Notes / scope

- Every glyph already renders via `PhosphorIconPainter(0xNNNN)`; the 49 named
  consts in lib/widgets/src/icons/phosphor.dart are curated sugar. We do NOT
  need to bulk-add all ~1512 consts for availability.
- OPTIONAL behind this card: generate the full name→codepoint set (from
  .claude/skills/ui-design/references/phosphor-glyphs.md, 1512 entries) so glyphs
  are discoverable by name — but only if the card makes them browsable; weigh
  against clide''s curated/minimal philosophy.
- The card is display-only (D-78); a click could copy the codepoint/name.
- Surfaced 2026-06-10 while choosing settings scope icons (T-302).', 'A conversation-pane card that renders one OR MANY Phosphor glyphs by name/codepoint, each with an optional label and an optional description line, so icons can be previewed and compared in the live pane — and so a set of candidate icons can be offered as a labelled choice list (e.g. picking settings-scope icons, T-302).

## Why

Picking icons needs to SEE real glyphs side by side with what each one means. Frame0 can''t render Phosphor (private-use codepoints, no font) and goldens render the font as Ahem boxes, so preview only works where the app has the font — a native card is the vehicle. Beyond a bare grid, real icon decisions are ''which of these N icons, for these N meanings'' — so each entry wants an optional label (what we''d call it) and an optional description (what it represents), turning the card into an offer/choice list.

## Deliverable

A conversation-pane card (peer of the image card, T-249/T-252) that renders a list/grid of entries, each entry = glyph + optional label + optional description, driven by the clide CLI (D-6 parity). Uses the bundled Phosphor.ttf via PhosphorIconPainter.

### Multi-size rendering (per entry)

Each icon is shown at SEVERAL sizes, not one: (1) a large hero rendering so the glyph''s detail is clearly legible, and (2) a sample at each font-size token the app actually uses inline, so you can judge how the glyph reads at real UI sizes. The relevant scale is the inline type scale in lib/widgets/src/typography.dart: clideFontBadge (11), clideFontSmall (12), clideFontMeta (13), clideFontCaption/clideFontMono (14), clideFontBody (15). Drive sizing off those tokens (not bare numbers) so the row tracks the scale if it changes; the hero size can be a named large constant. Lay the size samples out in a single row/strip per entry, smallest to largest, labelled with the token/px so a reviewer sees exactly where each size lands.

### CLI shape

- Trivial case stays terse, mirroring image show: `clide icon show <name|0xNNNN> [<name> ...]` renders the bare glyph(s) with name + codepoint.
- Labelled/described case takes a structured payload (per entry has up to three fields, so flags get unwieldy): a JSON array via `--stdin`/`--file`, each item `{"icon": "gear", "label": "Settings", "description": "global scope"}` where label and description are optional. icon resolves by kebab-case name (PhosphorIcons.byName) or 0xNNNN codepoint.
- One card per invocation; the entries render as rows (or a grid when label/description are absent).

## Display-only vs. selectable (D-78 — key boundary)

The card itself is a CONVERSATION WIDGET and stays display-only (D-78): it shows the labelled icon options and a click may copy the codepoint/name, but it does NOT resolve a selection inline. When the offer needs to be an actual PICK that returns a choice, that selection belongs in the interaction zone (AskUserQuestion-style option list that replaces the composer), NOT inline in the transcript — see the interaction-zone rule. So scope this ticket to the display/offer card; an interaction-zone icon picker (or feeding these entries into an AskUserQuestion option list) is a follow-up, not part of this card. Flag which path we want before building the selectable variant.

## Notes / scope

- Name->codepoint resolution ALREADY EXISTS: lib/widgets/src/icons/phosphor_glyphs.g.dart (generated, 1512 glyphs) + PhosphorIcons.byName. The earlier ''OPTIONAL: generate the full set'' caveat is resolved — every named glyph is already resolvable; the 49 curated consts in phosphor.dart remain curated sugar.
- Every glyph already renders via PhosphorIconPainter(0xNNNN).
- label and description are both optional per entry; an entry with neither degrades to the bare-preview look.
- Surfaced 2026-06-10 while choosing settings scope icons (T-302); refined 2026-06-10 to cover multi-icon labelled offer/choice lists.

## Acceptance

- `clide icon show` accepts multiple icons in one call and renders them in a single conversation card.
- A structured (JSON) input lets each icon carry an optional label and optional description, both rendered alongside the glyph.
- Each icon renders at multiple sizes: a large hero plus one sample at each inline font-size token (badge 11 -> body 15), sized off the typography tokens and labelled so the reviewer sees legibility at real UI sizes.
- The card is display-only (no inline selection); the description records that a selectable picker routes through the interaction zone as a separate follow-up.
- Unknown/invalid icon names fail with a clear user error, not a blank glyph.', NULL, '2026-06-10 10:41:56', '2026-06-10 10:41:56', '2026-06-10 10:41:56', NULL, 'cd2ddb517ae86b0e0751a599a99c3acd', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB234WP4Y6Q16A0HFW8BSXMG', 'title', 'Native Phosphor glyph preview card (clide icon show)', 'Native Phosphor glyph card — multi-icon list with optional labels/descriptions (previews + choice offers)', NULL, '2026-06-10 10:41:56', '2026-06-10 10:41:56', '2026-06-10 10:41:56', NULL, 'fd46733997b9f01126da8e45a3f2a52a', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB234WP4Y6Q16A0HFW8BSXMG', 'description', 'A conversation-pane card that renders one OR MANY Phosphor glyphs by name/codepoint, each with an optional label and an optional description line, so icons can be previewed and compared in the live pane — and so a set of candidate icons can be offered as a labelled choice list (e.g. picking settings-scope icons, T-302).

## Why

Picking icons needs to SEE real glyphs side by side with what each one means. Frame0 can''t render Phosphor (private-use codepoints, no font) and goldens render the font as Ahem boxes, so preview only works where the app has the font — a native card is the vehicle. Beyond a bare grid, real icon decisions are ''which of these N icons, for these N meanings'' — so each entry wants an optional label (what we''d call it) and an optional description (what it represents), turning the card into an offer/choice list.

## Deliverable

A conversation-pane card (peer of the image card, T-249/T-252) that renders a list/grid of entries, each entry = glyph + optional label + optional description, driven by the clide CLI (D-6 parity). Uses the bundled Phosphor.ttf via PhosphorIconPainter.

### Multi-size rendering (per entry)

Each icon is shown at SEVERAL sizes, not one: (1) a large hero rendering so the glyph''s detail is clearly legible, and (2) a sample at each font-size token the app actually uses inline, so you can judge how the glyph reads at real UI sizes. The relevant scale is the inline type scale in lib/widgets/src/typography.dart: clideFontBadge (11), clideFontSmall (12), clideFontMeta (13), clideFontCaption/clideFontMono (14), clideFontBody (15). Drive sizing off those tokens (not bare numbers) so the row tracks the scale if it changes; the hero size can be a named large constant. Lay the size samples out in a single row/strip per entry, smallest to largest, labelled with the token/px so a reviewer sees exactly where each size lands.

### CLI shape

- Trivial case stays terse, mirroring image show: `clide icon show <name|0xNNNN> [<name> ...]` renders the bare glyph(s) with name + codepoint.
- Labelled/described case takes a structured payload (per entry has up to three fields, so flags get unwieldy): a JSON array via `--stdin`/`--file`, each item `{"icon": "gear", "label": "Settings", "description": "global scope"}` where label and description are optional. icon resolves by kebab-case name (PhosphorIcons.byName) or 0xNNNN codepoint.
- One card per invocation; the entries render as rows (or a grid when label/description are absent).

## Display-only vs. selectable (D-78 — key boundary)

The card itself is a CONVERSATION WIDGET and stays display-only (D-78): it shows the labelled icon options and a click may copy the codepoint/name, but it does NOT resolve a selection inline. When the offer needs to be an actual PICK that returns a choice, that selection belongs in the interaction zone (AskUserQuestion-style option list that replaces the composer), NOT inline in the transcript — see the interaction-zone rule. So scope this ticket to the display/offer card; an interaction-zone icon picker (or feeding these entries into an AskUserQuestion option list) is a follow-up, not part of this card. Flag which path we want before building the selectable variant.

## Notes / scope

- Name->codepoint resolution ALREADY EXISTS: lib/widgets/src/icons/phosphor_glyphs.g.dart (generated, 1512 glyphs) + PhosphorIcons.byName. The earlier ''OPTIONAL: generate the full set'' caveat is resolved — every named glyph is already resolvable; the 49 curated consts in phosphor.dart remain curated sugar.
- Every glyph already renders via PhosphorIconPainter(0xNNNN).
- label and description are both optional per entry; an entry with neither degrades to the bare-preview look.
- Surfaced 2026-06-10 while choosing settings scope icons (T-302); refined 2026-06-10 to cover multi-icon labelled offer/choice lists.

## Acceptance

- `clide icon show` accepts multiple icons in one call and renders them in a single conversation card.
- A structured (JSON) input lets each icon carry an optional label and optional description, both rendered alongside the glyph.
- Each icon renders at multiple sizes: a large hero plus one sample at each inline font-size token (badge 11 -> body 15), sized off the typography tokens and labelled so the reviewer sees legibility at real UI sizes.
- The card is display-only (no inline selection); the description records that a selectable picker routes through the interaction zone as a separate follow-up.
- Unknown/invalid icon names fail with a clear user error, not a blank glyph.', 'A conversation-pane card that renders one OR MANY Phosphor glyphs by name/codepoint, each with an optional label and an optional description line, so icons can be previewed and compared in the live pane — and so a set of candidate icons can be offered as a labelled choice list (e.g. picking settings-scope icons, T-302).

## Why

Picking icons needs to SEE real glyphs side by side with what each one means. Frame0 can''t render Phosphor (private-use codepoints, no font) and goldens render the font as Ahem boxes, so preview only works where the app has the font — a native card is the vehicle. Beyond a bare grid, real icon decisions are ''which of these N icons, for these N meanings'' — so each entry wants an optional label (what we''d call it) and an optional description (what it represents), turning the card into an offer/choice list.

## Deliverable

A conversation-pane card (peer of the image card, T-249/T-252) that renders a list/grid of entries, each entry = glyph + optional label + optional description, driven by the clide CLI (D-6 parity). Uses the bundled Phosphor.ttf via PhosphorIconPainter.

### Multi-size rendering (per entry)

Each icon is shown at SEVERAL sizes, not one: (1) a large hero rendering at 48px so the glyph''s detail is clearly legible, and (2) a sample at each font-size token the app actually uses inline, so you can judge how the glyph reads at real UI sizes. The relevant inline scale is in lib/widgets/src/typography.dart: clideFontBadge (11), clideFontSmall (12), clideFontMeta (13), clideFontCaption/clideFontMono (14), clideFontBody (15). Drive the inline samples off those tokens (not bare numbers) so the row tracks the scale if it changes. The 48px hero is larger than any existing type token (welcome banner is 52, dialog title 16), so add a named preview constant for it (e.g. clideIconPreviewHero = 48) rather than a bare 48 — keep the scale coherent. Lay the size samples out in a single row/strip per entry, smallest to largest, labelled with the token/px so a reviewer sees exactly where each size lands.

### CLI shape

- Trivial case stays terse, mirroring image show: `clide icon show <name|0xNNNN> [<name> ...]` renders the bare glyph(s) with name + codepoint.
- Labelled/described case takes a structured payload (per entry has up to three fields, so flags get unwieldy): a JSON array via `--stdin`/`--file`, each item `{"icon": "gear", "label": "Settings", "description": "global scope"}` where label and description are optional. icon resolves by kebab-case name (PhosphorIcons.byName) or 0xNNNN codepoint.
- One card per invocation; the entries render as rows (or a grid when label/description are absent).

## Display-only card + interaction-zone selection (D-78 — decided)

DECIDED: the display card is display-only; the SELECTION happens in the convo box (interaction zone), not on the card. The card renders the labelled icon options for the user to SEE; when a pick is needed, Claude offers a matching choice list in the interaction zone (AskUserQuestion-style options that replace the composer), and the user selects there. This keeps conversation widgets display-only per D-78 and the interaction-zone rule.

The LABEL is the bridge between the two surfaces: Claude attaches a label to each icon on the display card, then offers the SAME labels as the options in the interaction-zone choice list — so ''I pick Settings'' in the convo box maps unambiguously back to the glyph the user saw on the card. That''s why per-entry labels are first-class here: they exist to facilitate this show-then-pick flow, with the description giving the extra context that doesn''t fit a one-word option. The card may still copy a codepoint/name on click (a convenience), but it never resolves the choice itself.

## Notes / scope

- Name->codepoint resolution ALREADY EXISTS: lib/widgets/src/icons/phosphor_glyphs.g.dart (generated, 1512 glyphs) + PhosphorIcons.byName. The earlier ''OPTIONAL: generate the full set'' caveat is resolved — every named glyph is already resolvable; the 49 curated consts in phosphor.dart remain curated sugar.
- Every glyph already renders via PhosphorIconPainter(0xNNNN).
- label and description are both optional per entry; an entry with neither degrades to the bare-preview look.
- Surfaced 2026-06-10 while choosing settings scope icons (T-302); refined 2026-06-10 to cover multi-icon labelled offer/choice lists.

## Acceptance

- `clide icon show` accepts multiple icons in one call and renders them in a single conversation card.
- A structured (JSON) input lets each icon carry an optional label and optional description, both rendered alongside the glyph.
- Each icon renders at multiple sizes: a 48px hero (new named constant, e.g. clideIconPreviewHero) plus one sample at each inline font-size token (badge 11 -> body 15), sized off the typography tokens and labelled so the reviewer sees legibility at real UI sizes.
- The card is display-only (no inline selection); selection happens in the interaction zone (convo box) via a Claude-offered choice list whose options reuse the per-icon labels from the card.
- Unknown/invalid icon names fail with a clear user error, not a blank glyph.', NULL, '2026-06-10 10:43:01', '2026-06-10 10:43:01', '2026-06-10 10:43:01', NULL, 'fdb996091e37ea8551ea0b002afb0291', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB234WP4Y6Q16A0HFW8BSXMG', 'description', 'A conversation-pane card that renders one OR MANY Phosphor glyphs by name/codepoint, each with an optional label and an optional description line, so icons can be previewed and compared in the live pane — and so a set of candidate icons can be offered as a labelled choice list (e.g. picking settings-scope icons, T-302).

## Why

Picking icons needs to SEE real glyphs side by side with what each one means. Frame0 can''t render Phosphor (private-use codepoints, no font) and goldens render the font as Ahem boxes, so preview only works where the app has the font — a native card is the vehicle. Beyond a bare grid, real icon decisions are ''which of these N icons, for these N meanings'' — so each entry wants an optional label (what we''d call it) and an optional description (what it represents), turning the card into an offer/choice list.

## Deliverable

A conversation-pane card (peer of the image card, T-249/T-252) that renders a list/grid of entries, each entry = glyph + optional label + optional description, driven by the clide CLI (D-6 parity). Uses the bundled Phosphor.ttf via PhosphorIconPainter.

### Multi-size rendering (per entry)

Each icon is shown at SEVERAL sizes, not one: (1) a large hero rendering at 48px so the glyph''s detail is clearly legible, and (2) a sample at each font-size token the app actually uses inline, so you can judge how the glyph reads at real UI sizes. The relevant inline scale is in lib/widgets/src/typography.dart: clideFontBadge (11), clideFontSmall (12), clideFontMeta (13), clideFontCaption/clideFontMono (14), clideFontBody (15). Drive the inline samples off those tokens (not bare numbers) so the row tracks the scale if it changes. The 48px hero is larger than any existing type token (welcome banner is 52, dialog title 16), so add a named preview constant for it (e.g. clideIconPreviewHero = 48) rather than a bare 48 — keep the scale coherent. Lay the size samples out in a single row/strip per entry, smallest to largest, labelled with the token/px so a reviewer sees exactly where each size lands.

### CLI shape

- Trivial case stays terse, mirroring image show: `clide icon show <name|0xNNNN> [<name> ...]` renders the bare glyph(s) with name + codepoint.
- Labelled/described case takes a structured payload (per entry has up to three fields, so flags get unwieldy): a JSON array via `--stdin`/`--file`, each item `{"icon": "gear", "label": "Settings", "description": "global scope"}` where label and description are optional. icon resolves by kebab-case name (PhosphorIcons.byName) or 0xNNNN codepoint.
- One card per invocation; the entries render as rows (or a grid when label/description are absent).

## Display-only card + interaction-zone selection (D-78 — decided)

DECIDED: the display card is display-only; the SELECTION happens in the convo box (interaction zone), not on the card. The card renders the labelled icon options for the user to SEE; when a pick is needed, Claude offers a matching choice list in the interaction zone (AskUserQuestion-style options that replace the composer), and the user selects there. This keeps conversation widgets display-only per D-78 and the interaction-zone rule.

The LABEL is the bridge between the two surfaces: Claude attaches a label to each icon on the display card, then offers the SAME labels as the options in the interaction-zone choice list — so ''I pick Settings'' in the convo box maps unambiguously back to the glyph the user saw on the card. That''s why per-entry labels are first-class here: they exist to facilitate this show-then-pick flow, with the description giving the extra context that doesn''t fit a one-word option. The card may still copy a codepoint/name on click (a convenience), but it never resolves the choice itself.

## Notes / scope

- Name->codepoint resolution ALREADY EXISTS: lib/widgets/src/icons/phosphor_glyphs.g.dart (generated, 1512 glyphs) + PhosphorIcons.byName. The earlier ''OPTIONAL: generate the full set'' caveat is resolved — every named glyph is already resolvable; the 49 curated consts in phosphor.dart remain curated sugar.
- Every glyph already renders via PhosphorIconPainter(0xNNNN).
- label and description are both optional per entry; an entry with neither degrades to the bare-preview look.
- Surfaced 2026-06-10 while choosing settings scope icons (T-302); refined 2026-06-10 to cover multi-icon labelled offer/choice lists.

## Acceptance

- `clide icon show` accepts multiple icons in one call and renders them in a single conversation card.
- A structured (JSON) input lets each icon carry an optional label and optional description, both rendered alongside the glyph.
- Each icon renders at multiple sizes: a 48px hero (new named constant, e.g. clideIconPreviewHero) plus one sample at each inline font-size token (badge 11 -> body 15), sized off the typography tokens and labelled so the reviewer sees legibility at real UI sizes.
- The card is display-only (no inline selection); selection happens in the interaction zone (convo box) via a Claude-offered choice list whose options reuse the per-icon labels from the card.
- Unknown/invalid icon names fail with a clear user error, not a blank glyph.', 'A conversation-pane card that renders one OR MANY Phosphor glyphs by name/codepoint, each with an optional label and an optional description line, so icons can be previewed and compared in the live pane — and so a set of candidate icons can be offered as a labelled choice list (e.g. picking settings-scope icons, T-302).

## Why

Picking icons needs to SEE real glyphs side by side with what each one means. Frame0 can''t render Phosphor (private-use codepoints, no font) and goldens render the font as Ahem boxes, so preview only works where the app has the font — a native card is the vehicle. Beyond a bare grid, real icon decisions are ''which of these N icons, for these N meanings'' — so each entry wants an optional label (what we''d call it) and an optional description (what it represents), turning the card into an offer/choice list.

## Deliverable

A conversation-pane card (peer of the image card, T-249/T-252) that renders a list/grid of entries, each entry = glyph + optional label + optional description, driven by the clide CLI (D-6 parity). Uses the bundled Phosphor.ttf via PhosphorIconPainter.

### Multi-size rendering (per entry)

Each icon is shown at SEVERAL sizes, not one: (1) a large hero rendering so the glyph''s detail is clearly legible, and (2) a sample at each font-size token the app actually uses inline, so you can judge how the glyph reads at real UI sizes. The relevant inline scale is in lib/widgets/src/typography.dart: clideFontBadge (11), clideFontSmall (12), clideFontMeta (13), clideFontCaption/clideFontMono (14), clideFontBody (15). Drive the inline samples off those tokens (not bare numbers) so the row tracks the scale if it changes. For the hero, REUSE the existing clideFontWelcomeBanner (52) token rather than adding a new constant — it''s already the app''s named oversized size; no new token needed. Lay the size samples out in a single row/strip per entry, smallest to largest, labelled with the token/px so a reviewer sees exactly where each size lands.

### CLI shape

- Trivial case stays terse, mirroring image show: `clide icon show <name|0xNNNN> [<name> ...]` renders the bare glyph(s) with name + codepoint.
- Labelled/described case takes a structured payload (per entry has up to three fields, so flags get unwieldy): a JSON array via `--stdin`/`--file`, each item `{"icon": "gear", "label": "Settings", "description": "global scope"}` where label and description are optional. icon resolves by kebab-case name (PhosphorIcons.byName) or 0xNNNN codepoint.
- One card per invocation; the entries render as rows (or a grid when label/description are absent).

## Display-only card + interaction-zone selection (D-78 — decided)

DECIDED: the display card is display-only; the SELECTION happens in the convo box (interaction zone), not on the card. The card renders the labelled icon options for the user to SEE; when a pick is needed, Claude offers a matching choice list in the interaction zone (AskUserQuestion-style options that replace the composer), and the user selects there. This keeps conversation widgets display-only per D-78 and the interaction-zone rule.

The LABEL is the bridge between the two surfaces: Claude attaches a label to each icon on the display card, then offers the SAME labels as the options in the interaction-zone choice list — so ''I pick Settings'' in the convo box maps unambiguously back to the glyph the user saw on the card. That''s why per-entry labels are first-class here: they exist to facilitate this show-then-pick flow, with the description giving the extra context that doesn''t fit a one-word option. The card may still copy a codepoint/name on click (a convenience), but it never resolves the choice itself.

## Notes / scope

- Name->codepoint resolution ALREADY EXISTS: lib/widgets/src/icons/phosphor_glyphs.g.dart (generated, 1512 glyphs) + PhosphorIcons.byName. The earlier ''OPTIONAL: generate the full set'' caveat is resolved — every named glyph is already resolvable; the 49 curated consts in phosphor.dart remain curated sugar.
- Every glyph already renders via PhosphorIconPainter(0xNNNN).
- label and description are both optional per entry; an entry with neither degrades to the bare-preview look.
- Surfaced 2026-06-10 while choosing settings scope icons (T-302); refined 2026-06-10 to cover multi-icon labelled offer/choice lists.

## Acceptance

- `clide icon show` accepts multiple icons in one call and renders them in a single conversation card.
- A structured (JSON) input lets each icon carry an optional label and optional description, both rendered alongside the glyph.
- Each icon renders at multiple sizes: a hero at the existing clideFontWelcomeBanner (52) token plus one sample at each inline font-size token (badge 11 -> body 15), sized off the typography tokens and labelled so the reviewer sees legibility at real UI sizes.
- The card is display-only (no inline selection); selection happens in the interaction zone (convo box) via a Claude-offered choice list whose options reuse the per-icon labels from the card.
- Unknown/invalid icon names fail with a clear user error, not a blank glyph.', NULL, '2026-06-10 10:44:06', '2026-06-10 10:44:06', '2026-06-10 10:44:06', NULL, 'a55e979e042abaf7b0758b5dbba183f7', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB23Z52EVGQ4ZDAQ5BVAJ13R', 'status', 'ready', 'done', NULL, '2026-06-10 10:46:25', '2026-06-10 10:46:25', '2026-06-10 10:46:25', NULL, '4f76b8c659b36db90ac957a42c610d6f', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB234WP4Y6Q16A0HFW8BSXMG', 'description', 'A conversation-pane card that renders one OR MANY Phosphor glyphs by name/codepoint, each with an optional label and an optional description line, so icons can be previewed and compared in the live pane — and so a set of candidate icons can be offered as a labelled choice list (e.g. picking settings-scope icons, T-302).

## Why

Picking icons needs to SEE real glyphs side by side with what each one means. Frame0 can''t render Phosphor (private-use codepoints, no font) and goldens render the font as Ahem boxes, so preview only works where the app has the font — a native card is the vehicle. Beyond a bare grid, real icon decisions are ''which of these N icons, for these N meanings'' — so each entry wants an optional label (what we''d call it) and an optional description (what it represents), turning the card into an offer/choice list.

## Deliverable

A conversation-pane card (peer of the image card, T-249/T-252) that renders a list/grid of entries, each entry = glyph + optional label + optional description, driven by the clide CLI (D-6 parity). Uses the bundled Phosphor.ttf via PhosphorIconPainter.

### Multi-size rendering (per entry)

Each icon is shown at SEVERAL sizes, not one: (1) a large hero rendering so the glyph''s detail is clearly legible, and (2) a sample at each font-size token the app actually uses inline, so you can judge how the glyph reads at real UI sizes. The relevant inline scale is in lib/widgets/src/typography.dart: clideFontBadge (11), clideFontSmall (12), clideFontMeta (13), clideFontCaption/clideFontMono (14), clideFontBody (15). Drive the inline samples off those tokens (not bare numbers) so the row tracks the scale if it changes. For the hero, REUSE the existing clideFontWelcomeBanner (52) token rather than adding a new constant — it''s already the app''s named oversized size; no new token needed. Lay the size samples out in a single row/strip per entry, smallest to largest, labelled with the token/px so a reviewer sees exactly where each size lands.

### CLI shape

- Trivial case stays terse, mirroring image show: `clide icon show <name|0xNNNN> [<name> ...]` renders the bare glyph(s) with name + codepoint.
- Labelled/described case takes a structured payload (per entry has up to three fields, so flags get unwieldy): a JSON array via `--stdin`/`--file`, each item `{"icon": "gear", "label": "Settings", "description": "global scope"}` where label and description are optional. icon resolves by kebab-case name (PhosphorIcons.byName) or 0xNNNN codepoint.
- One card per invocation; the entries render as rows (or a grid when label/description are absent).

## Display-only card + interaction-zone selection (D-78 — decided)

DECIDED: the display card is display-only; the SELECTION happens in the convo box (interaction zone), not on the card. The card renders the labelled icon options for the user to SEE; when a pick is needed, Claude offers a matching choice list in the interaction zone (AskUserQuestion-style options that replace the composer), and the user selects there. This keeps conversation widgets display-only per D-78 and the interaction-zone rule.

The LABEL is the bridge between the two surfaces: Claude attaches a label to each icon on the display card, then offers the SAME labels as the options in the interaction-zone choice list — so ''I pick Settings'' in the convo box maps unambiguously back to the glyph the user saw on the card. That''s why per-entry labels are first-class here: they exist to facilitate this show-then-pick flow, with the description giving the extra context that doesn''t fit a one-word option. The card may still copy a codepoint/name on click (a convenience), but it never resolves the choice itself.

## Notes / scope

- Name->codepoint resolution ALREADY EXISTS: lib/widgets/src/icons/phosphor_glyphs.g.dart (generated, 1512 glyphs) + PhosphorIcons.byName. The earlier ''OPTIONAL: generate the full set'' caveat is resolved — every named glyph is already resolvable; the 49 curated consts in phosphor.dart remain curated sugar.
- Every glyph already renders via PhosphorIconPainter(0xNNNN).
- label and description are both optional per entry; an entry with neither degrades to the bare-preview look.
- Surfaced 2026-06-10 while choosing settings scope icons (T-302); refined 2026-06-10 to cover multi-icon labelled offer/choice lists.

## Acceptance

- `clide icon show` accepts multiple icons in one call and renders them in a single conversation card.
- A structured (JSON) input lets each icon carry an optional label and optional description, both rendered alongside the glyph.
- Each icon renders at multiple sizes: a hero at the existing clideFontWelcomeBanner (52) token plus one sample at each inline font-size token (badge 11 -> body 15), sized off the typography tokens and labelled so the reviewer sees legibility at real UI sizes.
- The card is display-only (no inline selection); selection happens in the interaction zone (convo box) via a Claude-offered choice list whose options reuse the per-icon labels from the card.
- Unknown/invalid icon names fail with a clear user error, not a blank glyph.', 'A conversation-pane card that renders one OR MANY Phosphor glyphs by name/codepoint, each with an optional label and an optional description line, so icons can be previewed and compared in the live pane — and so a set of candidate icons can be offered as a labelled choice list (e.g. picking settings-scope icons, T-302).

## Why

Picking icons needs to SEE real glyphs side by side with what each one means. Frame0 can''t render Phosphor (private-use codepoints, no font) and goldens render the font as Ahem boxes, so preview only works where the app has the font — a native card is the vehicle. Beyond a bare grid, real icon decisions are ''which of these N icons, for these N meanings'' — so each entry wants an optional label (what we''d call it) and an optional description (what it represents), turning the card into an offer/choice list.

## Deliverable

A conversation-pane card (peer of the image card, T-249/T-252) that renders a list/grid of entries, each entry = glyph + optional label + optional description, driven by the clide CLI (D-6 parity). Uses the bundled Phosphor.ttf via PhosphorIconPainter.

### Multi-size rendering (per entry)

Each icon is shown at SEVERAL sizes, not one: (1) a large hero rendering so the glyph''s detail is clearly legible, and (2) a sample at each font-size token the app actually uses inline, so you can judge how the glyph reads at real UI sizes. The relevant inline scale is in lib/widgets/src/typography.dart: clideFontBadge (11), clideFontSmall (12), clideFontMeta (13), clideFontCaption/clideFontMono (14), clideFontBody (15). Drive the inline samples off those tokens (not bare numbers) so the row tracks the scale if it changes. For the hero, REUSE the existing clideFontWelcomeBanner (52) token rather than adding a new constant — it''s already the app''s named oversized size; no new token needed. Lay the size samples out in a single row/strip per entry, smallest to largest, labelled with the token/px so a reviewer sees exactly where each size lands.

### CLI shape + IPC wiring (mirror image.show exactly)

Follow the image-card template (lib/src/daemon/image_commands.dart) end to end — it is the proven D-6 parity pattern:

- REGISTRATION: a dotted `icon.show` command on DaemonDispatcher (invoked as `clide icon show`), declared with a CommandSchema — positional + per-arg ArgSpec — exactly like image.show''s `{positional: [''path''], args: {...}}`. Handler stays Flutter-free so it runs under `dart test`.
- BARE PREVIEW (variadic): one or more icons as positionals via ArgType.stringList — `clide icon show gear folder gauge` — each a kebab-case name (resolved by PhosphorIcons.byName) or a 0xNNNN codepoint. stringList is already supported by the schema (lib/src/ipc/command_schema.dart) and the argv parser, so no new CLI plumbing.
- LABELLED/DESCRIBED entries: a `--file <path.json>` flag whose value is a JSON array of `{"icon": "gear", "label": "Settings", "description": "global scope"}` (label, description optional); the handler reads and parses the file. NOTE: do NOT spec `--stdin` — clide''s CLI argv parser (lib/src/cli/argv_to_request.dart) only produces positionals/flags/passthrough and has no stdin path, so a `--file` flag (or repeated flags) is the grounded choice unless we deliberately add stdin support as separate work.
- RENDER PATH: validate + resolve icon names in the handler (inject a resolver the way image.show injects ImagePathResolver, so headless/dart-test stays filesystem-free), then publish on a dedicated MessageBus channel — e.g. `iconShowChannel = ''icon''`, peer of `imageShowChannel = ''image''` — captured post-boot in main.dart; the Claude extension subscribes to that literal and injects the card into the primary session''s conversation log. Honest failure (IpcError userError/notFound) on an unknown glyph name or a malformed/missing --file, and on no live UI bus (headless), mirroring image.show.
- One card per invocation; entries render as rows (or a grid when label/description are absent).

## Display-only card + interaction-zone selection (D-78 — decided)

DECIDED: the display card is display-only; the SELECTION happens in the convo box (interaction zone), not on the card. The card renders the labelled icon options for the user to SEE; when a pick is needed, Claude offers a matching choice list in the interaction zone (AskUserQuestion-style options that replace the composer), and the user selects there. This keeps conversation widgets display-only per D-78 and the interaction-zone rule.

The LABEL is the bridge between the two surfaces: Claude attaches a label to each icon on the display card, then offers the SAME labels as the options in the interaction-zone choice list — so ''I pick Settings'' in the convo box maps unambiguously back to the glyph the user saw on the card. That''s why per-entry labels are first-class here: they exist to facilitate this show-then-pick flow, with the description giving the extra context that doesn''t fit a one-word option. The card may still copy a codepoint/name on click (a convenience), but it never resolves the choice itself.

## Notes / scope

- Name->codepoint resolution ALREADY EXISTS: lib/widgets/src/icons/phosphor_glyphs.g.dart (generated, 1512 glyphs) + PhosphorIcons.byName. The earlier ''OPTIONAL: generate the full set'' caveat is resolved — every named glyph is already resolvable; the 49 curated consts in phosphor.dart remain curated sugar.
- Every glyph already renders via PhosphorIconPainter(0xNNNN).
- label and description are both optional per entry; an entry with neither degrades to the bare-preview look.
- Surfaced 2026-06-10 while choosing settings scope icons (T-302); refined 2026-06-10 to cover multi-icon labelled offer/choice lists.

## Acceptance

- `icon.show` is registered on DaemonDispatcher with a CommandSchema and invoked as `clide icon show`, mirroring image.show; the handler is Flutter-free and publishes on an `icon` MessageBus channel injected by the Claude extension.
- `clide icon show <name> [<name> ...]` accepts multiple icons (variadic stringList positionals) in one call and renders them in a single conversation card.
- A `--file <path.json>` payload lets each icon carry an optional label and optional description, both rendered alongside the glyph (no --stdin — not supported by the CLI parser).
- Each icon renders at multiple sizes: a hero at the existing clideFontWelcomeBanner (52) token plus one sample at each inline font-size token (badge 11 -> body 15), sized off the typography tokens and labelled so the reviewer sees legibility at real UI sizes.
- The card is display-only (no inline selection); selection happens in the interaction zone (convo box) via a Claude-offered choice list whose options reuse the per-icon labels from the card.
- Unknown/invalid icon names fail with a clear user error, not a blank glyph.', NULL, '2026-06-10 10:49:59', '2026-06-10 10:49:59', '2026-06-10 10:49:59', NULL, '071db34b13832c72d0762fb6f47d40f5', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB2ACSDBDZARV3NNGYD9NYYR', 'description', NULL, 'Add a stdin path to clide''s CLI so a command can receive a JSON payload piped in — `… | clide icon show --stdin`, `cat meta.json | clide image show foo.png --stdin` — instead of only positionals/flags or a `--file`.

## Why

Structured commands (the labelled icon-card entries in T-313, image annotation metadata in T-316) want a JSON payload that''s awkward to express as flags. Today clide''s CLI argv parser (lib/src/cli/argv_to_request.dart) only produces positionals, --flags, and `-- passthrough`; there is no stdin path. T-313 therefore falls back to a `--file <path.json>` flag. A `--stdin` convention is the ergonomic peer of `--file` for piping, and is shared infra both icon.show and image.show consume.

## Where the work lives

clide''s IPC server runs in-process and the `clide` CLI is a thin client that serialises argv into an IpcRequest over CLIDE_SOCK. So stdin must be slurped CLIENT-SIDE (in lib/src/cli/, around argv_to_request.dart / argv_dispatch.dart) and folded into the request before it is sent — the in-process handler never sees the real stdin. Decide how it surfaces in the envelope: e.g. a reserved `stdin`/`payload` field on IpcRequest, or a synthesised arg the CommandSchema can opt into (an ArgSpec flag like `acceptsStdin`, mirroring how ArgType.stringList is declared in lib/src/ipc/command_schema.dart).

## Scope / decisions

- Generic infra, not icon/image specific — once landed, any command opts in via its CommandSchema.
- Keep `--file` working; --stdin and --file should be mutually exclusive (error if both given) or layered with a defined precedence.
- Text/JSON payloads only to start; define a size cap and a clear error when --stdin is passed but stdin is empty/not a pipe (don''t hang waiting on a TTY).
- Honest IpcError (userError) on malformed JSON, surfaced like image.show''s other validation failures.
- D-6 parity: document the stdin convention alongside the other CLI verbs.

## Acceptance

- A command can declare (via CommandSchema) that it accepts a stdin payload; piping JSON in populates the IpcRequest with that payload.
- `clide icon show --stdin` (T-313) and `clide image show <path> --stdin` (T-316) both consume it.
- --stdin + --file together is a clear user error; --stdin with no piped input fails fast, never hangs on a TTY.
- Malformed JSON returns a userError with a helpful message.

Unblocks the piped-JSON variants of T-313 (icon entries) and T-316 (image annotations); both can also ship with --file independently of this.', NULL, '2026-06-10 10:55:30', '2026-06-10 10:55:30', '2026-06-10 10:55:30', NULL, '60b96ae9749305f70e7ca44457cf9e2b', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB2AD3HPR3HXSVASVZEX8PK0', 'description', NULL, 'Give `clide image show` the same structured-metadata plumbing the icon card gets (T-313), so an image driven into the conversation can carry ANNOTATIONS — not just a single one-line caption.

## Why

Today image.show (lib/src/daemon/image_commands.dart) takes a `path` positional plus an optional `--caption` string, and ImageMessage (lib/builtin/claude/src/transcript_reader.dart:160) holds only `path` + optional one-line `caption`. When showing a screenshot/wireframe to discuss, one line is thin — we want to attach a title/label, a longer description, and potentially captioned markers (callouts on specific spots). This mirrors the per-entry label+description the icon card introduces.

## Deliverable

Extend image.show to accept a JSON metadata payload (via the new stdin plumbing T-315 and/or a `--file <path.json>` flag, same as T-313''s icon entries) describing the image''s annotations, e.g.:

  { "path": "docs/shot.png", "label": "HUD v3", "description": "note the cramped status row", "caption": "before the fix" }

Extend ImageMessage + the image card to render the richer metadata. Keep the existing `clide image show <path> --caption "…"` form working unchanged (back-compat); the JSON payload is additive.

## Open decision — text vs visual annotation

''Annotated'' could mean (a) richer TEXT metadata shown around the image (label + description + caption), or (b) VISUAL overlays drawn ON the image (markers/arrows/numbered callouts at coordinates). Start with (a) — straightforward extension of the current card. (b) is a bigger, clide-owned CustomPaint job (markers:[{x,y,label}] painted over the image); feasible since the image card is our own rendering, but scope it as a follow-up unless we decide we need it now. Flag which we want before building markers.

## Dependencies

- Pairs with T-315 (stdin JSON plumbing) for the piped form; can land with `--file` alone if T-315 isn''t ready.
- Parallel to T-313 (icon card) — same --file/--stdin metadata pattern, same Flutter-free handler + MessageBus publish path.

## Acceptance

- `clide image show` accepts a JSON metadata payload (via --file, and via --stdin once T-315 lands) carrying at least label + description alongside the existing caption.
- ImageMessage + the image card render the added metadata.
- The existing `image show <path> [--caption]` form is unchanged.
- Malformed payload / unknown fields fail with a clear userError, mirroring image.show''s current validation.
- Visual marker overlays are explicitly noted as a separate follow-up unless pulled in by decision.', NULL, '2026-06-10 10:55:34', '2026-06-10 10:55:34', '2026-06-10 10:55:34', NULL, '8ff1b92539fd1e66d249a8ebb437197d', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB234WP4Y6Q16A0HFW8BSXMG', 'description', 'A conversation-pane card that renders one OR MANY Phosphor glyphs by name/codepoint, each with an optional label and an optional description line, so icons can be previewed and compared in the live pane — and so a set of candidate icons can be offered as a labelled choice list (e.g. picking settings-scope icons, T-302).

## Why

Picking icons needs to SEE real glyphs side by side with what each one means. Frame0 can''t render Phosphor (private-use codepoints, no font) and goldens render the font as Ahem boxes, so preview only works where the app has the font — a native card is the vehicle. Beyond a bare grid, real icon decisions are ''which of these N icons, for these N meanings'' — so each entry wants an optional label (what we''d call it) and an optional description (what it represents), turning the card into an offer/choice list.

## Deliverable

A conversation-pane card (peer of the image card, T-249/T-252) that renders a list/grid of entries, each entry = glyph + optional label + optional description, driven by the clide CLI (D-6 parity). Uses the bundled Phosphor.ttf via PhosphorIconPainter.

### Multi-size rendering (per entry)

Each icon is shown at SEVERAL sizes, not one: (1) a large hero rendering so the glyph''s detail is clearly legible, and (2) a sample at each font-size token the app actually uses inline, so you can judge how the glyph reads at real UI sizes. The relevant inline scale is in lib/widgets/src/typography.dart: clideFontBadge (11), clideFontSmall (12), clideFontMeta (13), clideFontCaption/clideFontMono (14), clideFontBody (15). Drive the inline samples off those tokens (not bare numbers) so the row tracks the scale if it changes. For the hero, REUSE the existing clideFontWelcomeBanner (52) token rather than adding a new constant — it''s already the app''s named oversized size; no new token needed. Lay the size samples out in a single row/strip per entry, smallest to largest, labelled with the token/px so a reviewer sees exactly where each size lands.

### CLI shape + IPC wiring (mirror image.show exactly)

Follow the image-card template (lib/src/daemon/image_commands.dart) end to end — it is the proven D-6 parity pattern:

- REGISTRATION: a dotted `icon.show` command on DaemonDispatcher (invoked as `clide icon show`), declared with a CommandSchema — positional + per-arg ArgSpec — exactly like image.show''s `{positional: [''path''], args: {...}}`. Handler stays Flutter-free so it runs under `dart test`.
- BARE PREVIEW (variadic): one or more icons as positionals via ArgType.stringList — `clide icon show gear folder gauge` — each a kebab-case name (resolved by PhosphorIcons.byName) or a 0xNNNN codepoint. stringList is already supported by the schema (lib/src/ipc/command_schema.dart) and the argv parser, so no new CLI plumbing.
- LABELLED/DESCRIBED entries: a `--file <path.json>` flag whose value is a JSON array of `{"icon": "gear", "label": "Settings", "description": "global scope"}` (label, description optional); the handler reads and parses the file. NOTE: do NOT spec `--stdin` — clide''s CLI argv parser (lib/src/cli/argv_to_request.dart) only produces positionals/flags/passthrough and has no stdin path, so a `--file` flag (or repeated flags) is the grounded choice unless we deliberately add stdin support as separate work.
- RENDER PATH: validate + resolve icon names in the handler (inject a resolver the way image.show injects ImagePathResolver, so headless/dart-test stays filesystem-free), then publish on a dedicated MessageBus channel — e.g. `iconShowChannel = ''icon''`, peer of `imageShowChannel = ''image''` — captured post-boot in main.dart; the Claude extension subscribes to that literal and injects the card into the primary session''s conversation log. Honest failure (IpcError userError/notFound) on an unknown glyph name or a malformed/missing --file, and on no live UI bus (headless), mirroring image.show.
- One card per invocation; entries render as rows (or a grid when label/description are absent).

## Display-only card + interaction-zone selection (D-78 — decided)

DECIDED: the display card is display-only; the SELECTION happens in the convo box (interaction zone), not on the card. The card renders the labelled icon options for the user to SEE; when a pick is needed, Claude offers a matching choice list in the interaction zone (AskUserQuestion-style options that replace the composer), and the user selects there. This keeps conversation widgets display-only per D-78 and the interaction-zone rule.

The LABEL is the bridge between the two surfaces: Claude attaches a label to each icon on the display card, then offers the SAME labels as the options in the interaction-zone choice list — so ''I pick Settings'' in the convo box maps unambiguously back to the glyph the user saw on the card. That''s why per-entry labels are first-class here: they exist to facilitate this show-then-pick flow, with the description giving the extra context that doesn''t fit a one-word option. The card may still copy a codepoint/name on click (a convenience), but it never resolves the choice itself.

## Notes / scope

- Name->codepoint resolution ALREADY EXISTS: lib/widgets/src/icons/phosphor_glyphs.g.dart (generated, 1512 glyphs) + PhosphorIcons.byName. The earlier ''OPTIONAL: generate the full set'' caveat is resolved — every named glyph is already resolvable; the 49 curated consts in phosphor.dart remain curated sugar.
- Every glyph already renders via PhosphorIconPainter(0xNNNN).
- label and description are both optional per entry; an entry with neither degrades to the bare-preview look.
- Surfaced 2026-06-10 while choosing settings scope icons (T-302); refined 2026-06-10 to cover multi-icon labelled offer/choice lists.

## Acceptance

- `icon.show` is registered on DaemonDispatcher with a CommandSchema and invoked as `clide icon show`, mirroring image.show; the handler is Flutter-free and publishes on an `icon` MessageBus channel injected by the Claude extension.
- `clide icon show <name> [<name> ...]` accepts multiple icons (variadic stringList positionals) in one call and renders them in a single conversation card.
- A `--file <path.json>` payload lets each icon carry an optional label and optional description, both rendered alongside the glyph (no --stdin — not supported by the CLI parser).
- Each icon renders at multiple sizes: a hero at the existing clideFontWelcomeBanner (52) token plus one sample at each inline font-size token (badge 11 -> body 15), sized off the typography tokens and labelled so the reviewer sees legibility at real UI sizes.
- The card is display-only (no inline selection); selection happens in the interaction zone (convo box) via a Claude-offered choice list whose options reuse the per-icon labels from the card.
- Unknown/invalid icon names fail with a clear user error, not a blank glyph.', 'A conversation-pane card that renders one OR MANY Phosphor glyphs by name/codepoint, each with an optional label and an optional description line, so icons can be previewed and compared in the live pane — and so a set of candidate icons can be offered as a labelled choice list (e.g. picking settings-scope icons, T-302).

## Why

Picking icons needs to SEE real glyphs side by side with what each one means. Frame0 can''t render Phosphor (private-use codepoints, no font) and goldens render the font as Ahem boxes, so preview only works where the app has the font — a native card is the vehicle. Beyond a bare grid, real icon decisions are ''which of these N icons, for these N meanings'' — so each entry wants an optional label (what we''d call it) and an optional description (what it represents), turning the card into an offer/choice list.

## Deliverable

A conversation-pane card (peer of the image card, T-249/T-252) that renders a list/grid of entries, each entry = glyph + optional label + optional description, driven by the clide CLI (D-6 parity). Uses the bundled Phosphor.ttf via PhosphorIconPainter.

### Multi-size rendering (per entry)

Each icon is shown at SEVERAL sizes, not one: (1) a large hero rendering so the glyph''s detail is clearly legible, and (2) a sample at each font-size token the app actually uses inline, so you can judge how the glyph reads at real UI sizes. The relevant inline scale is in lib/widgets/src/typography.dart: clideFontBadge (11), clideFontSmall (12), clideFontMeta (13), clideFontCaption/clideFontMono (14), clideFontBody (15). Drive the inline samples off those tokens (not bare numbers) so the row tracks the scale if it changes. For the hero, REUSE the existing clideFontWelcomeBanner (52) token rather than adding a new constant — it''s already the app''s named oversized size; no new token needed. Lay the size samples out in a single row/strip per entry, smallest to largest, labelled with the token/px so a reviewer sees exactly where each size lands.

### CLI shape + IPC wiring (mirror image.show exactly)

Follow the image-card template (lib/src/daemon/image_commands.dart) end to end — it is the proven D-6 parity pattern:

- REGISTRATION: a dotted `icon.show` command on DaemonDispatcher (invoked as `clide icon show`), declared with a CommandSchema — positional + per-arg ArgSpec — exactly like image.show''s `{positional: [''path''], args: {...}}`. Handler stays Flutter-free so it runs under `dart test`.
- BARE PREVIEW (variadic): one or more icons as positionals via ArgType.stringList — `clide icon show gear folder gauge` — each a kebab-case name (resolved by PhosphorIcons.byName) or a 0xNNNN codepoint. stringList is already supported by the schema (lib/src/ipc/command_schema.dart) and the argv parser, so no new CLI plumbing.
- LABELLED/DESCRIBED entries: a `--file <path.json>` flag whose value is a JSON array of `{"icon": "gear", "label": "Settings", "description": "global scope"}` (label, description optional); the handler reads and parses the file. NOTE: do NOT spec `--stdin` — clide''s CLI argv parser (lib/src/cli/argv_to_request.dart) only produces positionals/flags/passthrough and has no stdin path, so a `--file` flag (or repeated flags) is the grounded choice unless we deliberately add stdin support as separate work.
- RENDER PATH: validate + resolve icon names in the handler (inject a resolver the way image.show injects ImagePathResolver, so headless/dart-test stays filesystem-free), then publish on a dedicated MessageBus channel — e.g. `iconShowChannel = ''icon''`, peer of `imageShowChannel = ''image''` — captured post-boot in main.dart; the Claude extension subscribes to that literal and injects the card into the primary session''s conversation log. Honest failure (IpcError userError/notFound) on an unknown glyph name or a malformed/missing --file, and on no live UI bus (headless), mirroring image.show.
- One card per invocation; entries render as rows (or a grid when label/description are absent).

## Display-only card + interaction-zone selection (D-78 — decided)

DECIDED: the display card is display-only; the SELECTION happens in the convo box (interaction zone), not on the card. The card renders the labelled icon options for the user to SEE; when a pick is needed, Claude offers a matching choice list in the interaction zone (AskUserQuestion-style options that replace the composer), and the user selects there. This keeps conversation widgets display-only per D-78 and the interaction-zone rule.

The LABEL is the bridge between the two surfaces: Claude attaches a label to each icon on the display card, then offers the SAME labels as the options in the interaction-zone choice list — so ''I pick Settings'' in the convo box maps unambiguously back to the glyph the user saw on the card. That''s why per-entry labels are first-class here: they exist to facilitate this show-then-pick flow, with the description giving the extra context that doesn''t fit a one-word option. The card may still copy a codepoint/name on click (a convenience), but it never resolves the choice itself.

## Notes / scope

- Name->codepoint resolution ALREADY EXISTS: lib/widgets/src/icons/phosphor_glyphs.g.dart (generated, 1512 glyphs) + PhosphorIcons.byName. The earlier ''OPTIONAL: generate the full set'' caveat is resolved — every named glyph is already resolvable; the 49 curated consts in phosphor.dart remain curated sugar.
- Every glyph already renders via PhosphorIconPainter(0xNNNN).
- label and description are both optional per entry; an entry with neither degrades to the bare-preview look.
- Surfaced 2026-06-10 while choosing settings scope icons (T-302); refined 2026-06-10 to cover multi-icon labelled offer/choice lists.

## Acceptance

- `icon.show` is registered on DaemonDispatcher with a CommandSchema and invoked as `clide icon show`, mirroring image.show; the handler is Flutter-free and publishes on an `icon` MessageBus channel injected by the Claude extension.
- `clide icon show <name> [<name> ...]` accepts multiple icons (variadic stringList positionals) in one call and renders them in a single conversation card.
- A `--file <path.json>` payload lets each icon carry an optional label and optional description, both rendered alongside the glyph (no --stdin — not supported by the CLI parser).
- Each icon renders at multiple sizes: a hero at the existing clideFontWelcomeBanner (52) token plus one sample at each inline font-size token (badge 11 -> body 15), sized off the typography tokens and labelled so the reviewer sees legibility at real UI sizes.
- The card is display-only (no inline selection); selection happens in the interaction zone (convo box) via a Claude-offered choice list whose options reuse the per-icon labels from the card.
- Unknown/invalid icon names fail with a clear user error, not a blank glyph.

FOLLOW-UPS: the piped-JSON (--stdin) variant is split out as T-315 (generic CLI stdin plumbing); image.show gets the same metadata/annotation treatment in T-316. T-313 ships with --file regardless of T-315.', NULL, '2026-06-10 10:55:49', '2026-06-10 10:55:49', '2026-06-10 10:55:49', NULL, 'b75962f3fb5da0a8c44f7e059d7035b2', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB2EDCBYRBDSV9V1PJ1KE3CM', 'description', NULL, 'Epic for the unified conversation drawing card — ONE clide-owned canvas renderer driven by a JSON document, replacing the trend of one-off conversation renderers (image card, icon card, …). See decision D-91.

## The model

Think HTML `<canvas>`, NOT Obsidian''s `.canvas` (Obsidian naming its feature ''canvas'' doesn''t make its schema our pattern). The card''s JSON can express raw PRIMITIVES (rects/lines/text at coordinates — ''draw a box at x,y, a line from x,y to x,y'' works), but in the common case it runs in TEMPLATE mode: the JSON names a predefined component and the card grabs it. Templates lower onto the same primitive scene the raw API accepts (hybrid: scene-graph core + high-level block sugar).

Per drawn object there is an optional label + description widget rendered BENEATH it, shown only when those fields are present in the JSON.

The card is DISPLAY-ONLY (D-78) — selection/interaction happens in the interaction zone, never on the card. The labels are the bridge to interaction-zone choice lists (see T-313).

## Template set (expand as we go)

- image — display the file, lightbox on click
- icon — the multi-size glyph set (T-313)
- compare-images / before-after — two (or more) paths side by side, each with its label/description
- svg — render an SVG file
- graph — render a graph
- …more added incrementally; ''we will expand the templates as we go''

## Reuse goal

The same renderer is intended for reuse as the `.canvas` VIEWER elsewhere: a `.canvas` file is converted into this JSON (not the card adopting Obsidian''s schema natively). Narrows Q-4.

## Input

Driven via the clide CLI (D-6 parity), consuming the JSON-payload plumbing — `--file` and the stdin path (T-315).

## Children / related

- Core canvas engine (primitives + template dispatch + per-object label/description) — foundational.
- Per-template tickets: image, icon (T-313), compare/before-after, svg, graph.
- T-315 — stdin/--file JSON input plumbing (input channel).
- T-316 — image annotation metadata (folds in as the image/compare template''s label/description/markers).
- `.canvas` -> JSON converter / reuse (deferred).
- Existing image card (T-249/T-252): LEFT AS-IS for now; migrated onto the canvas once the canvas layer lands.

## Scope note

This is a real renderer with a schema, not a one-off widget. The schema must stay coherent across the primitive and template layers as templates accrue (D-91 cost). Start with a true canvas + the first templates; grow the template set over time.', NULL, '2026-06-10 11:10:59', '2026-06-10 11:10:59', '2026-06-10 11:10:59', NULL, '7892f2cc2259a7e3cf3d50ceb1c93358', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB2AD3HPR3HXSVASVZEX8PK0', 'parent_id', 'T-276', 'T-317', NULL, '2026-06-10 11:11:10', '2026-06-10 11:11:10', '2026-06-10 11:11:10', NULL, '245a2639738736df805e3e3eaa7cbb96', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB234WP4Y6Q16A0HFW8BSXMG', 'parent_id', 'T-276', 'T-317', NULL, '2026-06-10 11:11:10', '2026-06-10 11:11:10', '2026-06-10 11:11:10', NULL, '994f7c1bd8f3f205dc7183cccf7d4329', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB2ACSDBDZARV3NNGYD9NYYR', 'parent_id', 'T-276', 'T-317', NULL, '2026-06-10 11:11:10', '2026-06-10 11:11:10', '2026-06-10 11:11:10', NULL, 'e0ba90285dafac31357bb999d8e12c36', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB16YM1Y910T07Y1Y22MGTEM', 'status', 'ready', 'done', NULL, '2026-06-10 11:16:41', '2026-06-10 11:16:41', '2026-06-10 11:16:41', NULL, '9873b3f3b5d107be1146224ac48b9b45', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7162Z26FDWXG35VH0', 'description', 'Tier 5 of the build plan: bring the canvas pane (Obsidian-style spatial whiteboard) and the graph view (force-directed view of vault links) to feature parity.

**Canvas pane (`builtin.canvas`):**
- Render `.canvas` files (Obsidian-compatible JSON) — nodes (note, text, group, image), edges, layout state.
- Pan/zoom via `InteractiveViewer`; node selection, drag, resize.
- Edit affordances: add note from file picker, add text node, draw edge between nodes.
- Persist layout back to the `.canvas` file on disk.

**Graph view (`builtin.graph`):**
- Force-directed layout of the current vault (or a filtered subset) — nodes are notes, edges are wikilinks.
- Hover highlights connected subgraph; click opens the note in the editor.
- Filter pane: tag include/exclude, file glob, depth-from-active.
- pql provides the link data (`pql backlinks` / `pql outlinks`); rendering owned in-app.

Both panes use the existing `MultitabPane` (T-83) for tab management once they ship. Each lives in its own slot per D-47 (canvas in workspace, graph in context panel).', 'Tier 5 of the build plan: bring the canvas pane (Obsidian-style spatial whiteboard) and the graph view (force-directed view of vault links) to feature parity.

**Canvas pane (`builtin.canvas`):**
- Render `.canvas` files (Obsidian-compatible JSON) — nodes (note, text, group, image), edges, layout state.
- Pan/zoom via `InteractiveViewer`; node selection, drag, resize.
- Edit affordances: add note from file picker, add text node, draw edge between nodes.
- Persist layout back to the `.canvas` file on disk.

**Graph view (`builtin.graph`):**
- Force-directed layout of the current vault (or a filtered subset) — nodes are notes, edges are wikilinks.
- Hover highlights connected subgraph; click opens the note in the editor.
- Filter pane: tag include/exclude, file glob, depth-from-active.
- pql provides the link data (`pql backlinks` / `pql outlinks`); rendering owned in-app.

Both panes use the existing `MultitabPane` (T-83) for tab management once they ship. Each lives in its own slot per D-47 (canvas in workspace, graph in context panel).

MERGED (2026-06-10) into the unified canvas epic T-317 (decision D-91). The canvas rendering work consolidates onto one clide-owned canvas renderer driven by JSON; .canvas becomes an import format converted into that JSON rather than a native schema. T-7''s scope is preserved as children of T-317: canvas pane -> T-322, graph view -> T-323. This epic is cancelled as superseded; track the work under T-317.', NULL, '2026-06-10 11:17:31', '2026-06-10 11:17:31', '2026-06-10 11:17:31', NULL, 'e7d70c5b631bd6109f1b83b55c857c20', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM67JSC5RKS6M9182KG', 'parent_id', 'T-7', 'T-276', NULL, '2026-06-10 11:18:12', '2026-06-10 11:18:12', '2026-06-10 11:18:12', NULL, 'df23887d88f2a45e8ad12a72a4b27407', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7162Z26FDWXG35VH0', 'status', 'backlog', 'cancelled', NULL, '2026-06-10 11:18:15', '2026-06-10 11:18:15', '2026-06-10 11:18:15', NULL, '64906dcc15f8f1b32034640a7e9aab82', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB1ZFJK6J2GSV4SA69QF730C', 'status', 'ready', 'done', NULL, '2026-06-10 11:25:58', '2026-06-10 11:25:58', '2026-06-10 11:25:58', NULL, '678a32ea96db32f51581309dc2af1b6d', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB234WP4Y6Q16A0HFW8BSXMG', 'status', 'ready', 'backlog', NULL, '2026-06-10 11:29:04', '2026-06-10 11:29:04', '2026-06-10 11:29:04', NULL, 'fb25a3680bd8ffd0bc2089a6ab33820a', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB2J2HWD66QAFDDRRWS5NM48', 'status', 'backlog', 'ready', NULL, '2026-06-10 11:29:10', '2026-06-10 11:29:10', '2026-06-10 11:29:10', NULL, '43ad1db5744fc3bc86913f79cd007f42', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB1XDWKQ594ET4GDYEFK5ZJ4', 'status', 'backlog', 'ready', NULL, '2026-06-10 11:33:18', '2026-06-10 11:33:18', '2026-06-10 11:33:18', NULL, 'fba9411887602148dab1b2b4ad8647b7', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB1Q1Y3CYJHD7W5F68VDB6T4', 'status', 'backlog', 'ready', NULL, '2026-06-10 11:33:26', '2026-06-10 11:33:26', '2026-06-10 11:33:26', NULL, 'f280d9b2793130900d5e470c4cb6c088', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4KS233FGZE9H7ABWR', 'status', 'backlog', 'ready', NULL, '2026-06-10 11:33:35', '2026-06-10 11:33:35', '2026-06-10 11:33:35', NULL, 'bb110c716ec26f37ed4ece36b582d4d5', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB2J2HWD66QAFDDRRWS5NM48', 'status', 'ready', 'done', NULL, '2026-06-10 11:36:35', '2026-06-10 11:36:35', '2026-06-10 11:36:35', NULL, '376bbab713452158f399f02429870546', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4KS233FGZE9H7ABWR', 'description', 'The logo-mark spinner shown on in-progress activity/holder cards in the Claude conversation is too small to read as a spinner — it reads as a static speck. Enlarge it so the running state is legible at a glance.

**Where**
- `ClideSpinner` (lib/widgets/src/clide_spinner.dart) — defaults to size 14; renders the logo SVG at width/height = size.
- `ClideStatusIndicator` (lib/widgets/src/clide_status_indicator.dart) — default size 14; maps running→ClideSpinner, success→check, error→cross at the same size.
- Call sites: holder_card.dart:117 and :199 pass `size: 12` — the small value the user is seeing.

**Direction (settle in review)**
- Bump the spinner size on the activity cards (the `size: 12` call sites, and/or the indicator default) to something clearly legible — pull a concrete value from the ui-design control-geometry tokens rather than a magic number.
- Keep the running spinner, success check, and error cross visually balanced at the new size (they share `size`), so the card doesn''t jump when the state settles.
- Check the other ClideSpinner/StatusIndicator consumers (status surfaces) so the bump doesn''t bloat unrelated spots — may warrant sizing the cards explicitly rather than changing the shared default.

**Acceptance**
- The in-progress spinner on conversation activity cards is comfortably distinguishable as a spinning indicator; success/error glyphs stay aligned at the same footprint.', 'The logo-mark spinner shown on in-progress activity/holder cards in the Claude conversation is too small to read as a spinner — it reads as a static speck. Enlarge it so the running state is legible at a glance.

**Where**
- `ClideSpinner` (lib/widgets/src/clide_spinner.dart) — defaults to size 14; renders the logo SVG at width/height = size.
- `ClideStatusIndicator` (lib/widgets/src/clide_status_indicator.dart) — default size 14; maps running→ClideSpinner, success→check, error→cross at the same size.
- Call sites: holder_card.dart:117 and :199 pass `size: 12` — the small value the user is seeing.

**Direction (settle in review)**
- Bump the spinner size on the activity cards (the `size: 12` call sites, and/or the indicator default) to something clearly legible — pull a concrete value from the ui-design control-geometry tokens rather than a magic number.
- Keep the running spinner, success check, and error cross visually balanced at the new size (they share `size`), so the card doesn''t jump when the state settles.
- Check the other ClideSpinner/StatusIndicator consumers (status surfaces) so the bump doesn''t bloat unrelated spots — may warrant sizing the cards explicitly rather than changing the shared default.

**Acceptance**
- The in-progress spinner on conversation activity cards is comfortably distinguishable as a spinning indicator; success/error glyphs stay aligned at the same footprint.

**Initial trial**
- For the first cut, double the current size: the `size: 12` activity-card call sites go to `size: 24`. Trial that footprint, then settle the final value in review against the control-geometry tokens.', NULL, '2026-06-10 11:55:15', '2026-06-10 11:55:15', '2026-06-10 11:55:15', NULL, '3be7c3ff633afbc67c91dd3f97c27e6f', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4KS233FGZE9H7ABWR', 'status', 'ready', 'done', NULL, '2026-06-10 12:05:17', '2026-06-10 12:05:17', '2026-06-10 12:05:17', NULL, 'a19ce81190caca50c2628a98835d41a3', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB2TY91VHK7TPKPMZ11EG3TM', 'parent_id', NULL, 'T-276', NULL, '2026-06-10 12:05:21', '2026-06-10 12:05:21', '2026-06-10 12:05:21', NULL, 'fefee4b227754f03c985841fb869a346', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB2TY91VHK7TPKPMZ11EG3TM', 'description', NULL, 'AnimatedSwitcher in ClideStatusIndicator throws "Duplicate keys found" (Stack has multiple children with key [<''running''>]) during normal app run, cascading into a flood of follow-on errors ("Tried to build dirty widget in the wrong build scope", "debugNeedsLayout is not true", "ScrollController attached to multiple scroll views", etc).

Location: lib/widgets/src/clide_status_indicator.dart:37 (AnimatedSwitcher at build()).

Root cause: each status maps to a child with a fixed ValueKey (''running'' / ''success'' / ''error''). AnimatedSwitcher cross-fades the outgoing and incoming child inside a Stack for its 200ms duration. When the status flips back to a value whose previous child is still animating out (e.g. running -> success -> running within 200ms, or repeated running rebuilds), the still-exiting child and the new child both carry ValueKey(''running'') and collide in the Stack -> duplicate-key assertion. The downstream exceptions are the framework unwinding from the failed build.

Repro: observed live during `make run` with two Claude panes bound (primary + secondary-1); status indicators flipping quickly trigger it.

Fix direction: the ValueKey must be unique per indicator instance, not just per status, so two instances (or an in-flight transition) never share a key. Options: key by status combined with a stable per-widget id, or drop the const keys and let AnimatedSwitcher key on child type. Add a widget test that rapidly toggles status within the switch duration and pumps mid-transition to guard the regression.', NULL, '2026-06-10 12:05:39', '2026-06-10 12:05:39', '2026-06-10 12:05:39', NULL, '540deffcc7de142a4732a92b5f1dc5be', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB2TY91VHK7TPKPMZ11EG3TM', 'priority', 'medium', 'high', NULL, '2026-06-10 12:05:39', '2026-06-10 12:05:39', '2026-06-10 12:05:39', NULL, 'e845355200ef8aaabc986d577724d39e', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB2TY91VHK7TPKPMZ11EG3TM', 'status', 'backlog', 'ready', NULL, '2026-06-10 12:07:39', '2026-06-10 12:07:39', '2026-06-10 12:07:39', NULL, 'b013a394e376245d8248d776021e0314', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5TWC00GW0P3X02HZW', 'status', 'backlog', 'ready', NULL, '2026-06-10 12:08:14', '2026-06-10 12:08:14', '2026-06-10 12:08:14', NULL, 'f56fda6382cbec3561ef644954c04f43', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5TWC00GW0P3X02HZW', 'status', 'ready', 'backlog', NULL, '2026-06-10 12:08:18', '2026-06-10 12:08:18', '2026-06-10 12:08:18', NULL, '12eee2948e8f79732b40384a40429e14', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB2W4G9K8ZF782W7H2TM5XA8', 'status', 'backlog', 'ready', NULL, '2026-06-10 12:12:30', '2026-06-10 12:12:30', '2026-06-10 12:12:30', NULL, '6b9aaf9bd7ec3ad4ad3b95d1468ff9cf', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB1XDWKQ594ET4GDYEFK5ZJ4', 'status', 'ready', 'done', NULL, '2026-06-10 12:14:00', '2026-06-10 12:14:00', '2026-06-10 12:14:00', NULL, 'd90deec4e27b4298c6f7280338599c01', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB1Q1Y3CYJHD7W5F68VDB6T4', 'status', 'ready', 'done', NULL, '2026-06-10 12:31:23', '2026-06-10 12:31:23', '2026-06-10 12:31:23', NULL, 'dbac53eef0b8d58dbb5f00a2f77ee52f', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB1Q1Y3CYJHD7W5F68VDB6T4', 'status', 'done', 'done', NULL, '2026-06-10 12:32:07', '2026-06-10 12:32:07', '2026-06-10 12:32:07', NULL, 'ea979d683072b321ce6eae3dbbbf6c31', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB2W4G9K8ZF782W7H2TM5XA8', 'status', 'ready', 'done', NULL, '2026-06-10 12:51:50', '2026-06-10 12:51:50', '2026-06-10 12:51:50', NULL, 'a8a700b9b92afcb998b5c2e69660e1b2', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB1S7613SYF0M9XQT5JNWM40', 'status', 'backlog', 'ready', NULL, '2026-06-10 12:56:38', '2026-06-10 12:56:38', '2026-06-10 12:56:38', NULL, '0c7b9f022143b733461ca7b1b715c435', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB37JZSFZKWPK9PDFYJY2YC0', 'status', 'backlog', 'ready', NULL, '2026-06-10 13:00:19', '2026-06-10 13:00:19', '2026-06-10 13:00:19', NULL, 'a394b4a8b72a7bc99c7fc1a1ac6a2f19', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB2TY91VHK7TPKPMZ11EG3TM', 'status', 'ready', 'done', NULL, '2026-06-10 13:00:29', '2026-06-10 13:00:29', '2026-06-10 13:00:29', NULL, '25246286c46b36a114817316658049c7', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB1S7613SYF0M9XQT5JNWM40', 'status', 'ready', 'done', NULL, '2026-06-10 13:15:15', '2026-06-10 13:15:15', '2026-06-10 13:15:15', NULL, '9cea01c55347a9c347bd195d322dd004', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB37JZSFZKWPK9PDFYJY2YC0', 'status', 'ready', 'done', NULL, '2026-06-10 13:18:57', '2026-06-10 13:18:57', '2026-06-10 13:18:57', NULL, '02a8ea1b2623be255101f56c077f63ee', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7F2TBJJV1F2KP7XR8', 'status', 'backlog', 'ready', NULL, '2026-06-10 13:24:15', '2026-06-10 13:24:15', '2026-06-10 13:24:15', NULL, '85d0441183cc6f64fb1a956522a60f4a', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7F2TBJJV1F2KP7XR8', 'status', 'ready', 'in_progress', NULL, '2026-06-10 13:41:17', '2026-06-10 13:41:17', '2026-06-10 13:41:17', NULL, '14fa1745f31d356412fe910180183a53', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB3JAXDKZMS0805MMEYB6820', 'status', 'backlog', 'ready', NULL, '2026-06-10 13:53:28', '2026-06-10 13:53:28', '2026-06-10 13:53:28', NULL, 'addfc7d2a002212e979b3d7237cf37ce', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB3KS499THAD899M0NWN7E3R', 'status', 'backlog', 'ready', NULL, '2026-06-10 13:53:55', '2026-06-10 13:53:55', '2026-06-10 13:53:55', NULL, '72773d8d91af176305bd6c1b7d5d65be', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB3JM0AXK1CTWD720RV1AVZ0', 'status', 'backlog', 'ready', NULL, '2026-06-10 13:54:02', '2026-06-10 13:54:02', '2026-06-10 13:54:02', NULL, '5cb488441033ac5a781d4b7d91dbda6f', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7F2TBJJV1F2KP7XR8', 'status', 'in_progress', 'done', NULL, '2026-06-10 13:55:30', '2026-06-10 13:55:30', '2026-06-10 13:55:30', NULL, 'f618ee8a3a33dabfa822bd0cebae4e03', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB3JAXDKZMS0805MMEYB6820', 'status', 'ready', 'done', NULL, '2026-06-10 14:03:10', '2026-06-10 14:03:10', '2026-06-10 14:03:10', NULL, '96365bc3ef7dbf505448be2dad16e4b6', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB3JM0AXK1CTWD720RV1AVZ0', 'status', 'ready', 'done', NULL, '2026-06-10 14:14:33', '2026-06-10 14:14:33', '2026-06-10 14:14:33', NULL, 'd028dbbdbad663a682c5ed4d92dc7cc2', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB3KS499THAD899M0NWN7E3R', 'status', 'ready', 'done', NULL, '2026-06-10 14:29:07', '2026-06-10 14:29:07', '2026-06-10 14:29:07', NULL, 'b7a07e0516cc232a959ff1930f338f15', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4QKBQY7FPCNX6N28R', 'description', 'On first launch, check if tmux is on PATH. If missing, prompt the user with platform-appropriate install instructions (apt, dnf, brew) or offer to install automatically. Claude pane requires tmux per D-41; without it the primary session cannot persist.', 'On first launch, check if tmux is on PATH. If missing, prompt the user with platform-appropriate install instructions (apt, dnf, brew) or offer to install automatically. Claude pane requires tmux per D-41; without it the primary session cannot persist.

Obsolete: superseded by D-77/D-78. The Claude pane no longer requires tmux — it is driven over the stream-json stdio control protocol and persists via --resume (transcript files), not tmux. D-77 explicitly amends D-41 (tmux-for-persistence → --resume; tmux retained only for the general terminal). The ''primary session cannot persist without tmux'' premise is gone, so a first-launch tmux detect/install gate is unwarranted. Cancelling.', NULL, '2026-06-10 14:41:37', '2026-06-10 14:41:37', '2026-06-10 14:41:37', NULL, '020a1027abc50a0ab63ac839380dc767', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4QKBQY7FPCNX6N28R', 'status', 'backlog', 'cancelled', NULL, '2026-06-10 14:41:47', '2026-06-10 14:41:47', '2026-06-10 14:41:47', NULL, 'c1323729d101d47e5ea20df81e40735a', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4TQEYESK545T8F164', 'description', 'Reorder tabs in the sidebar and context panel icon rails by dragging. Persist order to project settings.', 'Reorder tabs in the sidebar and context panel icon rails by dragging. Persist order to project settings.

Notes (2026-06-10):
1. Applies to BOTH rails — the left sidebar icon rail and the right context-bar icon rail. Reordering + persistence must work the same on each.
2. After ordering, the left-most (first) item in the rail is the one that opens by default.', NULL, '2026-06-10 14:45:17', '2026-06-10 14:45:17', '2026-06-10 14:45:17', NULL, '86f1c477f9408ce87b624799a73b82c0', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM734YZ060Q63H40EYG', 'status', 'backlog', 'ready', NULL, '2026-06-10 14:46:51', '2026-06-10 14:46:51', '2026-06-10 14:46:51', NULL, 'a3785538cc5ea4040c7f88ee615342b4', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM734YZ060Q63H40EYG', 'status', 'ready', 'in_progress', NULL, '2026-06-10 14:53:03', '2026-06-10 14:53:03', '2026-06-10 14:53:03', NULL, '6fe6ac08d39ee01463fc6e629a0b00d7', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM734YZ060Q63H40EYG', 'description', 'From the PTY/IPC error-handling audit (T-18, see docs/audits/pty-ipc-error-handling-2026-05-05.md). Two cleanup items rolled together:

**Errno constants (audit item #23):**
- Magic numbers (`4` for EINTR, `9` for EBADF, `28` for SIGWINCH, `1` for SIGHUP, `32` for EPIPE) appear inline across `lib/src/pty/session.dart` and `lib/src/pty/native_pty.dart`.
- Centralize them in `lib/src/pty/errors.dart` or a sibling `posix.dart` as named constants.
- Existing `lib/src/ipc/errno_mapping.dart` already has a `PosixErrno` class — extend it or move to a shared location both layers import from.

**Logger standardization (audit item #22, partial #26):**
- `lib/src/ipc/server.dart` uses `stderr.writeln(...)` directly; the rest of the daemon either uses no logger or a custom one.
- The Flutter-host process often consumes stderr, so log lines disappear silently.
- Pick one logger interface (kernel `log` already exists for the app side), wire `DaemonServer` and the daemon-side handlers to use it.
- Dispatch error messages should prefix with the request `cmd` so log correlation works (audit item #26).

**Out of scope for this ticket:** changes to log-LEVEL policy, log retention, log files vs stderr — pure substitution job.', 'From the PTY/IPC error-handling audit (T-18, see docs/audits/pty-ipc-error-handling-2026-05-05.md). Two cleanup items rolled together:

**Errno constants (audit item #23):**
- Magic numbers (`4` for EINTR, `9` for EBADF, `28` for SIGWINCH, `1` for SIGHUP, `32` for EPIPE) appear inline across `lib/src/pty/session.dart` and `lib/src/pty/native_pty.dart`.
- Centralize them in `lib/src/pty/errors.dart` or a sibling `posix.dart` as named constants.
- Existing `lib/src/ipc/errno_mapping.dart` already has a `PosixErrno` class — extend it or move to a shared location both layers import from.

**Logger standardization (audit item #22, partial #26):**
- `lib/src/ipc/server.dart` uses `stderr.writeln(...)` directly; the rest of the daemon either uses no logger or a custom one.
- The Flutter-host process often consumes stderr, so log lines disappear silently.
- Pick one logger interface (kernel `log` already exists for the app side), wire `DaemonServer` and the daemon-side handlers to use it.
- Dispatch error messages should prefix with the request `cmd` so log correlation works (audit item #26).

**Out of scope for this ticket:** changes to log-LEVEL policy, log retention, log files vs stderr — pure substitution job.

Disposition (2026-06-10): mostly already done before pickup.
- #23 (errno constants): DONE prior. Magic numbers are centralized — errno values in lib/src/ipc/errno_mapping.dart (PosixErrno: eintr=4, ebadf=9, epipe=32, …), signals in lib/src/pty/ffi/libc.dart (sighup=1, sigwinch=28). native_pty.dart uses PosixErrno.* and libc.* throughout; no inline magic numbers remain. The ticket''s lib/src/pty/session.dart never existed at that path.
- #22 (logger): DONE prior. lib/src/ipc/server.dart imports the kernel Logger, holds a ''final Logger log'', and logs via log.error/warn/info(''ipc'', …). No stderr.writeln/print anywhere in lib/src/ipc, lib/src/pty, or lib/src/daemon. Folded in by the D-56 daemon dissolution + PTY FFI pivot.
- #26 (cmd correlation): the only live remnant — the catch-all ''dispatch threw'' log omitted the request cmd. Fixed: it now logs ''dispatch threw for "<cmd>"''. Internal logging only; no changelog.', NULL, '2026-06-10 14:58:32', '2026-06-10 14:58:32', '2026-06-10 14:58:32', NULL, '067666253769388e306dd99c4f976df9', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM734YZ060Q63H40EYG', 'status', 'in_progress', 'done', NULL, '2026-06-10 14:58:43', '2026-06-10 14:58:43', '2026-06-10 14:58:43', NULL, '192064fbd5628b282512128ddc3d2688', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM42M9RK4399B4F4WSG', 'status', 'backlog', 'ready', NULL, '2026-06-10 15:01:43', '2026-06-10 15:01:43', '2026-06-10 15:01:43', NULL, 'a002c3ce8b3efa35c18d9708ed37c9c3', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM60QRRNEEWG84VWKXC', 'status', 'backlog', 'ready', NULL, '2026-06-10 15:01:52', '2026-06-10 15:01:52', '2026-06-10 15:01:52', NULL, 'dee252ba6fbb07189c947101968e1743', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM42M9RK4399B4F4WSG', 'status', 'ready', 'in_progress', NULL, '2026-06-10 15:01:54', '2026-06-10 15:01:54', '2026-06-10 15:01:54', NULL, '1c3ed11e37579ea9a3a21e85e3ba110a', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM60QRRNEEWG84VWKXC', 'status', 'ready', 'in_progress', NULL, '2026-06-10 15:02:14', '2026-06-10 15:02:14', '2026-06-10 15:02:14', NULL, 'c5844c06118422cb09538405b12fe478', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM42M9RK4399B4F4WSG', 'description', 'Ship a VS Code-compatible keybinding preset that maps standard VS Code shortcuts to clide commands. Users select it in settings. Covers file navigation, editor actions, panel toggles, search, and terminal.

**Unblocked by T-117 (2026-05-17):** the keystroke mapper layer is now in place. Implementation is now just authoring `assets/keymaps/vscode.yaml` against the typed Intents in `lib/kernel/src/keymap/intents.dart` (plus `command:<id>` bindings for VS-Code-specific commands the preset wants to bind to clide commands). Users will switch presets via `app.keymap.preset = vscode` once a settings UI exists, or directly via the setting today.

**Acceptance:**
1. `assets/keymaps/vscode.yaml` ships covering the documented VS Code default keybindings.
2. `KeymapService.setPreset("vscode")` activates the preset and all asserted bindings resolve as expected.
3. The preset uses when-clauses where VS Code does (`editor.focused`, `inputFocused`, `palette.open`, …).
4. A regression test loads the preset and asserts a representative subset (e.g. ctrl+p → quick-open command, ctrl+shift+p → palette).

**Out of scope:** clide commands that have no VS Code analogue (those keep their default-preset bindings).', 'Ship a VS Code-compatible keybinding preset that maps standard VS Code shortcuts to clide commands. Users select it in settings. Covers file navigation, editor actions, panel toggles, search, and terminal.

**Unblocked by T-117 (2026-05-17):** the keystroke mapper layer is now in place. Implementation is now just authoring `assets/keymaps/vscode.yaml` against the typed Intents in `lib/kernel/src/keymap/intents.dart` (plus `command:<id>` bindings for VS-Code-specific commands the preset wants to bind to clide commands). Users will switch presets via `app.keymap.preset = vscode` once a settings UI exists, or directly via the setting today.

**Acceptance:**
1. `assets/keymaps/vscode.yaml` ships covering the documented VS Code default keybindings.
2. `KeymapService.setPreset("vscode")` activates the preset and all asserted bindings resolve as expected.
3. The preset uses when-clauses where VS Code does (`editor.focused`, `inputFocused`, `palette.open`, …).
4. A regression test loads the preset and asserts a representative subset (e.g. ctrl+p → quick-open command, ctrl+shift+p → palette).

**Out of scope:** clide commands that have no VS Code analogue (those keep their default-preset bindings).

Correction (2026-06-10): this ticket''s ''see Q-9'' reference is stale — Q-9 is ''Lua runtime vendoring'', unrelated. The search-everywhere / double-tap-modifier gap is now tracked by T-341.', NULL, '2026-06-10 15:07:52', '2026-06-10 15:07:52', '2026-06-10 15:07:52', NULL, 'f5caba1a25d32651bbd7503c906633cf', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM60QRRNEEWG84VWKXC', 'description', 'Ship a JetBrains/IntelliJ-compatible keybinding preset mapping standard JetBrains shortcuts to clide commands. Covers navigation, refactoring, search, run/debug, and tool windows.

**Unblocked by T-117 (2026-05-17):** the keystroke mapper layer is in place. Implementation is authoring `assets/keymaps/jetbrains.yaml` against the typed Intents + `command:<id>` bindings, plus when-clauses for the contexts JetBrains presets typically scope to (`editor.focused`, `inputFocused`, etc.).

**Acceptance:**
1. `assets/keymaps/jetbrains.yaml` ships covering the documented IntelliJ default keybindings.
2. `KeymapService.setPreset("jetbrains")` activates the preset and all asserted bindings resolve.
3. A regression test exercises a representative subset (e.g. shift+shift → quick-open command — see Q-9 if the search-everywhere overlay needs its own intent).', 'Ship a JetBrains/IntelliJ-compatible keybinding preset mapping standard JetBrains shortcuts to clide commands. Covers navigation, refactoring, search, run/debug, and tool windows.

**Unblocked by T-117 (2026-05-17):** the keystroke mapper layer is in place. Implementation is authoring `assets/keymaps/jetbrains.yaml` against the typed Intents + `command:<id>` bindings, plus when-clauses for the contexts JetBrains presets typically scope to (`editor.focused`, `inputFocused`, etc.).

**Acceptance:**
1. `assets/keymaps/jetbrains.yaml` ships covering the documented IntelliJ default keybindings.
2. `KeymapService.setPreset("jetbrains")` activates the preset and all asserted bindings resolve.
3. A regression test exercises a representative subset (e.g. shift+shift → quick-open command — see Q-9 if the search-everywhere overlay needs its own intent).

Correction (2026-06-10): ''see Q-9'' is stale (Q-9 is Lua runtime vendoring). The double-Shift ''Search Everywhere'' chord is NOT expressible by the current matcher (bare/double modifiers unsupported) — tracked in T-341. This preset maps quick-open to Ctrl+Shift+N and the palette to Ctrl+Shift+A as the expressible IntelliJ equivalents.', NULL, '2026-06-10 15:07:52', '2026-06-10 15:07:52', '2026-06-10 15:07:52', NULL, '18bc4f20a98f7528f3a9a976e34d9377', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5YG22EV7BFTX5RTPR', 'description', 'Conditional import behind TreeSitterService: native impl uses dart:ffi to libtree-sitter.so, web impl uses dart:js_interop to web-tree-sitter (official emscripten build from tree-sitter org). Same grammar .wasm files on both platforms. Vendor web-tree-sitter .wasm + JS glue as Flutter web assets, pinned version, added to licenses.yaml.', 'Conditional import behind TreeSitterService: native impl uses dart:ffi to libtree-sitter.so, web impl uses dart:js_interop to web-tree-sitter (official emscripten build from tree-sitter org). Same grammar .wasm files on both platforms. Vendor web-tree-sitter .wasm + JS glue as Flutter web assets, pinned version, added to licenses.yaml.

Cancelled 2026-06-10 (backlog relevance sweep): contradicts the desktop-first guardrail (CLAUDE.md) - web is an explicit non-goal / happy-accident only. TreeSitterService is FFI-only and there is no shipped web product, so a web-tree-sitter dual-path is not wanted. Reopen only if web ever becomes a real target.', NULL, '2026-06-10 15:13:50', '2026-06-10 15:13:50', '2026-06-10 15:13:50', NULL, 'ad42a5b7d9d3cc5c5e0e1ed97b9858aa', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM50X0DX8XTVZEA5GN8', 'description', 'Prompt before running extensions or loading project settings in untrusted repositories. Trust decision persisted per repo path. Untrusted mode disables third-party extensions and restricts IPC commands.', 'Prompt before running extensions or loading project settings in untrusted repositories. Trust decision persisted per repo path. Untrusted mode disables third-party extensions and restricts IPC commands.

Cancelled 2026-06-10 (relevance sweep): premature. Third-party (Lua) extension loading is not shipped - ExtensionScanner.discover is test-only and the Lua runtime is a Tier-6 skeleton. Nothing to trust-gate yet; revisit at Tier 6 when external extension loading lands (the trust surface will likely be Lua sandboxing per D-19, not a per-repo prompt).', NULL, '2026-06-10 15:13:52', '2026-06-10 15:13:52', '2026-06-10 15:13:52', NULL, 'c4e57efc161c7afbc5e8a3c3d08b8d74', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM6RDM2EKZX132GPV7M', 'description', 'Spec lists PRs as a left-panel section (icon rail position 5). No extension exists yet.', 'Spec lists PRs as a left-panel section (icon rail position 5). No extension exists yet.

Cancelled 2026-06-10 (relevance sweep): spec''d in D-47 but unscoped, no extension exists, and the data path (git host API vs local metadata) is undecided. Closing to clear the backlog; file a fresh scoped story if a PRs surface is wanted.', NULL, '2026-06-10 15:13:52', '2026-06-10 15:13:52', '2026-06-10 15:13:52', NULL, '99b1fceb9134d0e6bead70da08a51710', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4W194B2421P2SF83R', 'description', 'BUILD.md at app/native/linux-x64/ has TODO checklist: build from pinned source SHA in CI, record SHA-256, cross-compile for macOS (aarch64, x86_64) and Windows (x86_64). Currently built on contributor machine.', 'BUILD.md at app/native/linux-x64/ has TODO checklist: build from pinned source SHA in CI, record SHA-256, cross-compile for macOS (aarch64, x86_64) and Windows (x86_64). Currently built on contributor machine.

Path fix (2026-06-10 sweep): ticket says app/native/linux-x64/ - the app/ prefix is stale (D-56 dissolved the two-package layout). Correct path is native/linux-x64/BUILD.md. Work remains valid: native/linux-x64/libtree-sitter.so is committed but there is still no CI build/cross-compile job.', NULL, '2026-06-10 15:13:54', '2026-06-10 15:13:54', '2026-06-10 15:13:54', NULL, '3ddd8faeeaabb70a137165ec736e8a07', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM48MDE8ZZ82VWNY994', 'description', 'D-46 defines the boundary: content extensions (editor, claude, claude-control, markdown, diff, git-ui, pql, canvas, graph, decisions, tickets, todos, problems) move from app/lib/builtin/ to app/lib/extensions/. Incremental — one at a time, each behind a working build. Extension contract must support bundled Dart extension as a first-class category.', 'D-46 defines the boundary: content extensions (editor, claude, claude-control, markdown, diff, git-ui, pql, canvas, graph, decisions, tickets, todos, problems) move from app/lib/builtin/ to app/lib/extensions/. Incremental — one at a time, each behind a working build. Extension contract must support bundled Dart extension as a first-class category.

Path fix (2026-06-10 sweep): app/lib/builtin/ -> lib/builtin/ (app/ prefix stale per D-56). D-46 still confirmed/active. lib/extensions/ does not exist yet and the shipped extensions (editor, claude, markdown, diff, git-ui, pql, canvas, graph, decisions, tickets, todos, problems) are still under lib/builtin/. Migration unstarted, still valid.', NULL, '2026-06-10 15:13:56', '2026-06-10 15:13:56', '2026-06-10 15:13:56', NULL, '81d27a7cf777fc0290574d807938ea36', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM6T6580D8ABDVTMNZW', 'description', 'Tier 6 of the build plan: the things that make clide a real product instead of a working prototype.

**Extension API (third-party Lua):**
- The Lua runtime supporter tool (D-19) lands as a peer of pql/ptyc.
- Manifest schema, capability gating, sandboxed FS/IPC access.
- Same TabContribution / CommandContribution / etc. surface as built-in Dart extensions (D-15).
- Marketplace / distribution story is OUT OF SCOPE for Tier 6 — local-install only.

**Settings UI (`builtin.settings-ui`):**
- Schema-driven settings panel reading from the kernel SettingsStore.
- Render strategy: form fields keyed off the schema each subsystem registers.
- Edits write back to `.clide/settings.yaml`.

**Theming UI (`builtin.theme-picker` extends):**
- Live preview of the four bundled themes (D-44).
- Custom theme: import YAML, validate against schema, register at runtime.
- Per-component override surface (long horizon).

**Distributable builds:**
- AppImage / Flatpak for Linux, .dmg for macOS — see T-46.
- Self-update mechanism — see T-47.
- License manifest auto-regen as part of the release build.

Big epic — children land incrementally. Most concrete child tickets already exist; this is the umbrella.', 'Tier 6 of the build plan: the things that make clide a real product instead of a working prototype.

**Extension API (third-party Lua):**
- The Lua runtime supporter tool (D-19) lands as a peer of pql/ptyc.
- Manifest schema, capability gating, sandboxed FS/IPC access.
- Same TabContribution / CommandContribution / etc. surface as built-in Dart extensions (D-15).
- Marketplace / distribution story is OUT OF SCOPE for Tier 6 — local-install only.

**Settings UI (`builtin.settings-ui`):**
- Schema-driven settings panel reading from the kernel SettingsStore.
- Render strategy: form fields keyed off the schema each subsystem registers.
- Edits write back to `.clide/settings.yaml`.

**Theming UI (`builtin.theme-picker` extends):**
- Live preview of the four bundled themes (D-44).
- Custom theme: import YAML, validate against schema, register at runtime.
- Per-component override surface (long horizon).

**Distributable builds:**
- AppImage / Flatpak for Linux, .dmg for macOS — see T-46.
- Self-update mechanism — see T-47.
- License manifest auto-regen as part of the release build.

Big epic — children land incrementally. Most concrete child tickets already exist; this is the umbrella.

Status note (2026-06-10 sweep): mixed completion. theme-picker is substantially implemented; settings-ui is a stub; the Lua runtime is skeleton-only (lib/lua/); distributable builds (T-46/T-47) remain deferred Tier-6 work. Epic stays open as the umbrella.', NULL, '2026-06-10 15:13:57', '2026-06-10 15:13:57', '2026-06-10 15:13:57', NULL, '15d4ca47570b23a19b16c22e40a8d73e', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM66FTCTWHH9AQTNFKR', 'description', 'Minimize to system tray on Linux (AppIndicator) or Dock on macOS. Reopening from tray restores the window without cold boot. tmux sessions stay alive in background regardless.', 'Minimize to system tray on Linux (AppIndicator) or Dock on macOS. Reopening from tray restores the window without cold boot. tmux sessions stay alive in background regardless.

Scope split (2026-06-10 sweep): the session-persistence half is effectively done - tmux keeps Claude/terminal sessions alive across restart (D-41). The OS-tray/AppIndicator + dock half is a stub only (lib/kernel/src/tray.dart - TrayRegistry has no platform-channel wiring) and is Tier-6+. Remaining work = the tray integration.', NULL, '2026-06-10 15:13:59', '2026-06-10 15:13:59', '2026-06-10 15:13:59', NULL, '8a2142b2ae85644bdbe22627ce3bde77', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM67JSC5RKS6M9182KG', 'description', 'Spec lists images as a right-panel section. No extension exists yet.', 'Spec lists images as a right-panel section. No extension exists yet.

Relevance note (2026-06-10 sweep): likely superseded. The image card + full-screen lightbox shipped (T-249/T-252) and the canvas epic (T-317, D-91) folds image display into the unified drawing-card renderer rather than a separate context-panel tab. Confirm whether a distinct images rail section is still wanted; otherwise close in favor of the canvas path.', NULL, '2026-06-10 15:14:01', '2026-06-10 15:14:01', '2026-06-10 15:14:01', NULL, 'faf96dd64f003093273f6a331c56bfa8', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7P6Q0DG4RG4CBHFJG', 'description', 'Audit all interactive widgets for Semantics coverage (labels, roles, states). Verify flutter test can locate and interact with every panel, button, and input via find.bySemanticsLabel. Run the existing a11y test suite and document gaps. Target: every user-facing action is testable without widget keys.', 'Audit all interactive widgets for Semantics coverage (labels, roles, states). Verify flutter test can locate and interact with every panel, button, and input via find.bySemanticsLabel. Run the existing a11y test suite and document gaps. Target: every user-facing action is testable without widget keys.

Reframe (2026-06-10 sweep): the original ''audit Semantics coverage'' framing is stale - test/a11y/ (semantic_coverage, contrast, keyboard_traversal, i18n) is now a mature per-PR gate per D-20. Re-scope to forward work: ratchet the semantic-coverage floor and deepen per-extension Semantics assertions, rather than a one-time review.', NULL, '2026-06-10 15:14:02', '2026-06-10 15:14:02', '2026-06-10 15:14:02', NULL, 'a83b56d7fee3b9a20bc0d78f6125532a', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM79CNBXJ2S3CFQR7VM', 'description', 'Catch-all for the medium-priority items from the PTY/IPC error-handling audit (T-18, see docs/audits/pty-ipc-error-handling-2026-05-05.md) that didn`t earn dedicated tickets:

- **#17** — `files.read` `readAsStringSync` is unguarded; UTF-8 errors / permissions / mid-read deletion become 500-style dispatch errors. Wrap in try/catch and emit a clean `IpcResponse.err`.
- **#19** — `PtySession.close` swallows the 500ms timeout silently (`onTimeout: () {}`). Log when the timeout fires so we know SIGKILL was needed.
- **#20** — Reader isolate treats every negative `read()` return that isn`t EINTR as EOF. Distinguish EBADF/EIO (real EOF) from transient EAGAIN (recoverable) and log the latter.
- **#21** — `scm_rights.dart` reads cmsg-data fd without verifying `dataOffset + 4 <= msgControllen`. Bounds check before deref so a malformed peer can`t feed garbage as an fd.
- **#25** — `_gitError` in `lib/src/daemon/git_commands.dart` always reports `tool_error`; push rejections / merge conflicts should map to `IpcExitCode.conflict` when stderr matches known patterns.
- **#27** — `pane.spawn` returns `ok` even when `registry.write(id, bytes)` returned `n == -1`. Distinguish the failure.
- **#28** — `IpcResponse.fromJson` throws `TypeError` on a malformed peer response missing `error`. Graceful degrade.
- **#29** — PATH resolution in `native_pty.dart` uses the first existing match without `X_OK` check; non-executable files shadow valid binaries further along PATH.

Land each as a small focused commit; ticket closes when all items above are merged.', 'Catch-all for the medium-priority items from the PTY/IPC error-handling audit (T-18, see docs/audits/pty-ipc-error-handling-2026-05-05.md) that didn`t earn dedicated tickets:

- **#17** — `files.read` `readAsStringSync` is unguarded; UTF-8 errors / permissions / mid-read deletion become 500-style dispatch errors. Wrap in try/catch and emit a clean `IpcResponse.err`.
- **#19** — `PtySession.close` swallows the 500ms timeout silently (`onTimeout: () {}`). Log when the timeout fires so we know SIGKILL was needed.
- **#20** — Reader isolate treats every negative `read()` return that isn`t EINTR as EOF. Distinguish EBADF/EIO (real EOF) from transient EAGAIN (recoverable) and log the latter.
- **#21** — `scm_rights.dart` reads cmsg-data fd without verifying `dataOffset + 4 <= msgControllen`. Bounds check before deref so a malformed peer can`t feed garbage as an fd.
- **#25** — `_gitError` in `lib/src/daemon/git_commands.dart` always reports `tool_error`; push rejections / merge conflicts should map to `IpcExitCode.conflict` when stderr matches known patterns.
- **#27** — `pane.spawn` returns `ok` even when `registry.write(id, bytes)` returned `n == -1`. Distinguish the failure.
- **#28** — `IpcResponse.fromJson` throws `TypeError` on a malformed peer response missing `error`. Graceful degrade.
- **#29** — PATH resolution in `native_pty.dart` uses the first existing match without `X_OK` check; non-executable files shadow valid binaries further along PATH.

Land each as a small focused commit; ticket closes when all items above are merged.

Item status (2026-06-10 sweep): from the T-18 audit, #16 (git error kinds) landed via T-79 and #22 (logging) via T-80. #21 (scm_rights.dart bounds check) is OBSOLETE - fd-passing/recvmsg was removed, the file no longer exists; drop it. Spot-checked still-open: #17 files.read unguarded readAsStringSync (files_commands.dart), #28 IpcResponse.fromJson TypeError (envelope.dart), #29 PATH X_OK check (native_pty.dart). ~7 items remain.', NULL, '2026-06-10 15:14:04', '2026-06-10 15:14:04', '2026-06-10 15:14:04', NULL, '94ea0fc1d09ea5eb98acf8ff624ac984', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5YG22EV7BFTX5RTPR', 'status', 'backlog', 'cancelled', NULL, '2026-06-10 15:14:17', '2026-06-10 15:14:17', '2026-06-10 15:14:17', NULL, 'b459f350a8c1a86865579cde7f7b02b1', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM50X0DX8XTVZEA5GN8', 'status', 'backlog', 'cancelled', NULL, '2026-06-10 15:14:17', '2026-06-10 15:14:17', '2026-06-10 15:14:17', NULL, '351f1eede59364f6bb95653147b98ee2', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM6RDM2EKZX132GPV7M', 'status', 'backlog', 'cancelled', NULL, '2026-06-10 15:14:17', '2026-06-10 15:14:17', '2026-06-10 15:14:17', NULL, '992ba3fca9faf99417aaa1a7afa9e6be', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM42M9RK4399B4F4WSG', 'status', 'in_progress', 'done', NULL, '2026-06-10 15:17:59', '2026-06-10 15:17:59', '2026-06-10 15:17:59', NULL, '61000cdb8bb01686c6001f57d16ae717', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM60QRRNEEWG84VWKXC', 'status', 'in_progress', 'done', NULL, '2026-06-10 15:17:59', '2026-06-10 15:17:59', '2026-06-10 15:17:59', NULL, '81990604a08fbedc28075b95538625d6', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB493JEW32CH0H3771TNHF7G', 'description', NULL, 'Filed 2026-06-10 from a user request: when the agent fans out multiple subagents (Task/Agent tool), each spawned subagent should get its OWN collapsing activity card. The space is worth it — a fan-out of N agents should read as N cards, not one lumped card.

CURRENT BEHAVIOUR (confirmed): multiple Task/Agent spawns are MERGED into a single shared ''Activity / N steps'' cluster. groupConversation() in lib/builtin/claude/src/activity_cluster.dart:120-147 walks items and coalesces every consecutive _isFoldable item into one FoldedCluster. _isFoldable (:149-172, AssistantToolUse case at :161-164) only distinguishes diff tools (Edit/Write/MultiEdit/NotebookEdit/Update -> stay first-class) from everything else (Task/Agent/Bash/Read/... -> all foldable). The Task tool is treated identically to a Bash/Read call; there is NO subagent-aware grouping key (not toolUseId, not parent_tool_use_id). So 4 spawned agents render as one ''Activity 4 steps'' card.

What recent work already does (do NOT redo): T-263 folds the subagent PROMPT into the Agent card; T-264 nests the subagent''s RUN items under the parent Agent card (the ''agent run'' collapser); T-338 routes sidechain items to their parent via parent_tool_use_id. All of that is about what shows INSIDE one agent''s card. This ticket is the complement: stop merging DISTINCT agent spawns into a shared cluster.

SCOPE / DESIGN:
- An AssistantToolUse where _isAgentTool(name) (Task/Agent) should break the current Activity cluster and render as its own first-class collapsing card (its own ClideCollapserCard with the prompt + nested ''agent run'' from T-263/T-264), rather than folding into the generic Activity cluster with sibling tool calls.
- Decide grouping precisely in groupConversation/_isFoldable: an Agent tool-use is a cluster boundary (like a sticky item) OR emits its own single-item card. Adjacent non-agent foldables (Bash/Read/Grep) keep clustering into the normal Activity card as today.
- Label each subagent card by its task/description (the Agent call''s label) so parallel fan-outs are distinguishable, not ''Activity N steps''.
- Keep collapsed-by-default behaviour and the FoldLevel semantics; this changes the grouping boundary, not the fold mechanics.

Refs: lib/builtin/claude/src/activity_cluster.dart (groupConversation, _isFoldable, isDiffTool), lib/builtin/claude/src/conversation_view.dart (_ActivityCard at ~833, _toolUseCollapser ~615-657, _isAgentTool ~378). Related: T-230 (clustering), T-263, T-264, T-338.

Tests: a groupConversation case asserting that two consecutive Agent tool-uses yield two separate cards (not one FoldedCluster), while two consecutive Bash calls still yield one Activity cluster.', NULL, '2026-06-10 15:27:01', '2026-06-10 15:27:01', '2026-06-10 15:27:01', NULL, '59b702a540ce65892ea2c6fce5d1a045', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB493JEW32CH0H3771TNHF7G', 'description', 'Filed 2026-06-10 from a user request: when the agent fans out multiple subagents (Task/Agent tool), each spawned subagent should get its OWN collapsing activity card. The space is worth it — a fan-out of N agents should read as N cards, not one lumped card.

CURRENT BEHAVIOUR (confirmed): multiple Task/Agent spawns are MERGED into a single shared ''Activity / N steps'' cluster. groupConversation() in lib/builtin/claude/src/activity_cluster.dart:120-147 walks items and coalesces every consecutive _isFoldable item into one FoldedCluster. _isFoldable (:149-172, AssistantToolUse case at :161-164) only distinguishes diff tools (Edit/Write/MultiEdit/NotebookEdit/Update -> stay first-class) from everything else (Task/Agent/Bash/Read/... -> all foldable). The Task tool is treated identically to a Bash/Read call; there is NO subagent-aware grouping key (not toolUseId, not parent_tool_use_id). So 4 spawned agents render as one ''Activity 4 steps'' card.

What recent work already does (do NOT redo): T-263 folds the subagent PROMPT into the Agent card; T-264 nests the subagent''s RUN items under the parent Agent card (the ''agent run'' collapser); T-338 routes sidechain items to their parent via parent_tool_use_id. All of that is about what shows INSIDE one agent''s card. This ticket is the complement: stop merging DISTINCT agent spawns into a shared cluster.

SCOPE / DESIGN:
- An AssistantToolUse where _isAgentTool(name) (Task/Agent) should break the current Activity cluster and render as its own first-class collapsing card (its own ClideCollapserCard with the prompt + nested ''agent run'' from T-263/T-264), rather than folding into the generic Activity cluster with sibling tool calls.
- Decide grouping precisely in groupConversation/_isFoldable: an Agent tool-use is a cluster boundary (like a sticky item) OR emits its own single-item card. Adjacent non-agent foldables (Bash/Read/Grep) keep clustering into the normal Activity card as today.
- Label each subagent card by its task/description (the Agent call''s label) so parallel fan-outs are distinguishable, not ''Activity N steps''.
- Keep collapsed-by-default behaviour and the FoldLevel semantics; this changes the grouping boundary, not the fold mechanics.

Refs: lib/builtin/claude/src/activity_cluster.dart (groupConversation, _isFoldable, isDiffTool), lib/builtin/claude/src/conversation_view.dart (_ActivityCard at ~833, _toolUseCollapser ~615-657, _isAgentTool ~378). Related: T-230 (clustering), T-263, T-264, T-338.

Tests: a groupConversation case asserting that two consecutive Agent tool-uses yield two separate cards (not one FoldedCluster), while two consecutive Bash calls still yield one Activity cluster.', 'Filed 2026-06-10 from a user request: when the agent fans out multiple subagents (Task/Agent tool), each spawned subagent should get its OWN collapsing activity card. The space is worth it — a fan-out of N agents should read as N cards, not one lumped card.

CURRENT BEHAVIOUR (confirmed): multiple Task/Agent spawns are MERGED into a single shared ''Activity / N steps'' cluster. groupConversation() in lib/builtin/claude/src/activity_cluster.dart:120-147 walks items and coalesces every consecutive _isFoldable item into one FoldedCluster. _isFoldable (:149-172, AssistantToolUse case at :161-164) only distinguishes diff tools (Edit/Write/MultiEdit/NotebookEdit/Update -> stay first-class) from everything else (Task/Agent/Bash/Read/... -> all foldable). The Task tool is treated identically to a Bash/Read call; there is NO subagent-aware grouping key (not toolUseId, not parent_tool_use_id). So 4 spawned agents render as one ''Activity 4 steps'' card.

What recent work already does (do NOT redo): T-263 folds the subagent PROMPT into the Agent card; T-264 nests the subagent''s RUN items under the parent Agent card (the ''agent run'' collapser); T-338 routes sidechain items to their parent via parent_tool_use_id. All of that is about what shows INSIDE one agent''s card. This ticket is the complement: stop merging DISTINCT agent spawns into a shared cluster.

SCOPE / DESIGN:
- An AssistantToolUse where _isAgentTool(name) (Task/Agent) should break the current Activity cluster and render as its own first-class collapsing card (its own ClideCollapserCard with the prompt + nested ''agent run'' from T-263/T-264), rather than folding into the generic Activity cluster with sibling tool calls.
- Decide grouping precisely in groupConversation/_isFoldable: an Agent tool-use is a cluster boundary (like a sticky item) OR emits its own single-item card. Adjacent non-agent foldables (Bash/Read/Grep) keep clustering into the normal Activity card as today.
- Label each subagent card by its task/description (the Agent call''s label) so parallel fan-outs are distinguishable, not ''Activity N steps''.
- Keep collapsed-by-default behaviour and the FoldLevel semantics; this changes the grouping boundary, not the fold mechanics.

Refs: lib/builtin/claude/src/activity_cluster.dart (groupConversation, _isFoldable, isDiffTool), lib/builtin/claude/src/conversation_view.dart (_ActivityCard at ~833, _toolUseCollapser ~615-657, _isAgentTool ~378). Related: T-230 (clustering), T-263, T-264, T-338.

Tests: a groupConversation case asserting that two consecutive Agent tool-uses yield two separate cards (not one FoldedCluster), while two consecutive Bash calls still yield one Activity cluster.

SCOPE CLARIFICATION (2026-06-10, from user):

1. RIGHT card, not just A card. Each per-agent card must pull in ALL of that agent''s nested run — the folded prompt (T-263) AND every nested response: prose, thinking, sidechain tool cards, and results (T-264) — attributed to the CORRECT agent even under a parallel fan-out where multiple agents'' sidechain items interleave in the stream. Reuse the existing _sidechainFold machinery (conversation_view.dart:188-256): runByToolUseId / promptsByToolUseId are already keyed by the owning Agent''s toolUseId, and resolveOwner''s direct route (conversation_view.dart:210-217) uses parent_tool_use_id (T-338) which disambiguates concurrent agents correctly. THE HAZARD: resolveOwner falls back to ''nearest'' = lastAgent (the most-recently-emitted Agent in stream order; conversation_view.dart:228, applied at :242). In a parallel fan-out any item that lacks parent_tool_use_id and a rooted parentUuid chain would mis-route to whichever agent was emitted last — landing in the WRONG card. Harden this: for the multi-agent case, drop or guard the nearest-lastAgent fallback so an unattributable item is rendered inline/orphaned (resolveOwner already returns null -> handled at :243) rather than mis-filed into a sibling agent''s card.

2. PRESERVE the existing grouping. This ticket only adds an Agent-spawn cluster boundary; it must NOT regress the rest:
   - Non-agent foldables (Bash/Read/Grep/LS/etc.) keep coalescing into the generic ''Activity / N steps'' cluster exactly as today (activity_cluster.dart groupConversation/_isFoldable).
   - The intra-agent folding stays: prompt-into-call (T-263), run-nested-under-card (T-264), sidechain routing by parent_tool_use_id (T-338). Reuse them; do not rebuild.
   - Net behaviour: a fan-out of N agents -> N distinct collapsed cards, each containing its own complete run; surrounding non-agent tool calls still group into their normal Activity card.

Test additions: (a) two concurrent agents whose sidechain items interleave -> each agent''s run items land under its own card, none cross-attributed; (b) an unattributable sidechain item (no parent_tool_use_id, broken chain) is NOT swept into the nearest agent''s card; (c) regression: consecutive Bash/Read calls still form one Activity cluster.', NULL, '2026-06-10 15:28:52', '2026-06-10 15:28:52', '2026-06-10 15:28:52', NULL, '0352b24d88a4bf24ede628880fe9b502', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB4FDREHRYRR7B9ER72KCQKC', 'status', 'backlog', 'in_progress', NULL, '2026-06-10 15:54:23', '2026-06-10 15:54:23', '2026-06-10 15:54:23', NULL, '8061a1d449acdb1e467239de0dce5d1d', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB4FDREHRYRR7B9ER72KCQKC', 'status', 'in_progress', 'in_progress', NULL, '2026-06-10 16:02:55', '2026-06-10 16:02:55', '2026-06-10 16:02:55', NULL, '9c00a4d5fefdc3cf8f227b040bc78acb', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB4FDREHRYRR7B9ER72KCQKC', 'description', 'Add a row of type-filter toggle chips at the top of the tickets panel, directly below the "Filter tickets…" box (no section header — the chips read on their own). One chip per ticket type the user thinks in: Bug, Ticket, Epic, Initiative. All four ON by default.

## Behaviour
- Single-click a chip → toggle that type in/out of the list.
- Double-click a chip → isolate (solo) that type: turns it ON and all others OFF. Double-click the same chip again → restore all to ON. This is the chart-legend solo pattern (Plotly/Tableau/Grafana) — learnable and fully reversible.
- Last-off resets to all-on: disabling the final remaining type snaps all chips back ON. An empty type filter means "no filter", so the list is never mysteriously blank.
- Tooltip per chip: "Click to toggle · double-click to isolate".

## Type mapping (pql → chip)
pql ticket types are initiative, epic, story, task, bug (see lib/builtin/tickets/src/ticket_colors.dart). The four chips map as:
- Bug → bug
- Ticket → story + task (leaf work items)
- Epic → epic
- Initiative → initiative

Each chip carries its type-colored dot + border using TicketTypeColors (bug #E87D7D, story/task green/grey, epic #78A0F8, initiative #C792EA).

## Filtering
- Type filter is ANDed with the existing text filter in _TicketsViewState (lib/builtin/tickets/src/tickets_view.dart): a ticket shows only if its type is enabled AND it matches the text filter.
- When the type filter hides all items in a status section, that section collapses out (same as text-filter behaviour today).

## Implementation notes
- Active-chip visual: filled tint + type-colored border (active) vs muted/no border (inactive) — reuse the _Toggle pattern from lib/builtin/search/src/search_panel_view.dart and ClideTappable.
- Persist nothing across sessions for v1 (always all-on on load); revisit if requested.
- a11y: Semantics(button, toggled) per chip, mirroring the search-panel toggle.

## Wireframe
docs/design/wireframes/tickets/ticket-type-filters.json (+ .png export)', 'Add a row of type-filter toggle chips at the top of the tickets panel, directly below the "Filter tickets…" box (no section header — the chips read on their own). One chip per ticket type the user thinks in: Bug, Ticket, Epic, Initiative. All four ON by default.

## Behaviour
- Single-click a chip → toggle that type in/out of the list.
- Double-click a chip → isolate (solo) that type: turns it ON and all others OFF. Double-click the same chip again → restore all to ON. This is the chart-legend solo pattern (Plotly/Tableau/Grafana) — learnable and fully reversible.
- Last-off resets to all-on: disabling the final remaining type snaps all chips back ON. An empty type filter means "no filter", so the list is never mysteriously blank.
- Tooltip per chip: "Click to toggle · double-click to isolate".

## Type mapping (pql → chip)
pql ticket types are initiative, epic, story, task, bug (see lib/builtin/tickets/src/ticket_colors.dart). The four chips map as:
- Bug → bug
- Ticket → story + task (leaf work items)
- Epic → epic
- Initiative → initiative

Each chip carries its type-colored dot + border using TicketTypeColors (bug #E87D7D, story/task green/grey, epic #78A0F8, initiative #C792EA).

## Filtering
- Type filter is ANDed with the existing text filter in _TicketsViewState (lib/builtin/tickets/src/tickets_view.dart): a ticket shows only if its type is enabled AND it matches the text filter.
- When the type filter hides all items in a status section, that section collapses out (same as text-filter behaviour today).

## Implementation notes
- Active-chip visual: filled tint + type-colored border (active) vs muted/no border (inactive) — reuse the _Toggle pattern from lib/builtin/search/src/search_panel_view.dart and ClideTappable.
- Persist nothing across sessions for v1 (always all-on on load); revisit if requested.
- a11y: Semantics(button, toggled) per chip, mirroring the search-panel toggle.

## Wireframe
docs/design/wireframes/tickets/ticket-type-filters.json (+ .png export)

Design revision (2026-06-10, supersedes the chip set/order above): FIVE chips, one per pql type — no story+task grouping. Ordered LARGE→SMALL left to right: Initiative, Epic, Story, Task, Bug. Each maps 1:1 to its pql type (initiative/epic/story/task/bug) with its TicketTypeColors dot+border (initiative #C792EA, epic #78A0F8, story #7DD3A8, task #9AA0AA grey, bug #E87D7D). All five ON by default. Toggle/solo(double-click)/last-off-reset behaviour unchanged. Wireframe updated + approved.', NULL, '2026-06-10 16:06:25', '2026-06-10 16:06:25', '2026-06-10 16:06:25', NULL, '26b5b4d5cf2a48fe6aeacd7b83968848', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5TWC00GW0P3X02HZW', 'status', 'backlog', 'ready', NULL, '2026-06-10 16:09:21', '2026-06-10 16:09:21', '2026-06-10 16:09:21', NULL, 'c89b4ddcbdeea95483c53b1b76220842', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5TWC00GW0P3X02HZW', 'status', 'ready', 'in_progress', NULL, '2026-06-10 16:09:26', '2026-06-10 16:09:26', '2026-06-10 16:09:26', NULL, 'c36e6343d44f59ff4af0eea3178b5a94', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5TWC00GW0P3X02HZW', 'status', 'in_progress', 'backlog', NULL, '2026-06-10 16:09:57', '2026-06-10 16:09:57', '2026-06-10 16:09:57', NULL, 'be22c7ff64f106d600b4a5bd70ced1d2', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB4J5E6W983P1S7BE0FDPSMM', 'status', 'backlog', 'ready', NULL, '2026-06-10 16:10:20', '2026-06-10 16:10:20', '2026-06-10 16:10:20', NULL, '6f4b3ce9e2167200ebdde0c1511d4a91', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB4J5E6W983P1S7BE0FDPSMM', 'status', 'ready', 'in_progress', NULL, '2026-06-10 16:10:22', '2026-06-10 16:10:22', '2026-06-10 16:10:22', NULL, 'cce7ce3f17ae087f753f4d6d072a702e', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB4FDREHRYRR7B9ER72KCQKC', 'status', 'in_progress', 'done', NULL, '2026-06-10 16:12:15', '2026-06-10 16:12:15', '2026-06-10 16:12:15', NULL, '4cb2daa831a115888a9456461bf53bdf', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB4J5E6W983P1S7BE0FDPSMM', 'status', 'in_progress', 'in_progress', NULL, '2026-06-10 16:13:50', '2026-06-10 16:13:50', '2026-06-10 16:13:50', NULL, '88bf89e802bd16209db6d2c0a9b963c0', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB4J5E6W983P1S7BE0FDPSMM', 'status', 'in_progress', 'done', NULL, '2026-06-10 16:15:38', '2026-06-10 16:15:38', '2026-06-10 16:15:38', NULL, '4aa30d9c68463d18f5778cbd20c9da5a', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB493JEW32CH0H3771TNHF7G', 'status', 'backlog', 'ready', NULL, '2026-06-10 16:21:55', '2026-06-10 16:21:55', '2026-06-10 16:21:55', NULL, 'b2f20ad3cb093b7e89342f6b374097ff', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB44SKPKTHFMV6WD28GZYPXM', 'status', 'backlog', 'ready', NULL, '2026-06-10 16:22:24', '2026-06-10 16:22:24', '2026-06-10 16:22:24', NULL, 'b88b0e1ef2e1c3711527388dc8d07cce', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB3DWCJSGZH9WYDNFWZBAYYR', 'status', 'backlog', 'ready', NULL, '2026-06-10 16:22:28', '2026-06-10 16:22:28', '2026-06-10 16:22:28', NULL, '4b58326ae217b60be81a07603afee36d', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB2T11GCV1EV07DYD5BZENTM', 'status', 'backlog', 'ready', NULL, '2026-06-10 16:22:37', '2026-06-10 16:22:37', '2026-06-10 16:22:37', NULL, 'c62c5ac18a88ba763b5194f89a2a7482', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB4RD1DDSYM4J7WYEGTXARB4', 'status', 'backlog', 'done', NULL, '2026-06-10 16:34:51', '2026-06-10 16:34:51', '2026-06-10 16:34:51', NULL, '56cde33409eb796ad4fb420ed3033c70', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB4XCM5KBXDDSCWJ37GPYG3R', 'status', 'backlog', 'done', NULL, '2026-06-10 16:57:07', '2026-06-10 16:57:07', '2026-06-10 16:57:07', NULL, '1ce291d54831d3ede687384037c379ff', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB50YE6S6YWNP2ZSFWES9B2W', 'status', 'backlog', 'done', NULL, '2026-06-10 17:13:53', '2026-06-10 17:13:53', '2026-06-10 17:13:53', NULL, '87b069d3f25c91622c9720147d359360', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB58X0TFJ02YTMVPD0D9Q838', 'status', 'backlog', 'done', NULL, '2026-06-10 17:47:01', '2026-06-10 17:47:01', '2026-06-10 17:47:01', NULL, 'ba3d17ec4e668ade82b07d2bb848ab91', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB5CW7JPT6BR2RWMNYVCXJ50', 'status', 'backlog', 'done', NULL, '2026-06-10 18:20:28', '2026-06-10 18:20:28', '2026-06-10 18:20:28', NULL, '213109fcd67b4375ebbd3b59c4a1ed04', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB5HMYDXP62RKH3HP55T6AYG', 'status', 'backlog', 'review', NULL, '2026-06-10 18:24:41', '2026-06-10 18:24:41', '2026-06-10 18:24:41', NULL, 'c5a88f9594c44896a6a3d1a4b2418ed2', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB5HMYDXP62RKH3HP55T6AYG', 'status', 'review', 'done', NULL, '2026-06-10 18:27:58', '2026-06-10 18:27:58', '2026-06-10 18:27:58', NULL, 'a9c72ab53b69f5ca6bf1fa4dd0ddfa05', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB5M14B76B31654D959XM5AC', 'status', 'backlog', 'done', NULL, '2026-06-10 18:38:53', '2026-06-10 18:38:53', '2026-06-10 18:38:53', NULL, 'b94cfe8ba315b3be6775474c681b4e80', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBAWHM1SQ1686ZJ8JQCFQ1ZW', 'description', 'flutter pub outdated reports 16 packages behind latest (3 direct: ffi 2.1.3→2.2.0, jovial_svg 1.1.26→1.1.30, markdown 7.2.2→7.3.1; dev: alchemist 0.12.1→0.14.0, mocktail 1.0.4→1.0.5, test 1.31.0→1.31.1; plus transitive incl. xml 6.6.1→7.0.1 major). Per the prefer-zero-deps + exact-pin + advisory-review guardrail (D-42, CLAUDE.md supply chain), evaluate each pinned/direct dep: review CVEs/advisories (OSV.dev + pub.dev) for the current pin AND the candidate version, then bump the safe ones (artefact + assets/licenses.yaml in the same commit) and document any deliberately-held pins. Transitive deps move with the resolver/Flutter SDK; note but don''t force. Triggered by repeated ''N packages have newer versions'' noise on every build.', 'flutter pub outdated reports 16 packages behind latest (3 direct: ffi 2.1.3→2.2.0, jovial_svg 1.1.26→1.1.30, markdown 7.2.2→7.3.1; dev: alchemist 0.12.1→0.14.0, mocktail 1.0.4→1.0.5, test 1.31.0→1.31.1; plus transitive incl. xml 6.6.1→7.0.1 major). Per the prefer-zero-deps + exact-pin + advisory-review guardrail (D-42, CLAUDE.md supply chain), evaluate each pinned/direct dep: review CVEs/advisories (OSV.dev + pub.dev) for the current pin AND the candidate version, then bump the safe ones (artefact + assets/licenses.yaml in the same commit) and document any deliberately-held pins. Transitive deps move with the resolver/Flutter SDK; note but don''t force. Triggered by repeated ''N packages have newer versions'' noise on every build.

FOLLOW-UP SCOPE (folded in 2026-06-11):

1. DONE: osv-scanner supply-chain gate added to `make push-check` (ci/osv_scan.sh; fail-closed on any pubspec.lock advisory). Requires osv-scanner on PATH (brew install osv-scanner).

2. TODO — tighten env floors to reality. pubspec.yaml `environment` currently declares Dart >=3.5.0 / Flutter >=3.19.0, but we actually require more (alchemist 0.12 needs Flutter 3.32; the held markdown 7.3.1 needs Dart 3.9). Raise floors to ~Dart >=3.9.0 / Flutter >=3.32.0 — honest minimums. Raising Dart to 3.9 also unblocks the held markdown 7.2.2 -> 7.3.1 bump.

3. TODO — exact toolchain pin for reproducible builds. No FVM .fvmrc / .tool-versions / .flutter-version exists; a fresh clone builds with whatever Flutter the dev has (>= floor). Add an exact pin (FVM .fvmrc or asdf/mise .tool-versions) targeting the current toolchain (Dart 3.12.1 / Flutter 3.44.1).', NULL, '2026-06-11 07:05:54', '2026-06-11 07:05:54', '2026-06-11 07:05:54', NULL, 'f6d9c657c6987f7927bc3ba0bc02b3a4', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBAWHM1SQ1686ZJ8JQCFQ1ZW', 'status', 'backlog', 'ready', NULL, '2026-06-11 07:05:58', '2026-06-11 07:05:58', '2026-06-11 07:05:58', NULL, '1553f134361839180feffa625a88c06d', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBAWHM1SQ1686ZJ8JQCFQ1ZW', 'status', 'ready', 'done', NULL, '2026-06-11 10:12:25', '2026-06-11 10:12:25', '2026-06-11 10:12:25', NULL, '53cfd5cf779b9a8474afe7e74efd02a3', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB44SKPKTHFMV6WD28GZYPXM', 'status', 'ready', 'in_progress', NULL, '2026-06-11 10:47:15', '2026-06-11 10:47:15', '2026-06-11 10:47:15', NULL, '4ac3982fdaada5c776320c99cbf0763c', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB493JEW32CH0H3771TNHF7G', 'status', 'ready', 'in_progress', NULL, '2026-06-11 10:49:25', '2026-06-11 10:49:25', '2026-06-11 10:49:25', NULL, 'c4fca969ce9e6d31122706878554bbdb', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB3DWCJSGZH9WYDNFWZBAYYR', 'status', 'ready', 'in_progress', NULL, '2026-06-11 10:49:33', '2026-06-11 10:49:33', '2026-06-11 10:49:33', NULL, '6180a1491ff29428974ca84c0de4ebb0', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB44SKPKTHFMV6WD28GZYPXM', 'status', 'in_progress', 'done', NULL, '2026-06-11 11:27:00', '2026-06-11 11:27:00', '2026-06-11 11:27:00', NULL, 'b0cf6bb97619a79a419caf4287fe2a54', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB3DWCJSGZH9WYDNFWZBAYYR', 'status', 'in_progress', 'in_progress', NULL, '2026-06-11 11:27:07', '2026-06-11 11:27:07', '2026-06-11 11:27:07', NULL, '00d5d9b5cf592f3a3fc63fbef7a8b8f2', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB3DWCJSGZH9WYDNFWZBAYYR', 'status', 'in_progress', 'done', NULL, '2026-06-11 12:35:27', '2026-06-11 12:35:27', '2026-06-11 12:35:27', NULL, '3426869e05daf251e562d77373d55752', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB493JEW32CH0H3771TNHF7G', 'status', 'in_progress', 'in_progress', NULL, '2026-06-11 12:35:27', '2026-06-11 12:35:27', '2026-06-11 12:35:27', NULL, '4f776a2c08d43710d7dadf9bb3a4b71f', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB493JEW32CH0H3771TNHF7G', 'status', 'in_progress', 'done', NULL, '2026-06-11 12:57:24', '2026-06-11 12:57:24', '2026-06-11 12:57:24', NULL, 'd067abbb3829e8eb200f7f854befba2c', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7CEKQCMZAV751402G', 'status', 'backlog', 'ready', NULL, '2026-06-11 13:01:55', '2026-06-11 13:01:55', '2026-06-11 13:01:55', NULL, '122a1e8ac78fe4a4429c6e146b0e1a17', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7CEKQCMZAV751402G', 'description', 'Check for new versions on startup (or on demand via command palette). Show a non-intrusive notification when an update is available. Support in-place update without losing running Claude sessions (tmux sessions survive). Respect POLICY.md: no silent network calls on default launch path — the check should be opt-in or gated behind a setting. Consider delta updates for bandwidth efficiency.', 'Check for new versions on startup (or on demand via command palette). Show a non-intrusive notification when an update is available. Support in-place update without losing running Claude sessions (tmux sessions survive). Respect POLICY.md: no silent network calls on default launch path — the check should be opt-in or gated behind a setting. Consider delta updates for bandwidth efficiency.

─────────────────────────────────────────────
REFINED 2026-06-11

## Current state (grounding)
- Version is surfaced at runtime via `lib/src/build_info.g.dart` (`clideVersion`,
  `clideCommit`, `clideDate`, `clideRepository` = github.com/postmeridiem/clide),
  generated from pubspec by `make gen-build-info`. This is the "installed version".
- Install layout (`make install`): Linux → bundle at `~/.local/lib/clide/`, C client
  at `~/.local/bin/clide`, desktop file + icons. macOS → `~/Applications/clide.app`
  + `~/.local/bin/clide`. Windows: not yet shipped.
- clide currently makes NO outbound HTTP calls anywhere in `lib/`. Self-update would
  be the FIRST one — so this is a policy-sensitive feature, not just plumbing.
- tmux owns Claude session persistence (D-41); the app re-attaches on restart. An
  in-place update that restarts the app does NOT lose sessions — they live in tmux,
  outside the bundle.

## HARD CONSTRAINTS (non-negotiable)
- **D-64 (no telemetry / no phone-home):** "No auto-update checks without user
  action." This is STRICTER than this ticket''s original "opt-in or gated behind a
  setting" wording. A background/startup check — even one a setting enabled — runs
  "without user action" at that launch and conflicts with D-64. RESOLUTION: the
  version check must be **explicitly user-initiated every time** (a command-palette
  "Check for updates…" action / an About-screen button). If we ever want a
  startup/periodic check, that needs a deliberate D-64 amendment first — flag, don''t
  assume.
- **POLICY.md §"no network on the default launch path":** opening the app, a file,
  or typing must never trigger the fetch. The update check + download are explicit
  user actions, so they''re allowed — but must meet the §"grudging allowance"
  criteria: clear error on failure (not silent), cached result, app fully functional
  if the fetch fails.

## BLOCKING PREREQUISITE (likely its own ticket under T-46)
There is no release channel to update FROM today: only 2 git tags (v2.0.0, v2.1.0)
despite being at 2.3.3, no CI (`.github/workflows` is empty), and no published binary
artifacts. Self-update is meaningless without:
  1. Consistent, automated release tagging (every `release vX.Y.Z` commit → a tag).
  2. CI that builds the per-platform bundles and publishes them as GitHub Releases.
  3. Each artifact accompanied by a checksum AND a signature (POLICY.md: "behavior is
     determined by the SIGNED release artifact"). An unsigned/unverified download
     would break the trust model the update is supposed to preserve.
  4. A machine-readable "latest version" source — the GitHub Releases API
     (`/repos/postmeridiem/clide/releases/latest`) is the zero-infra option; a
     committed `latest.json` manifest is the alternative.
RECOMMENDATION: split this prerequisite into a sibling story "Release channel: CI
build + signed GitHub Releases + version manifest" and make T-47 depend on it.

## DECISIONS TO MAKE (surface before building)
1. Check source: GitHub Releases API vs a hosted `latest.json`. (Lean: Releases API —
   no extra infra, origin is already GitHub.)
2. Signature scheme + verification: minisign/age/cosign? Where does the public key
   live (vendored in-repo, per POLICY.md provenance)?
3. Delivery: full bundle replacement vs delta/binary-patch (original ask). Lean full
   for v1 — deltas are a bandwidth optimization, not correctness; revisit if size hurts.
4. Apply strategy per platform: Linux is easy (swap `~/.local/lib/clide/` + the
   `~/.local/bin/clide` client atomically, then relaunch). macOS `.app` replacement +
   notarization/quarantine handling is harder. Windows out of scope until it ships.
5. Privilege: user-local installs (`~/.local`, `~/Applications`) need no sudo — good.
   A system-wide install would; declare user-local only for v1.

## PROPOSED SCOPE / PHASES (each independently shippable)
P0 (prereq, separate ticket): release channel — tags + CI + signed GitHub Releases.
P1: "Check for updates…" command (palette + About-screen button). Explicit fetch of
    the latest release, semver-compare against `clideVersion`, non-intrusive ToastService
    notification ("clide X.Y.Z is available") with a "What''s changed" link to the release
    notes. No download yet. Clear error toast on network failure. Fully covers the D-64 /
    POLICY-compliant "notify" half of the story.
P2: download + signature/checksum verify into a staging dir; show progress; verify before
    touching the install.
P3: apply + relaunch (Linux first): atomic swap of bundle + client, restart the app;
    tmux sessions survive (D-41). Confirm-before-apply.
P4 (optional): macOS apply path (.app swap + quarantine), delta updates.

## ACCEPTANCE (for the full story; refine per-phase ticket)
- No network call on any default launch path (verified — grep + a test that boot makes
  no outbound connection).
- "Check for updates" only runs on explicit user action; failure surfaces a clear
  toast, never a silent hang or degraded launch.
- A downloaded update is signature+checksum verified before it can replace the install;
  verification failure aborts with the old version intact.
- Applying an update and relaunching preserves running Claude/tmux sessions.
- Version comparison is correct semver (2.3.10 > 2.3.9, pre-release handling defined).

## REFERENCES
POLICY.md (network rule + grudging-allowance criteria); D-64 (no phone-home);
D-41 (tmux session persistence); `lib/src/build_info.g.dart` (version source);
`lib/kernel/src/toast.dart` (ToastService — the notification); settings bool pattern
(`app.*.enabled`, `lib/kernel/src/extensions_manager.dart`); `Makefile` install target
(per-platform layout); parent epic T-46 (cross-platform installer).', NULL, '2026-06-11 13:30:03', '2026-06-11 13:30:03', '2026-06-11 13:30:03', NULL, 'cf37ae15ac8dbf59eb23e98fef32427f', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM7CEKQCMZAV751402G', 'status', 'ready', 'backlog', NULL, '2026-06-11 13:30:47', '2026-06-11 13:30:47', '2026-06-11 13:30:47', NULL, '2c566e731dfce3b9e111c1c1c50ec642', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBDSJYQFDNKP4KA1JAEDSS8W', 'description', NULL, 'Eliminate the out-of-repo pql dependency friction: clide ships its own pinned pql and owns first-open workspace setup. Spans four decisions — D-92 (bundle pql), D-93 (zero clide dirs in-repo), D-94 (workspace modes), D-95 (onboarding + read-mode). Outcome: a fresh clone/install of clide works with no separate pql install or version coordination; the repo''s only tool dirs are .git/ and .pql/. Three epics: T-355 bundle, T-356 footprint, T-357 onboarding.', NULL, '2026-06-11 13:37:57', '2026-06-11 13:37:57', '2026-06-11 13:37:57', NULL, '02cfffe1db3519f397186ca4cc80d736', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBDSKGAHYHH2NPZK8B6EV4D4', 'description', NULL, 'Vendor a version-pinned pql binary per shipped platform under native/<platform>/, following the dugite pattern (D-59/D-63): BUILD.md provenance (upstream commit SHA, build command, toolchain, sha256), assets/licenses.yaml entry (D-42/D-65). Add a bundled-first resolver mirroring _resolveDugiteGit() in lib/kernel/src/toolchain_paths.dart: CLIDE_PQL_BIN env override -> binary next to the executable -> system pql on PATH (currently pql is PATH-only via _findOnPath at line 88). SECURITY: resolve against the install dir only, never workspace-relative — a planted ./native/pql is a code-exec vector (the T-98 dugite lesson). Bundled copy must not self-update. Add a soft version-floor check that surfaces an out-of-date override/PATH pql in the Problems panel. Switch CI to run the in-tree binary instead of assuming pql on the runner.', NULL, '2026-06-11 13:38:05', '2026-06-11 13:38:05', '2026-06-11 13:38:05', NULL, '7965e1306d3c064cee76f6537d5ad237', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBDSM0PRGYR61R0NWYAT9VDC', 'description', NULL, 'Move clide''s project-scoped state out of the in-repo .clide/ dir into user scope, keyed by a workspace-path hash (reuse the FNV-1a convention from D-70''s IPC socket path). Affected today: SettingsStore project file (_projectFile -> .clide/settings.yaml in lib/kernel/src/settings.dart) and theme_persistence.dart (project.theme). Provide a one-time migration that relocates an existing .clide/settings.yaml to user scope and removes the dir. Drop .clide/ from the gitignore-at-install set (only .pql/ remains). If shared/committed clide config is ever needed, it goes as clide-owned keys in .pql/config.yaml, not a new dir. Note: the open extension-DB question (governance/questions/process.md Q on .clide/clide.db) now assumes a user-scope DB. Accept D-70''s trade-off: moving/renaming a repo re-keys it and resets personal layout.', NULL, '2026-06-11 13:38:13', '2026-06-11 13:38:13', '2026-06-11 13:38:13', NULL, '08f32bc29f3cfce247957d66415d85e4', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBDSPECQ0FPKB9SYTD7KZSBM', 'description', NULL, 'Add a first-open, idempotent workspace prep flow that reconciles state (virgin / pql-user / partially-init / fully-init / previously-declined) rather than blindly running pql init. Two ordered gates: (1) non-git folder -> OFFER git init, default NO, with a guard that warns when a parent .git would create a nested repo; or pick another folder. (2) pql provisioning, now that pql ships bundled (T-355): config+index is the mandatory floor (the files/query/ignore engine); the planning layer (decisions/tickets + changelog hooks, D-67) is a CONTEXTUAL opt-in offered at first open of the Decisions/Tickets surface, with disclosure. The modal must disclose everything it writes (.gitignore entries, pql config, and — opt-in only — git hooks). Handle the friction.md gotcha: pql init writes to .git/hooks and ignores an existing core.hooksPath; do not clobber it. Writable repo w/o .pql = invalid-until-init. Unwritable repo (read-only mount / no perms) -> degrade to read mode: file tree + editor + D-79 grep stay live, pql surfaces dark behind a banner (depends on T-358 modes). Remember a decline in user scope keyed by repo path; provide an explicit ''initialize workspace'' command; no re-nagging.', NULL, '2026-06-11 13:38:23', '2026-06-11 13:38:23', '2026-06-11 13:38:23', NULL, '47e2d75302ec95305ff1cacd2afc2a26', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBDSQ2GBSP0ZH4RHZG2PMR0R', 'description', NULL, 'Introduce a ''modes'' capability in the extension manifest (lib/extension/src/manifest.dart) as an open vocabulary: edit and read now, with remote/ssh/webui reserved (D-94). The extension host (lib/extension/src/host.dart) activates an extension only when the active workspace mode is in its declared set; an undeclared extension defaults to edit-only. Then classify the builtins: read-mode-safe = editor (view), files (tree + D-79 grep), git (status/log/diff viewing), terminal, claude; goes dark = pql (search/query/backlinks), decisions, tickets, graph; partial = problems (keep non-pql diagnostics, drop the pql.doctor row). This is the substrate read-mode degrade (T-357) gates on, and the seam the SSH-remote question (Q-23) is expected to resolve into.', NULL, '2026-06-11 13:38:31', '2026-06-11 13:38:31', '2026-06-11 13:38:31', NULL, 'ba0a16d581d6c81fd0cc39ffab15887d', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB2T11GCV1EV07DYD5BZENTM', 'status', 'ready', 'in_progress', NULL, '2026-06-11 14:18:34', '2026-06-11 14:18:34', '2026-06-11 14:18:34', NULL, 'a2a75bcb471d6eba8a215d56922c6337', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB2T11GCV1EV07DYD5BZENTM', 'status', 'in_progress', 'in_progress', NULL, '2026-06-11 14:59:53', '2026-06-11 14:59:53', '2026-06-11 14:59:53', NULL, '96bef4f722871cb468f67b55d6447acc', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB2T11GCV1EV07DYD5BZENTM', 'status', 'in_progress', 'done', NULL, '2026-06-11 17:09:12', '2026-06-11 17:09:12', '2026-06-11 17:09:12', NULL, '591cc2576194fd9400b42aa6c932f0a8', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHBGHNEQTAEPGNJKN42C1E8', 'description', NULL, 'Thirteen parallel subsystem reviewers + adversarial verification over ~58k LOC produced ~14 high-severity and ~35 medium findings plus systemic patterns and a feature backlog. Source: fable-ous.md (committed alongside this epic). Children are filed individually so they can land independently; feature proposals went to governance/questions as Q-records, not tickets.

Acceptance: all dragon (high-severity) findings resolved or formally rejected with a D-record; scorpions shipped or moved to follow-up work with rationale; rat-extermination and systemic-pattern batches closed; god-file split plans written into their tickets.', NULL, '2026-06-11 21:54:44', '2026-06-11 21:54:44', '2026-06-11 21:54:44', NULL, 'f4f3f8de34ddcffcedfa3dda86cddd7f', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHBJ5T7HAQ9CA8XQMX43A2C', 'description', NULL, 'lib/src/pty/native_pty.dart:444-450 — on child EOF, _reap() sets _dead = true but never closes _fd; a later close() short-circuits at `if (_dead) return;` (line ~460) so _nativeClose(_fd) (line ~477) never runs. Every terminal/Claude pane whose child exits on its own leaks an fd and a pty device for the life of the app. Two independent reviewers confirmed.

Fix: close the master fd in the natural-exit path (or let close() proceed to fd teardown when dead). Add a test asserting the fd is released after child EOF.', NULL, '2026-06-11 21:54:56', '2026-06-11 21:54:56', '2026-06-11 21:54:56', NULL, '446dac267b474cc3c72291e1d34ed8d1', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHBKK2TZQK683J8FS0ZH5A4', 'description', NULL, 'lib/builtin/claude/src/stream_json_session.dart:43-78 — the claude child stderr is never drained: >=64KB of --verbose spew fills the pipe, the child blocks mid-turn, and the flagship pane wedges with zero diagnostics. Nothing watches exitCode or stdout onDone (line ~303), so a crashed/dead session just looks busy.

Fix: drain stderr into a bounded ring buffer (surface it on failure), watch exitCode/onDone, and emit a terminal SessionEnded state to the pane. Intersects T-283 (resume hang has no timeout/fallback). Tests: dead-child surfaces SessionEnded; stderr flood does not wedge the session.', NULL, '2026-06-11 21:55:07', '2026-06-11 21:55:07', '2026-06-11 21:55:07', NULL, '9a3d2aecfc09ce6c6afa183e80e718f4', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHBN5F0F8SDF15P21DNKT1W', 'description', NULL, 'lib/src/ipc/mcp_server.dart:138-195, started unconditionally at boot (lib/main.dart:174-180). D-71 threat model (another user on the same host must not drive my IDE) is enforced with 0600 on the unix socket — then bypassed wholesale by an unauthenticated localhost HTTP port that, since D-86, serves every clide verb as a tool.

Fix: generate a token in the lock file (Claude Code /ide lock format has a slot for it) and require the auth header on every request. Tests: request without token is rejected; token round-trips via the lock file.', NULL, '2026-06-11 21:55:21', '2026-06-11 21:55:21', '2026-06-11 21:55:21', NULL, '3e4a3ab07c224bc9c498c4ac168fcb42', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHBPQE4J4YBJX92812ZK6DR', 'description', NULL, 'lib/src/editor/registry.dart:215-219 returns absolute paths verbatim — no .. normalization, no path_safety call — an unconfined read AND write primitive over IPC while files.read is carefully guarded.

Fix: route editor.open/editor.save through path_safety like files.*. Tests: traversal and absolute-escape attempts rejected for both verbs. Longer-term the confinement should move to the dispatch layer (see the systemic ticket filed with this epic).', NULL, '2026-06-11 21:55:33', '2026-06-11 21:55:33', '2026-06-11 21:55:33', NULL, '9814d1e2ac630b792799349b073e29cd', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHBR4636GSRJBWFJDAZ6ZA0', 'description', NULL, 'lib/src/search/replace_engine.dart:124-143 — the include/exclude glob filters the user typed are accepted but never applied; replace will happily rewrite files outside the filter.

Fix: apply the same glob filtering the search side uses before rewriting. Test: replace with an include glob touches only matching files; exclude glob is honored.', NULL, '2026-06-11 21:55:44', '2026-06-11 21:55:44', '2026-06-11 21:55:44', NULL, '6f7302d4cf04632c7c336131552dddc8', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHBSG6356MZJ2DCCCSBMBGM', 'description', NULL, 'lib/src/files/listing.dart:46-54 — stat() follows links, so isSymlink is always false; walkFiles therefore descends symlinked directories the docs claim it skips (escape hatch out of the workspace, plus cycle risk).

Fix: use lstat (FileStat via Link check / FileSystemEntity.isLinkSync on the raw path) for symlink detection. Tests: symlinked dir is reported as symlink and not descended; symlink cycle does not hang the walk.', NULL, '2026-06-11 21:55:56', '2026-06-11 21:55:56', '2026-06-11 21:55:56', NULL, 'eb7a89483e85f7c069567c56ee80fdb9', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHBV0465906BY3QFAY9F1YM', 'description', NULL, 'lib/builtin/terminal/src/terminal_pane.dart:131-137 calls ClideKernel.of(context) from dispose() — illegal ancestor lookup, swallowed by catch (_) — so pane.close is never sent and the backend PTY + daemon pane leak on every closed terminal pane. The same idiom leaks the settings listener in every disposed ClaudePane (lib/builtin/claude/src/claude_pane.dart:460-466).

Fix: cache the kernel ref in didChangeDependencies, delete the catch-alls. Combined with the PTY natural-exit fd leak this is a two-stage leak pipeline. Tests: closing a terminal pane sends pane.close; disposing a ClaudePane removes its settings listener.', NULL, '2026-06-11 21:56:09', '2026-06-11 21:56:09', '2026-06-11 21:56:09', NULL, '92693bb428217e84d75d240b5da07bec', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHBWE2W1226T58CX37E50HC', 'description', NULL, 'lib/main.dart:335-344 — switching projects builds a new dispatcher with fresh PaneRegistry, FilesService, EditorRegistry, etc., but nothing calls the old set''s shutdown() methods (which exist and have zero callers). Old file watchers keep emitting into the new workspace''s bus.

Fix: dispose/shutdown the previous service set before (or while) standing up the new one. Test: after a workspace switch, the old FilesService watcher no longer delivers events.', NULL, '2026-06-11 21:56:19', '2026-06-11 21:56:19', '2026-06-11 21:56:19', NULL, '25954a8b7b5f77985dff44c8e78f5ee9', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5W6VN98RQM6S22X28', 'description', 'The bottom status-bar context slot for the Claude pane (model · permission-mode · context, T-145/T-150) frequently renders empty and doesn''t update. The slot is fed by the active pane''s status widget via the focus service (PaneContextStatusItem -> ClidePane.statusWidget in claude_pane.dart), sourced from StreamJsonSession.statusStream (model/permissionMode from the ''system/init'' event; cost/contextWindow from ''result'' events in stream_json_session.dart).

Repro: open clide; the status line is often blank and stays blank until/unless a turn completes (or never populates).

Likely suspects to investigate:
- status only published while the pane is the focused contribution (active==true) — if focus isn''t on the Claude pane, the slot clears.
- statusStream may not emit until the first ''result''/''init'' event; a resumed session (--resume) may not re-emit init, so model/mode never arrive.
- _statusWidget returns null when _status.isEmpty AND no skills, so an unstarted/!init session shows nothing.
- focus-slot wiring (FocusTracker) may not re-publish on pane (re)build / session rebind.

Acceptance: the Claude status line shows model · mode · context promptly after a session starts/resumes and stays current across turns and focus changes; add a test covering the resumed-session (no fresh init) case.', 'The bottom status-bar context slot for the Claude pane (model · permission-mode · context, T-145/T-150) frequently renders empty and doesn''t update. The slot is fed by the active pane''s status widget via the focus service (PaneContextStatusItem -> ClidePane.statusWidget in claude_pane.dart), sourced from StreamJsonSession.statusStream (model/permissionMode from the ''system/init'' event; cost/contextWindow from ''result'' events in stream_json_session.dart).

Repro: open clide; the status line is often blank and stays blank until/unless a turn completes (or never populates).

Likely suspects to investigate:
- status only published while the pane is the focused contribution (active==true) — if focus isn''t on the Claude pane, the slot clears.
- statusStream may not emit until the first ''result''/''init'' event; a resumed session (--resume) may not re-emit init, so model/mode never arrive.
- _statusWidget returns null when _status.isEmpty AND no skills, so an unstarted/!init session shows nothing.
- focus-slot wiring (FocusTracker) may not re-publish on pane (re)build / session rebind.

Acceptance: the Claude status line shows model · mode · context promptly after a session starts/resumes and stays current across turns and focus changes; add a test covering the resumed-session (no fresh init) case.

Root cause found and verified by the 2026-06-11 Fable review (fable-ous.md, epic T-359): statusStream is a plain broadcast controller — the system/init event fires while spawn() is still awaiting a 256KB transcript-tail read, before the pane ever subscribes (lib/builtin/claude/src/claude_pane.dart:322, lib/builtin/claude/src/session_orchestrator.dart:222-225). Fix: seed from session.status on bind, or make the stream replay-latest (see the ValueStream systemic ticket under T-359).', NULL, '2026-06-11 21:56:28', '2026-06-11 21:56:28', '2026-06-11 21:56:28', NULL, '8bddda6f828eeb567dfaed51eef82762', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHBYTJ4E7ZBY6DWWNT1S16M', 'description', NULL, 'lib/builtin/claude/src/conversation_view.dart:268-277 — the _atBottom pin exists but is only consulted on viewport resize, not on new items. Anyone reading earlier output during a long streaming reply is dragged to the bottom continuously.

Fix: gate the new-item auto-scroll on _atBottom (one-line) and add the missing twin test: scrolled-up viewport stays put when items stream in; at-bottom viewport follows.', NULL, '2026-06-11 21:56:40', '2026-06-11 21:56:40', '2026-06-11 21:56:40', NULL, 'e519966a59d3a52cdc28d598967010ce', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHC0HYRZ86CWW0DDQJ5CAQM', 'description', NULL, 'lib/src/terminal/src/core/escape/parser.dart:501-516 — SGR 38/48 extended-color parsing does unguarded params[i + 1] lookahead, so a truncated sequence like printf ''\e[38m'' throws RangeError inside Terminal.write. An emulator must never throw on hostile bytes. Secondary, same code path: colon-form SGR sub-parameters (e.g. 38:2:r:g:b, emitted by modern terminfo) are not split out and get mangled into bogus params.

Fix: bounds-check the lookahead (ignore incomplete 38/48 sequences), and parse colon-form sub-parameters per ECMA-48/ITU T.416 — treat 38:2::r:g:b and 38;2;r;g;b equivalently. Note T-123 (parser split) touches the same file; coordinate but do not block on it.

Acceptance: feeding any truncated/garbled SGR byte sequence never throws (fuzz-style test over partial sequences); colon-form truecolor sets the same fg/bg as semicolon form; existing SGR tests stay green.', NULL, '2026-06-11 21:56:59', '2026-06-11 21:56:59', '2026-06-11 21:56:59', NULL, 'acbde4172213adbf84599ca1575e2bb6', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHC2NM7AYKENZ0ZD49HAX1W', 'description', NULL, 'lib/widgets/src/clide_collapser_card.dart:92-101 — excludeSemantics: true on the card wipes every expanded child from the a11y tree: a screen-reader user can expand a run/tool card and hear nothing inside it. A11y is a Tier-0 contract in this repo, so this is a contract breach, not polish.

Fix: exclude semantics only while collapsed (or scope the exclusion to the chrome, not the body); keep the header announcing expanded/collapsed state.

Acceptance: semantics test asserting expanded-card children are present in the semantics tree and absent (or summarized) when collapsed; make test-a11y green.', NULL, '2026-06-11 21:57:12', '2026-06-11 21:57:12', '2026-06-11 21:57:12', NULL, '7ffe4c0c1c435020f5b0ef564088b997', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHC46SEHH8NQY481VMGK66R', 'description', NULL, 'The three a11y gate tests hand-enumerate their subjects and have measurably drifted from lib/: the contrast gate checks fewer themes than lib/main.dart:443-454 actually loads (catppuccin is silently unvalidated — the same theme list also drifted between main.dart and the testmode harness), and the i18n gate checks 4 of 8 namespaces. The gates stay green while covering less — worst kind of drift.

Fix (pattern: hand-enumerated lists drift; export the truth): make lib/ export one canonical const each for bundled themes, a11y gate subjects, and i18n namespaces; the gates and the testmode harness iterate those exports instead of their own lists. Add a meta-assertion where feasible (e.g. namespace list derived from the assets dir at test time) so a new theme/namespace cannot ship unvalidated.

Acceptance: gates fail if a newly added theme/namespace is not covered; catppuccin contrast-checked; all 8 i18n namespaces checked; testmode harness consumes the same exported theme list.', NULL, '2026-06-11 21:57:26', '2026-06-11 21:57:26', '2026-06-11 21:57:26', NULL, 'c8af63caa7c66890bf983ca0745ba220', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHC5ZE4EZEGXK8YY8J86CM0', 'description', NULL, 'lib/src/ipc/server.dart:151-180 — D-72 promises serial dispatch, but the async onData handler never pauses the subscription, so pipelined requests interleave; the shared StringBuffer framing can also drop or double lines when chunks split mid-frame, and per-chunk utf8 decode corrupts multi-byte characters split across chunks.

Fix in one move: client.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter()) consumed with await for — gives correct framing, persistent UTF-8 decoding, and true serialization at once.

Acceptance: test sending two pipelined requests in a single write (responses arrive in order, both handled); test a request split mid-UTF-8-rune across two socket writes; existing IPC tests stay green. Runs under dart test — keep imports Flutter-free.', NULL, '2026-06-11 21:57:40', '2026-06-11 21:57:40', '2026-06-11 21:57:40', NULL, '4463b6a7be217a811ec7d0a34f90d40e', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHC7KDFW07S8WTCC3MD71J0', 'description', NULL, 'The terminal''s only ingestion API is write(String) (lib/src/terminal/src/terminal.dart:218), so both consumers decode bytes per-chunk — a multi-byte rune split across PTY reads renders as U+FFFD garbage. FileTailFollower starts reading mid-file by construction, so it can begin mid-character too.

Fix: add Terminal.writeBytes(List<int>) backed by a persistent chunked Utf8Decoder (allowMalformed) per terminal instance; migrate the PTY consumer and FileTailFollower to it. Keep write(String) for tests/programmatic use.

Acceptance: test feeding a multi-byte rune split across two writeBytes calls renders one glyph; FileTailFollower starting mid-rune resyncs without emitting replacement chars mid-stream.', NULL, '2026-06-11 21:57:52', '2026-06-11 21:57:52', '2026-06-11 21:57:52', NULL, 'e3a6ef892b21e588590ce513c7e4e40d', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHC90B72A270CAKA7AP1ZX8', 'description', NULL, 'lib/builtin/claude/src/session_orchestrator.dart:191-249 — spawn() does check-then-act on the sessions map across two awaits (transcript-tail read, process start). Two concurrent spawns for the same session id both pass the check; the loser''s live claude process is orphaned, never killed, never observed.

Fix: hold a Map<String, Future<ManagedSession>> — first caller installs the future synchronously, later callers await the same future; remove the entry on failure.

Acceptance: test issuing two concurrent spawn() calls for one id yields the same ManagedSession instance and exactly one process spawn (count via injected spawner); failure path clears the in-flight entry so a retry can proceed.', NULL, '2026-06-11 21:58:03', '2026-06-11 21:58:03', '2026-06-11 21:58:03', NULL, '8dc37c08e1f62b6b8c3cdf80e32eb4be', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHCAFKK334YNJXZJQG4J6AW', 'description', NULL, 'lib/builtin/claude/src/claude_pane.dart:266-281 — when (re)binding a session, widget.forkSourceId takes precedence forever, so /clear in a fork pane re-forks the original conversation instead of clearing, and /resume and /fork misbehave the same way. Related context: clide owns /clear, /resume, /compact interception (T-156); panes pin a session id.

Fix: treat forkSourceId as a one-shot spawn parameter — consume it on first bind (clear it into pane state), so subsequent session-mutating commands operate on the pane''s live session.

Acceptance: test that a fork pane after /clear starts an empty session (no fork source passed to the orchestrator on respawn); first bind still forks from the source.', NULL, '2026-06-11 21:58:16', '2026-06-11 21:58:16', '2026-06-11 21:58:16', NULL, 'ce8c670160f5180e3eb35263c28d4f78', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHCC6AR37VTF4SY8DR99JHC', 'description', NULL, 'lib/kernel/src/settings.dart:199-219 — the writer emits toString() for maps nested inside lists, corrupting them on the next read; this breaks the documented keymap overlay across restarts. Writes are also non-atomic (a crash mid-write truncates the file), and a parse failure on load silently resets ALL settings instead of preserving the file and surfacing the error.

Fix: serialize with a real encoder (JSON/YAML emitter, whatever the file format is) covering nested structures; write to a temp file + rename for atomicity; on parse failure keep the original file (e.g. move aside as .broken) and log via the kernel Logger instead of resetting.

Acceptance: round-trip test for a keymap overlay (list of maps) across save/load; simulated partial write leaves previous settings intact; corrupt file does not silently reset and produces a logged diagnostic.', NULL, '2026-06-11 21:58:33', '2026-06-11 21:58:33', '2026-06-11 21:58:33', NULL, '1f0f584e4c35a60c69b6ffdbe41caad9', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHCEC25337J2AXXQNST56Y4', 'description', NULL, 'lib/kernel/src/extensions_manager.dart:133-192 — a throw mid-contribution leaves earlier contributions mounted while the extension records as failed; a retry then double-applies them. Also: disabling an extension ignores extensions that depend on it, and contribution registries silently clobber on id collision. Benign among curated builtins; hazardous the day Tier-6 Lua extensions (T-8) land.

Fix: make activation transactional — collect contributions, mount only after the extension activates cleanly, and unwind mounted ones on failure; disable refuses (or cascades, pick one and record it) when dependents are active; registries reject or namespace duplicate ids with a logged diagnostic.

Acceptance: test that an extension throwing mid-activation leaves zero contributions mounted and can retry cleanly; disable-with-dependents behaves per the chosen rule; duplicate contribution id surfaces an error instead of clobbering.', NULL, '2026-06-11 21:58:49', '2026-06-11 21:58:49', '2026-06-11 21:58:49', NULL, 'fef851b7cad9f7a3307e04de1168792a', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHCG84F4SPFW111CC4K26A8', 'description', NULL, 'The owned terminal fork fixes what it trips over but has no vttest-style conformance suite. Verified debt:

- HTS (set tab stop) is a no-op: calls isSetAt instead of setAt (lib/src/terminal/src/terminal.dart:423).
- DECCKM (cursor-keys application mode) is tracked but never consumed when encoding arrow-key input.
- Legacy X10/X11 mouse reporting rows are off-by-one AND the existing test enshrines the bug — fix both together.
- CPR (cursor position report) replies 0-based where every real terminal is 1-based.
- Scrollback is maintained but structurally unreachable: ViewportOffset.zero() is pinned on every build (lib/src/terminal/src/terminal_view.dart:224), so no scrolling UI path exists. (Blocks the semantic-terminal feature idea; fix is a prerequisite there.)

Approach: fix each item with a focused conformance test (vttest-style expectations); consider starting a small conformance_test.dart suite that future escape-sequence work extends. Coordinate with T-123 (parser split) and T-369 (SGR crash) which touch the same area.

Acceptance: each of the five items has a test that fails on the old behavior and passes after; mouse test corrected, not deleted.', NULL, '2026-06-11 21:59:05', '2026-06-11 21:59:05', '2026-06-11 21:59:05', NULL, 'c47893702c6e206fb78da5e04c8ffdbe', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHCJEYHC91PMVNVWVHBR2RG', 'description', NULL, 'lib/widgets/src/clide_markdown.dart:408-410 — hard line breaks and image nodes both fall through to empty text spans: words on either side of a hard break glue together, and images vanish entirely (no placeholder, no alt text).

Fix: emit a newline span for hard breaks; render images as at least an alt-text placeholder chip (full image rendering can be a follow-up — note the existing feedback that live-pane images go through clide image show).

Acceptance: golden/widget test for hard-break line splitting; image node renders alt text; no regression in existing markdown goldens.', NULL, '2026-06-11 21:59:20', '2026-06-11 21:59:20', '2026-06-11 21:59:20', NULL, 'a839cd055a09b586f3693fabed212aa4', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHCM1RBAF72SCZBKRTXJSYC', 'description', NULL, 'Three compounding costs on every streamed token:

1. The whole markdown document re-parses inside build on each streaming delta, including sync existsSync() calls in the parse path (clide_markdown.dart) — sync I/O on the UI isolate per frame.
2. The conversation view re-derives its full item list O(n) on every controller notification.
3. Token streaming re-encodes the full reply text per delta (lib/builtin/claude/src/stream_json_session.dart:410-431) — O(n²) churn over a long reply.

Fix directions: cache parsed markdown per card keyed by content hash and only re-parse the tail/dirty card; move file-existence link checks off the build path (async + cache); make the session accumulate deltas in a StringBuffer instead of string concat re-encode; derive conversation items incrementally. Profile before/after with a long synthetic reply.

Acceptance: a 1000-delta synthetic stream does no existsSync in build (assert via injected fs seam or profiling harness), and per-delta work is bounded (no full-document re-parse); existing rendering tests green.', NULL, '2026-06-11 21:59:37', '2026-06-11 21:59:37', '2026-06-11 21:59:37', NULL, '2ad44f254878d377bb9b54512a5e4947', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHCP03EJ9CDBGZGRPD19N8W', 'description', NULL, 'lib/builtin/terminal/src/terminal_pane.dart:69 — the shell spawns with Directory.current as cwd. Launched from a desktop entry, that is $HOME, not the open workspace; after a project switch it is whatever the process started in. SpawnSpec.cwd already exists in the PTY layer.

Fix: pass the active workspace root as the spawn cwd (and re-derive it on project switch for new panes).

Acceptance: test that a terminal pane''s SpawnSpec.cwd equals the workspace root, not Directory.current.', NULL, '2026-06-11 21:59:50', '2026-06-11 21:59:50', '2026-06-11 21:59:50', NULL, '87e1c5e8220dd5fa5eb9d7b44335ed6a', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHCQHZQ0NKY1VRWWPSNZT84', 'description', NULL, 'lib/kernel/src/notify.dart has zero widget consumers — anything pushed through the Notifications service (e.g. cli_install''s dogfood warnings) accumulates in a list no surface renders. ToastService exists right next to it and does render.

Fix options (pick one, note it on this ticket): (a) route notify-level messages through ToastService with severity styling; (b) add a notifications tray/indicator surface; (c) delete the service and migrate callers to toasts. Option (a) or (c) is likely right for current scale — avoid building a tray nobody asked for.

Acceptance: a notification posted by cli_install is visibly surfaced in the UI (test via whichever surface is chosen); no silent sink remains.', NULL, '2026-06-11 22:00:05', '2026-06-11 22:00:05', '2026-06-11 22:00:05', NULL, 'b97d86a5de4f9b7435f678fb44bcb25b', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHCST6CQ449VJGAP6C5KZ5W', 'description', NULL, 'lib/builtin/welcome/src/welcome_view.dart:173-174 — the Clone-from-git and Start-a-Claude-session tiles are inert on tap, and the keyboard shortcuts printed on the tiles are not registered anywhere. First-run users hit dead UI on the first screen.

Fix: either wire the tiles (clone flow; open a Claude pane) and register the shortcuts through the keymap subsystem, or remove the tiles until the flows exist — no advertised dead ends. Note: the welcome screen also duplicates FileActions'' open-folder flow verbatim; the dedup is covered by the copy-paste sweep ticket under this epic, but if you touch this file, prefer calling into FileActions.

Acceptance: every tile on the welcome screen performs its action (widget test taps each); every shortcut shown is registered in the keymap.', NULL, '2026-06-11 22:00:22', '2026-06-11 22:00:22', '2026-06-11 22:00:22', NULL, 'e968c74a8637487134343841ae96ddfa', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHCVPGCKEGDC54KKQ120SRM', 'description', NULL, 'tools/ui/*.sh still cd into the removed app/ directory, so make test-e2e, make ui-dev, and make ui-smoke fail immediately. The staged Gitea CI workflow would fail in three independent ways the day it is activated, while D-32 describes it as ready.

Fix: repoint the scripts at the repo root (post app/-flattening layout), run each target to prove it, and walk the Gitea workflow steps locally (or in a dry-run) until each step is green or consciously removed. Amend D-32 if the CI story changed.

Acceptance: all three make targets run; the workflow file''s steps each map to a working make target; D-32 matches reality.', NULL, '2026-06-11 22:00:37', '2026-06-11 22:00:37', '2026-06-11 22:00:37', NULL, '89d8eb48c066c985f1fb44270b0a95da', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHCXFF5V1RT6QJETS2K4C0G', 'description', NULL, 'Verified-dead code worth one sweep (coverage denominator benefits too):

- Legacy free-function git API (~250 LOC duplicating GitClient, kept alive only by its own tests, and carrying its own latent pipe-deadlock bug) — delete API + tests.
- ToolCheck — zero callers.
- ~60% of lib/src/pty/ffi/libc.dart — fd-passing-era bindings unused since D-56.
- GraphView — unreachable placeholder (note: the Governance Graph idea (see Q-records from this review) may later want the slot; deleting now is still right, it is a 17-line stub).
- ColumnHat — duplicated line-for-line in app.dart, kept alive by a zero-coverage test; the app.dart split ticket removes the duplicate, this sweep removes the orphan.
- tmux-era team pipeline: TranscriptPublisher, TeamMemberJoined — nothing emits these events, yet the team roster UI listens to them exclusively (team tiles are populated by ghosts). Remove pipeline + dead listeners; if the roster UI stays, it needs a real data source first (surface that before deleting the UI).
- Dead ptyc binary still committed in native/linux-x64/ against D-62/D-63 — remove binary + licenses.yaml entry if present.
- mocktail — pinned, documented in D-25 as the IO-mocking strategy, imported by zero files: either adopt it where mocks are hand-rolled or drop the dep AND amend D-25.

Each bullet is one commit. Run make test + coverage after each; expect the floor to ratchet up.', NULL, '2026-06-11 22:01:02', '2026-06-11 22:01:02', '2026-06-11 22:01:02', NULL, 'eda1bd3f4f7db6bfe206a1c0c39e8dae', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHD098CV2N73823KX4Z99P4', 'description', NULL, 'Broadcast streams that carry STATE (not events) drop the current value for late subscribers. This one shape caused T-274 (status bar blank — root cause appended there), the meta sidebar''s manual compensation, and the prompt-stream''s initialData workaround.

Fix: write one small ValueStream<T> wrapper (a broadcast stream that replays the latest value to each new subscriber, plus a .value getter) in the kernel; retrofit statusStream, busyStream, and pendingPromptStream in the claude builtin; delete the per-site workarounds it obsoletes. No third-party dep (rxdart) — prefer-zero-deps; the wrapper is ~30 LOC.

Acceptance: unit tests for the wrapper (late subscriber gets latest value; no value yet = no synthetic emit unless seeded); T-274 repro covered: subscribing after the init event still yields the status. Closing this should make T-274 fixable in one line at the call site.', NULL, '2026-06-11 22:01:18', '2026-06-11 22:01:18', '2026-06-11 22:01:18', NULL, '8d7c4939861881d0de4c984be2df9b7c', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHD2FWTDFYA00W4QXTE41M0', 'description', NULL, 'The silent-swallow idiom turned an illegal-lookup-in-dispose into two resource leaks (T-366) and turned process-spawn failures into blank panes. Rule to apply: cleanup/teardown paths MAY swallow (with a comment saying why); spawn, read, and dispose-adjacent paths MUST log through the kernel Logger they already have access to.

Work: grep the tree for `catch (_)` and empty catch bodies; classify each site (cleanup vs load-bearing); add logging or rethrow on the load-bearing ones; leave a one-line justification comment on the legitimate swallows. Consider an analysis_options lint (avoid_catches_without_on_clauses or a custom assist) only if it can be enabled without suppressions — per repo policy no lint suppressions without approval.

Acceptance: zero unjustified empty catches on spawn/read/dispose paths; each remaining swallow carries a why-comment; any new logging visible in the kernel log during testmode.', NULL, '2026-06-11 22:01:37', '2026-06-11 22:01:37', '2026-06-11 22:01:37', NULL, 'bac36bc044fb209147b1c3d13c59b1d5', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHD4QYHYRTK0SGRZCBSHSQ0', 'description', NULL, 'The single-isolate app does sync I/O inside async IPC handlers: files.read does a sync 10MB read; the replace engine reads and rewrites workspace files synchronously — while grep right next to it fans out to isolates per D-79. There is no recorded rule, so each new handler guesses.

Work: claim a D-record (pql decisions claim D architecture "sync I/O policy in IPC handlers") deciding the rule — suggested: async File APIs by default in handlers; offload to an isolate above N KB (align N with the D-79 grep design); sync allowed only in pure-Dart test seams. Then apply it to files.read and replace_engine, citing the new D-NNN at each site.

Acceptance: D-record confirmed; files.read and search.replace no longer block the UI isolate on large files (test with a multi-MB fixture asserting the event loop stays responsive, e.g. a timer keeps firing).', NULL, '2026-06-11 22:01:52', '2026-06-11 22:01:52', '2026-06-11 22:01:52', NULL, 'da3256b09a0299b9a127cb80478f6af0', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHD6FQMXMQQQ877KMNCK6QC', 'description', NULL, 'Per-verb path confinement is a lottery: files.read remembered, search.replace half-remembered, editor.open/save forgot (T-363). The dispatcher registry (D-74) already co-registers a schema with every handler and the schema already knows which params are paths.

Fix: add a path-type marker to the schema layer (or derive from a naming convention recorded in the D-record amendment) and run path_safety confinement once in the dispatcher before the handler sees the request. Per-verb checks become defense-in-depth or get deleted.

Do after T-363 lands its point fix — this is the structural follow-up that prevents the next forgotten verb. Amend D-74 with the confinement rule.

Acceptance: a registered verb with a path param automatically rejects traversal/escape without any handler code; a regression test registers a synthetic verb and proves confinement applies; existing verbs unchanged behavior for in-workspace paths.', NULL, '2026-06-11 22:02:08', '2026-06-11 22:02:08', '2026-06-11 22:02:08', NULL, '41a21f3eaedab8c7455484862d7f5247', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHD8F2NBEFZNPKSJ9W253J0', 'description', NULL, 'Verified duplication clusters, each small, together the repo''s main rot vector:

- Welcome screen clones FileActions'' entire open-folder flow verbatim — call FileActions instead (coordinate with T-383).
- Command palette and quick-open are ~230-line near-twins — extract the shared list-overlay+filter core.
- Three private tail-a-growing-file implementations in the claude builtin alone — one shared follower (coordinate with T-373, which gives it the chunked decoder).
- Five hand-rolled _userErr helpers across handlers — one shared error-shaping helper.
- Five copy-pasted git test sandboxes, none isolating host git config (set GIT_CONFIG_GLOBAL/HOME in the shared fixture — flaky-test risk today).
- Two parallel ANSI flag enums that already drifted: strikethrough is stored but never painted — unify, then paint strikethrough.

One commit per cluster. Acceptance: each cluster has a single implementation with the call sites migrated and a test guarding the shared piece; git sandboxes isolated from host config.', NULL, '2026-06-11 22:02:25', '2026-06-11 22:02:25', '2026-06-11 22:02:25', NULL, '09ac8f7ccc448560db7318cb09d2a9a3', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHDAK04ZA0PBT69ZWNBXPSR', 'description', NULL, '16 handlers in the claude builtin return result: ok with an error field in the payload instead of an error envelope, drifting from the D-6 exit-code contract every other subsystem honors. Scripted example: clide claude.agent.set-permission-mode bogus exits 0 today, so scripts cannot detect failure.

Fix: sweep the claude builtin handlers; on failure return the error envelope (non-zero CLI exit) like the rest of the dispatcher. Audit callers/UI that may currently rely on ok-with-error.

Acceptance: clide claude.agent.set-permission-mode bogus exits non-zero; a table-driven test walks the claude verbs'' failure paths asserting error envelopes; D-6 conformance restored.', NULL, '2026-06-11 22:02:40', '2026-06-11 22:02:40', '2026-06-11 22:02:40', NULL, 'c6b3edd27b9c8d00aad3eee4bd7cc227', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHDC7B2MFQZVR1K9E30FXDR', 'description', NULL, 'CLAUDE.md and README still say "tmux owns Claude session persistence (D-41)" — superseded by D-75/D-77 per docs/architecture.md. README says "Pre-v2.0 (2.0.0-dev)" while pubspec is at v2.3.3, and headlines "canvas and graph surfaces" that are a 17-line stub and a flat ListView respectively (T-7 epic was cancelled).

Fix: rewrite the stale paragraphs in both files to match current architecture (clide-managed stream-json sessions); fix the README version line (or derive it); demote canvas/graph to roadmap wording or drop them. The repo''s honesty is its brand; the README is the one off-brand surface.

Acceptance: no tmux-persistence claim outside historical D-records; README version matches pubspec; every README feature claim maps to shipped behavior.', NULL, '2026-06-11 22:02:54', '2026-06-11 22:02:54', '2026-06-11 22:02:54', NULL, 'afb2a71c491410f5ca5d313d1b9c716b', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHDE5A3965GNRFS5WPZW878', 'description', NULL, 'No git tag since v2.1.0 despite five CHANGELOG releases; ci/release.sh exits 64 and still references the dissolved sidecar; the pre-push fast path''s safety argument cites "release CI on tagged versions" that does not exist; and the fast-path regex skips ALL tests for pushes touching test/, ci/, or the hook itself.

Work items (separable commits):
1. Back-tag v2.2.0 through v2.3.3 at the release-cut commits (find them via the CHANGELOG version-bump commits).
2. Rewrite ci/release.sh for the single-process architecture or delete it and fold release steps into the Makefile — either way, no stub that exits 64.
3. Add tagging to the release ritual in .claude/skills/git-commit/SKILL.md (version bump + changelog move + tag in one documented step).
4. Widen the pre-push fast-path regex so changes under test/, ci/, and the hook itself run the full gate.

This is also the blocking prerequisite the T-47 (self-update) refinement identified. Acceptance: git tag lists every released version; release.sh (or its replacement) runs end-to-end; fast-path regex covered by a hook test if feasible.', NULL, '2026-06-11 22:03:10', '2026-06-11 22:03:10', '2026-06-11 22:03:10', NULL, '50c2e5c64c6a78ac9e785fcd4a0a128d', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHDGPXQN31NNRPJ00PFRAG4', 'description', NULL, 'lib/app.dart is 1187 LOC mixing five confirmed concerns. Split plan (verified against the file 2026-06-12):

Inventory: ClideApp (14-29), _AppRoot (31-45), _RootShell/_RootShellState keyboard+intent routing (47-229), RootLayout (231-350), hat bar family _HatBar/_LeftHatContent/_RightHatContent/_WinBtn (352-439), project switcher family _ProjectSwitcherButton/_ProjectSwitcherDropdown/_RecentProjectRow/_ActionRow (441-672), SlotHost/_SlotHostState/_SlotBody/_SidebarSlot/_WorkspaceSlot/_RevealedTab/_ContextSlot (674-1030), _BottomRail (1032-1078), StatusbarCollapseToggle (1093-1126), StatusbarHost (1128-1170), _EditorDragHandle (924-1010), _WelcomeOverlay (1172-1187).

Target layout:
- app.dart keeps ClideApp + _AppRoot and RE-EXPORTS the public symbols so tests keep importing package:clide/app.dart.
- lib/widgets/root_shell.dart: _RootShell/_RootShellState (keyboard routing; depends on ModifierTapTracker, MenuBarController).
- lib/builtin/hat/hat_bar.dart: _HatBar, _LeftHatContent, _RightHatContent, _WinBtn, hatHeight.
- lib/builtin/hat/project_switcher.dart: the switcher family (~230 LOC).
- lib/widgets/slot_host.dart: SlotHost + slot bodies (NOTE: _RevealedTab references _SlotBody._resolveTitle — keep them together or extract the helper).
- lib/widgets/layout_status.dart: RootLayout internals, StatusbarHost, StatusbarCollapseToggle, _BottomRail, _EditorDragHandle(+Intent), _WelcomeOverlay.

Order: mechanical first (hat bar, switcher rows, welcome overlay), then root shell, then slot host (tangled: _SlotHostState registers focus scopes via ClideKernel.of in didChangeDependencies), then layout/status.

Tests importing app.dart: test/app_test.dart (RootLayout, StatusbarHost, ClideApp), test/app_statusbar_test.dart (StatusbarHost), test/app_collapse_toggle_test.dart (StatusbarCollapseToggle) — re-exports keep them unchanged.

CORRECTION to fable-ous.md: ColumnHat is NOT duplicated line-for-line in app.dart (verified); ColumnHat lives only in lib/widgets/src/clide_column_hat.dart. The rat-sweep ticket T-385 was annotated accordingly — verify whether ColumnHat is dead before deleting.', NULL, '2026-06-11 22:09:19', '2026-06-11 22:09:19', '2026-06-11 22:09:19', NULL, '4e73e28db0c7d196d2e6fec455c87a1a', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHCXFF5V1RT6QJETS2K4C0G', 'description', 'Verified-dead code worth one sweep (coverage denominator benefits too):

- Legacy free-function git API (~250 LOC duplicating GitClient, kept alive only by its own tests, and carrying its own latent pipe-deadlock bug) — delete API + tests.
- ToolCheck — zero callers.
- ~60% of lib/src/pty/ffi/libc.dart — fd-passing-era bindings unused since D-56.
- GraphView — unreachable placeholder (note: the Governance Graph idea (see Q-records from this review) may later want the slot; deleting now is still right, it is a 17-line stub).
- ColumnHat — duplicated line-for-line in app.dart, kept alive by a zero-coverage test; the app.dart split ticket removes the duplicate, this sweep removes the orphan.
- tmux-era team pipeline: TranscriptPublisher, TeamMemberJoined — nothing emits these events, yet the team roster UI listens to them exclusively (team tiles are populated by ghosts). Remove pipeline + dead listeners; if the roster UI stays, it needs a real data source first (surface that before deleting the UI).
- Dead ptyc binary still committed in native/linux-x64/ against D-62/D-63 — remove binary + licenses.yaml entry if present.
- mocktail — pinned, documented in D-25 as the IO-mocking strategy, imported by zero files: either adopt it where mocks are hand-rolled or drop the dep AND amend D-25.

Each bullet is one commit. Run make test + coverage after each; expect the floor to ratchet up.', 'Verified-dead code worth one sweep (coverage denominator benefits too):

- Legacy free-function git API (~250 LOC duplicating GitClient, kept alive only by its own tests, and carrying its own latent pipe-deadlock bug) — delete API + tests.
- ToolCheck — zero callers.
- ~60% of lib/src/pty/ffi/libc.dart — fd-passing-era bindings unused since D-56.
- GraphView — unreachable placeholder (note: the Governance Graph idea (see Q-records from this review) may later want the slot; deleting now is still right, it is a 17-line stub).
- ColumnHat — duplicated line-for-line in app.dart, kept alive by a zero-coverage test; the app.dart split ticket removes the duplicate, this sweep removes the orphan.
- tmux-era team pipeline: TranscriptPublisher, TeamMemberJoined — nothing emits these events, yet the team roster UI listens to them exclusively (team tiles are populated by ghosts). Remove pipeline + dead listeners; if the roster UI stays, it needs a real data source first (surface that before deleting the UI).
- Dead ptyc binary still committed in native/linux-x64/ against D-62/D-63 — remove binary + licenses.yaml entry if present.
- mocktail — pinned, documented in D-25 as the IO-mocking strategy, imported by zero files: either adopt it where mocks are hand-rolled or drop the dep AND amend D-25.

Each bullet is one commit. Run make test + coverage after each; expect the floor to ratchet up.

Correction (2026-06-12, verified during T-394 breakdown): ColumnHat is NOT duplicated line-for-line in app.dart — it exists only in lib/widgets/src/clide_column_hat.dart. Before deleting it, verify it actually has zero non-test callers; if it is genuinely used by app chrome, drop that bullet from this sweep.', NULL, '2026-06-11 22:09:30', '2026-06-11 22:09:30', '2026-06-11 22:09:30', NULL, '96c700c252728e81f7477b0f18e68192', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHDH8TE9MJBXZ4GQ5YT10JM', 'description', NULL, 'lib/builtin/claude/src/claude_meta_sidebar.dart is 1192 LOC. Split plan (verified against the file 2026-06-12). Public API (ClaudeMetaSidebar widget + SidebarTab enum) stays in the root file — tests and extension.dart need zero import changes.

Inventory: consts _labelColumnWidth/_rowPitch (43-44), SidebarTab enum (46), ClaudeMetaSidebar (48-79), _ClaudeMetaSidebarState monolith (81-638: lifecycle, stats polling, team membership streams, primary-session binding, broker subscription, config listener, inject state, accordion state, plus the three tab bodies), _ConfigSection/_ConfigPermKind enums (641/644), _MetaSection/_MetaRow models (646-657), _AgentRosterRow(+State) (680-928), _permissionModeBadge + _PermissionModeBadge T-181 (935-1009), _IconButton (1012-1039), _InjectTextField (1043-1070), _TaskRow T-171 (1077-1141), _TabStrip (1145-1192).

Target layout under lib/builtin/claude/src/meta_sidebar/: models.dart (enums + _MetaSection/_MetaRow + layout consts), activity_tab.dart (ActivityTabView ~70 LOC, from _activityBody/_runtimeSection 272-302), team_tab.dart (TeamTabView ~120 LOC, from _teamBody/_taskSection 304-380, props-driven with callbacks), config_tab.dart (ConfigTabView ~200 LOC, from _configBody family 382-597; accordion _expanded state stays in parent, passed as prop+callback), roster_row.dart (_AgentRosterRow ~250 LOC incl. bypass-confirm state), permission_badge.dart (~80), task_row.dart (~70), tab_strip.dart (~55), icon_button.dart + inject_field.dart (~30 each — keep here initially; promote to lib/widgets/ only when a second consumer appears). Root file shrinks to ~150 LOC of lifecycle + event bindings + tab switch.

Execution order (each phase independently green): 1) primitives (icon button, inject field, permission badge, models); 2) stateless tab views (activity, config, tab strip) with prop threading; 3) team tab + roster row (most orchestrator coupling: verify show/hide, mute, inject submit-and-clear, shift-click bypass confirm, fork, close, task reassign cycle, auto-front on TeamMemberJoined at line 158); 4) cleanup of moved methods from the root state.

Tests: test/builtin/claude/claude_meta_sidebar_test.dart imports only the root file and public symbols — no changes needed; no goldens reference the sidebar. Caveat from the rat sweep (T-385): TeamMemberJoined currently has no emitter — coordinate before investing in the team tab plumbing.', NULL, '2026-06-11 22:09:55', '2026-06-11 22:09:55', '2026-06-11 22:09:55', NULL, '02f7234d8c395607fe5aa477e6bf291f', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4RJ9K19P5AX14RHRR', 'description', 'parser.dart is a single 1139-line file containing the full ESC/CSI/OSC/DCS handler tree for the terminal emulator. Functional but unwieldy; the consultant flagged it as ''consider splitting'' in the T-107 review.

Suggested split (sequenced with the T-91 coverage sweep on lib/src/terminal/, so the split doesn''t fight in-flight test work):

- parser.dart — entry point + state machine driver
- esc_handlers.dart — single-char ESC dispatch table + handlers
- csi_handlers.dart — CSI parameter parsing + handlers
- osc_handlers.dart — OSC string handlers (title, colour set, etc.)
- dcs_handlers.dart — DCS/SOS/PM/APC string handlers

Each handler module exports a registrar that the driver wires at construction.

Done when:
- parser.dart < 400 LOC
- All existing parser tests pass without changes
- No new public surface; everything stays library-private

Source: T-107 / consultants.md "Code quality — Findings — [Major]".', 'parser.dart is a single 1139-line file containing the full ESC/CSI/OSC/DCS handler tree for the terminal emulator. Functional but unwieldy; the consultant flagged it as ''consider splitting'' in the T-107 review.

Suggested split (sequenced with the T-91 coverage sweep on lib/src/terminal/, so the split doesn''t fight in-flight test work):

- parser.dart — entry point + state machine driver
- esc_handlers.dart — single-char ESC dispatch table + handlers
- csi_handlers.dart — CSI parameter parsing + handlers
- osc_handlers.dart — OSC string handlers (title, colour set, etc.)
- dcs_handlers.dart — DCS/SOS/PM/APC string handlers

Each handler module exports a registrar that the driver wires at construction.

Done when:
- parser.dart < 400 LOC
- All existing parser tests pass without changes
- No new public surface; everything stays library-private

Source: T-107 / consultants.md "Code quality — Findings — [Major]".

Split breakdown from the 2026-06-11 Fable review (epic T-359), verified against the file 2026-06-12:

Structure today: main parser + routing (11-116), CSI core _escHandleCSI (196-209) + _consumeCsi (217-272), _csiHandlers table of 27 final bytes (274-304), cursor movement handlers (306-807), erase/scroll/line/char ops (809-945), SGR monolith (411-622, 212 LOC), mode set/reset (395-409, 946-1030), DA/DSR (334-343, 624-635), window manipulation (658-712), OSC (1034-1110), _Csi state object (1113-1131 — note the commented-out `intermediates` field at 1117/1125).

Target layout under escape/: parser.dart keeps EscapeParser (queue, tokenization, top-level dispatch, ~400 LOC); csi_parser.dart (CsiSequence value object — prefix, params, RESTORED intermediates, finalByte — plus the consume logic from _consumeCsi); csi_handlers.dart (dispatch table, now keyed on final byte + intermediates); cursor_handlers.dart; sgr_handler.dart (the 411-622 monolith); mode_handler.dart; osc_parser.dart + osc_handlers.dart. EscapeHandler interface unchanged. Preserve the zero-allocation/reset-able design goal noted at lines 14-16.

Bug this split must fix (verified): _consumeCsi DISCARDS intermediate bytes — lines 258-261 have `// intermediates.add(char);` commented out and `continue`, so CSI Ps SP q (DECSCUSR, cursor style) and CSI ! p / SP-intermediate forms dispatch on the bare final byte and fall to unknownCSI. Fix: restore the intermediates field on CsiSequence, capture them during consume, dispatch on (intermediates, finalByte), and add EscapeHandler.setCursorStyle for DECSCUSR. (DECSTR is CSI ! p — soft terminal reset — same intermediate mechanism.)

Related bug with its own ticket (T-369): unguarded params[i+1] lookahead in SGR 38/48 at lines ~502/512/547/557 (RangeError on truncated sequences) + colon-form sub-parameters unhandled. The split makes the fix natural: sgr_handler.dart owns guarded lookahead helpers; if T-369 lands first, carry its tests over; if this lands first, fix it inside sgr_handler.dart and close T-369 with it.

Tests: test/terminal/escape/parser_test.dart (786 LOC) splits along the same seams — keep parser_test.dart for top-level dispatch/SBC/rollback, add csi_parser_test.dart (intermediates capture, DECSCUSR), sgr_handler_test.dart (bounds + colon form + 256/RGB), mode_handler_test.dart, osc_parser_test.dart, window/DA splits as convenient. The _RecordingHandler fixture is reusable across all of them.', NULL, '2026-06-11 22:10:19', '2026-06-11 22:10:19', '2026-06-11 22:10:19', NULL, '2942deccaff5b534ac3e33ac23b4d9fa', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHBJ5T7HAQ9CA8XQMX43A2C', 'status', 'backlog', 'in_progress', NULL, '2026-06-11 22:14:48', '2026-06-11 22:14:48', '2026-06-11 22:14:48', NULL, '6f607da089f1326c07f4c17a6153c014', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHBJ5T7HAQ9CA8XQMX43A2C', 'status', 'in_progress', 'done', NULL, '2026-06-11 22:18:25', '2026-06-11 22:18:25', '2026-06-11 22:18:25', NULL, '307a819cf82cf2ed49b3fd9e192992b6', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHBV0465906BY3QFAY9F1YM', 'status', 'backlog', 'in_progress', NULL, '2026-06-11 22:18:56', '2026-06-11 22:18:56', '2026-06-11 22:18:56', NULL, '6b229d2b93c00f6197b026610c921273', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHBV0465906BY3QFAY9F1YM', 'status', 'in_progress', 'done', NULL, '2026-06-11 22:24:07', '2026-06-11 22:24:07', '2026-06-11 22:24:07', NULL, '6e0986eb4b0c15223d7b373bbbc421cb', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHBYTJ4E7ZBY6DWWNT1S16M', 'status', 'backlog', 'in_progress', NULL, '2026-06-11 22:24:34', '2026-06-11 22:24:34', '2026-06-11 22:24:34', NULL, '151c44c4c697f83900b1cc003c6a94f6', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHBYTJ4E7ZBY6DWWNT1S16M', 'status', 'in_progress', 'done', NULL, '2026-06-11 22:26:15', '2026-06-11 22:26:15', '2026-06-11 22:26:15', NULL, '05386705854fd48ee75d7a3dfbfd5bc9', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHC0HYRZ86CWW0DDQJ5CAQM', 'status', 'backlog', 'in_progress', NULL, '2026-06-11 22:26:38', '2026-06-11 22:26:38', '2026-06-11 22:26:38', NULL, '6d14a673d6733b5024726bfc227f6711', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHC0HYRZ86CWW0DDQJ5CAQM', 'status', 'in_progress', 'done', NULL, '2026-06-11 22:30:24', '2026-06-11 22:30:24', '2026-06-11 22:30:24', NULL, 'aa1fe975e147be83905f24c63662254d', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHBSG6356MZJ2DCCCSBMBGM', 'status', 'backlog', 'in_progress', NULL, '2026-06-11 22:30:48', '2026-06-11 22:30:48', '2026-06-11 22:30:48', NULL, '2c5c8e5cdf68c96e25705f014dcd6acc', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHBSG6356MZJ2DCCCSBMBGM', 'status', 'in_progress', 'done', NULL, '2026-06-11 22:32:08', '2026-06-11 22:32:08', '2026-06-11 22:32:08', NULL, 'f3dbb31fb6f6f416a2d4d8ef37723316', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHBR4636GSRJBWFJDAZ6ZA0', 'status', 'backlog', 'in_progress', NULL, '2026-06-11 22:32:29', '2026-06-11 22:32:29', '2026-06-11 22:32:29', NULL, '7b833a606da59ab523e0bb43f1753f6a', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHBR4636GSRJBWFJDAZ6ZA0', 'status', 'in_progress', 'done', NULL, '2026-06-11 22:34:31', '2026-06-11 22:34:31', '2026-06-11 22:34:31', NULL, '254ae09f42b4da439a04d59d675d8f42', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHBPQE4J4YBJX92812ZK6DR', 'status', 'backlog', 'in_progress', NULL, '2026-06-11 22:34:51', '2026-06-11 22:34:51', '2026-06-11 22:34:51', NULL, '14a7d3d6d6c71cae423ce12c71b6c540', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHBPQE4J4YBJX92812ZK6DR', 'status', 'in_progress', 'done', NULL, '2026-06-11 22:39:04', '2026-06-11 22:39:04', '2026-06-11 22:39:04', NULL, 'ad1c483fe26d5e417b2e1cd8986114f3', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHBWE2W1226T58CX37E50HC', 'status', 'backlog', 'in_progress', NULL, '2026-06-11 22:39:32', '2026-06-11 22:39:32', '2026-06-11 22:39:32', NULL, '9983d6ca4c8b8b49724fb5fe42b541cd', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHBWE2W1226T58CX37E50HC', 'status', 'in_progress', 'done', NULL, '2026-06-11 22:44:05', '2026-06-11 22:44:05', '2026-06-11 22:44:05', NULL, '7846c244fccd1cd444f6715ed7472549', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHC2NM7AYKENZ0ZD49HAX1W', 'status', 'backlog', 'in_progress', NULL, '2026-06-11 22:44:30', '2026-06-11 22:44:30', '2026-06-11 22:44:30', NULL, 'f20e68df446500477d6a3c7761e354c3', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHC2NM7AYKENZ0ZD49HAX1W', 'status', 'in_progress', 'done', NULL, '2026-06-11 22:46:46', '2026-06-11 22:46:46', '2026-06-11 22:46:46', NULL, '434ffa25b18e16c5b158c61df6f40bf8', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHBKK2TZQK683J8FS0ZH5A4', 'status', 'backlog', 'in_progress', NULL, '2026-06-11 22:47:12', '2026-06-11 22:47:12', '2026-06-11 22:47:12', NULL, 'e816d6787437a31d3ec34332d069776e', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHBKK2TZQK683J8FS0ZH5A4', 'status', 'in_progress', 'done', NULL, '2026-06-11 22:53:45', '2026-06-11 22:53:45', '2026-06-11 22:53:45', NULL, 'efa0615f1968f8cfebd7b0e26acbdf31', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM6K1QRC911JMQ9C960', 'description', 'Surfaced 2026-06-08 while chasing a --resume hang in the Claude pane (T-274 diagnostic line). The specific corrupted-transcript repro may turn out to be a one-off, but the code trace found two real latent gaps that make a resume hang unrecoverable regardless of root cause.

(a) No timeout / no fallback on the init-event wait.
On spawn the orchestrator listens for the session_id from claude''s init event (StreamJsonSession sessionIdResolved -> session_orchestrator.dart ~257) with NO timeout. If ''claude --resume <id>'' never emits an init event (hangs), the listener never fires: the pane shows ''resumed · <id>'' + running indicator forever, the process is never killed, and there is no fallback to a fresh --session-id spawn. Unrecoverable without killing the process / restarting clide.

(b) Resume is decided by file existence, not resumable content.
claude_pane.dart ~279: ''final resume = await File(transcriptFile).exists();'' — resume=true purely because the .jsonl exists. A metadata-only transcript (only system / permission-mode / attachment records; parseTranscriptChunk().items returns []) yields resume=true with zero seeded items. So clide passes --resume against a functionally empty session, the diagnostic logs ''fresh session (no history)'' (it keys off seeded count, not the resume flag — itself misleading), and if that resume hangs there is no fallback per (a).

Acceptance:
1. If a --resume spawn yields no init event within a short timeout (e.g. 10-30s), fall back to a fresh --session-id spawn (or surface a recoverable error with a retry affordance) — the pane must never spin forever with no recovery.
2. Don''t pass --resume for a transcript that has no resumable conversation items: validate parsed item count (not just file existence) before choosing --resume vs --session-id, and/or detect-and-repair a metadata-only transcript.
3. The T-274 diagnostic log reflects the actual spawn mode (resume vs fresh), not just seeded-item count.
4. Tests: (i) fake process that never emits init -> pane falls back / surfaces error within the timeout; (ii) metadata-only transcript -> spawn chooses fresh, not --resume.

Cross-refs: T-274 (resumed-session status bar empty), T-167/T-185 (resume/fork session id capture), D-77, claude_pane.dart:279/300-308, session_orchestrator.dart:240/257.

UPDATE 2026-06-08: the active hang did NOT reproduce — clide is running fine inside the 31b214bd primary session (this very session resumes cleanly). So the original break was a one-off (likely the single corrupted transcript), not a live resume bug. This ticket stands as defensive hardening only: the two gaps (no init-event timeout/fallback; resume keyed off file-exists not content) are real but latent — they''d only bite again if a resume genuinely stalls or a metadata-only transcript appears. Lowering to low priority.', 'Surfaced 2026-06-08 while chasing a --resume hang in the Claude pane (T-274 diagnostic line). The specific corrupted-transcript repro may turn out to be a one-off, but the code trace found two real latent gaps that make a resume hang unrecoverable regardless of root cause.

(a) No timeout / no fallback on the init-event wait.
On spawn the orchestrator listens for the session_id from claude''s init event (StreamJsonSession sessionIdResolved -> session_orchestrator.dart ~257) with NO timeout. If ''claude --resume <id>'' never emits an init event (hangs), the listener never fires: the pane shows ''resumed · <id>'' + running indicator forever, the process is never killed, and there is no fallback to a fresh --session-id spawn. Unrecoverable without killing the process / restarting clide.

(b) Resume is decided by file existence, not resumable content.
claude_pane.dart ~279: ''final resume = await File(transcriptFile).exists();'' — resume=true purely because the .jsonl exists. A metadata-only transcript (only system / permission-mode / attachment records; parseTranscriptChunk().items returns []) yields resume=true with zero seeded items. So clide passes --resume against a functionally empty session, the diagnostic logs ''fresh session (no history)'' (it keys off seeded count, not the resume flag — itself misleading), and if that resume hangs there is no fallback per (a).

Acceptance:
1. If a --resume spawn yields no init event within a short timeout (e.g. 10-30s), fall back to a fresh --session-id spawn (or surface a recoverable error with a retry affordance) — the pane must never spin forever with no recovery.
2. Don''t pass --resume for a transcript that has no resumable conversation items: validate parsed item count (not just file existence) before choosing --resume vs --session-id, and/or detect-and-repair a metadata-only transcript.
3. The T-274 diagnostic log reflects the actual spawn mode (resume vs fresh), not just seeded-item count.
4. Tests: (i) fake process that never emits init -> pane falls back / surfaces error within the timeout; (ii) metadata-only transcript -> spawn chooses fresh, not --resume.

Cross-refs: T-274 (resumed-session status bar empty), T-167/T-185 (resume/fork session id capture), D-77, claude_pane.dart:279/300-308, session_orchestrator.dart:240/257.

UPDATE 2026-06-08: the active hang did NOT reproduce — clide is running fine inside the 31b214bd primary session (this very session resumes cleanly). So the original break was a one-off (likely the single corrupted transcript), not a live resume bug. This ticket stands as defensive hardening only: the two gaps (no init-event timeout/fallback; resume keyed off file-exists not content) are real but latent — they''d only bite again if a resume genuinely stalls or a metadata-only transcript appears. Lowering to low priority.

T-361 (done, 2026-06-12) added the session-level building blocks this ticket can reuse: StreamJsonSession now watches the process exit code (SessionEnd with stderr tail, replay-latest via session.end) and the pane surfaces ''claude exited (code N) — /clear to restart''. A resume that dies at spawn now surfaces instead of hanging silently; what remains here is the timeout/fallback for a resume that starts but never produces the init event, and resume-decided-by-content.', NULL, '2026-06-11 22:53:52', '2026-06-11 22:53:52', '2026-06-11 22:53:52', NULL, '5a99913696126412ccc7b18f75d3ec15', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHBN5F0F8SDF15P21DNKT1W', 'status', 'backlog', 'in_progress', NULL, '2026-06-11 22:54:18', '2026-06-11 22:54:18', '2026-06-11 22:54:18', NULL, '2cadeabff0a0a89bbcc06db35dfa2f15', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHBN5F0F8SDF15P21DNKT1W', 'status', 'in_progress', 'done', NULL, '2026-06-11 22:57:42', '2026-06-11 22:57:42', '2026-06-11 22:57:42', NULL, 'cb060646e7e967d607dc013a75ec0a28', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHD098CV2N73823KX4Z99P4', 'status', 'backlog', 'in_progress', NULL, '2026-06-11 23:01:24', '2026-06-11 23:01:24', '2026-06-11 23:01:24', NULL, '33ef6141e9af3e6957def829e635b138', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM5W6VN98RQM6S22X28', 'status', 'backlog', 'done', NULL, '2026-06-11 23:04:46', '2026-06-11 23:04:46', '2026-06-11 23:04:46', NULL, '5b0e12802a8f9c0b90f8b08e97f85e29', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHD098CV2N73823KX4Z99P4', 'status', 'in_progress', 'done', NULL, '2026-06-11 23:04:46', '2026-06-11 23:04:46', '2026-06-11 23:04:46', NULL, '5d8d8c7a17da4894510db957e7af3c3f', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHCP03EJ9CDBGZGRPD19N8W', 'status', 'backlog', 'in_progress', NULL, '2026-06-11 23:05:16', '2026-06-11 23:05:16', '2026-06-11 23:05:16', NULL, '252a8c28446f3c86876ec826fce03987', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHCP03EJ9CDBGZGRPD19N8W', 'status', 'in_progress', 'done', NULL, '2026-06-11 23:06:26', '2026-06-11 23:06:26', '2026-06-11 23:06:26', NULL, '4e1cc82f703d717f7592890e230caf00', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHC90B72A270CAKA7AP1ZX8', 'status', 'backlog', 'in_progress', NULL, '2026-06-11 23:07:01', '2026-06-11 23:07:01', '2026-06-11 23:07:01', NULL, '795c139edb5acd0d2a187dac6a3066c7', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHC90B72A270CAKA7AP1ZX8', 'status', 'in_progress', 'done', NULL, '2026-06-11 23:08:13', '2026-06-11 23:08:13', '2026-06-11 23:08:13', NULL, 'f83a2fc13f3839070957bea6ac7fdc5f', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHCAFKK334YNJXZJQG4J6AW', 'status', 'backlog', 'in_progress', NULL, '2026-06-11 23:08:40', '2026-06-11 23:08:40', '2026-06-11 23:08:40', NULL, 'd61ecda5f46b3ad0e15ea566bc83a52c', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHCAFKK334YNJXZJQG4J6AW', 'status', 'in_progress', 'done', NULL, '2026-06-11 23:10:56', '2026-06-11 23:10:56', '2026-06-11 23:10:56', NULL, '4b505b885dc39785651e259370fbc97b', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHC5ZE4EZEGXK8YY8J86CM0', 'status', 'backlog', 'in_progress', NULL, '2026-06-11 23:11:24', '2026-06-11 23:11:24', '2026-06-11 23:11:24', NULL, '4763adf4924a8f8452c393db9ad03868', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHC5ZE4EZEGXK8YY8J86CM0', 'status', 'in_progress', 'done', NULL, '2026-06-11 23:13:18', '2026-06-11 23:13:18', '2026-06-11 23:13:18', NULL, '5382c848b654d1a93daed15a28d652cf', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHCC6AR37VTF4SY8DR99JHC', 'status', 'backlog', 'in_progress', NULL, '2026-06-11 23:13:49', '2026-06-11 23:13:49', '2026-06-11 23:13:49', NULL, '0edb800f29a8851306f7d21fb546d342', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHCC6AR37VTF4SY8DR99JHC', 'status', 'in_progress', 'done', NULL, '2026-06-11 23:16:28', '2026-06-11 23:16:28', '2026-06-11 23:16:28', NULL, '2fe291251d1a4789c8d2b75a2c32396f', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHCJEYHC91PMVNVWVHBR2RG', 'status', 'backlog', 'in_progress', NULL, '2026-06-11 23:16:53', '2026-06-11 23:16:53', '2026-06-11 23:16:53', NULL, 'e6c0cb3a2fce6e257e054f5b3e209814', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHCJEYHC91PMVNVWVHBR2RG', 'status', 'in_progress', 'done', NULL, '2026-06-11 23:18:22', '2026-06-11 23:18:22', '2026-06-11 23:18:22', NULL, '22809d0fac7e1aa116e682c18dae7455', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHCQHZQ0NKY1VRWWPSNZT84', 'status', 'backlog', 'in_progress', NULL, '2026-06-11 23:18:47', '2026-06-11 23:18:47', '2026-06-11 23:18:47', NULL, '2ebff93f1c7328538d0075a2a5c34cca', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHCQHZQ0NKY1VRWWPSNZT84', 'status', 'in_progress', 'done', NULL, '2026-06-11 23:20:52', '2026-06-11 23:20:52', '2026-06-11 23:20:52', NULL, '6a025da791052ffa97803f6ce8afa2f1', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHCQHZQ0NKY1VRWWPSNZT84', 'description', 'lib/kernel/src/notify.dart has zero widget consumers — anything pushed through the Notifications service (e.g. cli_install''s dogfood warnings) accumulates in a list no surface renders. ToastService exists right next to it and does render.

Fix options (pick one, note it on this ticket): (a) route notify-level messages through ToastService with severity styling; (b) add a notifications tray/indicator surface; (c) delete the service and migrate callers to toasts. Option (a) or (c) is likely right for current scale — avoid building a tray nobody asked for.

Acceptance: a notification posted by cli_install is visibly surfaced in the UI (test via whichever surface is chosen); no silent sink remains.', 'lib/kernel/src/notify.dart has zero widget consumers — anything pushed through the Notifications service (e.g. cli_install''s dogfood warnings) accumulates in a list no surface renders. ToastService exists right next to it and does render.

Fix options (pick one, note it on this ticket): (a) route notify-level messages through ToastService with severity styling; (b) add a notifications tray/indicator surface; (c) delete the service and migrate callers to toasts. Option (a) or (c) is likely right for current scale — avoid building a tray nobody asked for.

Acceptance: a notification posted by cli_install is visibly surfaced in the UI (test via whichever surface is chosen); no silent sink remains.

Resolved with option (a): Notifications now takes the kernel MessageBus and publishes every notification to the toast channel (severity-mapped, ''title — message''); the in-memory active list stays for API compatibility. No tray built.', NULL, '2026-06-11 23:20:59', '2026-06-11 23:20:59', '2026-06-11 23:20:59', NULL, 'a34021fbc6ce201bc9e8f5954129b7cd', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHCST6CQ449VJGAP6C5KZ5W', 'status', 'backlog', 'in_progress', NULL, '2026-06-11 23:21:26', '2026-06-11 23:21:26', '2026-06-11 23:21:26', NULL, '6aa2966edf63b21ad22355332371c219', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHCST6CQ449VJGAP6C5KZ5W', 'status', 'in_progress', 'done', NULL, '2026-06-11 23:24:31', '2026-06-11 23:24:31', '2026-06-11 23:24:31', NULL, '8d2499a198a90a09f0fd145c4c6ee9de', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHCST6CQ449VJGAP6C5KZ5W', 'description', 'lib/builtin/welcome/src/welcome_view.dart:173-174 — the Clone-from-git and Start-a-Claude-session tiles are inert on tap, and the keyboard shortcuts printed on the tiles are not registered anywhere. First-run users hit dead UI on the first screen.

Fix: either wire the tiles (clone flow; open a Claude pane) and register the shortcuts through the keymap subsystem, or remove the tiles until the flows exist — no advertised dead ends. Note: the welcome screen also duplicates FileActions'' open-folder flow verbatim; the dedup is covered by the copy-paste sweep ticket under this epic, but if you touch this file, prefer calling into FileActions.

Acceptance: every tile on the welcome screen performs its action (widget test taps each); every shortcut shown is registered in the keymap.', 'lib/builtin/welcome/src/welcome_view.dart:173-174 — the Clone-from-git and Start-a-Claude-session tiles are inert on tap, and the keyboard shortcuts printed on the tiles are not registered anywhere. First-run users hit dead UI on the first screen.

Fix: either wire the tiles (clone flow; open a Claude pane) and register the shortcuts through the keymap subsystem, or remove the tiles until the flows exist — no advertised dead ends. Note: the welcome screen also duplicates FileActions'' open-folder flow verbatim; the dedup is covered by the copy-paste sweep ticket under this epic, but if you touch this file, prefer calling into FileActions.

Acceptance: every tile on the welcome screen performs its action (widget test taps each); every shortcut shown is registered in the keymap.

Resolved by removal, not stub flows: the two inert tiles are gone (each returns with its real flow — clone is honorable-mention territory in Q-49), the Open-folder shortcut glyph now matches the actual ctrl+o binding, and the tips card was corrected to six bindings that actually exist (quick open, palette, sidebar/context collapse, find-in-files, focus mode — the old card advertised four bindings that were never registered).', NULL, '2026-06-11 23:24:39', '2026-06-11 23:24:39', '2026-06-11 23:24:39', NULL, '53b1878fe9fd9c383d11bade928e811d', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHDAK04ZA0PBT69ZWNBXPSR', 'status', 'backlog', 'in_progress', NULL, '2026-06-11 23:25:05', '2026-06-11 23:25:05', '2026-06-11 23:25:05', NULL, '9da97fcbea83b39c381d63cb06ea7b50', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHDAK04ZA0PBT69ZWNBXPSR', 'status', 'in_progress', 'done', NULL, '2026-06-11 23:28:30', '2026-06-11 23:28:30', '2026-06-11 23:28:30', NULL, 'bd49ff4ff2fa7892ab5b667e46236300', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHC7KDFW07S8WTCC3MD71J0', 'status', 'backlog', 'in_progress', NULL, '2026-06-11 23:28:58', '2026-06-11 23:28:58', '2026-06-11 23:28:58', NULL, 'baf6395b93ca8eea9fd9044debffd54d', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHC7KDFW07S8WTCC3MD71J0', 'status', 'in_progress', 'done', NULL, '2026-06-11 23:31:55', '2026-06-11 23:31:55', '2026-06-11 23:31:55', NULL, '06da283bf11516ecae7fd4bd326e470a', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHCEC25337J2AXXQNST56Y4', 'status', 'backlog', 'in_progress', NULL, '2026-06-11 23:32:21', '2026-06-11 23:32:21', '2026-06-11 23:32:21', NULL, '4da867943aa4bb0dea8bdc2699b64423', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHCEC25337J2AXXQNST56Y4', 'status', 'in_progress', 'done', NULL, '2026-06-11 23:35:05', '2026-06-11 23:35:05', '2026-06-11 23:35:05', NULL, 'f1f9f574e58d9142946e8f3267a63e55', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHCVPGCKEGDC54KKQ120SRM', 'status', 'backlog', 'in_progress', NULL, '2026-06-11 23:35:29', '2026-06-11 23:35:29', '2026-06-11 23:35:29', NULL, '6999f0d1e163b19d8a93c527359cfb28', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHCVPGCKEGDC54KKQ120SRM', 'description', 'tools/ui/*.sh still cd into the removed app/ directory, so make test-e2e, make ui-dev, and make ui-smoke fail immediately. The staged Gitea CI workflow would fail in three independent ways the day it is activated, while D-32 describes it as ready.

Fix: repoint the scripts at the repo root (post app/-flattening layout), run each target to prove it, and walk the Gitea workflow steps locally (or in a dry-run) until each step is green or consciously removed. Amend D-32 if the CI story changed.

Acceptance: all three make targets run; the workflow file''s steps each map to a working make target; D-32 matches reality.', 'tools/ui/*.sh still cd into the removed app/ directory, so make test-e2e, make ui-dev, and make ui-smoke fail immediately. The staged Gitea CI workflow would fail in three independent ways the day it is activated, while D-32 describes it as ready.

Fix: repoint the scripts at the repo root (post app/-flattening layout), run each target to prove it, and walk the Gitea workflow steps locally (or in a dry-run) until each step is green or consciously removed. Amend D-32 if the CI story changed.

Acceptance: all three make targets run; the workflow file''s steps each map to a working make target; D-32 matches reality.

2026-06-12: mechanical fixes done — tools/ui/build.sh and serve.sh repointed at the repo root (post app/-flattening), and the Gitea workflow rewritten to go through make targets with a real coverage run before the coverage gate (it previously cd''d into the removed app/ in every job AND ran coverage_gate with no coverage data). Verified: make ui-dev now reaches the real compiler. Which exposed the deeper break: flutter build web --wasm cannot compile the tree at all — dart:ffi (tree-sitter pivot, native PTY) is unavailable on the wasm target. Whether to fence, park, or drop the web/Playwright surface is a user decision → Q-50 (governance/questions/architecture.md). The workflow''s e2e job is withheld with a pointer to Q-50; make test-e2e/ui-dev/ui-smoke remain blocked on it. Leaving this ticket in review until Q-50 resolves.', NULL, '2026-06-11 23:38:58', '2026-06-11 23:38:58', '2026-06-11 23:38:58', NULL, '5d3c1b5fcdfd2f75a20ddf8cca9cb060', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHCVPGCKEGDC54KKQ120SRM', 'status', 'in_progress', 'review', NULL, '2026-06-11 23:39:03', '2026-06-11 23:39:03', '2026-06-11 23:39:03', NULL, '2be4d4e7daec8409e44c8c51e10cb458', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHCXFF5V1RT6QJETS2K4C0G', 'status', 'backlog', 'in_progress', NULL, '2026-06-12 00:01:13', '2026-06-12 00:01:13', '2026-06-12 00:01:13', NULL, '1924fedc940094f43fc5433cd1af7df5', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBJAXQHCKHS8ZSDZNM9NH7QM', 'description', NULL, 'Split out of the T-385 rat sweep: nothing in production constructs TeamMemberJoined/TeamMemberLeft (verified — only the type definition and tests), yet the team roster surfaces (lib/builtin/claude/src/team_panel_host.dart and the meta sidebar Team tab) populate their member lists EXCLUSIVELY from kernel.events.on<TeamMemberJoined>() — ghost-fed UI. The real membership source exists: TeamBroker (orchestrator.broker, T-170/T-171) tracks members via addMember/removeMember on team spawn/close.

Fix: drive both roster surfaces from TeamBroker membership (expose a listenable roster or change stream on the broker), delete TeamMemberJoined/TeamMemberLeft from kernel events/types.dart, and remove the dead listeners. Coordinate with T-395 (meta sidebar split) — whichever lands second adapts.

Acceptance: spawning a team session through the orchestrator makes the member appear in both surfaces (widget test); the ghost event types are gone from types.dart; no kernel.events team-member subscriptions remain.', NULL, '2026-06-12 00:12:04', '2026-06-12 00:12:04', '2026-06-12 00:12:04', NULL, 'f04b7af4488069d004d99acbf9717cc6', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHCXFF5V1RT6QJETS2K4C0G', 'status', 'in_progress', 'done', NULL, '2026-06-12 00:23:13', '2026-06-12 00:23:13', '2026-06-12 00:23:13', NULL, '8c817e20084503af9ab849d4974eef97', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHCXFF5V1RT6QJETS2K4C0G', 'description', 'Verified-dead code worth one sweep (coverage denominator benefits too):

- Legacy free-function git API (~250 LOC duplicating GitClient, kept alive only by its own tests, and carrying its own latent pipe-deadlock bug) — delete API + tests.
- ToolCheck — zero callers.
- ~60% of lib/src/pty/ffi/libc.dart — fd-passing-era bindings unused since D-56.
- GraphView — unreachable placeholder (note: the Governance Graph idea (see Q-records from this review) may later want the slot; deleting now is still right, it is a 17-line stub).
- ColumnHat — duplicated line-for-line in app.dart, kept alive by a zero-coverage test; the app.dart split ticket removes the duplicate, this sweep removes the orphan.
- tmux-era team pipeline: TranscriptPublisher, TeamMemberJoined — nothing emits these events, yet the team roster UI listens to them exclusively (team tiles are populated by ghosts). Remove pipeline + dead listeners; if the roster UI stays, it needs a real data source first (surface that before deleting the UI).
- Dead ptyc binary still committed in native/linux-x64/ against D-62/D-63 — remove binary + licenses.yaml entry if present.
- mocktail — pinned, documented in D-25 as the IO-mocking strategy, imported by zero files: either adopt it where mocks are hand-rolled or drop the dep AND amend D-25.

Each bullet is one commit. Run make test + coverage after each; expect the floor to ratchet up.

Correction (2026-06-12, verified during T-394 breakdown): ColumnHat is NOT duplicated line-for-line in app.dart — it exists only in lib/widgets/src/clide_column_hat.dart. Before deleting it, verify it actually has zero non-test callers; if it is genuinely used by app chrome, drop that bullet from this sweep.', 'Verified-dead code worth one sweep (coverage denominator benefits too):

- Legacy free-function git API (~250 LOC duplicating GitClient, kept alive only by its own tests, and carrying its own latent pipe-deadlock bug) — delete API + tests.
- ToolCheck — zero callers.
- ~60% of lib/src/pty/ffi/libc.dart — fd-passing-era bindings unused since D-56.
- GraphView — unreachable placeholder (note: the Governance Graph idea (see Q-records from this review) may later want the slot; deleting now is still right, it is a 17-line stub).
- ColumnHat — duplicated line-for-line in app.dart, kept alive by a zero-coverage test; the app.dart split ticket removes the duplicate, this sweep removes the orphan.
- tmux-era team pipeline: TranscriptPublisher, TeamMemberJoined — nothing emits these events, yet the team roster UI listens to them exclusively (team tiles are populated by ghosts). Remove pipeline + dead listeners; if the roster UI stays, it needs a real data source first (surface that before deleting the UI).
- Dead ptyc binary still committed in native/linux-x64/ against D-62/D-63 — remove binary + licenses.yaml entry if present.
- mocktail — pinned, documented in D-25 as the IO-mocking strategy, imported by zero files: either adopt it where mocks are hand-rolled or drop the dep AND amend D-25.

Each bullet is one commit. Run make test + coverage after each; expect the floor to ratchet up.

Correction (2026-06-12, verified during T-394 breakdown): ColumnHat is NOT duplicated line-for-line in app.dart — it exists only in lib/widgets/src/clide_column_hat.dart. Before deleting it, verify it actually has zero non-test callers; if it is genuinely used by app chrome, drop that bullet from this sweep.

Done 2026-06-12 across six commits. Notes: ColumnHat''s file carried the LIVE hatHeight constant (app hat bar + menu bar) — moved to widgets/src/chrome_metrics.dart before deleting the dead widget. TranscriptPublisher class removed; the ClaudeConversation addressing constants stay (still consumed). The TeamMemberJoined ghost-event rewiring is real work, split out as T-396. mocktail dropped with D-25 amended (hand-rolled fakes throughout). ptyc binary untracked+deleted (no licenses.yaml entry existed). Coverage rose 95.03% → 95.13% with the dead denominator gone; full push-check green.', NULL, '2026-06-12 00:23:24', '2026-06-12 00:23:24', '2026-06-12 00:23:24', NULL, '0791573d68f344d3edab4cd8b89d2d69', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHDGPXQN31NNRPJ00PFRAG4', 'status', 'backlog', 'in_progress', NULL, '2026-06-12 00:23:56', '2026-06-12 00:23:56', '2026-06-12 00:23:56', NULL, 'e2cf08e3a17b8f8ad8288061d263744c', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHDGPXQN31NNRPJ00PFRAG4', 'status', 'in_progress', 'done', NULL, '2026-06-12 00:29:57', '2026-06-12 00:29:57', '2026-06-12 00:29:57', NULL, 'f7a67bd27641e35f6cf1955fe78d41a6', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHDGPXQN31NNRPJ00PFRAG4', 'description', 'lib/app.dart is 1187 LOC mixing five confirmed concerns. Split plan (verified against the file 2026-06-12):

Inventory: ClideApp (14-29), _AppRoot (31-45), _RootShell/_RootShellState keyboard+intent routing (47-229), RootLayout (231-350), hat bar family _HatBar/_LeftHatContent/_RightHatContent/_WinBtn (352-439), project switcher family _ProjectSwitcherButton/_ProjectSwitcherDropdown/_RecentProjectRow/_ActionRow (441-672), SlotHost/_SlotHostState/_SlotBody/_SidebarSlot/_WorkspaceSlot/_RevealedTab/_ContextSlot (674-1030), _BottomRail (1032-1078), StatusbarCollapseToggle (1093-1126), StatusbarHost (1128-1170), _EditorDragHandle (924-1010), _WelcomeOverlay (1172-1187).

Target layout:
- app.dart keeps ClideApp + _AppRoot and RE-EXPORTS the public symbols so tests keep importing package:clide/app.dart.
- lib/widgets/root_shell.dart: _RootShell/_RootShellState (keyboard routing; depends on ModifierTapTracker, MenuBarController).
- lib/builtin/hat/hat_bar.dart: _HatBar, _LeftHatContent, _RightHatContent, _WinBtn, hatHeight.
- lib/builtin/hat/project_switcher.dart: the switcher family (~230 LOC).
- lib/widgets/slot_host.dart: SlotHost + slot bodies (NOTE: _RevealedTab references _SlotBody._resolveTitle — keep them together or extract the helper).
- lib/widgets/layout_status.dart: RootLayout internals, StatusbarHost, StatusbarCollapseToggle, _BottomRail, _EditorDragHandle(+Intent), _WelcomeOverlay.

Order: mechanical first (hat bar, switcher rows, welcome overlay), then root shell, then slot host (tangled: _SlotHostState registers focus scopes via ClideKernel.of in didChangeDependencies), then layout/status.

Tests importing app.dart: test/app_test.dart (RootLayout, StatusbarHost, ClideApp), test/app_statusbar_test.dart (StatusbarHost), test/app_collapse_toggle_test.dart (StatusbarCollapseToggle) — re-exports keep them unchanged.

CORRECTION to fable-ous.md: ColumnHat is NOT duplicated line-for-line in app.dart (verified); ColumnHat lives only in lib/widgets/src/clide_column_hat.dart. The rat-sweep ticket T-385 was annotated accordingly — verify whether ColumnHat is dead before deleting.', 'lib/app.dart is 1187 LOC mixing five confirmed concerns. Split plan (verified against the file 2026-06-12):

Inventory: ClideApp (14-29), _AppRoot (31-45), _RootShell/_RootShellState keyboard+intent routing (47-229), RootLayout (231-350), hat bar family _HatBar/_LeftHatContent/_RightHatContent/_WinBtn (352-439), project switcher family _ProjectSwitcherButton/_ProjectSwitcherDropdown/_RecentProjectRow/_ActionRow (441-672), SlotHost/_SlotHostState/_SlotBody/_SidebarSlot/_WorkspaceSlot/_RevealedTab/_ContextSlot (674-1030), _BottomRail (1032-1078), StatusbarCollapseToggle (1093-1126), StatusbarHost (1128-1170), _EditorDragHandle (924-1010), _WelcomeOverlay (1172-1187).

Target layout:
- app.dart keeps ClideApp + _AppRoot and RE-EXPORTS the public symbols so tests keep importing package:clide/app.dart.
- lib/widgets/root_shell.dart: _RootShell/_RootShellState (keyboard routing; depends on ModifierTapTracker, MenuBarController).
- lib/builtin/hat/hat_bar.dart: _HatBar, _LeftHatContent, _RightHatContent, _WinBtn, hatHeight.
- lib/builtin/hat/project_switcher.dart: the switcher family (~230 LOC).
- lib/widgets/slot_host.dart: SlotHost + slot bodies (NOTE: _RevealedTab references _SlotBody._resolveTitle — keep them together or extract the helper).
- lib/widgets/layout_status.dart: RootLayout internals, StatusbarHost, StatusbarCollapseToggle, _BottomRail, _EditorDragHandle(+Intent), _WelcomeOverlay.

Order: mechanical first (hat bar, switcher rows, welcome overlay), then root shell, then slot host (tangled: _SlotHostState registers focus scopes via ClideKernel.of in didChangeDependencies), then layout/status.

Tests importing app.dart: test/app_test.dart (RootLayout, StatusbarHost, ClideApp), test/app_statusbar_test.dart (StatusbarHost), test/app_collapse_toggle_test.dart (StatusbarCollapseToggle) — re-exports keep them unchanged.

CORRECTION to fable-ous.md: ColumnHat is NOT duplicated line-for-line in app.dart (verified); ColumnHat lives only in lib/widgets/src/clide_column_hat.dart. The rat-sweep ticket T-385 was annotated accordingly — verify whether ColumnHat is dead before deleting.

Done 2026-06-12. One deviation from the plan: the shell pieces went to lib/src/shell/ rather than lib/widgets/ + lib/builtin/hat/ — SlotHost/RootLayout know kernel + contribution types (not widget primitives), and the hat bar isn''t extension-shaped (no contributions), so neither home fit. app.dart kept the planned re-exports; zero test edits needed.', NULL, '2026-06-12 00:30:11', '2026-06-12 00:30:11', '2026-06-12 00:30:11', NULL, '871c3a1d4c3545dfa41bdafa3a39aaa8', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHDH8TE9MJBXZ4GQ5YT10JM', 'status', 'backlog', 'in_progress', NULL, '2026-06-12 00:30:17', '2026-06-12 00:30:17', '2026-06-12 00:30:17', NULL, '95cd4a80d4e61af091427c6d20bf701a', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBHDH8TE9MJBXZ4GQ5YT10JM', 'status', 'in_progress', 'done', NULL, '2026-06-12 00:39:04', '2026-06-12 00:39:04', '2026-06-12 00:39:04', NULL, '9354054c9dee37482c76674a331ebc26', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4RJ9K19P5AX14RHRR', 'status', 'backlog', 'in_progress', NULL, '2026-06-12 00:39:41', '2026-06-12 00:39:41', '2026-06-12 00:39:41', NULL, 'a5439ee868e2491127308f8028d29417', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM4RJ9K19P5AX14RHRR', 'status', 'in_progress', 'done', NULL, '2026-06-12 00:50:21', '2026-06-12 00:50:21', '2026-06-12 00:50:21', NULL, 'e8f7d648aeab251aa91d4b110d1d5cbc', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBJM6XXQZ3EMGRC13XRYVBEM', 'description', NULL, 'Follow-up to T-123. The escape parser now captures CSI intermediate bytes (0x20-0x2f) on _Csi.intermediates and routes any intermediate-bearing sequence to unknownCSI instead of mis-dispatching on the bare final byte. Nothing implements those forms yet.

Scope: implement DECSCUSR — `CSI Ps SP q` — cursor shape + blink:
- 0/1 blinking block (default), 2 steady block, 3 blinking underline, 4 steady underline, 5 blinking bar, 6 steady bar.

Plan:
1. lib/src/terminal/src/core/escape/handler.dart — add `void setCursorShape(<enum> shape, {required bool blink})` (or an int-style variant matching the existing surface; note resetCursorStyle() there is SGR pen state, NOT cursor shape — pick a name that cannot be confused with it).
2. lib/src/terminal/src/core/escape/csi_handlers.dart — dispatch: in parser.dart _escHandleCSI, intermediate-bearing sequences currently all fall to unknownCSI; add a lookup keyed on (intermediates, finalByte) — a simple `if (_csi.intermediates is [0x20] && finalByte == ''q'')` check is fine until a second form exists.
3. lib/src/terminal/src/core/terminal.dart — implement the handler method: store a cursorStyle field, notify observers.
4. Renderer (lib/src/terminal/src/ui/) — draw underline/bar cursors; today only block is painted. This is the bulk of the work; check TerminalPainter for the cursor paint path.
5. Tests: parser dispatch (test/terminal/escape/parser_test.dart has a _RecordingHandler fixture + an existing ''CSI intermediate bytes (T-123)'' group with a DECSCUSR placeholder test that expects unknownCSI — update it), terminal state, painter golden if shape rendering lands.

DECSTR (`CSI ! p`, soft reset) is a separate, smaller follow-up — same intermediates mechanism, maps to a subset of the existing reset paths; file separately if wanted.

Done when: claude/vim cursor-shape changes (insert vs normal mode) render as bar vs block in the terminal pane.', NULL, '2026-06-12 00:52:40', '2026-06-12 00:52:40', '2026-06-12 00:52:40', NULL, 'fd38b932757c81de62d693d72b883448', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB3DKQQJ583944DG8561VQ3G', 'status', 'backlog', 'done', NULL, '2026-06-12 01:04:52', '2026-06-12 01:04:52', '2026-06-12 01:04:52', NULL, '66a692e143b6a4be1b4845825e9e16ad', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB3DJZDDZ00BSA04B660RS7M', 'description', 'GATE for the whole epic — nothing else starts until this lands. Turn Q-23 into D-records and pick the footprint model with evidence. Decide between: (1) No-install ssh-exec (zero remote footprint) — stock ssh: ssh -tt PTYs for terminal/Claude, multiplexed ControlMaster command channels for git/pql/file ops; nothing clide-specific on the remote; watching degrades to polling; no stateful remote process. (2) Auto-pushed self-managed agent (VS Code Remote model) — clide auto-deploys + version-checks one self-contained binary on connect (a headless UI-less deployment of the existing subsystem library: lib/src/daemon, git, pql, files, pty, ipc/server.dart — hosting the same DaemonDispatcher + IpcServer); gains native inotify watching + stateful backend. MUST answer the user''s agent-model sub-questions: is it a proxy/backend? cleanup/GC on disconnect/version-bump/repo-removal? placement (per-repo .clide/agent vs per-host ~/.clide/agent vs shared — per-host shared likely)? multi-client sharing (two local clides / two users — share one agent or one each? IpcServer is already multi-connection, D-72)? version skew (version encoded in binary name, e.g. clide-agent-<ver>, so versions coexist)? Also measure ControlMaster per-command latency for the ssh-exec model. Also decide the remote-tool contract: what must exist remotely (git/pql/claude/shell), whether pql is hard-required or degrades, and how a preflight surfaces what is missing. Include the D-56 reconciliation: ''single process'' is scoped per-host-per-workspace; a headless remote deployment of the subsystem library does not violate the no-second-local-process rule. Artifacts: Q-23 -> Resolved; new D-records for footprint model + D-56 framing, ssh:// URI scheme, remote auth (system ssh, v1, Windows deferred), remote-tool contract, session identity keyed on (host, repo) amending D-41/D-77.', 'GATE for the whole epic — nothing else starts until this lands. Turn Q-23 into D-records and pick the footprint model with evidence. Decide between: (1) No-install ssh-exec (zero remote footprint) — stock ssh: ssh -tt PTYs for terminal/Claude, multiplexed ControlMaster command channels for git/pql/file ops; nothing clide-specific on the remote; watching degrades to polling; no stateful remote process. (2) Auto-pushed self-managed agent (VS Code Remote model) — clide auto-deploys + version-checks one self-contained binary on connect (a headless UI-less deployment of the existing subsystem library: lib/src/daemon, git, pql, files, pty, ipc/server.dart — hosting the same DaemonDispatcher + IpcServer); gains native inotify watching + stateful backend. MUST answer the user''s agent-model sub-questions: is it a proxy/backend? cleanup/GC on disconnect/version-bump/repo-removal? placement (per-repo .clide/agent vs per-host ~/.clide/agent vs shared — per-host shared likely)? multi-client sharing (two local clides / two users — share one agent or one each? IpcServer is already multi-connection, D-72)? version skew (version encoded in binary name, e.g. clide-agent-<ver>, so versions coexist)? Also measure ControlMaster per-command latency for the ssh-exec model. Also decide the remote-tool contract: what must exist remotely (git/pql/claude/shell), whether pql is hard-required or degrades, and how a preflight surfaces what is missing. Include the D-56 reconciliation: ''single process'' is scoped per-host-per-workspace; a headless remote deployment of the subsystem library does not violate the no-second-local-process rule. Artifacts: Q-23 -> Resolved; new D-records for footprint model + D-56 framing, ssh:// URI scheme, remote auth (system ssh, v1, Windows deferred), remote-tool contract, session identity keyed on (host, repo) amending D-41/D-77.

2026-06-12 status: BLOCKED ON USER — the footprint pick (no-install ssh-exec vs auto-pushed agent) is a user decision (the user explicitly does not want to manage remote installs, but the agent model buys inotify + a stateful backend). The decision menu + agent sub-questions are written up in Q-23''s 2026-06-12 triage block; resolve there, then convert to D-records per this ticket''s artifact list.

Also environment-blocked: the ControlMaster latency probe needs a reachable sshd; the dev box has none. Run the probe against a real remote host during the decision session.

Not actually gating everything: the model-independent backbone is proceeding — Phase 1 (T-331, DaemonTransport seam) is done; the model-independent parts of Phase 2 (T-332: WorkspaceRef, ssh:// parsing, RecentProject host fields) don''t need the footprint pick either. T-336 (execution layer) and Phases 3-5 stay gated.', NULL, '2026-06-12 01:05:38', '2026-06-12 01:05:38', '2026-06-12 01:05:38', NULL, '06d89d9d6456a6263a30f246ac165f0e', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB3DMF20SYFDT6WX2RFBQXKW', 'status', 'backlog', 'in_progress', NULL, '2026-06-12 01:10:56', '2026-06-12 01:10:56', '2026-06-12 01:10:56', NULL, '68dd989ecd85d7a231bf03e42b864417', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB3DMF20SYFDT6WX2RFBQXKW', 'description', 'Model-independent backbone. clide can represent and open an ssh:// workspace end-to-end (actual remote calls land on the execution layer from the fork phase). URI: ssh://[user@]host[:port]/abs/remote/path, resolving host aliases via ~/.ssh/config. lib/kernel/src/project.dart: RecentProject gains host/port/user (absent = local; back-compatible toJson/fromJson), bool get isRemote, remote display form in relativePath/timeAgo (e.g. buildbox:~/repo); introduce a WorkspaceRef { String? host; String path; } value type and migrate _current/current off bare Directory (Directory(remotePath) is meaningless locally) — local callers read .path; resolveProject (~:204) branches: local runs git rev-parse as today, remote resolves the toplevel via the execution layer. lib/main.dart: swapBackend remote branch wires DaemonClient to the remote transport (no local server bound for remote workspaces). Connection lifecycle: connect -> resolve auth -> establish transport -> preflight remote tools -> ProjectOpened. On SSH drop, DaemonClient reconnect re-attaches; events --since cursor-pull (server.dart ~:339) is the re-sync primitive (gap:true -> UI full refresh). Verify: unit tests on RecentProject/WorkspaceRef JSON round-trips (local + remote); open ssh://localhost/... loopback workspace and confirm resolveProject returns the remote toplevel. Depends on Phase 1 (transport seam).', 'Model-independent backbone. clide can represent and open an ssh:// workspace end-to-end (actual remote calls land on the execution layer from the fork phase). URI: ssh://[user@]host[:port]/abs/remote/path, resolving host aliases via ~/.ssh/config. lib/kernel/src/project.dart: RecentProject gains host/port/user (absent = local; back-compatible toJson/fromJson), bool get isRemote, remote display form in relativePath/timeAgo (e.g. buildbox:~/repo); introduce a WorkspaceRef { String? host; String path; } value type and migrate _current/current off bare Directory (Directory(remotePath) is meaningless locally) — local callers read .path; resolveProject (~:204) branches: local runs git rev-parse as today, remote resolves the toplevel via the execution layer. lib/main.dart: swapBackend remote branch wires DaemonClient to the remote transport (no local server bound for remote workspaces). Connection lifecycle: connect -> resolve auth -> establish transport -> preflight remote tools -> ProjectOpened. On SSH drop, DaemonClient reconnect re-attaches; events --since cursor-pull (server.dart ~:339) is the re-sync primitive (gap:true -> UI full refresh). Verify: unit tests on RecentProject/WorkspaceRef JSON round-trips (local + remote); open ssh://localhost/... loopback workspace and confirm resolveProject returns the remote toplevel. Depends on Phase 1 (transport seam).

2026-06-12 progress: the model-independent slice is in — WorkspaceRef value type (lib/kernel/src/workspace_ref.dart: local/remote ctors, ssh://[user@]host[:port]/abs/path parse with rejection of host-less/path-less forms, uri/display, value equality; exported from kernel.dart) and RecentProject host/port/user (back-compatible JSON — absent keys deserialize local; isRemote; ref getter; relativePath renders host:path; copyWith preserves host identity). Tests: test/kernel/src/workspace_ref_test.dart + new RecentProject cases in project_test.dart.

REMAINING (gated on T-330''s footprint pick / T-336 execution layer): migrate ProjectManager._current/current off bare Directory onto WorkspaceRef (touch all .current?.path callers), open() branching on isRemote, resolveProject remote toplevel via the execution layer, swapBackend remote branch (DaemonTransport seam from T-331 is ready), connection lifecycle + preflight + events --since re-sync. The ssh://localhost loopback verify also needs a reachable sshd (none on the dev box).', NULL, '2026-06-12 01:11:07', '2026-06-12 01:11:07', '2026-06-12 01:11:07', NULL, '9818a9e40bff585344ea3308256ccd67', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB3DJZDDZ00BSA04B660RS7M', 'status', 'backlog', 'done', NULL, '2026-06-12 03:14:44', '2026-06-12 03:14:44', '2026-06-12 03:14:44', NULL, '862d2f0dd02ae19c1608c05478ed6fd9', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB3DJZDDZ00BSA04B660RS7M', 'description', 'GATE for the whole epic — nothing else starts until this lands. Turn Q-23 into D-records and pick the footprint model with evidence. Decide between: (1) No-install ssh-exec (zero remote footprint) — stock ssh: ssh -tt PTYs for terminal/Claude, multiplexed ControlMaster command channels for git/pql/file ops; nothing clide-specific on the remote; watching degrades to polling; no stateful remote process. (2) Auto-pushed self-managed agent (VS Code Remote model) — clide auto-deploys + version-checks one self-contained binary on connect (a headless UI-less deployment of the existing subsystem library: lib/src/daemon, git, pql, files, pty, ipc/server.dart — hosting the same DaemonDispatcher + IpcServer); gains native inotify watching + stateful backend. MUST answer the user''s agent-model sub-questions: is it a proxy/backend? cleanup/GC on disconnect/version-bump/repo-removal? placement (per-repo .clide/agent vs per-host ~/.clide/agent vs shared — per-host shared likely)? multi-client sharing (two local clides / two users — share one agent or one each? IpcServer is already multi-connection, D-72)? version skew (version encoded in binary name, e.g. clide-agent-<ver>, so versions coexist)? Also measure ControlMaster per-command latency for the ssh-exec model. Also decide the remote-tool contract: what must exist remotely (git/pql/claude/shell), whether pql is hard-required or degrades, and how a preflight surfaces what is missing. Include the D-56 reconciliation: ''single process'' is scoped per-host-per-workspace; a headless remote deployment of the subsystem library does not violate the no-second-local-process rule. Artifacts: Q-23 -> Resolved; new D-records for footprint model + D-56 framing, ssh:// URI scheme, remote auth (system ssh, v1, Windows deferred), remote-tool contract, session identity keyed on (host, repo) amending D-41/D-77.

2026-06-12 status: BLOCKED ON USER — the footprint pick (no-install ssh-exec vs auto-pushed agent) is a user decision (the user explicitly does not want to manage remote installs, but the agent model buys inotify + a stateful backend). The decision menu + agent sub-questions are written up in Q-23''s 2026-06-12 triage block; resolve there, then convert to D-records per this ticket''s artifact list.

Also environment-blocked: the ControlMaster latency probe needs a reachable sshd; the dev box has none. Run the probe against a real remote host during the decision session.

Not actually gating everything: the model-independent backbone is proceeding — Phase 1 (T-331, DaemonTransport seam) is done; the model-independent parts of Phase 2 (T-332: WorkspaceRef, ssh:// parsing, RecentProject host fields) don''t need the footprint pick either. T-336 (execution layer) and Phases 3-5 stay gated.', 'GATE for the whole epic — nothing else starts until this lands. Turn Q-23 into D-records and pick the footprint model with evidence. Decide between: (1) No-install ssh-exec (zero remote footprint) — stock ssh: ssh -tt PTYs for terminal/Claude, multiplexed ControlMaster command channels for git/pql/file ops; nothing clide-specific on the remote; watching degrades to polling; no stateful remote process. (2) Auto-pushed self-managed agent (VS Code Remote model) — clide auto-deploys + version-checks one self-contained binary on connect (a headless UI-less deployment of the existing subsystem library: lib/src/daemon, git, pql, files, pty, ipc/server.dart — hosting the same DaemonDispatcher + IpcServer); gains native inotify watching + stateful backend. MUST answer the user''s agent-model sub-questions: is it a proxy/backend? cleanup/GC on disconnect/version-bump/repo-removal? placement (per-repo .clide/agent vs per-host ~/.clide/agent vs shared — per-host shared likely)? multi-client sharing (two local clides / two users — share one agent or one each? IpcServer is already multi-connection, D-72)? version skew (version encoded in binary name, e.g. clide-agent-<ver>, so versions coexist)? Also measure ControlMaster per-command latency for the ssh-exec model. Also decide the remote-tool contract: what must exist remotely (git/pql/claude/shell), whether pql is hard-required or degrades, and how a preflight surfaces what is missing. Include the D-56 reconciliation: ''single process'' is scoped per-host-per-workspace; a headless remote deployment of the subsystem library does not violate the no-second-local-process rule. Artifacts: Q-23 -> Resolved; new D-records for footprint model + D-56 framing, ssh:// URI scheme, remote auth (system ssh, v1, Windows deferred), remote-tool contract, session identity keyed on (host, repo) amending D-41/D-77.

2026-06-12 status: BLOCKED ON USER — the footprint pick (no-install ssh-exec vs auto-pushed agent) is a user decision (the user explicitly does not want to manage remote installs, but the agent model buys inotify + a stateful backend). The decision menu + agent sub-questions are written up in Q-23''s 2026-06-12 triage block; resolve there, then convert to D-records per this ticket''s artifact list.

Also environment-blocked: the ControlMaster latency probe needs a reachable sshd; the dev box has none. Run the probe against a real remote host during the decision session.

Not actually gating everything: the model-independent backbone is proceeding — Phase 1 (T-331, DaemonTransport seam) is done; the model-independent parts of Phase 2 (T-332: WorkspaceRef, ssh:// parsing, RecentProject host fields) don''t need the footprint pick either. T-336 (execution layer) and Phases 3-5 stay gated.

Resolved 2026-06-12: user picked the no-install ssh-exec model. Artifacts landed: D-96 (footprint + D-56 reconciliation), D-97 (ssh:// URI + system-ssh BatchMode auth, Windows deferred), D-98 (remote-tool contract + batched preflight; pql/claude degrade, shell+git required), D-99 (identity keyed on (host, repo), amends D-41/D-77); Q-23 marked Resolved. The ControlMaster latency probe was waived by the decision — latency is an accepted cost of the chosen model, to be measured during T-336 implementation against a real host. T-336 expanded into concrete tickets.', NULL, '2026-06-12 03:14:52', '2026-06-12 03:14:52', '2026-06-12 03:14:52', NULL, 'aa9bb91c7815bbfd2cfd575287693ac2', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBKMV7Y13PAYKZC0WB4FQXKC', 'description', NULL, 'The foundation module of the no-install ssh-exec execution layer (D-96/D-97). New lib/src/remote/ssh_connection.dart (Flutter-free — will be exercised by dart-test core suites like lib/src/ipc):

- SshConnection(WorkspaceRef ref): owns one ControlMaster connection per (host, port, user). Open: `ssh -o BatchMode=yes -o ControlMaster=auto -o ControlPath=<user-scope socket dir>/%C -o ControlPersist=60 -N` (or -M + background); the ControlPath dir lives in user scope next to the D-70 socket dir, never in the repo (D-93). Surface open errors verbatim (BatchMode auth failures must reach the UI with the D-97 guidance message).
- run(List<String> argv, {String? cwd, String? stdin}) → (exitCode, stdout, stderr): one exec channel over the master (`ssh <dest> -- cd <cwd> && exec ...` with proper shell quoting — write a quoteForShell helper, test it hard: spaces, quotes, $, globs).
- close(): `ssh -O exit` + cleanup. isAlive via `ssh -O check`.
- The ssh binary path is injectable (constructor param defaulting to ''ssh'') — tests use a stub executable (a shell script recording argv and replaying canned stdout/exit codes), so the full lifecycle is testable without sshd. Pattern: test/remote/ssh_connection_test.dart writes the stub into a temp dir via tester-side File I/O (dart test, no Flutter).
- Latency: measure per-run round-trip in debug logs (D-96 accepted the cost; T-330 deferred the measurement to here).

Done when: connection open/run/close lifecycle green under dart test with the stub ssh; quoting helper covered for the hostile cases; BatchMode failure surfaces a typed exception with stderr attached.', NULL, '2026-06-12 03:15:15', '2026-06-12 03:15:15', '2026-06-12 03:15:15', NULL, '6dd627aa5bdf8c8c4e9b8179c55fa601', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBKMXSVCE98K1H76N00TYCQR', 'description', NULL, 'The sweep half of D-96: subsystems that touch the workspace (git client, pql client, files listing/IO, search engines, editor registry) gain an ExecutionContext seam instead of bare Process.run/File/Directory, so the same subsystem code serves local and ssh-exec workspaces.

Shape: lib/src/remote/execution_context.dart (Flutter-free) —
- abstract ExecutionContext { Future<ProcResult> run(String exe, List<String> args, {String? cwd, String? stdinText}); plus the file primitives actually used: readFile/writeFile/stat/list/exists/delete (audit the real call surface first — grep Process.run + dart:io File/Directory under lib/src/{git,pql,files,search,editor,daemon}). }
- LocalExecutionContext: today''s behavior verbatim (Process.run + dart:io).
- SshExecutionContext(SshConnection) [T-398]: run → exec channel; file primitives via standard remote commands (cat/stat -c/find/test/rm; write via `cat > file` with stdin) — POSIX only per D-98.

Migration order (one subsystem per commit, zero behavior change proven by existing suites): git/operations.dart → pql/client.dart → files/listing.dart → search → editor/registry.dart. Constructor-inject the context defaulting to LocalExecutionContext so call sites don''t churn.

Watcher: the polling watcher (debounced mtime/git-status sweep emitting the same FileChange events; inotifywait opportunistic) is its own follow-up ticket once this seam exists — don''t fold it in here.

Done when: all five subsystems take an ExecutionContext, local default keeps every existing test green untouched, SshExecutionContext passes a stub-ssh suite for run + each file primitive.', NULL, '2026-06-12 03:15:36', '2026-06-12 03:15:36', '2026-06-12 03:15:36', NULL, 'ad670b5cb9daeb051843fb6da71f602f', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBKN09R21H3AWR2Q2ZTSGNSW', 'description', NULL, 'Interactive channels of the ssh-exec model (D-96). A remote terminal/Claude pane spawns `ssh -tt [-p port] [user@]host -- cd <cwd> && exec <cmd>` LOCALLY via the existing native PTY (posix_openpt + posix_spawn, lib/src/pty/native_pty.dart) — the local PTY wraps the ssh process, the remote side gets its own pty from -tt. So NO new PTY mechanism: implement a RemotePtySpawner that builds the ssh argv from a WorkspaceRef + command and hands it to NativePty.

- Resize: local PTY resize propagates through ssh automatically (SIGWINCH on the local pty → ssh forwards). Verify with a resize test against the stub.
- Exit/loss: ssh exiting (network drop) is a pane exit — the claude pane''s session-end status line (T-372 work) already renders that; terminal pane likewise.
- Env: CLIDE_SOCK etc. (agent_bootstrap.dart) is Phase-3 scope (T-333) — out of scope here.
- Tests: stub ssh (same harness as T-398) + the existing pty dart-test suite pattern (test/pty is serial under dart test).

Done when: a RemotePtySpawner produces correct argv (quoting via T-398''s helper), spawns through NativePty, resize + exit propagate, covered under dart test with the stub.', NULL, '2026-06-12 03:15:55', '2026-06-12 03:15:55', '2026-06-12 03:15:55', NULL, '29f76f72c9879c8728dfc00c1e604a8a', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBKN2MP35NPPK1BRDYY2M428', 'description', NULL, 'D-96''s watching degrade. Remote workspaces get FileChange events from a poller, not inotify, with the SAME event shapes the local watcher (lib/src/files/watcher.dart) emits — consumers must not know the difference.

- Primary mode: debounced sweep over the ExecutionContext (T-399): `git status --porcelain -z` (tracked changes, cheap on the remote) + a `find -newer <stamp>` pass for untracked/ignored-relevant paths, on a ~2s cadence, diffed against the previous snapshot to synthesize add/modify/delete events.
- Opportunistic upgrade: if the D-98 preflight found inotifywait, hold one long-lived exec channel running `inotifywait -m -r` and translate its lines — instant events, still zero-install (inotifywait is the remote''s own tool).
- Pause the sweep while no remote workspace is open; back off (cadence x4) when the pane is unfocused/minimized to respect the round-trip budget.
- Tests: drive with a fake ExecutionContext replaying canned snapshots; assert synthesized event sequences (created/modified/deleted, rename = delete+create), debounce, and the inotifywait line-translation table.

Done when: poller emits watcher-compatible events from snapshot diffs under test, inotifywait mode translates correctly, and cadence/backoff is config-free but bounded.', NULL, '2026-06-12 03:16:12', '2026-06-12 03:16:12', '2026-06-12 03:16:12', NULL, '7e7a88fb0b5d0193bd3ac83f23b62652', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBKN4QVFVE51MY2N0CWCVXHM', 'description', NULL, 'Implements D-98. On remote connect (after the SshConnection opens, before ProjectOpened fires), run ONE batched probe over the exec channel:

  for t in sh git pql claude inotifywait; do printf ''%s='' "$t"; command -v "$t" >/dev/null 2>&1 && "$t" --version 2>/dev/null | head -1 || echo MISSING; done

(or equivalent single round-trip). Parse into a RemoteToolset { git: version?, pql: version?, claude: version?, inotifywait: bool }.

- shell+git MISSING → the open fails with the probe output in the error (actionable, names the host).
- pql MISSING → planning/query surfaces dark behind the D-95-style banner ("pql not found on <host> — install it there to enable tickets/decisions"); version skew vs the bundled local pql is surfaced (toast), not reconciled.
- claude MISSING → Claude pane disabled with notice; everything else live.
- inotifywait presence feeds the T-401 watcher mode pick.
- Tests: parse table from canned probe outputs (all-present, pql-missing, git-missing, weird version strings); fail-the-open path; banner gating is a later UI ticket under Phase 5 (T-335) — this ticket is the probe + model + open-gate only.

Done when: probe runs as one exec round-trip, RemoteToolset drives open-failure for missing required tools, parse covered under dart test.', NULL, '2026-06-12 03:16:30', '2026-06-12 03:16:30', '2026-06-12 03:16:30', NULL, '86ad94f4dc6f7380b39c3ec96ce67d0f', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB3DQEMTDHF8SV27AKAB8JHW', 'description', 'PLACEHOLDER — exact tickets crystallize after the Phase-0 spike (T-330) picks the footprint model. Both designs below so the choice is a swap, not a redesign. IF auto-pushed agent: execution layer is mostly transport + provisioning — subsystems (GitClient, PqlClient, FilesService, SearchService, NativePty) run UNCHANGED inside the remote agent; buildDispatcher (main.dart ~:176) split into UI-coupled vs headless-safe registrations; new bin/clide_agent.dart hosts the headless set + an IpcServer; RemoteTransport = SSH-tunneled agent socket (stdio bridge); watching is native inotify in the agent (watcher.dart unchanged); plus a provisioning module lib/src/remote/ (push, version-name, launch, GC). IF no-install ssh-exec: introduce a RemoteExecutionContext that each subsystem uses instead of bare Process.run/File/Directory — ssh -tt for PTYs, multiplexed ControlMaster command channels for git/pql/file ops, and a polling watcher (debounced git-status/mtime, or inotifywait if present) emitting the same FileChange events so the UI is unaware; heavier subsystem surface, zero remote footprint. Either way: pql runs where its .pql/ index lives (remote), git runs where .git/ lives (remote), clide still only wraps pql (D-3 preserved). Blocks Phases 3 and 4. Depends on Phase 0 (T-330) and Phase 1 (T-331).', 'PLACEHOLDER — exact tickets crystallize after the Phase-0 spike (T-330) picks the footprint model. Both designs below so the choice is a swap, not a redesign. IF auto-pushed agent: execution layer is mostly transport + provisioning — subsystems (GitClient, PqlClient, FilesService, SearchService, NativePty) run UNCHANGED inside the remote agent; buildDispatcher (main.dart ~:176) split into UI-coupled vs headless-safe registrations; new bin/clide_agent.dart hosts the headless set + an IpcServer; RemoteTransport = SSH-tunneled agent socket (stdio bridge); watching is native inotify in the agent (watcher.dart unchanged); plus a provisioning module lib/src/remote/ (push, version-name, launch, GC). IF no-install ssh-exec: introduce a RemoteExecutionContext that each subsystem uses instead of bare Process.run/File/Directory — ssh -tt for PTYs, multiplexed ControlMaster command channels for git/pql/file ops, and a polling watcher (debounced git-status/mtime, or inotifywait if present) emitting the same FileChange events so the UI is unaware; heavier subsystem surface, zero remote footprint. Either way: pql runs where its .pql/ index lives (remote), git runs where .git/ lives (remote), clide still only wraps pql (D-3 preserved). Blocks Phases 3 and 4. Depends on Phase 0 (T-330) and Phase 1 (T-331).

2026-06-12: footprint decided — no-install ssh-exec (D-96, user pick). This story is now the EXECUTION-LAYER UMBRELLA for that model; the agent-model branch in the description above is dead. Expanded into: T-398 (SSH connection manager — ControlMaster + exec channel, the foundation), T-399 (ExecutionContext seam sweep across git/pql/files/search/editor), T-400 (remote PTY via ssh -tt through the existing NativePty), T-401 (polling watcher), T-402 (D-98 preflight probe). Blocker graph: 399/400/402 by 398; 401 by 399. Close this story when those five are done; T-333/T-334 unblock then.', NULL, '2026-06-12 03:16:59', '2026-06-12 03:16:59', '2026-06-12 03:16:59', NULL, 'ee6546888baa7789804fc49c278a6e60', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBKP67X1Y1FEE9T5R0E5DA9C', 'description', NULL, 'From the 2026-06-12 vim keybind review (user: "we are leaving opportunities on the table" for cross-pane vim interactions). Findings:

TODAY the vim layer (T-65) is editor-only. vim.normal/insert/visual scope flags are global (VimModeService), but every binding in vim.yaml either targets editor.vim.* (applied by the focused editor''s key handler, editor_view.dart _dispatchVim) or is a copy of the default preset''s app chords. Outside the editor, the vim preset offers nothing vim-shaped: no ctrl+w window family, no gt/gT, no j/k in the file tree / ticket list / git panel / conversation (those panes have NO key handling at all — mouse-only), no ex command line (vim_mode_service.dart explicitly defers it as "a transient overlay").

EXISTING primitives to map onto: focus.nextPanel/previousPanel (F6/shift+F6), panel.focus.left/middle/right (ctrl+1/2/3), panel.focusMode (ctrl+. — semantically EXACTLY vim''s ctrl+w o "only"), editor.open/close (ctrl+e/ctrl+w), dock.toggle (ctrl+j), sidebar.collapse/context.collapse, quickOpen, alt+1..5 sidebar sections. The D-82 sequence matcher already resolves exact-vs-longer ambiguity with a pending-exact + timeout (sequence_matcher.dart _pendingExact), so chord-prefixed sequences like "ctrl+w h" are expressible in preset YAML today.

GAP also found: no workspace tab next/prev cycling command exists for ANY preset (only direct alt+N for sidebar sections) — child ticket adds the commands, vim binds gt/gT to them.

Children: T-404 (ctrl+w window-command family), T-405 (tab cycle commands + gt/gT), T-406 (normal-mode list/scroll nav intents for non-editor panes), T-407 (ex command-line overlay). 404/405 are YAML+small-command work; 406 is the structural one; 407 is the most visible.', NULL, '2026-06-12 03:21:06', '2026-06-12 03:21:06', '2026-06-12 03:21:06', NULL, 'bf4b66250410bce443e0114635bb2401', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBKP8KFAF526ZNXBQS98DPPG', 'description', NULL, 'Bind vim''s window-command prefix in assets/keymaps/vim.yaml, guarded `when: vim.normal` (and probably `|| vim.visual`), mapping onto the existing panel commands — no new services:

- `ctrl+w h` → command:panel.focus.left; `ctrl+w l` → command:panel.focus.right (clide''s three-column layout has no vertical pane stack, so j/k map to the dock: `ctrl+w j` → command:dock.toggle — document the approximation in the YAML comment)
- `ctrl+w w` and `ctrl+w ctrl+w` → focus.nextPanel; `ctrl+w shift+w` → focus.previousPanel
- `ctrl+w o` → command:panel.focusMode (vim "only" — exact semantic match)
- `ctrl+w q` and `ctrl+w c` → command:editor.close

Conflict to resolve (the real work): editor.close carries defaultBinding ''ctrl+w'' globally. Verify how preset bindings + defaultBindings merge in KeymapService, and that the sequence matcher''s pending-exact path (sequence_matcher.dart, _pendingExact + timeout flush) makes bare ctrl+w wait for a possible second chord under the vim preset — bare ctrl+w should still close the editor after the ambiguity timeout, prefix completions should win immediately. Add matcher tests for chord-prefixed sequences (existing tests cover `d d` letter sequences; `ctrl+w h` adds a modified first chord).

Done when: all bindings above work under the vim preset with editor focused AND with tree/conversation focused (they''re global commands, not editor.vim.*); bare ctrl+w still closes the editor after the timeout; no behavior change under default/vscode/jetbrains presets; keymap loader + matcher tests cover the new shapes.', NULL, '2026-06-12 03:21:26', '2026-06-12 03:21:26', '2026-06-12 03:21:26', NULL, '263c482620fb5598ea49e292dc7d573a', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBKPAZR4XEV8YW3PVR2XJBFC', 'description', NULL, 'Two halves; the first benefits every preset (the review found NO tab-cycling command exists anywhere — only alt+1..5 direct sidebar-section picks):

1. New commands in the default-layout extension (or panels host): workspace.tab.next / workspace.tab.previous — cycle the workspace slot''s tab strip (PanelRegistry/MultitabPane activate-next/previous with wraparound). Give them defaultBindings ctrl+pagedown / ctrl+pageup (the GTK/VS Code convention) so default/vscode/jetbrains presets gain tab cycling for free. Check lib/kernel/src/panels/registry.dart for the activation API; add one if only direct activateTab(id) exists.

2. vim.yaml: `g t` → command:workspace.tab.next, `g shift+t` → command:workspace.tab.previous, when vim.normal. Watch the existing `g g` (docStart) prefix — the matcher already buffers `g`, so `g t` slots in beside it; add a matcher/loader test for two sequences sharing the `g` prefix with different finals.

Done when: ctrl+pagedown/up cycle workspace tabs under every preset; gt/gT cycle under vim; shared-prefix sequence test green; alt+N behavior unchanged.', NULL, '2026-06-12 03:21:43', '2026-06-12 03:21:43', '2026-06-12 03:21:43', NULL, '73451f38a7c81a487fa3d539e9d7daa5', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBKPD85PFBPJJTQ0WS3PWWXR', 'description', NULL, 'The structural piece: make vim NORMAL mode mean something in panes that aren''t the editor. Today the file tree, ticket board, git panel, and conversation view have no keyboard handling at all (mouse-only — verified 2026-06-12); under the vim preset, j/k outside the editor are dead keys.

Mechanism (follow the ActivateIntent pattern from default.yaml — intents dispatched via Actions.maybeInvoke against the FOCUSED context, so only opted-in widgets respond and there''s no global-flag confusion):

1. New typed intents in kernel/src/keymap/intents.dart: nav.down / nav.up / nav.pageDown / nav.pageUp / nav.top / nav.bottom / nav.expandOrRight / nav.collapseOrLeft / nav.activate (ids in builtinIntents).
2. vim.yaml binds them when "vim.normal && !editor.focused": j/k, ctrl+d/ctrl+u, "g g"/shift+g, l/h, [o, enter]. Needs an editor.focused scope flag if none exists — check what the editor publishes today; the editor''s own key handler consumes j/k first when focused, so the guard may even be unnecessary — verify dispatch order and document it.
3. Panes opt in with Actions handlers:
   - file tree (lib/builtin/files/src/file_tree_view.dart): selection cursor + j/k move, h/l collapse/expand-or-step-into, o/enter open (the NERDTree idiom)
   - conversation view (lib/builtin/claude/src/conversation_view.dart): j/k line scroll, ctrl+d/u half page, G jump-to-bottom AND re-arm follow-tail (_atBottom), gg top
   - ticket board + git panel lists: selection cursor + activate
4. default/vscode/jetbrains presets can bind the same intents to arrows/page keys later — the intents are preset-neutral; this ticket only wires vim.

Scope guard: this is keyboard NAVIGATION only — no editing semantics outside the editor. Start with tree + conversation (highest value), lists can trail in a follow-up commit on the same ticket.

Done when: with the vim preset active and the tree/conversation focused, j/k/ctrl+d/ctrl+u/gg/G work as above; widget tests per pane; zero behavior change under other presets and in insert mode.', NULL, '2026-06-12 03:22:05', '2026-06-12 03:22:05', '2026-06-12 03:22:05', NULL, '78c20e5b2c1549926cecc559a95426ff', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBKPFTC7H5NY0XHBTEGF8XQ4', 'description', NULL, 'The deferred piece vim_mode_service.dart already names: "command-line is surfaced separately as a transient overlay rather than a persistent mode." Minimal ex line, not a vimscript interpreter:

- `:` (shift+semicolon) when vim.normal opens a one-line overlay (reuse the quick-open overlay chrome/widgets; it is NOT a mode — Esc dismisses back to normal, no scope-flag churn beyond an exline.open flag for its own enter/escape bindings).
- v1 grammar, one table, no parsing cleverness:
  :w → editor save (find the editor''s save command id; check editor_commands.dart _save), :q → command:editor.close, :wq / :x → save then close, :e <text> → quickOpen.open pre-seeded with <text> (check QuickOpenIntent for a seed param; add one if absent), :<digits> → editor goto-line (editor has a goto? if not, smallest possible addition to editor.vim ops), :<unknown> → shake/flash + stay open.
- ZZ ("shift+z shift+z" sequence) → save-close, riding the same plumbing — include it here, it''s one YAML line once :wq exists.
- Cross-pane angle: the ex line is GLOBAL under vim.normal (works with tree/conversation focused — :q closes the focused tab via editor.close fallback to active workspace tab; keep v1 simple: editor-targeted only, document it).

Done when: : opens the overlay from any pane under the vim preset; the v1 table works with widget tests; unknown commands don''t execute anything; ZZ saves+closes.', NULL, '2026-06-12 03:22:28', '2026-06-12 03:22:28', '2026-06-12 03:22:28', NULL, '267348e926541d1c7b5e55c3c1ef6219', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBN3VTK2MYQQ173MSJN6E1DM', 'description', NULL, 'User report: typing /model in the Claude conversation view does nothing useful — it is forwarded to the session''s stream-json stdin like a plain message, and the CLI''s interactive /model picker only exists in its own TUI. Clide must own it (same class as /clear,/resume,/fork — T-156).

Interaction design:
- `/model <name>` → set the session model directly to <name> (accept aliases like sonnet/opus and full ids).
- `/model` (bare) → show a model picker in the interaction zone — replaces the composer while open, like ToolPromptCard (D-78); list selectable via keyboard (numbers/arrows + Enter), Esc cancels back to the composer.

Implementation map (from code exploration):
- Add ''model'' to kClideOwnedCommands in lib/builtin/claude/src/slash_commands.dart and handle it in ClaudePane._send (lib/builtin/claude/src/claude_pane.dart).
- Add StreamJsonSession.setModel(String) following the setPermissionMode control_request pattern (lib/builtin/claude/src/stream_json_session.dart) — subtype set_model; optimistically merge SessionStatus(model: …) so the status bar updates.
- Model list for the bare-picker: query the CLI via the supported_models-style control request if available (verify exact subtype/shapes against the installed CLI), falling back to a static alias list.
- Picker widget swaps in via the existing pending-interaction slot in ClaudePane; reuse composer focus/draft preservation (the draft must survive the swap).

Acceptance:
- `/model sonnet` switches the live session model; status bar reflects it on the next status merge.
- bare `/model` opens the picker; choosing an entry sets the model; Esc restores the composer with the draft intact.
- `/model` is never forwarded to the session as message text.
- Unit tests in test/builtin/claude/ for the parsing (slash_commands_test.dart), the pane interception, and the picker widget.', NULL, '2026-06-12 06:40:53', '2026-06-12 06:40:53', '2026-06-12 06:40:53', NULL, '86aaba4cdf1d5e3c054af341977c5315', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBN3VYR84023Z5XFEX9DS0S0', 'description', NULL, 'Regression from T-341 (double-tap-modifier shortcuts, shipped in 2.4.0). User report: pressing shift+; to type a colon in the editor or the Claude composer no longer types '':'' — the quick-open finder opens instead.

Likely cause: the double-Shift tap detector counts a Shift press/release as a "tap" even when another key was chorded while Shift was held. Typing '':'' is shift-down, '';'', shift-up; two colons (or a colon shortly after any shifted character) within the tap window then reads as shift,shift → "Search Everywhere" fires and may also swallow the keystroke.

Fix: a modifier press only qualifies as a tap if NO other key goes down between the modifier''s keydown and keyup. Any chorded key must invalidate the pending tap (and reset the double-tap sequence state).

Acceptance:
- Typing `::` rapidly in the editor and in the Claude composer produces two colons, never quick-open.
- Shifted typing in general (capitals, symbols) never triggers double-tap bindings.
- Genuine double-Shift (two bare taps within the window) still opens quick-open in all four presets.
- Regression test covering chorded-Shift-then-Shift-tap sequences.', NULL, '2026-06-12 06:40:54', '2026-06-12 06:40:54', '2026-06-12 06:40:54', NULL, '4f7eddbb58a3551d208dcd03541bed5d', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBN3VYR84023Z5XFEX9DS0S0', 'status', 'backlog', 'in_progress', NULL, '2026-06-12 06:40:59', '2026-06-12 06:40:59', '2026-06-12 06:40:59', NULL, '6f856737a3d115b0a8dd510d2051047d', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBN3VYR84023Z5XFEX9DS0S0', 'status', 'in_progress', 'done', NULL, '2026-06-12 06:49:24', '2026-06-12 06:49:24', '2026-06-12 06:49:24', NULL, 'ce08a8f54370d08b033552e169a8bbb9', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBN3VTK2MYQQ173MSJN6E1DM', 'status', 'backlog', 'in_progress', NULL, '2026-06-12 06:50:01', '2026-06-12 06:50:01', '2026-06-12 06:50:01', NULL, '801c09560f70be28365441175fb78440', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBN3VTK2MYQQ173MSJN6E1DM', 'status', 'in_progress', 'done', NULL, '2026-06-12 07:04:36', '2026-06-12 07:04:36', '2026-06-12 07:04:36', NULL, '09be3f51210b0815177613db912defaa', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBP3GM6V0RZBY2PXE9ZQFR88', 'status', 'backlog', 'in_progress', NULL, '2026-06-12 10:09:07', '2026-06-12 10:09:07', '2026-06-12 10:09:07', NULL, 'e54e34e5177b55ccbdf0da9c217d44a5', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBP3P8YERJ5R7ENSD675BX00', 'description', 'Turn the Claude sidebar Config tab''s read-only rows (T-183, split in T-395) into live controls — the heart of the power-panel epic. Inline: model picker (reuse the T-408 picker, anchored popover per D-ui primitive), permission-mode control (reuse T-275''s permission_mode_control), effort selector (lands with T-412; row shows ''n/a'' with a hint until supported). Each control reads live SessionStatus and writes through the same session APIs the slash commands use — one implementation, two surfaces (D-6).

Per-session scoping: controls target the active/primary session; the Team tab''s per-member badges (T-157) stay as-is. Keep read-only rows for facts (version, transcript path, skills count). A11y: every control keyboard-reachable, semantics labels per the a11y contract; run make test-a11y. Golden for the new rows if visual.', 'Turn the Claude sidebar Config tab''s read-only rows (T-183, split in T-395) into live controls — the heart of the power-panel epic. Inline: model picker (reuse the T-408 picker, anchored popover per D-ui primitive), permission-mode control (reuse T-275''s permission_mode_control), effort selector (lands with T-412; row shows ''n/a'' with a hint until supported). Each control reads live SessionStatus and writes through the same session APIs the slash commands use — one implementation, two surfaces (D-6).

Per-session scoping: controls target the active/primary session; the Team tab''s per-member badges (T-157) stay as-is. Keep read-only rows for facts (version, transcript path, skills count). A11y: every control keyboard-reachable, semantics labels per the a11y contract; run make test-a11y. Golden for the new rows if visual.

STYLING PASS (user, 2026-06-12): the Claude sidepanel looks bland and the font is
small. While making the Config tab interactive, also do a visual polish pass over
the whole Claude sidebar (Activity/Team/Config): bump the row/label typography to
the panel scale used elsewhere, give sections clearer hierarchy (headers, spacing,
accent marks per ui-design tokens), and make the controls feel like controls.
Treat ui-design skill as the reference for token/type choices.', NULL, '2026-06-12 10:24:43', '2026-06-12 10:24:43', '2026-06-12 10:24:43', NULL, '5e15c4d2cdabba62bbaba701a93f6e79', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBP3GM6V0RZBY2PXE9ZQFR88', 'status', 'in_progress', 'done', NULL, '2026-06-12 10:25:53', '2026-06-12 10:25:53', '2026-06-12 10:25:53', NULL, 'f65cf1d99c1d22ced8d18e1579b048ad', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBP3J7TXMG0F9E2WQDENPVJG', 'status', 'backlog', 'in_progress', NULL, '2026-06-12 10:25:53', '2026-06-12 10:25:53', '2026-06-12 10:25:53', NULL, 'dca846f23cb4353cc826ddd79a6c14f0', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBP3J7TXMG0F9E2WQDENPVJG', 'status', 'in_progress', 'done', NULL, '2026-06-12 10:56:52', '2026-06-12 10:56:52', '2026-06-12 10:56:52', NULL, 'fd7c4c5f0b0de9144c6220a4ce43476b', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBP3KRWM65MD3DS251NN9YX0', 'status', 'backlog', 'in_progress', NULL, '2026-06-12 10:56:52', '2026-06-12 10:56:52', '2026-06-12 10:56:52', NULL, 'd1eb3f87ceb5508e4dac1f191750f852', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBP3KRWM65MD3DS251NN9YX0', 'status', 'in_progress', 'done', NULL, '2026-06-12 11:06:36', '2026-06-12 11:06:36', '2026-06-12 11:06:36', NULL, 'b39b89981d73539635ddbff0d7ca137d', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBP3P8YERJ5R7ENSD675BX00', 'status', 'backlog', 'in_progress', NULL, '2026-06-12 11:06:36', '2026-06-12 11:06:36', '2026-06-12 11:06:36', NULL, 'e90215a982fee656911727727259d318', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBQ4BYD4STCKCY8JNKF23Q4W', 'description', NULL, 'The bottom central status bar mixes fonts, sizes, color tokens, and vertical alignment across its items, so the bar reads as several unrelated strips instead of one cohesive surface (user screenshot, 2026-06-12).

**Observed inconsistencies:**

- **Claude pane context status** (`lib/builtin/claude/src/claude_pane.dart:131` `_statusWidget`, `_ModeBadge` at line 816): `clideFontSmall` (12) + `clideMonoFamily` — the only 12px mono run in the bar.
- **Git branch item** (`lib/builtin/git/src/git_status_item.dart:78`): `clideFontCaption` (14), default UI face (Josefin Sans w300) — sits directly next to the 12px mono Claude segment.
- **Output dock item** (`lib/builtin/output/src/dock_status_item.dart:77`): `clideFontCaption` + `tokens.globalForeground` instead of `tokens.statusBarForeground`; also embeds `▼`/`▲` glyphs as text rather than a `ClideIcon`.
- **IPC tool status** (`lib/builtin/ipc_status/src/status_item.dart:45`) and **theme switcher** (`lib/builtin/theme_picker/src/theme_status_item.dart:68`): `clideFontCaption` + `statusBarForeground` — these two agree with each other but not with the Claude segment.
- **Vertical alignment:** `PaneContextStatusItem` (`lib/builtin/claude/src/pane_context_status.dart:34`) clamps its content in a fixed 16px `SizedBox` inside `ClideMarquee`, while `StatusbarHost` (`lib/src/shell/layout.dart:251`) centers other items via `CrossAxisAlignment.center` on the full bar height — the differing font sizes/line metrics make the Claude run sit visibly off-center relative to its neighbours.

**Direction (per /ui-design skill):**

- Typography rule says status bar text is `clideFontCaption` (14); mono (`clideFontMono`/`clideMonoFamily`) is reserved for code/paths/IDs. Decide one type treatment for the bar — likely caption + UI face for labels, mono only for genuinely code-like fragments (e.g. `633k / 1.0M ctx`) if at all — and apply it to every item.
- All status bar items should use `tokens.statusBarForeground` (muted variant: `globalTextMuted`) — fix the `globalForeground` borrow in the output dock item.
- Ensure every item centers in the bar''s vertical space: same slot height strategy (or none) across items so baselines align; review the fixed `_slotHeight = 16` in `pane_context_status.dart` against the bar''s `statusHeight`.
- Separator `·` styling (claude_pane.dart:136) should be a shared affordance if other items adopt segmented content.

Acceptance: one font family/size/token scheme across all five status items; all items visually centered in the bar''s vertical space; no `globalForeground` borrows; goldens updated.', NULL, '2026-06-12 11:23:21', '2026-06-12 11:23:21', '2026-06-12 11:23:21', NULL, 'dd7198e29cdc41d0837ce0ff068fa26f', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBP3P8YERJ5R7ENSD675BX00', 'status', 'in_progress', 'done', NULL, '2026-06-12 11:26:14', '2026-06-12 11:26:14', '2026-06-12 11:26:14', NULL, '6033e2a267f3dc8e1102fcb2ef515a2e', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBP3EZC7AJANXZVF3D91QYWM', 'status', 'backlog', 'ready', NULL, '2026-06-12 11:28:23', '2026-06-12 11:28:23', '2026-06-12 11:28:23', NULL, '8152841064ed2ff151449541e0b405d3', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBP3P91QQQDT5J50F52FPCKM', 'status', 'backlog', 'ready', NULL, '2026-06-12 11:28:28', '2026-06-12 11:28:28', '2026-06-12 11:28:28', NULL, 'ccb4c4193c34ef5e2bd9e20d407ccda3', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBPQ8QNGJFFK7G24CBWQAR2C', 'status', 'backlog', 'ready', NULL, '2026-06-12 11:28:32', '2026-06-12 11:28:32', '2026-06-12 11:28:32', NULL, '93622dd3b0a88598d1823685a0c2d3e6', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBQ595H08JFTRFSR90GSZQ0G', 'status', 'backlog', 'ready', NULL, '2026-06-12 11:28:38', '2026-06-12 11:28:38', '2026-06-12 11:28:38', NULL, '5729470fe53b18812c0338fa4f23a3c8', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBQ595H08JFTRFSR90GSZQ0G', 'status', 'ready', 'done', NULL, '2026-06-12 11:30:22', '2026-06-12 11:30:22', '2026-06-12 11:30:22', NULL, '6dd59c198c66791e49bad07edcc24882', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBP3P91QQQDT5J50F52FPCKM', 'status', 'ready', 'in_progress', NULL, '2026-06-12 11:30:55', '2026-06-12 11:30:55', '2026-06-12 11:30:55', NULL, 'c5a086c9415df9fbe4e7feacecc19c73', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FBP3P91QQQDT5J50F52FPCKM', 'status', 'in_progress', 'done', NULL, '2026-06-12 12:04:55', '2026-06-12 12:04:55', '2026-06-12 12:04:55', NULL, 'e7ff1649cb8b755d2888b851ad00c729', 2) ON CONFLICT(hash) DO NOTHING;
INSERT INTO ticket_history (ticket_record_id, field, old_value, new_value, changed_by, changed_at, created_at, updated_at, deleted_at, hash, canonical_version) VALUES ('06FB0TNQM62FKQQD0B9B80PFY4', 'description', 'Show the account/subscription usage budget (5-hour + weekly limits, % used, reset times) in the Claude meta sidebar (T-141). BLOCKED: this data is not programmatically exposed under subscription (OAuth) auth as of claude 2.1.150 — verified empirically + via docs (2026-05-23). /usage is TUI-only (headless ''claude -p /usage'' returns only a one-liner); stats-cache.json has activity counts only; the stream-json rate_limit_event is undocumented + needs a billed turn; ''claude auth status --json'' shows plan only. A ''claude usage --json'' + a /v1/organizations/{org}/usage/subscription endpoint are an OPEN, unshipped feature request (GitHub anthropics/claude-code#44328). Revisit when #44328 ships or an API-key usage path exists. See project memory ''claude-usage-budget-not-exposed''.

2026-06-09: detached from T-132 (which is otherwise complete) and made the RESOLVER ticket for Q-34 (how + when to surface the budget given upstream doesn''t expose it). Stays in the backlog; revisit when a viable data path lands (upstream claude usage --json / endpoint per anthropics/claude-code#44328, or an API-key usage path).', 'Show the account/subscription usage budget (5-hour + weekly limits, % used, reset times) in the Claude meta sidebar (T-141). BLOCKED: this data is not programmatically exposed under subscription (OAuth) auth as of claude 2.1.150 — verified empirically + via docs (2026-05-23). /usage is TUI-only (headless ''claude -p /usage'' returns only a one-liner); stats-cache.json has activity counts only; the stream-json rate_limit_event is undocumented + needs a billed turn; ''claude auth status --json'' shows plan only. A ''claude usage --json'' + a /v1/organizations/{org}/usage/subscription endpoint are an OPEN, unshipped feature request (GitHub anthropics/claude-code#44328). Revisit when #44328 ships or an API-key usage path exists. See project memory ''claude-usage-budget-not-exposed''.

2026-06-09: detached from T-132 (which is otherwise complete) and made the RESOLVER ticket for Q-34 (how + when to surface the budget given upstream doesn''t expose it). Stays in the backlog; revisit when a viable data path lands (upstream claude usage --json / endpoint per anthropics/claude-code#44328, or an API-key usage path).

UNBLOCKED (2026-06-12, T-415): probed claude 2.1.175 — a forwarded /usage IS
answered headless in stream-json (free, num_turns 0) with parseable text
(session %, week % all-models, week % Sonnet). The Activity tab now renders it
via parseUsageText + a user-initiated refresh control. Remaining scope for this
ticket would be per-member/team budget split, if still wanted.', NULL, '2026-06-12 12:11:28', '2026-06-12 12:11:28', '2026-06-12 12:11:28', NULL, '5e45a2e89f2234f8b642e1b9968d7ef1', 2) ON CONFLICT(hash) DO NOTHING;
