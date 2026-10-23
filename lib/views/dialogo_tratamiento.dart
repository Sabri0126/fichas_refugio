import 'package:flutter/material.dart';

import '../controllers/historial_notificaciones_controller.dart';
import '../controllers/tratamiento_controller.dart';
import '../models/tratamiento_model.dart';
import '../services/mensajeria_service.dart';
import '../theme/app_colors.dart';
import '../theme/category_colors.dart';

enum _AlcanceAviso { todos, esteCelular, nadie }

/// Las seis categorías del alta, en el orden de la grilla.
const categoriasRegistroMedico = <(String, String)>[
  ('diario', 'Tratamiento Diario'),
  ('unico', 'Dosis Única'),
  ('higiene', 'Higiene'),
  ('evento', 'Evento Médico'),
  ('veterinaria', 'Veterinaria'),
  ('vacuna', 'Vacuna'),
];

/// Dos columnas cuando cada una alcanza para el ícono y el nombre entero.
/// En un teléfono queda una columna, para que no se corte el texto.
class GrillaRegistrosMedicos extends StatelessWidget {
  final ValueChanged<String> alElegir;

  const GrillaRegistrosMedicos({super.key, required this.alElegir});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const espacio = 12.0;
        const anchoMinimo = 220.0;
        final disponible = constraints.maxWidth.isFinite ? constraints.maxWidth : 360.0;
        final columnas = disponible >= anchoMinimo * 2 + espacio ? 2 : 1;
        final anchoCelda = columnas == 1 ? disponible : (disponible - espacio) / 2;
        return Wrap(
          spacing: espacio,
          runSpacing: espacio,
          children: [
            for (final categoria in categoriasRegistroMedico)
              SizedBox(
                width: anchoCelda,
                child: _BotonCategoria(
                  etiqueta: categoria.$2,
                  categoria: categoria.$1,
                  alElegir: () => alElegir(categoria.$1),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _BotonCategoria extends StatelessWidget {
  final String etiqueta;
  final String categoria;
  final VoidCallback alElegir;

  const _BotonCategoria({
    required this.etiqueta,
    required this.categoria,
    required this.alElegir,
  });

  @override
  Widget build(BuildContext context) {
    final color = CategoryColors.base(categoria);
    final colorTexto = CategoryColors.texto(categoria);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: alElegir,
        style: OutlinedButton.styleFrom(
          backgroundColor: context.paleta.superficie,
          foregroundColor: colorTexto,
          side: BorderSide(color: context.paleta.borde),
          minimumSize: const Size.fromHeight(56),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          alignment: Alignment.centerLeft,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(CategoryColors.icono(categoria), size: 20, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                etiqueta,
                maxLines: 2,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorTexto,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Alta de un registro. Devuelve el modelo, o null si se cancela.
Future<TratamientoModel?> mostrarDialogoTratamiento(
  BuildContext context, {
  required TratamientoController controller,
  required String categoria,
  DateTime? fechaInicial,
}) {
  return showDialog<TratamientoModel>(
    context: context,
    builder: (ctx) => _DialogoTratamiento(
      controller: controller,
      categoria: categoria,
      fechaInicial: fechaInicial ?? DateTime.now(),
    ),
  );
}

/// Edición. Conserva id, categoría, dosis registradas y el resto de los datos.
Future<TratamientoModel?> mostrarDialogoEditarTratamiento(
  BuildContext context, {
  required TratamientoController controller,
  required TratamientoModel actual,
}) {
  return showDialog<TratamientoModel>(
    context: context,
    builder: (ctx) => _DialogoTratamiento(
      controller: controller,
      categoria: actual.categoria,
      actual: actual,
    ),
  );
}

class _DialogoTratamiento extends StatefulWidget {
  final TratamientoController controller;
  final String categoria;
  final TratamientoModel? actual;
  final DateTime? fechaInicial;

  const _DialogoTratamiento({
    required this.controller,
    required this.categoria,
    this.actual,
    this.fechaInicial,
  });

  @override
  State<_DialogoTratamiento> createState() => _DialogoTratamientoState();
}

class _DialogoTratamientoState extends State<_DialogoTratamiento> {
  late final TextEditingController _medicacion;
  late final TextEditingController _indicaciones;
  late final TextEditingController _notas;
  late final TextEditingController _veterinario;
  late final TextEditingController _diagnostico;
  late final TextEditingController _dias;
  late DateTime _fecha;
  late TimeOfDay _hora;
  var _cerrando = false;
  var _alcance = _AlcanceAviso.todos;
  var _avisoListo = true;

  bool get _esDiario => widget.categoria == 'diario';

  String? get _rotuloNotas => switch (widget.categoria) {
        'unico' => 'Razón de la aplicación / Notas',
        'vacuna' => 'Notas (opcional)',
        _ => null,
      };

  @override
  void initState() {
    super.initState();
    final actual = widget.actual;
    _medicacion = TextEditingController(text: actual?.medicacion ?? '');
    _indicaciones = TextEditingController(text: actual?.indicaciones ?? '');
    _notas = TextEditingController(text: actual?.notas ?? '');
    _veterinario = TextEditingController(text: actual?.veterinario ?? '');
    _diagnostico = TextEditingController(text: actual?.diagnostico ?? '');
    _dias = TextEditingController(text: (actual?.diasDuracion ?? 0).toString());
    _fecha = actual?.fechaInicio ?? widget.fechaInicial ?? DateTime.now();
    final partes = (actual?.horaRecordatorio ?? '09:00').split(':');
    _hora = TimeOfDay(
      hour: int.tryParse(partes.isNotEmpty ? partes[0] : '') ?? 9,
      minute: int.tryParse(partes.length > 1 ? partes[1] : '') ?? 0,
    );
    if (_esDiario && actual != null && !actual.notificar) {
      _alcance = _AlcanceAviso.nadie;
    }
    _avisoListo = !_esDiario || actual == null || !actual.notificar;
    if (!_avisoListo) _leerSilencioDeEsteCelular();
  }

  Future<void> _leerSilencioDeEsteCelular() async {
    final id = widget.actual?.id ?? '';
    try {
      final ids = await MensajeriaService.leerSilenciados();
      if (!mounted) return;
      setState(() {
        if (ids.contains(id)) _alcance = _AlcanceAviso.esteCelular;
        _avisoListo = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _avisoListo = true);
    }
  }

  @override
  void dispose() {
    _medicacion.dispose();
    _indicaciones.dispose();
    _notas.dispose();
    _veterinario.dispose();
    _diagnostico.dispose();
    _dias.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_cerrando || !_avisoListo) return;
    final medicacion = _medicacion.text.trim();
    if (medicacion.isEmpty) return;
    _cerrando = true;
    final hora =
        '${_hora.hour.toString().padLeft(2, '0')}:${_hora.minute.toString().padLeft(2, '0')}';
    final notas = _rotuloNotas == null ? (widget.actual?.notas ?? '') : _notas.text.trim();
    final esVisita = widget.categoria == 'veterinaria';
    final veterinario = esVisita ? _veterinario.text.trim() : (widget.actual?.veterinario ?? '');
    final diagnostico = esVisita ? _diagnostico.text.trim() : (widget.actual?.diagnostico ?? '');
    final actual = widget.actual;
    final avisa = _alcance != _AlcanceAviso.nadie;
    final modelo = actual == null
        ? widget.controller.crearTratamiento(
            categoria: widget.categoria,
            medicacion: medicacion,
            indicaciones: _indicaciones.text.trim(),
            notas: notas,
            veterinario: veterinario,
            diagnostico: diagnostico,
            fechaInicio: _fecha,
            diasDuracion: int.tryParse(_dias.text.trim()) ?? 0,
            horaRecordatorio: hora,
            notificar: _esDiario ? avisa : true,
          )
        : widget.controller.editarTratamiento(
            actual,
            medicacion: medicacion,
            indicaciones: _indicaciones.text.trim(),
            notas: notas,
            veterinario: veterinario,
            diagnostico: diagnostico,
            diasDuracion: _esDiario ? (int.tryParse(_dias.text.trim()) ?? 0) : actual.diasDuracion,
            fechaInicio: _fecha,
            horaRecordatorio: _esDiario ? hora : (actual.horaRecordatorio ?? hora),
            notificar: _esDiario ? avisa : null,
          );
    if (_esDiario) {
      try {
        await MensajeriaService.instance.definirSilencio(
          modelo.id,
          silenciar: _alcance == _AlcanceAviso.esteCelular,
        );
        HistorialNotificacionesController.refrescar();
      } catch (_) {
        _cerrando = false;
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar el aviso de este celular.')),
        );
        return;
      }
    }
    if (!mounted) return;
    Navigator.pop(context, modelo);
  }

  Widget _opcionAviso(_AlcanceAviso valor, String texto) {
    final elegido = _alcance == valor;
    return InkWell(
      onTap: _avisoListo ? () => setState(() => _alcance = valor) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              elegido ? Icons.radio_button_checked : Icons.radio_button_off,
              color: elegido ? AppColors.navy : context.paleta.textoSuave,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(texto)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final actual = widget.actual;
    final fecha =
        '${_fecha.day.toString().padLeft(2, '0')}/${_fecha.month.toString().padLeft(2, '0')}/${_fecha.year}';
    final hora =
        '${_hora.hour.toString().padLeft(2, '0')}:${_hora.minute.toString().padLeft(2, '0')}';
    final rotuloNotas = _rotuloNotas;

    return AlertDialog(
      title: Text(actual == null ? _tituloAlta(widget.categoria) : 'Editar tratamiento'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.categoria == 'veterinaria') ...[
              TextField(
                controller: _veterinario,
                scrollPadding: EdgeInsets.zero,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre del veterinario o la veterinaria',
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _medicacion,
              scrollPadding: EdgeInsets.zero,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: _rotuloMedicacion(widget.categoria)),
            ),
            const SizedBox(height: 16),
            if (widget.categoria == 'veterinaria') ...[
              TextField(
                controller: _diagnostico,
                scrollPadding: EdgeInsets.zero,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Diagnóstico'),
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _indicaciones,
              scrollPadding: EdgeInsets.zero,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: _rotuloIndicaciones(widget.categoria)),
            ),
            if (rotuloNotas != null) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _notas,
                scrollPadding: EdgeInsets.zero,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: rotuloNotas),
              ),
            ],
            if (_esDiario) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _dias,
                scrollPadding: EdgeInsets.zero,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Días de duración (0 = indefinido)',
                  helperText: _helperDias(_dias.text, _fecha),
                  helperMaxLines: 2,
                ),
              ),
            ],
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${_rotuloFecha(widget.categoria)}: $fecha'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final seleccionada = await showDatePicker(
                  context: context,
                  initialDate: _fecha,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (seleccionada == null) return;
                setState(() => _fecha = seleccionada);
              },
            ),
            if (_esDiario)
              InkWell(
                onTap: () async {
                  final seleccionada = await showTimePicker(
                    context: context,
                    initialTime: _hora,
                    builder: (context, child) {
                      return MediaQuery(
                        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                        child: child!,
                      );
                    },
                  );
                  if (seleccionada == null) return;
                  setState(() => _hora = seleccionada);
                },
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Hora del recordatorio: $hora'),
                  trailing: const Icon(Icons.access_time),
                ),
              ),
            if (_esDiario) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'La dosis se marca igual a la hora elegida. Esto solo corta el aviso.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 4),
              _opcionAviso(_AlcanceAviso.todos, 'Avisar en todos los celulares'),
              _opcionAviso(_AlcanceAviso.esteCelular, 'No avisar en este celular'),
              _opcionAviso(_AlcanceAviso.nadie, 'No avisar en ningún celular de administrador'),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _avisoListo ? _guardar : null,
          child: Text(actual == null ? 'Agregar' : 'Guardar'),
        ),
      ],
    );
  }
}

