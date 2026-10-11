import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/recordatorio_model.dart';

const _dias = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];

/// Lógica de recordatorios agendados. No escribe en Firebase.
class RecordatorioController {
  /// Id de documento de Firestore, sin persistir nada.
  String generarId() => FirebaseFirestore.instance.collection('perros').doc().id;

  RecordatorioModel crear({
    required String tipo,
    required String titulo,
    required String nota,
    required DateTime fechaHora,
  }) {
    return RecordatorioModel(
      id: generarId(),
      tipo: tipo,
      titulo: titulo.trim(),
      nota: nota.trim(),
      fechaHora: fechaHora,
    );
  }

  RecordatorioModel editar(
    RecordatorioModel actual, {
    String? tipo,
    String? titulo,
    String? nota,
    DateTime? fechaHora,
  }) {
    return actual.copyWith(
      tipo: tipo,
      titulo: titulo?.trim(),
      nota: nota?.trim(),
      fechaHora: fechaHora,
    );
  }

  bool esVencido(RecordatorioModel recordatorio, {DateTime? ahora}) {
    final momento = ahora ?? DateTime.now();
    return !recordatorio.fechaHora.isAfter(momento);
  }

  List<RecordatorioModel> proximos(List<RecordatorioModel> lista, {DateTime? ahora}) {
    final momento = ahora ?? DateTime.now();
    final resultado = lista.where((r) => !esVencido(r, ahora: momento)).toList();
    resultado.sort((a, b) => a.fechaHora.compareTo(b.fechaHora));
    return resultado;
  }

  List<RecordatorioModel> vencidos(List<RecordatorioModel> lista, {DateTime? ahora}) {
    final momento = ahora ?? DateTime.now();
    final resultado = lista.where((r) => esVencido(r, ahora: momento)).toList();
    resultado.sort((a, b) => b.fechaHora.compareTo(a.fechaHora));
    return resultado;
  }

  String formatearCuando(DateTime fecha, {DateTime? ahora}) {
    final momento = ahora ?? DateTime.now();
    final hora =
        '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
    final dia = DateTime(fecha.year, fecha.month, fecha.day);
    final hoy = DateTime(momento.year, momento.month, momento.day);
    if (dia == hoy) return 'Hoy $hora';
    if (dia == hoy.add(const Duration(days: 1))) return 'Mañana $hora';
    final nombre = _dias[fecha.weekday - 1];
    final numero = '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}';
    return '$nombre $numero $hora';
  }
}
