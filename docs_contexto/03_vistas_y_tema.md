# 03 — Vistas y tema

El código fuente de ficha, formulario y listado está en los archivos `04_codigo_vistas_clave*.md`. Acá va el mapa visual. El tema se pega completo.

## 1. Tema

`MaterialApp` (`lib/main.dart`): `theme: buildAppTheme()`, `locale: Locale('es')`, `supportedLocales: [Locale('es')]`. NO EXISTE `darkTheme`.

Paleta en `lib/theme/app_colors.dart`:

| Nombre | Hex |
|---|---|
| navy | `#2F4565` |
| arena | `#EADDC0` |
| terracota | `#C8553D` |
| superficie | blanco |
| bordeTarjeta | `#E2D5B5` |
| rellenoInput | `#FAF8F3` |
| bordeInput | `#D9CDB0` |
| texto | `#191919` |
| textoSecundario | `#6B6459` |
| dosisDada / activo | `#4F9D69` |
| pausado | `#D9A441` |
| dosisOlvidada | `#E07A5F` |
| pendiente | `#CFC7B8` |
| error | `#B3261E` |

Categorías en `lib/theme/category_colors.dart`: diario `#4CAF50` / texto `#2E7D32`; unico `#2196F3` / `#1565C0`; higiene `#00BCD4` / `#00727F`; evento `#9C27B0` / `#7B1FA2`; veterinaria `#FF9800` / `#B45309`. El tinte es el color base al 12 %.

Tipografía: Nunito vía `google_fonts`, archivos en `google_fonts/` (Regular, Italic, SemiBold, Bold, ExtraBold). Escala: headlineMedium 28/w800, titleLarge 20/w700, titleMedium 16/w700, bodyMedium 15 altura 1.4, labelMedium 12/w600.

### `ThemeData`

El fuente completo de `lib/theme/app_theme.dart` (133 líneas) está en `04_codigo_vistas_clave_08.md`. `app_colors.dart`, `category_colors.dart` y `entrada_escalonada.dart` están en `04_codigo_vistas_clave_09.md`. No se resumen acá.

Constantes que ese `ThemeData` fija, para leer este documento sin abrir el otro:

- Material 3. Scaffold arena. AppBar navy con texto e íconos arena.
- Cards blancas, elevación 0, radio 20, borde `#E2D5B5`.
- Inputs rellenos `#FAF8F3`, radio 14, borde `#D9CDB0`, foco navy de 1.6.
- Botones alto mínimo 48, radio 14. Switch, checkbox y chip seleccionado en terracota.
- Bottom sheet con asa, fondo blanco, radio superior 28. FAB terracota.

### Colores todavía hardcodeados (no pasan por `AppColors`)

| Archivo | Línea aprox. | Valor |
|---|---|---|
| `formulario_perro.dart` | 688 | texto chip Activo `#2E6B44`, Pausado `#8A6414` |
| `ficha_detalle_perro.dart` | 1222 | sombra `Color(0x0F000000)` |
| `pantalla_perros.dart` | 301-304 | degradado transparente, negro 10 %, 60 %, 90 % |
| `pantalla_perros.dart` | 265, 324, 359 | sombra negra 35 %, `Colors.black54`, fondo del lápiz `Colors.black54` |
| `pantalla_login.dart` | 171 | visitante `#ECDBBA` |
| `pantalla_login.dart` | 77, 140, 213 | `Colors.redAccent`, `Colors.deepOrange`, blanco y blanco al 8 % / 38 % / 70 % |
| `pantalla_menu.dart` | 23, 46, 56 | negro 40 %, `Colors.deepOrange`, `Colors.blueGrey` |
| `pantalla_bloqueo.dart` | 83-152 | negro 60 %, blanco, `Colors.redAccent`, `Colors.deepOrange` |
| `ficha_detalle_perro.dart` | 922 | pie de foto negro 50 %, texto blanco 11 px |

`Colors.white` sobre círculos de dosis y sobre el texto de las tarjetas del listado es intencional (contraste sobre foto o sobre verde/coral).

