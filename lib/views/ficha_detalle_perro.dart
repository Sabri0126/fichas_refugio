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
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../controllers/perro_controller.dart';
import '../controllers/tratamiento_controller.dart';
import '../models/egreso_model.dart';
import '../models/perro_model.dart';
import '../models/tratamiento_model.dart';
import '../theme/app_colors.dart';
import '../theme/category_colors.dart';
import '../theme/entrada_escalonada.dart';

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

  Future<void> _toggleDosis(TratamientoModel tratamiento, DateTime fecha) async {
    try {
      await _tratamientoController.toggleDosis(widget.idDocumento, tratamiento, fecha);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo actualizar el tratamiento')),
        );
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
        p: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 16 * escala, height: 1.45),
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

  TextScaler get _escala => TextScaler.linear(_escalaTexto);

  static const _inicialesDia = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
  static const _nombresDia = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];

  Widget _buildHistorialDosis(TratamientoModel tratamiento, bool esInvitado) {
    final registroDosis = tratamiento.registroDosis;
    final fechaInicio = tratamiento.fechaInicio;
    final inicioDia = fechaInicio == null
        ? null
        : DateTime(fechaInicio.year, fechaInicio.month, fechaInicio.day);
    final textTheme = Theme.of(context).textTheme;

    final circulos = <Widget>[];
    for (int i = 4; i >= 0; i--) {
      final dia = DateTime.now().subtract(Duration(days: i));
      final diaSoloFecha = DateTime(dia.year, dia.month, dia.day);
      final antesDeInicio = inicioDia != null && diaSoloFecha.isBefore(inicioDia);
      final esHoy = i == 0;

      Color fondo;
      IconData? icono;
      String estado;
      if (antesDeInicio) {
        fondo = AppColors.pendiente.withValues(alpha: 0.35);
        estado = 'antes del inicio del tratamiento';
      } else if (registroDosis.contains(_fechaISO(diaSoloFecha))) {
        fondo = AppColors.dosisDada;
        icono = Icons.check;
        estado = 'dosis dada';
      } else if (esHoy) {
        fondo = AppColors.pendiente;
        estado = 'dosis pendiente';
      } else {
        fondo = AppColors.dosisOlvidada;
        icono = Icons.close;
        estado = 'dosis olvidada';
      }

      final habilitado = !(esInvitado || antesDeInicio);

      circulos.add(
        Semantics(
          button: habilitado,
          label: '${esHoy ? 'Hoy' : _nombresDia[diaSoloFecha.weekday - 1]} ${diaSoloFecha.day}: $estado',
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: habilitado
                ? () {
                    HapticFeedback.selectionClick();
                    _toggleDosis(tratamiento, diaSoloFecha);
                  }
                : null,
            child: SizedBox(
              width: 40,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 40,
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: fondo,
                          shape: BoxShape.circle,
                          border: esHoy ? Border.all(color: AppColors.navy, width: 2) : null,
                        ),
                        child: icono == null ? null : Icon(icono, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                  Text(
                    _inicialesDia[diaSoloFecha.weekday - 1],
                    style: textTheme.labelMedium?.copyWith(
                      color: esHoy ? AppColors.navy : AppColors.textoSecundario,
                      fontWeight: esHoy ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Row(mainAxisAlignment: MainAxisAlignment.start, children: circulos);
  }

  Widget _tarjetaSeccion({required String titulo, required IconData icono, required List<Widget> children}) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icono, size: 22, color: AppColors.navy),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(titulo, textScaler: _escala, style: Theme.of(context).textTheme.titleLarge),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _chipDato(IconData icono, String texto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.rellenoInput,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.bordeTarjeta),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 18, color: AppColors.navy),
          const SizedBox(width: 6),
          Text(
            texto,
            textScaler: _escala,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _filaDato(String etiqueta, String valor) {
    final textTheme = Theme.of(context).textTheme;
    final sinDato = valor == 'No registrada';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etiqueta, textScaler: _escala, style: textTheme.labelMedium?.copyWith(color: AppColors.textoSecundario)),
        const SizedBox(height: 2),
        Text(
          valor,
          textScaler: _escala,
          style: sinDato
              ? textTheme.bodyLarge?.copyWith(color: AppColors.textoSecundario, fontStyle: FontStyle.italic)
              : textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildDatosBasicos(PerroModel perro) {
    final esHembra = perro.sexo == 'hembra';
    final edadTexto = _formatearEdadTexto(perro);
    final partesEdad = edadTexto.split(':');
    final edadValor = partesEdad.length > 1 ? partesEdad.sublist(1).join(':').trim() : edadTexto;
    final edadChip = edadTexto.startsWith('Edad estimada') ? '$edadValor aprox.' : edadValor;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chipDato(esHembra ? Icons.female : Icons.male, esHembra ? 'Hembra' : 'Macho'),
                _chipDato(Icons.cake_outlined, edadChip),
                _chipDato(
                  perro.castrado ? Icons.check_circle_outline : Icons.remove_circle_outline,
                  perro.castrado ? 'Castrado' : 'No castrado',
                ),
              ],
            ),
            const SizedBox(height: 16),
            _filaDato('Fecha de ingreso', _formatearFecha(perro.fechaIngreso)),
            if (perro.fechaFallecimiento != null) ...[
              const SizedBox(height: 12),
              _filaDato('Fecha de fallecimiento', _formatearFecha(perro.fechaFallecimiento)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTarjetaTratamiento(TratamientoModel t, String fechaHoy, bool esInvitado) {
    final textTheme = Theme.of(context).textTheme;
    final marcadoHoy = t.registroDosis.contains(fechaHoy);
    final diasDuracion = t.diasDuracion;
    final ValueChanged<bool?>? alCambiar = esInvitado ? null : (_) => _toggleDosis(t, DateTime.now());

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: marcadoHoy ? AppColors.dosisDada.withValues(alpha: 0.08) : AppColors.rellenoInput,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: marcadoHoy ? AppColors.dosisDada.withValues(alpha: 0.4) : AppColors.bordeTarjeta,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: alCambiar == null ? null : () => alCambiar(!marcadoHoy),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(value: marcadoHoy, onChanged: alCambiar),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutCubic,
                              style: (textTheme.titleMedium ?? const TextStyle()).copyWith(
                                color: marcadoHoy ? AppColors.textoSecundario : AppColors.texto,
                                decoration: marcadoHoy ? TextDecoration.lineThrough : TextDecoration.none,
                                decorationColor: AppColors.textoSecundario,
                              ),
                              child: Text(
                                t.medicacion,
                                textScaler: _escala,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${t.indicaciones} \u00b7 ${diasDuracion > 0 ? '$diasDuracion d\u00edas' : 'Indefinido'}',
                              textScaler: _escala,
                              style: textTheme.bodyMedium?.copyWith(color: AppColors.textoSecundario),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _buildHistorialDosis(t, esInvitado),
            ),
          ],
        ),
      ),
    );
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

  Widget _buildSeccionSalud(PerroModel perro, bool esInvitado) {
    final tratamientos = perro.tratamientos;
    final fechaHoy = _fechaHoyISO();
    // Las dosis únicas y visitas veterinarias no requieren seguimiento diario con checkbox.
    final tratamientosActivos = _tratamientoController.obtenerActivosDiarios(tratamientos);
    final tieneHistorial = tratamientos.isNotEmpty;
    final textTheme = Theme.of(context).textTheme;

    return _tarjetaSeccion(
      titulo: 'Ficha médica',
      icono: Icons.favorite_outline,
      children: [
        _construirTextoFormateado(
          perro.fichaMedica.isNotEmpty ? perro.fichaMedica : 'No hay ficha médica registrada.',
          _escalaTexto,
        ),
        if (tieneHistorial) ...[
          const SizedBox(height: 24),
          Text('Tratamientos activos', textScaler: _escala, style: textTheme.titleLarge),
          const SizedBox(height: 12),
          if (tratamientosActivos.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'No hay tratamientos diarios activos.',
                textScaler: _escala,
                style: textTheme.bodyMedium?.copyWith(color: AppColors.textoSecundario),
              ),
            ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            clipBehavior: Clip.none,
            child: Column(
              children: [
                for (var n = 0; n < tratamientosActivos.length; n++)
                  EntradaEscalonada(
                    indice: n,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildTarjetaTratamiento(tratamientosActivos[n], fechaHoy, esInvitado),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text('Ver Historial Médico', textScaler: _escala),
              onPressed: () => _mostrarHistorialCompleto(tratamientos),
            ),
          ),
        ],
      ],
    );
  }

  void _mostrarHistorialCompleto(List<TratamientoModel> tratamientos) {
    final eventosCalendario = _tratamientoController.construirEventosCalendario(tratamientos);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, controladorScroll) => PrimaryScrollController(
          controller: controladorScroll,
          child: CalendarioHistorialWidget(eventosCalendario: eventosCalendario),
        ),
      ),
    );
  }

  Widget _bannerEgreso(PerroModel perro) {
    final motivo = _perroController.formatearMotivoEgreso(perro.motivoEgreso);
    final nota = perro.notaEgreso?.trim();
    final icono = perro.motivoEgreso == 'familia' ? Icons.home_rounded : Icons.favorite_rounded;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.activoTexto.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.activoTexto.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: AppColors.activoTexto),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  motivo,
                  textScaler: _escala,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.activoTexto),
                ),
                if (perro.fechaEgreso != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Desde el ${_perroController.formatearFecha(perro.fechaEgreso)}',
                    textScaler: _escala,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                if (nota != null && nota.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(nota, textScaler: _escala, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _historialEgresos(PerroModel perro) {
    final ordenados = [...perro.historialEgresos]..sort((a, b) {
      if (a.fechaEgreso == null && b.fechaEgreso == null) return 0;
      if (a.fechaEgreso == null) return 1;
      if (b.fechaEgreso == null) return -1;
      return b.fechaEgreso!.compareTo(a.fechaEgreso!);
    });
    final filas = <Widget>[];
    for (var i = 0; i < ordenados.length; i++) {
      if (i > 0) filas.add(const Divider());
      filas.add(_filaEgreso(ordenados[i]));
    }
    return _tarjetaSeccion(
      titulo: 'Historial de egresos',
      icono: Icons.history_rounded,
      children: filas,
    );
  }

  Widget _filaEgreso(EgresoModel egreso) {
    final motivo = _perroController.formatearMotivoEgreso(egreso.motivo);
    final icono = switch (egreso.motivo) {
      'adopcion' => Icons.favorite_rounded,
      'familia' => Icons.home_rounded,
      _ => Icons.logout_rounded,
    };
    final nota = egreso.nota?.trim();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.activoTexto.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icono, size: 20, color: AppColors.activoTexto),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                motivo.isEmpty ? 'Egreso' : motivo,
                textScaler: _escala,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              if (egreso.fechaEgreso == null)
                Text(
                  'Egreso: sin fecha',
                  textScaler: _escala,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textoSecundario,
                    fontStyle: FontStyle.italic,
                  ),
                )
              else
                Text(
                  'Egreso: ${_perroController.formatearFecha(egreso.fechaEgreso)}',
                  textScaler: _escala,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textoSecundario),
                ),
              if (egreso.fechaRegreso != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Regreso: ${_perroController.formatearFecha(egreso.fechaRegreso)}',
                  textScaler: _escala,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textoSecundario),
                ),
              ],
              if (nota != null && nota.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  nota,
                  textScaler: _escala,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textoSecundario),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Column _buildInfoContenido(PerroModel perro, bool esInvitado) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Text(
          perro.nombre.isNotEmpty ? perro.nombre : 'Sin nombre',
          textScaler: _escala,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        if (perro.estado == 'egresado') ...[
          const SizedBox(height: 12),
          _bannerEgreso(perro),
        ],
        const SizedBox(height: 16),
        _buildDatosBasicos(perro),
        if (perro.historialEgresos.isNotEmpty) ...[
          const SizedBox(height: 12),
          _historialEgresos(perro),
        ],
        const SizedBox(height: 12),
        _tarjetaSeccion(
          titulo: 'Historia y observaciones',
          icono: Icons.menu_book_outlined,
          children: [
            _construirTextoFormateado(perro.historia.isNotEmpty ? perro.historia : 'No hay historia registrada.', _escalaTexto),
          ],
        ),
        const SizedBox(height: 12),
        _buildSeccionSalud(perro, esInvitado),
        if (perro.parientes.isNotEmpty) ...[
          const SizedBox(height: 12),
          _tarjetaSeccion(
            titulo: 'Familiares en el refugio',
            icono: Icons.people_outline,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: perro.parientes.map((familiar) {
                  final nombre = familiar['nombre']?.toString() ?? '';
                  final relacion = familiar['relacion']?.toString() ?? '';
                  final idDoc = familiar['id_documento']?.toString() ?? '';
                  return ActionChip(
                    backgroundColor: AppColors.rellenoInput,
                    avatar: const Icon(Icons.pets, size: 18, color: AppColors.navy),
                    label: Text('$nombre ($relacion)', textScaler: _escala),
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
      final textTheme = Theme.of(context).textTheme;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.navy.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.photo_camera_outlined, size: 30, color: AppColors.navy),
              ),
              const SizedBox(height: 12),
              Text('Aún no hay fotos en la galería', style: textTheme.titleMedium, textAlign: TextAlign.center),
              if (!esInvitado) ...[
                const SizedBox(height: 4),
                Text(
                  'Tocá el ícono de cámara arriba para agregar una.',
                  style: textTheme.bodyMedium?.copyWith(color: AppColors.textoSecundario),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
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
                    SizedBox(height: galeria.length > 1 ? 20 : 8),
                  ],
                ),
                if (!esInvitado)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Row(
                      children: [
                        IconButton.filled(
                          tooltip: 'Editar descripción',
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black.withValues(alpha: 0.5),
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => _editarFotoAGaleria(foto, index),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          tooltip: 'Eliminar foto',
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black.withValues(alpha: 0.5),
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.delete, size: 20),
                          onPressed: () => _eliminarFotoAGaleria(foto, index),
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
            child: IconButton.filled(
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: 0.5),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.arrow_back),
              onPressed: _moverIzquierda,
            ),
          ),
        if (_paginaActual < galeria.length - 1)
          Positioned(
            right: 8,
            child: IconButton.filled(
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: 0.5),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.arrow_forward),
              onPressed: _moverDerecha,
            ),
          ),
        if (galeria.length > 1)
          Positioned(
            bottom: 8,
            child: IgnorePointer(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(galeria.length, (index) {
                  final activa = index == _paginaActual;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: activa ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: activa ? AppColors.navy : AppColors.navy.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
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
            title: Text('Ficha de ${perro.nombre}', overflow: TextOverflow.ellipsis),
            actions: [
              if (_subiendoFoto)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Theme.of(context).colorScheme.onPrimary),
                  ),
                )
              else ...[
                if (!esInvitado) ...[
                  if (_modoReordenar)
                    IconButton(
                      icon: const Icon(Icons.check),
                      tooltip: 'Guardar orden de fotos',
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
                PopupMenuButton<void>(
                  icon: const Icon(Icons.more_vert),
                  tooltip: 'Más opciones',
                  itemBuilder: (context) => [
                    PopupMenuItem<void>(
                      enabled: _escalaTexto > 1.0,
                      onTap: () => setState(() => _escalaTexto -= 0.15),
                      child: const ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.zoom_out),
                        title: Text('Achicar texto'),
                      ),
                    ),
                    PopupMenuItem<void>(
                      onTap: () => setState(() => _escalaTexto += 0.15),
                      child: const ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.zoom_in),
                        title: Text('Agrandar texto'),
                      ),
                    ),
                    if (!esInvitado && !_modoReordenar)
                      PopupMenuItem<void>(
                        onTap: () async {
                          if (_modoReordenar) {
                            await _confirmarOrdenFotos();
                          } else {
                            _activarModoReordenar(perro);
                          }
                        },
                        child: const ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.reorder),
                          title: Text('Reordenar fotos'),
                        ),
                      ),
                  ],
                ),
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
                final galeriaVacia = galeria.isEmpty && !_modoReordenar;
                return Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      height: galeriaVacia ? 200 : 300,
                      decoration: const BoxDecoration(
                        color: AppColors.superficie,
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                        boxShadow: [
                          BoxShadow(color: AppColors.sombra, blurRadius: 16, offset: Offset(0, 4)),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: galeriaWidget,
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                        child: _buildInfoContenido(perro, esInvitado),
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

  @override
  void initState() {
    super.initState();
    _localeListo = initializeDateFormatting('es_ES');
  }

  List<Map<String, dynamic>> _eventosDelDia(DateTime dia) {
    return widget.eventosCalendario[DateTime.utc(dia.year, dia.month, dia.day)] ?? [];
  }

  Color obtenerColorCategoria(String? categoria) => CategoryColors.base(categoria);

  Widget _filaEvento(Map<String, dynamic> evento) {
    final textTheme = Theme.of(context).textTheme;
    final categoriaEvento = evento['categoria']?.toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.rellenoInput,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.bordeTarjeta),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: CategoryColors.tinte(categoriaEvento), shape: BoxShape.circle),
              child: Icon(CategoryColors.icono(categoriaEvento), size: 20, color: obtenerColorCategoria(categoriaEvento)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    evento['detalle']?.toString() ?? '${evento['medicacion']} - ${evento['indicaciones']}',
                    style: textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    CategoryColors.etiqueta(categoriaEvento),
                    style: textTheme.labelMedium?.copyWith(color: CategoryColors.texto(categoriaEvento)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final eventosSeleccionados = _eventosDelDia(_selectedDay);
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      top: false,
      child: ListView(
        primary: true,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text('Historial médico', style: textTheme.titleLarge),
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
              final fechaLegible = DateFormat("EEEE d 'de' MMMM", 'es_ES').format(_selectedDay);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TableCalendar<Map<String, dynamic>>(
                    locale: 'es_ES',
                    firstDay: DateTime.utc(_focusedDay.year - 2, _focusedDay.month, _focusedDay.day),
                    lastDay: DateTime.utc(_focusedDay.year + 1, _focusedDay.month, _focusedDay.day),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (dia) => isSameDay(dia, _selectedDay),
                    eventLoader: _eventosDelDia,
                    availableGestures: AvailableGestures.horizontalSwipe,
                    headerStyle: HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      titleTextStyle: textTheme.titleMedium ?? const TextStyle(),
                      leftChevronIcon: const Icon(Icons.chevron_left, color: AppColors.navy),
                      rightChevronIcon: const Icon(Icons.chevron_right, color: AppColors.navy),
                    ),
                    daysOfWeekStyle: DaysOfWeekStyle(
                      weekdayStyle: textTheme.labelMedium?.copyWith(color: AppColors.textoSecundario) ?? const TextStyle(),
                      weekendStyle: textTheme.labelMedium?.copyWith(color: AppColors.textoSecundario) ?? const TextStyle(),
                    ),
                    calendarStyle: CalendarStyle(
                      selectedDecoration: const BoxDecoration(
                        color: AppColors.navy,
                        shape: BoxShape.circle,
                      ),
                      selectedTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      todayDecoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.navy, width: 1.6),
                      ),
                      todayTextStyle: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w700),
                      markerDecoration: BoxDecoration(
                        color: obtenerColorCategoria('diario'),
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
                  ),
                  const SizedBox(height: 16),
                  Text(
                    fechaLegible,
                    style: textTheme.titleMedium?.copyWith(color: AppColors.navy),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          // --- SECCIÓN: Detalle de eventos del día seleccionado ---
          if (eventosSeleccionados.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  const Icon(Icons.event_available_outlined, size: 32, color: AppColors.pendiente),
                  const SizedBox(height: 8),
                  Text(
                    'No hay registros médicos para este día',
                    style: textTheme.bodyMedium?.copyWith(color: AppColors.textoSecundario),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              clipBehavior: Clip.none,
              child: Column(
                children: [
                  for (var n = 0; n < eventosSeleccionados.length; n++)
                    EntradaEscalonada(
                      indice: n,
                      child: _filaEvento(eventosSeleccionados[n]),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
