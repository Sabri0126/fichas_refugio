import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

/// Subida de una foto pública. [contentType] queda null porque galería,
/// recorte y perfil se suben con `putFile`, sin metadata.
class SubidaFoto {
  final String ruta;
  final String? contentType;

  const SubidaFoto(this.ruta, this.contentType);
}

/// Archivos de galería, recorte y perfil. Los tests usan una memoria.
abstract class AlmacenFotos {
  Future<String> subirArchivo(String ruta, File archivo);
  Future<void> borrarUrl(String url);
}

class AlmacenFotosFirebase implements AlmacenFotos {
  AlmacenFotosFirebase(this._storage);

  final FirebaseStorage _storage;

  @override
  Future<String> subirArchivo(String ruta, File archivo) async {
    final ref = _storage.ref(ruta);
    await ref.putFile(archivo);
    return ref.getDownloadURL();
  }

  @override
  Future<void> borrarUrl(String url) {
    return _storage.refFromURL(url).delete();
  }
}

/// Memoria para tests. No escribe contentType: imita `putFile`.
class AlmacenFotosMemoria implements AlmacenFotos {
  final List<SubidaFoto> subidas = [];
  final List<String> borradas = [];
  Object? errorSubida;

  @override
  Future<String> subirArchivo(String ruta, File archivo) async {
    final error = errorSubida;
    if (error != null) throw error;
    subidas.add(SubidaFoto(ruta, null));
    return 'https://memoria.local/$ruta';
  }

  @override
  Future<void> borrarUrl(String url) async {
    borradas.add(url);
  }
}

/// Elige y sube fotos de galería, recorte y perfil. No comprime.
///
/// El provider que lo arma no es autoDispose: lo usan la ficha y el formulario.
class FotosService {
  FotosService({
    FirebaseStorage? storage,
    AlmacenFotos? almacen,
    ImagePicker? picker,
    DateTime Function()? reloj,
  }) {
    _storage = storage;
    _almacenInyectado = almacen;
    _picker = picker;
    _reloj = reloj ?? DateTime.now;
  }

  late final FirebaseStorage? _storage;
  late final AlmacenFotos? _almacenInyectado;
  late final ImagePicker? _picker;
  late final DateTime Function() _reloj;

  AlmacenFotos get _almacen {
    final inyectado = _almacenInyectado;
    if (inyectado != null) return inyectado;
    final storage = _storage;
    if (storage == null) {
      throw StateError('FotosService sin almacenamiento');
    }
    return AlmacenFotosFirebase(storage);
  }

  Future<XFile?> elegirDeGaleria() {
    final picker = _picker ?? ImagePicker();
    return picker.pickImage(source: ImageSource.gallery);
  }

  Future<String> subirGaleria(File archivo) {
    return _subir('galeria_perros/galeria_${_ms()}.jpg', archivo);
  }

  Future<String> subirRecorte(File archivo) {
    return _subir('galeria_perros/recorte_${_ms()}.jpg', archivo);
  }

  Future<String> subirPerfil(File archivo) {
    return _subir('fotos_perfil/${_ms()}.jpg', archivo);
  }

  Future<void> borrarPorUrl(String url) {
    return _almacen.borrarUrl(url);
  }

  Future<String> _subir(String ruta, File archivo) {
    return _almacen.subirArchivo(ruta, archivo);
  }

  int _ms() => _reloj().millisecondsSinceEpoch;
}
