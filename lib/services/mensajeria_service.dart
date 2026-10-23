import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notificaciones_service.dart';
import '../models/dosis_avisada.dart';

/// Registra el celular para recibir push y reutiliza el toque de las alarmas locales.
class MensajeriaService {
  MensajeriaService._();
  static final MensajeriaService instance = MensajeriaService._();

  /// Ids de diarios que este celular no quiere recibir. La misma lista va en
  /// `dispositivos/{token}.silenciados`.
  static const claveSilenciados = 'tratamientos_silenciados';

  final FirebaseMessaging _mensajeria = FirebaseMessaging.instance;
  StreamSubscription<String>? _alRenovarToken;
  StreamSubscription<RemoteMessage>? _enPrimerPlano;
  bool _toquesListos = false;

  /// Android, iOS, macOS y web. En Windows y Linux el plugin no tiene canal.
  bool get _pushSoportado {
    if (kIsWeb) return true;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS || TargetPlatform.macOS => true,
      _ => false,
    };
  }

  /// Lee el push que abrió la app cerrada y engancha el toque con la app en segundo plano.
  /// Devuelve el payload para dejarlo pendiente hasta después del desbloqueo.
  Future<String?> prepararToques() async {
    if (!_pushSoportado || _toquesListos) return null;
    _toquesListos = true;
    FirebaseMessaging.onMessageOpenedApp.listen((mensaje) {
      final aviso = AvisoFicha.desdeDatos(mensaje.data);
      if (aviso == null) return;
      NotificacionesService.instance.abrirDesdePayload(aviso.payload);
    });
    final inicial = await _mensajeria.getInitialMessage();
    if (inicial == null) return null;
    return AvisoFicha.desdeDatos(inicial.data)?.payload;
  }

  Future<void> registrarDispositivo() async {
    if (!_pushSoportado) return;
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) return;

    await _mensajeria.requestPermission();
    final token = await _mensajeria.getToken();
    if (token != null && token.isNotEmpty) {
      await _guardarToken(token, usuario.uid);
    }

    await _alRenovarToken?.cancel();
    _alRenovarToken = _mensajeria.onTokenRefresh.listen((nuevo) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || nuevo.isEmpty) return;
      _guardarToken(nuevo, uid);
    });

    await _enPrimerPlano?.cancel();
    _enPrimerPlano = FirebaseMessaging.onMessage.listen((mensaje) {
      final notificacion = mensaje.notification;
      final titulo = notificacion?.title ?? '';
      final cuerpo = notificacion?.body ?? '';
      if (titulo.isEmpty && cuerpo.isEmpty) return;
      final aviso = AvisoFicha.desdeDatos(mensaje.data);
      NotificacionesService.instance.mostrarAhora(
        titulo: titulo,
        cuerpo: cuerpo,
        payload: aviso?.payload,
      );
    });
  }

  Future<void> desregistrarDispositivo() async {
    if (!_pushSoportado) return;
    try {
      await _borrarToken().timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  Future<void> _borrarToken() async {
    await _alRenovarToken?.cancel();
    _alRenovarToken = null;
    await _enPrimerPlano?.cancel();
    _enPrimerPlano = null;
    final token = await _mensajeria.getToken();
    if (token != null && token.isNotEmpty) {
      await FirebaseFirestore.instance.collection('dispositivos').doc(token).delete();
    }
    await _mensajeria.deleteToken();
  }

  /// Ids de diarios callados solo en este celular.
  static Future<Set<String>> leerSilenciados() async {
    final prefs = await SharedPreferences.getInstance();
    return _conjuntoSilenciados(prefs.getString(claveSilenciados));
  }

  /// Suma o saca un diario de la lista local y, si hay token, del documento del celular.
  Future<void> definirSilencio(String idTratamiento, {required bool silenciar}) async {
    final id = idTratamiento.trim();
    if (id.isEmpty) return;
    final ids = await leerSilenciados();
    if (silenciar) {
      ids.add(id);
    } else {
      ids.remove(id);
    }
    await _guardarSilenciadosLocales(ids);
    await _escribirSilencioRemoto(ids);
  }

  Future<void> _guardarToken(String token, String uid) async {
    final ref = FirebaseFirestore.instance.collection('dispositivos').doc(token);
    final locales = await leerSilenciados();
    var remotos = <String>{};
    try {
      final snap = await ref.get();
      remotos = _conjuntoSilenciados(snap.data()?['silenciados']);
    } catch (_) {}
    final unidos = {...locales, ...remotos};
    await _guardarSilenciadosLocales(unidos);
    await ref.set({
      'uid': uid,
      'plataforma': defaultTargetPlatform.name,
      'actualizado': FieldValue.serverTimestamp(),
      'silenciados': _listaOrdenada(unidos),
    }, SetOptions(merge: true));
  }

  Future<void> _escribirSilencioRemoto(Set<String> ids) async {
    if (!_pushSoportado) return;
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) return;
    final token = await _mensajeria.getToken();
    if (token == null || token.isEmpty) return;
    await FirebaseFirestore.instance.collection('dispositivos').doc(token).set({
      'uid': usuario.uid,
      'silenciados': _listaOrdenada(ids),
      'actualizado': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> _guardarSilenciadosLocales(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(claveSilenciados, jsonEncode(_listaOrdenada(ids)));
  }

  static List<String> _listaOrdenada(Set<String> ids) {
    final lista = ids.toList()..sort();
    return lista;
  }

  static Set<String> _conjuntoSilenciados(Object? crudo) {
    if (crudo is String) {
      try {
        return _conjuntoSilenciados(jsonDecode(crudo));
      } catch (_) {
        return {};
      }
    }
    if (crudo is! List) return {};
    return crudo.map((item) => item.toString().trim()).where((id) => id.isNotEmpty).toSet();
  }
}
