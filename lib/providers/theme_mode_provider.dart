import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferencias ya leídas en `main`, antes del primer frame.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences debe inyectarse en main');
});

/// Claro u oscuro. La clave `tema_modo` es la misma de antes: solo `dark`
/// se lee como oscuro; cualquier otro valor, incluido `system`, queda claro.
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _clave = 'tema_modo';

  @override
  ThemeMode build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return _desdeTexto(prefs.getString(_clave));
  }

  Future<void> fijar(ThemeMode nuevo) async {
    final modo = nuevo == ThemeMode.dark ? ThemeMode.dark : ThemeMode.light;
    state = modo;
    await ref
        .read(sharedPreferencesProvider)
        .setString(_clave, modo == ThemeMode.dark ? 'dark' : 'light');
  }

  static ThemeMode _desdeTexto(String? valor) {
    return valor == 'dark' ? ThemeMode.dark : ThemeMode.light;
  }
}
