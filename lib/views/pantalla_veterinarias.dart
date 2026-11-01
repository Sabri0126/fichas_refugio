import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers/veterinaria_controller.dart';
import '../models/contacto_veterinario_model.dart';
import '../theme/app_colors.dart';
import '../theme/category_colors.dart';
import '../util/plataforma.dart';

class PantallaVeterinarias extends StatefulWidget {
  const PantallaVeterinarias({super.key});

  @override
  State<PantallaVeterinarias> createState() => _PantallaVeterinariasState();
}

class _PantallaVeterinariasState extends State<PantallaVeterinarias> {
  final VeterinariaController _controller = VeterinariaController();

  void _aviso(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _guardar(ContactoVeterinarioModel? actual) async {
    final modelo = await showDialog<ContactoVeterinarioModel>(
      context: context,
      builder: (context) => _DialogoContacto(actual: actual),
    );
    if (modelo == null || !mounted) return;
    try {
      await _controller.guardar(modelo);
    } catch (_) {
      _aviso('No se pudo guardar el contacto.');
    }
  }

  Future<void> _eliminar(ContactoVeterinarioModel contacto) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar este contacto?'),
        content: Text(contacto.nombre),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    try {
      await _controller.eliminar(contacto.id);
    } catch (_) {
      _aviso('No se pudo eliminar el contacto.');
    }
  }

  Future<void> _opciones(ContactoVeterinarioModel contacto) async {
    final accion = await showModalBottomSheet<_AccionContacto>(
      context: context,
      showDragHandle: true,
      builder: (context) => HojaContactoVeterinario(
        contacto: contacto,
        puedeLlamar: !esWindows,
        onLlamar: () => Navigator.pop(context, _AccionContacto.llamar),
        onCompartir: () => Navigator.pop(context, _AccionContacto.compartir),
      ),
    );
    if (!mounted || accion == null) return;
    if (accion == _AccionContacto.llamar) {
      await _llamar(contacto);
    } else {
      await _compartir(contacto);
    }
  }

  Future<void> _llamar(ContactoVeterinarioModel contacto) async {
    final uri = VeterinariaController.uriTelefono(contacto.telefono);
    if (uri == null) {
      _aviso('El teléfono no se puede marcar.');
      return;
    }
    if (esWindows) {
      await Clipboard.setData(ClipboardData(text: contacto.telefono.trim()));
      _aviso('Número copiado. En la computadora no se puede llamar.');
      return;
    }
    try {
      final abrio = await launchUrl(Uri.parse(uri));
      if (!abrio) _aviso('No se pudo abrir el teléfono.');
    } catch (_) {
      _aviso('No se pudo abrir el teléfono.');
    }
  }

