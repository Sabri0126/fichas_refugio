import { DateTime } from 'luxon';

export const ZONA = 'America/Argentina/Buenos_Aires';

export type TipoAlarma = 'diaria' | 'ultimo_dia' | 'recordatorio' | 'seguimiento' | 'legacy' | 'ingreso';

export interface Alarma {
  clave: string;
  tipo: TipoAlarma;
  titulo: string;
  cuerpo: string;
  categoria: string;
  idPerro: string;
  fecha: DateTime;
  idTratamiento?: string;
  dia?: string;
  /** `false` calla el push en todos los celulares. Si falta, se avisa. */
  notificar?: boolean;
  /** Fecha de ingreso `aaaa-MM-dd`. Sirve para unir aniversarios de la misma camada. */
  cohorte?: string;
}

export interface DispositivoAviso {
  token: string;
  silenciados: readonly string[];
}

export interface TratamientoEntrada {
  id?: string;
  categoria?: string;
  activo?: boolean;
  medicacion?: string;
  hora_recordatorio?: string;
  notificar?: boolean;
  dias_duracion?: number | string;
  fecha_inicio?: unknown;
  fecha_proximo_recordatorio?: unknown;
  registro_dosis?: unknown;
}

export interface RecordatorioEntrada {
  id?: string;
  tipo?: string;
  titulo?: string;
  nota?: string;
  fecha_hora?: unknown;
}

export interface SeguimientoEntrada {
  id?: string;
  motivo?: string;
  detalle?: string;
  hora?: string;
  fecha_inicio?: unknown;
  dias_duracion?: number | string;
  activo?: boolean;
}

export interface PerroEntrada {
  id?: string;
  estado?: string;
  nombre?: string;
  fecha_ingreso?: unknown;
  tratamientos?: unknown;
  recordatorios?: unknown;
  seguimientos?: unknown;
}

interface Hora {
  hora: number;
  minuto: number;
}

export function aZona(valor: unknown): DateTime | null {
  if (valor == null) return null;
  if (DateTime.isDateTime(valor)) {
    const zoned = valor.setZone(ZONA);
    return zoned.isValid ? zoned : null;
  }
  if (valor instanceof Date) {
    const zoned = DateTime.fromJSDate(valor, { zone: ZONA });
    return zoned.isValid ? zoned : null;
  }
  if (typeof valor === 'string') {
    const zoned = DateTime.fromISO(valor, { setZone: true }).setZone(ZONA);
    return zoned.isValid ? zoned : null;
  }
  if (typeof valor === 'object') {
    const candidato = valor as { toDate?: () => Date; seconds?: number; _seconds?: number };
    if (typeof candidato.toDate === 'function') {
      const fecha = candidato.toDate();
      if (!(fecha instanceof Date) || Number.isNaN(fecha.getTime())) return null;
      const zoned = DateTime.fromJSDate(fecha, { zone: ZONA });
      return zoned.isValid ? zoned : null;
    }
    const segundos = candidato.seconds ?? candidato._seconds;
    if (typeof segundos === 'number') {
      const zoned = DateTime.fromSeconds(segundos, { zone: ZONA });
      return zoned.isValid ? zoned : null;
    }
  }
  return null;
}

