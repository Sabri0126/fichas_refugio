import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'tratamiento_model.dart';

/// Convierte un valor proveniente de Firestore (Timestamp, DateTime o String)
/// en un [DateTime], devolviendo `null` si no se puede interpretar.
DateTime? _fechaDesdeValor(dynamic valor) {
  if (valor is Timestamp) return valor.toDate();
  if (valor is DateTime) return valor;
  if (valor is String) return DateTime.tryParse(valor);
  return null;
}

/// Representa un perro registrado en el refugio, tal como se almacena en la
/// colección `perros` de Firestore.
class PerroModel {
  /// Identificador del documento en la colección `perros`.
  final String id;

  /// Nombre del perro.
  final String nombre;

  /// Sexo del perro: `'macho'` o `'hembra'`.
  final String sexo;

  /// Estado del perro dentro del refugio: `'activo'` (en el refugio o en
  /// adopción) o `'inactivo'` (fallecido o dado de baja).
  final String estado;

  /// Edad del perro en años completos.
  final int edad;

  /// Meses adicionales a la edad en años (p. ej. `edad = 1, meses = 3`
  /// significa 1 año y 3 meses).
  final int meses;

  /// Indica si la edad del perro es una estimación desconocida y no debe
  /// actualizarse automáticamente con el paso del tiempo.
  final bool edadIndeterminada;

  /// Año utilizado como referencia para calcular la edad mostrada, usado
  /// para perros con edad indeterminada o congelada.
  final int? edadAnioBase;

  /// Fecha en la que el perro ingresó al refugio.
  final DateTime? fechaIngreso;

  /// Fecha de fallecimiento del perro, si corresponde (solo cuando
  /// `estado == 'inactivo'`).
  final DateTime? fechaFallecimiento;

  /// Marca de tiempo de la última vez que se recalculó automáticamente la
  /// edad del perro (usada para el envejecimiento incremental de cachorros).
  final DateTime? ultimaActualizacionEdad;

  /// Reseña o historia libre del perro (cómo llegó al refugio, carácter, etc.).
  final String historia;

  /// Notas de la ficha médica del perro en formato de texto libre.
  final String fichaMedica;

  /// Indica si el perro está castrado/esterilizado.
  final bool castrado;

  /// Indica si el perro actualmente vive en un hogar de acogida (no en el
  /// refugio físico).
  final bool enCasa;

  /// URL de la foto de perfil del perro almacenada en Firebase Storage.
  final String? fotoPerfil;

  /// Lista de familiares del perro. Cada elemento es un mapa con las claves
  /// `id`, `id_documento`, `nombre` y `relacion` (p. ej. `'Madre'`, `'Hijo/a'`,
  /// `'Hermano/a'`) que referencian a otro documento de la colección `perros`.
  final List<Map<String, dynamic>> parientes;

  /// Lista de fotos adicionales del perro. Cada elemento es un mapa con las
  /// claves `url` (ubicación de la imagen) y `texto`/`descripcion` (pie de foto).
  final List<Map<String, dynamic>> galeria;

  /// Tratamientos médicos asociados a este perro.
  final List<TratamientoModel> tratamientos;

  /// Crea una instancia inmutable de [PerroModel].
  PerroModel({
    required this.id,
    required this.nombre,
    this.sexo = 'macho',
    this.estado = 'activo',
    this.edad = 0,
    this.meses = 0,
    this.edadIndeterminada = false,
    this.edadAnioBase,
    this.fechaIngreso,
    this.fechaFallecimiento,
    this.ultimaActualizacionEdad,
    this.historia = '',
    this.fichaMedica = '',
    this.castrado = false,
    this.enCasa = false,
    this.fotoPerfil,
    this.parientes = const [],
    this.galeria = const [],
    this.tratamientos = const [],
  });

