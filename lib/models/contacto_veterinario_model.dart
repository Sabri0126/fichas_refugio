/// Contacto de una veterinaria, guardado en la colección `veterinarias`.
class ContactoVeterinarioModel {
  final String id;
  final String nombre;
  final String ubicacion;
  final String telefono;
  final String notas;

  const ContactoVeterinarioModel({
    required this.id,
    required this.nombre,
    required this.ubicacion,
    required this.telefono,
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
      notas: data['notas']?.toString().trim() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'ubicacion': ubicacion,
      'telefono': telefono,
      'notas': notas,
    };
  }

  ContactoVeterinarioModel copyWith({
    String? id,
    String? nombre,
    String? ubicacion,
    String? telefono,
    String? notas,
  }) {
    return ContactoVeterinarioModel(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      ubicacion: ubicacion ?? this.ubicacion,
      telefono: telefono ?? this.telefono,
      notas: notas ?? this.notas,
    );
  }
}
