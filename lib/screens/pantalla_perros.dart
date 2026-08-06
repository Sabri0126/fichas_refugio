import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'ficha_detalle_perro.dart';
import 'formulario_perro.dart';

class PantallaPerros extends StatelessWidget {
  final bool soloInactivos;

  const PantallaPerros({super.key, this.soloInactivos = false});

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
    final anioBase = int.tryParse(perro['edad_anio_base']?.toString() ?? '') ?? DateTime.now().year;
    final aniosTranscurridos = DateTime.now().year - anioBase;

    return edadBase + (aniosTranscurridos > 0 ? aniosTranscurridos : 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          soloInactivos ? 'Difuntos' : 'Perritos',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24),
        ),
        backgroundColor: Colors.black87,
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance.collection('perros').snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text(soloInactivos ? 'No hay difuntos registrados.' : 'No hay perritos registrados aún.'));
          }

          final perros = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final estado = data['estado'] as String?;
            if (soloInactivos) {
              return estado == 'inactivo';
            } else {
              return estado == null || estado == 'activo';
            }
          }).toList();

          if (perros.isEmpty) {
            return Center(child: Text(soloInactivos ? 'No hay difuntos registrados.' : 'No hay perritos registrados aún.'));
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth >= 900
                  ? 3
                  : constraints.maxWidth >= 600
                      ? 2
                      : 1;

              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
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
                                      color: Colors.blueGrey.shade700,
                                      child: const Icon(Icons.pets, color: Colors.white24, size: 80),
                                    ),
                                  )
                                : Container(color: Colors.blueGrey.shade700, child: const Icon(Icons.pets, color: Colors.white24, size: 80)),
                          ),
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.75)],
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
                                    fontSize: 22,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Fecha de ingreso: ${_formatearFecha(perro['fecha_ingreso'])}',
                                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                                ),
                                Text(
                                  'Edad estimada: ${_calcularEdadEstimada(perro)} años',
                                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                                ),
                                Text(
                                  perro['castrado'] == true ? 'Castrado: Sí' : 'Castrado: No',
                                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: IconButton(
                              icon: const Icon(Icons.edit, color: Colors.white),
                              style: IconButton.styleFrom(backgroundColor: Colors.black54),
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
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FormularioPerro())),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
