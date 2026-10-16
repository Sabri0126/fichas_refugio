# Notificaciones en el servidor

Los avisos salen de una Cloud Function programada. Llegan a todos los celulares con cuenta, aunque nadie abra la app. Los visitantes no tienen token y no reciben nada.

La función se llama `enviarNotificaciones`. Corre cada 5 minutos, en `America/Argentina/Buenos_Aires`, región `southamerica-east1` (São Paulo). En el repo no figura la región de Firestore; si la base está en otro lado, las lecturas cruzan regiones y se puede mover la función después.

No despliegues nada hasta completar los pasos de abajo.

## 1. Requisitos

El proyecto `fichas-refugio` tiene que estar en el plan **Blaze**. Las funciones programadas no corren en el plan gratuito.

En la consola de Google Cloud, en Facturación, creá una **alerta de presupuesto** antes del primer deploy. Con el uso de un refugio el costo es bajo, pero la alerta avisa si algo se dispara.

Cada ejecución lee una vez el documento de cada perro activo, más `config/notificaciones` y los documentos de `dispositivos`.

Con una corrida cada 5 minutos hay **288 ejecuciones por día**.

| Perros activos | Lecturas de perros por día | Por mes (30 días) |
| --- | ---: | ---: |
| 20 | 5.760 | 172.800 |
| 50 | 14.400 | 432.000 |
| 100 | 28.800 | 864.000 |

Firestore cobra alrededor de **USD 0,06 cada 100.000 lecturas**. Con 50 perros activos, solo esas lecturas salen cerca de **USD 0,26 por mes**. Sumá 288 lecturas diarias de la config y una por cada celular registrado.

Las escrituras son menos: una de `ultima_ejecucion` por corrida, una por aviso nuevo y una transacción cuando hay que pausar un tratamiento. Cloud Functions y Cloud Scheduler, con una sola tarea cada 5 minutos, quedan dentro del tramo gratuito habitual.

## 2. Comandos

Desde la raíz del repo, en PowerShell:

```powershell
npm --prefix functions install
npm --prefix functions test
npm --prefix functions run build
firebase login
firebase deploy --only functions
```

`firebase.json` ya apunta el código a `functions/` y `.firebaserc` usa el proyecto `fichas-refugio`. El deploy compila antes de subir (`npm --prefix functions run build`).

## 3. Borrado automático del historial

Los avisos guardados en `notificaciones` tienen el campo `expira_en`, 30 días después de la ocurrencia. Firestore no los borra hasta que activás el TTL, una sola vez:

```powershell
gcloud firestore fields ttls update expira_en --collection-group=notificaciones --enable-ttl
```

Tiene que ser la misma cuenta y el mismo proyecto del deploy. El borrado real puede tardar hasta un día después de la fecha.

## 4. Reglas para pegar

No reemplaces el archivo de reglas. Sumá estos bloques dentro de `match /databases/{database}/documents`.

```
match /dispositivos/{token} {
  allow read: if false;
  allow create, update: if request.auth != null
    && request.resource.data.uid == request.auth.uid;
  allow delete: if request.auth != null
    && resource.data.uid == request.auth.uid;
}

match /notificaciones/{id} {
  allow read: if request.auth != null;
  allow write: if false;
}

match /config/{doc} {
  allow read, write: if false;
}
```

La función corre con la cuenta de servicio de Admin y no pasa por estas reglas. Los visitantes no están autenticados, así que no leen `notificaciones` ni escriben `dispositivos`.

## 5. Probar sin esperar los 5 minutos

Los tests de la lógica, sin Firebase:

```powershell
npm --prefix functions test
```

Para una corrida contra el emulador, en otra terminal, desde la raíz:

```powershell
firebase emulators:start --only functions,firestore
```

En la terminal del emulador, o con el shell:

```powershell
firebase functions:shell
```

Ahí invocá `enviarNotificaciones()`. Antes, cargá en el emulador un perro con `estado: "activo"` y un tratamiento diario cuya hora caiga en los próximos minutos, y un documento en `dispositivos` cuyo id sea un token de prueba.

Los logs de una corrida real:

```powershell
firebase functions:log --only enviarNotificaciones
```

Cada corrida deja un log `enviarNotificaciones` con la cantidad de alarmas, envíos, tokens borrados y pausas. No incluye nombres ni medicación.

## 7. Clima

Hay una segunda función, `enviarAvisosClima`. Corre a las 08:00 y a las 19:00, hora de Buenos Aires, en la misma región `southamerica-east1`. A la mañana manda un solo aviso: la condición más importante del día (granizo, tormenta, lluvia fuerte, calor, viento, lluvia, llovizna, frío durante el día, nublado o, si no hay ninguna, un día lindo para trabajar). El resto queda en una línea que empieza con "También". A la noche evalúa el frío o la helada de la noche que empieza. El frío de día (la máxima no sube) es distinto de la helada nocturna. Manda el push a los mismos documentos de `dispositivos` y guarda el aviso en `notificaciones`. Los visitantes no tienen token y no lo reciben.

### Documento `config/clima`

