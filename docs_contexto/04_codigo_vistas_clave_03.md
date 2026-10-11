# 04 — Código de vistas clave (3 de 9)

Código fuente copiado tal cual. Cada bloque indica archivo y rango de líneas.

### `lib/views/ficha_detalle_perro.dart` — parte 3/3, líneas 1001–1452 de 1452

```dart
                        child: Text(
                          foto['texto'],
                          textScaler: TextScaler.linear(_escalaTexto),
                          style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    SizedBox(height: galeria.length > 1 ? 20 : 8),
                  ],
                ),
                if (!esInvitado)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          child: IconButton(
                            icon: Icon(Icons.edit, color: Theme.of(context).colorScheme.onPrimary, size: 20),
                            onPressed: () => _editarFotoAGaleria(foto, index),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.secondary,
                          child: IconButton(
                            icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.onSecondary, size: 20),
                            onPressed: () => _eliminarFotoAGaleria(foto, index),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
        if (_paginaActual > 0)
          Positioned(
            left: 8,
            child: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              radius: 24,
              child: IconButton(
                icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onPrimary),
                onPressed: _moverIzquierda,
              ),
            ),
          ),
        if (_paginaActual < galeria.length - 1)
          Positioned(
            right: 8,
            child: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              radius: 24,
              child: IconButton(
                icon: Icon(Icons.arrow_forward, color: Theme.of(context).colorScheme.onPrimary),
                onPressed: _moverDerecha,
              ),
            ),
          ),
        if (galeria.length > 1)
          Positioned(
            bottom: 8,
            child: IgnorePointer(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(galeria.length, (index) {
                  final activa = index == _paginaActual;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: activa ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: activa ? AppColors.navy : AppColors.navy.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool esInvitado = FirebaseAuth.instance.currentUser == null;

    return StreamBuilder<PerroModel?>(
      stream: _perroController.observarPerroPorId(widget.idDocumento),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // --- SECCIÓN: Datos del perro y auto-archivado de tratamientos vencidos ---
        final perro = _procesarAutoArchivado(snapshot.data!);
        final galeria = perro.galeria;

        return Scaffold(
          // --- SECCIÓN: AppBar (título y acciones de galería/accesibilidad) ---
          appBar: AppBar(
            title: Text('Ficha de ${perro.nombre}', overflow: TextOverflow.ellipsis),
            actions: [
              if (_subiendoFoto)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Theme.of(context).colorScheme.onPrimary),
                  ),
                )
              else ...[
                if (!esInvitado) ...[
                  if (_modoReordenar)
                    IconButton(
                      icon: const Icon(Icons.check),
                      tooltip: 'Guardar orden de fotos',
                      onPressed: () async {
                        if (_modoReordenar) {
                          await _confirmarOrdenFotos();
                        } else {
                          _activarModoReordenar(perro);
                        }
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.add_a_photo),
                    tooltip: 'Agregar foto a la galería',
                    onPressed: _agregarFotoAGaleria,
                  ),
                ],
                PopupMenuButton<void>(
                  icon: const Icon(Icons.more_vert),
                  tooltip: 'Más opciones',
                  itemBuilder: (context) => [
                    PopupMenuItem<void>(
                      enabled: _escalaTexto > 1.0,
                      onTap: () => setState(() => _escalaTexto -= 0.15),
                      child: const ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.zoom_out),
                        title: Text('Achicar texto'),
                      ),
                    ),
                    PopupMenuItem<void>(
                      onTap: () => setState(() => _escalaTexto += 0.15),
                      child: const ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.zoom_in),
                        title: Text('Agrandar texto'),
                      ),
                    ),
                    if (!esInvitado && !_modoReordenar)
                      PopupMenuItem<void>(
                        onTap: () async {
                          if (_modoReordenar) {
                            await _confirmarOrdenFotos();
                          } else {
                            _activarModoReordenar(perro);
                          }
                        },
                        child: const ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.reorder),
                          title: Text('Reordenar fotos'),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 700;
                // --- SECCIÓN: Galería de fotos (carrusel o modo reordenar) ---
                final galeriaWidget = _buildGaleria(galeria, esInvitado, perro);

                if (isWide) {
                  return Row(
                    children: [
                      // --- SECCIÓN: Panel de información (layout ancho) ---
                      // Panel de info: ancho acotado, centrado, con margen para que respire
                      Center(
                        child: Container(
                          margin: const EdgeInsets.all(20),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 450),
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
                              child: _buildInfoContenido(perro, esInvitado),
                            ),
                          ),
                        ),
                      ),
                      Expanded(flex: 2, child: galeriaWidget),
                    ],
                  );
                }
                // --- SECCIÓN: Panel de información (layout angosto, apilado bajo la galería) ---
                final galeriaVacia = galeria.isEmpty && !_modoReordenar;
                return Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      height: galeriaVacia ? 200 : 300,
                      decoration: const BoxDecoration(
                        color: AppColors.superficie,
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                        boxShadow: [
                          BoxShadow(color: Color(0x0F000000), blurRadius: 16, offset: Offset(0, 4)),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: galeriaWidget,
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                        child: _buildInfoContenido(perro, esInvitado),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      }
    );
  }
}

class CalendarioHistorialWidget extends StatefulWidget {
  final Map<DateTime, List<Map<String, dynamic>>> eventosCalendario;

  const CalendarioHistorialWidget({super.key, required this.eventosCalendario});

  @override
  State<CalendarioHistorialWidget> createState() => _CalendarioHistorialWidgetState();
}

class _CalendarioHistorialWidgetState extends State<CalendarioHistorialWidget> {
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  late final Future<void> _localeListo;

  @override
  void initState() {
    super.initState();
    _localeListo = initializeDateFormatting('es_ES');
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
          color: AppColors.rellenoInput,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.bordeTarjeta),
        ),
        child: Row(
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
          // --- SECCIÓN: Calendario Histórico ---
          FutureBuilder<void>(
            future: _localeListo,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
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
                      weekdayStyle: textTheme.labelMedium?.copyWith(color: AppColors.textoSecundario) ?? const TextStyle(),
                      weekendStyle: textTheme.labelMedium?.copyWith(color: AppColors.textoSecundario) ?? const TextStyle(),
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
                    style: textTheme.bodyMedium?.copyWith(color: AppColors.textoSecundario),
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
      ),
    );
  }
}
```

