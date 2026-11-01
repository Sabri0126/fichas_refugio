import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Misma condición que usaba el perfil de usuario en Windows.
bool get esWindows => !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

/// Teléfono o tablet Android. En Windows y en web queda en falso.
bool get esAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// Navy en claro. En Windows oscuro, el lienzo claro para que el ícono se lea.
Color colorIconoSeccion(BuildContext context) {
  if (esWindows && context.temaOscuro) return context.paleta.lienzo;
  return AppColors.navy;
}

/// En Windows limita el ancho y centra. En Android y web devuelve [child].
class AnchoVentana extends StatelessWidget {
  final Widget child;
  final double maximo;

  const AnchoVentana({super.key, required this.child, this.maximo = 960});

  @override
  Widget build(BuildContext context) {
    if (!esWindows) return child;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maximo),
        child: child,
      ),
    );
  }
}
