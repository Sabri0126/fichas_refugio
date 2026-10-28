import { DateTime } from 'luxon';
import { describe, expect, it } from 'vitest';

import { ZONA } from '../src/alarmas.js';
import {
  type ConfigClima,
  evaluarClima,
  momentoClima,
  normalizarConfig,
} from '../src/clima.js';

const manana = DateTime.fromISO('2026-10-13T08:00:00', { zone: ZONA });
const mediodia = DateTime.fromISO('2026-10-13T12:30:00', { zone: ZONA });
const tarde = DateTime.fromISO('2026-10-13T15:00:00', { zone: ZONA });
const noche = DateTime.fromISO('2026-10-13T19:00:00', { zone: ZONA });
const CONSEJO_LLUVIA =
  'Guardá las cuchas y los comederos que estén a la intemperie, y revisá que sus espacios no se inunden.';
const CONSEJO_CALOR =
  'Poné piletas con agua fresca, reforzá los bebederos y asegurá sombra para todos. Evitá el sol en las horas centrales del día.';
const CONSEJO_FRIO =
  'Prendé las estufas, revisá que las cuchas estén secas y con abrigo, y sumá mantas para los más viejos y los cachorros.';
const CONSEJO_LLOVIZNA =
  'Revisá que las cuchas y los comederos no se mojen: con llovizna alcanza para humedecer lo que está a la intemperie.';
const CONSEJO_LLUVIA_FUERTE =
  'Guardá las cuchas y los comederos, y revisá que los espacios no se inunden. Si podés, dejá a los perros bajo techo.';
const CONSEJO_GRANIZO = 'Poné a resguardo a los perros y cubrí lo que esté afuera.';
const CONSEJO_TORMENTA = 'Vigilá a los perros que se asustan con los truenos y resguardá lo que esté afuera.';
const CONSEJO_VIENTO = 'Asegurá lonas, bebederos y todo lo que se pueda volar, y revisá que las cuchas queden firmes.';
const CONSEJO_FRIO_DIA =
  'Dejá abrigo en las cuchas durante el día y prestá atención a los más viejos y a los cachorros.';
const CONSEJO_NUBLADO =
  'No se espera sol: organizá el trabajo al aire libre igual, pero no cuentes con que se seque rápido.';
const CONSEJO_LINDO = 'Aprovechalo para baños, limpieza del predio o cortes de pelo.';

function hora(
  dia: string,
  h: number,
  extra: {
    t?: number | null;
    p?: number | null;
    mm?: number | null;
    codigo?: number | null;
    nubes?: number | null;
    viento?: number | null;
    rafaga?: number | null;
  } = {},
) {
  return { dia, h, ...extra };
}

function pronostico(opciones: {
  horas?: {
    dia?: string;
    h: number;
    t?: number | null;
    p?: number | null;
    mm?: number | null;
    codigo?: number | null;
    nubes?: number | null;
    viento?: number | null;
    rafaga?: number | null;
  }[];
  maxima?: (number | null)[];
  minima?: (number | null)[];
  probabilidadMax?: (number | null)[];
  precipitacionSuma?: (number | null)[];
  codigo?: (number | null)[];
  vientoMax?: (number | null)[];
  rafagaMax?: (number | null)[];
  fechas?: string[];
} = {}) {
  const horas = opciones.horas ?? [];
  return {
    hourly: {
      time: horas.map((item) => `${item.dia ?? '2026-10-13'}T${String(item.h).padStart(2, '0')}:00`),
      temperature_2m: horas.map((item) => item.t ?? null),
      precipitation_probability: horas.map((item) => item.p ?? null),
      precipitation: horas.map((item) => item.mm ?? null),
      weather_code: horas.map((item) => item.codigo ?? null),
      cloud_cover: horas.map((item) => item.nubes ?? null),
      wind_speed_10m: horas.map((item) => item.viento ?? null),
      wind_gusts_10m: horas.map((item) => item.rafaga ?? null),
    },
    daily: {
      time: opciones.fechas ?? ['2026-10-13', '2026-10-14'],
      temperature_2m_max: opciones.maxima ?? [20, 20],
      temperature_2m_min: opciones.minima ?? [10, 10],
      precipitation_probability_max: opciones.probabilidadMax ?? [0, 0],
      precipitation_sum: opciones.precipitacionSuma ?? [0, 0],
      weather_code: opciones.codigo ?? [null, null],
      wind_speed_10m_max: opciones.vientoMax ?? [null, null],
      wind_gusts_10m_max: opciones.rafagaMax ?? [null, null],
    },
  };
}

