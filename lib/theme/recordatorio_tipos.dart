import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'category_colors.dart';

class RecordatorioTipoVisual {
  final String tipo;
  final IconData icono;
  final Color color;
  final Color colorTexto;
  final String etiqueta;
  final String tituloSugerido;

  const RecordatorioTipoVisual({
    required this.tipo,
    required this.icono,
    required this.color,
    required this.colorTexto,
    required this.etiqueta,
    required this.tituloSugerido,
  });
}

abstract final class RecordatorioTipos {
  static const veterinaria = RecordatorioTipoVisual(
    tipo: 'veterinaria',
    icono: Icons.local_hospital,
    color: CategoryColors.veterinaria,
    colorTexto: CategoryColors.veterinariaTexto,
    etiqueta: 'Veterinario',
    tituloSugerido: 'Visita al veterinario',
  );

  static const medicacion = RecordatorioTipoVisual(
    tipo: 'medicacion',
    icono: Icons.medication_outlined,
    color: CategoryColors.unico,
    colorTexto: CategoryColors.unicoTexto,
    etiqueta: 'Medicación',
    tituloSugerido: 'Aplicar medicación',
  );

  static const higiene = RecordatorioTipoVisual(
    tipo: 'higiene',
    icono: Icons.shower,
    color: CategoryColors.higiene,
    colorTexto: CategoryColors.higieneTexto,
    etiqueta: 'Baño o corte de pelo',
    tituloSugerido: 'Baño',
  );

  static const otro = RecordatorioTipoVisual(
    tipo: 'otro',
    icono: Icons.event_note,
    color: AppColors.navy,
    colorTexto: AppColors.navy,
    etiqueta: 'Otro',
    tituloSugerido: '',
  );

  static const todos = [veterinaria, medicacion, higiene, otro];

  static RecordatorioTipoVisual de(String tipo) {
    for (final visual in todos) {
      if (visual.tipo == tipo) return visual;
    }
    return otro;
  }
}