## 2. Widgets reutilizables

NO EXISTE carpeta `lib/widgets/`. Casi todo son métodos privados del `State`.

| Nombre | Dónde | Parámetros | Usado en |
|---|---|---|---|
| `EntradaEscalonada` | `lib/theme/entrada_escalonada.dart` | `indice`, `child` | listado, formulario (diarios, pausados, eventos), ficha (tarjetas y filas del día) |
| `CalendarioHistorialWidget` | `ficha_detalle_perro.dart` ~1245 | `eventosCalendario` | bottom sheet de la ficha |
| `AppColors` / `CategoryColors` | `lib/theme/` | estáticos | vistas nuevas y tema |
| `buildAppTheme()` | `app_theme.dart` | ninguno | `main.dart` |
| `_MenuButton` | `pantalla_menu.dart` | `label`, `icon`, `color`, `onTap` | solo el menú |
| `_tarjetaSeccion` | ficha | `titulo`, `icono`, `children` | historia, ficha médica, familiares |
| `_chipDato` / `_filaDato` | ficha | ícono o etiqueta + valor | datos básicos |
| `_buildTarjetaTratamiento` | ficha | tratamiento, fechaHoy, esInvitado | tratamientos activos |
| `_buildHistorialDosis` | ficha | tratamiento, esInvitado | dentro de esa tarjeta |
| `_botonCategoriaSalud` | formulario | `etiqueta`, `icono`, `color`, `categoria` | grilla "Agregar registro médico" |
| `_tarjetaTratamientoDiario` | formulario | `i`, `t`, `pausado` | activos y pausados |
| `_filaEvento` | formulario | `i`, `t` | eventos |
| `_tarjetaFormulario` | formulario | `titulo?`, `icono?`, `accion?`, `children` | datos, familiares, historia |
| `_estadoVacio` | listado | `texto`, `icono` | lista vacía o sin resultados |
| `_campo` / `_campoPassword` | login | controller, label, icono | login |

## 3. Pantallas

### Login — `lib/views/pantalla_login.dart` — `PantallaLogin`

```
Scaffold
  Stack
    AssetImage PortonRefugio.jpg
    Container negro 55 %
    SafeArea > Column
      título "Fichas Refugio"
      TextField email
      TextField contraseña (ver/ocultar)
      ElevatedButton "Ingresar" (deepOrange, alto 50, radio 12)
      TextButton "Entrar como visitante"
```

| Widget | Callback | Efecto |
|---|---|---|
| Ingresar | `_ingresar` | `signInWithEmailAndPassword` y `pushReplacement` a menú |
| Ojo | `setState` de `_verPassword` | no llama controlador |
| Visitante | `Navigator.push` menú | no hay auth |

Estados: `_cargando` (spinner en el botón), error en SnackBar rojo. No hay modo edición.

### Bloqueo — `pantalla_bloqueo.dart` — `PantallaBloqueo`

Fondo del portón, velo negro, "Refugio Milagros de Amor", error en recuadro rojo, botón "Desbloquear" deepOrange. `initState` llama `_desbloquear` (`local_auth`). Si ok: `pushReplacement` menú y, si había payload, `push` de la ficha.

Estados: `_autenticando`, `_mensajeError`, dispositivo sin biometría.

### Menú — `pantalla_menu.dart` — `PantallaMenu`

Portón, velo negro 40 %, ícono pets 72, título 32 bold blanco, dos `_MenuButton` altos 64, radio 16, texto 20 blanco: "Perritos del refugio" (deepOrange) y "Difuntos" (blueGrey). Cada uno hace `Navigator.push` a `PantallaPerros`.

### Listado — `pantalla_perros.dart` — `PantallaPerros({soloInactivos})`

```
Scaffold
  AppBar título (Nunito 22 w800 arena) + IconButton logout
  Column
    TextField búsqueda
    Row ChoiceChip Todos | Refugio | En casa
    Expanded StreamBuilder
      GridView (1/2/3 columnas)
        GestureDetector > Card > Stack
          Image.network o ícono pets
          degradado
          nombre + 4 líneas de datos
          IconButton edit (si no es invitado)
  FAB add (si no es invitado)
```

