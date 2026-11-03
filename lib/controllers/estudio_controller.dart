import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/estudio_model.dart';

/// Archivos de estudios y de la galería pública. Los tests usan una memoria.
abstract class AlmacenEstudios {
  Future<void> subirJpeg(String ruta, Uint8List bytes);
  Future<Uint8List?> bajar(String ruta, {required int maxBytes, required Duration timeout});
  Future<void> borrar(String ruta);
  Future<Uint8List?> bajarUrl(String url);
  Future<String> subirPublico(String ruta, Uint8List bytes);
  Future<void> borrarUrl(String url);
}

class AlmacenFirebase implements AlmacenEstudios {
  AlmacenFirebase(this._storage);

  /// El contentType de un estudio. La galería pública no lo usa: va con putFile.
  static const contentTypeJpeg = 'image/jpeg';

  final FirebaseStorage _storage;

  @override
  Future<void> subirJpeg(String ruta, Uint8List bytes) {
    return _storage.ref(ruta).putData(bytes, SettableMetadata(contentType: contentTypeJpeg));
  }

  @override
  Future<Uint8List?> bajar(String ruta, {required int maxBytes, required Duration timeout}) {
    return _storage.ref(ruta).getData(maxBytes).timeout(timeout);
  }

  @override
  Future<void> borrar(String ruta) async {
    try {
      await _storage.ref(ruta).delete();
    } catch (_) {}
  }

