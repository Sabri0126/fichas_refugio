import 'package:fichas_refugio/controllers/reportes_controller.dart';
import 'package:fichas_refugio/models/egreso_model.dart';
import 'package:fichas_refugio/models/perro_model.dart';
import 'package:fichas_refugio/utils/fundacion_refugio.dart';
import 'package:flutter_test/flutter_test.dart';

final hoy = DateTime(2026, 6, 15);

PerroModel perro({
  required String id,
  String estado = 'activo',
  bool enCasa = false,
  DateTime? fechaIngreso,
  DateTime? fechaFallecimiento,
  DateTime? fechaEgreso,
  String? motivoEgreso,
  List<EgresoModel> historial = const [],
}) {
  return PerroModel(
    id: id,
    nombre: id,
    estado: estado,
    enCasa: enCasa,
    fechaIngreso: fechaIngreso,
    fechaFallecimiento: fechaFallecimiento,
    fechaEgreso: fechaEgreso,
    motivoEgreso: motivoEgreso,
    historialEgresos: historial,
  );
}

ReporteRefugio reporte(List<PerroModel> perros, {DateTime? mes}) {
  return ReportesController.calcular(perros, hoy: hoy, mes: mes ?? DateTime(2026, 6));
}

void main() {
  test('separa en casa y en el refugio', () {
    final actual = reporte([
      perro(id: 'a', enCasa: true),
      perro(id: 'b'),
      perro(id: 'c', estado: 'egresado', enCasa: true),
    ]).poblacion;

    expect(actual.activos, 2);
    expect(actual.enCasa, 1);
    expect(actual.enRefugio, 1);
  });

  test('el promedio ignora sin fecha y fechas futuras', () {
    final estadia = reporte([
      perro(id: 'con', fechaIngreso: DateTime(2024, 6, 15)),
      perro(id: 'sin'),
      perro(id: 'futura', fechaIngreso: DateTime(2027, 1, 1)),
    ]).estadia;

    expect(estadia.conFecha, 1);
    expect(estadia.sinFecha, 1);
    expect(estadia.mesesPromedio, 24);
    expect(estadia.residentes, 0);
  });

  test('más de 5 años no incluye al que cumple justo hoy', () {
    final estadia = reporte([
      perro(id: 'justo', fechaIngreso: DateTime(2021, 6, 15)),
      perro(id: 'antes', fechaIngreso: DateTime(2021, 6, 14)),
    ]).estadia;

    expect(estadia.conFecha, 2);
    expect(estadia.residentes, 1);
  });

  test('una adopción que volvió sigue en el histórico y en la población', () {
    final resultado = reporte([
      perro(
        id: 'volvio',
        historial: [
          EgresoModel(motivo: 'adopcion', fechaEgreso: DateTime(2024, 3, 2)),
        ],
      ),
      perro(
        id: 'familia',
        estado: 'egresado',
        motivoEgreso: 'familia',
        fechaEgreso: DateTime(2026, 6, 1),
      ),
      perro(id: 'memoria', estado: 'inactivo', fechaFallecimiento: DateTime(2020, 1, 1)),
    ]);

    expect(resultado.poblacion.activos, 1);
    expect(resultado.balance.adoptados, 1);
    expect(resultado.balance.reencontrados, 1);
    expect(resultado.balance.difuntos, 1);
  });

  test('el mes cuenta bordes y no suma lo que no tiene fecha', () {
    final junio = reporte([
      perro(id: 'fin', fechaIngreso: DateTime(2026, 6, 30)),
      perro(id: 'julio', fechaIngreso: DateTime(2026, 7, 1)),
      perro(id: 'sin-ingreso'),
      perro(
        id: 'adopcion-mes',
        estado: 'egresado',
        motivoEgreso: 'adopcion',
        fechaEgreso: DateTime(2026, 6, 2),
      ),
      perro(
        id: 'adopcion-vieja',
        historial: [
          EgresoModel(motivo: 'adopcion', fechaEgreso: DateTime(2025, 6, 2)),
        ],
      ),
      perro(
        id: 'adopcion-sin-fecha',
        estado: 'egresado',
        motivoEgreso: 'adopcion',
      ),
      perro(id: 'deceso', estado: 'inactivo', fechaFallecimiento: DateTime(2026, 6, 10)),
      perro(id: 'deceso-sin', estado: 'inactivo'),
    ], mes: DateTime(2026, 6)).mes;

    expect(junio.ingresos, 1);
    expect(junio.adopciones, 1);
    expect(junio.fallecimientos, 1);
  });

  test('50 meses se leen como 4 años y 2 meses', () {
    expect(ReportesController.textoMeses(50), '4 años y 2 meses');
    expect(ReportesController.textoMeses(1), '1 mes');
    expect(ReportesController.textoMeses(12), '1 año');
  });

  test('los años de servicio se cumplen el 29 de abril', () {
    expect(calcularAniosServicio(DateTime(2000, 4, 29)), 0);
    expect(calcularAniosServicio(DateTime(2026, 4, 28)), 25);
    expect(calcularAniosServicio(DateTime(2026, 4, 29)), 26);
    expect(textoAniosCuidando(26), '26 años cuidando perritos');
    expect(textoAniosCuidando(1), '1 año cuidando perritos');
  });
}
