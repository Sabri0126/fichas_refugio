import { DateTime } from 'luxon';

import { ZONA } from './alarmas.js';

export type MomentoClima = 'manana' | 'noche';
export type CategoriaClima = 'lluvia' | 'calor' | 'frio';

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
  calorMax: number;
  frioMin: number;
  heladaMax: number;
}

const DEFAULTS: ConfigClima = {
  activo: true,
  latitud: -38.9833,
  longitud: -64.0933,
  lugar: 'Río Colorado, Río Negro',
  lluviaProbMin: 60,
  lluviaMmMin: 2,
  calorMax: 30,
  frioMin: 4,
  heladaMax: 0,
};

const CONSEJO_LLUVIA =
  'Guardá las cuchas y los comederos que estén a la intemperie, y revisá que sus espacios no se inunden.';
const CONSEJO_CALOR =
  'Poné piletas con agua fresca, reforzá los bebederos y asegurá sombra para todos. Evitá el sol en las horas centrales del día.';
const CONSEJO_FRIO =
  'Prendé las estufas, revisá que las cuchas estén secas y con abrigo, y sumá mantas para los más viejos y los cachorros.';

interface HoraPronostico {
  instante: DateTime;
  temperatura: number | null;
  probabilidad: number | null;
  precipitacion: number | null;
}

interface DiaPronostico {
  fecha: string;
  maxima: number | null;
  minima: number | null;
  probabilidadMax: number | null;
  precipitacionSuma: number | null;
}

interface Pronostico {
  horas: HoraPronostico[];
  dias: DiaPronostico[];
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
    calorMax: numero(origen.calor_max, DEFAULTS.calorMax),
    frioMin: numero(origen.frio_min, DEFAULTS.frioMin),
    heladaMax: numero(origen.helada_max, DEFAULTS.heladaMax),
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
  const avisos: AvisoClima[] = [];

  if (momento === 'manana') {
    const lluvia = evaluarLluvia(datos, config, hoy, ahora);
    if (lluvia) avisos.push(lluvia);
    const calor = evaluarCalor(datos, config, hoy, ahora);
    if (calor) avisos.push(calor);
    return avisos;
  }

  const frio = evaluarNoche(datos, config, hoy, ahora);
  if (frio) avisos.push(frio);
  return avisos;
}

function evaluarLluvia(
  datos: Pronostico,
  config: ConfigClima,
  hoy: DateTime,
  ahora: DateTime,
): AvisoClima | null {
  const desde = hoy.set({ hour: 8 });
  const hasta = hoy.set({ hour: 22 });
  const horas = datos.horas.filter((hora) => hora.instante >= desde && hora.instante <= hasta);
  const probs = valores(horas.map((hora) => hora.probabilidad));
  const milimetros = valores(horas.map((hora) => hora.precipitacion));
  const diario = datos.dias.find((dia) => dia.fecha === hoy.toISODate());

  const probabilidad = probs.length > 0 ? Math.max(...probs) : (diario?.probabilidadMax ?? null);
  const mm = milimetros.length > 0 ? milimetros.reduce((suma, valor) => suma + valor, 0) : (diario?.precipitacionSuma ?? null);
  const porProbabilidad = probabilidad != null && probabilidad >= config.lluviaProbMin;
  const porMilimetros = mm != null && mm >= config.lluviaMmMin;
  if (!porProbabilidad && !porMilimetros) return null;

  const porcentaje = entero(probabilidad ?? diario?.probabilidadMax ?? 0);
  const detalleMm = mm == null ? '' : ` (hasta ${unDecimal(mm)} mm)`;
  return aviso(
    'lluvia',
    'manana',
    ahora,
    'Se espera lluvia hoy',
    `Probabilidad de lluvia de ${porcentaje} %${detalleMm}. ${CONSEJO_LLUVIA}`,
  );
}

function evaluarCalor(datos: Pronostico, config: ConfigClima, hoy: DateTime, ahora: DateTime): AvisoClima | null {
  const maxima = datos.dias.find((dia) => dia.fecha === hoy.toISODate())?.maxima;
  if (maxima == null || maxima < config.calorMax) return null;
  return aviso(
    'calor',
    'manana',
    ahora,
    'Hoy hará mucho calor',
    `Máxima de ${entero(maxima)} °C. ${CONSEJO_CALOR}`,
  );
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

  const horas: HoraPronostico[] = [];
  tiempos.forEach((tiempo, indice) => {
    const instante = DateTime.fromISO(tiempo, { zone: ZONA });
    if (!instante.isValid) return;
    horas.push({
      instante,
      temperatura: temperaturas[indice],
      probabilidad: probabilidades[indice],
      precipitacion: precipitaciones[indice],
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

  return tiempos.map((fecha, indice) => ({
    fecha,
    maxima: maximas[indice],
    minima: minimas[indice],
    probabilidadMax: probabilidades[indice],
    precipitacionSuma: sumas[indice],
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

function valores(serie: (number | null)[]): number[] {
  return serie.filter((valor): valor is number => valor != null);
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
