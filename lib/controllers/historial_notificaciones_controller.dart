import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/notificacion_registro_model.dart';

/// Historial de avisos del servidor. Lo leído y lo borrado queda en este teléfono.
class HistorialNotificacionesController {
  static const _claveLeidas = 'notif_leidas_hasta';
  static const _claveBorrado = 'notif_borrado_hasta';
  static const _claveEliminadas = 'notif_eliminadas';

  static bool _migrado = false;

  final _aviso = StreamController<void>.broadcast();

  Stream<List<NotificacionRegistroModel>> observarHistorial() {
    if (FirebaseAuth.instance.currentUser == null) {
      return Stream.value(const []);
    }
    return _observar();
  }

  Stream<int> observarNoLeidas() {
    return observarHistorial().map((lista) => lista.where((entrada) => !entrada.leida).length);
  }

  Future<void> marcarTodasLeidas() async {
    final prefs = await SharedPreferences.getInstance();
    await _migrar(prefs);
    await prefs.setString(_claveLeidas, DateTime.now().toIso8601String());
    _avisar();
  }

  Future<void> eliminar(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await _migrar(prefs);
    final ids = _leerIds(prefs);
    if (!ids.contains(id)) ids.add(id);
    await prefs.setString(_claveEliminadas, jsonEncode(ids));
    _avisar();
  }

  Future<void> borrarTodo() async {
    final prefs = await SharedPreferences.getInstance();
    await _migrar(prefs);
    await prefs.setString(_claveBorrado, DateTime.now().toIso8601String());
    await prefs.setString(_claveEliminadas, '[]');
    _avisar();
  }

  Stream<List<NotificacionRegistroModel>> _observar() {
    return Stream.multi((controller) {
      StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? remota;
      var activo = true;
      var generacion = 0;

      Future<void> enganchar() async {
        final esta = ++generacion;
        await remota?.cancel();
        if (!activo || esta != generacion) return;
        final corte = await _corte();
        if (!activo || esta != generacion) return;
        remota = _consulta(corte).snapshots().listen(
          (snap) async {
            try {
              final lista = await _armar(snap);
              if (activo && esta == generacion && !controller.isClosed) controller.add(lista);
            } catch (error, traza) {
              if (activo && !controller.isClosed) controller.addError(error, traza);
            }
          },
          onError: (Object error, StackTrace traza) {
            if (activo && !controller.isClosed) controller.addError(error, traza);
          },
        );
      }

      enganchar();
      final local = _aviso.stream.listen((_) => enganchar());
      controller.onCancel = () {
        activo = false;
        remota?.cancel();
        local.cancel();
      };
    });
  }

  Query<Map<String, dynamic>> _consulta(DateTime corte) {
    return FirebaseFirestore.instance
        .collection('notificaciones')
        .where('creada', isGreaterThan: Timestamp.fromDate(corte))
        .orderBy('creada', descending: true)
        .limit(100);
  }

  Future<DateTime> _corte() async {
    final prefs = await SharedPreferences.getInstance();
    await _migrar(prefs);
    final hace30 = DateTime.now().subtract(const Duration(days: 30));
    final borrado = DateTime.tryParse(prefs.getString(_claveBorrado) ?? '');
    if (borrado != null && borrado.isAfter(hace30)) return borrado;
    return hace30;
  }

  Future<List<NotificacionRegistroModel>> _armar(QuerySnapshot<Map<String, dynamic>> snap) async {
    final prefs = await SharedPreferences.getInstance();
    await _migrar(prefs);
    final leidasHasta = DateTime.tryParse(prefs.getString(_claveLeidas) ?? '');
    final presentes = snap.docs.map((doc) => doc.id).toSet();
    final eliminadas = _leerIds(prefs);
    final podadas = eliminadas.where(presentes.contains).toList();
    if (podadas.length != eliminadas.length) {
      await prefs.setString(_claveEliminadas, jsonEncode(podadas));
    }
    final ocultas = podadas.toSet();
    final lista = <NotificacionRegistroModel>[];
    for (final doc in snap.docs) {
      if (ocultas.contains(doc.id)) continue;
      final modelo = NotificacionRegistroModel.desdeDocumento(
        doc.id,
        doc.data(),
        leidasHasta: leidasHasta,
      );
      if (modelo != null) lista.add(modelo);
    }
    return lista;
  }

  Future<void> _migrar(SharedPreferences prefs) async {
    if (_migrado) return;
    await prefs.remove('historial_notificaciones');
    await prefs.remove('alarmas_programadas');
    await prefs.remove('ultima_reconciliacion');
    _migrado = true;
  }

  List<String> _leerIds(SharedPreferences prefs) {
    final raw = prefs.getString(_claveEliminadas);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded.map((item) => item.toString()).where((id) => id.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  void _avisar() {
    if (!_aviso.isClosed) _aviso.add(null);
  }
}