function config(extra: Record<string, unknown> = {}): ConfigClima {
  return normalizarConfig(extra);
}

describe('evaluarClima', () => {
  it('avisa llovizna cuando hay probabilidad alta y pocos milímetros', () => {
    const avisos = evaluarClima(
      pronostico({ horas: [hora('2026-10-13', 9, { p: 20, mm: 0 }), hora('2026-10-13', 15, { p: 60, mm: 0.2 })] }),
      config(),
      'manana',
      manana,
    );
    expect(avisos.map((aviso) => aviso.categoria)).toEqual(['llovizna']);
    expect(avisos[0].titulo).toBe('Se espera llovizna hoy');
    expect(avisos[0].cuerpo).toBe(`Probabilidad de llovizna de 60 % (hasta 0.2 mm). ${CONSEJO_LLOVIZNA}`);
    expect(avisos[0].clave).toBe('clima_manana_20261013');
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
    expect(avisos[0].cuerpo.startsWith('Probabilidad de llovizna de 80 % (hasta 1.0 mm).')).toBe(true);
  });

  it('avisa calor justo en el umbral y no por debajo', () => {
    const enUmbral = evaluarClima(pronostico({ maxima: [30, 10] }), config(), 'manana', manana);
    expect(enUmbral.map((aviso) => aviso.titulo)).toEqual(['Hoy hará mucho calor']);
    expect(enUmbral[0].cuerpo).toBe(`Máxima de 30 °C. ${CONSEJO_CALOR}`);
    expect(enUmbral[0].clave).toBe('clima_manana_20261013');

    const debajo = evaluarClima(pronostico({ maxima: [29.9, 40] }), config(), 'manana', manana);
    expect(debajo).toEqual([]);

    const redondeada = evaluarClima(pronostico({ maxima: [30.6, 10] }), config(), 'manana', manana);
    expect(redondeada[0].cuerpo.startsWith('Máxima de 31 °C.')).toBe(true);
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
    const deManana = evaluarClima(base, config(), 'manana', manana);
    expect(deManana).toHaveLength(1);
    expect(deManana[0].categoria).toBe('calor');
    expect(deManana[0].clave).toBe('clima_manana_20261013');
    expect(deManana[0].cuerpo).toBe(`Máxima de 35 °C. También: lluvia (90 %, hasta 8.0 mm). ${CONSEJO_CALOR}`);
    expect(evaluarClima(base, config(), 'noche', noche).map((aviso) => aviso.titulo)).toEqual([
      'Se espera helada esta noche',
    ]);
  });

  it('aplica umbrales de la config', () => {
    const propia = config({ calor_max: 10, lluvia_prob_min: 30, lluvia_mm_min: 20 });
    const avisos = evaluarClima(
      pronostico({ horas: [hora('2026-10-13', 12, { p: 35, mm: 0 })], maxima: [20, 20] }),
      propia,
      'manana',
      manana,
    );
    expect(avisos).toHaveLength(1);
    expect(avisos[0].categoria).toBe('calor');
    expect(avisos[0].cuerpo).toBe(`Máxima de 20 °C. También: lluvia (35 %). ${CONSEJO_CALOR}`);
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
        lluvia_fuerte_mm: '15',
        viento_kmh: null,
        rafaga_kmh: Number.NaN,
        frio_dia_max: false,
        nublado_min: {},
        lindo_min: '15',
        lindo_max: [],
      }),
    ).toEqual(normalizarConfig(undefined));
    expect(normalizarConfig(undefined)).toMatchObject({
      activo: true,
      latitud: -39.00560084311861,
      longitud: -64.05354141817675,
      lugar: 'Refugio Milagros de Amor, Río Colorado, Río Negro',
      lluviaProbMin: 60,
      lluviaMmMin: 2,
      calorMax: 30,
      frioMin: 4,
      heladaMax: 0,
      lluviaFuerteMm: 15,
      vientoKmh: 40,
      rafagaKmh: 60,
      frioDiaMax: 12,
      nubladoMin: 80,
      lindoMin: 15,
      lindoMax: 28,
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

  it('clasifica la precipitación según el código y los milímetros', () => {
    const casos: { codigo?: number; mm?: number; p?: number; categoria: string; titulo: string }[] = [
      { codigo: 53, p: 10, mm: 0.4, categoria: 'llovizna', titulo: 'Se espera llovizna hoy' },
      { codigo: 61, p: 10, mm: 0.4, categoria: 'lluvia', titulo: 'Se espera lluvia hoy' },
      { codigo: 65, p: 40, mm: 3, categoria: 'lluvia_fuerte', titulo: 'Se espera lluvia fuerte hoy' },
      { codigo: 82, p: 20, mm: 1, categoria: 'lluvia_fuerte', titulo: 'Se espera lluvia fuerte hoy' },
      { mm: 15, p: 30, categoria: 'lluvia_fuerte', titulo: 'Se espera lluvia fuerte hoy' },
      { codigo: 95, p: 80, mm: 6, categoria: 'tormenta', titulo: 'Tormenta eléctrica hoy' },
      { codigo: 96, p: 80, mm: 8, categoria: 'granizo', titulo: 'Alerta de granizo hoy' },
      { codigo: 99, p: 70, mm: 4, categoria: 'granizo', titulo: 'Alerta de granizo hoy' },
    ];
    for (const caso of casos) {
      const avisos = evaluarClima(
        pronostico({
          horas: [hora('2026-10-13', 14, { p: caso.p ?? 0, mm: caso.mm ?? 0, codigo: caso.codigo ?? null })],
        }),
        config(),
        'manana',
        manana,
      );
      expect(avisos.map((aviso) => aviso.categoria)).toEqual([caso.categoria]);
      expect(avisos[0].titulo).toBe(caso.titulo);
      expect(avisos[0].clave).toBe('clima_manana_20261013');
    }
  });

  it('la lluvia fuerte, la tormenta y el granizo traen su consejo', () => {
    const fuerte = evaluarClima(
      pronostico({ horas: [hora('2026-10-13', 15, { codigo: 67, p: 90, mm: 20 })] }),
      config(),
      'manana',
      manana,
    );
    expect(fuerte[0].cuerpo).toBe(`Lluvia fuerte con probabilidad de 90 % (hasta 20.0 mm). ${CONSEJO_LLUVIA_FUERTE}`);

    const tormenta = evaluarClima(
      pronostico({ horas: [hora('2026-10-13', 16, { codigo: 95, p: 80, mm: 5 })] }),
      config(),
      'manana',
      manana,
    );
    expect(tormenta[0].cuerpo).toBe(`Se espera tormenta eléctrica. ${CONSEJO_TORMENTA}`);

    const granizo = evaluarClima(
      pronostico({ horas: [hora('2026-10-13', 17, { codigo: 99, p: 70, mm: 4 })] }),
      config(),
      'manana',
      manana,
    );
    expect(granizo[0].cuerpo).toBe(`Se espera granizo. ${CONSEJO_GRANIZO}`);
  });

  it('si faltan los códigos horarios, usa el código del día', () => {
    const avisos = evaluarClima(
      pronostico({
        horas: [hora('2026-10-13', 12, { codigo: null, p: 10, mm: 0 })],
        codigo: [95, 0],
      }),
      config(),
      'manana',
      manana,
    );
    expect(avisos[0].categoria).toBe('tormenta');
  });

  it('prioriza el granizo y suma el resto en una sola línea', () => {
    const avisos = evaluarClima(
      pronostico({
        horas: [hora('2026-10-13', 15, { codigo: 96, p: 80, mm: 8, viento: 20, rafaga: 65 })],
        maxima: [35, 20],
      }),
      config(),
      'manana',
      manana,
    );
    expect(avisos).toHaveLength(1);
    expect(avisos[0].categoria).toBe('granizo');
    expect(avisos[0].cuerpo).toBe(
      `Se espera granizo. También: calor (máxima de 35 °C), ventoso (ráfagas de 65 km/h). ${CONSEJO_GRANIZO}`,
    );
  });

  it('avisa viento y frío de día, con el viento como condición principal', () => {
    const avisos = evaluarClima(
      pronostico({
        horas: [hora('2026-10-13', 11, { viento: 25, rafaga: 65, p: 0, mm: 0 })],
        maxima: [11, 10],
      }),
      config(),
      'manana',
      manana,
    );
    expect(avisos[0].categoria).toBe('viento');
    expect(avisos[0].titulo).toBe('Hoy va a estar ventoso');
    expect(avisos[0].cuerpo).toBe(`Ráfagas de hasta 65 km/h. También: máxima de 11 °C. ${CONSEJO_VIENTO}`);
  });

  it('avisa frío de día sin confundirlo con la helada de la noche', () => {
    const avisos = evaluarClima(
      pronostico({ horas: [hora('2026-10-13', 12, { p: 0, mm: 0 })], maxima: [11, 8] }),
      config(),
      'manana',
      manana,
    );
    expect(avisos[0].categoria).toBe('frio_dia');
    expect(avisos[0].titulo).toBe('Hoy hará frío todo el día');
    expect(avisos[0].cuerpo).toBe(`Máxima de 11 °C. ${CONSEJO_FRIO_DIA}`);
  });

  it('avisa nublado solo si no hay precipitación', () => {
    const nublado = evaluarClima(
      pronostico({
        horas: [
          hora('2026-10-13', 10, { nubes: 90, p: 0, mm: 0 }),
          hora('2026-10-13', 16, { nubes: 70, p: 0, mm: 0 }),
        ],
        maxima: [18, 18],
      }),
      config(),
      'manana',
      manana,
    );
    expect(nublado[0].categoria).toBe('nublado');
    expect(nublado[0].cuerpo).toBe(`Nubosidad promedio de 80 %. ${CONSEJO_NUBLADO}`);

    const conLluvia = evaluarClima(
      pronostico({
        horas: [hora('2026-10-13', 12, { nubes: 95, p: 80, mm: 4 })],
        maxima: [18, 18],
      }),
      config(),
      'manana',
      manana,
    );
    expect(conLluvia[0].categoria).toBe('lluvia');
    expect(conLluvia[0].cuerpo.includes('nublado')).toBe(false);
  });

  it('avisa un día lindo solo cuando no hay otra alerta', () => {
    const lindo = evaluarClima(
      pronostico({
        horas: [hora('2026-10-13', 12, { nubes: 20, viento: 10, rafaga: 20, p: 5, mm: 0 })],
        maxima: [22, 14],
      }),
      config(),
      'manana',
      manana,
    );
    expect(lindo[0].categoria).toBe('lindo');
    expect(lindo[0].titulo).toBe('Hoy es un día lindo para trabajar');
    expect(lindo[0].cuerpo).toBe(`Máxima de 22 °C, con poco viento y sin lluvia. ${CONSEJO_LINDO}`);
    expect(lindo[0].clave).toBe('clima_manana_20261013');

    const conLluvia = evaluarClima(
      pronostico({
        horas: [hora('2026-10-13', 12, { nubes: 20, viento: 10, p: 80, mm: 3 })],
        maxima: [22, 14],
      }),
      config(),
      'manana',
      manana,
    );
    expect(conLluvia[0].categoria).toBe('lluvia');
  });

  it('la hora local elige la mañana, el mediodía o la noche', () => {
    expect(momentoClima(manana)).toBe('manana');
    expect(momentoClima(mediodia)).toBe('mediodia');
    expect(momentoClima(tarde)).toBe('mediodia');
    expect(momentoClima(noche)).toBe('noche');
  });

  it('el mediodía calla si la mañana ya avisó lluvia y habla si no hubo aviso o aparece granizo', () => {
    const lluvia = pronostico({
      horas: [hora('2026-10-13', 9, { p: 80, mm: 4 }), hora('2026-10-13', 15, { p: 80, mm: 6 })],
    });
    expect(evaluarClima(lluvia, config(), 'mediodia', mediodia, { categoriaManana: 'lluvia' })).toEqual([]);

    const sinManana = evaluarClima(lluvia, config(), 'mediodia', mediodia);
    expect(sinManana).toHaveLength(1);
    expect(sinManana[0].categoria).toBe('lluvia');
    expect(sinManana[0].clave).toBe('clima_mediodia_20261013');

    const granizo = evaluarClima(
      pronostico({
        horas: [hora('2026-10-13', 9, { p: 80, mm: 4 }), hora('2026-10-13', 16, { codigo: 96, mm: 3 })],
      }),
      config(),
      'mediodia',
      mediodia,
      { categoriaManana: 'lluvia' },
    );
    expect(granizo).toHaveLength(1);
    expect(granizo[0].categoria).toBe('granizo');
    expect(granizo[0].clave).toBe('clima_mediodia_20261013');
  });

  it('el mediodía no avisa llovizna, nublado, frío de día ni un día lindo', () => {
    const suave = pronostico({
      horas: [hora('2026-10-13', 15, { p: 70, mm: 0.4, nubes: 90, t: 8, viento: 10 })],
      maxima: [8, 8],
    });
    expect(evaluarClima(suave, config(), 'mediodia', mediodia)).toEqual([]);
  });

  it('la noche no repite una racha ya anunciada', () => {
    const dias = pronostico({
      horas: [hora('2026-10-14', 10, { p: 80, mm: 5 }), hora('2026-10-15', 14, { p: 70, mm: 4 })],
      fechas: ['2026-10-13', '2026-10-14', '2026-10-15'],
    });
    const primera = evaluarClima(dias, config(), 'noche', noche);
    expect(primera).toHaveLength(1);
    expect(primera[0].clave).toBe('clima_racha_2026-10-14');
    expect(primera[0].titulo).toBe('Se vienen días de lluvia');
    expect(primera[0].cuerpo.startsWith('Se vienen días de lluvia: mañana y pasado.')).toBe(true);
    expect(primera[0].rachaDesde).toBe('2026-10-14');
    expect(primera[0].rachaHasta).toBe('2026-10-15');

    const repetida = evaluarClima(dias, config(), 'noche', noche, {
      rachaAnterior: { desde: '2026-10-14', hasta: '2026-10-15' },
    });
    expect(repetida).toEqual([]);

    const seguida = evaluarClima(dias, config(), 'noche', noche, {
      rachaAnterior: { desde: '2026-10-12', hasta: '2026-10-13' },
    });
    expect(seguida).toEqual([]);

    const heladaYaAvisada = evaluarClima(
      pronostico({
        horas: [
          hora('2026-10-14', 4, { t: -2 }),
          hora('2026-10-14', 10, { p: 80, mm: 5 }),
          hora('2026-10-15', 14, { p: 70, mm: 4 }),
        ],
        fechas: ['2026-10-13', '2026-10-14', '2026-10-15'],
      }),
      config(),
      'noche',
      noche,
      { rachaAnterior: { desde: '2026-10-14', hasta: '2026-10-15' } },
    );
    expect(heladaYaAvisada).toHaveLength(1);
    expect(heladaYaAvisada[0].titulo).toBe('Se espera helada esta noche');
    expect(heladaYaAvisada[0].cuerpo.includes('Se vienen días de lluvia')).toBe(false);
  });

  it('con helada, la racha queda en el mismo aviso y el texto empieza por el frío', () => {
    const avisos = evaluarClima(
      pronostico({
        horas: [
          hora('2026-10-13', 22, { t: 2 }),
          hora('2026-10-14', 4, { t: -1 }),
          hora('2026-10-14', 11, { p: 80, mm: 6 }),
          hora('2026-10-15', 15, { p: 70, mm: 5 }),
        ],
        fechas: ['2026-10-13', '2026-10-14', '2026-10-15'],
      }),
      config(),
      'noche',
      noche,
    );
    expect(avisos).toHaveLength(1);
    expect(avisos[0].titulo).toBe('Se espera helada esta noche');
    expect(avisos[0].clave).toBe('clima_frio_20261013_noche');
    expect(avisos[0].cuerpo.startsWith(`Mínima de -1 °C. ${CONSEJO_FRIO}`)).toBe(true);
    expect(avisos[0].cuerpo.endsWith('Se vienen días de lluvia: mañana y pasado.')).toBe(true);
    expect(avisos[0].rachaDesde).toBe('2026-10-14');
    expect(avisos[0].rachaHasta).toBe('2026-10-15');
  });

  it('una llovizna no arma racha, y un solo día de lluvia fuerte sí', () => {
    const llovizna = evaluarClima(
      pronostico({
        horas: [hora('2026-10-14', 10, { p: 80, mm: 0.3 }), hora('2026-10-15', 14, { p: 70, mm: 0.4 })],
        fechas: ['2026-10-13', '2026-10-14', '2026-10-15'],
      }),
      config(),
      'noche',
      noche,
    );
    expect(llovizna).toEqual([]);

    const fuerte = evaluarClima(
      pronostico({
        horas: [hora('2026-10-14', 10, { p: 90, mm: 20 }), hora('2026-10-15', 14, { p: 10, mm: 0 })],
        fechas: ['2026-10-13', '2026-10-14', '2026-10-15'],
      }),
      config(),
      'noche',
      noche,
    );
    expect(fuerte).toHaveLength(1);
    expect(fuerte[0].clave).toBe('clima_racha_2026-10-14');
    expect(fuerte[0].cuerpo.startsWith('Mañana se espera lluvia fuerte.')).toBe(true);
    expect(fuerte[0].rachaHasta).toBe('2026-10-14');
  });

  it('un día seco de por medio vuelve a avisar la racha', () => {
    const avisos = evaluarClima(
      pronostico({
        horas: [hora('2026-10-14', 10, { p: 80, mm: 5 }), hora('2026-10-15', 14, { p: 70, mm: 4 })],
        fechas: ['2026-10-13', '2026-10-14', '2026-10-15'],
      }),
      config(),
      'noche',
      noche,
      { rachaAnterior: { desde: '2026-10-11', hasta: '2026-10-12' } },
    );
    expect(avisos).toHaveLength(1);
    expect(avisos[0].clave).toBe('clima_racha_2026-10-14');
  });
});
