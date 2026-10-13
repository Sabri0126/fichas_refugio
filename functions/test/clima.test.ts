import { DateTime } from 'luxon';
import { describe, expect, it } from 'vitest';

import { ZONA } from '../src/alarmas.js';
import {
  type ConfigClima,
  evaluarClima,
  normalizarConfig,
} from '../src/clima.js';

const manana = DateTime.fromISO('2026-10-13T08:00:00', { zone: ZONA });
const noche = DateTime.fromISO('2026-10-13T19:00:00', { zone: ZONA });
const CONSEJO_LLUVIA =
  'Guardá las cuchas y los comederos que estén a la intemperie, y revisá que los espacios no se inunden.';
const CONSEJO_CALOR =
  'Poné piletas con agua fresca, reforzá los bebederos y asegurá sombra para todos.';
const CONSEJO_FRIO =
  'Prendé las estufas, revisá que las cuchas estén secas y con abrigo, y sumá mantas o paja para los más viejos y los cachorros.';

function hora(dia: string, h: number, extra: { t?: number | null; p?: number | null; mm?: number | null } = {}) {
  return { dia, h, ...extra };
}

function pronostico(opciones: {
  horas?: { dia?: string; h: number; t?: number | null; p?: number | null; mm?: number | null }[];
  maxima?: (number | null)[];
  minima?: (number | null)[];
  probabilidadMax?: (number | null)[];
  precipitacionSuma?: (number | null)[];
  fechas?: string[];
} = {}) {
  const horas = opciones.horas ?? [];
  return {
    hourly: {
      time: horas.map((item) => `${item.dia ?? '2026-10-13'}T${String(item.h).padStart(2, '0')}:00`),
      temperature_2m: horas.map((item) => item.t ?? null),
      precipitation_probability: horas.map((item) => item.p ?? null),
      precipitation: horas.map((item) => item.mm ?? null),
    },
    daily: {
      time: opciones.fechas ?? ['2026-10-13', '2026-10-14'],
      temperature_2m_max: opciones.maxima ?? [20, 20],
      temperature_2m_min: opciones.minima ?? [10, 10],
      precipitation_probability_max: opciones.probabilidadMax ?? [0, 0],
      precipitation_sum: opciones.precipitacionSuma ?? [0, 0],
    },
  };
}

function config(extra: Record<string, unknown> = {}): ConfigClima {
  return normalizarConfig(extra);
}

