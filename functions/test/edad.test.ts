import { DateTime } from 'luxon';
import { describe, expect, it } from 'vitest';

import { ZONA } from '../src/alarmas.js';
import { avanzarEdad, mesesCalendario } from '../src/edad.js';

function ba(iso: string): DateTime {
  return DateTime.fromISO(iso, { zone: ZONA });
}

describe('avanzarEdad', () => {
  it('suma un mes al cambiar de mes', () => {
    expect(mesesCalendario(ba('2026-08-15'), ba('2026-09-02'))).toBe(1);
    expect(avanzarEdad(0, 4, 1)).toEqual({ edad: 0, meses: 5, cruzoUnAnio: false });
  });

  it('al llegar a 12 meses pasa a 1 año y avisa', () => {
    expect(avanzarEdad(0, 11, 1)).toEqual({ edad: 1, meses: 0, cruzoUnAnio: true });
  });

  it('1 año y 11 meses pasa a 2 años sin aviso', () => {
    expect(avanzarEdad(1, 11, 1)).toEqual({ edad: 2, meses: 0, cruzoUnAnio: false });
  });

  it('no avanza si no pasó un mes', () => {
    expect(mesesCalendario(ba('2026-08-01'), ba('2026-08-31'))).toBe(0);
    expect(avanzarEdad(0, 4, 0)).toBeNull();
  });

  it('un salto de varios meses cruza el año una sola vez', () => {
    expect(avanzarEdad(0, 4, 10)).toEqual({ edad: 1, meses: 2, cruzoUnAnio: true });
  });
});
