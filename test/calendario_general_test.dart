import 'package:fichas_refugio/controllers/calendario_general_controller.dart';
import 'package:fichas_refugio/controllers/recordatorio_controller.dart';
import 'package:fichas_refugio/controllers/tratamiento_controller.dart';
import 'package:fichas_refugio/models/perro_model.dart';
import 'package:fichas_refugio/models/recordatorio_model.dart';
import 'package:fichas_refugio/models/tratamiento_model.dart';
import 'package:fichas_refugio/theme/app_colors.dart';
import 'package:fichas_refugio/theme/category_colors.dart';
import 'package:flutter_test/flutter_test.dart';

final hoy = DateTime(2026, 6, 15);
final ayer = DateTime(2026, 6, 14);
final manana = DateTime(2026, 6, 16);

String iso(DateTime fecha) => TratamientoController().formatearFechaISO(fecha);

TratamientoModel diario({
  String id = 'diario',
  String medicacion = 'Pastilla',
  String indicaciones = '1 comprimido',
  DateTime? inicio,
  int dias = 10,
  bool activo = true,
  List<String> dosis = const [],
  String? hora,
}) {
  return TratamientoModel(
    id: id,
    categoria: 'diario',
    medicacion: medicacion,
    indicaciones: indicaciones,
    fechaInicio: inicio ?? DateTime(2026, 6, 10),
    diasDuracion: dias,
    activo: activo,
    registroDosis: dosis,
    horaRecordatorio: hora,
  );
}

TratamientoModel evento({
  required String categoria,
  required String medicacion,
  required DateTime dia,
  String id = 'evento',
  String indicaciones = 'Control',
}) {
  return TratamientoModel(
    id: id,
    categoria: categoria,
    medicacion: medicacion,
    indicaciones: indicaciones,
    fechaInicio: dia,
    registroDosis: [iso(dia)],
    activo: true,
  );
}

PerroModel perro({
  String id = 'p1',
  String nombre = 'Luna',
  String estado = 'activo',
  DateTime? fechaIngreso,
  DateTime? fechaFallecimiento,
  List<TratamientoModel> tratamientos = const [],
  List<RecordatorioModel> recordatorios = const [],
}) {
  return PerroModel(
    id: id,
    nombre: nombre,
    estado: estado,
    fechaIngreso: fechaIngreso,
    fechaFallecimiento: fechaFallecimiento,
    tratamientos: tratamientos,
    recordatorios: recordatorios,
  );
}

RecordatorioModel recordatorio({
  required DateTime fechaHora,
  String id = 'r1',
  String tipo = 'veterinaria',
  String titulo = 'Visita',
  String nota = 'Llevar libreta',
}) {
  return RecordatorioModel(
    id: id,
    tipo: tipo,
    titulo: titulo,
    nota: nota,
    fechaHora: fechaHora,
  );
}

ResumenDia resumen(List<PerroModel> perros, DateTime dia, {String? idPerro}) {
  return CalendarioGeneralController.construirResumen(
    perros,
    dia,
    hoy: hoy,
    idPerro: idPerro,
  );
}

List<String> marcadores(
  List<PerroModel> perros,
  DateTime dia, {
  String? idPerro,
}) {
  return CalendarioGeneralController.marcadoresDelDia(
    perros,
    dia,
    hoy: hoy,
    idPerro: idPerro,
  );
}

