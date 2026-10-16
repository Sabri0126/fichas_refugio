import { DateTime } from 'luxon';

import { ZONA } from './alarmas.js';

export type MomentoClima = 'manana' | 'noche';
export type CategoriaClima =
  | 'lluvia'
  | 'calor'
  | 'frio'
  | 'granizo'
  | 'tormenta'
  | 'lluvia_fuerte'
  | 'viento'
  | 'llovizna'
  | 'frio_dia'
  | 'nublado'
  | 'lindo';

export interface AvisoClima {
  clave: string;
  tipo: 'clima';
  categoria: CategoriaClima;
  titulo: string;
  cuerpo: string;
}

export interface ConfigClima {
  activo: boolean;
  latitud: number;
  longitud: number;
  lugar: string;
  lluviaProbMin: number;
  lluviaMmMin: number;
  lluviaFuerteMm: number;
  calorMax: number;
  frioMin: number;
  heladaMax: number;
  vientoKmh: number;
  rafagaKmh: number;
  frioDiaMax: number;
  nubladoMin: number;
  lindoMin: number;
  lindoMax: number;
}

const DEFAULTS: ConfigClima = {
  activo: true,
  latitud: -39.00560084311861,
  longitud: -64.05354141817675,
  lugar: 'Refugio Milagros de Amor, Río Colorado, Río Negro',
  lluviaProbMin: 60,
  lluviaMmMin: 2,
  lluviaFuerteMm: 15,
  calorMax: 30,
  frioMin: 4,
  heladaMax: 0,
  vientoKmh: 40,
  rafagaKmh: 60,
  frioDiaMax: 12,
  nubladoMin: 80,
  lindoMin: 15,
  lindoMax: 28,
};

const LINDO_NUBES_MAX = 40;
const LINDO_LLUVIA_MAX = 20;
const LINDO_VIENTO_MAX = 25;

const CONSEJO_LLUVIA =
  'Guardá las cuchas y los comederos que estén a la intemperie, y revisá que sus espacios no se inunden.';
const CONSEJO_LLUVIA_FUERTE =
  'Guardá las cuchas y los comederos, y revisá que los espacios no se inunden. Si podés, dejá a los perros bajo techo.';
const CONSEJO_LLOVIZNA =
  'Revisá que las cuchas y los comederos no se mojen: con llovizna alcanza para humedecer lo que está a la intemperie.';
const CONSEJO_CALOR =
  'Poné piletas con agua fresca, reforzá los bebederos y asegurá sombra para todos. Evitá el sol en las horas centrales del día.';
const CONSEJO_FRIO =
  'Prendé las estufas, revisá que las cuchas estén secas y con abrigo, y sumá mantas para los más viejos y los cachorros.';
const CONSEJO_FRIO_DIA =
  'Dejá abrigo en las cuchas durante el día y prestá atención a los más viejos y a los cachorros.';
const CONSEJO_GRANIZO = 'Poné a resguardo a los perros y cubrí lo que esté afuera.';
const CONSEJO_TORMENTA = 'Vigilá a los perros que se asustan con los truenos y resguardá lo que esté afuera.';
const CONSEJO_VIENTO = 'Asegurá lonas, bebederos y todo lo que se pueda volar, y revisá que las cuchas queden firmes.';
const CONSEJO_NUBLADO = 'No se espera sol: organizá el trabajo al aire libre igual, pero no cuentes con que se seque rápido.';
const CONSEJO_LINDO = 'Aprovechalo para baños, limpieza del predio o cortes de pelo.';

const CODIGOS_GRANIZO = new Set([96, 99]);
const CODIGOS_TORMENTA = new Set([95]);
const CODIGOS_LLUVIA_FUERTE = new Set([65, 67, 82]);
const CODIGOS_LLUVIA = new Set([61, 63, 66, 80, 81]);
const CODIGOS_LLOVIZNA = new Set([51, 53, 55, 56, 57]);

const PRIORIDAD: Record<CategoriaClima, number> = {
  granizo: 1,
  tormenta: 2,
  lluvia_fuerte: 3,
  calor: 4,
  viento: 5,
  lluvia: 6,
  llovizna: 7,
  frio_dia: 8,
  nublado: 9,
  lindo: 10,
  frio: 11,
};

