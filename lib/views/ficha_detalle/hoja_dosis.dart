part of '../ficha_detalle_perro.dart';

class _HojaDosisPeriodo extends StatefulWidget {
  final TratamientoModel tratamiento;
  final DateTime inicio;
  final DateTime fin;
  final Future<bool> Function(DateTime dia) alAlternar;

  const _HojaDosisPeriodo({
    required this.tratamiento,
    required this.inicio,
    required this.fin,
    required this.alAlternar,
  });

  @override
  State<_HojaDosisPeriodo> createState() => _HojaDosisPeriodoState();
}

class _HojaDosisPeriodoState extends State<_HojaDosisPeriodo> {
  late DateTime _focused;
  late final Set<String> _dadas;
  final Set<String> _enCurso = {};

  @override
  void initState() {
    super.initState();
    _focused = widget.fin;
    _dadas = widget.tratamiento.registroDosis.toSet();
  }

  String _iso(DateTime dia) {
    final fecha = DateTime(dia.year, dia.month, dia.day);
    final mes = fecha.month.toString().padLeft(2, '0');
    final numero = fecha.day.toString().padLeft(2, '0');
    return '${fecha.year}-$mes-$numero';
  }

  /// Una pausa manual, que todavía no llegó a su último día, no se pinta como olvido.
  bool get _enPausa {
    if (widget.tratamiento.activo) return false;
    final fase = TratamientoController.calcularEstadoDuracion(widget.tratamiento).fase;
    return fase != FaseTratamiento.finalizado;
  }

  EstadoMarcaDosis _estado(DateTime dia) {
    final fecha = DateTime(dia.year, dia.month, dia.day);
    if (_dadas.contains(_iso(fecha))) return EstadoMarcaDosis.dada;
    if (_enPausa) return EstadoMarcaDosis.pausa;
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    if (fecha == hoy && widget.tratamiento.activo) return EstadoMarcaDosis.pendiente;
    return EstadoMarcaDosis.olvidada;
  }

  Future<void> _alternar(DateTime dia) async {
    final fecha = DateTime(dia.year, dia.month, dia.day);
    final inicio = DateTime(widget.inicio.year, widget.inicio.month, widget.inicio.day);
    final fin = DateTime(widget.fin.year, widget.fin.month, widget.fin.day);
    if (fecha.isBefore(inicio) || fecha.isAfter(fin)) return;
    final iso = _iso(dia);
    if (_enCurso.contains(iso)) return;
    final estaba = _dadas.contains(iso);
    setState(() {
      _enCurso.add(iso);
      if (estaba) {
        _dadas.remove(iso);
      } else {
        _dadas.add(iso);
      }
    });
    final ok = await widget.alAlternar(DateTime(dia.year, dia.month, dia.day));
    if (!mounted) return;
    setState(() {
      _enCurso.remove(iso);
      if (!ok) {
        if (estaba) {
          _dadas.add(iso);
        } else {
          _dadas.remove(iso);
        }
      }
    });
  }

  Widget _marca(DateTime dia, {required bool esHoy}) {
    final estado = _estado(dia);
    final Color fondo;
    final IconData? icono;
    switch (estado) {
      case EstadoMarcaDosis.dada:
        fondo = AppColors.dosisDada;
        icono = Icons.check;
      case EstadoMarcaDosis.pendiente:
        fondo = AppColors.pendiente;
        icono = null;
      case EstadoMarcaDosis.pausa:
        fondo = AppColors.pausado;
        icono = Icons.pause;
      case EstadoMarcaDosis.olvidada:
        fondo = AppColors.dosisOlvidada;
        icono = Icons.close;
    }
    final texto = esHoy ? colorIconoSeccion(context) : context.paleta.texto;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${dia.day}',
          style: TextStyle(
            fontSize: 12,
            height: 1.1,
            fontWeight: esHoy ? FontWeight.w800 : FontWeight.w600,
            color: texto,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: fondo,
            shape: BoxShape.circle,
            border: esHoy ? Border.all(color: colorIconoSeccion(context), width: 1.6) : null,
          ),
          child: icono == null ? null : Icon(icono, size: 10, color: Colors.white),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final nombre = widget.tratamiento.medicacion.trim().isEmpty
        ? 'Tratamiento diario'
        : widget.tratamiento.medicacion.trim();
    final alto = MediaQuery.sizeOf(context).height * 0.72;
    return SafeArea(
      child: SizedBox(
        height: alto,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text(nombre, style: textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Tocá un día para marcar o desmarcar la dosis.',
              style: textTheme.bodyMedium?.copyWith(color: context.paleta.textoSuave),
            ),
            const SizedBox(height: 12),
            _CuandoHayaLocale(
              child: TableCalendar<void>(
                  locale: 'es_ES',
                  firstDay: widget.inicio,
                  lastDay: widget.fin,
                  focusedDay: _focused,
                  selectedDayPredicate: (_) => false,
                  rowHeight: 58,
                  availableGestures: AvailableGestures.horizontalSwipe,
                  headerStyle: HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: textTheme.titleMedium ?? const TextStyle(),
                    leftChevronIcon: const Icon(Icons.chevron_left, color: AppColors.navy),
                    rightChevronIcon: const Icon(Icons.chevron_right, color: AppColors.navy),
                  ),
                  daysOfWeekStyle: DaysOfWeekStyle(
                    weekdayStyle: textTheme.labelMedium?.copyWith(color: context.paleta.textoSuave) ??
                        const TextStyle(),
                    weekendStyle: textTheme.labelMedium?.copyWith(color: context.paleta.textoSuave) ??
                        const TextStyle(),
                  ),
                  calendarStyle: const CalendarStyle(
                    outsideDaysVisible: false,
                  ),
                  onPageChanged: (enfocado) => _focused = enfocado,
                  enabledDayPredicate: (dia) {
                    final fecha = DateTime(dia.year, dia.month, dia.day);
                    final inicio = DateTime(widget.inicio.year, widget.inicio.month, widget.inicio.day);
                    final fin = DateTime(widget.fin.year, widget.fin.month, widget.fin.day);
                    return !fecha.isBefore(inicio) && !fecha.isAfter(fin);
                  },
                  onDaySelected: (seleccionado, enfocado) {
                    setState(() => _focused = enfocado);
                    _alternar(seleccionado);
                  },
                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (context, dia, _) => _marca(dia, esHoy: false),
                    todayBuilder: (context, dia, _) => _marca(dia, esHoy: true),
                  ),
                ),
            ),
          ],
        ),
      ),
    );
  }
}
