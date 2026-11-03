import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/perro_controller.dart';
import '../controllers/tratamiento_controller.dart';
import '../models/estado_duracion.dart';
import '../models/perro_model.dart';
import '../models/tratamiento_model.dart';
import 'firestore_providers.dart';
import 'theme_mode_provider.dart';

enum ModoVista { grande, compacta, lista }

enum OrdenListado { reciente, antiguo, nombre, edad }

enum SeccionPerros { activos, difuntos, egresados }

const claveVistaListado = 'vista_listado_perros';

/// Hay un diario en curso: activo, sin pausa y todavía no finalizado.
bool tieneTratamientoActivo(List<TratamientoModel> tratamientos, {DateTime? hoy}) {
  final momento = hoy ?? DateTime.now();
  final dia = DateTime(momento.year, momento.month, momento.day);
  final activos = TratamientoController.obtenerActivosDiarios(tratamientos);
  for (final tratamiento in activos) {
    final fase = TratamientoController.calcularEstadoDuracion(tratamiento, hoy: dia).fase;
    if (fase != FaseTratamiento.finalizado) return true;
  }
  return false;
}

class LecturaListaPerros {
  final List<PerroModel> perros;
  final bool desdeCache;

  const LecturaListaPerros({required this.perros, required this.desdeCache});
}

/// Una sola suscripción a `perros`, compartida por el menú, el listado,
/// el calendario y los reportes. No es autoDispose: si se soltara al salir
/// de la última pantalla, al volver aparecería el esqueleto de carga.
/// Si la escucha se cae, Riverpod la vuelve a abrir: si no, Windows se
/// quedaba con la primera lista para siempre.
final lecturaPerrosProvider = StreamProvider<LecturaListaPerros>((ref) {
  final controller = ref.watch(perroControllerProvider);
  return controller.observarListaConOrigen().map(
        (lectura) => LecturaListaPerros(perros: lectura.perros, desdeCache: lectura.desdeCache),
      );
});

final perrosProvider = Provider<AsyncValue<List<PerroModel>>>((ref) {
  final async = ref.watch(lecturaPerrosProvider);
  if (async.hasValue) return AsyncData(async.value!.perros);
  if (async.hasError) return AsyncError(async.error!, async.stackTrace ?? StackTrace.empty);
  return const AsyncLoading();
});

/// `false` mientras no hay una emisión: el aviso de sin conexión no aparece en la carga.
final perrosDesdeCacheProvider = Provider<bool>((ref) {
  return ref.watch(lecturaPerrosProvider).value?.desdeCache ?? false;
});

/// Se suelta al cerrar la ficha. Sigue emitiendo metadata y `perro == null` si se borró.
final perroProvider = StreamProvider.autoDispose.family<LecturaPerro, String>((ref, id) {
  return ref.watch(perroControllerProvider).observarPerroConOrigen(id);
}, retry: (_, _) => null);

class FiltrosPerros {
  final String texto;
  final String ubicacion;
  final String egreso;
  final String sexo;
  final String castrado;
  final bool soloConTratamiento;
  final bool soloTratamientoActivo;
  final OrdenListado orden;
  final ModoVista modoVista;

  const FiltrosPerros({
    this.texto = '',
    this.ubicacion = 'Todos',
    this.egreso = 'Todos',
    this.sexo = 'Todos',
    this.castrado = 'Todos',
    this.soloConTratamiento = false,
    this.soloTratamientoActivo = false,
    this.orden = OrdenListado.reciente,
    this.modoVista = ModoVista.grande,
  });

  FiltrosPerros copyWith({
    String? texto,
    String? ubicacion,
    String? egreso,
    String? sexo,
    String? castrado,
    bool? soloConTratamiento,
    bool? soloTratamientoActivo,
    OrdenListado? orden,
    ModoVista? modoVista,
  }) {
    return FiltrosPerros(
      texto: texto ?? this.texto,
      ubicacion: ubicacion ?? this.ubicacion,
      egreso: egreso ?? this.egreso,
      sexo: sexo ?? this.sexo,
      castrado: castrado ?? this.castrado,
      soloConTratamiento: soloConTratamiento ?? this.soloConTratamiento,
      soloTratamientoActivo: soloTratamientoActivo ?? this.soloTratamientoActivo,
      orden: orden ?? this.orden,
      modoVista: modoVista ?? this.modoVista,
    );
  }
}

/// Se descarta al salir de la sección, igual que el State de hoy.
/// El modo de vista se vuelve a leer de shared preferences.
final filtrosPerrosProvider = NotifierProvider.autoDispose
    .family<FiltrosPerrosNotifier, FiltrosPerros, SeccionPerros>(FiltrosPerrosNotifier.new);

class FiltrosPerrosNotifier extends Notifier<FiltrosPerros> {
  FiltrosPerrosNotifier(this.seccion);

