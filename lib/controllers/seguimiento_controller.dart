import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/seguimiento_model.dart';

/// Lógica de seguimientos. No escribe en Firebase.
class SeguimientoController {
  /// Id de documento de Firestore, sin persistir nada.
  String generarId() => FirebaseFirestore.instance.collection('perros').doc().id;

  SeguimientoModel crear({
    required String motivo,
    required String detalle,
    required String hora,
    required DateTime fechaInicio,
    required int diasDuracion,
  }) {
    final hoy = DateTime(fechaInicio.year, fechaInicio.month, fechaInicio.day);
    return SeguimientoModel(
      id: generarId(),
      motivo: motivo,
      detalle: detalle.trim(),
      hora: hora,
      fechaInicio: hoy,
      diasDuracion: diasDuracion < 0 ? 0 : diasDuracion,
      activo: true,
    );
  }

  SeguimientoModel editar(
    SeguimientoModel actual, {
    String? motivo,
    String? detalle,
    String? hora,
    int? diasDuracion,
  }) {
    return actual.copyWith(
      motivo: motivo,
      detalle: detalle?.trim(),
      hora: hora,
      diasDuracion: diasDuracion,
    );
  }

  SeguimientoModel cerrar(SeguimientoModel actual) => actual.copyWith(activo: false);

  List<SeguimientoModel> vigentes(List<SeguimientoModel> lista, {DateTime? ahora}) {
    final momento = ahora ?? DateTime.now();
    return [
      for (final seguimiento in lista)
        if (seguimiento.vigente(momento)) seguimiento,
    ];
  }

  List<SeguimientoModel> cerrados(List<SeguimientoModel> lista, {DateTime? ahora}) {
    final momento = ahora ?? DateTime.now();
    return [
      for (final seguimiento in lista)
        if (!seguimiento.vigente(momento)) seguimiento,
    ];
  }

  /// "Día 2 de 5", "Día 2" si no tiene fin, o "Empieza el dd/mm" si todavía no arrancó.
  String describirPlazo(SeguimientoModel seguimiento, {DateTime? ahora}) {
    final momento = ahora ?? DateTime.now();
    if (!seguimiento.activo) return 'Cerrado';
    final hoy = DateTime(momento.year, momento.month, momento.day);
    final inicio = DateTime(
      seguimiento.fechaInicio.year,
      seguimiento.fechaInicio.month,
      seguimiento.fechaInicio.day,
    );
    if (hoy.isBefore(inicio)) {
      final dd = inicio.day.toString().padLeft(2, '0');
      final mm = inicio.month.toString().padLeft(2, '0');
      return 'Empieza el $dd/$mm';
    }
    final fin = seguimiento.ultimoDia;
    if (fin != null && hoy.isAfter(fin)) return 'Finalizado';
    final dia = hoy.difference(inicio).inDays + 1;
    if (seguimiento.diasDuracion <= 0) return 'Día $dia';
    return 'Día $dia de ${seguimiento.diasDuracion}';
  }

  /// Al pasar a inactivo, los seguimientos dejan de avisar.
  static List<SeguimientoModel> cerrarActivos(List<SeguimientoModel> lista) {
    return [
      for (final seguimiento in lista)
        if (seguimiento.activo) seguimiento.copyWith(activo: false) else seguimiento,
    ];
  }

  /// Agrega al final las altas remotas que no estaban al abrir el formulario.
  static List<SeguimientoModel> fusionarAltasRemotas({
    required List<SeguimientoModel> local,
    required List<SeguimientoModel> remoto,
    required Set<String> idsIniciales,
  }) {
    final presentes = <String>{
      for (final item in local)
        if (item.id.isNotEmpty) item.id,
    };
    final altas = <SeguimientoModel>[];
    for (final item in remoto) {
      if (item.id.isEmpty || idsIniciales.contains(item.id) || presentes.contains(item.id)) {
        continue;
      }
      altas.add(item);
      presentes.add(item.id);
    }
    return [...local, ...altas];
  }
}
