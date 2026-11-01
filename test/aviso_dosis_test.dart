import 'package:fichas_refugio/models/dosis_avisada.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('la caché sin el día no abre el cartel', () {
    const registro = <String>[];
    final marcada = dosisAvisadaMarcada(registro, '2026-10-31');
    expect(marcada, isFalse);
    expect(listoParaAvisoDosis(desdeCache: true, marcada: marcada), isFalse);
  });

  test('el servidor con el día abre la confirmación', () {
    const registro = ['2026-10-31'];
    final marcada = dosisAvisadaMarcada(registro, '2026-10-31');
    expect(marcada, isTrue);
    expect(listoParaAvisoDosis(desdeCache: false, marcada: marcada), isTrue);
  });

  test('el servidor sin el día abre el aviso de pendiente', () {
    const registro = <String>['2026-10-30'];
    final marcada = dosisAvisadaMarcada(registro, '2026-10-31');
    expect(marcada, isFalse);
    expect(listoParaAvisoDosis(desdeCache: false, marcada: marcada), isTrue);
  });

  test('la caché que ya trae el día no espera al servidor', () {
    final marcada = dosisAvisadaMarcada(const ['2026-10-31'], '2026-10-31');
    expect(listoParaAvisoDosis(desdeCache: true, marcada: marcada), isTrue);
  });
}
