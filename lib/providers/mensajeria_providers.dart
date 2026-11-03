import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/mensajeria_service.dart';
import '../services/notificaciones_service.dart';
import 'auth_providers.dart';
import 'firestore_providers.dart';

/// El mismo singleton que main usa antes del ProviderScope.
/// No es autoDispose: el registro del dispositivo vive mientras la app está abierta.
final mensajeriaServiceProvider = Provider<MensajeriaService>((ref) {
  final servicio = MensajeriaService.instance;
  servicio.conectar(
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
  return servicio;
});

/// Alarmas locales. No es autoDispose: main lo inicializa antes del ProviderScope.
final notificacionesServiceProvider = Provider<NotificacionesService>((ref) {
  return NotificacionesService.instance;
});
