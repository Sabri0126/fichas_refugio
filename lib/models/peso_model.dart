import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? _fechaDesdeValor(dynamic valor) {
  if (valor is Timestamp) return valor.toDate();
  if (valor is DateTime) return valor;
  if (valor is String) return DateTime.tryParse(valor);
  return null;
}

double? _kgDesdeValor(dynamic valor) {
  if (valor is num) return valor.toDouble();
  final texto = valor?.toString().trim().replaceAll(',', '.');
  if (texto == null || texto.isEmpty) return null;
  return double.tryParse(texto);
}

/// "12,5" o "12". Vacío si el número no se puede mostrar.
String formatearKg(double kg) {
  if (!kg.isFinite) return '';
  final redondeado = (kg * 10).round() / 10;
  final texto = redondeado == redondeado.roundToDouble()
      ? redondeado.toStringAsFixed(0)
      : redondeado.toStringAsFixed(1);
  return texto.replaceAll('.', ',');
}

/// Acepta coma o punto. Null si no es un peso de perro (entre 0 y 150 kg).
double? parsearKg(String texto) {
  final limpio = texto.trim().replaceAll(',', '.');
  if (limpio.isEmpty) return null;
  final kg = double.tryParse(limpio);
  if (kg == null || !kg.isFinite || kg <= 0 || kg > 150) return null;
  return (kg * 10).round() / 10;
}

/// Arma la lista de `pesos` ignorando entradas ilegibles y ordenándola por fecha.
List<PesoModel> pesosDesdeValor(dynamic valor) {
  if (valor is! List) return const [];
  final lista = <PesoModel>[];
  for (final item in valor) {
    if (item is! Map) continue;
    try {
      lista.add(PesoModel.fromMap(Map<String, dynamic>.from(item)));
    } catch (_) {}
  }
  lista.sort((a, b) {
    final porFecha = a.fecha.compareTo(b.fecha);
    if (porFecha != 0) return porFecha;
    return a.id.compareTo(b.id);
  });
  return lista;
}

/// Una medición de peso, guardada en `pesos`.
class PesoModel {
  final String id;
  final DateTime fecha;
  final double kg;
  final bool estimado;
  final String nota;

  const PesoModel({
    required this.id,
    required this.fecha,
    required this.kg,
    required this.estimado,
    required this.nota,
  });

  factory PesoModel.fromMap(Map<String, dynamic> data) {
    final fecha = _fechaDesdeValor(data['fecha']);
    final id = data['id']?.toString() ?? '';
    final kg = _kgDesdeValor(data['kg']);
    if (fecha == null || id.isEmpty || kg == null || !kg.isFinite || kg <= 0 || kg > 150) {
      throw const FormatException('Peso inválido');
    }
    return PesoModel(
      id: id,
      fecha: DateTime(fecha.year, fecha.month, fecha.day),
      kg: (kg * 10).round() / 10,
      estimado: data['estimado'] == true,
      nota: data['nota']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fecha': Timestamp.fromDate(DateTime(fecha.year, fecha.month, fecha.day)),
      'kg': kg,
      'estimado': estimado,
      'nota': nota,
    };
  }

  PesoModel copyWith({
    String? id,
    DateTime? fecha,
    double? kg,
    bool? estimado,
    String? nota,
  }) {
    return PesoModel(
      id: id ?? this.id,
      fecha: fecha ?? this.fecha,
      kg: kg ?? this.kg,
      estimado: estimado ?? this.estimado,
      nota: nota ?? this.nota,
    );
  }
}
