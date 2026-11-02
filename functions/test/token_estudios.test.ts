import { describe, expect, it } from 'vitest';

import { metadataParaQuitarToken } from '../src/token_estudios';

describe('token de estudios', () => {
  it('borra el token del estudio y conserva el contentType', () => {
    expect(
      metadataParaQuitarToken({
        name: 'estudios_medicos/a1F9xVoWR6KK5Emo6AbC/kJ6TbfUZumvM3REssjKb.jpg',
        contentType: 'image/jpeg',
        metadata: { firebaseStorageDownloadTokens: 'abc' },
      }),
    ).toEqual({
      contentType: 'image/jpeg',
      metadata: { firebaseStorageDownloadTokens: null },
    });
  });

  it('no toca la galería ni un estudio que ya no tiene token', () => {
    expect(
      metadataParaQuitarToken({
        name: 'galeria_perros/radio.jpg',
        contentType: 'image/jpeg',
        metadata: { firebaseStorageDownloadTokens: 'abc' },
      }),
    ).toBeNull();
    expect(
      metadataParaQuitarToken({
        name: 'estudios_medicos/luna/radio.jpg',
        contentType: 'image/png',
        metadata: {},
      }),
    ).toBeNull();
  });
});
