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
  static const Color dosisOlvidada = Color(0xFFD4644A);
  static const Color pendiente = Color(0xFFCFC7B8);
  static const Color activoTexto = Color(0xFF2E6B44);
  static const Color pausadoTexto = Color(0xFF8A6414);

  static const Color error = Color(0xFFB3261E);
  static const Color sombra = Color(0x0F000000);
}
