import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? _fechaDesdeValor(dynamic valor) {
  if (valor is Timestamp) return valor.toDate();
  if (valor is DateTime) return valor;
  if (valor is String) return DateTime.tryParse(valor);
  return null;
}

const _tiposValidos = {'veterinaria', 'medicacion', 'higiene', 'otro'};

/// Arma la lista de `recordatorios` ignorando elementos que no se pueden leer.
List<RecordatorioModel> recordatoriosDesdeValor(dynamic valor) {
  if (valor is! List) return const [];
  final lista = <RecordatorioModel>[];
  for (final item in valor) {
    if (item is! Map) continue;
    try {
      lista.add(RecordatorioModel.fromMap(Map<String, dynamic>.from(item)));
    } catch (_) {}
  }
  return lista;
}

/// Recordatorio agendado de un perro, guardado en `recordatorios`.
class RecordatorioModel {
  final String id;
  final String tipo;
  final String titulo;
  final String nota;
  final DateTime fechaHora;

  const RecordatorioModel({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.nota,
    required this.fechaHora,
  });

  factory RecordatorioModel.fromMap(Map<String, dynamic> data) {
    final fechaHora = _fechaDesdeValor(data['fecha_hora']);
    final id = data['id']?.toString() ?? '';
    final tipo = data['tipo']?.toString() ?? '';
    final titulo = data['titulo']?.toString() ?? '';
    if (fechaHora == null || id.isEmpty || titulo.isEmpty || !_tiposValidos.contains(tipo)) {
      throw FormatException('Recordatorio inválido');
    }
    return RecordatorioModel(
      id: id,
      tipo: tipo,
      titulo: titulo,
      nota: data['nota']?.toString() ?? '',
      fechaHora: fechaHora,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tipo': tipo,
      'titulo': titulo,
      'nota': nota,
      'fecha_hora': Timestamp.fromDate(fechaHora),
    };
  }

  RecordatorioModel copyWith({
    String? id,
    String? tipo,
    String? titulo,
    String? nota,
    DateTime? fechaHora,
  }) {
    return RecordatorioModel(
      id: id ?? this.id,
      tipo: tipo ?? this.tipo,
      titulo: titulo ?? this.titulo,
      nota: nota ?? this.nota,
      fechaHora: fechaHora ?? this.fechaHora,
    );
  }
}
