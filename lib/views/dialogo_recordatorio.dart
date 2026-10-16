import 'package:flutter/material.dart';

import '../controllers/recordatorio_controller.dart';
import '../models/recordatorio_model.dart';
import '../theme/app_colors.dart';
import '../theme/recordatorio_tipos.dart';

/// Alta o edición. Devuelve el modelo, o null si se cancela.
Future<RecordatorioModel?> mostrarDialogoRecordatorio(
  BuildContext context, {
  required RecordatorioController controller,
  RecordatorioModel? actual,
  DateTime? fechaInicial,
}) {
  return showDialog<RecordatorioModel>(
    context: context,
    builder: (ctx) => _DialogoRecordatorio(
      controller: controller,
      actual: actual,
      fechaInicial: fechaInicial,
    ),
  );
}

class _DialogoRecordatorio extends StatefulWidget {
  final RecordatorioController controller;
  final RecordatorioModel? actual;
  final DateTime? fechaInicial;

  const _DialogoRecordatorio({
    required this.controller,
    this.actual,
    this.fechaInicial,
  });

  @override
  State<_DialogoRecordatorio> createState() => _DialogoRecordatorioState();
}

class _DialogoRecordatorioState extends State<_DialogoRecordatorio> {
  late String _tipo;
  late final TextEditingController _titulo;
  late final TextEditingController _nota;
  late DateTime _fechaHora;
  var _errorFecha = false;
  var _cerrando = false;

  bool get _exigirFutura {
    final actual = widget.actual;
    return actual == null || widget.controller.esVencido(actual);
  }

  @override
  void initState() {
    super.initState();
    final actual = widget.actual;
    _tipo = actual?.tipo ?? 'veterinaria';
    _titulo = TextEditingController(
      text: actual?.titulo ?? RecordatorioTipos.de(_tipo).tituloSugerido,
    );
    _nota = TextEditingController(text: actual?.nota ?? '');
    _fechaHora = actual?.fechaHora ?? widget.fechaInicial ?? _mananaALasNueve();
  }

  @override
  void dispose() {
    _titulo.dispose();
    _nota.dispose();
    super.dispose();
  }

  void _elegirTipo(RecordatorioTipoVisual visual) {
    final sugeridoAnterior = RecordatorioTipos.de(_tipo).tituloSugerido;
    final texto = _titulo.text.trim();
    setState(() {
      _tipo = visual.tipo;
      if (texto.isEmpty || texto == sugeridoAnterior) {
        _titulo.text = visual.tituloSugerido;
      }
    });
  }

  void _guardar() {
    if (_cerrando) return;
    final titulo = _titulo.text.trim();
    if (titulo.isEmpty) return;
    if (_exigirFutura && !_fechaHora.isAfter(DateTime.now())) {
      setState(() => _errorFecha = true);
      return;
    }
    final actual = widget.actual;
    final guardado = actual == null
        ? widget.controller.crear(
            tipo: _tipo,
            titulo: titulo,
            nota: _nota.text,
            fechaHora: _fechaHora,
          )
        : widget.controller.editar(
            actual,
            tipo: _tipo,
            titulo: titulo,
            nota: _nota.text,
            fechaHora: _fechaHora,
          );
    _cerrando = true;
    Navigator.pop(context, guardado);
  }

  @override
  Widget build(BuildContext context) {
    final actual = widget.actual;
    final hoy = DateTime.now();
    final primerDia = DateTime(hoy.year, hoy.month, hoy.day);
    final fechaInicial = _fechaHora.isBefore(primerDia) ? primerDia : _fechaHora;
    final fechaTexto =
        '${_fechaHora.day.toString().padLeft(2, '0')}/${_fechaHora.month.toString().padLeft(2, '0')}/${_fechaHora.year}';
    final horaTexto =
        '${_fechaHora.hour.toString().padLeft(2, '0')}:${_fechaHora.minute.toString().padLeft(2, '0')}';

    return AlertDialog(
      title: Text(actual == null ? 'Agendar recordatorio' : 'Editar recordatorio'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final visual in RecordatorioTipos.todos) ...[
              _FilaTipo(
                visual: visual,
                seleccionado: _tipo == visual.tipo,
                alElegir: () => _elegirTipo(visual),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: _titulo,
              scrollPadding: EdgeInsets.zero,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Título'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Fecha: $fechaTexto'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final seleccionada = await showDatePicker(
                  context: context,
                  initialDate: fechaInicial,
                  firstDate: primerDia,
                  lastDate: DateTime(2100),
                );
                if (seleccionada == null) return;
                setState(() {
                  _fechaHora = DateTime(
                    seleccionada.year,
                    seleccionada.month,
                    seleccionada.day,
                    _fechaHora.hour,
                    _fechaHora.minute,
                  );
                  _errorFecha = false;
                });
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Hora: $horaTexto'),
              trailing: const Icon(Icons.access_time),
              onTap: () async {
                final seleccionada = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(_fechaHora),
                  builder: (context, child) {
                    return MediaQuery(
                      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                      child: child!,
                    );
                  },
                );
                if (seleccionada == null) return;
                setState(() {
                  _fechaHora = DateTime(
                    _fechaHora.year,
                    _fechaHora.month,
                    _fechaHora.day,
                    seleccionada.hour,
                    seleccionada.minute,
                  );
                  _errorFecha = false;
                });
              },
            ),
            if (_errorFecha)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Elegí una fecha y hora futuras',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.error),
                ),
              ),
            TextField(
              controller: _nota,
              scrollPadding: EdgeInsets.zero,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nota (opcional)'),
            ),
          ],
        ),
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

class _FilaTipo extends StatelessWidget {
  final RecordatorioTipoVisual visual;
  final bool seleccionado;
  final VoidCallback alElegir;

  const _FilaTipo({
    required this.visual,
    required this.seleccionado,
    required this.alElegir,
  });

  @override
  Widget build(BuildContext context) {
    final borde = seleccionado ? visual.color : context.paleta.borde;
    return Material(
      color: seleccionado ? visual.color.withValues(alpha: 0.12) : context.paleta.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borde, width: seleccionado ? 1.6 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: alElegir,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: visual.color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(visual.icono, size: 18, color: visual.colorTexto),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(visual.etiqueta)),
              if (seleccionado) Icon(Icons.check, color: visual.colorTexto),
            ],
          ),
        ),
      ),
    );
  }
}

DateTime _mananaALasNueve() {
  final manana = DateTime.now().add(const Duration(days: 1));
  return DateTime(manana.year, manana.month, manana.day, 9, 0);
}