interface HoraPronostico {
  instante: DateTime;
  temperatura: number | null;
  probabilidad: number | null;
  precipitacion: number | null;
  codigo: number | null;
  nubes: number | null;
  viento: number | null;
  rafaga: number | null;
}

interface DiaPronostico {
  fecha: string;
  maxima: number | null;
  minima: number | null;
  probabilidadMax: number | null;
  precipitacionSuma: number | null;
  codigo: number | null;
  vientoMax: number | null;
  rafagaMax: number | null;
}

interface Pronostico {
  horas: HoraPronostico[];
  dias: DiaPronostico[];
}

interface Precipitacion {
  probabilidad: number | null;
  mm: number | null;
  codigos: number[];
}

interface Viento {
  velocidad: number | null;
  rafaga: number | null;
}

interface Hallazgo {
  categoria: CategoriaClima;
  titulo: string;
  detalle: string;
  resumen: string;
  consejo: string;
}

export function normalizarConfig(data: unknown): ConfigClima {
  const origen = esRegistro(data) ? data : {};
  return {
    activo: bandera(origen.activo, DEFAULTS.activo),
    latitud: numero(origen.latitud, DEFAULTS.latitud),
    longitud: numero(origen.longitud, DEFAULTS.longitud),
    lugar: texto(origen.lugar, DEFAULTS.lugar),
    lluviaProbMin: numero(origen.lluvia_prob_min, DEFAULTS.lluviaProbMin),
    lluviaMmMin: numero(origen.lluvia_mm_min, DEFAULTS.lluviaMmMin),
    lluviaFuerteMm: numero(origen.lluvia_fuerte_mm, DEFAULTS.lluviaFuerteMm),
    calorMax: numero(origen.calor_max, DEFAULTS.calorMax),
    frioMin: numero(origen.frio_min, DEFAULTS.frioMin),
    heladaMax: numero(origen.helada_max, DEFAULTS.heladaMax),
    vientoKmh: numero(origen.viento_kmh, DEFAULTS.vientoKmh),
    rafagaKmh: numero(origen.rafaga_kmh, DEFAULTS.rafagaKmh),
    frioDiaMax: numero(origen.frio_dia_max, DEFAULTS.frioDiaMax),
    nubladoMin: numero(origen.nublado_min, DEFAULTS.nubladoMin),
    lindoMin: numero(origen.lindo_min, DEFAULTS.lindoMin),
    lindoMax: numero(origen.lindo_max, DEFAULTS.lindoMax),
  };
}

export function evaluarClima(
  pronostico: unknown,
  config: ConfigClima,
  momento: MomentoClima,
  ahora: DateTime,
): AvisoClima[] {
  if (!config.activo) return [];
  const datos = interpretar(pronostico);
  if (!datos) return [];

  const hoy = ahora.setZone(ZONA).startOf('day');
  if (!hoy.isValid) return [];

  if (momento === 'manana') {
    const manana = evaluarManana(datos, config, hoy, ahora);
    return manana ? [manana] : [];
  }

  const frio = evaluarNoche(datos, config, hoy, ahora);
  return frio ? [frio] : [];
}

function evaluarManana(
  datos: Pronostico,
  config: ConfigClima,
  hoy: DateTime,
  ahora: DateTime,
): AvisoClima | null {
  const hallazgos = detectarCondiciones(datos, config, hoy);
  const elegido = hallazgos.length > 0 ? armarHallazgos(hallazgos) : evaluarLindo(datos, config, hoy);
  if (!elegido) return null;
  return avisoManana(elegido.categoria, ahora, elegido.titulo, elegido.cuerpo);
}

