import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/estado_duracion.dart';
import '../models/tratamiento_model.dart';

/// Controlador encargado de la lógica de negocio de los tratamientos médicos
/// de un perro: creación, edición, archivado, registro de dosis y el cálculo
/// de auto-archivado por vencimiento de fechas. No contiene código de UI.
class TratamientoController {
  CollectionReference<Map<String, dynamic>> get _perrosRef =>
      FirebaseFirestore.instance.collection('perros');

  /// Genera un identificador único para un nuevo tratamiento.
  ///
  /// @return un `String` único basado en un id de documento de Firestore
  /// (no persiste ningún documento, solo se usa el generador de ids).
  String generarId() => _perrosRef.doc().id;

  /// Convierte una fecha a formato ISO `yyyy-MM-dd`, usado como clave para
  /// registrar las dosis tomadas en `registro_dosis`.
  ///
  /// @param fecha la fecha a formatear.
  /// @return el `String` con la fecha en formato ISO.
  String formatearFechaISO(DateTime fecha) {
    return '${fecha.year.toString().padLeft(4, '0')}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';
  }

  /// Crea un nuevo [TratamientoModel] aplicando las reglas de negocio según
  /// su categoría:
  /// - `'diario'`: queda `activo = true`, sin registro de dosis inicial y con
  ///   hora de recordatorio.
  /// - `'unico'` / `'higiene'` / `'evento'` / `'veterinaria'`: se considera un
  ///   evento puntual. Queda `activo = true` (no se pausa al crearlo) y se
  ///   registra la propia `fechaInicio` como primera dosis (para el calendario).
  ///
  /// @param categoria tipo de tratamiento (`'diario'`, `'unico'`, `'higiene'`,
  ///   `'evento'`, `'veterinaria'`).
  /// @param medicacion nombre de la medicación o procedimiento.
  /// @param indicaciones indicaciones, dosis o diagnóstico.
  /// @param fechaInicio fecha de inicio o de aplicación del evento.
  /// @param diasDuracion días de duración (solo aplica a categoría `'diario'`).
  /// @param horaRecordatorio hora `HH:mm` del recordatorio diario (solo `'diario'`).
  /// @param fechaProximoRecordatorio próximo recordatorio opcional (`'unico'` y `'higiene'`).
  /// @return el [TratamientoModel] recién creado, listo para agregarse a la
  /// lista de tratamientos del perro.
  TratamientoModel crearTratamiento({
    required String categoria,
    required String medicacion,
    required String indicaciones,
    required DateTime fechaInicio,
    int diasDuracion = 0,
    String? horaRecordatorio,
    DateTime? fechaProximoRecordatorio,
  }) {
    final esEventoUnico = categoria != 'diario';

    if (esEventoUnico) {
      return TratamientoModel(
        id: generarId(),
        categoria: categoria,
        medicacion: medicacion,
        indicaciones: indicaciones,
        fechaInicio: fechaInicio,
        diasDuracion: 0,
        // Se registra la fecha elegida en el formulario (no la de hoy) para que el TableCalendar la ubique.
        registroDosis: [formatearFechaISO(fechaInicio)],
        activo: true,
        fechaProximoRecordatorio:
            (categoria == 'unico' || categoria == 'higiene')
            ? fechaProximoRecordatorio
            : null,
      );
    }

    return TratamientoModel(
      id: generarId(),
      categoria: categoria,
      medicacion: medicacion,
      indicaciones: indicaciones,
      fechaInicio: fechaInicio,
      diasDuracion: diasDuracion,
      horaRecordatorio: horaRecordatorio,
      registroDosis: const [],
      activo: true,
    );
  }

  /// Edita los campos editables de un tratamiento existente (medicación,
  /// indicaciones, días de duración, fecha de inicio y hora de recordatorio),
  /// preservando el resto de los datos (id, categoría, registro de dosis, etc.).
  ///
  /// @param actual el tratamiento a editar.
  /// @param medicacion nuevo nombre de la medicación.
  /// @param indicaciones nuevas indicaciones.
  /// @param diasDuracion nueva duración en días.
  /// @param fechaInicio nueva fecha de inicio.
  /// @param horaRecordatorio nueva hora del recordatorio.
  /// @return una nueva instancia de [TratamientoModel] con los campos actualizados.
  TratamientoModel editarTratamiento(
    TratamientoModel actual, {
    required String medicacion,
    required String indicaciones,
    required int diasDuracion,
    required DateTime fechaInicio,
    required String horaRecordatorio,
  }) {
    return actual.copyWith(
      medicacion: medicacion,
      indicaciones: indicaciones,
      diasDuracion: diasDuracion,
      fechaInicio: fechaInicio,
      horaRecordatorio: horaRecordatorio,
    );
  }

