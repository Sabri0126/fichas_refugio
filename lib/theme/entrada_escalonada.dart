import 'package:flutter/material.dart';

/// Aparición de un ítem de lista: sube 8 px y gana opacidad.
/// El retraso crece con [indice], y la animación completa no pasa de 300 ms.
/// No bloquea los toques: el widget recibe gestos desde el primer frame.
class EntradaEscalonada extends StatelessWidget {
  const EntradaEscalonada({super.key, required this.indice, required this.child});

  final int indice;
  final Widget child;

  static const int _duracionMs = 220;
  static const int _pasoMs = 30;
  static const int _retrasoMaxMs = 80;

  @override
  Widget build(BuildContext context) {
    final retrasoMs = (indice * _pasoMs).clamp(0, _retrasoMaxMs);
    final totalMs = retrasoMs + _duracionMs;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: totalMs),
      curve: Curves.linear,
      builder: (context, t, child) {
        final inicio = retrasoMs / totalMs;
        final crudo = ((t - inicio) / (1 - inicio)).clamp(0.0, 1.0);
        final eased = Curves.easeOutCubic.transform(crudo);
        return Opacity(
          opacity: eased,
          child: Transform.translate(
            offset: Offset(0, (1 - eased) * 8),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
