import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/perro_controller.dart';
import '../controllers/tratamiento_controller.dart';
import '../models/estado_duracion.dart';
import '../models/perro_model.dart';
import '../providers/auth_providers.dart';
import '../providers/firestore_providers.dart';
import '../providers/perros_providers.dart';
import '../theme/app_colors.dart';
import '../theme/entrada_escalonada.dart';
import '../utils/plataforma.dart';
import 'ficha_detalle_perro.dart';
import 'formulario_perro.dart';

export '../providers/perros_providers.dart' show ModoVista, OrdenListado, SeccionPerros, tieneTratamientoActivo;

/// Vista que sigue a [actual] al tocar el botón de la barra.
ModoVista vistaSiguiente(ModoVista actual) {
  return switch (actual) {
    ModoVista.grande => ModoVista.compacta,
    ModoVista.compacta => ModoVista.lista,
    ModoVista.lista => ModoVista.grande,
  };
}

String etiquetaVista(ModoVista modo) {
  return switch (modo) {
    ModoVista.grande => 'tarjetas grandes',
    ModoVista.compacta => 'tarjetas pequeñas',
    ModoVista.lista => 'lista',
  };
}

IconData iconoVista(ModoVista modo) {
  return switch (modo) {
    ModoVista.grande => Icons.grid_view_rounded,
    ModoVista.compacta => Icons.apps_rounded,
    ModoVista.lista => Icons.view_list_rounded,
  };
}

/// «En casa (4)» o «En casa · Hembra (2)». Null si no hay filtros.
String? resumenFiltros(List<String> etiquetas, int cantidad) {
  if (etiquetas.isEmpty) return null;
  return '${etiquetas.join(' · ')} ($cantidad)';
}

/// Del más joven al más viejo: primero los años, después los meses.
int compararEdadListado(PerroModel a, PerroModel b) => PerroController.compararPorEdad(a, b);

class PantallaPerros extends ConsumerStatefulWidget {
  final SeccionPerros seccion;
  final bool soloDatosIncompletos;

  const PantallaPerros({
    super.key,
    this.seccion = SeccionPerros.activos,
    this.soloDatosIncompletos = false,
  });

  @override
  ConsumerState<PantallaPerros> createState() => _PantallaPerrosState();
}

class _PantallaPerrosState extends ConsumerState<PantallaPerros> {
  final TextEditingController _busquedaController = TextEditingController();
  final FocusNode _focoBusqueda = FocusNode();

  PerroController get _perroController => ref.read(perroControllerProvider);

  FiltrosPerros get _filtros => ref.read(filtrosPerrosProvider(widget.seccion));

  void _filtrosNuevos(FiltrosPerros filtros) {
    ref.read(filtrosPerrosProvider(widget.seccion).notifier).reemplazar(filtros);
  }

