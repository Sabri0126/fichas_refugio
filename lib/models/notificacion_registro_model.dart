/// Una entrada del historial local de notificaciones de este teléfono.
class NotificacionRegistroModel {
  final String id;
  final String titulo;
  final String cuerpo;
  final String? idPerro;
  final String categoria;
  final DateTime fecha;
  final bool leida;

  const NotificacionRegistroModel({
    required this.id,
    required this.titulo,
    required this.cuerpo,
    this.idPerro,
    required this.categoria,
    required this.fecha,
    required this.leida,
  });

  factory NotificacionRegistroModel.fromMap(Map<String, dynamic> data) {
    final idPerro = data['idPerro']?.toString();
    return NotificacionRegistroModel(
      id: data['id']?.toString() ?? '',
      titulo: data['titulo']?.toString() ?? '',
      cuerpo: data['cuerpo']?.toString() ?? '',
      idPerro: idPerro == null || idPerro.isEmpty ? null : idPerro,
      categoria: data['categoria']?.toString() ?? 'diario',
      fecha: DateTime.tryParse(data['fecha']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      leida: data['leida'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'titulo': titulo,
      'cuerpo': cuerpo,
      'idPerro': idPerro,
      'categoria': categoria,
      'fecha': fecha.toIso8601String(),
      'leida': leida,
    };
  }
}
