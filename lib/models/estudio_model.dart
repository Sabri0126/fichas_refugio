import 'package:cloud_firestore/cloud_firestore.dart';

/// Mientras sea true, la ficha también muestra las fotos viejas de `galeria_estudios`
/// que todavía no tienen un documento en la subcolección.
const bool kLeerEstudiosLegacy = true;

/// Un estudio médico guardado en `perros/{perroId}/estudios/{id}`.
///
/// [ruta] es la ruta de Storage, sin token. [origenUrl] solo lo escribe la migración.
class EstudioModel {
  final String id;
  final String ruta;
  final String texto;
  final int orden;
  final DateTime creado;
  final String? origenUrl;

  const EstudioModel({
    required this.id,
    required this.ruta,
    required this.texto,
    required this.orden,
    required this.creado,
    this.origenUrl,
  });

  factory EstudioModel.fromMap(Map<String, dynamic> data, String id) {
    final creado = data['creado'];
    return EstudioModel(
      id: id,
      ruta: data['ruta']?.toString() ?? '',
      texto: data['texto']?.toString() ?? '',
      orden: data['orden'] is int ? data['orden'] as int : int.tryParse('${data['orden']}') ?? 0,
      creado: creado is Timestamp ? creado.toDate() : DateTime.now(),
      origenUrl: data['origenUrl']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ruta': ruta,
      'texto': texto,
      'orden': orden,
      'creado': Timestamp.fromDate(creado),
      if (origenUrl != null && origenUrl!.isNotEmpty) 'origenUrl': origenUrl,
    };
  }

  EstudioModel copyWith({String? ruta, String? texto, int? orden}) {
    return EstudioModel(
      id: id,
      ruta: ruta ?? this.ruta,
      texto: texto ?? this.texto,
      orden: orden ?? this.orden,
      creado: creado,
      origenUrl: origenUrl,
    );
  }
}

/// Una foto de la sección, nueva o todavía colgada del campo viejo.
class EntradaEstudio {
  final EstudioModel? estudio;
  final int? indiceLegacy;
  final String? urlLegacy;
  final String texto;

  const EntradaEstudio._({this.estudio, this.indiceLegacy, this.urlLegacy, required this.texto});

  factory EntradaEstudio.nueva(EstudioModel estudio) {
    return EntradaEstudio._(estudio: estudio, texto: estudio.texto);
  }

  factory EntradaEstudio.legacy({required int indice, required String url, required String texto}) {
    return EntradaEstudio._(indiceLegacy: indice, urlLegacy: url, texto: texto);
  }

  bool get esLegacy => estudio == null;

  String get clave => estudio?.ruta ?? urlLegacy ?? '';
}

/// Documentos de la subcolección más las fotos viejas que nadie migró todavía.
List<EntradaEstudio> unirEstudios(List<EstudioModel> documentos, List<Map<String, dynamic>> legacy) {
  final ordenados = [...documentos]..sort((a, b) => a.orden.compareTo(b.orden));
  final entradas = [for (final estudio in ordenados) EntradaEstudio.nueva(estudio)];
  if (!kLeerEstudiosLegacy) return entradas;
  final origenes = {
    for (final estudio in documentos)
      if (estudio.origenUrl != null && estudio.origenUrl!.isNotEmpty) estudio.origenUrl!,
  };
  for (var i = 0; i < legacy.length; i++) {
    final url = legacy[i]['url']?.toString() ?? '';
    if (url.isEmpty || origenes.contains(url)) continue;
    final texto = (legacy[i]['texto'] ?? legacy[i]['descripcion'] ?? '').toString();
    entradas.add(EntradaEstudio.legacy(indice: i, url: url, texto: texto));
  }
  return entradas;
}
