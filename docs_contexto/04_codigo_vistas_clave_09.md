# 04 — Código de vistas clave (9 de 9)

Código fuente copiado tal cual. Cada bloque indica archivo y rango de líneas.

### `lib/theme/app_colors.dart` — parte 1/1, líneas 1–24 de 24

```dart
import 'package:flutter/material.dart';

/// Paleta base y colores semánticos de estado de la app.
abstract final class AppColors {
  // --- Paleta base ---
  static const Color navy = Color(0xFF2F4565);
  static const Color arena = Color(0xFFEADDC0);
  static const Color terracota = Color(0xFFC8553D);
  static const Color superficie = Colors.white;
  static const Color bordeTarjeta = Color(0xFFE2D5B5);
  static const Color rellenoInput = Color(0xFFFAF8F3);
  static const Color bordeInput = Color(0xFFD9CDB0);
  static const Color texto = Color(0xFF191919);
  static const Color textoSecundario = Color(0xFF6B6459);

  // --- Estados ---
  static const Color dosisDada = Color(0xFF4F9D69);
  static const Color activo = dosisDada;
  static const Color pausado = Color(0xFFD9A441);
  static const Color dosisOlvidada = Color(0xFFE07A5F);
  static const Color pendiente = Color(0xFFCFC7B8);

  static const Color error = Color(0xFFB3261E);
}
```

### `lib/theme/category_colors.dart` — parte 1/1, líneas 1–53 de 53

```dart
import 'package:flutter/material.dart';

/// Colores por categoría de registro médico. Se usan idénticos en los botones
/// de alta, los íconos de las listas y los puntos del calendario.
abstract final class CategoryColors {
  static const Color diario = Color(0xFF4CAF50);
  static const Color unico = Color(0xFF2196F3);
  static const Color higiene = Color(0xFF00BCD4);
  static const Color evento = Color(0xFF9C27B0);
  static const Color veterinaria = Color(0xFFFF9800);

  /// Variantes oscurecidas para texto sobre fondo claro (contraste ≥ 4.5:1).
  static const Color diarioTexto = Color(0xFF2E7D32);
  static const Color unicoTexto = Color(0xFF1565C0);
  static const Color higieneTexto = Color(0xFF00727F);
  static const Color eventoTexto = Color(0xFF7B1FA2);
  static const Color veterinariaTexto = Color(0xFFB45309);

  static Color base(String? categoria) => switch (categoria) {
        'unico' => unico,
        'higiene' => higiene,
        'evento' => evento,
        'veterinaria' => veterinaria,
        _ => diario,
      };

  static Color texto(String? categoria) => switch (categoria) {
        'unico' => unicoTexto,
        'higiene' => higieneTexto,
        'evento' => eventoTexto,
        'veterinaria' => veterinariaTexto,
        _ => diarioTexto,
      };

  /// Fondo tintado al 12 % para el círculo detrás del ícono.
  static Color tinte(String? categoria) => base(categoria).withValues(alpha: 0.12);

  static IconData icono(String? categoria) => switch (categoria) {
        'unico' => Icons.vaccines,
        'higiene' => Icons.shower,
        'evento' => Icons.monitor_heart,
        'veterinaria' => Icons.local_hospital,
        _ => Icons.medication,
      };

  static String etiqueta(String? categoria) => switch (categoria) {
        'unico' => 'Dosis única',
        'higiene' => 'Higiene',
        'evento' => 'Evento médico',
        'veterinaria' => 'Veterinaria',
        _ => 'Tratamiento diario',
      };
}
```

### `lib/theme/entrada_escalonada.dart` — parte 1/1, líneas 1–40 de 40

```dart
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
```

