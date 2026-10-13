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

  ItemResumen({
    required this.perro,
    required this.titulo,
    required this.detalle,
    this.hora,
    required this.categoria,
    this.esRecordatorio = false,
  });
}

/// Listas del día, ya ordenadas. [total] suma todas.
class ResumenDia {
  final List<ItemResumen> dadas;
  final List<ItemResumen> pendientes;
  final List<ItemResumen> programadas;
  final List<ItemResumen> olvidadas;
  final List<ItemResumen> eventos;
  final List<ItemResumen> recordatorios;

  const ResumenDia({
    this.dadas = const [],
    this.pendientes = const [],
    this.programadas = const [],
    this.olvidadas = const [],
    this.eventos = const [],
    this.recordatorios = const [],
  });

  int get total =>
      dadas.length +
      pendientes.length +
      programadas.length +
      olvidadas.length +
      eventos.length +
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
    final olvidadas = <ItemResumen>[];
    final eventos = <ItemResumen>[];
    final recordatorios = <ItemResumen>[];

    for (final perro in perros) {
      if (perro.estado != 'activo') continue;
      if (idPerro != null && perro.id != idPerro) continue;

      for (final tratamiento in perro.tratamientos) {
        if (tratamiento.categoria == 'diario') {
          final dada = tratamiento.registroDosis.contains(iso);
          if (dada) dadas.add(_itemTratamiento(perro, tratamiento));
          // Limitación conocida: de un tratamiento pausado solo se muestran
          // las dosis dadas. Si `activo` es false, no entra en pendientes,
          // programadas ni olvidadas aunque el día le corresponda.
          if (!tratamiento.activo || !_corresponde(tratamiento, diaFecha)) {
            continue;
          }
          if (diaFecha == hoyFecha) {
            if (!dada) pendientes.add(_itemTratamiento(perro, tratamiento));
          } else if (diaFecha.isAfter(hoyFecha)) {
            programadas.add(_itemTratamiento(perro, tratamiento));
          } else if (!dada) {
            olvidadas.add(_itemTratamiento(perro, tratamiento));
          }
        } else if (tratamiento.registroDosis.contains(iso)) {
          eventos.add(_itemTratamiento(perro, tratamiento));
        }
      }

      for (final recordatorio in perro.recordatorios) {
        if (_soloFecha(recordatorio.fechaHora) != diaFecha) continue;
        recordatorios.add(_itemRecordatorio(perro, recordatorio));
      }
    }

    for (final lista in [
      dadas,
      pendientes,
      programadas,
      olvidadas,
      eventos,
      recordatorios,
    ]) {
      lista.sort(_compararItems);
    }

    return ResumenDia(
      dadas: dadas,
      pendientes: pendientes,
      programadas: programadas,
      olvidadas: olvidadas,
      eventos: eventos,
      recordatorios: recordatorios,
    );
  }

  /// Claves de puntos del día, sin repetir y como máximo 5.
  /// Prioridad: olvidada, pendiente, diario (dadas), categorías de eventos, recordatorio.
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

    if (resumen.olvidadas.isNotEmpty) agregar('olvidada');
    if (resumen.pendientes.isNotEmpty) agregar('pendiente');
    if (resumen.dadas.isNotEmpty) agregar('diario');
    const ordenEventos = ['unico', 'higiene', 'evento', 'veterinaria'];
    final presentes = resumen.eventos.map((item) => item.categoria).toSet();
    for (final categoria in ordenEventos) {
      if (presentes.contains(categoria)) agregar(categoria);
    }
    if (resumen.recordatorios.isNotEmpty) agregar('recordatorio');
    return claves;
  }

  static Color colorMarcador(String clave) {
    return switch (clave) {
      'olvidada' => AppColors.dosisOlvidada,
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
    TratamientoModel tratamiento,
  ) {
    return ItemResumen(
      perro: perro,
      titulo: tratamiento.medicacion,
      detalle: tratamiento.indicaciones,
      hora: tratamiento.categoria == 'diario'
          ? _horaONula(tratamiento.horaRecordatorio)
          : null,
      categoria: tratamiento.categoria,
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
