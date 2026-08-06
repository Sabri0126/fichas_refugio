import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
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

    return MarkdownBody(
      data: textoLimpio,
      styleSheet: MarkdownStyleSheet(
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

  Future<void> _agregarFotoAGaleria() async {
    final XFile? imagen = await _picker.pickImage(source: ImageSource.gallery);

    if (imagen != null && mounted) {
      TextEditingController textoController = TextEditingController();

      String? textoDescriptivo = await showDialog<String>(
        context: context,
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
          File archivoFisico = File(imagen.path);
          final nombreArchivo = 'galeria_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final refStorage = FirebaseStorage.instance.ref().child('galeria_perros').child(nombreArchivo);

          await refStorage.putFile(archivoFisico);
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
              else
                IconButton(
                  icon: const Icon(Icons.add_a_photo),
                  tooltip: 'Agregar foto a la galería',
                  onPressed: _agregarFotoAGaleria,
                )
            ],
          ),
          body: Row(
            children: [
              Expanded(
                flex: 1,
                child: Container(
                  color: Colors.grey.shade200,
                  padding: const EdgeInsets.all(24.0),
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
              Expanded(
                flex: 2,
                child: galeria.isEmpty
                    ? const Center(child: Text('Aún no hay fotos en la galería. ¡Tocá la cámara arriba a la derecha!', style: TextStyle(fontSize: 18)))
                    : Stack(
                        alignment: Alignment.center,
                        children: [
                          PageView.builder(
                            controller: _controladorCarrusel,
                            itemCount: galeria.length,
                            itemBuilder: (context, index) {
                              final foto = galeria[index];
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(foto['url'] ?? '', fit: BoxFit.contain),
                                      ),
                                    ),
                                  ),
                                  if (foto['texto'] != null && foto['texto'].toString().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 24.0, left: 40, right: 40),
                                      child: Text(foto['texto'], style: const TextStyle(fontSize: 20, fontStyle: FontStyle.italic), textAlign: TextAlign.center),
                                    ),
                                ],
                              );
                            },
                          ),
                          Positioned(
                            left: 16,
                            child: CircleAvatar(
                              backgroundColor: Colors.black54,
                              radius: 30,
                              child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30), onPressed: _moverIzquierda),
                            ),
                          ),
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