  @override
  Future<Uint8List?> bajarUrl(String url) async {
    try {
      return await _storage.refFromURL(url).getData(20 * 1024 * 1024).timeout(const Duration(seconds: 20));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> borrarUrl(String url) async {
    try {
      await _storage.refFromURL(url).delete();
    } catch (_) {}
  }

  @override
  Future<String> subirPublico(String ruta, Uint8List bytes) async {
    final ref = _storage.ref(ruta);
    await ref.putData(bytes, SettableMetadata(contentType: contentTypeJpeg));
    return ref.getDownloadURL();
  }
}

/// Memoria para tests. [subirPublico] es la única vía que pide una URL.
class AlmacenMemoria implements AlmacenEstudios {
  final Map<String, Uint8List> archivos = {};
  final Map<String, Uint8List> porUrl = {};
  var pidioUrlPublica = false;

  @override
  Future<void> subirJpeg(String ruta, Uint8List bytes) async {
    archivos[ruta] = Uint8List.fromList(bytes);
  }

  @override
  Future<Uint8List?> bajar(String ruta, {required int maxBytes, required Duration timeout}) async {
    final bytes = archivos[ruta];
    if (bytes == null || bytes.length > maxBytes) return null;
    return bytes;
  }

  @override
  Future<void> borrar(String ruta) async {
    archivos.remove(ruta);
  }

  @override
  Future<Uint8List?> bajarUrl(String url) async => porUrl[url];

  @override
  Future<void> borrarUrl(String url) async {
    porUrl.remove(url);
    archivos.removeWhere((ruta, _) => 'https://memoria.local/$ruta' == url);
  }

  @override
  Future<String> subirPublico(String ruta, Uint8List bytes) async {
    pidioUrlPublica = true;
    archivos[ruta] = Uint8List.fromList(bytes);
    final url = 'https://memoria.local/$ruta';
    porUrl[url] = Uint8List.fromList(bytes);
    return url;
  }
}

class EstudioController {
  EstudioController({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseStorage Function()? leerStorage,
    AlmacenEstudios? almacen,
  }) {
    _firestore = firestore;
    _storage = storage;
    _leerStorage = leerStorage;
    _almacenInyectado = almacen;
  }

  late final FirebaseFirestore? _firestore;
  late final FirebaseStorage? _storage;
  late final FirebaseStorage Function()? _leerStorage;
  late final AlmacenEstudios? _almacenInyectado;

  static const topeBytes = 20 * 1024 * 1024;
  static const espera = Duration(seconds: 20);

  FirebaseFirestore get _db {
    final db = _firestore;
    if (db == null) throw StateError('EstudioController sin Firestore');
    return db;
  }

  AlmacenEstudios get _almacen {
    final inyectado = _almacenInyectado;
    if (inyectado != null) return inyectado;
    final storage = _storage ?? _leerStorage?.call();
    if (storage == null) {
      throw StateError('EstudioController sin almacenamiento');
    }
    return AlmacenFirebase(storage);
  }

  CollectionReference<Map<String, dynamic>> _estudios(String perroId) {
    return _db.collection('perros').doc(perroId).collection('estudios');
  }

  Stream<List<EstudioModel>> observar(String perroId) {
    return _estudios(perroId).orderBy('orden').snapshots().map(
          (snapshot) => [for (final doc in snapshot.docs) EstudioModel.fromMap(doc.data(), doc.id)],
        );
  }

  Future<Uint8List?> descargar(String ruta) {
    return _almacen.bajar(ruta, maxBytes: topeBytes, timeout: espera);
  }

  String rutaDe(String perroId, String id) => 'estudios_medicos/$perroId/$id.jpg';

  Future<EstudioModel> agregar(String perroId, Uint8List archivo, String texto) async {
    final id = _db.collection('perros').doc().id;
    final ruta = rutaDe(perroId, id);
    await _almacen.subirJpeg(ruta, archivo);
    try {
      final orden = await _siguienteOrden(perroId);
      final estudio = EstudioModel(
        id: id,
        ruta: ruta,
        texto: texto,
        orden: orden,
        creado: DateTime.now(),
      );
      await crearDocumento(perroId, estudio);
      return estudio;
    } catch (e) {
      await _almacen.borrar(ruta);
      rethrow;
    }
  }

  Future<void> crearDocumento(String perroId, EstudioModel estudio) {
    return _estudios(perroId).doc(estudio.id).set(estudio.toMap());
  }

  Future<void> editarTexto(String perroId, String estudioId, String texto) {
    return _estudios(perroId).doc(estudioId).update({'texto': texto});
  }

  /// Borra el documento y el archivo. Si el archivo ya no está, sigue.
  Future<void> eliminar(String perroId, EstudioModel estudio) async {
    await _estudios(perroId).doc(estudio.id).delete();
    await _almacen.borrar(estudio.ruta);
  }

  Future<void> quitarDocumento(String perroId, String estudioId) {
    return _estudios(perroId).doc(estudioId).delete();
  }

  Future<void> restaurarDocumento(String perroId, EstudioModel estudio) {
    return crearDocumento(perroId, estudio);
  }

  Future<void> borrarArchivo(String ruta) => _almacen.borrar(ruta);

  /// Sube el recorte a una ruta nueva, actualiza el documento y borra la anterior.
  Future<EstudioModel> recortar(String perroId, EstudioModel estudio, Uint8List archivo) async {
    final id = _db.collection('perros').doc().id;
    final ruta = rutaDe(perroId, id);
    final anterior = estudio.ruta;
    await _almacen.subirJpeg(ruta, archivo);
    try {
      await _estudios(perroId).doc(estudio.id).update({'ruta': ruta});
    } catch (e) {
      await _almacen.borrar(ruta);
      rethrow;
    }
    await _almacen.borrar(anterior);
    return estudio.copyWith(ruta: ruta);
  }

  /// Galería pública → estudios. Copia, registra y recién ahí quita el origen.
  Future<void> moverDesdeGaleria({
    required String perroId,
    required int indice,
    required String? fotoPerfil,
  }) async {
    final ref = _db.collection('perros').doc(perroId);
    final data = (await ref.get()).data();
    if (data == null) return;
    final galeria = List<dynamic>.from(data['galeria'] ?? []);
    if (indice < 0 || indice >= galeria.length) return;
    final foto = galeria[indice];
    if (foto is! Map) return;
    final url = foto['url']?.toString() ?? '';
    final texto = (foto['texto'] ?? foto['descripcion'] ?? '').toString();
    final bytes = await _almacen.bajarUrl(url);
    if (bytes == null) throw StateError('No se pudo leer la foto');

    final id = _db.collection('perros').doc().id;
    final ruta = rutaDe(perroId, id);
    await _almacen.subirJpeg(ruta, bytes);
    final estudio = EstudioModel(
      id: id,
      ruta: ruta,
      texto: texto,
      orden: await _siguienteOrden(perroId),
      creado: DateTime.now(),
      origenUrl: url,
    );
    try {
      await crearDocumento(perroId, estudio);
      galeria.removeAt(indice);
      await ref.update({'galeria': galeria});
    } catch (e) {
      await _estudios(perroId).doc(id).delete().catchError((_) {});
      await _almacen.borrar(ruta);
      rethrow;
    }
    if (url.isNotEmpty && url != (fotoPerfil ?? '')) {
      try {
        await _almacen.borrarUrl(url);
      } catch (_) {}
    }
  }

  /// Estudios → galería pública. La foto legacy ya está en `galeria_perros/`.
  Future<void> moverHaciaGaleria({
    required String perroId,
    required EntradaEstudio entrada,
  }) async {
    if (entrada.esLegacy) {
      await _moverLegacyAGaleria(perroId, entrada.indiceLegacy!);
      return;
    }
    final estudio = entrada.estudio!;
    final bytes = await _almacen.bajar(estudio.ruta, maxBytes: topeBytes, timeout: espera);
    if (bytes == null) throw StateError('No se pudo leer el estudio');
    final nombre = 'galeria_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final url = await _almacen.subirPublico('galeria_perros/$nombre', bytes);
    final ref = _db.collection('perros').doc(perroId);
    try {
      await ref.update({
        'galeria': FieldValue.arrayUnion([
          {'url': url, 'texto': estudio.texto},
        ]),
      });
    } catch (e) {
      await _almacen.borrar('galeria_perros/$nombre');
      rethrow;
    }
    try {
      await quitarDocumento(perroId, estudio.id);
    } catch (e) {
      final data = (await ref.get()).data();
      final galeria = List<dynamic>.from(data?['galeria'] ?? []);
      galeria.removeWhere((item) => item is Map && item['url'] == url);
      await ref.update({'galeria': galeria});
      await _almacen.borrar('galeria_perros/$nombre');
      rethrow;
    }
    await _almacen.borrar(estudio.ruta);
  }

  /// Editar una foto vieja: primero pasa a la subcolección y después sale del campo.
  Future<EstudioModel> migrarLegacy({
    required String perroId,
    required int indice,
    required String texto,
  }) async {
    final ref = _db.collection('perros').doc(perroId);
    final data = (await ref.get()).data();
    final lista = List<dynamic>.from(data?['galeria_estudios'] ?? []);
    if (indice < 0 || indice >= lista.length) {
      throw StateError('El estudio viejo ya no está');
    }
    final foto = lista[indice];
    final url = foto is Map ? foto['url']?.toString() ?? '' : '';
    final bytes = await _almacen.bajarUrl(url);
    if (bytes == null) throw StateError('No se pudo leer el estudio');
    final id = _db.collection('perros').doc().id;
    final ruta = rutaDe(perroId, id);
    await _almacen.subirJpeg(ruta, bytes);
    final estudio = EstudioModel(
      id: id,
      ruta: ruta,
      texto: texto,
      orden: await _siguienteOrden(perroId),
      creado: DateTime.now(),
      origenUrl: url,
    );
    try {
      await crearDocumento(perroId, estudio);
      lista.removeAt(indice);
      await ref.update({'galeria_estudios': lista});
    } catch (e) {
      await _estudios(perroId).doc(id).delete().catchError((_) {});
      await _almacen.borrar(ruta);
      rethrow;
    }
    return estudio;
  }

  Future<void> quitarLegacy(String perroId, int indice) async {
    final ref = _db.collection('perros').doc(perroId);
    final data = (await ref.get()).data();
    final lista = List<dynamic>.from(data?['galeria_estudios'] ?? []);
    if (indice < 0 || indice >= lista.length) return;
    lista.removeAt(indice);
    await ref.update({'galeria_estudios': lista});
  }

  Future<void> restaurarLegacy(String perroId, String url, String texto) {
    return _db.collection('perros').doc(perroId).update({
      'galeria_estudios': FieldValue.arrayUnion([
        {'url': url, 'texto': texto},
      ]),
    });
  }

  Future<void> eliminarDelPerro(String perroId) async {
    final snapshot = await _estudios(perroId).get();
    for (final doc in snapshot.docs) {
      final ruta = doc.data()['ruta']?.toString() ?? '';
      if (ruta.isNotEmpty) await _almacen.borrar(ruta);
      await doc.reference.delete();
    }
  }

  Future<int> _siguienteOrden(String perroId) async {
    final snapshot = await _estudios(perroId).get();
    var maximo = -1;
    for (final doc in snapshot.docs) {
      final orden = doc.data()['orden'];
      final valor = orden is int ? orden : int.tryParse('$orden') ?? 0;
      if (valor > maximo) maximo = valor;
    }
    return maximo + 1;
  }

  Future<void> _moverLegacyAGaleria(String perroId, int indice) async {
    final ref = _db.collection('perros').doc(perroId);
    final data = (await ref.get()).data();
    if (data == null) return;
    final origen = List<dynamic>.from(data['galeria_estudios'] ?? []);
    if (indice < 0 || indice >= origen.length) return;
    final foto = origen.removeAt(indice);
    final llegada = List<dynamic>.from(data['galeria'] ?? []);
    llegada.add(foto);
    await ref.update({'galeria_estudios': origen, 'galeria': llegada});
  }
}
