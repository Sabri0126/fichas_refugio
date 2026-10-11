# 02 — Datos y lógica

Leído de `lib/models/`, `lib/controllers/` y `lib/services/`. No hay enums de Dart: las categorías son `String`.

## 1. Esquema de Firestore

NO EXISTE otra colección usada por la app. NO EXISTEN subcolecciones. NO EXISTE colección `usuarios` (la cuenta vive en Firebase Auth).

### Colección `perros` — un documento por perro

El id del documento es `PerroModel.id`. No se guarda dentro del mapa salvo al armar notificaciones.

| Campo Firestore | Tipo | Obligatorio en el modelo | Notas |
|---|---|---|---|
| `nombre` | String | sí (default `''`) | |
| `sexo` | String | sí | `'macho'` (default) o `'hembra'` |
| `estado` | String | sí | `'activo'` (default) o `'inactivo'` (fallecido) |
| `edad` | int | sí | años. Default 0 |
| `meses` | int | sí | solo se usa si `edad == 0`. Default 0 |
| `edad_indeterminada` | bool | sí | default false. Si true, la edad no se recalcula |
| `edad_anio_base` | int | opcional | `toMap` lo omite si es null |
| `fecha_ingreso` | Timestamp | opcional | también se acepta DateTime o String al leer |
| `fecha_fallecimiento` | Timestamp | opcional | se muestra si `estado == 'inactivo'` |
| `ultima_actualizacion_edad` | Timestamp | opcional | envejecimiento de cachorros |
| `historia` | String | sí | Markdown. Default `''` |
| `ficha_medica` | String | sí | Markdown. Default `''` |
| `castrado` | bool | sí | default false |
| `en_casa` | bool | sí | true = hogar de acogida. Default false |
| `foto_perfil` | String (URL) | opcional | Storage `fotos_perfil/` |
| `parientes` | array de mapas | sí | puede ir vacío |
| `galeria` | array de mapas | sí | puede ir vacío |
| `tratamientos` | array de mapas | sí | puede ir vacío. Siempre reescribir el array entero |

`parientes[]`: `id`, `id_documento` (id de otro perro), `nombre`, `relacion`. Relaciones vistas en el formulario: `'Madre'`, `'Padre'`, `'Hijo/a'`, `'Hermano/a'`. La inversa la calcula `obtenerRelacionInversa`.

`galeria[]`: `url` (String), `texto` (String). Al mostrar, si falta `texto` se usa `descripcion`. Al guardar una foto nueva solo se escribe `{url, texto}`.

### `tratamientos[]` (no es colección)

| Campo | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `id` | String | sí | id generado con `collection('perros').doc().id`. No crea un documento |
| `categoria` | String | sí | `'diario'`, `'unico'`, `'higiene'`, `'evento'`, `'veterinaria'`. Default al leer: `'diario'` |
| `medicacion` | String | sí | título. En veterinaria es "motivo" |
| `indicaciones` | String | sí | puede ir vacío |
| `fecha_inicio` | Timestamp o null | opcional | `toMap` escribe `null` si no hay fecha. No se omite la clave |
| `dias_duracion` | int | sí | `0` = indefinido. En eventos puntuales se guarda 0 |
| `hora_recordatorio` | String o null | opcional | `'HH:mm'`. Diario |
| `registro_dosis` | array de String | sí | cada ítem es `yyyy-MM-dd` |
| `activo` | bool | sí | en diarios: true = en curso, false = pausado. `fromMap` usa `data['activo'] == true` (si falta la clave, queda false) |
| `fecha_proximo_recordatorio` | Timestamp o null | opcional | solo `'unico'` y `'higiene'` al crear |

### Firebase Storage (no es Firestore)

- Foto de perfil: `fotos_perfil/{timestamp}.jpg` — `formulario_perro.dart`.
- Galería: `galeria_perros/{nombreArchivo}` — `ficha_detalle_perro.dart`.

## 2. Modelos Dart

NO EXISTE ningún `enum`.

### `PerroModel` — `lib/models/perro_model.dart`

