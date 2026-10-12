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

## 6. Limitaciones

- Si `dispositivos` está vacío, el historial se guarda y los tratamientos vencidos se pausan, pero nadie recibe el push.
- Si la función falla después de crear `notificaciones/{clave}` y antes del envío, esa clave no se vuelve a mandar. El push de esa vuelta se pierde. La ventana siguiente sigue con el resto.
- En Samsung y Xiaomi, el ahorro de batería puede demorar el aviso aunque FCM ya lo haya entregado. El canal Android es `tratamientos_diarios`, el mismo de la app, con prioridad alta.
