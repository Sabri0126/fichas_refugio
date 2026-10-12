import 'package:fichas_refugio/controllers/perro_controller.dart';
import 'package:fichas_refugio/models/egreso_model.dart';
import 'package:fichas_refugio/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

EgresoModel _egreso(String motivo, DateTime fecha) {
  return EgresoModel(motivo: motivo, fechaEgreso: fecha, nota: motivo);
}

void main() {
  final primero = _egreso('adopcion', DateTime(2026, 1, 10));
  final segundo = _egreso('familia', DateTime(2026, 3, 2));
  final nuevo = _egreso('adopcion', DateTime(2026, 4, 4));

  test('reemplazarEgreso no muta la lista y conserva el orden', () {
    final lista = [primero, segundo];
    final resultado = PerroController.reemplazarEgreso(lista, 1, nuevo);

    expect(lista, [primero, segundo]);
    expect(identical(resultado[0], primero), isTrue);
    expect(identical(resultado[1], nuevo), isTrue);
    expect(resultado, hasLength(2));
  });

  test('quitarEgreso no muta la lista y conserva el orden', () {
    final lista = [primero, segundo];
    final resultado = PerroController.quitarEgreso(lista, 0);

    expect(lista, [primero, segundo]);
    expect(resultado, [segundo]);
    expect(identical(resultado.single, segundo), isTrue);
  });

  test('un índice fuera de rango lanza RangeError', () {
    final lista = [primero];
    expect(() => PerroController.reemplazarEgreso(lista, 1, nuevo), throwsRangeError);
    expect(() => PerroController.reemplazarEgreso(lista, -1, nuevo), throwsRangeError);
    expect(() => PerroController.quitarEgreso(lista, 3), throwsRangeError);
    expect(lista, [primero]);
  });

  test('validarEgreso rechaza un regreso anterior al egreso', () {
    final hoy = DateTime.now();
    final egreso = DateTime(hoy.year, hoy.month, hoy.day);
    final resultado = PerroController.validarEgreso(
      EgresoModel(fechaEgreso: egreso, fechaRegreso: egreso.subtract(const Duration(days: 1))),
    );
    expect(resultado, 'La fecha de regreso no puede ser anterior a la de egreso.');
  });

  test('validarEgreso rechaza un egreso futuro', () {
    final manana = DateTime.now().add(const Duration(days: 2));
    final resultado = PerroController.validarEgreso(EgresoModel(fechaEgreso: manana));
    expect(resultado, 'La fecha de egreso no puede ser futura.');
  });

  test('validarEgreso acepta un egreso pasado con regreso posterior', () {
    final hoy = DateTime.now();
    final ayer = DateTime(hoy.year, hoy.month, hoy.day).subtract(const Duration(days: 1));
    final resultado = PerroController.validarEgreso(
      EgresoModel(motivo: 'adopcion', fechaEgreso: ayer, fechaRegreso: hoy),
    );
    expect(resultado, isNull);
  });

  test('validarEgreso acepta un egreso sin fecha de regreso', () {
    final ayer = DateTime.now().subtract(const Duration(days: 1));
    final resultado = PerroController.validarEgreso(EgresoModel(fechaEgreso: ayer));
    expect(resultado, isNull);
  });

  testWidgets('la fila no desborda a 360 dp con escala 1.6', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const escala = TextScaler.linear(1.6);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: escala),
            child: child!,
          );
        },
        home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.activoTexto.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.home_rounded, size: 20, color: AppColors.activoTexto),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Volvió con su familia', textScaler: escala),
                            SizedBox(height: 4),
                            Text('Egreso: 02/03/2026', textScaler: escala),
                            SizedBox(height: 2),
                            Text('Regreso: 12/10/2026', textScaler: escala),
                            SizedBox(height: 2),
                            Text(
                              'Nota larga para ver si el texto envuelve junto a los botones de editar y eliminar.',
                              textScaler: escala,
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            tooltip: 'Editar egreso',
                            color: AppColors.textoSecundario,
                            style: const ButtonStyle(visualDensity: VisualDensity.compact),
                            onPressed: () {},
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            tooltip: 'Eliminar egreso',
                            color: AppColors.error,
                            style: const ButtonStyle(visualDensity: VisualDensity.compact),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ),
          ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
