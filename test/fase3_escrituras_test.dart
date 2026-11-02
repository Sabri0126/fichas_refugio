import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:fichas_refugio/controllers/perro_controller.dart';
import 'package:fichas_refugio/controllers/peso_controller.dart';
import 'package:fichas_refugio/controllers/recordatorio_controller.dart';
import 'package:fichas_refugio/controllers/seguimiento_controller.dart';
import 'package:fichas_refugio/controllers/tratamiento_controller.dart';
import 'package:fichas_refugio/models/peso_model.dart';
import 'package:fichas_refugio/models/recordatorio_model.dart';
import 'package:fichas_refugio/models/seguimiento_model.dart';
import 'package:fichas_refugio/models/tratamiento_model.dart';
import 'package:fichas_refugio/providers/firestore_providers.dart';
import 'package:fichas_refugio/providers/guardado_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('toggleDosis, alta y guardado de tratamientos quedan en el documento', () async {
    final firestore = FakeFirebaseFirestore();
    final tratamientos = TratamientoController(firestore: firestore);
    final hoy = DateTime.now();
    final diario = TratamientoModel(
      id: 't1',
      categoria: 'diario',
      medicacion: 'Artrin',
      indicaciones: '1',
      fechaInicio: DateTime(2020, 1, 1),
      tipoDuracion: TratamientoModel.tipoHastaAviso,
      horaRecordatorio: '09:00',
    );
    await firestore.collection('perros').doc('luna').set({
      'nombre': 'Luna',
      'tratamientos': [diario.toMap()],
    });

    final marcado = await tratamientos.toggleDosis('luna', diario, hoy);
    expect(marcado, isTrue);
    final iso = tratamientos.formatearFechaISO(hoy);
    var data = (await firestore.collection('perros').doc('luna').get()).data()!;
    var lista = data['tratamientos'] as List;
    expect(lista.single['registro_dosis'], contains(iso));

    final nuevo = diario.copyWith(id: 't2', medicacion: 'Omeprazol');
    await tratamientos.agregarTratamiento('luna', nuevo);
    data = (await firestore.collection('perros').doc('luna').get()).data()!;
    lista = data['tratamientos'] as List;
    expect(lista.map((item) => item['id']), containsAll(['t1', 't2']));

    final archivado = [
      for (final item in lista)
        TratamientoModel.fromMap(Map<String, dynamic>.from(item as Map), item['id'] as String),
    ];
    await tratamientos.guardarTratamientos('luna', [
      archivado.first.copyWith(activo: false),
      archivado.last,
    ]);
    data = (await firestore.collection('perros').doc('luna').get()).data()!;
    lista = data['tratamientos'] as List;
    expect(lista.first['activo'], isFalse);
  });

  test('peso, seguimiento y recordatorio se escriben con el id del controller', () async {
    final firestore = FakeFirebaseFirestore();
    final perros = PerroController(firestore: firestore);
    await firestore.collection('perros').doc('luna').set({'nombre': 'Luna'});

    final idPeso = PesoController(firestore: firestore).generarId();
    await perros.agregarPeso(
      'luna',
      PesoModel(id: idPeso, fecha: DateTime(2026, 3, 1), kg: 12.4, estimado: false, nota: ''),
    );

    final idSeguimiento = SeguimientoController(firestore: firestore).generarId();
    await perros.agregarSeguimiento(
      'luna',
      SeguimientoModel(
        id: idSeguimiento,
        motivo: 'otro',
        detalle: 'tos',
        hora: '08:00',
        fechaInicio: DateTime(2026, 3, 1),
        diasDuracion: 3,
        activo: true,
      ),
    );

    final idRecordatorio = RecordatorioController(firestore: firestore).generarId();
    await perros.agregarRecordatorio(
      'luna',
      RecordatorioModel(
        id: idRecordatorio,
        tipo: 'otro',
        titulo: 'Baño',
        nota: '',
        fechaHora: DateTime(2026, 3, 2, 10),
      ),
    );

    final data = (await firestore.collection('perros').doc('luna').get()).data()!;
    expect((data['pesos'] as List).single['id'], idPeso);
    expect((data['seguimientos'] as List).single['id'], idSeguimiento);
    expect((data['recordatorios'] as List).single['id'], idRecordatorio);
    expect(idPeso, isNot(idSeguimiento));
  });

  test('GuardadoNotifier: éxito, error, timeout y segundo toque', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(guardadoProvider('ficha'), (_, _) {});
    final notifier = container.read(guardadoProvider('ficha').notifier);

    var corridas = 0;
    expect(await notifier.ejecutar(() async => corridas++), isTrue);
    expect(corridas, 1);
    expect(container.read(guardadoProvider('ficha')).hasError, isFalse);

    expect(
      await notifier.ejecutar(() async => throw StateError('fallo')),
      isFalse,
    );
    expect(container.read(guardadoProvider('ficha')).hasError, isTrue);

    final vencido = await notifier.ejecutar(
      () => Completer<void>().future,
      timeout: const Duration(milliseconds: 20),
    );
    expect(vencido, isFalse);
    expect(container.read(guardadoProvider('ficha')).hasError, isTrue);

    final puerta = Completer<void>();
    final primero = notifier.ejecutar(() async {
      corridas++;
      await puerta.future;
    });
    final segundo = await notifier.ejecutar(() async => corridas++);
    expect(segundo, isFalse);
    puerta.complete();
    expect(await primero, isTrue);
    expect(corridas, 2);
  });

  testWidgets('varios rebuilds archivan una sola vez', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final archivado = TratamientoModel(
      id: 't1',
      categoria: 'diario',
      medicacion: 'Artrin',
      indicaciones: '1',
      activo: false,
    );
    await firestore.collection('perros').doc('perro').set({
      'nombre': 'Luna',
      'tratamientos': [archivado.copyWith(activo: true).toMap()],
    });
    _SondaArchivadoState.escrituras = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [firestoreProvider.overrideWithValue(firestore)],
        child: const MaterialApp(home: _SondaArchivado()),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('rebuild'));
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 50));

    final data = (await firestore.collection('perros').doc('perro').get()).data()!;
    expect((data['tratamientos'] as List).single['activo'], isFalse);
    expect(_SondaArchivadoState.escrituras, 1);
  });
}

class _SondaArchivado extends ConsumerStatefulWidget {
  const _SondaArchivado();

  @override
  ConsumerState<_SondaArchivado> createState() => _SondaArchivadoState();
}

class _SondaArchivadoState extends ConsumerState<_SondaArchivado> {
  static int escrituras = 0;
  final _marca = MarcaArchivado();
  final _tratamientos = [
    TratamientoModel(
      id: 't1',
      categoria: 'diario',
      medicacion: 'Artrin',
      indicaciones: '1',
      activo: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final firma = TratamientoController.firmaArchivados(_tratamientos);
    if (_marca.reservar(firma)) {
      final controller = ref.read(tratamientoControllerProvider);
      final copia = _tratamientos;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        escrituras++;
        controller.guardarTratamientos('perro', copia).catchError((_) {});
      });
    }
    return TextButton(onPressed: () => setState(() {}), child: const Text('rebuild'));
  }
}
