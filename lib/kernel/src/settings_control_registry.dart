import 'package:flutter/widgets.dart';

/// Holds the bespoke widgets that draw [SettingsFieldKind.custom] fields
/// (T-452). A subsystem registers a builder under a `customId` (via
/// `SettingsControlContribution`, routed by the extension manager); the
/// settings renderer looks it up when it meets a custom field.
///
/// Controls register at activation, before any settings modal opens, so this
/// is a plain registry — no change notification needed.
class SettingsControlRegistry {
  final Map<String, WidgetBuilder> _byId = <String, WidgetBuilder>{};

  /// Register the [builder] for [customId]. Throws on a duplicate id so a
  /// collision rolls the contributing extension's activation back.
  void register(String customId, WidgetBuilder builder) {
    if (_byId.containsKey(customId)) {
      throw StateError('duplicate settings control id: $customId');
    }
    _byId[customId] = builder;
  }

  void unregister(String customId) => _byId.remove(customId);

  /// The builder for [customId], or null when none is registered.
  WidgetBuilder? builderFor(String customId) => _byId[customId];
}
