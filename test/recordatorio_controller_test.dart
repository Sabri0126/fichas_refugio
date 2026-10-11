import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fichas_refugio/controllers/recordatorio_controller.dart';
import 'package:fichas_refugio/models/perro_model.dart';
import 'package:fichas_refugio/models/recordatorio_model.dart';
import 'package:flutter_test/flutter_test.dart';

RecordatorioModel _recordatorio(String id, DateTime fecha) {
  return RecordatorioModel(
    id: id,
    tipo: 'veterinaria',
    titulo: id,
    nota: '',
    fechaHora: fecha,
  );
}

void main() {
  final controller = RecordatorioController();
  final ahora = DateTime(2026, 10, 11, 15, 0);

  test('proximos y vencidos quedan ordenados y partidos', () {
    final lista = [
      _recordatorio('pasado', DateTime(2026, 10, 10, 9, 0)),
      _recordatorio('limite', ahora),
      _recordatorio('tarde', DateTime(2026, 10, 12, 10, 0)),
      _recordatorio('temprano', DateTime(2026, 10, 11, 18, 0)),
    ];

    expect(
      controller.proximos(lista, ahora: ahora).map((r) => r.id),
      ['temprano', 'tarde'],
    );
    expect(
      controller.vencidos(lista, ahora: ahora).map((r) => r.id),
      ['limite', 'pasado'],
    );
  });

  test('esVencido en el límite exacto', () {
    expect(controller.esVencido(_recordatorio('igual', ahora), ahora: ahora), isTrue);
    expect(
      controller.esVencido(
        _recordatorio('despues', ahora.add(const Duration(minutes: 1))),
        ahora: ahora,
      ),
      isFalse,
    );
  });

  test('formatearCuando cubre hoy, mañana y otro mes', () {
    expect(
      controller.formatearCuando(DateTime(2026, 10, 11, 14, 0), ahora: ahora),
      'Hoy 14:00',
    );
    expect(
      controller.formatearCuando(DateTime(2026, 10, 12, 9, 0), ahora: ahora),
      'Mañana 09:00',
    );
    expect(
      controller.formatearCuando(
        DateTime(2026, 11, 1, 9, 0),
        ahora: DateTime(2026, 10, 31, 20, 0),
      ),
      'Mañana 09:00',
    );
    expect(
      controller.formatearCuando(DateTime(2026, 11, 14, 10, 30), ahora: ahora),
      'sáb 14/11 10:30',
    );
    expect(
      controller.formatearCuando(DateTime(2026, 12, 1, 8, 5), ahora: ahora),
      'mar 01/12 08:05',
    );
  });

  test('fromMap tolera entradas inválidas y la ausencia del campo', () {
    final lista = recordatoriosDesdeValor([
      {
        'id': 'ok',
        'tipo': 'veterinaria',
        'titulo': 'Visita',
        'nota': 'Ayuno',
        'fecha_hora': Timestamp.fromDate(DateTime(2026, 11, 14, 10, 30)),
      },
      {
        'id': 'texto',
        'tipo': 'higiene',
        'titulo': 'Baño',
        'fecha_hora': '2026-12-01T08:05:00',
      },
      'no-es-mapa',
      {'id': 'sin-fecha', 'tipo': 'otro', 'titulo': 'X'},
      {
        'id': 'tipo-mal',
        'tipo': 'raro',
        'titulo': 'X',
        'fecha_hora': DateTime(2026, 1, 1, 10),
      },
    ]);

    expect(lista.map((r) => r.id), ['ok', 'texto']);
    expect(lista.first.nota, 'Ayuno');
    expect(lista.first.fechaHora, DateTime(2026, 11, 14, 10, 30));

    final sinCampo = PerroModel.fromMap({'nombre': 'Lola'}, '2');
    expect(sinCampo.recordatorios, isEmpty);

    final guardado = PerroModel(id: '3', nombre: 'Canelo', recordatorios: lista).toMap();
    expect(guardado.containsKey('recordatorios'), isTrue);
    final vacio = PerroModel(id: '4', nombre: 'Canelo').toMap();
    expect(vacio['recordatorios'], isEmpty);

    final copiado = PerroModel(id: '5', nombre: 'Canelo', recordatorios: lista).copyWith(tratamientos: const []);
    expect(copiado.recordatorios.map((r) => r.id), ['ok', 'texto']);
  });
}
