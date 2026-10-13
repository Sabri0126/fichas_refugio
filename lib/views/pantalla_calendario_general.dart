import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../controllers/calendario_general_controller.dart';
import '../controllers/perro_controller.dart';
import '../models/perro_model.dart';
import '../theme/app_colors.dart';
import '../theme/category_colors.dart';
import '../theme/entrada_escalonada.dart';
import '../theme/recordatorio_tipos.dart';
import 'ficha_detalle_perro.dart';

class PantallaCalendarioGeneral extends StatefulWidget {
  const PantallaCalendarioGeneral({super.key});

  @override
  State<PantallaCalendarioGeneral> createState() =>
      _PantallaCalendarioGeneralState();
}

class _PantallaCalendarioGeneralState extends State<PantallaCalendarioGeneral> {
  final PerroController _perroController = PerroController();
  late final Stream<List<PerroModel>> _streamPerros = _perroController
      .observarPerros();
  late final Future<void> _localeListo;
  late final DateTime _hoy;
  late final DateTime _primerDia;
  late final DateTime _ultimoDia;

  DateTime _diaSeleccionado = DateTime.now();
  DateTime _diaEnfocado = DateTime.now();
  CalendarFormat _formato = CalendarFormat.month;
  String? _idPerroFiltro;

  @override
  void initState() {
    super.initState();
    final ahora = DateTime.now();
    _hoy = DateTime(ahora.year, ahora.month, ahora.day);
    _diaSeleccionado = _hoy;
    _diaEnfocado = _hoy;
    _primerDia = _fechaEnAnio(_hoy, -2);
    _ultimoDia = _fechaEnAnio(_hoy, 1);
    _localeListo = initializeDateFormatting('es_ES');
  }

  DateTime _fechaEnAnio(DateTime base, int deltaAnios) {
    final anio = base.year + deltaAnios;
    final ultimoDiaMes = DateTime(anio, base.month + 1, 0).day;
    final dia = base.day > ultimoDiaMes ? ultimoDiaMes : base.day;
    return DateTime(anio, base.month, dia);
  }

  DateTime _soloFecha(DateTime fecha) =>
      DateTime(fecha.year, fecha.month, fecha.day);