  Future<void> _compartir(ContactoVeterinarioModel contacto) async {
    try {
      await Share.share(VeterinariaController.textoCompartir(contacto));
    } catch (_) {
      _aviso('No se pudo compartir el contacto.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Veterinarias y contactos',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.arena,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Agregar veterinaria',
        onPressed: () => _guardar(null),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<ContactoVeterinarioModel>>(
        stream: _controller.observar(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('No se pudieron cargar los contactos.'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final contactos = snapshot.data!;
          if (contactos.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Todavía no hay veterinarias cargadas.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.paleta.textoSuave,
                  ),
                ),
              ),
            );
          }
          final abajo = 96 + MediaQuery.paddingOf(context).bottom;
          return AnchoVentana(
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(16, 16, 16, abajo),
              itemCount: contactos.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, indice) {
                final contacto = contactos[indice];
                return _TarjetaContacto(
                  contacto: contacto,
                  onTap: () => _opciones(contacto),
                  onEditar: () => _guardar(contacto),
                  onEliminar: () => _eliminar(contacto),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

enum _AccionContacto { llamar, compartir }

class HojaContactoVeterinario extends StatelessWidget {
  final ContactoVeterinarioModel contacto;
  final bool puedeLlamar;
  final VoidCallback onLlamar;
  final VoidCallback onCompartir;

  const HojaContactoVeterinario({
    super.key,
    required this.contacto,
    required this.puedeLlamar,
    required this.onLlamar,
    required this.onCompartir,
  });

  @override
  Widget build(BuildContext context) {
    final notas = contacto.notas.trim();
    final suave = context.paleta.textoSuave;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              contacto.nombre,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              contacto.ubicacion,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: suave),
            ),
            const SizedBox(height: 4),
            Text(
              contacto.telefono,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (notas.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                notas,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: suave),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onLlamar,
                icon: Icon(puedeLlamar ? Icons.phone : Icons.content_copy),
                label: Text(puedeLlamar ? 'Llamar' : 'Copiar número'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onCompartir,
                icon: const Icon(Icons.share),
                label: const Text('Compartir'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaContacto extends StatelessWidget {
  final ContactoVeterinarioModel contacto;
  final VoidCallback onTap;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  const _TarjetaContacto({
    required this.contacto,
    required this.onTap,
    required this.onEditar,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final notas = contacto.notas.trim();
    final suave = context.paleta.textoSuave;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: CategoryColors.tinte('veterinaria'),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.local_hospital_outlined,
                    color: CategoryColors.veterinariaTexto,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contacto.nombre,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      contacto.ubicacion,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: suave),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      contacto.telefono,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (notas.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        notas,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: suave),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Editar o eliminar',
                onSelected: (valor) {
                  if (valor == 'editar') onEditar();
                  if (valor == 'eliminar') onEliminar();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'editar', child: Text('Editar')),
                  PopupMenuItem(value: 'eliminar', child: Text('Eliminar')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogoContacto extends StatefulWidget {
  final ContactoVeterinarioModel? actual;

  const _DialogoContacto({this.actual});

  @override
  State<_DialogoContacto> createState() => _DialogoContactoState();
}

class _DialogoContactoState extends State<_DialogoContacto> {
  late final TextEditingController _nombre;
  late final TextEditingController _ubicacion;
  late final TextEditingController _telefono;
  late final TextEditingController _notas;
  var _error = '';
  var _cerrando = false;

  @override
  void initState() {
    super.initState();
    final actual = widget.actual;
    _nombre = TextEditingController(text: actual?.nombre ?? '');
    _ubicacion = TextEditingController(text: actual?.ubicacion ?? '');
    _telefono = TextEditingController(text: actual?.telefono ?? '');
    _notas = TextEditingController(text: actual?.notas ?? '');
  }

  @override
  void dispose() {
    _nombre.dispose();
    _ubicacion.dispose();
    _telefono.dispose();
    _notas.dispose();
    super.dispose();
  }

  void _guardar() {
    if (_cerrando) return;
    final error = VeterinariaController.validar(
      nombre: _nombre.text,
      ubicacion: _ubicacion.text,
      telefono: _telefono.text,
      notas: _notas.text,
    );
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    _cerrando = true;
    Navigator.pop(
      context,
      ContactoVeterinarioModel(
        id: widget.actual?.id ?? '',
        nombre: _nombre.text.trim(),
        ubicacion: _ubicacion.text.trim(),
        telefono: _telefono.text.trim(),
        notas: _notas.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final actual = widget.actual;
    return AlertDialog(
      scrollable: true,
      title: Text(
        actual == null ? 'Agregar veterinaria' : 'Editar veterinaria',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nombre,
            autofocus: actual == null,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            scrollPadding: EdgeInsets.zero,
            decoration: const InputDecoration(
              labelText: 'Nombre del veterinario',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ubicacion,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            scrollPadding: EdgeInsets.zero,
            decoration: const InputDecoration(
              labelText: 'Ubicación de la veterinaria',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _telefono,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            scrollPadding: EdgeInsets.zero,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+()\s\-]')),
            ],
            decoration: const InputDecoration(labelText: 'Teléfono'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notas,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            scrollPadding: EdgeInsets.zero,
            minLines: 1,
            maxLines: 4,
            onSubmitted: (_) => _guardar(),
            decoration: const InputDecoration(labelText: 'Notas (opcional)'),
          ),
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _error,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardar,
          child: Text(actual == null ? 'Agregar' : 'Guardar'),
        ),
      ],
    );
  }
}
