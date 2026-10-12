import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../controllers/historial_notificaciones_controller.dart';
import '../services/mensajeria_service.dart';
import '../services/notificaciones_service.dart';
import '../theme/app_colors.dart';
import 'pantalla_notificaciones.dart';
import 'pantalla_perros.dart';

class PantallaMenu extends StatefulWidget {
  const PantallaMenu({super.key});

  @override
  State<PantallaMenu> createState() => _PantallaMenuState();
}

class _PantallaMenuState extends State<PantallaMenu> {
  final HistorialNotificacionesController _historial = HistorialNotificacionesController();
  StreamSubscription<int>? _badge;
  int _noLeidas = 0;

  @override
  void initState() {
    super.initState();
    final esInvitado = FirebaseAuth.instance.currentUser == null;
    if (!esInvitado) {
      unawaited(MensajeriaService.instance.registrarDispositivo().catchError((Object _) {}));
      unawaited(NotificacionesService.instance.migrarAlarmasLocales());
      _badge = _historial.observarNoLeidas().listen((cantidad) {
        if (!mounted) return;
        setState(() => _noLeidas = cantidad);
      });
    }
  }

  @override
  void dispose() {
    _badge?.cancel();
    super.dispose();
  }

  Future<void> _abrirNotificaciones() {
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PantallaNotificaciones()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool esInvitado = FirebaseAuth.instance.currentUser == null;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Reemplazá NetworkImage('URL_DE_TU_IMAGEN') por AssetImage('assets/fondo.jpg') si usás un asset local
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
                  Colors.black.withValues(alpha: 0.25),
                  Colors.black.withValues(alpha: 0.72),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Stack(
              children: [
                Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.pets, size: 72, color: Colors.white),
                    const SizedBox(height: 16),
                    Text(
                      'Refugio Milagros de Amor',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontSize: 32,
                        color: Colors.white,
                      ),
                    ),
                const SizedBox(height: 60),
                _MenuButton(
                  label: 'Perritos del refugio',
                  icon: Icons.favorite,
                  color: AppColors.terracota,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PantallaPerros(seccion: SeccionPerros.activos)),
                  ),
                ),
                const SizedBox(height: 20),
                _MenuButton(
                  label: 'Difuntos',
                  icon: Icons.local_florist,
                  color: AppColors.navy,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PantallaPerros(seccion: SeccionPerros.difuntos)),
                  ),
                ),
                const SizedBox(height: 20),
                _MenuButton(
                  label: 'Adoptados y reencontrados',
                  icon: Icons.favorite_rounded,
                  color: AppColors.activoTexto,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PantallaPerros(seccion: SeccionPerros.egresados)),
                  ),
                ),
              ],
            ),
          ),
        ),
                if (!esInvitado)
                  Positioned(
                    top: 0,
                    right: 8,
                    child: Badge(
                      isLabelVisible: _noLeidas > 0,
                      label: Text(_noLeidas > 9 ? '9+' : '$_noLeidas'),
                      child: IconButton(
                        tooltip: 'Notificaciones',
                        onPressed: _abrirNotificaciones,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(width: 44, height: 44),
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

class _MenuButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MenuButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
