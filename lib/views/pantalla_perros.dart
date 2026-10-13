import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../controllers/perro_controller.dart';
import '../models/perro_model.dart';
import '../theme/app_colors.dart';
import '../theme/entrada_escalonada.dart';
import 'ficha_detalle_perro.dart';
import 'formulario_perro.dart';

enum ModoVista { grande, compacta, lista }

enum SeccionPerros { activos, difuntos, egresados }

class PantallaPerros extends StatefulWidget {
  final SeccionPerros seccion;

  const PantallaPerros({super.key, this.seccion = SeccionPerros.activos});

  @override
  State<PantallaPerros> createState() => _PantallaPerrosState();
}

class _PantallaPerrosState extends State<PantallaPerros> {
  final PerroController _perroController = PerroController();
  final TextEditingController _busquedaController = TextEditingController();
  String _textoBusqueda = '';
  String _filtroUbicacion = 'Todos';
  String _filtroEgreso = 'Todos';
  ModoVista _modoVista = ModoVista.grande;
  late final Stream<List<PerroModel>> _streamPerros = _perroController.observarPerros();

  @override
  void initState() {
    super.initState();
    unawaited(_cargarModoVista());
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  Future<void> _cargarModoVista() async {
    final prefs = await SharedPreferences.getInstance();
    final valor = prefs.getString('vista_listado_perros');
    final ModoVista modo = switch (valor) {
      'compacta' => ModoVista.compacta,
      'lista' => ModoVista.lista,
      _ => ModoVista.grande,
    };
    if (!mounted || modo == _modoVista) return;
    setState(() => _modoVista = modo);
  }

  Future<void> _guardarModoVista(ModoVista modo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('vista_listado_perros', modo.name);
  }

  void _cambiarModoVista(ModoVista modo) {
    setState(() => _modoVista = modo);
    unawaited(_guardarModoVista(modo));
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
    final edad = _perroController.formatearEdadTexto(perro);
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
    final motivo = _perroController.formatearMotivoEgreso(perro.motivoEgreso);
    if (motivo.isEmpty) return null;
    return 'Motivo: $motivo';
  }

  String? _lineaEgreso(PerroModel perro) {
    if (perro.fechaEgreso == null) return null;
    return 'Egreso: ${_perroController.formatearFecha(perro.fechaEgreso)}';
  }

  int _compararFechaDesc(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return b.compareTo(a);
  }

  IconData get _iconoModoVista {
    switch (_modoVista) {
      case ModoVista.grande:
        return Icons.grid_view_rounded;
      case ModoVista.compacta:
        return Icons.apps_rounded;
      case ModoVista.lista:
        return Icons.view_list_rounded;
    }
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
            label: perro.nombre.isNotEmpty ? perro.nombre : 'Sin nombre',
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
                              stops: const [0.0, 0.35, 0.65, 1.0],
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.10),
                                Colors.black.withValues(alpha: 0.60),
                                Colors.black.withValues(alpha: 0.90),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12,
                        child: Column(
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
                            Text(
                              _perroController.formatearEdadTexto(perro),
                              style: estiloDato,
                            ),
                            Text(
                              perro.castrado ? 'Castrado: Sí' : 'Castrado: No',
                              style: estiloDato,
                            ),
                            if (widget.seccion == SeccionPerros.difuntos && perro.fechaFallecimiento != null)
                              Text(
                                'Fallecimiento: ${_perroController.formatearFecha(perro.fechaFallecimiento)}',
                                style: estiloDato,
                              ),
                            if (widget.seccion == SeccionPerros.egresados && _lineaMotivo(perro) != null)
                              Text(_lineaMotivo(perro)!, style: estiloDato),
                            if (widget.seccion == SeccionPerros.egresados && _lineaEgreso(perro) != null)
                              Text(_lineaEgreso(perro)!, style: estiloDato),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
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
        childAspectRatio: 0.8,
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
            label: nombre,
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
                    side: const BorderSide(color: AppColors.bordeTarjeta),
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
                              stops: const [0.0, 0.35, 0.65, 1.0],
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.10),
                                Colors.black.withValues(alpha: 0.60),
                                Colors.black.withValues(alpha: 0.90),
                              ],
                            ),
                          ),
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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
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
                    label: nombre,
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
                                    if (perro.enCasa) ...[
                                      const SizedBox(height: 6),
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
                                  ],
                                ),
                              ),
                            ],
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

  Widget _estadoVacio(String texto, {IconData icono = Icons.pets}) {
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
              child: Icon(icono, size: 30, color: AppColors.navy),
            ),
            const SizedBox(height: 12),
            Text(
              texto,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textoSecundario),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool esInvitado = FirebaseAuth.instance.currentUser == null;

    return Scaffold(
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
          PopupMenuButton<ModoVista>(
            tooltip: 'Cambiar vista',
            initialValue: _modoVista,
            onSelected: _cambiarModoVista,
            icon: Icon(_iconoModoVista),
            itemBuilder: (context) => [
              CheckedPopupMenuItem(
                value: ModoVista.grande,
                checked: _modoVista == ModoVista.grande,
                child: const Text('Tarjetas grandes'),
              ),
              CheckedPopupMenuItem(
                value: ModoVista.compacta,
                checked: _modoVista == ModoVista.compacta,
                child: const Text('Tarjetas pequeñas'),
              ),
              CheckedPopupMenuItem(
                value: ModoVista.lista,
                checked: _modoVista == ModoVista.lista,
                child: const Text('Lista'),
              ),
            ],
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
              onChanged: (value) => setState(() => _textoBusqueda = value),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre...',
                prefixIcon: const Icon(Icons.search),
                fillColor: AppColors.superficie,
                suffixIcon: _textoBusqueda.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _busquedaController.clear();
                          setState(() => _textoBusqueda = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: widget.seccion == SeccionPerros.egresados
                ? Wrap(
                    alignment: WrapAlignment.start,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Todos'),
                        selected: _filtroEgreso == 'Todos',
                        onSelected: (_) => setState(() => _filtroEgreso = 'Todos'),
                      ),
                      ChoiceChip(
                        label: const Text('Adoptados'),
                        selected: _filtroEgreso == 'Adoptados',
                        onSelected: (_) => setState(() => _filtroEgreso = 'Adoptados'),
                      ),
                      ChoiceChip(
                        label: const Text('Reencontrados'),
                        selected: _filtroEgreso == 'Reencontrados',
                        onSelected: (_) => setState(() => _filtroEgreso = 'Reencontrados'),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Todos'),
                        selected: _filtroUbicacion == 'Todos',
                        onSelected: (_) => setState(() => _filtroUbicacion = 'Todos'),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Refugio'),
                        selected: _filtroUbicacion == 'Refugio',
                        onSelected: (_) => setState(() => _filtroUbicacion = 'Refugio'),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('En casa'),
                        selected: _filtroUbicacion == 'En casa',
                        onSelected: (_) => setState(() => _filtroUbicacion = 'En casa'),
                      ),
                    ],
                  ),
          ),
          // --- SECCIÓN: Listado de perros (filtrado, orden y grilla) ---
          Expanded(
            child: StreamBuilder<List<PerroModel>>(
        stream: _streamPerros,
        builder: (context, AsyncSnapshot<List<PerroModel>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _estadoVacio(_textoVacioSeccion());
          }

          final perrosPorEstado = snapshot.data!.where((perro) {
            switch (widget.seccion) {
              case SeccionPerros.difuntos:
                return perro.estado == 'inactivo';
              case SeccionPerros.egresados:
                return perro.estado == 'egresado';
              case SeccionPerros.activos:
                return perro.estado == 'activo';
            }
          }).toList();

          final totalEnCasa = perrosPorEstado.where((p) => p.enCasa).length;
          final totalRefugio = perrosPorEstado.length - totalEnCasa;
          final totalAdoptados = perrosPorEstado.where((p) => p.motivoEgreso == 'adopcion').length;
          final totalFamilia = perrosPorEstado.where((p) => p.motivoEgreso == 'familia').length;

          final perros = perrosPorEstado.where((perro) {
            if (widget.seccion == SeccionPerros.egresados) {
              if (_filtroEgreso == 'Adoptados') return perro.motivoEgreso == 'adopcion';
              if (_filtroEgreso == 'Reencontrados') return perro.motivoEgreso == 'familia';
              return true;
            }
            if (_filtroUbicacion == 'En casa') {
              return perro.enCasa;
            }
            if (_filtroUbicacion == 'Refugio') {
              return !perro.enCasa;
            }
            return true;
          }).where((perro) {
            if (_textoBusqueda.isEmpty) return true;
            return perro.nombre.toLowerCase().contains(_textoBusqueda.toLowerCase());
          }).toList();

          perros.sort((a, b) {
            if (widget.seccion == SeccionPerros.egresados) {
              final porEgreso = _compararFechaDesc(a.fechaEgreso, b.fechaEgreso);
              if (porEgreso != 0) return porEgreso;
            }
            return _compararFechaDesc(a.fechaIngreso, b.fechaIngreso);
          });

          if (perros.isEmpty) {
            return _estadoVacio(
              _textoBusqueda.isNotEmpty ? 'No se encontraron resultados.' : _textoVacioSeccion(),
              icono: _textoBusqueda.isNotEmpty ? Icons.search_off : Icons.pets,
            );
          }

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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Text(
                      widget.seccion == SeccionPerros.egresados
                          ? 'Adoptados ($totalAdoptados) | Reencontrados ($totalFamilia)'
                          : 'Perritos del refugio ($totalRefugio) | En casa ($totalEnCasa)',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.navy),
                    ),
                  ),
                  Expanded(
                    child: switch (_modoVista) {
                      ModoVista.grande => _grillaGrande(perros, crossAxisCount),
                      ModoVista.compacta => _grillaCompacta(perros, constraints.maxWidth),
                      ModoVista.lista => _vistaLista(perros),
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
        ),
        ],
      ),
      // --- SECCIÓN: Botón flotante para dar de alta un nuevo perro ---
      floatingActionButton: esInvitado
          ? null
          : FloatingActionButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FormularioPerro())),
              tooltip: 'Nuevo ingreso',
              child: const Icon(Icons.add),
            ),
    );
  }
}