export function calcularAlarmas(perro: PerroEntrada, desde: DateTime, hasta: DateTime): Alarma[] {
  if (perro.estado !== 'activo') return [];
  const inicioVentana = desde.setZone(ZONA);
  const finVentana = hasta.setZone(ZONA);
  if (!inicioVentana.isValid || !finVentana.isValid || finVentana <= inicioVentana) return [];

  const idPerro = perro.id?.toString() ?? '';
  const nombre = nombrePerro(perro);
  const alarmas: Alarma[] = [];

  for (const tratamiento of listaDe<TratamientoEntrada>(perro.tratamientos)) {
    const categoria = tratamiento.categoria?.toString() ?? '';
    if (categoria === 'diario') {
      const diaria = alarmaDiaria(tratamiento, idPerro, nombre, inicioVentana, finVentana);
      if (diaria.length > 0) alarmas.push(...diaria);
      continue;
    }
    const legacy = alarmaLegacy(tratamiento, idPerro, nombre, inicioVentana, finVentana);
    if (legacy) alarmas.push(legacy);
  }

  for (const recordatorio of listaDe<RecordatorioEntrada>(perro.recordatorios)) {
    const agendado = alarmaRecordatorio(recordatorio, idPerro, nombre, inicioVentana, finVentana);
    if (agendado) alarmas.push(agendado);
  }

  for (const seguimiento of listaDe<SeguimientoEntrada>(perro.seguimientos)) {
    alarmas.push(...alarmaSeguimiento(seguimiento, idPerro, nombre, inicioVentana, finVentana));
  }

  const ingreso = alarmaIngreso(perro, idPerro, nombre, inicioVentana, finVentana);
  if (ingreso) alarmas.push(ingreso);

  alarmas.sort((a, b) => a.fecha.toMillis() - b.fecha.toMillis() || a.clave.localeCompare(b.clave));
  return alarmas;
}

export function calcularPausas(perro: PerroEntrada, hoy: DateTime): string[] {
  if (perro.estado !== 'activo') return [];
  const hoyDia = hoy.setZone(ZONA).startOf('day');
  if (!hoyDia.isValid) return [];
  const ids: string[] = [];

  for (const tratamiento of listaDe<TratamientoEntrada>(perro.tratamientos)) {
    if (tratamiento.categoria !== 'diario' || tratamiento.activo !== true) continue;
    const dias = leerDias(tratamiento.dias_duracion);
    if (dias <= 0) continue;
    const inicio = diaDe(tratamiento.fecha_inicio);
    const id = tratamiento.id?.toString() ?? '';
    if (!inicio || id === '') continue;
    const ultimoDia = inicio.plus({ days: dias - 1 });
    if (hoyDia > ultimoDia) ids.push(id);
  }

  return ids;
}

export function listaSilenciados(valor: unknown): string[] {
  if (!Array.isArray(valor)) return [];
  return valor.map((item) => String(item).trim()).filter((item) => item !== '');
}

/** Sin tokens si el diario está callado para todos. Si no, omite los celulares que lo silenciaron. */
export function tokensParaAlarma(
  dispositivos: readonly DispositivoAviso[],
  alarma: { notificar?: boolean; idTratamiento?: string },
): string[] {
  if (alarma.notificar === false) return [];
  const id = alarma.idTratamiento?.trim() ?? '';
  return dispositivos.flatMap((dispositivo) => {
    if (id !== '' && dispositivo.silenciados.includes(id)) return [];
    return [dispositivo.token];
  });
}

function alarmaDiaria(
  tratamiento: TratamientoEntrada,
  idPerro: string,
  nombre: string,
  desde: DateTime,
  hasta: DateTime,
): Alarma[] {
  if (tratamiento.activo !== true) return [];
  const medicacion = tratamiento.medicacion?.toString().trim() ?? '';
  if (medicacion === '') return [];
  const hora = horaValida(tratamiento.hora_recordatorio);
  if (!hora) return [];

  const dias = leerDias(tratamiento.dias_duracion);
  const inicio = diaDe(tratamiento.fecha_inicio);
  if (dias > 0 && !inicio) return [];
  const ultimoDia = inicio && dias > 0 ? inicio.plus({ days: dias - 1 }) : null;
  const idItem = tratamiento.id?.toString() ?? '';
  const alarmas: Alarma[] = [];

  for (const dia of diasDeVentana(desde, hasta)) {
    if (inicio && dia < inicio) continue;
    if (ultimoDia && dia > ultimoDia) continue;
    const ocurrencia = dia.set({
      hour: hora.hora,
      minute: hora.minuto,
      second: 0,
      millisecond: 0,
    });
    if (!enVentana(ocurrencia, desde, hasta)) continue;

    const diaIso = dia.setZone(ZONA).toFormat('yyyy-MM-dd');
    if (diaYaMarcado(tratamiento.registro_dosis, diaIso)) continue;

    const esUltimo = ultimoDia != null && dia.hasSame(ultimoDia, 'day');
    const tipo: TipoAlarma = esUltimo ? 'ultimo_dia' : 'diaria';
    const aviso = 'Si no se la diste, tocá para dejarla pendiente.';
    const titulo = esUltimo ? 'Último día de medicación' : 'Medicación dada';
    const cuerpo = esUltimo
      ? `Hoy es el último día de ${medicacion} para ${nombre}. Mañana el tratamiento se pausará automáticamente. ${aviso}`
      : `Se marcó ${medicacion} para ${nombre}. ${aviso}`;

    alarmas.push({
      clave: armarClave(idPerro, tipo, idItem, ocurrencia),
      tipo,
      titulo,
      cuerpo,
      categoria: 'diario',
      idPerro,
      fecha: ocurrencia,
      idTratamiento: idItem,
      dia: diaIso,
      notificar: tratamiento.notificar !== false,
    });
  }

  return alarmas;
}