```dart
class PerroModel {
  final String id;
  final String nombre;
  final String sexo;
  final String estado;
  final int edad;
  final int meses;
  final bool edadIndeterminada;
  final int? edadAnioBase;
  final DateTime? fechaIngreso;
  final DateTime? fechaFallecimiento;
  final DateTime? ultimaActualizacionEdad;
  final String historia;
  final String fichaMedica;
  final bool castrado;
  final bool enCasa;
  final String? fotoPerfil;
  final List<Map<String, dynamic>> parientes;
  final List<Map<String, dynamic>> galeria;
  final List<TratamientoModel> tratamientos;

  PerroModel({
    required this.id,
    required this.nombre,
    this.sexo = 'macho',
    this.estado = 'activo',
    this.edad = 0,
    this.meses = 0,
    this.edadIndeterminada = false,
    this.edadAnioBase,
    this.fechaIngreso,
    this.fechaFallecimiento,
    this.ultimaActualizacionEdad,
    this.historia = '',
    this.fichaMedica = '',
    this.castrado = false,
    this.enCasa = false,
    this.fotoPerfil,
    this.parientes = const [],
    this.galeria = const [],
    this.tratamientos = const [],
  });
}
```

También: `factory fromMap`, `toMap`, `copyWith` (solo tratamientos, parientes, galeria, fotoPerfil).

### `TratamientoModel` — `lib/models/tratamiento_model.dart`

```dart
class TratamientoModel {
  final String id;
  final String categoria;
  final String medicacion;
  final String indicaciones;
  final DateTime? fechaInicio;
  final int diasDuracion;
  final String? horaRecordatorio;
  final List<String> registroDosis;
  final bool activo;
  final DateTime? fechaProximoRecordatorio;

  TratamientoModel({
    required this.id,
    required this.categoria,
    required this.medicacion,
    required this.indicaciones,
    this.fechaInicio,
    this.diasDuracion = 0,
    this.horaRecordatorio,
    this.registroDosis = const [],
    this.activo = true,
    this.fechaProximoRecordatorio,
  });
}
```

Categorías usadas (strings, no enum):

| Valor | Etiqueta en UI (`CategoryColors.etiqueta`) | Ícono |
|---|---|---|
| `diario` | Tratamiento diario | `Icons.medication` |
| `unico` | Dosis única | `Icons.vaccines` |
| `higiene` | Higiene | `Icons.shower` |
| `evento` | Evento médico | `Icons.monitor_heart` |
| `veterinaria` | Veterinaria | `Icons.local_hospital` |

Cualquier otro string cae en diario (color, ícono y etiqueta).

## 3. Controladores — firmas públicas

Instancia local en la vista. No son singletons.

### `PerroController` — `lib/controllers/perro_controller.dart`

| Firma | Qué hace | Quién lo llama |
|---|---|---|
| `Stream<List<PerroModel>> observarPerros()` | Stream de toda la colección `perros` | `pantalla_perros.dart` (lista y notificaciones) |
| `Stream<PerroModel?> observarPerroPorId(String id)` | Stream de un documento | `ficha_detalle_perro.dart` |
| `Future<List<PerroModel>> obtenerListaPerros()` | Lectura única de todos | `formulario_perro.dart` (elegir familiar) |
| `String? validarNombre(String? valor)` | Error si el nombre está vacío | formulario, campo nombre |
| `String? validarMeses(String? valor)` | Error si meses >= 12 | formulario, campo meses |
| `int calcularEdadEstimada(PerroModel perro)` | Suma años desde `edadAnioBase`. Inactivo no envejece | lo usa `formatearEdadTexto` |
| `String formatearEdadTexto(PerroModel perro)` | "Edad: Indeterminada" / "N meses" / "Edad estimada: N años" | listado |
| `String formatearFecha(DateTime? fecha)` | `dd/mm/yyyy` o `'No registrada'` | listado |
| `String obtenerRelacionInversa(String relacion, String sexoOriginal)` | Madre/Padre ↔ Hijo/Hija | formulario al vincular familiar |
| `Future<String> guardarPerro(PerroModel perro)` | Crea o actualiza el documento. Devuelve el id | formulario `_guardarDatos` |
| `Future<void> eliminarPerro(String id)` | Borra el documento | formulario, confirmar eliminar |
| `Future<void> actualizarFotoPerfil(String id, String url)` | Escribe `foto_perfil` | ficha, al recortar perfil |
| `Future<void> actualizarUrlDeFoto(String id, String urlAnterior, String urlNueva)` | Cambia la URL en perfil o en galería | ficha, al recortar una foto |
| `Future<void> agregarFotoAGaleria(String id, String url, String texto)` | `arrayUnion` de `{url, texto}` | ficha |
| `Future<void> editarFotoDeGaleria(String id, int indice, String nuevoTexto)` | Reemplaza el ítem en ese índice | ficha |
| `Future<String?> eliminarFotoDeGaleria(String id, int indice)` | Quita el ítem y devuelve la URL | ficha |
| `Future<void> reordenarFotos(String id, String? nuevaFotoPerfil, List<Map<String, dynamic>> nuevaGaleria)` | La primera foto pasa a perfil | ficha, al confirmar orden |

