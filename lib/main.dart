import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'providers/auth_providers.dart';
import 'providers/theme_mode_provider.dart';
import 'services/mensajeria_service.dart';
import 'services/notificaciones_service.dart';
import 'theme/app_theme.dart';
import 'views/pantalla_bloqueo.dart';
import 'views/pantalla_login.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Guarda el payload de una notificación que abrió la app en frío,
/// hasta que la pantalla de bloqueo pueda navegar tras la autenticación.
class EstadoNotificacion {
  static String? payloadPendiente;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  LicenseRegistry.addLicense(() async* {
    final licencia = await rootBundle.loadString('google_fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(<String>['google_fonts'], licencia);
  });
  await NotificacionesService.instance.inicializar(navigatorKey: navigatorKey);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final prefs = await SharedPreferences.getInstance();
  await _capturarNotificacionDeInicio();
  MensajeriaService.instance.conectar(
    push: FuentePushFirebase(FirebaseMessaging.instance),
  );
  final idPush = await MensajeriaService.instance.prepararToques();
  if (idPush != null && idPush.isNotEmpty) {
    EstadoNotificacion.payloadPendiente = idPush;
  }
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const MyApp(),
    ),
  );
}

Future<void> _capturarNotificacionDeInicio() async {
  final NotificationAppLaunchDetails? launchDetails =
      await FlutterLocalNotificationsPlugin().getNotificationAppLaunchDetails();

  if (launchDetails?.didNotificationLaunchApp ?? false) {
    EstadoNotificacion.payloadPendiente =
        launchDetails!.notificationResponse?.payload;
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modo = ref.watch(themeModeProvider);
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
      theme: buildAppTheme(),
      darkTheme: buildAppTheme(oscuro: true),
      themeMode: modo,
      home: const _PuertaAuth(),
    );
  }
}

/// Puerta de la app: cargando, usuario o login.
class _PuertaAuth extends ConsumerWidget {
  const _PuertaAuth();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    if (auth.isLoading && !auth.hasValue) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (auth.value != null) {
      return const PantallaBloqueo();
    }
    return const PantallaLogin();
  }
}
