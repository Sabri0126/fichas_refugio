import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/estado_duracion.dart';
import '../models/tratamiento_model.dart';

/// Cómo se pinta un día en la tira de dosis de la ficha.
enum EstadoMarcaDosis { dada, pendiente, olvidada, pausa }

/// Un día visible de la tira, ya clasificado.
class MarcaDiaDosis {
  final DateTime dia;
  final EstadoMarcaDosis estado;

  const MarcaDiaDosis(this.dia, this.estado);
}

/// Controlador encargado de la lógica de negocio de los tratamientos médicos
/// de un perro: creación, edición, archivado, registro de dosis y el cálculo
/// de auto-archivado por vencimiento de fechas. No contiene código de UI.
class TratamientoController {
  TratamientoController({FirebaseFirestore? firestore}) {
    _firestore = firestore;
  }

  late final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _perrosRef => _db.collection('perros');

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
  String formatearFechaISO(DateTime fecha) => fechaIso(fecha);

  /// Fecha calendario en `yyyy-MM-dd`, sin hora.
  static String fechaIso(DateTime fecha) {
    return '${fecha.year.toString().padLeft(4, '0')}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';
  }

  /// Día y mes, `dd/mm`.
  static String fechaCorta(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    return '$dia/$mes';
  }

  static DateTime soloFecha(DateTime fecha) => DateTime(fecha.year, fecha.month, fecha.day);

  /// Crea un nuevo [TratamientoModel] aplicando las reglas de negocio según
  /// su categoría:
  /// - `'diario'`: queda `activo = true`, sin registro de dosis inicial y con
  ///   hora de recordatorio.
  /// - `'unico'` / `'higiene'` / `'evento'` / `'veterinaria'` / `'vacuna'`: se
  ///   considera un evento puntual. Queda `activo = true` (no se pausa al
  ///   crearlo) y se registra la propia `fechaInicio` como primera dosis.
  ///
  /// @param categoria tipo de tratamiento (`'diario'`, `'unico'`, `'higiene'`,
  ///   `'evento'`, `'veterinaria'`, `'vacuna'`).
  /// @param medicacion nombre de la medicación, procedimiento o vacuna.
  /// @param indicaciones indicaciones o dosis administrada.
  /// @param notas razón de la aplicación o notas (`'unico'` y `'vacuna'`).
  /// @param veterinario nombre de quien atendió (`'veterinaria'`).
  /// @param diagnostico diagnóstico de la visita (`'veterinaria'`).
  /// @param fechaInicio fecha de inicio o de aplicación del evento.
  /// @param diasDuracion días de duración (solo aplica a categoría `'diario'`).
  /// @param horaRecordatorio hora `HH:mm` del recordatorio diario (solo `'diario'`).
  /// @param fechaProximoRecordatorio próximo recordatorio opcional (`'unico'` y `'higiene'`).
  /// @param notificar si el diario avisa a los celulares. `false` lo calla en todos.
  /// @return el [TratamientoModel] recién creado, listo para agregarse a la
  /// lista de tratamientos del perro.
  TratamientoModel crearTratamiento({
    required String categoria,
    required String medicacion,
    required String indicaciones,
    String notas = '',
    String veterinario = '',
    String diagnostico = '',
    required DateTime fechaInicio,
    int diasDuracion = 0,
    String? horaRecordatorio,
    DateTime? fechaProximoRecordatorio,
    bool notificar = true,
    String tipoDuracion = TratamientoModel.tipoHastaAviso,
  }) {
    final esEventoUnico = categoria != 'diario';

    if (esEventoUnico) {
      return TratamientoModel(
        id: generarId(),
        categoria: categoria,
        medicacion: medicacion,
        indicaciones: indicaciones,
        notas: notas,
        veterinario: veterinario,
        diagnostico: diagnostico,
        fechaInicio: fechaInicio,
        diasDuracion: 0,
        // Se registra la fecha elegida en el formulario (no la de hoy) para que el TableCalendar la ubique.
        registroDosis: [formatearFechaISO(fechaInicio)],
        activo: true,
        fechaProximoRecordatorio:
            (categoria == 'unico' || categoria == 'higiene')
            ? fechaProximoRecordatorio
            : null,
        notificar: notificar,
      );
    }

    final duracion = _duracionDiaria(tipo: tipoDuracion, dias: diasDuracion);
    return TratamientoModel(
      id: generarId(),
      categoria: categoria,
      medicacion: medicacion,
      indicaciones: indicaciones,
      notas: notas,
      veterinario: veterinario,
      diagnostico: diagnostico,
      fechaInicio: fechaInicio,
      diasDuracion: duracion.dias,
      horaRecordatorio: horaRecordatorio,
      registroDosis: const [],
      activo: true,
      notificar: notificar,
      tipoDuracion: duracion.tipo,
    );
  }

  /// Días fijos con 0 días pasan a hasta nuevo aviso. Los otros tipos no guardan días.
  static ({String tipo, int dias}) _duracionDiaria({required String tipo, required int dias}) {
    if (tipo == TratamientoModel.tipoDePorVida) return (tipo: tipo, dias: 0);
    if (tipo == TratamientoModel.tipoDias && dias > 0) return (tipo: tipo, dias: dias);
    return (tipo: TratamientoModel.tipoHastaAviso, dias: 0);
  }

