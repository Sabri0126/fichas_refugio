import 'package:flutter_test/flutter_test.dart';
import 'package:fichas_refugio/controllers/perro_controller.dart';
import 'package:fichas_refugio/models/egreso_model.dart';
import 'package:fichas_refugio/models/perro_model.dart';

PerroModel _perro({
  required String estado,
  List<EgresoModel> historialEgresos = const [],
  String? motivoEgreso,
  DateTime? fechaEgreso,
  String? notaEgreso,
}) {
  return PerroModel(
    id: '1',
    nombre: 'Canelo',
    estado: estado,
    historialEgresos: historialEgresos,
    motivoEgreso: motivoEgreso,
    fechaEgreso: fechaEgreso,
    notaEgreso: notaEgreso,
  );
}

void main() {
  final egresoPrevio = EgresoModel(
    motivo: 'adopcion',
    fechaEgreso: DateTime(2024, 3, 1),
    nota: 'Primera casa',
    fechaRegreso: DateTime(2024, 6, 1),
  );

  test('alta sin perro previo devuelve historial vacío', () {
    final historial = PerroController.calcularHistorialEgresos(
      original: null,
      estadoNuevo: 'egresado',
    );
    expect(historial, isEmpty);
  });

  test('activo que pasa a egresado no archiva', () {
    final original = _perro(estado: 'activo');
    final historial = PerroController.calcularHistorialEgresos(
      original: original,
      estadoNuevo: 'egresado',
      motivo: 'adopcion',
      fechaEgreso: DateTime(2026, 1, 1),
    );
    expect(historial, isEmpty);
    expect(original.historialEgresos, isEmpty);
  });

  test('egresado que vuelve a activo archiva con fecha de regreso y no muta la lista original', () {
    final original = _perro(
      estado: 'egresado',
      motivoEgreso: 'familia',
      fechaEgreso: DateTime(2026, 2, 2),
      notaEgreso: '  apareció la familia  ',
    );
    final regreso = DateTime(2026, 2, 10);
    final historial = PerroController.calcularHistorialEgresos(
      original: original,
      estadoNuevo: 'activo',
      motivo: 'familia',
      fechaEgreso: DateTime(2026, 2, 2),
      nota: '  apareció la familia  ',
      fechaRegreso: regreso,
    );

    expect(original.historialEgresos, isEmpty);
    expect(identical(historial, original.historialEgresos), isFalse);
    expect(historial, hasLength(1));
    expect(historial.single.motivo, 'familia');
    expect(historial.single.fechaEgreso, DateTime(2026, 2, 2));
    expect(historial.single.nota, 'apareció la familia');
    expect(historial.single.fechaRegreso, regreso);
  });

  test('egresado que pasa a inactivo archiva sin fecha de regreso', () {
    final original = _perro(estado: 'egresado', motivoEgreso: 'adopcion');
    final historial = PerroController.calcularHistorialEgresos(
      original: original,
      estadoNuevo: 'inactivo',
      motivo: 'adopcion',
      fechaEgreso: DateTime(2025, 5, 5),
      nota: '   ',
      fechaRegreso: DateTime(2025, 6, 1),
    );

    expect(historial, hasLength(1));
    expect(historial.single.fechaRegreso, isNull);
    expect(historial.single.nota, isNull);
  });

  test('seguir egresado no duplica el historial', () {
    final original = _perro(estado: 'egresado', historialEgresos: [egresoPrevio]);
    final historial = PerroController.calcularHistorialEgresos(
      original: original,
      estadoNuevo: 'egresado',
      motivo: 'familia',
      fechaEgreso: DateTime(2026, 8, 8),
    );

    expect(historial, hasLength(1));
    expect(historial.single, same(egresoPrevio));
    expect(original.historialEgresos, hasLength(1));
    expect(identical(historial, original.historialEgresos), isFalse);
  });

  test('un egreso previo, vuelve a egresar y luego regresa, deja dos entradas', () {
    final original = _perro(
      estado: 'activo',
      historialEgresos: [egresoPrevio],
    );
    final alEgresar = PerroController.calcularHistorialEgresos(
      original: original,
      estadoNuevo: 'egresado',
      motivo: 'familia',
    );
    expect(alEgresar, hasLength(1));

    final egresado = _perro(
      estado: 'egresado',
      historialEgresos: alEgresar,
      motivoEgreso: 'familia',
      fechaEgreso: DateTime(2026, 9, 1),
      notaEgreso: 'Segunda vez',
    );
    final alRegresar = PerroController.calcularHistorialEgresos(
      original: egresado,
      estadoNuevo: 'activo',
      motivo: 'familia',
      fechaEgreso: DateTime(2026, 9, 1),
      nota: 'Segunda vez',
      fechaRegreso: DateTime(2026, 9, 20),
    );

    expect(alRegresar, hasLength(2));
    expect(alRegresar.first, same(egresoPrevio));
    expect(alRegresar.last.motivo, 'familia');
    expect(alRegresar.last.fechaRegreso, DateTime(2026, 9, 20));
    expect(egresado.historialEgresos, hasLength(1));
  });
}
