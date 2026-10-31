import 'package:fichas_refugio/controllers/calendario_general_controller.dart';
import 'package:fichas_refugio/controllers/tratamiento_controller.dart';
import 'package:fichas_refugio/models/perro_model.dart';
import 'package:fichas_refugio/models/tratamiento_model.dart';
import 'package:flutter_test/flutter_test.dart';

TratamientoModel _diario({
  required int dias,
  required DateTime inicio,
  List<String> registroDosis = const [],
}) {
  return TratamientoModel(
    id: 't',
    categoria: 'diario',
    medicacion: 'Tratamiento prueba',
    indicaciones: '1 comprimido',
    fechaInicio: inicio,
    diasDuracion: dias,
    registroDosis: registroDosis,
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
    expect(TratamientoController.dosisFueraDePeriodo(editado()), ['2026-10-31']);
  });

  test('no se puede registrar una dosis fuera del período', () {
    final tratamiento = _diario(dias: 4, inicio: inicio, registroDosis: const ['2026-10-19']);

    expect(TratamientoController.diaDentroDePeriodo(tratamiento, DateTime(2026, 10, 22)), isTrue);
    expect(TratamientoController.diaDentroDePeriodo(tratamiento, DateTime(2026, 10, 31)), isFalse);

    final afuera = controller.alternarDosis(tratamiento, DateTime(2026, 10, 31), true);
    expect(afuera.registroDosis, ['2026-10-19']);

    final adentro = controller.alternarDosis(tratamiento, DateTime(2026, 10, 20), true);
    expect(adentro.registroDosis, ['2026-10-19', '2026-10-20']);
  });

  test('quitar las dosis fuera de período las elimina', () {
    final resultado = TratamientoController.quitarDosisFueraDePeriodo(editado());

    expect(resultado.registroDosis, ['2026-10-19']);
  });

  test('sin confirmación no se borran las dosis fuera de período', () {
    final tratamientos = [editado()];

    expect(TratamientoController.cantidadDosisFueraDePeriodo(tratamientos), 1);

    final conservadas = TratamientoController.limpiarDosisFueraDePeriodo(
      tratamientos,
      borrar: false,
    );
    expect(identical(conservadas, tratamientos), isTrue);
    expect(conservadas.single.registroDosis, dosis);

    final borradas = TratamientoController.limpiarDosisFueraDePeriodo(
      tratamientos,
      borrar: true,
    );
    expect(borradas.single.registroDosis, ['2026-10-19']);
  });

  test('el historial de un diario con duración fija muestra el período y cuenta solo sus dosis', () {
    final historial = controller.construirHistorialLista([
      _diario(dias: 4, inicio: inicio, registroDosis: dosis),
    ]);

    expect(historial.single.fechaInicio, DateTime(2026, 10, 19));
    expect(historial.single.fechaFin, DateTime(2026, 10, 22));
    expect(historial.single.cantidadDosis, 1);
  });

  test('un diario indefinido mantiene el rango de dosis', () {
    final historial = controller.construirHistorialLista([
      _diario(dias: 0, inicio: inicio, registroDosis: const ['2026-10-15', '2026-10-31']),
    ]);

    expect(historial.single.fechaInicio, DateTime(2026, 10, 15));
    expect(historial.single.fechaFin, DateTime(2026, 10, 31));
    expect(historial.single.cantidadDosis, 2);
  });

  test('el calendario del historial omite una dosis fuera de período', () {
    final eventos = controller.construirEventosCalendario([
      _diario(dias: 4, inicio: inicio, registroDosis: dosis),
    ]);

    expect(eventos[DateTime.utc(2026, 10, 19)]!.single['medicacion'], 'Tratamiento prueba');
    expect(eventos[DateTime.utc(2026, 10, 31)], isNull);
  });

  test('el calendario general no cuenta ni muestra una dosis fuera del período', () {
    final perro = PerroModel(
      id: 'p',
      nombre: 'FichaTest',
      tratamientos: [_diario(dias: 4, inicio: inicio, registroDosis: dosis)],
    );
    final hoy = DateTime(2026, 10, 31);

    final diaFuera = CalendarioGeneralController.construirResumen([perro], hoy, hoy: hoy);
    final diaDentro = CalendarioGeneralController.construirResumen(
      [perro],
      DateTime(2026, 10, 19),
      hoy: hoy,
    );
    final filas = CalendarioGeneralController.construirLista(
      [perro],
      desde: DateTime(2026, 10, 1),
      hasta: hoy,
    );

    expect(diaFuera.dadas, isEmpty);
    expect(diaDentro.dadas, hasLength(1));
    expect(filas.single.cantidadDosis, 1);
    expect(filas.single.fecha, DateTime(2026, 10, 19));
  });
}