  /// Edita los campos editables de un tratamiento existente (medicación,
  /// indicaciones, días de duración, fecha de inicio y hora de recordatorio).
  /// En un evento puntual, el registro de dosis queda en el día nuevo: el
  /// calendario lo usa para ubicar la aplicación. Un diario conserva su
  /// historial de dosis.
  ///
  /// @param actual el tratamiento a editar.
  /// @param medicacion nuevo nombre de la medicación.
  /// @param indicaciones nuevas indicaciones.
  /// @param diasDuracion nueva duración en días.
  /// @param fechaInicio nueva fecha de inicio.
  /// @param horaRecordatorio nueva hora del recordatorio.
  /// @param notificar si el diario avisa. `null` conserva el valor anterior.
  /// @return una nueva instancia de [TratamientoModel] con los campos actualizados.
  TratamientoModel editarTratamiento(
    TratamientoModel actual, {
    required String medicacion,
    required String indicaciones,
    String? notas,
    String? veterinario,
    String? diagnostico,
    required int diasDuracion,
    required DateTime fechaInicio,
    required String horaRecordatorio,
    bool? notificar,
    String? tipoDuracion,
    DateTime? fechaSuspension,
    bool limpiarSuspension = false,
    List<CambioDosis>? cambiosDosis,
  }) {
    final duracion = actual.categoria == 'diario'
        ? _duracionDiaria(tipo: tipoDuracion ?? actual.tipoDuracion, dias: diasDuracion)
        : (tipo: actual.tipoDuracion, dias: diasDuracion);
    return actual.copyWith(
      medicacion: medicacion,
      indicaciones: indicaciones,
      notas: notas,
      veterinario: veterinario,
      diagnostico: diagnostico,
      diasDuracion: duracion.dias,
      tipoDuracion: duracion.tipo,
      fechaInicio: fechaInicio,
      horaRecordatorio: horaRecordatorio,
      registroDosis: actual.categoria == 'diario' ? null : [formatearFechaISO(fechaInicio)],
      notificar: notificar,
      fechaSuspension: fechaSuspension,
      limpiarSuspension: limpiarSuspension,
      cambiosDosis: cambiosDosis,
    );
  }

  /// Decide si un diario pausado vuelve a estar activo después de editarlo.
  /// Solo se reactiva cuando antes estaba [FaseTratamiento.finalizado] y la
  /// edición lo saca de esa fase (más días, otra fecha de inicio o indefinido).
  /// Una pausa hecha a mano, o un tratamiento que sigue terminado, queda pausado.
  /// Un diario que ya estaba activo, y cualquier evento puntual, se devuelven igual.
  ///
  /// @param original el tratamiento antes de la edición.
  /// @param editado el tratamiento con los campos ya editados.
  /// @param hoy fecha de referencia para la fase. Por defecto, la fecha actual.
  /// @return [editado] con `activo` según la regla anterior.
  static TratamientoModel resolverActivoTrasEditar(
    TratamientoModel original,
    TratamientoModel editado, {
    DateTime? hoy,
  }) {
    if (original.categoria != 'diario' || original.activo) return editado;

    final antes = calcularEstadoDuracion(original, hoy: hoy).fase;
    final despues = calcularEstadoDuracion(editado, hoy: hoy).fase;
    final reactivar =
        antes == FaseTratamiento.finalizado && despues != FaseTratamiento.finalizado;
    if (!reactivar) {
      if (editado.activo == false) return editado;
      return editado.copyWith(activo: false);
    }
    return editado.copyWith(activo: true, limpiarSuspension: true);
  }

  /// Período en el que el diario puede tener dosis.
  /// El fin es el más temprano entre el último día fijo y [TratamientoModel.fechaSuspension].
  /// Un indefinido activo no tiene fin. Uno suspendido sin fecha usa la última dosis.
  /// Un evento puntual o un diario sin fecha de inicio no tienen período.
  static ({DateTime inicio, DateTime? fin})? periodoEfectivo(TratamientoModel tratamiento) {
    if (tratamiento.categoria != 'diario' || tratamiento.fechaInicio == null) return null;
    final inicio = soloFecha(tratamiento.fechaInicio!);
    DateTime? fin;
    if (tratamiento.tipoDuracion == TratamientoModel.tipoDias && tratamiento.diasDuracion > 0) {
      fin = DateTime(inicio.year, inicio.month, inicio.day + tratamiento.diasDuracion - 1);
    }
    if (tratamiento.fechaSuspension != null) {
      final suspension = soloFecha(tratamiento.fechaSuspension!);
      if (fin == null || suspension.isBefore(fin)) fin = suspension;
    } else if (!tratamiento.activo && fin == null) {
      fin = _ultimaDosis(tratamiento, inicio);
    }
    return (inicio: inicio, fin: fin);
  }

  /// `true` si [dia] cae dentro de [periodoEfectivo]. Sin período, cualquier día cuenta.
  /// Un fin abierto acepta desde el inicio en adelante.
  static bool diaDentroDePeriodo(TratamientoModel tratamiento, DateTime dia) {
    final periodo = periodoEfectivo(tratamiento);
    if (periodo == null) return true;
    final fecha = soloFecha(dia);
    if (fecha.isBefore(periodo.inicio)) return false;
    if (periodo.fin != null && fecha.isAfter(periodo.fin!)) return false;
    return true;
  }

