import { DateTime } from 'luxon';
import { describe, expect, it } from 'vitest';

import {
  ZONA,
  aZona,
  calcularAlarmas,
  calcularPausas,
  type PerroEntrada,
} from '../src/alarmas.js';

function ba(iso: string): DateTime {
  return DateTime.fromISO(iso, { zone: ZONA });
}

function diario(extra: Record<string, unknown> = {}) {
  return {
    id: 'doxi',
    categoria: 'diario',
    activo: true,
    medicacion: 'Doxiciclina',
    hora_recordatorio: '09:00',
    dias_duracion: 30,
    fecha_inicio: ba('2026-01-01T12:00:00'),
    ...extra,
  };
}

function perro(extra: Partial<PerroEntrada> = {}): PerroEntrada {
  return {
    id: 'canelo',
    estado: 'activo',
    nombre: 'Canelo',
    tratamientos: [diario()],
    recordatorios: [],
    ...extra,
  };
}

describe('calcularAlarmas', () => {
  it('incluye la diaria dentro de la ventana y excluye la de afuera', () => {
    const dentro = calcularAlarmas(perro(), ba('2026-01-10T08:00:00'), ba('2026-01-10T10:00:00'));
    expect(dentro).toHaveLength(1);
    expect(dentro[0].tipo).toBe('diaria');
    expect(dentro[0].titulo).toBe('Medicación dada');
    expect(dentro[0].cuerpo).toBe(
      'Se marcó Doxiciclina para Canelo. Si no se la diste, tocá para dejarla pendiente.',
    );
    expect(dentro[0].idTratamiento).toBe('doxi');
    expect(dentro[0].dia).toBe('2026-01-10');
    expect(dentro[0].categoria).toBe('diario');

    const fuera = calcularAlarmas(perro(), ba('2026-01-10T10:00:00'), ba('2026-01-10T10:05:00'));
    expect(fuera).toHaveLength(0);
  });

  it('la ventana cruza medianoche', () => {
    const alarmas = calcularAlarmas(
      perro({ tratamientos: [diario({ hora_recordatorio: '00:30', dias_duracion: 0 })] }),
      ba('2026-01-10T23:50:00'),
      ba('2026-01-11T01:00:00'),
    );
    expect(alarmas.map((alarma) => alarma.fecha.setZone(ZONA).toFormat('yyyy-MM-dd HH:mm'))).toEqual([
      '2026-01-11 00:30',
    ]);
  });

  it('N=30 avisa el día 29, marca el último día y no avisa el 31', () => {
    const dia29 = calcularAlarmas(perro(), ba('2026-01-29T08:00:00'), ba('2026-01-29T10:00:00'));
    expect(dia29[0].tipo).toBe('diaria');
    expect(dia29[0].cuerpo).toContain('Se marcó Doxiciclina para Canelo');

    const dia30 = calcularAlarmas(perro(), ba('2026-01-30T08:00:00'), ba('2026-01-30T10:00:00'));
    expect(dia30).toHaveLength(1);
    expect(dia30[0].tipo).toBe('ultimo_dia');
    expect(dia30[0].titulo).toBe('Último día de medicación');
    expect(dia30[0].cuerpo).toBe(
      'Hoy es el último día de Doxiciclina para Canelo. Mañana el tratamiento se pausará automáticamente. Si no se la diste, tocá para dejarla pendiente.',
    );

    const dia31 = calcularAlarmas(perro(), ba('2026-01-31T08:00:00'), ba('2026-01-31T10:00:00'));
    expect(dia31).toHaveLength(0);
    expect(calcularPausas(perro(), ba('2026-01-30T23:00:00'))).toEqual([]);
    expect(calcularPausas(perro(), ba('2026-01-31T08:00:00'))).toEqual(['doxi']);
  });

  it('N=0 sigue todos los días y no se pausa', () => {
    const alarmas = calcularAlarmas(
      perro({ tratamientos: [diario({ dias_duracion: 0 })] }),
      ba('2026-03-01T08:00:00'),
      ba('2026-03-02T10:00:00'),
    );
    expect(alarmas.map((alarma) => alarma.tipo)).toEqual(['diaria', 'diaria']);
    expect(calcularPausas(perro({ tratamientos: [diario({ dias_duracion: 0 })] }), ba('2027-01-01T00:00:00'))).toEqual(
      [],
    );
  });

  it('no avisa antes del inicio ni si el inicio es futuro', () => {
    const antes = calcularAlarmas(perro(), ba('2025-12-31T08:00:00'), ba('2025-12-31T10:00:00'));
    expect(antes).toHaveLength(0);

    const futuro = calcularAlarmas(
      perro({ tratamientos: [diario({ fecha_inicio: ba('2026-02-01T12:00:00') })] }),
      ba('2026-01-10T08:00:00'),
      ba('2026-01-10T10:00:00'),
    );
    expect(futuro).toHaveLength(0);
  });

  it('ignora un tratamiento pausado y un perro que no está activo', () => {
    const pausado = calcularAlarmas(
      perro({ tratamientos: [diario({ activo: false })] }),
      ba('2026-01-10T08:00:00'),
      ba('2026-01-10T10:00:00'),
    );
    expect(pausado).toHaveLength(0);

    const egresado = calcularAlarmas(
      perro({ estado: 'egresado' }),
      ba('2026-01-10T08:00:00'),
      ba('2026-01-10T10:00:00'),
    );
    expect(egresado).toHaveLength(0);
    expect(calcularPausas(perro({ estado: 'egresado' }), ba('2026-02-01T00:00:00'))).toEqual([]);
  });

  it('incluye el recordatorio dentro de la ventana y excluye el de afuera', () => {
    const base = perro({
      tratamientos: [],
      recordatorios: [
        {
          id: 'vet',
          tipo: 'veterinaria',
          titulo: 'Visita al veterinario',
          nota: 'Ayuno',
          fecha_hora: ba('2026-01-10T10:30:00'),
        },
      ],
    });
    const dentro = calcularAlarmas(base, ba('2026-01-10T10:00:00'), ba('2026-01-10T11:00:00'));
    expect(dentro[0]).toMatchObject({
      tipo: 'recordatorio',
      titulo: 'Recordatorio: Visita al veterinario',
      cuerpo: 'Canelo · Ayuno',
      categoria: 'veterinaria',
    });

    const fuera = calcularAlarmas(base, ba('2026-01-10T11:00:00'), ba('2026-01-10T12:00:00'));
    expect(fuera).toHaveLength(0);
  });

  it('legacy usa el texto de veterinaria o el de dosis única', () => {
    const ventana = [ba('2026-01-10T09:00:00'), ba('2026-01-10T12:00:00')] as const;
    const vet = calcularAlarmas(
      perro({
        tratamientos: [
          {
            id: 'visita',
            categoria: 'veterinaria',
            medicacion: 'Control',
            fecha_proximo_recordatorio: ba('2026-01-10T10:00:00'),
          },
        ],
      }),
      ...ventana,
    );
    expect(vet[0].titulo).toBe('Visita veterinaria');
    expect(vet[0].cuerpo).toBe('Recordatorio: visita veterinaria para Canelo');
    expect(vet[0].categoria).toBe('veterinaria');

    const higiene = calcularAlarmas(
      perro({
        tratamientos: [
          {
            id: 'bano',
            categoria: 'higiene',
            medicacion: 'Baño',
            fecha_proximo_recordatorio: ba('2026-01-10T10:00:00'),
          },
        ],
      }),
      ...ventana,
    );
    expect(higiene[0].titulo).toBe('Dosis única pendiente');
    expect(higiene[0].cuerpo).toBe('Recordatorio: aplicar Baño a Canelo');
    expect(higiene[0].categoria).toBe('higiene');
  });

  it('la clave es estable', () => {
    const desde = ba('2026-01-10T08:00:00');
    const hasta = ba('2026-01-10T10:00:00');
    const primera = calcularAlarmas(perro(), desde, hasta)[0].clave;
    const segunda = calcularAlarmas(perro(), desde, hasta)[0].clave;
    expect(primera).toBe(segunda);
    expect(primera).toBe('canelo_diaria_doxi_202601100900');
  });

  it('un Timestamp UTC se lee como el día en Buenos Aires', () => {
    const fechaInicio = { toDate: () => new Date('2026-01-15T02:30:00.000Z') };
    expect(aZona(fechaInicio)?.toFormat('yyyy-MM-dd HH:mm')).toBe('2026-01-14 23:30');

    const conInicio = perro({
      tratamientos: [diario({ dias_duracion: 1, fecha_inicio: fechaInicio })],
    });
    const diaLocal = calcularAlarmas(conInicio, ba('2026-01-14T08:00:00'), ba('2026-01-14T10:00:00'));
    expect(diaLocal).toHaveLength(1);
    expect(diaLocal[0].tipo).toBe('ultimo_dia');
    expect(diaLocal[0].fecha.setZone(ZONA).toFormat('yyyy-MM-dd HH:mm')).toBe('2026-01-14 09:00');
    expect(diaLocal[0].clave.endsWith('202601140900')).toBe(true);

    const diaUtc = calcularAlarmas(conInicio, ba('2026-01-15T08:00:00'), ba('2026-01-15T10:00:00'));
    expect(diaUtc).toHaveLength(0);
  });

  it('un día ya marcado no genera alarma', () => {
    const alarmas = calcularAlarmas(
      perro({ tratamientos: [diario({ registro_dosis: ['2026-01-10'] })] }),
      ba('2026-01-10T08:00:00'),
      ba('2026-01-10T10:00:00'),
    );
    expect(alarmas).toHaveLength(0);
  });

  it('avisa el seguimiento a la hora elegida, dentro de los días, y marca el último', () => {
    const base = perro({
      tratamientos: [],
      seguimientos: [
        {
          id: 'ojo-1',
          motivo: 'ojo',
          detalle: 'ojo izquierdo',
          hora: '18:00',
          fecha_inicio: ba('2026-01-10T12:00:00'),
          dias_duracion: 3,
          activo: true,
        },
      ],
    });

    const primero = calcularAlarmas(base, ba('2026-01-10T17:00:00'), ba('2026-01-10T19:00:00'));
    expect(primero).toHaveLength(1);
    expect(primero[0].tipo).toBe('seguimiento');
    expect(primero[0].categoria).toBe('seguimiento');
    expect(primero[0].titulo).toBe('Seguimiento de Canelo');
    expect(primero[0].cuerpo).toBe('Recordá revisarle el ojo a Canelo (ojo izquierdo).');
    expect(primero[0].fecha.setZone(ZONA).toFormat('yyyy-MM-dd HH:mm')).toBe('2026-01-10 18:00');
    expect(primero[0].clave).toBe('canelo_seguimiento_ojo-1_202601101800');
    expect(calcularAlarmas(base, ba('2026-01-10T17:00:00'), ba('2026-01-10T19:00:00'))[0].clave).toBe(primero[0].clave);

    const fuera = calcularAlarmas(base, ba('2026-01-09T17:00:00'), ba('2026-01-09T19:00:00'));
    expect(fuera).toHaveLength(0);

    const ultimo = calcularAlarmas(base, ba('2026-01-12T17:00:00'), ba('2026-01-12T19:00:00'));
    expect(ultimo[0].cuerpo).toBe(
      'Recordá revisarle el ojo a Canelo (ojo izquierdo). Es el último día de seguimiento: si no mejora, extendelo o consultá al veterinario.',
    );

    const despues = calcularAlarmas(base, ba('2026-01-13T17:00:00'), ba('2026-01-13T19:00:00'));
    expect(despues).toHaveLength(0);
  });

  it('un seguimiento sin fin sigue, y uno cerrado o sin id no avisa', () => {
    const ventana = [ba('2027-06-01T17:00:00'), ba('2027-06-01T19:00:00')] as const;
    const abierto = calcularAlarmas(
      perro({
        tratamientos: [],
        seguimientos: [
          {
            id: 'pata-1',
            motivo: 'pata',
            detalle: '',
            hora: '18:00',
            fecha_inicio: ba('2026-01-10T12:00:00'),
            dias_duracion: 0,
            activo: true,
          },
        ],
      }),
      ...ventana,
    );
    expect(abierto[0].cuerpo).toBe('Fijate cómo apoya la pata Canelo.');

    const cerrado = calcularAlarmas(
      perro({
        tratamientos: [],
        seguimientos: [
          {
            id: 'pata-1',
            motivo: 'pata',
            hora: '18:00',
            fecha_inicio: ba('2026-01-10T12:00:00'),
            dias_duracion: 0,
            activo: false,
          },
        ],
      }),
      ...ventana,
    );
    expect(cerrado).toHaveLength(0);

    const sinId = calcularAlarmas(
      perro({
        tratamientos: [],
        seguimientos: [
          {
            motivo: 'una',
            hora: '18:00',
            fecha_inicio: ba('2026-01-10T12:00:00'),
            dias_duracion: 0,
            activo: true,
          },
        ],
      }),
      ...ventana,
    );
    expect(sinId).toHaveLength(0);
  });

  it('arma la frase según el motivo y no repite la clave entre seguimientos', () => {
    const frases: [string, string][] = [
      ['ojo', 'Recordá revisarle el ojo a Canelo.'],
      ['herida', 'No olvides controlar la lastimadura de Canelo.'],
      ['animo', 'Supervisá el estado de ánimo de Canelo.'],
      ['pata', 'Fijate cómo apoya la pata Canelo.'],
      ['una', 'Chequeá la uña de Canelo.'],
      ['comportamiento', 'Recordá observar el comportamiento de Canelo.'],
      ['otro', 'Recordá hacerle el seguimiento a Canelo.'],
    ];
    const desde = ba('2026-01-10T17:00:00');
    const hasta = ba('2026-01-10T19:00:00');
    const claves = new Set<string>();
    for (const [motivo, cuerpo] of frases) {
      const alarmas = calcularAlarmas(
        perro({
          tratamientos: [],
          seguimientos: [
            {
              id: motivo,
              motivo,
              hora: '18:00',
              fecha_inicio: ba('2026-01-10T08:00:00'),
              dias_duracion: 5,
              activo: true,
            },
          ],
        }),
        desde,
        hasta,
      );
      expect(alarmas[0].cuerpo).toBe(cuerpo);
      claves.add(alarmas[0].clave);
    }
    expect(claves.size).toBe(frases.length);
  });

  it('la alarma diaria trae el tratamiento y el día', () => {
    const alarmas = calcularAlarmas(perro(), ba('2026-01-10T08:00:00'), ba('2026-01-10T10:00:00'));
    expect(alarmas[0].idTratamiento).toBe('doxi');
    expect(alarmas[0].dia).toBe('2026-01-10');
  });
});
