import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/estudio_controller.dart';
import '../models/estudio_model.dart';
import 'auth_providers.dart';
import 'firestore_providers.dart';

final estudioControllerProvider = Provider<EstudioController>((ref) {
  return EstudioController(
    firestore: ref.watch(firestoreProvider),
    leerStorage: () => ref.read(storageProvider),
  );
});

/// Visitante: lista vacía y sin consulta. El personal ve la subcolección.
final estudiosProvider = StreamProvider.autoDispose.family<List<EstudioModel>, String>((ref, perroId) {
  final controller = ref.watch(estudioControllerProvider);
  final esInvitado = ref.watch(sessionProvider.select((sesion) => sesion.esInvitado));
  if (esInvitado) return Stream.value(const <EstudioModel>[]);
  return controller.observar(perroId);
}, retry: (_, _) => null);

/// Bytes de una ruta de Storage. La miniatura y el visor lo miran juntos.
final estudioBytesProvider = FutureProvider.autoDispose.family<Uint8List?, String>((ref, ruta) {
  return ref.watch(estudioControllerProvider).descargar(ruta);
});

/// El visitante no ve la sección. El personal la ve cuando hay fotos.
bool seccionEstudiosVisible({required bool esInvitado, required int cantidad}) {
  return !esInvitado && cantidad > 0;
}
