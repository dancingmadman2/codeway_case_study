import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:opencv_dart/opencv_dart.dart' as cv;

import 'package:codeway_img_proc/data/services/isolate_models.dart';

class ImageProcessingService {
  Future<List<Uint8List>> cropFaces(
      Uint8List imageBytes, List<Rect> faceBounds) {
    final input = CropFacesInput(
      imageBytes,
      faceBounds
          .map((r) => IsolateRect(r.left, r.top, r.right, r.bottom))
          .toList(),
    );
    return compute(_cropFacesIsolate, input);
  }

  static List<Uint8List> _cropFacesIsolate(CropFacesInput input) {
    final decoded = img.decodeImage(input.imageBytes);
    if (decoded == null) return [];

    final faces = <Uint8List>[];
    for (final bounds in input.faceBounds) {
      final x = max(0, bounds.left.round());
      final y = max(0, bounds.top.round());
      final right = min(decoded.width, bounds.right.round());
      final bottom = min(decoded.height, bounds.bottom.round());
      final w = right - x;
      final h = bottom - y;

      if (w <= 0 || h <= 0) continue;

      final cropped = img.copyCrop(decoded, x: x, y: y, width: w, height: h);
      faces.add(Uint8List.fromList(img.encodePng(cropped)));
    }
    return faces;
  }

  Future<List<Uint8List>> applyGrayscale(List<Uint8List> images) {
    return compute(_applyGrayscaleIsolate, images);
  }

  static List<Uint8List> _applyGrayscaleIsolate(List<Uint8List> images) {
    return images.map((imageBytes) {
      final decoded = img.decodeImage(imageBytes);
      if (decoded == null) return imageBytes;
      final gray = img.grayscale(decoded);
      return Uint8List.fromList(img.encodePng(gray));
    }).toList();
  }

  Future<Uint8List> compositeFaces(
    Uint8List originalBytes,
    List<Uint8List> faceImages,
    List<Rect> bounds,
  ) {
    final input = CompositeFacesInput(
      originalBytes,
      faceImages,
      bounds
          .map((r) => IsolateRect(r.left, r.top, r.right, r.bottom))
          .toList(),
    );
    return compute(_compositeFacesIsolate, input);
  }

  static Uint8List _compositeFacesIsolate(CompositeFacesInput input) {
    final decoded = img.decodeImage(input.originalBytes);
    if (decoded == null) return input.originalBytes;

    for (var i = 0;
        i < input.faceImages.length && i < input.bounds.length;
        i++) {
      final face = img.decodeImage(input.faceImages[i]);
      if (face == null) continue;

      final dstX = max(0, input.bounds[i].left.round());
      final dstY = max(0, input.bounds[i].top.round());
      final fw = face.width;
      final fh = face.height;

      // Ellipse center and radii (inscribed in face bounding box)
      final cx = fw / 2.0;
      final cy = fh / 2.0;
      final rx = fw / 2.0;
      final ry = fh / 2.0;

      for (var py = 0; py < fh; py++) {
        for (var px = 0; px < fw; px++) {
          final dx = (px - cx) / rx;
          final dy = (py - cy) / ry;
          final d = dx * dx + dy * dy;

          // Outside ellipse — keep original
          if (d > 1.0) continue;

          final origX = dstX + px;
          final origY = dstY + py;
          if (origX >= decoded.width || origY >= decoded.height) continue;

          final facePixel = face.getPixel(px, py);

          if (d <= 0.8) {
            // Fully inside — use grayscale face pixel
            decoded.setPixel(origX, origY, facePixel);
          } else {
            // Feather zone (0.8 < d <= 1.0): lerp from grayscale to original
            final t = (d - 0.8) / 0.2; // 0.0 at d=0.8, 1.0 at d=1.0
            final origPixel = decoded.getPixel(origX, origY);
            final blendR = (facePixel.r * (1.0 - t) + origPixel.r * t).round();
            final blendG = (facePixel.g * (1.0 - t) + origPixel.g * t).round();
            final blendB = (facePixel.b * (1.0 - t) + origPixel.b * t).round();
            decoded.setPixelRgb(origX, origY, blendR, blendG, blendB);
          }
        }
      }
    }

    return Uint8List.fromList(img.encodePng(decoded));
  }

  Future<Uint8List> enhanceContrast(Uint8List imageBytes) {
    return compute(_enhanceContrastIsolate, imageBytes);
  }

  static Uint8List _enhanceContrastIsolate(Uint8List imageBytes) {
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) return imageBytes;

    final enhanced = img.adjustColor(decoded, contrast: 1.5);
    return Uint8List.fromList(img.encodePng(enhanced));
  }

  Future<Uint8List> enhanceDocument(Uint8List imageBytes) {
    return compute(_enhanceDocumentIsolate, imageBytes);
  }

  static Uint8List _enhanceDocumentIsolate(Uint8List imageBytes) {
    final src = cv.imdecode(imageBytes, cv.IMREAD_COLOR);
    if (src.isEmpty) return imageBytes;
    try {
      // Color-preserving enhancement via LAB color space
      final lab = cv.cvtColor(src, cv.COLOR_BGR2Lab);
      final channels = cv.split(lab);
      lab.dispose();

      final lChannel = channels[0]; // Lightness
      final aChannel = channels[1];
      final bChannel = channels[2];

      // CLAHE on lightness only — preserves color, improves contrast
      final clahe = cv.CLAHE(3.0, (4, 4));
      final enhancedL = clahe.apply(lChannel);
      lChannel.dispose();
      clahe.dispose();

      // Merge enhanced L with original A,B
      final mergeInput = cv.VecMat.fromList([enhancedL, aChannel, bChannel]);
      final merged = cv.merge(mergeInput);
      mergeInput.dispose();
      enhancedL.dispose();
      aChannel.dispose();
      bChannel.dispose();
      channels.dispose();

      final result = cv.cvtColor(merged, cv.COLOR_Lab2BGR);
      merged.dispose();

      // Pass 1: Fine detail sharpening (small sigma targets text stroke edges)
      final blur1 = cv.gaussianBlur(result, (0, 0), 1.0);
      final sharp1 = cv.addWeighted(result, 1.8, blur1, -0.8, 0);
      blur1.dispose();
      result.dispose();

      // Pass 2: Medium-scale crispness (larger sigma for word-level contrast)
      final blur2 = cv.gaussianBlur(sharp1, (0, 0), 2.5);
      final sharpened = cv.addWeighted(sharp1, 1.3, blur2, -0.3, 0);
      blur2.dispose();
      sharp1.dispose();

      final (_, encoded) = cv.imencode('.png', sharpened);
      sharpened.dispose();
      return encoded;
    } finally {
      src.dispose();
    }
  }

  Future<Uint8List> createThumbnail(Uint8List imageBytes,
      {int width = 400}) {
    return compute(_createThumbnailIsolate, ThumbnailInput(imageBytes, width: width));
  }

  static Uint8List _createThumbnailIsolate(ThumbnailInput input) {
    final decoded = img.decodeImage(input.imageBytes);
    if (decoded == null) return input.imageBytes;

    final resized = img.copyResize(decoded,
        width: input.width, interpolation: img.Interpolation.average);
    return Uint8List.fromList(img.encodePng(resized));
  }
}
