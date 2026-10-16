import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../controllers/perro_controller.dart';
import '../controllers/peso_controller.dart';
import '../controllers/recordatorio_controller.dart';
import '../controllers/seguimiento_controller.dart';
import '../controllers/tratamiento_controller.dart';
import '../models/egreso_model.dart';
import '../models/estado_duracion.dart';
import '../models/perro_model.dart';
import '../models/peso_model.dart';
import '../models/recordatorio_model.dart';
import '../models/seguimiento_model.dart';
import '../models/tratamiento_model.dart';
import '../theme/app_colors.dart';
import '../theme/category_colors.dart';
import '../theme/encabezado_seccion.dart';
import '../theme/entrada_escalonada.dart';
import '../theme/recordatorio_tipos.dart';
import '../theme/seguimiento_tipos.dart';
import 'dialogo_peso.dart';
import 'dialogo_recordatorio.dart';
import 'dialogo_tratamiento.dart';

class FormularioPerro extends StatefulWidget {
  final String? idDocumento;
  final PerroModel? perroActual;

  const FormularioPerro({super.key, this.idDocumento, this.perroActual});

  @override
  State<FormularioPerro> createState() => _FormularioPerroState();
}

class _FormularioPerroState extends State<FormularioPerro> {
  final PerroController _perroController = PerroController();
  final TratamientoController _tratamientoController = TratamientoController();
  final RecordatorioController _recordatorioController = RecordatorioController();
  final SeguimientoController _seguimientoController = SeguimientoController();
  final PesoController _pesoController = PesoController();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _edadController = TextEditingController();
  final TextEditingController _mesesController = TextEditingController();
  final TextEditingController _historiaController = TextEditingController();
  final TextEditingController _fichaMedicaController = TextEditingController();
  final TextEditingController _fechaIngresoController = TextEditingController();
  final TextEditingController _fechaFallecimientoController =
      TextEditingController();
  final TextEditingController _fechaEgresoController = TextEditingController();
  final TextEditingController _notaEgresoController = TextEditingController();
  final TextEditingController _fechaRegresoController = TextEditingController();

  DateTime? _fechaIngreso;
  DateTime? _fechaFallecimiento;
  DateTime? _fechaEgreso;
  DateTime? _fechaRegreso;
  bool _estaCastrado = false;
  bool _enCasa = false;
  bool _estaGuardando = false;
  bool _edadIndeterminada = false;
  String _estado = 'activo';
  String? _motivoEgreso;
  List<EgresoModel> _historialEgresos = [];
  String _sexo = 'macho';
  List<Map<String, dynamic>> _parientes = [];
  List<TratamientoModel> _tratamientos = [];
  final Set<String> _idsReanudadosManualmente = {};
  final Set<String> _idsInicialesTratamientos = {};
  List<RecordatorioModel> _recordatorios = [];
  final Set<String> _idsInicialesRecordatorios = {};
  List<SeguimientoModel> _seguimientos = [];
  final Set<String> _idsInicialesSeguimientos = {};
  List<PesoModel> _pesos = [];
  final Set<String> _idsInicialesPesos = {};

  bool _hayCambios = false;

