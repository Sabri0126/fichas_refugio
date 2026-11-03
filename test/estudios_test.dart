import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:fichas_refugio/controllers/estudio_controller.dart';
import 'package:fichas_refugio/controllers/perro_controller.dart';
import 'package:fichas_refugio/models/estudio_model.dart';
import 'package:fichas_refugio/models/perro_model.dart';
import 'package:fichas_refugio/providers/auth_providers.dart';
import 'package:fichas_refugio/providers/estudios_providers.dart';
import 'package:fichas_refugio/providers/firestore_providers.dart';
import 'package:fichas_refugio/services/exportar_ficha.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('agregar no pide URL, edita, borra y deshace el archivo si Firestore falla', () async {
    final firestore = FakeFirebaseFirestore();
    final memoria = AlmacenMemoria();
    final controller = EstudioController(firestore: firestore, almacen: memoria);
    final bytes = Uint8List.fromList([1, 2, 3]);

    final creado = await controller.agregar('luna', bytes, 'radio');
    expect(creado.ruta, 'estudios_medicos/luna/${creado.id}.jpg');
    expect(memoria.archivos[creado.ruta], bytes);
    expect(memoria.pidioUrlPublica, isFalse);

    await controller.editarTexto('luna', creado.id, 'nueva');
    final data = (await firestore.collection('perros').doc('luna').collection('estudios').doc(creado.id).get()).data()!;
    expect(data['texto'], 'nueva');
    expect(data.containsKey('url'), isFalse);

    await controller.eliminar('luna', creado);
    expect(memoria.archivos.containsKey(creado.ruta), isFalse);

    final falla = _ControllerQueFalla(firestore: firestore, almacen: memoria);
    expect(() => falla.agregar('luna', bytes, 'otra'), throwsStateError);
    await pumpEventQueue();
    expect(memoria.archivos.values, isEmpty);
  });

  test('eliminar un perro borra sus estudios y los archivos', () async {
    final firestore = FakeFirebaseFirestore();
    final memoria = AlmacenMemoria();
    final estudios = EstudioController(firestore: firestore, almacen: memoria);
    await firestore.collection('perros').doc('luna').set({'nombre': 'Luna'});
    final bytes = Uint8List.fromList([1, 2, 3]);
    final primero = await estudios.agregar('luna', bytes, 'radio');
    final segundo = await estudios.agregar('luna', bytes, 'análisis');

    await PerroController(firestore: firestore, estudios: estudios).eliminarPerro('luna');

    final restantes = await firestore.collection('perros').doc('luna').collection('estudios').get();
    expect(restantes.docs, isEmpty);
    expect(memoria.archivos.containsKey(primero.ruta), isFalse);
    expect(memoria.archivos.containsKey(segundo.ruta), isFalse);
    expect((await firestore.collection('perros').doc('luna').get()).exists, isFalse);
  });

  test('mover de galería a estudios y de vuelta', () async {
    final firestore = FakeFirebaseFirestore();
    final memoria = AlmacenMemoria();
    final controller = EstudioController(firestore: firestore, almacen: memoria);
    const url = 'https://memoria.local/galeria_perros/vieja.jpg';
    memoria.porUrl[url] = Uint8List.fromList([9, 9]);
    memoria.archivos['galeria_perros/vieja.jpg'] = Uint8List.fromList([9, 9]);
    await firestore.collection('perros').doc('luna').set({
      'nombre': 'Luna',
      'galeria': [
        {'url': url, 'texto': 'herida'},
      ],
    });

    await controller.moverDesdeGaleria(perroId: 'luna', indice: 0, fotoPerfil: null);
    final estudios = await firestore.collection('perros').doc('luna').collection('estudios').get();
    expect(estudios.docs, hasLength(1));
    expect(estudios.docs.single.data()['origenUrl'], url);
    final perro = (await firestore.collection('perros').doc('luna').get()).data()!;
    expect(perro['galeria'], isEmpty);
    expect(memoria.archivos.containsKey('galeria_perros/vieja.jpg'), isFalse);

    final entrada = EntradaEstudio.nueva(EstudioModel.fromMap(estudios.docs.single.data(), estudios.docs.single.id));
    await controller.moverHaciaGaleria(perroId: 'luna', entrada: entrada);
    final despues = (await firestore.collection('perros').doc('luna').get()).data()!;
    expect((despues['galeria'] as List), isNotEmpty);
    expect(memoria.pidioUrlPublica, isTrue);
    final quedan = await firestore.collection('perros').doc('luna').collection('estudios').get();
    expect(quedan.docs, isEmpty);
  });

  test('las fotos viejas ya migradas no se duplican', () {
    const url = 'https://example.invalid/c.jpg';
    final entradas = unirEstudios(
      [
        EstudioModel(
          id: 'e1',
          ruta: 'estudios_medicos/luna/e1.jpg',
          texto: 'radio',
          orden: 0,
          creado: DateTime(2026, 1, 1),
          origenUrl: url,
        ),
      ],
      [
        {'url': url, 'texto': 'radio'},
        {'url': 'https://example.invalid/nueva.jpg', 'texto': 'análisis'},
      ],
    );
    expect(entradas, hasLength(2));
    expect(entradas.where((entrada) => entrada.esLegacy), hasLength(1));
    expect(entradas.last.urlLegacy, 'https://example.invalid/nueva.jpg');
  });

  test('el visitante no consulta y el personal ve la lista ordenada', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('perros').doc('luna').collection('estudios').doc('b').set({
      'ruta': 'estudios_medicos/luna/b.jpg',
      'texto': 'b',
      'orden': 2,
      'creado': DateTime(2026, 1, 2),
    });
    await firestore.collection('perros').doc('luna').collection('estudios').doc('a').set({
      'ruta': 'estudios_medicos/luna/a.jpg',
      'texto': 'a',
      'orden': 0,
      'creado': DateTime(2026, 1, 1),
    });

    final visitante = _contenedor(firestore, MockFirebaseAuth(signedIn: false));
    visitante.listen(estudiosProvider('luna'), (_, _) {});
    await _emitio(visitante);
    expect(visitante.read(estudiosProvider('luna')).value, isEmpty);

    final auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'staff', email: 'staff@refugio.test'),
    );
    final personal = _contenedor(firestore, auth);
    personal.listen(estudiosProvider('luna'), (_, _) {});
    await _emitio(personal, minimo: 2);
    expect(personal.read(estudiosProvider('luna')).value!.map((e) => e.texto), ['a', 'b']);

    await auth.signOut();
    await pumpEventQueue();
    expect(personal.read(estudiosProvider('luna')).value, isEmpty);
  });

  test('el visitante exporta sin el estudio', () async {
    final perro = PerroModel(
      id: 'luna',
      nombre: 'Luna',
      galeriaEstudios: [
        {'url': 'https://example.invalid/c.jpg', 'texto': 'Radiografía secreta'},
      ],
    );
    final pedidas = <String>[];
    await ExportarFicha.generar(
      perro: perro,
      edad: '1 año',
      incluirEstudios: false,
      descargar: (url) async {
        pedidas.add(url);
        return null;
      },
    );
    expect(pedidas, isEmpty);
  });

  testWidgets('el visitante no ve la sección y el personal sí', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('perros').doc('luna').collection('estudios').doc('a').set({
      'ruta': 'estudios_medicos/luna/a.jpg',
      'texto': 'radio',
      'orden': 0,
      'creado': DateTime(2026, 1, 1),
    });
    final auth = MockFirebaseAuth(signedIn: false);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firestoreProvider.overrideWithValue(firestore),
          firebaseAuthProvider.overrideWithValue(auth),
        ],
        child: const MaterialApp(home: _VistaEstudios()),
      ),
    );
    await tester.pump();
    expect(find.text('Estudios y registros'), findsNothing);

    await auth.signInWithEmailAndPassword(email: 'staff@refugio.test', password: 'clave');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Estudios y registros'), findsOneWidget);
  });
}

class _ControllerQueFalla extends EstudioController {
  _ControllerQueFalla({required super.firestore, required super.almacen});

  @override
  Future<void> crearDocumento(String perroId, EstudioModel estudio) async {
    throw StateError('firestore');
  }
}

class _VistaEstudios extends ConsumerWidget {
  const _VistaEstudios();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final esInvitado = ref.watch(sessionProvider).esInvitado;
    final estudios = ref.watch(estudiosProvider('luna'));
    final cantidad = estudios.asData?.value.length ?? 0;
    if (!seccionEstudiosVisible(esInvitado: esInvitado, cantidad: cantidad)) {
      return const SizedBox.shrink();
    }
    return const Text('Estudios y registros');
  }
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
    final lista = container.read(estudiosProvider('luna')).asData?.value;
    if (lista != null && lista.length >= minimo) return;
    await pumpEventQueue();
  }
  fail('Los estudios no emitieron');
}
