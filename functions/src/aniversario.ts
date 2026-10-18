import { DateTime } from 'luxon';

import { ZONA } from './alarmas.js';

const FUNDACION = { year: 2000, month: 4, day: 29 };

/// Años ya cumplidos. Antes del 29 de abril de este año resta uno.
export function aniosCumplidos(ahora: DateTime): number {
  const dia = ahora.setZone(ZONA).startOf('day');
  let anios = dia.year - FUNDACION.year;
  const cumple = dia.set({ month: FUNDACION.month, day: FUNDACION.day });
  if (dia < cumple) anios -= 1;
  return anios < 0 ? 0 : anios;
}

/// Solo la corrida de las 8 del 29 de abril, hora de Buenos Aires.
export function esMananaDeAniversario(ahora: DateTime): boolean {
  const local = ahora.setZone(ZONA);
  return local.month === 4 && local.day === 29 && local.hour < 12;
}

export function mensajeAniversario(ahora: DateTime): {
  clave: string;
  titulo: string;
  cuerpo: string;
  idPerro: string;
  categoria: string;
  tipo: string;
} {
  const local = ahora.setZone(ZONA);
  const anios = aniosCumplidos(local);
  return {
    clave: `aniversario_${local.year}`,
    titulo: '¡Feliz aniversario!',
    cuerpo: `Hoy el Refugio Milagros de Amor cumple ${anios} años de servicio ininterrumpido cuidando perritos.`,
    idPerro: '',
    categoria: 'aniversario',
    tipo: 'aniversario',
  };
}
