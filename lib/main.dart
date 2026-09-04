import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'services/notificaciones_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'views/pantalla_login.dart';
import 'views/pantalla_bloqueo.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Guarda el payload de una notificación que abrió la app en frío,
/// hasta que la pantalla de bloqueo pueda navegar tras la autenticación.
class EstadoNotificacion {
  static String? payloadPendiente;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificacionesService.instance.inicializar(navigatorKey: navigatorKey);
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await _capturarNotificacionDeInicio();
  runApp(const MyApp());
}

Future<void> _capturarNotificacionDeInicio() async {
  final NotificationAppLaunchDetails? launchDetails =
      await FlutterLocalNotificationsPlugin().getNotificationAppLaunchDetails();

  if (launchDetails?.didNotificationLaunchApp ?? false) {
    EstadoNotificacion.payloadPendiente = launchDetails!.notificationResponse?.payload;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const Color _fondoArena = Color.fromARGB(255, 236, 223, 193);
  static const Color _terracota = Color.fromARGB(255, 197, 90, 68);
  static const Color _azulMarino = Color.fromARGB(255, 47, 67, 99);
  static const Color _grisOscuro = Color(0xFF191919);

  @override
  Widget build(BuildContext context) {
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10.0),
      borderSide: BorderSide(color: _azulMarino.withValues(alpha: 0.35)),
    );

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Fichas Refugio',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es')],
      locale: const Locale('es'),
      theme: ThemeData(
        colorScheme: const ColorScheme.light(
          primary: _azulMarino,
          secondary: _terracota,
          surface: Colors.white,
          onPrimary: _fondoArena,
          onSecondary: _grisOscuro,
          onSurface: _grisOscuro,
        ),
        scaffoldBackgroundColor: _fondoArena,
        appBarTheme: const AppBarTheme(
          backgroundColor: _azulMarino,
          foregroundColor: _fondoArena,
          iconTheme: IconThemeData(color: _fondoArena),
          titleTextStyle: TextStyle(
            color: _fondoArena,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: _grisOscuro),
          bodyMedium: TextStyle(color: _grisOscuro),
          titleLarge: TextStyle(color: _grisOscuro),
        ).apply(bodyColor: _grisOscuro, displayColor: _grisOscuro),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.8),
          border: inputBorder,
          enabledBorder: inputBorder,
          focusedBorder: inputBorder.copyWith(
            borderSide: const BorderSide(color: _azulMarino, width: 1.5),
          ),
        ),
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) {
            return const PantallaBloqueo();
          }
          return const PantallaLogin();
        },
      ),
    );
  }
}