  File? _imagenSeleccionada;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.perroActual != null) {
      final perro = widget.perroActual!;
      _nombreController.text = perro.nombre;
      _edadController.text = perro.edad.toString();
      _mesesController.text = perro.meses.toString();
      _edadIndeterminada = perro.edadIndeterminada;
      _historiaController.text = perro.historia;
      _fichaMedicaController.text = perro.fichaMedica;

      _fechaIngreso = perro.fechaIngreso;
      _fechaIngresoController.text = _fechaIngreso != null
          ? '${_fechaIngreso!.day.toString().padLeft(2, '0')}/${_fechaIngreso!.month.toString().padLeft(2, '0')}/${_fechaIngreso!.year}'
          : '';
      _estaCastrado = perro.castrado;
      _enCasa = perro.enCasa;
      _estado = perro.estado;
      _sexo = perro.sexo;
      _parientes = perro.parientes;
      _tratamientos = perro.tratamientos;
      _idsInicialesTratamientos.addAll(
        perro.tratamientos.map((tratamiento) => tratamiento.id).where((id) => id.isNotEmpty),
      );
      _recordatorios = List<RecordatorioModel>.from(perro.recordatorios);
      _idsInicialesRecordatorios.addAll(
        perro.recordatorios.map((recordatorio) => recordatorio.id).where((id) => id.isNotEmpty),
      );
      _seguimientos = List<SeguimientoModel>.from(perro.seguimientos);
      _idsInicialesSeguimientos.addAll(
        perro.seguimientos.map((seguimiento) => seguimiento.id).where((id) => id.isNotEmpty),
      );
      _pesos = List<PesoModel>.from(perro.pesos);
      _idsInicialesPesos.addAll(
        perro.pesos.map((peso) => peso.id).where((id) => id.isNotEmpty),
      );
      _historialEgresos = List<EgresoModel>.from(perro.historialEgresos);

      _fechaFallecimiento = perro.fechaFallecimiento;
      _fechaFallecimientoController.text = _fechaFallecimiento != null
          ? '${_fechaFallecimiento!.day.toString().padLeft(2, '0')}/${_fechaFallecimiento!.month.toString().padLeft(2, '0')}/${_fechaFallecimiento!.year}'
          : '';
      _motivoEgreso = perro.estado == 'egresado' ? perro.motivoEgreso : null;
      _fechaEgreso = perro.estado == 'egresado' ? perro.fechaEgreso : null;
      _fechaEgresoController.text = _fechaEgreso != null
          ? '${_fechaEgreso!.day.toString().padLeft(2, '0')}/${_fechaEgreso!.month.toString().padLeft(2, '0')}/${_fechaEgreso!.year}'
          : '';
      _notaEgresoController.text = perro.estado == 'egresado' ? (perro.notaEgreso ?? '') : '';
      if (perro.estado == 'egresado') {
        final hoy = DateTime.now();
        _fechaRegreso = DateTime(hoy.year, hoy.month, hoy.day);
        _fechaRegresoController.text =
            '${_fechaRegreso!.day.toString().padLeft(2, '0')}/${_fechaRegreso!.month.toString().padLeft(2, '0')}/${_fechaRegreso!.year}';
      }
    }
    // Registrar listeners después de cargar valores iniciales para no marcar cambios prematuros
    for (final c in [
      _nombreController,
      _edadController,
      _mesesController,
      _historiaController,
      _fichaMedicaController,
      _fechaEgresoController,
      _notaEgresoController,
      _fechaRegresoController,
    ]) {
      c.addListener(() => setState(() => _hayCambios = true));
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _edadController.dispose();
    _mesesController.dispose();
    _historiaController.dispose();
    _fichaMedicaController.dispose();
    _fechaIngresoController.dispose();
    _fechaFallecimientoController.dispose();
    _fechaEgresoController.dispose();
    _notaEgresoController.dispose();
    _fechaRegresoController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFechaFallecimiento() async {
    final fechaSeleccionada = await showDatePicker(
      context: context,
      initialDate: _fechaFallecimiento ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (fechaSeleccionada != null) {
      setState(() {
        _fechaFallecimiento = fechaSeleccionada;
        _fechaFallecimientoController.text =
            '${fechaSeleccionada.day.toString().padLeft(2, '0')}/${fechaSeleccionada.month.toString().padLeft(2, '0')}/${fechaSeleccionada.year}';
      });
    }
  }

  Future<void> _seleccionarFechaIngreso() async {
    final fechaSeleccionada = await showDatePicker(
      context: context,
      initialDate: _fechaIngreso ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (fechaSeleccionada != null) {
      setState(() {
        _fechaIngreso = fechaSeleccionada;
        _fechaIngresoController.text =
            '${fechaSeleccionada.day.toString().padLeft(2, '0')}/${fechaSeleccionada.month.toString().padLeft(2, '0')}/${fechaSeleccionada.year}';
      });
    }
  }

  Future<void> _seleccionarFechaEgreso() async {
    final fechaSeleccionada = await showDatePicker(
      context: context,
      initialDate: _fechaEgreso ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (fechaSeleccionada != null) {
      _fechaEgresoController.text =
          '${fechaSeleccionada.day.toString().padLeft(2, '0')}/${fechaSeleccionada.month.toString().padLeft(2, '0')}/${fechaSeleccionada.year}';
      setState(() => _fechaEgreso = fechaSeleccionada);
    }
  }

  Future<void> _seleccionarFechaRegreso() async {
    final fechaSeleccionada = await showDatePicker(
      context: context,
      initialDate: _fechaRegreso ?? DateTime.now(),
      firstDate: _fechaEgreso ?? DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (fechaSeleccionada != null) {
      _fechaRegresoController.text =
          '${fechaSeleccionada.day.toString().padLeft(2, '0')}/${fechaSeleccionada.month.toString().padLeft(2, '0')}/${fechaSeleccionada.year}';
      setState(() => _fechaRegreso = fechaSeleccionada);
    }
  }

  String _lineaEgresoAnterior(EgresoModel egreso) {
    final motivo = PerroController.formatearMotivoEgreso(egreso.motivo);
    final fecha = _perroController.formatearFecha(egreso.fechaEgreso);
    final base = motivo.isEmpty ? fecha : '$motivo · $fecha';
    if (egreso.fechaRegreso == null) return base;
    return '$base → regresó ${_perroController.formatearFecha(egreso.fechaRegreso)}';
  }

  Future<void> _quitarEgresoAnterior(int indice) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Borrar este egreso?'),
        content: const Text('Se quita del historial cuando guardes la ficha.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Borrar')),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    setState(() {
      _historialEgresos.removeAt(indice);
      _hayCambios = true;
    });
  }

  void _insertarBulletTexto(TextEditingController controller) {
    final selection = controller.selection;
    final start = selection.isValid ? selection.start : controller.text.length;
    final end = selection.isValid ? selection.end : controller.text.length;
    final text = controller.text;
    final prefix = text.substring(0, start);
    final suffix = text.substring(end);

    controller.value = TextEditingValue(
      text: '$prefix• $suffix',
      selection: TextSelection.collapsed(offset: start + 2),
    );
  }

  void _insertarFormatoTexto(
    TextEditingController controller,
    String delimitadorInicio,
    String delimitadorFin,
  ) {
    final selection = controller.selection;
    final start = selection.isValid ? selection.start : controller.text.length;
    final end = selection.isValid ? selection.end : controller.text.length;
    final text = controller.text;
    final selectedText = text.substring(start, end);
    final prefix = text.substring(0, start);
    final suffix = text.substring(end);

    final nuevoTexto =
        '$prefix$delimitadorInicio$selectedText$delimitadorFin$suffix';
    final nuevaPosicion =
        start +
        delimitadorInicio.length +
        selectedText.length +
        delimitadorFin.length;

    controller.value = TextEditingValue(
      text: nuevoTexto,
      selection: TextSelection.collapsed(offset: nuevaPosicion),
    );
  }

  void _abrirOpcionesFotoPerfil() {
    final urlActual = widget.perroActual?.fotoPerfil;
    final hayFotoActual =
        _imagenSeleccionada != null ||
        (urlActual != null && urlActual.isNotEmpty);

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Cambiar foto'),
              onTap: () {
                Navigator.pop(context);
                _seleccionarImagen();
              },
            ),
            if (hayFotoActual)
              ListTile(
                leading: const Icon(Icons.crop),
                title: const Text('Recortar foto actual'),
                onTap: () {
                  Navigator.pop(context);
                  _recortarFotoActual();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _recortarFotoActual() async {
    setState(() => _estaGuardando = true);
    final colorScheme = Theme.of(context).colorScheme;
    try {
      File archivoOrigen;

      if (_imagenSeleccionada != null) {
        archivoOrigen = _imagenSeleccionada!;
      } else {
        final urlActual = widget.perroActual!.fotoPerfil!;
        final respuesta = await http.get(Uri.parse(urlActual));
        final directorioTemporal = await getTemporaryDirectory();
        archivoOrigen = File(
          '${directorioTemporal.path}/temp_recorte_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        await archivoOrigen.writeAsBytes(respuesta.bodyBytes);
      }

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: archivoOrigen.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Ajustar imagen',
            toolbarColor: colorScheme.primary,
            toolbarWidgetColor: colorScheme.onPrimary,
            initAspectRatio: CropAspectRatioPreset.square,
            aspectRatioPresets: const [CropAspectRatioPreset.square],
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Ajustar imagen',
            doneButtonTitle: 'Listo',
            cancelButtonTitle: 'Cancelar',
          ),
        ],
      );

      if (croppedFile != null) {
        setState(() => _imagenSeleccionada = File(croppedFile.path));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo recortar la foto actual.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _estaGuardando = false);
      }
    }
  }

  Future<void> _seleccionarImagen() async {
    final XFile? imagen = await _picker.pickImage(source: ImageSource.gallery);
    if (imagen == null || !mounted) return;

    try {
      final soportaRecorte = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

      if (!soportaRecorte) {
        setState(() => _imagenSeleccionada = File(imagen.path));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Se usará la imagen original porque el recorte no está disponible en esta plataforma.',
              ),
            ),
          );
        }
        return;
      }

      final colorScheme = Theme.of(context).colorScheme;
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: imagen.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Ajustar imagen',
            toolbarColor: colorScheme.primary,
            toolbarWidgetColor: colorScheme.onPrimary,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Ajustar imagen',
            doneButtonTitle: 'Listo',
            cancelButtonTitle: 'Cancelar',
          ),
        ],
      );

      if (croppedFile != null) {
        setState(() => _imagenSeleccionada = File(croppedFile.path));
      }
    } on MissingPluginException catch (_) {
      setState(() => _imagenSeleccionada = File(imagen.path));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'El recorte de imagen no está disponible aquí. Se usará la imagen original.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo procesar la imagen.')),
        );
      }
    }
  }

  void _confirmarEliminarFicha() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar ficha?'),
        content: const Text(
          'Esta acción es irreversible y borrará todos los datos del perro.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              await _perroController.eliminarPerro(widget.idDocumento!);
              if (!context.mounted) return;
              Navigator.of(context)
                ..pop()
                ..pop(true);
            },
            child: const Text('Eliminar', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Future<void> _guardarDatos() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _estaGuardando = true);

      try {
        String? urlImagen = widget.perroActual?.fotoPerfil;

        if (_imagenSeleccionada != null) {
          final nombreArchivo = '${DateTime.now().millisecondsSinceEpoch}.jpg';
          final ref = FirebaseStorage.instance
              .ref()
              .child('fotos_perfil')
              .child(nombreArchivo);
          await ref.putFile(_imagenSeleccionada!);
          urlImagen = await ref.getDownloadURL();
        }

        final parientesNormalizados = _parientes
            .map((p) {
              final id = (p['id'] ?? p['id_documento'] ?? '').toString();
              return {
                'id': id,
                'id_documento': id,
                'nombre': (p['nombre'] ?? '').toString(),
                'relacion': (p['relacion'] ?? 'Hermano/a').toString(),
              };
            })
            .where((p) => (p['id'] as String).isNotEmpty)
            .toList();

        var tratamientosAGuardar = _tratamientos;
        var recordatoriosAGuardar = _recordatorios;
        var seguimientosAGuardar = _seguimientos;
        var pesosAGuardar = _pesos;
        var altasConservadas = 0;
        final idDocumento = widget.idDocumento;
        if (idDocumento != null && idDocumento.isNotEmpty) {
          try {
            final remoto = await _perroController.obtenerPerroPorId(idDocumento);
            if (remoto != null) {
              tratamientosAGuardar = TratamientoController.reconciliarPausas(
                _tratamientos,
                remoto.tratamientos,
                _idsReanudadosManualmente,
              );
              final tratamientosFusionados = TratamientoController.fusionarAltasRemotas(
                local: tratamientosAGuardar,
                remoto: remoto.tratamientos,
                idsIniciales: _idsInicialesTratamientos,
              );
              final recordatoriosFusionados = RecordatorioController.fusionarAltasRemotas(
                local: _recordatorios,
                remoto: remoto.recordatorios,
                idsIniciales: _idsInicialesRecordatorios,
              );
              final seguimientosFusionados = SeguimientoController.fusionarAltasRemotas(
                local: _seguimientos,
                remoto: remoto.seguimientos,
                idsIniciales: _idsInicialesSeguimientos,
              );
              final pesosFusionados = PesoController.fusionarAltasRemotas(
                local: _pesos,
                remoto: remoto.pesos,
                idsIniciales: _idsInicialesPesos,
              );
              altasConservadas = (tratamientosFusionados.length - tratamientosAGuardar.length) +
                  (recordatoriosFusionados.length - _recordatorios.length) +
                  (seguimientosFusionados.length - _seguimientos.length) +
                  (pesosFusionados.length - _pesos.length);
              tratamientosAGuardar = tratamientosFusionados;
              recordatoriosAGuardar = recordatoriosFusionados;
              seguimientosAGuardar = seguimientosFusionados;
              pesosAGuardar = pesosFusionados;
            }
          } catch (_) {}
        }

        if (_estado == 'inactivo') {
          tratamientosAGuardar = TratamientoController.pausarDiariosActivos(tratamientosAGuardar);
          recordatoriosAGuardar = RecordatorioController.cancelarPendientes(recordatoriosAGuardar);
          seguimientosAGuardar = SeguimientoController.cerrarActivos(seguimientosAGuardar);
        }

        final perro = PerroModel(
          id: widget.idDocumento ?? '',
          nombre: _nombreController.text.trim(),
          sexo: _sexo,
          estado: _estado,
          edad: int.tryParse(_edadController.text.trim()) ?? 0,
          meses: int.tryParse(_mesesController.text.trim()) ?? 0,
          edadIndeterminada: _edadIndeterminada,
          edadAnioBase: _estado == 'activo' ? DateTime.now().year : null,
          fechaIngreso: _fechaIngreso,
          fechaFallecimiento: _estado == 'inactivo'
              ? _fechaFallecimiento
              : null,
          motivoEgreso: _estado == 'egresado' ? _motivoEgreso : null,
          fechaEgreso: _estado == 'egresado' ? _fechaEgreso : null,
          notaEgreso: _estado == 'egresado' && _notaEgresoController.text.trim().isNotEmpty
              ? _notaEgresoController.text.trim()
              : null,
          historialEgresos: PerroController.calcularHistorialEgresos(
            original: widget.perroActual,
            estadoNuevo: _estado,
            motivo: _motivoEgreso,
            fechaEgreso: _fechaEgreso,
            nota: _notaEgresoController.text,
            fechaRegreso: _fechaRegreso,
            historialBase: _historialEgresos,
          ),
          ultimaActualizacionEdad: DateTime.now(),
          historia: _historiaController.text.trim(),
          fichaMedica: _fichaMedicaController.text.trim(),
          castrado: _estaCastrado,
          enCasa: _enCasa,
          fotoPerfil: urlImagen,
          parientes: parientesNormalizados,
          tratamientos: tratamientosAGuardar,
          recordatorios: recordatoriosAGuardar,
          seguimientos: seguimientosAGuardar,
          pesos: pesosAGuardar,
        );

        await _perroController.guardarPerro(perro);

        if (mounted) {
          if (altasConservadas > 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Se conservaron $altasConservadas cambios que hizo otra persona mientras editabas.',
                ),
              ),
            );
          }
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al procesar la información')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _estaGuardando = false);
        }
      }
    }
  }

  Future<void> _mostrarDialogoAgregarFamiliar() async {
    String? seleccionadoId;
    String? seleccionadoNombre;
    String seleccionadaRelacion = 'Hermano/a';
    const relaciones = ['Hermano/a', 'Padre', 'Madre', 'Hijo/a'];

    final listaPerros = await _perroController.obtenerListaPerros();
    final opciones = listaPerros
        .where((p) => p.id != widget.idDocumento)
        .map(
          (p) => {'id': p.id, 'nombre': p.nombre.isNotEmpty ? p.nombre : p.id},
        )
        .toList();

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Añadir familiar'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Perro',
                ),
                initialValue: seleccionadoId,
                items: opciones
                    .map(
                      (o) => DropdownMenuItem(
                        value: o['id'],
                        child: Text(o['nombre']!),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setDialogState(() {
                  seleccionadoId = val;
                  seleccionadoNombre = opciones.firstWhere(
                    (o) => o['id'] == val,
                  )['nombre'];
                }),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Relación',
                ),
                initialValue: seleccionadaRelacion,
                items: relaciones
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (val) =>
                    setDialogState(() => seleccionadaRelacion = val!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: seleccionadoId == null
                  ? null
                  : () {
                      setState(() {
                        _parientes.add({
                          'id': seleccionadoId,
                          'id_documento': seleccionadoId,
                          'nombre': seleccionadoNombre,
                          'relacion': seleccionadaRelacion,
                        });
                        _hayCambios = true;
                      });
                      Navigator.pop(ctx);
                    },
              child: const Text('Añadir'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaFormulario({
    String? titulo,
    IconData? icono,
    Widget? accion,
    required List<Widget> children,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (titulo != null) ...[
              Row(
                children: [
                  if (icono != null) ...[
                    Icon(icono, size: 22, color: AppColors.navy),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      titulo,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  ?accion,
                ],
              ),
              const SizedBox(height: 16),
            ],
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _estadoVacioSalud(IconData icono, String texto) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: context.paleta.relleno,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.paleta.borde),
      ),
      child: Row(
        children: [
          Icon(icono, color: AppColors.pendiente),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              texto,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.paleta.textoSuave,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tituloSeccion(String titulo, int cantidad, {IconData icono = Icons.medical_services_outlined}) {
    return EncabezadoSeccion(
      titulo: titulo,
      icono: icono,
      cantidad: cantidad,
    );
  }

  Widget _chipEstado({required bool activo}) {
    final color = activo ? AppColors.activo : AppColors.pausado;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        activo ? 'Activo' : 'Pausado',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: activo ? context.paleta.activoTexto : context.paleta.pausadoTexto,
        ),
      ),
    );
  }

  String _sufijoDuracion(TratamientoModel tratamiento) {
    final estado = TratamientoController.calcularEstadoDuracion(tratamiento);
    switch (estado.fase) {
      case FaseTratamiento.enCurso:
        return estado.restantes == 1 ? ' · Queda 1 día' : ' · Quedan ${estado.restantes} días';
      case FaseTratamiento.ultimoDia:
        return ' · Último día hoy';
      case FaseTratamiento.noIniciado:
        final inicio = tratamiento.fechaInicio;
        if (inicio == null) return '';
        final dia = inicio.day.toString().padLeft(2, '0');
        final mes = inicio.month.toString().padLeft(2, '0');
        return ' · Empieza el $dia/$mes';
      case FaseTratamiento.finalizado:
      case FaseTratamiento.indefinido:
        return '';
    }
  }

  Widget _tarjetaTratamientoDiario({
    required int i,
    required TratamientoModel t,
    required bool pausado,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final dias = t.diasDuracion;
    final fechaTexto = t.fechaInicio != null
        ? '${t.fechaInicio!.day.toString().padLeft(2, '0')}/${t.fechaInicio!.month.toString().padLeft(2, '0')}/${t.fechaInicio!.year}'
        : '';
    final horaRecordatorio = t.horaRecordatorio ?? '';
    final sufijo = pausado ? '' : _sufijoDuracion(t);
    final datos = <String>[
      if (t.indicaciones.trim().isNotEmpty) t.indicaciones.trim(),
      dias > 0 ? '$dias días' : 'Indefinido',
      if (!pausado && fechaTexto.isNotEmpty) 'Desde $fechaTexto',
      if (!pausado && horaRecordatorio.isNotEmpty) 'Recordatorio $horaRecordatorio',
      if (sufijo.trim().isNotEmpty) sufijo.replaceFirst(RegExp(r'^ · '), ''),
    ];
    final colorIcono = pausado ? AppColors.pausado : CategoryColors.base('diario');

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      opacity: pausado ? 0.65 : 1,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: pausado ? null : () => _mostrarDialogoEditarTratamiento(i),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colorIcono.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        pausado ? Icons.pause_circle_outline : Icons.medication,
                        size: 22,
                        color: colorIcono,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _capitalizarPrimera(t.medicacion),
                            style: textTheme.titleMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [for (final dato in datos) _datoTratamiento(dato)],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _chipEstado(activo: !pausado),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: pausado
                      ? [
                          FilledButton.tonalIcon(
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Reanudar'),
                            onPressed: () => _alternarPausaTratamiento(i),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_forever,
                              color: AppColors.error,
                            ),
                            tooltip: 'Eliminar definitivamente',
                            onPressed: () => setState(() {
                              _tratamientos.removeAt(i);
                              _hayCambios = true;
                            }),
                          ),
                        ]
                      : [
                          FilledButton.tonalIcon(
                            icon: const Icon(Icons.pause),
                            label: const Text('Pausar'),
                            onPressed: () => _alternarPausaTratamiento(i),
                          ),
                          const SizedBox(width: 4),
                          IconButton.outlined(
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: 'Editar',
                            onPressed: () =>
                                _mostrarDialogoEditarTratamiento(i),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: AppColors.error,
                            ),
                            tooltip: 'Eliminar',
                            onPressed: () =>
                                _mostrarDialogoEliminarTratamiento(i),
                          ),
                        ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _datoTratamiento(String texto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: context.paleta.relleno,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: context.paleta.borde),
      ),
      child: Text(
        texto,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: context.paleta.textoSuave),
      ),
    );
  }

  Widget _filaEvento(int i, TratamientoModel t) {
    final textTheme = Theme.of(context).textTheme;
    final fechaTexto = t.fechaInicio != null
        ? '${t.fechaInicio!.day.toString().padLeft(2, '0')}/${t.fechaInicio!.month.toString().padLeft(2, '0')}/${t.fechaInicio!.year}'
        : 'Sin fecha';
    final color = _colorCategoria(t.categoria);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: context.paleta.superficie,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: context.paleta.borde),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: () => _mostrarDialogoEditarTratamiento(i),
          contentPadding: const EdgeInsets.only(left: 12, right: 4),
          leading: CircleAvatar(
            radius: 20,
            backgroundColor: CategoryColors.tinte(t.categoria),
            child: Icon(_iconoCategoria(t.categoria), size: 20, color: color),
          ),
          title: Text(
            _capitalizarPrimera(t.medicacion),
            style: textTheme.titleMedium?.copyWith(fontSize: 15),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          isThreeLine: true,
          subtitle: Text(
            '${_etiquetaCategoria(t.categoria)} · $fechaTexto'
            '${t.detalleVisible.isNotEmpty ? '\n${t.detalleVisible}' : ''}',
            style: textTheme.bodyMedium?.copyWith(
              color: context.paleta.textoSuave,
              fontSize: 13,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                tooltip: 'Editar',
                color: context.paleta.textoSuave,
                onPressed: () => _mostrarDialogoEditarTratamiento(i),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                tooltip: 'Eliminar',
                color: AppColors.error,
                onPressed: () => _mostrarDialogoEliminarTratamiento(i),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _capitalizarPrimera(String texto) {
    final limpio = texto.trim();
    if (limpio.isEmpty) return limpio;
    return limpio[0].toUpperCase() + limpio.substring(1);
  }

  String _etiquetaCategoria(String categoria) => CategoryColors.etiqueta(categoria);

  IconData _iconoCategoria(String categoria) => CategoryColors.icono(categoria);

  Color _colorCategoria(String categoria) => CategoryColors.base(categoria);

  Future<void> _alternarPausaTratamiento(int indice) async {
    final actual = _tratamientos[indice];
    if (actual.categoria != 'diario') return;

    final estabaReanudado = _idsReanudadosManualmente.contains(actual.id);
    setState(() {
      final actualizado = _tratamientoController.alternarPausa(actual);
      _tratamientos[indice] = actualizado;
      if (actualizado.activo) {
        _idsReanudadosManualmente.add(actual.id);
      } else {
        _idsReanudadosManualmente.remove(actual.id);
      }
      _hayCambios = true;
    });

    final idDocumento = widget.idDocumento;
    if (idDocumento == null || idDocumento.isEmpty) return;

    try {
      await _tratamientoController.persistirAlternarPausa(idDocumento, actual.id);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _tratamientos[indice] = actual;
        if (estabaReanudado) {
          _idsReanudadosManualmente.add(actual.id);
        } else {
          _idsReanudadosManualmente.remove(actual.id);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo actualizar el estado del tratamiento')),
      );
    }
  }

  Widget _seccionPeso() {
    final visibles = [..._pesos]..sort((a, b) => b.fecha.compareTo(a.fecha));
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tituloSeccion('Peso', visibles.length, icono: Icons.monitor_weight_outlined),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            onPressed: () => _mostrarDialogoPeso(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Agregar peso'),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Cada medición queda con su fecha. Si es un aproximado, marcalo como estimado. Se guarda al tocar Guardar Cambios.',
          style: textTheme.bodyMedium?.copyWith(color: context.paleta.textoSuave),
        ),
        if (visibles.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (var n = 0; n < visibles.length; n++)
            EntradaEscalonada(
              indice: n,
              child: _filaPeso(visibles[n]),
            ),
        ],
      ],
    );
  }

  Widget _filaPeso(PesoModel peso) {
    final textTheme = Theme.of(context).textTheme;
    final nota = peso.nota.trim();
    final partes = <String>[
      PesoController.formatearFecha(peso.fecha),
      if (peso.estimado) 'aprox.',
      if (nota.isNotEmpty) nota,
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: context.paleta.superficie,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: context.paleta.borde),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: () => _mostrarDialogoPeso(actual: peso),
          contentPadding: const EdgeInsets.only(left: 12, right: 4),
          leading: CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.navy.withValues(alpha: 0.12),
            child: Icon(
              peso.estimado ? Icons.straighten : Icons.monitor_weight_outlined,
              size: 20,
              color: AppColors.navy,
            ),
          ),
          title: Text(
            '${formatearKg(peso.kg)} kg',
            style: textTheme.titleMedium?.copyWith(fontSize: 15),
          ),
          subtitle: Text(
            partes.join(' · '),
            style: textTheme.bodyMedium?.copyWith(color: context.paleta.textoSuave, fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                tooltip: 'Editar',
                color: context.paleta.textoSuave,
                onPressed: () => _mostrarDialogoPeso(actual: peso),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                tooltip: 'Eliminar',
                color: AppColors.error,
                onPressed: () => _eliminarPeso(peso),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _mostrarDialogoPeso({PesoModel? actual}) async {
    final guardado = await mostrarDialogoPeso(
      context,
      controller: _pesoController,
      actual: actual,
    );
    if (!mounted || guardado == null) return;
    setState(() {
      if (actual == null) {
        _pesos.add(guardado);
      } else {
        final indice = _pesos.indexWhere((peso) => peso.id == actual.id);
        if (indice >= 0) _pesos[indice] = guardado;
      }
      _hayCambios = true;
    });
  }

  Future<void> _eliminarPeso(PesoModel peso) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar esta medición?'),
        content: Text('${formatearKg(peso.kg)} kg del ${PesoController.formatearFecha(peso.fecha)}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    setState(() {
      _pesos = _pesoController.eliminar(_pesos, peso.id);
      _hayCambios = true;
    });
  }

  Widget _seccionSeguimientos() {
    final vigentes = _seguimientoController.vigentes(_seguimientos);
    final cerrados = _seguimientoController.cerrados(_seguimientos);
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tituloSeccion('Seguimientos', vigentes.length, icono: Icons.visibility_outlined),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            onPressed: () => _mostrarDialogoSeguimiento(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Agregar seguimiento'),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Avisa todos los días a la hora elegida, hasta que pasen los días o lo cierres. Se guarda al tocar Guardar Cambios.',
          style: textTheme.bodyMedium?.copyWith(color: context.paleta.textoSuave),
        ),
        const SizedBox(height: 12),
        if (vigentes.isEmpty && cerrados.isEmpty)
          _estadoVacioSalud(Icons.visibility_off_outlined, 'No hay seguimientos.')
        else ...[
          if (vigentes.isNotEmpty)
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              clipBehavior: Clip.none,
              child: Column(
                children: [
                  for (var n = 0; n < vigentes.length; n++)
                    EntradaEscalonada(
                      indice: n,
                      child: _filaSeguimiento(_indiceSeguimiento(vigentes[n]), cerrado: false),
                    ),
                ],
              ),
            ),
          if (cerrados.isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              shape: const Border(),
              collapsedShape: const Border(),
              collapsedIconColor: context.paleta.textoSuave,
              iconColor: context.paleta.textoSuave,
              title: Row(
                children: [
                  Icon(Icons.history_rounded, size: 20, color: context.paleta.textoSuave),
                  const SizedBox(width: 8),
                  Text(
                    'Cerrados (${cerrados.length})',
                    style: textTheme.titleMedium?.copyWith(color: context.paleta.textoSuave),
                  ),
                ],
              ),
              children: [
                for (var n = 0; n < cerrados.length; n++)
                  _filaSeguimiento(_indiceSeguimiento(cerrados[n]), cerrado: true),
              ],
            ),
        ],
      ],
    );
  }

  int _indiceSeguimiento(SeguimientoModel seguimiento) {
    return _seguimientos.indexWhere((item) => item.id == seguimiento.id);
  }

  Widget _filaSeguimiento(int indice, {required bool cerrado}) {
    final seguimiento = _seguimientos[indice];
    final visual = SeguimientoTipos.de(seguimiento.motivo);
    final textTheme = Theme.of(context).textTheme;
    final plazo = _seguimientoController.describirPlazo(seguimiento);
    final detalle = seguimiento.detalle.trim();
    final subtitulo = detalle.isEmpty
        ? '$plazo · ${seguimiento.hora} h'
        : '$plazo · ${seguimiento.hora} h · $detalle';
    final fila = Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: context.paleta.superficie,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: context.paleta.borde),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: () => _mostrarDialogoSeguimiento(indice: indice),
          contentPadding: const EdgeInsets.only(left: 12, right: 4),
          leading: CircleAvatar(
            radius: 20,
            backgroundColor: visual.color.withValues(alpha: 0.12),
            child: Icon(visual.icono, size: 20, color: visual.color),
          ),
          title: Text(
            visual.etiqueta,
            style: textTheme.titleMedium?.copyWith(fontSize: 15),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            subtitulo,
            style: textTheme.bodyMedium?.copyWith(
              color: context.paleta.textoSuave,
              fontSize: 13,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                tooltip: 'Editar',
                color: context.paleta.textoSuave,
                onPressed: () => _mostrarDialogoSeguimiento(indice: indice),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                tooltip: 'Eliminar',
                color: AppColors.error,
                onPressed: () {
                  setState(() {
                    _seguimientos.removeAt(indice);
                    _hayCambios = true;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );

    if (!cerrado) return fila;
    return AnimatedOpacity(
      opacity: 0.65,
      duration: const Duration(milliseconds: 200),
      child: fila,
    );
  }

  Future<void> _mostrarDialogoSeguimiento({int? indice}) async {
    final actual = indice == null ? null : _seguimientos[indice];
    var motivo = actual?.motivo ?? 'ojo';
    if (SeguimientoTipos.de(motivo).motivo != motivo) motivo = 'otro';
    final detalleController = TextEditingController(text: actual?.detalle ?? '');
    var dias = actual?.diasDuracion ?? 5;
    const duraciones = <(int, String)>[
      (3, '3 días'),
      (5, '5 días'),
      (7, '7 días'),
      (14, '14 días'),
      (0, 'Hasta que lo cierre'),
    ];
    if (!duraciones.any((opcion) => opcion.$1 == dias)) dias = 5;
    var hora = _horaDeTexto(actual?.hora ?? '18:00');

    final guardado = await showDialog<SeguimientoModel>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final horaTexto =
              '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}';
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
                          selected: motivo == visual.motivo,
                          onSelected: (seleccionado) {
                            if (!seleccionado) return;
                            setDialogState(() => motivo = visual.motivo);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: detalleController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Detalle (opcional)',
                      helperText: 'Por ejemplo: ojo izquierdo irritado',
                      helperMaxLines: 2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Duración', style: Theme.of(ctx).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final opcion in duraciones)
                        ChoiceChip(
                          label: Text(opcion.$2),
                          selected: dias == opcion.$1,
                          onSelected: (seleccionado) {
                            if (!seleccionado) return;
                            setDialogState(() => dias = opcion.$1);
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
                        context: ctx,
                        initialTime: hora,
                        builder: (BuildContext context, Widget? child) {
                          return MediaQuery(
                            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                            child: child!,
                          );
                        },
                      );
                      if (seleccionada == null) return;
                      setDialogState(() => hora = seleccionada);
                    },
                  ),
                  Text(
                    'Si la hora de hoy ya pasó, el primer aviso llega mañana.',
                    style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(color: context.paleta.textoSuave),
                  ),
                  if (actual != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      actual.activo
                          ? 'Los días se cuentan desde el día en que lo creaste.'
                          : 'Está cerrado. Guardar no lo vuelve a abrir.',
                      style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(color: context.paleta.textoSuave),
                    ),
                  ],
                ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  FocusScope.of(ctx).unfocus();
                  final horaTextoGuardada =
                      '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}';
                  final resultado = actual == null
                      ? _seguimientoController.crear(
                          motivo: motivo,
                          detalle: detalleController.text,
                          hora: horaTextoGuardada,
                          fechaInicio: DateTime.now(),
                          diasDuracion: dias,
                        )
                      : _seguimientoController.editar(
                          actual,
                          motivo: motivo,
                          detalle: detalleController.text,
                          hora: horaTextoGuardada,
                          diasDuracion: dias,
                        );
                  Navigator.pop(ctx, resultado);
                },
                child: Text(actual == null ? 'Agregar' : 'Guardar'),
              ),
            ],
          );
        },
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => detalleController.dispose());
    if (!mounted || guardado == null) return;
    setState(() {
      if (indice == null) {
        _seguimientos.add(guardado);
      } else {
        _seguimientos[indice] = guardado;
      }
      _hayCambios = true;
    });
  }

  TimeOfDay _horaDeTexto(String hora) {
    final partes = hora.split(':');
    var horas = int.tryParse(partes[0]) ?? 18;
    var minutos = partes.length > 1 ? int.tryParse(partes[1]) ?? 0 : 0;
    if (horas < 0 || horas > 23) horas = 18;
    if (minutos < 0 || minutos > 59) minutos = 0;
    return TimeOfDay(hour: horas, minute: minutos);
  }

  Widget _seccionRecordatorios() {
    final proximos = _recordatorioController.proximos(_recordatorios);
    final vencidos = _recordatorioController.vencidos(_recordatorios);
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tituloSeccion('Recordatorios', proximos.length, icono: Icons.alarm_rounded),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            onPressed: () => _mostrarDialogoRecordatorio(),
            icon: const Icon(Icons.alarm_add_rounded),
            label: const Text('Agendar recordatorio'),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Un aviso en el día y la hora que elijas. No se repite. Se guarda al tocar Guardar Cambios.',
          style: textTheme.bodyMedium?.copyWith(color: context.paleta.textoSuave),
        ),
        const SizedBox(height: 12),
        if (proximos.isEmpty && vencidos.isEmpty)
          _estadoVacioSalud(Icons.alarm_off_outlined, 'No hay recordatorios agendados.')
        else ...[
          if (proximos.isNotEmpty)
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              clipBehavior: Clip.none,
              child: Column(
                children: [
                  for (var n = 0; n < proximos.length; n++)
                    EntradaEscalonada(
                      indice: n,
                      child: _filaRecordatorio(_indiceRecordatorio(proximos[n]), vencido: false),
                    ),
                ],
              ),
            ),
          if (vencidos.isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              shape: const Border(),
              collapsedShape: const Border(),
              collapsedIconColor: context.paleta.textoSuave,
              iconColor: context.paleta.textoSuave,
              title: Row(
                children: [
                  Icon(Icons.history_rounded, size: 20, color: context.paleta.textoSuave),
                  const SizedBox(width: 8),
                  Text(
                    'Vencidos (${vencidos.length})',
                    style: textTheme.titleMedium?.copyWith(color: context.paleta.textoSuave),
                  ),
                ],
              ),
              children: [
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  clipBehavior: Clip.none,
                  child: Column(
                    children: [
                      for (var n = 0; n < vencidos.length; n++)
                        EntradaEscalonada(
                          indice: n,
                          child: _filaRecordatorio(_indiceRecordatorio(vencidos[n]), vencido: true),
                        ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ],
    );
  }

  int _indiceRecordatorio(RecordatorioModel recordatorio) {
    return _recordatorios.indexWhere((r) => r.id == recordatorio.id);
  }

  Widget _filaRecordatorio(int indice, {required bool vencido}) {
    final recordatorio = _recordatorios[indice];
    final visual = RecordatorioTipos.de(recordatorio.tipo);
    final textTheme = Theme.of(context).textTheme;
    final nota = recordatorio.nota.trim();
    final cuando = _recordatorioController.formatearCuando(recordatorio.fechaHora);
    final fila = Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: context.paleta.superficie,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: context.paleta.borde),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: () => _mostrarDialogoRecordatorio(indice: indice),
          contentPadding: const EdgeInsets.only(left: 12, right: 4),
          leading: CircleAvatar(
            radius: 20,
            backgroundColor: visual.color.withValues(alpha: 0.12),
            child: Icon(visual.icono, size: 20, color: visual.color),
          ),
          title: Text(
            recordatorio.titulo,
            style: textTheme.titleMedium?.copyWith(fontSize: 15),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            nota.isEmpty ? cuando : '$cuando · $nota',
            style: textTheme.bodyMedium?.copyWith(
              color: context.paleta.textoSuave,
              fontSize: 13,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                tooltip: 'Editar',
                color: context.paleta.textoSuave,
                onPressed: () => _mostrarDialogoRecordatorio(indice: indice),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                tooltip: 'Eliminar',
                color: AppColors.error,
                onPressed: () {
                  setState(() {
                    _recordatorios.removeAt(indice);
                    _hayCambios = true;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );

    if (!vencido) return fila;
    return AnimatedOpacity(
      opacity: 0.65,
      duration: const Duration(milliseconds: 200),
      child: fila,
    );
  }

  Future<void> _mostrarDialogoRecordatorio({int? indice}) async {
    final actual = indice == null ? null : _recordatorios[indice];
    final guardado = await mostrarDialogoRecordatorio(
      context,
      controller: _recordatorioController,
      actual: actual,
    );
    if (!mounted || guardado == null) return;
    setState(() {
      if (indice == null) {
        _recordatorios.add(guardado);
      } else {
        _recordatorios[indice] = guardado;
      }
      _hayCambios = true;
    });
  }

  Future<void> _mostrarDialogoAgregarTratamiento({
    required String categoria,
  }) async {
    final nuevo = await mostrarDialogoTratamiento(
      context,
      controller: _tratamientoController,
      categoria: categoria,
    );
    if (!mounted || nuevo == null) return;
    setState(() {
      _tratamientos.add(nuevo);
      _hayCambios = true;
    });
  }

  Future<void> _mostrarDialogoEditarTratamiento(int indice) async {
    final actualizado = await mostrarDialogoEditarTratamiento(
      context,
      controller: _tratamientoController,
      actual: _tratamientos[indice],
    );
    if (!mounted || actualizado == null) return;
    setState(() {
      _tratamientos[indice] = actualizado;
      _hayCambios = true;
    });
  }


  Future<void> _mostrarDialogoEliminarTratamiento(int indice) async {
    final esDiario = _tratamientos[indice].categoria == 'diario';

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(esDiario ? 'Eliminar tratamiento' : 'Eliminar registro'),
        content: Text(
          esDiario
              ? '¿Qué querés hacer con este tratamiento?'
              : '¿Querés eliminar este registro médico? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          if (esDiario)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _alternarPausaTratamiento(indice);
              },
              child: const Text('Pausar'),
            ),
          TextButton(
            onPressed: () {
              final quitado = _tratamientos[indice];
              setState(() {
                _tratamientos.removeAt(indice);
                _hayCambios = true;
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  persist: false,
                  duration: const Duration(seconds: 5),
                  content: Text('Se eliminó ${_capitalizarPrimera(quitado.medicacion)}'),
                  action: SnackBarAction(
                    label: 'Deshacer',
                    textColor: AppColors.arena,
                    onPressed: () {
                      if (!mounted) return;
                      setState(() {
                        final destino = indice.clamp(0, _tratamientos.length);
                        _tratamientos.insert(destino, quitado);
                        _hayCambios = true;
                      });
                    },
                  ),
                ),
              );
            },
            child: Text(
              esDiario ? 'Eliminar definitivamente' : 'Eliminar',
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmarSalida() async {
    if (!_hayCambios) {
      Navigator.pop(context);
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hay cambios sin guardar'),
        content: const Text('¿Qué querés hacer con los cambios?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Descartar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _guardarDatos();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final esEdicion = widget.idDocumento != null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmarSalida();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(esEdicion ? 'Editar Ficha' : 'Nuevo Ingreso'),
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              child: Column(
                children: [
                  // --- SECCIÓN: Foto de perfil ---
                  Center(
                    child: GestureDetector(
                      onTap: _abrirOpcionesFotoPerfil,
                      child: CircleAvatar(
                        radius: 60,
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        backgroundImage: _imagenSeleccionada != null
                            ? FileImage(_imagenSeleccionada!) as ImageProvider
                            : (widget.perroActual?.fotoPerfil != null
                                  ? NetworkImage(
                                      widget.perroActual!.fotoPerfil!,
                                    )
                                  : null),
                        child:
                            _imagenSeleccionada == null &&
                                widget.perroActual?.fotoPerfil == null
                            ? Icon(
                                Icons.add_a_photo,
                                size: 40,
                                color: Theme.of(context).colorScheme.primary,
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // --- SECCIÓN: Datos básicos (nombre, ingreso, sexo, edad, castración, estado) ---
                  _tarjetaFormulario(
                    titulo: 'Datos básicos',
                    icono: Icons.pets,
                    children: [
                  TextFormField(
                    controller: _nombreController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del perrito',
                      prefixIcon: Icon(Icons.pets),
                    ),
                    validator: _perroController.validarNombre,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _fechaIngresoController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Fecha de ingreso (opcional)',
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    onTap: _seleccionarFechaIngreso,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text('Sexo', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(width: 12),
                      ChoiceChip(
                        label: const Text('Macho'),
                        selected: _sexo == 'macho',
                        onSelected: (_) => setState(() => _sexo = 'macho'),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Hembra'),
                        selected: _sexo == 'hembra',
                        onSelected: (_) => setState(() => _sexo = 'hembra'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Edad indeterminada'),
                    value: _edadIndeterminada,
                    onChanged: (valor) => setState(() {
                      _edadIndeterminada = valor ?? false;
                      if (_edadIndeterminada) {
                        _edadController.clear();
                        _mesesController.clear();
                      }
                    }),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _edadController,
                    enabled: !_edadIndeterminada,
                    decoration: const InputDecoration(
                      labelText: 'Edad estimada (años, opcional)',
                      prefixIcon: Icon(Icons.cake),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  if (!_edadIndeterminada &&
                      _edadController.text.trim() == '0') ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _mesesController,
                      decoration: const InputDecoration(
                        labelText: 'Meses (opcional)',
                        prefixIcon: Icon(Icons.calendar_view_month),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [LengthLimitingTextInputFormatter(2)],
                      validator: _perroController.validarMeses,
                    ),
                  ],
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_sexo == 'hembra' ? '¿Ya está castrada?' : '¿Ya está castrado?'),
                    value: _estaCastrado,
                    onChanged: (valor) => setState(() => _estaCastrado = valor),
                  ),
                  const SizedBox(height: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Estado', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      SelectorEstadoPerro(
                        estado: _estado,
                        onChanged: (valor) => setState(() {
                          _estado = valor;
                          if (valor == 'egresado') _motivoEgreso ??= 'adopcion';
                        }),
                      ),
                    ],
                  ),
                  if (_estado == 'inactivo') ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _fechaFallecimientoController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Fecha de fallecimiento (opcional)',
                        prefixIcon: Icon(Icons.sentiment_very_dissatisfied),
                      ),
                      onTap: _seleccionarFechaFallecimiento,
                    ),
                  ],
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    alignment: Alignment.topCenter,
                    child: _estado == 'egresado'
                        ? Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Motivo', style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    ChoiceChip(
                                      label: const Text('Adoptado'),
                                      selected: _motivoEgreso == 'adopcion',
                                      onSelected: (_) => setState(() => _motivoEgreso = 'adopcion'),
                                    ),
                                    ChoiceChip(
                                      label: const Text('Volvió con su familia'),
                                      selected: _motivoEgreso == 'familia',
                                      onSelected: (_) => setState(() => _motivoEgreso = 'familia'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _fechaEgresoController,
                                  readOnly: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Fecha de egreso (opcional)',
                                    prefixIcon: Icon(Icons.event_available),
                                  ),
                                  onTap: _seleccionarFechaEgreso,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _notaEgresoController,
                                  minLines: 3,
                                  maxLines: 3,
                                  decoration: const InputDecoration(
                                    labelText: 'Nota (opcional)',
                                    helperText: 'La ven también los visitantes. No cargues datos personales.',
                                    helperMaxLines: 3,
                                    alignLabelWithHint: true,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    alignment: Alignment.topCenter,
                    child: widget.perroActual?.estado == 'egresado' && _estado == 'activo'
                        ? Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextFormField(
                                  controller: _fechaRegresoController,
                                  readOnly: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Fecha de regreso al refugio',
                                    prefixIcon: Icon(Icons.login_rounded),
                                  ),
                                  onTap: _seleccionarFechaRegreso,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Los datos del egreso quedan guardados en el historial de la ficha.',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: context.paleta.textoSuave,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                  if (_historialEgresos.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Egresos anteriores (${_historialEgresos.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    for (var i = 0; i < _historialEgresos.length; i++)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _lineaEgresoAnterior(_historialEgresos[i]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Borrar egreso',
                            icon: const Icon(Icons.delete_outline, color: AppColors.error),
                            onPressed: () => _quitarEgresoAnterior(i),
                          ),
                        ],
                      ),
                  ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  // --- SECCIÓN: Familiares vinculados ---
                  _tarjetaFormulario(
                    titulo: 'Familiares',
                    icono: Icons.people_outline,
                    accion: FilledButton.tonalIcon(
                      icon: const Icon(Icons.add),
                      label: const Text('Añadir'),
                      onPressed: _mostrarDialogoAgregarFamiliar,
                    ),
                    children: [
                  if (_parientes.isEmpty)
                    Text(
                      'Sin familiares registrados.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.paleta.textoSuave,
                      ),
                    )
                  else
                    Column(
                      children: _parientes.asMap().entries.map((entry) {
                        final i = entry.key;
                        final p = entry.value;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: AppColors.navy.withValues(alpha: 0.08),
                            child: const Icon(Icons.pets, size: 20, color: AppColors.navy),
                          ),
                          title: Text(p['nombre']?.toString() ?? ''),
                          subtitle: Text(p['relacion']?.toString() ?? ''),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: AppColors.error,
                            ),
                            tooltip: 'Quitar familiar',
                            onPressed: () => setState(() {
                              _parientes.removeAt(i);
                              _hayCambios = true;
                            }),
                          ),
                        );
                      }).toList(),
                    ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // --- SECCIÓN: Historia / observaciones ---
                  _tarjetaFormulario(
                    children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Historia',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            tooltip: 'Negrita',
                            onPressed: () => _insertarFormatoTexto(
                              _historiaController,
                              '**',
                              '**',
                            ),
                            icon: const Icon(Icons.format_bold),
                          ),
                          IconButton(
                            tooltip: 'Cursiva',
                            onPressed: () => _insertarFormatoTexto(
                              _historiaController,
                              '*',
                              '*',
                            ),
                            icon: const Icon(Icons.format_italic),
                          ),
                          IconButton(
                            tooltip: 'Agregar viñeta',
                            onPressed: () =>
                                _insertarBulletTexto(_historiaController),
                            icon: const Icon(Icons.format_list_bulleted),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _historiaController,
                    decoration: const InputDecoration(
                      labelText: 'Descripción de la historia',
                      alignLabelWithHint: true,
                    ),
                    maxLines: 6,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sale en la tarjeta para adoptar. La ven los visitantes.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.paleta.textoSuave),
                  ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // --- SECCIÓN: Gestión de salud ---
                  const Divider(height: 32),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: EncabezadoSeccion(
                      titulo: 'Gestión de Salud',
                      icono: Icons.favorite_outline,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Ficha médica',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: context.paleta.lienzo),
                        ),
                      ),
                      Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            tooltip: 'Negrita',
                            color: context.paleta.lienzo,
                            onPressed: () => _insertarFormatoTexto(
                              _fichaMedicaController,
                              '**',
                              '**',
                            ),
                            icon: const Icon(Icons.format_bold),
                          ),
                          IconButton(
                            tooltip: 'Cursiva',
                            color: context.paleta.lienzo,
                            onPressed: () => _insertarFormatoTexto(
                              _fichaMedicaController,
                              '*',
                              '*',
                            ),
                            icon: const Icon(Icons.format_italic),
                          ),
                          IconButton(
                            tooltip: 'Agregar viñeta',
                            color: context.paleta.lienzo,
                            onPressed: () =>
                                _insertarBulletTexto(_fichaMedicaController),
                            icon: const Icon(Icons.format_list_bulleted),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _fichaMedicaController,
                    decoration: const InputDecoration(
                      labelText: 'Detalles médicos',
                      alignLabelWithHint: true,
                    ),
                    maxLines: 6,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Notas clínicas. No salen en la tarjeta.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.paleta.textoSuave),
                  ),
                  const SizedBox(height: 24),
                  // --- SECCIÓN: Tratamientos (activos y pausados) ---
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Agregar registro médico',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(color: context.paleta.lienzo),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'El diario avisa cada día a la hora elegida. Los demás quedan en la fecha de la aplicación.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.paleta.textoSuave),
                  ),
                  const SizedBox(height: 12),
                  GrillaRegistrosMedicos(
                    alElegir: (categoria) => _mostrarDialogoAgregarTratamiento(categoria: categoria),
                  ),
                  const SizedBox(height: 32),
                  _seccionPeso(),
                  const SizedBox(height: 32),
                  _seccionSeguimientos(),
                  const SizedBox(height: 32),
                  _seccionRecordatorios(),
                  const SizedBox(height: 32),
                  // --- SECCIÓN 1: Tratamientos Diarios (solo categoría diario) ---
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _tituloSeccion(
                      'Tratamientos Diarios',
                      _tratamientos.where((t) => t.categoria == 'diario').length,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      final diariosActivos = _tratamientos
                          .asMap()
                          .entries
                          .where(
                            (e) =>
                                e.value.categoria == 'diario' && e.value.activo,
                          )
                          .toList();
                      final diariosPausados = _tratamientos
                          .asMap()
                          .entries
                          .where(
                            (e) =>
                                e.value.categoria == 'diario' &&
                                !e.value.activo,
                          )
                          .toList();
                      final textTheme = Theme.of(context).textTheme;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (diariosActivos.isEmpty)
                            _estadoVacioSalud(
                              Icons.medication_outlined,
                              'Sin tratamientos diarios activos.',
                            )
                          else
                            AnimatedSize(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOutCubic,
                              alignment: Alignment.topCenter,
                              clipBehavior: Clip.none,
                              child: Column(
                                children: [
                                  for (var n = 0; n < diariosActivos.length; n++)
                                    EntradaEscalonada(
                                      indice: n,
                                      child: _tarjetaTratamientoDiario(
                                        i: diariosActivos[n].key,
                                        t: diariosActivos[n].value,
                                        pausado: false,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          if (diariosPausados.isNotEmpty)
                            ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              shape: const Border(),
                              collapsedShape: const Border(),
                              collapsedIconColor: context.paleta.textoSuave,
                              iconColor: context.paleta.textoSuave,
                              title: Row(
                                children: [
                                  const Icon(
                                    Icons.pause_circle_outline,
                                    size: 20,
                                    color: AppColors.pausado,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Pausados (${diariosPausados.length})',
                                    style: textTheme.titleMedium?.copyWith(
                                      color: context.paleta.textoSuave,
                                    ),
                                  ),
                                ],
                              ),
                              children: [
                                AnimatedSize(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOutCubic,
                                  alignment: Alignment.topCenter,
                                  clipBehavior: Clip.none,
                                  child: Column(
                                    children: [
                                      for (var n = 0; n < diariosPausados.length; n++)
                                        EntradaEscalonada(
                                          indice: n,
                                          child: _tarjetaTratamientoDiario(
                                            i: diariosPausados[n].key,
                                            t: diariosPausados[n].value,
                                            pausado: true,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  // --- SECCIÓN 2: Eventos y Visitas (categoría != diario) ---
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _tituloSeccion(
                      'Eventos y Visitas',
                      _tratamientos.where((t) => t.categoria != 'diario').length,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      final eventos = _tratamientos
                          .asMap()
                          .entries
                          .where((e) => e.value.categoria != 'diario')
                          .toList()
                        ..sort((a, b) {
                          final fechaA = a.value.fechaInicio ??
                              DateTime.fromMillisecondsSinceEpoch(0);
                          final fechaB = b.value.fechaInicio ??
                              DateTime.fromMillisecondsSinceEpoch(0);
                          return fechaB.compareTo(fechaA);
                        });
                      if (eventos.isEmpty) {
                        return _estadoVacioSalud(
                          Icons.event_note_outlined,
                          'Sin eventos ni visitas registrados.',
                        );
                      }

                      return AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        clipBehavior: Clip.none,
                        child: Column(
                          children: [
                            for (var n = 0; n < eventos.length; n++)
                              EntradaEscalonada(
                                indice: n,
                                child: _filaEvento(eventos[n].key, eventos[n].value),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  // --- SECCIÓN: Ubicación (en casa / refugio) ---
                  Card(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    child: CheckboxListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      secondary: const Icon(Icons.home_outlined, color: AppColors.navy),
                      title: const Text('Este perrito/a está en casa'),
                      value: _enCasa,
                      onChanged: (valor) =>
                          setState(() => _enCasa = valor ?? false),
                    ),
                  ),
                  if (widget.idDocumento != null) ...[
                    const SizedBox(height: 24),
                    TextButton.icon(
                      onPressed: _confirmarEliminarFicha,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Eliminar ficha'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        // --- SECCIÓN: Acción de guardado (barra inferior fija) ---
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: context.paleta.superficie,
            border: Border(top: BorderSide(color: context.paleta.borde)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: FilledButton(
                onPressed: _estaGuardando ? null : _guardarDatos,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  textStyle: Theme.of(context).textTheme.titleMedium,
                ),
                child: _estaGuardando
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.6,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      )
                    : Text(esEdicion ? 'Guardar Cambios' : 'Crear Ficha'),
              ),
            ),
          ),
        ),
      ), // cierra Scaffold
    ); // cierra PopScope
  }
}

/// Activo, fallecido o egresado, en un control que ocupa el ancho
/// y no corta la etiqueta.
class SelectorEstadoPerro extends StatelessWidget {
  final String estado;
  final ValueChanged<String> onChanged;

  const SelectorEstadoPerro({
    super.key,
    required this.estado,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final actual = switch (estado) {
      'inactivo' => 'inactivo',
      'egresado' => 'egresado',
      _ => 'activo',
    };
    return SegmentedButton<String>(
      expandedInsets: EdgeInsets.zero,
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(value: 'activo', label: Text('Activo', overflow: TextOverflow.ellipsis)),
        ButtonSegment(value: 'inactivo', label: Text('Fallecido', overflow: TextOverflow.ellipsis)),
        ButtonSegment(value: 'egresado', label: Text('Egresado', overflow: TextOverflow.ellipsis)),
      ],
      selected: {actual},
      onSelectionChanged: (seleccion) => onChanged(seleccion.first),
    );
  }
}