  @override
  void initState() {
    super.initState();
    if (widget.soloDatosIncompletos) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final actual = _filtros;
        _filtrosNuevos(actual.copyWith(soloDatosIncompletos: true));
      });
    }
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    _focoBusqueda.dispose();
    super.dispose();
  }

  void _abrirNuevoIngreso() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const FormularioPerro()));
  }

  String _etiquetaAccesible(PerroModel perro) {
    final partes = <String>[perro.nombre.isNotEmpty ? perro.nombre : 'Sin nombre'];
    if (perro.sexo == 'hembra') {
      partes.add('hembra');
    } else if (perro.sexo == 'macho') {
      partes.add('macho');
    }
    if (!_sinEdadUtil(perro)) {
      final edad = _edadCorta(perro);
      if (edad.isNotEmpty) partes.add(edad.toLowerCase());
    }
    if (perro.estado == 'activo') {
      partes.add(perro.enCasa ? 'en casa' : 'en el refugio');
    }
    if (_tieneDosisPendiente(perro)) partes.add('dosis pendiente');
    if (_faltanDatosStaff(perro)) partes.add('faltan datos');
    return partes.join(', ');
  }

  void _cambiarModoVista(ModoVista modo) {
    unawaited(ref.read(filtrosPerrosProvider(widget.seccion).notifier).fijarModoVista(modo));
  }

  void _quitarFiltros() {
    ref.read(filtrosPerrosProvider(widget.seccion).notifier).quitarFiltros();
  }

  void _abrirFicha(String idDocumento) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FichaDetallePerro(idDocumento: idDocumento),
      ),
    );
  }

  Widget _fotoPerro(PerroModel perro) {
    final placeholder = Container(
      color: Theme.of(context).colorScheme.primary,
      child: Icon(
        Icons.pets,
        color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.4),
        size: 80,
      ),
    );
    if (perro.fotoPerfil != null && perro.fotoPerfil!.isNotEmpty) {
      return Image.network(
        perro.fotoPerfil!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      );
    }
    return placeholder;
  }

  String _detalleLista(PerroModel perro) {
    if (_sinEdadUtil(perro)) return '';
    final edad = PerroController.formatearEdadTexto(perro);
    if (edad.startsWith('Edad: ') || edad.startsWith('Edad estimada: ')) {
      return edad;
    }
    final sexo = perro.sexo == 'hembra' ? 'Hembra' : 'Macho';
    return '$sexo · $edad';
  }

  String _textoVacioSeccion() {
    switch (widget.seccion) {
      case SeccionPerros.difuntos:
        return 'No hay difuntos registrados.';
      case SeccionPerros.egresados:
        return 'No hay adoptados ni reencontrados registrados.';
      case SeccionPerros.activos:
        return 'No hay perritos registrados aún.';
    }
  }

  String? _lineaMotivo(PerroModel perro) {
    final motivo = PerroController.formatearMotivoEgreso(perro.motivoEgreso);
    if (motivo.isEmpty) return null;
    return 'Motivo: $motivo';
  }

  String? _lineaEgreso(PerroModel perro) {
    if (perro.fechaEgreso == null) return null;
    return 'Egreso: ${_perroController.formatearFecha(perro.fechaEgreso)}';
  }

  bool _faltanDatosStaff(PerroModel perro) {
    if (ref.read(sessionProvider).esInvitado) return false;
    return datosFaltantes(perro).isNotEmpty;
  }

  bool _tieneDosisPendiente(PerroModel perro) {
    if (perro.estado != 'activo') return false;
    final hoy = DateTime.now();
    final hoyFecha = DateTime(hoy.year, hoy.month, hoy.day);
    final iso =
        '${hoyFecha.year.toString().padLeft(4, '0')}-${hoyFecha.month.toString().padLeft(2, '0')}-${hoyFecha.day.toString().padLeft(2, '0')}';
    for (final tratamiento in perro.tratamientos) {
      if (tratamiento.categoria != 'diario' || !tratamiento.activo) continue;
      if (tratamiento.registroDosis.contains(iso)) continue;
      final fase = TratamientoController.calcularEstadoDuracion(tratamiento, hoy: hoyFecha).fase;
      if (fase == FaseTratamiento.enCurso ||
          fase == FaseTratamiento.ultimoDia ||
          fase == FaseTratamiento.indefinido) {
        return true;
      }
    }
    return false;
  }

  bool _sinEdadUtil(PerroModel perro) =>
      esWindows &&
      widget.seccion == SeccionPerros.difuntos &&
      !perro.edadIndeterminada &&
      perro.edad == 0 &&
      perro.meses == 0;

  String _edadCorta(PerroModel perro) {
    final texto = PerroController.formatearEdadTexto(perro);
    return texto
        .replaceFirst('Edad estimada: ', '')
        .replaceFirst('Edad: ', '');
  }

  String _edadCompacta(PerroModel perro) {
    if (perro.edadIndeterminada) return 'Ind.';
    if (PerroController.edadSinCargar(perro)) return 'Sin edad';
    if (PerroController.cuentaPorMeses(perro)) {
      if (perro.edad == 0) {
        return perro.meses == 1 ? '1 m' : '${perro.meses} m';
      }
      if (perro.meses <= 0) return perro.edad == 1 ? '1 a' : '${perro.edad} a';
      return '${perro.edad} a ${perro.meses} m';
    }
    final anios = PerroController.calcularEdadEstimada(perro);
    return anios == 1 ? '1 a' : '$anios a';
  }

  String _datoDistintivo(PerroModel perro) {
    if (esAndroid) {
      final simbolo = perro.sexo == 'hembra' ? '♀' : '♂';
      if (_sinEdadUtil(perro)) return simbolo;
      return '$simbolo · ${_edadCompacta(perro)}';
    }
    final sexo = perro.sexo == 'hembra' ? 'Hembra' : 'Macho';
    if (_sinEdadUtil(perro)) return sexo;
    return '$sexo · ${_edadCorta(perro)}';
  }

  Widget _grillaGrande(List<PerroModel> perros, int crossAxisCount) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 104),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.9,
      ),
      itemCount: perros.length,
      itemBuilder: (context, index) {
        final idDocumento = perros[index].id;
        final perro = perros[index];
        final estiloDato = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontSize: 14,
          height: 1.35,
          color: Colors.white.withValues(alpha: 0.88),
        );

        return EntradaEscalonada(
          indice: index,
          child: Semantics(
            button: true,
            label: _etiquetaAccesible(perro),
            child: ExcludeSemantics(
              child: GestureDetector(
              onTap: () => _abrirFicha(idDocumento),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(color: AppColors.sombra, blurRadius: 16, offset: Offset(0, 4)),
                  ],
                ),
                child: Card(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned.fill(child: _fotoPerro(perro)),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: const [0.0, 0.42, 0.7, 1.0],
                              colors: [
                                Colors.black.withValues(alpha: 0.12),
                                Colors.black.withValues(alpha: 0.2),
                                Colors.black.withValues(alpha: 0.72),
                                Colors.black.withValues(alpha: 0.94),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (_tieneDosisPendiente(perro) || _faltanDatosStaff(perro))
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Wrap(
                            spacing: 6,
                            children: [
                              if (_tieneDosisPendiente(perro)) const _InsigniaPendiente(),
                              if (_faltanDatosStaff(perro)) const _InsigniaFaltanDatos(),
                            ],
                          ),
                        ),
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12,
                        child: widget.seccion == SeccionPerros.egresados
                            ? _resumenEgreso(perro)
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    perro.nombre.isNotEmpty ? perro.nombre : 'Sin nombre',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                      fontSize: 26,
                                      color: Colors.white,
                                      shadows: [Shadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: 6)],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Fecha de ingreso: ${_perroController.formatearFecha(perro.fechaIngreso)}',
                                    style: estiloDato,
                                  ),
                                  Text(
                                    perro.sexo == 'hembra' ? 'Sexo: Hembra' : 'Sexo: Macho',
                                    style: estiloDato,
                                  ),
                                  if (!_sinEdadUtil(perro))
                                    Text(
                                      PerroController.formatearEdadTexto(perro),
                                      style: estiloDato,
                                    ),
                                  Text(
                                    PerroController.formatearCastracion(perro),
                                    style: estiloDato,
                                  ),
                                  if (widget.seccion == SeccionPerros.difuntos && perro.fechaFallecimiento != null)
                                    Text(
                                      'Fallecimiento: ${_perroController.formatearFecha(perro.fechaFallecimiento)}',
                                      style: estiloDato,
                                    ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ),
          ),
        );
      },
    );
  }

  Widget _resumenEgreso(PerroModel perro) {
    final nombre = perro.nombre.isNotEmpty ? perro.nombre : 'Sin nombre';
    final motivo = PerroController.formatearMotivoEgreso(perro.motivoEgreso);
    final chips = <String>[
      perro.sexo == 'hembra' ? 'Hembra' : 'Macho',
      _edadCorta(perro),
      if (motivo.isNotEmpty) motivo,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          nombre,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontSize: 26,
            color: Colors.white,
            shadows: [Shadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: 6)],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [for (final chip in chips) _chipSobreFoto(chip)],
        ),
        if (perro.fechaEgreso != null) ...[
          const SizedBox(height: 8),
          Text(
            'Egresó el ${_perroController.formatearFecha(perro.fechaEgreso)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }

  Widget _chipSobreFoto(String texto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
      ),
      child: Text(
        texto,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.white),
      ),
    );
  }

  Widget _grillaCompacta(List<PerroModel> perros, double ancho) {
    final columnas = ancho >= 900 ? 5 : ancho >= 600 ? 4 : 3;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 104),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columnas,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.72,
      ),
      itemCount: perros.length,
      itemBuilder: (context, index) {
        final idDocumento = perros[index].id;
        final perro = perros[index];
        final nombre = perro.nombre.isNotEmpty ? perro.nombre : 'Sin nombre';

        return EntradaEscalonada(
          indice: index,
          child: Semantics(
            button: true,
            label: _etiquetaAccesible(perro),
            child: ExcludeSemantics(
              child: GestureDetector(
              onTap: () => _abrirFicha(idDocumento),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(color: AppColors.sombra, blurRadius: 16, offset: Offset(0, 4)),
                  ],
                ),
                child: Card(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: context.paleta.borde),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned.fill(child: _fotoPerro(perro)),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: const [0.0, 0.42, 0.7, 1.0],
                              colors: [
                                Colors.black.withValues(alpha: 0.12),
                                Colors.black.withValues(alpha: 0.2),
                                Colors.black.withValues(alpha: 0.72),
                                Colors.black.withValues(alpha: 0.94),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (_tieneDosisPendiente(perro) || _faltanDatosStaff(perro))
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Wrap(
                            spacing: 4,
                            children: [
                              if (_tieneDosisPendiente(perro)) const _InsigniaPendiente(),
                              if (_faltanDatosStaff(perro)) const _InsigniaFaltanDatos(),
                            ],
                          ),
                        ),
                      Positioned(
                        left: 8,
                        right: perro.enCasa ? 26 : 8,
                        bottom: 8,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              nombre,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                              ),
                            ),
                            Text(
                              _datoDistintivo(perro),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.92),
                              ),
                            ),
                            if (widget.seccion == SeccionPerros.egresados && _lineaMotivo(perro) != null)
                              Text(
                                _lineaMotivo(perro)!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontSize: 11,
                                  color: Colors.white,
                                ),
                              ),
                            if (widget.seccion == SeccionPerros.egresados && _lineaEgreso(perro) != null)
                              Text(
                                _lineaEgreso(perro)!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontSize: 11,
                                  color: Colors.white,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (perro.enCasa)
                        const Positioned(
                          right: 6,
                          bottom: 6,
                          child: Icon(Icons.home_rounded, color: Colors.white, size: 16),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            ),
          ),
        );
      },
    );
  }

  Widget _vistaLista(List<PerroModel> perros) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ancho = constraints.maxWidth > 700 ? 700.0 : constraints.maxWidth;
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: ancho,
            height: constraints.maxHeight,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 104),
              itemCount: perros.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final idDocumento = perros[index].id;
                final perro = perros[index];
                final nombre = perro.nombre.isNotEmpty ? perro.nombre : 'Sin nombre';

                return EntradaEscalonada(
                  indice: index,
                  child: Semantics(
                    button: true,
                    label: _etiquetaAccesible(perro),
                    child: ExcludeSemantics(
                      child: Card(
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _abrirFicha(idDocumento),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              _miniaturaLista(perro),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      nombre,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 2),
                                    if (_detalleLista(perro).isNotEmpty)
                                      Text(
                                        _detalleLista(perro),
                                        style: Theme.of(context).textTheme.bodyMedium,
                                      ),
                                    if (widget.seccion == SeccionPerros.egresados && _lineaMotivo(perro) != null)
                                      Text(
                                        _lineaMotivo(perro)!,
                                        style: Theme.of(context).textTheme.bodyMedium,
                                      ),
                                    if (widget.seccion == SeccionPerros.egresados && _lineaEgreso(perro) != null)
                                      Text(
                                        _lineaEgreso(perro)!,
                                        style: Theme.of(context).textTheme.bodyMedium,
                                      ),
                                    if (_tieneDosisPendiente(perro) || _faltanDatosStaff(perro) || perro.enCasa) ...[
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: [
                                          if (_tieneDosisPendiente(perro)) const _InsigniaPendiente(clara: true),
                                          if (_faltanDatosStaff(perro)) const _InsigniaFaltanDatos(clara: true),
                                          if (perro.enCasa)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.terracota.withValues(alpha: 0.14),
                                                borderRadius: BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                'En casa',
                                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                  color: AppColors.terracota,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                        ],
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
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _miniaturaLista(PerroModel perro) {
    final placeholder = Container(
      width: 64,
      height: 64,
      color: AppColors.navy,
      child: Icon(Icons.pets, color: Colors.white.withValues(alpha: 0.4), size: 28),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 64,
        height: 64,
        child: perro.fotoPerfil != null && perro.fotoPerfil!.isNotEmpty
            ? Image.network(
                perro.fotoPerfil!,
                width: 64,
                height: 64,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => placeholder,
              )
            : placeholder,
      ),
    );
  }

  Widget _estadoVacio(String texto, {IconData icono = Icons.pets, Widget? accion}) {
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
                color: context.paleta.lienzo.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icono, size: 30, color: context.paleta.lienzo),
            ),
            const SizedBox(height: 12),
            Text(
              texto,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: context.paleta.lienzoSuave),
            ),
            if (accion != null) ...[
              const SizedBox(height: 16),
              accion,
            ],
          ],
        ),
      ),
    );
  }

  Widget _esqueleto() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: 6,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, _) => Container(
        height: 88,
        decoration: BoxDecoration(
          color: context.paleta.borde.withValues(alpha: context.temaOscuro ? 0.25 : 0.55),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  bool get _hayFiltrosExtra => _etiquetasFiltro(_filtros).isNotEmpty;

  List<(String, VoidCallback)> _chipsFiltro(FiltrosPerros filtros) {
    final chips = <(String, VoidCallback)>[];
    void agregar(String etiqueta, FiltrosPerros Function(FiltrosPerros) quitar) {
      chips.add((etiqueta, () => _filtrosNuevos(quitar(filtros))));
    }
    if (widget.seccion == SeccionPerros.egresados) {
      if (filtros.egreso != 'Todos') {
        agregar(filtros.egreso, (f) => f.copyWith(egreso: 'Todos'));
      }
    } else if (filtros.ubicacion != 'Todos') {
      agregar(filtros.ubicacion, (f) => f.copyWith(ubicacion: 'Todos'));
    }
    if (filtros.sexo != 'Todos') agregar(filtros.sexo, (f) => f.copyWith(sexo: 'Todos'));
    if (filtros.castrado != 'Todos') agregar(filtros.castrado, (f) => f.copyWith(castrado: 'Todos'));
    if (filtros.soloConTratamiento) {
      agregar('Con dosis pendiente hoy', (f) => f.copyWith(soloConTratamiento: false));
    }
    if (filtros.soloTratamientoActivo) {
      agregar('Con tratamiento activo', (f) => f.copyWith(soloTratamientoActivo: false));
    }
    if (filtros.soloDatosIncompletos) {
      agregar('Datos incompletos', (f) => f.copyWith(soloDatosIncompletos: false));
    }
    return chips;
  }

  List<String> _etiquetasFiltro(FiltrosPerros filtros) =>
      [for (final chip in _chipsFiltro(filtros)) chip.$1];

  Future<void> _abrirFiltros() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModal) {
            final filtros = _filtros;
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: PanelOrdenFiltros(
                  egresados: widget.seccion == SeccionPerros.egresados,
                  mostrarPendientes: widget.seccion == SeccionPerros.activos,
                  ubicacion: filtros.ubicacion,
                  motivo: filtros.egreso,
                  ordenEtiqueta: switch (filtros.orden) {
                    OrdenListado.reciente => 'Recientes',
                    OrdenListado.antiguo => 'Antiguos',
                    OrdenListado.nombre => 'Nombre',
                    OrdenListado.edad => 'Edad',
                  },
                  sexo: filtros.sexo,
                  castrado: filtros.castrado,
                  soloPendientes: filtros.soloConTratamiento,
                  soloActivos: filtros.soloTratamientoActivo,
                  soloDatosIncompletos: filtros.soloDatosIncompletos,
                  onUbicacion: (valor) {
                    _filtrosNuevos(filtros.copyWith(ubicacion: valor));
                    setModal(() {});
                  },
                  onMotivo: (valor) {
                    _filtrosNuevos(filtros.copyWith(egreso: valor));
                    setModal(() {});
                  },
                  onOrden: (valor) {
                    _filtrosNuevos(
                      filtros.copyWith(
                        orden: switch (valor) {
                          'Antiguos' => OrdenListado.antiguo,
                          'Nombre' => OrdenListado.nombre,
                          'Edad' => OrdenListado.edad,
                          _ => OrdenListado.reciente,
                        },
                      ),
                    );
                    setModal(() {});
                  },
                  onSexo: (valor) {
                    _filtrosNuevos(filtros.copyWith(sexo: valor));
                    setModal(() {});
                  },
                  onCastrado: (valor) {
                    _filtrosNuevos(filtros.copyWith(castrado: valor));
                    setModal(() {});
                  },
                  onPendientes: (valor) {
                    _filtrosNuevos(filtros.copyWith(soloConTratamiento: valor));
                    setModal(() {});
                  },
                  onActivos: (valor) {
                    _filtrosNuevos(filtros.copyWith(soloTratamientoActivo: valor));
                    setModal(() {});
                  },
                  onDatosIncompletos: (valor) {
                    _filtrosNuevos(filtros.copyWith(soloDatosIncompletos: valor));
                    setModal(() {});
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool esInvitado = ref.watch(sessionProvider).esInvitado;
    final filtros = ref.watch(filtrosPerrosProvider(widget.seccion));
    final asyncTodos = ref.watch(perrosProvider);
    final asyncFiltrados = ref.watch(perrosFiltradosProvider(widget.seccion));

    final puedeNuevo = !esInvitado &&
        !(esWindows &&
            (widget.seccion == SeccionPerros.difuntos || widget.seccion == SeccionPerros.egresados));
    final atajos = <ShortcutActivator, VoidCallback>{
      if (esWindows) const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
        _focoBusqueda.requestFocus();
      },
      if (esWindows && puedeNuevo) const SingleActivator(LogicalKeyboardKey.keyN, control: true): _abrirNuevoIngreso,
    };
    return CallbackShortcuts(
      bindings: atajos,
      child: Focus(
        autofocus: true,
        child: Scaffold(
          // --- SECCIÓN: AppBar (título y selector de vista) ---
          appBar: AppBar(
            title: Text(
              widget.seccion == SeccionPerros.difuntos
                  ? 'Difuntos'
                  : widget.seccion == SeccionPerros.egresados
                      ? 'Adoptados y reencontrados'
                      : 'Perritos del refugio',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.arena,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Orden y filtros',
                onPressed: _abrirFiltros,
                icon: Badge(
                  isLabelVisible: _hayFiltrosExtra || filtros.orden != OrdenListado.reciente,
                  smallSize: 8,
                  child: const Icon(Icons.tune_rounded),
                ),
              ),
              BotonVista(
                modo: filtros.modoVista,
                onChanged: _cambiarModoVista,
              ),
            ],
          ),
          body: Column(
            children: [
              // --- SECCIÓN: Barra de búsqueda por nombre ---
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _busquedaController,
                  focusNode: _focoBusqueda,
                  onChanged: (value) => _filtrosNuevos(_filtros.copyWith(texto: value)),
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre...',
                    prefixIcon: const Icon(Icons.search),
                    fillColor: context.paleta.superficie,
                    suffixIcon: filtros.texto.isNotEmpty
                        ? IconButton(
                            tooltip: 'Borrar búsqueda',
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _busquedaController.clear();
                              _filtrosNuevos(_filtros.copyWith(texto: ''));
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              // --- SECCIÓN: Listado de perros (filtrado, orden y grilla) ---
              Expanded(
                child: _cuerpoListado(esInvitado, filtros, asyncTodos, asyncFiltrados),
              ),
            ],
          ),
          // --- SECCIÓN: Botón flotante para dar de alta un nuevo perro ---
          floatingActionButton: puedeNuevo
              ? FloatingActionButton(
                  onPressed: _abrirNuevoIngreso,
                  tooltip: 'Nuevo ingreso',
                  child: const Icon(Icons.add),
                )
              : null,
        ),
      ),
    );
  }

  Widget _cuerpoListado(
    bool esInvitado,
    FiltrosPerros filtros,
    AsyncValue<List<PerroModel>> asyncTodos,
    AsyncValue<List<PerroModel>> asyncFiltrados,
  ) {
    if (asyncTodos.isLoading && !asyncTodos.hasValue) return _esqueleto();
    if (!asyncTodos.hasValue || asyncTodos.value!.isEmpty) {
      return _estadoVacio(
        _textoVacioSeccion(),
        accion: !esInvitado && widget.seccion == SeccionPerros.activos
            ? FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FormularioPerro()),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Agregar primer perrito'),
              )
            : null,
      );
    }

    final perros = asyncFiltrados.value ?? const <PerroModel>[];
    final vacio = perros.isEmpty
        ? _estadoVacio(
            filtros.texto.isNotEmpty ? 'No se encontraron resultados.' : _textoVacioSeccion(),
            icono: filtros.texto.isNotEmpty ? Icons.search_off : Icons.pets,
          )
        : null;
    if (vacio != null && _chipsFiltro(filtros).isEmpty) return vacio;

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 900
            ? 3
            : constraints.maxWidth >= 600
                ? 2
                : 1;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_chipsFiltro(filtros).isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final chip in _chipsFiltro(filtros))
                      InputChip(
                        label: Text(chip.$1),
                        onDeleted: chip.$2,
                        deleteIconColor: context.paleta.lienzo,
                      ),
                    Text(
                      '(${perros.length})',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: context.paleta.lienzo),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: _quitarFiltros,
                      child: const Text('Quitar todos'),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: vacio ??
                  switch (filtros.modoVista) {
                    ModoVista.grande => _grillaGrande(perros, crossAxisCount),
                    ModoVista.compacta => _grillaCompacta(perros, constraints.maxWidth),
                    ModoVista.lista => _vistaLista(perros),
                  },
            ),
          ],
        );
      },
    );
  }
}

