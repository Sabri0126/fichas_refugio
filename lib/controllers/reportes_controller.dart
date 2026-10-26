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
  final int reencuentros;
  final int fallecimientos;

  const RendimientoMes({
    required this.ingresos,
    required this.adopciones,
    required this.reencuentros,
    required this.fallecimientos,
  });
}

/// Un perro dentro de un año de la curva. El nombre ya está listo para mostrar.
class PerroAnio {
  final String id;
  final String nombre;

  const PerroAnio({required this.id, required this.nombre});
}

/// Población al cierre de un año, con los movimientos de ese año.
/// Los números son el largo de cada lista.
class PuntoPoblacion {
  final int anio;
  final List<PerroAnio> quienesEntraron;
  final List<PerroAnio> quienesSalieron;
  final List<PerroAnio> quienesQuedaron;

  const PuntoPoblacion({
    required this.anio,
    required this.quienesEntraron,
    required this.quienesSalieron,
    required this.quienesQuedaron,
  });

  int get entraron => quienesEntraron.length;
  int get salieron => quienesSalieron.length;
  int get quedaron => quienesQuedaron.length;
}

/// Curva anual. [sinFecha] son perros que no se pueden ubicar en el tiempo.
class SeriePoblacion {
  final List<PuntoPoblacion> puntos;
  final int sinFecha;

  const SeriePoblacion({required this.puntos, required this.sinFecha});
}

/// Los bloques de la pantalla de reportes.
class ReporteRefugio {
  final PoblacionActual poblacion;
  final BalanceHistorico balance;
  final LargaEstadia estadia;
  final RendimientoMes mes;
  final SeriePoblacion serie;

  const ReporteRefugio({
    required this.poblacion,
    required this.balance,
    required this.estadia,
    required this.mes,
    required this.serie,
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
        adopciones: _egresosDelMes(perros, mes, 'adopcion'),
        reencuentros: _egresosDelMes(perros, mes, 'familia'),
        fallecimientos: perros.where((perro) {
          return perro.estado == 'inactivo' && _enMes(perro.fechaFallecimiento, mes);
        }).length,
      ),
      serie: _seriePoblacion(perros, dia),
    );
  }

  /// Un punto por año, del primer ingreso fechado al año de [hoy].
  /// El cierre del año en curso es [hoy], no el 31 de diciembre.
  static SeriePoblacion _seriePoblacion(List<PerroModel> perros, DateTime hoy) {
    final fechados = <PerroModel>[];
    var sinFecha = 0;
    for (final perro in perros) {
      if (_poblacionFechada(perro)) {
        fechados.add(perro);
      } else {
        sinFecha++;
      }
    }
    if (fechados.isEmpty) return SeriePoblacion(puntos: const [], sinFecha: sinFecha);

    var primero = fechados.first.fechaIngreso!.year;
    for (final perro in fechados) {
      final anio = perro.fechaIngreso!.year;
      if (anio < primero) primero = anio;
    }
    if (primero > hoy.year) return SeriePoblacion(puntos: const [], sinFecha: sinFecha);

    final puntos = <PuntoPoblacion>[];
    for (var anio = primero; anio <= hoy.year; anio++) {
      final corte = anio == hoy.year ? hoy : DateTime(anio, 12, 31);
      final entraron = <PerroAnio>[];
      final salieron = <PerroAnio>[];
      final quedaron = <PerroAnio>[];
      for (final perro in fechados) {
        final ficha = _perroAnio(perro);
        final ingreso = perro.fechaIngreso!;
        if (ingreso.year == anio && !_solo(ingreso).isAfter(corte)) entraron.add(ficha);
        if (_salioEnAnio(perro, anio, corte)) salieron.add(ficha);
        if (_aCargo(perro, corte)) quedaron.add(ficha);
      }
      _ordenar(entraron);
      _ordenar(salieron);
      _ordenar(quedaron);
      puntos.add(
        PuntoPoblacion(
          anio: anio,
          quienesEntraron: entraron,
          quienesSalieron: salieron,
          quienesQuedaron: quedaron,
        ),
      );
    }
    return SeriePoblacion(puntos: puntos, sinFecha: sinFecha);
  }

  /// Se puede saber si estaba a cargo: ingreso, muerte y cada egreso tienen fecha.
  static bool _poblacionFechada(PerroModel perro) {
    if (perro.fechaIngreso == null) return false;
    if (perro.estado == 'inactivo' && perro.fechaFallecimiento == null) return false;
    if (perro.estado == 'egresado' && perro.fechaEgreso == null) return false;
    for (final egreso in perro.historialEgresos) {
      if (egreso.fechaEgreso == null || egreso.fechaRegreso == null) return false;
    }
    return true;
  }

  static bool _aCargo(PerroModel perro, DateTime dia) {
    final ingreso = _solo(perro.fechaIngreso!);
    if (ingreso.isAfter(dia)) return false;
    final muerte = perro.fechaFallecimiento;
    if (muerte != null && !_solo(muerte).isAfter(dia)) return false;
    for (final egreso in perro.historialEgresos) {
      final salida = _solo(egreso.fechaEgreso!);
      final regreso = _solo(egreso.fechaRegreso!);
      if (!salida.isAfter(dia) && regreso.isAfter(dia)) return false;
    }
    if (perro.estado == 'egresado') {
      final salida = _solo(perro.fechaEgreso!);
      if (!salida.isAfter(dia)) return false;
    }
    return true;
  }

  static bool _salioEnAnio(PerroModel perro, int anio, DateTime corte) {
    bool enElAnio(DateTime? fecha) {
      if (fecha == null || fecha.year != anio) return false;
      return !_solo(fecha).isAfter(corte);
    }

    if (enElAnio(perro.fechaFallecimiento)) return true;
    if (perro.estado == 'egresado' && enElAnio(perro.fechaEgreso)) return true;
    for (final egreso in perro.historialEgresos) {
      if (enElAnio(egreso.fechaEgreso)) return true;
    }
    return false;
  }

  static PerroAnio _perroAnio(PerroModel perro) {
    final nombre = perro.nombre.trim();
    return PerroAnio(id: perro.id, nombre: nombre.isEmpty ? 'Sin nombre' : nombre);
  }

  static void _ordenar(List<PerroAnio> lista) {
    lista.sort((a, b) {
      final porNombre = a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
      if (porNombre != 0) return porNombre;
      return a.id.compareTo(b.id);
    });
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

  static int _egresosDelMes(List<PerroModel> perros, DateTime mes, String motivo) {
    var total = 0;
    for (final perro in perros) {
      if (perro.estado == 'egresado' && perro.motivoEgreso == motivo && _enMes(perro.fechaEgreso, mes)) {
        total++;
      }
      for (final egreso in perro.historialEgresos) {
        if (egreso.motivo == motivo && _enMes(egreso.fechaEgreso, mes)) total++;
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
