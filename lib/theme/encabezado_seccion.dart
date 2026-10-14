import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Título de un grupo de la ficha o del formulario: ícono, texto y
/// una marca terracota debajo. Sobre el fondo de la pantalla usa un
/// color que se lee también en modo oscuro.
class EncabezadoSeccion extends StatelessWidget {
  final String titulo;
  final IconData icono;
  final int? cantidad;
  final TextScaler? textScaler;
  final bool subrayado;

  const EncabezadoSeccion({
    super.key,
    required this.titulo,
    required this.icono,
    this.cantidad,
    this.textScaler,
    this.subrayado = true,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final color = context.paleta.lienzo;
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icono, size: 20, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    titulo,
                    textScaler: textScaler,
                    style: textTheme.headlineMedium?.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
                if (cantidad != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$cantidad',
                      textScaler: textScaler,
                      style: textTheme.labelMedium?.copyWith(color: color),
                    ),
                  ),
                ],
              ],
            ),
            if (subrayado) ...[
              const SizedBox(height: 8),
              Container(
                height: 3,
                width: 40,
                decoration: BoxDecoration(
                  color: AppColors.terracota,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