void main() {
  test('una dosis marcada hoy queda en dadas y no en pendientes', () {
    final lista = [
      perro(
        tratamientos: [
          diario(dosis: [iso(hoy)], hora: '09:00'),
        ],
      ),
    ];

    final dia = resumen(lista, hoy);

    expect(dia.dadas, hasLength(1));
    expect(dia.dadas.single.titulo, 'Pastilla');
    expect(dia.dadas.single.hora, '09:00');
    expect(dia.pendientes, isEmpty);
    expect(dia.total, 1);
  });

  test(
    'un diario de hoy sin marcar queda pendiente, también si es el último día',
    () {
      final enCurso = diario(id: 'curso', medicacion: 'En curso');
      final ultimo = diario(
        id: 'ultimo',
        medicacion: 'Último',
        inicio: hoy,
        dias: 1,
        hora: '08:00',
      );

      final dia = resumen([
        perro(tratamientos: [enCurso, ultimo]),
      ], hoy);

      expect(dia.pendientes.map((item) => item.titulo), ['Último', 'En curso']);
      expect(dia.dadas, isEmpty);
      expect(dia.programadas, isEmpty);
    },
  );

  test('ayer sin marcar no aparece y ayer marcada es dada', () {
    final lista = [
      perro(
        tratamientos: [
          diario(id: 'sin', medicacion: 'Sin marcar'),
          diario(
            id: 'con',
            medicacion: 'Marcada',
            dosis: [iso(ayer)],
            hora: '07:30',
          ),
        ],
      ),
    ];

    final dia = resumen(lista, ayer);

    expect(dia.dadas.map((item) => item.titulo), ['Marcada']);
    expect(dia.pendientes, isEmpty);
    expect(dia.total, 1);
    expect(marcadores(lista, ayer), ['diario']);
  });

  test('mañana dentro del rango queda programada', () {
    final dia = resumen([
      perro(tratamientos: [diario(hora: '21:00')]),
    ], manana);

    expect(dia.programadas, hasLength(1));
    expect(dia.programadas.single.hora, '21:00');
    expect(dia.dadas, isEmpty);
    expect(dia.pendientes, isEmpty);
  });

  test('un diario pausado solo muestra las dosis dadas', () {
    final pausado = diario(activo: false, dosis: [iso(ayer)], hora: '10:00');
    final lista = [
      perro(tratamientos: [pausado]),
    ];

    final diaDada = resumen(lista, ayer);
    final diaSinMarca = resumen(lista, DateTime(2026, 6, 13));
    final hoyPausado = resumen(lista, hoy);

    expect(diaDada.dadas, hasLength(1));
    expect(diaSinMarca.dadas, isEmpty);
    expect(diaSinMarca.total, 0);
    expect(hoyPausado.pendientes, isEmpty);
    expect(hoyPausado.dadas, isEmpty);
  });

  test(
    'un diario fuera de rango no entra en pendientes ni programadas',
    () {
      final tratamiento = diario(inicio: DateTime(2026, 6, 10), dias: 5);
      final lista = [
        perro(tratamientos: [tratamiento]),
      ];

      final antes = resumen(lista, DateTime(2026, 6, 9));
      final despues = resumen(lista, DateTime(2026, 6, 15));

      expect(antes.total, 0);
      expect(despues.total, 0);
      expect(marcadores(lista, DateTime(2026, 6, 9)), isEmpty);
      expect(marcadores(lista, DateTime(2026, 6, 15)), isEmpty);
    },
  );

  test('un indefinido corresponde desde el inicio y no antes', () {
    final tratamiento = diario(
      dias: 0,
      inicio: DateTime(2026, 6, 15),
      medicacion: 'Crónico',
    );
    final lista = [
      perro(tratamientos: [tratamiento]),
    ];

    expect(resumen(lista, DateTime(2026, 6, 14)).total, 0);
    expect(resumen(lista, hoy).pendientes.single.titulo, 'Crónico');
  });

  test('un evento puntual aparece solo el día de su registro', () {
    final lista = [
      perro(
        tratamientos: [
          evento(
            id: 'vet',
            categoria: 'veterinaria',
            medicacion: 'Consulta',
            dia: hoy,
          ),
          evento(
            id: 'bano',
            categoria: 'higiene',
            medicacion: 'Baño',
            dia: manana,
            indicaciones: 'Corte',
          ),
        ],
      ),
    ];

    final diaHoy = resumen(lista, hoy);
    final diaManana = resumen(lista, manana);

    expect(diaHoy.eventos.map((item) => item.categoria), ['veterinaria']);
    expect(diaHoy.eventos.single.titulo, 'Consulta');
    expect(diaHoy.dadas, isEmpty);
    expect(diaManana.eventos.map((item) => item.titulo), ['Baño']);
    expect(diaManana.eventos.single.detalle, 'Corte');
  });

  test('un recordatorio aparece en su día, también si ya venció', () {
    final lista = [
      perro(
        recordatorios: [
          recordatorio(
            id: 'hoy',
            titulo: 'Hoy',
            fechaHora: DateTime(2026, 6, 15, 18, 5),
          ),
          recordatorio(
            id: 'ayer',
            titulo: 'Ayer',
            fechaHora: DateTime(2026, 6, 14, 8, 0),
            tipo: 'higiene',
          ),
        ],
      ),
    ];

    final diaHoy = resumen(lista, hoy);
    final diaAyer = resumen(lista, ayer);

    expect(diaHoy.recordatorios.single.titulo, 'Hoy');
    expect(diaHoy.recordatorios.single.hora, '18:05');
    expect(diaHoy.recordatorios.single.esRecordatorio, isTrue);
    expect(diaHoy.recordatorios.single.categoria, 'veterinaria');
    expect(diaAyer.recordatorios.single.titulo, 'Ayer');
    expect(diaAyer.recordatorios.single.categoria, 'higiene');
    expect(resumen(lista, manana).recordatorios, isEmpty);
  });

  test('un egresado no aparece y un fallecido conserva las dosis dadas', () {
    final tratamiento = diario(dosis: [iso(hoy)]);
    final lista = [
      perro(id: 'activo', nombre: 'Luna', tratamientos: [tratamiento]),
      perro(
        id: 'difunto',
        nombre: 'Sol',
        estado: 'inactivo',
        tratamientos: [tratamiento],
      ),
      perro(
        id: 'egresado',
        nombre: 'Nube',
        estado: 'egresado',
        tratamientos: [tratamiento],
      ),
    ];

    final dia = resumen(lista, hoy);

    expect(dia.dadas.map((item) => item.perro.nombre), ['Luna', 'Sol']);
  });

  test('un fallecido muestra eventos médicos y no recordatorios ni dosis futuras', () {
    final sol = perro(
      id: 'sol',
      nombre: 'Sol',
      estado: 'inactivo',
      tratamientos: [
        diario(id: 'dada', medicacion: 'Dada', dosis: [iso(hoy)]),
        diario(id: 'futura', medicacion: 'Futura'),
        evento(categoria: 'veterinaria', medicacion: 'Control', dia: hoy, id: 'vet'),
      ],
      recordatorios: [
        recordatorio(fechaHora: DateTime(2026, 6, 15, 18, 0), id: 'hoy'),
      ],
    );

    final dia = resumen([sol], hoy);
    final futuro = resumen([sol], manana);

    expect(dia.dadas.map((item) => item.titulo), ['Dada']);
    expect(dia.eventos.map((item) => item.titulo), ['Control']);
    expect(dia.pendientes, isEmpty);
    expect(dia.recordatorios, isEmpty);
    expect(futuro.programadas, isEmpty);
    expect(futuro.dadas, isEmpty);
  });

  test('el filtro por idPerro restringe el resumen y los marcadores', () {
    final lista = [
      perro(
        id: 'luna',
        nombre: 'Luna',
        tratamientos: [diario(id: 'a', medicacion: 'De Luna')],
      ),
      perro(
        id: 'sol',
        nombre: 'Sol',
        tratamientos: [diario(id: 'b', medicacion: 'De Sol')],
      ),
    ];

    final filtrado = resumen(lista, hoy, idPerro: 'sol');

    expect(filtrado.pendientes.map((item) => item.titulo), ['De Sol']);
    expect(marcadores(lista, hoy, idPerro: 'sol'), ['pendiente']);
    expect(marcadores(lista, hoy, idPerro: 'nadie'), isEmpty);
  });

  test(
    'dentro de cada lista ordena por hora y deja las horas nulas al final',
    () {
      final lista = [
        perro(
          id: 'zoe',
          nombre: 'Zoe',
          tratamientos: [diario(id: 'z', medicacion: 'Zoe', hora: null)],
        ),
        perro(
          id: 'mora',
          nombre: 'Mora',
          tratamientos: [diario(id: 'm', medicacion: 'Mora', hora: '18:00')],
        ),
        perro(
          id: 'bruno',
          nombre: 'Bruno',
          tratamientos: [diario(id: 'b', medicacion: 'Bruno', hora: '08:00')],
        ),
        perro(
          id: 'ana',
          nombre: 'Ana',
          tratamientos: [diario(id: 'a', medicacion: 'Ana', hora: '08:00')],
        ),
      ];

      final nombres = resumen(
        lista,
        hoy,
      ).pendientes.map((item) => item.perro.nombre);

      expect(nombres, ['Ana', 'Bruno', 'Mora', 'Zoe']);
    },
  );

  test('los marcadores respetan prioridad, no se repiten y cortan en 5', () {
    final lista = [
      perro(
        tratamientos: [
          diario(id: 'olvido-1', medicacion: 'Olvido 1'),
          diario(id: 'olvido-2', medicacion: 'Olvido 2'),
          diario(
            id: 'dada',
            medicacion: 'Dada',
            dosis: [iso(ayer)],
            hora: '09:00',
          ),
          evento(
            id: 'vet',
            categoria: 'veterinaria',
            medicacion: 'Vet',
            dia: ayer,
          ),
          evento(
            id: 'evt',
            categoria: 'evento',
            medicacion: 'Evento',
            dia: ayer,
          ),
          evento(
            id: 'hig',
            categoria: 'higiene',
            medicacion: 'Baño',
            dia: ayer,
          ),
          evento(id: 'uni', categoria: 'unico', medicacion: 'Única', dia: ayer),
        ],
        recordatorios: [recordatorio(fechaHora: DateTime(2026, 6, 14, 11, 0))],
      ),
    ];

    expect(marcadores(lista, ayer), [
      'diario',
      'unico',
      'higiene',
      'evento',
      'veterinaria',
    ]);
    expect(marcadores(lista, ayer), isNot(contains('olvidada')));
    expect(marcadores(lista, hoy), ['pendiente']);
  });

  test('los colores de marcador siguen la paleta pedida', () {
    expect(
      CalendarioGeneralController.colorMarcador('ingreso'),
      AppColors.terracota,
    );
    expect(
      CalendarioGeneralController.colorMarcador('deceso'),
      AppColors.textoSecundario,
    );
    expect(
      CalendarioGeneralController.colorMarcador('pendiente'),
      AppColors.pendiente,
    );
    expect(
      CalendarioGeneralController.colorMarcador('diario'),
      CategoryColors.diario,
    );
    expect(
      CalendarioGeneralController.colorMarcador('unico'),
      CategoryColors.unico,
    );
    expect(
      CalendarioGeneralController.colorMarcador('higiene'),
      CategoryColors.higiene,
    );
    expect(
      CalendarioGeneralController.colorMarcador('evento'),
      CategoryColors.evento,
    );
    expect(
      CalendarioGeneralController.colorMarcador('veterinaria'),
      CategoryColors.veterinaria,
    );
    expect(
      CalendarioGeneralController.colorMarcador('recordatorio'),
      AppColors.navy,
    );
  });

  test('un día sin nada deja todas las listas vacías', () {
    final dia = resumen([perro()], DateTime(2026, 1, 2));

    expect(dia.dadas, isEmpty);
    expect(dia.pendientes, isEmpty);
    expect(dia.programadas, isEmpty);
    expect(dia.hitos, isEmpty);
    expect(dia.eventos, isEmpty);
    expect(dia.recordatorios, isEmpty);
    expect(dia.total, 0);
    expect(marcadores([perro()], DateTime(2026, 1, 2)), isEmpty);
  });

  test('el ingreso y el deceso aparecen aunque el perro no esté activo', () {
    final pampa = perro(
      id: 'pampa',
      nombre: 'Pampa',
      fechaIngreso: DateTime(2026, 6, 15, 18, 30),
    );
    final zanca = perro(
      id: 'zanca',
      nombre: 'Zanca',
      estado: 'inactivo',
      fechaFallecimiento: ayer,
      tratamientos: [diario(medicacion: 'No debe verse')],
    );

    final diaIngreso = resumen([pampa, zanca], hoy);
    expect(diaIngreso.hitos.map((item) => item.titulo), ['Ingreso de Pampa']);
    expect(marcadores([pampa], hoy), ['ingreso']);

    final diaDeceso = resumen([pampa, zanca], ayer);
    expect(diaDeceso.hitos.map((item) => item.titulo), ['Falleció Zanca']);
    expect(diaDeceso.dadas, isEmpty);
    expect(diaDeceso.pendientes, isEmpty);
    expect(diaDeceso.programadas, isEmpty);
    expect(marcadores([zanca], ayer), ['deceso']);

    final filtrado = resumen([pampa, zanca], hoy, idPerro: 'zanca');
    expect(filtrado.hitos, isEmpty);
  });

  test('pasar a difuntos pausa los diarios activos y cancela recordatorios pendientes', () {
    final ahora = DateTime(2026, 6, 15, 12);
    final diarioActivo = diario(id: 'activo', medicacion: 'Pastilla');
    final diarioPausado = diario(id: 'pausado', activo: false);
    final visita = evento(
      categoria: 'veterinaria',
      medicacion: 'Control',
      dia: DateTime(2026, 6, 10),
      id: 'vet',
    );

    final tratamientos = TratamientoController.pausarDiariosActivos([
      diarioActivo,
      diarioPausado,
      visita,
    ]);
    expect(tratamientos[0].activo, isFalse);
    expect(tratamientos[1].activo, isFalse);
    expect(tratamientos[2].activo, isTrue);
    expect(tratamientos[2].medicacion, 'Control');

    final vencido = recordatorio(id: 'viejo', fechaHora: DateTime(2026, 6, 14, 9));
    final pendiente = recordatorio(id: 'nuevo', fechaHora: DateTime(2026, 6, 16, 9));
    final restantes = RecordatorioController.cancelarPendientes(
      [vencido, pendiente],
      ahora: ahora,
    );
    expect(restantes.map((item) => item.id), ['viejo']);
  });
}
