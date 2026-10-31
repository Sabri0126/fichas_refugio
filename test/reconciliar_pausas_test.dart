import 'package:fichas_refugio/controllers/tratamiento_controller.dart';
import 'package:fichas_refugio/models/tratamiento_model.dart';
import 'package:flutter_test/flutter_test.dart';

TratamientoModel _tratamiento({
  required String id,
  String categoria = 'diario',
  bool activo = true,
}) {
  return TratamientoModel(
    id: id,
    categoria: categoria,
    medicacion: 'Doxiciclina',
    indicaciones: '1 comprimido',
    activo: activo,
  );
}

void main() {
  test('pausado en el servidor y activo en el formulario queda pausado', () {
    final resultado = TratamientoController.reconciliarPausas(
      [_tratamiento(id: 'doxi', activo: true)],
      [_tratamiento(id: 'doxi', activo: false)],
      {},
    );

    expect(resultado, hasLength(1));
    expect(resultado.single.activo, isFalse);
    expect(resultado.single.medicacion, 'Doxiciclina');
  });

  test('reanudado a mano queda activo aunque el servidor lo tenga pausado', () {
    final resultado = TratamientoController.reconciliarPausas(
      [_tratamiento(id: 'doxi', activo: true)],
      [_tratamiento(id: 'doxi', activo: false)],
      {'doxi'},
    );

    expect(resultado.single.activo, isTrue);
  });

  test('pausado en la base y reactivado por edición queda activo', () {
    final resultado = TratamientoController.reconciliarPausas(
      [_tratamiento(id: 'doxi', activo: true)],
      [_tratamiento(id: 'doxi', activo: false)],
      {'doxi'},
    );

    expect(resultado.single.activo, isTrue);
  });

  test('un id que no está en el servidor no cambia', () {
    final local = _tratamiento(id: 'nuevo', activo: true);
    final resultado = TratamientoController.reconciliarPausas(
      [local],
      [_tratamiento(id: 'otro', activo: false)],
      {},
    );

    expect(resultado.single.activo, isTrue);
    expect(identical(resultado.single, local), isTrue);
  });

  test('si el servidor lo tiene activo no cambia', () {
    final local = _tratamiento(id: 'doxi', activo: true);
    final resultado = TratamientoController.reconciliarPausas(
      [local],
      [_tratamiento(id: 'doxi', activo: true)],
      {},
    );

    expect(resultado.single.activo, isTrue);
    expect(identical(resultado.single, local), isTrue);
  });
}