/// Chips de un filtro. Con [envolver] bajan de renglón en vez de cortarse.
class FiltrosHorizontales extends StatelessWidget {
  final List<String> opciones;
  final String seleccionado;
  final ValueChanged<String> onChanged;
  final bool envolver;

  const FiltrosHorizontales({
    super.key,
    required this.opciones,
    required this.seleccionado,
    required this.onChanged,
    this.envolver = false,
  });

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      for (final opcion in opciones)
        ChoiceChip(
          label: Text(opcion),
          selected: seleccionado == opcion,
          onSelected: (_) => onChanged(opcion),
        ),
    ];
    if (envolver) {
      return Wrap(spacing: 8, runSpacing: 8, children: chips);
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < chips.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            chips[i],
          ],
        ],
      ),
    );
  }
}

/// Contenido de la hoja "Orden y filtros". La ubicación o el motivo van primero.
class PanelOrdenFiltros extends StatelessWidget {
  final bool egresados;
  final bool mostrarPendientes;
  final String ubicacion;
  final String motivo;
  final String ordenEtiqueta;
  final String sexo;
  final String castrado;
  final bool soloPendientes;
  final bool soloActivos;
  final bool soloDatosIncompletos;
  final ValueChanged<String> onUbicacion;
  final ValueChanged<String> onMotivo;
  final ValueChanged<String> onOrden;
  final ValueChanged<String> onSexo;
  final ValueChanged<String> onCastrado;
  final ValueChanged<bool> onPendientes;
  final ValueChanged<bool> onActivos;
  final ValueChanged<bool> onDatosIncompletos;