Método privado relevante: `_actualizarEdadesCachorros` corre dentro de `guardarPerro`.

### `TratamientoController` — `lib/controllers/tratamiento_controller.dart`

| Firma | Qué hace | Quién lo llama |
|---|---|---|
| `String generarId()` | Id nuevo, sin escribir un documento | lo usa `crearTratamiento` |
| `String formatearFechaISO(DateTime fecha)` | `yyyy-MM-dd` | interno y dosis |
| `TratamientoModel crearTratamiento({required String categoria, required String medicacion, required String indicaciones, required DateTime fechaInicio, int diasDuracion = 0, String? horaRecordatorio, DateTime? fechaProximoRecordatorio})` | Arma el modelo según diario vs puntual | formulario, diálogo agregar |
| `TratamientoModel editarTratamiento(TratamientoModel actual, {required String medicacion, required String indicaciones, required int diasDuracion, required DateTime fechaInicio, required String horaRecordatorio})` | Copia con esos campos. No toca categoría ni `registroDosis` | formulario, diálogo editar |
| `TratamientoModel alternarPausa(TratamientoModel tratamiento)` | Niega `activo` solo si es `diario` | formulario |
| `TratamientoModel archivar(TratamientoModel tratamiento)` | `activo: false` | auto-archivo |
| `TratamientoModel restaurar(TratamientoModel tratamiento)` | `activo: true` | NO ENCONTRADO un llamado desde una vista |
| `Future<void> persistirAlternarPausa(String idPerro, String idTratamiento)` | Lee el array y voltea `activo` solo en ese diario | formulario, si ya hay id |
| `DateTime normalizarDia(DateTime fecha)` | Quita la hora | `toggleDosis` |
| `Future<void> toggleDosis(String perroId, TratamientoModel tratamiento, DateTime fechaDosis)` | Agrega o quita ese día en `registro_dosis` y reescribe el array | ficha, checkbox y círculos |
| `TratamientoModel alternarDosis(TratamientoModel tratamiento, DateTime fecha, bool marcar)` | Copia local del registro. No escribe Firestore | NO ENCONTRADO un llamado desde una vista |
| `List<TratamientoModel> obtenerActivos(...)` | `activo == true` | NO ENCONTRADO en vistas |
| `List<TratamientoModel> obtenerArchivados(...)` | `activo == false` | NO ENCONTRADO en vistas |
| `List<TratamientoModel> obtenerDiarios(...)` | `categoria == 'diario'` | NO ENCONTRADO en vistas (el formulario filtra a mano) |
| `List<TratamientoModel> obtenerActivosDiarios(...)` | diario y activo | ficha, sección salud |
| `List<TratamientoModel> obtenerDiariosPausados(...)` | diario y no activo | NO ENCONTRADO en vistas |
| `List<TratamientoModel> obtenerEventosYVisitas(...)` | no diario, fecha descendente | NO ENCONTRADO en vistas (el formulario ordena a mano) |
| `List<TratamientoModel> autoArchivarVencidos(..., {DateTime? ahora})` | Pausa diarios vencidos | ficha `_procesarAutoArchivado` |
| `bool huboCambiosDeArchivado(original, actualizada)` | Compara `activo` por posición | ficha |
| `Future<void> guardarTratamientos(String idPerro, List<TratamientoModel> tratamientos)` | `update` del campo `tratamientos` | ficha, auto-archivo |
| `Future<List<TratamientoModel>> procesarAutoArchivadoYPersistir(...)` | Archiva y guarda si hubo cambios | NO ENCONTRADO en vistas (la ficha llama las dos piezas por separado) |
| `Map<DateTime, List<Map<String, dynamic>>> construirEventosCalendario(List<TratamientoModel> tratamientos)` | Mapa para el calendario | ficha `_mostrarHistorialCompleto` |

