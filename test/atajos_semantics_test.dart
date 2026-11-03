import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:fichas_refugio/models/perro_model.dart';
import 'package:fichas_refugio/providers/auth_providers.dart';
import 'package:fichas_refugio/providers/firestore_providers.dart';
import 'package:fichas_refugio/providers/perros_providers.dart';
import 'package:fichas_refugio/providers/theme_mode_provider.dart';
import 'package:fichas_refugio/services/fotos_service.dart';
import 'package:fichas_refugio/theme/app_theme.dart';
import 'package:fichas_refugio/views/pantalla_menu.dart';
import 'package:fichas_refugio/views/pantalla_perros.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<void> montarPerros(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
          fotosServiceProvider.overrideWithValue(FotosService(almacen: AlmacenFotosMemoria())),
          firebaseAuthProvider.overrideWithValue(
            MockFirebaseAuth(
              signedIn: true,
              mockUser: MockUser(uid: 'staff', email: 'staff@refugio.test'),
            ),
          ),
          perrosProvider.overrideWithValue(
            AsyncData([
              PerroModel(
                id: 'p1',
                nombre: 'Luna',
                estado: 'activo',
                sexo: 'hembra',
                edad: 3,
                enCasa: true,
              ),
            ]),
          ),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const PantallaPerros(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Ctrl+F lleva el foco a la búsqueda en Windows', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await montarPerros(tester);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      final editable = tester.widgetList<EditableText>(find.byType(EditableText)).first;
      expect(editable.focusNode.hasFocus, isTrue);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Semantics de BotonMenu incluye label y detalle', (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: BotonMenu(
              label: 'Perritos del refugio',
              detalle: '4 activos',
              icon: Icons.pets,
              color: const Color(0xFF2E6B44),
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Perritos del refugio. 4 activos'), findsOneWidget);
    } finally {
      handle.dispose();
    }
  });

  testWidgets('Semantics de la tarjeta resume nombre, sexo, edad y estado', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final handle = tester.ensureSemantics();
    try {
      await montarPerros(tester);
      expect(
        find.bySemanticsLabel(RegExp(r'Luna, hembra, .*en casa')),
        findsOneWidget,
      );
    } finally {
      handle.dispose();
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
