import 'dart:async';

import 'package:fichas_refugio/providers/auth_providers.dart';
import 'package:fichas_refugio/providers/theme_mode_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('sesión', () {
    test('sin usuario es invitado y no puede editar', () async {
      final auth = MockFirebaseAuth(signedIn: false);
      final container = _contenedorAuth(auth);

      expect(container.read(sessionProvider).usuario, isNull);
      expect(container.read(sessionProvider).esInvitado, isTrue);
      expect(container.read(sessionProvider).puedeEditar, isFalse);
    });

    test('con usuario logueado puede editar', () async {
      const uid = 'usuario-1';
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: uid, email: 'a@refugio.test'),
      );
      final container = _contenedorAuth(auth);

      await auth.signInWithEmailAndPassword(
        email: 'a@refugio.test',
        password: 'clave',
      );
      await pumpEventQueue();

      final sesion = container.read(sessionProvider);
      expect(container.read(authStateProvider).value?.uid, uid);
      expect(sesion.usuario?.uid, uid);
      expect(sesion.esInvitado, isFalse);
      expect(sesion.puedeEditar, isTrue);
    });

    test('el cierre y el inicio de sesión actualizan la sesión', () async {
      final auth = MockFirebaseAuth(
        signedIn: false,
        mockUser: MockUser(uid: 'usuario-2', email: 'b@refugio.test'),
      );
      final container = _contenedorAuth(auth);

      expect(container.read(sessionProvider).esInvitado, isTrue);

      await auth.signInWithEmailAndPassword(
        email: 'b@refugio.test',
        password: 'clave',
      );
      await pumpEventQueue();

      expect(container.read(authStateProvider).hasValue, isTrue);
      expect(container.read(sessionProvider).puedeEditar, isTrue);
      expect(container.read(sessionProvider).usuario?.uid, 'usuario-2');
      expect(container.read(sessionProvider).esInvitado, isFalse);

      await auth.signOut();
      await pumpEventQueue();

      expect(container.read(authStateProvider).hasValue, isTrue);
      expect(container.read(authStateProvider).value, isNull);
      expect(container.read(sessionProvider).usuario, isNull);
      expect(container.read(sessionProvider).esInvitado, isTrue);
      expect(container.read(sessionProvider).puedeEditar, isFalse);
    });

    test('un error de auth, con o sin usuario previo, deja la sesión como visitante', () async {
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'usuario-3', email: 'c@refugio.test'),
      );
      final sinValor = ProviderContainer(
        overrides: [
          firebaseAuthProvider.overrideWithValue(auth),
          authStateProvider.overrideWith((ref) => Stream<User?>.error(StateError('auth'))),
        ],
      );
      addTearDown(sinValor.dispose);
      sinValor.listen(sessionProvider, (_, _) {});
      await pumpEventQueue();

      expect(sinValor.read(authStateProvider).hasError, isTrue);
      expect(sinValor.read(sessionProvider).usuario, isNull);
      expect(sinValor.read(sessionProvider).esInvitado, isTrue);

      final cambios = StreamController<User?>();
      addTearDown(cambios.close);
      final conValor = ProviderContainer(
        overrides: [
          firebaseAuthProvider.overrideWithValue(auth),
          authStateProvider.overrideWith((ref) => cambios.stream),
        ],
      );
      addTearDown(conValor.dispose);
      conValor.listen(sessionProvider, (_, _) {});
      cambios.add(auth.currentUser);
      await pumpEventQueue();
      expect(conValor.read(sessionProvider).puedeEditar, isTrue);

      cambios.addError(StateError('auth'));
      await pumpEventQueue();

      expect(conValor.read(authStateProvider).hasError, isTrue);
      expect(conValor.read(authStateProvider).hasValue, isTrue);
      expect(conValor.read(sessionProvider).usuario, isNull);
      expect(conValor.read(sessionProvider).esInvitado, isTrue);
      expect(conValor.read(sessionProvider).puedeEditar, isFalse);
    });
  });

  group('tema', () {
    test('lee el modo guardado y lo vuelve a guardar', () async {
      final primero = await _contenedorTema({'tema_modo': 'dark'});
      expect(primero.read(themeModeProvider), ThemeMode.dark);

      await primero.read(themeModeProvider.notifier).fijar(ThemeMode.light);
      expect(primero.read(themeModeProvider), ThemeMode.light);

      final prefs = primero.read(sharedPreferencesProvider);
      expect(prefs.getString('tema_modo'), 'light');

      final segundo = _contenedorConPrefs(prefs);
      expect(segundo.read(themeModeProvider), ThemeMode.light);
    });

    test('sin valor o con system queda en claro', () async {
      final vacio = await _contenedorTema({});
      expect(vacio.read(themeModeProvider), ThemeMode.light);

      final sistema = await _contenedorTema({'tema_modo': 'system'});
      expect(sistema.read(themeModeProvider), ThemeMode.light);
    });
  });
}

ProviderContainer _contenedorAuth(MockFirebaseAuth auth) {
  final container = ProviderContainer(
    overrides: [firebaseAuthProvider.overrideWithValue(auth)],
  );
  addTearDown(container.dispose);
  container.listen(sessionProvider, (_, _) {});
  return container;
}

Future<ProviderContainer> _contenedorTema(Map<String, Object> valores) async {
  SharedPreferences.setMockInitialValues(valores);
  final prefs = await SharedPreferences.getInstance();
  return _contenedorConPrefs(prefs);
}

ProviderContainer _contenedorConPrefs(SharedPreferences prefs) {
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}
