import 'package:fichas_refugio/controllers/tratamiento_controller.dart';
import 'package:fichas_refugio/models/tratamiento_model.dart';
import 'package:flutter_test/flutter_test.dart';

const _dosis = ['2026-03-01', '2026-03-02'];

TratamientoModel _diario({
  required int dias,
  required DateTime inicio,
  String indicaciones = '1 comprimido',
}) {
  return TratamientoModel(
    id: 't',
    categoria: 'diario',
    medicacion: 'Doxiciclina',
    indicaciones: indicaciones,
    fechaInicio: inicio,
    diasDuracion: dias,
    activo: false,
    registroDosis: _dosis,
  );
}

void main() {
  final inicio = DateTime(2026, 3, 1);
  final controller = TratamientoController();

  TratamientoModel editar(
    TratamientoModel actual, {
    int? dias,
    String? indicaciones,
  }) {
    return controller.editarTratamiento(
      actual,
      medicacion: actual.medicacion,
      indicaciones: indicaciones ?? actual.indicaciones,
      diasDuracion: dias ?? actual.diasDuracion,
      fechaInicio: actual.fechaInicio!,
      horaRecordatorio: actual.horaRecordatorio ?? '09:00',
    );
  }

  TratamientoModel resolver(TratamientoModel original, TratamientoModel editado, DateTime hoy) {
    return TratamientoController.resolverActivoTrasEditar(original, editado, hoy: hoy);
  }

  test('un tratamiento terminado al que se le agregan días queda activo', () {
    final original = _diario(dias: 30, inicio: inicio);
    final resultado = resolver(original, editar(original, dias: 60), DateTime(2026, 4, 15));

    expect(resultado.activo, isTrue);
    expect(resultado.diasDuracion, 60);
  });

  test('un tratamiento terminado editado sin agregar días sigue pausado', () {
    final original = _diario(dias: 30, inicio: inicio);
    final resultado = resolver(
      original,
      editar(original, indicaciones: '2 comprimidos'),
      DateTime(2026, 4, 15),
    );

    expect(resultado.activo, isFalse);
    expect(resultado.indicaciones, '2 comprimidos');
    expect(resultado.diasDuracion, 30);
  });

  test('un tratamiento pausado a mano y no terminado sigue pausado después de editar', () {
    final original = _diario(dias: 30, inicio: inicio);
    final resultado = resolver(
      original,
      editar(original, indicaciones: 'con comida'),
      DateTime(2026, 3, 10),
    );

    expect(resultado.activo, isFalse);
    expect(resultado.indicaciones, 'con comida');
  });

  test('se conserva registroDosis', () {
    final terminado = _diario(dias: 30, inicio: inicio);
    final reactivado = resolver(terminado, editar(terminado, dias: 60), DateTime(2026, 4, 15));
    final enCurso = resolver(
      terminado,
      editar(terminado, indicaciones: 'con comida'),
      DateTime(2026, 3, 10),
    );

    expect(reactivado.registroDosis, _dosis);
    expect(enCurso.registroDosis, _dosis);
  });
}
