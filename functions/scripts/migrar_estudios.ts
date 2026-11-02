/**
 * Migración de galeria_estudios a perros/{id}/estudios.
 * No borra archivos de galeria_perros/.
 *
 * Simulación (no escribe):
 *   npx tsx scripts/migrar_estudios.ts --perro=ID_DE_FICHATEST
 * Aplicar:
 *   npx tsx scripts/migrar_estudios.ts --perro=ID_DE_FICHATEST --aplicar
 * Quitar el campo, solo si cada URL ya tiene su archivo:
 *   npx tsx scripts/migrar_estudios.ts --perro=ID_DE_FICHATEST --quitar-campo
 */
import { mkdir, writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { tieneTokenDescarga } from '../src/token_estudios.ts';

export { tieneTokenDescarga };

export interface EntradaLegacy {
  url: string;
  texto: string;
}

export interface DocumentoEstudio {
  origenUrl?: string;
  ruta: string;
  orden?: number;
}

export function rutaDesdeUrl(url: string, bucket: string): string | null {
  let parsed: URL;
  try {
    parsed = new URL(url);
  } catch {
    return null;
  }
  const coincidencia = parsed.pathname.match(/\/b\/([^/]+)\/o\/(.+)$/);
  if (!coincidencia) return null;
  const bucketUrl = decodeURIComponent(coincidencia[1]);
  if (bucketUrl !== bucket) return null;
  return decodeURIComponent(coincidencia[2]);
}

/**
 * `setMetadata` fusiona la metadata custom: omitir la clave no la borra.
 * Hay que mandarla en null para que Storage la quite.
 */
export function metadataSinToken(
  metadata: Record<string, string | number | boolean | null> | null | undefined,
): Record<string, string | null> {
  const copia: Record<string, string | null> = {};
  for (const [clave, valor] of Object.entries(metadata ?? {})) {
    if (valor == null) continue;
    copia[clave] = String(valor);
  }
  copia.firebaseStorageDownloadTokens = null;
  return copia;
}

const EXTENSION_POR_TIPO: Record<string, string> = {
  'image/jpeg': '.jpg',
  'image/jpg': '.jpg',
  'image/png': '.png',
  'image/webp': '.webp',
  'application/pdf': '.pdf',
};

/** image/jpeg → .jpg. Si el tipo no está en la lista, usa la extensión del origen. */
export function extensionDe(contentType: string | null | undefined, rutaOrigen: string): string {
  const tipo = (contentType ?? '').split(';')[0].trim().toLowerCase();
  const conocida = EXTENSION_POR_TIPO[tipo];
  if (conocida) return conocida;
  const nombre = rutaOrigen.split('/').pop() ?? '';
  const punto = nombre.lastIndexOf('.');
  if (punto > 0 && punto < nombre.length - 1) {
    const ext = nombre.slice(punto).toLowerCase();
    if (/^\.[a-z0-9]+$/.test(ext)) return ext;
  }
  return '.jpg';
}

export function contentTypesIguales(
  origen: string | null | undefined,
  destino: string | null | undefined,
): boolean {
  const normalizar = (valor: string | null | undefined) => (valor ?? '').split(';')[0].trim().toLowerCase();
  return normalizar(origen) === normalizar(destino);
}

export function esRutaGaleriaPerros(ruta: string): boolean {
  if (!ruta.startsWith('galeria_perros/')) return false;
  const resto = ruta.slice('galeria_perros/'.length);
  if (resto.length === 0) return false;
  return resto.split('/').every((parte) => parte.length > 0 && parte !== '.' && parte !== '..');
}

export function esDestinoEstudio(ruta: string): boolean {
  if (!ruta.startsWith('estudios_medicos/')) return false;
  const resto = ruta.slice('estudios_medicos/'.length);
  if (resto.length === 0) return false;
  return resto.split('/').every((parte) => parte.length > 0 && parte !== '.' && parte !== '..');
}

/** El orden nuevo sigue al máximo que ya está en la subcolección. */
export function ordenMigrado(documentos: readonly { orden?: number }[], indice: number): number {
  const ordenes = documentos
    .map((doc) => doc.orden)
    .filter((orden): orden is number => typeof orden === 'number' && Number.isFinite(orden));
  const maximo = ordenes.length === 0 ? -1 : Math.max(...ordenes);
  return maximo + 1 + indice;
}

interface MetaLeida {
  size?: string | number;
  contentType?: string | null;
  metadata?: Record<string, string | number | boolean | null> | null;
}

interface OpcionesCopia {
  contentType?: string;
  metadata?: Record<string, string | null>;
}

export async function copiarEstudio(
  origen: {
    getMetadata: () => Promise<[MetaLeida, ...unknown[]]>;
    copy: (destino: unknown, opciones?: OpcionesCopia) => Promise<unknown>;
  },
  destino: {
    getMetadata: () => Promise<[MetaLeida, ...unknown[]]>;
    setMetadata: (metadata: OpcionesCopia) => Promise<unknown>;
    delete: (opciones?: { ignoreNotFound?: boolean }) => Promise<unknown>;
  },
): Promise<void> {
  const [meta] = await origen.getMetadata();
  const limpia = metadataSinToken(meta.metadata);
  const contentType = contentTypeUtil(meta.contentType);
  const opciones: OpcionesCopia = { metadata: limpia };
  if (contentType) opciones.contentType = contentType;
  let copiado = false;
  try {
    await origen.copy(destino, opciones);
    copiado = true;
    await destino.setMetadata(opciones);
    const [destinoMeta] = await destino.getMetadata();
    if (tieneTokenDescarga(destinoMeta.metadata)) {
      throw new Error('el destino conservó firebaseStorageDownloadTokens');
    }
    if (Number(destinoMeta.size ?? -1) !== Number(meta.size ?? -2)) {
      throw new Error('el tamaño no coincide en el archivo copiado');
    }
    if (!contentTypesIguales(meta.contentType, destinoMeta.contentType)) {
      throw new Error(
        `el contentType no coincide: origen ${meta.contentType ?? 'null'}, destino ${destinoMeta.contentType ?? 'null'}`,
      );
    }
  } catch (error) {
    if (copiado) await descartarDestino(destino);
    throw error;
  }
}

function contentTypeUtil(valor: string | null | undefined): string | undefined {
  if (typeof valor !== 'string') return undefined;
  const limpio = valor.trim();
  return limpio === '' ? undefined : limpio;
}

async function descartarDestino(destino: {
  delete: (opciones?: { ignoreNotFound?: boolean }) => Promise<unknown>;
}): Promise<void> {
  try {
    await destino.delete({ ignoreNotFound: true });
  } catch {
    // Se informa el error de la copia; el borrado es el intento de no dejar el archivo.
  }
}

/** Borra solo el archivo recién copiado a estudios_medicos/. */
export async function borrarDestinoCopiado(
  ruta: string,
  borrar: (ruta: string) => Promise<void>,
): Promise<void> {
  if (!esDestinoEstudio(ruta) || ruta.includes('galeria_perros/')) return;
  await borrar(ruta);
}

export function yaMigrado(url: string, documentos: DocumentoEstudio[]): boolean {
  return documentos.some((doc) => doc.origenUrl === url);
}

export interface PlanEntrada {
  estado: 'salteado' | 'simulado' | 'copiado' | 'error';
  origen?: string;
  destino?: string;
  detalle?: string;
}

export async function procesarEntrada(
  entrada: EntradaLegacy,
  opciones: {
    aplicar: boolean;
    bucket: string;
    perroId: string;
    estudioId: string;
    documentos: DocumentoEstudio[];
    tamanoOrigen: (ruta: string) => Promise<number | null>;
    contentTypeOrigen?: (ruta: string) => Promise<string | null>;
    copiar: (origen: string, destino: string) => Promise<void>;
    crear: (estudioId: string, ruta: string, texto: string, orden: number, origenUrl: string) => Promise<void>;
    borrarDestino: (ruta: string) => Promise<void>;
    orden: number;
  },
): Promise<PlanEntrada> {
  if (yaMigrado(entrada.url, opciones.documentos)) {
    return { estado: 'salteado', detalle: 'ya tenía documento' };
  }
  const origen = rutaDesdeUrl(entrada.url, opciones.bucket);
  if (!origen) return { estado: 'error', detalle: 'la URL no es del bucket del proyecto' };
  if (!esRutaGaleriaPerros(origen)) {
    return { estado: 'error', origen, detalle: 'el origen no está en galeria_perros/' };
  }
  const contentType = (await opciones.contentTypeOrigen?.(origen)) ?? null;
  const destino = `estudios_medicos/${opciones.perroId}/${opciones.estudioId}${extensionDe(contentType, origen)}`;
  const tamano = await opciones.tamanoOrigen(origen);
  if (tamano == null) {
    return { estado: 'error', origen, destino, detalle: 'el archivo de origen no existe' };
  }
  if (!opciones.aplicar) {
    return {
      estado: 'simulado',
      origen,
      destino,
      detalle: `tamaño ${tamano}${contentType ? `, ${contentType}` : ''}`,
    };
  }
  try {
    await opciones.copiar(origen, destino);
  } catch (error) {
    return { estado: 'error', origen, destino, detalle: mensaje(error) };
  }
  try {
    await opciones.crear(opciones.estudioId, destino, entrada.texto, opciones.orden, entrada.url);
  } catch (error) {
    await borrarDestinoCopiado(destino, opciones.borrarDestino);
    return { estado: 'error', origen, destino, detalle: mensaje(error) };
  }
  return { estado: 'copiado', origen, destino };
}

function mensaje(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

export function puedeQuitarCampo(entrada: {
  urls: string[];
  documentos: DocumentoEstudio[];
  tamanoDestino: (ruta: string) => number | null;
  tamanoOrigen: (url: string) => number | null;
}): { ok: boolean; detalle: string } {
  for (const url of entrada.urls) {
    const doc = entrada.documentos.find((item) => item.origenUrl === url);
    if (!doc) return { ok: false, detalle: `falta el documento de ${url}` };
    const destino = entrada.tamanoDestino(doc.ruta);
    const origen = entrada.tamanoOrigen(url);
    if (destino == null) return { ok: false, detalle: `falta el archivo ${doc.ruta}` };
    if (origen == null || destino !== origen) {
      return { ok: false, detalle: `el tamaño no coincide en ${doc.ruta}` };
    }
  }
  return { ok: true, detalle: 'listo' };
}

function leerOrden(valor: unknown): number | undefined {
  if (typeof valor === 'number' && Number.isFinite(valor)) return valor;
  if (typeof valor === 'string' && valor.trim() !== '' && Number.isFinite(Number(valor))) return Number(valor);
  return undefined;
}

function esCli(): boolean {
  const argumento = process.argv[1]?.replaceAll('\\', '/') ?? '';
  return argumento.endsWith('migrar_estudios.ts') || argumento.endsWith('migrar_estudios.js');
}

async function main(): Promise<void> {
  const argumentos = new Map<string, string>();
  let aplicar = false;
  let todos = false;
  let quitarCampo = false;
  for (const arg of process.argv.slice(2)) {
    if (arg === '--aplicar') aplicar = true;
    else if (arg === '--todos') todos = true;
    else if (arg === '--quitar-campo') quitarCampo = true;
    else if (arg.startsWith('--perro=')) argumentos.set('perro', arg.slice('--perro='.length));
  }
  const perro = argumentos.get('perro');
  if (!perro && !todos) {
    console.error('Falta --perro=<id>, o pasá --todos.');
    process.exitCode = 1;
    return;
  }

  const admin = await import('firebase-admin');
  if (admin.apps.length === 0) admin.initializeApp();
  const db = admin.firestore();
  const bucket = admin.storage().bucket();
  const nombreBucket = bucket.name;

  const ids = todos
    ? (await db.collection('perros').get()).docs.map((doc) => doc.id)
    : [perro!];

  const resumen: Record<string, unknown>[] = [];
  let huboError = false;

  for (const id of ids) {
    const doc = await db.collection('perros').doc(id).get();
    const campo = doc.get('galeria_estudios');
    const entradas: EntradaLegacy[] = Array.isArray(campo)
      ? campo
          .filter((item): item is { url?: string; texto?: string; descripcion?: string } => !!item && typeof item === 'object')
          .map((item) => ({
            url: String(item.url ?? ''),
            texto: String(item.texto ?? item.descripcion ?? ''),
          }))
          .filter((item) => item.url.length > 0)
      : [];
    const existentes = await db.collection('perros').doc(id).collection('estudios').get();
    const documentos: DocumentoEstudio[] = existentes.docs.map((item) => ({
      origenUrl: item.get('origenUrl')?.toString(),
      ruta: item.get('ruta')?.toString() ?? '',
      orden: leerOrden(item.get('orden')),
    }));
    const ordenesIniciales = documentos.map((item) => ({ orden: item.orden }));
    const resultados: PlanEntrada[] = [];
    const leidos = new Map<string, { tamano: number | null; contentType: string | null }>();
    const leerArchivo = async (ruta: string) => {
      const previo = leidos.get(ruta);
      if (previo) return previo;
      const info = await describirArchivo(bucket, ruta);
      leidos.set(ruta, info);
      return info;
    };

    if (quitarCampo) {
      const conTamanos = await tamanosReales(bucket, entradas, documentos, nombreBucket);
      if (!conTamanos.ok) {
        huboError = true;
        resumen.push({ perro: id, quitarCampo: false, detalle: conTamanos.detalle });
        console.log(`${id}: no se quita el campo (${conTamanos.detalle})`);
        continue;
      }
      if (aplicar) {
        await db.collection('perros').doc(id).update({ galeria_estudios: admin.firestore.FieldValue.delete() });
      }
      resumen.push({ perro: id, quitarCampo: true, simulado: !aplicar });
      console.log(`${id}: ${aplicar ? 'campo quitado' : 'se podría quitar el campo'}`);
      continue;
    }

    for (let i = 0; i < entradas.length; i++) {
      const entrada = entradas[i];
      try {
        const resultado = await procesarEntrada(entrada, {
          aplicar,
          bucket: nombreBucket,
          perroId: id,
          estudioId: db.collection('perros').doc().id,
          documentos,
          orden: ordenMigrado(ordenesIniciales, i),
          tamanoOrigen: async (ruta) => (await leerArchivo(ruta)).tamano,
          contentTypeOrigen: async (ruta) => (await leerArchivo(ruta)).contentType,
          copiar: async (origenRuta, destinoRuta) => {
            const origen = bucket.file(origenRuta);
            const destino = bucket.file(destinoRuta);
            await copiarEstudio(
              {
                getMetadata: () => origen.getMetadata(),
                copy: (_destino, opciones) => origen.copy(destino, opciones),
              },
              {
                getMetadata: () => destino.getMetadata(),
                setMetadata: (metadata) => destino.setMetadata(metadata),
                delete: () => destino.delete({ ignoreNotFound: true }),
              },
            );
          },
          borrarDestino: (ruta) => borrarDestinoCopiado(ruta, async (segura) => {
            await bucket.file(segura).delete({ ignoreNotFound: true });
          }),
          crear: async (estudioId, ruta, texto, orden, origenUrl) => {
            await db.collection('perros').doc(id).collection('estudios').doc(estudioId).set({
              ruta,
              texto,
              orden,
              creado: admin.firestore.FieldValue.serverTimestamp(),
              origenUrl,
            });
            documentos.push({ origenUrl, ruta });
          },
        });
        if (resultado.estado === 'error') {
          huboError = true;
          console.error(`${id}: ${resultado.detalle ?? 'error'} (${resultado.destino ?? resultado.origen ?? ''})`);
        }
        resultados.push(resultado);
      } catch (error) {
        huboError = true;
        resultados.push({ estado: 'error', detalle: error instanceof Error ? error.message : String(error) });
      }
    }
    const conteo = {
      perro: id,
      copiados: resultados.filter((item) => item.estado === 'copiado').length,
      simulados: resultados.filter((item) => item.estado === 'simulado').length,
      salteados: resultados.filter((item) => item.estado === 'salteado').length,
      errores: resultados.filter((item) => item.estado === 'error').length,
      resultados,
    };
    resumen.push(conteo);
    console.log(`${id}: ${JSON.stringify({ ...conteo, resultados: undefined })}`);
  }

  const carpeta = resolve(dirname(fileURLToPath(import.meta.url)), 'logs');
  await mkdir(carpeta, { recursive: true });
  const archivo = resolve(carpeta, `migracion-${Date.now()}.json`);
  await writeFile(archivo, JSON.stringify(resumen, null, 2));
  console.log(`Log: ${archivo}`);
  if (huboError) process.exitCode = 1;
}

async function tamanosReales(
  bucket: {
    file: (ruta: string) => {
      exists: () => Promise<[boolean]>;
      getMetadata: () => Promise<[{ size?: string | number }]>;
    };
  },
  entradas: EntradaLegacy[],
  documentos: DocumentoEstudio[],
  nombreBucket: string,
): Promise<{ ok: boolean; detalle: string }> {
  const origenes = new Map<string, number | null>();
  const destinos = new Map<string, number | null>();
  for (const entrada of entradas) {
    const ruta = rutaDesdeUrl(entrada.url, nombreBucket);
    origenes.set(entrada.url, ruta ? await tamano(bucket, ruta) : null);
  }
  for (const doc of documentos) {
    destinos.set(doc.ruta, await tamano(bucket, doc.ruta));
  }
  return puedeQuitarCampo({
    urls: entradas.map((item) => item.url),
    documentos,
    tamanoOrigen: (url) => origenes.get(url) ?? null,
    tamanoDestino: (ruta) => destinos.get(ruta) ?? null,
  });
}

async function describirArchivo(
  bucket: {
    file: (ruta: string) => {
      exists: () => Promise<[boolean]>;
      getMetadata: () => Promise<[{ size?: string | number; contentType?: string | null }]>;
    };
  },
  ruta: string,
): Promise<{ tamano: number | null; contentType: string | null }> {
  const archivo = bucket.file(ruta);
  const [existe] = await archivo.exists();
  if (!existe) return { tamano: null, contentType: null };
  const [meta] = await archivo.getMetadata();
  const tipo = meta.contentType;
  return {
    tamano: Number(meta.size ?? 0),
    contentType: typeof tipo === 'string' && tipo.trim() !== '' ? tipo : null,
  };
}

async function tamano(
  bucket: {
    file: (ruta: string) => {
      exists: () => Promise<[boolean]>;
      getMetadata: () => Promise<[{ size?: string | number }]>;
    };
  },
  ruta: string,
): Promise<number | null> {
  const archivo = bucket.file(ruta);
  const [existe] = await archivo.exists();
  if (!existe) return null;
  const [meta] = await archivo.getMetadata();
  return Number(meta.size ?? 0);
}

if (esCli()) {
  main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}
