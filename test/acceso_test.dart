import 'package:fichas_refugio/providers/auth_providers.dart';
import 'package:fichas_refugio/providers/mensajeria_providers.dart';
import 'package:fichas_refugio/services/mensaje_login.dart';
import 'package:fichas_refugio/services/mensajeria_service.dart';
import 'package:fichas_refugio/views/pantalla_bloqueo.dart';
import 'package:fichas_refugio/views/pantalla_login.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('mensajeErrorLogin', () {
    test('invalid-credential y wrong-password muestran email o contraseña', () {
      expect(mensajeErrorLogin('invalid-credential'), 'Email o contraseña incorrectos.');
      expect(mensajeErrorLogin('wrong-password'), 'Email o contraseña incorrectos.');
    });

    test('network-request-failed muestra sin conexión', () {
      expect(
        mensajeErrorLogin('network-request-failed'),
        'Sin conexión. Revisá tu internet e intentá de nuevo.',
      );
    });

    test('otros códigos conocidos', () {
      expect(mensajeErrorLogin('user-not-found'), 'No existe una cuenta con ese email.');
      expect(mensajeErrorLogin('invalid-email'), 'El email no es válido.');
      expect(mensajeErrorLogin('too-many-requests'), 'Demasiados intentos. Intentá más tarde.');
      expect(mensajeErrorLogin('otro'), 'Error al iniciar sesión.');
    });
  });

  testWidgets('el login no recorta la contraseña', (tester) async {
    final auth = AuthEspia(
      signedIn: false,
      mockUser: MockUser(uid: 'u1', email: 'a@refugio.test'),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [firebaseAuthProvider.overrideWithValue(auth)],
        child: const MaterialApp(home: PantallaLogin()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'a@refugio.test');
    await tester.enterText(find.byType(TextField).at(1), ' ab ');
    await tester.tap(find.text('Ingresar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(auth.ultimaPassword, ' ab ');
  });

  testWidgets('el login muestra el texto de contraseña olvidada', (tester) async {
    final auth = MockFirebaseAuth(signedIn: false);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [firebaseAuthProvider.overrideWithValue(auth)],
        child: const MaterialApp(home: PantallaLogin()),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('¿Olvidaste la contraseña? Pedísela a la administradora.'),
      findsOneWidget,
    );
  });

  testWidgets('sin biometría el bloqueo ofrece contraseña y cerrar sesión', (tester) async {
    final auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'u1', email: 'a@refugio.test'),
    );
    final local = FakeLocalAuth(disponible: false);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(auth),
          localAuthProvider.overrideWithValue(local),
          mensajeriaServiceProvider.overrideWithValue(MensajeriaService()),
        ],
        child: const MaterialApp(home: PantallaBloqueo()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.text('Este dispositivo no soporta autenticación biométrica.'), findsOneWidget);
    expect(find.text('Ingresar con contraseña'), findsOneWidget);
    expect(find.text('Cerrar sesión'), findsOneWidget);

    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(auth.currentUser, isNull);
    expect(find.byType(PantallaLogin), findsOneWidget);
  });
}

class AuthEspia extends MockFirebaseAuth {
  AuthEspia({super.signedIn, super.mockUser});

  String? ultimaPassword;

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    ultimaPassword = password;
    throw FirebaseAuthException(code: 'too-many-requests');
  }
}

class FakeLocalAuth extends LocalAuthentication {
  FakeLocalAuth({this.disponible = true});

  final bool disponible;

  @override
  Future<bool> get canCheckBiometrics async => disponible;

  @override
  Future<bool> isDeviceSupported() async => disponible;
}
