import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:jovial_svg/jovial_svg.dart';

class ClideSvgView extends StatelessWidget {
  const ClideSvgView.asset(this.assetPath, {super.key, this.width, this.height}) : svgString = null;
  const ClideSvgView.string(this.svgString, {super.key, this.width, this.height}) : assetPath = null;

  final String? assetPath;
  final String? svgString;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (assetPath != null) {
      child = ScalableImageWidget.fromSISource(
        si: ScalableImageSource.fromSvg(rootBundle, assetPath!),
      );
    } else if (svgString != null) {
      final si = ScalableImage.fromSvgString(svgString!);
      child = ScalableImageWidget(si: si);
    } else {
      return const SizedBox.shrink();
    }

    if (width != null || height != null) {
      child = SizedBox(width: width, height: height, child: child);
    }
    return child;
  }
}
