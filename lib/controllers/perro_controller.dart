import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/egreso_model.dart';
import '../models/perro_model.dart';
import '../models/peso_model.dart';
import '../models/recordatorio_model.dart';
import '../models/seguimiento_model.dart';
import '../models/tratamiento_model.dart';
import '../services/nombre_usuario.dart';
import '../services/fotos_service.dart';
import 'estudio_controller.dart';

/// Una emisión de [PerroController.observarPerroConOrigen].
class LecturaPerro {
  final PerroModel? perro;
  final bool desdeCache;

  const LecturaPerro({required this.perro, required this.desdeCache});
}

/// Controlador encargado de la lógica de negocio y de acceso a Firestore de
/// los perros del refugio: lectura/escritura de fichas, validaciones de
/// formulario, cálculo de edades y sincronización del árbol de familiares.
/// No contiene código de UI.
class PerroController {
  PerroController({FirebaseFirestore? firestore, this._fotos, this._estudios}) {
    _firestore = firestore;
  }

  late final FirebaseFirestore? _firestore;
  final FotosService? _fotos;
  final EstudioController? _estudios;

  FirebaseFirestore get _db {
    final db = _firestore;
    if (db == null) throw StateError('PerroController sin Firestore');
    return db;
  }

  CollectionReference<Map<String, dynamic>> get _perrosRef => _db.collection('perros');

  /// Escucha en tiempo real todos los perros de la colección `perros`.
  ///
  /// @return un `Stream` que emite la lista completa de [PerroModel] cada vez
  /// que hay un cambio en la colección.
  Stream<List<PerroModel>> observarPerros() {
    return _perrosRef.snapshots().map(
          (snapshot) => snapshot.docs.map((doc) => PerroModel.fromMap(doc.data(), doc.id)).toList(),
        );
  }

  /// Una sola escucha de la colección, sin cambios de metadata: en Windows
  /// esos eventos dejaban la lista quieta y trababan el guardado.
  /// La primera emisión suele salir de la copia local aunque haya WiFi.
  /// [snapshotsInSync] avisa cuando el servidor ya respondió y apaga el aviso.
  Stream<({List<PerroModel> perros, bool desdeCache})> observarListaConOrigen() {
    List<PerroModel>? previa;
    var enCache = false;
    var alDia = false;
    final salida = StreamController<({List<PerroModel> perros, bool desdeCache})>();

    void emitir() {
      final lista = previa;
      if (lista == null || salida.isClosed) return;
      salida.add((perros: lista, desdeCache: enCache && !alDia));
    }

    final documentos = _perrosRef.snapshots().listen(
      (snapshot) {
        final copiaLocal = snapshot.metadata.isFromCache && !snapshot.metadata.hasPendingWrites;
        enCache = copiaLocal;
        if (!copiaLocal) alDia = true;
        previa = [for (final doc in snapshot.docs) PerroModel.fromMap(doc.data(), doc.id)];
        emitir();
      },
      onError: salida.addError,
    );

    StreamSubscription<void>? sincronia;
    try {
      sincronia = _db.snapshotsInSync().listen(
        (_) {
          alDia = true;
          emitir();
        },
        onError: (_) {},
      );
    } catch (_) {}

    salida.onCancel = () {
      documentos.cancel();
      sincronia?.cancel();
    };
    return salida.stream;
  }

  /// `true` cuando Firestore está sirviendo la copia local, sin red.
  Stream<bool> observarDesdeCache() {
    return _perrosRef.snapshots(includeMetadataChanges: true).map(
          (snapshot) => snapshot.metadata.isFromCache,
        );
  }

  /// Escucha en tiempo real un perro puntual por su id de documento.
  ///
  /// @param id id del documento del perro en la colección `perros`.
  /// @return un `Stream` que emite el [PerroModel] actualizado, o `null` si
  /// el documento fue eliminado.
  Stream<PerroModel?> observarPerroPorId(String id) {
    return observarPerroConOrigen(id).map((lectura) => lectura.perro);
  }