| Widget | Callback | Método |
|---|---|---|
| Búsqueda `onChanged` | `setState` `_textoBusqueda` | filtro local, no controlador |
| Clear | limpia controller y texto | — |
| Chips | `setState` `_filtroUbicacion` | — |
| Tarjeta | `Navigator.push` `FichaDetallePerro(idDocumento)` | — |
| Lápiz | `Navigator.push` `FormularioPerro(idDocumento, perroActual)` | — |
| FAB | `Navigator.push` `FormularioPerro()` | — |
| Logout | `signOut` + `pushAndRemoveUntil` login | — |
| `initState` | stream `observarPerros` | `NotificacionesService.programarRecordatorios` si hay usuario |

Estados: `ConnectionState.waiting` spinner; lista vacía; filtro/búsqueda sin resultados; con datos. Invitado: sin lápiz ni FAB. El stream no muestra un widget de error si `snapshot.hasError` (cae en vacío). NO ENCONTRADO estado de error propio.

Estilo: padding grilla `16,0,16,104`. Card radio 20, elevación 3, sombra negra 35 %. Nombre 26 blanco w800, una línea. Datos 14, blanco 88 %, alto de línea 1.35. Buscador relleno blanco. Chips del tema (terracota al seleccionar).

### Ficha — `ficha_detalle_perro.dart` — `FichaDetallePerro({idDocumento})`

```
Scaffold
  AppBar "Ficha de {nombre}"
    actions: spinner si sube foto
    si no es invitado: check (solo en modo reordenar), add_a_photo
    PopupMenuButton: Achicar texto, Agrandar texto, Reordenar fotos
  body LayoutBuilder
    ancho >= 700: Row [galería flex 4 | panel flex 6]
    si no: Column [galería 200 o 300 | scroll de datos]
  datos:
    headlineMedium nombre
    chips Sexo, Edad, Castrado
    filas Fecha de ingreso, Fecha de fallecimiento
    Card Historia (Markdown)
    Card Ficha médica (Markdown)
      tarjetas de tratamientos activos
      FilledButton.tonal "Ver Historial Médico"
    Card Familiares (ActionChip)
```

| Widget | Callback | Método |
|---|---|---|
| Achicar / Agrandar | `setState` `_escalaTexto ± 0.15` | — |
| Reordenar / check | `_activarModoReordenar` o `_confirmarOrdenFotos` | `reordenarFotos` |
| Cámara | `_agregarFotoAGaleria` | `agregarFotoAGaleria` |
| Editar / borrar foto, flechas, abrir foto | métodos privados de la ficha | `editarFotoDeGaleria`, `eliminarFotoDeGaleria` |
| Checkbox tratamiento | `_toggleDosis(t, DateTime.now())` | `toggleDosis` |
| Círculo | `_toggleDosis(tratamiento, dia)` | `toggleDosis` |
| Ver Historial Médico | `_mostrarHistorialCompleto` | `construirEventosCalendario` |
| Día del calendario | `setState` del día | — |
| Chip familiar | `pushReplacement` otra ficha | — |
| Al pintar | `_procesarAutoArchivado` | `autoArchivarVencidos` + `guardarTratamientos` |

Estados: waiting spinner; sin documento "Perrito no encontrado."; con datos; `_subiendoFoto`; `_modoReordenar`; invitado (solo lectura de dosis y fotos). Zoom de Markdown con `_escalaTexto` (empieza en 1.0).

Estilo: secciones en Card padding 20. Nombre headlineMedium. Galería vacía: círculo 64, ícono 30. Indicador de página: punto 6 o pastilla 18, navy. Tarjeta de tratamiento: radio interno 14, tinte verde al 8 % si hoy está marcado, título tachado.

### Formulario — `formulario_perro.dart` — `FormularioPerro({idDocumento?, perroActual?})`

