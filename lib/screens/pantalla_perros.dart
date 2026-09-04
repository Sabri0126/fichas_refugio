import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../controllers/perro_controller.dart';
import '../models/perro_model.dart';
import '../services/notificaciones_service.dart';
import 'ficha_detalle_perro.dart';
import 'formulario_perro.dart';
import 'pantalla_login.dart';

class PantallaPerros extends StatefulWidget {
  final bool soloInactivos;

  const PantallaPerros({super.key, this.soloInactivos = false});

  @override
  State<PantallaPerros> createState() => _PantallaPerrosState();
}

class _PantallaPerrosState extends State<PantallaPerros> {
  final PerroController _perroController = PerroController();
  final TextEditingController _busquedaController = TextEditingController();
  String _textoBusqueda = '';
  String _filtroUbicacion = 'Todos';
  StreamSubscription<List<PerroModel>>? _suscripcionTratamientos;

  @override
  void initState() {
    super.initState();
    final bool esInvitado = FirebaseAuth.instance.currentUser == null;
    // Los visitantes no deben programar notificaciones locales.
    if (!esInvitado) {
      _suscripcionTratamientos = _perroController.observarPerros().listen((perros) {
        final perrosConId = perros.map((p) => {...p.toMap(), 'id': p.id}).toList();
        NotificacionesService.instance.programarRecordatorios(perrosConId);
      });
    }
  }

  @override
  void dispose() {
    _suscripcionTratamientos?.cancel();
    _busquedaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool esInvitado = FirebaseAuth.instance.currentUser == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.soloInactivos ? 'Difuntos' : 'Perritos del refugio',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              if (!esInvitado) {
                await FirebaseAuth.instance.signOut();
              }
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const PantallaLogin()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: TextField(
              controller: _busquedaController,
              onChanged: (value) => setState(() => _textoBusqueda = value),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.8),
                suffixIcon: _textoBusqueda.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _busquedaController.clear();
                          setState(() => _textoBusqueda = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
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
          Expanded(
            child: StreamBuilder<List<PerroModel>>(
        stream: _perroController.observarPerros(),
        builder: (context, AsyncSnapshot<List<PerroModel>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text(widget.soloInactivos ? 'No hay difuntos registrados.' : 'No hay perritos registrados aún.'));
          }

          final perrosPorEstado = snapshot.data!.where((perro) {
            if (widget.soloInactivos) {
              return perro.estado == 'inactivo';
            } else {
              return perro.estado == 'activo';
            }
          }).toList();

          final totalEnCasa = perrosPorEstado.where((p) => p.enCasa).length;
          final totalRefugio = perrosPorEstado.length - totalEnCasa;

          final perros = perrosPorEstado.where((perro) {
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
            final dtA = a.fechaIngreso;
            final dtB = b.fechaIngreso;
            if (dtA == null && dtB == null) return 0;
            if (dtA == null) return 1;
            if (dtB == null) return -1;
            return dtB.compareTo(dtA);
          });

          if (perros.isEmpty) {
            return Center(child: Text(_textoBusqueda.isNotEmpty ? 'No se encontraron resultados.' : widget.soloInactivos ? 'No hay difuntos registrados.' : 'No hay perritos registrados aún.'));
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
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      'Perritos del refugio ($totalRefugio) | En casa ($totalEnCasa)',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
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

                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FichaDetallePerro(idDocumento: idDocumento),
                              ),
                            );
                          },
                          child: Card(
                            clipBehavior: Clip.antiAlias,
                            elevation: 6,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Positioned.fill(
                                  child: perro.fotoPerfil != null && perro.fotoPerfil!.isNotEmpty
                                      ? Image.network(
                                          perro.fotoPerfil!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => Container(
                                            color: Theme.of(context).colorScheme.primary,
                                            child: Icon(
                                              Icons.pets,
                                              color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.4),
                                              size: 80,
                                            ),
                                          ),
                                        )
                                      : Container(
                                          color: Theme.of(context).colorScheme.primary,
                                          child: Icon(
                                            Icons.pets,
                                            color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.4),
                                            size: 80,
                                          ),
                                        ),
                                ),
                                Positioned.fill(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Colors.black.withValues(alpha: 0.8),
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
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 26,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Fecha de ingreso: ${_perroController.formatearFecha(perro.fechaIngreso)}',
                                        style: const TextStyle(fontSize: 15, color: Colors.white70),
                                      ),
                                      Text(
                                        perro.sexo == 'hembra' ? 'Sexo: Hembra' : 'Sexo: Macho',
                                        style: const TextStyle(fontSize: 15, color: Colors.white70),
                                      ),
                                      Text(
                                        _perroController.formatearEdadTexto(perro),
                                        style: const TextStyle(fontSize: 15, color: Colors.white70),
                                      ),
                                      Text(
                                        perro.castrado ? 'Castrado: Sí' : 'Castrado: No',
                                        style: const TextStyle(fontSize: 15, color: Colors.white70),
                                      ),
                                      if (widget.soloInactivos && perro.fechaFallecimiento != null)
                                        Text(
                                          'Fallecimiento: ${_perroController.formatearFecha(perro.fechaFallecimiento)}',
                                          style: const TextStyle(fontSize: 15, color: Colors.white70),
                                        ),
                                    ],
                                  ),
                                ),
                                if (!esInvitado)
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.white),
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.black54,
                                      ),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => FormularioPerro(idDocumento: idDocumento, datosActuales: perro.toMap()),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
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
      floatingActionButton: esInvitado
          ? null
          : FloatingActionButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FormularioPerro())),
              backgroundColor: Theme.of(context).colorScheme.secondary,
              foregroundColor: Theme.of(context).colorScheme.onSecondary,
              child: const Icon(Icons.add),
            ),
    );
  }
}