  /// Igual que [observarPerroPorId], e indica si la emisión sale de la caché.
  ///
  /// Incluye cambios de metadata para distinguir la copia local del servidor
  /// aunque el documento no haya cambiado.
  Stream<LecturaPerro> observarPerroConOrigen(String id) {
    return _perrosRef.doc(id).snapshots(includeMetadataChanges: true).map(
          (snapshot) => LecturaPerro(
            perro: snapshot.exists ? PerroModel.fromMap(snapshot.data()!, snapshot.id) : null,
            desdeCache: snapshot.metadata.isFromCache,
          ),
        );
  }

  /// Obtiene, en una sola consulta, la lista completa de perros. Utilizado
  /// para poblar selectores (p. ej. el listado de posibles familiares).
  ///
  /// @return un `Future` con la lista de [PerroModel] existentes.
  Future<List<PerroModel>> obtenerListaPerros() async {
    final snapshot = await _perrosRef.get();
    return snapshot.docs.map((doc) => PerroModel.fromMap(doc.data(), doc.id)).toList();
  }

  /// Lee una sola vez el documento del perro. Devuelve null si no existe.
  Future<PerroModel?> obtenerPerroPorId(String id) async {
    final snapshot = await _perrosRef.doc(id).get();
    if (!snapshot.exists) return null;
    return PerroModel.fromMap(snapshot.data()!, snapshot.id);
  }

  /// Valida el campo de nombre del formulario de ficha.
  ///
  /// @param valor el texto ingresado por el usuario.
  /// @return un mensaje de error si el nombre está vacío, o `null` si es válido.
  String? validarNombre(String? valor) {
    if (valor == null || valor.trim().isEmpty) return 'Ingresá un nombre';
    return null;
  }

  /// Valida el campo de meses del formulario de ficha: debe estar entre 0 y 11,
  /// ya que a partir de los 12 meses la edad pasa a contarse en años.
  ///
  /// @param valor el texto ingresado por el usuario.
  /// @return un mensaje de error si el valor es inválido, o `null` si es correcto.
  String? validarMeses(String? valor) {
    if (valor != null && valor.isNotEmpty && (int.tryParse(valor) ?? 0) >= 12) {
      return 'El valor debe estar entre 0 y 11. A partir de los 12 meses equivale a 1 año.';
    }
    return null;
  }

  /// Calcula la edad estimada actual de un perro a partir de su edad base y
  /// del año en que se registró dicha edad (`edad_anio_base`). Los perros con
  /// estado `'inactivo'` (fallecidos) o `'egresado'` quedan con la edad congelada.
  ///
  /// No aplica a quienes [cuentaPorMeses]: su edad ya está guardada en años y meses.
  ///
  /// @param perro el perro sobre el cual calcular la edad.
  /// @return la edad estimada en años.
  static int calcularEdadEstimada(PerroModel perro) {
    if (perro.estado == 'inactivo' || perro.estado == 'egresado' || cuentaPorMeses(perro)) {
      return perro.edad;
    }

    final anioBase = perro.edadAnioBase ?? DateTime.now().year;
    final aniosTranscurridos = DateTime.now().year - anioBase;

    return perro.edad + (aniosTranscurridos > 0 ? aniosTranscurridos : 0);
  }

  /// Edad que se carga en el formulario. Quien no cuenta por meses ve la edad
  /// estimada, así al guardar con base en el año actual no pierde años.
  static int edadEnFormulario(PerroModel perro) =>
      cuentaPorMeses(perro) ? perro.edad : calcularEdadEstimada(perro);

  /// Ingresó con menos de un año, o el documento todavía no tiene la marca
  /// pero la edad guardada es 0.
  static bool cuentaPorMeses(PerroModel perro) =>
      !perro.edadIndeterminada && (perro.cuentaMeses || perro.edad == 0);

  /// Meses de calendario entre [desde] y [hasta], sin mirar el día.
  static int mesesCalendario(DateTime desde, DateTime hasta) =>
      (hasta.year - desde.year) * 12 + hasta.month - desde.month;

  /// Suma [mesesPasados] a una edad en años y meses.
  /// [cruzoUnAnio] es true solo si el mes en que llega a 12 meses es el último
  /// mes sumado, o sea el mes actual.
  static ({int edad, int meses, bool cruzoUnAnio})? avanzarEdad({
    required int edad,
    required int meses,
    required int mesesPasados,
  }) {
    if (mesesPasados <= 0) return null;
    final total = edad * 12 + meses + mesesPasados;
    if (total < 0) return null;
    final antesDelUltimoMes = total - 1;
    return (
      edad: total ~/ 12,
      meses: total % 12,
      cruzoUnAnio: antesDelUltimoMes < 12 && total >= 12,
    );
  }

