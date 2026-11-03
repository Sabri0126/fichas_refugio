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
}) {
  return PerroModel(
    id: 'p',
    nombre: 'Canelo',
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
}
