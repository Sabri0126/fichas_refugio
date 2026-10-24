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
import '../controllers/peso_controller.dart';
import '../controllers/recordatorio_controller.dart';
import '../controllers/seguimiento_controller.dart';
import '../controllers/tratamiento_controller.dart';
import '../models/dosis_avisada.dart';
import '../models/egreso_model.dart';
import '../models/estado_duracion.dart';
import '../models/perro_model.dart';
import '../models/peso_model.dart';
import '../models/recordatorio_model.dart';
import '../models/seguimiento_model.dart';
import '../models/tratamiento_model.dart';
import '../services/exportar_ficha.dart';
import '../theme/app_colors.dart';
import '../theme/encabezado_seccion.dart';
import '../theme/category_colors.dart';
import '../theme/entrada_escalonada.dart';
import '../theme/recordatorio_tipos.dart';
import '../theme/seguimiento_tipos.dart';
import '../widgets/grafico_peso.dart';
import 'dialogo_peso.dart';
import 'formulario_perro.dart';
import 'pantalla_tarjeta_perro.dart';

/// Texto que se lee al abrir la foto. Vacío y «Sin descripción» no se muestran.
String? descripcionFotoVisible(String? texto, [String? alternativa]) {
  for (final candidato in [texto, alternativa]) {
    final limpio = candidato?.trim() ?? '';
    if (limpio.isNotEmpty && limpio != 'Sin descripción') return limpio;
  }
  return null;
}

/// Foto a pantalla completa, con la descripción debajo y fuera del zoom.
class VisorFoto extends StatelessWidget {
  final String url;
  final String? descripcion;

  /// Imagen ya cargada. La usa el test para no salir a la red.
  final ImageProvider? imagen;

  const VisorFoto({super.key, required this.url, this.descripcion, this.imagen});

