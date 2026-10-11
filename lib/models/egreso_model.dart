import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? _fechaDesdeValor(dynamic valor) {
  if (valor is Timestamp) return valor.toDate();
  if (valor is DateTime) return valor;
  if (valor is String) return DateTime.tryParse(valor);
  return null;
}

/// Un egreso ya cerrado de un perro, guardado en `historial_egresos`.
class EgresoModel {
  final String? motivo;
  final DateTime? fechaEgreso;
  final String? nota;
  final DateTime? fechaRegreso;

  const EgresoModel({
    this.motivo,
    this.fechaEgreso,
    this.nota,
    this.fechaRegreso,
  });

  factory EgresoModel.fromMap(Map<String, dynamic> data) {
    final motivo = data['motivo']?.toString();
    final nota = data['nota']?.toString();
    return EgresoModel(
      motivo: motivo == null || motivo.isEmpty ? null : motivo,
      fechaEgreso: _fechaDesdeValor(data['fecha_egreso']),
      nota: nota == null || nota.trim().isEmpty ? null : nota,
      fechaRegreso: _fechaDesdeValor(data['fecha_regreso']),
    );
  }

  Map<String, dynamic> toMap() {
    final notaLimpia = nota?.trim();
    return {
      if (motivo != null && motivo!.isNotEmpty) 'motivo': motivo,
      if (fechaEgreso != null) 'fecha_egreso': Timestamp.fromDate(fechaEgreso!),
      if (notaLimpia != null && notaLimpia.isNotEmpty) 'nota': notaLimpia,
      if (fechaRegreso != null) 'fecha_regreso': Timestamp.fromDate(fechaRegreso!),
    };
  }
}