Crearlo a mano en la consola de Firestore, colección `config`, id `clima`. Si no existe, o si falta un campo, la función usa estos valores. Un número que no sea un número finito se ignora y vuelve al valor de la tabla.

| Campo | Default | Unidad |
| --- | --- | --- |
| `activo` | `true` | Si es `false`, la corrida no consulta ni envía nada. |
| `latitud` | `-39.00560084311861` | Grados, WGS84. |
| `longitud` | `-64.05354141817675` | Grados, WGS84. Negativo es oeste. |
| `lugar` | `Refugio Milagros de Amor, Río Colorado, Río Negro` | Nombre de referencia. No sale en el texto del aviso. |
| `lluvia_prob_min` | `60` | Porcentaje. Entre las 08 y las 22. Con milímetros por debajo de `lluvia_mm_min` avisa llovizna; si no hay milímetros, avisa lluvia. |
| `lluvia_mm_min` | `2` | Milímetros. Avisa lluvia si la suma en ese tramo llega a este valor. |
| `lluvia_fuerte_mm` | `15` | Milímetros. Avisa lluvia fuerte si la suma llega a este valor, o si el código del tiempo es lluvia fuerte. |
| `calor_max` | `30` | °C. Máxima diaria. |
| `frio_min` | `4` | °C. Mínima entre las 20:00 y las 08:00 del día siguiente. |
| `helada_max` | `0` | °C. Si la mínima de esa noche es menor o igual, el aviso es de helada en vez de frío. |
| `viento_kmh` | `40` | km/h. Viento sostenido entre las 08 y las 22. |
| `rafaga_kmh` | `60` | km/h. Ráfaga en ese mismo tramo. |
| `frio_dia_max` | `12` | °C. Si la máxima del día no supera este valor, avisa que hará frío todo el día. |
| `nublado_min` | `80` | Porcentaje de nubosidad promedio. Solo si no hay precipitación. |
| `lindo_min` | `15` | °C. Piso de la máxima para el aviso de día lindo. |
| `lindo_max` | `28` | °C. Techo de la máxima para el aviso de día lindo. |

Para mudar el refugio, cambiá `latitud` y `longitud`. Para avisar con menos calor, por ejemplo, poné `calor_max` en `10`.

### Probar una corrida

En Google Cloud, Cloud Scheduler, abrí el trabajo de `enviarAvisosClima` y usá **Forzar ejecución**. La hora local de esa corrida decide si evalúa la mañana (antes de las 12) o la noche.

El id de la mañana es fijo: `clima_manana_{yyyyMMdd}`, por ejemplo `notificaciones/clima_manana_20261013`. El de la noche sigue siendo `clima_frio_{yyyyMMdd}_noche`. `create()` no lo vuelve a escribir si ya existe, así que una segunda corrida del mismo día no manda otro push aunque el pronóstico cambie. Para repetir la prueba, borrá ese documento en la consola y forzá de nuevo.

El día lindo sale solo si no hay ninguna otra alerta: máxima entre `lindo_min` y `lindo_max`, nubosidad de hasta 40 %, probabilidad de lluvia de hasta 20 % y viento de hasta 25 km/h.

Logs:

```powershell
firebase functions:log --only enviarAvisosClima
```

Cada corrida deja `avisos` y `enviados`. Si Open-Meteo no responde, el log es `enviarAvisosClima: consulta fallida` y no se envía nada.

### Costo y atribución

Son dos llamadas por día a Open-Meteo, sin clave. El uso no comercial de esa API es gratis. Hay que atribuir la fuente: la pantalla de notificaciones muestra `Datos del clima: Open-Meteo.com`.


## 8. Seguimientos

Un seguimiento es una observación diaria de un perro: un ojo, una herida, el ánimo, una pata, una uña, el comportamiento u otro motivo. Vive en el array `seguimientos` del documento del perro, no en una colección aparte.

Cada elemento tiene `id`, `motivo`, `detalle`, `hora` (por defecto `18:00`), `fecha_inicio`, `dias_duracion` y `activo`. `dias_duracion` en `0` no tiene fecha de fin: sigue hasta que alguien lo cierra. Cerrarlo pone `activo` en `false`. La función no escribe ese campo; el fin por días se calcula con la fecha.

`enviarNotificaciones` arma un aviso por día, a la hora del seguimiento, mientras el perro esté `activo` y el seguimiento también. El id es `{idPerro}_seguimiento_{id}_{yyyyMMddHHmm}`. El último día agrega una frase para extenderlo o consultar al veterinario. Al tocar el aviso se abre la ficha del perro.

## 6. Limitaciones

- Si `dispositivos` está vacío, el historial se guarda y los tratamientos vencidos se pausan, pero nadie recibe el push.
- Si la función falla después de crear `notificaciones/{clave}` y antes del envío, esa clave no se vuelve a mandar. El push de esa vuelta se pierde. La ventana siguiente sigue con el resto.
- En Samsung y Xiaomi, el ahorro de batería puede demorar el aviso aunque FCM ya lo haya entregado. El canal Android es `tratamientos_diarios`, el mismo de la app, con prioridad alta.