function alarmaLegacy(
  tratamiento: TratamientoEntrada,
  idPerro: string,
  nombre: string,
  desde: DateTime,
  hasta: DateTime,
): Alarma | null {
  const fecha = aZona(tratamiento.fecha_proximo_recordatorio);
  if (!fecha || !enVentana(fecha, desde, hasta)) return null;
  const categoria = tratamiento.categoria?.toString() ?? '';
  const medicacion = tratamiento.medicacion?.toString().trim() ?? '';
  const esVisita = categoria === 'veterinaria';
  const idItem = tratamiento.id?.toString() ?? '';
  return {
    clave: armarClave(idPerro, 'legacy', idItem, fecha),
    tipo: 'legacy',
    titulo: esVisita ? 'Visita veterinaria' : 'Dosis única pendiente',
    cuerpo: esVisita
      ? `Recordatorio: visita veterinaria para ${nombre}`
      : `Recordatorio: aplicar ${medicacion} a ${nombre}`,
    categoria,
    idPerro,
    fecha,
  };
}

function alarmaSeguimiento(
  seguimiento: SeguimientoEntrada,
  idPerro: string,
  nombre: string,
  desde: DateTime,
  hasta: DateTime,
): Alarma[] {
  if (seguimiento.activo !== true) return [];
  const idItem = seguimiento.id?.toString() ?? '';
  if (idItem === '') return [];
  const hora = horaValida(seguimiento.hora);
  if (!hora) return [];
  const inicio = diaDe(seguimiento.fecha_inicio);
  if (!inicio) return [];

  const dias = leerDias(seguimiento.dias_duracion);
  const ultimoDia = dias > 0 ? inicio.plus({ days: dias - 1 }) : null;
  const motivo = seguimiento.motivo?.toString() ?? '';
  const detalle = seguimiento.detalle?.toString().trim() ?? '';
  const alarmas: Alarma[] = [];

  for (const dia of diasDeVentana(desde, hasta)) {
    if (dia < inicio) continue;
    if (ultimoDia && dia > ultimoDia) continue;
    const ocurrencia = dia.set({
      hour: hora.hora,
      minute: hora.minuto,
      second: 0,
      millisecond: 0,
    });
    if (!enVentana(ocurrencia, desde, hasta)) continue;

    const esUltimo = ultimoDia != null && dia.hasSame(ultimoDia, 'day');
    alarmas.push({
      clave: armarClave(idPerro, 'seguimiento', idItem, ocurrencia),
      tipo: 'seguimiento',
      titulo: `Seguimiento de ${nombre}`,
      cuerpo: cuerpoSeguimiento(motivo, nombre, detalle, esUltimo),
      categoria: 'seguimiento',
      idPerro,
      fecha: ocurrencia,
    });
  }

  return alarmas;
}

function cuerpoSeguimiento(motivo: string, nombre: string, detalle: string, esUltimo: boolean): string {
  const frase = fraseSeguimiento(motivo, nombre);
  const limpio = detalle.replace(/\.+$/, '');
  const base = limpio === '' ? frase : `${frase.slice(0, -1)} (${limpio}).`;
  if (!esUltimo) return base;
  return `${base} Es el último día de seguimiento: si no mejora, extendelo o consultá al veterinario.`;
}

