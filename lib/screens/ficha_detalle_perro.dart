import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

class FichaDetallePerro extends StatefulWidget {
  final String idDocumento;

  const FichaDetallePerro({super.key, required this.idDocumento});

  @override
  State<FichaDetallePerro> createState() => _FichaDetallePerroState();
}

class _FichaDetallePerroState extends State<FichaDetallePerro> {
  final PageController _controladorCarrusel = PageController();
  final ImagePicker _picker = ImagePicker();
  bool _subiendoFoto = false;
  bool _modoReordenar = false;
  int _paginaActual = 0;

  String _formatearFecha(dynamic fecha) {
    if (fecha == null) {
      return 'No registrada';
    }

    DateTime? fechaDate;
    if (fecha is Timestamp) {
      fechaDate = fecha.toDate();
    } else if (fecha is DateTime) {
      fechaDate = fecha;
    } else if (fecha is String) {
      fechaDate = DateTime.tryParse(fecha);
    }

    if (fechaDate == null) {
      return 'No registrada';
    }

    return '${fechaDate.day.toString().padLeft(2, '0')}/${fechaDate.month.toString().padLeft(2, '0')}/${fechaDate.year}';
  }

  int _calcularEdadEstimada(Map<String, dynamic> perro) {
    final edadBase = int.tryParse(perro['edad']?.toString() ?? '') ?? 0;
    final fechaIngreso = perro['fecha_ingreso'];

    DateTime? ingresoDate;
    if (fechaIngreso is Timestamp) {
      ingresoDate = fechaIngreso.toDate();
    } else if (fechaIngreso is DateTime) {
      ingresoDate = fechaIngreso;
    } else if (fechaIngreso is String) {
      ingresoDate = DateTime.tryParse(fechaIngreso);
    }

    if (ingresoDate != null) {
      final ahora = DateTime.now();
      final aniosTranscurridos = ahora.year - ingresoDate.year;
      if (aniosTranscurridos > 0) {
        return edadBase + aniosTranscurridos;
      }
    }

    return edadBase;
  }

  Widget _construirTextoFormateado(String texto) {
    final textoLimpio = texto.trim();

    if (textoLimpio.isEmpty) {
      return const Text('Sin información.');
    }

    final textoMarkdown = textoLimpio.replaceAll(RegExp(r'(?<!\n)\n(?!\n)'), '\n\n');

    return MarkdownBody(
      data: textoMarkdown,
      selectable: true,
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: const TextStyle(fontSize: 16, height: 1.4),
        strong: const TextStyle(fontWeight: FontWeight.bold),
        em: const TextStyle(fontStyle: FontStyle.italic),
        listBullet: const TextStyle(fontSize: 16),
        h1: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        h2: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  void dispose() {
    _controladorCarrusel.dispose();
    super.dispose();
  }

  void _moverIzquierda() => _controladorCarrusel.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  void _moverDerecha() => _controladorCarrusel.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);

  Future<void> _reordenarFotos(List<dynamic> galeria, int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;

    final nuevaGaleria = List<dynamic>.from(galeria);
    final elemento = nuevaGaleria.removeAt(oldIndex);
    final indiceAjustado = oldIndex < newIndex ? newIndex - 1 : newIndex;
    nuevaGaleria.insert(indiceAjustado.clamp(0, nuevaGaleria.length), elemento);

    setState(() => _subiendoFoto = true);
    try {
      await FirebaseFirestore.instance.collection('perros').doc(widget.idDocumento).update({'galeria': nuevaGaleria});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo reordenar la galería')));
      }
    } finally {
      if (mounted) {
        setState(() => _subiendoFoto = false);
      }
    }
  }

