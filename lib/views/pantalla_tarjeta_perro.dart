import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../controllers/perro_controller.dart';
import '../models/perro_model.dart';
import '../services/exportar_ficha.dart';
import '../theme/app_colors.dart';

/// Vista previa de la tarjeta 4:5 y botón para compartirla como PNG.
class PantallaTarjetaPerro extends StatefulWidget {
  final PerroModel perro;

  const PantallaTarjetaPerro({super.key, required this.perro});

  @override
  State<PantallaTarjetaPerro> createState() => _PantallaTarjetaPerroState();
}

class _PantallaTarjetaPerroState extends State<PantallaTarjetaPerro> {
  final GlobalKey _clave = GlobalKey();
  bool _inicioPrecarga = false;
  bool _lista = false;
  bool _compartiendo = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inicioPrecarga) return;
    _inicioPrecarga = true;
    _precache();
  }

  Future<void> _precache() async {
    final perfil = widget.perro.fotoPerfil;
    final urls = <String>[
      if (perfil != null && perfil.isNotEmpty) perfil,
      ...TarjetaPerro.urlsMiniaturas(widget.perro).take(3),
    ];
    for (final url in urls) {
      if (!mounted) return;
      try {
        await precacheImage(NetworkImage(url), context).timeout(const Duration(seconds: 8));
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() => _lista = true);
  }

  Future<void> _compartir() async {
    final boundary = _clave.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    setState(() => _compartiendo = true);
    try {
      final imagen = await boundary.toImage(pixelRatio: 1080 / TarjetaPerro.ancho);
      final datos = await imagen.toByteData(format: ui.ImageByteFormat.png);
      if (datos == null) throw StateError('sin bytes');
      final nombre = widget.perro.nombre.trim().isEmpty ? 'Sin nombre' : widget.perro.nombre.trim();
      final seguro = nombre.replaceAll(RegExp(r'[^\w\-]+'), '_');
      final dir = await getTemporaryDirectory();
      final archivo = File('${dir.path}/tarjeta_$seguro.png');
      await archivo.writeAsBytes(datos.buffer.asUint8List(datos.offsetInBytes, datos.lengthInBytes));
      await Share.shareXFiles(
        [XFile(archivo.path, mimeType: 'image/png')],
        subject: 'Ficha de $nombre',
        text: ExportarFicha.textoCompartir(
          widget.perro,
          edad: PerroController.formatearEdadTexto(widget.perro),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo compartir la imagen')),
      );
    } finally {
      if (mounted) setState(() => _compartiendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final habilitado = _lista && !_compartiendo;
    return Scaffold(
      appBar: AppBar(title: const Text('Compartir como imagen')),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: FittedBox(
                  child: RepaintBoundary(
                    key: _clave,
                    child: TarjetaPerro(perro: widget.perro),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: habilitado ? _compartir : null,
                  child: Text(_lista ? 'Compartir imagen' : 'Preparando imagen…'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta vertical 4:5 con la foto, los datos clave y un recorte de la historia.
class TarjetaPerro extends StatelessWidget {
  static const ancho = 360.0;
  static const alto = 450.0;
  static const citaKey = Key('citaHistoria');

  final PerroModel perro;

  const TarjetaPerro({super.key, required this.perro});

  /// Edad como en la ficha: «1 año aprox.» cuando la edad es estimada.
  static String edadVisible(PerroModel perro) {
    final texto = PerroController.formatearEdadTexto(perro);
    final partes = texto.split(':');
    final valor = partes.length > 1 ? partes.sublist(1).join(':').trim() : texto;
    if (texto.startsWith('Edad estimada')) return '$valor aprox.';
    return valor;
  }

  /// Recorte de la historia, sin viñetas ni énfasis de Markdown.
  static String? fragmentoHistoria(String historia) {
    final lineas = historia.split(RegExp(r'\r?\n')).map((linea) {
      var texto = linea.trim().replaceFirst(RegExp(r'^(?:\d+[.)]|[-*•])\s+'), '');
      texto = texto.replaceAll('**', '').replaceAll('__', '').replaceAll('_', '');
      return texto.trim();
    }).where((linea) => linea.isNotEmpty);
    final limpio = lineas.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (limpio.isEmpty) return null;
    const limite = 140;
    if (limpio.length <= limite) return limpio;
    final corte = limpio.lastIndexOf(' ', limite);
    final hasta = corte >= 80 ? corte : limite;
    return '${limpio.substring(0, hasta).trimRight()}…';
  }

  static List<String> urlsMiniaturas(PerroModel perro) {
    return perro.galeria
        .map((foto) => foto['url']?.toString() ?? '')
        .where((url) => url.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final nombre = perro.nombre.trim().isEmpty ? 'Sin nombre' : perro.nombre.trim();
    final hembra = perro.sexo == 'hembra';
    final historia = fragmentoHistoria(perro.historia);
    final fotos = urlsMiniaturas(perro);
    final visibles = fotos.take(3).toList();
    final resto = fotos.length > 3 ? '+${fotos.length - 2}' : null;

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: SizedBox(
        width: ancho,
        height: alto,
        child: ColoredBox(
          color: AppColors.arena,
          child: Stack(
            children: [
              const Positioned(
                right: -20,
                bottom: 8,
                child: Icon(Icons.pets, size: 150, color: Color(0x0F2F4565)),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _franja(),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: SizedBox(width: double.infinity, child: _fotoConNombre(nombre)),
                          ),
                          const SizedBox(height: 22),
                          Wrap(
                            spacing: 5,
                            runSpacing: 6,
                            children: [
                              _chip(hembra ? Icons.female : Icons.male, hembra ? 'Hembra' : 'Macho'),
                              _chip(null, edadVisible(perro)),
                              _chip(null, PerroController.formatearCastracion(perro)),
                              _chip(null, perro.enCasa ? 'En casa' : 'En el refugio'),
                            ],
                          ),
                          if (historia != null) ...[
                            const SizedBox(height: 10),
                            _cita(historia),
                          ],
                          if (visibles.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                for (var i = 0; i < visibles.length; i++) ...[
                                  if (i > 0) const SizedBox(width: 8),
                                  _miniatura(
                                    visibles[i],
                                    resto: i == 2 ? resto : null,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6, child: ColoredBox(color: AppColors.terracota)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _franja() {
    return Container(
      height: 44,
      color: AppColors.navy,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Refugio Milagros de Amor',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: AppColors.arena,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Ficha de perfil canino',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 10,
              color: AppColors.arena.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fotoConNombre(String nombre) {
    final url = perro.fotoPerfil;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: _foto(url, 72),
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Text(
                  nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w800,
                    fontSize: 28,
                    height: 1.05,
                    color: AppColors.navy,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _foto(String? url, double icono) {
    if (url == null || url.isEmpty) return _placeholder(icono);
    return Image.network(
      url,
      fit: BoxFit.cover,
      alignment: const Alignment(0, -0.3),
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, _, _) => _placeholder(icono),
    );
  }

  Widget _placeholder(double icono) {
    return ColoredBox(
      color: AppColors.navy,
      child: Center(child: Icon(Icons.pets, size: icono, color: AppColors.arena)),
    );
  }

  Widget _chip(IconData? icono, String texto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.bordeTarjeta),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[
            Icon(icono, size: 13, color: AppColors.navy),
            const SizedBox(width: 4),
          ],
          Text(
            texto,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w600,
              fontSize: 11,
              color: AppColors.texto,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cita(String historia) {
    return IntrinsicHeight(
      key: citaKey,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(width: 3, child: ColoredBox(color: AppColors.terracota)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              historia,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12,
                height: 1.35,
                color: AppColors.texto,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniatura(String url, {String? resto}) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _foto(url, 22),
            if (resto != null)
              ColoredBox(
                color: AppColors.navy.withValues(alpha: 0.6),
                child: Center(
                  child: Text(
                    resto,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