  /// Fechas de [TratamientoModel.registroDosis] que caen fuera de [periodoEfectivo].
  static List<String> dosisFueraDePeriodo(TratamientoModel tratamiento) {
    final periodo = periodoEfectivo(tratamiento);
    if (periodo == null) return const [];
    final fuera = <String>[];
    for (final texto in tratamiento.registroDosis) {
      final fecha = DateTime.tryParse(texto);
      if (fecha == null) continue;
      if (!diaDentroDePeriodo(tratamiento, fecha)) fuera.add(texto);
    }
    return fuera;
  }

  /// Dosis de [TratamientoModel.registroDosis] que caen dentro de [periodoEfectivo].
  /// Las que están afuera no se cuentan, aunque sigan guardadas.
  static int contarDosisEnPeriodo(TratamientoModel tratamiento) {
    final fuera = dosisFueraDePeriodo(tratamiento).toSet();
    if (fuera.isEmpty) return tratamiento.registroDosis.length;
    var total = 0;
    for (final dosis in tratamiento.registroDosis) {
      if (!fuera.contains(dosis)) total++;
    }
    return total;
  }

  /// Cuántas dosis de [tratamientos] caen fuera de [periodoEfectivo].
  static int cantidadDosisFueraDePeriodo(Iterable<TratamientoModel> tratamientos) {
    var total = 0;
    for (final tratamiento in tratamientos) {
      total += dosisFueraDePeriodo(tratamiento).length;
    }
    return total;
  }

  /// Si [borrar] es true, quita las dosis fuera de período. Si es false, devuelve
  /// la misma lista: no se borra nada sin una confirmación explícita.
  static List<TratamientoModel> limpiarDosisFueraDePeriodo(
    List<TratamientoModel> tratamientos, {
    required bool borrar,
  }) {
    if (!borrar) return tratamientos;
    return [for (final tratamiento in tratamientos) quitarDosisFueraDePeriodo(tratamiento)];
  }

  /// Quita de [TratamientoModel.registroDosis] las fechas fuera de [periodoEfectivo].
  static TratamientoModel quitarDosisFueraDePeriodo(TratamientoModel tratamiento) {
    final fuera = dosisFueraDePeriodo(tratamiento).toSet();
    if (fuera.isEmpty) return tratamiento;
    return tratamiento.copyWith(
      registroDosis: [
        for (final dosis in tratamiento.registroDosis)
          if (!fuera.contains(dosis)) dosis,
      ],
    );
  }

  /// Dosis marcadas después de [ultimoDia]. Sirve para avisarlo antes de suspender.
  static int contarDosisPosteriores(TratamientoModel tratamiento, DateTime ultimoDia) {
    final limite = soloFecha(ultimoDia);
    var total = 0;
    for (final texto in tratamiento.registroDosis) {
      final fecha = DateTime.tryParse(texto);
      if (fecha == null) continue;
      if (soloFecha(fecha).isAfter(limite)) total++;
    }
    return total;
  }

  /// Cierra el diario en [ultimoDia], lo deja inactivo y saca las dosis posteriores.
  static TratamientoModel suspender(
    TratamientoModel tratamiento, {
    required DateTime ultimoDia,
  }) {
    if (tratamiento.categoria != 'diario') return tratamiento;
    final fin = soloFecha(ultimoDia);
    return tratamiento.copyWith(
      activo: false,
      fechaSuspension: fin,
      registroDosis: [
        for (final texto in tratamiento.registroDosis)
          if (!_esPosterior(texto, fin)) texto,
      ],
    );
  }

  static bool _esPosterior(String texto, DateTime limite) {
    final fecha = DateTime.tryParse(texto);
    if (fecha == null) return false;
    return soloFecha(fecha).isAfter(limite);
  }

  /// Cómo quedaría el historial si se suspende en [ultimoDia].
  static ({DateTime? inicio, int enPeriodo, int posteriores}) resumenSuspension(
    TratamientoModel tratamiento, {
    required DateTime ultimoDia,
  }) {
    final fin = soloFecha(ultimoDia);
    final inicio = tratamiento.fechaInicio == null ? null : soloFecha(tratamiento.fechaInicio!);
    var enPeriodo = 0;
    var posteriores = 0;
    for (final texto in tratamiento.registroDosis) {
      final fecha = DateTime.tryParse(texto);
      if (fecha == null) continue;
      final dia = soloFecha(fecha);
      if (inicio != null && dia.isBefore(inicio)) continue;
      if (dia.isAfter(fin)) {
        posteriores++;
      } else {
        enPeriodo++;
      }
    }
    return (inicio: inicio, enPeriodo: enPeriodo, posteriores: posteriores);
  }

