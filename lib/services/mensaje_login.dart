/// Mensaje de UI según el código de [FirebaseAuthException].
String mensajeErrorLogin(String code) {
  switch (code) {
    case 'user-not-found':
      return 'No existe una cuenta con ese email.';
    case 'wrong-password':
    case 'invalid-credential':
      return 'Email o contraseña incorrectos.';
    case 'invalid-email':
      return 'El email no es válido.';
    case 'too-many-requests':
      return 'Demasiados intentos. Intentá más tarde.';
    case 'network-request-failed':
      return 'Sin conexión. Revisá tu internet e intentá de nuevo.';
    default:
      return 'Error al iniciar sesión.';
  }
}
