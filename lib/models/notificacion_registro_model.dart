import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? _fecha(dynamic valor) {
  if (valor is Timestamp) return valor.toDate();
  if (valor is DateTime) return valor;
  if (valor is String) return DateTime.tryParse(valor);
  return null;
}

/// Un aviso guardado en `notificaciones`. `leida` se calcula en el teléfono.
class NotificacionRegistroModel {
  final String id;
  final String titulo;
  final String cuerpo;
  final String? idPerro;
  final String? idTratamiento;
  final String? dia;
  final String categoria;
  final String tipo;
  final DateTime fecha;
  final DateTime creada;
  final bool leida;

  const NotificacionRegistroModel({
    required this.id,
    required this.titulo,
    required this.cuerpo,
    this.idPerro,
    this.idTratamiento,
    this.dia,
    required this.categoria,
    required this.tipo,
    required this.fecha,
    required this.creada,
    required this.leida,
  });

  /// Devuelve null si falta `creada` o no se puede leer la fecha.
  static NotificacionRegistroModel? desdeDocumento(
    String id,
    Map<String, dynamic> data, {
    required DateTime? leidasHasta,
  }) {
    final creada = _fecha(data['creada']);
    final ocurrencia = _fecha(data['fecha']) ?? creada;
    if (creada == null || ocurrencia == null || id.isEmpty) return null;
    final idPerro = data['id_perro']?.toString();
    final idTratamiento = data['id_tratamiento']?.toString().trim() ?? '';
    final dia = data['dia']?.toString().trim() ?? '';
    return NotificacionRegistroModel(
      id: id,
      titulo: data['titulo']?.toString() ?? '',
      cuerpo: data['cuerpo']?.toString() ?? '',
      idPerro: idPerro == null || idPerro.isEmpty ? null : idPerro,
      idTratamiento: idTratamiento.isEmpty ? null : idTratamiento,
      dia: dia.isEmpty ? null : dia,
      categoria: data['categoria']?.toString() ?? 'diario',
      tipo: data['tipo']?.toString() ?? '',
      fecha: ocurrencia,
      creada: creada,
      leida: leidasHasta != null && !creada.isAfter(leidasHasta),
    );
  }
}