  Future<void> _editarFotoAGaleria(Map<String, dynamic> foto, int index) async {
    final textoController = TextEditingController(text: foto['texto']?.toString() ?? '');

    final textoDescriptivo = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar descripción'),
        content: TextField(
          controller: textoController,
          decoration: const InputDecoration(hintText: 'Descripción de la foto'),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, textoController.text), child: const Text('Guardar')),
        ],
      ),
    );

    if (textoDescriptivo == null) return;

    if (!mounted) return;

    setState(() => _subiendoFoto = true);
    try {
      final docRef = FirebaseFirestore.instance.collection('perros').doc(widget.idDocumento);
      final snapshot = await docRef.get();
      final data = snapshot.data() as Map<String, dynamic>;
      final galeria = List<dynamic>.from(data['galeria'] ?? []);
      galeria[index] = {'url': foto['url'], 'texto': textoDescriptivo};

      await docRef.update({'galeria': galeria});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo actualizar la foto')));
      }
    } finally {
      if (mounted) {
        setState(() => _subiendoFoto = false);
      }
    }
  }

  Future<void> _eliminarFotoAGaleria(Map<String, dynamic> foto, int index) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar foto'),
        content: const Text('¿Querés eliminar esta foto de la galería?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );

    if (confirmar != true) return;

    if (!mounted) return;

    setState(() => _subiendoFoto = true);
    try {
      final docRef = FirebaseFirestore.instance.collection('perros').doc(widget.idDocumento);
      final snapshot = await docRef.get();
      final data = snapshot.data() as Map<String, dynamic>;
      final galeria = List<dynamic>.from(data['galeria'] ?? []);
      final fotoAEliminar = galeria[index];
      galeria.removeAt(index);

      await docRef.update({'galeria': galeria});

      final urlFoto = fotoAEliminar['url']?.toString();
      if (urlFoto != null && urlFoto.isNotEmpty) {
        try {
          final refStorage = FirebaseStorage.instance.refFromURL(urlFoto);
          await refStorage.delete();
        } catch (_) {}
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo eliminar la foto')));
      }
    } finally {
      if (mounted) {
        setState(() => _subiendoFoto = false);
      }
    }
  }

  Future<void> _agregarFotoAGaleria() async {
    final XFile? imagen = await _picker.pickImage(source: ImageSource.gallery);

    if (imagen == null || !mounted) return;

    try {
      final soportaRecorte = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
      File archivoParaSubir;

      if (!soportaRecorte) {
        archivoParaSubir = File(imagen.path);
      } else {
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: imagen.path,
          aspectRatio: const CropAspectRatio(ratioX: 4, ratioY: 3),
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Ajustar foto',
              toolbarColor: Colors.black87,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.original,
              lockAspectRatio: false,
            ),
            IOSUiSettings(
              title: 'Ajustar foto',
              doneButtonTitle: 'Listo',
              cancelButtonTitle: 'Cancelar',
            ),
          ],
        );

        if (croppedFile == null) return;
        archivoParaSubir = File(croppedFile.path);
      }

      if (!mounted) return;

      final currentContext = context;
      TextEditingController textoController = TextEditingController();

      String? textoDescriptivo = await showDialog<String>(
        context: currentContext,
        builder: (context) => AlertDialog(
          title: const Text('Agregar descripción (opcional)'),
          content: TextField(
            controller: textoController,
            decoration: const InputDecoration(hintText: "Ej: Jugando en el patio..."),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.pop(context, textoController.text), child: const Text('Subir Foto')),
          ],
        ),
      );

      if (textoDescriptivo != null) {
        setState(() => _subiendoFoto = true);
        try {
          final nombreArchivo = 'galeria_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final refStorage = FirebaseStorage.instance.ref().child('galeria_perros').child(nombreArchivo);

          await refStorage.putFile(archivoParaSubir);
          final urlDescarga = await refStorage.getDownloadURL();

          final nuevoItemGaleria = {
            'url': urlDescarga,
            'texto': textoDescriptivo,
          };

          await FirebaseFirestore.instance.collection('perros').doc(widget.idDocumento).update({
            'galeria': FieldValue.arrayUnion([nuevoItemGaleria])
          });
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al subir la foto')));
        } finally {
          if (mounted) setState(() => _subiendoFoto = false);
        }
      }
    } on MissingPluginException catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El recorte de imagen no está disponible aquí. Se subirá la imagen original.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo procesar la imagen.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('perros').doc(widget.idDocumento).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));

        var perro = snapshot.data!.data() as Map<String, dynamic>;
        List<dynamic> galeria = perro['galeria'] ?? [];

        return Scaffold(
          appBar: AppBar(
            title: Text('Ficha de ${perro['nombre']}', style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.black87,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              if (_subiendoFoto)
                const Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(color: Colors.white))
              else ...[
                IconButton(
                  icon: Icon(_modoReordenar ? Icons.done : Icons.reorder),
                  tooltip: _modoReordenar ? 'Terminar reordenar' : 'Reordenar galería',
                  onPressed: () => setState(() => _modoReordenar = !_modoReordenar),
                ),
                IconButton(
                  icon: const Icon(Icons.add_a_photo),
                  tooltip: 'Agregar foto a la galería',
                  onPressed: _agregarFotoAGaleria,
                ),
              ],
            ],
          ),
          body: Row(
            children: [
              Expanded(
                flex: 1,
                child: Container(
                  color: Colors.grey.shade200,
                  padding: const EdgeInsets.all(24.0),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(perro['nombre'] ?? 'Sin nombre', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
                        const Divider(color: Colors.black, thickness: 3),
                        const SizedBox(height: 16),
                        Text('Nombre: ${perro['nombre'] ?? 'Sin nombre'}', style: const TextStyle(fontSize: 18)),
                        Text('Fecha de ingreso: ${_formatearFecha(perro['fecha_ingreso'])}', style: const TextStyle(fontSize: 18)),
                        Text('Edad estimada: ${_calcularEdadEstimada(perro)} años', style: const TextStyle(fontSize: 18)),
                        Text(perro['castrado'] == true ? 'Castrado: Sí' : 'Castrado: No', style: const TextStyle(fontSize: 18)),
                        const SizedBox(height: 24),
                        const Text('Historia:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        _construirTextoFormateado(perro['historia']?.toString() ?? 'No hay historia registrada.'),
                        const SizedBox(height: 16),
                        const Text('Ficha médica:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        _construirTextoFormateado(perro['ficha_medica']?.toString() ?? 'No hay ficha médica registrada.'),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: galeria.isEmpty
                    ? const Center(child: Text('Aún no hay fotos en la galería. ¡Tocá la cámara arriba a la derecha!', style: TextStyle(fontSize: 18)))
                    : _modoReordenar
                        ? Container(
                            padding: const EdgeInsets.all(16),
                            child: ReorderableListView.builder(
                              itemCount: galeria.length,
                              onReorder: (oldIndex, newIndex) => _reordenarFotos(galeria, oldIndex, newIndex),
                              itemBuilder: (context, index) {
                                final foto = galeria[index];
                                return Card(
                                  key: ValueKey('${foto['url'] ?? index}-$index'),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: ListTile(
                                    leading: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        foto['url'] ?? '',
                                        width: 56,
                                        height: 56,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    title: Text(foto['texto']?.toString().isNotEmpty == true ? foto['texto'] : 'Sin descripción'),
                                    subtitle: const Text('Arrastrá para cambiar el orden'),
                                    trailing: const Icon(Icons.drag_handle),
                                  ),
                                );
                              },
                            ),
                          )
                        : Stack(
                            alignment: Alignment.center,
                            children: [
                              PageView.builder(
                                controller: _controladorCarrusel,
                                itemCount: galeria.length,
                                onPageChanged: (index) => setState(() => _paginaActual = index),
                                itemBuilder: (context, index) {
                                  final foto = galeria[index];
                                  return Stack(
                                    children: [
                                      Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Expanded(
                                              child: Padding(
                                                padding: const EdgeInsets.all(16.0),
                                                child: Center(
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(12),
                                                    child: ConstrainedBox(
                                                      constraints: const BoxConstraints(maxWidth: 600),
                                                      child: Image.network(foto['url'] ?? '', fit: BoxFit.contain),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            if (foto['texto'] != null && foto['texto'].toString().isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(bottom: 24.0, left: 40, right: 40),
                                                child: Text(foto['texto'], style: const TextStyle(fontSize: 20, fontStyle: FontStyle.italic), textAlign: TextAlign.center),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Positioned(
                                        top: 24,
                                        right: 24,
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              backgroundColor: Colors.black54,
                                              child: IconButton(
                                                icon: const Icon(Icons.edit, color: Colors.white),
                                                onPressed: () => _editarFotoAGaleria(foto, index),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            CircleAvatar(
                                              backgroundColor: Colors.redAccent,
                                              child: IconButton(
                                                icon: const Icon(Icons.delete, color: Colors.white),
                                                onPressed: () => _eliminarFotoAGaleria(foto, index),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                              if (_paginaActual > 0)
                                Positioned(
                                  left: 16,
                                  child: CircleAvatar(
                                    backgroundColor: Colors.black54,
                                    radius: 30,
                                    child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30), onPressed: _moverIzquierda),
                                  ),
                                ),
                              if (_paginaActual < galeria.length - 1)
                                Positioned(
                                  right: 16,
                                  child: CircleAvatar(
                                    backgroundColor: Colors.black54,
                                    radius: 30,
                                    child: IconButton(icon: const Icon(Icons.arrow_forward, color: Colors.white, size: 30), onPressed: _moverDerecha),
                                  ),
                                ),
                            ],
                          ),
              ),
            ],
          ),
        );
      }
    );
  }
}