  @override
  Widget build(BuildContext context) {
    final pie = descripcionFotoVisible(descripcion);
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                clipBehavior: Clip.none,
                boundaryMargin: const EdgeInsets.all(double.infinity),
                child: SizedBox(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  child: Image(
                    image: imagen ?? NetworkImage(url),
                    fit: BoxFit.contain,
                  ),
                ),
              );
            },
          ),
        ),
        if (pie != null)
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.3),
            child: ColoredBox(
              color: const Color(0xB8000000),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(
                      pie,
                      style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.35),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class FichaDetallePerro extends StatefulWidget {
  final String idDocumento;
  final DosisAvisada? dosisAvisada;

  const FichaDetallePerro({super.key, required this.idDocumento, this.dosisAvisada});

  @override
  State<FichaDetallePerro> createState() => _FichaDetallePerroState();
}

class _FichaDetallePerroState extends State<FichaDetallePerro> {
  final PerroController _perroController = PerroController();
  final TratamientoController _tratamientoController = TratamientoController();
  final RecordatorioController _recordatorioController = RecordatorioController();
  final SeguimientoController _seguimientoController = SeguimientoController();
  final PesoController _pesoController = PesoController();
  final Set<String> _cerrandoSeguimiento = {};
  bool _guardandoPeso = false;
  final PageController _controladorCarrusel = PageController();
  final ImagePicker _picker = ImagePicker();
  bool _subiendoFoto = false;
  bool _modoReordenar = false;
  int? _egresoEnCurso;
  int _paginaActual = 0;
  double _escalaTexto = 1.3;
  List<Map<String, dynamic>> _fotosReordenar = [];
  bool _hojaDosisMostrada = false;

  String _formatearFecha(DateTime? fecha) => _perroController.formatearFecha(fecha);

  String _fechaHoyISO() => _tratamientoController.formatearFechaISO(DateTime.now());

  Future<void> _compartirFicha(PerroModel perro) async {
    try {
      await ExportarFicha.compartir(perro, edad: _formatearEdadTexto(perro));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo compartir la ficha')),
      );
    }
  }

  Future<bool> _toggleDosis(TratamientoModel tratamiento, DateTime fecha) async {
    try {
      await _tratamientoController.toggleDosis(widget.idDocumento, tratamiento, fecha);
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo actualizar el tratamiento')),
        );
      }
      return false;
    }
  }

  void _prepararHojaDosis(PerroModel perro) {
    final aviso = widget.dosisAvisada;
    if (aviso == null || _hojaDosisMostrada) return;
    _hojaDosisMostrada = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mostrarHojaDosis(perro, aviso);
    });
  }

  void _mostrarHojaDosis(PerroModel perro, DosisAvisada aviso) {
    TratamientoModel? tratamiento;
    for (final item in perro.tratamientos) {
      if (item.id == aviso.idTratamiento) {
        tratamiento = item;
        break;
      }
    }
    if (tratamiento == null) return;
    final marcada = tratamiento.registroDosis.contains(aviso.dia);
    final medicacion = tratamiento.medicacion.trim().isEmpty ? 'La medicación' : tratamiento.medicacion.trim();
    final hora = tratamiento.horaRecordatorio?.trim() ?? '';
    final texto = marcada
        ? 'Quedó marcada como dada${hora.isEmpty ? '.' : ' a las $hora.'}'
        : 'Está pendiente.';

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$medicacion de hoy', style: Theme.of(sheetContext).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(texto),
                const SizedBox(height: 16),
                if (marcada) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('Sí, se la di'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _dejarPendiente(tratamiento!, aviso);
                      },
                      child: const Text('No se la di, dejar pendiente'),
                    ),
                  ),
                ] else
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _marcarDadaDesdeAviso(tratamiento!, aviso);
                      },
                      child: const Text('Marcar como dada'),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _dejarPendiente(TratamientoModel tratamiento, DosisAvisada aviso) async {
    if (!tratamiento.registroDosis.contains(aviso.dia)) return;
    final fecha = DateTime.tryParse(aviso.dia);
    if (fecha == null) return;
    final ok = await _toggleDosis(tratamiento, fecha);
    if (!ok || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quedó pendiente')));
  }

  Future<void> _marcarDadaDesdeAviso(TratamientoModel tratamiento, DosisAvisada aviso) async {
    if (tratamiento.registroDosis.contains(aviso.dia)) return;
    final fecha = DateTime.tryParse(aviso.dia);
    if (fecha == null) return;
    await _toggleDosis(tratamiento, fecha);
  }

  String _formatearEdadTexto(PerroModel perro) => PerroController.formatearEdadTexto(perro);

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

  void _abrirFotoPantallaCompleta(String url, {String? descripcion}) {
    bool procesando = false;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StatefulBuilder(
          builder: (context, setStateLocal) => Scaffold(
            backgroundColor: Colors.black,
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              backgroundColor: Colors.black.withValues(alpha: 0.35),
              elevation: 0,
              foregroundColor: Colors.white,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                procesando
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                      )
                    : IconButton(
                        tooltip: 'Recortar foto',
                        icon: const Icon(Icons.crop, color: Colors.white),
                        onPressed: () => _recortarFotoExistente(url, context, setStateLocal, (valor) => procesando = valor),
                      ),
              ],
            ),
            body: VisorFoto(url: url, descripcion: descripcion),
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

  Future<void> _editarFotoAGaleria(Map<String, dynamic> foto, int index, {bool estudios = false}) async {
    final textoController = TextEditingController(text: foto['texto']?.toString() ?? '');

    final textoDescriptivo = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar descripción'),
        content: TextField(
          controller: textoController,
          decoration: InputDecoration(
            hintText: estudios ? 'Radiografía, herida, resultado...' : 'Descripción de la foto',
          ),
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
      if (estudios) {
        await _perroController.editarFotoDeEstudios(widget.idDocumento, index, textoDescriptivo);
      } else {
        await _perroController.editarFotoDeGaleria(widget.idDocumento, index, textoDescriptivo);
      }
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

  Future<void> _eliminarFotoAGaleria(Map<String, dynamic> foto, int index, {bool estudios = false}) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(estudios ? 'Eliminar estudio' : 'Eliminar foto'),
        content: Text(
          estudios ? '¿Querés eliminar este estudio?' : '¿Querés eliminar esta foto de la galería?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );

    if (confirmar != true) return;

    if (!mounted) return;

    final texto = (foto['texto'] ?? foto['descripcion'] ?? '').toString();
    setState(() => _subiendoFoto = true);
    try {
      final urlFoto = estudios
          ? await _perroController.eliminarFotoDeEstudios(widget.idDocumento, index)
          : await _perroController.eliminarFotoDeGaleria(widget.idDocumento, index);

      if (!mounted || urlFoto == null) return;
      var deshecha = false;
      ScaffoldMessenger.of(context)
          .showSnackBar(
            SnackBar(
              persist: false,
              duration: const Duration(seconds: 5),
              content: Text(estudios ? 'Estudio eliminado' : 'Foto eliminada'),
              action: SnackBarAction(
                label: 'Deshacer',
                textColor: AppColors.arena,
                onPressed: () {
                  deshecha = true;
                  final restaurar = estudios
                      ? _perroController.agregarFotoAEstudios(widget.idDocumento, urlFoto, texto)
                      : _perroController.agregarFotoAGaleria(widget.idDocumento, urlFoto, texto);
                  restaurar.catchError((_) {});
                },
              ),
            ),
          )
          .closed
          .then((_) async {
            if (deshecha) return;
            try {
              await FirebaseStorage.instance.refFromURL(urlFoto).delete();
            } catch (_) {}
          });
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

  Future<void> _moverFoto({required String desde, required int indice}) async {
    setState(() => _subiendoFoto = true);
    try {
      await _perroController.moverFoto(widget.idDocumento, desde: desde, indice: indice);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo mover la foto')));
      }
    } finally {
      if (mounted) setState(() => _subiendoFoto = false);
    }
  }

  Future<void> _agregarFotoAGaleria() => _agregarFoto(estudios: false);

  Future<void> _agregarFoto({required bool estudios}) async {
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
          title: Text(estudios ? 'Agregar estudio' : 'Agregar descripción (opcional)'),
          content: TextField(
            controller: textoController,
            decoration: InputDecoration(
              hintText: estudios ? 'Radiografía, herida, resultado...' : 'Ej: Jugando en el patio...',
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, null), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, textoController.text),
              child: Text(estudios ? 'Subir estudio' : 'Subir Foto'),
            ),
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

          if (estudios) {
            await _perroController.agregarFotoAEstudios(widget.idDocumento, urlDescarga, textoDescriptivo);
          } else {
            await _perroController.agregarFotoAGaleria(widget.idDocumento, urlDescarga, textoDescriptivo);
          }
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

  TextScaler get _escala => TextScaler.linear(_escalaTexto);

  static const _inicialesDia = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
  static const _nombresDia = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];

  Widget _buildHistorialDosis(TratamientoModel tratamiento, bool esInvitado) {
    final textTheme = Theme.of(context).textTheme;
    final hoy = DateTime.now();
    final hoyFecha = DateTime(hoy.year, hoy.month, hoy.day);
    final marcas = TratamientoController.marcasDosisRecientes(tratamiento, hoy: hoy);
    if (marcas.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        for (final marca in marcas)
          _puntoDosis(
            tratamiento: tratamiento,
            marca: marca,
            esHoy: marca.dia == hoyFecha,
            esInvitado: esInvitado,
            textTheme: textTheme,
          ),
      ],
    );
  }

  Widget _puntoDosis({
    required TratamientoModel tratamiento,
    required MarcaDiaDosis marca,
    required bool esHoy,
    required bool esInvitado,
    required TextTheme textTheme,
  }) {
    final Color fondo;
    final IconData? icono;
    final String estado;
    switch (marca.estado) {
      case EstadoMarcaDosis.dada:
        fondo = AppColors.dosisDada;
        icono = Icons.check;
        estado = 'dosis dada';
      case EstadoMarcaDosis.pendiente:
        fondo = AppColors.pendiente;
        icono = null;
        estado = 'dosis pendiente';
      case EstadoMarcaDosis.pausa:
        fondo = AppColors.pausado;
        icono = Icons.pause;
        estado = 'tratamiento en pausa';
      case EstadoMarcaDosis.olvidada:
        fondo = AppColors.dosisOlvidada;
        icono = Icons.close;
        estado = 'dosis olvidada';
    }
    final habilitado = !esInvitado;

    return Semantics(
      button: habilitado,
      label: '${esHoy ? 'Hoy' : _nombresDia[marca.dia.weekday - 1]} ${marca.dia.day}: $estado',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: habilitado
            ? () {
                HapticFeedback.selectionClick();
                _toggleDosis(tratamiento, marca.dia);
              }
            : null,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
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
              Text(
                _inicialesDia[marca.dia.weekday - 1],
                style: textTheme.labelMedium?.copyWith(
                  color: esHoy ? AppColors.navy : context.paleta.textoSuave,
                  fontWeight: esHoy ? FontWeight.w800 : FontWeight.w600,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tarjetaSeccion({
    required String titulo,
    required IconData icono,
    required List<Widget> children,
    Widget? accion,
  }) {
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
                  child: Text(
                    titulo,
                    textScaler: _escala,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ?accion,
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _encabezadoGrupo(String titulo, IconData icono) {
    return EncabezadoSeccion(titulo: titulo, icono: icono, textScaler: _escala);
  }

  String _capitalizar(String texto) {
    final limpio = texto.trim();
    if (limpio.isEmpty) return limpio;
    return limpio[0].toUpperCase() + limpio.substring(1);
  }

  Widget _chipDato(IconData icono, String texto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.paleta.relleno,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.paleta.borde),
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
        Text(etiqueta, textScaler: _escala, style: textTheme.labelMedium?.copyWith(color: context.paleta.textoSuave)),
        const SizedBox(height: 2),
        Text(
          valor,
          textScaler: _escala,
          style: sinDato
              ? textTheme.bodyLarge?.copyWith(color: context.paleta.textoSuave, fontStyle: FontStyle.italic)
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
                  PerroController.formatearCastracion(perro),
                ),
              ],
            ),
            if (perro.fechaIngreso != null || perro.fechaFallecimiento != null) ...[
              const SizedBox(height: 16),
              if (perro.fechaIngreso != null)
                _filaDato('Fecha de ingreso', _formatearFecha(perro.fechaIngreso)),
              if (perro.fechaFallecimiento != null) ...[
                if (perro.fechaIngreso != null) const SizedBox(height: 12),
                _filaDato('Fecha de fallecimiento', _formatearFecha(perro.fechaFallecimiento)),
              ],
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
        color: marcadoHoy ? AppColors.dosisDada.withValues(alpha: 0.08) : context.paleta.relleno,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: marcadoHoy ? AppColors.dosisDada.withValues(alpha: 0.4) : context.paleta.borde,
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
                                color: marcadoHoy ? context.paleta.textoSuave : context.paleta.texto,
                                decoration: marcadoHoy ? TextDecoration.lineThrough : TextDecoration.none,
                                decorationColor: context.paleta.textoSuave,
                              ),
                              child: Text(
                                _capitalizar(t.medicacion),
                                textScaler: _escala,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${t.indicaciones} \u00b7 ${diasDuracion > 0 ? '$diasDuracion d\u00edas' : 'Indefinido'}',
                              textScaler: _escala,
                              style: textTheme.bodyMedium?.copyWith(color: context.paleta.textoSuave),
                            ),
                            _progresoDuracion(t),
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

  Widget _progresoDuracion(TratamientoModel t) {
    final estado = TratamientoController.calcularEstadoDuracion(t);
    if (estado.fase == FaseTratamiento.indefinido) return const SizedBox.shrink();
    final texto = _textoDuracion(estado);
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Semantics(
          key: ValueKey(texto),
          label: texto,
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: ExcludeSemantics(child: _contenidoDuracion(estado)),
          ),
        ),
      ),
    );
  }

  String _textoDuracion(EstadoDuracion estado) {
    switch (estado.fase) {
      case FaseTratamiento.enCurso:
        final quedan = estado.restantes == 1 ? 'queda 1 día' : 'quedan ${estado.restantes} días';
        return 'Día ${estado.diaActual} de ${estado.total} · $quedan';
      case FaseTratamiento.ultimoDia:
        return 'Último día de medicación. Mañana el tratamiento se pausará automáticamente.';
      case FaseTratamiento.noIniciado:
        return estado.diasParaInicio == 1 ? 'Empieza mañana' : 'Empieza en ${estado.diasParaInicio} días';
      case FaseTratamiento.finalizado:
        final fin = estado.ultimoDia;
        if (fin == null) return 'Finalizó';
        return 'Finalizó el ${_fechaCorta(fin)}';
      case FaseTratamiento.indefinido:
        return '';
    }
  }

  Widget _contenidoDuracion(EstadoDuracion estado) {
    final textTheme = Theme.of(context).textTheme;
    final secundario = textTheme.bodyMedium?.copyWith(color: context.paleta.textoSuave);
    switch (estado.fase) {
      case FaseTratamiento.enCurso:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_textoDuracion(estado), textScaler: _escala, style: secundario),
            const SizedBox(height: 6),
            _barraDuracion(estado.diaActual / estado.total, AppColors.dosisDada),
          ],
        );
      case FaseTratamiento.ultimoDia:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.pausado.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                children: [
                  Icon(Icons.flag_rounded, size: 16, color: context.paleta.pausadoTexto),
                  Text(
                    'Último día de medicación',
                    textScaler: _escala,
                    style: textTheme.labelMedium?.copyWith(color: context.paleta.pausadoTexto),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            _barraDuracion(1, AppColors.pausado),
            const SizedBox(height: 6),
            Text(
              'Mañana el tratamiento se pausará automáticamente.',
              textScaler: _escala,
              style: secundario,
            ),
          ],
        );
      case FaseTratamiento.noIniciado:
      case FaseTratamiento.finalizado:
        return Text(_textoDuracion(estado), textScaler: _escala, style: secundario);
      case FaseTratamiento.indefinido:
        return const SizedBox.shrink();
    }
  }

  Widget _barraDuracion(double valor, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: LinearProgressIndicator(
        minHeight: 6,
        value: valor,
        color: color,
        backgroundColor: context.paleta.borde,
      ),
    );
  }

  String _fechaCorta(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    return '$dia/$mes/${fecha.year}';
  }

  String? _textoUltimaEdicion(PerroModel perro) {
    final nombre = perro.editadoPor?.trim() ?? '';
    final fecha = perro.editadoEn;
    if (nombre.isEmpty || fecha == null) return null;
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    final hora = fecha.hour.toString().padLeft(2, '0');
    final minuto = fecha.minute.toString().padLeft(2, '0');
    return 'Última edición: $nombre · $dia/$mes/${fecha.year}, $hora:$minuto';
  }

  /// Marca como inactivos los tratamientos diarios ya finalizados,
  /// persistiendo el cambio en Firestore para que dejen de listarse en "Tratamientos actuales".
  PerroModel _procesarAutoArchivado(PerroModel perro) {
    if (perro.tratamientos.isEmpty) return perro;

    final actualizados = _tratamientoController.autoArchivarVencidos(perro.tratamientos);
    if (!_tratamientoController.huboCambiosDeArchivado(perro.tratamientos, actualizados)) return perro;

    _tratamientoController.guardarTratamientos(widget.idDocumento, actualizados).catchError((_) {});

    return perro.copyWith(tratamientos: actualizados);
  }

  Widget? _buildFichaMedica(PerroModel perro) {
    if (perro.fichaMedica.trim().isEmpty) return null;
    return _tarjetaSeccion(
      titulo: 'Ficha médica',
      icono: Icons.favorite_outline,
      children: [
        _construirTextoFormateado(perro.fichaMedica, _escalaTexto),
      ],
    );
  }

  Widget? _buildTratamientosActuales(PerroModel perro, bool esInvitado) {
    final tratamientosActivos = _tratamientoController.obtenerActivosDiarios(perro.tratamientos);
    if (tratamientosActivos.isEmpty) return null;
    final fechaHoy = _fechaHoyISO();

    return _tarjetaSeccion(
      titulo: 'Tratamientos actuales',
      icono: Icons.medication_outlined,
      children: [
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
      ],
    );
  }

  Widget _botonHistorial(List<TratamientoModel> tratamientos) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _mostrarHistorialCompleto(tratamientos),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
          child: Row(
            children: [
              const Icon(Icons.calendar_month_outlined, size: 22, color: AppColors.navy),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Historial médico',
                  textScaler: _escala,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: context.paleta.textoSuave),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _buildPeso(PerroModel perro, bool esInvitado) {
    if (perro.pesos.isEmpty) return null;
    final ultimo = _pesoController.ultimo(perro.pesos);
    if (ultimo == null) return null;
    final variacion = _pesoController.variacion(perro.pesos);
    final textTheme = Theme.of(context).textTheme;
    final aprox = ultimo.estimado ? ' aprox.' : '';
    final nota = ultimo.nota.trim();

    return _tarjetaSeccion(
      titulo: 'Peso',
      icono: Icons.monitor_weight_outlined,
      accion: esInvitado
          ? null
          : IconButton(
              tooltip: 'Agregar peso',
              onPressed: _guardandoPeso ? null : _agregarPesoRapido,
              icon: const Icon(Icons.add),
            ),
      children: [
        Text(
          '${formatearKg(ultimo.kg)} kg$aprox',
          textScaler: _escala,
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          PesoController.formatearFecha(ultimo.fecha),
          textScaler: _escala,
          style: textTheme.bodyMedium?.copyWith(color: context.paleta.textoSuave),
        ),
        if (variacion != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              if (variacion.diferenciaKg.abs() >= 0.05) ...[
                Icon(
                  variacion.diferenciaKg > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 18,
                  color: context.paleta.texto,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                _pesoController.describirVariacion(variacion),
                textScaler: _escala,
                style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
        if (nota.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(nota, textScaler: _escala, style: textTheme.bodyMedium),
        ],
        if (perro.pesos.length >= 2) ...[
          const SizedBox(height: 12),
          GraficoPeso(pesos: perro.pesos),
        ],
      ],
    );
  }

  Future<void> _agregarPesoRapido() async {
    final peso = await mostrarDialogoPeso(context, controller: _pesoController);
    if (peso == null || !mounted) return;
    setState(() => _guardandoPeso = true);
    try {
      await _perroController.agregarPeso(widget.idDocumento, peso);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar el peso')),
      );
    } finally {
      if (mounted) setState(() => _guardandoPeso = false);
    }
  }

  Widget? _seguimientosEnCurso(PerroModel perro) {
    final vigentes = _seguimientoController.vigentes(perro.seguimientos);
    if (vigentes.isEmpty) return null;
    return _tarjetaSeccion(
        titulo: 'En seguimiento',
        icono: Icons.visibility_outlined,
        children: [
          for (var i = 0; i < vigentes.length; i++) ...[
            _filaSeguimientoFicha(vigentes[i]),
            if (i != vigentes.length - 1) const SizedBox(height: 8),
          ],
        ],
      );
  }

  Widget _filaSeguimientoFicha(SeguimientoModel seguimiento) {
    final visual = SeguimientoTipos.de(seguimiento.motivo);
    final detalle = seguimiento.detalle.trim();
    final plazo = _seguimientoController.describirPlazo(seguimiento);
    final textTheme = Theme.of(context).textTheme;
    final cerrando = _cerrandoSeguimiento.contains(seguimiento.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: visual.color.withValues(alpha: 0.12),
              child: Icon(visual.icono, size: 20, color: visual.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    visual.etiqueta,
                    textScaler: _escala,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium,
                  ),
                  Text(
                    detalle.isEmpty ? '$plazo · ${seguimiento.hora} h' : '$plazo · ${seguimiento.hora} h · $detalle',
                    textScaler: _escala,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(color: context.paleta.textoSuave),
                  ),
                ],
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: cerrando ? null : () => _cerrarSeguimiento(seguimiento),
            child: const Text('Cerrar seguimiento'),
          ),
        ),
      ],
    );
  }

  Future<void> _cerrarSeguimiento(SeguimientoModel seguimiento) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cerrar el seguimiento?'),
        content: const Text('Deja de avisar por este motivo. Podés crear uno nuevo si hace falta.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cerrar')),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    setState(() => _cerrandoSeguimiento.add(seguimiento.id));
    try {
      await _perroController.cerrarSeguimiento(widget.idDocumento, seguimiento.id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo cerrar el seguimiento')),
      );
    } finally {
      if (mounted) setState(() => _cerrandoSeguimiento.remove(seguimiento.id));
    }
  }

  Widget? _proximosRecordatorios(PerroModel perro) {
    final proximos = _recordatorioController.proximos(perro.recordatorios);
    if (proximos.isEmpty) return null;
    final visibles = proximos.take(3).toList();
    final resto = proximos.length - visibles.length;
    final textTheme = Theme.of(context).textTheme;
    return _tarjetaSeccion(
        titulo: 'Próximos recordatorios',
        icono: Icons.alarm_rounded,
        children: [
          for (var i = 0; i < visibles.length; i++) ...[
            _filaRecordatorioFicha(visibles[i]),
            if (i != visibles.length - 1 || resto > 0) const SizedBox(height: 8),
          ],
          if (resto > 0)
            Text(
              'y $resto más',
              textScaler: _escala,
              style: textTheme.labelMedium?.copyWith(color: context.paleta.textoSuave),
            ),
        ],
      );
  }

  Widget _filaRecordatorioFicha(RecordatorioModel recordatorio) {
    final visual = RecordatorioTipos.de(recordatorio.tipo);
    final nota = recordatorio.nota.trim();
    final cuando = _recordatorioController.formatearCuando(recordatorio.fechaHora);
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: visual.color.withValues(alpha: 0.12),
          child: Icon(visual.icono, size: 20, color: visual.color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                recordatorio.titulo,
                textScaler: _escala,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleMedium,
              ),
              Text(
                nota.isEmpty ? cuando : '$cuando · $nota',
                textScaler: _escala,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium?.copyWith(color: context.paleta.textoSuave),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _mostrarHistorialCompleto(List<TratamientoModel> tratamientos) {
    final eventosCalendario = _tratamientoController.construirEventosCalendario(tratamientos);
    final historial = _tratamientoController.construirHistorialLista(tratamientos);

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
          child: CalendarioHistorialWidget(
            eventosCalendario: eventosCalendario,
            historial: historial,
          ),
        ),
      ),
    );
  }

  Widget _bannerEgreso(PerroModel perro) {
    final motivo = PerroController.formatearMotivoEgreso(perro.motivoEgreso);
    final nota = perro.notaEgreso?.trim();
    final icono = perro.motivoEgreso == 'familia' ? Icons.home_rounded : Icons.favorite_rounded;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.paleta.activoTexto.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.paleta.activoTexto.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: context.paleta.activoTexto),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  motivo,
                  textScaler: _escala,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: context.paleta.activoTexto),
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

  Widget _historialEgresos(PerroModel perro, bool esInvitado) {
    final originales = perro.historialEgresos;
    final indices = List<int>.generate(originales.length, (i) => i);
    indices.sort((a, b) {
      final fechaA = originales[a].fechaEgreso;
      final fechaB = originales[b].fechaEgreso;
      if (fechaA == null && fechaB == null) return 0;
      if (fechaA == null) return 1;
      if (fechaB == null) return -1;
      return fechaB.compareTo(fechaA);
    });
    final filas = <Widget>[];
    for (var i = 0; i < indices.length; i++) {
      if (i > 0) filas.add(const Divider());
      final indice = indices[i];
      filas.add(_filaEgreso(originales[indice], indice, esInvitado));
    }
    return _tarjetaSeccion(
      titulo: 'Historial de egresos',
      icono: Icons.history_rounded,
      children: filas,
    );
  }

  Widget _filaEgreso(EgresoModel egreso, int indice, bool esInvitado) {
    final motivo = PerroController.formatearMotivoEgreso(egreso.motivo);
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
            color: context.paleta.activoTexto.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icono, size: 20, color: context.paleta.activoTexto),
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
                    color: context.paleta.textoSuave,
                    fontStyle: FontStyle.italic,
                  ),
                )
              else
                Text(
                  'Egreso: ${_perroController.formatearFecha(egreso.fechaEgreso)}',
                  textScaler: _escala,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.paleta.textoSuave),
                ),
              if (egreso.fechaRegreso != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Regreso: ${_perroController.formatearFecha(egreso.fechaRegreso)}',
                  textScaler: _escala,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.paleta.textoSuave),
                ),
              ],
              if (nota != null && nota.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  nota,
                  textScaler: _escala,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.paleta.textoSuave),
                ),
              ],
            ],
          ),
        ),
        if (!esInvitado)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                tooltip: 'Editar egreso',
                color: context.paleta.textoSuave,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                onPressed: _egresoEnCurso == indice ? null : () => _editarEgreso(indice, egreso),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                tooltip: 'Eliminar egreso',
                color: AppColors.error,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                onPressed: _egresoEnCurso == indice ? null : () => _eliminarEgreso(indice, egreso),
              ),
            ],
          ),
      ],
    );
  }

  Future<void> _editarEgreso(int indice, EgresoModel egreso) async {
    final nuevo = await showDialog<EgresoModel>(
      context: context,
      builder: (context) => _DialogoEditarEgreso(egreso: egreso),
    );
    if (nuevo == null || !mounted) return;
    await _guardarCambioEgreso(indice, egreso, nuevo, 'Egreso actualizado.');
  }

  Future<void> _eliminarEgreso(int indice, EgresoModel egreso) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar este egreso?'),
        content: const Text('Se borra del historial de la ficha. Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    await _guardarCambioEgreso(indice, egreso, null, 'Egreso eliminado.');
  }

  Future<void> _guardarCambioEgreso(
    int indice,
    EgresoModel esperado,
    EgresoModel? nuevo,
    String mensajeOk,
  ) async {
    setState(() => _egresoEnCurso = indice);
    try {
      await _perroController.actualizarHistorialEgresos(widget.idDocumento, esperado, indice, nuevo);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensajeOk)));
    } on HistorialDesactualizadoException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Otra persona modificó este historial. Revisá y volvé a intentar.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar el cambio.')),
      );
    } finally {
      if (mounted) setState(() => _egresoEnCurso = null);
    }
  }

  Column _buildInfoContenido(PerroModel perro, bool esInvitado) {
    final fichaMedica = _buildFichaMedica(perro);
    final peso = _buildPeso(perro, esInvitado);
    final tratamientos = _buildTratamientosActuales(perro, esInvitado);
    final seguimiento = esInvitado ? null : _seguimientosEnCurso(perro);
    final recordatorios = esInvitado ? null : _proximosRecordatorios(perro);
    final estudios = _buildEstudios(perro, esInvitado);
    final bloquesMedicos = <Widget>[
      ?fichaMedica,
      ?peso,
      ?tratamientos,
      if (perro.tratamientos.isNotEmpty) _botonHistorial(perro.tratamientos),
      ?seguimiento,
      ?recordatorios,
      ?estudios,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              perro.nombre.isNotEmpty ? perro.nombre : 'Sin nombre',
              textScaler: _escala,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            if (!esInvitado)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  backgroundColor: context.temaOscuro
                      ? Colors.transparent
                      : Color.lerp(AppColors.arena, AppColors.navy, 0.14),
                  foregroundColor: context.paleta.texto,
                  side: BorderSide(
                    color: context.temaOscuro
                        ? context.paleta.borde
                        : Color.lerp(AppColors.arena, AppColors.navy, 0.28)!,
                  ),
                  minimumSize: const Size(48, 48),
                ),
                onPressed: _subiendoFoto || _modoReordenar
                    ? null
                    : () async {
                        final eliminado = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FormularioPerro(
                              idDocumento: widget.idDocumento,
                              perroActual: perro,
                            ),
                          ),
                        );
                        if (eliminado == true && mounted) Navigator.pop(context);
                      },
                icon: const Icon(Icons.edit_note_rounded),
                label: Text('Editar ficha', textScaler: _escala),
              ),
          ],
        ),
        if (perro.estado == 'egresado') ...[
          const SizedBox(height: 12),
          _bannerEgreso(perro),
        ],
        const SizedBox(height: 16),
        _encabezadoGrupo('Perfil general', Icons.pets_rounded),
        _buildDatosBasicos(perro),
        if (perro.historia.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          _tarjetaSeccion(
            titulo: 'Historia y observaciones',
            icono: Icons.menu_book_outlined,
            children: [
              _construirTextoFormateado(perro.historia, _escalaTexto),
            ],
          ),
        ],
        if (perro.parientes.isNotEmpty) ...[
          const SizedBox(height: 12),
          _tarjetaSeccion(
            titulo: 'Familiares/Parientes',
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
                    backgroundColor: context.paleta.relleno,
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
        if (perro.historialEgresos.isNotEmpty) ...[
          const SizedBox(height: 12),
          _historialEgresos(perro, esInvitado),
        ],
        if (bloquesMedicos.isNotEmpty) ...[
          const SizedBox(height: 28),
          _encabezadoGrupo('Información médica', Icons.medical_services_outlined),
          for (var i = 0; i < bloquesMedicos.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            bloquesMedicos[i],
          ],
        ],
        if (!esInvitado && perro.galeriaEstudios.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _filaAgregarEstudio(),
          ),
        if (_textoUltimaEdicion(perro) case final marca?)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Text(
              marca,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.paleta.textoSuave),
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget? _buildEstudios(PerroModel perro, bool esInvitado) {
    final fotos = perro.galeriaEstudios;
    if (fotos.isEmpty) return null;
    return _tarjetaSeccion(
      titulo: 'Estudios y registros',
      icono: Icons.grid_view_rounded,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var index = 0; index < fotos.length; index++)
              _miniaturaEstudio(fotos[index], index, esInvitado),
          ],
        ),
        if (!esInvitado) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: _botonAgregarEstudio(),
          ),
        ],
      ],
    );
  }

  Widget _botonAgregarEstudio() {
    return TextButton.icon(
      onPressed: _subiendoFoto || _modoReordenar ? null : () => _agregarFoto(estudios: true),
      icon: const Icon(Icons.add_a_photo_outlined),
      label: const Text('Agregar estudio'),
    );
  }

  Widget _filaAgregarEstudio() {
    final textTheme = Theme.of(context).textTheme;
    final habilitado = !_subiendoFoto && !_modoReordenar;
    return Material(
      color: context.paleta.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: context.paleta.borde),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: habilitado ? () => _agregarFoto(estudios: true) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.document_scanner_outlined, color: context.paleta.lienzo),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Agregar un estudio', textScaler: _escala, style: textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      'Radiografías, análisis u otros registros.',
                      textScaler: _escala,
                      style: textTheme.bodyMedium?.copyWith(color: context.paleta.textoSuave),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _zonaPrimeraFoto() {
    final textTheme = Theme.of(context).textTheme;
    final habilitado = !_subiendoFoto && !_modoReordenar;
    final colorBorde = context.paleta.lienzo.withValues(alpha: 0.45);
    return Material(
      color: context.paleta.superficie,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: habilitado ? _agregarFotoAGaleria : null,
        child: CustomPaint(
          painter: _BordePunteado(color: colorBorde),
          child: SizedBox(
            height: 140,
            width: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_a_photo_outlined, size: 32, color: context.paleta.lienzo),
                const SizedBox(height: 8),
                Text('Agregar la primera foto', textScaler: _escala, style: textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  'Tocá acá para subirla',
                  textScaler: _escala,
                  style: textTheme.bodyMedium?.copyWith(color: context.paleta.textoSuave),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniaturaEstudio(Map<String, dynamic> foto, int index, bool esInvitado) {
    final url = foto['url']?.toString() ?? '';
    final texto = foto['texto']?.toString() ?? '';
    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        children: [
          Positioned.fill(
            child: Material(
              color: context.paleta.relleno,
              clipBehavior: Clip.antiAlias,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: url.isEmpty
                    ? null
                    : () => _abrirFotoPantallaCompleta(
                          url,
                          descripcion: descripcionFotoVisible(
                            foto['texto']?.toString(),
                            foto['descripcion']?.toString(),
                          ),
                        ),
                child: url.isEmpty
                    ? Icon(Icons.broken_image_outlined, color: context.paleta.textoSuave)
                    : Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Icon(Icons.broken_image_outlined, color: context.paleta.textoSuave),
                      ),
              ),
            ),
          ),
          if (texto.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text(
                      texto,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
              ),
            ),
          if (!esInvitado)
            Positioned(
              top: 2,
              right: 2,
              child: PopupMenuButton<String>(
                tooltip: 'Opciones del estudio',
                padding: EdgeInsets.zero,
                iconSize: 18,
                icon: const Icon(Icons.more_horiz, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.45),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(48, 48),
                  fixedSize: const Size(48, 48),
                ),
                onSelected: (accion) {
                  switch (accion) {
                    case 'mover':
                      _moverFoto(desde: 'galeria_estudios', indice: index);
                    case 'editar':
                      _editarFotoAGaleria(foto, index, estudios: true);
                    case 'borrar':
                      _eliminarFotoAGaleria(foto, index, estudios: true);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'mover', child: Text('Mover a fotos')),
                  PopupMenuItem(
                    value: 'editar',
                    child: Text(texto.isEmpty ? 'Agregar descripción' : 'Editar descripción'),
                  ),
                  const PopupMenuItem(value: 'borrar', child: Text('Eliminar')),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _rotuloFotos() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text('Fotos', style: Theme.of(context).textTheme.titleMedium),
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
      if (esInvitado) return const SizedBox.shrink();
      return _zonaPrimeraFoto();
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
                            onTap: () => _abrirFotoPantallaCompleta(
                              foto['url']?.toString() ?? '',
                              descripcion: descripcionFotoVisible(
                                foto['texto']?.toString(),
                                foto['descripcion']?.toString(),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(foto['url'] ?? '', fit: BoxFit.contain),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (foto['texto'] != null && foto['texto'].toString().isNotEmpty)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.paleta.borde),
                        ),
                        child: Text(
                          foto['texto'],
                          textScaler: TextScaler.linear(_escalaTexto),
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                          maxLines: 3,
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
                    child: PopupMenuButton<String>(
                      tooltip: 'Opciones de la foto',
                      icon: const Icon(Icons.more_horiz),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.55),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(48, 48),
                        fixedSize: const Size(48, 48),
                      ),
                      onSelected: (accion) {
                        switch (accion) {
                          case 'editar':
                            _editarFotoAGaleria(foto, index);
                          case 'mover':
                            _moverFoto(desde: 'galeria', indice: index);
                          case 'eliminar':
                            _eliminarFotoAGaleria(foto, index);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'editar',
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.notes_rounded),
                            title: Text('Editar descripción'),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'mover',
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.drive_file_move_outlined),
                            title: Text('Mover a estudios'),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'eliminar',
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.delete_outline),
                            title: Text('Eliminar foto'),
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
            child: IconButton.filled(
              tooltip: 'Foto anterior',
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: 0.5),
                foregroundColor: Colors.white,
                minimumSize: const Size(48, 48),
              ),
              icon: const Icon(Icons.arrow_back),
              onPressed: _moverIzquierda,
            ),
          ),
        if (_paginaActual < galeria.length - 1)
          Positioned(
            right: 8,
            child: IconButton.filled(
              tooltip: 'Foto siguiente',
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: 0.5),
                foregroundColor: Colors.white,
                minimumSize: const Size(48, 48),
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
        _prepararHojaDosis(perro);

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
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  tooltip: 'Más opciones',
                  onSelected: (accion) async {
                    switch (accion) {
                      case 'achicar':
                        setState(() => _escalaTexto -= 0.15);
                      case 'agrandar':
                        setState(() => _escalaTexto += 0.15);
                      case 'compartir':
                        await Future<void>.delayed(Duration.zero);
                        if (!mounted) return;
                        await _compartirFicha(perro);
                      case 'imagen':
                        await Future<void>.delayed(Duration.zero);
                        if (!context.mounted) return;
                        await Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => PantallaTarjetaPerro(perro: perro)),
                        );
                      case 'reordenar':
                        _activarModoReordenar(perro);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem<String>(
                      value: 'achicar',
                      enabled: _escalaTexto > 1.0,
                      child: const _OpcionMenu(icono: Icons.zoom_out, texto: 'Achicar texto'),
                    ),
                    const PopupMenuItem<String>(
                      value: 'agrandar',
                      child: _OpcionMenu(icono: Icons.zoom_in, texto: 'Agrandar texto'),
                    ),
                    const PopupMenuItem<String>(
                      value: 'compartir',
                      child: _OpcionMenu(icono: Icons.picture_as_pdf_outlined, texto: 'Compartir ficha (PDF)'),
                    ),
                    const PopupMenuItem<String>(
                      value: 'imagen',
                      child: _OpcionMenu(icono: Icons.image_outlined, texto: 'Compartir como imagen'),
                    ),
                    if (!esInvitado && !_modoReordenar)
                      const PopupMenuItem<String>(
                        value: 'reordenar',
                        child: _OpcionMenu(icono: Icons.reorder, texto: 'Reordenar fotos'),
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
                final mostrarCaja = galeria.isNotEmpty || _modoReordenar;
                final panelInfo = Center(
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
                );

                if (isWide) {
                  if (!mostrarCaja && esInvitado) return panelInfo;
                  return Row(
                    children: [
                      panelInfo,
                      Expanded(
                        flex: 2,
                        child: mostrarCaja
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                                    child: _rotuloFotos(),
                                  ),
                                  Expanded(child: _buildGaleria(galeria, esInvitado, perro)),
                                ],
                              )
                            : Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 24),
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 420),
                                    child: _zonaPrimeraFoto(),
                                  ),
                                ),
                              ),
                      ),
                    ],
                  );
                }
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (mostrarCaja) ...[
                        _rotuloFotos(),
                        SizedBox(
                          height: 220,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: context.paleta.superficie,
                              borderRadius: BorderRadius.all(Radius.circular(24)),
                              boxShadow: [
                                BoxShadow(color: AppColors.sombra, blurRadius: 16, offset: Offset(0, 4)),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: const BorderRadius.all(Radius.circular(24)),
                              child: _buildGaleria(galeria, esInvitado, perro),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ] else if (!esInvitado) ...[
                        _zonaPrimeraFoto(),
                        const SizedBox(height: 16),
                      ],
                      _buildInfoContenido(perro, esInvitado),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      }
    );
  }
}

