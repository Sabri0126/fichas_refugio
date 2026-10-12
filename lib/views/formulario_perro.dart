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
import '../controllers/recordatorio_controller.dart';
import '../controllers/tratamiento_controller.dart';
import '../models/egreso_model.dart';
import '../models/estado_duracion.dart';
import '../models/perro_model.dart';
import '../models/recordatorio_model.dart';
import '../models/tratamiento_model.dart';
import '../theme/app_colors.dart';
import '../theme/category_colors.dart';
import '../theme/entrada_escalonada.dart';
import '../theme/recordatorio_tipos.dart';

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
  List<RecordatorioModel> _recordatorios = [];

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
      _recordatorios = List<RecordatorioModel>.from(perro.recordatorios);
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
    final motivo = _perroController.formatearMotivoEgreso(egreso.motivo);
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
            }
          } catch (_) {}
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
          recordatorios: _recordatorios,
        );

        await _perroController.guardarPerro(perro);

        if (mounted) {
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

  String _tituloDialogoAgregar(String categoria) {
    switch (categoria) {
      case 'unico':
        return 'Agregar dosis única';
      case 'higiene':
        return 'Agregar higiene';
      case 'evento':
        return 'Agregar evento médico';
      case 'veterinaria':
        return 'Agregar visita veterinaria';
      default:
        return 'Agregar tratamiento diario';
    }
  }

  Widget _botonCategoriaSalud({
    required String etiqueta,
    required IconData icono,
    required Color color,
    required String categoria,
  }) {
    final colorTexto = CategoryColors.texto(categoria);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () => _mostrarDialogoAgregarTratamiento(categoria: categoria),
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.superficie,
          foregroundColor: colorTexto,
          side: const BorderSide(color: AppColors.bordeTarjeta),
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
              child: Icon(icono, size: 20, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                etiqueta,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
        color: AppColors.rellenoInput,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.bordeTarjeta),
      ),
      child: Row(
        children: [
          Icon(icono, color: AppColors.pendiente),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              texto,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textoSecundario,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tituloSeccion(String titulo, int cantidad) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Flexible(
          child: Text(
            titulo,
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.navy.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$cantidad',
            style: textTheme.labelMedium?.copyWith(color: AppColors.navy),
          ),
        ),
      ],
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
          color: activo ? AppColors.activoTexto : AppColors.pausadoTexto,
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

  String _helperDias(String texto, DateTime inicio) {
    final dias = int.tryParse(texto.trim()) ?? 0;
    if (dias <= 0) return 'Sin fecha de fin.';
    final ultimo = DateTime(inicio.year, inicio.month, inicio.day + dias - 1);
    final dia = ultimo.day.toString().padLeft(2, '0');
    final mes = ultimo.month.toString().padLeft(2, '0');
    return 'El día de inicio cuenta como día 1. Último día de medicación: $dia/$mes/${ultimo.year}';
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
    final subtitulo = pausado
        ? '${t.indicaciones} · ${dias > 0 ? '$dias días' : 'Indefinido'}'
        : '${t.indicaciones} · ${dias > 0 ? '$dias días' : 'Indefinido'} · Desde $fechaTexto'
            '${horaRecordatorio.isNotEmpty ? ' · Recordatorio $horaRecordatorio' : ''}'
            '$sufijo';
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
                          const SizedBox(height: 2),
                          Text(
                            subtitulo,
                            style: textTheme.bodyMedium?.copyWith(
                              color: AppColors.textoSecundario,
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
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

  Widget _filaEvento(int i, TratamientoModel t) {
    final textTheme = Theme.of(context).textTheme;
    final fechaTexto = t.fechaInicio != null
        ? '${t.fechaInicio!.day.toString().padLeft(2, '0')}/${t.fechaInicio!.month.toString().padLeft(2, '0')}/${t.fechaInicio!.year}'
        : 'Sin fecha';
    final color = _colorCategoria(t.categoria);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.superficie,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.bordeTarjeta),
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
          subtitle: Text(
            '${_etiquetaCategoria(t.categoria)} · $fechaTexto'
            '${t.indicaciones.isNotEmpty ? ' · ${t.indicaciones}' : ''}',
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.textoSecundario,
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
                color: AppColors.textoSecundario,
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

  String _etiquetaCategoria(String categoria) {
    return switch (categoria) {
      'unico' => 'Dosis única',
      'higiene' => 'Higiene',
      'evento' => 'Evento médico',
      'veterinaria' => 'Veterinaria',
      _ => 'Tratamiento diario',
    };
  }

  IconData _iconoCategoria(String categoria) {
    return switch (categoria) {
      'unico' => Icons.vaccines,
      'higiene' => Icons.shower,
      'evento' => Icons.monitor_heart,
      'veterinaria' => Icons.local_hospital,
      _ => Icons.medication,
    };
  }

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

  Widget _seccionRecordatorios() {
    final proximos = _recordatorioController.proximos(_recordatorios);
    final vencidos = _recordatorioController.vencidos(_recordatorios);
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tituloSeccion('Recordatorios', proximos.length),
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
          'Se guarda al tocar Guardar Cambios.',
          style: textTheme.bodyMedium?.copyWith(color: AppColors.textoSecundario),
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
              collapsedIconColor: AppColors.textoSecundario,
              iconColor: AppColors.textoSecundario,
              title: Row(
                children: [
                  const Icon(Icons.history_rounded, size: 20, color: AppColors.textoSecundario),
                  const SizedBox(width: 8),
                  Text(
                    'Vencidos (${vencidos.length})',
                    style: textTheme.titleMedium?.copyWith(color: AppColors.textoSecundario),
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
        color: AppColors.superficie,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.bordeTarjeta),
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
              color: AppColors.textoSecundario,
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
                color: AppColors.textoSecundario,
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
    final exigirFutura = actual == null || _recordatorioController.esVencido(actual);
    var tipo = actual?.tipo ?? 'veterinaria';
    final tituloController = TextEditingController(
      text: actual?.titulo ?? RecordatorioTipos.de(tipo).tituloSugerido,
    );
    final notaController = TextEditingController(text: actual?.nota ?? '');
    final base = actual?.fechaHora ?? _mananaALasNueve();
    var fechaHora = DateTime(base.year, base.month, base.day, base.hour, base.minute);
    var errorFecha = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final hoy = DateTime.now();
          final primerDia = DateTime(hoy.year, hoy.month, hoy.day);
          final fechaInicial = fechaHora.isBefore(primerDia) ? primerDia : fechaHora;
          final fechaTexto =
              '${fechaHora.day.toString().padLeft(2, '0')}/${fechaHora.month.toString().padLeft(2, '0')}/${fechaHora.year}';
          final horaTexto =
              '${fechaHora.hour.toString().padLeft(2, '0')}:${fechaHora.minute.toString().padLeft(2, '0')}';

          return AlertDialog(
            title: Text(actual == null ? 'Agendar recordatorio' : 'Editar recordatorio'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final visual in RecordatorioTipos.todos)
                        ChoiceChip(
                          avatar: Icon(visual.icono, size: 18, color: visual.colorTexto),
                          label: Text(visual.etiqueta),
                          selected: tipo == visual.tipo,
                          onSelected: (seleccionado) {
                            if (!seleccionado) return;
                            setDialogState(() {
                              final sugeridoAnterior = RecordatorioTipos.de(tipo).tituloSugerido;
                              final texto = tituloController.text.trim();
                              tipo = visual.tipo;
                              if (texto.isEmpty || texto == sugeridoAnterior) {
                                tituloController.text = visual.tituloSugerido;
                              }
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: tituloController,
                    decoration: const InputDecoration(labelText: 'Título'),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Fecha: $fechaTexto'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final seleccionada = await showDatePicker(
                        context: ctx,
                        initialDate: fechaInicial,
                        firstDate: primerDia,
                        lastDate: DateTime(2100),
                      );
                      if (seleccionada == null) return;
                      setDialogState(() {
                        fechaHora = DateTime(
                          seleccionada.year,
                          seleccionada.month,
                          seleccionada.day,
                          fechaHora.hour,
                          fechaHora.minute,
                        );
                        errorFecha = false;
                      });
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Hora: $horaTexto'),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final seleccionada = await showTimePicker(
                        context: ctx,
                        initialTime: TimeOfDay.fromDateTime(fechaHora),
                        builder: (BuildContext context, Widget? child) {
                          return MediaQuery(
                            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                            child: child!,
                          );
                        },
                      );
                      if (seleccionada == null) return;
                      setDialogState(() {
                        fechaHora = DateTime(
                          fechaHora.year,
                          fechaHora.month,
                          fechaHora.day,
                          seleccionada.hour,
                          seleccionada.minute,
                        );
                        errorFecha = false;
                      });
                    },
                  ),
                  if (errorFecha)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Elegí una fecha y hora futuras',
                        style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(color: AppColors.error),
                      ),
                    ),
                  TextField(
                    controller: notaController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Nota (opcional)',
                      helperMaxLines: 2,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  final titulo = tituloController.text.trim();
                  if (titulo.isEmpty) return;
                  if (exigirFutura && !fechaHora.isAfter(DateTime.now())) {
                    setDialogState(() => errorFecha = true);
                    return;
                  }
                  final guardado = actual == null
                      ? _recordatorioController.crear(
                          tipo: tipo,
                          titulo: titulo,
                          nota: notaController.text,
                          fechaHora: fechaHora,
                        )
                      : _recordatorioController.editar(
                          actual,
                          tipo: tipo,
                          titulo: titulo,
                          nota: notaController.text,
                          fechaHora: fechaHora,
                        );
                  setState(() {
                    if (indice == null) {
                      _recordatorios.add(guardado);
                    } else {
                      _recordatorios[indice] = guardado;
                    }
                    _hayCambios = true;
                  });
                  Navigator.pop(ctx);
                },
                child: Text(actual == null ? 'Agregar' : 'Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }

  DateTime _mananaALasNueve() {
    final manana = DateTime.now().add(const Duration(days: 1));
    return DateTime(manana.year, manana.month, manana.day, 9, 0);
  }

  Future<void> _mostrarDialogoAgregarTratamiento({
    required String categoria,
  }) async {
    final medicacionController = TextEditingController();
    final indicacionesController = TextEditingController();
    final diasController = TextEditingController(text: '0');
    DateTime fechaInicio = DateTime.now();
    TimeOfDay horaRecordatorio = const TimeOfDay(hour: 9, minute: 0);

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final esEventoUnico = categoria != 'diario';
          final labelPrimerCampo = switch (categoria) {
            'veterinaria' => 'Motivo de la visita',
            'unico' => 'Medicación / Aplicación',
            'higiene' => 'Procedimiento / Cuidado',
            'evento' => 'Evento / Motivo',
            _ => 'Medicación',
          };
          final labelSegundoCampo = switch (categoria) {
            'veterinaria' => 'Diagnóstico / Indicaciones',
            'evento' => 'Notas / Indicaciones',
            _ => 'Indicaciones',
          };
          final labelFecha = switch (categoria) {
            'veterinaria' => 'Fecha de visita',
            'unico' => 'Fecha de aplicación',
            'higiene' => 'Fecha',
            'evento' => 'Fecha del evento',
            _ => 'Fecha de inicio',
          };

          return AlertDialog(
            title: Text(_tituloDialogoAgregar(categoria)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: medicacionController,
                    decoration: InputDecoration(
                      labelText: labelPrimerCampo,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: indicacionesController,
                    decoration: InputDecoration(
                      labelText: labelSegundoCampo,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!esEventoUnico)
                    TextField(
                      controller: diasController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Días de duración (0 = indefinido)',
                        helperText: _helperDias(diasController.text, fechaInicio),
                        helperMaxLines: 2,
                      ),
                    ),
                  if (!esEventoUnico) const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '$labelFecha: ${fechaInicio.day.toString().padLeft(2, '0')}/${fechaInicio.month.toString().padLeft(2, '0')}/${fechaInicio.year}',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final seleccionada = await showDatePicker(
                        context: ctx,
                        initialDate: fechaInicio,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (seleccionada != null) {
                        setDialogState(() => fechaInicio = seleccionada);
                      }
                    },
                  ),
                  if (!esEventoUnico)
                    InkWell(
                      onTap: () async {
                        final seleccionada = await showTimePicker(
                          context: ctx,
                          initialTime: horaRecordatorio,
                          builder: (BuildContext context, Widget? child) {
                            return MediaQuery(
                              data: MediaQuery.of(
                                context,
                              ).copyWith(alwaysUse24HourFormat: true),
                              child: child!,
                            );
                          },
                        );
                        if (seleccionada != null) {
                          setDialogState(() => horaRecordatorio = seleccionada);
                        }
                      },
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Hora del recordatorio: ${horaRecordatorio.hour.toString().padLeft(2, '0')}:${horaRecordatorio.minute.toString().padLeft(2, '0')}',
                        ),
                        trailing: const Icon(Icons.access_time),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  final medicacion = medicacionController.text.trim();
                  if (medicacion.isEmpty) return;

                  final horaFormateada =
                      '${horaRecordatorio.hour.toString().padLeft(2, '0')}:${horaRecordatorio.minute.toString().padLeft(2, '0')}';

                  final nuevoTratamiento = _tratamientoController
                      .crearTratamiento(
                        categoria: categoria,
                        medicacion: medicacion,
                        indicaciones: indicacionesController.text.trim(),
                        fechaInicio: fechaInicio,
                        diasDuracion:
                            int.tryParse(diasController.text.trim()) ?? 0,
                        horaRecordatorio: horaFormateada,
                      );

                  setState(() {
                    _tratamientos.add(nuevoTratamiento);
                    _hayCambios = true;
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Agregar'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _mostrarDialogoEditarTratamiento(int indice) async {
    final tratamiento = _tratamientos[indice];
    final medicacionController = TextEditingController(
      text: tratamiento.medicacion,
    );
    final indicacionesController = TextEditingController(
      text: tratamiento.indicaciones,
    );
    final diasController = TextEditingController(
      text: tratamiento.diasDuracion.toString(),
    );

    DateTime fechaInicio = tratamiento.fechaInicio ?? DateTime.now();

    final partesHora = (tratamiento.horaRecordatorio ?? '09:00').split(':');
    TimeOfDay horaRecordatorio = TimeOfDay(
      hour: int.tryParse(partesHora.isNotEmpty ? partesHora[0] : '') ?? 9,
      minute: int.tryParse(partesHora.length > 1 ? partesHora[1] : '') ?? 0,
    );

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Editar tratamiento'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: medicacionController,
                  decoration: const InputDecoration(
                    labelText: 'Medicación',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: indicacionesController,
                  decoration: const InputDecoration(
                    labelText: 'Indicaciones',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: diasController,
                  keyboardType: TextInputType.number,
                  onChanged: tratamiento.categoria == 'diario' ? (_) => setDialogState(() {}) : null,
                  decoration: InputDecoration(
                    labelText: 'Días de duración (0 = indefinido)',
                    helperText: tratamiento.categoria == 'diario'
                        ? _helperDias(diasController.text, fechaInicio)
                        : null,
                    helperMaxLines: tratamiento.categoria == 'diario' ? 2 : null,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Fecha de inicio: ${fechaInicio.day.toString().padLeft(2, '0')}/${fechaInicio.month.toString().padLeft(2, '0')}/${fechaInicio.year}',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final seleccionada = await showDatePicker(
                      context: ctx,
                      initialDate: fechaInicio,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (seleccionada != null) {
                      setDialogState(() => fechaInicio = seleccionada);
                    }
                  },
                ),
                InkWell(
                  onTap: () async {
                    final seleccionada = await showTimePicker(
                      context: ctx,
                      initialTime: horaRecordatorio,
                      builder: (BuildContext context, Widget? child) {
                        return MediaQuery(
                          data: MediaQuery.of(
                            context,
                          ).copyWith(alwaysUse24HourFormat: true),
                          child: child!,
                        );
                      },
                    );
                    if (seleccionada != null) {
                      setDialogState(() => horaRecordatorio = seleccionada);
                    }
                  },
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Hora del recordatorio: ${horaRecordatorio.hour.toString().padLeft(2, '0')}:${horaRecordatorio.minute.toString().padLeft(2, '0')}',
                    ),
                    trailing: const Icon(Icons.access_time),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final medicacion = medicacionController.text.trim();
                if (medicacion.isEmpty) return;

                final horaFormateada =
                    '${horaRecordatorio.hour.toString().padLeft(2, '0')}:${horaRecordatorio.minute.toString().padLeft(2, '0')}';

                setState(() {
                  _tratamientos[indice] = _tratamientoController
                      .editarTratamiento(
                        tratamiento,
                        medicacion: medicacion,
                        indicaciones: indicacionesController.text.trim(),
                        diasDuracion:
                            int.tryParse(diasController.text.trim()) ?? 0,
                        fechaInicio: fechaInicio,
                        horaRecordatorio: horaFormateada,
                      );
                  _hayCambios = true;
                });
                Navigator.pop(ctx);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
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
              setState(() {
                _tratamientos.removeAt(indice);
                _hayCambios = true;
              });
              Navigator.pop(ctx);
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
                    title: const Text('¿Ya está castrado?'),
                    value: _estaCastrado,
                    onChanged: (valor) => setState(() => _estaCastrado = valor),
                  ),
                  const SizedBox(height: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Estado', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Activo'),
                            selected: _estado == 'activo',
                            onSelected: (_) => setState(() => _estado = 'activo'),
                          ),
                          ChoiceChip(
                            label: const Text('Inactivo'),
                            selected: _estado == 'inactivo',
                            onSelected: (_) => setState(() => _estado = 'inactivo'),
                          ),
                          ChoiceChip(
                            label: const Text('Egresado'),
                            selected: _estado == 'egresado',
                            onSelected: (_) => setState(() {
                              _estado = 'egresado';
                              _motivoEgreso ??= 'adopcion';
                            }),
                          ),
                        ],
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
                                    color: AppColors.textoSecundario,
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
                        color: AppColors.textoSecundario,
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
                    ],
                  ),
                  const SizedBox(height: 24),
                  // --- SECCIÓN: Gestión de salud ---
                  const Divider(height: 32),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        const Icon(Icons.favorite_outline, color: AppColors.navy),
                        const SizedBox(width: 8),
                        Text(
                          'Gestión de Salud',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Ficha médica',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            tooltip: 'Negrita',
                            onPressed: () => _insertarFormatoTexto(
                              _fichaMedicaController,
                              '**',
                              '**',
                            ),
                            icon: const Icon(Icons.format_bold),
                          ),
                          IconButton(
                            tooltip: 'Cursiva',
                            onPressed: () => _insertarFormatoTexto(
                              _fichaMedicaController,
                              '*',
                              '*',
                            ),
                            icon: const Icon(Icons.format_italic),
                          ),
                          IconButton(
                            tooltip: 'Agregar viñeta',
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
                  const SizedBox(height: 24),
                  // --- SECCIÓN: Tratamientos (activos y pausados) ---
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Agregar registro médico',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      const espacio = 12.0;
                      final anchoCelda = (constraints.maxWidth - espacio) / 2;
                      return Wrap(
                        spacing: espacio,
                        runSpacing: espacio,
                        children: [
                          SizedBox(
                            width: anchoCelda,
                            child: _botonCategoriaSalud(
                              etiqueta: 'Tratamiento Diario',
                              icono: Icons.medication,
                              color: CategoryColors.base('diario'),
                              categoria: 'diario',
                            ),
                          ),
                          SizedBox(
                            width: anchoCelda,
                            child: _botonCategoriaSalud(
                              etiqueta: 'Dosis Única',
                              icono: Icons.vaccines,
                              color: CategoryColors.base('unico'),
                              categoria: 'unico',
                            ),
                          ),
                          SizedBox(
                            width: anchoCelda,
                            child: _botonCategoriaSalud(
                              etiqueta: 'Higiene',
                              icono: Icons.shower,
                              color: CategoryColors.base('higiene'),
                              categoria: 'higiene',
                            ),
                          ),
                          SizedBox(
                            width: anchoCelda,
                            child: _botonCategoriaSalud(
                              etiqueta: 'Evento Médico',
                              icono: Icons.monitor_heart,
                              color: CategoryColors.base('evento'),
                              categoria: 'evento',
                            ),
                          ),
                          SizedBox(
                            width: anchoCelda,
                            child: _botonCategoriaSalud(
                              etiqueta: 'Veterinaria',
                              icono: Icons.local_hospital,
                              color: CategoryColors.base('veterinaria'),
                              categoria: 'veterinaria',
                            ),
                          ),
                        ],
                      );
                    },
                  ),
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
                              collapsedIconColor: AppColors.textoSecundario,
                              iconColor: AppColors.textoSecundario,
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
                                      color: AppColors.textoSecundario,
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
          decoration: const BoxDecoration(
            color: AppColors.superficie,
            border: Border(top: BorderSide(color: AppColors.bordeTarjeta)),
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
