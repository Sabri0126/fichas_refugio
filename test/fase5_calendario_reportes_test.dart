import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:fichas_refugio/controllers/calendario_general_controller.dart';
import 'package:fichas_refugio/controllers/reportes_controller.dart';
import 'package:fichas_refugio/controllers/tratamiento_controller.dart';
import 'package:fichas_refugio/models/perro_model.dart';
import 'package:fichas_refugio/models/seguimiento_model.dart';
import 'package:fichas_refugio/models/tratamiento_model.dart';
import 'package:fichas_refugio/providers/auth_providers.dart';
import 'package:fichas_refugio/providers/calendario_providers.dart';
import 'package:fichas_refugio/providers/firestore_providers.dart';
import 'package:fichas_refugio/providers/perros_providers.dart';
import 'package:fichas_refugio/providers/reportes_providers.dart';
import 'package:fichas_refugio/theme/app_theme.dart';
import 'package:fichas_refugio/views/pantalla_calendario_general.dart';
import 'package:fichas_refugio/views/pantalla_reportes.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _hoy = DateTime(2026, 6, 15);

TratamientoModel _diario() {
  return TratamientoModel(
    id: 'diario',
    categoria: 'diario',
    medicacion: 'Pastilla',
    indicaciones: '1 comprimido',
    fechaInicio: DateTime(2026, 6, 10),
    diasDuracion: 10,
    activo: true,
  );
}

PerroModel _luna() {
  return PerroModel(
    id: 'p1',
    nombre: 'Luna',
    estado: 'activo',
    fechaIngreso: DateTime(2020, 4, 29),
    tratamientos: [_diario()],
    seguimientos: [
      SeguimientoModel(
        id: 's1',
        motivo: 'Herida',
        detalle: 'Revisar',
        hora: '09:00',
        fechaInicio: DateTime(2026, 6, 1),
        diasDuracion: 30,
        activo: true,
      ),
    ],
  );
}

PerroModel _inactivo() {
  return PerroModel(id: 'fuera', nombre: 'Nube', estado: 'inactivo');
}

DateTime Function() _reloj() => () => _hoy;

ProviderContainer _contenedor(List<PerroModel> perros) {
  return ProviderContainer(
    overrides: [
      relojProvider.overrideWithValue(_reloj()),
      perrosProvider.overrideWithValue(AsyncData(perros)),
    ],
  );
}