function detectarCondiciones(datos: Pronostico, config: ConfigClima, hoy: DateTime): Hallazgo[] {
  const horas = horasDelDia(datos, hoy);
  const diario = datos.dias.find((dia) => dia.fecha === hoy.toISODate());
  const precipitacion = leerPrecipitacion(horas, diario);
  const hallazgos: Hallazgo[] = [];

  const precip = hallazgoPrecipitacion(precipitacion, config);
  if (precip) hallazgos.push(precip);

  const maxima = diario?.maxima ?? null;
  if (maxima != null && maxima >= config.calorMax) {
    hallazgos.push({
      categoria: 'calor',
      titulo: 'Hoy hará mucho calor',
      detalle: `Máxima de ${entero(maxima)} °C.`,
      resumen: `calor (máxima de ${entero(maxima)} °C)`,
      consejo: CONSEJO_CALOR,
    });
  }

  const viento = leerViento(horas, diario);
  const vientoHallazgo = hallazgoViento(viento, config);
  if (vientoHallazgo) hallazgos.push(vientoHallazgo);

  if (maxima != null && maxima <= config.frioDiaMax) {
    hallazgos.push({
      categoria: 'frio_dia',
      titulo: 'Hoy hará frío todo el día',
      detalle: `Máxima de ${entero(maxima)} °C.`,
      resumen: `máxima de ${entero(maxima)} °C`,
      consejo: CONSEJO_FRIO_DIA,
    });
  }

  if (!precip) {
    const nubes = promedio(valores(horas.map((hora) => hora.nubes)));
    if (nubes != null && nubes >= config.nubladoMin) {
      hallazgos.push({
        categoria: 'nublado',
        titulo: 'Hoy estará nublado',
        detalle: `Nubosidad promedio de ${entero(nubes)} %.`,
        resumen: `nublado (${entero(nubes)} %)`,
        consejo: CONSEJO_NUBLADO,
      });
    }
  }

  return hallazgos;
}

function evaluarLindo(datos: Pronostico, config: ConfigClima, hoy: DateTime): { categoria: CategoriaClima; titulo: string; cuerpo: string } | null {
  const horas = horasDelDia(datos, hoy);
  const diario = datos.dias.find((dia) => dia.fecha === hoy.toISODate());
  const maxima = diario?.maxima ?? null;
  if (maxima == null || maxima < config.lindoMin || maxima > config.lindoMax) return null;

  const nubes = promedio(valores(horas.map((hora) => hora.nubes)));
  if (nubes == null || nubes > LINDO_NUBES_MAX) return null;

  const precipitacion = leerPrecipitacion(horas, diario);
  if (precipitacion.probabilidad == null || precipitacion.probabilidad > LINDO_LLUVIA_MAX) return null;
  if (precipitacion.mm != null && precipitacion.mm > 0) return null;

  const viento = leerViento(horas, diario);
  if (viento.velocidad == null || viento.velocidad > LINDO_VIENTO_MAX) return null;
  if (viento.rafaga != null && viento.rafaga >= config.rafagaKmh) return null;

  return {
    categoria: 'lindo',
    titulo: 'Hoy es un día lindo para trabajar',
    cuerpo: `Máxima de ${entero(maxima)} °C, con poco viento y sin lluvia. ${CONSEJO_LINDO}`,
  };
}

function armarHallazgos(hallazgos: Hallazgo[]): { categoria: CategoriaClima; titulo: string; cuerpo: string } {
  const ordenados = [...hallazgos].sort((a, b) => PRIORIDAD[a.categoria] - PRIORIDAD[b.categoria]);
  const [principal, ...resto] = ordenados;
  const tambien = resto.length === 0 ? '' : ` También: ${resto.map((item) => item.resumen).join(', ')}.`;
  return {
    categoria: principal.categoria,
    titulo: principal.titulo,
    cuerpo: `${principal.detalle}${tambien} ${principal.consejo}`,
  };
}

