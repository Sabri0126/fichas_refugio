import 'package:fichas_refugio/models/tratamiento_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sin el campo notificar el diario sigue avisando', () {
    final diario = TratamientoModel.fromMap({
      'categoria': 'diario',
      'medicacion': 'Comida',
      'activo': true,
    }, 'd1');

    expect(diario.notificar, isTrue);
    expect(diario.toMap()['notificar'], isTrue);
  });

  test('notificar false se lee y se escribe', () {
    final diario = TratamientoModel.fromMap({
      'categoria': 'diario',
      'medicacion': 'Paseo',
      'notificar': false,
      'activo': true,
    }, 'd2');

    expect(diario.notificar, isFalse);
    expect(diario.toMap()['notificar'], isFalse);
    expect(diario.copyWith(notificar: true).toMap()['notificar'], isTrue);
  });
}
