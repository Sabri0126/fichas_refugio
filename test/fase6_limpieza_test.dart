import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:fichas_refugio/controllers/estudio_controller.dart';
import 'package:fichas_refugio/controllers/perro_controller.dart';
import 'package:fichas_refugio/models/perro_model.dart';
import 'package:fichas_refugio/models/tratamiento_model.dart';
import 'package:fichas_refugio/providers/auth_providers.dart';
import 'package:fichas_refugio/providers/calendario_providers.dart';
import 'package:fichas_refugio/providers/firestore_providers.dart';
import 'package:fichas_refugio/providers/perros_providers.dart';
import 'package:fichas_refugio/providers/theme_mode_provider.dart';
import 'package:fichas_refugio/services/fotos_service.dart';
import 'package:fichas_refugio/services/mensajeria_service.dart';
import 'package:fichas_refugio/theme/app_theme.dart';
import 'package:fichas_refugio/views/ficha_detalle_perro.dart';
import 'package:fichas_refugio/views/formulario_perro.dart';
import 'package:fichas_refugio/views/pantalla_calendario_general.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('las fotos públicas usan la ruta de hoy y putFile no manda contentType', () async {
    final memoria = AlmacenFotosMemoria();
    final instante = DateTime.utc(2026, 6, 15, 12);
    final fotos = FotosService(almacen: memoria, reloj: () => instante);
    final archivo = File('x.jpg');
    final ms = instante.millisecondsSinceEpoch;

    expect(
      await fotos.subirGaleria(archivo),
      'https://memoria.local/galeria_perros/galeria_$ms.jpg',
    );
    expect(
      await fotos.subirRecorte(archivo),
      'https://memoria.local/galeria_perros/recorte_$ms.jpg',
    );
    expect(
      await fotos.subirPerfil(archivo),
      'https://memoria.local/fotos_perfil/$ms.jpg',
    );
    expect(memoria.subidas.map((subida) => subida.ruta), [
      'galeria_perros/galeria_$ms.jpg',
      'galeria_perros/recorte_$ms.jpg',
      'fotos_perfil/$ms.jpg',
    ]);
    expect(memoria.subidas.map((subida) => subida.contentType), [null, null, null]);

    await fotos.borrarPorUrl('https://memoria.local/fotos_perfil/$ms.jpg');
    expect(memoria.borradas, ['https://memoria.local/fotos_perfil/$ms.jpg']);

    memoria.errorSubida = StateError('fallo');
    expect(fotos.subirGaleria(archivo), throwsA(isA<StateError>()));
  });

  test('un estudio se sube como image/jpeg', () {
    expect(AlmacenFirebase.contentTypeJpeg, 'image/jpeg');
  });

  testWidgets('el contador de pendientes cambia al cruzar la medianoche', (tester) async {
    final base = DateTime(2026, 6, 15, 23, 59, 59);
    final arranque = tester.binding.clock.now();
    final perro = PerroModel(
      id: 'p1',
      nombre: 'Luna',
      estado: 'activo',
      tratamientos: [
        TratamientoModel(
          id: 'diario',
          categoria: 'diario',
          medicacion: 'Pastilla',
          indicaciones: '1',
          fechaInicio: DateTime(2026, 6, 15),
          diasDuracion: 1,
          activo: true,
        ),
      ],
    );
    final contenedor = ProviderContainer(
      overrides: [
        relojProvider.overrideWithValue(
          () => base.add(tester.binding.clock.now().difference(arranque)),
        ),
        perrosProvider.overrideWithValue(AsyncData([perro])),
      ],
    );
    try {
      expect(contenedor.read(hoyProvider), DateTime(2026, 6, 15));
      expect(contenedor.read(pendientesHoyProvider), 1);

      await tester.pump(const Duration(seconds: 2));

      expect(contenedor.read(hoyProvider), DateTime(2026, 6, 16));
      expect(contenedor.read(pendientesHoyProvider), 0);
    } finally {
      contenedor.dispose();
    }
  });

  testWidgets('el visitante no marca la dosis y el personal sí', (tester) async {
    final perro = PerroModel(
      id: 'p1',
      nombre: 'Luna',
      estado: 'activo',
      fechaIngreso: DateTime(2020, 4, 29),
      tratamientos: [
        TratamientoModel(
          id: 'diario',
          categoria: 'diario',
          medicacion: 'Pastilla',
          indicaciones: '1 comprimido',
          fechaInicio: DateTime(2026, 6, 10),
          diasDuracion: 10,
          activo: true,
        ),
      ],
    );

    await _montarCalendario(tester, perro, invitado: true);
    expect(find.text('Pendientes de hoy'), findsOneWidget);
    expect(find.byTooltip('Marcar como dada'), findsNothing);

    await _montarCalendario(tester, perro, invitado: false);
    expect(find.text('Pendientes de hoy'), findsOneWidget);
    expect(find.byTooltip('Marcar como dada'), findsOneWidget);
  });

  test('registrar y desregistrar escriben el documento del dispositivo', () async {
    SharedPreferences.setMockInitialValues({});
    final firestore = FakeFirebaseFirestore();
    final auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'u1', email: 'staff@refugio.test'),
    );
    final servicio = MensajeriaService(
      firestore: firestore,
      auth: auth,
      push: FuentePushFija('token-1'),
    );

    await servicio.registrarDispositivo();
    final doc = await firestore.collection('dispositivos').doc('token-1').get();
    expect(doc.exists, isTrue);
    expect(doc.data()?['uid'], 'u1');
    expect(doc.data()?['plataforma'], isNotEmpty);
    expect(doc.data()?.containsKey('actualizado'), isTrue);
    expect(doc.data()?['silenciados'], isEmpty);

    await servicio.desregistrarDispositivo();
    final despues = await firestore.collection('dispositivos').doc('token-1').get();
    expect(despues.exists, isFalse);
  });

  test('registrar el dispositivo no lee el documento remoto', () async {
    SharedPreferences.setMockInitialValues({
      MensajeriaService.claveSilenciados: '["local-1"]',
    });
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('dispositivos').doc('token-1').set({
      'uid': 'otro',
      'silenciados': ['remoto-1'],
    });
    final auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'u1', email: 'staff@refugio.test'),
    );
    final servicio = MensajeriaService(
      firestore: firestore,
      auth: auth,
      push: FuentePushFija('token-1'),
    );

    await servicio.registrarDispositivo();
    final doc = await firestore.collection('dispositivos').doc('token-1').get();
    expect(doc.data()?['uid'], 'u1');
    expect(doc.data()?['silenciados'], ['local-1']);
  });

  testWidgets('el formulario guarda con los controladores del provider', (tester) async {
    final firestore = FakeFirebaseFirestore();
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firestoreProvider.overrideWithValue(firestore),
          fotosServiceProvider.overrideWithValue(
            FotosService(almacen: AlmacenFotosMemoria()),
          ),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FormularioPerro(
                        idDocumento: 'p1',
                        perroActual: PerroModel(
                          id: 'p1',
                          nombre: 'Luna',
                          estado: 'activo',
                          edad: 2,
                          fechaIngreso: DateTime(2020, 4, 29),
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.enterText(find.byType(TextFormField).first, 'Luna Editada');
    await tester.tap(find.text('Guardar Cambios'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final doc = await firestore.collection('perros').doc('p1').get();
    expect(doc.exists, isTrue);
    expect(doc.data()?['nombre'], 'Luna Editada');
  });

  testWidgets('la ficha partida muestra las mismas secciones', (tester) async {
    final perro = PerroModel(
      id: 'p1',
      nombre: 'Luna',
      estado: 'activo',
      sexo: 'hembra',
      fechaIngreso: DateTime(2020, 4, 29),
      historia: 'Llegó de cachorra.',
    );

    await _montarFicha(tester, perro, invitado: false);
    expect(find.text('Ficha de Luna'), findsOneWidget);
    expect(find.text('Perfil general'), findsOneWidget);
    expect(find.text('Fecha de ingreso'), findsOneWidget);
    expect(find.text('Historia y observaciones'), findsOneWidget);
    expect(find.text('Editar ficha'), findsOneWidget);
    expect(find.text('Registrar en el calendario'), findsOneWidget);
    expect(find.text('Subir foto de estudio'), findsOneWidget);
    expect(find.text('Fotos de estudios'), findsNothing);
    expect(find.text('Agregar un estudio'), findsNothing);

    await _montarFicha(tester, perro, invitado: true);
    expect(find.text('Ficha de Luna'), findsOneWidget);
    expect(find.text('Perfil general'), findsOneWidget);
    expect(find.text('Fecha de ingreso'), findsOneWidget);
    expect(find.text('Historia y observaciones'), findsOneWidget);
    expect(find.text('Editar ficha'), findsNothing);
    expect(find.text('Registrar en el calendario'), findsNothing);
    expect(find.text('Subir foto de estudio'), findsNothing);
    expect(find.text('Fotos de estudios'), findsNothing);
  });

  testWidgets('Registrar en el calendario abre tratamiento, seguimiento o recordatorio', (tester) async {
    final perro = PerroModel(
      id: 'p1',
      nombre: 'Luna',
      estado: 'activo',
      sexo: 'hembra',
      fechaIngreso: DateTime(2020, 4, 29),
    );

    Future<void> abrirOpcion(String etiqueta, String tituloFormulario) async {
      await _montarFicha(tester, perro, invitado: false);
      await tester.tap(find.text('Registrar en el calendario'));
      await tester.pumpAndSettle();
      expect(find.text('¿Qué querés registrar?'), findsOneWidget);
      await tester.tap(find.text(etiqueta));
      await tester.pumpAndSettle();
      expect(find.text(tituloFormulario), findsOneWidget);
      await tester.tap(find.text('Cancelar').last);
      await tester.pumpAndSettle();
    }

    await abrirOpcion('Tratamiento', 'Agregar registro médico');
    await abrirOpcion('Seguimiento', 'Agregar seguimiento');
    await abrirOpcion('Recordatorio', 'Agendar recordatorio');
  });

  testWidgets('la ficha muestra solo el acceso Salud y sin el texto viejo de la galería', (tester) async {
    final perro = PerroModel(
      id: 'p1',
      nombre: 'Luna',
      estado: 'activo',
      sexo: 'hembra',
      fechaIngreso: DateTime(2020, 4, 29),
      historia: 'Llegó de cachorra.',
      tratamientos: [
        TratamientoModel(
          id: 'diario',
          categoria: 'diario',
          medicacion: 'Pastilla',
          indicaciones: '1',
          fechaInicio: DateTime(2026, 6, 10),
          diasDuracion: 10,
          activo: true,
        ),
      ],
    );

    await _montarFicha(tester, perro, invitado: false);
    expect(find.text('Salud'), findsOneWidget);
    expect(find.text('Historia'), findsNothing);
    expect(find.text('Estudios'), findsNothing);
    expect(find.text('Galería'), findsNothing);
    expect(find.text('Agregar la primera foto'), findsOneWidget);
    expect(
      find.text('Fotos del perro. Los estudios médicos van en Estudios y registros.'),
      findsNothing,
    );
  });

  testWidgets('personal con perro activo ve Salud aunque no haya tratamientos', (tester) async {
    final perro = PerroModel(
      id: 'p1',
      nombre: 'Luna',
      estado: 'activo',
      sexo: 'hembra',
      fechaIngreso: DateTime(2020, 4, 29),
      parientes: [
        {'nombre': 'Canelo', 'relacion': 'hermano', 'id_documento': 'p2'},
      ],
    );

    await _montarFicha(tester, perro, invitado: false);
    expect(find.text('Salud'), findsOneWidget);
    expect(find.text('Historia'), findsNothing);
    expect(find.text('Familiares/Parientes'), findsOneWidget);
  });

  testWidgets('en celular angosto Suspender y Cambiar dosis se leen enteros', (tester) async {
    final perro = PerroModel(
      id: 'p1',
      nombre: 'Merlina',
      estado: 'activo',
      sexo: 'hembra',
      fechaIngreso: DateTime(2020, 4, 29),
      tratamientos: [
        TratamientoModel(
          id: 'vida',
          categoria: 'diario',
          medicacion: 'Fenobarbital P-100',
          indicaciones: '1/4 comp. c/ 24hs',
          fechaInicio: DateTime(2026, 9, 10),
          diasDuracion: 0,
          activo: true,
          tipoDuracion: TratamientoModel.tipoDePorVida,
        ),
      ],
    );

    final overflows = <String>[];
    final previo = FlutterError.onError;
    FlutterError.onError = (details) {
      final texto = details.toString();
      if (texto.contains('overflowed') || texto.contains('OVERFLOW')) {
        overflows.add(texto);
      }
      previo?.call(details);
    };
    addTearDown(() => FlutterError.onError = previo);

    await _montarFicha(tester, perro, invitado: false, tamano: const Size(360, 1400));
    await tester.scrollUntilVisible(find.text('Cambiar dosis'), 200);
    await tester.pumpAndSettle();

    expect(find.text('Suspender'), findsOneWidget);
    expect(find.text('Cambiar dosis'), findsOneWidget);
    expect(tester.getRect(find.text('Cambiar dosis')).right, lessThanOrEqualTo(360));
    expect(overflows, isEmpty);

    await tester.tap(find.text('Suspender'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Suspender Fenobarbital'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cambiar dosis'));
    await tester.pumpAndSettle();
    expect(find.text('Dosis nueva'), findsOneWidget);
    expect(find.text('Guardar cambio'), findsOneWidget);
    Navigator.of(tester.element(find.text('Dosis nueva'))).pop();
    await tester.pumpAndSettle();
  });
}

Future<void> _montarCalendario(WidgetTester tester, PerroModel perro, {required bool invitado}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        relojProvider.overrideWithValue(() => DateTime(2026, 6, 15)),
        perrosProvider.overrideWithValue(AsyncData([perro])),
        firebaseAuthProvider.overrideWithValue(
          invitado
              ? MockFirebaseAuth(signedIn: false)
              : MockFirebaseAuth(
                  signedIn: true,
                  mockUser: MockUser(uid: 'staff', email: 'staff@refugio.test'),
                ),
        ),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: const PantallaCalendarioGeneral(),
      ),
    ),
  );
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (find.text('Pendientes de hoy').evaluate().isNotEmpty) return;
  }
  fail('el calendario no mostró los pendientes');
}

Future<void> _montarFicha(
  WidgetTester tester,
  PerroModel perro, {
  required bool invitado,
  Size tamano = const Size(800, 1400),
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize = tamano;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
        fotosServiceProvider.overrideWithValue(FotosService(almacen: AlmacenFotosMemoria())),
        perroProvider.overrideWith((ref, id) {
          return Stream.value(LecturaPerro(perro: perro, desdeCache: false));
        }),
        firebaseAuthProvider.overrideWithValue(
          invitado
              ? MockFirebaseAuth(signedIn: false)
              : MockFirebaseAuth(
                  signedIn: true,
                  mockUser: MockUser(uid: 'staff', email: 'staff@refugio.test'),
                ),
        ),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: FichaDetallePerro(idDocumento: perro.id),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}