  /// Del más joven al más viejo. Si empatan los años, desempatan los meses.
  static int compararPorEdad(PerroModel a, PerroModel b) {
    final porAnios = calcularEdadEstimada(a).compareTo(calcularEdadEstimada(b));
    if (porAnios != 0) return porAnios;
    return a.meses.compareTo(b.meses);
  }

  /// True si la ficha que se guarda sigue contando la edad por meses.
  /// Lo es con edad 0, o si ya contaba y la edad en años no se corrigió.
  /// Con edad indeterminada no cuenta.
  static bool cuentaMesesAlGuardar({
    required int edadNueva,
    required bool? yaContaba,
    required int? edadAnterior,
    required bool edadIndeterminada,
  }) {
    if (edadIndeterminada) return false;
    if (edadNueva == 0) return true;
    return yaContaba == true && edadAnterior == edadNueva;
  }

  /// Genera el texto descriptivo de la edad de un perro para mostrar en la UI,
  /// contemplando los casos de edad indeterminada y de cachorros (edad en meses).
  ///
  /// @param perro el perro sobre el cual generar el texto.
  /// @return el texto de edad listo para mostrarse (p. ej. `'Edad estimada: 3 años'`).
  static String formatearEdadTexto(PerroModel perro) {
    if (perro.edadIndeterminada) {
      return 'Edad: Indeterminada';
    }

    if (cuentaPorMeses(perro)) {
      if (perro.edad == 0) {
        return perro.meses == 1 ? 'Edad: 1 mes' : 'Edad: ${perro.meses} meses';
      }
      final anios = perro.edad;
      final unidadAnio = anios == 1 ? 'año' : 'años';
      if (perro.meses <= 0) return 'Edad estimada: $anios $unidadAnio';
      final unidadMes = perro.meses == 1 ? 'mes' : 'meses';
      return 'Edad estimada: $anios $unidadAnio y ${perro.meses} $unidadMes';
    }

    final anios = calcularEdadEstimada(perro);
    return 'Edad estimada: $anios ${anios == 1 ? 'año' : 'años'}';
  }

  /// Castrado o castrada, según el sexo. Si no lo está, también concuerda.
  static String formatearCastracion(PerroModel perro) {
    final hembra = perro.sexo == 'hembra';
    if (perro.castrado) return hembra ? 'Castrada' : 'Castrado';
    return hembra ? 'No castrada' : 'No castrado';
  }

  /// Formatea una fecha en formato `dd/mm/yyyy` para mostrarla en la UI.
  ///
  /// @param fecha la fecha a formatear, puede ser `null`.
  /// @return el texto formateado, o `'No registrada'` si `fecha` es `null`.
  String formatearFecha(DateTime? fecha) {
    if (fecha == null) return 'No registrada';
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
  }

  /// Texto de UI para el motivo de egreso.
  ///
  /// @param motivo `'adopcion'`, `'familia'` o null.
  /// @return `'Adoptado'`, `'Volvió con su familia'` o `''`.
  static String formatearMotivoEgreso(String? motivo) {
    if (motivo == 'adopcion') return 'Adoptado';
    if (motivo == 'familia') return 'Volvió con su familia';
    return '';
  }

  /// Archiva el egreso vigente cuando el perro deja de estar egresado.
  /// No toca Firebase. No muta [original.historialEgresos].
  static List<EgresoModel> calcularHistorialEgresos({
    required PerroModel? original,
    required String estadoNuevo,
    String? motivo,
    DateTime? fechaEgreso,
    String? nota,
    DateTime? fechaRegreso,
    List<EgresoModel>? historialBase,
  }) {
    if (original == null) return const [];
    final base = historialBase ?? original.historialEgresos;
    if (original.estado == 'egresado' && estadoNuevo != 'egresado') {
      final notaLimpia = nota?.trim();
      return [
        ...base,
        EgresoModel(
          motivo: motivo,
          fechaEgreso: fechaEgreso,
          nota: notaLimpia == null || notaLimpia.isEmpty ? null : notaLimpia,
          fechaRegreso: estadoNuevo == 'activo' ? fechaRegreso : null,
        ),
      ];
    }
    return List<EgresoModel>.from(base);
  }

