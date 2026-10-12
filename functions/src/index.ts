import { getApps, initializeApp } from 'firebase-admin/app';
import { type Firestore, FieldValue, getFirestore, Timestamp } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { logger } from 'firebase-functions';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { DateTime } from 'luxon';

import { type Alarma, type PerroEntrada, ZONA, aZona, calcularAlarmas, calcularPausas } from './alarmas.js';

if (getApps().length === 0) initializeApp();

const CANAL_ANDROID = 'tratamientos_diarios';
const REGION = 'southamerica-east1';
const TOKENS_INVALIDOS = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
]);

export const enviarNotificaciones = onSchedule(
  {
    schedule: 'every 5 minutes',
    timeZone: ZONA,
    timeoutSeconds: 120,
    maxInstances: 1,
    region: REGION,
  },
  async () => {
    const db = getFirestore();
    const ahora = DateTime.now().setZone(ZONA);
    const configRef = db.doc('config/notificaciones');
    const config = await configRef.get();
    const desde = inicioDeVentana(config.get('ultima_ejecucion'), ahora);

    const perrosSnap = await db.collection('perros').where('estado', '==', 'activo').get();
    const perros = perrosSnap.docs.map((doc) => ({ id: doc.id, ...doc.data() }) as PerroEntrada);
    const alarmas = perros.flatMap((perro) => calcularAlarmas(perro, desde, ahora));

    const nuevas: Alarma[] = [];
    for (const alarma of alarmas) {
      const creada = await crearNotificacion(db, alarma);
      if (creada) nuevas.push(alarma);
    }

    const dispositivos = await db.collection('dispositivos').get();
    const tokens = dispositivos.docs.map((doc) => doc.id);
    let enviados = 0;
    const tokensMalos = new Set<string>();
    for (const alarma of nuevas) {
      const resultado = await enviarAlarma(tokens, alarma);
      enviados += resultado.enviados;
      for (const token of resultado.invalidos) tokensMalos.add(token);
    }
    for (const token of tokensMalos) {
      await db.collection('dispositivos').doc(token).delete();
    }

    let pausas = 0;
    for (const perro of perros) {
      const ids = calcularPausas(perro, ahora);
      if (ids.length === 0 || !perro.id) continue;
      pausas += await pausarTratamientos(db, perro.id, ids);
    }

    await configRef.set({ ultima_ejecucion: Timestamp.fromDate(ahora.toJSDate()) }, { merge: true });

    logger.info('enviarNotificaciones', {
      alarmas: alarmas.length,
      enviados,
      tokensEliminados: tokensMalos.size,
      pausas,
    });
  },
);

function inicioDeVentana(ultima: unknown, ahora: DateTime): DateTime {
  const piso = ahora.minus({ hours: 12 });
  const fecha = aZona(ultima);
  if (!fecha) return ahora.minus({ minutes: 5 });
  return fecha > piso ? fecha : piso;
}

async function crearNotificacion(
  db: Firestore,
  alarma: Alarma,
): Promise<boolean> {
  try {
    await db.collection('notificaciones').doc(alarma.clave).create({
      titulo: alarma.titulo,
      cuerpo: alarma.cuerpo,
      id_perro: alarma.idPerro,
      categoria: alarma.categoria,
      tipo: alarma.tipo,
      fecha: Timestamp.fromDate(alarma.fecha.toJSDate()),
      creada: FieldValue.serverTimestamp(),
      expira_en: Timestamp.fromDate(alarma.fecha.plus({ days: 30 }).toJSDate()),
    });
    return true;
  } catch (error) {
    if (yaExiste(error)) return false;
    throw error;
  }
}

async function enviarAlarma(
  tokens: string[],
  alarma: Alarma,
): Promise<{ enviados: number; invalidos: string[] }> {
  let enviados = 0;
  const invalidos: string[] = [];
  for (let i = 0; i < tokens.length; i += 500) {
    const lote = tokens.slice(i, i + 500);
    if (lote.length === 0) continue;
    const respuesta = await getMessaging().sendEachForMulticast({
      tokens: lote,
      notification: { title: alarma.titulo, body: alarma.cuerpo },
      data: {
        id_perro: alarma.idPerro,
        tipo: alarma.tipo,
        notif_id: alarma.clave,
      },
      android: {
        priority: 'high',
        ttl: 12 * 60 * 60 * 1000,
        notification: { channelId: CANAL_ANDROID },
      },
    });
    enviados += respuesta.successCount;
    respuesta.responses.forEach((item, indice) => {
      const codigo = item.error?.code;
      if (codigo && TOKENS_INVALIDOS.has(codigo)) invalidos.push(lote[indice]);
    });
  }
  return { enviados, invalidos };
}

async function pausarTratamientos(
  db: Firestore,
  idPerro: string,
  ids: string[],
): Promise<number> {
  const buscados = new Set(ids);
  return db.runTransaction(async (tx) => {
    const ref = db.collection('perros').doc(idPerro);
    const snap = await tx.get(ref);
    if (!snap.exists) return 0;
    const tratamientos = snap.get('tratamientos');
    if (!Array.isArray(tratamientos)) return 0;
    let cambios = 0;
    const actualizados = tratamientos.map((item) => {
      if (typeof item !== 'object' || item == null) return item;
      const tratamiento = item as { id?: string; activo?: boolean };
      if (!buscados.has(tratamiento.id?.toString() ?? '') || tratamiento.activo === false) return item;
      cambios += 1;
      return { ...tratamiento, activo: false };
    });
    if (cambios > 0) tx.update(ref, { tratamientos: actualizados });
    return cambios;
  });
}

function yaExiste(error: unknown): boolean {
  const codigo = (error as { code?: number | string }).code;
  return codigo === 6 || codigo === 'already-exists' || codigo === 'ALREADY_EXISTS';
}
