# 04 — Código de vistas clave (6 de 9)

Código fuente copiado tal cual. Cada bloque indica archivo y rango de líneas.

### `lib/views/formulario_perro.dart` — parte 3/4, líneas 1001–1500 de 1978

```dart
                      decoration: const InputDecoration(
                        labelText: 'Días de duración (0 = indefinido)',
                      ),
                    ),
                  if (!esEventoUnico) const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '$labelFecha: ${fechaInicio.day.toString().padLeft(2, '0')}/${fechaInicio.month.toString().padLeft(2, '0')}/${fechaInicio.year}',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final seleccionada = await showDatePicker(
                        context: ctx,
                        initialDate: fechaInicio,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (seleccionada != null) {
                        setDialogState(() => fechaInicio = seleccionada);
                      }
                    },
                  ),
                  if (!esEventoUnico)
                    InkWell(
                      onTap: () async {
                        final seleccionada = await showTimePicker(
                          context: ctx,
                          initialTime: horaRecordatorio,
                          builder: (BuildContext context, Widget? child) {
                            return MediaQuery(
                              data: MediaQuery.of(
                                context,
                              ).copyWith(alwaysUse24HourFormat: true),
                              child: child!,
                            );
                          },
                        );
                        if (seleccionada != null) {
                          setDialogState(() => horaRecordatorio = seleccionada);
                        }
                      },
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Hora del recordatorio: ${horaRecordatorio.hour.toString().padLeft(2, '0')}:${horaRecordatorio.minute.toString().padLeft(2, '0')}',
                        ),
                        trailing: const Icon(Icons.access_time),
                      ),
                    ),
                  if (permiteProximoRecordatorio)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        fechaProximoRecordatorio != null
                            ? 'Recordar próxima vez: ${fechaProximoRecordatorio!.day.toString().padLeft(2, '0')}/${fechaProximoRecordatorio!.month.toString().padLeft(2, '0')}/${fechaProximoRecordatorio!.year} ${fechaProximoRecordatorio!.hour.toString().padLeft(2, '0')}:${fechaProximoRecordatorio!.minute.toString().padLeft(2, '0')}'
                            : 'Recordar próxima vez (opcional)',
                      ),
                      trailing: fechaProximoRecordatorio != null
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => setDialogState(
                                () => fechaProximoRecordatorio = null,
                              ),
                            )
                          : const Icon(Icons.event),
                      onTap: () async {
                        final fechaSeleccionada = await showDatePicker(
                          context: ctx,
                          initialDate:
                              fechaProximoRecordatorio ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2100),
                        );
                        if (fechaSeleccionada == null) return;
                        if (!ctx.mounted) return;

                        final horaSeleccionada = await showTimePicker(
                          context: ctx,
                          initialTime: TimeOfDay.fromDateTime(
                            fechaProximoRecordatorio ?? DateTime.now(),
                          ),
                          builder: (BuildContext context, Widget? child) {
                            return MediaQuery(
                              data: MediaQuery.of(
                                context,
                              ).copyWith(alwaysUse24HourFormat: true),
                              child: child!,
                            );
                          },
                        );
                        if (horaSeleccionada == null) return;

                        setDialogState(() {
                          fechaProximoRecordatorio = DateTime(
                            fechaSeleccionada.year,
                            fechaSeleccionada.month,
                            fechaSeleccionada.day,
                            horaSeleccionada.hour,
                            horaSeleccionada.minute,
                          );
                        });
                      },
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  final medicacion = medicacionController.text.trim();
                  if (medicacion.isEmpty) return;

                  final horaFormateada =
                      '${horaRecordatorio.hour.toString().padLeft(2, '0')}:${horaRecordatorio.minute.toString().padLeft(2, '0')}';

                  final nuevoTratamiento = _tratamientoController
                      .crearTratamiento(
                        categoria: categoria,
                        medicacion: medicacion,
                        indicaciones: indicacionesController.text.trim(),
                        fechaInicio: fechaInicio,
                        diasDuracion:
                            int.tryParse(diasController.text.trim()) ?? 0,
                        horaRecordatorio: horaFormateada,
                        fechaProximoRecordatorio: fechaProximoRecordatorio,
                      );

                  setState(() {
                    _tratamientos.add(nuevoTratamiento);
                    _hayCambios = true;
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Agregar'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _mostrarDialogoEditarTratamiento(int indice) async {
    final tratamiento = _tratamientos[indice];
    final medicacionController = TextEditingController(
      text: tratamiento.medicacion,
    );
    final indicacionesController = TextEditingController(
      text: tratamiento.indicaciones,
    );
    final diasController = TextEditingController(
      text: tratamiento.diasDuracion.toString(),
    );

    DateTime fechaInicio = tratamiento.fechaInicio ?? DateTime.now();

    final partesHora = (tratamiento.horaRecordatorio ?? '09:00').split(':');
    TimeOfDay horaRecordatorio = TimeOfDay(
      hour: int.tryParse(partesHora.isNotEmpty ? partesHora[0] : '') ?? 9,
      minute: int.tryParse(partesHora.length > 1 ? partesHora[1] : '') ?? 0,
    );

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Editar tratamiento'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: medicacionController,
                  decoration: const InputDecoration(
                    labelText: 'Medicación',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: indicacionesController,
                  decoration: const InputDecoration(
                    labelText: 'Indicaciones',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: diasController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Días de duración (0 = indefinido)',
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Fecha de inicio: ${fechaInicio.day.toString().padLeft(2, '0')}/${fechaInicio.month.toString().padLeft(2, '0')}/${fechaInicio.year}',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final seleccionada = await showDatePicker(
                      context: ctx,
                      initialDate: fechaInicio,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (seleccionada != null) {
                      setDialogState(() => fechaInicio = seleccionada);
                    }
                  },
                ),
                InkWell(
                  onTap: () async {
                    final seleccionada = await showTimePicker(
                      context: ctx,
                      initialTime: horaRecordatorio,
                      builder: (BuildContext context, Widget? child) {
                        return MediaQuery(
                          data: MediaQuery.of(
                            context,
                          ).copyWith(alwaysUse24HourFormat: true),
                          child: child!,
                        );
                      },
                    );
                    if (seleccionada != null) {
                      setDialogState(() => horaRecordatorio = seleccionada);
                    }
                  },
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Hora del recordatorio: ${horaRecordatorio.hour.toString().padLeft(2, '0')}:${horaRecordatorio.minute.toString().padLeft(2, '0')}',
                    ),
                    trailing: const Icon(Icons.access_time),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final medicacion = medicacionController.text.trim();
                if (medicacion.isEmpty) return;

                final horaFormateada =
                    '${horaRecordatorio.hour.toString().padLeft(2, '0')}:${horaRecordatorio.minute.toString().padLeft(2, '0')}';

                setState(() {
                  _tratamientos[indice] = _tratamientoController
                      .editarTratamiento(
                        tratamiento,
                        medicacion: medicacion,
                        indicaciones: indicacionesController.text.trim(),
                        diasDuracion:
                            int.tryParse(diasController.text.trim()) ?? 0,
                        fechaInicio: fechaInicio,
                        horaRecordatorio: horaFormateada,
                      );
                  _hayCambios = true;
                });
                Navigator.pop(ctx);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _mostrarDialogoEliminarTratamiento(int indice) async {
    final esDiario = _tratamientos[indice].categoria == 'diario';

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(esDiario ? 'Eliminar tratamiento' : 'Eliminar registro'),
        content: Text(
          esDiario
              ? '¿Qué querés hacer con este tratamiento?'
              : '¿Querés eliminar este registro médico? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          if (esDiario)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _alternarPausaTratamiento(indice);
              },
              child: const Text('Pausar'),
            ),
          TextButton(
            onPressed: () {
              setState(() {
                _tratamientos.removeAt(indice);
                _hayCambios = true;
              });
              Navigator.pop(ctx);
            },
            child: Text(
              esDiario ? 'Eliminar definitivamente' : 'Eliminar',
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmarSalida() async {
    if (!_hayCambios) {
      Navigator.pop(context);
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hay cambios sin guardar'),
        content: const Text('¿Qué querés hacer con los cambios?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Descartar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _guardarDatos();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final esEdicion = widget.idDocumento != null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmarSalida();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(esEdicion ? 'Editar Ficha' : 'Nuevo Ingreso'),
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              child: Column(
                children: [
                  // --- SECCIÓN: Foto de perfil ---
                  Center(
                    child: GestureDetector(
                      onTap: _abrirOpcionesFotoPerfil,
                      child: CircleAvatar(
                        radius: 60,
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        backgroundImage: _imagenSeleccionada != null
                            ? FileImage(_imagenSeleccionada!) as ImageProvider
                            : (widget.perroActual?.fotoPerfil != null
                                  ? NetworkImage(
                                      widget.perroActual!.fotoPerfil!,
                                    )
                                  : null),
                        child:
                            _imagenSeleccionada == null &&
                                widget.perroActual?.fotoPerfil == null
                            ? Icon(
                                Icons.add_a_photo,
                                size: 40,
                                color: Theme.of(context).colorScheme.primary,
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // --- SECCIÓN: Datos básicos (nombre, ingreso, sexo, edad, castración, estado) ---
                  _tarjetaFormulario(
                    titulo: 'Datos básicos',
                    icono: Icons.pets,
                    children: [
                  TextFormField(
                    controller: _nombreController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del perrito',
                      prefixIcon: Icon(Icons.pets),
                    ),
                    validator: _perroController.validarNombre,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _fechaIngresoController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Fecha de ingreso (opcional)',
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    onTap: _seleccionarFechaIngreso,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text('Sexo', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(width: 12),
                      ChoiceChip(
                        label: const Text('Macho'),
                        selected: _sexo == 'macho',
                        onSelected: (_) => setState(() => _sexo = 'macho'),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Hembra'),
                        selected: _sexo == 'hembra',
                        onSelected: (_) => setState(() => _sexo = 'hembra'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Edad indeterminada'),
                    value: _edadIndeterminada,
                    onChanged: (valor) => setState(() {
                      _edadIndeterminada = valor ?? false;
                      if (_edadIndeterminada) {
                        _edadController.clear();
                        _mesesController.clear();
                      }
                    }),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _edadController,
                    enabled: !_edadIndeterminada,
                    decoration: const InputDecoration(
                      labelText: 'Edad estimada (años, opcional)',
                      prefixIcon: Icon(Icons.cake),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  if (!_edadIndeterminada &&
                      _edadController.text.trim() == '0') ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _mesesController,
                      decoration: const InputDecoration(
                        labelText: 'Meses (opcional)',
                        prefixIcon: Icon(Icons.calendar_view_month),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [LengthLimitingTextInputFormatter(2)],
                      validator: _perroController.validarMeses,
                    ),
                  ],
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('¿Ya está castrado?'),
                    value: _estaCastrado,
                    onChanged: (valor) => setState(() => _estaCastrado = valor),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('Estado', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(width: 12),
                      ChoiceChip(
                        label: const Text('Activo'),
                        selected: _estado == 'activo',
                        onSelected: (_) => setState(() => _estado = 'activo'),
                      ),
```

