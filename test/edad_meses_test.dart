import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:fichas_refugio/controllers/perro_controller.dart';
import 'package:fichas_refugio/models/perro_model.dart';
import 'package:flutter_test/flutter_test.dart';

PerroModel perro({
  int edad = 0,
  int meses = 0,
  bool cuentaMeses = false,
  bool edadIndeterminada = false,
  int? edadAnioBase,
  String estado = 'activo',
  String nombre = 'Canelo',
}) {
  return PerroModel(
    id: 'p',
    nombre: nombre,
    estado: estado,
    edad: edad,
    meses: meses,
    cuentaMeses: cuentaMeses,
    edadIndeterminada: edadIndeterminada,
    edadAnioBase: edadAnioBase,
  );
}

void main() {
  test('suma un mes al cambiar de mes', () {
    expect(
      PerroController.mesesCalendario(DateTime(2026, 8, 15), DateTime(2026, 9, 2)),
      1,
    );
    expect(
      PerroController.avanzarEdad(edad: 0, meses: 4, mesesPasados: 1),
      (edad: 0, meses: 5, cruzoUnAnio: false),
    );
  });

  test('al llegar a 12 meses pasa a 1 año y avisa', () {
    expect(
      PerroController.avanzarEdad(edad: 0, meses: 11, mesesPasados: 1),
      (edad: 1, meses: 0, cruzoUnAnio: true),
    );
  });

  test('un salto que cae justo en 12 meses avisa este mes', () {
    expect(
      PerroController.avanzarEdad(edad: 0, meses: 4, mesesPasados: 8),
      (edad: 1, meses: 0, cruzoUnAnio: true),
    );
  });

  test('un salto que pasó el año en un mes anterior no avisa', () {
    expect(
      PerroController.avanzarEdad(edad: 0, meses: 4, mesesPasados: 10),
      (edad: 1, meses: 2, cruzoUnAnio: false),
    );
    expect(
      PerroController.avanzarEdad(edad: 0, meses: 11, mesesPasados: 2),
      (edad: 1, meses: 1, cruzoUnAnio: false),
    );
  });

  test('1 año y 11 meses pasa a 2 años sin aviso', () {
    expect(
      PerroController.avanzarEdad(edad: 1, meses: 11, mesesPasados: 1),
      (edad: 2, meses: 0, cruzoUnAnio: false),
    );
  });

  test('un adulto sin marca no muestra meses ni suma el año dos veces', () {
    final adulto = perro(edad: 2, meses: 4, edadAnioBase: DateTime.now().year);
    expect(PerroController.cuentaPorMeses(adulto), isFalse);
    expect(
      PerroController.formatearEdadTexto(adulto),
      'Edad estimada: 2 años',
    );
  });

  test('quien cuenta por meses muestra años y meses guardados', () {
    final joven = perro(edad: 1, meses: 3, cuentaMeses: true, edadAnioBase: 2024);
    expect(PerroController.formatearEdadTexto(joven), 'Edad estimada: 1 año y 3 meses');
    expect(PerroController.calcularEdadEstimada(joven), 1);
  });

  test('un cachorro sin marca también cuenta por meses', () {
    final cachorro = perro(edad: 0, meses: 4);
    expect(PerroController.cuentaPorMeses(cachorro), isTrue);
    expect(PerroController.formatearEdadTexto(cachorro), 'Edad: 4 meses');
  });

  test('corregir la edad a años deja de contar por meses', () {
    expect(
      PerroController.cuentaMesesAlGuardar(
        edadNueva: 0,
        yaContaba: false,
        edadAnterior: null,
        edadIndeterminada: false,
      ),
      isTrue,
    );
    expect(
      PerroController.cuentaMesesAlGuardar(
        edadNueva: 1,
        yaContaba: true,
        edadAnterior: 1,
        edadIndeterminada: false,
      ),
      isTrue,
    );
    expect(
      PerroController.cuentaMesesAlGuardar(
        edadNueva: 3,
        yaContaba: true,
        edadAnterior: 0,
        edadIndeterminada: false,
      ),
      isFalse,
    );
  });

  test('la edad indeterminada no cuenta por meses', () {
    expect(
      PerroController.cuentaMesesAlGuardar(
        edadNueva: 0,
        yaContaba: true,
        edadAnterior: 0,
        edadIndeterminada: true,
      ),
      isFalse,
    );
  });

  test('editar un adulto no pierde los años sumados', () {
    final original = perro(edad: 2, edadAnioBase: 2025);
    final enCampo = PerroController.edadEnFormulario(original);
    final guardado = perro(edad: enCampo, edadAnioBase: DateTime.now().year);

    expect(enCampo, 2 + (DateTime.now().year - 2025));
    expect(
      PerroController.calcularEdadEstimada(guardado),
      PerroController.calcularEdadEstimada(original),
    );

    final cachorro = perro(edad: 0, meses: 4, cuentaMeses: true, edadAnioBase: 2025);
    expect(PerroController.edadEnFormulario(cachorro), 0);
  });

  test('guardar sin tocar la edad no pisa el mes que sumó la función', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final firestore = FakeFirebaseFirestore();
    final marca = DateTime(2026, 11, 1);
    await firestore.collection('perros').doc('cachorro').set({
      'nombre': 'Canelo',
      'edad': 0,
      'meses': 5,
      'cuenta_meses': true,
      'ultima_actualizacion_edad': Timestamp.fromDate(marca),
    });

    await PerroController(firestore: firestore).guardarPerro(
      PerroModel(
        id: 'cachorro',
        nombre: 'Canelo',
        edad: 0,
        meses: 4,
        cuentaMeses: true,
        ultimaActualizacionEdad: DateTime(2026, 10, 1),
      ),
      edadOriginal: 0,
      mesesOriginales: 4,
    );

    final data = (await firestore.collection('perros').doc('cachorro').get()).data()!;
    expect(data['meses'], 5);
    expect(data['edad'], 0);
    expect((data['ultima_actualizacion_edad'] as Timestamp).toDate(), marca);
  });

  test('0 años y 0 meses es edad sin cargar', () {
    final sin = perro(edad: 0, meses: 0);
    expect(PerroController.edadSinCargar(sin), isTrue);
    expect(PerroController.formatearEdadTexto(sin), 'Edad sin cargar');
    expect(PerroController.formatearEdadTexto(perro(edad: 0, meses: 4)), 'Edad: 4 meses');
  });

  test('validarEdad y validarEdadCargada', () {
    final c = PerroController();
    expect(c.validarEdad('30'), isNotNull);
    expect(c.validarEdad('3'), isNull);
    expect(c.validarEdadCargada('', '', false), isNotNull);
    expect(c.validarEdadCargada('0', '0', false), isNotNull);
    expect(c.validarEdadCargada('0', '0', true), isNull);
    expect(c.validarEdadCargada('0', '3', false), isNull);
  });

  test('mesesQueSumariaLaFuncion avisa con ingreso viejo', () {
    final ingreso = DateTime(2026, 3, 1);
    final ahora = DateTime(2026, 11, 1);
    expect(
      PerroController.mesesQueSumariaLaFuncion(
        edadNueva: 0,
        mesesNuevos: 0,
        edadIndeterminada: false,
        yaContaba: true,
        edadAnterior: 0,
        mesesAnteriores: 0,
        ultimaActualizacionEdad: null,
        fechaIngreso: ingreso,
        ahora: ahora,
      ),
      8,
    );
    expect(
      PerroController.mesesQueSumariaLaFuncion(
        edadNueva: 1,
        mesesNuevos: 0,
        edadIndeterminada: false,
        yaContaba: true,
        edadAnterior: 0,
        mesesAnteriores: 0,
        ultimaActualizacionEdad: null,
        fechaIngreso: ingreso,
        ahora: ahora,
      ),
      0,
    );
  });

  test('compararPorEdad deja sin cargar al final', () {
    final lista = [
      perro(edad: 0, meses: 0, nombre: 'Sin'),
      perro(edad: 0, meses: 3, nombre: 'Cachorro'),
      perro(edad: 2, meses: 0, nombre: 'Adulto'),
    ]..sort(PerroController.compararPorEdad);
    expect(lista.map((p) => p.nombre), ['Cachorro', 'Adulto', 'Sin']);
  });
}
