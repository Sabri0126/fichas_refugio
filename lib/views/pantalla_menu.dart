import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';
import '../providers/calendario_providers.dart';
import '../providers/notificaciones_providers.dart';
import '../providers/perros_providers.dart';
import '../providers/theme_mode_provider.dart';
import '../services/mensajeria_service.dart';
import '../services/nombre_usuario.dart';
import '../services/notificaciones_service.dart';
import '../theme/app_colors.dart';
import '../theme/category_colors.dart';
import '../util/plataforma.dart';
import '../utils/fundacion_refugio.dart';
import 'pantalla_calendario_general.dart';
import 'pantalla_login.dart';
import 'pantalla_notificaciones.dart';
import 'pantalla_perros.dart';
import 'pantalla_reportes.dart';
import 'pantalla_veterinarias.dart';

class PantallaMenu extends ConsumerStatefulWidget {
  const PantallaMenu({super.key});

  @override
  ConsumerState<PantallaMenu> createState() => _PantallaMenuState();
}

class _PantallaMenuState extends ConsumerState<PantallaMenu> {
  bool _pidiendoNombre = false;
  bool _efectosStaff = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual<bool>(
      sessionProvider.select((sesion) => sesion.esInvitado),
      (anterior, esInvitado) {
        if (esInvitado || _efectosStaff) return;
        _efectosStaff = true;
        unawaited(MensajeriaService.instance.registrarDispositivo().catchError((Object _) {}));
        unawaited(NotificacionesService.instance.migrarAlarmasLocales());
        unawaited(_prepararNombre());
      },
      fireImmediately: true,
    );
  }

  Future<void> _prepararNombre() async {
    final usuario = ref.read(sessionProvider).usuario;
    if (usuario == null || !mounted) return;
    await NombreUsuario.cargar(usuario.uid);
    if (!mounted) return;
    setState(() {});
    if (NombreUsuario.falta(usuario)) await _pedirNombre();
  }

  Future<void> _pedirNombre() async {
    final usuario = ref.read(sessionProvider).usuario;
    if (usuario == null || !mounted || _pidiendoNombre) return;
    _pidiendoNombre = true;
    try {
      final elegido = await showDialog<String>(
        context: context,
        builder: (context) => _DialogoNombre(inicial: NombreUsuario.visible(usuario)),
      );
      if (elegido == null || !mounted) return;
      final limpio = elegido.trim();
      if (limpio.isEmpty) return;
      await NombreUsuario.guardar(usuario, limpio);
      if (mounted) setState(() {});
    } finally {
      _pidiendoNombre = false;
    }
  }

  Future<void> _abrirNotificaciones() {
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PantallaNotificaciones()),
    );
  }

  Future<bool> _confirmarCierreSesion(bool esInvitado) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(esInvitado ? '¿Salir?' : '¿Cerrar sesión?'),
        content: Text(
          esInvitado
              ? '¿Querés salir del modo visitante y volver al inicio de sesión?'
              : '¿Estás seguro de que querés salir de tu cuenta?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.logout),
            label: const Text('Salir'),
          ),
        ],
      ),
    );
    return confirmar == true;
  }

  @override
  Widget build(BuildContext context) {
    final sesion = ref.watch(sessionProvider);
    final bool esInvitado = sesion.esInvitado;
    final modo = ref.watch(themeModeProvider);
    final datos = ref.watch(perrosProvider).value;
    final desdeCache = ref.watch(perrosDesdeCacheProvider);
    final noLeidas = ref.watch(notificacionesNoLeidasProvider);
    final pendientes = ref.watch(pendientesHoyProvider);
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/PortonRefugio.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: context.temaOscuro ? 0.55 : 0.25),
                  Colors.black.withValues(alpha: context.temaOscuro ? 0.88 : 0.72),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.pets,
                                  size: 72,
                                  color: Colors.white,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Refugio Milagros de Amor',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                        fontSize: 32,
                                        color: Colors.white,
                                      ),
                                ),
                                const SizedBox(height: 12),
                                Builder(
                                  builder: (context) {
                                    final activos = datos?.where((perro) => perro.estado == 'activo').toList() ?? [];
                                    final enCasa = activos.where((perro) => perro.enCasa).length;
                                    final enRefugio = activos.length - enCasa;
                                    final difuntos = datos?.where((perro) => perro.estado == 'inactivo').length;
                                    final adoptados = datos?.where((perro) => perro.estado == 'egresado' && perro.motivoEgreso == 'adopcion').length;
                                    final reencontrados = datos?.where((perro) => perro.estado == 'egresado' && perro.motivoEgreso == 'familia').length;
                                    final cuidado = activos.length == 1
                                        ? '1 perrito a nuestro cuidado'
                                        : '${activos.length} perritos a nuestro cuidado';
                                    return AnchoVentana(
                                      child: Column(
                                      children: [
                                        if (datos != null)
                                          Text(
                                            cuidado,
                                            textAlign: TextAlign.center,
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              color: Colors.white.withValues(alpha: 0.95),
                                              shadows: const [Shadow(color: Colors.black87, blurRadius: 6)],
                                            ),
                                          ),
                                        if (pendientes > 0) ...[
                                          const SizedBox(height: 20),
                                          _PanelDelDia(
                                            cantidad: pendientes,
                                            onTap: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => const PantallaCalendarioGeneral(),
                                              ),
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 28),
                                        BotonMenu(
                                          label: 'Perritos del refugio',
                                          detalle: datos == null
                                              ? null
                                              : '$enRefugio en el refugio · $enCasa en casa',
                                          icon: Icons.pets,
                                          color: AppColors.terracota,
                                          onTap: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => const PantallaPerros(
                                                seccion: SeccionPerros.activos,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        BotonMenu(
                                          label: 'Difuntos',
                                          detalle: difuntos == null
                                              ? null
                                              : (difuntos == 1 ? '1 en memoria' : '$difuntos en memoria'),
                                          icon: Icons.local_florist,
                                          color: AppColors.navy,
                                          onTap: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => const PantallaPerros(
                                                seccion: SeccionPerros.difuntos,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        BotonMenu(
                                          label: 'Adoptados y reencontrados',
                                          detalle: adoptados == null
                                              ? null
                                              : '$adoptados adoptados · $reencontrados reencontrados',
                                          icon: Icons.volunteer_activism,
                                          color: AppColors.activoTexto,
                                          onTap: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => const PantallaPerros(
                                                seccion: SeccionPerros.egresados,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        BotonMenu(
                                          label: 'Calendario general',
                                          detalle: pendientes == 0
                                              ? null
                                              : (pendientes == 1 ? '1 pendiente hoy' : '$pendientes pendientes hoy'),
                                          icon: Icons.calendar_month_rounded,
                                          color: CategoryColors.unicoTexto,
                                          onTap: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => const PantallaCalendarioGeneral(),
                                            ),
                                          ),
                                        ),
                                        if (!esInvitado) ...[
                                          const SizedBox(height: 16),
                                          BotonMenu(
                                            label: 'Reportes',
                                            detalle: 'Población y estadía',
                                            icon: Icons.insights,
                                            color: CategoryColors.higieneTexto,
                                            onTap: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => const PantallaReportes(),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          BotonMenu(
                                            label: 'Veterinarias y contactos',
                                            detalle: 'Llamar o compartir',
                                            icon: Icons.local_hospital_outlined,
                                            color: AppColors.arena,
                                            textoOscuro: true,
                                            onTap: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => const PantallaVeterinarias(),
                                              ),
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 28),
                                        Text(
                                          textoAniosCuidando(calcularAniosServicio()),
                                          textAlign: TextAlign.center,
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: Colors.white.withValues(alpha: 0.9),
                                            shadows: const [Shadow(color: Colors.black87, blurRadius: 6)],
                                          ),
                                        ),
                                      ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                Positioned(
                  top: 52,
                  left: 16,
                  right: 16,
                  child: desdeCache
                      ? Material(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(12),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Text(
                              'Sin conexión. Estás viendo datos guardados en el dispositivo.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white, fontSize: 13),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                Positioned(
                  top: esWindows ? 64 : 12,
                  left: esWindows ? null : 8,
                  right: esWindows ? 8 : null,
                  child: IconButton(
                    tooltip: 'Cerrar sesión',
                    onPressed: () async {
                      final confirmar = await _confirmarCierreSesion(
                        esInvitado,
                      );
                      if (confirmar != true || !context.mounted) return;
                      if (!esInvitado) {
                        await MensajeriaService.instance
                            .desregistrarDispositivo();
                        NombreUsuario.olvidar();
                        await FirebaseAuth.instance.signOut();
                      }
                      if (!context.mounted) return;
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PantallaLogin(),
                        ),
                        (route) => false,
                      );
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 44,
                      height: 44,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.4),
                      foregroundColor: Colors.white,
                      fixedSize: const Size(44, 44),
                      shape: const CircleBorder(),
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.logout_rounded),
                  ),
                ),
                if (!esInvitado)
                  Positioned(
                    top: 16,
                    left: esWindows ? 16 : 60,
                    right: 120,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _pedirNombre,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: Text(
                          _etiquetaNombre(sesion.usuario),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: 12,
                  right: esInvitado ? 8 : 60,
                  child: PopupMenuButton<ThemeMode>(
                    tooltip: 'Apariencia',
                    initialValue: modo,
                    onSelected: (nuevo) => ref.read(themeModeProvider.notifier).fijar(nuevo),
                    icon: Icon(
                      modo == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.4),
                      foregroundColor: Colors.white,
                      fixedSize: const Size(44, 44),
                      shape: const CircleBorder(),
                    ),
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: ThemeMode.light, child: Text('Claro')),
                      PopupMenuItem(value: ThemeMode.dark, child: Text('Oscuro')),
                    ],
                  ),
                ),
                if (!esInvitado)
                  Positioned(
                    top: 12,
                    right: 8,
                    child: Badge(
                      isLabelVisible: noLeidas > 0,
                      label: Text(noLeidas > 9 ? '9+' : '$noLeidas'),
                      child: IconButton(
                        tooltip: 'Notificaciones',
                        onPressed: _abrirNotificaciones,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 44,
                          height: 44,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.4),
                          foregroundColor: Colors.white,
                          fixedSize: const Size(44, 44),
                          shape: const CircleBorder(),
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.notifications_rounded),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BotonMenu extends StatelessWidget {
  final String label;
  final String? detalle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool textoOscuro;

  const BotonMenu({
    super.key,
    required this.label,
    this.detalle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.textoOscuro = false,
  });

  @override
  Widget build(BuildContext context) {
    final oscuro = context.temaOscuro;
    final fondo = textoOscuro || !oscuro ? color : Color.lerp(color, Colors.black, 0.35)!;
    final tinta = textoOscuro ? AppColors.navy : Colors.white;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: fondo,
          foregroundColor: tinta,
          elevation: 0,
          minimumSize: const Size(0, 64),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: textoOscuro
                ? BorderSide(color: AppColors.navy.withValues(alpha: 0.18))
                : oscuro
                    ? BorderSide(color: Colors.white.withValues(alpha: 0.22))
                    : BorderSide.none,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: textoOscuro
                    ? AppColors.navy.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 22, color: tinta),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(color: tinta),
                  ),
                  if (detalle != null)
                    Text(
                      detalle!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: tinta.withValues(alpha: textoOscuro ? 0.8 : 0.9),
                        fontSize: esWindows ? 15 : 13,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PanelDelDia extends StatelessWidget {
  final int cantidad;
  final VoidCallback onTap;

  const _PanelDelDia({required this.cantidad, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final texto = cantidad == 1 ? '1 dosis pendiente hoy' : '$cantidad dosis pendientes hoy';
    final oscuro = context.temaOscuro;
    final tinta = oscuro ? context.paleta.texto : AppColors.texto;
    return Material(
      color: oscuro ? context.paleta.superficie : Colors.white.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.medication_outlined, color: AppColors.terracota),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  texto,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: tinta),
                ),
              ),
              Icon(Icons.chevron_right, color: oscuro ? context.paleta.textoSuave : AppColors.navy),
            ],
          ),
        ),
      ),
    );
  }
}

String _etiquetaNombre(User? usuario) {
  final nombre = NombreUsuario.visible(usuario);
  if (nombre.isNotEmpty) return nombre;
  return 'Elegí tu nombre';
}

class _DialogoNombre extends StatefulWidget {
  final String inicial;

  const _DialogoNombre({required this.inicial});

  @override
  State<_DialogoNombre> createState() => _DialogoNombreState();
}

class _DialogoNombreState extends State<_DialogoNombre> {
  late final TextEditingController _nombre = TextEditingController(text: widget.inicial);

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  void _guardar() {
    final limpio = _nombre.text.trim();
    if (limpio.isEmpty) return;
    Navigator.pop(context, limpio);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tu nombre'),
      content: TextField(
        controller: _nombre,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        scrollPadding: EdgeInsets.zero,
        decoration: const InputDecoration(labelText: 'Cómo te ven en las fichas'),
        onSubmitted: (_) => _guardar(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardar,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