function fraseSeguimiento(motivo: string, nombre: string): string {
  switch (motivo) {
    case 'ojo':
      return `Recordá revisarle el ojo a ${nombre}.`;
    case 'herida':
      return `No olvides controlar la lastimadura de ${nombre}.`;
    case 'animo':
      return `Supervisá el estado de ánimo de ${nombre}.`;
    case 'pata':
      return `Fijate cómo apoya la pata ${nombre}.`;
    case 'una':
      return `Chequeá la uña de ${nombre}.`;
    case 'comportamiento':
      return `Recordá observar el comportamiento de ${nombre}.`;
    default:
      return `Recordá hacerle el seguimiento a ${nombre}.`;
  }
}

function alarmaRecordatorio(
  recordatorio: RecordatorioEntrada,
  idPerro: string,
  nombre: string,
  desde: DateTime,
  hasta: DateTime,
): Alarma | null {
  const fecha = aZona(recordatorio.fecha_hora);
  if (!fecha || !enVentana(fecha, desde, hasta)) return null;
  const titulo = recordatorio.titulo?.toString().trim() ?? '';
  const nota = recordatorio.nota?.toString().trim() ?? '';
  const tipo = recordatorio.tipo?.toString() ?? '';
  const idItem = recordatorio.id?.toString() ?? '';
  return {
    clave: armarClave(idPerro, 'recordatorio', idItem, fecha),
    tipo: 'recordatorio',
    titulo: `Recordatorio: ${titulo}`,
    cuerpo: nota === '' ? nombre : `${nombre} · ${nota}`,
    categoria: tipo === '' ? 'otro' : tipo,
    idPerro,
    fecha,
  };
}

function diaYaMarcado(registro: unknown, dia: string): boolean {
  if (!Array.isArray(registro)) return false;
  return registro.some((item) => item?.toString() === dia);
}

function armarClave(idPerro: string, tipo: TipoAlarma, idItem: string, fecha: DateTime): string {
  return `${idPerro}_${tipo}_${idItem}_${fecha.setZone(ZONA).toFormat('yyyyMMddHHmm')}`;
}

function enVentana(ocurrencia: DateTime, desde: DateTime, hasta: DateTime): boolean {
  const millis = ocurrencia.toMillis();
  return millis > desde.toMillis() && millis <= hasta.toMillis();
}

function diasDeVentana(desde: DateTime, hasta: DateTime): DateTime[] {
  const dias: DateTime[] = [];
  const fin = hasta.setZone(ZONA).startOf('day');
  for (let dia = desde.setZone(ZONA).startOf('day'); dia <= fin; dia = dia.plus({ days: 1 })) {
    dias.push(dia);
  }
  return dias;
}

/// A las 9:00 del aniversario de ingreso. Una clave por perro y por año.
function alarmaIngreso(
  perro: PerroEntrada,
  idPerro: string,
  nombre: string,
  desde: DateTime,
  hasta: DateTime,
): Alarma | null {
  if (idPerro === '') return null;
  const ingreso = diaDe(perro.fecha_ingreso);
  if (!ingreso) return null;

  for (const dia of diasDeVentana(desde, hasta)) {
    const anios = dia.year - ingreso.year;
    if (anios < 1) continue;
    const cumple = diaAniversario(ingreso, dia.year);
    if (!cumple || !dia.hasSame(cumple, 'day')) continue;
    const ocurrencia = cumple.set({ hour: 9, minute: 0, second: 0, millisecond: 0 });
    if (!enVentana(ocurrencia, desde, hasta)) continue;
    const verbo = anios === 1 ? 'cumple' : 'cumplen';
    const unidad = anios === 1 ? 'año' : 'años';
    return {
      clave: `ingreso_${idPerro}_${dia.year}`,
      tipo: 'ingreso',
      titulo: 'Aniversario de ingreso',
      cuerpo: `Hoy se ${verbo} ${anios} ${unidad} desde que ${nombre} ingresó al refugio.`,
      categoria: 'ingreso',
      idPerro,
      fecha: ocurrencia,
      cohorte: ingreso.toFormat('yyyy-MM-dd'),
    };
  }
  return null;
}

