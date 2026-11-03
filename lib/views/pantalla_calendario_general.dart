import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../controllers/calendario_general_controller.dart';
import '../controllers/tratamiento_controller.dart';
import '../models/dosis_avisada.dart';
import '../models/perro_model.dart';
import '../models/tratamiento_model.dart';
import '../providers/auth_providers.dart';
import '../providers/calendario_providers.dart';
import '../providers/firestore_providers.dart';
import '../providers/guardado_provider.dart';
import '../providers/perros_providers.dart';
import '../theme/app_colors.dart';
import '../theme/category_colors.dart';
import '../utils/plataforma.dart';
import '../theme/entrada_escalonada.dart';
import '../theme/recordatorio_tipos.dart';
import '../theme/seguimiento_tipos.dart';
import 'alta_calendario.dart';
import 'ficha_detalle_perro.dart';

class PantallaCalendarioGeneral extends ConsumerStatefulWidget {
  const PantallaCalendarioGeneral({super.key});

  @override
  ConsumerState<PantallaCalendarioGeneral> createState() =>
      _PantallaCalendarioGeneralState();
}

class _PantallaCalendarioGeneralState extends ConsumerState<PantallaCalendarioGeneral> {
  final TextEditingController _busqueda = TextEditingController();
  final ScrollController _scrollCalendario = ScrollController();
  final ScrollController _scrollResumen = ScrollController();

  @override
  void initState() {
    super.initState();
    _busqueda.addListener(() {
      if (!mounted) return;
      ref.read(filtrosCalendarioProvider.notifier).buscar(_busqueda.text);
    });
  }

  DateTime _soloFecha(DateTime fecha) =>
      DateTime(fecha.year, fecha.month, fecha.day);

  @override
  void dispose() {
    _busqueda.dispose();
    _scrollCalendario.dispose();
    _scrollResumen.dispose();
    super.dispose();
  }

  void _irAHoy() => ref.read(filtrosCalendarioProvider.notifier).irAHoy();

  String _capitalizar(String texto) {
    final limpio = texto.trim();
    if (limpio.isEmpty) return limpio;
    return limpio[0].toUpperCase() + limpio.substring(1);
  }

