import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/historial_notificaciones_controller.dart';
import '../controllers/perro_controller.dart';
import '../controllers/peso_controller.dart';
import '../controllers/recordatorio_controller.dart';
import '../controllers/seguimiento_controller.dart';
import '../controllers/tratamiento_controller.dart';
import '../controllers/veterinaria_controller.dart';

/// Firestore de la app. Los tests lo reemplazan por [FakeFirebaseFirestore].
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final storageProvider = Provider<FirebaseStorage>((ref) {
  return FirebaseStorage.instance;
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

final tratamientoControllerProvider = Provider<TratamientoController>((ref) {
  return TratamientoController(firestore: ref.watch(firestoreProvider));
});

final pesoControllerProvider = Provider<PesoController>((ref) {
  return PesoController(firestore: ref.watch(firestoreProvider));
});

final seguimientoControllerProvider = Provider<SeguimientoController>((ref) {
  return SeguimientoController(firestore: ref.watch(firestoreProvider));
});

final recordatorioControllerProvider = Provider<RecordatorioController>((ref) {
  return RecordatorioController(firestore: ref.watch(firestoreProvider));
});
