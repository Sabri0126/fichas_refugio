# 01 — Arquitectura

Contexto para un rediseño visual. No cambia lógica. Generado leyendo el código del repo `fichas_refugio`. Si algo no está en el código, dice NO EXISTE o NO ENCONTRADO.

## 1. Qué hace la app

App Flutter del refugio **Refugio Milagros de Amor** (`lib/views/pantalla_menu.dart`). Gestiona fichas de perros en Firestore.

- Login con email y contraseña (Firebase Auth) o entrada como visitante sin cuenta.
- Tras un login real, una pantalla pide biometría o PIN (`local_auth`) antes del menú.
- Menú con dos listas: perros activos ("Perritos del refugio") y fallecidos ("Difuntos").
- Cada ficha tiene foto de perfil, galería, datos (sexo, edad, castrado, en casa, fechas), historia en Markdown, familiares vinculados y ficha médica.
- La ficha médica mezcla texto libre, tratamientos diarios (dosis de hoy y de los 4 días anteriores) y eventos puntuales (dosis única, higiene, evento médico, veterinaria).
- El historial médico es un bottom sheet con calendario (`table_calendar`).
- Hay búsqueda por nombre y filtros Todos / Refugio / En casa.
- Recordatorios locales de medicación (`flutter_local_notifications`). Al tocarlos se abre la ficha de ese perro.
- El visitante puede ver fichas. No puede crear, editar, borrar, reordenar fotos ni marcar dosis.

No hay módulo de usuarios dentro de la app (solo Firebase Auth). No hay adopción, turnos ni inventario aparte de lo médico.

## 2. Versiones y dependencias

Salida de `flutter --version` (esta máquina):

- Flutter 3.44.0, channel stable, revision 559ffa3f75 (2026-05-15)
- Dart 3.12.0
- DevTools 2.57.0

`pubspec.yaml`: `version: 1.0.0+1`, SDK `sdk: ^3.12.0`, `publish_to: 'none'`.

### dependencies

| Paquete | Versión en pubspec | Uso en esta app |
|---|---|---|
| flutter | sdk | UI |
| flutter_localizations | sdk | `Locale('es')` en `MaterialApp` |
| cupertino_icons | ^1.0.8 | Íconos iOS. NO ENCONTRADO un uso directo en `lib/` |
| firebase_core | ^4.12.1 | Arranque de Firebase |
| cloud_firestore | ^6.7.1 | Base de datos. Colección `perros` |
| firebase_storage | ^13.4.6 | Fotos: `fotos_perfil/` y `galeria_perros/` |
| firebase_auth | ^6.5.7 | Login email/contraseña. El visitante es `currentUser == null` |
| image_picker | ^1.2.3 | Elegir foto de cámara o galería del dispositivo |
| image_cropper | ^12.2.1 | Recorte antes de subir |
| flutter_markdown | ^0.7.7+1 | Render de historia y ficha médica |
| http | ^1.6.0 | Descargar una imagen de red para recortarla |
| path_provider | ^2.1.6 | Archivo temporal de ese recorte |
| local_auth | ^3.0.2 | Biometría / PIN en `pantalla_bloqueo.dart` |
| flutter_local_notifications | ^19.4.2 | Recordatorios |
| timezone | ^0.10.1 | Zona horaria de las alarmas |
| flutter_timezone | ^4.1.1 | Zona local del dispositivo |
| table_calendar | ^3.1.3 | **Sí existe.** Calendario del historial médico |
| intl | ^0.20.2 | **Sí existe.** Fecha larga del calendario (`es_ES`) y `initializeDateFormatting` |
| google_fonts | ^8.2.1 | **Sí existe.** Nunito empaquetada en `google_fonts/`. `allowRuntimeFetching = false` |

### dev_dependencies

| Paquete | Versión |
|---|---|
| flutter_test | sdk |
| flutter_launcher_icons | ^0.14.4 |
| flutter_lints | ^6.0.0 |

Assets declarados: `assets/PortonRefugio.jpg`, `google_fonts/`. Ícono launcher: `assets/huella.png` (android y windows).

### Estado, imágenes, navegación