### `NotificacionesService` — `lib/services/notificaciones_service.dart`

Singleton `NotificacionesService.instance`.

| Firma | Qué hace | Quién lo llama |
|---|---|---|
| `Future<void> inicializar({GlobalKey<NavigatorState>? navigatorKey})` | Timezone, canal Android, permisos | `main.dart` |
| `Future<void> programarRecordatorios(List<Map<String, dynamic>> perrosConTratamiento)` | Cancela todas y reprograma | `pantalla_perros.dart` `initState`, solo si hay usuario |

## 4. Lógica médica

### 4a. Diario vs evento puntual

La distinción es `categoria == 'diario'` o no. No hay otro flag.

- **Diario:** se puede pausar (`activo`). Nace con `activo: true` y `registroDosis` vacío. Tiene `diasDuracion` y `horaRecordatorio`. Aparece en "Tratamientos Diarios" del formulario y, si está activo, en la ficha con checkbox y 5 círculos.
- **Puntual** (`unico`, `higiene`, `evento`, `veterinaria`): `alternarPausa` lo devuelve igual. Al crearlo queda `activo: true` y `registroDosis` ya contiene la `fechaInicio` (para que el calendario lo muestre). `diasDuracion` se fuerza a 0. `fechaProximoRecordatorio` solo se guarda si la categoría es `unico` o `higiene`. Aparece en "Eventos y Visitas". No tiene checkbox ni círculos en la ficha.

### 4b. Los 5 círculos

Código: `_buildHistorialDosis` en `lib/views/ficha_detalle_perro.dart`.

- Recorre `i` de 4 a 0. El día es `DateTime.now()` menos `i` días. Orden visual: hace 4 días, hace 3, hace 2, ayer, hoy.
- Debajo, la inicial según `DateTime.weekday` (lunes = 1): `L M X J V S D`.
- Dato: `tratamiento.registroDosis`, lista de `yyyy-MM-dd`. La vista arma la clave con `_fechaISO` (mismo formato que el controlador).

Estado de cada círculo:

| Condición | Color | Ícono | Texto de accesibilidad |
|---|---|---|---|
| El día es anterior a `fechaInicio` | `pendiente` al 35 % | ninguno | "antes del inicio del tratamiento" |
| La fecha ISO está en `registroDosis` | `dosisDada` `#4F9D69` | check blanco | "dosis dada" |
| Es hoy y no está registrada | `pendiente` `#CFC7B8` | ninguno | "dosis pendiente" |
| Es un día pasado, ya empezó el tratamiento, y no está registrada | `dosisOlvidada` `#E07A5F` | close blanco | "dosis olvidada" |

Hoy lleva además un anillo navy de 2 px. El círculo mide 24 px dentro de un área de 40×40.

Toque (si no es invitado y el día no es anterior al inicio): `HapticFeedback.selectionClick()` y `_toggleDosis(tratamiento, diaSoloFecha)`. Eso agrega o quita esa fecha. Un día olvidado se puede marcar después (dosis retroactiva). Volver a tocar una dosis dada la desmarca. `toggleDosis` no escribe nada si el día es anterior a `fechaInicio`.

El checkbox de la tarjeta llama `_toggleDosis(t, DateTime.now())`, o sea solo el día de hoy. El `InkWell` cubre checkbox + título, no los círculos.

### 4c. "5 días", "Indefinido" y recordatorios

`diasDuracion` es un int que el formulario pide como "Días de duración (0 = indefinido)".

- `0`: no vence. La notificación diaria se repite todos los días a `hora_recordatorio` (`matchDateTimeComponents: DateTimeComponents.time`).
- `N > 0`: `autoArchivarVencidos` calcula `fechaFin = fechaInicio + N días`. Si hoy es posterior a `fechaFin`, pone `activo: false`. La ficha corre esto al pintar (`_procesarAutoArchivado`) y, si cambió, llama `guardarTratamientos`. Esos diarios dejan de listarse como activos.
- El texto "5 días" no es un caso especial. Es el subtítulo cuando `diasDuracion > 0`: `'$dias días'`. Si no: `'Indefinido'`.
- Hora: string `HH:mm`. Default del diálogo de alta: 09:00. El time picker fuerza formato 24 h.
- Notificaciones (`programarRecordatorios`): ignora perros `inactivo` y diarios con `activo == false`. Canal Android `tratamientos_diarios`. Título "Medicación pendiente", cuerpo "Toca darle {medicacion} a {nombre}". Payload = id del perro.
- Si el diario tiene fin, programa una alarma por cada día restante, no una repetición infinita.
- Si no es diario y tiene `fecha_proximo_recordatorio` en el futuro: una sola alarma. Título "Visita veterinaria" solo si `categoria == 'veterinaria'`; si no, "Dosis única pendiente" (también para higiene y evento). Al crear, ese campo solo se guarda en `unico` e `higiene`.

