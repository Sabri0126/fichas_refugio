import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../views/ficha_detalle_perro.dart';

/// Programa recordatorios diarios de medicación usando notificaciones locales.
class NotificacionesService {
  NotificacionesService._();
  static final NotificacionesService instance = NotificacionesService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _inicializado = false;
  bool _inicializando = false;
  GlobalKey<NavigatorState>? _navigatorKey;

  // Debe coincidir con el channelId usado en programarRecordatorios().
  static const _canalTratamientos = AndroidNotificationChannel(
    'tratamientos_diarios',
    'Recordatorios de tratamientos',
    description: 'Recordatorio diario para administrar medicación a los perros',
    importance: Importance.high,
  );

  Future<void> inicializar({GlobalKey<NavigatorState>? navigatorKey}) async {
    if (navigatorKey != null) _navigatorKey = navigatorKey;
    if (_inicializado || _inicializando) return;
    _inicializando = true;

    try {
      tz_data.initializeTimeZones();
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));

      const configuracionAndroid = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
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
    final idPerro = respuesta.payload;
    if (idPerro == null || idPerro.isEmpty) return;
    _navigatorKey?.currentState?.push(
      MaterialPageRoute(
        builder: (_) => FichaDetallePerro(idDocumento: idPerro),
      ),
    );
  }

  DateTime? _leerFecha(dynamic valor) {
    if (valor is Timestamp) return valor.toDate();
    if (valor is DateTime) return valor;
    if (valor is String) return DateTime.tryParse(valor);
    return null;
  }

  /// Cancela todas las notificaciones y reprograma una alarma diaria por cada tratamiento activo,
  /// respetando la hora guardada en `hora_recordatorio` (formato 'HH:mm').
  Future<void> programarRecordatorios(
    List<Map<String, dynamic>> perrosConTratamiento,
  ) async {
    await inicializar();
    await _plugin.cancelAll();

    final ahora = DateTime.now();

    for (final perro in perrosConTratamiento) {
      if (perro['estado'] == 'inactivo') continue;

      final idPerro =
          perro['id']?.toString() ?? perro['id_documento']?.toString() ?? '';
      final nombrePerro = perro['nombre']?.toString() ?? 'tu perrito';
      final tratamientos = List<dynamic>.from(perro['tratamientos'] ?? []);

      for (final tratamientoRaw in tratamientos) {
        final tratamiento = Map<String, dynamic>.from(tratamientoRaw as Map);
        final categoria = tratamiento['categoria']?.toString() ?? 'diario';
        final medicacion = tratamiento['medicacion']?.toString() ?? '';
        final idTratamiento = tratamiento['id']?.toString() ?? medicacion;
        final idNotificacion = '$idPerro-$idTratamiento'.hashCode & 0x7fffffff;

        if (categoria == 'diario') {
          if (tratamiento['activo'] == false) continue;
          if (medicacion.isEmpty) continue;

          final diasDuracion =
              int.tryParse(tratamiento['dias_duracion']?.toString() ?? '') ?? 0;
          final fechaInicio = _leerFecha(tratamiento['fecha_inicio']) ?? ahora;

          final partesHora =
              (tratamiento['hora_recordatorio']?.toString() ?? '09:00').split(
                ':',
              );
          final hora = partesHora.isNotEmpty
              ? int.tryParse(partesHora[0]) ?? 9
              : 9;
          final minuto = partesHora.length > 1
              ? int.tryParse(partesHora[1]) ?? 0
              : 0;

          const detallesNotificacion = NotificationDetails(
            android: AndroidNotificationDetails(
              'tratamientos_diarios',
              'Recordatorios de tratamientos',
              channelDescription:
                  'Recordatorio diario para administrar medicación a los perros',
              importance: Importance.high,
              priority: Priority.high,
            ),
          );

          if (diasDuracion == 0) {
            // Sin fecha de finalización (indefinido): se mantiene la alarma diaria recurrente.
            await _plugin.zonedSchedule(
              idNotificacion,
              'Medicación pendiente',
              'Toca darle $medicacion a $nombrePerro',
              _proximaInstancia(hora, minuto),
              detallesNotificacion,
              androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
              matchDateTimeComponents: DateTimeComponents.time,
              payload: idPerro,
            );
            continue;
          }

          // Tratamiento con fecha de fin: se programa una notificación puntual por cada día
          // restante para que las alarmas se detengan solas al llegar a fechaFin.
          final fechaFin = fechaInicio.add(Duration(days: diasDuracion));
          if (ahora.isAfter(fechaFin)) continue;

          final inicioBucle = ahora.isAfter(fechaInicio) ? ahora : fechaInicio;
          var fechaCursor = DateTime(
            inicioBucle.year,
            inicioBucle.month,
            inicioBucle.day,
          );
          var indiceDia = 0;

          while (!fechaCursor.isAfter(fechaFin)) {
            final horarioDelDia = DateTime(
              fechaCursor.year,
              fechaCursor.month,
              fechaCursor.day,
              hora,
              minuto,
            );
            if (horarioDelDia.isAfter(ahora)) {
              final idNotificacionDia =
                  '$idPerro-$idTratamiento-$indiceDia'.hashCode & 0x7fffffff;
              await _plugin.zonedSchedule(
                idNotificacionDia,
                'Medicación pendiente',
                'Toca darle $medicacion a $nombrePerro',
                tz.TZDateTime.from(horarioDelDia, tz.local),
                detallesNotificacion,
                androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
                matchDateTimeComponents: null,
                payload: idPerro,
              );
            }
            fechaCursor = fechaCursor.add(const Duration(days: 1));
            indiceDia++;
          }
          continue;
        }

        // Dosis única / Visita veterinaria: alarma única a futuro (no recurrente).
        final fechaProximoRecordatorio = _leerFecha(
          tratamiento['fecha_proximo_recordatorio'],
        );
        if (fechaProximoRecordatorio == null) continue;
        if (!fechaProximoRecordatorio.isAfter(ahora)) continue;

        final esVisitaVet = categoria == 'veterinaria';
        final titulo = esVisitaVet
            ? 'Visita veterinaria'
            : 'Dosis única pendiente';
        final cuerpo = esVisitaVet
            ? 'Recordatorio: visita veterinaria para $nombrePerro'
            : 'Recordatorio: aplicar $medicacion a $nombrePerro';

        await _plugin.zonedSchedule(
          idNotificacion,
          titulo,
          cuerpo,
          tz.TZDateTime.from(fechaProximoRecordatorio, tz.local),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'tratamientos_diarios',
              'Recordatorios de tratamientos',
              channelDescription:
                  'Recordatorio diario para administrar medicación a los perros',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: null,
          payload: idPerro,
        );
      }
    }
  }

  // Usa un DateTime local (constructor de Dart) para que la instancia absoluta
  // resultante corresponda a la hora:minuto pedidos en la zona horaria del dispositivo.
  tz.TZDateTime _proximaInstancia(int hora, int minuto) {
    final ahora = DateTime.now();
    var horarioLocal = DateTime(
      ahora.year,
      ahora.month,
      ahora.day,
      hora,
      minuto,
    );
    if (horarioLocal.isBefore(ahora)) {
      horarioLocal = horarioLocal.add(const Duration(days: 1));
    }
    return tz.TZDateTime.from(horarioLocal, tz.local);
  }
}
