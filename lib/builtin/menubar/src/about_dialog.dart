import 'dart:async';

import 'package:clide/clide.dart' show clideName, clideTagline, clideVersion, clideRepository, clideCommit, clideDate;
import 'package:clide/kernel/kernel.dart';
import 'package:clide/src/update/update_check.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

import 'licenses_loader.dart';

/// The Help → About dialog (T-48): clide identity + build info, plus the
/// bundled-dependency licenses parsed from `assets/licenses.yaml`.
class AboutDialog extends StatelessWidget {
  const AboutDialog({super.key, required this.onDismiss, this.updateFetch});
  final VoidCallback onDismiss;

  /// Injected fetch for the update check, so widget tests never touch the
  /// network (T-47 P1). Production passes null → the real [githubGet].
  @visibleForTesting
  final GithubFetch? updateFetch;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
    // Wide enough that the license lines and the update row don't clip on an
    // ordinary screen, never wider than the window allows.
    final width = (MediaQuery.sizeOf(context).width - 80).clamp(480.0, 760.0);
    return Container(
      width: width,
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
          _Kv(
            label: ClideSettings.i18n.string(context, 'about.version', namespace: 'builtin.menubar', placeholder: 'Version'),
            value: clideVersion,
            tokens: tokens,
          ),
          _Kv(
            label: ClideSettings.i18n.string(context, 'about.commit', namespace: 'builtin.menubar', placeholder: 'Commit'),
            value: clideCommit,
            tokens: tokens,
          ),
          _Kv(
            label: ClideSettings.i18n.string(context, 'about.built', namespace: 'builtin.menubar', placeholder: 'Built'),
            value: _formatDate(clideDate),
            tokens: tokens,
          ),
          _Kv(
            label: ClideSettings.i18n.string(context, 'about.repository', namespace: 'builtin.menubar', placeholder: 'Repository'),
            value: clideRepository,
            tokens: tokens,
          ),
          const SizedBox(height: 14),
          _UpdateCheckRow(tokens: tokens, fetch: updateFetch),
          const SizedBox(height: 16),
          ClideText(
            ClideSettings.i18n.string(context, 'licenses.heading', namespace: 'builtin.menubar', placeholder: 'Bundled dependencies'),
            fontSize: clideFontCaption,
            color: tokens.globalTextMuted,
          ),
          const SizedBox(height: 6),
          _Licenses(tokens: tokens),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ClideButton(
                label: ClideSettings.i18n.string(context, 'button.close', namespace: 'builtin.menubar', placeholder: 'Close'),
                onPressed: onDismiss,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "Check for updates" button + inline status (T-47 P1). The check runs only on
/// this explicit tap — never on launch, never on a timer (D-64 / POLICY.md).
class _UpdateCheckRow extends StatefulWidget {
  const _UpdateCheckRow({required this.tokens, this.fetch});
  final SurfaceTokens tokens;
  final GithubFetch? fetch;

  @override
  State<_UpdateCheckRow> createState() => _UpdateCheckRowState();
}

class _UpdateCheckRowState extends State<_UpdateCheckRow> {
  UpdateCheckResult? _result;
  bool _checking = false;

  // Install (T-621): driven through the `app.update` verb so the CLI and this
  // button are one path (D-6); progress arrives as `app.update` events.
  bool _installing = false;
  String? _phase;
  double? _fraction;
  String? _installError;
  StreamSubscription<DaemonEvent>? _progress;

  @override
  void dispose() {
    unawaited(_progress?.cancel());
    super.dispose();
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _result = null;
      _installError = null;
    });
    final r = await checkForUpdate(repositoryUrl: clideRepository, currentVersion: clideVersion, fetch: widget.fetch ?? githubGet);
    if (mounted) {
      setState(() {
        _checking = false;
        _result = r;
      });
    }
  }

  Future<void> _install() async {
    final kernel = ClideKernel.of(context);
    setState(() {
      _installing = true;
      _installError = null;
      _phase = 'downloading';
      _fraction = null;
    });
    unawaited(_progress?.cancel());
    _progress = kernel.events.on<DaemonEvent>().where((e) => e.subsystem == 'app' && e.kind == 'app.update').listen((e) {
      if (!mounted) return;
      setState(() {
        _phase = e.data['phase'] as String?;
        _fraction = (e.data['fraction'] as num?)?.toDouble();
      });
    });
    final r = await kernel.ipc.request('app.update', args: {'install': true});
    if (!mounted) return;
    // On success the windows restart and this one goes away; stay on
    // "Restarting…" until it does.
    if (!r.ok) {
      setState(() {
        _installing = false;
        _phase = null;
        _installError = r.error?.message ?? 'unknown error';
      });
    }
  }

  String _t(String key, String fallback) => ClideSettings.i18n.string(context, key, namespace: 'builtin.menubar', placeholder: fallback);

  @override
  Widget build(BuildContext context) {
    final r = _result;
    final canInstall = r is UpdateAvailable && r.bundle != null && !_installing;
    return Row(
      children: [
        ClideButton(label: _t('about.checkUpdates', 'Check for updates'), onPressed: _checking || _installing ? null : _check),
        const SizedBox(width: 12),
        Expanded(child: _status(context)),
        if (canInstall) ...[
          const SizedBox(width: 12),
          Semantics(
            excludeSemantics: true,
            button: true,
            label: ClideSettings.i18n.interpolated(
              context,
              'about.install.semantics',
              namespace: 'builtin.menubar',
              placeholder: 'Install clide {version} and restart every window. Running Claude turns and terminals stop; conversations resume.',
              replacers: [I18nReplacer(from: '{version}', replace: r.latest)],
            ),
            child: ClideButton(key: const Key('about-install'), label: _t('about.install', 'Install and restart'), onPressed: _install),
          ),
        ],
      ],
    );
  }

  Widget _status(BuildContext context) {
    final tokens = widget.tokens;
    if (_checking) return ClideText(_t('about.checking', 'Checking…'), fontSize: 12, color: tokens.globalTextMuted);
    if (_installing) return ClideText(_phaseText(context), fontSize: 12, color: tokens.globalTextMuted);
    final err = _installError;
    if (err != null) {
      return ClideText(
        '${_t('about.installFailed', 'Update failed')} ($err)',
        fontSize: 12,
        color: tokens.statusError,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }
    switch (_result) {
      case null:
        return const SizedBox.shrink();
      case UpdateUpToDate():
        return ClideText(_t('about.upToDate', "You're on the latest version."), fontSize: 12, color: tokens.globalTextMuted);
      case UpdateAvailable(:final latest, :final url):
        return Semantics(
          button: true,
          excludeSemantics: true,
          label: 'clide $latest available — release notes',
          child: ClideTappable(
            cursor: SystemMouseCursors.click,
            onTap: () => unawaited(ClideKernel.of(context).os.openURL(url)),
            builder: (ctx, hovered, _) => ClideText(
              ClideSettings.i18n.interpolated(
                context,
                'about.updateAvailable',
                namespace: 'builtin.menubar',
                placeholder: 'clide {version} is available — release notes',
                replacers: [I18nReplacer(from: '{version}', replace: latest)],
              ),
              fontSize: 12,
              color: tokens.globalFocus,
            ),
          ),
        );
      case UpdateCheckFailed(:final message):
        return ClideText(
          '${_t('about.updateFailed', "Couldn't check for updates")} ($message)',
          fontSize: 12,
          color: tokens.statusError,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
    }
  }

  String _phaseText(BuildContext context) {
    switch (_phase) {
      case 'verifying':
        return _t('about.phase.verifying', 'Verifying…');
      case 'unpacking':
        return _t('about.phase.unpacking', 'Unpacking…');
      case 'installing':
        return _t('about.phase.installing', 'Installing…');
      case 'restarting':
        return _t('about.phase.restarting', 'Restarting windows…');
      default:
        final f = _fraction;
        return ClideSettings.i18n.interpolated(
          context,
          'about.phase.downloading',
          namespace: 'builtin.menubar',
          placeholder: 'Downloading… {percent}',
          replacers: [I18nReplacer(from: '{percent}', replace: f == null ? '' : '${(f * 100).round()}%')],
        );
    }
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
            child: ClideText(value, fontSize: 13, fontFamily: ClideSettings.fonts.monoOf(context), maxLines: 1, overflow: TextOverflow.ellipsis),
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
          return ClideText(
            snap.hasError
                ? ClideSettings.i18n.string(context, 'licenses.unavailable', namespace: 'builtin.menubar', placeholder: 'Licenses unavailable.')
                : ClideSettings.i18n.string(context, 'licenses.loading', namespace: 'builtin.menubar', placeholder: 'Loading…'),
            fontSize: 12,
            color: tokens.globalTextMuted,
          );
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
                  fontFamily: ClideSettings.fonts.monoOf(context),
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
