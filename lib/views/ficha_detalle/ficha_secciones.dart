part of '../ficha_detalle_perro.dart';

mixin _FichaSecciones on _FichaEstado {
  String _formatearFecha(DateTime? fecha) => _perroController.formatearFecha(fecha);

  String _fechaHoyISO() => _tratamientoController.formatearFechaISO(DateTime.now());

  Future<void> _compartirFicha(PerroModel perro) async {
    try {
      final esInvitado = ref.read(sessionProvider).esInvitado;
      final nuevos = esInvitado
          ? const <EstudioModel>[]
          : ref.read(estudiosProvider(widget.idDocumento)).asData?.value ?? const <EstudioModel>[];
      await ExportarFicha.compartir(
        perro,
        edad: _formatearEdadTexto(perro),
        incluirEstudios: !esInvitado,
        estudiosNuevos: nuevos,
        bajarRuta: _estudioController.descargar,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo compartir la ficha')),
      );
    }
  }

  Future<bool> _toggleDosis(TratamientoModel tratamiento, DateTime fecha) async {
    if (!TratamientoController.puedeMarcarDosis(tratamiento, fecha)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ese día está fuera del período del tratamiento')),
        );
      }
      return false;
    }
    try {
      return await _tratamientoController.toggleDosis(widget.idDocumento, tratamiento, fecha);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo actualizar el tratamiento')),
        );
      }
      return false;
    }
  }

  TratamientoModel? _tratamientoDelAviso(PerroModel? perro, DosisAvisada aviso) {
    if (perro == null) return null;
    for (final item in perro.tratamientos) {
      if (item.id == aviso.idTratamiento) return item;
    }
    return null;
  }

  void _programarAviso(PerroModel perro, {required bool desdeCache}) {
    var mostrar = false;
    final aviso = widget.dosisAvisada;
    if (aviso != null && !_hojaDosisMostrada) {
      final tratamiento = _tratamientoDelAviso(perro, aviso);
      if (tratamiento == null) {
        if (!desdeCache) _hojaDosisMostrada = true;
      } else if (listoParaAvisoDosis(
        desdeCache: desdeCache,
        marcada: dosisAvisadaMarcada(tratamiento.registroDosis, aviso.dia),
      )) {
        _hojaDosisMostrada = true;
        mostrar = true;
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _perroVisible.value = perro;
      if (mostrar && aviso != null) _mostrarHojaDosis(aviso);
    });
  }

  void _mostrarHojaDosis(DosisAvisada aviso) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return ValueListenableBuilder<PerroModel?>(
          valueListenable: _perroVisible,
          builder: (context, perro, _) {
            final tratamiento = _tratamientoDelAviso(perro, aviso);
            if (tratamiento == null) return const SizedBox.shrink();
            final marcada = dosisAvisadaMarcada(tratamiento.registroDosis, aviso.dia);
            final medicacion = tratamiento.medicacion.trim().isEmpty
                ? 'La medicación'
                : tratamiento.medicacion.trim();
            final fechaAviso = DateTime.tryParse(aviso.dia);
            final ahora = DateTime.now();
            final esHoy = fechaAviso != null &&
                fechaAviso.year == ahora.year &&
                fechaAviso.month == ahora.month &&
                fechaAviso.day == ahora.day;
            final tituloDosis = esHoy || fechaAviso == null
                ? '$medicacion de hoy'
                : '$medicacion del ${_fechaCorta(fechaAviso)}';
            final hora = tratamiento.horaRecordatorio?.trim() ?? '';
            final texto = marcada
                ? 'Quedó marcada como dada${hora.isEmpty ? '.' : ' a las $hora.'}'
                : 'Está pendiente.';

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tituloDosis, style: Theme.of(sheetContext).textTheme.titleLarge),
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
                            final actual = _tratamientoDelAviso(_perroVisible.value, aviso);
                            Navigator.pop(sheetContext);
                            if (actual != null) _dejarPendiente(actual, aviso);
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
                            final actual = _tratamientoDelAviso(_perroVisible.value, aviso);
                            Navigator.pop(sheetContext);
                            if (actual != null) _marcarDadaDesdeAviso(actual, aviso);
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
    _perroVisible.dispose();
    _controladorCarrusel.dispose();
    super.dispose();
  }

  void _moverIzquierda() => _controladorCarrusel.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  void _moverDerecha() => _controladorCarrusel.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);

  void _abrirFotoPantallaCompleta(
    String url, {
    String? descripcion,
    ImageProvider? imagen,
    Uint8List? bytesIniciales,
    String? rutaEstudio,
    Future<void> Function(Uint8List archivo)? guardarRecorte,
  }) {
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
                        onPressed: () => _recortarFotoExistente(
                          url,
                          context,
                          setStateLocal,
                          (valor) => procesando = valor,
                          bytesIniciales: bytesIniciales,
                          guardarRecorte: guardarRecorte,
                        ),
                      ),
              ],
            ),
            body: rutaEstudio == null
                ? VisorFoto(url: url, descripcion: descripcion, imagen: imagen)
                : _VisorEstudio(ruta: rutaEstudio, descripcion: descripcion, inicial: bytesIniciales),
          ),
        ),
      ),
    );
  }

  Future<void> _recortarFotoExistente(
    String url,
    BuildContext context,
    StateSetter setStateLocal,
    void Function(bool) actualizarProcesando, {
    Uint8List? bytesIniciales,
    Future<void> Function(Uint8List archivo)? guardarRecorte,
  }) async {
    setStateLocal(() => actualizarProcesando(true));
    final colorScheme = Theme.of(context).colorScheme;
    try {
      final directorioTemporal = await getTemporaryDirectory();
      final archivoTemp = File('${directorioTemporal.path}/temp_recorte_${DateTime.now().millisecondsSinceEpoch}.jpg');
      if (bytesIniciales != null) {
        await archivoTemp.writeAsBytes(bytesIniciales);
      } else {
        final respuesta = await http.get(Uri.parse(url));
        await archivoTemp.writeAsBytes(respuesta.bodyBytes);
      }

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

      final recorte = await File(croppedFile.path).readAsBytes();
      if (guardarRecorte != null) {
        await guardarRecorte(recorte);
      } else {
        final fotos = _fotos;
        final nuevaUrl = await fotos.subirRecorte(File(croppedFile.path));
        await _perroController.actualizarUrlDeFoto(widget.idDocumento, url, nuevaUrl);
      }

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

    final texto = (foto['texto'] ?? foto['descripcion'] ?? '').toString();
    setState(() => _subiendoFoto = true);
    try {
      final urlFoto = await _perroController.eliminarFotoDeGaleria(widget.idDocumento, index);
      final fotos = _fotos;

      if (!mounted || urlFoto == null) return;
      var deshecha = false;
      ScaffoldMessenger.of(context)
          .showSnackBar(
            SnackBar(
              persist: false,
              duration: const Duration(seconds: 5),
              content: const Text('Foto eliminada'),
              action: SnackBarAction(
                label: 'Deshacer',
                textColor: AppColors.arena,
                onPressed: () {
                  deshecha = true;
                  _perroController.agregarFotoAGaleria(widget.idDocumento, urlFoto, texto).catchError((_) {});
                },
              ),
            ),
          )
          .closed
          .then((_) async {
            if (deshecha) return;
            try {
              await fotos.borrarPorUrl(urlFoto);
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
  Future<void> _editarEstudio(EntradaEstudio entrada) async {
    final textoController = TextEditingController(text: entrada.texto);
    final textoDescriptivo = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar descripción'),
        content: TextField(
          controller: textoController,
          decoration: const InputDecoration(hintText: 'Radiografía, herida, resultado...'),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, textoController.text), child: const Text('Guardar')),
        ],
      ),
    );
    if (textoDescriptivo == null || !mounted) return;
    final guardado = await _ejecutarGuardado(claveGuardadoEstudio, () async {
      if (entrada.esLegacy) {
        await _estudioController.migrarLegacy(
          perroId: widget.idDocumento,
          indice: entrada.indiceLegacy!,
          texto: textoDescriptivo,
        );
      } else {
        await _estudioController.editarTexto(widget.idDocumento, entrada.estudio!.id, textoDescriptivo);
      }
    });
    if (guardado == ResultadoGuardado.error && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo actualizar la foto')),
      );
    }
  }

  Future<void> _eliminarEstudio(EntradaEstudio entrada) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar estudio'),
        content: const Text('¿Querés eliminar este estudio?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    final guardado = await _ejecutarGuardado(claveGuardadoEstudio, () async {
      if (entrada.esLegacy) {
        await _estudioController.quitarLegacy(widget.idDocumento, entrada.indiceLegacy!);
      } else {
        await _estudioController.quitarDocumento(widget.idDocumento, entrada.estudio!.id);
      }
    });
    if (guardado == ResultadoGuardado.error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo eliminar la foto')),
      );
      return;
    }
    if (!mounted) return;
    final fotos = _fotos;
    var deshecha = false;
    ScaffoldMessenger.of(context)
        .showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 5),
            content: const Text('Estudio eliminado'),
            action: SnackBarAction(
              label: 'Deshacer',
              textColor: AppColors.arena,
              onPressed: () {
                deshecha = true;
                final restaurar = entrada.esLegacy
                    ? _estudioController.restaurarLegacy(
                        widget.idDocumento,
                        entrada.urlLegacy ?? '',
                        entrada.texto,
                      )
                    : _estudioController.restaurarDocumento(widget.idDocumento, entrada.estudio!);
                restaurar.catchError((_) {});
              },
            ),
          ),
        )
        .closed
        .then((_) async {
          if (deshecha) return;
          if (entrada.esLegacy) {
            final url = entrada.urlLegacy;
            if (url == null || url.isEmpty) return;
            try {
              await fotos.borrarPorUrl(url);
            } catch (_) {}
          } else {
            await _estudioController.borrarArchivo(entrada.estudio!.ruta);
          }
        });
  }

  Future<void> _moverEstudio(EntradaEstudio entrada) async {
    final guardado = await _ejecutarGuardado(
      claveGuardadoEstudio,
      () => _estudioController.moverHaciaGaleria(perroId: widget.idDocumento, entrada: entrada),
    );
    if (guardado == ResultadoGuardado.error && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo mover la foto')),
      );
    }
  }

  Future<void> _moverGaleriaAEstudios(int indice, String? fotoPerfil) async {
    final guardado = await _ejecutarGuardado(
      claveGuardadoEstudio,
      () => _estudioController.moverDesdeGaleria(
        perroId: widget.idDocumento,
        indice: indice,
        fotoPerfil: fotoPerfil,
      ),
    );
    if (guardado == ResultadoGuardado.error && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo mover la foto')),
      );
    }
  }

  Future<void> _agregarFotoAGaleria() => _agregarFoto(estudios: false);

  Future<void> _agregarFoto({required bool estudios}) async {
    final imagen = await _fotos.elegirDeGaleria();

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
          if (estudios) {
            final bytes = await archivoParaSubir.readAsBytes();
            final guardado = await _ejecutarGuardado(
              claveGuardadoEstudio,
              () => _estudioController.agregar(widget.idDocumento, bytes, textoDescriptivo),
            );
            if (guardado == ResultadoGuardado.error) {
              throw StateError('estudio');
            }
          } else {
            final fotos = _fotos;
            final urlDescarga = await fotos.subirGaleria(archivoParaSubir);
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
        estado = 'tratamiento suspendido';
      case EstadoMarcaDosis.olvidada:
        fondo = AppColors.dosisOlvidada;
        icono = Icons.close;
        estado = 'dosis olvidada';
    }
    final habilitado = !esInvitado;

    return Semantics(
      button: habilitado,
      label: '${esHoy ? 'Hoy' : _FichaEstado.nombresDia[marca.dia.weekday - 1]} ${marca.dia.day}: $estado',
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
                  border: esHoy ? Border.all(color: colorIconoSeccion(context), width: 2) : null,
                ),
                child: icono == null ? null : Icon(icono, size: 14, color: Colors.white),
              ),
              Text(
                esWindows ? '${marca.dia.day}' : _FichaEstado.inicialesDia[marca.dia.weekday - 1],
                style: textTheme.labelMedium?.copyWith(
                  color: esHoy ? colorIconoSeccion(context) : context.paleta.textoSuave,
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
                Icon(icono, size: 22, color: colorIconoSeccion(context)),
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
          Icon(icono, size: 18, color: colorIconoSeccion(context)),
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

  Widget _buildTarjetaTratamiento(
    TratamientoModel t,
    String fechaHoy,
    bool esInvitado,
    String nombrePerro,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final marcadoHoy = t.registroDosis.contains(fechaHoy);
    final ValueChanged<bool?>? alCambiar = esInvitado ? null : (_) => _toggleDosis(t, DateTime.now());
    final fijo = t.tipoDuracion == TratamientoModel.tipoDias && t.diasDuracion > 0;
    final hastaAviso = t.tipoDuracion == TratamientoModel.tipoHastaAviso;
    final tacharHoy = marcadoHoy && !esWindows;

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
                    Checkbox(
                      value: marcadoHoy,
                      onChanged: alCambiar,
                      fillColor: esWindows
                          ? WidgetStateProperty.resolveWith((estados) {
                              if (estados.contains(WidgetState.selected)) return AppColors.dosisDada;
                              return null;
                            })
                          : null,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _nombreYDuracion(t, textTheme, tacharHoy, fijo),
                            const SizedBox(height: 2),
                            _resumenTarjeta(t, fijo),
                            if (fijo) _progresoDuracion(t),
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
            if (!esInvitado && TratamientoController.hayDiasAnteriores(t))
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _abrirDosisAnteriores(t),
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text('Marcar un día anterior', textScaler: _escala),
                ),
              ),
            if (!esInvitado) _accionesTratamiento(t, nombrePerro, hastaAviso: hastaAviso),
          ],
        ),
      ),
    );
  }

  Widget _nombreTratamiento(TratamientoModel t, TextTheme textTheme, bool tacharHoy) {
    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      style: (textTheme.titleMedium ?? const TextStyle()).copyWith(
        color: tacharHoy ? context.paleta.textoSuave : context.paleta.texto,
        decoration: tacharHoy ? TextDecoration.lineThrough : TextDecoration.none,
        decorationColor: context.paleta.textoSuave,
      ),
      child: Text(
        _capitalizar(t.medicacion),
        textScaler: _escala,
      ),
    );
  }

  Widget _nombreYDuracion(TratamientoModel t, TextTheme textTheme, bool tacharHoy, bool fijo) {
    final nombre = _nombreTratamiento(t, textTheme, tacharHoy);
    if (esAndroid) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          nombre,
          if (!fijo) ...[
            const SizedBox(height: 6),
            _chipDuracion(t),
          ],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(child: nombre),
        if (!fijo) ...[
          const SizedBox(width: 6),
          _chipDuracion(t),
        ],
      ],
    );
  }

  Widget _chipDuracion(TratamientoModel tratamiento) {
    final dePorVida = tratamiento.dePorVida;
    final color = colorIconoSeccion(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            dePorVida ? Icons.all_inclusive : Icons.hourglass_empty,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            dePorVida ? 'De por vida' : 'Hasta nuevo aviso',
            textScaler: _escala,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  Widget _resumenTarjeta(TratamientoModel tratamiento, bool fijo) {
    final estilo = Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.paleta.textoSuave);
    if (fijo) {
      return Text(
        '${tratamiento.indicaciones} · ${tratamiento.diasDuracion} días',
        textScaler: _escala,
        style: estilo,
      );
    }
    if (tratamiento.dePorVida) {
      final desde = tratamiento.fechaInicio == null ? '' : 'Desde ${_fechaCorta(tratamiento.fechaInicio!)}';
      final actual = tratamiento.indicaciones.trim();
      final tramos = TratamientoController.tramosDosis(tratamiento);
      final ultimo = tramos.isEmpty ? null : tramos.last.desde;
      final cambio = tratamiento.cambiosDosis.isEmpty || ultimo == null
          ? ''
          : ' (desde ${TratamientoController.fechaCorta(ultimo)})';
      final dosis = actual.isEmpty ? '' : 'Dosis actual: $actual$cambio';
      final texto = [desde, dosis].where((parte) => parte.isNotEmpty).join(' · ');
      return Text(texto, textScaler: _escala, style: estilo);
    }
    final dia = TratamientoController.diaDeTratamiento(tratamiento);
    final desde = tratamiento.fechaInicio == null ? '' : 'desde ${_fechaCorta(tratamiento.fechaInicio!)}';
    final cantidad = TratamientoController.contarDosisEnPeriodo(tratamiento);
    final dosis = cantidad == 1 ? '1 dosis dada' : '$cantidad dosis dadas';
    final partes = [
      if (tratamiento.indicaciones.trim().isNotEmpty) tratamiento.indicaciones.trim(),
      if (dia > 0) 'Día $dia',
      if (desde.isNotEmpty) desde,
      dosis,
    ];
    return Text(partes.join(' · '), textScaler: _escala, style: estilo);
  }

  Widget _accionesTratamiento(
    TratamientoModel tratamiento,
    String nombrePerro, {
    required bool hastaAviso,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 4),
      child: Row(
        children: [
          if (hastaAviso)
            OutlinedButton.icon(
              onPressed: () => _suspenderDesdeFicha(tratamiento, nombrePerro),
              icon: const Icon(Icons.stop_circle_outlined),
              label: Text('Suspender', textScaler: _escala),
            ),
          if (tratamiento.dePorVida)
            OutlinedButton.icon(
              onPressed: () => _cambiarDosisDesdeFicha(tratamiento),
              icon: const Icon(Icons.tune),
              label: Text('Cambiar dosis', textScaler: _escala),
            ),
          if (!hastaAviso)
            PopupMenuButton<String>(
              tooltip: 'Más acciones',
              onSelected: (valor) {
                if (valor == 'suspender') _suspenderDesdeFicha(tratamiento, nombrePerro);
              },
              itemBuilder: (ctx) => const [
                PopupMenuItem(value: 'suspender', child: Text('Suspender')),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _suspenderDesdeFicha(TratamientoModel tratamiento, String nombrePerro) async {
    final confirmacion = await mostrarHojaSuspender(
      context,
      tratamiento: tratamiento,
      nombrePerro: nombrePerro,
    );
    if (confirmacion == null || !mounted) return;
    final guardado = await _ejecutarGuardado(
      claveGuardadoSuspender,
      () => _tratamientoController.persistirTratamiento(widget.idDocumento, confirmacion.tratamiento),
    );
    if (guardado == ResultadoGuardado.error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo suspender el tratamiento')),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Se suspendió ${_capitalizar(tratamiento.medicacion)}'),
        action: SnackBarAction(
          label: 'Deshacer',
          textColor: AppColors.arena,
          onPressed: () async {
            try {
              await _tratamientoController.persistirTratamiento(widget.idDocumento, tratamiento);
            } catch (_) {}
          },
        ),
      ),
    );
  }

  Future<void> _cambiarDosisDesdeFicha(TratamientoModel tratamiento) async {
    final actualizado = await mostrarHojaCambioDosis(context, tratamiento: tratamiento);
    if (actualizado == null || !mounted) return;
    final guardado = await _ejecutarGuardado(
      claveGuardadoDosis,
      () => _tratamientoController.persistirTratamiento(widget.idDocumento, actualizado),
    );
    if (guardado == ResultadoGuardado.error && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar el cambio de dosis')),
      );
    }
  }

  Future<void> _reanudarDesdeFicha(TratamientoModel tratamiento) async {
    final base = _tratamientoController.reanudarComoNuevo(tratamiento);
    final creado = await mostrarDialogoEditarTratamiento(
      context,
      controller: _tratamientoController,
      actual: base,
      titulo: 'Reanudar tratamiento',
      preguntarCambioDosis: false,
    );
    if (creado == null || !mounted) return;
    final guardado = await _ejecutarGuardado(
      claveGuardadoReanudar,
      () => _tratamientoController.agregarTratamiento(
        widget.idDocumento,
        creado,
        anterior: TratamientoController.cerrarPeriodoLegacy(tratamiento),
      ),
    );
    if (guardado == ResultadoGuardado.error && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo reanudar el tratamiento')),
      );
    }
  }

  Future<void> _abrirDosisAnteriores(TratamientoModel tratamiento) async {
    final periodo = TratamientoController.periodoMarcable(tratamiento);
    if (periodo == null || !mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _HojaDosisPeriodo(
        tratamiento: tratamiento,
        inicio: periodo.inicio,
        fin: periodo.fin,
        alAlternar: (dia) => _toggleDosis(tratamiento, dia),
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
        return 'Último día de medicación. Mañana el tratamiento finaliza automáticamente.';
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
              'Mañana el tratamiento finaliza automáticamente.',
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

    final firma = TratamientoController.firmaArchivados(actualizados);
    if (_marcaArchivado.reservar(firma)) {
      final idDocumento = widget.idDocumento;
      final controller = _tratamientoController;
      final marca = _marcaArchivado;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        persistirArchivadoSiMontado(
          montado: () => mounted,
          escribir: () => controller.guardarTratamientos(idDocumento, actualizados),
          liberar: () => marca.pendiente = null,
        );
      });
    }

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
    final tratamientosActivos = TratamientoController.obtenerActivosDiarios(perro.tratamientos);
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
                    child: _buildTarjetaTratamiento(
                      tratamientosActivos[n],
                      fechaHoy,
                      esInvitado,
                      perro.nombre,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget? _buildSuspendidos(PerroModel perro, bool esInvitado) {
    final lista = perro.tratamientos.where((t) => t.categoria == 'diario' && !t.activo).toList();
    if (lista.isEmpty) return null;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(Icons.history, color: colorIconoSeccion(context)),
          title: Text(
            'Suspendidos y finalizados (${lista.length})',
            textScaler: _escala,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          children: [
            for (final tratamiento in lista)
              _filaSuspendido(tratamiento, esInvitado),
          ],
        ),
      ),
    );
  }

  Widget _filaSuspendido(TratamientoModel tratamiento, bool esInvitado) {
    final periodo = TratamientoController.periodoEfectivo(tratamiento);
    final inicio = periodo?.inicio ?? tratamiento.fechaInicio;
    final fin = periodo?.fin;
    final rango = inicio == null
        ? 'Sin fecha'
        : fin == null
            ? 'Desde ${_fechaCorta(inicio)}'
            : '${_fechaCorta(inicio)} – ${_fechaCorta(fin)}';
    final cuenta = tratamiento.cuentaDosis;
    final cantidad = TratamientoController.contarDosisEnPeriodo(tratamiento);
    final dosis = !cuenta
        ? ''
        : cantidad == 1
            ? ' · 1 dosis'
            : ' · $cantidad dosis';
    return ListTile(
      title: Text(_capitalizar(tratamiento.medicacion), textScaler: _escala),
      subtitle: Text(
        '${TratamientoController.etiquetaEstado(tratamiento)} · $rango$dosis',
        textScaler: _escala,
      ),
      trailing: esInvitado
          ? null
          : TextButton(
              onPressed: () => _reanudarDesdeFicha(tratamiento),
              child: const Text('Reanudar'),
            ),
    );
  }

  Widget _botonHistorial(List<TratamientoModel> tratamientos, bool esInvitado) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _mostrarHistorialCompleto(tratamientos, esInvitado),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
          child: Row(
            children: [
              Icon(Icons.calendar_month_outlined, size: 22, color: colorIconoSeccion(context)),
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
    final guardado = await _ejecutarGuardado(
      claveGuardadoPeso,
      () => _perroController.agregarPeso(widget.idDocumento, peso),
    );
    if (guardado == ResultadoGuardado.error && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar el peso')),
      );
    }
    if (mounted) setState(() => _guardandoPeso = false);
  }

  Widget? _seguimientosEnCurso(PerroModel perro) {
    final vigentes = SeguimientoController.vigentes(perro.seguimientos);
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
    final plazo = SeguimientoController.describirPlazo(seguimiento);
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
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: cerrando ? null : () => _cerrarSeguimiento(seguimiento),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Cerrar seguimiento'),
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
    final guardado = await _ejecutarGuardado(
      claveGuardadoSeguimiento,
      () => _perroController.cerrarSeguimiento(widget.idDocumento, seguimiento.id),
    );
    if (guardado == ResultadoGuardado.error && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo cerrar el seguimiento')),
      );
    }
    if (mounted) setState(() => _cerrandoSeguimiento.remove(seguimiento.id));
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

  void _mostrarHistorialCompleto(List<TratamientoModel> tratamientos, bool esInvitado) {
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
            esInvitado: esInvitado,
            alAlternar: (tratamiento, dia) => _toggleDosis(tratamiento, dia),
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
    final suspendidos = _buildSuspendidos(perro, esInvitado);
    final seguimiento = esInvitado ? null : _seguimientosEnCurso(perro);
    final recordatorios = esInvitado ? null : _proximosRecordatorios(perro);
    final asyncEstudios = ref.watch(estudiosProvider(widget.idDocumento));
    final cargandoEstudios = !esInvitado && asyncEstudios.isLoading && !asyncEstudios.hasValue;
    final entradasEstudios = esInvitado
        ? const <EntradaEstudio>[]
        : unirEstudios(asyncEstudios.asData?.value ?? const [], perro.galeriaEstudios);
    final estudios = _buildEstudios(entradasEstudios, esInvitado, cargandoEstudios);
    final bloquesMedicos = <Widget>[
      ?fichaMedica,
      ?peso,
      ?tratamientos,
      ?suspendidos,
      if (perro.tratamientos.isNotEmpty) _botonHistorial(perro.tratamientos, esInvitado),
      ?seguimiento,
      ?recordatorios,
      ?estudios,
    ];
    return Column(
      crossAxisAlignment: esWindows ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
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
                      ? (esWindows ? context.paleta.relleno : Colors.transparent)
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
                    avatar: Icon(Icons.pets, size: 18, color: colorIconoSeccion(context)),
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
        if (!esInvitado && entradasEstudios.isEmpty && !cargandoEstudios)
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

  Widget? _buildEstudios(List<EntradaEstudio> entradas, bool esInvitado, bool cargando) {
    final visible = seccionEstudiosVisible(esInvitado: esInvitado, cantidad: entradas.length) ||
        (!esInvitado && cargando && entradas.isEmpty);
    if (!visible) return null;
    return _tarjetaSeccion(
      titulo: 'Estudios y registros',
      icono: Icons.grid_view_rounded,
      children: [
        _aclaracionEstudios(),
        const SizedBox(height: 12),
        if (cargando && entradas.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final entrada in entradas) _miniaturaEstudio(entrada)],
          ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: _botonAgregarEstudio(),
        ),
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
                      'Radiografías, análisis u otros estudios. Los registros médicos del calendario se cargan en Editar ficha.',
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
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 168, minWidth: double.infinity),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                  const SizedBox(height: 2),
                  Text(
                    'Fotos del perro. Los estudios médicos van en Estudios y registros.',
                    textScaler: _escala,
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(color: context.paleta.textoSuave),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniaturaEstudio(EntradaEstudio entrada) {
    final texto = entrada.texto;
    final child = entrada.esLegacy ? _fotoLegacy(entrada.urlLegacy ?? '') : _fotoEstudio(entrada.estudio!.ruta);
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
                onTap: () => _abrirEstudio(entrada),
                child: child,
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
                    _moverEstudio(entrada);
                  case 'editar':
                    _editarEstudio(entrada);
                  case 'borrar':
                    _eliminarEstudio(entrada);
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

  Widget _fotoLegacy(String url) {
    if (url.isEmpty) return Icon(Icons.broken_image_outlined, color: context.paleta.textoSuave);
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Icon(Icons.broken_image_outlined, color: context.paleta.textoSuave),
    );
  }

  Widget _fotoEstudio(String ruta) {
    final async = ref.watch(estudioBytesProvider(ruta));
    if (async.hasError || (async.hasValue && async.value == null)) {
      return Icon(Icons.broken_image_outlined, color: context.paleta.textoSuave);
    }
    final bytes = async.asData?.value;
    if (bytes == null) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
    }
    return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
  }

  void _abrirEstudio(EntradaEstudio entrada) {
    if (entrada.esLegacy) {
      _abrirFotoPantallaCompleta(
        entrada.urlLegacy ?? '',
        descripcion: descripcionFotoVisible(entrada.texto, null),
      );
      return;
    }
    final ruta = entrada.estudio!.ruta;
    final bytes = ref.read(estudioBytesProvider(ruta)).asData?.value;
    _abrirFotoPantallaCompleta(
      '',
      descripcion: descripcionFotoVisible(entrada.texto, null),
      imagen: bytes == null ? null : MemoryImage(bytes),
      bytesIniciales: bytes,
      rutaEstudio: ruta,
      guardarRecorte: (archivo) async {
        final resultado = await _ejecutarGuardado(
          claveGuardadoEstudio,
          () => _estudioController.recortar(widget.idDocumento, entrada.estudio!, archivo),
        );
        if (resultado == ResultadoGuardado.error) throw StateError('estudio');
      },
    );
  }
  Widget _aclaracionEstudios() {
    return Text(
      'Acá se suben fotos de estudios (radiografías, análisis) para tenerlas en la ficha. Los registros médicos que aparecen en el calendario se cargan en Editar ficha.',
      textScaler: _escala,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.paleta.textoSuave),
    );
  }

  Widget _rotuloFotos() {
    final esInvitado = ref.read(sessionProvider).esInvitado;
    final detalle = esInvitado
        ? 'Fotos del perro.'
        : 'Fotos del perro. Los estudios médicos van en Estudios y registros.';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Galería', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(
            detalle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.paleta.textoSuave),
          ),
        ],
      ),
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
                            _moverGaleriaAEstudios(index, perro.fotoPerfil);
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

  Future<ResultadoGuardado> _ejecutarGuardado(String clave, Future<void> Function() accion) {
    return ref.read(guardadoProvider(clave).notifier).ejecutar(accion);
  }

}
