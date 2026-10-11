import 'package:flutter/material.dart';

import '../controllers/historial_notificaciones_controller.dart';
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
  List<NotificacionRegistroModel> _items = [];
  Set<String> _noLeidasAlAbrir = {};
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    await _historial.reconciliar();
    final lista = await _historial.obtenerHistorial();
    final noLeidas = lista.where((entrada) => !entrada.leida).map((entrada) => entrada.id).toSet();
    await _historial.marcarTodasLeidas();
    if (!mounted) return;
    setState(() {
      _items = lista;
      _noLeidasAlAbrir = noLeidas;
      _cargando = false;
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
    if (!mounted) return;
    setState(() => _items = []);
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Borrar todo',
            onPressed: _items.isEmpty ? null : _confirmarBorrado,
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? _estadoVacio()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: _items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    final noLeida = _noLeidasAlAbrir.contains(item.id);
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
                          setState(() => _items.removeWhere((entrada) => entrada.id == item.id));
                          _historial.eliminar(item.id);
                        },
                        child: Card(
                          margin: EdgeInsets.zero,
                          clipBehavior: Clip.antiAlias,
                          color: noLeida ? AppColors.terracota.withValues(alpha: 0.08) : null,
                          child: InkWell(
                            onTap: item.idPerro == null
                                ? null
                                : () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => FichaDetallePerro(idDocumento: item.idPerro!),
                                      ),
                                    ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: CategoryColors.tinte(item.categoria),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      CategoryColors.icono(item.categoria),
                                      size: 20,
                                      color: CategoryColors.base(item.categoria),
                                    ),
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
                                            color: AppColors.textoSecundario,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          _formatearFecha(item.fecha),
                                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                            color: AppColors.textoSecundario,
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
                  },
                ),
    );
  }

  Widget _estadoVacio() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.navy.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.notifications_none_rounded, size: 30, color: AppColors.navy),
            ),
            const SizedBox(height: 12),
            Text(
              'No hay notificaciones por ahora.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textoSecundario),
            ),
            const SizedBox(height: 8),
            Text(
              'Se guardan las últimas 100, por un máximo de 30 días.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.textoSecundario),
            ),
          ],
        ),
      ),
    );
  }
}
