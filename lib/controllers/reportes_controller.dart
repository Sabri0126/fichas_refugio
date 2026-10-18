import '../models/perro_model.dart';

/// Foto de hoy: quién está a cargo del refugio.
class PoblacionActual {
  final int activos;
  final int enCasa;
  final int enRefugio;

  const PoblacionActual({
    required this.activos,
    required this.enCasa,
    required this.enRefugio,
  });
}

/// Adopciones, reencuentros y decesos acumulados, incluidos los que volvieron.
class BalanceHistorico {
  final int adoptados;
  final int reencontrados;
  final int difuntos;

  const BalanceHistorico({
    required this.adoptados,
    required this.reencontrados,
    required this.difuntos,
  });
}

/// Estadía de los activos. [mesesPromedio] es null si nadie tiene fecha usable.
class LargaEstadia {
  final int? mesesPromedio;
  final int conFecha;
  final int sinFecha;
  final int residentes;

  const LargaEstadia({
    required this.mesesPromedio,
    required this.conFecha,
    required this.sinFecha,
    required this.residentes,
  });
}

/// Movimiento de un mes calendario.
class RendimientoMes {
  final int ingresos;
  final int adopciones;
  final int fallecimientos;

  const RendimientoMes({
    required this.ingresos,
    required this.adopciones,
    required this.fallecimientos,
  });
}

/// Los cuatro bloques de la pantalla de reportes.
class ReporteRefugio {
  final PoblacionActual poblacion;
  final BalanceHistorico balance;
  final LargaEstadia estadia;
  final RendimientoMes mes;

  const ReporteRefugio({
    required this.poblacion,
    required this.balance,
    required this.estadia,
    required this.mes,
  });
}

/// Métricas en memoria. No lee Firebase.
abstract final class ReportesController {
  static ReporteRefugio calcular(
    List<PerroModel> perros, {
    required DateTime hoy,
    required DateTime mes,
  }) {
    final dia = _solo(hoy);
    final corte = _haceAnios(dia, 5);
    final activos = [for (final perro in perros) if (perro.estado == 'activo') perro];
    final enCasa = activos.where((perro) => perro.enCasa).length;

    var conFecha = 0;
    var sinFecha = 0;
    var residentes = 0;
    var sumaMeses = 0;
    for (final perro in activos) {
      final ingreso = perro.fechaIngreso;
      if (ingreso == null) {
        sinFecha++;
        continue;
      }
      final inicio = _solo(ingreso);
      if (inicio.isAfter(dia)) continue;
      conFecha++;
      sumaMeses += _mesesEnteros(inicio, dia);
      if (inicio.isBefore(corte)) residentes++;
    }

    return ReporteRefugio(
      poblacion: PoblacionActual(
        activos: activos.length,
        enCasa: enCasa,
        enRefugio: activos.length - enCasa,
      ),
      balance: BalanceHistorico(
        adoptados: _egresos(perros, 'adopcion'),
        reencontrados: _egresos(perros, 'familia'),
        difuntos: perros.where((perro) => perro.estado == 'inactivo').length,
      ),
      estadia: LargaEstadia(
        mesesPromedio: conFecha == 0 ? null : (sumaMeses / conFecha).round(),
        conFecha: conFecha,
        sinFecha: sinFecha,
        residentes: residentes,
      ),
      mes: RendimientoMes(
        ingresos: perros.where((perro) => _enMes(perro.fechaIngreso, mes)).length,
        adopciones: _adopcionesDelMes(perros, mes),
        fallecimientos: perros.where((perro) {
          return perro.estado == 'inactivo' && _enMes(perro.fechaFallecimiento, mes);
        }).length,
      ),
    );
  }

  /// 50 meses se lee «4 años y 2 meses».
  static String textoMeses(int meses) {
    final anios = meses ~/ 12;
    final resto = meses % 12;
    if (anios == 0) return resto == 1 ? '1 mes' : '$resto meses';
    if (resto == 0) return anios == 1 ? '1 año' : '$anios años';
    final anio = anios == 1 ? '1 año' : '$anios años';
    final mes = resto == 1 ? '1 mes' : '$resto meses';
    return '$anio y $mes';
  }

  static int _egresos(List<PerroModel> perros, String motivo) {
    var total = 0;
    for (final perro in perros) {
      if (perro.estado == 'egresado' && perro.motivoEgreso == motivo) total++;
      for (final egreso in perro.historialEgresos) {
        if (egreso.motivo == motivo) total++;
      }
    }
    return total;
  }

  static int _adopcionesDelMes(List<PerroModel> perros, DateTime mes) {
    var total = 0;
    for (final perro in perros) {
      if (perro.estado == 'egresado' && perro.motivoEgreso == 'adopcion' && _enMes(perro.fechaEgreso, mes)) {
        total++;
      }
      for (final egreso in perro.historialEgresos) {
        if (egreso.motivo == 'adopcion' && _enMes(egreso.fechaEgreso, mes)) total++;
      }
    }
    return total;
  }

  static bool _enMes(DateTime? fecha, DateTime mes) {
    if (fecha == null) return false;
    return fecha.year == mes.year && fecha.month == mes.month;
  }

  static int _mesesEnteros(DateTime desde, DateTime hasta) {
    var meses = (hasta.year - desde.year) * 12 + (hasta.month - desde.month);
    if (hasta.day < desde.day) meses--;
    if (meses < 0) return 0;
    return meses;
  }

  static DateTime _haceAnios(DateTime dia, int anios) {
    final anio = dia.year - anios;
    final ultimo = DateTime(anio, dia.month + 1, 0).day;
    final fecha = dia.day > ultimo ? ultimo : dia.day;
    return DateTime(anio, dia.month, fecha);
  }

  static DateTime _solo(DateTime fecha) => DateTime(fecha.year, fecha.month, fecha.day);
}
