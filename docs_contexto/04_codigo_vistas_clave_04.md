# 04 — Código de vistas clave (4 de 9)

Código fuente copiado tal cual. Cada bloque indica archivo y rango de líneas.

### `lib/views/formulario_perro.dart` — parte 1/4, líneas 1–500 de 1978

```dart
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
import '../controllers/tratamiento_controller.dart';
import '../models/perro_model.dart';
import '../models/tratamiento_model.dart';
import '../theme/app_colors.dart';
import '../theme/category_colors.dart';
import '../theme/entrada_escalonada.dart';

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
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _edadController = TextEditingController();
  final TextEditingController _mesesController = TextEditingController();
  final TextEditingController _historiaController = TextEditingController();
  final TextEditingController _fichaMedicaController = TextEditingController();
  final TextEditingController _fechaIngresoController = TextEditingController();
  final TextEditingController _fechaFallecimientoController =
      TextEditingController();

  DateTime? _fechaIngreso;
  DateTime? _fechaFallecimiento;
  bool _estaCastrado = false;
  bool _enCasa = false;
  bool _estaGuardando = false;
  bool _edadIndeterminada = false;
  String _estado = 'activo';
  String _sexo = 'macho';
  List<Map<String, dynamic>> _parientes = [];
  List<TratamientoModel> _tratamientos = [];

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

      _fechaFallecimiento = perro.fechaFallecimiento;
      _fechaFallecimientoController.text = _fechaFallecimiento != null
          ? '${_fechaFallecimiento!.day.toString().padLeft(2, '0')}/${_fechaFallecimiento!.month.toString().padLeft(2, '0')}/${_fechaFallecimiento!.year}'
          : '';
    }
    // Registrar listeners después de cargar valores iniciales para no marcar cambios prematuros
    for (final c in [
      _nombreController,
      _edadController,
      _mesesController,
      _historiaController,
      _fichaMedicaController,
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
                ..pop();
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

        final perro = PerroModel(
          id: widget.idDocumento ?? '',
          nombre: _nombreController.text.trim(),
          sexo: _sexo,
          estado: _estado,
          edad: int.tryParse(_edadController.text.trim()) ?? 0,
          meses: int.tryParse(_mesesController.text.trim()) ?? 0,
          edadIndeterminada: _edadIndeterminada,
          edadAnioBase: _estado != 'inactivo' ? DateTime.now().year : null,
          fechaIngreso: _fechaIngreso,
          fechaFallecimiento: _estado == 'inactivo'
              ? _fechaFallecimiento
              : null,
          ultimaActualizacionEdad: DateTime.now(),
          historia: _historiaController.text.trim(),
          fichaMedica: _fichaMedicaController.text.trim(),
          castrado: _estaCastrado,
          enCasa: _enCasa,
          fotoPerfil: urlImagen,
          parientes: parientesNormalizados,
          tratamientos: _tratamientos,
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
```

