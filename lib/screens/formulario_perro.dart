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

  DateTime? _fechaIngreso;
  bool _estaCastrado = false;
  bool _estaGuardando = false;

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
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _edadController.dispose();
    _historiaController.dispose();
    _fichaMedicaController.dispose();
    _fechaIngresoController.dispose();
    super.dispose();
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
            toolbarColor: Colors.black87,
            toolbarWidgetColor: Colors.white,
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
          'edad': int.tryParse(_edadController.text.trim()) ?? 0,
          'edad_anio_base': DateTime.now().year,
          'historia': _historiaController.text.trim(),
          'ficha_medica': _fichaMedicaController.text.trim(),
          'castrado': _estaCastrado,
          if (urlImagen != null) 'foto_perfil': urlImagen,
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

  @override
  Widget build(BuildContext context) {
    final esEdicion = widget.idDocumento != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(esEdicion ? 'Editar Ficha' : 'Nuevo Ingreso', style: const TextStyle(color: Colors.white)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Center(
                child: GestureDetector(
                  onTap: _seleccionarImagen,
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey.shade300,
                    backgroundImage: _imagenSeleccionada != null
                        ? FileImage(_imagenSeleccionada!) as ImageProvider
                        : (widget.datosActuales?['foto_perfil'] != null ? NetworkImage(widget.datosActuales!['foto_perfil']) : null),
                    child: _imagenSeleccionada == null && widget.datosActuales?['foto_perfil'] == null
                        ? const Icon(Icons.add_a_photo, size: 40, color: Colors.grey)
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
              TextFormField(controller: _edadController, decoration: const InputDecoration(labelText: 'Edad estimada (años, opcional)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.cake)), keyboardType: TextInputType.number),
              const SizedBox(height: 16),
              SwitchListTile(title: const Text('¿Ya está castrado?'), value: _estaCastrado, activeThumbColor: Colors.deepOrange, onChanged: (valor) => setState(() => _estaCastrado = valor)),
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
              const SizedBox(height: 32),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _estaGuardando ? null : _guardarDatos,
                  style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white),
                  child: _estaGuardando ? const CircularProgressIndicator(color: Colors.white) : Text(esEdicion ? 'Guardar Cambios' : 'Crear Ficha', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
