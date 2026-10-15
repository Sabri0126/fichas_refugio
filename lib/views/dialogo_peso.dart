import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/peso_controller.dart';
import '../models/peso_model.dart';

/// Diálogo de alta o edición. Devuelve el modelo listo, o null si se cancela.
/// El `setState` del llamador va después de que este future termina.
Future<PesoModel?> mostrarDialogoPeso(
  BuildContext context, {
  required PesoController controller,
  PesoModel? actual,
}) {
  return showDialog<PesoModel>(
    context: context,
    builder: (ctx) => _DialogoPeso(controller: controller, actual: actual),
  );
}

class _DialogoPeso extends StatefulWidget {
  final PesoController controller;
  final PesoModel? actual;

  const _DialogoPeso({required this.controller, this.actual});

  @override
  State<_DialogoPeso> createState() => _DialogoPesoState();
}

class _DialogoPesoState extends State<_DialogoPeso> {
  late final TextEditingController _kgController;
  late final TextEditingController _notaController;
  late DateTime _fecha;
  late bool _estimado;
  var _error = '';
  var _cerrando = false;

  @override
  void initState() {
    super.initState();
    final actual = widget.actual;
    _kgController = TextEditingController(
      text: actual == null ? '' : formatearKg(actual.kg),
    );
    _notaController = TextEditingController(text: actual?.nota ?? '');
    _fecha = actual?.fecha ?? DateTime.now();
    _estimado = actual?.estimado ?? false;
  }

  @override
  void dispose() {
    _kgController.dispose();
    _notaController.dispose();
    super.dispose();
  }

  void _guardar() {
    if (_cerrando) return;
    final kg = parsearKg(_kgController.text);
    if (kg == null) {
      setState(() => _error = 'Ingresá un peso en kilos, por ejemplo 12,5.');
      return;
    }
    final actual = widget.actual;
    final modelo = actual == null
        ? widget.controller.crear(
            kg: kg,
            fecha: _fecha,
            estimado: _estimado,
            nota: _notaController.text,
          )
        : widget.controller.editar(
            actual,
            kg: kg,
            fecha: _fecha,
            estimado: _estimado,
            nota: _notaController.text,
          );
    _cerrando = true;
    Navigator.pop(context, modelo);
  }

  /// El tilde del teclado llega en medio del cierre del IME. Guardar en ese
  /// momento pelea el foco con el diálogo y la app deja de responder.
  void _guardarDesdeTeclado() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _guardar();
    });
  }

  @override
  Widget build(BuildContext context) {
    final actual = widget.actual;
    return AlertDialog(
      scrollable: true,
      title: Text(actual == null ? 'Agregar peso' : 'Editar peso'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _kgController,
            autofocus: actual == null,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            scrollPadding: EdgeInsets.zero,
            onEditingComplete: _guardarDesdeTeclado,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            decoration: InputDecoration(
              labelText: 'Kilos',
              hintText: '12,5',
              suffixText: 'kg',
              errorText: _error.isEmpty ? null : _error,
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Fecha: ${PesoController.formatearFecha(_fecha)}'),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: () async {
              final hoy = DateTime.now();
              final tope = DateTime(hoy.year, hoy.month, hoy.day);
              final inicial = _fecha.isAfter(tope) ? tope : _fecha;
              final elegida = await showDatePicker(
                context: context,
                initialDate: inicial,
                firstDate: DateTime(2000),
                lastDate: tope,
              );
              if (elegida == null) return;
              setState(() => _fecha = elegida);
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Peso estimado'),
            subtitle: const Text('Marcalo si es un aproximado.'),
            value: _estimado,
            onChanged: (valor) => setState(() => _estimado = valor),
          ),
          TextField(
            controller: _notaController,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            scrollPadding: EdgeInsets.zero,
            onEditingComplete: _guardarDesdeTeclado,
            decoration: const InputDecoration(
              labelText: 'Nota (opcional)',
            ),
          ),
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
