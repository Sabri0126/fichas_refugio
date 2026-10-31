import 'package:fichas_refugio/controllers/tratamiento_controller.dart';
import 'package:fichas_refugio/models/estado_duracion.dart';
import 'package:fichas_refugio/models/tratamiento_model.dart';
import 'package:flutter_test/flutter_test.dart';

TratamientoModel diario({
  required String id,
  required String medicacion,
  required DateTime inicio,
  String indicaciones = '1 comprimido',
  int dias = 0,
  String? tipo,
  bool activo = true,
  DateTime? suspension,
  List<String> dosis = const [],
  List<CambioDosis> cambios = const [],
}) {
  return TratamientoModel(
    id: id,
    categoria: 'diario',
    medicacion: medicacion,
    indicaciones: indicaciones,
    fechaInicio: inicio,
    diasDuracion: dias,
    tipoDuracion: tipo,
    activo: activo,
    fechaSuspension: suspension,
    registroDosis: dosis,
    cambiosDosis: cambios,
  );
}

void main() {
  final controller = TratamientoController();

  test('sin tipo guardado se deduce de los días', () {
    final fijo = TratamientoModel.fromMap({
      'categoria': 'diario',
      'dias_duracion': 10,
      'activo': true,
    }, 'fijo');
    final abierto = TratamientoModel.fromMap({
      'categoria': 'diario',
      'dias_duracion': 0,
      'activo': true,
    }, 'abierto');

    expect(fijo.tipoDuracion, TratamientoModel.tipoDias);
    expect(abierto.tipoDuracion, TratamientoModel.tipoHastaAviso);
    expect(abierto.fechaSuspension, isNull);
    expect(abierto.cambiosDosis, isEmpty);
  });

  test('suspender cierra el período y el historial cuenta solo esas dosis', () {
    final actrin = diario(
      id: 'actrin',
      medicacion: 'Actrin',
      inicio: DateTime(2026, 10, 19),
      tipo: TratamientoModel.tipoHastaAviso,
      dosis: const ['2026-10-19', '2026-10-31', '2026-11-01'],
    );

    expect(TratamientoController.contarDosisPosteriores(actrin, DateTime(2026, 10, 31)), 1);

    final suspendido = TratamientoController.suspender(actrin, ultimoDia: DateTime(2026, 10, 31));
    expect(suspendido.activo, isFalse);
    expect(suspendido.fechaSuspension, DateTime(2026, 10, 31));
    expect(suspendido.registroDosis, ['2026-10-19', '2026-10-31']);

    final historial = controller.construirHistorialLista([suspendido]);
    expect(historial.single.fechaInicio, DateTime(2026, 10, 19));
    expect(historial.single.fechaFin, DateTime(2026, 10, 31));
    expect(historial.single.cantidadDosis, 2);
    expect(
      TratamientoController.etiquetaEstado(suspendido, hoy: DateTime(2026, 11, 2)),
      'Suspendido el 31/10',
    );
  });

  test('una dosis posterior a la suspensión no cuenta', () {
    final suspendido = diario(
      id: 'actrin',
      medicacion: 'Actrin',
      inicio: DateTime(2026, 10, 19),
      tipo: TratamientoModel.tipoHastaAviso,
      activo: false,
      suspension: DateTime(2026, 10, 31),
      dosis: const ['2026-10-19', '2026-10-31', '2026-11-01'],
    );

    expect(TratamientoController.dosisFueraDePeriodo(suspendido), ['2026-11-01']);
    expect(TratamientoController.contarDosisEnPeriodo(suspendido), 2);
    expect(TratamientoController.diaDentroDePeriodo(suspendido, DateTime(2026, 11, 1)), isFalse);
  });

  test('un tratamiento de días suspendido antes no queda como si hubiera terminado', () {
    final fijo = diario(
      id: 'corto',
      medicacion: 'Antibiótico',
      inicio: DateTime(2026, 10, 1),
      dias: 10,
      tipo: TratamientoModel.tipoDias,
      dosis: const ['2026-10-01', '2026-10-03', '2026-10-08'],
    );

    final suspendido = TratamientoController.suspender(fijo, ultimoDia: DateTime(2026, 10, 3));
    final historial = controller.construirHistorialLista([suspendido]);

    expect(historial.single.fechaInicio, DateTime(2026, 10, 1));
    expect(historial.single.fechaFin, DateTime(2026, 10, 3));
    expect(historial.single.cantidadDosis, 2);
    expect(suspendido.registroDosis, ['2026-10-01', '2026-10-03']);
    expect(
      TratamientoController.etiquetaEstado(suspendido, hoy: DateTime(2026, 10, 20)),
      'Suspendido el 03/10',
    );
  });

  test('reanudar crea un tratamiento nuevo y deja el anterior cerrado', () {
    final anterior = diario(
      id: 'viejo',
      medicacion: 'Actrin',
      inicio: DateTime(2026, 10, 19),
      tipo: TratamientoModel.tipoHastaAviso,
      activo: false,
      suspension: DateTime(2026, 10, 31),
      dosis: const ['2026-10-19'],
      indicaciones: '1 pastilla',
    );

    final nuevo = controller.reanudarComoNuevo(
      anterior,
      hoy: DateTime(2026, 12, 1),
      id: 'nuevo',
    );

    expect(nuevo.id, 'nuevo');
    expect(nuevo.fechaInicio, DateTime(2026, 12, 1));
    expect(nuevo.registroDosis, isEmpty);
    expect(nuevo.activo, isTrue);
    expect(nuevo.medicacion, 'Actrin');
    expect(nuevo.indicaciones, '1 pastilla');
    expect(nuevo.tipoDuracion, TratamientoModel.tipoHastaAviso);
    expect(anterior.fechaSuspension, DateTime(2026, 10, 31));
    expect(anterior.registroDosis, ['2026-10-19']);
  });

  test('un indefinido viejo sin fecha se cierra en la última dosis al reanudar', () {
    final viejo = diario(
      id: 'viejo',
      medicacion: 'Actrin',
      inicio: DateTime(2026, 10, 1),
      activo: false,
      dosis: const ['2026-10-01', '2026-10-05'],
    );

    final cerrado = TratamientoController.cerrarPeriodoLegacy(viejo);
    expect(cerrado.fechaSuspension, DateTime(2026, 10, 5));
    expect(viejo.fechaSuspension, isNull);
  });

  test('cambiar la dosis deja la anterior en el día que corresponde', () {
    final nala = diario(
      id: 'nala',
      medicacion: 'Fenobarbital',
      inicio: DateTime(2024, 3, 2),
      tipo: TratamientoModel.tipoDePorVida,
      indicaciones: '1/4 pastilla',
    );

    final cambiado = TratamientoController.cambiarDosis(
      nala,
      '1/2 pastilla',
      desde: DateTime(2026, 9, 15),
    );

    expect(cambiado.indicaciones, '1/2 pastilla');
    expect(cambiado.cambiosDosis.map((c) => c.indicaciones), ['1/4 pastilla', '1/2 pastilla']);
    expect(TratamientoController.dosisVigenteEn(cambiado, DateTime(2026, 9, 14)), '1/4 pastilla');
    expect(TratamientoController.dosisVigenteEn(cambiado, DateTime(2026, 9, 15)), '1/2 pastilla');
    expect(TratamientoController.dosisVigenteEn(nala, DateTime(2026, 9, 15)), '1/4 pastilla');
  });

  test('el historial de por vida no cuenta dosis', () {
    final nala = diario(
      id: 'nala',
      medicacion: 'Fenobarbital',
      inicio: DateTime(2024, 3, 2),
      tipo: TratamientoModel.tipoDePorVida,
      dosis: const ['2024-03-02', '2026-10-31'],
    );

    final historial = controller.construirHistorialLista([nala]);
    expect(historial.single.cuentaDosis, isFalse);
    expect(historial.single.fechaInicio, DateTime(2024, 3, 2));
    expect(historial.single.fechaFin, isNull);
    expect(TratamientoController.etiquetaDuracion(nala), 'De por vida');
  });

  test('un indefinido con inicio futuro está programado', () {
    final futuro = diario(
      id: 'futuro',
      medicacion: 'Actrin',
      inicio: DateTime(2026, 12, 1),
      tipo: TratamientoModel.tipoHastaAviso,
    );
    final hoy = DateTime(2026, 11, 1);

    expect(
      TratamientoController.calcularEstadoDuracion(futuro, hoy: hoy).fase,
      FaseTratamiento.noIniciado,
    );
    expect(TratamientoController.etiquetaEstado(futuro, hoy: hoy), 'Programado');
  });
}
