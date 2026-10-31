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

  /// Tipo de tratamiento. Valores usados: `'diario'`, `'unico'`, `'higiene'`,
  /// `'evento'`, `'veterinaria'` y `'vacuna'`.
  final String categoria;

  /// Nombre de la medicación, del procedimiento, de la vacuna o motivo de la visita.
  final String medicacion;

  /// Indicaciones o dosis administrada.
  final String indicaciones;

  /// Razón de la aplicación o notas. La usan la dosis única y la vacuna.
  final String notas;

  /// Nombre de quien atendió la visita. Solo lo usa la categoría `'veterinaria'`.
  final String veterinario;

  /// Diagnóstico de la visita. Solo lo usa la categoría `'veterinaria'`.
  final String diagnostico;

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

  /// Si el diario manda aviso a los celulares de administradores.
  /// `false` lo calla en todos. Si el campo no viene de Firestore, sigue avisando.
  final bool notificar;

  /// Crea una instancia inmutable de [TratamientoModel].
  TratamientoModel({
    required this.id,
    required this.categoria,
    required this.medicacion,
    required this.indicaciones,
    this.notas = '',
    this.veterinario = '',
    this.diagnostico = '',
    this.fechaInicio,
    this.diasDuracion = 0,
    this.horaRecordatorio,
    this.registroDosis = const [],
    this.activo = true,
    this.fechaProximoRecordatorio,
    this.notificar = true,
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
      notas: data['notas']?.toString() ?? '',
      veterinario: data['veterinario']?.toString() ?? '',
      diagnostico: data['diagnostico']?.toString() ?? '',
      fechaInicio: _fechaDesdeValor(data['fecha_inicio']),
      diasDuracion: int.tryParse(data['dias_duracion']?.toString() ?? '') ?? 0,
      horaRecordatorio: data['hora_recordatorio']?.toString(),
      registroDosis: List<String>.from(data['registro_dosis'] ?? const []),
      activo: data['activo'] == true,
      fechaProximoRecordatorio: _fechaDesdeValor(
        data['fecha_proximo_recordatorio'],
      ),
      notificar: data['notificar'] != false,
    );
  }

  /// Convierte esta instancia en un mapa listo para guardarse en Firestore
  /// dentro del campo `tratamientos` del documento del perro.
  /// Se escriben todas las claves conocidas para no borrar recordatorios ni
  /// fechas al reemplazar el array `tratamientos`.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'categoria': categoria,
      'medicacion': medicacion,
      'indicaciones': indicaciones,
      'notas': notas,
      'veterinario': veterinario,
      'diagnostico': diagnostico,
      'fecha_inicio': fechaInicio != null ? Timestamp.fromDate(fechaInicio!) : null,
      'dias_duracion': diasDuracion,
      'hora_recordatorio': horaRecordatorio,
      'registro_dosis': registroDosis,
      'activo': activo,
      'fecha_proximo_recordatorio': fechaProximoRecordatorio != null
          ? Timestamp.fromDate(fechaProximoRecordatorio!)
          : null,
      'notificar': notificar,
    };
  }

  /// Copia el tratamiento cambiando solo los campos indicados.
  TratamientoModel copyWith({
    String? id,
    String? categoria,
    String? medicacion,
    String? indicaciones,
    String? notas,
    String? veterinario,
    String? diagnostico,
    DateTime? fechaInicio,
    int? diasDuracion,
    String? horaRecordatorio,
    List<String>? registroDosis,
    bool? activo,
    DateTime? fechaProximoRecordatorio,
    bool? notificar,
  }) {
    return TratamientoModel(
      id: id ?? this.id,
      categoria: categoria ?? this.categoria,
      medicacion: medicacion ?? this.medicacion,
      indicaciones: indicaciones ?? this.indicaciones,
      notas: notas ?? this.notas,
      veterinario: veterinario ?? this.veterinario,
      diagnostico: diagnostico ?? this.diagnostico,
      fechaInicio: fechaInicio ?? this.fechaInicio,
      diasDuracion: diasDuracion ?? this.diasDuracion,
      horaRecordatorio: horaRecordatorio ?? this.horaRecordatorio,
      registroDosis: registroDosis ?? this.registroDosis,
      activo: activo ?? this.activo,
      fechaProximoRecordatorio: fechaProximoRecordatorio ?? this.fechaProximoRecordatorio,
      notificar: notificar ?? this.notificar,
    );
  }

  /// Texto secundario de listas y calendario.
  /// En una visita veterinaria junta veterinario, diagnóstico e indicaciones.
  String get detalleVisible {
    if (categoria == 'veterinaria') {
      return [
        veterinario.trim(),
        diagnostico.trim(),
        indicaciones.trim(),
      ].where((parte) => parte.isNotEmpty).join(' · ');
    }
    final dosis = indicaciones.trim();
    final extra = notas.trim();
    if (dosis.isEmpty) return extra;
    if (extra.isEmpty) return dosis;
    return '$dosis · $extra';
  }
}
