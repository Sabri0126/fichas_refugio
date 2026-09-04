import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/tratamiento_model.dart';

/// Controlador encargado de la lógica de negocio de los tratamientos médicos
/// de un perro: creación, edición, archivado, registro de dosis y el cálculo
/// de auto-archivado por vencimiento de fechas. No contiene código de UI.
class TratamientoController {
  final CollectionReference<Map<String, dynamic>> _perrosRef =
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
  /// - `'unico'` / `'veterinaria'`: se considera un evento puntual, por lo
  ///   que queda `activo = false` y se registra la propia `fechaInicio` como
  ///   primera dosis (para que se vea en el calendario histórico).
  ///
  /// @param categoria tipo de tratamiento (`'diario'`, `'unico'`, `'veterinaria'`).
  /// @param medicacion nombre de la medicación o procedimiento.
  /// @param indicaciones indicaciones, dosis o diagnóstico.
  /// @param fechaInicio fecha de inicio o de aplicación del evento.
  /// @param diasDuracion días de duración (solo aplica a categoría `'diario'`).
  /// @param horaRecordatorio hora `HH:mm` del recordatorio diario (solo `'diario'`).
  /// @param fechaProximoRecordatorio próximo recordatorio opcional (solo `'unico'`).
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
        activo: false,
        fechaProximoRecordatorio: categoria == 'unico' ? fechaProximoRecordatorio : null,
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
    return TratamientoModel(
      id: actual.id,
      categoria: actual.categoria,
      medicacion: medicacion,
      indicaciones: indicaciones,
      fechaInicio: fechaInicio,
      diasDuracion: diasDuracion,
      horaRecordatorio: horaRecordatorio,
      registroDosis: actual.registroDosis,
      activo: actual.activo,
      fechaProximoRecordatorio: actual.fechaProximoRecordatorio,
    );
  }

  /// Marca un tratamiento como archivado (deja de listarse como activo) sin
  /// eliminarlo del historial.
  ///
  /// @param tratamiento el tratamiento a archivar.
  /// @return una copia del tratamiento con `activo = false`.
  TratamientoModel archivar(TratamientoModel tratamiento) => TratamientoModel(
        id: tratamiento.id,
        categoria: tratamiento.categoria,
        medicacion: tratamiento.medicacion,
        indicaciones: tratamiento.indicaciones,
        fechaInicio: tratamiento.fechaInicio,
        diasDuracion: tratamiento.diasDuracion,
        horaRecordatorio: tratamiento.horaRecordatorio,
        registroDosis: tratamiento.registroDosis,
        activo: false,
        fechaProximoRecordatorio: tratamiento.fechaProximoRecordatorio,
      );

  /// Restaura un tratamiento previamente archivado, volviéndolo a marcar
  /// como activo.
  ///
  /// @param tratamiento el tratamiento a restaurar.
  /// @return una copia del tratamiento con `activo = true`.
  TratamientoModel restaurar(TratamientoModel tratamiento) => TratamientoModel(
        id: tratamiento.id,
        categoria: tratamiento.categoria,
        medicacion: tratamiento.medicacion,
        indicaciones: tratamiento.indicaciones,
        fechaInicio: tratamiento.fechaInicio,
        diasDuracion: tratamiento.diasDuracion,
        horaRecordatorio: tratamiento.horaRecordatorio,
        registroDosis: tratamiento.registroDosis,
        activo: true,
        fechaProximoRecordatorio: tratamiento.fechaProximoRecordatorio,
      );

  /// Marca o desmarca la dosis de un tratamiento para una fecha determinada
  /// (usado por el checkbox diario de "dosis tomada hoy").
  ///
  /// @param tratamiento el tratamiento a actualizar.
  /// @param fecha la fecha de la dosis a marcar/desmarcar.
  /// @param marcar `true` para registrar la dosis, `false` para quitarla.
  /// @return una copia del tratamiento con `registroDosis` actualizado.
  TratamientoModel alternarDosis(TratamientoModel tratamiento, DateTime fecha, bool marcar) {
    final fechaIso = formatearFechaISO(fecha);
    final registroDosis = List<String>.from(tratamiento.registroDosis);

    if (marcar) {
      if (!registroDosis.contains(fechaIso)) registroDosis.add(fechaIso);
    } else {
      registroDosis.remove(fechaIso);
    }

    return TratamientoModel(
      id: tratamiento.id,
      categoria: tratamiento.categoria,
      medicacion: tratamiento.medicacion,
      indicaciones: tratamiento.indicaciones,
      fechaInicio: tratamiento.fechaInicio,
      diasDuracion: tratamiento.diasDuracion,
      horaRecordatorio: tratamiento.horaRecordatorio,
      registroDosis: registroDosis,
      activo: tratamiento.activo,
      fechaProximoRecordatorio: tratamiento.fechaProximoRecordatorio,
    );
  }

  /// Filtra los tratamientos que se consideran activos (no archivados).
  ///
  /// @param tratamientos la lista completa de tratamientos del perro.
  /// @return la sublista de tratamientos con `activo == true`.
  List<TratamientoModel> obtenerActivos(List<TratamientoModel> tratamientos) =>
      tratamientos.where((t) => t.activo).toList();

  /// Filtra los tratamientos archivados (histórico, ya no vigentes).
  ///
  /// @param tratamientos la lista completa de tratamientos del perro.
  /// @return la sublista de tratamientos con `activo == false`.
  List<TratamientoModel> obtenerArchivados(List<TratamientoModel> tratamientos) =>
      tratamientos.where((t) => !t.activo).toList();

  /// Filtra los tratamientos diarios activos, que son los únicos que se
  /// controlan con el checkbox de "dosis tomada hoy" (las dosis únicas y
  /// visitas veterinarias no requieren seguimiento diario).
  ///
  /// @param tratamientos la lista completa de tratamientos del perro.
  /// @return la sublista de tratamientos con `categoria == 'diario'` y `activo == true`.
  List<TratamientoModel> obtenerActivosDiarios(List<TratamientoModel> tratamientos) =>
      tratamientos.where((t) => t.activo && t.categoria == 'diario').toList();

  /// Regla de negocio de auto-archivado: un tratamiento diario se considera
  /// vencido cuando han transcurrido más de `diasDuracion` días desde su
  /// `fechaInicio`. Los tratamientos vencidos se marcan como `activo = false`
  /// para que dejen de listarse en "Tratamientos activos". Los tratamientos
  /// con `diasDuracion == 0` se consideran indefinidos y nunca vencen.
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
      if (t.fechaInicio == null || t.diasDuracion <= 0) return t;

      final fechaFin = t.fechaInicio!.add(Duration(days: t.diasDuracion));
      if (fechaReferencia.isAfter(fechaFin)) {
        return archivar(t);
      }
      return t;
    }).toList();
  }

  /// Indica si el auto-archivado produjo cambios respecto a la lista original,
  /// comparando el estado `activo` de cada tratamiento por su id.
  ///
  /// @param original la lista antes de aplicar [autoArchivarVencidos].
  /// @param actualizada la lista devuelta por [autoArchivarVencidos].
  /// @return `true` si al menos un tratamiento cambió su estado `activo`.
  bool huboCambiosDeArchivado(List<TratamientoModel> original, List<TratamientoModel> actualizada) {
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
  Future<void> guardarTratamientos(String idPerro, List<TratamientoModel> tratamientos) {
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
        final fechaNormalizada = DateTime.utc(fecha.year, fecha.month, fecha.day);

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
