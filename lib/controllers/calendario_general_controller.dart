import 'package:flutter/material.dart';

import '../models/estado_duracion.dart';
import '../models/perro_model.dart';
import '../models/recordatorio_model.dart';
import '../models/tratamiento_model.dart';
import '../theme/app_colors.dart';
import '../theme/category_colors.dart';
import 'tratamiento_controller.dart';

/// Una fila del resumen: un tratamiento o un recordatorio de un perro.
class ItemResumen {
  final PerroModel perro;
  final String titulo;
  final String detalle;
  final String? hora;
  final String categoria;
  final bool esRecordatorio;
  final String? tratamientoId;
  final bool pendiente;

  ItemResumen({
    required this.perro,
    required this.titulo,
    required this.detalle,
    this.hora,
    required this.categoria,
    this.esRecordatorio = false,
    this.tratamientoId,
    this.pendiente = false,
  });
}

/// Listas del día, ya ordenadas. [total] suma todas.
class ResumenDia {
  final List<ItemResumen> dadas;
  final List<ItemResumen> pendientes;
  final List<ItemResumen> programadas;
  final List<ItemResumen> eventos;
  final List<ItemResumen> hitos;
  final List<ItemResumen> recordatorios;

  const ResumenDia({
    this.dadas = const [],
    this.pendientes = const [],
    this.programadas = const [],
    this.eventos = const [],
    this.hitos = const [],
    this.recordatorios = const [],
  });

  int get total =>
      dadas.length +
      pendientes.length +
      programadas.length +
      eventos.length +
      hitos.length +
      recordatorios.length;
}

/// Reglas del calendario general. No lee Firebase: recibe los perros ya cargados.
abstract final class CalendarioGeneralController {
  static final TratamientoController _fechas = TratamientoController();

  static ResumenDia construirResumen(
    List<PerroModel> perros,
    DateTime dia, {
    required DateTime hoy,
    String? idPerro,
  }) {
    final diaFecha = _soloFecha(dia);
    final hoyFecha = _soloFecha(hoy);
    final iso = _fechas.formatearFechaISO(diaFecha);
    final dadas = <ItemResumen>[];
    final pendientes = <ItemResumen>[];
    final programadas = <ItemResumen>[];
    final eventos = <ItemResumen>[];
    final hitos = <ItemResumen>[];
    final recordatorios = <ItemResumen>[];

    for (final perro in perros) {
      if (idPerro != null && perro.id != idPerro) continue;
      _agregarHitos(perro, diaFecha, hitos);
      final fallecido = perro.estado == 'inactivo';
      if (perro.estado != 'activo' && !fallecido) continue;

      for (final tratamiento in perro.tratamientos) {
        if (tratamiento.categoria == 'diario') {
          final dada = tratamiento.registroDosis.contains(iso);
          if (dada) dadas.add(_itemTratamiento(perro, tratamiento));
          // De un tratamiento pausado, o de un perro fallecido, solo se
          // muestran las dosis ya dadas. No entran pendientes ni programadas.
          if (fallecido || !tratamiento.activo || !_corresponde(tratamiento, diaFecha)) {
            continue;
          }
          if (diaFecha == hoyFecha) {
            if (!dada) {
              pendientes.add(_itemTratamiento(perro, tratamiento, pendiente: true));
            }
          } else if (diaFecha.isAfter(hoyFecha)) {
            programadas.add(_itemTratamiento(perro, tratamiento));
          }
        } else if (tratamiento.registroDosis.contains(iso)) {
          eventos.add(_itemTratamiento(perro, tratamiento));
        }
      }

      if (fallecido) continue;
      for (final recordatorio in perro.recordatorios) {
        if (_soloFecha(recordatorio.fechaHora) != diaFecha) continue;
        recordatorios.add(_itemRecordatorio(perro, recordatorio));
      }
    }

    for (final lista in [
      dadas,
      pendientes,
      programadas,
      eventos,
      hitos,
      recordatorios,
    ]) {
      lista.sort(_compararItems);
    }

    return ResumenDia(
      dadas: dadas,
      pendientes: pendientes,
      programadas: programadas,
      eventos: eventos,
      hitos: hitos,
      recordatorios: recordatorios,
    );
  }

  static void _agregarHitos(PerroModel perro, DateTime dia, List<ItemResumen> hitos) {
    final ingreso = perro.fechaIngreso;
    if (ingreso != null && _soloFecha(ingreso) == dia) {
      hitos.add(ItemResumen(
        perro: perro,
        titulo: 'Ingreso de ${perro.nombre}',
        detalle: '',
        categoria: 'ingreso',
      ));
    }
    final deceso = perro.fechaFallecimiento;
    if (deceso != null && _soloFecha(deceso) == dia) {
      hitos.add(ItemResumen(
        perro: perro,
        titulo: 'Falleció ${perro.nombre}',
        detalle: '',
        categoria: 'deceso',
      ));
    }
  }

