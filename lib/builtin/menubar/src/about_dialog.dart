import 'package:clide/clide.dart' show clideName, clideTagline, clideVersion, clideRepository, clideCommit, clideDate;
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

import 'licenses_loader.dart';

/// The Help → About dialog (T-48): clide identity + build info, plus the
/// bundled-dependency licenses parsed from `assets/licenses.yaml`.
class AboutDialog extends StatelessWidget {
  const AboutDialog({super.key, required this.onDismiss});
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    return Container(
      width: 480,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.modalSurfaceBackground,
        border: Border.all(color: tokens.modalSurfaceBorder),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        // Stretch so the build-info rows and the licenses list get a bounded
        // width (the Container is width-fixed); the labels stay left-aligned.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ClideText(clideName, fontSize: 20, fontWeight: FontWeight.w600),
          const SizedBox(height: 2),
          const ClideText(clideTagline, muted: true, fontSize: 13),
          const SizedBox(height: 16),
          _Kv(label: 'Version', value: clideVersion, tokens: tokens),
          _Kv(label: 'Commit', value: clideCommit, tokens: tokens),
          _Kv(label: 'Built', value: _formatDate(clideDate), tokens: tokens),
          _Kv(label: 'Repository', value: clideRepository, tokens: tokens),
          const SizedBox(height: 16),
          ClideText('Bundled dependencies', fontSize: clideFontCaption, color: tokens.globalTextMuted),
          const SizedBox(height: 6),
          _Licenses(tokens: tokens),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [ClideButton(label: 'Close', onPressed: onDismiss)],
          ),
        ],
      ),
    );
  }
}

/// A label/value row in the build-info block.
class _Kv extends StatelessWidget {
  const _Kv({required this.label, required this.value, required this.tokens});
  final String label;
  final String value;
  final SurfaceTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: ClideText(label, fontSize: 13, color: tokens.globalTextMuted)),
          Expanded(
            child: ClideText(value, fontSize: 13, fontFamily: clideMonoFamily, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

/// The bundled-dependency list, loaded lazily from `assets/licenses.yaml`.
class _Licenses extends StatelessWidget {
  const _Licenses({required this.tokens});
  final SurfaceTokens tokens;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LicensesManifest>(
      future: loadLicenses(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return ClideText(snap.hasError ? 'Licenses unavailable.' : 'Loading…', fontSize: 12, color: tokens.globalTextMuted);
        }
        final deps = snap.data!.dependencies;
        return Container(
          constraints: const BoxConstraints(maxHeight: 260),
          decoration: BoxDecoration(
            border: Border.all(color: tokens.globalBorder),
            borderRadius: BorderRadius.circular(4),
          ),
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: deps.length,
            itemBuilder: (ctx, i) {
              final d = deps[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                child: ClideText(
                  '${d.name} ${d.version} · ${d.license}',
                  fontSize: 12,
                  fontFamily: clideMonoFamily,
                  color: tokens.globalTextMuted,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// `2026-06-07T11:45:29Z` → `2026-06-07 11:45 UTC`. Falls back to the raw
/// string if it doesn't parse.
String _formatDate(String iso) {
  final dt = DateTime.tryParse(iso);
  if (dt == null) return iso;
  final u = dt.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${u.year}-${two(u.month)}-${two(u.day)} ${two(u.hour)}:${two(u.minute)} UTC';
}
