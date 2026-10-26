import 'package:fichas_refugio/controllers/reportes_controller.dart';
import 'package:fichas_refugio/models/egreso_model.dart';
import 'package:fichas_refugio/models/perro_model.dart';
import 'package:fichas_refugio/theme/app_theme.dart';
import 'package:fichas_refugio/utils/fundacion_refugio.dart';
import 'package:fichas_refugio/widgets/grafico_poblacion.dart';
import 'package:flutter/material.dart';
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
    expect(junio.reencuentros, 0);
  });

  test('el mes cuenta un reencuentro por su fecha de egreso', () {
    final junio = reporte([
      perro(
        id: 'volvio',
        fechaIngreso: DateTime(2020, 1, 1),
        historial: [
          EgresoModel(
            motivo: 'familia',
            fechaEgreso: DateTime(2026, 6, 4),
            fechaRegreso: DateTime(2026, 8, 1),
          ),
        ],
      ),
      perro(
        id: 'familia-mes',
        estado: 'egresado',
        motivoEgreso: 'familia',
        fechaEgreso: DateTime(2026, 6, 9),
        fechaIngreso: DateTime(2021, 1, 1),
      ),
    ]).mes;

    expect(junio.reencuentros, 2);
  });

  test('la población cierra el año y el año en curso cierra hoy', () {
    final serie = reporte([
      perro(id: 'sigue', fechaIngreso: DateTime(2024, 1, 10)),
      perro(
        id: 'adoptado',
        estado: 'egresado',
        motivoEgreso: 'adopcion',
        fechaIngreso: DateTime(2022, 3, 1),
        fechaEgreso: DateTime(2024, 3, 1),
      ),
      perro(
        id: 'volvio',
        fechaIngreso: DateTime(2020, 5, 1),
        historial: [
          EgresoModel(
            motivo: 'adopcion',
            fechaEgreso: DateTime(2022, 1, 1),
            fechaRegreso: DateTime(2023, 6, 1),
          ),
        ],
      ),
      perro(
        id: 'murio',
        estado: 'inactivo',
        fechaIngreso: DateTime(2019, 2, 1),
        fechaFallecimiento: DateTime(2021, 5, 1),
      ),
      perro(id: 'sin-fecha'),
      perro(id: 'tarde', fechaIngreso: DateTime(2026, 12, 1)),
    ]).serie;

    expect(serie.sinFecha, 1);
    expect(serie.puntos.first.anio, 2019);
    expect(serie.puntos.last.anio, 2026);

    PuntoPoblacion del(int anio) => serie.puntos.firstWhere((punto) => punto.anio == anio);

    expect(del(2019).quedaron, 1);
    expect(del(2019).entraron, 1);
    expect(del(2020).quedaron, 2);
    expect(del(2021).quedaron, 1);
    expect(del(2021).salieron, 1);
    expect(del(2022).quedaron, 1);
    expect(del(2022).entraron, 1);
    expect(del(2022).salieron, 1);
    expect(del(2023).quedaron, 2);
    expect(del(2024).quedaron, 2);
    expect(del(2024).salieron, 1);
    expect(del(2024).quienesEntraron.map((perro) => perro.nombre), ['sigue']);
    expect(del(2024).quienesSalieron.map((perro) => perro.nombre), ['adoptado']);
    expect(del(2024).quienesQuedaron.map((perro) => perro.nombre), ['sigue', 'volvio']);
    expect(del(2026).quedaron, 2);
    expect(del(2026).entraron, 0);
  });

  testWidgets('el gráfico deja escrito el cierre del último año', (tester) async {
    PuntoPoblacion? abierto;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: GraficoPoblacion(
            alVer: (punto) => abierto = punto,
            puntos: [
              PuntoPoblacion(
                anio: 2024,
                quienesEntraron: [
                  PerroAnio(id: 'a', nombre: 'A'),
                  PerroAnio(id: 'b', nombre: 'B'),
                ],
                quienesSalieron: [PerroAnio(id: 'c', nombre: 'C')],
                quienesQuedaron: [
                  PerroAnio(id: 'a', nombre: 'A'),
                  PerroAnio(id: 'b', nombre: 'B'),
                  PerroAnio(id: 'd', nombre: 'D'),
                  PerroAnio(id: 'e', nombre: 'E'),
                ],
              ),
              PuntoPoblacion(
                anio: 2025,
                quienesEntraron: [PerroAnio(id: 'f', nombre: 'F')],
                quienesSalieron: [],
                quienesQuedaron: [
                  PerroAnio(id: 'a', nombre: 'A'),
                  PerroAnio(id: 'b', nombre: 'B'),
                  PerroAnio(id: 'd', nombre: 'D'),
                  PerroAnio(id: 'e', nombre: 'E'),
                  PerroAnio(id: 'f', nombre: 'F'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('2025: Entraron 1 · Salieron 0 · Quedaron 5'), findsOneWidget);
    await tester.tap(find.text('2025: Entraron 1 · Salieron 0 · Quedaron 5'));
    expect(abierto?.anio, 2025);
    expect(abierto?.quienesEntraron.single.nombre, 'F');
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
