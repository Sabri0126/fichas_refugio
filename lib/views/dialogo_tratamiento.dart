import 'package:flutter/material.dart';

import '../controllers/historial_notificaciones_controller.dart';
import '../controllers/tratamiento_controller.dart';
import '../models/tratamiento_model.dart';
import '../services/mensajeria_service.dart';
import '../theme/app_colors.dart';
import '../theme/category_colors.dart';
import '../util/plataforma.dart';

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
        final columnas = esAndroid || disponible >= anchoMinimo * 2 + espacio ? 2 : 1;
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
  String? titulo,
  bool preguntarCambioDosis = true,
}) {
  return showDialog<TratamientoModel>(
    context: context,
    builder: (ctx) => _DialogoTratamiento(
      controller: controller,
      categoria: actual.categoria,
      actual: actual,
      titulo: titulo,
      preguntarCambioDosis: preguntarCambioDosis,
    ),
  );
}

class _DialogoTratamiento extends StatefulWidget {
  final TratamientoController controller;
  final String categoria;
  final TratamientoModel? actual;
  final DateTime? fechaInicial;
  final String? titulo;
  final bool preguntarCambioDosis;

  const _DialogoTratamiento({
    required this.controller,
    required this.categoria,
    this.actual,
    this.fechaInicial,
    this.titulo,
    this.preguntarCambioDosis = true,
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
  late String _tipo;
  DateTime? _fechaSuspension;
  var _cerrando = false;
  var _alcance = _AlcanceAviso.todos;
  var _avisoListo = true;
  var _guardando = false;
  var _puedeCerrar = false;
  var _cerrandoRuta = false;
  var _preguntandoSalida = false;
  var _errorNombre = false;
  var _errorDias = false;
  final _claveNombre = GlobalKey();
  final _claveDias = GlobalKey();
  final _focoNombre = FocusNode();
  final _focoDias = FocusNode();
  late String _med0;
  late String _ind0;
  late String _notas0;
  late String _vet0;
  late String _diag0;
  late String _dias0;
  late String _tipo0;
  late DateTime _fecha0;
  late TimeOfDay _hora0;
  DateTime? _susp0;
  late _AlcanceAviso _alcance0;

  bool get _esDiario => widget.categoria == 'diario';

  String get _pistaToque => esAndroid ? 'Tocá para cambiar.' : 'Hacé clic para cambiar.';

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
    _tipo = actual?.tipoDuracion ?? TratamientoModel.tipoHastaAviso;
    final diasIniciales = actual?.diasDuracion ?? 0;
    _dias = TextEditingController(text: diasIniciales > 0 ? diasIniciales.toString() : '');
    _fecha = actual?.fechaInicio ?? widget.fechaInicial ?? DateTime.now();
    if (actual != null && !actual.activo && actual.categoria == 'diario') {
      final etiqueta = TratamientoController.etiquetaEstado(actual);
      if (actual.fechaSuspension != null || etiqueta != 'Finalizado') {
        _fechaSuspension = actual.fechaSuspension ??
            TratamientoController.periodoEfectivo(actual)?.fin ??
            DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      }
    }
    final partes = (actual?.horaRecordatorio ?? '09:00').split(':');
    _hora = TimeOfDay(
      hour: int.tryParse(partes.isNotEmpty ? partes[0] : '') ?? 9,
      minute: int.tryParse(partes.length > 1 ? partes[1] : '') ?? 0,
    );
    if (_esDiario && actual != null && !actual.notificar) {
      _alcance = _AlcanceAviso.nadie;
    }
    _avisoListo = !_esDiario || actual == null || !actual.notificar;
    _guardarReferencia();
    if (!_avisoListo) _leerSilencioDeEsteCelular();
  }

  void _guardarReferencia() {
    _med0 = _medicacion.text;
    _ind0 = _indicaciones.text;
    _notas0 = _notas.text;
    _vet0 = _veterinario.text;
    _diag0 = _diagnostico.text;
    _dias0 = _dias.text;
    _tipo0 = _tipo;
    _fecha0 = _fecha;
    _hora0 = _hora;
    _susp0 = _fechaSuspension;
    _alcance0 = _alcance;
  }

  bool _mismoDia(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  bool get _hayCambios {
    if (_medicacion.text != _med0 || _indicaciones.text != _ind0 || _notas.text != _notas0) return true;
    if (_veterinario.text != _vet0 || _diagnostico.text != _diag0 || _dias.text != _dias0) return true;
    if (_tipo != _tipo0 || _hora != _hora0 || _alcance != _alcance0) return true;
    if (!_mismoDia(_fecha, _fecha0)) return true;
    final suspension = _fechaSuspension;
    final inicial = _susp0;
    if ((suspension == null) != (inicial == null)) return true;
    if (suspension != null && inicial != null && !_mismoDia(suspension, inicial)) return true;
    return false;
  }

  Future<void> _leerSilencioDeEsteCelular() async {
    final id = widget.actual?.id ?? '';
    try {
      final ids = await MensajeriaService.leerSilenciados();
      if (!mounted) return;
      setState(() {
        if (ids.contains(id)) _alcance = _AlcanceAviso.esteCelular;
        _alcance0 = _alcance;
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
    _focoNombre.dispose();
    _focoDias.dispose();
    super.dispose();
  }

  Future<bool> _marcarErroresYEnfocar() async {
    final sinNombre = _medicacion.text.trim().isEmpty;
    final sinDias = _esDiario &&
        _tipo == TratamientoModel.tipoDias &&
        (int.tryParse(_dias.text.trim()) ?? 0) < 1;
    if (!sinNombre && !sinDias) return false;
    setState(() {
      _errorNombre = sinNombre;
      _errorDias = sinDias;
    });
    final clave = sinNombre ? _claveNombre : _claveDias;
    final foco = sinNombre ? _focoNombre : _focoDias;
    final destino = clave.currentContext;
    if (destino != null) {
      await Scrollable.ensureVisible(
        destino,
        alignment: 0.2,
        duration: const Duration(milliseconds: 250),
      );
    }
    if (!mounted) return true;
    foco.requestFocus();
    return true;
  }

  Future<void> _intentarGuardar() async {
    if (_guardando || _cerrando || _cerrandoRuta || !_avisoListo) return;
    if (await _marcarErroresYEnfocar()) return;
    if (!mounted || _cerrando || _cerrandoRuta) return;
    setState(() => _guardando = true);
    try {
      await _guardar();
    } finally {
      if (mounted && !_puedeCerrar) setState(() => _guardando = false);
    }
  }

  Future<void> _alIntentarCerrar(bool yaCerro, Object? resultado) async {
    if (yaCerro || _cerrandoRuta || _preguntandoSalida || _guardando) return;
    if (resultado is TratamientoModel || !_hayCambios) {
      await _cerrarDeVerdad(resultado);
      return;
    }
    _preguntandoSalida = true;
    final salir = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Salir sin guardar?'),
        content: const Text('Se pierde lo que cargaste.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salir'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Seguir editando'),
          ),
        ],
      ),
    );
    _preguntandoSalida = false;
    if (salir == true) await _cerrarDeVerdad(null);
  }

  Future<void> _cerrarDeVerdad(Object? resultado) async {
    if (_cerrandoRuta) return;
    _cerrandoRuta = true;
    setState(() => _puedeCerrar = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    Navigator.pop(context, resultado);
  }

  Future<void> _guardar() async {
    if (_cerrando || !_avisoListo) return;
    final medicacion = _medicacion.text.trim();
    final dias = _esDiario && _tipo == TratamientoModel.tipoDias
        ? (int.tryParse(_dias.text.trim()) ?? 0)
        : 0;
    if (medicacion.isEmpty || (_esDiario && _tipo == TratamientoModel.tipoDias && dias < 1)) {
      return;
    }
    _cerrando = true;
    final hora =
        '${_hora.hour.toString().padLeft(2, '0')}:${_hora.minute.toString().padLeft(2, '0')}';
    final notas = _rotuloNotas == null ? (widget.actual?.notas ?? '') : _notas.text.trim();
    final esVisita = widget.categoria == 'veterinaria';
    final veterinario = esVisita ? _veterinario.text.trim() : (widget.actual?.veterinario ?? '');
    final diagnostico = esVisita ? _diagnostico.text.trim() : (widget.actual?.diagnostico ?? '');
    final actual = widget.actual;
    final avisa = _alcance != _AlcanceAviso.nadie;
    var modelo = actual == null
        ? widget.controller.crearTratamiento(
            categoria: widget.categoria,
            medicacion: medicacion,
            indicaciones: _indicaciones.text.trim(),
            notas: notas,
            veterinario: veterinario,
            diagnostico: diagnostico,
            fechaInicio: _fecha,
            diasDuracion: dias,
            horaRecordatorio: hora,
            notificar: _esDiario ? avisa : true,
            tipoDuracion: _tipo,
          )
        : widget.controller.editarTratamiento(
            actual,
            medicacion: medicacion,
            indicaciones: _indicaciones.text.trim(),
            notas: notas,
            veterinario: veterinario,
            diagnostico: diagnostico,
            diasDuracion: _esDiario ? dias : actual.diasDuracion,
            fechaInicio: _fecha,
            horaRecordatorio: _esDiario ? hora : (actual.horaRecordatorio ?? hora),
            notificar: _esDiario ? avisa : null,
            tipoDuracion: _esDiario ? _tipo : null,
            fechaSuspension: _fechaSuspension,
          );
    if (_esDiario && actual != null && widget.preguntarCambioDosis) {
      final nueva = _indicaciones.text.trim();
      if (nueva != actual.indicaciones.trim()) {
        final eleccion = await _preguntarCambioOCorreccion();
        if (!mounted) return;
        if (eleccion == null) {
          _cerrando = false;
          return;
        }
        final base = modelo.copyWith(
          indicaciones: actual.indicaciones,
          cambiosDosis: actual.cambiosDosis,
        );
        if (eleccion == 'cambio') {
          final hoy = DateTime.now();
          final hoyFecha = DateTime(hoy.year, hoy.month, hoy.day);
          final comienzo = DateTime(_fecha.year, _fecha.month, _fecha.day);
          final desde = await showDatePicker(
            context: context,
            initialDate: hoyFecha.isBefore(comienzo) ? comienzo : hoyFecha,
            firstDate: comienzo,
            lastDate: hoyFecha.isBefore(comienzo) ? comienzo : hoyFecha,
            helpText: 'Desde cuándo rige la dosis nueva',
          );
          if (!mounted || desde == null) {
            _cerrando = false;
            return;
          }
          modelo = TratamientoController.cambiarDosis(base, nueva, desde: desde);
        } else {
          modelo = TratamientoController.corregirTextoDosis(base, nueva);
        }
      }
    }
    if (_esDiario && actual != null) {
      final fuera = TratamientoController.dosisFueraDePeriodo(modelo);
      if (fuera.isNotEmpty) {
        final borrar = await _ofrecerBorrarDosisFuera(fuera.length);
        if (!mounted) return;
        if (borrar == true) {
          modelo = TratamientoController.quitarDosisFueraDePeriodo(modelo);
        }
      }
    }
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
    if (!mounted || _cerrandoRuta) return;
    _cerrandoRuta = true;
    Navigator.pop(context, modelo);
  }

  Future<String?> _preguntarCambioOCorreccion() {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cambió la dosis'),
        content: const Text('¿Es un cambio de dosis o una corrección del texto?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'correccion'),
            child: const Text('Corrección'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'cambio'),
            child: const Text('Cambio de dosis'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _ofrecerBorrarDosisFuera(int cantidad) {
    final texto = cantidad == 1
        ? 'Hay 1 dosis registrada fuera del período. ¿Querés borrarla?'
        : 'Hay $cantidad dosis registradas fuera del período. ¿Querés borrarlas?';
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dosis fuera del período'),
        content: Text(texto),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
  }

  Widget _opcionAviso(_AlcanceAviso valor, String texto) {
    final elegido = _alcance == valor;
    return InkWell(
      onTap: _avisoListo ? () => setState(() => _alcance = valor) : null,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: esAndroid ? 10 : 6),
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

  Future<void> _elegirFecha() async {
    final seleccionada = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (seleccionada == null) return;
    setState(() => _fecha = seleccionada);
  }

  Future<void> _elegirSuspension() async {
    final hoy = DateTime.now();
    final hoyFecha = DateTime(hoy.year, hoy.month, hoy.day);
    final comienzo = DateTime(_fecha.year, _fecha.month, _fecha.day);
    final actual = _fechaSuspension!;
    final inicial = actual.isBefore(comienzo)
        ? comienzo
        : (actual.isAfter(hoyFecha) ? hoyFecha : actual);
    final seleccionada = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: comienzo,
      lastDate: hoyFecha.isBefore(comienzo) ? comienzo : hoyFecha,
    );
    if (seleccionada == null) return;
    setState(() => _fechaSuspension = seleccionada);
  }

  Future<void> _elegirHora() async {
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
  }

  String _tituloDialogo() {
    final propio = widget.titulo;
    if (propio != null) return propio;
    if (widget.actual == null) return _tituloAlta(widget.categoria);
    return _tituloEdicion(widget.categoria);
  }

  @override
  Widget build(BuildContext context) {
    final fecha = _fechaTexto(_fecha);
    final hora =
        '${_hora.hour.toString().padLeft(2, '0')}:${_hora.minute.toString().padLeft(2, '0')}';
    if (esAndroid) return _pantallaAndroid(context, fecha: fecha, hora: hora);

    return PopScope<Object?>(
      canPop: _puedeCerrar,
      onPopInvokedWithResult: (yaCerro, resultado) {
        _alIntentarCerrar(yaCerro, resultado);
      },
      child: AlertDialog(
        scrollable: true,
        title: Text(_tituloDialogo()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ..._seccionDatos(widget.categoria),
            if (_esDiario) ...[
              ..._duracionWindows(),
              ..._cuandoYAvisosWindows(fecha, hora),
            ] else ...[
              ..._seccionFecha(widget.categoria, fecha),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: _guardando ? null : () => Navigator.maybePop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: _avisoListo ? _intentarGuardar : null,
            child: _guardando ? _indicadorGuardado() : Text(_textoBotonAndroid()),
          ),
        ],
      ),
    );
  }

  Widget _indicadorGuardado() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
        const SizedBox(width: 8),
        Text(_textoBotonAndroid()),
      ],
    );
  }

  List<Widget> _duracionWindows() {
    return [
      const SizedBox(height: 24),
      _tituloSeccion('Duración'),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SegmentedButton<String>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: TratamientoModel.tipoDias, label: Text('Días fijos')),
            ButtonSegment(value: TratamientoModel.tipoHastaAviso, label: Text('Hasta nuevo aviso')),
            ButtonSegment(value: TratamientoModel.tipoDePorVida, label: Text('De por vida')),
          ],
          selected: {_tipo},
          onSelectionChanged: (elegido) => setState(() {
            _tipo = elegido.first;
            if (_tipo != TratamientoModel.tipoDias) _errorDias = false;
          }),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        _ayudaDuracion(_tipo, _dias.text, _fecha),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      if (_tipo == TratamientoModel.tipoDias) ...[
        const SizedBox(height: 12),
        _campoDias(),
      ],
    ];
  }

  List<Widget> _cuandoYAvisosWindows(String fecha, String hora) {
    return [
      const SizedBox(height: 24),
      _tituloSeccion('¿Cuándo empieza?'),
      _pistaSeccion(_pistaToque),
      _filaFechaHora(fecha: fecha, hora: hora),
      if (_fechaSuspension != null) ...[
        const SizedBox(height: 12),
        _tileValor(
          icono: Icons.event_busy_outlined,
          etiqueta: 'Suspendido el',
          valor: _fechaTexto(_fechaSuspension!),
          alTocar: _elegirSuspension,
        ),
      ],
      const SizedBox(height: 8),
      Text(
        'La dosis se marca igual a la hora elegida. Esto solo corta el aviso.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 4),
      _opcionAviso(_AlcanceAviso.todos, 'Avisar en todos los celulares'),
      _opcionAviso(_AlcanceAviso.esteCelular, 'No avisar en este celular'),
      _opcionAviso(_AlcanceAviso.nadie, 'No avisar en ningún celular de administrador'),
    ];
  }

  String _textoBotonAndroid() {
    if (widget.actual != null) return 'Guardar cambios';
    return switch (widget.categoria) {
      'unico' => 'Agregar dosis',
      'higiene' => 'Agregar higiene',
      'evento' => 'Agregar evento',
      'veterinaria' => 'Agregar visita',
      'vacuna' => 'Agregar vacuna',
      _ => 'Agregar tratamiento',
    };
  }

  Widget _pantallaAndroid(BuildContext context, {required String fecha, required String hora}) {
    final categoria = widget.categoria;
    return Dialog.fullscreen(
      child: PopScope<Object?>(
        canPop: _puedeCerrar,
        onPopInvokedWithResult: (yaCerro, resultado) {
          _alIntentarCerrar(yaCerro, resultado);
        },
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Cancelar',
              onPressed: _guardando ? null : () => Navigator.maybePop(context),
            ),
            title: Text(_tituloDialogo()),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            children: [
              _encabezadoTipo(categoria),
              const SizedBox(height: 24),
              ..._seccionDatos(categoria),
              if (_esDiario) ..._seccionDiaria(fecha, hora) else ..._seccionFecha(categoria, fecha),
            ],
          ),
          bottomNavigationBar: _barraGuardar(),
        ),
      ),
    );
  }

  Widget _barraGuardar() {
    return Container(
      decoration: BoxDecoration(
        color: context.paleta.superficie,
        border: Border(top: BorderSide(color: context.paleta.borde)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: FilledButton.icon(
            onPressed: _avisoListo ? _intentarGuardar : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              textStyle: Theme.of(context).textTheme.titleMedium,
            ),
            icon: _guardando
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.6,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  )
                : const Icon(Icons.check),
            label: Text(_textoBotonAndroid()),
          ),
        ),
      ),
    );
  }

  Widget _encabezadoTipo(String categoria) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: CategoryColors.tinte(categoria),
            shape: BoxShape.circle,
          ),
          child: Icon(CategoryColors.icono(categoria), color: CategoryColors.base(categoria)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            CategoryColors.etiqueta(categoria),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: CategoryColors.texto(categoria),
            ),
          ),
        ),
      ],
    );
  }

  Widget _tituloSeccion(String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        texto,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: context.paleta.lienzo,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _pistaSeccion(String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        texto,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.paleta.textoSuave),
      ),
    );
  }

  Widget _campo(
    TextEditingController controller,
    String etiqueta, {
    bool largo = false,
    TextCapitalization capitalizacion = TextCapitalization.sentences,
    String? ayuda,
    String? error,
    FocusNode? foco,
    Key? clave,
    ValueChanged<String>? alEscribir,
  }) {
    return TextField(
      key: clave,
      focusNode: foco,
      controller: controller,
      textCapitalization: capitalizacion,
      minLines: largo ? 1 : null,
      maxLines: largo ? 4 : 1,
      keyboardType: largo ? TextInputType.multiline : null,
      onChanged: alEscribir,
      decoration: InputDecoration(
        labelText: etiqueta,
        hintText: ayuda,
        errorText: error,
      ),
    );
  }

  Widget _campoNombre() {
    final categoria = widget.categoria;
    return _campo(
      _medicacion,
      _rotuloNombreObligatorio(categoria),
      ayuda: _ejemploNombre(categoria),
      error: _errorNombre ? 'Escribí el nombre para poder guardar' : null,
      foco: _focoNombre,
      clave: _claveNombre,
      alEscribir: (texto) {
        if (_errorNombre && texto.trim().isNotEmpty) setState(() => _errorNombre = false);
      },
    );
  }

  Widget _campoDias() {
    return TextField(
      key: _claveDias,
      focusNode: _focoDias,
      controller: _dias,
      keyboardType: TextInputType.number,
      onChanged: (texto) {
        setState(() {
          if (_errorDias && (int.tryParse(texto.trim()) ?? 0) >= 1) _errorDias = false;
        });
      },
      decoration: InputDecoration(
        labelText: 'Cantidad de días',
        errorText: _errorDias ? 'Indicá cuántos días dura' : null,
      ),
    );
  }

  Widget _campoIndicaciones() {
    final categoria = widget.categoria;
    return _campo(
      _indicaciones,
      _rotuloIndicaciones(categoria),
      largo: true,
      ayuda: categoria == 'diario' ? 'Ej.: medio comprimido con la comida' : null,
    );
  }

  List<Widget> _seccionDatos(String categoria) {
    final indicaciones = _campoIndicaciones();
    final notas = _rotuloNotas;
    switch (categoria) {
      case 'veterinaria':
        return [
          _tituloSeccion('Visita'),
          _campo(
            _veterinario,
            'Nombre del veterinario o la veterinaria',
            capitalizacion: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
          _campoNombre(),
          const SizedBox(height: 16),
          _campo(_diagnostico, 'Diagnóstico', largo: true),
          const SizedBox(height: 24),
          _tituloSeccion('Indicaciones'),
          indicaciones,
        ];
      case 'unico':
      case 'vacuna':
        return [
          _tituloSeccion(categoria == 'vacuna' ? 'Vacuna' : 'Aplicación'),
          _campoNombre(),
          const SizedBox(height: 16),
          indicaciones,
          if (notas != null) ...[
            const SizedBox(height: 16),
            _campo(_notas, notas, largo: true),
          ],
        ];
      case 'higiene':
        return [
          _tituloSeccion('Cuidado'),
          _campoNombre(),
          const SizedBox(height: 16),
          indicaciones,
        ];
      case 'evento':
        return [
          _tituloSeccion('Evento'),
          _campoNombre(),
          const SizedBox(height: 16),
          indicaciones,
        ];
      default:
        return [
          _tituloSeccion('Medicación'),
          _campoNombre(),
          const SizedBox(height: 16),
          indicaciones,
        ];
    }
  }

  List<Widget> _seccionFecha(String categoria, String fecha) {
    final titulo = switch (categoria) {
      'evento' => 'Fecha del evento',
      'veterinaria' => 'Fecha de visita',
      'vacuna' || 'unico' => 'Fecha de aplicación',
      _ => 'Fecha',
    };
    return [
      const SizedBox(height: 24),
      _tituloSeccion(titulo),
      _pistaSeccion(_pistaToque),
      _tileValor(
        icono: Icons.calendar_today,
        etiqueta: _rotuloFecha(categoria),
        valor: fecha,
        alTocar: _elegirFecha,
      ),
    ];
  }

  List<Widget> _seccionDiaria(String fecha, String hora) {
    return [
      const SizedBox(height: 24),
      _tituloSeccion('¿Por cuánto tiempo?'),
      _opcionDuracion(TratamientoModel.tipoDias, 'Días fijos'),
      _opcionDuracion(TratamientoModel.tipoHastaAviso, 'Hasta nuevo aviso'),
      _opcionDuracion(TratamientoModel.tipoDePorVida, 'De por vida'),
      if (_tipo == TratamientoModel.tipoDias) ...[
        const SizedBox(height: 4),
        _campoDias(),
      ],
      const SizedBox(height: 24),
      _tituloSeccion('¿Cuándo empieza?'),
      _pistaSeccion(_pistaToque),
      _filaFechaHora(fecha: fecha, hora: hora),
      if (_fechaSuspension != null) ...[
        const SizedBox(height: 12),
        _tileValor(
          icono: Icons.event_busy_outlined,
          etiqueta: 'Suspendido el',
          valor: _fechaTexto(_fechaSuspension!),
          alTocar: _elegirSuspension,
        ),
      ],
      const SizedBox(height: 24),
      _tituloSeccion('Avisos'),
      _tarjetaOpcion(
        elegido: _alcance == _AlcanceAviso.todos,
        titulo: 'Avisar en todos los celulares',
        alTocar: _avisoListo ? () => setState(() => _alcance = _AlcanceAviso.todos) : null,
      ),
      _tarjetaOpcion(
        elegido: _alcance == _AlcanceAviso.esteCelular,
        titulo: 'No avisar en este celular',
        alTocar: _avisoListo ? () => setState(() => _alcance = _AlcanceAviso.esteCelular) : null,
      ),
      _tarjetaOpcion(
        elegido: _alcance == _AlcanceAviso.nadie,
        titulo: 'No avisar en ningún celular de administrador',
        alTocar: _avisoListo ? () => setState(() => _alcance = _AlcanceAviso.nadie) : null,
      ),
      Text(
        'Aunque no se avise, la dosis se marca como dada a la hora elegida.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.paleta.textoSuave),
      ),
    ];
  }

  Widget _opcionDuracion(String valor, String titulo) {
    final elegido = _tipo == valor;
    return _tarjetaOpcion(
      elegido: elegido,
      titulo: titulo,
      ayuda: elegido ? _ayudaDuracion(_tipo, _dias.text, _fecha) : null,
      alTocar: () => setState(() {
        _tipo = valor;
        if (valor != TratamientoModel.tipoDias) _errorDias = false;
      }),
    );
  }

  Widget _tarjetaOpcion({
    required bool elegido,
    required String titulo,
    String? ayuda,
    required VoidCallback? alTocar,
  }) {
    final color = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: context.paleta.superficie,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: elegido ? color : context.paleta.borde, width: elegido ? 2 : 1),
        ),
        child: InkWell(
          onTap: alTocar,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      elegido ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: elegido ? color : context.paleta.textoSuave,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(titulo)),
                  ],
                ),
                if (ayuda != null) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 34),
                    child: Text(
                      ayuda,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.paleta.textoSuave),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _filaFechaHora({required String fecha, required String hora}) {
    final fechaBox = _tileValor(
      icono: Icons.calendar_today,
      etiqueta: 'Empieza',
      valor: fecha,
      alTocar: _elegirFecha,
    );
    final horaBox = _tileValor(
      icono: Icons.access_time,
      etiqueta: 'Hora del aviso',
      valor: hora,
      alTocar: _elegirHora,
    );
    final ladoALado = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: fechaBox),
        const SizedBox(width: 12),
        Expanded(child: horaBox),
      ],
    );
    // El AlertDialog de Windows pide el ancho intrínseco. LayoutBuilder no puede darlo.
    if (!esAndroid) return ladoALado;
    return LayoutBuilder(
      builder: (context, constraints) {
        final escala = MediaQuery.textScalerOf(context).scale(1);
        if (constraints.maxWidth < 280 * escala) {
          return Column(
            children: [
              fechaBox,
              const SizedBox(height: 12),
              horaBox,
            ],
          );
        }
        return ladoALado;
      },
    );
  }

  Widget _tileValor({
    required IconData icono,
    required String etiqueta,
    required String valor,
    required VoidCallback alTocar,
  }) {
    return Material(
      color: context.paleta.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: context.paleta.borde),
      ),
      child: InkWell(
        onTap: alTocar,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icono, color: context.paleta.lienzo),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      etiqueta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: context.paleta.textoSuave,
                      ),
                    ),
                    Text(
                      valor,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              Icon(Icons.edit_outlined, color: context.paleta.textoSuave),
            ],
          ),
        ),
      ),
    );
  }
}

