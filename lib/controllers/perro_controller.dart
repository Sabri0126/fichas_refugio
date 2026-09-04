import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/perro_model.dart';

/// Controlador encargado de la lógica de negocio y de acceso a Firestore de
/// los perros del refugio: lectura/escritura de fichas, validaciones de
/// formulario, cálculo de edades y sincronización del árbol de familiares.
/// No contiene código de UI.
class PerroController {
  final CollectionReference<Map<String, dynamic>> _perrosRef =
      FirebaseFirestore.instance.collection('perros');

  /// Escucha en tiempo real todos los perros de la colección `perros`.
  ///
  /// @return un `Stream` que emite la lista completa de [PerroModel] cada vez
  /// que hay un cambio en la colección.
  Stream<List<PerroModel>> observarPerros() {
    return _perrosRef.snapshots().map(
          (snapshot) => snapshot.docs.map((doc) => PerroModel.fromMap(doc.data(), doc.id)).toList(),
        );
  }

  /// Escucha en tiempo real un perro puntual por su id de documento.
  ///
  /// @param id id del documento del perro en la colección `perros`.
  /// @return un `Stream` que emite el [PerroModel] actualizado, o `null` si
  /// el documento fue eliminado.
  Stream<PerroModel?> observarPerroPorId(String id) {
    return _perrosRef.doc(id).snapshots().map(
          (snapshot) => snapshot.exists ? PerroModel.fromMap(snapshot.data()!, snapshot.id) : null,
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
  /// estado `'inactivo'` (fallecidos) quedan con la edad congelada.
  ///
  /// @param perro el perro sobre el cual calcular la edad.
  /// @return la edad estimada en años.
  int calcularEdadEstimada(PerroModel perro) {
    if (perro.estado == 'inactivo') {
      return perro.edad;
    }

    final anioBase = perro.edadAnioBase ?? DateTime.now().year;
    final aniosTranscurridos = DateTime.now().year - anioBase;

    return perro.edad + (aniosTranscurridos > 0 ? aniosTranscurridos : 0);
  }

  /// Genera el texto descriptivo de la edad de un perro para mostrar en la UI,
  /// contemplando los casos de edad indeterminada y de cachorros (edad en meses).
  ///
  /// @param perro el perro sobre el cual generar el texto.
  /// @return el texto de edad listo para mostrarse (p. ej. `'Edad estimada: 3 años'`).
  String formatearEdadTexto(PerroModel perro) {
    if (perro.edadIndeterminada) {
      return 'Edad: Indeterminada';
    }

    if (perro.edad == 0) {
      return 'Edad: ${perro.meses} meses';
    }

    return 'Edad estimada: ${calcularEdadEstimada(perro)} años';
  }

  /// Formatea una fecha en formato `dd/mm/yyyy` para mostrarla en la UI.
  ///
  /// @param fecha la fecha a formatear, puede ser `null`.
  /// @return el texto formateado, o `'No registrada'` si `fecha` es `null`.
  String formatearFecha(DateTime? fecha) {
    if (fecha == null) return 'No registrada';
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
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

  /// Guarda (crea o actualiza) la ficha de un perro, sincroniza la relación
  /// inversa con sus familiares vinculados y dispara el recálculo de edades
  /// de los cachorros, todo en una única transacción por lotes (`WriteBatch`).
  ///
  /// @param perro los datos del perro a guardar. Si `perro.id` está vacío, se
  /// genera un nuevo documento; en caso contrario se actualiza el existente.
  /// @return el id del documento guardado (nuevo o existente).
  Future<String> guardarPerro(PerroModel perro) async {
    final docRef = perro.id.isEmpty ? _perrosRef.doc() : _perrosRef.doc(perro.id);
    final idPerroActual = docRef.id;

    final datosPerro = perro.toMap();

    // La galería se gestiona exclusivamente desde sus propios métodos
    // (agregarFotoAGaleria, editarFotoDeGaleria, etc.), no desde este
    // formulario, así que se inyecta el estado previo del documento para no
    // pisarla con el valor por defecto ([]) que trae `perro`.
    if (perro.id.isNotEmpty) {
      final snapshotActual = await docRef.get();
      final galeriaPrevia = snapshotActual.data()?['galeria'];
      datosPerro['galeria'] = galeriaPrevia is List ? galeriaPrevia : <Map<String, dynamic>>[];
    }

    final batch = FirebaseFirestore.instance.batch();
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

    await _actualizarEdadesCachorros(batch, idPerroActual);
    await batch.commit();

    return idPerroActual;
  }

  /// Regla de negocio de envejecimiento incremental: recorre los perros
  /// cachorros (edad en años igual a `0`) y, si transcurrieron meses
  /// completos desde la última actualización, incrementa sus meses o los
  /// convierte a `1` año al llegar a los `12` meses. No afecta a perros con
  /// edad indeterminada ni a los fallecidos/inactivos, que quedan congelados.
  ///
  /// @param batch el lote de escritura de Firestore donde se acumulan las
  /// actualizaciones (se agrega a la misma transacción que guarda la ficha).
  /// @param idExcluir id del perro que se está guardando en esta misma
  /// operación, para no reprocesarlo dos veces.
  /// @return un `Future` que se completa cuando se agregaron las
  /// actualizaciones necesarias al `batch` (la escritura real ocurre al
  /// hacer `batch.commit()`).
  Future<void> _actualizarEdadesCachorros(WriteBatch batch, String idExcluir) async {
    final ahora = DateTime.now();
    final cachorrosSnapshot = await _perrosRef.where('edad', isEqualTo: 0).get();

    for (final doc in cachorrosSnapshot.docs) {
      if (doc.id == idExcluir) continue;

      final datos = doc.data();

      // Los perros fallecidos quedan congelados: nunca deben envejecer.
      final fechaFallecimiento = datos['fecha_fallecimiento'];
      final tieneFechaFallecimiento = fechaFallecimiento != null && fechaFallecimiento.toString().trim().isNotEmpty;
      if (tieneFechaFallecimiento || datos['estado']?.toString() == 'inactivo') continue;

      if (datos['edad_indeterminada'] == true) continue;

      final ultimaActualizacion = _fechaDesdeValor(datos['ultima_actualizacion_edad']) ?? _fechaDesdeValor(datos['fecha_ingreso']);
      if (ultimaActualizacion == null) continue;

      final mesesPasados = (ahora.year - ultimaActualizacion.year) * 12 + ahora.month - ultimaActualizacion.month;
      if (mesesPasados <= 0) continue;

      final mesesActuales = int.tryParse(datos['meses']?.toString() ?? '') ?? 0;
      final nuevoTotalMeses = mesesActuales + mesesPasados;

      if (nuevoTotalMeses >= 12) {
        batch.update(doc.reference, {
          'edad': 1,
          'meses': 0,
          'ultima_actualizacion_edad': Timestamp.fromDate(ahora),
        });
      } else {
        batch.update(doc.reference, {
          'meses': nuevoTotalMeses,
          'ultima_actualizacion_edad': Timestamp.fromDate(ahora),
        });
      }
    }
  }

  DateTime? _fechaDesdeValor(dynamic valor) {
    if (valor is Timestamp) return valor.toDate();
    if (valor is DateTime) return valor;
    if (valor is String) return DateTime.tryParse(valor);
    return null;
  }

  /// Elimina definitivamente la ficha de un perro de Firestore.
  ///
  /// @param id id del documento del perro a eliminar.
  /// @return un `Future` que se completa cuando el documento fue eliminado.
  Future<void> eliminarPerro(String id) {
    return _perrosRef.doc(id).delete();
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

    final galeria = List<dynamic>.from(data['galeria'] ?? []);
    final indice = galeria.indexWhere((foto) => (foto is Map ? foto['url']?.toString() : foto?.toString()) == urlAnterior);
    if (indice != -1) {
      final item = Map<String, dynamic>.from(galeria[indice] as Map);
      item['url'] = urlNueva;
      galeria[indice] = item;
      await _perrosRef.doc(id).update({'galeria': galeria});
    }
  }

  /// Agrega una nueva foto a la galería del perro.
  ///
  /// @param id id del documento del perro.
  /// @param url URL de la foto ya subida a Storage.
  /// @param texto descripción opcional de la foto.
  /// @return un `Future` que se completa cuando se guardó el cambio.
  Future<void> agregarFotoAGaleria(String id, String url, String texto) {
    return _perrosRef.doc(id).update({
      'galeria': FieldValue.arrayUnion([
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
  Future<void> editarFotoDeGaleria(String id, int indice, String nuevoTexto) async {
    final snapshot = await _perrosRef.doc(id).get();
    final data = snapshot.data();
    if (data == null) return;

    final galeria = List<dynamic>.from(data['galeria'] ?? []);
    if (indice < 0 || indice >= galeria.length) return;

    final urlActual = (galeria[indice] is Map) ? (galeria[indice] as Map)['url'] : null;
    galeria[indice] = {'url': urlActual, 'texto': nuevoTexto};

    await _perrosRef.doc(id).update({'galeria': galeria});
  }

  /// Elimina una foto de la galería según su posición y devuelve su URL para
  /// que la capa de almacenamiento (Storage) pueda borrar el archivo físico.
  ///
  /// @param id id del documento del perro.
  /// @param indice posición de la foto dentro de la lista `galeria`.
  /// @return la URL de la foto eliminada, o `null` si no tenía URL o el
  /// índice no existía.
  Future<String?> eliminarFotoDeGaleria(String id, int indice) async {
    final snapshot = await _perrosRef.doc(id).get();
    final data = snapshot.data();
    if (data == null) return null;

    final galeria = List<dynamic>.from(data['galeria'] ?? []);
    if (indice < 0 || indice >= galeria.length) return null;

    final fotoAEliminar = galeria[indice];
    galeria.removeAt(indice);

    await _perrosRef.doc(id).update({'galeria': galeria});

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