  const PanelOrdenFiltros({
    super.key,
    required this.egresados,
    required this.mostrarPendientes,
    required this.ubicacion,
    required this.motivo,
    required this.ordenEtiqueta,
    required this.sexo,
    required this.castrado,
    required this.soloPendientes,
    required this.soloActivos,
    this.soloDatosIncompletos = false,
    required this.onUbicacion,
    required this.onMotivo,
    required this.onOrden,
    required this.onSexo,
    required this.onCastrado,
    required this.onPendientes,
    required this.onActivos,
    required this.onDatosIncompletos,
  });

  @override
  Widget build(BuildContext context) {
    final titulo = Theme.of(context).textTheme.titleMedium;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Orden y filtros', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        Text(egresados ? 'Motivo' : 'Ubicación', style: titulo),
        const SizedBox(height: 8),
        FiltrosHorizontales(
          envolver: true,
          opciones: egresados
              ? const ['Todos', 'Adoptados', 'Reencontrados']
              : const ['Todos', 'Refugio', 'En casa'],
          seleccionado: egresados ? motivo : ubicacion,
          onChanged: egresados ? onMotivo : onUbicacion,
        ),
        const SizedBox(height: 16),
        Text('Orden', style: titulo),
        const SizedBox(height: 8),
        FiltrosHorizontales(
          envolver: true,
          opciones: const ['Recientes', 'Antiguos', 'Nombre', 'Edad'],
          seleccionado: ordenEtiqueta,
          onChanged: onOrden,
        ),
        const SizedBox(height: 16),
        Text('Sexo', style: titulo),
        const SizedBox(height: 8),
        FiltrosHorizontales(
          envolver: true,
          opciones: const ['Todos', 'Macho', 'Hembra'],
          seleccionado: sexo,
          onChanged: onSexo,
        ),
        const SizedBox(height: 16),
        Text('Castración', style: titulo),
        const SizedBox(height: 8),
        FiltrosHorizontales(
          envolver: true,
          opciones: const ['Todos', 'Castrados', 'Sin castrar'],
          seleccionado: castrado,
          onChanged: onCastrado,
        ),
        if (mostrarPendientes) ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Con dosis pendiente hoy'),
            value: soloPendientes,
            onChanged: onPendientes,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Con tratamiento activo'),
            value: soloActivos,
            onChanged: onActivos,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Datos incompletos'),
            value: soloDatosIncompletos,
            onChanged: onDatosIncompletos,
          ),
        ],
      ],
    );
  }
}

