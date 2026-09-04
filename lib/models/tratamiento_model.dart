import 'package:cloud_firestore/cloud_firestore.dart';

/// Convierte un valor proveniente de Firestore (Timestamp, DateTime o String)
/// en un [DateTime], devolviendo `null` si no se puede interpretar.
DateTime? _fechaDesdeValor(dynamic valor) {
  if (valor is Timestamp) return valor.toDate();
  if (valor is DateTime) return valor;
  if (valor is String) return DateTime.tryParse(valor);
  return null;
}

/// Representa un tratamiento médico asociado a un perro (medicación, vacuna,
/// evento veterinario, etc.). Los tratamientos se almacenan como una lista de
/// mapas dentro del documento del perro en la colección `perros` de Firestore
/// (campo `tratamientos`), por lo que no poseen una colección propia.
class TratamientoModel {
  /// Identificador único del tratamiento, generado con
  /// `FirebaseFirestore.instance.collection('perros').doc().id` al crearlo.
  final String id;

  /// Tipo de tratamiento. Valores usados actualmente: `'diario'` (medicación
  /// recurrente), `'unico'` (evento puntual, p. ej. una vacuna) y
  /// `'veterinaria'` (visita o diagnóstico veterinario).
  final String categoria;

  /// Nombre de la medicación o del procedimiento aplicado.
  final String medicacion;

  /// Indicaciones, dosis o diagnóstico asociado al tratamiento.
  final String indicaciones;

  /// Fecha en la que se inició el tratamiento o en la que ocurrió el evento.
  final DateTime? fechaInicio;

  /// Duración del tratamiento en días. Un valor de `0` indica que el
  /// tratamiento es indefinido (sin fecha de finalización).
  final int diasDuracion;

  /// Hora del recordatorio diario en formato `HH:mm`. Solo aplica a
  /// tratamientos de categoría `'diario'`.
  final String? horaRecordatorio;

  /// Lista de fechas (en formato ISO `yyyy-MM-dd`) en las que ya se registró
  /// la administración de una dosis o la realización del evento.
  final List<String> registroDosis;

  /// Indica si el tratamiento sigue activo (pendiente de dosis) o si ya
  /// finalizó/se completó.
  final bool activo;

  /// Fecha y hora del próximo recordatorio programado. Solo aplica a
  /// tratamientos de categoría `'unico'`.
  final DateTime? fechaProximoRecordatorio;

  /// Crea una instancia inmutable de [TratamientoModel].
  TratamientoModel({
    required this.id,
    required this.categoria,
    required this.medicacion,
    required this.indicaciones,
    this.fechaInicio,
    this.diasDuracion = 0,
    this.horaRecordatorio,
    this.registroDosis = const [],
    this.activo = true,
    this.fechaProximoRecordatorio,
  });

  /// Construye un [TratamientoModel] a partir del mapa `data` obtenido de
  /// Firestore. Si `data` no incluye un campo `id`, se utiliza el parámetro
  /// [id] recibido como respaldo.
  factory TratamientoModel.fromMap(Map<String, dynamic> data, String id) {
    return TratamientoModel(
      id: (data['id'] as String?) ?? id,
      categoria: data['categoria']?.toString() ?? 'diario',
      medicacion: data['medicacion']?.toString() ?? '',
      indicaciones: data['indicaciones']?.toString() ?? '',
      fechaInicio: _fechaDesdeValor(data['fecha_inicio']),
      diasDuracion: int.tryParse(data['dias_duracion']?.toString() ?? '') ?? 0,
      horaRecordatorio: data['hora_recordatorio']?.toString(),
      registroDosis: List<String>.from(data['registro_dosis'] ?? const []),
      activo: data['activo'] == true,
      fechaProximoRecordatorio: _fechaDesdeValor(data['fecha_proximo_recordatorio']),
    );
  }

  /// Convierte esta instancia en un mapa listo para guardarse en Firestore
  /// dentro del campo `tratamientos` del documento del perro.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'categoria': categoria,
      'medicacion': medicacion,
      'indicaciones': indicaciones,
      if (fechaInicio != null) 'fecha_inicio': Timestamp.fromDate(fechaInicio!),
      'dias_duracion': diasDuracion,
      if (horaRecordatorio != null) 'hora_recordatorio': horaRecordatorio,
      'registro_dosis': registroDosis,
      'activo': activo,
      if (fechaProximoRecordatorio != null)
        'fecha_proximo_recordatorio': Timestamp.fromDate(fechaProximoRecordatorio!),
    };
  }
}
