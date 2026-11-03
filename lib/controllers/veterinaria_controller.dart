import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/contacto_veterinario_model.dart';

/// Contactos de veterinarias compartidos entre los administradores.
class VeterinariaController {
  VeterinariaController({FirebaseFirestore? firestore}) {
    _firestore = firestore;
  }

  late final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db {
    final db = _firestore;
    if (db == null) throw StateError('VeterinariaController sin Firestore');
    return db;
  }

  CollectionReference<Map<String, dynamic>> get _ref => _db.collection('veterinarias');

  static const int maxNombre = 80;
  static const int maxUbicacion = 160;
  static const int maxTelefono = 40;
  static const int maxNotas = 400;

  /// Deja dígitos y, si estaba al principio, el `+`. Null si no alcanza para marcar.
  static String? uriTelefono(String telefono) {
    final buffer = StringBuffer();
    for (final caracter in telefono.trim().split('')) {
      final esMas = caracter == '+' && buffer.isEmpty;
      final codigo = caracter.codeUnitAt(0);
      final esDigito = codigo >= 48 && codigo <= 57;
      if (esMas || esDigito) buffer.write(caracter);
    }
    final limpio = buffer.toString();
    final digitos = limpio.startsWith('+') ? limpio.substring(1) : limpio;
    if (digitos.length < 6) return null;
    return 'tel:$limpio';
  }

  /// Texto para la hoja de compartir. Omite las notas cuando están vacías.
  static String textoCompartir(ContactoVeterinarioModel contacto) {
    final lineas = <String>[
      contacto.nombre.trim(),
      contacto.ubicacion.trim(),
      'Teléfono: ${contacto.telefono.trim()}',
    ];
    final notas = contacto.notas.trim();
    if (notas.isNotEmpty) lineas.add('Notas: $notas');
    return lineas.join('\n');
  }

  /// Null si los datos se pueden guardar.
  static String? validar({
    required String nombre,
    required String ubicacion,
    required String telefono,
    required String notas,
  }) {
    final nombreLimpio = nombre.trim();
    final ubicacionLimpia = ubicacion.trim();
    final telefonoLimpio = telefono.trim();
    final notasLimpias = notas.trim();
    if (nombreLimpio.isEmpty) {
      return 'Ingresá el nombre del veterinario.';
    }
    if (nombreLimpio.length > maxNombre) {
      return 'El nombre es demasiado largo.';
    }
    if (ubicacionLimpia.isEmpty) {
      return 'Ingresá la ubicación de la veterinaria.';
    }
    if (ubicacionLimpia.length > maxUbicacion) {
      return 'La ubicación es demasiado larga.';
    }
    if (telefonoLimpio.isEmpty) {
      return 'Ingresá el teléfono.';
    }
    if (telefonoLimpio.length > maxTelefono) {
      return 'El teléfono es demasiado largo.';
    }
    if (!_telefonoPermitido.hasMatch(telefonoLimpio) || uriTelefono(telefonoLimpio) == null) {
      return 'El teléfono no se puede marcar.';
    }
    if (notasLimpias.length > maxNotas) {
      return 'Las notas son demasiado largas.';
    }
    return null;
  }

  static final RegExp _telefonoPermitido = RegExp(r'^[0-9+()\s\-]+$');

  Stream<List<ContactoVeterinarioModel>> observar() {
    return _ref.snapshots().map((snapshot) {
      final lista = <ContactoVeterinarioModel>[];
      for (final doc in snapshot.docs) {
        try {
          lista.add(ContactoVeterinarioModel.fromMap(doc.data(), doc.id));
        } catch (_) {}
      }
      lista.sort((a, b) {
        final porNombre = a.nombre.toLowerCase().compareTo(
          b.nombre.toLowerCase(),
        );
        if (porNombre != 0) return porNombre;
        return a.id.compareTo(b.id);
      });
      return lista;
    });
  }

  Future<void> guardar(ContactoVeterinarioModel contacto) async {
    final error = validar(
      nombre: contacto.nombre,
      ubicacion: contacto.ubicacion,
      telefono: contacto.telefono,
      notas: contacto.notas,
    );
    if (error != null) throw ArgumentError(error);
    final id = contacto.id.isEmpty ? _ref.doc().id : contacto.id;
    final limpio = contacto.copyWith(
      id: id,
      nombre: contacto.nombre.trim(),
      ubicacion: contacto.ubicacion.trim(),
      telefono: contacto.telefono.trim(),
      notas: contacto.notas.trim(),
    );
    await _ref.doc(id).set(limpio.toMap());
  }

  Future<void> eliminar(String id) async {
    await _ref.doc(id).delete();
  }
}