String _tituloAlta(String categoria) => switch (categoria) {
      'unico' => 'Agregar dosis única',
      'higiene' => 'Agregar higiene',
      'evento' => 'Agregar evento médico',
      'veterinaria' => 'Agregar visita veterinaria',
      'vacuna' => 'Agregar vacuna',
      _ => 'Agregar tratamiento diario',
    };

String _rotuloMedicacion(String categoria) => switch (categoria) {
      'veterinaria' => 'Motivo de visita',
      'unico' => 'Medicación / Aplicación',
      'higiene' => 'Procedimiento / Cuidado',
      'evento' => 'Evento / Motivo',
      'vacuna' => 'Nombre de la vacuna',
      _ => 'Medicación',
    };

String _rotuloIndicaciones(String categoria) => switch (categoria) {
      'veterinaria' => 'Indicaciones',
      'evento' => 'Notas / Indicaciones',
      'unico' || 'vacuna' => 'Dosis administrada',
      'higiene' => 'Notas (opcional)',
      _ => 'Indicaciones',
    };

String _rotuloFecha(String categoria) => switch (categoria) {
      'veterinaria' => 'Fecha de visita',
      'unico' || 'vacuna' => 'Fecha de aplicación',
      'higiene' => 'Fecha',
      'evento' => 'Fecha del evento',
      _ => 'Fecha de inicio',
    };

String _helperDias(String texto, DateTime inicio) {
  final dias = int.tryParse(texto.trim()) ?? 0;
  if (dias <= 0) return 'Sin fecha de fin.';
  final ultimo = DateTime(inicio.year, inicio.month, inicio.day + dias - 1);
  final dia = ultimo.day.toString().padLeft(2, '0');
  final mes = ultimo.month.toString().padLeft(2, '0');
  return 'El día de inicio cuenta como día 1. Último día de medicación: $dia/$mes/${ultimo.year}';
}