  /// Tratamiento nuevo, con la dosis y el tipo actuales, empezando en [hoy].
  /// [id] permite armarlo en tests sin tocar Firebase.
  TratamientoModel reanudarComoNuevo(
    TratamientoModel tratamiento, {
    DateTime? hoy,
    String? id,
  }) {
    final inicio = soloFecha(hoy ?? DateTime.now());
    final tipo = tratamiento.tipoDuracion;
    return TratamientoModel(
      id: id ?? generarId(),
      categoria: 'diario',
      medicacion: tratamiento.medicacion,
      indicaciones: tratamiento.indicaciones,
      notas: tratamiento.notas,
      fechaInicio: inicio,
      diasDuracion: tipo == TratamientoModel.tipoDias ? tratamiento.diasDuracion : 0,
      horaRecordatorio: tratamiento.horaRecordatorio,
      registroDosis: const [],
      activo: true,
      notificar: tratamiento.notificar,
      tipoDuracion: tipo,
    );
  }

  /// Si un indefinido viejo no tiene fecha de suspensión, la cierra en la última dosis.
  /// Un tratamiento de días fijos no se toca: su fin ya está en la duración.
  static TratamientoModel cerrarPeriodoLegacy(TratamientoModel tratamiento) {
    if (tratamiento.activo ||
        tratamiento.fechaSuspension != null ||
        tratamiento.categoria != 'diario' ||
        tratamiento.tipoDuracion == TratamientoModel.tipoDias) {
      return tratamiento;
    }
    final inicio = tratamiento.fechaInicio;
    if (inicio == null) return tratamiento;
    final ultima = _ultimaDosis(tratamiento, soloFecha(inicio));
    if (ultima == null) return tratamiento;
    return tratamiento.copyWith(fechaSuspension: ultima);
  }

  /// Anota [nueva] desde [desde]. El primer cambio también guarda la dosis anterior.
  static TratamientoModel cambiarDosis(
    TratamientoModel tratamiento,
    String nueva, {
    required DateTime desde,
  }) {
    final iso = fechaIso(desde);
    final cambios = [...tratamiento.cambiosDosis];
    if (cambios.isEmpty) {
      final inicio = tratamiento.fechaInicio;
      final isoInicio = inicio == null ? iso : fechaIso(inicio);
      if (isoInicio != iso) {
        cambios.add(CambioDosis(desde: isoInicio, indicaciones: tratamiento.indicaciones));
      }
    }
    final indice = cambios.indexWhere((cambio) => cambio.desde == iso);
    if (indice >= 0) {
      cambios[indice] = CambioDosis(desde: iso, indicaciones: nueva);
    } else {
      cambios.add(CambioDosis(desde: iso, indicaciones: nueva));
    }
    cambios.sort((a, b) => a.desde.compareTo(b.desde));
    return tratamiento.copyWith(indicaciones: nueva, cambiosDosis: cambios);
  }

  /// Corrige el texto de la dosis vigente sin abrir un tramo nuevo.
  static TratamientoModel corregirTextoDosis(TratamientoModel tratamiento, String nuevoTexto) {
    if (tratamiento.cambiosDosis.isEmpty) {
      return tratamiento.copyWith(indicaciones: nuevoTexto);
    }
    final cambios = [...tratamiento.cambiosDosis]..sort((a, b) => a.desde.compareTo(b.desde));
    final ultimo = cambios.last;
    if (ultimo.indicaciones.trim() == tratamiento.indicaciones.trim()) {
      cambios[cambios.length - 1] = CambioDosis(desde: ultimo.desde, indicaciones: nuevoTexto);
    }
    return tratamiento.copyWith(indicaciones: nuevoTexto, cambiosDosis: cambios);
  }

  /// Dosis que regía en [dia]. Sin cambios, es la indicación actual.
  static String dosisVigenteEn(TratamientoModel tratamiento, DateTime dia) {
    if (tratamiento.cambiosDosis.isEmpty) return tratamiento.indicaciones;
    final iso = fechaIso(dia);
    final ordenados = [...tratamiento.cambiosDosis]..sort((a, b) => a.desde.compareTo(b.desde));
    CambioDosis? vigente;
    for (final cambio in ordenados) {
      if (cambio.desde.compareTo(iso) <= 0) vigente = cambio;
    }
    return vigente?.indicaciones ?? ordenados.first.indicaciones;
  }

  /// Tramos para mostrarlos en la ficha, del más viejo al más nuevo.
  static List<TramoDosis> tramosDosis(TratamientoModel tratamiento) {
    if (tratamiento.cambiosDosis.isEmpty) {
      final texto = tratamiento.indicaciones.trim();
      if (texto.isEmpty) return const [];
      final desde = tratamiento.fechaInicio == null ? null : soloFecha(tratamiento.fechaInicio!);
      return [TramoDosis(indicaciones: texto, desde: desde, hasta: null)];
    }
    final ordenados = [...tratamiento.cambiosDosis]..sort((a, b) => a.desde.compareTo(b.desde));
    final tramos = <TramoDosis>[];
    for (var i = 0; i < ordenados.length; i++) {
      final desde = DateTime.tryParse(ordenados[i].desde);
      DateTime? hasta;
      if (i + 1 < ordenados.length) {
        final siguiente = DateTime.tryParse(ordenados[i + 1].desde);
        if (siguiente != null) hasta = soloFecha(siguiente).subtract(const Duration(days: 1));
      }
      tramos.add(TramoDosis(
        indicaciones: ordenados[i].indicaciones,
        desde: desde == null ? null : soloFecha(desde),
        hasta: hasta,
      ));
    }
    return tramos;
  }

