import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http/http.dart' as http;
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path_provider/path_provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../controllers/perro_controller.dart';
import '../controllers/tratamiento_controller.dart';
import '../models/perro_model.dart';
import '../models/tratamiento_model.dart';

class FichaDetallePerro extends StatefulWidget {
  final String idDocumento;

  const FichaDetallePerro({super.key, required this.idDocumento});

  @override
  State<FichaDetallePerro> createState() => _FichaDetallePerroState();
}

class _FichaDetallePerroState extends State<FichaDetallePerro> {
  final PerroController _perroController = PerroController();
  final TratamientoController _tratamientoController = TratamientoController();
  final PageController _controladorCarrusel = PageController();
  final ImagePicker _picker = ImagePicker();
  bool _subiendoFoto = false;
  bool _modoReordenar = false;
  int _paginaActual = 0;
  double _escalaTexto = 1.3;
  List<Map<String, dynamic>> _fotosReordenar = [];

  String _formatearFecha(DateTime? fecha) => _perroController.formatearFecha(fecha);

  String _fechaHoyISO() => _tratamientoController.formatearFechaISO(DateTime.now());

  Future<void> _actualizarDosisTratamiento(
    PerroModel perro,
    TratamientoModel tratamiento,
    String fechaHoy,
    bool marcar,
  ) async {
    final tratamientos = List<TratamientoModel>.from(perro.tratamientos);
    final indice = tratamientos.indexWhere((t) => t.id == tratamiento.id);
    if (indice == -1) return;

    final fecha = DateTime.tryParse(fechaHoy) ?? DateTime.now();
    tratamientos[indice] = _tratamientoController.alternarDosis(tratamientos[indice], fecha, marcar);

    try {
      await _tratamientoController.guardarTratamientos(widget.idDocumento, tratamientos);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo actualizar el tratamiento')));
      }
    }
  }

  String _formatearEdadTexto(PerroModel perro) => _perroController.formatearEdadTexto(perro);

  Widget _construirTextoFormateado(String texto, double escala) {
    final textoLimpio = texto.trim();

    if (textoLimpio.isEmpty) {
      return Text('Sin información.', textScaler: TextScaler.linear(escala));
    }

    final textoMarkdown = textoLimpio.replaceAll(RegExp(r'(?<!\n)\n(?!\n)'), '\n\n');

    return MarkdownBody(
      data: textoMarkdown,
      selectable: true,
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: TextStyle(fontSize: 16 * escala, height: 1.4),
        strong: const TextStyle(fontWeight: FontWeight.bold),
        em: const TextStyle(fontStyle: FontStyle.italic),
        listBullet: TextStyle(fontSize: 16 * escala),
        h1: TextStyle(fontSize: 24 * escala, fontWeight: FontWeight.bold),
        h2: TextStyle(fontSize: 20 * escala, fontWeight: FontWeight.bold),
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

  void _abrirFotoPantallaCompleta(String url) {
    bool procesando = false;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StatefulBuilder(
          builder: (context, setStateLocal) => Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            appBar: AppBar(
              backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0),
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                procesando
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : IconButton(
                        icon: Icon(Icons.crop, color: Theme.of(context).colorScheme.onSurface),
                        onPressed: () => _recortarFotoExistente(url, context, setStateLocal, (valor) => procesando = valor),
                      ),
              ],
            ),
            body: Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _recortarFotoExistente(
    String url,
    BuildContext context,
    StateSetter setStateLocal,
    void Function(bool) actualizarProcesando,
  ) async {
    setStateLocal(() => actualizarProcesando(true));
    final colorScheme = Theme.of(context).colorScheme;
    try {
      final respuesta = await http.get(Uri.parse(url));
      final directorioTemporal = await getTemporaryDirectory();
      final archivoTemp = File('${directorioTemporal.path}/temp_recorte_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await archivoTemp.writeAsBytes(respuesta.bodyBytes);

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: archivoTemp.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Recortar foto',
            toolbarColor: colorScheme.primary,
            toolbarWidgetColor: colorScheme.onPrimary,
            activeControlsWidgetColor: colorScheme.secondary,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Recortar foto',
            doneButtonTitle: 'Listo',
            cancelButtonTitle: 'Cancelar',
          ),
        ],
      );

      if (croppedFile == null) {
        setStateLocal(() => actualizarProcesando(false));
        return;
      }

      final nombreArchivo = 'recorte_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final refStorage = FirebaseStorage.instance.ref().child('galeria_perros').child(nombreArchivo);
      await refStorage.putFile(File(croppedFile.path));
      final nuevaUrl = await refStorage.getDownloadURL();

      await _perroController.actualizarUrlDeFoto(widget.idDocumento, url, nuevaUrl);

      if (context.mounted) Navigator.pop(context);
    } catch (_) {
      if (context.mounted) {
        setStateLocal(() => actualizarProcesando(false));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo recortar la foto')));
      }
    }
  }

  List<Map<String, dynamic>> _construirListaReordenamiento(PerroModel perro) {
    final perfilUrl = perro.fotoPerfil ?? '';
    final galeria = perro.galeria;
    final listaUnificada = <Map<String, dynamic>>[];

    if (perfilUrl.trim().isNotEmpty) {
      listaUnificada.add({'url': perfilUrl, 'texto': 'Foto de perfil', 'descripcion': 'Foto de perfil'});
    }

    for (final foto in galeria) {
      final item = Map<String, dynamic>.from(foto);
      final url = item['url']?.toString() ?? '';
      if (url.trim().isEmpty) continue;

      item['url'] = url;
      item['texto'] ??= item['descripcion'] ?? 'Sin descripción';
      item['descripcion'] ??= item['texto'] ?? 'Sin descripción';
      listaUnificada.add(item);
    }

    return listaUnificada;
  }

  void _activarModoReordenar(PerroModel perro) {
    setState(() {
      _modoReordenar = true;
      _fotosReordenar = _construirListaReordenamiento(perro);
    });
  }

  Future<void> _confirmarOrdenFotos() async {
    if (_fotosReordenar.isEmpty) {
      setState(() {
        _modoReordenar = false;
        _fotosReordenar = [];
      });
      return;
    }

    final perfilItem = _fotosReordenar.first;
    final perfilUrl = perfilItem['url']?.toString() ?? '';
    final galeriaOrdenada = _fotosReordenar.sublist(1).map((foto) {
      final mapa = Map<String, dynamic>.from(foto);
      final url = mapa['url']?.toString() ?? '';
      if (url.isEmpty) return null;
      mapa['url'] = url;
      mapa['texto'] ??= mapa['descripcion'] ?? 'Sin descripción';
      mapa['descripcion'] ??= mapa['texto'];
      return mapa;
    }).whereType<Map<String, dynamic>>().toList();

    setState(() => _subiendoFoto = true);
    try {
      await _perroController.reordenarFotos(
        widget.idDocumento,
        perfilUrl.isNotEmpty ? perfilUrl : null,
        galeriaOrdenada,
      );

      if (mounted) {
        setState(() {
          _modoReordenar = false;
          _fotosReordenar = [];
          _paginaActual = 0;
        });
        if (_controladorCarrusel.hasClients) {
          _controladorCarrusel.jumpToPage(0);
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo guardar el orden de las fotos')));
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
      await _perroController.editarFotoDeGaleria(widget.idDocumento, index, textoDescriptivo);
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
      final urlFoto = await _perroController.eliminarFotoDeGaleria(widget.idDocumento, index);

      if (urlFoto != null) {
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
              toolbarColor: Theme.of(context).colorScheme.primary,
              toolbarWidgetColor: Theme.of(context).colorScheme.onPrimary,
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

      if (!mounted) return;

      final textoController = TextEditingController();

      final textoDescriptivo = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Agregar descripción (opcional)'),
          content: TextField(
            controller: textoController,
            decoration: const InputDecoration(hintText: "Ej: Jugando en el patio..."),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, null), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.pop(dialogContext, textoController.text), child: const Text('Subir Foto')),
          ],
        ),
      );

      if (textoDescriptivo != null) {
        if (!mounted || !context.mounted) return;

        setState(() => _subiendoFoto = true);
        try {
          final nombreArchivo = 'galeria_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final refStorage = FirebaseStorage.instance.ref().child('galeria_perros').child(nombreArchivo);

          await refStorage.putFile(archivoParaSubir);
          final urlDescarga = await refStorage.getDownloadURL();

          await _perroController.agregarFotoAGaleria(widget.idDocumento, urlDescarga, textoDescriptivo);
        } catch (e) {
          if (mounted && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al subir la foto')));
          }
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

  String _fechaISO(DateTime fecha) {
    return '${fecha.year.toString().padLeft(4, '0')}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';
  }

  Widget _buildHistorialDosis(TratamientoModel tratamiento) {
    final registroDosis = tratamiento.registroDosis;
    final fechaInicio = tratamiento.fechaInicio;

    final circulos = <Widget>[];
    for (int i = 4; i >= 0; i--) {
      final dia = DateTime.now().subtract(Duration(days: i));
      final diaSoloFecha = DateTime(dia.year, dia.month, dia.day);

      Color color;
      if (fechaInicio != null &&
          diaSoloFecha.isBefore(DateTime(fechaInicio.year, fechaInicio.month, fechaInicio.day))) {
        color = Colors.grey.shade200;
      } else if (registroDosis.contains(_fechaISO(dia))) {
        color = Colors.green;
      } else if (i == 0) {
        color = Colors.grey;
      } else {
        color = Colors.red;
      }

      if (circulos.isNotEmpty) circulos.add(const SizedBox(width: 4));
      circulos.add(
        Container(
          width: 15,
          height: 15,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      );
    }

    return Row(mainAxisAlignment: MainAxisAlignment.start, children: circulos);
  }

  /// Marca como inactivos los tratamientos diarios cuyo ciclo (fecha_inicio + dias_duracion) ya venció,
  /// persistiendo el cambio en Firestore para que dejen de listarse en "Tratamientos activos".
  PerroModel _procesarAutoArchivado(PerroModel perro) {
    if (perro.tratamientos.isEmpty) return perro;

    final actualizados = _tratamientoController.autoArchivarVencidos(perro.tratamientos);
    if (!_tratamientoController.huboCambiosDeArchivado(perro.tratamientos, actualizados)) return perro;

    _tratamientoController.guardarTratamientos(widget.idDocumento, actualizados).catchError((_) {});

    return perro.copyWith(tratamientos: actualizados);
  }

  List<Widget> _buildTratamientos(PerroModel perro, bool esInvitado) {
    final tratamientos = perro.tratamientos;
    if (tratamientos.isEmpty) return [];

    final fechaHoy = _fechaHoyISO();
    // Las dosis únicas y visitas veterinarias no requieren seguimiento diario con checkbox.
    final tratamientosActivos = _tratamientoController.obtenerActivosDiarios(tratamientos);

    return [
      const SizedBox(height: 24),
      Row(
        children: [
          Expanded(
            child: Text(
              'Tratamientos activos:',
              textScaler: TextScaler.linear(_escalaTexto),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: 'Ver historial médico completo',
            onPressed: () => _mostrarHistorialCompleto(tratamientos),
          ),
        ],
      ),
      const SizedBox(height: 10),
      ...tratamientosActivos.map((t) {
        final registroDosis = t.registroDosis;
        final marcadoHoy = registroDosis.contains(fechaHoy);
        final diasDuracion = t.diasDuracion;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: CheckboxListTile(
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(t.medicacion, textScaler: TextScaler.linear(_escalaTexto)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${t.indicaciones} \u00b7 ${diasDuracion > 0 ? '$diasDuracion d\u00edas' : 'Indefinido'}',
                  textScaler: TextScaler.linear(_escalaTexto),
                ),
                const SizedBox(height: 6),
                _buildHistorialDosis(t),
              ],
            ),
            value: marcadoHoy,
            onChanged: esInvitado
                ? null
                : (valor) => _actualizarDosisTratamiento(perro, t, fechaHoy, valor ?? false),
          ),
        );
      }),
    ];
  }

  void _mostrarHistorialCompleto(List<TratamientoModel> tratamientos) {
    final eventosCalendario = _tratamientoController.construirEventosCalendario(tratamientos);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => CalendarioHistorialWidget(eventosCalendario: eventosCalendario),
    );
  }

  Column _buildInfoContenido(PerroModel perro, bool esInvitado) {
    final tieneFechaFallecimiento = perro.fechaFallecimiento != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Text(
          perro.nombre.isNotEmpty ? perro.nombre : 'Sin nombre',
          textScaler: TextScaler.linear(_escalaTexto),
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),
        Text('Fecha de ingreso: ${_formatearFecha(perro.fechaIngreso)}', textScaler: TextScaler.linear(_escalaTexto), style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 8),
        Text(perro.sexo == 'hembra' ? 'Sexo: Hembra' : 'Sexo: Macho', textScaler: TextScaler.linear(_escalaTexto), style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 8),
        Text(_formatearEdadTexto(perro), textScaler: TextScaler.linear(_escalaTexto), style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 8),
        Text(perro.castrado ? 'Castrado: Sí' : 'Castrado: No', textScaler: TextScaler.linear(_escalaTexto), style: const TextStyle(fontSize: 16)),
        if (tieneFechaFallecimiento) ...[
          const SizedBox(height: 8),
          Text(
            'Fecha de fallecimiento: ${_formatearFecha(perro.fechaFallecimiento)}',
            textScaler: TextScaler.linear(_escalaTexto),
            style: const TextStyle(fontSize: 16),
          ),
        ],
        const SizedBox(height: 22),
        Text('Historia/Observaciones:', textScaler: TextScaler.linear(_escalaTexto), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _construirTextoFormateado(perro.historia.isNotEmpty ? perro.historia : 'No hay historia registrada.', _escalaTexto),
        const SizedBox(height: 20),
        Text('Ficha médica:', textScaler: TextScaler.linear(_escalaTexto), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _construirTextoFormateado(perro.fichaMedica.isNotEmpty ? perro.fichaMedica : 'No hay ficha médica registrada.', _escalaTexto),
        ..._buildTratamientos(perro, esInvitado),
        if (perro.parientes.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Familiares en el refugio:', textScaler: TextScaler.linear(_escalaTexto), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: perro.parientes.map((familiar) {
              final nombre = familiar['nombre']?.toString() ?? '';
              final relacion = familiar['relacion']?.toString() ?? '';
              final idDoc = familiar['id_documento']?.toString() ?? '';
              return ActionChip(
                elevation: 3,
                shadowColor: const Color.fromARGB(202, 0, 0, 0),
                avatar: const Icon(Icons.people, size: 18),
                label: Text('$nombre ($relacion)', textScaler: TextScaler.linear(_escalaTexto)),
                onPressed: idDoc.isEmpty
                    ? null
                    : () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FichaDetallePerro(idDocumento: idDoc),
                          ),
                        ),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildGaleria(List<Map<String, dynamic>> galeria, bool esInvitado, PerroModel perro) {
    if (_modoReordenar) {
      final fotosReordenables = _fotosReordenar.isNotEmpty ? _fotosReordenar : _construirListaReordenamiento(perro);
      if (fotosReordenables.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Aún no hay fotos para ordenar.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        );
      }

      return Container(
        padding: const EdgeInsets.all(16),
        child: ReorderableListView.builder(
          itemCount: fotosReordenables.length,
          onReorderItem: (oldIndex, newIndex) {
            if (oldIndex == newIndex) return;

            setState(() {
              if (oldIndex < newIndex) {
                newIndex -= 1;
              }
              final elemento = _fotosReordenar.removeAt(oldIndex);
              _fotosReordenar.insert(newIndex, elemento);
            });
          },
          itemBuilder: (context, index) {
            final foto = fotosReordenables[index];
            final url = foto['url']?.toString() ?? '';
            final titulo = foto['texto']?.toString().isNotEmpty == true
                ? foto['texto']
                : (foto['descripcion']?.toString().isNotEmpty == true ? foto['descripcion'] : 'Sin descripción');

            return Card(
              key: ValueKey('$url-$index'),
              margin: const EdgeInsets.only(bottom: 12),
              child: Stack(
                children: [
                  ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(url, width: 56, height: 56, fit: BoxFit.cover),
                    ),
                    title: Text(titulo),
                    subtitle: Text(index == 0 ? 'Portada actual' : 'Arrastrá para cambiar el orden'),
                    trailing: const Icon(Icons.drag_handle),
                  ),
                  if (index == 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Portada actual',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      );
    }

    if (galeria.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Aún no hay fotos en la galería.\n¡Tocá la cámara arriba!',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return Stack(
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
                Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Center(
                          child: GestureDetector(
                            onTap: () => _abrirFotoPantallaCompleta(foto['url']?.toString() ?? ''),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(foto['url'] ?? '', fit: BoxFit.contain),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (foto['texto'] != null && foto['texto'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text(
                          foto['texto'],
                          textScaler: TextScaler.linear(_escalaTexto),
                          style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
                if (!esInvitado)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          child: IconButton(
                            icon: Icon(Icons.edit, color: Theme.of(context).colorScheme.onPrimary, size: 20),
                            onPressed: () => _editarFotoAGaleria(foto, index),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.secondary,
                          child: IconButton(
                            icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.onSecondary, size: 20),
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
            left: 8,
            child: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              radius: 24,
              child: IconButton(
                icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onPrimary),
                onPressed: _moverIzquierda,
              ),
            ),
          ),
        if (_paginaActual < galeria.length - 1)
          Positioned(
            right: 8,
            child: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              radius: 24,
              child: IconButton(
                icon: Icon(Icons.arrow_forward, color: Theme.of(context).colorScheme.onPrimary),
                onPressed: _moverDerecha,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool esInvitado = FirebaseAuth.instance.currentUser == null;

    return StreamBuilder<PerroModel?>(
      stream: _perroController.observarPerroPorId(widget.idDocumento),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // --- SECCIÓN: Datos del perro y auto-archivado de tratamientos vencidos ---
        final perro = _procesarAutoArchivado(snapshot.data!);
        final galeria = perro.galeria;

        return Scaffold(
          // --- SECCIÓN: AppBar (título y acciones de galería/accesibilidad) ---
          appBar: AppBar(
            title: Text('Ficha de ${perro.nombre}'),
            actions: [
              if (_subiendoFoto)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(color: Theme.of(context).colorScheme.onPrimary),
                )
              else ...[
                IconButton(
                  icon: const Icon(Icons.zoom_out),
                  tooltip: 'Achicar texto',
                  onPressed: _escalaTexto <= 1.0 ? null : () => setState(() => _escalaTexto -= 0.15),
                ),
                IconButton(
                  icon: const Icon(Icons.zoom_in),
                  tooltip: 'Agrandar texto',
                  onPressed: () => setState(() => _escalaTexto += 0.15),
                ),
                if (!esInvitado) ...[
                  IconButton(
                    icon: Icon(_modoReordenar ? Icons.check : Icons.reorder),
                    tooltip: _modoReordenar ? 'Guardar orden de fotos' : 'Reordenar fotos',
                    onPressed: () async {
                      if (_modoReordenar) {
                        await _confirmarOrdenFotos();
                      } else {
                        _activarModoReordenar(perro);
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_a_photo),
                    tooltip: 'Agregar foto a la galería',
                    onPressed: _agregarFotoAGaleria,
                  ),
                ],
              ],
            ],
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 700;
                // --- SECCIÓN: Galería de fotos (carrusel o modo reordenar) ---
                final galeriaWidget = _buildGaleria(galeria, esInvitado, perro);

                if (isWide) {
                  return Row(
                    children: [
                      // --- SECCIÓN: Panel de información (layout ancho) ---
                      // Panel de info: ancho acotado, centrado, con margen para que respire
                      Center(
                        child: Container(
                          margin: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 450),
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
                              child: _buildInfoContenido(perro, esInvitado),
                            ),
                          ),
                        ),
                      ),
                      Expanded(flex: 2, child: galeriaWidget),
                    ],
                  );
                }
                // --- SECCIÓN: Panel de información (layout angosto, apilado bajo la galería) ---
                return Column(
                  children: [
                    SizedBox(height: 300, child: galeriaWidget),
                    Expanded(
                      child: Container(
                        color: Theme.of(context).colorScheme.surface,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                          child: _buildInfoContenido(perro, esInvitado),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      }
    );
  }
}

class CalendarioHistorialWidget extends StatefulWidget {
  final Map<DateTime, List<Map<String, dynamic>>> eventosCalendario;

  const CalendarioHistorialWidget({super.key, required this.eventosCalendario});

  @override
  State<CalendarioHistorialWidget> createState() => _CalendarioHistorialWidgetState();
}

class _CalendarioHistorialWidgetState extends State<CalendarioHistorialWidget> {
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  late final Future<void> _localeListo;

  static const _azulMarino = Color.fromARGB(255, 47, 67, 99);

  @override
  void initState() {
    super.initState();
    _localeListo = initializeDateFormatting('es_ES');
  }

  List<Map<String, dynamic>> _eventosDelDia(DateTime dia) {
    return widget.eventosCalendario[DateTime.utc(dia.year, dia.month, dia.day)] ?? [];
  }

  Color obtenerColorCategoria(String? categoria) {
    if (categoria == 'unico') return Colors.blue;
    if (categoria == 'veterinaria') return Colors.orange;
    return Colors.green; // Por defecto (Tratamiento Diario)
  }

  @override
  Widget build(BuildContext context) {
    final eventosSeleccionados = _eventosDelDia(_selectedDay);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Historial médico', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            // --- SECCIÓN: Calendario Histórico ---
            FutureBuilder<void>(
              future: _localeListo,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return TableCalendar<Map<String, dynamic>>(
                  locale: 'es_ES',
                  firstDay: DateTime.utc(_focusedDay.year - 2, _focusedDay.month, _focusedDay.day),
                  lastDay: DateTime.utc(_focusedDay.year + 1, _focusedDay.month, _focusedDay.day),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (dia) => isSameDay(dia, _selectedDay),
                  eventLoader: _eventosDelDia,
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                  ),
                  calendarStyle: CalendarStyle(
                    selectedDecoration: const BoxDecoration(
                      color: _azulMarino,
                      shape: BoxShape.circle,
                    ),
                    todayDecoration: BoxDecoration(
                      color: _azulMarino.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                    markerDecoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    markerMargin: const EdgeInsets.only(top: 6),
                  ),
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, date, events) {
                      if (events.isEmpty) return null;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: events.take(4).map((evento) {
                          return Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              color: obtenerColorCategoria(evento['categoria']?.toString()),
                              shape: BoxShape.circle,
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  onDaySelected: (diaSeleccionado, diaEnfocado) {
                    setState(() {
                      _selectedDay = diaSeleccionado;
                      _focusedDay = diaEnfocado;
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 12),
            // --- SECCIÓN: Detalle de eventos del día seleccionado ---
            Expanded(
              child: eventosSeleccionados.isEmpty
                  ? const Center(
                      child: Text(
                        'No hay registros médicos para este día',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: eventosSeleccionados.length,
                      itemBuilder: (context, index) {
                        final evento = eventosSeleccionados[index];
                        final categoriaEvento = evento['categoria']?.toString();
                        final icono = categoriaEvento == 'unico'
                            ? Icons.medication
                            : categoriaEvento == 'veterinaria'
                                ? Icons.local_hospital
                                : Icons.check_circle;
                        return Card(
                          child: ListTile(
                            leading: Icon(icono, color: obtenerColorCategoria(categoriaEvento)),
                            title: Text(evento['detalle']?.toString() ?? '${evento['medicacion']} - ${evento['indicaciones']}'),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
