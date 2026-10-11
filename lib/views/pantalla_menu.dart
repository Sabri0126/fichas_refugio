import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'pantalla_perros.dart';

class PantallaMenu extends StatelessWidget {
  const PantallaMenu({super.key});

  @override
  Widget build(BuildContext context) {
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
            child: Center(
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
