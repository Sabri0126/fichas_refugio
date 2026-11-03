import 'package:fichas_refugio/services/cerrar_sesion.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('signOut corre aunque fallen el desregistro y el olvido del nombre', () async {
    final auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'u1', email: 'a@refugio.test'),
    );
    expect(auth.currentUser, isNotNull);

    await cerrarSesionCon(
      desregistrar: () async => throw StateError('sin red'),
      olvidar: () => throw StateError('prefs'),
      auth: auth,
    );

    expect(auth.currentUser, isNull);
  });

  test('sin errores llama al desregistro, olvida el nombre y cierra Auth', () async {
    final auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'u1', email: 'a@refugio.test'),
    );
    var desregistro = 0;
    var olvido = 0;

    await cerrarSesionCon(
      desregistrar: () async {
        desregistro += 1;
      },
      olvidar: () {
        olvido += 1;
      },
      auth: auth,
    );

    expect(desregistro, 1);
    expect(olvido, 1);
    expect(auth.currentUser, isNull);
  });
}
