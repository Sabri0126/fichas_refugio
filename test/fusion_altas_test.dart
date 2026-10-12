import 'package:fichas_refugio/controllers/recordatorio_controller.dart';
import 'package:fichas_refugio/controllers/tratamiento_controller.dart';
import 'package:fichas_refugio/models/recordatorio_model.dart';
import 'package:fichas_refugio/models/tratamiento_model.dart';
import 'package:flutter_test/flutter_test.dart';

TratamientoModel _tratamiento(String id) {
  return TratamientoModel(
    id: id,
    categoria: 'diario',
    medicacion: id.isEmpty ? 'Sin id' : id,
    indicaciones: '',
  );
}

RecordatorioModel _recordatorio(String id) {
  return RecordatorioModel(
    id: id,
    tipo: 'veterinaria',
    titulo: id.isEmpty ? 'Sin id' : id,
    nota: '',
    fechaHora: DateTime(2026, 10, 12, 9),
  );
}

void main() {
  group('tratamientos', () {
    test('un alta remota nueva se agrega al final', () {
      final local = _tratamiento('local');
      final alta = _tratamiento('nuevo');
      final resultado = TratamientoController.fusionarAltasRemotas(
        local: [local],
        remoto: [alta],
        idsIniciales: {'local'},
      );

      expect(resultado.map((item) => item.id), ['local', 'nuevo']);
      expect(identical(resultado.first, local), isTrue);
      expect(identical(resultado.last, alta), isTrue);
    });

    test('lo borrado en el formulario no reaparece', () {
      final local = _tratamiento('queda');
      final resultado = TratamientoController.fusionarAltasRemotas(
        local: [local],
        remoto: [_tratamiento('borrado'), local],
        idsIniciales: {'queda', 'borrado'},
      );

      expect(resultado.map((item) => item.id), ['queda']);
    });

    test('un ítem que ya está en local no se duplica', () {
      final local = _tratamiento('mismo');
      final resultado = TratamientoController.fusionarAltasRemotas(
        local: [local],
        remoto: [_tratamiento('mismo')],
        idsIniciales: {},
      );

      expect(resultado, hasLength(1));
      expect(identical(resultado.single, local), isTrue);
    });

    test('sin altas remotas la lista queda igual', () {
      final local = _tratamiento('solo');
      final resultado = TratamientoController.fusionarAltasRemotas(
        local: [local],
        remoto: [local],
        idsIniciales: {'solo'},
      );

      expect(resultado, hasLength(1));
      expect(identical(resultado.single, local), isTrue);
    });

    test('un id vacío se ignora', () {
      final local = _tratamiento('local');
      final resultado = TratamientoController.fusionarAltasRemotas(
        local: [local],
        remoto: [_tratamiento('')],
        idsIniciales: {'local'},
      );

      expect(resultado.map((item) => item.id), ['local']);
    });
  });

  group('recordatorios', () {
    test('un alta remota nueva se agrega al final', () {
      final local = _recordatorio('local');
      final alta = _recordatorio('nuevo');
      final resultado = RecordatorioController.fusionarAltasRemotas(
        local: [local],
        remoto: [alta],
        idsIniciales: {'local'},
      );

      expect(resultado.map((item) => item.id), ['local', 'nuevo']);
      expect(identical(resultado.first, local), isTrue);
      expect(identical(resultado.last, alta), isTrue);
    });

    test('lo borrado en el formulario no reaparece', () {
      final local = _recordatorio('queda');
      final resultado = RecordatorioController.fusionarAltasRemotas(
        local: [local],
        remoto: [_recordatorio('borrado'), local],
        idsIniciales: {'queda', 'borrado'},
      );

      expect(resultado.map((item) => item.id), ['queda']);
    });

    test('un ítem que ya está en local no se duplica', () {
      final local = _recordatorio('mismo');
      final resultado = RecordatorioController.fusionarAltasRemotas(
        local: [local],
        remoto: [_recordatorio('mismo')],
        idsIniciales: {},
      );

      expect(resultado, hasLength(1));
      expect(identical(resultado.single, local), isTrue);
    });

    test('sin altas remotas la lista queda igual', () {
      final local = _recordatorio('solo');
      final resultado = RecordatorioController.fusionarAltasRemotas(
        local: [local],
        remoto: [local],
        idsIniciales: {'solo'},
      );

      expect(resultado, hasLength(1));
      expect(identical(resultado.single, local), isTrue);
    });

    test('un id vacío se ignora', () {
      final local = _recordatorio('local');
      final resultado = RecordatorioController.fusionarAltasRemotas(
        local: [local],
        remoto: [_recordatorio('')],
        idsIniciales: {'local'},
      );

      expect(resultado.map((item) => item.id), ['local']);
    });
  });
}