  /// Claves de puntos del día, sin repetir y como máximo 5.
  /// Prioridad: pendiente, diario (dadas), categorías de eventos, ingreso, deceso, recordatorio.
  static List<String> marcadoresDelDia(
    List<PerroModel> perros,
    DateTime dia, {
    required DateTime hoy,
    String? idPerro,
  }) {
    final resumen = construirResumen(perros, dia, hoy: hoy, idPerro: idPerro);
    final claves = <String>[];

    void agregar(String clave) {
      if (claves.length >= 5 || claves.contains(clave)) return;
      claves.add(clave);
    }

    if (resumen.pendientes.isNotEmpty) agregar('pendiente');
    if (resumen.dadas.isNotEmpty) agregar('diario');
    const ordenEventos = ['unico', 'higiene', 'evento', 'veterinaria'];
    final presentes = resumen.eventos.map((item) => item.categoria).toSet();
    for (final categoria in ordenEventos) {
      if (presentes.contains(categoria)) agregar(categoria);
    }
    if (resumen.hitos.any((item) => item.categoria == 'ingreso')) agregar('ingreso');
    if (resumen.hitos.any((item) => item.categoria == 'deceso')) agregar('deceso');
    if (resumen.recordatorios.isNotEmpty) agregar('recordatorio');
    return claves;
  }

  /// Claves de la leyenda que aparecen al menos un día del mes de [mes].
  static List<String> clavesEnMes(
    List<PerroModel> perros,
    DateTime mes, {
    required DateTime hoy,
    String? idPerro,
  }) {
    final inicio = DateTime(mes.year, mes.month, 1);
    final fin = DateTime(mes.year, mes.month + 1, 0);
    final claves = <String>[];
    for (var dia = inicio; !dia.isAfter(fin); dia = dia.add(const Duration(days: 1))) {
      for (final clave in marcadoresDelDia(perros, dia, hoy: hoy, idPerro: idPerro)) {
        if (!claves.contains(clave)) claves.add(clave);
      }
    }
    return claves;
  }

  static Color colorMarcador(String clave) {
    return switch (clave) {
      'ingreso' => AppColors.terracota,
      'deceso' => AppColors.textoSecundario,
      'pendiente' => AppColors.pendiente,
      'diario' => CategoryColors.diario,
      'recordatorio' => AppColors.navy,
      _ => CategoryColors.base(clave),
    };
  }

  static bool _corresponde(TratamientoModel tratamiento, DateTime dia) {
    final estado = TratamientoController.calcularEstadoDuracion(
      tratamiento,
      hoy: dia,
    );
    if (estado.fase == FaseTratamiento.enCurso ||
        estado.fase == FaseTratamiento.ultimoDia) {
      return true;
    }
    if (estado.fase == FaseTratamiento.indefinido &&
        tratamiento.fechaInicio != null) {
      return !dia.isBefore(_soloFecha(tratamiento.fechaInicio!));
    }
    return false;
  }

  static ItemResumen _itemTratamiento(
    PerroModel perro,
    TratamientoModel tratamiento, {
    bool pendiente = false,
  }) {
    return ItemResumen(
      perro: perro,
      titulo: tratamiento.medicacion,
      detalle: tratamiento.indicaciones,
      hora: tratamiento.categoria == 'diario'
          ? _horaONula(tratamiento.horaRecordatorio)
          : null,
      categoria: tratamiento.categoria,
      tratamientoId: tratamiento.id,
      pendiente: pendiente,
    );
  }

  static ItemResumen _itemRecordatorio(
    PerroModel perro,
    RecordatorioModel recordatorio,
  ) {
    final hora = recordatorio.fechaHora.hour.toString().padLeft(2, '0');
    final minuto = recordatorio.fechaHora.minute.toString().padLeft(2, '0');
    return ItemResumen(
      perro: perro,
      titulo: recordatorio.titulo,
      detalle: recordatorio.nota,
      hora: '$hora:$minuto',
      categoria: recordatorio.tipo,
      esRecordatorio: true,
    );
  }

  static String? _horaONula(String? hora) {
    final texto = hora?.trim() ?? '';
    if (texto.isEmpty) return null;
    return texto;
  }

  static DateTime _soloFecha(DateTime fecha) =>
      DateTime(fecha.year, fecha.month, fecha.day);

  static int _compararItems(ItemResumen a, ItemResumen b) {
    final aSinHora = a.hora == null;
    final bSinHora = b.hora == null;
    if (aSinHora != bSinHora) return aSinHora ? 1 : -1;
    if (!aSinHora) {
      final porHora = a.hora!.compareTo(b.hora!);
      if (porHora != 0) return porHora;
    }
    final porNombre = a.perro.nombre.compareTo(b.perro.nombre);
    if (porNombre != 0) return porNombre;
    return a.titulo.compareTo(b.titulo);
  }
}