  Future<void> _marcarDada(ItemResumen item) async {
    final id = item.tratamientoId;
    if (id == null) return;
    TratamientoModel? tratamiento;
    for (final actual in item.perro.tratamientos) {
      if (actual.id == id) {
        tratamiento = actual;
        break;
      }
    }
    if (tratamiento == null) return;
    final dia = ref.read(filtrosCalendarioProvider).diaSeleccionado;
    final tratamientos = ref.read(tratamientoControllerProvider);
    final resultado = await ref.read(guardadoProvider(claveGuardadoCalendario).notifier).ejecutar(
      () async {
        await tratamientos.toggleDosis(item.perro.id, tratamiento!, dia);
      },
    );
    if (!mounted || resultado != ResultadoGuardado.error) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No se pudo marcar la dosis')),
    );
  }

  String _plural(int n, String singular, String plural) {
    return n == 1 ? '1 $singular' : '$n $plural';
  }

  @override
  Widget build(BuildContext context) {
    final asyncPerros = ref.watch(perrosProvider);
    final filtros = ref.watch(filtrosCalendarioProvider);
    final locale = ref.watch(localeCalendarioProvider);
    final activosAsync = ref.watch(perrosActivosCalendarioProvider);
    final resumen = ref.watch(resumenDiaProvider).asData?.value;
    final entradas = ref.watch(listaCalendarioProvider).asData?.value.entradas ?? const <EntradaListaGeneral>[];
    final seguimientos = ref.watch(seguimientosActivosProvider).asData?.value ?? const <ItemResumen>[];
    final esInvitado = ref.watch(sessionProvider).esInvitado;
    ref.watch(guardadoProvider(claveGuardadoCalendario));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendario general'),
        actions: [
          TextButton(
            onPressed: _irAHoy,
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).appBarTheme.foregroundColor),
            child: const Text('Hoy'),
          ),
        ],
      ),
      body: SafeArea(
        child: () {
            if (asyncPerros.hasError && !asyncPerros.hasValue) {
              return _estadoMensaje(
                'No se pudo cargar el calendario.',
                icono: Icons.cloud_off_outlined,
              );
            }
            if (!asyncPerros.hasValue) {
              return const Center(child: CircularProgressIndicator());
            }
            final perros = asyncPerros.value!;
            if (perros.isEmpty) {
              return _estadoMensaje('No hay perritos registrados aún.');
            }
            final activos = activosAsync.asData?.value ?? const <PerroModel>[];
            final filtro = idPerroEnActivos(activos, filtros.idPerro);
            return LayoutBuilder(
              builder: (context, constraints) {
                final ancho = constraints.maxWidth >= 900;
                return SizedBox(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  child: () {
                      if (locale.isLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final filtroPerro = _filtroPerro(activos, filtro);
                      final esLista = filtros.vista == VistaCalendario.lista;
                      if (!ancho) {
                        return ListView(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          children: [
                            filtroPerro,
                            const SizedBox(height: 12),
                            _selectorFormato(filtros),
                            const SizedBox(height: 12),
                            _botonesAlta(activos, filtros, esInvitado),
                            const SizedBox(height: 12),
                            if (esLista)
                              _panelLista(entradas, filtros, seguimientos)
                            else ...[
                              _calendario(perros, filtro, filtros, altoCelda: 52),
                              const SizedBox(height: 12),
                              _leyenda(perros, filtro, filtros),
                              const SizedBox(height: 20),
                              _resumen(resumen ?? const ResumenDia(), filtros, seguimientos, esInvitado),
                            ],
                          ],
                        );
                      }
                      if (esLista) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _conScroll(
                            _scrollCalendario,
                            Align(
                              alignment: Alignment.topCenter,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 720),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    filtroPerro,
                                    const SizedBox(height: 12),
                                    _selectorFormato(filtros),
                                    const SizedBox(height: 12),
                                    _botonesAlta(activos, filtros, esInvitado),
                                    const SizedBox(height: 12),
                                    _panelLista(entradas, filtros, seguimientos),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: 5,
                              child: LayoutBuilder(
                                builder: (context, caja) {
                                  final anchoColumna = caja.maxWidth > 760 ? 760.0 : caja.maxWidth;
                                  final altoCelda = (anchoColumna / 7).clamp(48.0, 72.0);
                                  return Align(
                                    alignment: Alignment.topLeft,
                                    child: SizedBox(
                                      width: anchoColumna,
                                      height: caja.maxHeight,
                                      child: _conScroll(
                                        _scrollCalendario,
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            filtroPerro,
                                            const SizedBox(height: 12),
                                            _selectorFormato(filtros),
                                            const SizedBox(height: 12),
                                            _botonesAlta(activos, filtros, esInvitado),
                                            const SizedBox(height: 12),
                                            _calendario(perros, filtro, filtros, altoCelda: altoCelda),
                                            const SizedBox(height: 12),
                                            _leyenda(perros, filtro, filtros),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              flex: 6,
                              child: _conScroll(
                                _scrollResumen,
                                Align(
                                  alignment: Alignment.topLeft,
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 880),
                                    child: _resumen(resumen ?? const ResumenDia(), filtros, seguimientos, esInvitado),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                  }(),
                );
              },
            );
          }(),
      ),
    );
  }

  static const _ordenTipos = [
    'diario',
    'unico',
    'vacuna',
    'higiene',
    'evento',
    'veterinaria',
    'recordatorio',
    'ingreso',
    'deceso',
  ];

  static const _etiquetasTipo = {
    'diario': 'Tratamiento diario',
    'unico': 'Dosis única',
    'vacuna': 'Vacuna',
    'higiene': 'Higiene',
    'evento': 'Evento',
    'veterinaria': 'Veterinaria',
    'recordatorio': 'Recordatorio',
    'ingreso': 'Ingreso',
    'deceso': 'Fallecimiento',
  };

  Widget _panelLista(List<EntradaListaGeneral> todas, FiltrosCalendario filtros, List<ItemResumen> seguimientos) {
    final consulta = filtros.busqueda.trim().toLowerCase();
    final filtradas = [
      for (final entrada in todas)
        if (filtros.tipo == null || entrada.categoria == filtros.tipo)
          if (consulta.isEmpty || _coincideLista(entrada, consulta)) entrada,
    ];
    final categorias = [
      for (final categoria in _ordenTipos)
        if (todas.any((entrada) => entrada.categoria == categoria)) categoria,
    ];
    final textTheme = Theme.of(context).textTheme;
    final estiloVacio = textTheme.bodyMedium?.copyWith(color: context.paleta.textoSuave);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _seguimientosActivos(seguimientos),
        TextField(
          controller: _busqueda,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Buscar perro, medicación o nota',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        if (categorias.length > 1) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Todas'),
                selected: filtros.tipo == null,
                onSelected: (seleccionado) {
                  if (!seleccionado) return;
                  ref.read(filtrosCalendarioProvider.notifier).filtrarTipo(null);
                },
              ),
              for (final categoria in categorias)
                ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: CalendarioGeneralController.colorMarcador(categoria),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(_etiquetasTipo[categoria] ?? categoria),
                    ],
                  ),
                  selected: filtros.tipo == categoria,
                  onSelected: (seleccionado) {
                    ref.read(filtrosCalendarioProvider.notifier).filtrarTipo(seleccionado ? categoria : null);
                  },
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        if (todas.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text('No hay registros en este período.', style: estiloVacio),
          )
        else if (filtradas.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text('Ningún registro coincide.', style: estiloVacio),
          )
        else
          for (final grupo in _agruparLista(filtradas)) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 4),
              child: Text(grupo.$1, style: textTheme.titleMedium),
            ),
            for (final entrada in grupo.$2) _filaLista(entrada),
          ],
      ],
    );
  }

  bool _coincideLista(EntradaListaGeneral entrada, String consulta) {
    return entrada.perro.nombre.toLowerCase().contains(consulta) ||
        entrada.titulo.toLowerCase().contains(consulta) ||
        entrada.detalle.toLowerCase().contains(consulta);
  }

  List<(String, List<EntradaListaGeneral>)> _agruparLista(List<EntradaListaGeneral> entradas) {
    final grupos = <String, List<EntradaListaGeneral>>{};
    final orden = <String>[];
    for (final entrada in entradas) {
      final clave = _tituloMes(entrada.fecha);
      if (!grupos.containsKey(clave)) orden.add(clave);
      grupos.putIfAbsent(clave, () => []).add(entrada);
    }
    return [
      for (final clave in orden) (clave, grupos[clave]!),
    ];
  }

  String _tituloMes(DateTime fecha) {
    final texto = DateFormat('MMMM y', 'es_ES').format(fecha);
    if (texto.isEmpty) return texto;
    return texto[0].toUpperCase() + texto.substring(1);
  }

  String _fechaCorta(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    return '$dia/$mes/${fecha.year}';
  }

  String _resumenLista(EntradaListaGeneral entrada) {
    final nombre = entrada.perro.nombre.trim().isEmpty ? 'Sin nombre' : entrada.perro.nombre.trim();
    final fin = _fechaCorta(entrada.fecha);
    final desde = entrada.desde;
    final mismoDia = desde != null &&
        desde.year == entrada.fecha.year &&
        desde.month == entrada.fecha.month &&
        desde.day == entrada.fecha.day;
    final rango = desde == null || mismoDia ? fin : '${_fechaCorta(desde)} – $fin';
    if (entrada.categoria != 'diario' || !entrada.cuentaDosis) return '$nombre · $rango';
    if (entrada.cantidadDosis <= 0) return '$nombre · $rango · sin dosis registradas';
    final dosis = entrada.cantidadDosis == 1 ? '1 dosis' : '${entrada.cantidadDosis} dosis';
    return '$nombre · $rango · $dosis';
  }

  (IconData, Color) _iconoLista(EntradaListaGeneral entrada) {
    if (entrada.categoria == 'ingreso') {
      return (Icons.login_rounded, AppColors.terracota);
    }
    if (entrada.categoria == 'deceso') {
      return (Icons.local_florist, context.paleta.textoSuave);
    }
    if (entrada.categoria == 'recordatorio') {
      final tipo = RecordatorioTipos.de(entrada.tipoRecordatorio ?? '');
      return (tipo.icono, tipo.color);
    }
    return (CategoryColors.icono(entrada.categoria), CategoryColors.base(entrada.categoria));
  }

  Widget _filaLista(EntradaListaGeneral entrada) {
    final textTheme = Theme.of(context).textTheme;
    final visual = _iconoLista(entrada);
    final detalle = entrada.detalle.trim();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => ref.read(filtrosCalendarioProvider.notifier).seleccionarDia(
          entrada.fecha,
          vista: VistaCalendario.mes,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: visual.$2.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(visual.$1, size: 20, color: visual.$2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _capitalizar(entrada.titulo),
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _resumenLista(entrada),
                      style: textTheme.bodyMedium?.copyWith(color: context.paleta.textoSuave),
                    ),
                    if (detalle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        detalle,
                        style: textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _estadoMensaje(String texto, {IconData icono = Icons.pets}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.navy.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icono, size: 30, color: context.paleta.lienzo),
            ),
            const SizedBox(height: 12),
            Text(
              texto,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: context.paleta.lienzoSuave,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _conScroll(ScrollController controlador, Widget child) {
    return Scrollbar(
      controller: controlador,
      child: SingleChildScrollView(
        controller: controlador,
        padding: const EdgeInsets.only(top: 12, bottom: 24),
        child: child,
      ),
    );
  }

  Widget _botonesAlta(List<PerroModel> activos, FiltrosCalendario filtros, bool esInvitado) {
    if (esInvitado) return const SizedBox.shrink();
    final hayPerros = activos.isNotEmpty;
    return Material(
      color: context.paleta.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: context.paleta.borde),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _celdaAlta(
                icono: Icons.medical_services_outlined,
                texto: 'Agregar registro',
                habilitado: hayPerros,
                alTocar: () => abrirAltaRegistroCalendario(
                  context,
                  activos: activos,
                  idPreseleccionado: filtros.idPerro,
                  fecha: filtros.diaSeleccionado,
                  tratamientos: ref.read(tratamientoControllerProvider),
                  perros: ref.read(perroControllerProvider),
                ),
              ),
            ),
            VerticalDivider(width: 1, thickness: 1, color: context.paleta.borde),
            Expanded(
              child: _celdaAlta(
                icono: Icons.alarm_add,
                texto: 'Agregar recordatorio',
                habilitado: hayPerros,
                alTocar: () => abrirAltaRecordatorioCalendario(
                  context,
                  activos: activos,
                  idPreseleccionado: filtros.idPerro,
                  fecha: filtros.diaSeleccionado,
                  recordatorios: ref.read(recordatorioControllerProvider),
                  perros: ref.read(perroControllerProvider),
                ),
              ),
            ),
            VerticalDivider(width: 1, thickness: 1, color: context.paleta.borde),
            Expanded(
              child: _celdaAlta(
                icono: Icons.visibility_outlined,
                texto: 'Agregar seguimiento',
                habilitado: hayPerros,
                alTocar: () => abrirAltaSeguimientoCalendario(
                  context,
                  activos: activos,
                  idPreseleccionado: filtros.idPerro,
                  fecha: filtros.diaSeleccionado,
                  seguimientos: ref.read(seguimientoControllerProvider),
                  perros: ref.read(perroControllerProvider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _celdaAlta({
    required IconData icono,
    required String texto,
    required bool habilitado,
    required VoidCallback alTocar,
  }) {
    final color = habilitado ? context.paleta.lienzo : context.paleta.textoSuave;
    return InkWell(
      onTap: habilitado ? alTocar : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, size: 20, color: color),
            const SizedBox(height: 4),
            Text(
              texto,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _selectorFormato(FiltrosCalendario filtros) {
    return SegmentedButton<VistaCalendario>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(value: VistaCalendario.mes, label: Text('Mes'), icon: Icon(Icons.calendar_month_outlined)),
        ButtonSegment(value: VistaCalendario.lista, label: Text('Resumen'), icon: Icon(Icons.view_list_outlined)),
      ],
      selected: {filtros.vista},
      onSelectionChanged: (seleccion) => ref.read(filtrosCalendarioProvider.notifier).cambiarVista(seleccion.first),
    );
  }

  Widget _filtroPerro(List<PerroModel> activos, String? filtro) {
    return DropdownButtonFormField<String?>(
      initialValue: filtro,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Filtrar por perro'),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('Todos los perros'),
        ),
        for (final perro in activos)
          DropdownMenuItem<String?>(
            value: perro.id,
            child: Text(
              perro.nombre.isEmpty ? 'Sin nombre' : perro.nombre,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (id) => ref.read(filtrosCalendarioProvider.notifier).filtrarPerro(id),
    );
  }

  Widget _calendario(
    List<PerroModel> perros,
    String? filtro,
    FiltrosCalendario filtros, {
    required double altoCelda,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
        child: TableCalendar<void>(
      rowHeight: altoCelda,
      locale: 'es_ES',
      firstDay: filtros.primerDia,
      lastDay: filtros.ultimoDia,
      focusedDay: filtros.diaEnfocado,
      currentDay: filtros.hoy,
      calendarFormat: CalendarFormat.month,
      startingDayOfWeek: StartingDayOfWeek.monday,
      availableCalendarFormats: const {
        CalendarFormat.month: 'Mes',
      },
      availableGestures: AvailableGestures.horizontalSwipe,
      selectedDayPredicate: (dia) => isSameDay(dia, filtros.diaSeleccionado),
      headerStyle: HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        titleTextStyle: textTheme.titleMedium ?? const TextStyle(),
        leftChevronIcon: const Icon(Icons.chevron_left, color: AppColors.navy),
        rightChevronIcon: const Icon(
          Icons.chevron_right,
          color: AppColors.navy,
        ),
      ),
      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle:
            textTheme.labelMedium?.copyWith(color: context.paleta.textoSuave) ??
            const TextStyle(),
        weekendStyle:
            textTheme.labelMedium?.copyWith(color: context.paleta.textoSuave) ??
            const TextStyle(),
      ),
      calendarStyle: const CalendarStyle(
        selectedDecoration: BoxDecoration(
          color: AppColors.navy,
          shape: BoxShape.circle,
        ),
        selectedTextStyle: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        todayDecoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.fromBorderSide(
            BorderSide(color: AppColors.navy, width: 1.6),
          ),
        ),
        todayTextStyle: TextStyle(
          color: AppColors.navy,
          fontWeight: FontWeight.w700,
        ),
      ),
      calendarBuilders: CalendarBuilders(
        headerTitleBuilder: (context, dia) {
          final titulo = DateFormat.yMMMM('es_ES').format(dia);
          return FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              titulo,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: textTheme.titleMedium,
            ),
          );
        },
        markerBuilder: (context, date, events) {
          final claves = CalendarioGeneralController.marcadoresDelDia(
            perros,
            date,
            hoy: filtros.hoy,
            idPerro: filtro,
          );
          if (claves.isEmpty) return null;
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final clave in claves)
                Container(
                  width: esWindows ? 9 : 6,
                  height: esWindows ? 9 : 6,
                  margin: EdgeInsets.symmetric(horizontal: esWindows ? 1.5 : 1),
                  decoration: BoxDecoration(
                    color: CalendarioGeneralController.colorMarcador(clave),
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          );
        },
      ),
      onDaySelected: (seleccionado, enfocado) {
        ref.read(filtrosCalendarioProvider.notifier).seleccionarDia(seleccionado, enfocado: enfocado);
      },
      onPageChanged: (enfocado) => ref.read(filtrosCalendarioProvider.notifier).enfocar(enfocado),
      onFormatChanged: (_) {},
        ),
      ),
    );
  }

  Widget _leyenda(List<PerroModel> perros, String? filtro, FiltrosCalendario filtros) {
    final claves = CalendarioGeneralController.clavesEnMes(
      perros,
      filtros.diaEnfocado,
      hoy: filtros.hoy,
      idPerro: filtro,
    );
    if (claves.isEmpty) return const SizedBox.shrink();
    const etiquetas = {
      'diario': 'Dosis dada',
      'pendiente': 'Pendiente',
      'unico': 'Dosis única',
      'vacuna': 'Vacuna',
      'higiene': 'Higiene',
      'evento': 'Evento',
      'veterinaria': 'Veterinaria',
      'ingreso': 'Ingreso',
      'deceso': 'Fallecimiento',
      'recordatorio': 'Recordatorio',
    };
    final estilo = Theme.of(context).textTheme.labelMedium?.copyWith(color: context.paleta.texto);
    Widget punto(Color color, String etiqueta) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(etiqueta, style: estilo),
        ],
      );
    }

    return Card(
      child: ExpansionTile(
        initiallyExpanded: claves.length <= 4,
        title: Text('Leyenda', style: Theme.of(context).textTheme.titleMedium),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                for (final clave in claves)
                  if (etiquetas[clave] != null)
                    punto(CalendarioGeneralController.colorMarcador(clave), etiquetas[clave]!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _resumen(ResumenDia resumen, FiltrosCalendario filtros, List<ItemResumen> seguimientos, bool esInvitado) {
    final textTheme = Theme.of(context).textTheme;
    final dia = _soloFecha(filtros.diaSeleccionado);
    final fecha = DateFormat("EEEE d 'de' MMMM", 'es_ES').format(dia);
    final fechaLegible = fecha.isEmpty
        ? fecha
        : '${fecha[0].toUpperCase()}${fecha.substring(1)}';
    final comparacion = dia.compareTo(filtros.hoy);
    final secciones = <Widget>[];

    if (comparacion == 0) {
      secciones.add(
        _seccion(
          'Pendientes de hoy',
          Icons.pending_outlined,
          resumen.pendientes,
          permitirMarcar: !esInvitado,
        ),
      );
      secciones.add(
        _seccion('Dosis dadas', Icons.check_circle_outline, resumen.dadas),
      );
    } else if (comparacion < 0) {
      secciones.add(
        _seccion('Dosis dadas', Icons.check_circle_outline, resumen.dadas),
      );
    } else {
      secciones.add(
        _seccion('Programadas', Icons.event_outlined, resumen.programadas),
      );
    }
    secciones.add(
      _seccion(
        'Eventos especiales',
        Icons.pets_rounded,
        resumen.hitos,
      ),
    );
    secciones.add(
      _seccion(
        'Eventos y visitas',
        Icons.medical_services_outlined,
        resumen.eventos,
      ),
    );
    secciones.add(
      _seccion('Recordatorios', Icons.alarm_rounded, resumen.recordatorios),
    );
    final visibles = secciones.whereType<_SeccionVisible>().toList();

    final conteos = <String>[
      if (comparacion <= 0 && resumen.dadas.isNotEmpty)
        _plural(resumen.dadas.length, 'dosis dada', 'dosis dadas'),
      if (resumen.pendientes.isNotEmpty)
        _plural(resumen.pendientes.length, 'pendiente', 'pendientes'),
      if (resumen.programadas.isNotEmpty)
        _plural(resumen.programadas.length, 'programada', 'programadas'),
      if (resumen.hitos.isNotEmpty) _textoHitos(resumen.hitos),
      if (resumen.eventos.isNotEmpty)
        _plural(resumen.eventos.length, 'evento', 'eventos'),
      if (resumen.recordatorios.isNotEmpty)
        _plural(resumen.recordatorios.length, 'recordatorio', 'recordatorios'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _seguimientosActivos(seguimientos),
        Text('Resumen del día', style: textTheme.titleLarge?.copyWith(color: context.paleta.lienzo)),
        const SizedBox(height: 4),
        Text(
          fechaLegible,
          style: textTheme.titleMedium?.copyWith(color: context.paleta.lienzo),
        ),
        if (visibles.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                Icon(
                  Icons.event_available_outlined,
                  size: 32,
                  color: context.paleta.textoSuave,
                ),
                const SizedBox(height: 8),
                Text(
                  'No hay registros ni pendientes para este día',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: context.paleta.textoSuave,
                  ),
                ),
              ],
            ),
          )
        else ...[
          if (conteos.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final conteo in conteos) _chipConteo(conteo)],
            ),
          ],
          for (final seccion in visibles) seccion,
        ],
      ],
    );
  }

  String _textoHitos(List<ItemResumen> hitos) {
    final ingresos = hitos.where((item) => item.categoria == 'ingreso').length;
    final decesos = hitos.where((item) => item.categoria == 'deceso').length;
    final partes = <String>[
      if (ingresos > 0) _plural(ingresos, 'ingreso', 'ingresos'),
      if (decesos > 0) _plural(decesos, 'fallecimiento', 'fallecimientos'),
    ];
    return partes.join(' · ');
  }

  Widget _chipConteo(String texto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.paleta.relleno,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: context.paleta.borde),
      ),
      child: Text(texto, style: Theme.of(context).textTheme.labelMedium),
    );
  }

  Widget _seguimientosActivos(List<ItemResumen> items) {
    return _seccion('Seguimientos activos', Icons.visibility_outlined, items);
  }

  Widget _seccion(
    String titulo,
    IconData icono,
    List<ItemResumen> items, {
    Color? tinte,
    bool permitirMarcar = false,
  }) {
    if (items.isEmpty) return const _SeccionOculta();
    final textTheme = Theme.of(context).textTheme;
    final color = tinte ?? context.paleta.lienzo;
    return _SeccionVisible(
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icono, size: 20, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    titulo,
                    style: textTheme.titleMedium?.copyWith(color: tinte),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              clipBehavior: Clip.none,
              child: Column(
                children: [
                  for (var i = 0; i < items.length; i++)
                    EntradaEscalonada(
                      indice: i,
                      child: _filaResumen(items[i], permitirMarcar: permitirMarcar),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filaResumen(ItemResumen item, {bool permitirMarcar = false}) {
    final textTheme = Theme.of(context).textTheme;
    final nombre = item.perro.nombre.isEmpty ? 'Sin nombre' : item.perro.nombre;
    final detalle = item.detalle.trim();
    final subtitulo = detalle.isEmpty ? nombre : '$nombre · $detalle';
    final etiqueta = detalle.isEmpty
        ? '${item.titulo}, $nombre'
        : '${item.titulo}, $nombre, $detalle';
    final visual = _visualCategoria(item);

    return Semantics(
      button: true,
      label: etiqueta,
      child: ExcludeSemantics(
        child: Card(
          margin: const EdgeInsets.only(bottom: 8),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              final idTratamiento = item.tratamientoId;
              final dosis = permitirMarcar && idTratamiento != null
                  ? DosisAvisada(
                      idTratamiento: idTratamiento,
                      dia: TratamientoController.fechaIso(ref.read(filtrosCalendarioProvider).diaSeleccionado),
                    )
                  : null;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FichaDetallePerro(
                    idDocumento: item.perro.id,
                    dosisAvisada: dosis,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final angosta = constraints.maxWidth < 400;
                  final texto = angosta && item.hora != null ? '${item.hora} · $subtitulo' : subtitulo;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _avatar(item.perro),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _capitalizar(item.titulo),
                              style: textTheme.titleMedium,
                            ),
                            Text(
                              texto,
                              style: textTheme.bodyMedium?.copyWith(
                                color: context.paleta.textoSuave,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!angosta && item.hora != null) ...[
                        const SizedBox(width: 8),
                        Text(item.hora!, style: textTheme.labelMedium),
                      ],
                      if (permitirMarcar && item.tratamientoId != null) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: 'Marcar como dada',
                          onPressed: () => _marcarDada(item),
                          icon: const Icon(Icons.check_circle_outline),
                          color: context.paleta.activoTexto,
                        ),
                      ],
                      const SizedBox(width: 4),
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: visual.tinte,
                          shape: BoxShape.circle,
                          border: item.pendiente
                              ? Border.all(color: context.paleta.pausadoTexto, width: 1.4)
                              : null,
                        ),
                        child: Icon(visual.icono, size: 16, color: visual.color),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  _VisualCategoria _visualCategoria(ItemResumen item) {
    if (item.categoria == 'ingreso') {
      return _VisualCategoria(
        icono: Icons.login_rounded,
        color: AppColors.terracota,
        tinte: AppColors.terracota.withValues(alpha: 0.12),
      );
    }
    if (item.categoria == 'deceso') {
      return _VisualCategoria(
        icono: Icons.local_florist,
        color: context.paleta.textoSuave,
        tinte: context.paleta.textoSuave.withValues(alpha: 0.12),
      );
    }
    if (item.pendiente) {
      return _VisualCategoria(
        icono: Icons.hourglass_bottom_rounded,
        color: context.paleta.pausadoTexto,
        tinte: AppColors.pausado.withValues(alpha: 0.18),
      );
    }
    if (item.esRecordatorio) {
      final tipo = RecordatorioTipos.de(item.categoria);
      return _VisualCategoria(
        icono: tipo.icono,
        color: tipo.color,
        tinte: tipo.color.withValues(alpha: 0.12),
      );
    }
    if (item.esSeguimiento) {
      final tipo = SeguimientoTipos.de(item.categoria);
      return _VisualCategoria(
        icono: tipo.icono,
        color: tipo.color,
        tinte: tipo.color.withValues(alpha: 0.12),
      );
    }
    return _VisualCategoria(
      icono: CategoryColors.icono(item.categoria),
      color: CategoryColors.base(item.categoria),
      tinte: CategoryColors.tinte(item.categoria),
    );
  }

  Widget _avatar(PerroModel perro) {
    final foto = perro.fotoPerfil;
    if (foto == null || foto.isEmpty) return _avatarVacio();
    return ClipOval(
      child: Image.network(
        foto,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _avatarVacio(),
      ),
    );
  }

  Widget _avatarVacio() {
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        color: AppColors.navy,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.pets,
        size: 22,
        color: Colors.white.withValues(alpha: 0.4),
      ),
    );
  }
}

class _VisualCategoria {
  final IconData icono;
  final Color color;
  final Color tinte;

  const _VisualCategoria({
    required this.icono,
    required this.color,
    required this.tinte,
  });
}

class _SeccionVisible extends StatelessWidget {
  final Widget child;

  const _SeccionVisible({required this.child});

  @override
  Widget build(BuildContext context) => child;
}

class _SeccionOculta extends StatelessWidget {
  const _SeccionOculta();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
