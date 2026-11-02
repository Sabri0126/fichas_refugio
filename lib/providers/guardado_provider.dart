import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Un guardado a la vez, con tope de espera.
///
/// La ficha y el formulario usan claves distintas para que el spinner
/// de uno no prenda el del otro.
class GuardadoNotifier extends AsyncNotifier<void> {
  GuardadoNotifier(this.clave);

  final String clave;

  @override
  FutureOr<void> build() {}

  /// `false` si ya hay un guardado en curso, o si [accion] falla o vence.
  ///
  /// El tiempo vencido no deshace la escritura: [accion] sigue su curso.
  Future<bool> ejecutar(
    Future<void> Function() accion, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();
    final resultado = await AsyncValue.guard(() => accion().timeout(timeout));
    state = resultado;
    return !resultado.hasError;
  }
}

final guardadoProvider = AsyncNotifierProvider.autoDispose
    .family<GuardadoNotifier, void, String>(GuardadoNotifier.new);
