import 'package:fichas_refugio/controllers/tratamiento_controller.dart';
import 'package:fichas_refugio/models/tratamiento_model.dart';
import 'package:flutter_test/flutter_test.dart';

TratamientoModel _diario({
  required int dias,
  required DateTime inicio,
  List<String> registroDosis = const [],
  bool conservarDosisFuera = false,
}) {
  return TratamientoModel(
    id: 't',
    categoria: 'diario',
    medicacion: 'Tratamiento prueba',
    indicaciones: '1 comprimido',
    fechaInicio: inicio,
    diasDuracion: dias,
    registroDosis: registroDosis,
    conservarDosisFuera: conservarDosisFuera,
  );
}

void main() {
  final inicio = DateTime(2026, 10, 19);
  const dosis = ['2026-10-19', '2026-10-31'];
  final controller = TratamientoController();

  TratamientoModel editado() {
    return controller.editarTratamiento(
      _diario(dias: 4, inicio: inicio, registroDosis: dosis),
      medicacion: 'Tratamiento prueba',
      indicaciones: 'con comida',
      diasDuracion: 4,
      fechaInicio: inicio,
      horaRecordatorio: '09:00',
    );
  }

  test('editar deja detectadas las dosis fuera de período', () {
    final fuera = TratamientoController.dosisFueraDePeriodo(editado());

    expect(fuera, ['2026-10-31']);
  });

  test('si la persona borra, se eliminan las dosis fuera de período', () {
    final resultado = TratamientoController.resolverDosisFueraDePeriodo(editado(), borrar: true);

    expect(resultado.registroDosis, ['2026-10-19']);
    expect(resultado.conservarDosisFuera, isFalse);
  });

  test('si la persona no borra, se conservan las dosis fuera de período', () {
    final resultado = TratamientoController.resolverDosisFueraDePeriodo(editado(), borrar: false);

    expect(resultado.registroDosis, dosis);
    expect(resultado.conservarDosisFuera, isTrue);
  });

  test('el historial de un diario con duración fija muestra el período', () {
    final historial = controller.construirHistorialLista([
      _diario(dias: 4, inicio: inicio, registroDosis: dosis),
    ]);

    expect(historial.single.fechaInicio, DateTime(2026, 10, 19));
    expect(historial.single.fechaFin, DateTime(2026, 10, 22));
  });

  test('un diario indefinido mantiene el rango de dosis', () {
    final historial = controller.construirHistorialLista([
      _diario(dias: 0, inicio: inicio, registroDosis: const ['2026-10-15', '2026-10-31']),
    ]);

    expect(historial.single.fechaInicio, DateTime(2026, 10, 15));
    expect(historial.single.fechaFin, DateTime(2026, 10, 31));
  });

  test('el calendario omite una dosis fuera de período salvo que se conserve', () {
    final tratamiento = _diario(dias: 4, inicio: inicio, registroDosis: dosis);
    final oculto = controller.construirEventosCalendario([tratamiento]);
    final visible = controller.construirEventosCalendario([
      tratamiento.copyWith(conservarDosisFuera: true),
    ]);

    expect(oculto[DateTime.utc(2026, 10, 19)]!.single['medicacion'], 'Tratamiento prueba');
    expect(oculto[DateTime.utc(2026, 10, 31)], isNull);
    expect(visible[DateTime.utc(2026, 10, 31)]!.single['medicacion'], 'Tratamiento prueba');
  });
}