  /// Texto corto del estado, para la ficha, el formulario y la exportación.
  static String etiquetaEstado(TratamientoModel tratamiento, {DateTime? hoy}) {
    if (tratamiento.categoria != 'diario') return '';
    if (!tratamiento.activo) {
      if (tratamiento.fechaSuspension != null) {
        return 'Suspendido el ${fechaCorta(tratamiento.fechaSuspension!)}';
      }
      final fase = calcularEstadoDuracion(tratamiento, hoy: hoy).fase;
      if (fase == FaseTratamiento.finalizado &&
          tratamiento.tipoDuracion == TratamientoModel.tipoDias) {
        return 'Finalizado';
      }
      final inicio = tratamiento.fechaInicio;
      final ultima = inicio == null ? null : _ultimaDosis(tratamiento, soloFecha(inicio));
      if (ultima != null) return 'Suspendido el ${fechaCorta(ultima)}';
      return 'Suspendido';
    }
    switch (calcularEstadoDuracion(tratamiento, hoy: hoy).fase) {
      case FaseTratamiento.noIniciado:
        return 'Programado';
      case FaseTratamiento.ultimoDia:
        return 'Último día';
      case FaseTratamiento.finalizado:
        return 'Finalizado';
      case FaseTratamiento.indefinido:
      case FaseTratamiento.enCurso:
        return 'En curso';
    }
  }

  /// Nombre del tipo de duración, para chips y la exportación.
  static String etiquetaDuracion(TratamientoModel tratamiento) {
    switch (tratamiento.tipoDuracion) {
      case TratamientoModel.tipoDePorVida:
        return 'De por vida';
      case TratamientoModel.tipoHastaAviso:
        return 'Hasta nuevo aviso';
      default:
        return tratamiento.diasDuracion > 0 ? '${tratamiento.diasDuracion} días' : 'Hasta nuevo aviso';
    }
  }

