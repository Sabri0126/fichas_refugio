import { type Firestore, FieldValue, Timestamp } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { DateTime } from 'luxon';

const CANAL_ANDROID = 'tratamientos_diarios';
const TOKENS_INVALIDOS = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
]);

export interface MensajePush {
  clave: string;
  titulo: string;
  cuerpo: string;
  idPerro: string;
  categoria: string;
  tipo: string;
  fecha: DateTime;
  idTratamiento?: string;
  dia?: string;
}

export async function crearNotificacion(db: Firestore, mensaje: MensajePush): Promise<boolean> {
  try {
    await db.collection('notificaciones').doc(mensaje.clave).create({
      titulo: mensaje.titulo,
      cuerpo: mensaje.cuerpo,
      id_perro: mensaje.idPerro,
      categoria: mensaje.categoria,
      tipo: mensaje.tipo,
      fecha: Timestamp.fromDate(mensaje.fecha.toJSDate()),
      ...(mensaje.idTratamiento ? { id_tratamiento: mensaje.idTratamiento } : {}),
      ...(mensaje.dia ? { dia: mensaje.dia } : {}),
      creada: FieldValue.serverTimestamp(),
      expira_en: Timestamp.fromDate(mensaje.fecha.plus({ days: 30 }).toJSDate()),
    });
    return true;
  } catch (error) {
    if (yaExiste(error)) return false;
    throw error;
  }
}

export async function enviarAlarma(
  tokens: string[],
  mensaje: MensajePush,
): Promise<{ enviados: number; invalidos: string[] }> {
  let enviados = 0;
  const invalidos: string[] = [];
  for (let i = 0; i < tokens.length; i += 500) {
    const lote = tokens.slice(i, i + 500);
    if (lote.length === 0) continue;
    const respuesta = await getMessaging().sendEachForMulticast({
      tokens: lote,
      notification: { title: mensaje.titulo, body: mensaje.cuerpo },
      data: {
        id_perro: mensaje.idPerro,
        tipo: mensaje.tipo,
        notif_id: mensaje.clave,
        ...(mensaje.idTratamiento ? { id_tratamiento: mensaje.idTratamiento } : {}),
        ...(mensaje.dia ? { dia: mensaje.dia } : {}),
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

function yaExiste(error: unknown): boolean {
  const codigo = (error as { code?: number | string }).code;
  return codigo === 6 || codigo === 'already-exists' || codigo === 'ALREADY_EXISTS';
}
