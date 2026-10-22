import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Nombre con el que la persona aparece en las fichas.
///
/// En Windows, `User.updateProfile` y `User.reload` cierran el proceso
/// (fallo nativo de firebase_auth) y el nombre no llega a persistir.
/// Por eso acá se guarda en el dispositivo y esas llamadas se omiten.
abstract final class NombreUsuario {
  static const _prefijo = 'nombre_visible_';
  static String? _memoria;

  static String _clave(String uid) => '$_prefijo$uid';

  static bool get _perfilNativoInestable =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  static Future<void> cargar(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final guardado = prefs.getString(_clave(uid))?.trim() ?? '';
    _memoria = guardado.isEmpty ? null : guardado;
  }

  static void olvidar() {
    _memoria = null;
  }

  static String visible(User? usuario) {
    final local = _memoria?.trim() ?? '';
    if (local.isNotEmpty) return local;
    return usuario?.displayName?.trim() ?? '';
  }

  static bool falta(User? usuario) => visible(usuario).isEmpty;

  static Future<void> guardar(User usuario, String nombre) async {
    final limpio = nombre.trim();
    if (limpio.isEmpty) return;
    _memoria = limpio;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_clave(usuario.uid), limpio);
    if (_perfilNativoInestable) return;
    try {
      await usuario.updateProfile(displayName: limpio);
      await usuario.reload();
    } catch (_) {}
  }
}
