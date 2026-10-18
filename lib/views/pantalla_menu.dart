import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../controllers/calendario_general_controller.dart';
import '../controllers/historial_notificaciones_controller.dart';
import '../controllers/perro_controller.dart';
import '../models/perro_model.dart';
import '../services/mensajeria_service.dart';
import '../services/notificaciones_service.dart';
import '../theme/app_colors.dart';
import '../theme/category_colors.dart';
import '../theme/tema_app.dart';
import 'pantalla_calendario_general.dart';
import 'pantalla_login.dart';
import 'pantalla_notificaciones.dart';
import 'pantalla_perros.dart';

class PantallaMenu extends StatefulWidget {
  const PantallaMenu({super.key});

  @override
  State<PantallaMenu> createState() => _PantallaMenuState();
}

class _PantallaMenuState extends State<PantallaMenu> {
  final HistorialNotificacionesController _historial =
      HistorialNotificacionesController();
  final PerroController _perros = PerroController();
  StreamSubscription<int>? _badge;
  int _noLeidas = 0;

  @override
  void initState() {
    super.initState();
    final esInvitado = FirebaseAuth.instance.currentUser == null;
    if (!esInvitado) {
      unawaited(
        MensajeriaService.instance.registrarDispositivo().catchError(
          (Object _) {},
        ),
      );
      unawaited(NotificacionesService.instance.migrarAlarmasLocales());
      _badge = _historial.observarNoLeidas().listen((cantidad) {
        if (!mounted) return;
        setState(() => _noLeidas = cantidad);
      });
      final sinNombre = FirebaseAuth.instance.currentUser?.displayName?.trim().isEmpty ?? true;
      if (sinNombre) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _pedirNombre();
        });
      }
    }
  }

  @override
  void dispose() {
    _badge?.cancel();
    super.dispose();
  }

  Future<void> _pedirNombre() async {
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null || !mounted) return;
    final elegido = await showDialog<String>(
      context: context,
      builder: (context) => _DialogoNombre(inicial: usuario.displayName?.trim() ?? ''),
    );
    if (elegido == null || !mounted) return;
    final limpio = elegido.trim();
    if (limpio.isEmpty) return;
    await usuario.updateProfile(displayName: limpio);
    await usuario.reload();
    if (mounted) setState(() {});
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
    final bool esInvitado = FirebaseAuth.instance.currentUser == null;
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
                                StreamBuilder<List<PerroModel>>(
                                  stream: _perros.observarPerros(),
                                  builder: (context, snapshot) {
                                    final datos = snapshot.data;
                                    final activos = datos?.where((perro) => perro.estado == 'activo').toList() ?? const <PerroModel>[];
                                    final enCasa = activos.where((perro) => perro.enCasa).length;
                                    final enRefugio = activos.length - enCasa;
                                    final difuntos = datos?.where((perro) => perro.estado == 'inactivo').length;
                                    final adoptados = datos?.where((perro) => perro.estado == 'egresado' && perro.motivoEgreso == 'adopcion').length;
                                    final reencontrados = datos?.where((perro) => perro.estado == 'egresado' && perro.motivoEgreso == 'familia').length;
                                    final hoy = DateTime.now();
                                    final pendientes = datos == null
                                        ? 0
                                        : CalendarioGeneralController.construirResumen(datos, hoy, hoy: hoy).pendientes.length;
                                    final cuidado = activos.length == 1
                                        ? '1 perrito a nuestro cuidado'
                                        : '${activos.length} perritos a nuestro cuidado';
                                    return Column(
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
                                      ],
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
                  child: StreamBuilder<bool>(
                    stream: _perros.observarDesdeCache(),
                    builder: (context, snapshot) {
                      if (snapshot.data != true) return const SizedBox.shrink();
                      return Material(
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
                      );
                    },
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 8,
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
                    left: 60,
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
                          _etiquetaNombre(FirebaseAuth.instance.currentUser),
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
                    initialValue: TemaApp.modo.value,
                    onSelected: TemaApp.fijar,
                    icon: Icon(
                      TemaApp.modo.value == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode,
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
                      isLabelVisible: _noLeidas > 0,
                      label: Text(_noLeidas > 9 ? '9+' : '$_noLeidas'),
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

  const BotonMenu({
    super.key,
    required this.label,
    this.detalle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final oscuro = context.temaOscuro;
    final fondo = oscuro ? Color.lerp(color, Colors.black, 0.35)! : color;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: fondo,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 64),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: oscuro
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
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
                  ),
                  if (detalle != null)
                    Text(
                      detalle!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
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
  final nombre = usuario?.displayName?.trim() ?? '';
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