/// Un toque pasa a la vista siguiente: grandes, pequeñas, lista.
class BotonVista extends StatelessWidget {
  final ModoVista modo;
  final ValueChanged<ModoVista> onChanged;

  const BotonVista({super.key, required this.modo, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final etiqueta = 'Vista: ${etiquetaVista(modo)}. Tocá para cambiar';
    return Semantics(
      button: true,
      label: etiqueta,
      child: IconButton(
        tooltip: etiqueta,
        onPressed: () => onChanged(vistaSiguiente(modo)),
        icon: Icon(iconoVista(modo)),
      ),
    );
  }
}

class _InsigniaPendiente extends StatelessWidget {
  final bool clara;

  const _InsigniaPendiente({this.clara = false});

  @override
  Widget build(BuildContext context) {
    final fondo = clara ? AppColors.pausado.withValues(alpha: 0.18) : AppColors.pausado;
    final tinta = clara ? context.paleta.pausadoTexto : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Pendiente',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: tinta,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InsigniaFaltanDatos extends StatelessWidget {
  final bool clara;

  const _InsigniaFaltanDatos({this.clara = false});

  @override
  Widget build(BuildContext context) {
    final fondo = clara ? AppColors.terracota.withValues(alpha: 0.16) : AppColors.terracota;
    final tinta = clara ? AppColors.terracota : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Faltan datos',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: tinta,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
