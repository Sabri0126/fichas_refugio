import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/dosis_avisada.dart';
import '../theme/app_colors.dart';
import '../views/ficha_detalle_perro.dart';

/// Muestra avisos locales y abre la ficha cuando se toca uno.
class NotificacionesService {
  NotificacionesService._();
  static final NotificacionesService instance = NotificacionesService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _inicializado = false;
  bool _inicializando = false;
  GlobalKey<NavigatorState>? _navigatorKey;

  static const _canalTratamientos = AndroidNotificationChannel(
    'tratamientos_diarios',
    'Recordatorios de tratamientos',
    description: 'Recordatorio diario para administrar medicación a los perros',
    importance: Importance.high,
  );

  static const _claveMigracion = 'alarmas_locales_migradas';

  Future<void> inicializar({GlobalKey<NavigatorState>? navigatorKey}) async {
    if (navigatorKey != null) _navigatorKey = navigatorKey;
    if (_inicializado || _inicializando) return;
    _inicializando = true;

    try {
      tz_data.initializeTimeZones();
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));

      const configuracionAndroid = AndroidInitializationSettings(
        'ic_stat_huella',
      );
      const configuracionWindows = WindowsInitializationSettings(
        appName: 'Fichas Refugio',
        appUserModelId: 'com.fichasrefugio.app',
        guid: '10de3825-9a9f-4245-8e9e-7d6eb8a601fb',
      );
      const configuracionInicializacion = InitializationSettings(
        android: configuracionAndroid,
        windows: configuracionWindows,
      );

      await _plugin.initialize(
        configuracionInicializacion,
        onDidReceiveNotificationResponse: _alRecibirRespuestaNotificacion,
      );

      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      // Se crea explícitamente con importancia alta para que Samsung/Android 13+
      // no lo hereden con una importancia distinta si ya existía de una versión previa.
      await androidPlugin?.createNotificationChannel(_canalTratamientos);

      final permisoNotificaciones = await androidPlugin
          ?.requestNotificationsPermission();
      final permisoAlarmasExactas = await androidPlugin
          ?.requestExactAlarmsPermission();
      if (permisoNotificaciones == false || permisoAlarmasExactas == false) {
        // El usuario denegó el permiso: sin esto, las notificaciones fallan
        // en silencio (no lanza excepción) en Android 13+ y en Samsung.
        // ignore: avoid_print
        print(
          'NotificacionesService: permisos denegados '
          '(notificaciones=$permisoNotificaciones, alarmasExactas=$permisoAlarmasExactas)',
        );
      }

      _inicializado = true;
    } finally {
      _inicializando = false;
    }
  }

  void _alRecibirRespuestaNotificacion(NotificationResponse respuesta) {
    abrirDesdePayload(respuesta.payload);
  }

  void abrirDesdePayload(String? payload) {
    final aviso = AvisoFicha.desdePayload(payload);
    if (aviso == null) return;
    _navigatorKey?.currentState?.push(
      MaterialPageRoute(
        builder: (_) => FichaDetallePerro(idDocumento: aviso.idPerro, dosisAvisada: aviso.dosis),
      ),
    );
  }

  Future<void> mostrarAhora({
    required String titulo,
    required String cuerpo,
    String? payload,
  }) async {
    await inicializar();
    const detalles = NotificationDetails(
      android: AndroidNotificationDetails(
        'tratamientos_diarios',
        'Recordatorios de tratamientos',
        channelDescription: 'Recordatorio diario para administrar medicación a los perros',
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_stat_huella',
        color: AppColors.terracota,
      ),
    );
    final id = DateTime.now().millisecondsSinceEpoch.remainder(0x7fffffff);
    await _plugin.show(id, titulo, cuerpo, detalles, payload: payload);
  }

  Future<void> migrarAlarmasLocales() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_claveMigracion) == true) return;
    await inicializar();
    await _plugin.cancelAll();
    await prefs.setBool(_claveMigracion, true);
  }
}
