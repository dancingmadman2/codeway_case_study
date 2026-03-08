import 'dart:typed_data';

import 'package:image/image.dart' as img;

Uint8List imageToBytes(img.Image image) {
  return Uint8List.fromList(img.encodePng(image));
}

img.Image bytesToImage(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw FormatException('Failed to decode image data');
  }
  return decoded;
}