```
PopScope (confirma salida)
  Scaffold
    AppBar "Editar Ficha" | "Nuevo Ingreso"
    body Form > scroll padding 16
      CircleAvatar foto 60
      Card Datos básicos
      Card Familiares
      Card Historia + barra bold/italic/viñeta
      Divider
      "Gestión de Salud"
      Ficha médica + barra de formato
      "Agregar registro médico" + grilla 2 columnas
      "Tratamientos Diarios" + pastilla con cantidad
      tarjetas activas + ExpansionTile Pausados
      "Eventos y Visitas" + filas
      Card "Este perrito/a está en casa"
      TextButton "Eliminar ficha" (solo edición)
    bottomNavigationBar
      FilledButton "Guardar Cambios" | "Crear Ficha"
```

| Widget | Callback | Método |
|---|---|---|
| Foto | `_abrirOpcionesFotoPerfil` | picker / cropper; la URL se sube en `_guardarDatos` |
| Nombre | validator | `validarNombre` |
| Fecha ingreso / fallecimiento | `_seleccionarFechaIngreso` / `_seleccionarFechaFallecimiento` | `showDatePicker` |
| Sexo, estado | `setState` `'macho'/'hembra'`, `'activo'/'inactivo'` | — |
| Edad indeterminada | `setState`, limpia campos | — |
| Meses | validator | `validarMeses` |
| Castrado | `setState` | — |
| Añadir familiar | `_mostrarDialogoAgregarFamiliar` | `obtenerListaPerros`, `obtenerRelacionInversa` |
| Quitar familiar | `removeAt` + `_hayCambios` | se persiste al guardar |
| Bold / italic / viñeta | `_insertarFormatoTexto` / `_insertarBulletTexto` | — |
| Botón de categoría | `_mostrarDialogoAgregarTratamiento(categoria:)` | `crearTratamiento` (en memoria hasta guardar) |
| Pausar / Reanudar | `_alternarPausaTratamiento(i)` | `alternarPausa` + `persistirAlternarPausa` |
| Editar tratamiento | `_mostrarDialogoEditarTratamiento(i)` | `editarTratamiento` |
| Eliminar | `_mostrarDialogoEliminarTratamiento(i)` o `removeAt` si está pausado | — |
| En casa | `setState` `_enCasa` | — |
| Guardar | `_guardarDatos` | `guardarPerro` |
| Eliminar ficha | `_confirmarEliminarFicha` | `eliminarPerro` |
| Atrás | `_confirmarSalida` | puede llamar `_guardarDatos` |

Estados: alta vs edición (`idDocumento != null`); `_estaGuardando` (spinner en el botón, `onPressed` null); `_hayCambios`; edad indeterminada; estado inactivo muestra fecha de fallecimiento; listas vacías de diarios, eventos y familiares.

Estilo: tarjetas del tema, separación 16. Grilla de categorías: alto mínimo 56, ícono en círculo 36. Chip Activo/Pausado. Pausados con `AnimatedOpacity` 0.65. Botones de acción abajo de la tarjeta, no en el `trailing`. Barra inferior blanca con borde superior.

## 4. Particularidades visuales

### Cinco círculos

`Row` de 5 `GestureDetector`. Área 40×40. `AnimatedContainer` 24×24, 200 ms, `Curves.easeOutCubic`, `BoxShape.circle`. Check o close de 14 px en blanco. Inicial del día en `labelMedium`; hoy en navy w800. Ver estados de color en el documento 02.

### Bottom sheet del historial

`showModalBottomSheet(isScrollControlled: true)` > `DraggableScrollableSheet` (inicial 0.85, mínimo 0.5, máximo 0.95) > `PrimaryScrollController` > `CalendarioHistorialWidget`.

El widget es un `ListView(primary: true)` con:

