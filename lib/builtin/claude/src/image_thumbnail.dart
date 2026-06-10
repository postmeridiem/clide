/// Inline image preview for pasted-image references (T-236 / T-254).
///
/// A bounded, keyboard-activatable thumbnail that opens the full image in the
/// shared lightbox (T-252) on tap. Used both for `@<path>` image tokens in the
/// conversation log and for the composer's attachment chips, so the two stay
/// visually consistent. Reads the file directly via `Image.file` (dart:io) —
/// pasted temp files live outside the workspace, so this is not gated by the
/// `files.read` allow-list (D-80); it's display-only. A missing/unreadable file
/// degrades to a muted placeholder instead of throwing.
library;

import 'dart:io';

import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

/// Open [path] full-size in the lightbox via the kernel dialog router.
void openImageLightbox(BuildContext context, String path) {
  ClideKernel.of(context).dialog.show<Object>(
        (ctx, dismiss) => ClideLightbox(
          onDismiss: dismiss,
          child: Image.file(
            File(path),
            fit: BoxFit.contain,
            errorBuilder: (ctx, _, __) => _placeholder(ctx, 48),
          ),
        ),
      );
}

Widget _placeholder(BuildContext context, double size) {
  final t = ClideTheme.of(context).surface;
  return Container(
    width: size,
    height: size,
    color: t.panelBackground,
    alignment: Alignment.center,
    child: ClideIcon(PhosphorIcons.byName('image'), size: size * 0.45, color: t.globalTextMuted),
  );
}

class ImageThumbnail extends StatelessWidget {
  const ImageThumbnail({super.key, required this.path, this.size = 56, this.radius = 4});

  final String path;
  final double size;
  final double radius;

  String get _fileName => path.split('/').where((s) => s.isNotEmpty).lastOrNull ?? path;

  @override
  Widget build(BuildContext context) {
    final t = ClideTheme.of(context).surface;
    return Semantics(
      button: true,
      label: 'Image $_fileName',
      excludeSemantics: true,
      child: ClideTappable(
        onTap: () => openImageLightbox(context, path),
        builder: (ctx, hovered, pressed) => DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: hovered ? t.globalFocus : t.globalBorder),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Image.file(
              File(path),
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (ctx, _, __) => _placeholder(ctx, size),
            ),
          ),
        ),
      ),
    );
  }
}
