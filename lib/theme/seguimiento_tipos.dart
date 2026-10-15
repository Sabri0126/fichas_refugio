import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'category_colors.dart';

class SeguimientoTipoVisual {
  final String motivo;
  final IconData icono;
  final Color color;
  final Color colorTexto;
  final String etiqueta;

  const SeguimientoTipoVisual({
    required this.motivo,
    required this.icono,
    required this.color,
    required this.colorTexto,
    required this.etiqueta,
  });
}

abstract final class SeguimientoTipos {
  static const ojo = SeguimientoTipoVisual(
    motivo: 'ojo',
    icono: Icons.visibility,
    color: CategoryColors.unico,
    colorTexto: CategoryColors.unicoTexto,
    etiqueta: 'Ojo',
  );

  static const herida = SeguimientoTipoVisual(
    motivo: 'herida',
    icono: Icons.healing,
    color: AppColors.terracota,
    colorTexto: AppColors.terracota,
    etiqueta: 'Herida',
  );

  static const animo = SeguimientoTipoVisual(
    motivo: 'animo',
    icono: Icons.mood_bad,
    color: CategoryColors.veterinaria,
    colorTexto: CategoryColors.veterinariaTexto,
    etiqueta: 'Ánimo',
  );

  static const pata = SeguimientoTipoVisual(
    motivo: 'pata',
    icono: Icons.pets,
    color: CategoryColors.diario,
    colorTexto: CategoryColors.diarioTexto,
    etiqueta: 'Pata',
  );

  static const una = SeguimientoTipoVisual(
    motivo: 'una',
    icono: Icons.content_cut,
    color: CategoryColors.higiene,
    colorTexto: CategoryColors.higieneTexto,
    etiqueta: 'Uña',
  );

  static const comportamiento = SeguimientoTipoVisual(
    motivo: 'comportamiento',
    icono: Icons.psychology,
    color: CategoryColors.evento,
    colorTexto: CategoryColors.eventoTexto,
    etiqueta: 'Comportamiento',
  );

  static const otro = SeguimientoTipoVisual(
    motivo: 'otro',
    icono: Icons.search,
    color: AppColors.navy,
    colorTexto: AppColors.navy,
    etiqueta: 'Otro',
  );

  static const todos = [ojo, herida, animo, pata, una, comportamiento, otro];

  static SeguimientoTipoVisual de(String motivo) {
    for (final visual in todos) {
      if (visual.motivo == motivo) return visual;
    }
    return otro;
  }
}
