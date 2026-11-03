import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_cropper/image_cropper.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../controllers/estudio_controller.dart';
import '../controllers/perro_controller.dart';
import '../controllers/peso_controller.dart';
import '../controllers/recordatorio_controller.dart';
import '../controllers/seguimiento_controller.dart';
import '../controllers/tratamiento_controller.dart';
import '../models/estudio_model.dart';
import '../models/dosis_avisada.dart';
import '../models/egreso_model.dart';
import '../models/estado_duracion.dart';
import '../models/perro_model.dart';
import '../models/peso_model.dart';
import '../models/recordatorio_model.dart';
import '../models/seguimiento_model.dart';
import '../models/tratamiento_model.dart';
import '../providers/auth_providers.dart';
import '../providers/calendario_providers.dart';
import '../providers/escala_ficha_provider.dart';
import '../providers/estudios_providers.dart';
import '../providers/firestore_providers.dart';
import '../providers/guardado_provider.dart';
import '../providers/perros_providers.dart';
import '../services/exportar_ficha.dart';
import '../services/fotos_service.dart';
import '../theme/app_colors.dart';
import '../theme/encabezado_seccion.dart';
import '../utils/plataforma.dart';
import '../theme/category_colors.dart';
import '../theme/entrada_escalonada.dart';
import '../theme/recordatorio_tipos.dart';
import '../theme/seguimiento_tipos.dart';
import '../widgets/grafico_peso.dart';
import '../widgets/indice_secciones.dart';
import 'alta_calendario.dart';
import 'dialogo_peso.dart';
import 'dialogo_tratamiento.dart';
import 'formulario_perro.dart';
import 'hojas_tratamiento.dart';
import 'pantalla_tarjeta_perro.dart';

part 'ficha_detalle/visor_foto.dart';
part 'ficha_detalle/ficha_estado.dart';
part 'ficha_detalle/ficha_secciones.dart';
part 'ficha_detalle/borde_punteado.dart';
part 'ficha_detalle/locale_calendario.dart';
part 'ficha_detalle/hoja_dosis.dart';
part 'ficha_detalle/calendario_historial.dart';
part 'ficha_detalle/dialogo_egreso.dart';
part 'ficha_detalle/opcion_menu.dart';

/// Texto que se lee al abrir la foto. Vacío y «Sin descripción» no se muestran.
String? descripcionFotoVisible(String? texto, [String? alternativa]) {
  for (final candidato in [texto, alternativa]) {
    final limpio = candidato?.trim() ?? '';
    if (limpio.isNotEmpty && limpio != 'Sin descripción') return limpio;
  }
  return null;
}

class FichaDetallePerro extends ConsumerStatefulWidget {
  final String idDocumento;
  final DosisAvisada? dosisAvisada;

  const FichaDetallePerro({super.key, required this.idDocumento, this.dosisAvisada});

  @override
  ConsumerState<FichaDetallePerro> createState() => _FichaDetallePerroState();
}

class _FichaDetallePerroState extends ConsumerState<FichaDetallePerro> with _FichaEstado, _FichaSecciones {
  @override
  Widget build(BuildContext context) {
    for (final clave in clavesGuardadoFicha) {
      ref.watch(guardadoProvider(clave));
    }
    final bool esInvitado = ref.watch(sessionProvider).esInvitado;
    final preferenciaEscala = ref.watch(escalaFichaProvider);
    final lectura = ref.watch(perroProvider(widget.idDocumento)).asData?.value;
    if (lectura == null || lectura.perro == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // --- SECCIÓN: Datos del perro y auto-archivado de tratamientos vencidos ---
    final perro = _procesarAutoArchivado(lectura.perro!);
        final galeria = perro.galeria;
        _programarAviso(perro, desdeCache: lectura.desdeCache);

        return Scaffold(
          // --- SECCIÓN: AppBar (título y acciones de galería/accesibilidad) ---
          appBar: AppBar(
            title: Text('Ficha de ${perro.nombre}', overflow: TextOverflow.ellipsis),
            actions: [
              if (_subiendoFoto || _generandoPdf)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                      if (_generandoPdf) ...[
                        const SizedBox(width: 8),
                        Text(
                          'Generando PDF…',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              else ...[
                if (!esInvitado) ...[
                  if (_modoReordenar) ...[
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Cancelar',
                      onPressed: _cancelarReordenar,
                    ),
                    IconButton(
                      icon: const Icon(Icons.check),
                      tooltip: 'Guardar orden de fotos',
                      onPressed: _confirmarOrdenFotos,
                    ),
                  ] else
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
                    final escala = ref.read(escalaFichaProvider.notifier);
                    switch (accion) {
                      case 'achicar':
                        await escala.achicar();
                      case 'agrandar':
                        await escala.agrandar();
                      case 'normal':
                        await escala.normal();
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
                      enabled: preferenciaEscala > escalaFichaMin,
                      child: const _OpcionMenu(icono: Icons.zoom_out, texto: 'Achicar texto'),
                    ),
                    PopupMenuItem<String>(
                      value: 'agrandar',
                      enabled: preferenciaEscala < escalaFichaMax,
                      child: const _OpcionMenu(icono: Icons.zoom_in, texto: 'Agrandar texto'),
                    ),
                    PopupMenuItem<String>(
                      value: 'normal',
                      enabled: preferenciaEscala != escalaFichaMin,
                      child: const _OpcionMenu(icono: Icons.text_fields, texto: 'Tamaño normal'),
                    ),
                    PopupMenuItem<String>(
                      value: 'compartir',
                      enabled: !_generandoPdf,
                      child: const _OpcionMenu(icono: Icons.picture_as_pdf_outlined, texto: 'Compartir ficha (PDF)'),
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
            bottom: esInvitado
                ? const PreferredSize(
                    preferredSize: Size.fromHeight(28),
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Text(
                        'Modo visitante · solo lectura',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  )
                : null,
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 700;
                final mostrarCaja = galeria.isNotEmpty || _modoReordenar;
                final panelScroll = SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
                  child: _buildInfoContenido(perro, esInvitado),
                );
                final panelInfo = Center(
                  child: Container(
                    margin: const EdgeInsets.all(20),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 450),
                      child: panelScroll,
                    ),
                  ),
                );
                final zonaFotos = mostrarCaja
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
                      );

                if (isWide) {
                  if (!mostrarCaja && esInvitado) return panelInfo;
                  if (esWindows) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: panelScroll,
                          ),
                        ),
                        Expanded(flex: 3, child: zonaFotos),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      panelInfo,
                      Expanded(flex: 2, child: zonaFotos),
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
}