function hallazgoPrecipitacion(precipitacion: Precipitacion, config: ConfigClima): Hallazgo | null {
  const { probabilidad, mm, codigos } = precipitacion;
  const tiene = (codigosBuscados: Set<number>) => codigos.some((codigo) => codigosBuscados.has(codigo));
  const porcentaje = probabilidad == null ? null : entero(probabilidad);
  const detalleMm = textoMm(mm);

  if (tiene(CODIGOS_GRANIZO)) {
    return {
      categoria: 'granizo',
      titulo: 'Alerta de granizo hoy',
      detalle: 'Se espera granizo.',
      resumen: 'granizo',
      consejo: CONSEJO_GRANIZO,
    };
  }
  if (tiene(CODIGOS_TORMENTA)) {
    return {
      categoria: 'tormenta',
      titulo: 'Tormenta eléctrica hoy',
      detalle: 'Se espera tormenta eléctrica.',
      resumen: 'tormenta eléctrica',
      consejo: CONSEJO_TORMENTA,
    };
  }
  if (tiene(CODIGOS_LLUVIA_FUERTE) || (mm != null && mm >= config.lluviaFuerteMm)) {
    return {
      categoria: 'lluvia_fuerte',
      titulo: 'Se espera lluvia fuerte hoy',
      detalle: detallePrecipitacion('lluvia fuerte', porcentaje, detalleMm, true),
      resumen: mm != null && mm > 0 ? `lluvia fuerte (hasta ${unDecimal(mm)} mm)` : 'lluvia fuerte',
      consejo: CONSEJO_LLUVIA_FUERTE,
    };
  }

  const porMm = mm != null && mm >= config.lluviaMmMin;
  const lloviznaPorMm = probabilidad != null && probabilidad >= config.lluviaProbMin && mm != null && mm > 0 && mm < config.lluviaMmMin;
  const porProbabilidad = probabilidad != null && probabilidad >= config.lluviaProbMin && !lloviznaPorMm;
  if (tiene(CODIGOS_LLUVIA) || porMm || porProbabilidad) {
    return {
      categoria: 'lluvia',
      titulo: 'Se espera lluvia hoy',
      detalle: detallePrecipitacion('lluvia', porcentaje, detalleMm, false),
      resumen: resumenLluvia('lluvia', porcentaje, mm),
      consejo: CONSEJO_LLUVIA,
    };
  }
  if (tiene(CODIGOS_LLOVIZNA) || lloviznaPorMm) {
    return {
      categoria: 'llovizna',
      titulo: 'Se espera llovizna hoy',
      detalle: detallePrecipitacion('llovizna', porcentaje, detalleMm, false),
      resumen: resumenLluvia('llovizna', porcentaje, mm),
      consejo: CONSEJO_LLOVIZNA,
    };
  }
  return null;
}

function detallePrecipitacion(nombre: string, porcentaje: number | null, detalleMm: string, fuerte: boolean): string {
  if (porcentaje == null) {
    const base = fuerte ? 'Se espera lluvia fuerte' : `Se espera ${nombre}`;
    return `${base}${detalleMm}.`;
  }
  if (fuerte) return `Lluvia fuerte con probabilidad de ${porcentaje} %${detalleMm}.`;
  return `Probabilidad de ${nombre} de ${porcentaje} %${detalleMm}.`;
}

function hallazgoViento(viento: Viento, config: ConfigClima): Hallazgo | null {
  const porVelocidad = viento.velocidad != null && viento.velocidad >= config.vientoKmh;
  const porRafaga = viento.rafaga != null && viento.rafaga >= config.rafagaKmh;
  if (!porVelocidad && !porRafaga) return null;

  const detalle =
    porVelocidad && porRafaga
      ? `Viento de hasta ${entero(viento.velocidad ?? 0)} km/h, con ráfagas de ${entero(viento.rafaga ?? 0)} km/h.`
      : porRafaga
        ? `Ráfagas de hasta ${entero(viento.rafaga ?? 0)} km/h.`
        : `Viento de hasta ${entero(viento.velocidad ?? 0)} km/h.`;
  const resumen = porRafaga
    ? `ventoso (ráfagas de ${entero(viento.rafaga ?? 0)} km/h)`
    : `ventoso (hasta ${entero(viento.velocidad ?? 0)} km/h)`;
  return {
    categoria: 'viento',
    titulo: 'Hoy va a estar ventoso',
    detalle,
    resumen,
    consejo: CONSEJO_VIENTO,
  };
}

function resumenLluvia(nombre: string, porcentaje: number | null, mm: number | null): string {
  const porcentajeTexto = porcentaje == null ? '' : `${porcentaje} %`;
  const mmTexto = mm != null && mm > 0 ? `hasta ${unDecimal(mm)} mm` : '';
  const partes = [porcentajeTexto, mmTexto].filter((parte) => parte !== '');
  if (partes.length === 0) return nombre;
  return `${nombre} (${partes.join(', ')})`;
}

