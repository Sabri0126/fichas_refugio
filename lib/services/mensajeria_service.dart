import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notificaciones_service.dart';
import '../models/dosis_avisada.dart';

/// Aviso push ya separado del plugin, para poder probarlo sin Firebase Messaging.
class MensajePush {
  final Map<String, dynamic> data;
  final String titulo;
  final String cuerpo;

  const MensajePush({required this.data, this.titulo = '', this.cuerpo = ''});
}

/// Token y eventos de push. La app usa [FuentePushFirebase].
abstract class FuentePush {
  bool get soportado;
  Future<void> pedirPermiso();
  Future<String?> token();
  Future<void> borrarToken();
  Future<MensajePush?> mensajeInicial();
  Stream<String> get alRenovarToken;
  Stream<MensajePush> get enPrimerPlano;
  Stream<MensajePush> get alAbrir;
}

class FuentePushFirebase implements FuentePush {
  FuentePushFirebase(this._mensajeria);

  final FirebaseMessaging _mensajeria;

  @override
  bool get soportado {
    if (kIsWeb) return true;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS || TargetPlatform.macOS => true,
      _ => false,
    };
  }

  @override
  Future<void> pedirPermiso() async {
    await _mensajeria.requestPermission();
  }

  @override
  Future<String?> token() => _mensajeria.getToken();

  @override
  Future<void> borrarToken() => _mensajeria.deleteToken();

  @override
  Future<MensajePush?> mensajeInicial() async {
    final inicial = await _mensajeria.getInitialMessage();
    if (inicial == null) return null;
    return _desde(inicial);
  }

  @override
  Stream<String> get alRenovarToken => _mensajeria.onTokenRefresh;

  @override
  Stream<MensajePush> get enPrimerPlano => FirebaseMessaging.onMessage.map(_desde);

  @override
  Stream<MensajePush> get alAbrir => FirebaseMessaging.onMessageOpenedApp.map(_desde);

  static MensajePush _desde(RemoteMessage mensaje) {
    return MensajePush(
      data: mensaje.data,
      titulo: mensaje.notification?.title ?? '',
      cuerpo: mensaje.notification?.body ?? '',
    );
  }
}

/// Token fijo para tests. [soportado] queda en true aunque la prueba corra en Windows.
class FuentePushFija implements FuentePush {
  FuentePushFija(this.tokenActual);

  String? tokenActual;

  @override
  bool get soportado => true;

  @override
  Future<void> pedirPermiso() async {}

  @override
  Future<String?> token() async => tokenActual;

  @override
  Future<void> borrarToken() async {
    tokenActual = null;
  }

  @override
  Future<MensajePush?> mensajeInicial() async => null;

  @override
  Stream<String> get alRenovarToken => const Stream.empty();

  @override
  Stream<MensajePush> get enPrimerPlano => const Stream.empty();

  @override
  Stream<MensajePush> get alAbrir => const Stream.empty();
}

/// Registra el celular para recibir push y reutiliza el toque de las alarmas locales.
///
/// [instance] existe antes del ProviderScope: main engancha el toque en frío.
/// El provider le pasa Firestore y Auth. No es autoDispose.
class MensajeriaService {
  MensajeriaService({FirebaseFirestore? firestore, FirebaseAuth? auth, FuentePush? push}) {
    _firestore = firestore;
    _auth = auth;
    _push = push;
  }

  static final MensajeriaService instance = MensajeriaService();

  /// Ids de diarios que este celular no quiere recibir. La misma lista va en
  /// `dispositivos/{token}.silenciados`.
  static const claveSilenciados = 'tratamientos_silenciados';

  FirebaseFirestore? _firestore;
  FirebaseAuth? _auth;
  FuentePush? _push;
  StreamSubscription<String>? _alRenovarToken;
  StreamSubscription<MensajePush>? _enPrimerPlano;
  bool _toquesListos = false;

  /// Lo llama el provider cuando ya hay Firestore y Auth. El push puede llegar antes, desde main.
  void conectar({FirebaseFirestore? firestore, FirebaseAuth? auth, FuentePush? push}) {
    if (firestore != null) _firestore = firestore;
    if (auth != null) _auth = auth;
    if (push != null) _push = push;
  }

  /// Lee el push que abrió la app cerrada y engancha el toque con la app en segundo plano.
  /// Devuelve el payload para dejarlo pendiente hasta después del desbloqueo.
  Future<String?> prepararToques() async {
    final push = _push;
    if (push == null || !push.soportado || _toquesListos) return null;
    _toquesListos = true;
    push.alAbrir.listen((mensaje) {
      final aviso = AvisoFicha.desdeDatos(mensaje.data);
      if (aviso == null) return;
      NotificacionesService.instance.abrirDesdePayload(aviso.payload);
    });
    final inicial = await push.mensajeInicial();
    if (inicial == null) return null;
    return AvisoFicha.desdeDatos(inicial.data)?.payload;
  }

  Future<void> registrarDispositivo() async {
    final push = _push;
    final auth = _auth;
    final db = _firestore;
    if (push == null || !push.soportado || auth == null || db == null) return;
    final usuario = auth.currentUser;
    if (usuario == null) return;

    await push.pedirPermiso();
    final token = await push.token();
    if (token != null && token.isNotEmpty) {
      await _guardarToken(db, token, usuario.uid);
    }

    await _alRenovarToken?.cancel();
    _alRenovarToken = push.alRenovarToken.listen((nuevo) {
      final uid = _auth?.currentUser?.uid;
      final base = _firestore;
      if (uid == null || base == null || nuevo.isEmpty) return;
      _guardarToken(base, nuevo, uid);
    });

    await _enPrimerPlano?.cancel();
    _enPrimerPlano = push.enPrimerPlano.listen((mensaje) {
      if (mensaje.titulo.isEmpty && mensaje.cuerpo.isEmpty) return;
      final aviso = AvisoFicha.desdeDatos(mensaje.data);
      NotificacionesService.instance.mostrarAhora(
        titulo: mensaje.titulo,
        cuerpo: mensaje.cuerpo,
        payload: aviso?.payload,
      );
    });
  }

  Future<void> desregistrarDispositivo() async {
    final push = _push;
    if (push == null || !push.soportado) return;
    try {
      await _borrarToken().timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  Future<void> _borrarToken() async {
    final push = _push;
    final db = _firestore;
    if (push == null || db == null) return;
    await _alRenovarToken?.cancel();
    _alRenovarToken = null;
    await _enPrimerPlano?.cancel();
    _enPrimerPlano = null;
    final token = await push.token();
    if (token != null && token.isNotEmpty) {
      await db.collection('dispositivos').doc(token).delete();
    }
    await push.borrarToken();
  }

  /// Ids de diarios callados solo en este celular. Lee SharedPreferences, no Firestore.
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

  Future<void> _guardarToken(FirebaseFirestore db, String token, String uid) async {
    final locales = await leerSilenciados();
    await db.collection('dispositivos').doc(token).set({
      'uid': uid,
      'plataforma': defaultTargetPlatform.name,
      'actualizado': FieldValue.serverTimestamp(),
      'silenciados': _listaOrdenada(locales),
    }, SetOptions(merge: true));
  }

  Future<void> _escribirSilencioRemoto(Set<String> ids) async {
    final push = _push;
    final auth = _auth;
    final db = _firestore;
    if (push == null || !push.soportado || auth == null || db == null) return;
    final usuario = auth.currentUser;
    if (usuario == null) return;
    final token = await push.token();
    if (token == null || token.isEmpty) return;
    await db.collection('dispositivos').doc(token).set({
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
