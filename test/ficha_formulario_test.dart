import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:fichas_refugio/controllers/perro_controller.dart';
import 'package:fichas_refugio/controllers/tratamiento_controller.dart';
import 'package:fichas_refugio/models/perro_model.dart';
import 'package:fichas_refugio/providers/firestore_providers.dart';
import 'package:fichas_refugio/services/fotos_service.dart';
import 'package:fichas_refugio/theme/app_theme.dart';
import 'package:fichas_refugio/views/alta_calendario.dart';
import 'package:fichas_refugio/views/dialogo_tratamiento.dart';
import 'package:fichas_refugio/views/formulario_perro.dart';
import 'package:fichas_refugio/widgets/indice_secciones.dart';
import 'package:flutter/foundation.dart';
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

  testWidgets('la ventana flotante muestra las categorías en lista sin cortes', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (ctx) => Dialog(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: GrillaRegistrosMedicos(
                          alElegir: (_) => Navigator.pop(ctx),
                          diseno: DisenoRegistros.lista,
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
    await tester.pumpAndSettle();

    final etiquetas = [
      'Tratamiento Diario',
      'Dosis Única',
      'Higiene',
      'Evento Médico',
      'Veterinaria',
      'Vacuna',
    ];
    for (final etiqueta in etiquetas) {
      expect(find.text(etiqueta), findsOneWidget);
    }
    final ys = [for (final e in etiquetas) tester.getTopLeft(find.text(e)).dy];
    for (var i = 1; i < ys.length; i++) {
      expect(ys[i], greaterThan(ys[i - 1]));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('la grilla por defecto sigue en dos columnas en Android', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(
            body: SizedBox(
              width: 400,
              child: GrillaRegistrosMedicos(alElegir: _noopCategoria),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final diario = tester.getTopLeft(find.text('Tratamiento Diario'));
      final unica = tester.getTopLeft(find.text('Dosis Única'));
      expect(unica.dx, greaterThan(diario.dx));
      expect((unica.dy - diario.dy).abs(), lessThan(16));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('en veterinaria el motivo crece y el veterinario queda de una línea', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () {
                  mostrarDialogoTratamiento(
                    context,
                    controller: TratamientoController(),
                    categoria: 'veterinaria',
                    fechaInicial: DateTime(2026, 3, 1),
                  );
                },
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      final campos = tester.widgetList<TextField>(find.byType(TextField)).toList();
      final vet = campos.firstWhere(
        (campo) => campo.decoration?.labelText == 'Nombre del veterinario o la veterinaria',
      );
      final motivo = campos.firstWhere(
        (campo) => campo.decoration?.labelText == 'Motivo de visita (obligatorio)',
      );
      expect(motivo.maxLines, isNull);
      expect(motivo.minLines, 2);
      expect(motivo.keyboardType, TextInputType.multiline);
      expect(vet.maxLines, 1);

      final motivoFinder = find.byWidgetPredicate(
        (widget) => widget is TextField && widget.decoration?.labelText == 'Motivo de visita (obligatorio)',
      );
      final altoAntes = tester.getSize(motivoFinder).height;
      await tester.enterText(motivoFinder, 'Línea 1\nLínea 2\nLínea 3\nLínea 4\nLínea 5\nLínea 6');
      await tester.pumpAndSettle();
      final altoDespues = tester.getSize(motivoFinder).height;
      expect(altoDespues, greaterThan(altoAntes));

      await tester.enterText(motivoFinder, '');
      await tester.tap(find.text('Agregar visita'));
      await tester.pumpAndSettle();
      expect(find.text('Escribí el nombre para poder guardar'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('en vacuna el nombre y la dosis quedan de una línea', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () {
                  mostrarDialogoTratamiento(
                    context,
                    controller: TratamientoController(),
                    categoria: 'vacuna',
                    fechaInicial: DateTime(2026, 3, 1),
                  );
                },
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      final nombre = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Nombre de la vacuna (obligatorio)'),
      );
      final dosis = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Dosis administrada'),
      );
      expect(nombre.maxLines, 1);
      expect(dosis.maxLines, 1);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
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

void _noopCategoria(String _) {}
