import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:fichas_refugio/controllers/perro_controller.dart';
import 'package:fichas_refugio/controllers/tratamiento_controller.dart';
import 'package:fichas_refugio/models/perro_model.dart';
import 'package:fichas_refugio/providers/firestore_providers.dart';
import 'package:fichas_refugio/services/fotos_service.dart';
import 'package:fichas_refugio/theme/app_theme.dart';
import 'package:fichas_refugio/views/alta_calendario.dart';
import 'package:fichas_refugio/views/formulario_perro.dart';
import 'package:fichas_refugio/widgets/indice_secciones.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('IndiceSecciones muestra solo las secciones pasadas y hace ensureVisible', (
    tester,
  ) async {
    final claveA = GlobalKey();
    final claveB = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                IndiceSecciones(
                  secciones: [
                    SeccionIndice(etiqueta: 'Salud', clave: claveA),
                    SeccionIndice(etiqueta: 'Historia', clave: claveB),
                  ],
                ),
                const SizedBox(height: 800),
                Container(key: claveA, height: 40, color: Colors.red, child: const Text('destino-a')),
                const SizedBox(height: 800),
                Container(key: claveB, height: 40, color: Colors.blue, child: const Text('destino-b')),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Salud'), findsOneWidget);
    expect(find.text('Historia'), findsOneWidget);
    expect(find.text('Galería'), findsNothing);

    final antes = tester.getRect(find.text('destino-b')).top;
    await tester.tap(find.text('Historia'));
    await tester.pumpAndSettle();
    final despues = tester.getRect(find.text('destino-b')).top;
    expect(despues, lessThan(antes));
    expect(despues, lessThan(600));
  });

  testWidgets('abrirAltaRegistroParaPerro agrega el tratamiento a FichaTest', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('perros').doc('FichaTest').set({
      'nombre': 'FichaTest',
      'estado': 'activo',
      'tratamientos': <Map<String, dynamic>>[],
    });
    final tratamientos = TratamientoController(firestore: firestore);
    final perros = PerroController(firestore: firestore);
    final perro = PerroModel(id: 'FichaTest', nombre: 'FichaTest', estado: 'activo');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [firestoreProvider.overrideWithValue(firestore)],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () {
                  abrirAltaRegistroParaPerro(
                    context,
                    perro: perro,
                    fecha: DateTime(2026, 3, 1),
                    tratamientos: tratamientos,
                    perros: perros,
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
    await tester.pumpAndSettle();
    await tester.tap(find.text('Evento Médico'));
    await tester.pumpAndSettle();

    final campoNombre = find.byType(TextField).first;
    await tester.enterText(campoNombre, 'Control de prueba');
    await tester.pump();
    await tester.tap(find.text('Agregar evento'));
    await tester.pumpAndSettle();

    final data = (await firestore.collection('perros').doc('FichaTest').get()).data()!;
    final lista = data['tratamientos'] as List;
    expect(lista, hasLength(1));
    expect(lista.single['medicacion'], 'Control de prueba');
    expect(lista.single['categoria'], 'evento');
  });

  testWidgets('guardar el formulario sin nombre deja el foco en el nombre', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final firestore = FakeFirebaseFirestore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firestoreProvider.overrideWithValue(firestore),
          fotosServiceProvider.overrideWithValue(FotosService(almacen: AlmacenFotosMemoria())),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const FormularioPerro(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Datos básicos'), findsWidgets);
    expect(find.text('Ubicación'), findsOneWidget);

    await tester.tap(find.text('Crear Ficha'));
    await tester.pumpAndSettle();

    expect(find.text('Ingresá un nombre'), findsOneWidget);
    final editable = tester.widgetList<EditableText>(find.byType(EditableText)).first;
    expect(editable.focusNode.hasFocus, isTrue);
    expect(editable.controller.text, isEmpty);
  });
}
