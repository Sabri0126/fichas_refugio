import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';
import '../providers/mensajeria_providers.dart';
import 'nombre_usuario.dart';

/// Cierra la sesión del staff: saca el dispositivo, olvida el nombre y sale de Auth.
///
/// [auth.signOut] corre siempre, aunque fallen el desregistro o el olvido del nombre.
Future<void> cerrarSesion(WidgetRef ref) {
  final mensajeria = ref.read(mensajeriaServiceProvider);
  final auth = ref.read(firebaseAuthProvider);
  return cerrarSesionCon(
    desregistrar: mensajeria.desregistrarDispositivo,
    olvidar: NombreUsuario.olvidar,
    auth: auth,
  );
}

/// Variante testeable de [cerrarSesion].
Future<void> cerrarSesionCon({
  required Future<void> Function() desregistrar,
  required void Function() olvidar,
  required FirebaseAuth auth,
}) async {
  try {
    await desregistrar();
  } catch (_) {}
  try {
    olvidar();
  } catch (_) {}
  await auth.signOut();
}
