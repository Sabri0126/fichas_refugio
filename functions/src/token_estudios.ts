/** Solo los archivos de estudios. El resto del bucket no se toca. */
export const PREFIJO_ESTUDIOS = 'estudios_medicos/';

export function tieneTokenDescarga(
  metadata: Record<string, string | number | boolean | null> | null | undefined,
): boolean {
  const valor = metadata?.firebaseStorageDownloadTokens;
  return valor != null && String(valor).length > 0;
}

export interface ActualizacionSinToken {
  contentType?: string;
  metadata: { firebaseStorageDownloadTokens: null };
}

/**
 * Metadata para borrar el token sin pisar el contentType.
 * `null` si el objeto no es un estudio o ya no tiene token.
 */
export function metadataParaQuitarToken(objeto: {
  name?: string;
  contentType?: string | null;
  metadata?: Record<string, string | number | boolean | null> | null;
}): ActualizacionSinToken | null {
  if (!objeto.name?.startsWith(PREFIJO_ESTUDIOS)) return null;
  if (objeto.name.includes('..')) return null;
  if (!tieneTokenDescarga(objeto.metadata)) return null;
  const actualizacion: ActualizacionSinToken = {
    metadata: { firebaseStorageDownloadTokens: null },
  };
  if (typeof objeto.contentType === 'string' && objeto.contentType.trim() !== '') {
    actualizacion.contentType = objeto.contentType;
  }
  return actualizacion;
}
