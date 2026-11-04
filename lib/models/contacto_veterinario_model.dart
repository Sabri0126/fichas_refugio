/// Contacto de una veterinaria, guardado en la colección `veterinarias`.
class ContactoVeterinarioModel {
  final String id;
  final String nombre;
  final String ubicacion;
  final String telefono;
  final String email;
  final String notas;

  const ContactoVeterinarioModel({
    required this.id,
    required this.nombre,
    required this.ubicacion,
    required this.telefono,
    this.email = '',
    required this.notas,
  });

  factory ContactoVeterinarioModel.fromMap(
    Map<String, dynamic> data,
    String id,
  ) {
    final nombre = data['nombre']?.toString().trim() ?? '';
    final ubicacion = data['ubicacion']?.toString().trim() ?? '';
    final telefono = data['telefono']?.toString().trim() ?? '';
    if (id.isEmpty || nombre.isEmpty || ubicacion.isEmpty || telefono.isEmpty) {
      throw const FormatException('Contacto de veterinaria inválido');
    }
    return ContactoVeterinarioModel(
      id: id,
      nombre: nombre,
      ubicacion: ubicacion,
      telefono: telefono,
      email: data['email']?.toString().trim() ?? '',
      notas: data['notas']?.toString().trim() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    final mapa = <String, dynamic>{
      'nombre': nombre,
      'ubicacion': ubicacion,
      'telefono': telefono,
      'notas': notas,
    };
    final correo = email.trim();
    if (correo.isNotEmpty) mapa['email'] = correo;
    return mapa;
  }

  ContactoVeterinarioModel copyWith({
    String? id,
    String? nombre,
    String? ubicacion,
    String? telefono,
    String? email,
    String? notas,
  }) {
    return ContactoVeterinarioModel(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      ubicacion: ubicacion ?? this.ubicacion,
      telefono: telefono ?? this.telefono,
      email: email ?? this.email,
      notas: notas ?? this.notas,
    );
  }
}