function evaluarNoche(datos: Pronostico, config: ConfigClima, hoy: DateTime, ahora: DateTime): AvisoClima | null {
  const desde = hoy.set({ hour: 20 });
  const hasta = hoy.plus({ days: 1 }).set({ hour: 8 });
  const temperaturas = valores(
    datos.horas
      .filter((hora) => hora.instante >= desde && hora.instante <= hasta)
      .map((hora) => hora.temperatura),
  );
  if (temperaturas.length === 0) return null;
  const minima = Math.min(...temperaturas);
  if (minima <= config.heladaMax) {
    return aviso(
      'frio',
      'noche',
      ahora,
      'Se espera helada esta noche',
      `Mínima de ${entero(minima)} °C. ${CONSEJO_FRIO}`,
    );
  }
  if (minima <= config.frioMin) {
    return aviso('frio', 'noche', ahora, 'Noche muy fría', `Mínima de ${entero(minima)} °C. ${CONSEJO_FRIO}`);
  }
  return null;
}

function horasDelDia(datos: Pronostico, hoy: DateTime): HoraPronostico[] {
  const desde = hoy.set({ hour: 8 });
  const hasta = hoy.set({ hour: 22 });
  return datos.horas.filter((hora) => hora.instante >= desde && hora.instante <= hasta);
}

function leerPrecipitacion(horas: HoraPronostico[], diario: DiaPronostico | undefined): Precipitacion {
  const probs = valores(horas.map((hora) => hora.probabilidad));
  const milimetros = valores(horas.map((hora) => hora.precipitacion));
  const codigosHora = horas
    .map((hora) => hora.codigo)
    .filter((codigo): codigo is number => codigo != null)
    .map((codigo) => Math.round(codigo));
  const codigoDiario = diario?.codigo == null ? [] : [Math.round(diario.codigo)];
  return {
    probabilidad: probs.length > 0 ? Math.max(...probs) : (diario?.probabilidadMax ?? null),
    mm: milimetros.length > 0 ? milimetros.reduce((suma, valor) => suma + valor, 0) : (diario?.precipitacionSuma ?? null),
    codigos: codigosHora.length > 0 ? codigosHora : codigoDiario,
  };
}

function leerViento(horas: HoraPronostico[], diario: DiaPronostico | undefined): Viento {
  const velocidades = valores(horas.map((hora) => hora.viento));
  const rafagas = valores(horas.map((hora) => hora.rafaga));
  return {
    velocidad: velocidades.length > 0 ? Math.max(...velocidades) : (diario?.vientoMax ?? null),
    rafaga: rafagas.length > 0 ? Math.max(...rafagas) : (diario?.rafagaMax ?? null),
  };
}

function avisoManana(categoria: CategoriaClima, ahora: DateTime, titulo: string, cuerpo: string): AvisoClima {
  const fecha = ahora.setZone(ZONA).toFormat('yyyyMMdd');
  return {
    clave: `clima_manana_${fecha}`,
    tipo: 'clima',
    categoria,
    titulo,
    cuerpo,
  };
}

function aviso(
  categoria: CategoriaClima,
  momento: MomentoClima,
  ahora: DateTime,
  titulo: string,
  cuerpo: string,
): AvisoClima {
  const fecha = ahora.setZone(ZONA).toFormat('yyyyMMdd');
  return {
    clave: `clima_${categoria}_${fecha}_${momento}`,
    tipo: 'clima',
    categoria,
    titulo,
    cuerpo,
  };
}

function interpretar(valor: unknown): Pronostico | null {
  if (!esRegistro(valor)) return null;
  const hourly = valor.hourly;
  const daily = valor.daily;
  if (hourly != null && !esRegistro(hourly)) return null;
  if (daily != null && !esRegistro(daily)) return null;
  return {
    horas: leerHoras(esRegistro(hourly) ? hourly : {}),
    dias: leerDias(esRegistro(daily) ? daily : {}),
  };
}