  /// Pausa o reanuda un tratamiento diario. Solo altera [TratamientoModel.activo];
  /// categoría, fechas y recordatorios se conservan intactos.
  /// No aplica a eventos puntuales (`categoria != 'diario'`): se devuelve igual.
  TratamientoModel alternarPausa(TratamientoModel tratamiento) {
    if (tratamiento.categoria != 'diario') return tratamiento;
    return tratamiento.copyWith(activo: !tratamiento.activo);
  }

  /// Pausa un tratamiento (`activo = false`) sin tocar el resto de campos.
  TratamientoModel archivar(TratamientoModel tratamiento) =>
      tratamiento.copyWith(activo: false);

  /// Reanuda un tratamiento (`activo = true`) sin tocar el resto de campos.
  TratamientoModel restaurar(TratamientoModel tratamiento) =>
      tratamiento.copyWith(activo: true);

  /// Alterna `activo` de un tratamiento diario en Firestore tocando únicamente
  /// esa clave del mapa, para no resetear categoría, fechas ni recordatorios.
  /// Ignora ids que no sean de categoría `'diario'`.
  Future<void> persistirAlternarPausa(String idPerro, String idTratamiento) async {
    final snapshot = await _perrosRef.doc(idPerro).get();
    final data = snapshot.data();
    if (data == null) return;

    final crudos = List<dynamic>.from(data['tratamientos'] ?? const []);
    var huboCambio = false;
    final actualizados = crudos.map((item) {
      final mapa = Map<String, dynamic>.from(item as Map);
      if (mapa['id']?.toString() == idTratamiento &&
          mapa['categoria']?.toString() == 'diario') {
        mapa['activo'] = mapa['activo'] != true;
        huboCambio = true;
      }
      return mapa;
    }).toList();

    if (!huboCambio) return;
    await _perrosRef.doc(idPerro).update({'tratamientos': actualizados});
  }

  /// Día calendario sin hora, para que la misma fecha no se duplique.
  DateTime normalizarDia(DateTime fecha) =>
      DateTime(fecha.year, fecha.month, fecha.day);

  /// Lee `tratamientos` como lista. Si un update indexado lo dejó como mapa,
  /// rearma la lista por clave numérica para poder volver a guardarlo como array.
  List<TratamientoModel> _tratamientosDesdeDocumento(dynamic raw) {
    final mapas = <Map<String, dynamic>>[];

    if (raw is List) {
      for (final item in raw) {
        if (item is Map) mapas.add(Map<String, dynamic>.from(item));
      }
    } else if (raw is Map) {
      final claves = raw.keys.toList()
        ..sort(
          (a, b) => (int.tryParse(a.toString()) ?? 0).compareTo(
            int.tryParse(b.toString()) ?? 0,
          ),
        );
      for (final clave in claves) {
        final item = raw[clave];
        if (item is Map) mapas.add(Map<String, dynamic>.from(item));
      }
    }

    return mapas
        .map((mapa) => TratamientoModel.fromMap(mapa, mapa['id']?.toString() ?? ''))
        .toList();
  }

