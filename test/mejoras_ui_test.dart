import 'dart:convert';
import 'dart:math' as math;

import 'package:fichas_refugio/controllers/perro_controller.dart';
import 'package:fichas_refugio/controllers/tratamiento_controller.dart';
import 'package:fichas_refugio/models/perro_model.dart';
import 'package:fichas_refugio/models/tratamiento_model.dart';
import 'package:fichas_refugio/services/exportar_ficha.dart';
import 'package:fichas_refugio/theme/app_colors.dart';
import 'package:fichas_refugio/theme/app_theme.dart';
import 'package:fichas_refugio/theme/encabezado_seccion.dart';
import 'package:fichas_refugio/views/formulario_perro.dart';
import 'package:fichas_refugio/views/pantalla_menu.dart';
import 'package:fichas_refugio/views/pantalla_perros.dart';
import 'package:fichas_refugio/views/pantalla_tarjeta_perro.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/widgets.dart' as pw;

TratamientoModel _diario({
  required DateTime inicio,
  int dias = 5,
  bool activo = true,
  List<String> doses = const [],
}) {
  return TratamientoModel(
    id: 't1',
    categoria: 'diario',
    medicacion: 'medicación diaria',
    indicaciones: 'indicaciones',
    fechaInicio: inicio,
    diasDuracion: dias,
    activo: activo,
    registroDosis: doses,
  );
}

