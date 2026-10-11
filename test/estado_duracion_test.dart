import 'package:fichas_refugio/controllers/tratamiento_controller.dart';
import 'package:fichas_refugio/models/estado_duracion.dart';
import 'package:fichas_refugio/models/tratamiento_model.dart';
import 'package:flutter_test/flutter_test.dart';

TratamientoModel _diario({required int dias, DateTime? inicio}) {
  return TratamientoModel(
    id: 't',
    categoria: 'diario',
    medicacion: 'Doxiciclina',
    indicaciones: '1 comprimido',
    fechaInicio: inicio,
    diasDuracion: dias,
    activo: true,
  );
}

void main() {
  final fechaInicio = DateTime(2026, 3, 1);

  EstadoDuracion estado(DateTime hoy, {int dias = 30, DateTime? desde}) {
    return TratamientoController.calcularEstadoDuracion(
      _diario(dias: dias, inicio: desde ?? fechaInicio),
      hoy: hoy,
    );
  }

  test('día 1 de 30 está en curso y faltan 29', () {
    final resultado = estado(DateTime(2026, 3, 1, 22, 30));
    expect(resultado.fase, FaseTratamiento.enCurso);
    expect(resultado.diaActual, 1);
    expect(resultado.restantes, 29);
  });

  test('día 29 faltan 1 y el día 30 es el último', () {
    final dia29 = estado(DateTime(2026, 3, 29));
    expect(dia29.fase, FaseTratamiento.enCurso);
    expect(dia29.diaActual, 29);
    expect(dia29.restantes, 1);

    final dia30 = estado(DateTime(2026, 3, 30));
    expect(dia30.fase, FaseTratamiento.ultimoDia);
    expect(dia30.restantes, 0);
    expect(dia30.ultimoDia, DateTime(2026, 3, 30));
  });

  test('el día 31 está finalizado', () {
    final resultado = estado(DateTime(2026, 3, 31));
    expect(resultado.fase, FaseTratamiento.finalizado);
  });

  test('un solo día empieza y termina el mismo día', () {
    final resultado = estado(DateTime(2026, 5, 4), dias: 1, desde: DateTime(2026, 5, 4, 18));
    expect(resultado.fase, FaseTratamiento.ultimoDia);
    expect(resultado.ultimoDia, DateTime(2026, 5, 4));
  });

  test('duración 0 o sin fecha de inicio es indefinido', () {
    expect(
      TratamientoController.calcularEstadoDuracion(_diario(dias: 0, inicio: fechaInicio)).fase,
      FaseTratamiento.indefinido,
    );
    expect(
      TratamientoController.calcularEstadoDuracion(_diario(dias: 30)).fase,
      FaseTratamiento.indefinido,
    );
  });

  test('un inicio futuro cuenta los días que faltan', () {
    final dentroDe9 = estado(DateTime(2026, 4, 1), desde: DateTime(2026, 4, 10));
    expect(dentroDe9.fase, FaseTratamiento.noIniciado);
    expect(dentroDe9.diasParaInicio, 9);

    final manana = estado(DateTime(2026, 4, 9), desde: DateTime(2026, 4, 10));
    expect(manana.diasParaInicio, 1);
  });

  test('cruza de mes y de año', () {
    final finDeMes = estado(DateTime(2026, 2, 18), desde: DateTime(2026, 1, 20));
    expect(finDeMes.fase, FaseTratamiento.ultimoDia);
    expect(finDeMes.ultimoDia, DateTime(2026, 2, 18));

    final aMitad = estado(DateTime(2026, 1, 31), desde: DateTime(2026, 1, 20));
    expect(aMitad.fase, FaseTratamiento.enCurso);
    expect(aMitad.diaActual, 12);
    expect(aMitad.restantes, 18);

    final finDeAnio = estado(DateTime(2027, 1, 18), desde: DateTime(2026, 12, 20));
    expect(finDeAnio.fase, FaseTratamiento.ultimoDia);
    expect(finDeAnio.ultimoDia, DateTime(2027, 1, 18));

    final pasadoElAnio = estado(DateTime(2027, 1, 19), desde: DateTime(2026, 12, 20));
    expect(pasadoElAnio.fase, FaseTratamiento.finalizado);
  });

  test('autoArchivarVencidos pausa el día 31 y no antes', () {
    final controller = TratamientoController();
    final tratamiento = _diario(dias: 30, inicio: fechaInicio);

    final dia30 = controller.autoArchivarVencidos([tratamiento], ahora: DateTime(2026, 3, 30, 23));
    expect(dia30.single.activo, isTrue);
    expect(controller.huboCambiosDeArchivado([tratamiento], dia30), isFalse);

    final dia31 = controller.autoArchivarVencidos([tratamiento], ahora: DateTime(2026, 3, 31, 8));
    expect(dia31.single.activo, isFalse);
    expect(controller.huboCambiosDeArchivado([tratamiento], dia31), isTrue);
  });
}
