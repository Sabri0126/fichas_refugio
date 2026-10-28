import { getApps, initializeApp } from 'firebase-admin/app';
import { type Firestore, getFirestore, Timestamp } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { DateTime } from 'luxon';

import {
  type Alarma,
  type DispositivoAviso,
  type PerroEntrada,
  ZONA,
  aZona,
  agruparIngresos,
  calcularAlarmas,
  calcularPausas,
  listaSilenciados,
  tokensParaAlarma,
} from './alarmas.js';
import { esMananaDeAniversario, mensajeAniversario } from './aniversario.js';
import { type CategoriaClima, evaluarClima, momentoClima, normalizarConfig, rachaGuardada } from './clima.js';
import { crearNotificacion, enviarAlarma } from './envio.js';

if (getApps().length === 0) initializeApp();

const REGION = 'southamerica-east1';

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
    const alarmas = agruparIngresos(perros.flatMap((perro) => calcularAlarmas(perro, desde, ahora)));

    const nuevas: Alarma[] = [];
    for (const alarma of alarmas) {
      const creada = await crearNotificacion(db, alarma);
      if (creada) nuevas.push(alarma);
    }

    const dispositivosSnap = await db.collection('dispositivos').get();
    const dispositivos: DispositivoAviso[] = dispositivosSnap.docs.map((doc) => ({
      token: doc.id,
      silenciados: listaSilenciados(doc.get('silenciados')),
    }));
    let enviados = 0;
    let marcadas = 0;
    const tokensMalos = new Set<string>();
    for (const alarma of nuevas) {
      if (alarma.idTratamiento && alarma.dia) {
        marcadas += await marcarDosis(db, alarma.idPerro, alarma.idTratamiento, alarma.dia);
      }
      const resultado = await enviarAlarma(tokensParaAlarma(dispositivos, alarma), alarma);
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
      marcadas,
      tokensEliminados: tokensMalos.size,
      pausas,
    });
  },
);

const OPCIONES_CLIMA = {
  timeZone: ZONA,
  timeoutSeconds: 60,
  maxInstances: 1,
  region: REGION,
};

export const enviarAvisosClima = onSchedule(
  { ...OPCIONES_CLIMA, schedule: '0 8,19 * * *' },
  correrAvisosClima,
);

export const enviarAvisosClimaMediodia = onSchedule(
  { ...OPCIONES_CLIMA, schedule: '30 12 * * *' },
  correrAvisosClima,
);

async function correrAvisosClima(): Promise<void> {
  const db = getFirestore();
  const ahora = DateTime.now().setZone(ZONA);
  if (esMananaDeAniversario(ahora)) {
    const mensaje = { ...mensajeAniversario(ahora), fecha: ahora };
    const creada = await crearNotificacion(db, mensaje);
    if (creada) {
      const dispositivos = await db.collection('dispositivos').get();
      const tokens = dispositivos.docs.map((doc) => doc.id);
      const resultado = await enviarAlarma(tokens, mensaje);
      for (const token of resultado.invalidos) {
        await db.collection('dispositivos').doc(token).delete();
      }
      logger.info('aniversario', { anio: ahora.year, enviados: resultado.enviados });
    }
  }

  const configDoc = await db.doc('config/clima').get();
  const config = normalizarConfig(configDoc.data());
  if (!config.activo) {
    logger.info('enviarAvisosClima', { avisos: 0, enviados: 0 });
    return;
  }

  const crudo = await consultarOpenMeteo(config.latitud, config.longitud);
  if (crudo == null) return;

  const momento = momentoClima(ahora);
  const categoriaManana = momento === 'mediodia' ? await categoriaDeLaManana(db, ahora) : null;
  const avisos = evaluarClima(crudo, config, momento, ahora, {
    categoriaManana,
    rachaAnterior: rachaGuardada(configDoc.data()),
  });
  const dispositivos = await db.collection('dispositivos').get();
  const tokens = dispositivos.docs.map((doc) => doc.id);
  let enviados = 0;
  const tokensMalos = new Set<string>();

  for (const aviso of avisos) {
    const mensaje = {
      clave: aviso.clave,
      titulo: aviso.titulo,
      cuerpo: aviso.cuerpo,
      idPerro: '',
      categoria: aviso.categoria,
      tipo: aviso.tipo,
      fecha: ahora,
    };
    const creada = await crearNotificacion(db, mensaje);
    if (!creada) continue;
    if (aviso.rachaDesde && aviso.rachaHasta) {
      await db.doc('config/clima').set(
        { racha_desde: aviso.rachaDesde, racha_hasta: aviso.rachaHasta },
        { merge: true },
      );
    }
    const resultado = await enviarAlarma(tokens, mensaje);
    enviados += resultado.enviados;
    for (const token of resultado.invalidos) tokensMalos.add(token);
  }

  for (const token of tokensMalos) {
    await db.collection('dispositivos').doc(token).delete();
  }

  logger.info('enviarAvisosClima', { avisos: avisos.length, enviados, momento });
}

