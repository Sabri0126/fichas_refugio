import 'package:flutter/material.dart';

import '../controllers/historial_notificaciones_controller.dart';
import '../models/dosis_avisada.dart';
import '../models/notificacion_registro_model.dart';
import '../theme/app_colors.dart';
import '../theme/category_colors.dart';
import '../theme/entrada_escalonada.dart';
import 'ficha_detalle_perro.dart';

class PantallaNotificaciones extends StatefulWidget {
  const PantallaNotificaciones({super.key});

  @override
  State<PantallaNotificaciones> createState() => _PantallaNotificacionesState();
}

class _PantallaNotificacionesState extends State<PantallaNotificaciones> {
  final HistorialNotificacionesController _historial = HistorialNotificacionesController();
  late final Stream<List<NotificacionRegistroModel>> _stream = _historial.observarHistorial();
  Set<String> _noLeidasAlAbrir = {};
  final Set<String> _vistas = {};
  final Set<String> _ocultasAhora = {};
  bool _puntosListos = false;
  bool _marque = false;

  String _formatearFecha(DateTime fecha) {
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final dia = DateTime(fecha.year, fecha.month, fecha.day);
    final hora = '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
    if (dia == hoy) return 'Hoy $hora';
    if (dia == hoy.subtract(const Duration(days: 1))) return 'Ayer $hora';
    final dd = fecha.day.toString().padLeft(2, '0');
    final mm = fecha.month.toString().padLeft(2, '0');
    return '$dd/$mm $hora';
  }

  bool _mostrarPunto(NotificacionRegistroModel item) {
    if (_vistas.contains(item.id)) return false;
    if (!_puntosListos) return !item.leida;
    return _noLeidasAlAbrir.contains(item.id) || !item.leida;
  }