void main() {
  final hoy = DateTime(2026, 10, 13);

  test('no muestra días anteriores al inicio', () {
    final marcas = TratamientoController.marcasDosisRecientes(
      _diario(inicio: DateTime(2026, 10, 11)),
      hoy: hoy,
    );
    expect(marcas.map((marca) => marca.dia.day), [11, 12, 13]);
    expect(marcas.every((marca) => !marca.dia.isBefore(DateTime(2026, 10, 11))), isTrue);
  });

  test('un tratamiento pausado no marca los días vacíos como olvidados', () {
    final marcas = TratamientoController.marcasDosisRecientes(
      _diario(inicio: DateTime(2026, 10, 11), activo: false, doses: const ['2026-10-11']),
      hoy: hoy,
    );
    expect(marcas[0].estado, EstadoMarcaDosis.dada);
    expect(marcas[1].estado, EstadoMarcaDosis.pausa);
    expect(marcas[2].estado, EstadoMarcaDosis.pausa);
  });

  test('hoy sin dosis queda pendiente y un día pasado queda olvidado', () {
    final marcas = TratamientoController.marcasDosisRecientes(
      _diario(inicio: DateTime(2026, 10, 11)),
      hoy: hoy,
    );
    expect(marcas[0].estado, EstadoMarcaDosis.olvidada);
    expect(marcas[2].estado, EstadoMarcaDosis.pendiente);
  });

  testWidgets('filtros, estado, menú y encabezado no desbordan a 360 dp con escala 1.6', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                FiltrosHorizontales(
                  opciones: const ['Todos', 'Adoptados', 'Reencontrados'],
                  seleccionado: 'Todos',
                  onChanged: (_) {},
                ),
                const SizedBox(height: 16),
                SelectorEstadoPerro(estado: 'egresado', onChanged: (_) {}),
                const SizedBox(height: 16),
                const EncabezadoSeccion(titulo: 'Gestión de Salud', icono: Icons.favorite_outline),
                BotonMenu(
                  label: 'Adoptados y reencontrados',
                  detalle: '0 adoptados · 1 reencontrados',
                  icon: Icons.volunteer_activism,
                  color: const Color(0xFF2E6B44),
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Reencontrados'), findsOneWidget);
    expect(find.text('Fallecido'), findsOneWidget);
    expect(find.text('Egresado'), findsOneWidget);
  });

  testWidgets('el tema oscuro carga', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(oscuro: true),
        home: const Scaffold(body: Text('Oscuro')),
      ),
    );
    expect(find.text('Oscuro'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el botón de vista recorre las tres vistas y vuelve a la primera', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.pumpWidget(const MaterialApp(home: _CicloVista()));

    expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);
    await tester.tap(find.byType(BotonVista));
    await tester.pump();
    expect(find.byIcon(Icons.apps_rounded), findsOneWidget);
    await tester.tap(find.byType(BotonVista));
    await tester.pump();
    expect(find.byIcon(Icons.view_list_rounded), findsOneWidget);
    await tester.tap(find.byType(BotonVista));
    await tester.pump();
    expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);
  });

  testWidgets('en oscuro el chip y el input tienen texto claro', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final tema = buildAppTheme(oscuro: true);
    await tester.pumpWidget(
      MaterialApp(
        theme: tema,
        home: Scaffold(
          body: Column(
            children: [
              ChoiceChip(label: const Text('Todos'), selected: false, onSelected: (_) {}),
              const TextField(),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    final colorChip = tester.renderObject<RenderParagraph>(find.text('Todos')).text.style!.color!;
    final fondoChip = tema.chipTheme.backgroundColor!;
    final colorInput = tema.textTheme.bodyLarge!.color!;
    final rellenoInput = tema.inputDecorationTheme.fillColor!;

    expect(_contraste(colorChip, fondoChip), greaterThanOrEqualTo(4.5));
    expect(_contraste(colorInput, rellenoInput), greaterThanOrEqualTo(4.5));
    expect(colorChip.computeLuminance(), greaterThan(0.6));
    expect(colorInput.computeLuminance(), greaterThan(0.6));
  });

  testWidgets('el panel de filtros muestra Ubicación primero', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: PanelOrdenFiltros(
              egresados: false,
              mostrarPendientes: true,
              ubicacion: 'Todos',
              motivo: 'Todos',
              ordenEtiqueta: 'Recientes',
              sexo: 'Todos',
              castrado: 'Todos',
              soloPendientes: false,
              soloActivos: false,
              onUbicacion: (_) {},
              onMotivo: (_) {},
              onOrden: (_) {},
              onSexo: (_) {},
              onCastrado: (_) {},
              onPendientes: (_) {},
              onActivos: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final etiquetas = tester
        .widgetList<Text>(find.byType(Text))
        .map((texto) => texto.data)
        .whereType<String>()
        .toList();
    expect(etiquetas.first, 'Orden y filtros');
    expect(etiquetas[1], 'Ubicación');
    expect(etiquetas.indexOf('Ubicación'), lessThan(etiquetas.indexOf('Orden')));
    expect(find.text('Con tratamiento activo'), findsOneWidget);
  });

  test('el filtro de tratamiento activo deja afuera pausados y finalizados', () {
    final hoy = DateTime(2026, 10, 13);
    TratamientoModel diario({required bool activo, required DateTime inicio, int dias = 5}) {
      return TratamientoModel(
        id: 't',
        categoria: 'diario',
        medicacion: 'pastilla',
        indicaciones: '',
        fechaInicio: inicio,
        diasDuracion: dias,
        activo: activo,
      );
    }

    expect(
      tieneTratamientoActivo([diario(activo: true, inicio: hoy)], hoy: hoy),
      isTrue,
    );
    expect(
      tieneTratamientoActivo([diario(activo: false, inicio: hoy)], hoy: hoy),
      isFalse,
    );
    expect(
      tieneTratamientoActivo(
        [diario(activo: true, inicio: DateTime(2026, 10, 1), dias: 3)],
        hoy: hoy,
      ),
      isFalse,
    );
  });

  test('el pdf admite eñe, viñeta y raya', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final bytes = await ExportarFicha.generar(
      perro: PerroModel(
        id: 'p1',
        nombre: 'Ñoño',
        historia: 'Llegó con una herida.',
        tratamientos: [
          TratamientoModel(
            id: 't1',
            categoria: 'diario',
            medicacion: 'Ivermectina',
            indicaciones: 'uña • dosis — mañana',
            activo: true,
          ),
        ],
      ),
      edad: '2 años',
    );
    expect(bytes, isNotEmpty);
  });

  test('el pdf se genera aunque fallen las fotos y también con fotos inyectadas', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final perro = PerroModel(
      id: 'p2',
      nombre: 'Luna',
      galeria: [
        {'url': 'https://example.invalid/a.jpg', 'texto': 'En el parque'},
        {'url': 'https://example.invalid/b.jpg', 'descripcion': 'Sin descripción'},
      ],
      galeriaEstudios: [
        {'url': 'https://example.invalid/c.jpg', 'descripcion': 'Radiografía 08/10'},
      ],
    );

    final sinFotos = await ExportarFicha.generar(
      perro: perro,
      edad: '3 años',
      descargar: (_) async => null,
    );
    expect(sinFotos, isNotEmpty);

    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    );
    final conFotos = await ExportarFicha.generar(
      perro: perro,
      edad: '3 años',
      descargar: (_) async => pw.MemoryImage(png),
    );
    expect(conFotos, isNotEmpty);
    expect(conFotos.length, greaterThan(sinFotos.length));
  });

  testWidgets('la tarjeta muestra castrada, un año y el resto de las fotos', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final hembra = PerroModel(
      id: 'h',
      nombre: 'Nika',
      sexo: 'hembra',
      edad: 1,
      edadAnioBase: DateTime.now().year,
      castrado: true,
      historia: 'Llegó en enero con su hermana y se quedó en el refugio.',
      galeria: List.generate(5, (i) => {'url': 'https://example.invalid/$i.jpg', 'texto': 'foto'}),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(body: Center(child: TarjetaPerro(perro: hembra))),
      ),
    );
    await tester.pump();

    expect(find.text('Castrada'), findsOneWidget);
    expect(find.text('1 año aprox.'), findsOneWidget);
    expect(find.text('+3'), findsOneWidget);
    expect(find.textContaining('Llegó en enero'), findsOneWidget);
    expect(find.byKey(TarjetaPerro.citaKey), findsOneWidget);
  });

  testWidgets('sin historia la tarjeta no muestra la cita', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final perro = PerroModel(
      id: 'm',
      nombre: 'Melchor',
      sexo: 'macho',
      edad: 2,
      edadAnioBase: DateTime.now().year,
      historia: '   ',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(body: Center(child: TarjetaPerro(perro: perro))),
      ),
    );
    await tester.pump();

    expect(find.byKey(TarjetaPerro.citaKey), findsNothing);
    expect(find.text('Melchor'), findsOneWidget);
  });

  test('el fragmento de la historia saca viñetas y negritas', () {
    expect(
      TarjetaPerro.fragmentoHistoria('• 4 cachorras **en** el portón'),
      '4 cachorras en el portón',
    );
  });

  test('un año queda en singular y la castración concuerda con el sexo', () {
    final macho = PerroModel(
      id: 'm',
      nombre: 'Melchor',
      sexo: 'macho',
      edad: 1,
      edadAnioBase: DateTime.now().year,
      castrado: true,
    );
    final hembra = PerroModel(
      id: 'h',
      nombre: 'Nika',
      sexo: 'hembra',
      edad: 1,
      edadAnioBase: DateTime.now().year,
      castrado: true,
    );

    expect(PerroController.formatearEdadTexto(macho), 'Edad estimada: 1 año');
    expect(PerroController.formatearEdadTexto(hembra), 'Edad estimada: 1 año');
    expect(PerroController.formatearCastracion(macho), 'Castrado');
    expect(PerroController.formatearCastracion(hembra), 'Castrada');
    expect(
      PerroController.formatearCastracion(PerroModel(id: 'h2', nombre: 'Uma', sexo: 'hembra', castrado: false)),
      'No castrada',
    );
  });

  test('el botón de nuevo ingreso cambia de color en oscuro', () {
    final claro = buildAppTheme().floatingActionButtonTheme.backgroundColor;
    final oscuro = buildAppTheme(oscuro: true).floatingActionButtonTheme.backgroundColor;
    expect(claro, AppColors.terracota);
    expect(oscuro, Color.lerp(AppColors.terracota, Colors.black, 0.35));
  });
}

double _luminancia(Color color) {
  double canal(double valor) {
    return valor <= 0.04045 ? valor / 12.92 : math.pow((valor + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * canal(color.r) + 0.7152 * canal(color.g) + 0.0722 * canal(color.b);
}

double _contraste(Color a, Color b) {
  final clara = math.max(_luminancia(a), _luminancia(b));
  final oscura = math.min(_luminancia(a), _luminancia(b));
  return (clara + 0.05) / (oscura + 0.05);
}

class _CicloVista extends StatefulWidget {
  const _CicloVista();

  @override
  State<_CicloVista> createState() => _CicloVistaState();
}

class _CicloVistaState extends State<_CicloVista> {
  ModoVista modo = ModoVista.grande;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BotonVista(
        modo: modo,
        onChanged: (nuevo) => setState(() => modo = nuevo),
      ),
    );
  }
}
