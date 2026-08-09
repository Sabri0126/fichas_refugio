import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'ficha_detalle_perro.dart';
import 'formulario_perro.dart';

class PantallaPerros extends StatefulWidget {
  final bool soloInactivos;

  const PantallaPerros({super.key, this.soloInactivos = false});

  @override
  State<PantallaPerros> createState() => _PantallaPerrosState();
}

class _PantallaPerrosState extends State<PantallaPerros> {
  final TextEditingController _busquedaController = TextEditingController();
  String _textoBusqueda = '';
  String _filtroUbicacion = 'Todos';

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

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

    // Para difuntos/inactivos, la edad queda congelada en el valor guardado.
    if ((perro['estado']?.toString() ?? '') == 'inactivo') {
      return edadBase;
    }

    final anioBase = int.tryParse(perro['edad_anio_base']?.toString() ?? '') ?? DateTime.now().year;
    final aniosTranscurridos = DateTime.now().year - anioBase;

    return edadBase + (aniosTranscurridos > 0 ? aniosTranscurridos : 0);
  }

  @override
  Widget build(BuildContext context) {
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
            onPressed: () => FirebaseAuth.instance.signOut(),
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
            child: StreamBuilder(
        stream: FirebaseFirestore.instance.collection('perros').snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text(widget.soloInactivos ? 'No hay difuntos registrados.' : 'No hay perritos registrados aún.'));
          }

          final perrosPorEstado = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final estado = data['estado'] as String?;
            if (widget.soloInactivos) {
              return estado == 'inactivo';
            } else {
              return estado == null || estado == 'activo';
            }
          }).toList();

          final totalEnCasa = perrosPorEstado.where((p) => (p.data() as Map<String, dynamic>)['en_casa'] == true).length;
          final totalRefugio = perrosPorEstado.length - totalEnCasa;

          final perros = perrosPorEstado.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final enCasa = data['en_casa'] == true;

            if (_filtroUbicacion == 'En casa') {
              return enCasa;
            }
            if (_filtroUbicacion == 'Refugio') {
              return !enCasa;
            }
            return true;
          }).where((doc) {
            if (_textoBusqueda.isEmpty) return true;
            final data = doc.data() as Map<String, dynamic>;
            final nombre = (data['nombre'] as String? ?? '').toLowerCase();
            return nombre.contains(_textoBusqueda.toLowerCase());
          }).toList();

          perros.sort((a, b) {
            final dataA = a.data() as Map<String, dynamic>;
            final dataB = b.data() as Map<String, dynamic>;
            final fechaA = dataA['fecha_ingreso'];
            final fechaB = dataB['fecha_ingreso'];
            DateTime? dtA = fechaA is Timestamp ? fechaA.toDate() : null;
            DateTime? dtB = fechaB is Timestamp ? fechaB.toDate() : null;
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
                        final perro = perros[index].data() as Map<String, dynamic>;

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
                                  child: perro['foto_perfil'] != null && perro['foto_perfil'].toString().isNotEmpty
                                      ? Image.network(
                                          perro['foto_perfil'],
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
                                        perro['nombre'] ?? 'Sin nombre',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 26,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Fecha de ingreso: ${_formatearFecha(perro['fecha_ingreso'])}',
                                        style: const TextStyle(fontSize: 15, color: Colors.white70),
                                      ),
                                      Text(
                                        perro['sexo'] == 'hembra' ? 'Sexo: Hembra' : 'Sexo: Macho',
                                        style: const TextStyle(fontSize: 15, color: Colors.white70),
                                      ),
                                      Text(
                                        'Edad estimada: ${_calcularEdadEstimada(perro)} años',
                                        style: const TextStyle(fontSize: 15, color: Colors.white70),
                                      ),
                                      Text(
                                        perro['castrado'] == true ? 'Castrado: Sí' : 'Castrado: No',
                                        style: const TextStyle(fontSize: 15, color: Colors.white70),
                                      ),
                                      if (widget.soloInactivos && perro['fecha_fallecimiento'] != null)
                                        Text(
                                          'Fallecimiento: ${_formatearFecha(perro['fecha_fallecimiento'])}',
                                          style: const TextStyle(fontSize: 15, color: Colors.white70),
                                        ),
                                    ],
                                  ),
                                ),
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
                                          builder: (context) => FormularioPerro(idDocumento: idDocumento, datosActuales: perro),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FormularioPerro())),
        backgroundColor: Theme.of(context).colorScheme.secondary,
        foregroundColor: Theme.of(context).colorScheme.onSecondary,
        child: const Icon(Icons.add),
      ),
    );
  }
}