  void _marcarVista(NotificacionRegistroModel item) {
    setState(() {
      _vistas.add(item.id);
      _noLeidasAlAbrir.remove(item.id);
    });
    if (item.tipo == 'clima' || item.idPerro == null) return;
    final dosis = item.idTratamiento != null && item.dia != null
        ? DosisAvisada(idTratamiento: item.idTratamiento!, dia: item.dia!)
        : null;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FichaDetallePerro(idDocumento: item.idPerro!, dosisAvisada: dosis),
      ),
    );
  }

  void _marcarAlMostrar(List<NotificacionRegistroModel> lista) {
    if (_marque) return;
    _marque = true;
    final capturadas = lista.where((entrada) => !entrada.leida).map((entrada) => entrada.id).toSet();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      setState(() {
        _noLeidasAlAbrir = capturadas;
        _puntosListos = true;
      });
      await _historial.marcarTodasLeidas(lista);
    });
  }

  Future<void> _confirmarBorrado() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Borrar el historial?'),
        content: const Text('Se eliminarán todas las notificaciones de esta lista. Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Borrar')),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    await _historial.borrarTodo();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<NotificacionRegistroModel>>(
      stream: _stream,
      builder: (context, snapshot) {
        final items = (snapshot.data ?? const <NotificacionRegistroModel>[])
            .where((entrada) => !_ocultasAhora.contains(entrada.id))
            .toList();
        if (snapshot.hasData && !snapshot.hasError) _marcarAlMostrar(items);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Notificaciones'),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_sweep_outlined),
                tooltip: 'Borrar todo',
                onPressed: items.isEmpty ? null : _confirmarBorrado,
              ),
            ],
          ),
          body: _cuerpo(snapshot, items),
        );
      },
    );
  }

  Widget _cuerpo(AsyncSnapshot<List<NotificacionRegistroModel>> snapshot, List<NotificacionRegistroModel> items) {
    if (snapshot.hasError) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _estadoVacio(error: true),
          const SizedBox(height: 12),
          _creditoClima(),
        ],
      );
    }
    if (!snapshot.hasData) {
      return const Center(child: CircularProgressIndicator());
    }
    if (items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _estadoVacio(),
          const SizedBox(height: 12),
          _creditoClima(),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        for (var index = 0; index < items.length; index++) ...[
          _fila(items[index], index),
          if (index != items.length - 1) const SizedBox(height: 12),
        ],
        const SizedBox(height: 12),
        _creditoClima(),
      ],
    );
  }

  Widget _fila(NotificacionRegistroModel item, int index) {
    final noLeida = _mostrarPunto(item);
    final visual = _visual(item);
    return EntradaEscalonada(
      indice: index,
      child: Dismissible(
        key: ValueKey(item.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.delete_outline, color: AppColors.error),
        ),
        onDismissed: (_) {
          setState(() => _ocultasAhora.add(item.id));
          _historial.eliminar(item.id);
        },
        child: Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          color: noLeida ? AppColors.terracota.withValues(alpha: 0.08) : null,
          child: InkWell(
            onTap: () => _marcarVista(item),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: visual.fondo,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(visual.icono, size: 20, color: visual.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.titulo, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          item.cuerpo,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: context.paleta.textoSuave,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatearFecha(item.fecha),
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: context.paleta.textoSuave,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (noLeida)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(top: 6, left: 8),
                      decoration: const BoxDecoration(
                        color: AppColors.terracota,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  ({IconData icono, Color color, Color fondo}) _visual(NotificacionRegistroModel item) {
    if (item.tipo == 'ultimo_dia') {
      return (
        icono: Icons.flag_rounded,
        color: AppColors.pausado,
        fondo: AppColors.pausado.withValues(alpha: 0.12),
      );
    }
    if (item.categoria == 'seguimiento') {
      return (
        icono: Icons.visibility_outlined,
        color: AppColors.terracota,
        fondo: AppColors.terracota.withValues(alpha: 0.12),
      );
    }
    if (item.categoria == 'ingreso') {
      return (
        icono: Icons.cake_outlined,
        color: AppColors.terracota,
        fondo: AppColors.terracota.withValues(alpha: 0.12),
      );
    }
    if (item.categoria == 'llovizna') {
      return (
        icono: Icons.grain,
        color: CategoryColors.higieneTexto,
        fondo: CategoryColors.higieneTexto.withValues(alpha: 0.12),
      );
    }
    if (item.categoria == 'lluvia') {
      return (
        icono: Icons.umbrella_rounded,
        color: CategoryColors.unicoTexto,
        fondo: CategoryColors.unicoTexto.withValues(alpha: 0.12),
      );
    }
    if (item.categoria == 'lluvia_fuerte') {
      return (
        icono: Icons.water_drop,
        color: AppColors.navy,
        fondo: AppColors.navy.withValues(alpha: 0.12),
      );
    }
    if (item.categoria == 'tormenta') {
      return (
        icono: Icons.thunderstorm,
        color: CategoryColors.eventoTexto,
        fondo: CategoryColors.eventoTexto.withValues(alpha: 0.12),
      );
    }
    if (item.categoria == 'granizo') {
      return (
        icono: Icons.storm,
        color: AppColors.navy,
        fondo: AppColors.navy.withValues(alpha: 0.12),
      );
    }
    if (item.categoria == 'viento') {
      return (
        icono: Icons.air,
        color: CategoryColors.diarioTexto,
        fondo: CategoryColors.diarioTexto.withValues(alpha: 0.12),
      );
    }
    if (item.categoria == 'nublado') {
      return (
        icono: Icons.cloud,
        color: AppColors.textoSecundario,
        fondo: AppColors.textoSecundario.withValues(alpha: 0.12),
      );
    }
    if (item.categoria == 'frio_dia') {
      return (
        icono: Icons.thermostat,
        color: CategoryColors.higieneTexto,
        fondo: CategoryColors.higieneTexto.withValues(alpha: 0.12),
      );
    }
    if (item.categoria == 'lindo') {
      return (
        icono: Icons.wb_sunny_outlined,
        color: AppColors.activoTexto,
        fondo: AppColors.activo.withValues(alpha: 0.12),
      );
    }
    if (item.categoria == 'calor') {
      return (
        icono: Icons.wb_sunny_rounded,
        color: AppColors.pausado,
        fondo: AppColors.pausado.withValues(alpha: 0.12),
      );
    }
    if (item.categoria == 'frio') {
      return (
        icono: Icons.ac_unit_rounded,
        color: CategoryColors.higieneTexto,
        fondo: CategoryColors.higieneTexto.withValues(alpha: 0.12),
      );
    }
    if (item.categoria == 'medicacion') {
      return (
        icono: CategoryColors.icono('unico'),
        color: CategoryColors.base('unico'),
        fondo: CategoryColors.tinte('unico'),
      );
    }
    if (item.categoria == 'otro') {
      return (
        icono: Icons.event_note,
        color: AppColors.navy,
        fondo: AppColors.navy.withValues(alpha: 0.12),
      );
    }
    return (
      icono: CategoryColors.icono(item.categoria),
      color: CategoryColors.base(item.categoria),
      fondo: CategoryColors.tinte(item.categoria),
    );
  }

  Widget _estadoVacio({bool error = false}) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.navy.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.notifications_none_rounded, size: 30, color: context.paleta.lienzo),
          ),
          const SizedBox(height: 12),
          Text(
            error ? 'No se pudo cargar el historial.' : 'No hay notificaciones por ahora.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: context.paleta.lienzoSuave),
          ),
          const SizedBox(height: 8),
          Text(
            error ? 'Probá de nuevo en un rato.' : 'Se guardan hasta 30 días.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: context.paleta.lienzoSuave),
          ),
        ],
      ),
    );
  }

  Widget _creditoClima() {
    return Text(
      'Datos del clima: Open-Meteo.com',
      style: Theme.of(context).textTheme.labelMedium?.copyWith(color: context.paleta.lienzoSuave),
    );
  }
}
