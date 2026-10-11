import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/notificacion_registro_model.dart';

/// Historial local de alarmas que ya debían sonar en este teléfono.
class HistorialNotificacionesController {
  static const _claveHistorial = 'historial_notificaciones';
  static const _claveAlarmas = 'alarmas_programadas';
  static const _claveUltima = 'ultima_reconciliacion';

  Future<void> guardarSnapshot(List<Map<String, dynamic>> alarmas) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_claveAlarmas, jsonEncode(alarmas));
  }

  Future<void> reconciliar({DateTime? ahora}) async {
    final momento = ahora ?? DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final ultimaRaw = prefs.getString(_claveUltima);
    if (ultimaRaw == null) {
      await prefs.setString(_claveUltima, momento.toIso8601String());
      return;
    }

    final ultima = DateTime.tryParse(ultimaRaw) ?? momento;
    final historial = _leerHistorial(prefs);
    final ids = historial.map((entrada) => entrada.id).toSet();
    final limiteAtras = momento.subtract(const Duration(days: 14));

    for (final alarma in _leerSnapshot(prefs)) {
      if (alarma['repite'] == true) {
        _agregarRepeticiones(
          alarma: alarma,
          ultima: ultima,
          momento: momento,
          limiteAtras: limiteAtras,
          historial: historial,
          ids: ids,
        );
      } else {
        final fecha = DateTime.tryParse(alarma['fecha']?.toString() ?? '');
        if (fecha == null) continue;
        if (fecha.isAfter(ultima) && !fecha.isAfter(momento)) {
          _agregar(alarma, fecha, historial, ids);
        }
      }
    }

    final corte = momento.subtract(const Duration(days: 30));
    final podado = historial.where((entrada) => !entrada.fecha.isBefore(corte)).toList()
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
    final resultado = podado.length > 100 ? podado.sublist(0, 100) : podado;

    await prefs.setString(_claveHistorial, jsonEncode(resultado.map((entrada) => entrada.toMap()).toList()));
    await prefs.setString(_claveUltima, momento.toIso8601String());
  }

  Future<List<NotificacionRegistroModel>> obtenerHistorial() async {
    final prefs = await SharedPreferences.getInstance();
    final historial = _leerHistorial(prefs);
    historial.sort((a, b) => b.fecha.compareTo(a.fecha));
    return historial;
  }

  Future<int> contarNoLeidas() async {
    final historial = await obtenerHistorial();
    return historial.where((entrada) => !entrada.leida).length;
  }

  Future<void> marcarTodasLeidas() async {
    final prefs = await SharedPreferences.getInstance();
    final historial = _leerHistorial(prefs);
    final leidas = historial
        .map(
          (entrada) => NotificacionRegistroModel(
            id: entrada.id,
            titulo: entrada.titulo,
            cuerpo: entrada.cuerpo,
            idPerro: entrada.idPerro,
            categoria: entrada.categoria,
            fecha: entrada.fecha,
            leida: true,
          ),
        )
        .toList();
    await prefs.setString(_claveHistorial, jsonEncode(leidas.map((entrada) => entrada.toMap()).toList()));
  }

  Future<void> eliminar(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final historial = _leerHistorial(prefs)..removeWhere((entrada) => entrada.id == id);
    await prefs.setString(_claveHistorial, jsonEncode(historial.map((entrada) => entrada.toMap()).toList()));
  }

  Future<void> borrarTodo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_claveHistorial, '[]');
  }

  void _agregarRepeticiones({
    required Map<String, dynamic> alarma,
    required DateTime ultima,
    required DateTime momento,
    required DateTime limiteAtras,
    required List<NotificacionRegistroModel> historial,
    required Set<String> ids,
  }) {
    final desde = DateTime.tryParse(alarma['desde']?.toString() ?? '') ?? ultima;
    final partes = (alarma['hora']?.toString() ?? '09:00').split(':');
    final hora = int.tryParse(partes.isNotEmpty ? partes[0] : '') ?? 9;
    final minuto = partes.length > 1 ? int.tryParse(partes[1]) ?? 0 : 0;

    var inicio = desde.isAfter(ultima) ? desde : ultima;
    if (limiteAtras.isAfter(inicio)) inicio = limiteAtras;

    var dia = DateTime(inicio.year, inicio.month, inicio.day);
    final ultimoDia = DateTime(momento.year, momento.month, momento.day);

    while (!dia.isAfter(ultimoDia)) {
      final ocurrencia = DateTime(dia.year, dia.month, dia.day, hora, minuto);
      final dentroDeVentana = ocurrencia.isAfter(ultima) && !ocurrencia.isAfter(momento);
      final noAnteriorAlInicio = !ocurrencia.isBefore(desde);
      final dentroDeCatorceDias = !ocurrencia.isBefore(limiteAtras);
      if (dentroDeVentana && noAnteriorAlInicio && dentroDeCatorceDias) {
        _agregar(alarma, ocurrencia, historial, ids);
      }
      dia = dia.add(const Duration(days: 1));
    }
  }

  void _agregar(
    Map<String, dynamic> alarma,
    DateTime fecha,
    List<NotificacionRegistroModel> historial,
    Set<String> ids,
  ) {
    final id = '${alarma['id']}_${fecha.millisecondsSinceEpoch}';
    if (id == '_' || ids.contains(id)) return;
    ids.add(id);
    final idPerro = alarma['idPerro']?.toString();
    historial.add(
      NotificacionRegistroModel(
        id: id,
        titulo: alarma['titulo']?.toString() ?? '',
        cuerpo: alarma['cuerpo']?.toString() ?? '',
        idPerro: idPerro == null || idPerro.isEmpty ? null : idPerro,
        categoria: alarma['categoria']?.toString() ?? 'diario',
        fecha: fecha,
        leida: false,
      ),
    );
  }

  List<NotificacionRegistroModel> _leerHistorial(SharedPreferences prefs) {
    final raw = prefs.getString(_claveHistorial);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((item) => NotificacionRegistroModel.fromMap(Map<String, dynamic>.from(item)))
          .where((entrada) => entrada.id.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  List<Map<String, dynamic>> _leerSnapshot(SharedPreferences prefs) {
    final raw = prefs.getString(_claveAlarmas);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
    } catch (_) {
      return [];
    }
  }
}
