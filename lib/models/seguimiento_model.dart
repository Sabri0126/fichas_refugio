import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? _fechaDesdeValor(dynamic valor) {
  if (valor is Timestamp) return valor.toDate();
  if (valor is DateTime) return valor;
  if (valor is String) return DateTime.tryParse(valor);
  return null;
}

bool _horaValida(String hora) {
  final coincidencia = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(hora.trim());
  if (coincidencia == null) return false;
  final horas = int.parse(coincidencia.group(1)!);
  final minutos = int.parse(coincidencia.group(2)!);
  return horas >= 0 && horas <= 23 && minutos >= 0 && minutos <= 59;
}

/// Arma la lista de `seguimientos` ignorando elementos que no se pueden leer.
List<SeguimientoModel> seguimientosDesdeValor(dynamic valor) {
  if (valor is! List) return const [];
  final lista = <SeguimientoModel>[];
  for (final item in valor) {
    if (item is! Map) continue;
    try {
      lista.add(SeguimientoModel.fromMap(Map<String, dynamic>.from(item)));
    } catch (_) {}
  }
  return lista;
}

/// Observación diaria de un perro, guardada en `seguimientos`.
/// `diasDuracion` en 0 sigue hasta que alguien lo cierra.
class SeguimientoModel {
  final String id;
  final String motivo;
  final String detalle;
  final String hora;
  final DateTime fechaInicio;
  final int diasDuracion;
  final bool activo;

  const SeguimientoModel({
    required this.id,
    required this.motivo,
    required this.detalle,
    required this.hora,
    required this.fechaInicio,
    required this.diasDuracion,
    required this.activo,
  });

  /// Último día inclusive. Null si no tiene fecha de fin.
  DateTime? get ultimoDia {
    if (diasDuracion <= 0) return null;
    final inicio = DateTime(fechaInicio.year, fechaInicio.month, fechaInicio.day);
    return inicio.add(Duration(days: diasDuracion - 1));
  }

  /// Sigue en curso, o todavía no empezó. Un cerrado o ya vencido no lo está.
  bool vigente(DateTime ahora) {
    if (!activo) return false;
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final inicio = DateTime(fechaInicio.year, fechaInicio.month, fechaInicio.day);
    if (hoy.isBefore(inicio)) return true;
    final fin = ultimoDia;
    if (fin == null) return true;
    return !hoy.isAfter(fin);
  }

  factory SeguimientoModel.fromMap(Map<String, dynamic> data) {
    final fechaInicio = _fechaDesdeValor(data['fecha_inicio']);
    final id = data['id']?.toString() ?? '';
    final hora = data['hora']?.toString() ?? '';
    final diasRaw = data['dias_duracion'];
    final dias = diasRaw is int ? diasRaw : int.tryParse(diasRaw?.toString() ?? '');
    var motivo = data['motivo']?.toString().trim() ?? '';
    if (motivo.isEmpty) motivo = 'otro';
    if (fechaInicio == null || id.isEmpty || dias == null || dias < 0 || !_horaValida(hora)) {
      throw const FormatException('Seguimiento inválido');
    }
    return SeguimientoModel(
      id: id,
      motivo: motivo,
      detalle: data['detalle']?.toString() ?? '',
      hora: hora.trim(),
      fechaInicio: fechaInicio,
      diasDuracion: dias,
      activo: data['activo'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'motivo': motivo,
      'detalle': detalle,
      'hora': hora,
      'fecha_inicio': Timestamp.fromDate(fechaInicio),
      'dias_duracion': diasDuracion,
      'activo': activo,
    };
  }

  SeguimientoModel copyWith({
    String? id,
    String? motivo,
    String? detalle,
    String? hora,
    DateTime? fechaInicio,
    int? diasDuracion,
    bool? activo,
  }) {
    return SeguimientoModel(
      id: id ?? this.id,
      motivo: motivo ?? this.motivo,
      detalle: detalle ?? this.detalle,
      hora: hora ?? this.hora,
      fechaInicio: fechaInicio ?? this.fechaInicio,
      diasDuracion: diasDuracion ?? this.diasDuracion,
      activo: activo ?? this.activo,
    );
  }
}