  /// Construye un [PerroModel] a partir del mapa `data` de un documento de
  /// Firestore y su identificador [id] (normalmente `doc.id`).
  factory PerroModel.fromMap(Map<String, dynamic> data, String id) {
    final tratamientosRaw = data['tratamientos'];
    final tratamientos = tratamientosRaw is List
        ? tratamientosRaw
            .map((t) => TratamientoModel.fromMap(
                  Map<String, dynamic>.from(t as Map),
                  (t['id'] ?? '').toString(),
                ))
            .toList()
        : <TratamientoModel>[];

    final parientesRaw = data['parientes'];
    final parientes = parientesRaw is List
        ? parientesRaw.map((p) => Map<String, dynamic>.from(p as Map)).toList()
        : <Map<String, dynamic>>[];

    final galeriaRaw = data['galeria'];
    List<Map<String, dynamic>> galeria;
    try {
      if (galeriaRaw == null) {
        developer.log(
          'Campo "galeria" nulo para perro $id. Valor crudo: $galeriaRaw',
          name: 'PerroModel.fromMap',
        );
        galeria = <Map<String, dynamic>>[];
      } else if (galeriaRaw is List) {
        galeria = galeriaRaw
            .whereType<Object>()
            .map((g) {
              if (g is Map) {
                return Map<String, dynamic>.from(g);
              }
              developer.log(
                'Elemento de "galeria" con tipo inesperado para perro $id. '
                'Valor crudo: $g (${g.runtimeType})',
                name: 'PerroModel.fromMap',
              );
              return <String, dynamic>{};
            })
            .where((m) => m.isNotEmpty)
            .toList();
      } else {
        developer.log(
          'Campo "galeria" con tipo inesperado para perro $id. '
          'Valor crudo: $galeriaRaw (${galeriaRaw.runtimeType})',
          name: 'PerroModel.fromMap',
        );
        galeria = <Map<String, dynamic>>[];
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error al parsear "galeria" para perro $id. Valor crudo: $galeriaRaw',
        name: 'PerroModel.fromMap',
        error: e,
        stackTrace: stackTrace,
      );
      galeria = <Map<String, dynamic>>[];
    }

    return PerroModel(
      id: id,
      nombre: data['nombre']?.toString() ?? '',
      sexo: data['sexo']?.toString() ?? 'macho',
      estado: data['estado']?.toString() ?? 'activo',
      edad: int.tryParse(data['edad']?.toString() ?? '') ?? 0,
      meses: int.tryParse(data['meses']?.toString() ?? '') ?? 0,
      edadIndeterminada: data['edad_indeterminada'] == true,
      edadAnioBase: int.tryParse(data['edad_anio_base']?.toString() ?? ''),
      fechaIngreso: _fechaDesdeValor(data['fecha_ingreso']),
      fechaFallecimiento: _fechaDesdeValor(data['fecha_fallecimiento']),
      ultimaActualizacionEdad: _fechaDesdeValor(data['ultima_actualizacion_edad']),
      historia: data['historia']?.toString() ?? '',
      fichaMedica: data['ficha_medica']?.toString() ?? '',
      castrado: data['castrado'] == true,
      enCasa: data['en_casa'] == true,
      fotoPerfil: data['foto_perfil']?.toString(),
      parientes: parientes,
      galeria: galeria,
      tratamientos: tratamientos,
    );
  }

  /// Convierte esta instancia en un mapa listo para guardarse en el
  /// documento del perro en la colección `perros` de Firestore.
  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'sexo': sexo,
      'estado': estado,
      'edad': edad,
      'meses': meses,
      'edad_indeterminada': edadIndeterminada,
      if (edadAnioBase != null) 'edad_anio_base': edadAnioBase,
      if (fechaIngreso != null) 'fecha_ingreso': Timestamp.fromDate(fechaIngreso!),
      if (fechaFallecimiento != null) 'fecha_fallecimiento': Timestamp.fromDate(fechaFallecimiento!),
      if (ultimaActualizacionEdad != null)
        'ultima_actualizacion_edad': Timestamp.fromDate(ultimaActualizacionEdad!),
      'historia': historia,
      'ficha_medica': fichaMedica,
      'castrado': castrado,
      'en_casa': enCasa,
      'foto_perfil': fotoPerfil,
      'parientes': parientes,
      'galeria': galeria,
      'tratamientos': tratamientos.map((t) => t.toMap()).toList(),
    };
  }

  /// Crea una copia de este [PerroModel] reemplazando únicamente los campos
  /// indicados, útil para aplicar reglas de negocio (p. ej. auto-archivado
  /// de tratamientos) sin reconstruir manualmente todos los campos.
  PerroModel copyWith({
    List<TratamientoModel>? tratamientos,
    List<Map<String, dynamic>>? parientes,
    List<Map<String, dynamic>>? galeria,
    String? fotoPerfil,
  }) {
    return PerroModel(
      id: id,
      nombre: nombre,
      sexo: sexo,
      estado: estado,
      edad: edad,
      meses: meses,
      edadIndeterminada: edadIndeterminada,
      edadAnioBase: edadAnioBase,
      fechaIngreso: fechaIngreso,
      fechaFallecimiento: fechaFallecimiento,
      ultimaActualizacionEdad: ultimaActualizacionEdad,
      historia: historia,
      fichaMedica: fichaMedica,
      castrado: castrado,
      enCasa: enCasa,
      fotoPerfil: fotoPerfil ?? this.fotoPerfil,
      parientes: parientes ?? this.parientes,
      galeria: galeria ?? this.galeria,
      tratamientos: tratamientos ?? this.tratamientos,
    );
  }
}