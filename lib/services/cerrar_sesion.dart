import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';
import '../providers/mensajeria_providers.dart';
import 'nombre_usuario.dart';

/// Cierra la sesión del staff: saca el dispositivo, olvida el nombre y sale de Auth.
Future<void> cerrarSesion(WidgetRef ref) async {
  final mensajeria = ref.read(mensajeriaServiceProvider);
  final auth = ref.read(firebaseAuthProvider);
  await mensajeria.desregistrarDispositivo();
  NombreUsuario.olvidar();
  await auth.signOut();
}
