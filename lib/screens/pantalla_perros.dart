import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'ficha_detalle_perro.dart';
import 'formulario_perro.dart';

class PantallaPerros extends StatelessWidget {
  const PantallaPerros({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sector General', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24)),
        backgroundColor: Colors.black87,
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance.collection('perros').snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No hay perritos registrados aún.'));
          }

          final perros = snapshot.data!.docs;

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.8,
            ),
            itemCount: perros.length,
            itemBuilder: (context, index) {
              final idDocumento = perros[index].id;
              var perro = perros[index].data() as Map<String, dynamic>;

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
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      perro['foto_perfil'] != null && perro['foto_perfil'].toString().isNotEmpty
                          ? Image.network(perro['foto_perfil'], fit: BoxFit.cover)
                          : Container(color: Colors.blueGrey.shade700, child: const Icon(Icons.pets, color: Colors.white24, size: 80)),

                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: 250,
                          color: Colors.white.withValues(alpha: 0.95),
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(perro['nombre'] ?? 'Sin nombre', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 26, color: Colors.black87)),
                              const Divider(color: Colors.black, thickness: 2),
                              const SizedBox(height: 8),
                              Text('• Edad: ${perro['edad']} años.', style: const TextStyle(fontSize: 13)),
                              Text('• Estado: ${perro['estado']}.', style: const TextStyle(fontSize: 13)),
                              Text(perro['castrado'] == true ? '• Castrado.' : '• Sin castrar.', style: const TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                      ),

                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton(
                          icon: const Icon(Icons.edit, color: Colors.white),
                          style: IconButton.styleFrom(backgroundColor: Colors.black54),
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (context) => FormularioPerro(idDocumento: idDocumento, datosActuales: perro),
                            ));
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