- **Estado:** NO EXISTE Provider, Riverpod, Bloc, GetX ni ChangeNotifier. Cada pantalla es un `StatefulWidget` con `setState`. Las listas y la ficha escuchan Firestore con `StreamBuilder` (`observarPerros`, `observarPerroPorId`).
- **Imágenes:** `Image.network`, `FileImage`, `AssetImage`, `image_picker`, `image_cropper`, Firebase Storage.
- **Navegación:** NO EXISTE `routes:` ni GoRouter. Solo `Navigator.push`, `pushReplacement` y `pushAndRemoveUntil` con `MaterialPageRoute`. Hay un `navigatorKey` global en `lib/main.dart` para las notificaciones.

`lib/firebase_options.dart` existe y configura Firebase. Su contenido no se copia acá (credenciales).

## 3. Árbol de `lib/` (hasta 3 niveles)

NO EXISTE carpeta `repositories/`, `widgets/` ni `l10n/`.

```
lib/
  main.dart                          Arranque, tema, locale es, home según auth
  firebase_options.dart              Opciones de Firebase. NO CITAR (claves)
  controllers/
    perro_controller.dart            CRUD de perros, fotos, validación, edad, familiares
    tratamiento_controller.dart      Tratamientos, dosis, pausa, calendario, auto-archivo
  models/
    perro_model.dart                 Documento de un perro
    tratamiento_model.dart           Un ítem del array tratamientos
  services/
    notificaciones_service.dart      Alarmas locales de medicación
  theme/
    app_colors.dart                  Paleta navy / arena / terracota y estados de dosis
    app_theme.dart                   ThemeData Material 3 (Nunito)
    category_colors.dart             Color, ícono y etiqueta por categoría médica
    entrada_escalonada.dart          Fade + slide de 8 px al entrar un ítem de lista
  views/
    pantalla_login.dart              Email, contraseña, "Entrar como visitante"
    pantalla_bloqueo.dart            Biometría / PIN
    pantalla_menu.dart               Portada con dos botones
    pantalla_perros.dart             Búsqueda, filtros, grilla, FAB
    ficha_detalle_perro.dart         Ficha, galería, dosis, calendario
    formulario_perro.dart            Alta y edición de la ficha completa
```

`test/widget_test.dart` existe fuera de `lib/`. NO ENCONTRADO que cubra la UI médica actual.

## 4. Cómo está el MVC

| Capa | Dónde | Qué hace |
|---|---|---|
| Modelo | `lib/models/` | Clases inmutables. `fromMap` / `toMap` / `copyWith`. Sin lógica de pantalla |
| Vista | `lib/views/` | Widgets. Instancian los controladores en el `State`. Llaman métodos y hacen `setState` o rearman con el stream |
| Controlador | `lib/controllers/` | Reglas y acceso a Firestore. No importan Flutter widgets (salvo tipos de datos) |
| Servicio | `lib/services/notificaciones_service.dart` | Notificaciones. La vista del listado lo dispara |

Comunicación: la vista crea `PerroController()` y `TratamientoController()` como campos. No hay inyección. El refresco de la ficha no es un callback del controlador: `FichaDetallePerro` escucha `observarPerroPorId` y Firestore empuja el documento nuevo.

### Ejemplo: marcar la dosis de hoy

1. Vista `lib/views/ficha_detalle_perro.dart`, checkbox de `_buildTarjetaTratamiento`. Si no es invitado: `onChanged: (_) => _toggleDosis(t, DateTime.now())`.
2. `_toggleDosis` (`ficha_detalle_perro.dart`) llama `_tratamientoController.toggleDosis(widget.idDocumento, tratamiento, fecha)`.
3. `TratamientoController.toggleDosis` (`lib/controllers/tratamiento_controller.dart`): normaliza el día a medianoche. Si el día es anterior a `fechaInicio`, no hace nada. En una transacción lee `perros/{id}`, busca el tratamiento por `id`, agrega o quita la fecha ISO `yyyy-MM-dd` en `registro_dosis`, y escribe el array `tratamientos` entero. No usa `FieldValue.arrayUnion` sobre un índice (eso convertía el array en mapa).
4. El `StreamBuilder` de la ficha recibe el documento actualizado y vuelve a pintar checkbox y círculos.

Los círculos de días anteriores llaman el mismo `_toggleDosis` con la fecha de ese día. El visitante pasa `onChanged: null` y `onTap: null`.

