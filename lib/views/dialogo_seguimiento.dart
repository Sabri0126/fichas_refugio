import 'package:flutter/material.dart';

import '../controllers/seguimiento_controller.dart';
import '../models/seguimiento_model.dart';
import '../theme/app_colors.dart';
import '../theme/seguimiento_tipos.dart';

/// Alta o edición. Devuelve el modelo, o null si se cancela.
/// [fechaInicial] es el día de inicio de un alta nueva.
Future<SeguimientoModel?> mostrarDialogoSeguimiento(
  BuildContext context, {
  required SeguimientoController controller,
  SeguimientoModel? actual,
  DateTime? fechaInicial,
}) {
  return showDialog<SeguimientoModel>(
    context: context,
    builder: (ctx) => _DialogoSeguimiento(
      controller: controller,
      actual: actual,
      fechaInicial: fechaInicial,
    ),
  );
}

class _DialogoSeguimiento extends StatefulWidget {
  final SeguimientoController controller;
  final SeguimientoModel? actual;
  final DateTime? fechaInicial;

  const _DialogoSeguimiento({
    required this.controller,
    this.actual,
    this.fechaInicial,
  });

  @override
  State<_DialogoSeguimiento> createState() => _DialogoSeguimientoState();
}

class _DialogoSeguimientoState extends State<_DialogoSeguimiento> {
  static const _duraciones = <(int, String)>[
    (3, '3 días'),
    (5, '5 días'),
    (7, '7 días'),
    (14, '14 días'),
    (0, 'Hasta que lo cierre'),
  ];

  late String _motivo;
  late final TextEditingController _detalle;
  late int _dias;
  late TimeOfDay _hora;

  @override
  void initState() {
    super.initState();
    final actual = widget.actual;
    var motivo = actual?.motivo ?? 'ojo';
    if (SeguimientoTipos.de(motivo).motivo != motivo) motivo = 'otro';
    _motivo = motivo;
    _detalle = TextEditingController(text: actual?.detalle ?? '');
    final dias = actual?.diasDuracion ?? 5;
    _dias = _duraciones.any((opcion) => opcion.$1 == dias) ? dias : 5;
    _hora = _horaDeTexto(actual?.hora ?? '18:00');
  }

  @override
  void dispose() {
    _detalle.dispose();
    super.dispose();
  }

  void _guardar() {
    FocusScope.of(context).unfocus();
    final hora =
        '${_hora.hour.toString().padLeft(2, '0')}:${_hora.minute.toString().padLeft(2, '0')}';
    final actual = widget.actual;
    final resultado = actual == null
        ? widget.controller.crear(
            motivo: _motivo,
            detalle: _detalle.text,
            hora: hora,
            fechaInicio: widget.fechaInicial ?? DateTime.now(),
            diasDuracion: _dias,
          )
        : widget.controller.editar(
            actual,
            motivo: _motivo,
            detalle: _detalle.text,
            hora: hora,
            diasDuracion: _dias,
          );
    Navigator.pop(context, resultado);
  }

  @override
  Widget build(BuildContext context) {
    final actual = widget.actual;
    final horaTexto =
        '${_hora.hour.toString().padLeft(2, '0')}:${_hora.minute.toString().padLeft(2, '0')}';
    return AlertDialog(
      scrollable: true,
      title: Text(actual == null ? 'Agregar seguimiento' : 'Editar seguimiento'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final visual in SeguimientoTipos.todos)
                ChoiceChip(
                  avatar: Icon(visual.icono, size: 18, color: visual.colorTexto),
                  label: Text(visual.etiqueta),
                  selected: _motivo == visual.motivo,
                  onSelected: (seleccionado) {
                    if (!seleccionado) return;
                    setState(() => _motivo = visual.motivo);
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _detalle,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Detalle (opcional)',
              helperText: 'Por ejemplo: ojo izquierdo irritado',
              helperMaxLines: 2,
            ),
          ),
          const SizedBox(height: 12),
          Text('Duración', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final opcion in _duraciones)
                ChoiceChip(
                  label: Text(opcion.$2),
                  selected: _dias == opcion.$1,
                  onSelected: (seleccionado) {
                    if (!seleccionado) return;
                    setState(() => _dias = opcion.$1);
                  },
                ),
            ],
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Hora del aviso: $horaTexto'),
            trailing: const Icon(Icons.access_time),
            onTap: () async {
              final seleccionada = await showTimePicker(
                context: context,
                initialTime: _hora,
                builder: (BuildContext context, Widget? child) {
                  return MediaQuery(
                    data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                    child: child!,
                  );
                },
              );
              if (seleccionada == null) return;
              setState(() => _hora = seleccionada);
            },
          ),
          Text(
            'Si la hora de hoy ya pasó, el primer aviso llega mañana.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.paleta.textoSuave),
          ),
          if (actual != null) ...[
            const SizedBox(height: 8),
            Text(
              actual.activo
                  ? 'Los días se cuentan desde el día en que lo creaste.'
                  : 'Está cerrado. Guardar no lo vuelve a abrir.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.paleta.textoSuave),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardar,
          child: Text(actual == null ? 'Agregar' : 'Guardar'),
        ),
      ],
    );
  }
}

TimeOfDay _horaDeTexto(String hora) {
  final partes = hora.split(':');
  var horas = int.tryParse(partes[0]) ?? 18;
  var minutos = partes.length > 1 ? int.tryParse(partes[1]) ?? 0 : 0;
  if (horas < 0 || horas > 23) horas = 18;
  if (minutos < 0 || minutos > 59) minutos = 0;
  return TimeOfDay(hour: horas, minute: minutos);
}
