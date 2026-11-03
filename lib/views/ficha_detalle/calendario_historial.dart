part of '../ficha_detalle_perro.dart';

enum _VistaHistorial { calendario, lista }

class CalendarioHistorialWidget extends StatefulWidget {
  final Map<DateTime, List<Map<String, dynamic>>> eventosCalendario;
  final List<EntradaHistorial> historial;
  final bool esInvitado;
  final Future<bool> Function(TratamientoModel tratamiento, DateTime dia) alAlternar;

  const CalendarioHistorialWidget({
    super.key,
    required this.eventosCalendario,
    required this.historial,
    required this.esInvitado,
    required this.alAlternar,
  });

  @override
  State<CalendarioHistorialWidget> createState() => _CalendarioHistorialWidgetState();
}

class _CalendarioHistorialWidgetState extends State<CalendarioHistorialWidget> {
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  _VistaHistorial _vista = _VistaHistorial.lista;
  final TextEditingController _busqueda = TextEditingController();
  final Map<String, Set<String>> _registros = {};

  @override
  void initState() {
    super.initState();
    for (final entrada in widget.historial) {
      if (entrada.categoria != 'diario' || entrada.origen.id.isEmpty) continue;
      _registros[entrada.origen.id] = entrada.origen.registroDosis.toSet();
    }
    _busqueda.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _eventosDelDia(DateTime dia) {
    return widget.eventosCalendario[DateTime.utc(dia.year, dia.month, dia.day)] ?? [];
  }

  Color obtenerColorCategoria(String? categoria) => CategoryColors.base(categoria);

  Widget _filaEvento(Map<String, dynamic> evento) {
    final textTheme = Theme.of(context).textTheme;
    final categoriaEvento = evento['categoria']?.toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.paleta.relleno,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.paleta.borde),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: CategoryColors.tinte(categoriaEvento), shape: BoxShape.circle),
              child: Icon(CategoryColors.icono(categoriaEvento), size: 20, color: obtenerColorCategoria(categoriaEvento)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    evento['detalle']?.toString() ?? '${evento['medicacion']} - ${evento['indicaciones']}',
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    CategoryColors.etiqueta(categoriaEvento),
                    style: textTheme.labelMedium?.copyWith(color: CategoryColors.texto(categoriaEvento)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final eventosSeleccionados = _eventosDelDia(_selectedDay);
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      top: false,
      child: ListView(
        primary: true,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text('Historial médico', style: textTheme.titleLarge),
          const SizedBox(height: 12),
          SegmentedButton<_VistaHistorial>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: _VistaHistorial.lista,
                label: Text('Resumen'),
                icon: Icon(Icons.view_list_outlined),
              ),
              ButtonSegment(
                value: _VistaHistorial.calendario,
                label: Text('Calendario'),
                icon: Icon(Icons.calendar_month_outlined),
              ),
            ],
            selected: {_vista},
            onSelectionChanged: (seleccion) => setState(() => _vista = seleccion.first),
          ),
          const SizedBox(height: 16),
          if (_vista == _VistaHistorial.lista)
            _panelLista()
          else ...[
          // --- SECCIÓN: Calendario Histórico ---
          _CuandoHayaLocale(
            child: Builder(
              builder: (context) {
              final fechaLegible = DateFormat("EEEE d 'de' MMMM", 'es_ES').format(_selectedDay);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TableCalendar<Map<String, dynamic>>(
                    locale: 'es_ES',
                    firstDay: DateTime.utc(_focusedDay.year - 2, _focusedDay.month, _focusedDay.day),
                    lastDay: DateTime.utc(_focusedDay.year + 1, _focusedDay.month, _focusedDay.day),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (dia) => isSameDay(dia, _selectedDay),
                    eventLoader: _eventosDelDia,
                    availableGestures: AvailableGestures.horizontalSwipe,
                    headerStyle: HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      titleTextStyle: textTheme.titleMedium ?? const TextStyle(),
                      leftChevronIcon: const Icon(Icons.chevron_left, color: AppColors.navy),
                      rightChevronIcon: const Icon(Icons.chevron_right, color: AppColors.navy),
                    ),
                    daysOfWeekStyle: DaysOfWeekStyle(
                      weekdayStyle: textTheme.labelMedium?.copyWith(color: context.paleta.textoSuave) ?? const TextStyle(),
                      weekendStyle: textTheme.labelMedium?.copyWith(color: context.paleta.textoSuave) ?? const TextStyle(),
                    ),
                    calendarStyle: CalendarStyle(
                      selectedDecoration: const BoxDecoration(
                        color: AppColors.navy,
                        shape: BoxShape.circle,
                      ),
                      selectedTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      todayDecoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.navy, width: 1.6),
                      ),
                      todayTextStyle: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w700),
                      markerDecoration: BoxDecoration(
                        color: obtenerColorCategoria('diario'),
                        shape: BoxShape.circle,
                      ),
                      markerMargin: const EdgeInsets.only(top: 6),
                    ),
                    calendarBuilders: CalendarBuilders(
                      markerBuilder: (context, date, events) {
                        if (events.isEmpty) return null;
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: events.take(4).map((evento) {
                            return Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                color: obtenerColorCategoria(evento['categoria']?.toString()),
                                shape: BoxShape.circle,
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                    onDaySelected: (diaSeleccionado, diaEnfocado) {
                      setState(() {
                        _selectedDay = diaSeleccionado;
                        _focusedDay = diaEnfocado;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    fechaLegible,
                    style: textTheme.titleMedium?.copyWith(color: AppColors.navy),
                  ),
                ],
              );
              },
            ),
          ),
          const SizedBox(height: 12),
          // --- SECCIÓN: Detalle de eventos del día seleccionado ---
          if (eventosSeleccionados.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  const Icon(Icons.event_available_outlined, size: 32, color: AppColors.pendiente),
                  const SizedBox(height: 8),
                  Text(
                    'No hay registros médicos para este día',
                    style: textTheme.bodyMedium?.copyWith(color: context.paleta.textoSuave),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              clipBehavior: Clip.none,
              child: Column(
                children: [
                  for (var n = 0; n < eventosSeleccionados.length; n++)
                    EntradaEscalonada(
                      indice: n,
                      child: _filaEvento(eventosSeleccionados[n]),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _panelLista() {
    return _CuandoHayaLocale(
      child: Builder(
        builder: (context) {
        final filtradas = _entradasFiltradas();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _busqueda,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Buscar medicación o indicación',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 16),
            if (filtradas.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Ningún registro coincide.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.paleta.textoSuave),
                ),
              )
            else
              for (final grupo in _agrupar(filtradas)) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, top: 4),
                  child: Text(grupo.$1, style: Theme.of(context).textTheme.titleMedium),
                ),
                for (final entrada in grupo.$2) _filaHistorial(entrada),
              ],
          ],
        );
        },
      ),
    );
  }

