part of '../ficha_detalle_perro.dart';

class _OpcionMenu extends StatelessWidget {
  final IconData icono;
  final String texto;

  const _OpcionMenu({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icono, size: 22, color: context.paleta.texto),
        const SizedBox(width: 12),
        Expanded(child: Text(texto)),
      ],
    );
  }
}
