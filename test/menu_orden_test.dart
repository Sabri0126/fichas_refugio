import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:fichas_refugio/models/perro_model.dart';
import 'package:fichas_refugio/providers/auth_providers.dart';
import 'package:fichas_refugio/providers/calendario_providers.dart';
import 'package:fichas_refugio/providers/firestore_providers.dart';
import 'package:fichas_refugio/providers/mensajeria_providers.dart';
import 'package:fichas_refugio/providers/notificaciones_providers.dart';
import 'package:fichas_refugio/providers/perros_providers.dart';
import 'package:fichas_refugio/providers/theme_mode_provider.dart';
import 'package:fichas_refugio/services/mensajeria_service.dart';
import 'package:fichas_refugio/theme/app_theme.dart';
import 'package:fichas_refugio/views/pantalla_menu.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

PerroModel _incompleto() {
  return PerroModel(
    id: 'p1',
    nombre: 'Luna',
    estado: 'activo',
  );
}

PerroModel _completo() {
  return PerroModel(
    id: 'p2',
    nombre: 'Canelo',
    estado: 'activo',
    edad: 4,
    fechaIngreso: DateTime(2020, 1, 1),
    fotoPerfil: 'https://ejemplo.test/foto.jpg',
  );
}

Future<void> _montarMenu(
  WidgetTester tester, {
  required bool invitado,
  required List<PerroModel> perros,
}) async {
  SharedPreferences.setMockInitialValues({'alarmas_locales_migradas': true});
  final prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
        relojProvider.overrideWithValue(() => DateTime(2026, 6, 15)),
        perrosProvider.overrideWithValue(AsyncData(perros)),
        notificacionesNoLeidasProvider.overrideWithValue(0),
        mensajeriaServiceProvider.overrideWithValue(MensajeriaService()),
        firebaseAuthProvider.overrideWithValue(
          invitado
              ? MockFirebaseAuth(signedIn: false)
              : MockFirebaseAuth(
                  signedIn: true,
                  mockUser: MockUser(
                    uid: 'staff',
                    email: 'staff@refugio.test',
                    displayName: 'Sabri',
                  ),
                ),
        ),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: const PantallaMenu(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('el menú de staff ordena los botones de más usado a menos usado', (tester) async {
    await _montarMenu(tester, invitado: false, perros: [_incompleto(), _completo()]);

    final etiquetas = [
      'Perritos del refugio',
      'Calendario general',
      'Fichas con datos faltantes (1)',
      'Adoptados y reencontrados',
      'Difuntos',
      'Reportes',
      'Veterinarias y contactos',
    ];
    for (final etiqueta in etiquetas) {
      expect(find.text(etiqueta), findsOneWidget);
    }

    final ys = [
      for (final etiqueta in etiquetas) tester.getTopLeft(find.text(etiqueta)).dy,
    ];
    for (var i = 1; i < ys.length; i++) {
      expect(ys[i], greaterThan(ys[i - 1]), reason: '${etiquetas[i]} debajo de ${etiquetas[i - 1]}');
    }
  });

  testWidgets('el visitante no ve fichas incompletas, reportes ni veterinarias', (tester) async {
    await _montarMenu(tester, invitado: true, perros: [_incompleto()]);

    expect(find.textContaining('Fichas con datos faltantes'), findsNothing);
    expect(find.text('Reportes'), findsNothing);
    expect(find.text('Veterinarias y contactos'), findsNothing);
    expect(find.text('Perritos del refugio'), findsOneWidget);
    expect(find.text('Calendario general'), findsOneWidget);
  });
}
