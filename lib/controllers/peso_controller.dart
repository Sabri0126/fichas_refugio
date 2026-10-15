import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/peso_model.dart';

/// Diferencia entre la última medición y la anterior.
class VariacionPeso {
  final double diferenciaKg;
  final double porcentaje;

  const VariacionPeso({required this.diferenciaKg, required this.porcentaje});
}

/// Lógica de pesos. No escribe en Firebase, salvo el id que pide a Firestore.
class PesoController {
  String generarId() => FirebaseFirestore.instance.collection('perros').doc().id;

  PesoModel crear({
    required double kg,
    required DateTime fecha,
    required bool estimado,
    String nota = '',
  }) {
    return PesoModel(
      id: generarId(),
      fecha: DateTime(fecha.year, fecha.month, fecha.day),
      kg: kg,
      estimado: estimado,
      nota: nota.trim(),
    );
  }

  PesoModel editar(
    PesoModel actual, {
    double? kg,
    DateTime? fecha,
    bool? estimado,
    String? nota,
  }) {
    return actual.copyWith(
      kg: kg,
      fecha: fecha == null ? null : DateTime(fecha.year, fecha.month, fecha.day),
      estimado: estimado,
      nota: nota?.trim(),
    );
  }

  List<PesoModel> eliminar(List<PesoModel> lista, String id) {
    return [
      for (final peso in lista)
        if (peso.id != id) peso,
    ];
  }

  /// La medición más reciente. Null si la lista está vacía.
  PesoModel? ultimo(List<PesoModel> pesos) {
    if (pesos.isEmpty) return null;
    final ordenados = [...pesos]..sort(_porFecha);
    return ordenados.last;
  }

  /// Diferencia contra la medición anterior. Null si hay menos de dos.
  VariacionPeso? variacion(List<PesoModel> pesos) {
    if (pesos.length < 2) return null;
    final ordenados = [...pesos]..sort(_porFecha);
    final anterior = ordenados[ordenados.length - 2];
    final reciente = ordenados.last;
    if (anterior.kg == 0) return null;
    final diferencia = reciente.kg - anterior.kg;
    return VariacionPeso(
      diferenciaKg: diferencia,
      porcentaje: (diferencia / anterior.kg) * 100,
    );
  }

  /// "+0,4 kg (3%)", "−0,4 kg (3%)" o "Sin cambios".
  String describirVariacion(VariacionPeso variacion) {
    if (variacion.diferenciaKg.abs() < 0.05) return 'Sin cambios';
    final signo = variacion.diferenciaKg > 0 ? '+' : '−';
    final kilos = formatearKg(variacion.diferenciaKg.abs());
    final porcentaje = variacion.porcentaje.abs().round();
    return '$signo$kilos kg ($porcentaje%)';
  }

  static String formatearFecha(DateTime fecha) {
    final dd = fecha.day.toString().padLeft(2, '0');
    final mm = fecha.month.toString().padLeft(2, '0');
    return '$dd/$mm/${fecha.year}';
  }

  /// Agrega al final las altas remotas que no estaban al abrir el formulario.
  static List<PesoModel> fusionarAltasRemotas({
    required List<PesoModel> local,
    required List<PesoModel> remoto,
    required Set<String> idsIniciales,
  }) {
    final presentes = <String>{
      for (final item in local)
        if (item.id.isNotEmpty) item.id,
    };
    final altas = <PesoModel>[];
    for (final item in remoto) {
      if (item.id.isEmpty || idsIniciales.contains(item.id) || presentes.contains(item.id)) {
        continue;
      }
      altas.add(item);
      presentes.add(item.id);
    }
    return [...local, ...altas];
  }

  static int _porFecha(PesoModel a, PesoModel b) {
    final porFecha = a.fecha.compareTo(b.fecha);
    if (porFecha != 0) return porFecha;
    return a.id.compareTo(b.id);
  }
}