void _escucharCalendario(ProviderContainer container) {
  container.listen(filtrosCalendarioProvider, (_, _) {});
  container.listen(perrosActivosCalendarioProvider, (_, _) {});
  container.listen(resumenDiaProvider, (_, _) {});
  container.listen(listaCalendarioProvider, (_, _) {});
  container.listen(seguimientosActivosProvider, (_, _) {});
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('los filtros cambian día, vista, perro, tipo y búsqueda', () {
    final container = _contenedor(const []);
    addTearDown(container.dispose);
    _escucharCalendario(container);
    final filtros = container.read(filtrosCalendarioProvider.notifier);

    expect(container.read(filtrosCalendarioProvider).diaSeleccionado, _hoy);
    expect(container.read(filtrosCalendarioProvider).vista, VistaCalendario.mes);

    filtros.seleccionarDia(DateTime(2026, 6, 20, 18, 30));
    expect(
      container.read(filtrosCalendarioProvider).diaSeleccionado,
      DateTime(2026, 6, 20),
    );

    filtros.cambiarVista(VistaCalendario.lista);
    expect(container.read(filtrosCalendarioProvider).vista, VistaCalendario.lista);
    filtros.irAHoy();
    final vuelta = container.read(filtrosCalendarioProvider);
    expect(vuelta.vista, VistaCalendario.mes);
    expect(vuelta.diaSeleccionado, _hoy);
    expect(vuelta.diaEnfocado, _hoy);

    filtros.filtrarPerro('p1');
    filtros.filtrarTipo('diario');
    filtros.buscar('luna');
    filtros.buscar('luna');
    final conFiltro = container.read(filtrosCalendarioProvider);
    expect(conFiltro.idPerro, 'p1');
    expect(conFiltro.tipo, 'diario');
    expect(conFiltro.busqueda, 'luna');
  });

  test('resumen, lista y seguimientos coinciden con el controlador', () {
    final perros = [_luna(), _inactivo()];
    final container = _contenedor(perros);
    addTearDown(container.dispose);
    _escucharCalendario(container);
    final filtros = container.read(filtrosCalendarioProvider);

    final resumen = container.read(resumenDiaProvider).requireValue;
    final directo = CalendarioGeneralController.construirResumen(
      perros,
      filtros.diaSeleccionado,
      hoy: filtros.hoy,
    );
    expect(resumen.pendientes.length, directo.pendientes.length);
    expect(resumen.dadas.length, directo.dadas.length);
    expect(resumen.pendientes.map((item) => item.titulo), directo.pendientes.map((item) => item.titulo));

    final lista = container.read(listaCalendarioProvider).requireValue.entradas;
    final antigua = CalendarioGeneralController.fechaMasAntigua(perros);
    final desde = antigua != null && antigua.isBefore(filtros.primerDia) ? antigua : filtros.primerDia;
    final listaDirecta = CalendarioGeneralController.construirLista(
      perros,
      desde: desde,
      hasta: filtros.ultimoDia,
    );
    expect(lista.length, listaDirecta.length);
    expect(lista.map((entrada) => entrada.titulo), listaDirecta.map((entrada) => entrada.titulo));

    final seguimientos = container.read(seguimientosActivosProvider).requireValue;
    final seguimientosDirectos = CalendarioGeneralController.seguimientosActivos(perros, hoy: filtros.hoy);
    expect(seguimientos.length, seguimientosDirectos.length);
    expect(seguimientos.map((item) => item.titulo), seguimientosDirectos.map((item) => item.titulo));

    container.read(filtrosCalendarioProvider.notifier).filtrarPerro('fuera');
    final ignorado = container.read(resumenDiaProvider).requireValue;
    expect(ignorado.pendientes.length, directo.pendientes.length);
    expect(container.read(filtrosCalendarioProvider).idPerro, 'fuera');

    final listaAntes = container.read(listaCalendarioProvider);
    final resumenAntes = container.read(resumenDiaProvider);
    container.read(filtrosCalendarioProvider.notifier).buscar('otra');
    container.read(filtrosCalendarioProvider.notifier).filtrarTipo('vacuna');
    expect(identical(container.read(listaCalendarioProvider), listaAntes), isTrue);
    expect(identical(container.read(resumenDiaProvider), resumenAntes), isTrue);
  });

  test('pendientes de hoy coinciden con el cálculo anterior', () {
    final perros = [_luna()];
    final container = _contenedor(perros);
    addTearDown(container.dispose);

    final esperados = CalendarioGeneralController.construirResumen(perros, _hoy, hoy: _hoy).pendientes.length;
    expect(container.read(pendientesHoyProvider), esperados);
    expect(esperados, greaterThan(0));
  });

  test('sin lista, los pendientes de hoy son cero', () {
    final container = ProviderContainer(
      overrides: [
        relojProvider.overrideWithValue(_reloj()),
        perrosProvider.overrideWithValue(const AsyncLoading()),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(pendientesHoyProvider), 0);
  });

  test('el mes del reporte arranca en el reloj y calcular coincide', () {
    final perros = [_luna()];
    final container = _contenedor(perros);
    addTearDown(container.dispose);
    container.listen(mesReporteProvider, (_, _) {});
    container.listen(reporteProvider, (_, _) {});

    expect(container.read(mesReporteProvider), DateTime(2026, 6));
    container.read(mesReporteProvider.notifier).fijarMes(3);
    container.read(mesReporteProvider.notifier).fijarAnio(2024);
    expect(container.read(mesReporteProvider), DateTime(2024, 3));

    final reporte = container.read(reporteProvider).requireValue;
    final directo = ReportesController.calcular(perros, hoy: _hoy, mes: DateTime(2024, 3));
    expect(reporte.poblacion.activos, directo.poblacion.activos);
    expect(reporte.poblacion.enCasa, directo.poblacion.enCasa);
    expect(reporte.poblacion.enRefugio, directo.poblacion.enRefugio);
    expect(reporte.balance.adoptados, directo.balance.adoptados);
    expect(reporte.balance.reencontrados, directo.balance.reencontrados);
    expect(reporte.balance.difuntos, directo.balance.difuntos);
    expect(reporte.estadia.mesesPromedio, directo.estadia.mesesPromedio);
    expect(reporte.estadia.conFecha, directo.estadia.conFecha);
    expect(reporte.mes.ingresos, directo.mes.ingresos);
    expect(reporte.mes.adopciones, directo.mes.adopciones);
    expect(reporte.serie.puntos.length, directo.serie.puntos.length);
    expect(reporte.serie.sinFecha, directo.serie.sinFecha);
  });

  test('un error de perros deja el reporte en error aunque haya valor', () {
    final error = StateError('red');
    final container = ProviderContainer(
      overrides: [
        relojProvider.overrideWithValue(_reloj()),
        perrosProvider.overrideWithValue(AsyncError(error, StackTrace.empty)),
      ],
    );
    addTearDown(container.dispose);
    container.listen(reporteProvider, (_, _) {});
    final reporte = container.read(reporteProvider);
    expect(reporte.hasError, isTrue);
    expect(reporte.hasValue, isFalse);
  });

  testWidgets('el calendario muestra carga, error, vacío y datos', (tester) async {
    await _montarCalendario(tester, perros: const AsyncLoading());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('No se pudo cargar el calendario.'), findsNothing);

    await _montarCalendario(tester, perros: AsyncError(StateError('red'), StackTrace.empty));
    expect(find.text('No se pudo cargar el calendario.'), findsOneWidget);

    await _montarCalendario(tester, perros: const AsyncData([]));
    expect(find.text('No hay perritos registrados aún.'), findsOneWidget);

    await _montarCalendario(tester, perros: AsyncData([_luna()]));
    await _esperarCalendario(tester);
    expect(find.text('Pastilla'), findsWidgets);
    expect(find.text('Agregar registro'), findsOneWidget);
  });

  testWidgets('el visitante no ve Agregar registro', (tester) async {
    await _montarCalendario(
      tester,
      perros: AsyncData([_luna()]),
      auth: MockFirebaseAuth(signedIn: false),
    );
    await _esperarCalendario(tester);
    expect(find.text('Agregar registro'), findsNothing);
    expect(find.byTooltip('Marcar como dada'), findsOneWidget);
  });

  testWidgets('marcar la dosis escribe en el firestore inyectado', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final perro = _luna();
    await firestore.collection('perros').doc(perro.id).set(perro.toMap());

    await _montarCalendario(
      tester,
      perros: AsyncData([perro]),
      firestore: firestore,
    );
    await _esperarCalendario(tester);
    await tester.tap(find.byTooltip('Marcar como dada'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final data = (await firestore.collection('perros').doc(perro.id).get()).data()!;
    final registro = ((data['tratamientos'] as List).single as Map)['registro_dosis'] as List;
    expect(registro, contains(TratamientoController.fechaIso(_hoy)));
  });

  testWidgets('un fallo al marcar la dosis muestra el aviso', (tester) async {
    await _montarCalendario(
      tester,
      perros: AsyncData([_luna()]),
      tratamientos: _TratamientosQueFallan(),
    );
    await _esperarCalendario(tester);
    await tester.tap(find.byTooltip('Marcar como dada'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('No se pudo marcar la dosis'), findsOneWidget);
  });

  testWidgets('los reportes muestran carga, error, vacío y datos', (tester) async {
    await _montarReportes(tester, const AsyncLoading());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('No se pudieron cargar los reportes.'), findsNothing);

    await _montarReportes(tester, AsyncError(StateError('red'), StackTrace.empty));
    expect(find.text('No se pudieron cargar los reportes.'), findsOneWidget);

    await _montarReportes(tester, const AsyncData([]));
    await tester.pump();
    expect(find.text('Hoy en el refugio'), findsOneWidget);
    expect(find.text('0 en el refugio · 0 en casa'), findsOneWidget);

    await _montarReportes(tester, AsyncData([_luna()]));
    await tester.pump();
    expect(find.text('Hoy en el refugio'), findsOneWidget);
    expect(find.text('1 en el refugio · 0 en casa'), findsOneWidget);
  });
}

Future<void> _montarCalendario(
  WidgetTester tester, {
  required AsyncValue<List<PerroModel>> perros,
  MockFirebaseAuth? auth,
  FakeFirebaseFirestore? firestore,
  TratamientoController? tratamientos,
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        relojProvider.overrideWithValue(_reloj()),
        perrosProvider.overrideWithValue(perros),
        firebaseAuthProvider.overrideWithValue(
          auth ??
              MockFirebaseAuth(
                signedIn: true,
                mockUser: MockUser(uid: 'staff', email: 'staff@refugio.test'),
              ),
        ),
        if (firestore != null) firestoreProvider.overrideWithValue(firestore),
        if (tratamientos != null) tratamientoControllerProvider.overrideWithValue(tratamientos),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: const PantallaCalendarioGeneral(),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _esperarCalendario(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (find.text('Filtrar por perro').evaluate().isNotEmpty) return;
  }
  fail('el calendario no salió de la carga');
}

Future<void> _montarReportes(WidgetTester tester, AsyncValue<List<PerroModel>> perros) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        relojProvider.overrideWithValue(_reloj()),
        perrosProvider.overrideWithValue(perros),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: const PantallaReportes(),
      ),
    ),
  );
  await tester.pump();
}

class _TratamientosQueFallan extends TratamientoController {
  @override
  Future<bool> toggleDosis(
    String perroId,
    TratamientoModel tratamiento,
    DateTime fechaDosis,
  ) async {
    throw StateError('fallo');
  }
}
