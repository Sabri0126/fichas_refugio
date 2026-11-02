import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/historial_notificaciones_controller.dart';
import '../controllers/perro_controller.dart';
import '../controllers/veterinaria_controller.dart';

/// Firestore de la app. Los tests lo reemplazan por [FakeFirebaseFirestore].
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final perroControllerProvider = Provider<PerroController>((ref) {
  return PerroController(firestore: ref.watch(firestoreProvider));
});

final veterinariaControllerProvider = Provider<VeterinariaController>((ref) {
  return VeterinariaController(firestore: ref.watch(firestoreProvider));
});

final historialNotificacionesControllerProvider = Provider<HistorialNotificacionesController>((ref) {
  return HistorialNotificacionesController(firestore: ref.watch(firestoreProvider));
});