  void _irAHoy() {
    setState(() {
      _diaSeleccionado = _hoy;
      _diaEnfocado = _hoy;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendario general'),
        actions: [
          IconButton(
            tooltip: 'Ir a hoy',
            onPressed: _irAHoy,
            icon: const Icon(Icons.today_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<List<PerroModel>>(
          stream: _streamPerros,
          builder: (context, snapshot) {
            if (snapshot.hasError && !snapshot.hasData) {
              return _estadoMensaje(
                'No se pudo cargar el calendario.',
                icono: Icons.cloud_off_outlined,
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final activos =
                snapshot.data!
                    .where((perro) => perro.estado == 'activo')
                    .toList()
                  ..sort((a, b) => a.nombre.compareTo(b.nombre));
            if (activos.isEmpty) {
              return _estadoMensaje('No hay perritos registrados aún.');
            }
            final filtro = activos.any((perro) => perro.id == _idPerroFiltro)
                ? _idPerroFiltro
                : null;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _filtroPerro(activos, filtro),
                const SizedBox(height: 12),
                FutureBuilder<void>(
                  future: _localeListo,
                  builder: (context, locale) {
                    if (locale.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _calendario(activos, filtro),
                        const SizedBox(height: 12),
                        _leyenda(),
                        const SizedBox(height: 20),
                        _resumen(activos, filtro),
                      ],
                    );
                  },
                ),
              ],
            );
          },
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
              child: Icon(icono, size: 30, color: AppColors.navy),
            ),
            const SizedBox(height: 12),
            Text(
              texto,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textoSecundario,
              ),
            ),
          ],
        ),
      ),
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
      onChanged: (id) => setState(() => _idPerroFiltro = id),
    );
  }

  Widget _calendario(List<PerroModel> activos, String? filtro) {
    final textTheme = Theme.of(context).textTheme;
    return TableCalendar<void>(
      locale: 'es_ES',
      firstDay: _primerDia,
      lastDay: _ultimoDia,
      focusedDay: _diaEnfocado,
      currentDay: _hoy,
      calendarFormat: _formato,
      startingDayOfWeek: StartingDayOfWeek.monday,
      availableCalendarFormats: const {
        CalendarFormat.month: 'Mes',
        CalendarFormat.twoWeeks: '2 semanas',
      },
      availableGestures: AvailableGestures.horizontalSwipe,
      selectedDayPredicate: (dia) => isSameDay(dia, _diaSeleccionado),
      headerStyle: HeaderStyle(
        formatButtonVisible: true,
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
            textTheme.labelMedium?.copyWith(color: AppColors.textoSecundario) ??
            const TextStyle(),
        weekendStyle:
            textTheme.labelMedium?.copyWith(color: AppColors.textoSecundario) ??
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
        markerBuilder: (context, date, events) {
          final claves = CalendarioGeneralController.marcadoresDelDia(
            activos,
            date,
            hoy: _hoy,
            idPerro: filtro,
          );
          if (claves.isEmpty) return null;
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final clave in claves)
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
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
        setState(() {
          _diaSeleccionado = _soloFecha(seleccionado);
          _diaEnfocado = enfocado;
        });
      },
      onPageChanged: (enfocado) => _diaEnfocado = enfocado,
      onFormatChanged: (formato) {
        if (_formato == formato) return;
        setState(() => _formato = formato);
      },
    );
  }

  Widget _leyenda() {
    final estilo = Theme.of(context).textTheme.labelMedium;
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

    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: [
        punto(CategoryColors.diario, 'Dosis dada'),
        punto(AppColors.dosisOlvidada, 'Olvidada'),
        punto(AppColors.pendiente, 'Pendiente'),
        punto(CategoryColors.unico, 'Dosis única'),
        punto(CategoryColors.higiene, 'Higiene'),
        punto(CategoryColors.evento, 'Evento'),
        punto(CategoryColors.veterinaria, 'Veterinaria'),
        punto(AppColors.navy, 'Recordatorio'),
      ],
    );
  }

  Widget _resumen(List<PerroModel> activos, String? filtro) {
    final textTheme = Theme.of(context).textTheme;
    final resumen = CalendarioGeneralController.construirResumen(
      activos,
      _diaSeleccionado,
      hoy: _hoy,
      idPerro: filtro,
    );
    final dia = _soloFecha(_diaSeleccionado);
    final fecha = DateFormat("EEEE d 'de' MMMM", 'es_ES').format(dia);
    final fechaLegible = fecha.isEmpty
        ? fecha
        : '${fecha[0].toUpperCase()}${fecha.substring(1)}';
    final comparacion = dia.compareTo(_hoy);
    final secciones = <Widget>[];

    if (comparacion == 0) {
      secciones.add(
        _seccion(
          'Pendientes de hoy',
          Icons.pending_outlined,
          resumen.pendientes,
        ),
      );
      secciones.add(
        _seccion('Dosis dadas', Icons.check_circle_outline, resumen.dadas),
      );
    } else if (comparacion < 0) {
      secciones.add(
        _seccion(
          'Dosis olvidadas',
          Icons.warning_amber_rounded,
          resumen.olvidadas,
          tinte: AppColors.dosisOlvidada,
        ),
      );
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
        '${resumen.dadas.length} dadas',
      if (resumen.pendientes.isNotEmpty)
        '${resumen.pendientes.length} pendientes',
      if (resumen.programadas.isNotEmpty)
        '${resumen.programadas.length} programadas',
      if (resumen.olvidadas.isNotEmpty) '${resumen.olvidadas.length} olvidadas',
      if (resumen.eventos.isNotEmpty) '${resumen.eventos.length} eventos',
      if (resumen.recordatorios.isNotEmpty)
        '${resumen.recordatorios.length} recordatorios',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Resumen del día', style: textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          fechaLegible,
          style: textTheme.titleMedium?.copyWith(color: AppColors.navy),
        ),
        if (visibles.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                const Icon(
                  Icons.event_available_outlined,
                  size: 32,
                  color: AppColors.textoSecundario,
                ),
                const SizedBox(height: 8),
                Text(
                  'No hay registros ni pendientes para este día',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.textoSecundario,
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

  Widget _chipConteo(String texto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.rellenoInput,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.bordeTarjeta),
      ),
      child: Text(texto, style: Theme.of(context).textTheme.labelMedium),
    );
  }

  Widget _seccion(
    String titulo,
    IconData icono,
    List<ItemResumen> items, {
    Color? tinte,
  }) {
    if (items.isEmpty) return const _SeccionOculta();
    final textTheme = Theme.of(context).textTheme;
    final color = tinte ?? AppColors.navy;
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
                    EntradaEscalonada(indice: i, child: _filaResumen(items[i])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filaResumen(ItemResumen item) {
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
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FichaDetallePerro(idDocumento: item.perro.id),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _avatar(item.perro),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.titulo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleMedium,
                        ),
                        Text(
                          subtitulo,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.textoSecundario,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (item.hora != null) ...[
                    const SizedBox(width: 8),
                    Text(item.hora!, style: textTheme.labelMedium),
                  ],
                  const SizedBox(width: 8),
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: visual.tinte,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(visual.icono, size: 16, color: visual.color),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  _VisualCategoria _visualCategoria(ItemResumen item) {
    if (item.esRecordatorio) {
      final tipo = RecordatorioTipos.de(item.categoria);
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
