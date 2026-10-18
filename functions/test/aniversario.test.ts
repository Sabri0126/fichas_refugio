import { DateTime } from 'luxon';
import { describe, expect, it } from 'vitest';

import { aniosCumplidos, esMananaDeAniversario, mensajeAniversario } from '../src/aniversario.js';
import { ZONA } from '../src/alarmas.js';

function ba(iso: string): DateTime {
  return DateTime.fromISO(iso, { zone: ZONA });
}

describe('aniversario', () => {
  it('cuenta los años cumplidos el 29 de abril', () => {
    expect(aniosCumplidos(ba('2000-04-29T08:00:00'))).toBe(0);
    expect(aniosCumplidos(ba('2026-04-28T08:00:00'))).toBe(25);
    expect(aniosCumplidos(ba('2026-04-29T08:00:00'))).toBe(26);
  });

  it('solo la mañana del 29 de abril', () => {
    expect(esMananaDeAniversario(ba('2026-04-29T08:00:00'))).toBe(true);
    expect(esMananaDeAniversario(ba('2026-04-29T19:00:00'))).toBe(false);
    expect(esMananaDeAniversario(ba('2026-04-28T08:00:00'))).toBe(false);
  });

  it('arma un aviso que no abre una ficha', () => {
    const mensaje = mensajeAniversario(ba('2026-04-29T08:00:00'));
    expect(mensaje.clave).toBe('aniversario_2026');
    expect(mensaje.idPerro).toBe('');
    expect(mensaje.cuerpo).toContain('cumple 26 años');
  });
});