  List<EntradaHistorial> _entradasFiltradas() {
    final consulta = _busqueda.text.trim().toLowerCase();
    return [
      for (final entrada in widget.historial)
        if (consulta.isEmpty ||
            entrada.titulo.toLowerCase().contains(consulta) ||
            entrada.indicaciones.toLowerCase().contains(consulta))
          entrada,
    ];
  }

  List<(String, List<EntradaHistorial>)> _agrupar(List<EntradaHistorial> entradas) {
    final grupos = <String, List<EntradaHistorial>>{};
    final orden = <String>[];
    for (final entrada in entradas) {
      final fecha = entrada.fechaFin ?? entrada.fechaInicio;
      final clave = fecha == null ? 'Sin fecha' : _tituloMes(fecha);
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

  String _fechaCortaHistorial(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    return '$dia/$mes/${fecha.year}';
  }

  int _dosisEnPeriodo(EntradaHistorial entrada) {
    final registro = _registros[entrada.origen.id];
    if (registro == null) return entrada.cantidadDosis;
    return TratamientoController.contarDosisEnPeriodo(
      entrada.origen.copyWith(registroDosis: registro.toList()),
    );
  }

  String _resumenHistorial(EntradaHistorial entrada) {
    final inicio = entrada.fechaInicio;
    final fin = entrada.fechaFin;
    if (inicio == null && fin == null) return 'Sin fecha';
    final desde = _fechaCortaHistorial(inicio ?? fin!);
    final rango = fin == null ? desde : '$desde – ${_fechaCortaHistorial(fin)}';
    if (entrada.categoria == 'diario') {
      if (!entrada.cuentaDosis) return rango;
      final cantidad = _dosisEnPeriodo(entrada);
      if (cantidad <= 0) return '$rango · sin dosis registradas';
      final dosis = cantidad == 1 ? '1 dosis' : '$cantidad dosis';
      return '$rango · $dosis';
    }
    if (entrada.cantidadDosis > 1) return '$rango · ${entrada.cantidadDosis} dosis';
    return rango;
  }

  bool _puedeCorregir(EntradaHistorial entrada) {
    if (widget.esInvitado || entrada.categoria != 'diario') return false;
    return TratamientoController.periodoCorreccion(entrada.origen) != null;
  }

  String _isoDia(DateTime dia) {
    final mes = dia.month.toString().padLeft(2, '0');
    final numero = dia.day.toString().padLeft(2, '0');
    return '${dia.year}-$mes-$numero';
  }

  Future<void> _corregirDosis(EntradaHistorial entrada) async {
    final periodo = TratamientoController.periodoCorreccion(entrada.origen);
    if (periodo == null) return;
    final registro = _registros[entrada.origen.id] ?? entrada.origen.registroDosis.toSet();
    final actual = entrada.origen.copyWith(registroDosis: registro.toList());
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _HojaDosisPeriodo(
        tratamiento: actual,
        inicio: periodo.inicio,
        fin: periodo.fin,
        alAlternar: (dia) async {
          final ok = await widget.alAlternar(actual, dia);
          if (!ok || !mounted) return ok;
          final iso = _isoDia(dia);
          setState(() {
            final dias = _registros.putIfAbsent(entrada.origen.id, () => registro.toSet());
            if (dias.contains(iso)) {
              dias.remove(iso);
            } else {
              dias.add(iso);
            }
          });
          return true;
        },
      ),
    );
  }

  String _textoTramo(TramoDosis tramo) {
    final desde = tramo.desde == null ? '' : _fechaCortaHistorial(tramo.desde!);
    if (tramo.hasta == null) {
      return desde.isEmpty ? tramo.indicaciones : '${tramo.indicaciones} · desde $desde';
    }
    return '${tramo.indicaciones} · $desde – ${_fechaCortaHistorial(tramo.hasta!)}';
  }

  Widget _filaHistorial(EntradaHistorial entrada) {
    final textTheme = Theme.of(context).textTheme;
    final fecha = entrada.fechaInicio ?? entrada.fechaFin;
    final etiqueta = entrada.categoria == 'diario'
        ? TratamientoController.etiquetaEstado(entrada.origen)
        : '';
    final corregir = _puedeCorregir(entrada);
    final tramos = entrada.origen.cambiosDosis.isEmpty
        ? const <TramoDosis>[]
        : TratamientoController.tramosDosis(entrada.origen);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: context.paleta.relleno,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: context.paleta.borde),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: fecha == null
                  ? null
                  : () => setState(() {
                        _vista = _VistaHistorial.calendario;
                        _selectedDay = fecha;
                        _focusedDay = fecha;
                      }),
              child: Padding(
                padding: EdgeInsets.fromLTRB(12, 12, 12, corregir ? 0 : 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: CategoryColors.tinte(entrada.categoria),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        CategoryColors.icono(entrada.categoria),
                        size: 20,
                        color: CategoryColors.base(entrada.categoria),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entrada.titulo, style: textTheme.titleMedium),
                          if (etiqueta.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: entrada.activo
                                      ? AppColors.activo.withValues(alpha: 0.14)
                                      : AppColors.pausado.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  etiqueta,
                                  style: textTheme.labelMedium?.copyWith(
                                    color: entrada.activo
                                        ? context.paleta.activoTexto
                                        : context.paleta.pausadoTexto,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 2),
                          Text(
                            _resumenHistorial(entrada),
                            style: textTheme.bodyMedium?.copyWith(color: context.paleta.textoSuave),
                          ),
                          if (entrada.indicaciones.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              entrada.indicaciones,
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
            if (entrada.origen.cambiosDosis.isNotEmpty)
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.only(left: 64, right: 12),
                  childrenPadding: const EdgeInsets.fromLTRB(64, 0, 16, 8),
                  title: Text('Cambios de dosis', style: textTheme.bodyMedium),
                  children: [
                    for (final tramo in tramos)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(_textoTramo(tramo), style: textTheme.bodyMedium),
                        ),
                      ),
                  ],
                ),
              ),
            if (corregir)
              Padding(
                padding: const EdgeInsets.only(left: 52),
                child: TextButton.icon(
                  onPressed: () => _corregirDosis(entrada),
                  icon: const Icon(Icons.edit_calendar_outlined),
                  label: const Text('Corregir dosis'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
