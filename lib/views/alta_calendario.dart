import 'package:flutter/material.dart';

import '../controllers/perro_controller.dart';
import '../controllers/recordatorio_controller.dart';
import '../controllers/seguimiento_controller.dart';
import '../controllers/tratamiento_controller.dart';
import '../models/perro_model.dart';
import '../theme/app_colors.dart';
import 'dialogo_recordatorio.dart';
import 'dialogo_seguimiento.dart';
import 'dialogo_tratamiento.dart';

/// Elige un perro activo y abre el alta de un registro médico.
Future<void> abrirAltaRegistroCalendario(
  BuildContext context, {
  required List<PerroModel> activos,
  required String? idPreseleccionado,
  required DateTime fecha,
  required TratamientoController tratamientos,
  required PerroController perros,
}) async {
  final perro = await _elegirPerro(context, activos, idPreseleccionado);
  if (perro == null || !context.mounted) return;
  final categoria = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Agregar registro médico'),
      content: SingleChildScrollView(
        child: GrillaRegistrosMedicos(
          alElegir: (elegida) => Navigator.pop(ctx, elegida),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
      ],
    ),
  );
  if (categoria == null || !context.mounted) return;
  final modelo = await mostrarDialogoTratamiento(
    context,
    controller: tratamientos,
    categoria: categoria,
    fechaInicial: fecha,
  );
  if (modelo == null || !context.mounted) return;
  try {
    await perros.agregarTratamiento(perro.id, modelo);
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No se pudo guardar el registro')),
    );
  }
}

/// Elige un perro activo y abre el alta de un recordatorio.
Future<void> abrirAltaRecordatorioCalendario(
  BuildContext context, {
  required List<PerroModel> activos,
  required String? idPreseleccionado,
  required DateTime fecha,
  required RecordatorioController recordatorios,
  required PerroController perros,
}) async {
  final perro = await _elegirPerro(context, activos, idPreseleccionado);
  if (perro == null || !context.mounted) return;
  final modelo = await mostrarDialogoRecordatorio(
    context,
    controller: recordatorios,
    fechaInicial: _fechaRecordatorio(fecha),
  );
  if (modelo == null || !context.mounted) return;
  try {
    await perros.agregarRecordatorio(perro.id, modelo);
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No se pudo guardar el recordatorio')),
    );
  }
}

/// Elige un perro activo y abre el alta de un seguimiento.
/// El día seleccionado en el calendario queda como fecha de inicio.
Future<void> abrirAltaSeguimientoCalendario(
  BuildContext context, {
  required List<PerroModel> activos,
  required String? idPreseleccionado,
  required DateTime fecha,
  required SeguimientoController seguimientos,
  required PerroController perros,
}) async {
  final perro = await _elegirPerro(context, activos, idPreseleccionado);
  if (perro == null || !context.mounted) return;
  final modelo = await mostrarDialogoSeguimiento(
    context,
    controller: seguimientos,
    fechaInicial: fecha,
  );
  if (modelo == null || !context.mounted) return;
  try {
    await perros.agregarSeguimiento(perro.id, modelo);
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No se pudo guardar el seguimiento')),
    );
  }
}

/// El día elegido a las 09:00 si todavía es futuro; si no, mañana a las 09:00.
DateTime _fechaRecordatorio(DateTime dia) {
  final candidata = DateTime(dia.year, dia.month, dia.day, 9);
  if (candidata.isAfter(DateTime.now())) return candidata;
  final manana = DateTime.now().add(const Duration(days: 1));
  return DateTime(manana.year, manana.month, manana.day, 9);
}

Future<PerroModel?> _elegirPerro(
  BuildContext context,
  List<PerroModel> activos,
  String? idPreseleccionado,
) {
  final existe = activos.any((perro) => perro.id == idPreseleccionado);
  return showDialog<PerroModel>(
    context: context,
    builder: (ctx) => _SelectorPerro(
      activos: activos,
      idInicial: existe ? idPreseleccionado : null,
    ),
  );
}

class _SelectorPerro extends StatefulWidget {
  final List<PerroModel> activos;
  final String? idInicial;

  const _SelectorPerro({required this.activos, required this.idInicial});

  @override
  State<_SelectorPerro> createState() => _SelectorPerroState();
}

class _SelectorPerroState extends State<_SelectorPerro> {
  final TextEditingController _busqueda = TextEditingController();
  String? _idElegido;

  @override
  void initState() {
    super.initState();
    _idElegido = widget.idInicial;
    _busqueda.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final consulta = _busqueda.text.trim().toLowerCase();
    final visibles = [
      for (final perro in widget.activos)
        if (consulta.isEmpty || perro.nombre.toLowerCase().contains(consulta)) perro,
    ];
    final repetidos = _nombresRepetidos(widget.activos);
    final elegido = _buscar(_idElegido);

    final alto = (MediaQuery.sizeOf(context).height * 0.5).clamp(240.0, 420.0);
    return AlertDialog(
      title: const Text('Elegir perro'),
      content: SizedBox(
        width: 420,
        height: alto,
        child: Column(
          children: [
            TextField(
              controller: _busqueda,
              scrollPadding: EdgeInsets.zero,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Buscar por nombre',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: visibles.isEmpty
                  ? Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        'Ningún perro coincide.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: context.paleta.textoSuave,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: visibles.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 4),
                      itemBuilder: (context, indice) {
                        final perro = visibles[indice];
                        final seleccionado = perro.id == _idElegido;
                        final sinFoto = perro.fotoPerfil == null || perro.fotoPerfil!.isEmpty;
                        final mostrarIngreso = sinFoto &&
                            repetidos.contains(perro.nombre.trim().toLowerCase());
                        return Material(
                          color: seleccionado
                              ? context.paleta.lienzo.withValues(alpha: 0.08)
                              : context.paleta.superficie,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: seleccionado ? context.paleta.lienzo : context.paleta.borde,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            leading: _AvatarPerro(url: perro.fotoPerfil),
                            title: Text(perro.nombre),
                            subtitle: mostrarIngreso ? Text(_textoIngreso(perro.fechaIngreso)) : null,
                            onTap: () => setState(() => _idElegido = perro.id),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: elegido == null ? null : () => Navigator.pop(context, elegido),
          child: const Text('Continuar'),
        ),
      ],
    );
  }

  PerroModel? _buscar(String? id) {
    for (final perro in widget.activos) {
      if (perro.id == id) return perro;
    }
    return null;
  }
}

Set<String> _nombresRepetidos(List<PerroModel> activos) {
  final vistos = <String>{};
  final repetidos = <String>{};
  for (final perro in activos) {
    final nombre = perro.nombre.trim().toLowerCase();
    if (nombre.isEmpty) continue;
    if (!vistos.add(nombre)) repetidos.add(nombre);
  }
  return repetidos;
}

String _textoIngreso(DateTime? fecha) {
  if (fecha == null) return 'Sin fecha de ingreso';
  final dia = fecha.day.toString().padLeft(2, '0');
  final mes = fecha.month.toString().padLeft(2, '0');
  return 'Ingreso $dia/$mes/${fecha.year}';
}

class _AvatarPerro extends StatelessWidget {
  final String? url;

  const _AvatarPerro({required this.url});

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) return _vacio();
    return ClipOval(
      child: Image.network(
        url!,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _vacio(),
      ),
    );
  }

  Widget _vacio() {
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(color: AppColors.navy, shape: BoxShape.circle),
      child: Icon(Icons.pets, size: 22, color: Colors.white.withValues(alpha: 0.4)),
    );
  }
}
