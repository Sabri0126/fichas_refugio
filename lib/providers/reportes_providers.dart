import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/reportes_controller.dart';
import 'calendario_providers.dart';
import 'perros_providers.dart';

/// Mes elegido en reportes. Arranca en el mes del reloj.
final mesReporteProvider = NotifierProvider.autoDispose<MesReporteNotifier, DateTime>(
  MesReporteNotifier.new,
);

class MesReporteNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final ahora = ref.watch(relojProvider)();
    return DateTime(ahora.year, ahora.month);
  }

  void fijarMes(int mes) => state = DateTime(state.year, mes);

  void fijarAnio(int anio) => state = DateTime(anio, state.month);
}

/// Reporte del mes elegido. Un error de la lista se muestra aunque haya caché.
final reporteProvider = Provider.autoDispose<AsyncValue<ReporteRefugio>>((ref) {
  final async = ref.watch(perrosProvider);
  final mes = ref.watch(mesReporteProvider);
  final ahora = ref.watch(relojProvider)();
  if (async.hasError) {
    return AsyncError(async.error!, async.stackTrace ?? StackTrace.empty);
  }
  if (!async.hasValue) return const AsyncLoading();
  return AsyncData(ReportesController.calcular(async.value!, hoy: ahora, mes: mes));
});
