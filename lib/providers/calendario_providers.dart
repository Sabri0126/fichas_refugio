import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../controllers/calendario_general_controller.dart';
import '../models/perro_model.dart';
import 'perros_providers.dart';

enum VistaCalendario { mes, lista }

/// Día, vista y filtros del calendario. [hoy] y el rango quedan fijos
/// hasta salir de la pantalla.
class FiltrosCalendario {
  final DateTime diaSeleccionado;
  final DateTime diaEnfocado;
  final VistaCalendario vista;
  final String? idPerro;
  final String? tipo;
  final String busqueda;
  final DateTime hoy;
  final DateTime primerDia;
  final DateTime ultimoDia;

  const FiltrosCalendario({
    required this.diaSeleccionado,
    required this.diaEnfocado,
    required this.vista,
    required this.hoy,
    required this.primerDia,
    required this.ultimoDia,
    this.idPerro,
    this.tipo,
    this.busqueda = '',
  });

  FiltrosCalendario copyWith({
    DateTime? diaSeleccionado,
    DateTime? diaEnfocado,
    VistaCalendario? vista,
    String? idPerro,
    bool limpiarPerro = false,
    String? tipo,
    bool limpiarTipo = false,
    String? busqueda,
  }) {
    return FiltrosCalendario(
      diaSeleccionado: diaSeleccionado ?? this.diaSeleccionado,
      diaEnfocado: diaEnfocado ?? this.diaEnfocado,
      vista: vista ?? this.vista,
      idPerro: limpiarPerro ? null : (idPerro ?? this.idPerro),
      tipo: limpiarTipo ? null : (tipo ?? this.tipo),
      busqueda: busqueda ?? this.busqueda,
      hoy: hoy,
      primerDia: primerDia,
      ultimoDia: ultimoDia,
    );
  }
}

final relojProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Una sola vez por ejecución. El calendario espera este futuro para usar `es_ES`.
final localeCalendarioProvider = FutureProvider<void>((ref) {
  return initializeDateFormatting('es_ES');
});

final filtrosCalendarioProvider =
    NotifierProvider.autoDispose<FiltrosCalendarioNotifier, FiltrosCalendario>(
  FiltrosCalendarioNotifier.new,
);

class FiltrosCalendarioNotifier extends Notifier<FiltrosCalendario> {
  @override
  FiltrosCalendario build() {
    final ahora = ref.watch(relojProvider)();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    return FiltrosCalendario(
      diaSeleccionado: hoy,
      diaEnfocado: hoy,
      vista: VistaCalendario.mes,
      hoy: hoy,
      primerDia: _fechaEnAnio(hoy, -2),
      ultimoDia: _fechaEnAnio(hoy, 1),
    );
  }

  void seleccionarDia(DateTime dia, {DateTime? enfocado, VistaCalendario? vista}) {
    final solo = DateTime(dia.year, dia.month, dia.day);
    state = state.copyWith(
      diaSeleccionado: solo,
      diaEnfocado: enfocado ?? solo,
      vista: vista,
    );
  }

  void enfocar(DateTime dia) => state = state.copyWith(diaEnfocado: dia);

  void cambiarVista(VistaCalendario vista) => state = state.copyWith(vista: vista);

  void filtrarPerro(String? id) => state = state.copyWith(idPerro: id, limpiarPerro: id == null);

  void filtrarTipo(String? tipo) => state = state.copyWith(tipo: tipo, limpiarTipo: tipo == null);

  void buscar(String texto) {
    if (texto == state.busqueda) return;
    state = state.copyWith(busqueda: texto);
  }

  void irAHoy() {
    state = state.copyWith(
      diaSeleccionado: state.hoy,
      diaEnfocado: state.hoy,
      vista: state.vista == VistaCalendario.lista ? VistaCalendario.mes : state.vista,
    );
  }
}

DateTime _fechaEnAnio(DateTime base, int deltaAnios) {
  final anio = base.year + deltaAnios;
  final ultimoDiaMes = DateTime(anio, base.month + 1, 0).day;
  final dia = base.day > ultimoDiaMes ? ultimoDiaMes : base.day;
  return DateTime(anio, base.month, dia);
}

