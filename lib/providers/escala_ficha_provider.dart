import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme_mode_provider.dart';

const claveEscalaFicha = 'escala_texto_ficha';
const escalaFichaMin = 1.0;
const escalaFichaDefault = 1.3;
const escalaFichaMax = 1.9;
const escalaFichaPaso = 0.15;
const escalaFichaTopeEfectivo = 2.0;

/// Preferencia de tamaño de la ficha. Parte de [escalaFichaDefault] y se multiplica por el del sistema.
final escalaFichaProvider = NotifierProvider<EscalaFichaNotifier, double>(
  EscalaFichaNotifier.new,
);

class EscalaFichaNotifier extends Notifier<double> {
  @override
  double build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return _acotar(prefs.getDouble(claveEscalaFicha) ?? escalaFichaDefault);
  }

  Future<void> achicar() => fijar(state - escalaFichaPaso);

  Future<void> agrandar() => fijar(state + escalaFichaPaso);

  Future<void> normal() => fijar(escalaFichaDefault);

  Future<void> fijar(double valor) async {
    final acotado = _acotar(valor);
    state = acotado;
    await ref.read(sharedPreferencesProvider).setDouble(claveEscalaFicha, acotado);
  }

  static double _acotar(double valor) {
    if (valor < escalaFichaMin) return escalaFichaMin;
    if (valor > escalaFichaMax) return escalaFichaMax;
    return double.parse(valor.toStringAsFixed(2));
  }
}

/// Escala efectiva: preferencia × sistema, con tope [escalaFichaTopeEfectivo].
double escalaFichaEfectiva(double preferencia, double escalaSistema) {
  final producto = preferencia * escalaSistema;
  if (producto > escalaFichaTopeEfectivo) return escalaFichaTopeEfectivo;
  if (producto < 0.1) return 0.1;
  return producto;
}