describe('evaluarClima', () => {
  it('avisa lluvia cuando la probabilidad horaria llega al umbral', () => {
    const avisos = evaluarClima(
      pronostico({ horas: [hora('2026-10-13', 9, { p: 20, mm: 0 }), hora('2026-10-13', 15, { p: 60, mm: 0.2 })] }),
      config(),
      'manana',
      manana,
    );
    expect(avisos.map((aviso) => aviso.categoria)).toEqual(['lluvia']);
    expect(avisos[0].titulo).toBe('Se espera lluvia hoy');
    expect(avisos[0].cuerpo).toBe(`Probabilidad de lluvia de 60 % (hasta 0.2 mm). ${CONSEJO_LLUVIA}`);
    expect(avisos[0].clave).toBe('clima_lluvia_20261013_manana');
    expect(avisos[0].tipo).toBe('clima');
  });

  it('avisa lluvia por milímetros aunque la probabilidad no alcance', () => {
    const avisos = evaluarClima(
      pronostico({
        horas: [hora('2026-10-13', 10, { p: 10, mm: 1.2 }), hora('2026-10-13', 11, { p: 15, mm: 1.05 })],
      }),
      config(),
      'manana',
      manana,
    );
    expect(avisos).toHaveLength(1);
    expect(avisos[0].cuerpo).toBe(`Probabilidad de lluvia de 15 % (hasta 2.3 mm). ${CONSEJO_LLUVIA}`);
  });

  it('no avisa lluvia si ni la probabilidad ni los milímetros alcanzan', () => {
    const avisos = evaluarClima(
      pronostico({ horas: [hora('2026-10-13', 12, { p: 59.6, mm: 1.9 })] }),
      config(),
      'manana',
      manana,
    );
    expect(avisos).toEqual([]);
  });

  it('si faltan las horas, usa el pronóstico diario', () => {
    const avisos = evaluarClima(
      pronostico({
        horas: [hora('2026-10-13', 8, { p: null, mm: null }), hora('2026-10-13', 18, { p: null, mm: null })],
        probabilidadMax: [70, 0],
        precipitacionSuma: [4.2, 0],
      }),
      config(),
      'manana',
      manana,
    );
    expect(avisos[0].cuerpo.startsWith('Probabilidad de lluvia de 70 % (hasta 4.2 mm).')).toBe(true);
  });

  it('ignora las horas nulas y se queda con el resto', () => {
    const avisos = evaluarClima(
      pronostico({
        horas: [
          hora('2026-10-13', 8, { p: null, mm: null }),
          hora('2026-10-13', 14, { p: 80, mm: 0 }),
          hora('2026-10-13', 22, { p: null, mm: 1 }),
        ],
      }),
      config(),
      'manana',
      manana,
    );
    expect(avisos[0].cuerpo.startsWith('Probabilidad de lluvia de 80 % (hasta 1.0 mm).')).toBe(true);
  });

  it('avisa calor justo en el umbral y no por debajo', () => {
    const enUmbral = evaluarClima(pronostico({ maxima: [35, 10] }), config(), 'manana', manana);
    expect(enUmbral.map((aviso) => aviso.titulo)).toEqual(['Hoy hará mucho calor']);
    expect(enUmbral[0].cuerpo).toBe(`Máxima de 35 °C. ${CONSEJO_CALOR}`);
    expect(enUmbral[0].clave).toBe('clima_calor_20261013_manana');

    const debajo = evaluarClima(pronostico({ maxima: [34.9, 40] }), config(), 'manana', manana);
    expect(debajo).toEqual([]);

    const redondeada = evaluarClima(pronostico({ maxima: [35.6, 10] }), config(), 'manana', manana);
    expect(redondeada[0].cuerpo.startsWith('Máxima de 36 °C.')).toBe(true);
  });

  it('la noche fría y la helada usan la mínima del tramo, aunque sea después de la medianoche', () => {
    const frio = evaluarClima(
      pronostico({
        horas: [
          hora('2026-10-13', 20, { t: 8 }),
          hora('2026-10-13', 23, { t: 6 }),
          hora('2026-10-14', 3, { t: 1 }),
          hora('2026-10-14', 8, { t: 4 }),
        ],
      }),
      config(),
      'noche',
      noche,
    );
    expect(frio[0].titulo).toBe('Noche muy fría');
    expect(frio[0].categoria).toBe('frio');
    expect(frio[0].cuerpo).toBe(`Mínima de 1 °C. ${CONSEJO_FRIO}`);
    expect(frio[0].clave).toBe('clima_frio_20261013_noche');

    const helada = evaluarClima(
      pronostico({
        horas: [hora('2026-10-13', 21, { t: 4 }), hora('2026-10-14', 4, { t: -1.2 })],
      }),
      config(),
      'noche',
      noche,
    );
    expect(helada[0].titulo).toBe('Se espera helada esta noche');
    expect(helada[0].cuerpo).toBe(`Mínima de -1 °C. ${CONSEJO_FRIO}`);
  });

  it('la mañana no evalúa el frío y la noche no evalúa lluvia ni calor', () => {
    const base = pronostico({
      horas: [hora('2026-10-13', 15, { p: 90, mm: 8, t: 30 }), hora('2026-10-14', 3, { t: -2 })],
      maxima: [35, 10],
    });
    expect(evaluarClima(base, config(), 'manana', manana).map((aviso) => aviso.categoria)).toEqual(['lluvia', 'calor']);
    expect(evaluarClima(base, config(), 'noche', noche).map((aviso) => aviso.titulo)).toEqual([
      'Se espera helada esta noche',
    ]);
  });

  it('aplica umbrales de la config', () => {
    const propia = config({ calor_max: 10, lluvia_prob_min: 30, lluvia_mm_min: 20 });
    const avisos = evaluarClima(
      pronostico({ horas: [hora('2026-10-13', 12, { p: 35, mm: 0 })], maxima: [12, 12] }),
      propia,
      'manana',
      manana,
    );
    expect(avisos.map((aviso) => aviso.categoria)).toEqual(['lluvia', 'calor']);
  });

  it('una config inválida vuelve a los valores por defecto', () => {
    expect(
      normalizarConfig({
        activo: 'no',
        latitud: 'sur',
        longitud: Number.NaN,
        lugar: 12,
        lluvia_prob_min: null,
        lluvia_mm_min: Number.POSITIVE_INFINITY,
        calor_max: '32',
        frio_min: false,
        helada_max: {},
      }),
    ).toEqual(normalizarConfig(undefined));
    expect(normalizarConfig(undefined)).toMatchObject({
      activo: true,
      latitud: -38.9833,
      longitud: -64.0933,
      lugar: 'Río Colorado, Río Negro',
      lluviaProbMin: 60,
      lluviaMmMin: 2,
      calorMax: 35,
      frioMin: 3,
      heladaMax: 0,
    });
  });

  it('con activo en false no arma avisos', () => {
    const avisos = evaluarClima(
      pronostico({ horas: [hora('2026-10-13', 12, { p: 100, mm: 20 })], maxima: [40, 40] }),
      config({ activo: false }),
      'manana',
      manana,
    );
    expect(avisos).toEqual([]);
  });

  it('una respuesta con forma inesperada no produce avisos', () => {
    expect(evaluarClima(null, config(), 'manana', manana)).toEqual([]);
    expect(evaluarClima('lluvia', config(), 'manana', manana)).toEqual([]);
    expect(evaluarClima({ hourly: 4, daily: [] }, config(), 'noche', noche)).toEqual([]);
  });
});
