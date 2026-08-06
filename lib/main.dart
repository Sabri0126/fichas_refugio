import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fichas Refugio',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: const PantallaPerros(),
    );
  }
}

// =====================================================================
// PANTALLA PRINCIPAL: Grilla de perritos
// =====================================================================
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
                      // Pasamos el ID del documento para poder leer en vivo la galería
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
                          color: Colors.white.withOpacity(0.95),
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

// =====================================================================
// PANTALLA DETALLE: Galería interactiva con escucha EN VIVO
// =====================================================================
class FichaDetallePerro extends StatefulWidget {
  final String idDocumento;

  const FichaDetallePerro({super.key, required this.idDocumento});

  @override
  State<FichaDetallePerro> createState() => _FichaDetallePerroState();
}

class _FichaDetallePerroState extends State<FichaDetallePerro> {
  final PageController _controladorCarrusel = PageController();
  final ImagePicker _picker = ImagePicker();
  bool _subiendoFoto = false;

  @override
  void dispose() {
    _controladorCarrusel.dispose();
    super.dispose();
  }

  void _moverIzquierda() => _controladorCarrusel.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  void _moverDerecha() => _controladorCarrusel.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);

  // Lógica de subir foto a la galería
  Future<void> _agregarFotoAGaleria() async {
    final XFile? imagen = await _picker.pickImage(source: ImageSource.gallery);
    
    if (imagen != null && mounted) {
      TextEditingController textoController = TextEditingController();
      
      // Pedimos el texto descriptivo con un pop-up
      String? textoDescriptivo = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Agregar descripción (opcional)'),
          content: TextField(
            controller: textoController,
            decoration: const InputDecoration(hintText: "Ej: Jugando en el patio..."),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.pop(context, textoController.text), child: const Text('Subir Foto')),
          ],
        ),
      );

      if (textoDescriptivo != null) {
        setState(() => _subiendoFoto = true);
        try {
          File archivoFisico = File(imagen.path);
          final nombreArchivo = 'galeria_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final refStorage = FirebaseStorage.instance.ref().child('galeria_perros').child(nombreArchivo);
          
          await refStorage.putFile(archivoFisico);
          final urlDescarga = await refStorage.getDownloadURL();
          
          final nuevoItemGaleria = {
            'url': urlDescarga,
            'texto': textoDescriptivo,
          };
          
          await FirebaseFirestore.instance.collection('perros').doc(widget.idDocumento).update({
            'galeria': FieldValue.arrayUnion([nuevoItemGaleria])
          });
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al subir la foto')));
        } finally {
          if (mounted) setState(() => _subiendoFoto = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Usamos StreamBuilder para que la galería se actualice apenas sube la foto
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('perros').doc(widget.idDocumento).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        
        var perro = snapshot.data!.data() as Map<String, dynamic>;
        List<dynamic> galeria = perro['galeria'] ?? [];

        return Scaffold(
          appBar: AppBar(
            title: Text('Ficha de ${perro['nombre']}', style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.black87,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              // Botón en la barra superior para agregar fotos a la galería
              if (_subiendoFoto)
                const Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(color: Colors.white))
              else
                IconButton(
                  icon: const Icon(Icons.add_a_photo),
                  tooltip: 'Agregar foto a la galería',
                  onPressed: _agregarFotoAGaleria,
                )
            ],
          ),
          body: Row(
            children: [
              Expanded(
                flex: 1,
                child: Container(
                  color: Colors.grey.shade200,
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(perro['nombre'] ?? 'Sin nombre', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
                      const Divider(color: Colors.black, thickness: 3),
                      const SizedBox(height: 16),
                      Text('• Edad: ${perro['edad']} años.', style: const TextStyle(fontSize: 18)),
                      Text('• Estado: ${perro['estado']}.', style: const TextStyle(fontSize: 18)),
                      Text(perro['castrado'] == true ? '• Castrado.' : '• Sin castrar.', style: const TextStyle(fontSize: 18)),
                      const SizedBox(height: 24),
                      const Text('Más información:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(perro['historia'] ?? 'No hay observaciones médicas.', style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: galeria.isEmpty
                    ? const Center(child: Text('Aún no hay fotos en la galería. ¡Tocá la cámara arriba a la derecha!', style: TextStyle(fontSize: 18)))
                    : Stack(
                        alignment: Alignment.center,
                        children: [
                          PageView.builder(
                            controller: _controladorCarrusel,
                            itemCount: galeria.length,
                            itemBuilder: (context, index) {
                              final foto = galeria[index];
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(foto['url'] ?? '', fit: BoxFit.contain),
                                      ),
                                    ),
                                  ),
                                  if (foto['texto'] != null && foto['texto'].toString().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 24.0, left: 40, right: 40),
                                      child: Text(foto['texto'], style: const TextStyle(fontSize: 20, fontStyle: FontStyle.italic), textAlign: TextAlign.center),
                                    ),
                                ],
                              );
                            },
                          ),
                          Positioned(
                            left: 16,
                            child: CircleAvatar(
                              backgroundColor: Colors.black54,
                              radius: 30,
                              child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30), onPressed: _moverIzquierda),
                            ),
                          ),
                          Positioned(
                            right: 16,
                            child: CircleAvatar(
                              backgroundColor: Colors.black54,
                              radius: 30,
                              child: IconButton(icon: const Icon(Icons.arrow_forward, color: Colors.white, size: 30), onPressed: _moverDerecha),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      }
    );
  }
}

// =====================================================================
// FORMULARIO: Con soporte para subir Foto de Perfil
// =====================================================================
class FormularioPerro extends StatefulWidget {
  final String? idDocumento;
  final Map<String, dynamic>? datosActuales;

  const FormularioPerro({super.key, this.idDocumento, this.datosActuales});

  @override
  State<FormularioPerro> createState() => _FormularioPerroState();
}

class _FormularioPerroState extends State<FormularioPerro> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _edadController = TextEditingController();
  final TextEditingController _historiaController = TextEditingController();
  
  String _estadoSeleccionado = 'activo';
  bool _estaCastrado = false;
  bool _estaGuardando = false;

  File? _imagenSeleccionada;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.datosActuales != null) {
      _nombreController.text = widget.datosActuales!['nombre'] ?? '';
      _edadController.text = widget.datosActuales!['edad']?.toString() ?? '';
      _historiaController.text = widget.datosActuales!['historia'] ?? '';
      _estadoSeleccionado = widget.datosActuales!['estado'] ?? 'activo';
      _estaCastrado = widget.datosActuales!['castrado'] ?? false;
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _edadController.dispose();
    _historiaController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarImagen() async {
    final XFile? imagen = await _picker.pickImage(source: ImageSource.gallery);
    if (imagen != null) setState(() => _imagenSeleccionada = File(imagen.path));
  }

  Future<void> _guardarDatos() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _estaGuardando = true); 

      try {
        String? urlImagen = widget.datosActuales?['foto_perfil'];

        if (_imagenSeleccionada != null) {
          final nombreArchivo = '${DateTime.now().millisecondsSinceEpoch}.jpg';
          final ref = FirebaseStorage.instance.ref().child('fotos_perfil').child(nombreArchivo);
          await ref.putFile(_imagenSeleccionada!);
          urlImagen = await ref.getDownloadURL();
        }

        final datosFicha = {
          'nombre': _nombreController.text.trim(),
          'edad': int.tryParse(_edadController.text.trim()) ?? 0,
          'historia': _historiaController.text.trim(),
          'estado': _estadoSeleccionado,
          'castrado': _estaCastrado,
          if (urlImagen != null) 'foto_perfil': urlImagen,
        };

        if (widget.idDocumento == null) {
          await FirebaseFirestore.instance.collection('perros').add(datosFicha);
        } else {
          await FirebaseFirestore.instance.collection('perros').doc(widget.idDocumento).update(datosFicha);
        }
        
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al procesar la información')));
      } finally {
        if (mounted) setState(() => _estaGuardando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final esEdicion = widget.idDocumento != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(esEdicion ? 'Editar Ficha' : 'Nuevo Ingreso', style: const TextStyle(color: Colors.white)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Center(
                child: GestureDetector(
                  onTap: _seleccionarImagen,
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey.shade300,
                    backgroundImage: _imagenSeleccionada != null
                        ? FileImage(_imagenSeleccionada!) as ImageProvider
                        : (widget.datosActuales?['foto_perfil'] != null ? NetworkImage(widget.datosActuales!['foto_perfil']) : null),
                    child: _imagenSeleccionada == null && widget.datosActuales?['foto_perfil'] == null
                        ? const Icon(Icons.add_a_photo, size: 40, color: Colors.grey)
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(controller: _nombreController, decoration: const InputDecoration(labelText: 'Nombre del perrito', border: OutlineInputBorder(), prefixIcon: Icon(Icons.pets)), validator: (value) => value == null || value.trim().isEmpty ? 'Ingresá un nombre' : null),
              const SizedBox(height: 16),
              TextFormField(controller: _edadController, decoration: const InputDecoration(labelText: 'Edad estimada (años)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.cake)), keyboardType: TextInputType.number, validator: (value) => value == null || value.trim().isEmpty ? 'Falta ingresar la edad' : null),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _estadoSeleccionado,
                decoration: const InputDecoration(labelText: 'Estado en el refugio', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'activo', child: Text('Activo (Buscando familia)')),
                  DropdownMenuItem(value: 'adoptado', child: Text('Adoptado')),
                  DropdownMenuItem(value: 'miembro', child: Text('Miembro (Residente permanente)')),
                ],
                onChanged: (valor) { if (valor != null) setState(() => _estadoSeleccionado = valor); },
              ),
              const SizedBox(height: 16),
              SwitchListTile(title: const Text('¿Ya está castrado?'), value: _estaCastrado, activeColor: Colors.deepOrange, onChanged: (valor) => setState(() => _estaCastrado = valor)),
              const SizedBox(height: 16),
              TextFormField(controller: _historiaController, decoration: const InputDecoration(labelText: 'Observaciones / Historia Médica', border: OutlineInputBorder()), maxLines: 4),
              const SizedBox(height: 32),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _estaGuardando ? null : _guardarDatos,
                  style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white),
                  child: _estaGuardando ? const CircularProgressIndicator(color: Colors.white) : Text(esEdicion ? 'Guardar Cambios' : 'Crear Ficha', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}