  /// Copia [lista] con la entrada [indice] reemplazada. No muta [lista].
  static List<EgresoModel> reemplazarEgreso(List<EgresoModel> lista, int indice, EgresoModel nuevo) {
    if (indice < 0 || indice >= lista.length) {
      throw RangeError.index(indice, lista, 'indice');
    }
    return [
      for (var i = 0; i < lista.length; i++)
        if (i == indice) nuevo else lista[i],
    ];
  }

  /// Copia [lista] sin la entrada [indice]. No muta [lista].
  static List<EgresoModel> quitarEgreso(List<EgresoModel> lista, int indice) {
    if (indice < 0 || indice >= lista.length) {
      throw RangeError.index(indice, lista, 'indice');
    }
    return [
      for (var i = 0; i < lista.length; i++)
        if (i != indice) lista[i],
    ];
  }

  /// Campos `editado_por` y `editado_en` de una edición con sesión.
  /// El nombre visible gana sobre el email; si ambos están vacíos, queda "Administrador".
  static Map<String, dynamic> marcaEdicion({
    required String? nombreVisible,
    required String? email,
    required DateTime ahora,
  }) {
    final nombre = nombreVisible?.trim() ?? '';
    final correo = email?.trim() ?? '';
    return {
      'editado_por': nombre.isNotEmpty
          ? nombre
          : (correo.isNotEmpty ? correo : 'Administrador'),
      'editado_en': Timestamp.fromDate(ahora),
    };
  }

  /// Null si el egreso se puede guardar.
  static String? validarEgreso(EgresoModel egreso) {
    final hoy = DateTime.now();
    final hoyDia = DateTime(hoy.year, hoy.month, hoy.day);
    final egresoDia = _dia(egreso.fechaEgreso);
    final regresoDia = _dia(egreso.fechaRegreso);
    if (egresoDia != null && egresoDia.isAfter(hoyDia)) {
      return 'La fecha de egreso no puede ser futura.';
    }
    if (regresoDia != null && egresoDia != null && regresoDia.isBefore(egresoDia)) {
      return 'La fecha de regreso no puede ser anterior a la de egreso.';
    }
    return null;
  }

