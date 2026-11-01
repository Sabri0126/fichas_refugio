/// El cartel puede abrirse. Una copia de caché sin el día se deja pasar:
/// el servidor puede estar por escribir la marca automática.
bool listoParaAvisoDosis({required bool desdeCache, required bool marcada}) {
  if (!desdeCache) return true;
  return marcada;
}

/// El día del aviso ya está en el registro de dosis.
bool dosisAvisadaMarcada(Iterable<String> registroDosis, String dia) => registroDosis.contains(dia);

/// Dosis diaria que la notificación acaba de marcar, para confirmarla en la ficha.
class DosisAvisada {
  final String idTratamiento;
  final String dia;

  const DosisAvisada({required this.idTratamiento, required this.dia});
}

/// Aviso que abre una ficha. El payload es `id_perro` o `id_perro|id_tratamiento|dia`.
class AvisoFicha {
  final String idPerro;
  final DosisAvisada? dosis;

  const AvisoFicha({required this.idPerro, this.dosis});

  String get payload {
    final dosis = this.dosis;
    if (dosis == null) return idPerro;
    return '$idPerro|${dosis.idTratamiento}|${dosis.dia}';
  }

  static AvisoFicha? desdePayload(String? payload) {
    if (payload == null) return null;
    final partes = payload.split('|');
    final id = partes.first.trim();
    if (id.isEmpty) return null;
    if (partes.length >= 3) {
      final tratamiento = partes[1].trim();
      final dia = partes[2].trim();
      if (tratamiento.isNotEmpty && dia.isNotEmpty) {
        return AvisoFicha(
          idPerro: id,
          dosis: DosisAvisada(idTratamiento: tratamiento, dia: dia),
        );
      }
    }
    return AvisoFicha(idPerro: id);
  }

  static AvisoFicha? desdeDatos(Map<String, dynamic> data) {
    final id = data['id_perro']?.toString().trim() ?? '';
    if (id.isEmpty) return null;
    final tratamiento = data['id_tratamiento']?.toString().trim() ?? '';
    final dia = data['dia']?.toString().trim() ?? '';
    if (tratamiento.isEmpty || dia.isEmpty) return AvisoFicha(idPerro: id);
    return AvisoFicha(
      idPerro: id,
      dosis: DosisAvisada(idTratamiento: tratamiento, dia: dia),
    );
  }
}
