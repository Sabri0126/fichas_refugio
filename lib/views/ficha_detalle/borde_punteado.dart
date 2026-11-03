part of '../ficha_detalle_perro.dart';

class _BordePunteado extends CustomPainter {
  final Color color;

  const _BordePunteado({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final pintura = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final camino = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
          const Radius.circular(20),
        ),
      );
    for (final tramo in camino.computeMetrics()) {
      const dash = 7.0;
      const espacio = 5.0;
      var distancia = 0.0;
      while (distancia < tramo.length) {
        final fin = (distancia + dash).clamp(0.0, tramo.length);
        canvas.drawPath(tramo.extractPath(distancia, fin), pintura);
        distancia += dash + espacio;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BordePunteado anterior) => anterior.color != color;
}

