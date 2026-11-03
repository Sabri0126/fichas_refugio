import 'package:flutter/material.dart';

class SeccionIndice {
  final String etiqueta;
  final GlobalKey clave;

  const SeccionIndice({required this.etiqueta, required this.clave});
}

/// Chips de acceso rápido. Solo muestra las secciones recibidas.
class IndiceSecciones extends StatelessWidget {
  final List<SeccionIndice> secciones;
  final EdgeInsetsGeometry padding;

  const IndiceSecciones({
    super.key,
    required this.secciones,
    this.padding = const EdgeInsets.only(bottom: 12),
  });

  Future<void> _ir(GlobalKey clave) async {
    final contexto = clave.currentContext;
    if (contexto == null) return;
    await Scrollable.ensureVisible(
      contexto,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      alignment: 0.05,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (secciones.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: padding,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final seccion in secciones)
            ActionChip(
              label: Text(seccion.etiqueta),
              onPressed: () => _ir(seccion.clave),
            ),
        ],
      ),
    );
  }
}
