import 'package:flutter/material.dart';

import '../controllers/tratamiento_controller.dart';
import '../models/tratamiento_model.dart';
import '../theme/app_colors.dart';

/// El diario ya suspendido, listo para guardarse.
class ConfirmacionSuspension {
  final TratamientoModel tratamiento;
  final DateTime ultimoDia;

  const ConfirmacionSuspension({
    required this.tratamiento,
    required this.ultimoDia,
  });
}

/// Pide el último día de medicación y muestra cómo va a quedar el historial.
Future<ConfirmacionSuspension?> mostrarHojaSuspender(
  BuildContext context, {
  required TratamientoModel tratamiento,
  required String nombrePerro,
}) {
  final hoy = DateTime.now();
  final hoyFecha = DateTime(hoy.year, hoy.month, hoy.day);
  final inicio = tratamiento.fechaInicio == null
      ? hoyFecha
      : DateTime(
          tratamiento.fechaInicio!.year,
          tratamiento.fechaInicio!.month,
          tratamiento.fechaInicio!.day,
        );
  if (inicio.isAfter(hoyFecha)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Este tratamiento todavía no empezó')),
    );
    return Future.value(null);
  }
  return showModalBottomSheet<ConfirmacionSuspension>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _HojaSuspender(
      tratamiento: tratamiento,
      nombrePerro: nombrePerro,
      inicio: inicio,
      hoy: hoyFecha,
    ),
  );
}

class _HojaSuspender extends StatefulWidget {
  final TratamientoModel tratamiento;
  final String nombrePerro;
  final DateTime inicio;
  final DateTime hoy;

  const _HojaSuspender({
    required this.tratamiento,
    required this.nombrePerro,
    required this.inicio,
    required this.hoy,
  });

  @override
  State<_HojaSuspender> createState() => _HojaSuspenderState();
}

class _HojaSuspenderState extends State<_HojaSuspender> {
  late DateTime _ultimoDia;

  @override
  void initState() {
    super.initState();
    _ultimoDia = widget.hoy;
  }

  String _fecha(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    return '$dia/$mes/${fecha.year}';
  }

  @override
  Widget build(BuildContext context) {
    final tratamiento = widget.tratamiento;
    final nombre = tratamiento.medicacion.trim().isEmpty ? 'el tratamiento' : tratamiento.medicacion.trim();
    final perro = widget.nombrePerro.trim();
    final resumen = TratamientoController.resumenSuspension(tratamiento, ultimoDia: _ultimoDia);
    final inicio = resumen.inicio ?? widget.inicio;
    final rango = '${_fecha(inicio)} – ${_fecha(_ultimoDia)}';
    final cuenta = tratamiento.cuentaDosis;
    final dosis = resumen.enPeriodo == 1 ? '1 dosis' : '${resumen.enPeriodo} dosis';
    final preview = cuenta ? 'Quedará en el historial: $rango · $dosis' : 'Quedará en el historial: $rango';
    final posteriores = resumen.posteriores;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 8, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              perro.isEmpty ? 'Suspender $nombre' : 'Suspender $nombre de $perro',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'El historial conserva el período y las dosis dadas. Los recordatorios dejan de llegar.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.paleta.textoSuave,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Último día de medicación'),
              subtitle: Text(_fecha(_ultimoDia)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final elegida = await showDatePicker(
                  context: context,
                  initialDate: _ultimoDia,
                  firstDate: widget.inicio,
                  lastDate: widget.hoy,
                );
                if (elegida == null) return;
                setState(() => _ultimoDia = DateTime(elegida.year, elegida.month, elegida.day));
              },
            ),
            const SizedBox(height: 8),
            Text(preview, style: Theme.of(context).textTheme.bodyMedium),
            if (posteriores > 0) ...[
              const SizedBox(height: 8),
              Text(
                posteriores == 1
                    ? 'Se quitará 1 dosis marcada después de esa fecha'
                    : 'Se quitarán $posteriores dosis marcadas después de esa fecha',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.error),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.error.withValues(alpha: 0.14),
                      foregroundColor: AppColors.error,
                    ),
                    onPressed: () {
                      Navigator.pop(
                        context,
                        ConfirmacionSuspension(
                          tratamiento: TratamientoController.suspender(
                            tratamiento,
                            ultimoDia: _ultimoDia,
                          ),
                          ultimoDia: _ultimoDia,
                        ),
                      );
                    },
                    child: const Text('Suspender'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Pide la dosis nueva y desde cuándo rige. Devuelve el tratamiento actualizado.
Future<TratamientoModel?> mostrarHojaCambioDosis(
  BuildContext context, {
  required TratamientoModel tratamiento,
}) {
  return showModalBottomSheet<TratamientoModel>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _HojaCambioDosis(tratamiento: tratamiento),
  );
}

class _HojaCambioDosis extends StatefulWidget {
  final TratamientoModel tratamiento;

  const _HojaCambioDosis({required this.tratamiento});

  @override
  State<_HojaCambioDosis> createState() => _HojaCambioDosisState();
}

class _HojaCambioDosisState extends State<_HojaCambioDosis> {
  late final TextEditingController _dosis;
  late DateTime _desde;

  @override
  void initState() {
    super.initState();
    _dosis = TextEditingController(text: widget.tratamiento.indicaciones);
    final hoy = DateTime.now();
    _desde = DateTime(hoy.year, hoy.month, hoy.day);
  }

  @override
  void dispose() {
    _dosis.dispose();
    super.dispose();
  }

  String _fecha(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    return '$dia/$mes/${fecha.year}';
  }

  @override
  Widget build(BuildContext context) {
    final tramos = TratamientoController.tramosDosis(widget.tratamiento);
    final inicio = widget.tratamiento.fechaInicio;
    final primera = inicio == null
        ? DateTime(2000)
        : DateTime(inicio.year, inicio.month, inicio.day);
    final hoy = DateTime.now();
    final ultima = DateTime(hoy.year, hoy.month, hoy.day);

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 8, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cambiar dosis', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'La dosis anterior queda en el historial. El conteo de dosis no cambia.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.paleta.textoSuave),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _dosis,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Dosis nueva'),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Desde'),
              subtitle: Text(_fecha(_desde)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final elegida = await showDatePicker(
                  context: context,
                  initialDate: _desde.isBefore(primera) ? primera : _desde,
                  firstDate: primera,
                  lastDate: ultima.isBefore(primera) ? primera : ultima,
                );
                if (elegida == null) return;
                setState(() => _desde = DateTime(elegida.year, elegida.month, elegida.day));
              },
            ),
            if (tramos.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Dosis anteriores', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              for (final tramo in tramos)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    _lineaTramo(tramo),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  final nueva = _dosis.text.trim();
                  if (nueva.isEmpty || nueva == widget.tratamiento.indicaciones.trim()) {
                    Navigator.pop(context);
                    return;
                  }
                  Navigator.pop(
                    context,
                    TratamientoController.cambiarDosis(
                      widget.tratamiento,
                      nueva,
                      desde: _desde,
                    ),
                  );
                },
                child: const Text('Guardar cambio'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _lineaTramo(TramoDosis tramo) {
    final desde = tramo.desde == null ? '' : _fecha(tramo.desde!);
    if (tramo.hasta == null) {
      return desde.isEmpty ? tramo.indicaciones : '${tramo.indicaciones} · desde $desde';
    }
    return '${tramo.indicaciones} · $desde – ${_fecha(tramo.hasta!)}';
  }
}
