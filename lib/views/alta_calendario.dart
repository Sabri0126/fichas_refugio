import 'package:flutter/material.dart';

import '../controllers/perro_controller.dart';
import '../controllers/recordatorio_controller.dart';
import '../controllers/seguimiento_controller.dart';
import '../controllers/tratamiento_controller.dart';
import '../models/perro_model.dart';
import '../models/recordatorio_model.dart';
import '../models/seguimiento_model.dart';
import '../models/tratamiento_model.dart';
import '../theme/app_colors.dart';
import 'dialogo_recordatorio.dart';
import 'dialogo_seguimiento.dart';
import 'dialogo_tratamiento.dart';

/// Opciones del alta desde la ficha ("Registrar en el calendario").
enum TipoRegistroCalendario { tratamiento, seguimiento, recordatorio }

/// Diálogo con las tres opciones de alta, una por renglón.
Future<TipoRegistroCalendario?> elegirTipoRegistroCalendario(BuildContext context) {
  return showDialog<TipoRegistroCalendario>(
    context: context,
    builder: (ctx) => const _DialogoTipoRegistro(),
  );
}

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
  await abrirAltaRegistroParaPerro(
    context,
    perro: perro,
    fecha: fecha,
    tratamientos: tratamientos,
    perros: perros,
  );
}

/// Alta de tratamiento para un perro ya elegido (ficha o calendario).
/// `null` si canceló, `true` si guardó, `false` si falló.
Future<bool?> abrirAltaRegistroParaPerro(
  BuildContext context, {
  required PerroModel perro,
  required DateTime fecha,
  required TratamientoController tratamientos,
  required PerroController perros,
  Future<void> Function(TratamientoModel modelo)? alGuardar,
}) async {
  final categoria = await showDialog<String>(
    context: context,
    builder: (ctx) => _DialogoCategoria(
      alElegir: (elegida) => Navigator.pop(ctx, elegida),
    ),
  );
  if (categoria == null || !context.mounted) return null;
  final modelo = await mostrarDialogoTratamiento(
    context,
    controller: tratamientos,
    categoria: categoria,
    fechaInicial: fecha,
  );
  if (modelo == null || !context.mounted) return null;
  try {
    if (alGuardar != null) {
      await alGuardar(modelo);
    } else {
      await perros.agregarTratamiento(perro.id, modelo);
    }
    return true;
  } catch (_) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No se pudo guardar el registro')),
    );
    return false;
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
  await abrirAltaRecordatorioParaPerro(
    context,
    perro: perro,
    fecha: fecha,
    recordatorios: recordatorios,
    perros: perros,
  );
}

/// Alta de recordatorio para un perro ya elegido (ficha o calendario).
/// `null` si canceló, `true` si guardó, `false` si falló.
Future<bool?> abrirAltaRecordatorioParaPerro(
  BuildContext context, {
  required PerroModel perro,
  required DateTime fecha,
  required RecordatorioController recordatorios,
  required PerroController perros,
  Future<void> Function(RecordatorioModel modelo)? alGuardar,
}) async {
  final modelo = await mostrarDialogoRecordatorio(
    context,
    controller: recordatorios,
    fechaInicial: _fechaRecordatorio(fecha),
  );
  if (modelo == null || !context.mounted) return null;
  try {
    if (alGuardar != null) {
      await alGuardar(modelo);
    } else {
      await perros.agregarRecordatorio(perro.id, modelo);
    }
    return true;
  } catch (_) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No se pudo guardar el recordatorio')),
    );
    return false;
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
  await abrirAltaSeguimientoParaPerro(
    context,
    perro: perro,
    fecha: fecha,
    seguimientos: seguimientos,
    perros: perros,
  );
}

/// Alta de seguimiento para un perro ya elegido (ficha o calendario).
/// `null` si canceló, `true` si guardó, `false` si falló.
Future<bool?> abrirAltaSeguimientoParaPerro(
  BuildContext context, {
  required PerroModel perro,
  required DateTime fecha,
  required SeguimientoController seguimientos,
  required PerroController perros,
  Future<void> Function(SeguimientoModel modelo)? alGuardar,
}) async {
  final modelo = await mostrarDialogoSeguimiento(
    context,
    controller: seguimientos,
    fechaInicial: fecha,
  );
  if (modelo == null || !context.mounted) return null;
  try {
    if (alGuardar != null) {
      await alGuardar(modelo);
    } else {
      await perros.agregarSeguimiento(perro.id, modelo);
    }
    return true;
  } catch (_) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No se pudo guardar el seguimiento')),
    );
    return false;
  }
}

/// Misma forma que el diálogo de categoría: no usa AlertDialog porque la grilla
/// mide el ancho con LayoutBuilder y AlertDialog pide el intrínseco.
class _DialogoTipoRegistro extends StatelessWidget {
  const _DialogoTipoRegistro();

  static const _opciones = <(TipoRegistroCalendario, IconData, String, String, Color)>[
    (
      TipoRegistroCalendario.tratamiento,
      Icons.medical_services_outlined,
      'Tratamiento',
      'Vacunas, medicación, visitas al veterinario',
      AppColors.navy,
    ),
    (
      TipoRegistroCalendario.seguimiento,
      Icons.visibility_outlined,
      'Seguimiento',
      'Observar algo unos días: un ojo, una herida, el ánimo',
      AppColors.terracota,
    ),
    (
      TipoRegistroCalendario.recordatorio,
      Icons.alarm_add,
      'Recordatorio',
      'Algo para hacer en una fecha',
      AppColors.navy,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final pantalla = MediaQuery.sizeOf(context);
    var ancho = pantalla.width - 80;
    if (ancho > 560) ancho = 560;
    if (ancho < 280) ancho = 280;
    var alto = pantalla.height - 80;
    if (alto < 240) alto = 240;
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: ancho, maxHeight: alto),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('¿Qué querés registrar?', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              for (var i = 0; i < _opciones.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                _opcion(
                  context,
                  tipo: _opciones[i].$1,
                  icono: _opciones[i].$2,
                  titulo: _opciones[i].$3,
                  ejemplo: _opciones[i].$4,
                  color: _opciones[i].$5,
                ),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _opcion(
    BuildContext context, {
    required TipoRegistroCalendario tipo,
    required IconData icono,
    required String titulo,
    required String ejemplo,
    required Color color,
  }) {
    return Material(
      color: context.paleta.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: context.paleta.borde),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.pop(context, tipo),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icono, size: 22, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      ejemplo,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.paleta.textoSuave,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La grilla mide el ancho con LayoutBuilder. AlertDialog pide el ancho
/// intrínseco y eso tira la app, así que este diálogo no lo usa.
class _DialogoCategoria extends StatelessWidget {
  final ValueChanged<String> alElegir;

  const _DialogoCategoria({required this.alElegir});

  @override
  Widget build(BuildContext context) {
    final pantalla = MediaQuery.sizeOf(context);
    var ancho = pantalla.width - 80;
    if (ancho > 560) ancho = 560;
    if (ancho < 280) ancho = 280;
    var alto = pantalla.height - 80;
    if (alto < 240) alto = 240;
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: ancho, maxHeight: alto),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Agregar registro médico', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              GrillaRegistrosMedicos(
                alElegir: alElegir,
                diseno: DisenoRegistros.lista,
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
              ),
            ],
          ),
        ),
      ),
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