String _tituloEdicion(String categoria) => switch (categoria) {
      'unico' => 'Editar dosis única',
      'higiene' => 'Editar higiene',
      'evento' => 'Editar evento médico',
      'veterinaria' => 'Editar visita veterinaria',
      'vacuna' => 'Editar vacuna',
      _ => 'Editar tratamiento diario',
    };

String _tituloAlta(String categoria) => switch (categoria) {
      'unico' => 'Agregar dosis única',
      'higiene' => 'Agregar higiene',
      'evento' => 'Agregar evento médico',
      'veterinaria' => 'Agregar visita veterinaria',
      'vacuna' => 'Agregar vacuna',
      _ => 'Agregar tratamiento diario',
    };

String _rotuloNombreObligatorio(String categoria) {
  final base = _rotuloMedicacion(categoria);
  final sufijo = switch (categoria) {
    'higiene' || 'evento' || 'veterinaria' || 'vacuna' => 'obligatorio',
    _ => 'obligatoria',
  };
  return '$base ($sufijo)';
}

String _ejemploNombre(String categoria) => switch (categoria) {
      'higiene' => 'Ej.: Baño',
      'evento' => 'Ej.: Convulsión',
      'veterinaria' => 'Ej.: Control anual',
      'vacuna' => 'Ej.: Antirrábica',
      _ => 'Ej.: Fenobarbital 100 mg',
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

String _fechaTexto(DateTime fecha) {
  final dia = fecha.day.toString().padLeft(2, '0');
  final mes = fecha.month.toString().padLeft(2, '0');
  return '$dia/$mes/${fecha.year}';
}

String _ayudaDuracion(String tipo, String texto, DateTime inicio) {
  switch (tipo) {
    case TratamientoModel.tipoDePorVida:
      return 'Medicación crónica. No se cuentan dosis; podés registrar cambios de dosis.';
    case TratamientoModel.tipoHastaAviso:
      return 'Sigue hasta que lo suspendas. Las dosis se cuentan.';
    default:
      final dias = int.tryParse(texto.trim()) ?? 0;
      if (dias <= 0) return 'El día de inicio cuenta como día 1.';
      final ultimo = DateTime(inicio.year, inicio.month, inicio.day + dias - 1);
      return 'El día de inicio cuenta como día 1. Último día: ${_fechaTexto(ultimo)}.';
  }
}