async function categoriaDeLaManana(db: Firestore, ahora: DateTime): Promise<CategoriaClima | null> {
  const fecha = ahora.toFormat('yyyyMMdd');
  const doc = await db.doc(`notificaciones/clima_manana_${fecha}`).get();
  const categoria = doc.get('categoria');
  return typeof categoria === 'string' ? (categoria as CategoriaClima) : null;
}

async function consultarOpenMeteo(latitud: number, longitud: number): Promise<unknown | null> {
  const url = new URL('https://api.open-meteo.com/v1/forecast');
  url.searchParams.set('latitude', String(latitud));
  url.searchParams.set('longitude', String(longitud));
  url.searchParams.set('timezone', ZONA);
  url.searchParams.set('forecast_days', '3');
  url.searchParams.set(
    'hourly',
    'temperature_2m,precipitation_probability,precipitation,weather_code,cloud_cover,wind_speed_10m,wind_gusts_10m',
  );
  url.searchParams.set(
    'daily',
    'temperature_2m_max,temperature_2m_min,precipitation_probability_max,precipitation_sum,weather_code,wind_speed_10m_max,wind_gusts_10m_max',
  );

  let ultimo: unknown;
  for (let intento = 0; intento < 2; intento += 1) {
    try {
      const respuesta = await fetch(url, { signal: AbortSignal.timeout(10_000) });
      if (!respuesta.ok) throw new Error(`Open-Meteo respondió ${respuesta.status}`);
      return (await respuesta.json()) as unknown;
    } catch (error) {
      ultimo = error;
    }
  }

  const mensaje = ultimo instanceof Error ? ultimo.message : 'error desconocido';
  logger.error('enviarAvisosClima: consulta fallida', { mensaje });
  return null;
}

function inicioDeVentana(ultima: unknown, ahora: DateTime): DateTime {
  const piso = ahora.minus({ hours: 12 });
  const fecha = aZona(ultima);
  if (!fecha) return ahora.minus({ minutes: 5 });
  return fecha > piso ? fecha : piso;
}

async function marcarDosis(
  db: Firestore,
  idPerro: string,
  idTratamiento: string,
  dia: string,
): Promise<number> {
  return db.runTransaction(async (tx) => {
    const ref = db.collection('perros').doc(idPerro);
    const snap = await tx.get(ref);
    if (!snap.exists) return 0;
    const tratamientos = snap.get('tratamientos');
    if (!Array.isArray(tratamientos)) return 0;
    let cambios = 0;
    const actualizados = tratamientos.map((item) => {
      if (typeof item !== 'object' || item == null) return item;
      const tratamiento = item as { id?: string; registro_dosis?: unknown };
      if ((tratamiento.id?.toString() ?? '') !== idTratamiento) return item;
      const registro = Array.isArray(tratamiento.registro_dosis)
        ? tratamiento.registro_dosis.map((fecha) => fecha?.toString() ?? '')
        : [];
      if (registro.includes(dia)) return item;
      cambios += 1;
      return { ...tratamiento, registro_dosis: [...registro, dia] };
    });
    if (cambios > 0) tx.update(ref, { tratamientos: actualizados });
    return cambios;
  });
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

