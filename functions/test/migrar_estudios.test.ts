import { describe, expect, it, vi } from 'vitest';

import {
  borrarDestinoCopiado,
  contentTypesIguales,
  copiarEstudio,
  extensionDe,
  metadataSinToken,
  ordenMigrado,
  puedeQuitarCampo,
  procesarEntrada,
  rutaDesdeUrl,
  yaMigrado,
} from '../scripts/migrar_estudios';

const bucket = 'refugio-test.appspot.com';
const url =
  'https://firebasestorage.googleapis.com/v0/b/refugio-test.appspot.com/o/galeria_perros%2Fradio.jpg?alt=media&token=abc';

describe('migración de estudios', () => {
  it('pasa de la URL a la ruta y rechaza otro bucket', () => {
    expect(rutaDesdeUrl(url, bucket)).toBe('galeria_perros/radio.jpg');
    expect(rutaDesdeUrl(url, 'otro.appspot.com')).toBeNull();
    expect(rutaDesdeUrl('https://otro.example/foto.jpg', bucket)).toBeNull();
  });

  it('no copia el token de descarga', () => {
    expect(
      metadataSinToken({
        firebaseStorageDownloadTokens: 'abc',
        contentType: 'image/jpeg',
      }),
    ).toEqual({
      contentType: 'image/jpeg',
      firebaseStorageDownloadTokens: null,
    });
  });

  it('al copiar anula el token y, si sigue, lo marca como error', async () => {
    const origen = archivo({
      size: 10,
      contentType: 'image/jpeg',
      metadata: { firebaseStorageDownloadTokens: 'abc' },
    });
    const destino = archivo({ size: 10, contentType: null, metadata: {} });
    await copiarEstudio(origen, destino);
    expect(destino.metadata.firebaseStorageDownloadTokens ?? null).toBeNull();
    expect(destino.contentType).toBe('image/jpeg');
    expect(origen.copiadoCon?.contentType).toBe('image/jpeg');
    expect(origen.copiadoCon?.metadata?.firebaseStorageDownloadTokens).toBeNull();
    expect(destino.metadataEscrita?.contentType).toBe('image/jpeg');
    expect(destino.metadataEscrita?.metadata?.firebaseStorageDownloadTokens).toBeNull();
    expect(destino.borrados).toBe(0);
    expect(origen.borrados).toBe(0);

    const origen2 = archivo({ size: 10, contentType: 'image/jpeg', metadata: { firebaseStorageDownloadTokens: 'abc' } });
    const destinoConToken = archivo({ size: 10, contentType: 'image/jpeg', metadata: {}, conservaToken: true });
    await expect(copiarEstudio(origen2, destinoConToken)).rejects.toThrow(/firebaseStorageDownloadTokens/);
    expect(destinoConToken.borrados).toBe(1);
    expect(origen2.borrados).toBe(0);
  });

  it('conserva el contentType y una diferencia es un error', async () => {
    const origen = archivo({ size: 8, contentType: 'image/png', metadata: {} });
    const destino = archivo({ size: 8, contentType: null, metadata: {} });
    await copiarEstudio(origen, destino);
    expect(contentTypesIguales(origen.contentType, destino.contentType)).toBe(true);
    expect(destino.borrados).toBe(0);

    const distinto = archivo({ size: 8, contentType: null, metadata: {}, forzarContentType: 'application/octet-stream' });
    await expect(copiarEstudio(origen, distinto)).rejects.toThrow(/contentType/);
    expect(distinto.borrados).toBe(1);
    expect(origen.borrados).toBe(0);
  });

  it('si falla setMetadata o la lectura, borra la copia y no crea el documento', async () => {
    const origen = archivo({ size: 10, contentType: 'image/jpeg', metadata: {} });
    const destino = archivo({ size: 10, contentType: 'image/jpeg', metadata: {}, fallaSetMetadata: true });
    const crear = vi.fn();
    const resultado = await procesarEntrada(
      { url, texto: 'radio' },
      {
        ...base({ aplicar: true, crear }),
        copiar: async () => {
          await copiarEstudio(origen, destino);
        },
      },
    );
    expect(resultado.estado).toBe('error');
    expect(destino.borrados).toBe(1);
    expect(origen.borrados).toBe(0);
    expect(crear).not.toHaveBeenCalled();

    const origenLectura = archivo({ size: 10, contentType: 'image/jpeg', metadata: {} });
    const destinoLectura = archivo({ size: 10, contentType: 'image/jpeg', metadata: {}, fallaLectura: true });
    const crearLectura = vi.fn();
    const lectura = await procesarEntrada(
      { url, texto: 'radio' },
      {
        ...base({ aplicar: true, crear: crearLectura }),
        copiar: async () => {
          await copiarEstudio(origenLectura, destinoLectura);
        },
      },
    );
    expect(lectura.estado).toBe('error');
    expect(destinoLectura.borrados).toBe(1);
    expect(origenLectura.borrados).toBe(0);
    expect(crearLectura).not.toHaveBeenCalled();
  });

  it('la extensión sale del contentType o, si no se conoce, del archivo', async () => {
    expect(extensionDe('image/jpeg', 'galeria_perros/a.png')).toBe('.jpg');
    expect(extensionDe('image/png', 'galeria_perros/a.jpg')).toBe('.png');
    expect(extensionDe('image/webp', 'galeria_perros/a')).toBe('.webp');
    expect(extensionDe('application/pdf', 'galeria_perros/a.jpg')).toBe('.pdf');
    expect(extensionDe('image/gif', 'galeria_perros/placa.GIF')).toBe('.gif');
    expect(extensionDe(null, 'galeria_perros/sin-extension')).toBe('.jpg');

    const simulado = await procesarEntrada(
      { url, texto: 'radio' },
      base({ aplicar: false, contentTypeOrigen: async () => 'image/png' }),
    );
    expect(simulado.estado).toBe('simulado');
    expect(simulado.destino).toBe('estudios_medicos/luna/e2.png');
  });

  it('si el tamaño no coincide o falla el documento, borra solo el destino', async () => {
    const origen = archivo({ size: 10, contentType: 'image/jpeg', metadata: {} });
    const destino = archivo({ size: 10, contentType: 'image/jpeg', metadata: {}, forzarTamano: 4 });
    await expect(copiarEstudio(origen, destino)).rejects.toThrow(/tamaño/);
    expect(destino.borrados).toBe(1);
    expect(origen.borrados).toBe(0);

    const borrar = vi.fn();
    const copiar = vi.fn();
    const resultado = await procesarEntrada(
      { url, texto: 'radio' },
      {
        aplicar: true,
        bucket,
        perroId: 'luna',
        estudioId: 'e2',
        documentos: [],
        orden: 0,
        tamanoOrigen: async () => 10,
        copiar,
        crear: async () => {
          throw new Error('firestore');
        },
        borrarDestino: borrar,
      },
    );
    expect(resultado.estado).toBe('error');
    expect(copiar).toHaveBeenCalledWith('galeria_perros/radio.jpg', 'estudios_medicos/luna/e2.jpg');
    expect(borrar).toHaveBeenCalledTimes(1);
    expect(borrar).toHaveBeenCalledWith('estudios_medicos/luna/e2.jpg');

    const borrarGaleria = vi.fn();
    await borrarDestinoCopiado('galeria_perros/radio.jpg', borrarGaleria);
    expect(borrarGaleria).not.toHaveBeenCalled();
  });

  it('solo copia archivos que ya están en galeria_perros', async () => {
    const copiar = vi.fn();
    const otra =
      'https://firebasestorage.googleapis.com/v0/b/refugio-test.appspot.com/o/perfil%2Ffoto.jpg?alt=media&token=abc';
    const resultado = await procesarEntrada(
      { url: otra, texto: 'foto' },
      base({ aplicar: true, copiar }),
    );
    expect(resultado.estado).toBe('error');
    expect(copiar).not.toHaveBeenCalled();

    const escapada =
      'https://firebasestorage.googleapis.com/v0/b/refugio-test.appspot.com/o/galeria_perros%2F..%2Fsecreto.jpg?alt=media';
    const escapadaResultado = await procesarEntrada(
      { url: escapada, texto: 'foto' },
      base({ aplicar: true, copiar }),
    );
    expect(escapadaResultado.estado).toBe('error');
    expect(copiar).not.toHaveBeenCalled();
  });

  it('en simulación un origen inexistente es un error', async () => {
    const copiar = vi.fn();
    const resultado = await procesarEntrada(
      { url, texto: 'radio' },
      base({ aplicar: false, copiar, tamanoOrigen: async () => null }),
    );
    expect(resultado.estado).toBe('error');
    expect(copiar).not.toHaveBeenCalled();
  });

  it('el orden queda después de los estudios que ya existen', async () => {
    const documentos = [{ orden: 0 }, { orden: 4 }];
    expect(ordenMigrado(documentos, 0)).toBe(5);
    expect(ordenMigrado(documentos, 1)).toBe(6);
    expect(ordenMigrado([], 0)).toBe(0);

    const crear = vi.fn();
    const resultado = await procesarEntrada(
      { url, texto: 'radio' },
      base({ aplicar: true, orden: ordenMigrado(documentos, 1), crear }),
    );
    expect(resultado.estado).toBe('copiado');
    expect(crear).toHaveBeenCalledWith('e2', 'estudios_medicos/luna/e2.jpg', 'radio', 6, url);
  });

  it('la segunda corrida no duplica y la simulación no escribe', async () => {
    const documentos = [{ origenUrl: url, ruta: 'estudios_medicos/luna/e1.jpg' }];
    expect(yaMigrado(url, documentos)).toBe(true);
    const copiar = vi.fn();
    const crear = vi.fn();
    const salteado = await procesarEntrada(
      { url, texto: 'radio' },
      {
        aplicar: true,
        bucket,
        perroId: 'luna',
        estudioId: 'e2',
        documentos,
        orden: 0,
        tamanoOrigen: async () => 10,
        copiar,
        crear,
        borrarDestino: async () => {},
      },
    );
    expect(salteado.estado).toBe('salteado');
    expect(copiar).not.toHaveBeenCalled();

    const simulado = await procesarEntrada(
      { url, texto: 'radio' },
      {
        aplicar: false,
        bucket,
        perroId: 'luna',
        estudioId: 'e2',
        documentos: [],
        orden: 0,
        tamanoOrigen: async () => 20,
        copiar,
        crear,
        borrarDestino: async () => {},
      },
    );
    expect(simulado.estado).toBe('simulado');
    expect(simulado.destino).toBe('estudios_medicos/luna/e2.jpg');
    expect(copiar).not.toHaveBeenCalled();
    expect(crear).not.toHaveBeenCalled();
  });

  it('no quita el campo si falta el archivo', () => {
    const decision = puedeQuitarCampo({
      urls: [url],
      documentos: [{ origenUrl: url, ruta: 'estudios_medicos/luna/e1.jpg' }],
      tamanoDestino: () => null,
      tamanoOrigen: () => 12,
    });
    expect(decision.ok).toBe(false);
  });
});

