/// Tier-0 in-memory stub for the OS-keychain-backed vault.
///
/// Lands on `libsecret` (Linux) and macOS Keychain in a later tier.
/// The async API already matches the eventual platform-channel shape,
/// so consumers don't need to change when the real backend arrives.
class SecretsVault {
  final Map<String, String> _memory = {};

  Future<void> write({
    required String extensionId,
    required String key,
    required String value,
  }) async {
    _memory['$extensionId/$key'] = value;
  }

  Future<String?> read({
    required String extensionId,
    required String key,
  }) async {
    return _memory['$extensionId/$key'];
  }

  Future<void> delete({
    required String extensionId,
    required String key,
  }) async {
    _memory.remove('$extensionId/$key');
  }

  Future<void> deleteAll({required String extensionId}) async {
    _memory.removeWhere((k, _) => k.startsWith('$extensionId/'));
  }
}
