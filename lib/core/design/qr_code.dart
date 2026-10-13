import 'package:barcode/barcode.dart';
import 'package:flutter/widgets.dart';

import 'tokens.dart';

/// QR-код ссылки (шаг 23: ссылка объекта для Telegram-бота). Всегда тёмные
/// модули на белом с полем в 2 модуля — так его читает любая камера и в
/// тёмной теме. Рисуется сам, без картинок и сети.
class AppQrCode extends StatelessWidget {
  const AppQrCode(this.data, {super.key, this.size = 200, this.semanticLabel});

  final String data;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: semanticLabel,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpace.s),
        child: CustomPaint(
          size: Size.square(size),
          painter: _QrPainter(data),
        ),
      ),
    );
  }
}

/// Модули QR-кода [data] в квадрате [size] (с полем): прямоугольники
/// тёмных модулей. Пустой список — данные не поместились в QR.
List<Rect> qrModules(String data, double size) {
  try {
    final bc =
        Barcode.qrCode(errorCorrectLevel: BarcodeQRCorrectionLevel.medium);
    final bars = bc
        .make(data, width: size, height: size, drawText: false)
        .whereType<BarcodeBar>()
        .where((b) => b.black)
        .toList();
    if (bars.isEmpty) return const [];
    // Поле 2 модуля с каждой стороны: сжимаем код внутрь квадрата.
    final cell = bars.map((b) => b.width).reduce((a, b) => a < b ? a : b);
    final modules = (size / cell).round();
    final k = modules / (modules + 4);
    final pad = (size - size * k) / 2;
    return [
      for (final b in bars)
        Rect.fromLTWH(
            pad + b.left * k, pad + b.top * k, b.width * k, b.height * k),
    ];
  } on BarcodeException {
    return const [];
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.data);
  final String data;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.surface);
    final ink = Paint()
      ..color = AppColors.ink
      ..isAntiAlias = false;
    for (final r in qrModules(data, size.shortestSide)) {
      // +0,5 px — без светлых щелей между соседними модулями.
      canvas.drawRect(
          Rect.fromLTWH(r.left, r.top, r.width + 0.5, r.height + 0.5), ink);
    }
  }

  @override
  bool shouldRepaint(_QrPainter old) => old.data != data;
}
