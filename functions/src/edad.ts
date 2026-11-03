import { type Firestore, type QueryDocumentSnapshot, Timestamp } from 'firebase-admin/firestore';
import { DateTime } from 'luxon';

import { type Alarma, ZONA, aZona } from './alarmas.js';
import { crearNotificacion } from './envio.js';

/// Meses de calendario entre dos fechas, sin mirar el día.
export function mesesCalendario(desde: DateTime, hasta: DateTime): number {
  return (hasta.year - desde.year) * 12 + hasta.month - desde.month;
}

/// Suma meses a una edad. `cruzoUnAnio` solo la primera vez que deja los 0 años.
export function avanzarEdad(
  edad: number,
  meses: number,
  mesesPasados: number,
): { edad: number; meses: number; cruzoUnAnio: boolean } | null {
  if (mesesPasados <= 0) return null;
  const total = edad * 12 + meses + mesesPasados;
  if (total < 0) return null;
  return {
    edad: Math.floor(total / 12),
    meses: total % 12,
    cruzoUnAnio: edad === 0 && total >= 12,
  };
}

interface CambioEdad {
  ref: QueryDocumentSnapshot['ref'];
  datos: Record<string, unknown>;
  aviso: Alarma | null;
}

/// Avanza la edad de los activos que cuentan por meses y arma el aviso de 1 año.
/// La notificación se crea antes de escribir la edad, para poder reintentar.
export async function actualizarEdadesPorMes(
  db: Firestore,
  docs: QueryDocumentSnapshot[],
  ahora: DateTime,
): Promise<Alarma[]> {
  const ahoraZona = ahora.setZone(ZONA);
  const cambios: CambioEdad[] = [];

  for (const doc of docs) {
    const data = doc.data();
    if (data.edad_indeterminada === true) continue;
    const fallecio = data.fecha_fallecimiento;
    if (fallecio != null && String(fallecio).trim() !== '') continue;

    const edad = numero(data.edad);
    const cuenta = data.cuenta_meses === true || edad === 0;
    if (!cuenta) continue;

    const ultima = aZona(data.ultima_actualizacion_edad) ?? aZona(data.fecha_ingreso);
    if (!ultima) continue;

    const avance = avanzarEdad(edad, numero(data.meses), mesesCalendario(ultima, ahoraZona));
    if (!avance) continue;

    const nombre = data.nombre?.toString().trim() || 'Un perro';
    cambios.push({
      ref: doc.ref,
      datos: {
        edad: avance.edad,
        meses: avance.meses,
        cuenta_meses: true,
        ultima_actualizacion_edad: Timestamp.fromDate(ahoraZona.toJSDate()),
      },
      aviso: avance.cruzoUnAnio
        ? {
            clave: `cumple_1_${doc.id}`,
            tipo: 'cumple_1',
            titulo: 'Cumple 1 año',
            cuerpo: `${nombre} cumple 1 año este mes.`,
            categoria: 'cumple_1',
            idPerro: doc.id,
            fecha: ahoraZona,
          }
        : null,
    });
  }

  const nuevas: Alarma[] = [];
  for (const cambio of cambios) {
    if (!cambio.aviso) continue;
    const creada = await crearNotificacion(db, cambio.aviso);
    if (creada) nuevas.push(cambio.aviso);
  }

  for (let i = 0; i < cambios.length; i += 400) {
    const lote = db.batch();
    for (const cambio of cambios.slice(i, i + 400)) {
      lote.update(cambio.ref, cambio.datos);
    }
    await lote.commit();
  }

  return nuevas;
}

function numero(valor: unknown): number {
  const parsed = Number.parseInt(String(valor ?? '0'), 10);
  return Number.isFinite(parsed) ? parsed : 0;
}