  /// Día de medicación contando el inicio como día 1. Antes del inicio es 0.
  static int diaDeTratamiento(TratamientoModel tratamiento, {DateTime? hoy}) {
    final inicio = tratamiento.fechaInicio;
    if (inicio == null) return 0;
    final referencia = soloFecha(hoy ?? DateTime.now());
    final comienzo = soloFecha(inicio);
    if (referencia.isBefore(comienzo)) return 0;
    return _diasEntre(comienzo, referencia) + 1;
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
  /// Devuelve `false` sin escribir si el día queda fuera de [periodoEfectivo]
  /// o de [periodoCorreccion].
  Future<bool> toggleDosis(
    String perroId,
    TratamientoModel tratamiento,
    DateTime fechaDosis,
  ) async {
    final dia = normalizarDia(fechaDosis);
    if (!_diaDentroDeCorreccion(tratamiento, dia)) return false;

    final fechaIso = formatearFechaISO(dia);
    final docRef = _perrosRef.doc(perroId);
    var escrito = false;

    await _db.runTransaction((tx) async {
      final snapshot = await tx.get(docRef);
      final data = snapshot.data();
      if (data == null) return;

      final tratamientos = _tratamientosDesdeDocumento(data['tratamientos']);
      final indice = tratamientos.indexWhere((t) => t.id == tratamiento.id);
      if (indice == -1) return;
      if (!_diaDentroDeCorreccion(tratamientos[indice], dia)) return;

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
      escrito = true;
    });
    return escrito;
  }

  bool _diaDentroDeCorreccion(TratamientoModel tratamiento, DateTime dia) =>
      puedeMarcarDosis(tratamiento, dia);

  /// `false` si [dia] está fuera del período o de lo que se puede corregir.
  static bool puedeMarcarDosis(TratamientoModel tratamiento, DateTime dia) {
    final fecha = soloFecha(dia);
    if (!diaDentroDePeriodo(tratamiento, fecha)) return false;
    final inicio = tratamiento.fechaInicio;
    if (inicio != null && fecha.isBefore(soloFecha(inicio))) return false;
    final periodo = periodoCorreccion(tratamiento);
    if (periodo != null && fecha.isBefore(periodo.inicio)) return false;
    if (periodo != null && fecha.isAfter(periodo.fin)) return false;
    return true;
  }

  /// Copia local con la dosis del día marcada o desmarcada.
  TratamientoModel alternarDosis(
    TratamientoModel tratamiento,
    DateTime fecha,
    bool marcar,
  ) {
    if (marcar && !diaDentroDePeriodo(tratamiento, fecha)) return tratamiento;
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

  /// Suspende los diarios que siguen activos y anota el día. Los eventos no cambian.
  static List<TratamientoModel> pausarDiariosActivos(
    List<TratamientoModel> tratamientos, {
    DateTime? hoy,
  }) {
    final dia = soloFecha(hoy ?? DateTime.now());
    return [
      for (final tratamiento in tratamientos)
        tratamiento.categoria == 'diario' && tratamiento.activo
            ? tratamiento.copyWith(activo: false, fechaSuspension: dia)
            : tratamiento,
    ];
  }

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

  /// Conserva `activo: false` de un diario que el servidor pausó, salvo reanudación manual.
  /// No agrega tratamientos que solo existan en [remoto].
  static List<TratamientoModel> reconciliarPausas(
    List<TratamientoModel> local,
    List<TratamientoModel> remoto,
    Set<String> reanudados,
  ) {
    final pausadosRemotos = <String>{
      for (final tratamiento in remoto)
        if (!tratamiento.activo) tratamiento.id,
    };
    return [
      for (final tratamiento in local)
        if (tratamiento.categoria == 'diario' &&
            tratamiento.activo &&
            pausadosRemotos.contains(tratamiento.id) &&
            !reanudados.contains(tratamiento.id))
          tratamiento.copyWith(activo: false)
        else
          tratamiento,
    ];
  }

  /// Agrega al final las altas remotas que no estaban al abrir el formulario.
  /// No modifica los objetos de [local] ni de [remoto]. Ignora `id` vacío.
  static List<TratamientoModel> fusionarAltasRemotas({
    required List<TratamientoModel> local,
    required List<TratamientoModel> remoto,
    required Set<String> idsIniciales,
  }) {
    final presentes = <String>{
      for (final item in local)
        if (item.id.isNotEmpty) item.id,
    };
    final altas = <TratamientoModel>[];
    for (final item in remoto) {
      if (item.id.isEmpty || idsIniciales.contains(item.id) || presentes.contains(item.id)) {
        continue;
      }
      altas.add(item);
      presentes.add(item.id);
    }
    return [...local, ...altas];
  }

  /// Día de inicio = día 1. Sin días fijos queda indefinido.
  /// Un indefinido con inicio futuro está programado, no en curso.
  static EstadoDuracion calcularEstadoDuracion(TratamientoModel tratamiento, {DateTime? hoy}) {
    final referencia = hoy ?? DateTime.now();
    final hoyFecha = soloFecha(referencia);
    final esFijo = tratamiento.tipoDuracion == TratamientoModel.tipoDias && tratamiento.diasDuracion > 0;
    if (!esFijo || tratamiento.fechaInicio == null) {
      if (tratamiento.fechaInicio != null) {
        final inicio = soloFecha(tratamiento.fechaInicio!);
        if (hoyFecha.isBefore(inicio)) {
          return EstadoDuracion(
            fase: FaseTratamiento.noIniciado,
            diasParaInicio: _diasEntre(hoyFecha, inicio),
          );
        }
      }
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

  /// Últimos [maximo] días del tratamiento que ya empezaron y no pasaron
  /// el último día de medicación. Los días anteriores al inicio no entran.
  /// Si el tratamiento está pausado, un día sin dosis es [EstadoMarcaDosis.pausa]
  /// y no se marca como olvidado.
  static List<MarcaDiaDosis> marcasDosisRecientes(
    TratamientoModel tratamiento, {
    DateTime? hoy,
    int maximo = 5,
  }) {
    final referencia = hoy ?? DateTime.now();
    final hoyFecha = DateTime(referencia.year, referencia.month, referencia.day);
    final inicio = tratamiento.fechaInicio;
    final inicioFecha = inicio == null
        ? null
        : DateTime(inicio.year, inicio.month, inicio.day);
    final marcas = <MarcaDiaDosis>[];

    for (var i = 0; i < 21 && marcas.length < maximo; i++) {
      final dia = hoyFecha.subtract(Duration(days: i));
      if (inicioFecha != null && dia.isBefore(inicioFecha)) break;
      if (!diaDentroDePeriodo(tratamiento, dia)) continue;
      final fase = calcularEstadoDuracion(tratamiento, hoy: dia).fase;
      if (fase == FaseTratamiento.noIniciado || fase == FaseTratamiento.finalizado) {
        continue;
      }
      final iso =
          '${dia.year.toString().padLeft(4, '0')}-${dia.month.toString().padLeft(2, '0')}-${dia.day.toString().padLeft(2, '0')}';
      final dada = tratamiento.registroDosis.contains(iso);
      final EstadoMarcaDosis estado;
      if (dada) {
        estado = EstadoMarcaDosis.dada;
      } else if (!tratamiento.activo) {
        estado = EstadoMarcaDosis.pausa;
      } else if (dia == hoyFecha) {
        estado = EstadoMarcaDosis.pendiente;
      } else {
        estado = EstadoMarcaDosis.olvidada;
      }
      marcas.add(MarcaDiaDosis(dia, estado));
    }

    return marcas.reversed.toList();
  }

  /// Días en los que se puede marcar una dosis: desde el inicio hasta hoy,
  /// o hasta el último día de medicación si ese tramo ya terminó.
  /// Un diario indefinido llega hasta hoy. Antes del inicio no hay período.
  static ({DateTime inicio, DateTime fin})? periodoMarcable(
    TratamientoModel tratamiento, {
    DateTime? hoy,
  }) {
    if (tratamiento.categoria != 'diario' || tratamiento.fechaInicio == null) return null;
    final inicio = DateTime(
      tratamiento.fechaInicio!.year,
      tratamiento.fechaInicio!.month,
      tratamiento.fechaInicio!.day,
    );
    final referencia = hoy ?? DateTime.now();
    final hoyFecha = DateTime(referencia.year, referencia.month, referencia.day);
    if (hoyFecha.isBefore(inicio)) return null;
    var fin = hoyFecha;
    final efectivo = periodoEfectivo(tratamiento);
    if (efectivo?.fin != null && efectivo!.fin!.isBefore(fin)) fin = efectivo.fin!;
    if (fin.isBefore(inicio)) return null;
    return (inicio: inicio, fin: fin);
  }

  /// Período que se puede corregir sin alargar un diario ya detenido.
  /// Uno en curso usa [periodoMarcable]. Uno con la duración cumplida llega
  /// hasta su último día de medicación. Uno pausado antes de ese día, o
  /// indefinido ya pausado, llega solo hasta la última dosis registrada.
  static ({DateTime inicio, DateTime fin})? periodoCorreccion(
    TratamientoModel tratamiento, {
    DateTime? hoy,
  }) {
    final periodo = periodoMarcable(tratamiento, hoy: hoy);
    if (periodo == null || tratamiento.activo || tratamiento.fechaSuspension != null) {
      return periodo;
    }
    final fase = calcularEstadoDuracion(tratamiento, hoy: hoy).fase;
    if (fase == FaseTratamiento.finalizado) return periodo;
    final ultima = _ultimaDosis(tratamiento, periodo.inicio);
    if (ultima == null || ultima.isBefore(periodo.inicio)) {
      return (inicio: periodo.inicio, fin: periodo.inicio);
    }
    if (ultima.isAfter(periodo.fin)) return periodo;
    return (inicio: periodo.inicio, fin: ultima);
  }

  static DateTime? _ultimaDosis(TratamientoModel tratamiento, DateTime inicio) {
    DateTime? ultima;
    for (final texto in tratamiento.registroDosis) {
      final fecha = DateTime.tryParse(texto);
      if (fecha == null) continue;
      final dia = DateTime(fecha.year, fecha.month, fecha.day);
      if (dia.isBefore(inicio)) continue;
      if (ultima == null || dia.isAfter(ultima)) ultima = dia;
    }
    return ultima;
  }

  /// Hay días del período que no entran en la tira de la última semana.
  static bool hayDiasAnteriores(TratamientoModel tratamiento, {DateTime? hoy}) {
    final periodo = periodoMarcable(tratamiento, hoy: hoy);
    if (periodo == null) return false;
    final marcas = marcasDosisRecientes(tratamiento, hoy: hoy);
    if (marcas.isEmpty) return true;
    return periodo.inicio.isBefore(marcas.first.dia);
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

  /// Ids archivados, en orden. Sirve para no repetir la misma escritura.
  static String firmaArchivados(List<TratamientoModel> tratamientos) {
    return [
      for (final tratamiento in tratamientos)
        if (!tratamiento.activo) tratamiento.id,
    ].join('|');
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

  /// Reemplaza en Firestore el tratamiento con el mismo id.
  Future<void> persistirTratamiento(String idPerro, TratamientoModel actualizado) {
    return _escribirTratamientos(idPerro, (tratamientos) {
      final indice = tratamientos.indexWhere((t) => t.id == actualizado.id);
      if (indice == -1) return false;
      tratamientos[indice] = actualizado;
      return true;
    });
  }

  /// Cierra [anterior] si hacía falta y agrega [nuevo].
  Future<void> agregarTratamiento(
    String idPerro,
    TratamientoModel nuevo, {
    TratamientoModel? anterior,
  }) {
    return _escribirTratamientos(idPerro, (tratamientos) {
      if (anterior != null) {
        final indice = tratamientos.indexWhere((t) => t.id == anterior.id);
        if (indice != -1) tratamientos[indice] = anterior;
      }
      if (tratamientos.every((t) => t.id != nuevo.id)) tratamientos.add(nuevo);
      return true;
    });
  }

  Future<void> _escribirTratamientos(
    String idPerro,
    bool Function(List<TratamientoModel> tratamientos) aplicar,
  ) {
    final docRef = _perrosRef.doc(idPerro);
    return _db.runTransaction((tx) async {
      final snapshot = await tx.get(docRef);
      final data = snapshot.data();
      if (data == null) return;
      final tratamientos = _tratamientosDesdeDocumento(data['tratamientos']);
      if (!aplicar(tratamientos)) return;
      tx.update(docRef, {
        'tratamientos': tratamientos.map((t) => t.toMap()).toList(),
      });
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
      for (final fechaNormalizada in _diasEnCalendario(tratamiento)) {
        final dia = DateTime(fechaNormalizada.year, fechaNormalizada.month, fechaNormalizada.day);
        final texto = tratamiento.categoria == 'diario'
            ? dosisVigenteEn(tratamiento, dia).trim()
            : tratamiento.detalleVisible;
        final detalle = tratamiento.categoria == 'veterinaria'
            ? '🏥 ${tratamiento.medicacion}${texto.isEmpty ? '' : ' - $texto'}'
            : '${tratamiento.medicacion}${texto.isEmpty ? '' : ' · $texto'}';
        eventosCalendario.putIfAbsent(fechaNormalizada, () => []).add({
          'medicacion': tratamiento.medicacion,
          'indicaciones': texto,
          'detalle': detalle,
          'categoria': tratamiento.categoria,
        });
      }
    }

    return eventosCalendario;
  }

  /// Días en los que el historial muestra el tratamiento.
  /// Un evento puntual vive en `fechaInicio`. Si esa fecha todavía no está,
  /// se usa el registro. Un diario sigue el registro de dosis dadas.
  /// En un diario con duración fija, una dosis fuera del período no entra.
  List<DateTime> _diasEnCalendario(TratamientoModel tratamiento) {
    if (tratamiento.categoria != 'diario') {
      final inicio = tratamiento.fechaInicio;
      if (inicio != null) {
        return [DateTime.utc(inicio.year, inicio.month, inicio.day)];
      }
    }
    final dias = <DateTime>[];
    for (final texto in tratamiento.registroDosis) {
      final fecha = DateTime.tryParse(texto);
      if (fecha == null) continue;
      if (!diaDentroDePeriodo(tratamiento, fecha)) continue;
      dias.add(DateTime.utc(fecha.year, fecha.month, fecha.day));
    }
    return dias;
  }

  /// Una fila por tratamiento, de más nuevo a más viejo.
  /// Un diario con duración fija usa su período, aunque haya dosis afuera.
  /// Uno indefinido usa el rango de dosis. El resto usa su fecha.
  List<EntradaHistorial> construirHistorialLista(List<TratamientoModel> tratamientos) {
    final entradas = <EntradaHistorial>[];
    for (final tratamiento in tratamientos) {
      final dosis = <DateTime>[];
      for (final texto in tratamiento.registroDosis) {
        final fecha = DateTime.tryParse(texto);
        if (fecha == null) continue;
        dosis.add(DateTime(fecha.year, fecha.month, fecha.day));
      }
      dosis.sort();

      DateTime? inicio = tratamiento.fechaInicio == null
          ? null
          : DateTime(
              tratamiento.fechaInicio!.year,
              tratamiento.fechaInicio!.month,
              tratamiento.fechaInicio!.day,
            );
      final puntual = tratamiento.categoria != 'diario';
      final periodo = periodoEfectivo(tratamiento);
      DateTime? fin;
      if (periodo != null) {
        inicio = periodo.inicio;
        if (periodo.fin != null && !_mismoDia(periodo.inicio, periodo.fin!)) fin = periodo.fin;
      } else if (puntual && inicio != null) {
        dosis
          ..clear()
          ..add(inicio);
      } else if (dosis.isNotEmpty && (inicio == null || dosis.first.isBefore(inicio))) {
        inicio = dosis.first;
      }
      if (periodo == null &&
          dosis.isNotEmpty &&
          inicio != null &&
          !_mismoDia(inicio, dosis.last)) {
        fin = dosis.last;
      }

      final titulo = tratamiento.medicacion.trim().isEmpty ? 'Sin nombre' : tratamiento.medicacion.trim();
      entradas.add(
        EntradaHistorial(
          categoria: tratamiento.categoria,
          titulo: titulo,
          indicaciones: tratamiento.detalleVisible,
          fechaInicio: inicio,
          fechaFin: fin,
          cantidadDosis: contarDosisEnPeriodo(tratamiento),
          cuentaDosis: tratamiento.cuentaDosis,
          activo: tratamiento.activo,
          origen: tratamiento,
        ),
      );
    }
    entradas.sort((a, b) => b.fechaReferencia.compareTo(a.fechaReferencia));
    return entradas;
  }

  bool _mismoDia(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Recuerda la última firma de archivado que ya se mandó a escribir.
class MarcaArchivado {
  String? pendiente;

  /// `true` solo la primera vez que aparece [firma].
  bool reservar(String firma) {
    if (pendiente == firma) return false;
    pendiente = firma;
    return true;
  }
}

/// Escribe el archivado si la ficha sigue abierta. Si falla, [liberar] permite reintentar.
Future<void> persistirArchivadoSiMontado({
  required bool Function() montado,
  required Future<void> Function() escribir,
  required void Function() liberar,
}) {
  if (!montado()) return Future.value();
  return escribir().catchError((Object _) {
    if (montado()) liberar();
  });
}

/// Una fila del historial médico en lista.
class EntradaHistorial {
  final String categoria;
  final String titulo;
  final String indicaciones;
  final DateTime? fechaInicio;
  final DateTime? fechaFin;
  final int cantidadDosis;

  /// Un tratamiento de por vida no muestra el total.
  final bool cuentaDosis;
  final bool activo;
  final TratamientoModel origen;

  const EntradaHistorial({
    required this.categoria,
    required this.titulo,
    required this.indicaciones,
    required this.fechaInicio,
    required this.fechaFin,
    required this.cantidadDosis,
    this.cuentaDosis = true,
    required this.activo,
    required this.origen,
  });

  /// Fecha para ordenar y agrupar: la última dosis, o el inicio.
  DateTime get fechaReferencia => fechaFin ?? fechaInicio ?? DateTime.fromMillisecondsSinceEpoch(0);
}

/// Un tramo de la dosis, para la línea de tiempo.
class TramoDosis {
  final String indicaciones;
  final DateTime? desde;
  final DateTime? hasta;

  const TramoDosis({
    required this.indicaciones,
    required this.desde,
    required this.hasta,
  });
}