/// Une los aniversarios de perros que entraron el mismo día en un solo aviso.
/// Uno solo conserva su clave y su ficha. Una camada queda sin perro asociado.
export function agruparIngresos(alarmas: Alarma[]): Alarma[] {
  const otras: Alarma[] = [];
  const grupos = new Map<string, Alarma[]>();
  for (const alarma of alarmas) {
    if (alarma.tipo !== 'ingreso' || !alarma.cohorte) {
      otras.push(alarma);
      continue;
    }
    const lista = grupos.get(alarma.cohorte) ?? [];
    lista.push(alarma);
    grupos.set(alarma.cohorte, lista);
  }
  const unidas = [...grupos.values()].map((grupo) => (grupo.length === 1 ? grupo[0] : unirIngresos(grupo)));
  return [...otras, ...unidas].sort(
    (a, b) => a.fecha.toMillis() - b.fecha.toMillis() || a.clave.localeCompare(b.clave),
  );
}

function unirIngresos(grupo: Alarma[]): Alarma {
  const base = grupo[0];
  const anio = base.fecha.setZone(ZONA).year;
  const anios = anio - Number(base.cohorte!.slice(0, 4));
  const nombres = grupo.map(nombreDeIngreso).sort((a, b) => a.localeCompare(b, 'es'));
  const verbo = anios === 1 ? 'cumple' : 'cumplen';
  const unidad = anios === 1 ? 'año' : 'años';
  return {
    clave: `ingreso_${base.cohorte}_${anio}`,
    tipo: 'ingreso',
    titulo: 'Aniversario de ingreso',
    cuerpo: `Hoy se ${verbo} ${anios} ${unidad} desde que ${listaNombres(nombres)} ingresaron al refugio.`,
    categoria: 'ingreso',
    idPerro: '',
    fecha: base.fecha,
    cohorte: base.cohorte,
  };
}

function nombreDeIngreso(alarma: Alarma): string {
  const coincidencia = /desde que (.+) ingresó al refugio\.$/.exec(alarma.cuerpo);
  return coincidencia?.[1] ?? 'tu perrito';
}

function listaNombres(nombres: string[]): string {
  if (nombres.length <= 1) return nombres[0] ?? 'tu perrito';
  if (nombres.length === 2) return `${nombres[0]} y ${nombres[1]}`;
  return `${nombres.slice(0, -1).join(', ')} y ${nombres[nombres.length - 1]}`;
}

/// El 29 de febrero, en un año no bisiesto, cae el 28.
function diaAniversario(ingreso: DateTime, anio: number): DateTime | null {
  const candidato = DateTime.fromObject(
    { year: anio, month: ingreso.month, day: ingreso.day },
    { zone: ZONA },
  );
  if (candidato.isValid) return candidato.startOf('day');
  if (ingreso.month === 2 && ingreso.day === 29) {
    return DateTime.fromObject({ year: anio, month: 2, day: 28 }, { zone: ZONA }).startOf('day');
  }
  return null;
}

function diaDe(valor: unknown): DateTime | null {
  const fecha = aZona(valor);
  return fecha ? fecha.startOf('day') : null;
}

function horaValida(valor: unknown): Hora | null {
  if (typeof valor !== 'string') return null;
  const coincidencia = /^(\d{1,2}):(\d{2})$/.exec(valor.trim());
  if (!coincidencia) return null;
  const hora = Number(coincidencia[1]);
  const minuto = Number(coincidencia[2]);
  if (hora > 23 || minuto > 59) return null;
  return { hora, minuto };
}

function leerDias(valor: unknown): number {
  if (typeof valor === 'number' && Number.isFinite(valor)) return Math.trunc(valor);
  if (typeof valor === 'string' && valor.trim() !== '') {
    const numero = Number(valor);
    if (Number.isFinite(numero)) return Math.trunc(numero);
  }
  return 0;
}

function nombrePerro(perro: PerroEntrada): string {
  const nombre = perro.nombre?.toString().trim() ?? '';
  return nombre === '' ? 'tu perrito' : nombre;
}

function listaDe<T>(valor: unknown): T[] {
  if (!Array.isArray(valor)) return [];
  return valor.filter((item): item is T => typeof item === 'object' && item != null);
}