Pausa de un tratamiento (formulario): la vista llama `alternarPausa` (solo memoria) y, si el perro ya tiene id, `persistirAlternarPausa`. Si Firestore falla, la vista revierte el ítem y muestra un SnackBar.

## 5. Mapa de navegación

NO EXISTE tabla de rutas con nombres. Argumentos por constructor.

| Pantalla | Clase | Cómo se llega | Argumentos |
|---|---|---|---|
| Login | `PantallaLogin` | `home` de `MaterialApp` si no hay usuario | ninguno |
| Bloqueo | `PantallaBloqueo` | `home` si `authStateChanges` tiene usuario | ninguno |
| Menú | `PantallaMenu` | Tras biometría (`pushReplacement`); también `pushReplacement` al final de `_ingresar`; el visitante hace `push` desde el login | ninguno |
| Listado activos | `PantallaPerros` | Menú, botón "Perritos del refugio" | `soloInactivos: false` (default) |
| Listado difuntos | `PantallaPerros` | Menú, botón "Difuntos" | `soloInactivos: true` |
| Ficha | `FichaDetallePerro` | Tap en una tarjeta del listado; también al abrir la app desde una notificación (payload = id del perro), después del desbloqueo | `idDocumento: String` (requerido) |
| Alta | `FormularioPerro` | FAB "+" del listado (oculto si es invitado) | ninguno (`idDocumento` y `perroActual` quedan null) |
| Edición | `FormularioPerro` | Ícono lápiz de la tarjeta (oculto si es invitado) | `idDocumento`, `perroActual: PerroModel` |
| Familiar | `FichaDetallePerro` | Chip de familiar en la ficha | `pushReplacement` con el `id_documento` del familiar |
| Login de nuevo | `PantallaLogin` | Logout del listado: `pushAndRemoveUntil` | ninguno |
| Foto grande | diálogo / ruta interna | Tap en una foto de la galería. Método `_abrirFotoPantallaCompleta` | NO es una pantalla con nombre propio |

`CalendarioHistorialWidget` no es una ruta. Se muestra en un `showModalBottomSheet` + `DraggableScrollableSheet`. Constructor: `eventosCalendario` (`Map<DateTime, List<Map<String, dynamic>>>`).

Detalle del arranque (`lib/main.dart`):

- `home` es un `StreamBuilder<User?>` de `FirebaseAuth.instance.authStateChanges()`.
- Esperando: `CircularProgressIndicator`.
- Con usuario: `PantallaBloqueo`.
- Sin usuario: `PantallaLogin`.
- `_ingresar` además hace `pushReplacement` a `PantallaMenu` después de `signInWithEmailAndPassword`. Conviene no "corregirlo" en un refactor visual: el `StreamBuilder` ya cambia el `home` a `PantallaBloqueo` cuando aparece el usuario.

Cerrar sesión (`pantalla_perros.dart`): si no es invitado, `FirebaseAuth.instance.signOut()`, luego `pushAndRemoveUntil` a `PantallaLogin`.

## 6. Plataformas, oscuro, orientación, tablets

Carpetas de plataforma presentes en el repo: `android/`, `ios/`, `windows/`, `macos/`, `linux/`, `web/`. El ícono launcher se genera para android y windows (`flutter_launcher_icons`). Las notificaciones se inicializan con settings de Android y Windows. NO ENCONTRADO un `if` que desactive una plataforma.

- **Modo oscuro:** NO EXISTE `darkTheme` ni `ThemeMode` en `MaterialApp`. Solo `theme: buildAppTheme()`. Hay `android/app/src/main/res/values-night/styles.xml` (splash nativo). La UI Flutter no tiene tema oscuro.
- **Orientación:** NO ENCONTRADO `SystemChrome.setPreferredOrientations` ni bloqueo de orientación.
- **Tablets / ancho:**
  - Listado (`pantalla_perros.dart`): `LayoutBuilder`. 1 columna si ancho < 600, 2 si >= 600, 3 si >= 900. `childAspectRatio: 0.9`.
  - Ficha (`ficha_detalle_perro.dart`): si `constraints.maxWidth >= 700`, galería a la izquierda (flex 4) y panel de datos a la derecha (flex 6, ancho máximo 480). Si no, galería arriba (200 px vacía, 300 px con fotos) y datos abajo con scroll.
