import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show Uint8List, compute;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/custom_assets/assets.gen.dart';
import '../../../core/utils/logo_assets.dart';
import 'share_story_model.dart';
import 'share_story_widget.dart';

/// JPEG quality of the story: about 400 KB at 1080x1920 (the same image is
/// about 3 MB as a PNG, the court's texture being heavy to compress).
const int kShareStoryJpegQuality = 90;

/// Encodes opaque RGBA pixels as a JPEG.
Uint8List encodeShareStoryJpeg(Uint8List rgba, int width, int height) {
  final image = img.Image.fromBytes(
    width: width,
    height: height,
    bytes: rgba.buffer,
    numChannels: 4,
  );
  return img.encodeJpg(image, quality: kShareStoryJpegQuality);
}

Uint8List _encodeInIsolate((Uint8List, int, int) a) =>
    encodeShareStoryJpeg(a.$1, a.$2, a.$3);

/// The 1080x1920 JPEG of [data]: the story is drawn once just outside the
/// screen (a 360x640 canvas at pixel ratio 3) and read back as an image.
/// Returns the file, in the temporary folder.
Future<File> captureShareStory(
  BuildContext context,
  ShareStoryData data,
) async {
  final overlay = Overlay.of(context, rootOverlay: true);
  // Images are decoded before the first frame, so none is missing in the PNG.
  final team = [data.home, if (data.away != null) data.away!];
  final images = <AssetGenImage>[
    Assets.images.fullplayground,
    Assets.icons.nameLogo,
    Assets.icons.apple,
    Assets.icons.google,
    Assets.icons.chefcurry,
    Assets.icons.sixman,
    Assets.icons.luxarytax,
    for (final t in team) ...[jerseyAsset(t.jerseyIndex), logoAsset(t.teamLogo)],
  ];
  await Future.wait([
    for (final i in images)
      precacheImage(i.provider(), context).catchError((_) {}),
  ]);

  final key = GlobalKey();
  final entry = OverlayEntry(
    builder: (_) => Positioned(
      left: -2 * ShareStoryWidget.width,
      top: 0,
      width: ShareStoryWidget.width,
      height: ShareStoryWidget.height,
      child: RepaintBoundary(
        key: key,
        child: Material(
          color: Colors.black,
          child: ShareStoryWidget(data: data),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  try {
    // Let it lay out and paint once before reading it.
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);
    final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    // The encoding is heavy: off the main isolate, the screen stays smooth.
    final jpeg = await compute(
      _encodeInIsolate,
      (raw!.buffer.asUint8List(), image.width, image.height),
    );
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/m5m_story_${data.date.millisecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(jpeg, flush: true);
    return file;
  } finally {
    entry.remove();
  }
}

/// Captures the story and opens the system share sheet with the image.
/// [context] must belong to the tapped button (iPad popover anchor).
Future<void> shareShareStory(BuildContext context, ShareStoryData data) async {
  final box = context.findRenderObject() as RenderBox?;
  final origin = box != null && box.hasSize
      ? box.localToGlobal(Offset.zero) & box.size
      : null;
  final file = await captureShareStory(context, data);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: 'image/jpeg')],
      sharePositionOrigin: origin,
    ),
  );
}
