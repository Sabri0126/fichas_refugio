import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:fichas_refugio/providers/auth_providers.dart';
import 'package:fichas_refugio/providers/firestore_providers.dart';
import 'package:fichas_refugio/providers/notificaciones_providers.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('el visitante recibe una lista vacía y no ve documentos nuevos', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('notificaciones').doc('n1').set(_aviso('Aviso'));
    final container = _contenedor(firestore, MockFirebaseAuth(signedIn: false));
    container.listen(notificacionesProvider, (_, _) {});
    await _emitio(container);

    expect(container.read(notificacionesProvider).value, isEmpty);
    expect(container.read(notificacionesNoLeidasProvider), 0);

    await firestore.collection('notificaciones').doc('n2').set(_aviso('Otra'));
    await pumpEventQueue();
    await pumpEventQueue();

    expect(container.read(notificacionesProvider).value, isEmpty);
    expect(container.read(notificacionesNoLeidasProvider), 0);
  });

  test('el staff recibe las notificaciones y el conteo de no leídas', () async {
    SharedPreferences.setMockInitialValues({
      'notif_leidas_hasta': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
    });
    final firestore = FakeFirebaseFirestore();
    final leida = DateTime.now().subtract(const Duration(days: 2));
    final nueva = DateTime.now();
    await firestore.collection('notificaciones').doc('vieja').set(_aviso('Vieja', creada: leida));
    await firestore.collection('notificaciones').doc('nueva').set(_aviso('Nueva', creada: nueva));

    final auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'staff', email: 'staff@refugio.test'),
    );
    final container = _contenedor(firestore, auth);
    container.listen(notificacionesProvider, (_, _) {});
    await _emitio(container, minimo: 1);

    final titulos = container.read(notificacionesProvider).value!.map((entrada) => entrada.titulo).toSet();
    expect(titulos, containsAll(['Vieja', 'Nueva']));
    expect(container.read(notificacionesNoLeidasProvider), 1);
  });

  test('al pasar a visitante la lista se vacía', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('notificaciones').doc('n1').set(_aviso('Aviso'));
    final auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'staff', email: 'staff@refugio.test'),
    );
    final container = _contenedor(firestore, auth);
    container.listen(sessionProvider, (_, _) {});
    container.listen(notificacionesProvider, (_, _) {});

    await auth.signInWithEmailAndPassword(email: 'staff@refugio.test', password: 'clave');
    await _emitio(container, minimo: 1);
    expect(container.read(notificacionesProvider).value, isNotEmpty);

    await auth.signOut();
    await pumpEventQueue();

    expect(container.read(sessionProvider).esInvitado, isTrue);
    expect(container.read(notificacionesProvider).value, isEmpty);
    expect(container.read(notificacionesNoLeidasProvider), 0);
  });
}

Map<String, Object?> _aviso(String titulo, {DateTime? creada}) {
  final momento = creada ?? DateTime.now();
  return {
    'titulo': titulo,
    'cuerpo': 'cuerpo',
    'creada': Timestamp.fromDate(momento),
    'fecha': Timestamp.fromDate(momento),
    'categoria': 'diario',
    'tipo': 'dosis',
  };
}

ProviderContainer _contenedor(FakeFirebaseFirestore firestore, MockFirebaseAuth auth) {
  final container = ProviderContainer(
    overrides: [
      firestoreProvider.overrideWithValue(firestore),
      firebaseAuthProvider.overrideWithValue(auth),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _emitio(ProviderContainer container, {int minimo = 0}) async {
  for (var i = 0; i < 30; i++) {
    final lista = container.read(notificacionesProvider).asData?.value;
    if (lista != null && lista.length >= minimo) return;
    await pumpEventQueue();
  }
  fail('Las notificaciones no emitieron');
}
