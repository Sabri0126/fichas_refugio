import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/notificacion_registro_model.dart';
import 'auth_providers.dart';
import 'firestore_providers.dart';

/// Visitante: lista vacía y sin consulta. Staff: la única suscripción del historial,
/// así marcar leídas y borrar siguen reenganchando el mismo stream.
final notificacionesProvider = StreamProvider.autoDispose<List<NotificacionRegistroModel>>((ref) {
  final historial = ref.watch(historialNotificacionesControllerProvider);
  final esInvitado = ref.watch(sessionProvider.select((sesion) => sesion.esInvitado));
  if (esInvitado) return Stream.value(const <NotificacionRegistroModel>[]);
  return historial.observarHistorial(esInvitado: false);
}, retry: (_, _) => null);

/// En carga o sin dato queda en 0, como el badge antes de la primera emisión.
final notificacionesNoLeidasProvider = Provider.autoDispose<int>((ref) {
  final lista = ref.watch(notificacionesProvider).asData?.value;
  if (lista == null) return 0;
  return lista.where((entrada) => !entrada.leida).length;
});