/// El id guardado se usa solo si ese perro sigue activo.
String? idPerroEnActivos(List<PerroModel> activos, String? id) {
  if (id == null) return null;
  return activos.any((perro) => perro.id == id) ? id : null;
}

final perrosActivosCalendarioProvider = Provider.autoDispose<AsyncValue<List<PerroModel>>>((ref) {
  return _conPerros(ref.watch(perrosProvider), (perros) {
    final activos = perros.where((perro) => perro.estado == 'activo').toList()
      ..sort((a, b) => a.nombre.compareTo(b.nombre));
    return activos;
  });
});

final resumenDiaProvider = Provider.autoDispose<AsyncValue<ResumenDia>>((ref) {
  final async = ref.watch(perrosProvider);
  final dia = ref.watch(filtrosCalendarioProvider.select((filtros) => filtros.diaSeleccionado));
  final id = ref.watch(filtrosCalendarioProvider.select((filtros) => filtros.idPerro));
  final hoy = ref.watch(filtrosCalendarioProvider.select((filtros) => filtros.hoy));
  return _conPerros(async, (perros) {
    final activos = [for (final perro in perros) if (perro.estado == 'activo') perro];
    return CalendarioGeneralController.construirResumen(
      perros,
      dia,
      hoy: hoy,
      idPerro: idPerroEnActivos(activos, id),
    );
  });
});

class ListaCalendario {
  final List<EntradaListaGeneral> entradas;

  const ListaCalendario(this.entradas);
}

final listaCalendarioProvider = Provider.autoDispose<AsyncValue<ListaCalendario>>((ref) {
  final async = ref.watch(perrosProvider);
  final id = ref.watch(filtrosCalendarioProvider.select((filtros) => filtros.idPerro));
  final primerDia = ref.watch(filtrosCalendarioProvider.select((filtros) => filtros.primerDia));
  final ultimoDia = ref.watch(filtrosCalendarioProvider.select((filtros) => filtros.ultimoDia));
  return _conPerros(async, (perros) {
    final activos = [for (final perro in perros) if (perro.estado == 'activo') perro];
    final filtro = idPerroEnActivos(activos, id);
    final antigua = CalendarioGeneralController.fechaMasAntigua(perros, idPerro: filtro);
    final desde = antigua != null && antigua.isBefore(primerDia) ? antigua : primerDia;
    return ListaCalendario(
      CalendarioGeneralController.construirLista(
        perros,
        desde: desde,
        hasta: ultimoDia,
        idPerro: filtro,
      ),
    );
  });
});

final seguimientosActivosProvider = Provider.autoDispose<AsyncValue<List<ItemResumen>>>((ref) {
  final async = ref.watch(perrosProvider);
  final id = ref.watch(filtrosCalendarioProvider.select((filtros) => filtros.idPerro));
  final hoy = ref.watch(filtrosCalendarioProvider.select((filtros) => filtros.hoy));
  return _conPerros(async, (perros) {
    final activos = [for (final perro in perros) if (perro.estado == 'activo') perro];
    return CalendarioGeneralController.seguimientosActivos(
      perros,
      hoy: hoy,
      idPerro: idPerroEnActivos(activos, id),
    );
  });
});

/// Pendientes de hoy para el menú. Sin lista, cero.
final pendientesHoyProvider = Provider<int>((ref) {
  final datos = ref.watch(perrosProvider).value;
  if (datos == null) return 0;
  final ahora = ref.watch(relojProvider)();
  final hoy = DateTime(ahora.year, ahora.month, ahora.day);
  return CalendarioGeneralController.construirResumen(datos, hoy, hoy: hoy).pendientes.length;
});

AsyncValue<T> _conPerros<T>(AsyncValue<List<PerroModel>> async, T Function(List<PerroModel>) calcular) {
  if (async.hasError && !async.hasValue) {
    return AsyncError(async.error!, async.stackTrace ?? StackTrace.empty);
  }
  if (!async.hasValue) return const AsyncLoading();
  return AsyncData(calcular(async.requireValue));
}