### 4d. Calendario del historial

`_mostrarHistorialCompleto` llama `construirEventosCalendario(tratamientos)` y abre el bottom sheet con `CalendarioHistorialWidget`.

`construirEventosCalendario` recorre **todos** los tratamientos (diarios y puntuales). Por cada string de `registroDosis` que parsee como fecha, agrega un evento en `DateTime.utc(año, mes, día)`. El mapa del evento tiene `medicacion`, `indicaciones`, `detalle`, `categoria`. `detalle` es `'{medicacion} - {indicaciones}'`. Si la categoría es `veterinaria`, antepone el emoji `🏥`.

`eventLoader` del `TableCalendar`: `_eventosDelDia`, que lee ese mapa con la clave UTC del día.

`markerBuilder`: hasta 4 puntos de 6 px. Color = `CategoryColors.base(categoria)`:

| categoría | color |
|---|---|
| diario (y cualquier otra) | `#4CAF50` |
| unico | `#2196F3` |
| higiene | `#00BCD4` |
| evento | `#9C27B0` |
| veterinaria | `#FF9800` |

`onDaySelected` solo hace `setState` de `_selectedDay` y `_focusedDay`. No llama al controlador. `selectedDayPredicate` usa `isSameDay`. Rango: 2 años atrás y 1 adelante respecto de `_focusedDay`. Gestos: solo swipe horizontal.

Los puntos salen de `registro_dosis`, no de un cálculo de "debió tomarla". Un día olvidado en los círculos no aparece en el calendario si nadie lo marcó.

## 5. Reglas de negocio que se ven en la UI

- Nombre vacío: el formulario no guarda. Mensaje "Ingresá un nombre".
- Meses >= 12: "El valor debe estar entre 0 y 11...". El campo meses solo aparece si la edad en años es `0` y la edad no es indeterminada.
- Edad indeterminada: deshabilita el campo de años y lo vacía.
- Medicación vacía en los diálogos de alta y edición: el botón no cierra el diálogo (`return` sin `pop`).
- Fecha de ingreso y de fallecimiento son opcionales. Fallecimiento solo se muestra si el estado es `inactivo`.
- Eliminar ficha: diálogo "¿Estás seguro...?". Solo si `idDocumento != null`.
- Salir del formulario con cambios: diálogo "Hay cambios sin guardar" con Cancelar / Descartar / Guardar.
- Eliminar tratamiento diario: "Cancelar", "Pausar" y "Eliminar definitivamente".
- Eliminar evento: "Cancelar" y "Eliminar". No ofrece pausar.
- Un diario pausado, en el formulario, se borra directo (ícono `delete_forever`), sin diálogo.
- Visitante: sin FAB, sin lápiz, sin cámara, sin reordenar, sin marcar dosis, sin el texto "Tocá el ícono de cámara...".
- Dosis anterior a `fechaInicio`: el círculo no es tocable.
- Auto-archivo: un diario vencido desaparece de "Tratamientos activos" de la ficha sin un aviso en pantalla. En el formulario sigue en "Pausados" si `activo` pasó a false.
- Estados vacíos literales: "No hay perritos registrados aún.", "No hay difuntos registrados.", "No se encontraron resultados.", "Aún no hay fotos en la galería", "No hay ficha médica registrada.", "No hay tratamientos diarios activos.", "Sin tratamientos diarios activos.", "Sin eventos ni visitas registrados.", "No hay registros médicos para este día", "Sin familiares registrados.", "No registrada".
- Zoom de texto de la ficha: achicar deshabilitado si `_escalaTexto <= 1.0`. Paso 0.15. No tiene tope superior en el código.
