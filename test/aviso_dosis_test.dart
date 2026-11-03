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

  test('la notificación en caché sin el día no abre el cartel de pendiente', () {
    expect(
      cartelAvisoDosis(desdeCache: true, marcada: false, desdeNotificacion: true),
      isNull,
    );
  });

  test('la notificación con el día abre la confirmación', () {
    expect(
      cartelAvisoDosis(desdeCache: false, marcada: true, desdeNotificacion: true),
      CartelAvisoDosis.confirmacion,
    );
    expect(
      cartelAvisoDosis(desdeCache: true, marcada: true, desdeNotificacion: true),
      CartelAvisoDosis.confirmacion,
    );
  });

  test('la notificación que el servidor dejó sin marcar abre el pendiente', () {
    expect(
      cartelAvisoDosis(desdeCache: false, marcada: false, desdeNotificacion: true),
      CartelAvisoDosis.pendiente,
    );
  });

  test('el calendario sin el día y con datos del servidor abre el de pendiente', () {
    expect(
      cartelAvisoDosis(desdeCache: false, marcada: false, desdeNotificacion: false),
      CartelAvisoDosis.pendiente,
    );
  });
}
