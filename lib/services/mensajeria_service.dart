import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'notificaciones_service.dart';
import '../models/dosis_avisada.dart';

/// Registra el celular para recibir push y reutiliza el toque de las alarmas locales.
class MensajeriaService {
  MensajeriaService._();
  static final MensajeriaService instance = MensajeriaService._();

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

  Future<void> _guardarToken(String token, String uid) {
    return FirebaseFirestore.instance.collection('dispositivos').doc(token).set({
      'uid': uid,
      'plataforma': defaultTargetPlatform.name,
      'actualizado': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
