import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// RGBA-пиксели → JPEG (пакет image — тяжёлый, файл подключается
/// отложенно: `deferred as stamp_encode`).
Uint8List rgbaToJpeg(Uint8List rgba, int width, int height,
        {int quality = 85}) =>
    Uint8List.fromList(img.encodeJpg(
        img.Image.fromBytes(
            width: width,
            height: height,
            bytes: rgba.buffer,
            bytesOffset: rgba.offsetInBytes,
            numChannels: 4,
            order: img.ChannelOrder.rgba),
        quality: quality));
