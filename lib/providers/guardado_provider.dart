import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cómo terminó un intento de guardado.
enum ResultadoGuardado { listo, ocupado, error }

const claveGuardadoFormulario = 'formulario';
const claveGuardadoPeso = 'ficha-peso';
const claveGuardadoSeguimiento = 'ficha-seguimiento';
const claveGuardadoSuspender = 'ficha-suspender';
const claveGuardadoDosis = 'ficha-dosis';
const claveGuardadoReanudar = 'ficha-reanudar';
const claveGuardadoEstudio = 'ficha-estudio';

const clavesGuardadoFicha = <String>[
  claveGuardadoPeso,
  claveGuardadoSeguimiento,
  claveGuardadoSuspender,
  claveGuardadoDosis,
  claveGuardadoReanudar,
  claveGuardadoEstudio,
];

/// Un guardado a la vez, con tope de espera.
///
/// Cada clave tiene su propio spinner: la ficha y el formulario no se pisan,
/// y dentro de la ficha un peso no bloquea un seguimiento.
class GuardadoNotifier extends AsyncNotifier<void> {
  GuardadoNotifier(this.clave);

  final String clave;

  @override
  FutureOr<void> build() {}

  /// `ocupado` si ya hay un guardado en curso. `error` si [accion] falla o vence.
  ///
  /// El tiempo vencido no deshace la escritura: [accion] sigue su curso.
  /// Si la pantalla se cerró, no se vuelve a asignar el estado.
  Future<ResultadoGuardado> ejecutar(
    Future<void> Function() accion, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    if (!reservar()) return ResultadoGuardado.ocupado;
    final resultado = await AsyncValue.guard(() => accion().timeout(timeout));
    if (!ref.mounted) {
      return resultado.hasError ? ResultadoGuardado.error : ResultadoGuardado.listo;
    }
    state = resultado;
    return resultado.hasError ? ResultadoGuardado.error : ResultadoGuardado.listo;
  }

  /// Deja el guardado en curso antes de una espera que no debe contar en el tope.
  bool reservar() {
    if (!ref.mounted || state.isLoading) return false;
    state = const AsyncLoading();
    return true;
  }

  /// Suelta la reserva. No hace nada si la pantalla ya se cerró.
  void soltar() {
    if (!ref.mounted) return;
    state = const AsyncData(null);
  }
}

final guardadoProvider = AsyncNotifierProvider.autoDispose
    .family<GuardadoNotifier, void, String>(GuardadoNotifier.new);