  /// Marca o desmarca la dosis de [fechaDosis].
  ///
  /// Lee el documento, cambia `registroDosis` en Dart y reescribe el array
  /// `tratamientos` completo. No usa rutas indexadas ni `FieldValue`.
  Future<void> toggleDosis(
    String perroId,
    TratamientoModel tratamiento,
    DateTime fechaDosis,
  ) async {
    final dia = normalizarDia(fechaDosis);
    final inicio = tratamiento.fechaInicio;
    if (inicio != null && dia.isBefore(normalizarDia(inicio))) return;

    final fechaIso = formatearFechaISO(dia);
    final docRef = _perrosRef.doc(perroId);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snapshot = await tx.get(docRef);
      final data = snapshot.data();
      if (data == null) return;

      final tratamientos = _tratamientosDesdeDocumento(data['tratamientos']);
      final indice = tratamientos.indexWhere((t) => t.id == tratamiento.id);
      if (indice == -1) return;

      final registro = List<String>.from(tratamientos[indice].registroDosis);
      if (registro.contains(fechaIso)) {
        registro.remove(fechaIso);
      } else {
        registro.add(fechaIso);
      }
      tratamientos[indice] = tratamientos[indice].copyWith(registroDosis: registro);

      tx.update(docRef, {
        'tratamientos': tratamientos.map((t) => t.toMap()).toList(),
      });
    });
  }

  /// Copia local con la dosis del día marcada o desmarcada.
  TratamientoModel alternarDosis(
    TratamientoModel tratamiento,
    DateTime fecha,
    bool marcar,
  ) {
    final fechaIso = formatearFechaISO(normalizarDia(fecha));
    final registroDosis = List<String>.from(tratamiento.registroDosis);

    if (marcar) {
      if (!registroDosis.contains(fechaIso)) registroDosis.add(fechaIso);
    } else {
      registroDosis.remove(fechaIso);
    }

    return tratamiento.copyWith(registroDosis: registroDosis);
  }

  /// Filtra los tratamientos que se consideran activos (no pausados).
  List<TratamientoModel> obtenerActivos(List<TratamientoModel> tratamientos) =>
      tratamientos.where((t) => t.activo).toList();

  /// Filtra los tratamientos pausados (`activo == false`).
  List<TratamientoModel> obtenerArchivados(
    List<TratamientoModel> tratamientos,
  ) => tratamientos.where((t) => !t.activo).toList();

  /// Todos los tratamientos de categoría `'diario'`.
  List<TratamientoModel> obtenerDiarios(List<TratamientoModel> tratamientos) =>
      tratamientos.where((t) => t.categoria == 'diario').toList();

  /// Tratamientos diarios activos (checkbox de dosis del día).
  List<TratamientoModel> obtenerActivosDiarios(
    List<TratamientoModel> tratamientos,
  ) => tratamientos.where((t) => t.activo && t.categoria == 'diario').toList();

  /// Tratamientos diarios pausados.
  List<TratamientoModel> obtenerDiariosPausados(
    List<TratamientoModel> tratamientos,
  ) => tratamientos.where((t) => !t.activo && t.categoria == 'diario').toList();

  /// Eventos puntuales (dosis única, higiene, evento médico, veterinaria),
  /// ordenados por fecha de inicio descendente (más recientes o futuros primero).
  List<TratamientoModel> obtenerEventosYVisitas(
    List<TratamientoModel> tratamientos,
  ) {
    final eventos = tratamientos.where((t) => t.categoria != 'diario').toList();
    eventos.sort((a, b) {
      final fechaA = a.fechaInicio ?? DateTime.fromMillisecondsSinceEpoch(0);
      final fechaB = b.fechaInicio ?? DateTime.fromMillisecondsSinceEpoch(0);
      return fechaB.compareTo(fechaA);
    });
    return eventos;
  }

  /// Día de inicio = día 1. `diasDuracion == 0` o sin fecha queda indefinido.
  static EstadoDuracion calcularEstadoDuracion(TratamientoModel tratamiento, {DateTime? hoy}) {
    final referencia = hoy ?? DateTime.now();
    final hoyFecha = DateTime(referencia.year, referencia.month, referencia.day);
    if (tratamiento.diasDuracion <= 0 || tratamiento.fechaInicio == null) {
      return const EstadoDuracion(fase: FaseTratamiento.indefinido);
    }

    final inicio = DateTime(
      tratamiento.fechaInicio!.year,
      tratamiento.fechaInicio!.month,
      tratamiento.fechaInicio!.day,
    );
    final total = tratamiento.diasDuracion;
    final ultimoDia = DateTime(inicio.year, inicio.month, inicio.day + total - 1);
    if (hoyFecha.isBefore(inicio)) {
      return EstadoDuracion(
        fase: FaseTratamiento.noIniciado,
        total: total,
        ultimoDia: ultimoDia,
        diasParaInicio: _diasEntre(hoyFecha, inicio),
      );
    }

    final diaActual = _diasEntre(inicio, hoyFecha) + 1;
    if (diaActual < total) {
      return EstadoDuracion(
        fase: FaseTratamiento.enCurso,
        diaActual: diaActual,
        total: total,
        restantes: total - diaActual,
        ultimoDia: ultimoDia,
      );
    }
    if (diaActual == total) {
      return EstadoDuracion(
        fase: FaseTratamiento.ultimoDia,
        diaActual: diaActual,
        total: total,
        restantes: 0,
        ultimoDia: ultimoDia,
      );
    }
    return EstadoDuracion(
      fase: FaseTratamiento.finalizado,
      diaActual: diaActual,
      total: total,
      restantes: 0,
      ultimoDia: ultimoDia,
    );
  }

  static int _diasEntre(DateTime desde, DateTime hasta) {
    final a = DateTime.utc(desde.year, desde.month, desde.day);
    final b = DateTime.utc(hasta.year, hasta.month, hasta.day);
    return b.difference(a).inDays;
  }

  /// Regla de negocio de auto-archivado: un tratamiento diario se pausa cuando
  /// [calcularEstadoDuracion] da [FaseTratamiento.finalizado], es decir el día
  /// siguiente al último de medicación. Los indefinidos no vencen.
  ///
  /// @param tratamientos la lista completa de tratamientos del perro.
  /// @param ahora fecha de referencia para el cálculo (por defecto, la fecha actual).
  /// @return una nueva lista con los tratamientos vencidos marcados como archivados.
  List<TratamientoModel> autoArchivarVencidos(
    List<TratamientoModel> tratamientos, {
    DateTime? ahora,
  }) {
    final fechaReferencia = ahora ?? DateTime.now();

    return tratamientos.map((t) {
      if (t.categoria != 'diario' || !t.activo) return t;
      final estado = calcularEstadoDuracion(t, hoy: fechaReferencia);
      if (estado.fase == FaseTratamiento.finalizado) return archivar(t);
      return t;
    }).toList();
  }

  /// Indica si el auto-archivado produjo cambios respecto a la lista original,
  /// comparando el estado `activo` de cada tratamiento por su id.
  ///
  /// @param original la lista antes de aplicar [autoArchivarVencidos].
  /// @param actualizada la lista devuelta por [autoArchivarVencidos].
  /// @return `true` si al menos un tratamiento cambió su estado `activo`.
  bool huboCambiosDeArchivado(
    List<TratamientoModel> original,
    List<TratamientoModel> actualizada,
  ) {
    for (var i = 0; i < original.length && i < actualizada.length; i++) {
      if (original[i].activo != actualizada[i].activo) return true;
    }
    return false;
  }

  /// Persiste la lista completa de tratamientos de un perro en Firestore,
  /// sobrescribiendo el campo `tratamientos` del documento.
  ///
  /// @param idPerro id del documento del perro en la colección `perros`.
  /// @param tratamientos la lista de tratamientos a guardar.
  /// @return un `Future` que se completa cuando la escritura finaliza.
  Future<void> guardarTratamientos(
    String idPerro,
    List<TratamientoModel> tratamientos,
  ) {
    return _perrosRef.doc(idPerro).update({
      'tratamientos': tratamientos.map((t) => t.toMap()).toList(),
    });
  }

  /// Aplica la regla de auto-archivado por vencimiento y, si hubo cambios,
  /// persiste el resultado en Firestore. Pensado para ejecutarse cada vez
  /// que se abre la ficha de un perro.
  ///
  /// @param idPerro id del documento del perro en la colección `perros`.
  /// @param tratamientos la lista de tratamientos actual del perro.
  /// @return la lista de tratamientos ya procesada (con los vencidos archivados).
  Future<List<TratamientoModel>> procesarAutoArchivadoYPersistir(
    String idPerro,
    List<TratamientoModel> tratamientos,
  ) async {
    final actualizados = autoArchivarVencidos(tratamientos);
    if (huboCambiosDeArchivado(tratamientos, actualizados)) {
      await guardarTratamientos(idPerro, actualizados);
    }
    return actualizados;
  }

  /// Construye un mapa de eventos por fecha a partir del historial de dosis
  /// registradas de todos los tratamientos, para alimentar el calendario de
  /// historial médico.
  ///
  /// @param tratamientos la lista completa de tratamientos del perro.
  /// @return un mapa donde la clave es la fecha (normalizada a UTC, sin hora)
  /// y el valor es la lista de eventos (`medicacion`, `indicaciones`, `detalle`,
  /// `categoria`) ocurridos ese día.
  Map<DateTime, List<Map<String, dynamic>>> construirEventosCalendario(
    List<TratamientoModel> tratamientos,
  ) {
    final eventosCalendario = <DateTime, List<Map<String, dynamic>>>{};

    for (final tratamiento in tratamientos) {
      final detalle = tratamiento.categoria == 'veterinaria'
          ? '🏥 ${tratamiento.medicacion} - ${tratamiento.indicaciones}'
          : '${tratamiento.medicacion} - ${tratamiento.indicaciones}';

      for (final fechaTexto in tratamiento.registroDosis) {
        final fecha = DateTime.tryParse(fechaTexto);
        if (fecha == null) continue;
        final fechaNormalizada = DateTime.utc(
          fecha.year,
          fecha.month,
          fecha.day,
        );

        eventosCalendario.putIfAbsent(fechaNormalizada, () => []).add({
          'medicacion': tratamiento.medicacion,
          'indicaciones': tratamiento.indicaciones,
          'detalle': detalle,
          'categoria': tratamiento.categoria,
        });
      }
    }

    return eventosCalendario;
  }
}