class _BordePunteado extends CustomPainter {
  final Color color;

  const _BordePunteado({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final pintura = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final camino = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
          const Radius.circular(20),
        ),
      );
    for (final tramo in camino.computeMetrics()) {
      const dash = 7.0;
      const espacio = 5.0;
      var distancia = 0.0;
      while (distancia < tramo.length) {
        final fin = (distancia + dash).clamp(0.0, tramo.length);
        canvas.drawPath(tramo.extractPath(distancia, fin), pintura);
        distancia += dash + espacio;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BordePunteado anterior) => anterior.color != color;
}

enum _VistaHistorial { calendario, lista }

class CalendarioHistorialWidget extends StatefulWidget {
  final Map<DateTime, List<Map<String, dynamic>>> eventosCalendario;
  final List<EntradaHistorial> historial;

  const CalendarioHistorialWidget({
    super.key,
    required this.eventosCalendario,
    required this.historial,
  });

  @override
  State<CalendarioHistorialWidget> createState() => _CalendarioHistorialWidgetState();
}

class _CalendarioHistorialWidgetState extends State<CalendarioHistorialWidget> {
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  late final Future<void> _localeListo;
  _VistaHistorial _vista = _VistaHistorial.lista;
  String? _filtroCategoria;
  final TextEditingController _busqueda = TextEditingController();

