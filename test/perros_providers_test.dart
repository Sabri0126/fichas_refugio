import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:fichas_refugio/controllers/calendario_general_controller.dart';
import 'package:fichas_refugio/providers/firestore_providers.dart';
import 'package:fichas_refugio/providers/perros_providers.dart';
import 'package:fichas_refugio/providers/theme_mode_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('la lista se emite, se actualiza y dos lecturas ven la misma instancia', () async {
    final firestore = FakeFirebaseFirestore();
    final container = await _contenedor(firestore);
    container.listen(perrosProvider, (_, _) {});

    await firestore.collection('perros').doc('luna').set(_perro('Luna', sexo: 'hembra', enCasa: true));
    await _emitio(container);

    final primera = container.read(perrosProvider).value!;
    final segunda = container.read(perrosProvider).value!;
    expect(identical(primera, segunda), isTrue);
    expect(primera.single.nombre, 'Luna');

    await firestore.collection('perros').doc('luna').update({'nombre': 'Luna'});
    await firestore.collection('perros').doc('sol').set(_perro('Sol'));
    await _emitio(container, cantidad: 2);

    final actualizada = container.read(perrosProvider).value!;
    expect(actualizada.map((perro) => perro.nombre).toSet(), {'Luna', 'Sol'});
    expect(identical(actualizada, primera), isFalse);
    expect(identical(actualizada, container.read(perrosProvider).value), isTrue);
  });

  test('editar un campo se refleja en la lista', () async {
    final firestore = FakeFirebaseFirestore();
    final container = await _contenedor(firestore);
    container.listen(perrosProvider, (_, _) {});

    await firestore.collection('perros').doc('luna').set(_perro('Luna', sexo: 'hembra'));
    await _emitio(container);
    expect(container.read(perrosProvider).value!.single.sexo, 'hembra');

    await firestore.collection('perros').doc('luna').update({'sexo': 'macho'});
    await _emitioSexo(container, 'macho');

    expect(container.read(perrosProvider).value!.single.sexo, 'macho');
    expect(container.read(perrosProvider).value!.single.nombre, 'Luna');
  });

  test('borrar el documento deja el perro en null', () async {
    final firestore = FakeFirebaseFirestore();
    final container = await _contenedor(firestore);
    await firestore.collection('perros').doc('ficha').set(_perro('Ficha'));
    container.listen(perroProvider('ficha'), (_, _) {});
    await _emitioPerro(container, 'ficha');
    expect(container.read(perroProvider('ficha')).value?.perro?.nombre, 'Ficha');

    await firestore.collection('perros').doc('ficha').delete();
    await pumpEventQueue();
    await pumpEventQueue();

    expect(container.read(perroProvider('ficha')).value?.perro, isNull);
  });

  test('al marcar la dosis de hoy deja de figurar como pendiente', () async {
    final firestore = FakeFirebaseFirestore();
    final container = await _contenedor(firestore);
    final hoy = DateTime.now();
    final iso = _iso(hoy);
    await firestore.collection('perros').doc('luna').set({
      ..._perro('Luna'),
      'tratamientos': [_diario(registro: const [])],
    });
    container.listen(perrosProvider, (_, _) {});
    await _emitio(container);

    final antes = CalendarioGeneralController.construirResumen(
      container.read(perrosProvider).value!,
      hoy,
      hoy: hoy,
    );
    expect(antes.pendientes.map((item) => item.titulo), ['Artrin']);

    await firestore.collection('perros').doc('luna').update({
      'tratamientos': [_diario(registro: [iso])],
    });
    await _emitioDosis(container, iso);

    final despues = CalendarioGeneralController.construirResumen(
      container.read(perrosProvider).value!,
      hoy,
      hoy: hoy,
    );
    expect(despues.pendientes, isEmpty);
    expect(despues.dadas.map((item) => item.titulo), ['Artrin']);
  });

  test('filtra por ubicación, sexo y texto', () async {
    final firestore = FakeFirebaseFirestore();
    final container = await _contenedor(firestore);
    await firestore.collection('perros').doc('luna').set(_perro('Luna', sexo: 'hembra', enCasa: true));
    await firestore.collection('perros').doc('sol').set(_perro('Sol', sexo: 'macho'));
    await firestore.collection('perros').doc('roca').set(_perro('Roca', sexo: 'macho', enCasa: true));
    container.listen(perrosFiltradosProvider(SeccionPerros.activos), (_, _) {});
    await _emitio(container, cantidad: 3);

    final notifier = container.read(filtrosPerrosProvider(SeccionPerros.activos).notifier);
    notifier.reemplazar(const FiltrosPerros(ubicacion: 'En casa', sexo: 'Hembra'));
    expect(
      container.read(perrosFiltradosProvider(SeccionPerros.activos)).value!.map((perro) => perro.nombre),
      ['Luna'],
    );

    notifier.reemplazar(const FiltrosPerros(texto: 'ro'));
    expect(
      container.read(perrosFiltradosProvider(SeccionPerros.activos)).value!.map((perro) => perro.nombre),
      ['Roca'],
    );
  });
}

Map<String, Object?> _diario({required List<String> registro}) {
  return {
    'id': 't1',
    'categoria': 'diario',
    'medicacion': 'Artrin',
    'activo': true,
    'fecha_inicio': '2020-01-01',
    'dias_duracion': 0,
    'tipo_duracion': 'hasta_aviso',
    'hora_recordatorio': '09:00',
    'registro_dosis': registro,
  };
}

String _iso(DateTime fecha) {
  final mes = fecha.month.toString().padLeft(2, '0');
  final dia = fecha.day.toString().padLeft(2, '0');
  return '${fecha.year.toString().padLeft(4, '0')}-$mes-$dia';
}

Map<String, Object?> _perro(String nombre, {String sexo = 'macho', bool enCasa = false}) {
  return {
    'nombre': nombre,
    'sexo': sexo,
    'estado': 'activo',
    'en_casa': enCasa,
    'castrado': false,
    'galeria': <Map<String, dynamic>>[],
  };
}

Future<ProviderContainer> _contenedor(FirebaseFirestore firestore) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      firestoreProvider.overrideWithValue(firestore),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _emitio(ProviderContainer container, {int cantidad = 1}) async {
  for (var i = 0; i < 20; i++) {
    final lista = container.read(perrosProvider).value;
    if (lista != null && lista.length >= cantidad) return;
    await pumpEventQueue();
  }
  fail('La lista de perros no emitió $cantidad');
}

Future<void> _emitioSexo(ProviderContainer container, String sexo) async {
  for (var i = 0; i < 20; i++) {
    final lista = container.read(perrosProvider).value;
    if (lista != null && lista.any((perro) => perro.sexo == sexo)) return;
    await pumpEventQueue();
  }
  fail('La lista no reflejó el sexo $sexo');
}

Future<void> _emitioDosis(ProviderContainer container, String iso) async {
  for (var i = 0; i < 20; i++) {
    final lista = container.read(perrosProvider).value;
    final marcada = lista?.any(
          (perro) => perro.tratamientos.any((tratamiento) => tratamiento.registroDosis.contains(iso)),
        ) ??
        false;
    if (marcada) return;
    await pumpEventQueue();
  }
  fail('La dosis marcada no llegó a la lista');
}

Future<void> _emitioPerro(ProviderContainer container, String id) async {
  for (var i = 0; i < 20; i++) {
    if (container.read(perroProvider(id)).value?.perro != null) return;
    await pumpEventQueue();
  }
  fail('La ficha no emitió');
}
