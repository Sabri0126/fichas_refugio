import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

class FormularioPerro extends StatefulWidget {
  final String? idDocumento;
  final Map<String, dynamic>? datosActuales;

  const FormularioPerro({super.key, this.idDocumento, this.datosActuales});

  @override
  State<FormularioPerro> createState() => _FormularioPerroState();
}

class _FormularioPerroState extends State<FormularioPerro> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _edadController = TextEditingController();
  final TextEditingController _historiaController = TextEditingController();
  final TextEditingController _fichaMedicaController = TextEditingController();
  final TextEditingController _fechaIngresoController = TextEditingController();
  final TextEditingController _fechaFallecimientoController = TextEditingController();

  DateTime? _fechaIngreso;
  DateTime? _fechaFallecimiento;
  bool _estaCastrado = false;
  bool _enCasa = false;
  bool _estaGuardando = false;
  String _estado = 'activo';
  String _sexo = 'macho';
  List<Map<String, dynamic>> _parientes = [];

  bool _hayCambios = false;

  File? _imagenSeleccionada;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.datosActuales != null) {
      _nombreController.text = widget.datosActuales!['nombre'] ?? '';
      _edadController.text = widget.datosActuales!['edad']?.toString() ?? '';
      _historiaController.text = widget.datosActuales!['historia'] ?? '';
      _fichaMedicaController.text = widget.datosActuales!['ficha_medica'] ?? '';

      final fecha = widget.datosActuales!['fecha_ingreso'];
      if (fecha is Timestamp) {
        _fechaIngreso = fecha.toDate();
      } else if (fecha is DateTime) {
        _fechaIngreso = fecha;
      } else if (fecha is String) {
        _fechaIngreso = DateTime.tryParse(fecha);
      }

      _fechaIngresoController.text = _fechaIngreso != null
          ? '${_fechaIngreso!.day.toString().padLeft(2, '0')}/${_fechaIngreso!.month.toString().padLeft(2, '0')}/${_fechaIngreso!.year}'
          : '';
      _estaCastrado = widget.datosActuales!['castrado'] ?? false;
      _enCasa = widget.datosActuales!['en_casa'] ?? false;
      _estado = widget.datosActuales!['estado'] ?? 'activo';
      _sexo = widget.datosActuales!['sexo'] ?? 'macho';
      final parientesRaw = widget.datosActuales!['parientes'];
      if (parientesRaw is List) {
        _parientes = parientesRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }

      final fechaFall = widget.datosActuales!['fecha_fallecimiento'];
      if (fechaFall is Timestamp) {
        _fechaFallecimiento = fechaFall.toDate();
      } else if (fechaFall is DateTime) {
        _fechaFallecimiento = fechaFall;
      } else if (fechaFall is String) {
        _fechaFallecimiento = DateTime.tryParse(fechaFall);
      }
      _fechaFallecimientoController.text = _fechaFallecimiento != null
          ? '${_fechaFallecimiento!.day.toString().padLeft(2, '0')}/${_fechaFallecimiento!.month.toString().padLeft(2, '0')}/${_fechaFallecimiento!.year}'
          : '';
    }
    // Registrar listeners después de cargar valores iniciales para no marcar cambios prematuros
    for (final c in [_nombreController, _edadController, _historiaController, _fichaMedicaController]) {
      c.addListener(() => setState(() => _hayCambios = true));
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _edadController.dispose();
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
        _fechaIngresoController.text = '${fechaSeleccionada.day.toString().padLeft(2, '0')}/${fechaSeleccionada.month.toString().padLeft(2, '0')}/${fechaSeleccionada.year}';
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

  void _insertarFormatoTexto(TextEditingController controller, String delimitadorInicio, String delimitadorFin) {
    final selection = controller.selection;
    final start = selection.isValid ? selection.start : controller.text.length;
    final end = selection.isValid ? selection.end : controller.text.length;
    final text = controller.text;
    final selectedText = text.substring(start, end);
    final prefix = text.substring(0, start);
    final suffix = text.substring(end);

    final nuevoTexto = '$prefix$delimitadorInicio$selectedText$delimitadorFin$suffix';
    final nuevaPosicion = start + delimitadorInicio.length + selectedText.length + delimitadorFin.length;

    controller.value = TextEditingValue(
      text: nuevoTexto,
      selection: TextSelection.collapsed(offset: nuevaPosicion),
    );
  }

  Future<void> _seleccionarImagen() async {
    final XFile? imagen = await _picker.pickImage(source: ImageSource.gallery);
    if (imagen == null) return;

    try {
      final soportaRecorte = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

      if (!soportaRecorte) {
        setState(() => _imagenSeleccionada = File(imagen.path));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Se usará la imagen original porque el recorte no está disponible en esta plataforma.')),
          );
        }
        return;
      }

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: imagen.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Ajustar imagen',
            toolbarColor: Theme.of(context).colorScheme.primary,
            toolbarWidgetColor: Theme.of(context).colorScheme.onPrimary,
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
          const SnackBar(content: Text('El recorte de imagen no está disponible aquí. Se usará la imagen original.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo procesar la imagen.')));
      }
    }
  }

  Future<void> _guardarDatos() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _estaGuardando = true);

      try {
        String? urlImagen = widget.datosActuales?['foto_perfil'];

        if (_imagenSeleccionada != null) {
          final nombreArchivo = '${DateTime.now().millisecondsSinceEpoch}.jpg';
          final ref = FirebaseStorage.instance.ref().child('fotos_perfil').child(nombreArchivo);
          await ref.putFile(_imagenSeleccionada!);
          urlImagen = await ref.getDownloadURL();
        }

        final datosFicha = {
          'nombre': _nombreController.text.trim(),
          if (_fechaIngreso != null) 'fecha_ingreso': Timestamp.fromDate(_fechaIngreso!),
          'sexo': _sexo,
          'edad': int.tryParse(_edadController.text.trim()) ?? 0,
          if (_estado != 'inactivo') 'edad_anio_base': DateTime.now().year,
          'historia': _historiaController.text.trim(),
          'ficha_medica': _fichaMedicaController.text.trim(),
          'castrado': _estaCastrado,
          'en_casa': _enCasa,
          'estado': _estado,
          if (_estado == 'inactivo' && _fechaFallecimiento != null)
            'fecha_fallecimiento': Timestamp.fromDate(_fechaFallecimiento!),
          'parientes': _parientes,
          'foto_perfil': ?urlImagen,
        };

        if (widget.idDocumento == null) {
          await FirebaseFirestore.instance.collection('perros').add(datosFicha);
        } else {
          await FirebaseFirestore.instance.collection('perros').doc(widget.idDocumento).set(datosFicha, SetOptions(merge: true));
        }

        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al procesar la información')));
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

    final snapshot = await FirebaseFirestore.instance.collection('perros').get();
    final opciones = snapshot.docs
        .where((d) => d.id != widget.idDocumento)
        .map((d) => {'id': d.id, 'nombre': (d.data())['nombre']?.toString() ?? d.id})
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
                decoration: const InputDecoration(labelText: 'Perro', border: OutlineInputBorder()),
                initialValue: seleccionadoId,
                items: opciones
                    .map((o) => DropdownMenuItem(value: o['id'], child: Text(o['nombre']!)))
                    .toList(),
                onChanged: (val) => setDialogState(() {
                  seleccionadoId = val;
                  seleccionadoNombre = opciones.firstWhere((o) => o['id'] == val)['nombre'];
                }),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Relación', border: OutlineInputBorder()),
                initialValue: seleccionadaRelacion,
                items: relaciones
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (val) => setDialogState(() => seleccionadaRelacion = val!),
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
        title: Text(esEdicion ? 'Editar Ficha' : 'Nuevo Ingreso', style: const TextStyle(color: Colors.white)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            child: Column(
              children: [
              Center(
                child: GestureDetector(
                  onTap: _seleccionarImagen,
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    backgroundImage: _imagenSeleccionada != null
                        ? FileImage(_imagenSeleccionada!) as ImageProvider
                        : (widget.datosActuales?['foto_perfil'] != null ? NetworkImage(widget.datosActuales!['foto_perfil']) : null),
                    child: _imagenSeleccionada == null && widget.datosActuales?['foto_perfil'] == null
                        ? Icon(Icons.add_a_photo, size: 40, color: Theme.of(context).colorScheme.primary)
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(controller: _nombreController, decoration: const InputDecoration(labelText: 'Nombre del perrito', border: OutlineInputBorder(), prefixIcon: Icon(Icons.pets)), validator: (value) => value == null || value.trim().isEmpty ? 'Ingresá un nombre' : null),
              const SizedBox(height: 16),
              TextFormField(
                controller: _fechaIngresoController,
                readOnly: true,
                decoration: const InputDecoration(labelText: 'Fecha de ingreso (opcional)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_today)),
                onTap: _seleccionarFechaIngreso,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Sexo: ', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 12),
                  ChoiceChip(
                    label: const Text('Macho'),
                    selected: _sexo == 'macho',
                    selectedColor: Colors.blue.shade200,
                    onSelected: (_) => setState(() => _sexo = 'macho'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Hembra'),
                    selected: _sexo == 'hembra',
                    selectedColor: Colors.pink.shade200,
                    onSelected: (_) => setState(() => _sexo = 'hembra'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(controller: _edadController, decoration: const InputDecoration(labelText: 'Edad estimada (años, opcional)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.cake)), keyboardType: TextInputType.number),
              const SizedBox(height: 16),
              SwitchListTile(title: const Text('¿Ya está castrado?'), value: _estaCastrado, activeThumbColor: Colors.deepOrange, onChanged: (valor) => setState(() => _estaCastrado = valor)),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Estado: ', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 12),
                  ChoiceChip(
                    label: const Text('Activo'),
                    selected: _estado == 'activo',
                    selectedColor: Colors.green.shade200,
                    onSelected: (_) => setState(() => _estado = 'activo'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Inactivo'),
                    selected: _estado == 'inactivo',
                    selectedColor: Colors.blueGrey.shade200,
                    onSelected: (_) => setState(() => _estado = 'inactivo'),
                  ),
                ],
              ),
              if (_estado == 'inactivo') ...
                [
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _fechaFallecimientoController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Fecha de fallecimiento (opcional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.sentiment_very_dissatisfied),
                    ),
                    onTap: _seleccionarFechaFallecimiento,
                  ),
                ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('Familiares', style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Añadir familiar'),
                    style: ElevatedButton.styleFrom(elevation: 2),
                    onPressed: _mostrarDialogoAgregarFamiliar,
                  ),
                ],
              ),
              if (_parientes.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Sin familiares registrados.'),
                )
              else
                Column(
                  children: _parientes.asMap().entries.map((entry) {
                    final i = entry.key;
                    final p = entry.value;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.people),
                      title: Text(p['nombre']?.toString() ?? ''),
                      subtitle: Text(p['relacion']?.toString() ?? ''),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        onPressed: () => setState(() {
                          _parientes.removeAt(i);
                          _hayCambios = true;
                        }),
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text('Historia', style: Theme.of(context).textTheme.titleMedium),
                  ),
                  Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        tooltip: 'Negrita',
                        onPressed: () => _insertarFormatoTexto(_historiaController, '**', '**'),
                        icon: const Icon(Icons.format_bold),
                      ),
                      IconButton(
                        tooltip: 'Cursiva',
                        onPressed: () => _insertarFormatoTexto(_historiaController, '*', '*'),
                        icon: const Icon(Icons.format_italic),
                      ),
                      IconButton(
                        tooltip: 'Agregar viñeta',
                        onPressed: () => _insertarBulletTexto(_historiaController),
                        icon: const Icon(Icons.format_list_bulleted),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _historiaController,
                decoration: const InputDecoration(labelText: 'Descripción de la historia', border: OutlineInputBorder()),
                maxLines: 6,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text('Ficha médica', style: Theme.of(context).textTheme.titleMedium),
                  ),
                  Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        tooltip: 'Negrita',
                        onPressed: () => _insertarFormatoTexto(_fichaMedicaController, '**', '**'),
                        icon: const Icon(Icons.format_bold),
                      ),
                      IconButton(
                        tooltip: 'Cursiva',
                        onPressed: () => _insertarFormatoTexto(_fichaMedicaController, '*', '*'),
                        icon: const Icon(Icons.format_italic),
                      ),
                      IconButton(
                        tooltip: 'Agregar viñeta',
                        onPressed: () => _insertarBulletTexto(_fichaMedicaController),
                        icon: const Icon(Icons.format_list_bulleted),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _fichaMedicaController,
                decoration: const InputDecoration(labelText: 'Detalles médicos, tratamientos y seguimiento', border: OutlineInputBorder()),
                maxLines: 6,
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Este perrito/a está en casa'),
                value: _enCasa,
                onChanged: (valor) => setState(() => _enCasa = valor ?? false),
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _estaGuardando ? null : _guardarDatos,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                  child: _estaGuardando
                      ? CircularProgressIndicator(color: Theme.of(context).colorScheme.onPrimary)
                      : Text(esEdicion ? 'Guardar Cambios' : 'Crear Ficha', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              ],
            ),
          ),
        ),
      ),
    ),   // cierra Scaffold
  );     // cierra PopScope
  }
}