  /// Suma una medición al array `pesos` si ese id todavía no está.
  Future<void> agregarPeso(String idPerro, PesoModel peso) async {
    final ref = _perrosRef.doc(idPerro);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();
      if (data == null) return;
      final crudos = data['pesos'];
      final lista = crudos is List ? List<dynamic>.from(crudos) : <dynamic>[];
      final yaEsta = lista.any((item) {
        if (item is! Map) return false;
        return item['id']?.toString() == peso.id;
      });
      if (yaEsta) return;
      lista.add(peso.toMap());
      tx.update(ref, {'pesos': lista});
    });
  }

  /// Suma un registro médico al array `tratamientos` si ese id todavía no está.
  Future<void> agregarTratamiento(String idPerro, TratamientoModel tratamiento) {
    return _agregarEnLista(idPerro, 'tratamientos', tratamiento.id, tratamiento.toMap());
  }

  /// Suma un recordatorio al array `recordatorios` si ese id todavía no está.
  Future<void> agregarRecordatorio(String idPerro, RecordatorioModel recordatorio) {
    return _agregarEnLista(idPerro, 'recordatorios', recordatorio.id, recordatorio.toMap());
  }

  /// Suma un seguimiento al array `seguimientos` si ese id todavía no está.
  Future<void> agregarSeguimiento(String idPerro, SeguimientoModel seguimiento) {
    return _agregarEnLista(idPerro, 'seguimientos', seguimiento.id, seguimiento.toMap());
  }

  /// Marca de la sesión actual. Vacía si no hay usuario logueado.
  Map<String, dynamic> _marcaEdicionActual() {
    final usuario = _usuarioActual();
    if (usuario == null) return const {};
    return marcaEdicion(
      nombreVisible: NombreUsuario.visible(usuario),
      email: usuario.email,
      ahora: DateTime.now(),
    );
  }

  User? _usuarioActual() {
    try {
      return FirebaseAuth.instance.currentUser;
    } catch (_) {
      return null;
    }
  }

  Future<void> _agregarEnLista(
    String idPerro,
    String campo,
    String id,
    Map<String, dynamic> mapa,
  ) async {
    final ref = _perrosRef.doc(idPerro);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();
      if (data == null) return;
      final crudos = data[campo];
      final lista = crudos is List ? List<dynamic>.from(crudos) : <dynamic>[];
      final yaEsta = lista.any((item) {
        if (item is! Map) return false;
        return item['id']?.toString() == id;
      });
      if (yaEsta) return;
      lista.add(mapa);
      tx.update(ref, {
        campo: lista,
        ..._marcaEdicionActual(),
      });
    });
  }

  /// Pone `activo` en false en el seguimiento indicado, sin tocar el resto del array.
  Future<void> cerrarSeguimiento(String idPerro, String idSeguimiento) async {
    final ref = _perrosRef.doc(idPerro);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();
      if (data == null) return;
      final crudos = data['seguimientos'];
      if (crudos is! List) return;
      var huboCambio = false;
      final actualizados = crudos.map((item) {
        if (item is! Map) return item;
        final mapa = Map<String, dynamic>.from(item);
        if (mapa['id']?.toString() == idSeguimiento && mapa['activo'] == true) {
          mapa['activo'] = false;
          huboCambio = true;
        }
        return mapa;
      }).toList();
      if (!huboCambio) return;
      tx.update(ref, {'seguimientos': actualizados});
    });
  }

  /// Reemplaza o quita una entrada solo si sigue igual a [esperado].
  /// [nuevo] null la elimina. Escribe `[]` si no queda ninguna.
  Future<void> actualizarHistorialEgresos(
    String idPerro,
    EgresoModel esperado,
    int indice,
    EgresoModel? nuevo,
  ) async {
    final ref = _perrosRef.doc(idPerro);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();
      if (data == null) throw const HistorialDesactualizadoException();
      final lista = _leerHistorial(data['historial_egresos']);
      if (indice < 0 || indice >= lista.length || !_mismoEgreso(lista[indice], esperado)) {
        throw const HistorialDesactualizadoException();
      }
      final siguiente = nuevo == null
          ? quitarEgreso(lista, indice)
          : reemplazarEgreso(lista, indice, nuevo);
      tx.update(ref, {
        'historial_egresos': siguiente.map((egreso) => egreso.toMap()).toList(),
      });
    });
  }

  static DateTime? _dia(DateTime? fecha) {
    if (fecha == null) return null;
    return DateTime(fecha.year, fecha.month, fecha.day);
  }

  static bool _mismoEgreso(EgresoModel actual, EgresoModel esperado) {
    final izq = actual.toMap();
    final der = esperado.toMap();
    if (izq.length != der.length) return false;
    for (final entrada in izq.entries) {
      if (der[entrada.key] != entrada.value) return false;
    }
    return true;
  }

  List<EgresoModel> _leerHistorial(dynamic valor) {
    if (valor is! List) return const [];
    final historial = <EgresoModel>[];
    for (final item in valor) {
      if (item is! Map) continue;
      try {
        historial.add(EgresoModel.fromMap(Map<String, dynamic>.from(item)));
      } catch (_) {}
    }
    return historial;
  }

  /// Determina la relación inversa a mostrar en el familiar vinculado (p. ej.
  /// si A es "Madre" de B, B es "Hijo/a" de A, respetando el sexo del perro
  /// original para elegir entre "Hijo" e "Hija").
  ///
  /// @param relacion la relación elegida desde el perro que se está editando.
  /// @param sexoOriginal el sexo del perro que se está editando (`'macho'`/`'hembra'`).
  /// @return la relación inversa a guardar en el perro familiar vinculado.
  String obtenerRelacionInversa(String relacion, String sexoOriginal) {
    if (relacion == 'Madre' || relacion == 'Padre') {
      return sexoOriginal == 'hembra' ? 'Hija' : 'Hijo';
    }
    if (relacion == 'Hijo/a') {
      return sexoOriginal == 'hembra' ? 'Madre' : 'Padre';
    }
    return 'Hermano/a';
  }

  /// Guarda (crea o actualiza) la ficha de un perro y sincroniza la relación
  /// inversa con sus familiares vinculados, en un único lote.
  ///
  /// Si [edadOriginal] y [mesesOriginales] son los que tenía la ficha al abrir
  /// el formulario, y quien cuenta por meses no los cambió, se conservan la
  /// edad, los meses y la última actualización que ya escribió la función.
  ///
  /// @param perro los datos del perro a guardar. Si `perro.id` está vacío, se
  /// genera un nuevo documento; en caso contrario se actualiza el existente.
  /// @return el id del documento guardado (nuevo o existente).
  Future<String> guardarPerro(
    PerroModel perro, {
    int? edadOriginal,
    int? mesesOriginales,
  }) async {
    final docRef = perro.id.isEmpty ? _perrosRef.doc() : _perrosRef.doc(perro.id);
    final idPerroActual = docRef.id;

    final datosPerro = perro.toMap();
    if (perro.motivoEgreso == null) datosPerro['motivo_egreso'] = FieldValue.delete();
    if (perro.fechaEgreso == null) datosPerro['fecha_egreso'] = FieldValue.delete();
    if (perro.notaEgreso == null) datosPerro['nota_egreso'] = FieldValue.delete();
    if (perro.historialEgresos.isEmpty) datosPerro['historial_egresos'] = FieldValue.delete();
    datosPerro.addAll(_marcaEdicionActual());

    // La galería y los estudios viejos se preservan: este formulario no los pisa.
    if (perro.id.isNotEmpty) {
      final snapshotActual = await docRef.get();
      final datosActuales = snapshotActual.data();
      final galeriaPrevia = datosActuales?['galeria'];
      final estudiosPrevios = datosActuales?['galeria_estudios'];
      datosPerro['galeria'] = galeriaPrevia is List ? galeriaPrevia : <Map<String, dynamic>>[];
      datosPerro['galeria_estudios'] = estudiosPrevios is List ? estudiosPrevios : <Map<String, dynamic>>[];
      if (datosActuales != null &&
          _conservarEdadDelDocumento(
            perro: perro,
            edadOriginal: edadOriginal,
            mesesOriginales: mesesOriginales,
          )) {
        if (datosActuales.containsKey('edad')) datosPerro['edad'] = datosActuales['edad'];
        if (datosActuales.containsKey('meses')) datosPerro['meses'] = datosActuales['meses'];
        if (datosActuales.containsKey('ultima_actualizacion_edad')) {
          datosPerro['ultima_actualizacion_edad'] = datosActuales['ultima_actualizacion_edad'];
        } else {
          datosPerro.remove('ultima_actualizacion_edad');
        }
      }
    }

    final batch = _db.batch();
    batch.set(docRef, datosPerro, SetOptions(merge: true));

    for (final familiar in perro.parientes) {
      final idFamiliar = (familiar['id'] ?? '').toString();
      if (idFamiliar.isEmpty || idFamiliar == idPerroActual) continue;

      final relacionInversa = obtenerRelacionInversa(
        familiar['relacion']?.toString() ?? 'Hermano/a',
        perro.sexo,
      );

      batch.update(_perrosRef.doc(idFamiliar), {
        'parientes': FieldValue.arrayUnion([
          {
            'id': idPerroActual,
            'id_documento': idPerroActual,
            'nombre': perro.nombre,
            'relacion': relacionInversa,
          }
        ])
      });
    }

    await batch.commit();

    return idPerroActual;
  }

  /// El staff no tocó la edad y la función pudo haber sumado un mes mientras
  /// el formulario estaba abierto.
  static bool _conservarEdadDelDocumento({
    required PerroModel perro,
    required int? edadOriginal,
    required int? mesesOriginales,
  }) {
    if (edadOriginal == null || mesesOriginales == null) return false;
    if (perro.edadIndeterminada) return false;
    if (!(perro.cuentaMeses || perro.edad == 0)) return false;
    return perro.edad == edadOriginal && perro.meses == mesesOriginales;
  }

  /// Elimina la ficha y lo que queda afuera del documento: el vínculo en los
  /// otros familiares, las fotos de Storage y los avisos de ese perro.
  /// El calendario sale de la ficha, así que al borrar el documento desaparece.
  /// Si una foto o un aviso no se puede borrar, la ficha igual se elimina.
  Future<void> eliminarPerro(String id) async {
    PerroModel? perro;
    try {
      perro = await obtenerPerroPorId(id);
    } catch (_) {}
    if (perro != null) {
      try {
        await _quitarDeFamiliares(id);
      } catch (_) {}
      try {
        await _borrarFotos(perro);
      } catch (_) {}
      try {
        await _estudios?.eliminarDelPerro(id);
      } catch (_) {}
      try {
        await _borrarAvisos(id);
      } catch (_) {}
    }
    await _perrosRef.doc(id).delete();
  }

  Future<void> _quitarDeFamiliares(String id) async {
    final snapshot = await _perrosRef.get();
    WriteBatch? lote;
    var operaciones = 0;

    Future<void> enviar() async {
      final pendiente = lote;
      if (pendiente == null || operaciones == 0) return;
      lote = null;
      operaciones = 0;
      await pendiente.commit();
    }

    for (final doc in snapshot.docs) {
      if (doc.id == id) continue;
      final crudo = doc.data()['parientes'];
      if (crudo is! List) continue;
      final queda = <dynamic>[];
      var cambio = false;
      for (final item in crudo) {
        if (item is Map) {
          final mapa = Map<String, dynamic>.from(item);
          final familiarId = (mapa['id'] ?? mapa['id_documento'] ?? '').toString();
          if (familiarId == id) {
            cambio = true;
            continue;
          }
        }
        queda.add(item);
      }
      if (!cambio) continue;
      lote ??= _db.batch();
      lote!.update(doc.reference, {'parientes': queda});
      operaciones++;
      if (operaciones >= 400) await enviar();
    }
    await enviar();
  }

  Future<void> _borrarFotos(PerroModel perro) async {
    final urls = <String>{};
    final perfil = perro.fotoPerfil?.trim() ?? '';
    if (perfil.isNotEmpty) urls.add(perfil);
    for (final foto in [...perro.galeria, ...perro.galeriaEstudios]) {
      final url = foto['url']?.toString().trim() ?? '';
      if (url.isNotEmpty) urls.add(url);
    }
    for (final url in urls) {
      final fotos = _fotos;
      // Sin servicio no hay Storage. Lo dejan así los tests que no borran fotos;
      // el provider de la app siempre lo pasa.
      if (fotos == null) continue;
      try {
        await fotos.borrarPorUrl(url);
      } catch (_) {}
    }
  }

  Future<void> _borrarAvisos(String id) async {
    final avisos = _db.collection('notificaciones');
    final snapshot = await avisos.where('id_perro', isEqualTo: id).get();
    WriteBatch? lote;
    var operaciones = 0;

    Future<void> enviar() async {
      final pendiente = lote;
      if (pendiente == null || operaciones == 0) return;
      lote = null;
      operaciones = 0;
      await pendiente.commit();
    }

    for (final doc in snapshot.docs) {
      lote ??= _db.batch();
      lote!.delete(doc.reference);
      operaciones++;
      if (operaciones >= 400) await enviar();
    }
    await enviar();
  }

  /// Actualiza únicamente la foto de perfil de un perro.
  ///
  /// @param id id del documento del perro.
  /// @param url nueva URL de la foto de perfil almacenada en Storage.
  /// @return un `Future` que se completa cuando se guardó el cambio.
  Future<void> actualizarFotoPerfil(String id, String url) {
    return _perrosRef.doc(id).update({'foto_perfil': url});
  }

  /// Reemplaza la URL de una foto ya existente (perfil o galería) por una
  /// nueva, usado al recortar una foto que ya estaba guardada.
  ///
  /// @param id id del documento del perro.
  /// @param urlAnterior URL actual de la foto que se está reemplazando.
  /// @param urlNueva nueva URL generada tras el recorte.
  /// @return un `Future` que se completa cuando se guardó el cambio.
  Future<void> actualizarUrlDeFoto(String id, String urlAnterior, String urlNueva) async {
    final snapshot = await _perrosRef.doc(id).get();
    final data = snapshot.data();
    if (data == null) return;

    if (data['foto_perfil']?.toString() == urlAnterior) {
      await actualizarFotoPerfil(id, urlNueva);
      return;
    }

    for (final campo in ['galeria', 'galeria_estudios']) {
      final fotos = List<dynamic>.from(data[campo] ?? []);
      final indice = fotos.indexWhere((foto) => (foto is Map ? foto['url']?.toString() : foto?.toString()) == urlAnterior);
      if (indice == -1) continue;
      final item = Map<String, dynamic>.from(fotos[indice] as Map);
      item['url'] = urlNueva;
      fotos[indice] = item;
      await _perrosRef.doc(id).update({campo: fotos});
      return;
    }
  }

  /// Agrega una nueva foto a la galería del perro.
  ///
  /// @param id id del documento del perro.
  /// @param url URL de la foto ya subida a Storage.
  /// @param texto descripción opcional de la foto.
  /// @return un `Future` que se completa cuando se guardó el cambio.
  Future<void> agregarFotoAGaleria(String id, String url, String texto) {
    return _agregarFoto(id, 'galeria', url, texto);
  }

  Future<void> _agregarFoto(String id, String campo, String url, String texto) {
    return _perrosRef.doc(id).update({
      campo: FieldValue.arrayUnion([
        {'url': url, 'texto': texto}
      ])
    });
  }

  /// Edita la descripción de una foto de la galería según su posición.
  ///
  /// @param id id del documento del perro.
  /// @param indice posición de la foto dentro de la lista `galeria`.
  /// @param nuevoTexto nueva descripción de la foto.
  /// @return un `Future` que se completa cuando se guardó el cambio.
  Future<void> editarFotoDeGaleria(String id, int indice, String nuevoTexto) {
    return editarTextoDeFoto(id, 'galeria', indice, nuevoTexto);
  }

  Future<void> editarTextoDeFoto(String id, String campo, int indice, String nuevoTexto) async {
    final snapshot = await _perrosRef.doc(id).get();
    final data = snapshot.data();
    if (data == null) return;

    final fotos = List<dynamic>.from(data[campo] ?? []);
    if (indice < 0 || indice >= fotos.length) return;

    final urlActual = (fotos[indice] is Map) ? (fotos[indice] as Map)['url'] : null;
    fotos[indice] = {'url': urlActual, 'texto': nuevoTexto};

    await _perrosRef.doc(id).update({campo: fotos});
  }

  /// Elimina una foto de la galería según su posición y devuelve su URL para
  /// que la capa de almacenamiento (Storage) pueda borrar el archivo físico.
  ///
  /// @param id id del documento del perro.
  /// @param indice posición de la foto dentro de la lista `galeria`.
  /// @return la URL de la foto eliminada, o `null` si no tenía URL o el
  /// índice no existía.
  Future<String?> eliminarFotoDeGaleria(String id, int indice) {
    return eliminarFoto(id, 'galeria', indice);
  }

  Future<String?> eliminarFoto(String id, String campo, int indice) async {
    final snapshot = await _perrosRef.doc(id).get();
    final data = snapshot.data();
    if (data == null) return null;

    final fotos = List<dynamic>.from(data[campo] ?? []);
    if (indice < 0 || indice >= fotos.length) return null;

    final fotoAEliminar = fotos[indice];
    fotos.removeAt(indice);

    await _perrosRef.doc(id).update({campo: fotos});

    final urlFoto = (fotoAEliminar is Map ? fotoAEliminar['url'] : null)?.toString();
    return (urlFoto != null && urlFoto.isNotEmpty) ? urlFoto : null;
  }

  /// Guarda el nuevo orden de las fotos tras un reordenamiento manual,
  /// separando cuál queda como foto de perfil (la primera) del resto de la
  /// galería.
  ///
  /// @param id id del documento del perro.
  /// @param nuevaFotoPerfil URL que quedará como foto de perfil, o `null`
  /// para quitar la foto de perfil.
  /// @param nuevaGaleria lista ordenada del resto de las fotos.
  /// @return un `Future` que se completa cuando se guardó el nuevo orden.
  Future<void> reordenarFotos(String id, String? nuevaFotoPerfil, List<Map<String, dynamic>> nuevaGaleria) {
    return _perrosRef.doc(id).update({
      'foto_perfil': nuevaFotoPerfil,
      'galeria': nuevaGaleria,
    });
  }
}

/// La entrada del historial cambió desde que se abrió la ficha.
class HistorialDesactualizadoException implements Exception {
  const HistorialDesactualizadoException();
}
