import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Auth de la app. Los tests lo reemplazan por un mock, sin Firebase real.
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

/// Usuario de Firebase. Sin reintento: un error se muestra igual que el
/// StreamBuilder anterior (login), en vez de volver a suscribirse.
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
}, retry: (_, _) => null);

/// Sesión derivada de [authStateProvider].
///
/// Mientras el stream no emitió, usa `currentUser`, que es lo que las
/// pantallas leían antes y evita un frame de visitante.
final sessionProvider = Provider<Sesion>((ref) {
  final asyncUsuario = ref.watch(authStateProvider);
  final User? usuario;
  if (asyncUsuario.hasError) {
    usuario = null;
  } else if (asyncUsuario.hasValue) {
    usuario = asyncUsuario.value;
  } else if (asyncUsuario.isLoading) {
    usuario = ref.read(firebaseAuthProvider).currentUser;
  } else {
    usuario = null;
  }
  final hayUsuario = usuario != null;
  return Sesion(
    usuario: usuario,
    esInvitado: !hayUsuario,
    puedeEditar: hayUsuario,
  );
});

class Sesion {
  const Sesion({
    required this.usuario,
    required this.esInvitado,
    required this.puedeEditar,
  });

  final User? usuario;
  final bool esInvitado;
  final bool puedeEditar;
}