  final SeccionPerros seccion;

  @override
  FiltrosPerros build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return FiltrosPerros(modoVista: modoVistaGuardado(prefs.getString(claveVistaListado)));
  }

  void reemplazar(FiltrosPerros filtros) => state = filtros;

  void quitarFiltros() {
    state = FiltrosPerros(
      texto: state.texto,
      orden: state.orden,
      modoVista: state.modoVista,
    );
  }

  Future<void> fijarModoVista(ModoVista modo) async {
    state = state.copyWith(modoVista: modo);
    await ref.read(sharedPreferencesProvider).setString(claveVistaListado, modo.name);
  }
}

final perrosFiltradosProvider =
    Provider.autoDispose.family<AsyncValue<List<PerroModel>>, SeccionPerros>((ref, seccion) {
  final async = ref.watch(perrosProvider);
  final filtros = ref.watch(filtrosPerrosProvider(seccion));
  if (async.hasValue) return AsyncData(filtrarPerros(async.value!, filtros, seccion));
  if (async.hasError) return AsyncError(async.error!, async.stackTrace ?? StackTrace.empty);
  return const AsyncLoading();
});

List<PerroModel> filtrarPerros(
  List<PerroModel> todos,
  FiltrosPerros filtros,
  SeccionPerros seccion,
) {
  final perros = todos.where((perro) {
    switch (seccion) {
      case SeccionPerros.difuntos:
        return perro.estado == 'inactivo';
      case SeccionPerros.egresados:
        return perro.estado == 'egresado';
      case SeccionPerros.activos:
        return perro.estado == 'activo';
    }
  }).where((perro) {
    if (seccion == SeccionPerros.egresados) {
      if (filtros.egreso == 'Adoptados') return perro.motivoEgreso == 'adopcion';
      if (filtros.egreso == 'Reencontrados') return perro.motivoEgreso == 'familia';
      return true;
    }
    if (filtros.ubicacion == 'En casa') return perro.enCasa;
    if (filtros.ubicacion == 'Refugio') return !perro.enCasa;
    return true;
  }).where((perro) {
    if (filtros.sexo == 'Macho' && perro.sexo != 'macho') return false;
    if (filtros.sexo == 'Hembra' && perro.sexo != 'hembra') return false;
    if (filtros.castrado == 'Castrados' && !perro.castrado) return false;
    if (filtros.castrado == 'Sin castrar' && perro.castrado) return false;
    if (filtros.soloConTratamiento && !_tieneDosisPendiente(perro)) return false;
    if (filtros.soloTratamientoActivo && !tieneTratamientoActivo(perro.tratamientos)) return false;
    if (filtros.texto.isEmpty) return true;
    return perro.nombre.toLowerCase().contains(filtros.texto.toLowerCase());
  }).toList();

  perros.sort((a, b) {
    switch (filtros.orden) {
      case OrdenListado.nombre:
        return a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
      case OrdenListado.edad:
        return _compararEdad(a, b);
      case OrdenListado.antiguo:
        return _compararFechaDesc(b.fechaIngreso, a.fechaIngreso);
      case OrdenListado.reciente:
        if (seccion == SeccionPerros.egresados) {
          final porEgreso = _compararFechaDesc(a.fechaEgreso, b.fechaEgreso);
          if (porEgreso != 0) return porEgreso;
        }
        return _compararFechaDesc(a.fechaIngreso, b.fechaIngreso);
    }
  });
  return perros;
}

int _compararEdad(PerroModel a, PerroModel b) => PerroController.compararPorEdad(a, b);

int _compararFechaDesc(DateTime? a, DateTime? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return b.compareTo(a);
}

bool _tieneDosisPendiente(PerroModel perro) {
  if (perro.estado != 'activo') return false;
  final hoy = DateTime.now();
  final hoyFecha = DateTime(hoy.year, hoy.month, hoy.day);
  final iso =
      '${hoyFecha.year.toString().padLeft(4, '0')}-${hoyFecha.month.toString().padLeft(2, '0')}-${hoyFecha.day.toString().padLeft(2, '0')}';
  for (final tratamiento in perro.tratamientos) {
    if (tratamiento.categoria != 'diario' || !tratamiento.activo) continue;
    if (tratamiento.registroDosis.contains(iso)) continue;
    final fase = TratamientoController.calcularEstadoDuracion(tratamiento, hoy: hoyFecha).fase;
    if (fase == FaseTratamiento.enCurso ||
        fase == FaseTratamiento.ultimoDia ||
        fase == FaseTratamiento.indefinido) {
      return true;
    }
  }
  return false;
}

ModoVista modoVistaGuardado(String? valor) {
  return switch (valor) {
    'compacta' => ModoVista.compacta,
    'lista' => ModoVista.lista,
    _ => ModoVista.grande,
  };
}