function leerHoras(hourly: Record<string, unknown>): HoraPronostico[] {
  const tiempos = textos(hourly.time);
  if (!tiempos) return [];
  const temperaturas = numerosOpcionales(hourly.temperature_2m, tiempos.length);
  const probabilidades = numerosOpcionales(hourly.precipitation_probability, tiempos.length);
  const precipitaciones = numerosOpcionales(hourly.precipitation, tiempos.length);
  if (!temperaturas || !probabilidades || !precipitaciones) return [];
  const codigos = serieOpcional(hourly.weather_code, tiempos.length);
  const nubes = serieOpcional(hourly.cloud_cover, tiempos.length);
  const vientos = serieOpcional(hourly.wind_speed_10m, tiempos.length);
  const rafagas = serieOpcional(hourly.wind_gusts_10m, tiempos.length);

  const horas: HoraPronostico[] = [];
  tiempos.forEach((tiempo, indice) => {
    const instante = DateTime.fromISO(tiempo, { zone: ZONA });
    if (!instante.isValid) return;
    horas.push({
      instante,
      temperatura: temperaturas[indice],
      probabilidad: probabilidades[indice],
      precipitacion: precipitaciones[indice],
      codigo: codigos[indice],
      nubes: nubes[indice],
      viento: vientos[indice],
      rafaga: rafagas[indice],
    });
  });
  return horas;
}

function leerDias(daily: Record<string, unknown>): DiaPronostico[] {
  const tiempos = textos(daily.time);
  if (!tiempos) return [];
  const maximas = numerosOpcionales(daily.temperature_2m_max, tiempos.length);
  const minimas = numerosOpcionales(daily.temperature_2m_min, tiempos.length);
  const probabilidades = numerosOpcionales(daily.precipitation_probability_max, tiempos.length);
  const sumas = numerosOpcionales(daily.precipitation_sum, tiempos.length);
  if (!maximas || !minimas || !probabilidades || !sumas) return [];
  const codigos = serieOpcional(daily.weather_code, tiempos.length);
  const vientos = serieOpcional(daily.wind_speed_10m_max, tiempos.length);
  const rafagas = serieOpcional(daily.wind_gusts_10m_max, tiempos.length);

  return tiempos.map((fecha, indice) => ({
    fecha,
    maxima: maximas[indice],
    minima: minimas[indice],
    probabilidadMax: probabilidades[indice],
    precipitacionSuma: sumas[indice],
    codigo: codigos[indice],
    vientoMax: vientos[indice],
    rafagaMax: rafagas[indice],
  }));
}

function textos(valor: unknown): string[] | null {
  if (!Array.isArray(valor)) return null;
  if (!valor.every((item) => typeof item === 'string')) return null;
  return valor as string[];
}

function numerosOpcionales(valor: unknown, largo: number): (number | null)[] | null {
  if (valor == null) return Array.from({ length: largo }, () => null);
  if (!Array.isArray(valor)) return null;
  const serie = valor.slice(0, largo).map((item) => (typeof item === 'number' && Number.isFinite(item) ? item : null));
  while (serie.length < largo) serie.push(null);
  return serie;
}

function serieOpcional(valor: unknown, largo: number): (number | null)[] {
  return numerosOpcionales(valor, largo) ?? Array.from({ length: largo }, () => null);
}

function valores(serie: (number | null)[]): number[] {
  return serie.filter((valor): valor is number => valor != null);
}

function promedio(serie: number[]): number | null {
  if (serie.length === 0) return null;
  return serie.reduce((suma, valor) => suma + valor, 0) / serie.length;
}

function esRegistro(valor: unknown): valor is Record<string, unknown> {
  return typeof valor === 'object' && valor != null && !Array.isArray(valor);
}

function numero(valor: unknown, defecto: number): number {
  return typeof valor === 'number' && Number.isFinite(valor) ? valor : defecto;
}

function bandera(valor: unknown, defecto: boolean): boolean {
  return typeof valor === 'boolean' ? valor : defecto;
}

function texto(valor: unknown, defecto: string): string {
  return typeof valor === 'string' && valor.trim() !== '' ? valor : defecto;
}

function entero(valor: number): number {
  const redondeado = Math.round(valor);
  return redondeado === 0 ? 0 : redondeado;
}

function unDecimal(valor: number): string {
  return (Math.round(valor * 10) / 10).toFixed(1);
}

function textoMm(mm: number | null): string {
  if (mm == null || mm <= 0) return '';
  return ` (hasta ${unDecimal(mm)} mm)`;
}
