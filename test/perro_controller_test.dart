import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fichas_refugio/controllers/perro_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ahora = DateTime(2026, 10, 28, 15, 4);

  test('el nombre visible gana sobre el email', () {
    final marca = PerroController.marcaEdicion(
      nombreVisible: ' Sabrina ',
      email: 'sabrina@refugio.org',
      ahora: ahora,
    );

    expect(marca['editado_por'], 'Sabrina');
    expect(marca['editado_en'], Timestamp.fromDate(ahora));
  });

  test('sin nombre usa el email', () {
    final marca = PerroController.marcaEdicion(
      nombreVisible: '  ',
      email: ' turno@refugio.org ',
      ahora: ahora,
    );

    expect(marca['editado_por'], 'turno@refugio.org');
    expect(marca['editado_en'], Timestamp.fromDate(ahora));
  });

  test('sin nombre ni email queda Administrador', () {
    final marca = PerroController.marcaEdicion(
      nombreVisible: null,
      email: '',
      ahora: ahora,
    );

    expect(marca['editado_por'], 'Administrador');
    expect(marca['editado_en'], Timestamp.fromDate(ahora));
  });
}