- Título "Historial médico" en titleLarge.
- `FutureBuilder` hasta que cargue `initializeDateFormatting('es_ES')`.
- `TableCalendar` locale `es_ES`. Día seleccionado: círculo navy, texto blanco w700. Hoy: borde navy 1.6, sin relleno, texto navy w700. Cabecera centrada, chevrones navy, sin botón de formato. `outsideDaysVisible` no se setea (queda el default de la librería, que los muestra).
- `markerBuilder` como en el documento 02.
- Fecha legible: `DateFormat("EEEE d 'de' MMMM", 'es_ES')` en titleMedium navy. Ejemplo de forma: "miércoles 8 de octubre".
- Filas: contenedor `#FAF8F3`, radio 14, borde `#E2D5B5`, avatar circular con tinte de categoría, título del `detalle`, subtítulo `CategoryColors.etiqueta`.
- Vacío: ícono `event_available_outlined` en `pendiente` y el texto "No hay registros médicos para este día".

### Tarjetas del listado

`Card` clip, radio 20, elevación 3. Foto `BoxFit.cover` o fondo navy con `Icons.pets` al 40 %. Degradado de arriba a abajo en stops 0, 0.35, 0.65, 1: transparente, negro 10 %, negro 60 %, negro 90 %. Texto abajo, padding 12. Nombre con sombra `black54` blur 6.

## 5. Textos y locale

`MaterialApp.locale` es `Locale('es')`, no `es_AR`. El calendario pide datos de `es_ES` con `intl`. Fechas cortas de la app son `dd/mm/yyyy` armadas a mano (`formatearFecha`), no `DateFormat`.

Textos a conservar (los que ve la persona):

- Login: "Fichas Refugio", "Email", "Contraseña", "Ingresar", "Entrar como visitante", y los errores de `_mensajeDeError`.
- Bloqueo: "Refugio Milagros de Amor", "Desbloquear", "Verificá tu identidad para acceder a Fichas Refugio".
- Menú: "Refugio Milagros de Amor", "Perritos del refugio", "Difuntos".
- Listado: "Perritos del refugio", "Difuntos", "Buscar por nombre...", "Todos", "Refugio", "En casa", "Perritos del refugio (N) | En casa (N)", "Fecha de ingreso:", "Sexo: Hembra/Macho", "Castrado: Sí/No", "Fallecimiento:", "Nuevo ingreso", "Cerrar sesión", "Sin nombre".
- Ficha: "Ficha de {nombre}", "Más opciones", "Achicar texto", "Agrandar texto", "Reordenar fotos", "Guardar orden de fotos", "Agregar foto a la galería", "Aún no hay fotos en la galería", "Tocá el ícono de cámara arriba para agregar una.", "Sexo", "Edad", "Castrado", "Fecha de ingreso", "Fecha de fallecimiento", "No registrada", "Historia y observaciones", "Ficha médica", "Tratamientos activos", "Ver Historial Médico", "Familiares en el refugio", "Historial médico", "No hay registros médicos para este día".
- Formulario: "Editar Ficha", "Nuevo Ingreso", "Datos básicos", "Nombre del perrito", "Fecha de ingreso (opcional)", "Sexo", "Macho", "Hembra", "Edad indeterminada", "Edad estimada (años, opcional)", "Meses (opcional)", "¿Ya está castrado?", "Estado", "Activo", "Inactivo", "Familiares", "Añadir", "Historia", "Gestión de Salud", "Agregar registro médico", "Tratamiento Diario", "Dosis Única", "Higiene", "Evento Médico", "Veterinaria", "Tratamientos Diarios", "Pausados", "Pausar", "Reanudar", "Eventos y Visitas", "Este perrito/a está en casa", "Guardar Cambios", "Crear Ficha", "Eliminar ficha", "Hay cambios sin guardar".
- Diálogos de tratamiento: "Agregar tratamiento diario", "Agregar dosis única", "Agregar higiene", "Agregar evento médico", "Agregar visita veterinaria", "Cancelar", "Agregar", "Editar tratamiento", "Guardar", "Eliminar tratamiento", "Eliminar registro", "Pausar", "Eliminar definitivamente".
- Notificación: "Medicación pendiente", "Toca darle {med} a {nombre}", "Visita veterinaria", "Dosis única pendiente".
