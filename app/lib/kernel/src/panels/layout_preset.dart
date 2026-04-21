import 'package:clide_app/extension/src/contribution.dart';
import 'package:clide_app/kernel/src/panels/slot_id.dart';

/// Canonical "three-column + statusbar" preset — the default-layout
/// extension contributes this at Tier 0. Split out so tests and the
/// default-layout extension share one source of truth.
///
/// Columns (px):
///   sidebar  240 (drag 180–400)
///   center   flex (workspace on top, statusbar below)
///   context  280 (drag 220–420)
///   statusbar 26 (fixed height strip)
LayoutPresetContribution classicPreset() => const LayoutPresetContribution(
      id: 'builtin.default-layout.classic',
      displayName: 'Classic',
      slots: [
        LayoutSlot(
          slot: Slots.sidebar,
          position: SlotPosition.left,
          defaultSize: 240,
          minSize: 180,
          maxSize: 400,
        ),
        LayoutSlot(
          slot: Slots.workspace,
          position: SlotPosition.center,
        ),
        LayoutSlot(
          slot: Slots.contextPanel,
          position: SlotPosition.right,
          defaultSize: 280,
          minSize: 220,
          maxSize: 420,
        ),
        LayoutSlot(
          slot: Slots.statusbar,
          position: SlotPosition.bottom,
          defaultSize: 26,
          minSize: 26,
          maxSize: 26,
        ),
      ],
    );
