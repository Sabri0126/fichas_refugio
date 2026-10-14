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

/// Colores que cambian entre el tema claro y el oscuro.
class PaletaApp extends ThemeExtension<PaletaApp> {
  final Color fondo;
  final Color superficie;
  final Color relleno;
  final Color borde;
  final Color texto;
  final Color textoSuave;
  final Color lienzo;
  final Color lienzoSuave;
  final Color activoTexto;
  final Color pausadoTexto;

  const PaletaApp({
    required this.fondo,
    required this.superficie,
    required this.relleno,
    required this.borde,
    required this.texto,
    required this.textoSuave,
    required this.lienzo,
    required this.lienzoSuave,
    required this.activoTexto,
    required this.pausadoTexto,
  });

  static const clara = PaletaApp(
    fondo: AppColors.arena,
    superficie: AppColors.superficie,
    relleno: AppColors.rellenoInput,
    borde: AppColors.bordeTarjeta,
    texto: AppColors.texto,
    textoSuave: AppColors.textoSecundario,
    lienzo: AppColors.navy,
    lienzoSuave: AppColors.textoSecundario,
    activoTexto: AppColors.activoTexto,
    pausadoTexto: AppColors.pausadoTexto,
  );

  static const oscura = PaletaApp(
    fondo: Color(0xFF141B24),
    superficie: Color(0xFF1F2A37),
    relleno: Color(0xFF263342),
    borde: Color(0xFF34445A),
    texto: Color(0xFFECE6DA),
    textoSuave: Color(0xFFB7AFA2),
    lienzo: Color(0xFFECE6DA),
    lienzoSuave: Color(0xFFB7AFA2),
    activoTexto: Color(0xFF9DDBB4),
    pausadoTexto: Color(0xFFE4C56A),
  );

  @override
  PaletaApp copyWith({
    Color? fondo,
    Color? superficie,
    Color? relleno,
    Color? borde,
    Color? texto,
    Color? textoSuave,
    Color? lienzo,
    Color? lienzoSuave,
    Color? activoTexto,
    Color? pausadoTexto,
  }) {
    return PaletaApp(
      fondo: fondo ?? this.fondo,
      superficie: superficie ?? this.superficie,
      relleno: relleno ?? this.relleno,
      borde: borde ?? this.borde,
      texto: texto ?? this.texto,
      textoSuave: textoSuave ?? this.textoSuave,
      lienzo: lienzo ?? this.lienzo,
      lienzoSuave: lienzoSuave ?? this.lienzoSuave,
      activoTexto: activoTexto ?? this.activoTexto,
      pausadoTexto: pausadoTexto ?? this.pausadoTexto,
    );
  }

  @override
  PaletaApp lerp(ThemeExtension<PaletaApp>? other, double t) {
    if (other is! PaletaApp) return this;
    Color mezcla(Color a, Color b) => Color.lerp(a, b, t)!;
    return PaletaApp(
      fondo: mezcla(fondo, other.fondo),
      superficie: mezcla(superficie, other.superficie),
      relleno: mezcla(relleno, other.relleno),
      borde: mezcla(borde, other.borde),
      texto: mezcla(texto, other.texto),
      textoSuave: mezcla(textoSuave, other.textoSuave),
      lienzo: mezcla(lienzo, other.lienzo),
      lienzoSuave: mezcla(lienzoSuave, other.lienzoSuave),
      activoTexto: mezcla(activoTexto, other.activoTexto),
      pausadoTexto: mezcla(pausadoTexto, other.pausadoTexto),
    );
  }
}

extension PaletaContext on BuildContext {
  PaletaApp get paleta => Theme.of(this).extension<PaletaApp>() ?? PaletaApp.clara;

  bool get temaOscuro => Theme.of(this).brightness == Brightness.dark;
}
