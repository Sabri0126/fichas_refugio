import 'package:flutter/material.dart';

/// Colores por categoría de registro médico. Se usan idénticos en los botones
/// de alta, los íconos de las listas y los puntos del calendario.
abstract final class CategoryColors {
  static const Color diario = Color(0xFF4CAF50);
  static const Color unico = Color(0xFF2196F3);
  static const Color higiene = Color(0xFF00BCD4);
  static const Color evento = Color(0xFF9C27B0);
  static const Color veterinaria = Color(0xFFFF9800);
  static const Color vacuna = Color(0xFFE91E63);

  /// Variantes oscurecidas para texto sobre fondo claro (contraste ≥ 4.5:1).
  static const Color diarioTexto = Color(0xFF2E7D32);
  static const Color unicoTexto = Color(0xFF1565C0);
  static const Color higieneTexto = Color(0xFF00727F);
  static const Color eventoTexto = Color(0xFF7B1FA2);
  static const Color veterinariaTexto = Color(0xFFB45309);
  static const Color vacunaTexto = Color(0xFFAD1457);

  static Color base(String? categoria) => switch (categoria) {
        'unico' => unico,
        'higiene' => higiene,
        'evento' => evento,
        'veterinaria' => veterinaria,
        'vacuna' => vacuna,
        _ => diario,
      };

  static Color texto(String? categoria) => switch (categoria) {
        'unico' => unicoTexto,
        'higiene' => higieneTexto,
        'evento' => eventoTexto,
        'veterinaria' => veterinariaTexto,
        'vacuna' => vacunaTexto,
        _ => diarioTexto,
      };

  /// Fondo tintado al 12 % para el círculo detrás del ícono.
  static Color tinte(String? categoria) => base(categoria).withValues(alpha: 0.12);

  static IconData icono(String? categoria) => switch (categoria) {
        'unico' => Icons.medication_liquid,
        'higiene' => Icons.shower,
        'evento' => Icons.monitor_heart,
        'veterinaria' => Icons.local_hospital,
        'vacuna' => Icons.vaccines,
        _ => Icons.medication,
      };

  static String etiqueta(String? categoria) => switch (categoria) {
        'unico' => 'Dosis única',
        'higiene' => 'Higiene',
        'evento' => 'Evento médico',
        'veterinaria' => 'Veterinaria',
        'vacuna' => 'Vacuna',
        _ => 'Tratamiento diario',
      };
}