function base(extra: {
  aplicar: boolean;
  copiar?: ReturnType<typeof vi.fn>;
  crear?: ReturnType<typeof vi.fn>;
  orden?: number;
  tamanoOrigen?: (ruta: string) => Promise<number | null>;
  contentTypeOrigen?: (ruta: string) => Promise<string | null>;
}) {
  return {
    aplicar: extra.aplicar,
    bucket,
    perroId: 'luna',
    estudioId: 'e2',
    documentos: [] as { origenUrl?: string; ruta: string }[],
    orden: extra.orden ?? 0,
    tamanoOrigen: extra.tamanoOrigen ?? (async () => 10),
    contentTypeOrigen: extra.contentTypeOrigen,
    copiar: extra.copiar ?? vi.fn(),
    crear: extra.crear ?? vi.fn(),
    borrarDestino: vi.fn(),
  };
}

function archivo(opciones: {
  size: number;
  contentType: string | null;
  metadata: Record<string, string>;
  conservaToken?: boolean;
  forzarTamano?: number;
  forzarContentType?: string;
  fallaSetMetadata?: boolean;
  fallaLectura?: boolean;
}) {
  const estado = {
    metadata: { ...opciones.metadata } as Record<string, string | null>,
    size: opciones.size,
    contentType: opciones.contentType as string | null,
    borrados: 0,
    copiadoCon: undefined as { contentType?: string; metadata?: Record<string, string | null> } | undefined,
    metadataEscrita: undefined as { contentType?: string; metadata?: Record<string, string | null> } | undefined,
    async getMetadata() {
      if (this.fallaLectura) throw new Error('no se pudo leer la metadata');
      return [
        {
          size: this.forzarTamano ?? this.size,
          contentType: this.forzarContentType ?? this.contentType,
          metadata: { ...this.metadata },
        },
      ] as [{ size: number; contentType: string | null; metadata: Record<string, string | null> }];
    },
    async copy(
      destino: {
        size: number;
        contentType: string | null;
        metadata: Record<string, string | null>;
        conservaToken: boolean;
      },
      opcionesCopia?: { contentType?: string; metadata?: Record<string, string | null> },
    ) {
      this.copiadoCon = opcionesCopia;
      destino.size = this.size;
      destino.metadata = { ...this.metadata };
      for (const [clave, valor] of Object.entries(opcionesCopia?.metadata ?? {})) {
        if (valor === null) delete destino.metadata[clave];
        else destino.metadata[clave] = valor;
      }
      destino.contentType = opcionesCopia?.contentType ?? null;
      if (destino.conservaToken) destino.metadata.firebaseStorageDownloadTokens = 'abc';
    },
    async setMetadata(metadata: { contentType?: string; metadata?: Record<string, string | null> }) {
      if (this.fallaSetMetadata) throw new Error('setMetadata falló');
      this.metadataEscrita = metadata;
      if (metadata.contentType !== undefined) this.contentType = metadata.contentType;
      else this.contentType = null;
      for (const [clave, valor] of Object.entries(metadata.metadata ?? {})) {
        if (valor === null) delete this.metadata[clave];
        else this.metadata[clave] = valor;
      }
      if (this.conservaToken) this.metadata.firebaseStorageDownloadTokens = 'abc';
    },
    async delete() {
      this.borrados += 1;
    },
    conservaToken: opciones.conservaToken ?? false,
    forzarTamano: opciones.forzarTamano,
    forzarContentType: opciones.forzarContentType,
    fallaSetMetadata: opciones.fallaSetMetadata ?? false,
    fallaLectura: opciones.fallaLectura ?? false,
  };
  return estado;
}
