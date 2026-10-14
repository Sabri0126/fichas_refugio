import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferencia de tema claro u oscuro. Claro es el valor por defecto.
abstract final class TemaApp {
  static final ValueNotifier<ThemeMode> modo = ValueNotifier(ThemeMode.light);
  static const _clave = 'tema_modo';

  static Future<void> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    modo.value = _desdeTexto(prefs.getString(_clave));
  }

  static Future<void> fijar(ThemeMode nuevo) async {
    modo.value = nuevo == ThemeMode.dark ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_clave, modo.value == ThemeMode.dark ? 'dark' : 'light');
  }

  /// Un valor guardado como "system" se lee como Claro.
  static ThemeMode _desdeTexto(String? valor) {
    return valor == 'dark' ? ThemeMode.dark : ThemeMode.light;
  }
}