  static const _ordenCategorias = ['diario', 'unico', 'vacuna', 'higiene', 'evento', 'veterinaria'];

  @override
  void initState() {
    super.initState();
    _localeListo = initializeDateFormatting('es_ES');
    _busqueda.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
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
          color: context.paleta.relleno,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.paleta.borde),
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
          SegmentedButton<_VistaHistorial>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: _VistaHistorial.lista,
                label: Text('Resumen'),
                icon: Icon(Icons.view_list_outlined),
              ),
              ButtonSegment(
                value: _VistaHistorial.calendario,
                label: Text('Calendario'),
                icon: Icon(Icons.calendar_month_outlined),
              ),
            ],
            selected: {_vista},
            onSelectionChanged: (seleccion) => setState(() => _vista = seleccion.first),
          ),
          const SizedBox(height: 16),
          if (_vista == _VistaHistorial.lista)
            _panelLista()
          else ...[
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
                      weekdayStyle: textTheme.labelMedium?.copyWith(color: context.paleta.textoSuave) ?? const TextStyle(),
                      weekendStyle: textTheme.labelMedium?.copyWith(color: context.paleta.textoSuave) ?? const TextStyle(),
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
                    style: textTheme.bodyMedium?.copyWith(color: context.paleta.textoSuave),
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
        ],
      ),
    );
  }

  Widget _panelLista() {
    return FutureBuilder<void>(
      future: _localeListo,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final filtradas = _entradasFiltradas();
        final categorias = [
          for (final categoria in _ordenCategorias)
            if (widget.historial.any((entrada) => entrada.categoria == categoria)) categoria,
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _busqueda,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Buscar medicación o indicación',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            if (categorias.length > 1) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Todas'),
                    selected: _filtroCategoria == null,
                    onSelected: (seleccionado) {
                      if (!seleccionado) return;
                      setState(() => _filtroCategoria = null);
                    },
                  ),
                  for (final categoria in categorias)
                    ChoiceChip(
                      label: Text(CategoryColors.etiqueta(categoria)),
                      selected: _filtroCategoria == categoria,
                      onSelected: (seleccionado) {
                        setState(() => _filtroCategoria = seleccionado ? categoria : null);
                      },
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            if (filtradas.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Ningún registro coincide.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.paleta.textoSuave),
                ),
              )
            else
              for (final grupo in _agrupar(filtradas)) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, top: 4),
                  child: Text(grupo.$1, style: Theme.of(context).textTheme.titleMedium),
                ),
                for (final entrada in grupo.$2) _filaHistorial(entrada),
              ],
          ],
        );
      },
    );
  }

  List<EntradaHistorial> _entradasFiltradas() {
    final consulta = _busqueda.text.trim().toLowerCase();
    return [
      for (final entrada in widget.historial)
        if (_filtroCategoria == null || entrada.categoria == _filtroCategoria)
          if (consulta.isEmpty ||
              entrada.titulo.toLowerCase().contains(consulta) ||
              entrada.indicaciones.toLowerCase().contains(consulta))
            entrada,
    ];
  }

  List<(String, List<EntradaHistorial>)> _agrupar(List<EntradaHistorial> entradas) {
    final grupos = <String, List<EntradaHistorial>>{};
    final orden = <String>[];
    for (final entrada in entradas) {
      final fecha = entrada.fechaFin ?? entrada.fechaInicio;
      final clave = fecha == null ? 'Sin fecha' : _tituloMes(fecha);
      if (!grupos.containsKey(clave)) orden.add(clave);
      grupos.putIfAbsent(clave, () => []).add(entrada);
    }
    return [
      for (final clave in orden) (clave, grupos[clave]!),
    ];
  }

  String _tituloMes(DateTime fecha) {
    final texto = DateFormat('MMMM y', 'es_ES').format(fecha);
    if (texto.isEmpty) return texto;
    return texto[0].toUpperCase() + texto.substring(1);
  }

  String _fechaCortaHistorial(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    return '$dia/$mes/${fecha.year}';
  }

  String _resumenHistorial(EntradaHistorial entrada) {
    final inicio = entrada.fechaInicio;
    final fin = entrada.fechaFin;
    if (inicio == null && fin == null) return 'Sin fecha';
    final desde = _fechaCortaHistorial(inicio ?? fin!);
    final rango = fin == null ? desde : '$desde – ${_fechaCortaHistorial(fin)}';
    if (entrada.categoria == 'diario') {
      if (entrada.cantidadDosis <= 0) return '$rango · sin dosis registradas';
      final dosis = entrada.cantidadDosis == 1 ? '1 dosis' : '${entrada.cantidadDosis} dosis';
      return '$rango · $dosis';
    }
    if (entrada.cantidadDosis > 1) return '$rango · ${entrada.cantidadDosis} dosis';
    return rango;
  }

  Widget _filaHistorial(EntradaHistorial entrada) {
    final textTheme = Theme.of(context).textTheme;
    final fecha = entrada.fechaInicio ?? entrada.fechaFin;
    final enCurso = entrada.activo && entrada.categoria == 'diario';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: context.paleta.relleno,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: context.paleta.borde),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: fecha == null
              ? null
              : () => setState(() {
                    _vista = _VistaHistorial.calendario;
                    _selectedDay = fecha;
                    _focusedDay = fecha;
                  }),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: CategoryColors.tinte(entrada.categoria),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    CategoryColors.icono(entrada.categoria),
                    size: 20,
                    color: CategoryColors.base(entrada.categoria),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entrada.titulo, style: textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(
                        enCurso ? '${_resumenHistorial(entrada)} · En curso' : _resumenHistorial(entrada),
                        style: textTheme.bodyMedium?.copyWith(color: context.paleta.textoSuave),
                      ),
                      if (entrada.indicaciones.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          entrada.indicaciones,
                          style: textTheme.bodyMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogoEditarEgreso extends StatefulWidget {
  final EgresoModel egreso;

  const _DialogoEditarEgreso({required this.egreso});

  @override
  State<_DialogoEditarEgreso> createState() => _DialogoEditarEgresoState();
}

class _DialogoEditarEgresoState extends State<_DialogoEditarEgreso> {
  late String _motivo;
  DateTime? _fechaEgreso;
  DateTime? _fechaRegreso;
  late final TextEditingController _nota;
  String? _error;

  @override
  void initState() {
    super.initState();
    final motivo = widget.egreso.motivo;
    _motivo = motivo == 'familia' ? 'familia' : 'adopcion';
    _fechaEgreso = widget.egreso.fechaEgreso;
    _fechaRegreso = widget.egreso.fechaRegreso;
    _nota = TextEditingController(text: widget.egreso.nota ?? '');
  }

  @override
  void dispose() {
    _nota.dispose();
    super.dispose();
  }

  String _textoFecha(DateTime? fecha) {
    if (fecha == null) return 'Sin fecha';
    final dd = fecha.day.toString().padLeft(2, '0');
    final mm = fecha.month.toString().padLeft(2, '0');
    return '$dd/$mm/${fecha.year}';
  }

  Future<void> _elegirEgreso() async {
    final hoy = DateTime.now();
    final inicial = _fechaEgreso ?? hoy;
    final fecha = await showDatePicker(
      context: context,
      initialDate: inicial.isAfter(hoy) ? hoy : inicial,
      firstDate: DateTime(2000),
      lastDate: hoy,
    );
    if (fecha == null) return;
    setState(() => _fechaEgreso = fecha);
  }

  Future<void> _elegirRegreso() async {
    final hoy = DateTime.now();
    final inicial = _fechaRegreso ?? _fechaEgreso ?? hoy;
    final fecha = await showDatePicker(
      context: context,
      initialDate: inicial.isAfter(hoy) ? hoy : inicial,
      firstDate: DateTime(2000),
      lastDate: hoy,
    );
    if (fecha == null) return;
    setState(() => _fechaRegreso = fecha);
  }

  void _guardar() {
    final nota = _nota.text.trim();
    final nuevo = EgresoModel(
      motivo: _motivo,
      fechaEgreso: _fechaEgreso,
      nota: nota.isEmpty ? null : nota,
      fechaRegreso: _fechaRegreso,
    );
    final error = PerroController.validarEgreso(nuevo);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context, nuevo);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar egreso'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final ancho = constraints.maxWidth - 24;
                Widget chip(String valor, String texto) {
                  return ChoiceChip(
                    label: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: ancho),
                      child: Text(texto),
                    ),
                    selected: _motivo == valor,
                    onSelected: (_) => setState(() => _motivo = valor),
                  );
                }

                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    chip('adopcion', 'Adoptado'),
                    chip('familia', 'Volvió con su familia'),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Fecha de egreso'),
              subtitle: Text(_textoFecha(_fechaEgreso)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _elegirEgreso,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Fecha de regreso'),
              subtitle: Text(_textoFecha(_fechaRegreso)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _elegirRegreso,
            ),
            if (_fechaRegreso != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() => _fechaRegreso = null),
                  child: const Text('Quitar fecha de regreso'),
                ),
              ),
            TextField(
              controller: _nota,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Nota (opcional)',
                helperText: 'La ven también los visitantes. No cargues datos personales.',
                helperMaxLines: 3,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _guardar, child: const Text('Guardar')),
      ],
    );
  }
}

class _OpcionMenu extends StatelessWidget {
  final IconData icono;
  final String texto;

  const _OpcionMenu({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icono, size: 22, color: context.paleta.texto),
        const SizedBox(width: 12),
        Expanded(child: Text(texto)),
      ],
    );
  }
}
