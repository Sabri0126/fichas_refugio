# 04 — Código de vistas clave (7 de 9)

Código fuente copiado tal cual. Cada bloque indica archivo y rango de líneas.

### `lib/views/formulario_perro.dart` — parte 4/4, líneas 1501–1978 de 1978

```dart
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Inactivo'),
                        selected: _estado == 'inactivo',
                        onSelected: (_) => setState(() => _estado = 'inactivo'),
                      ),
                    ],
                  ),
                  if (_estado == 'inactivo') ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _fechaFallecimientoController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Fecha de fallecimiento (opcional)',
                        prefixIcon: Icon(Icons.sentiment_very_dissatisfied),
                      ),
                      onTap: _seleccionarFechaFallecimiento,
                    ),
                  ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  // --- SECCIÓN: Familiares vinculados ---
                  _tarjetaFormulario(
                    titulo: 'Familiares',
                    icono: Icons.people_outline,
                    accion: FilledButton.tonalIcon(
                      icon: const Icon(Icons.add),
                      label: const Text('Añadir'),
                      onPressed: _mostrarDialogoAgregarFamiliar,
                    ),
                    children: [
                  if (_parientes.isEmpty)
                    Text(
                      'Sin familiares registrados.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textoSecundario,
                      ),
                    )
                  else
                    Column(
                      children: _parientes.asMap().entries.map((entry) {
                        final i = entry.key;
                        final p = entry.value;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: AppColors.navy.withValues(alpha: 0.08),
                            child: const Icon(Icons.pets, size: 20, color: AppColors.navy),
                          ),
                          title: Text(p['nombre']?.toString() ?? ''),
                          subtitle: Text(p['relacion']?.toString() ?? ''),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: AppColors.error,
                            ),
                            tooltip: 'Quitar familiar',
                            onPressed: () => setState(() {
                              _parientes.removeAt(i);
                              _hayCambios = true;
                            }),
                          ),
                        );
                      }).toList(),
                    ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // --- SECCIÓN: Historia / observaciones ---
                  _tarjetaFormulario(
                    children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Historia',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            tooltip: 'Negrita',
                            onPressed: () => _insertarFormatoTexto(
                              _historiaController,
                              '**',
                              '**',
                            ),
                            icon: const Icon(Icons.format_bold),
                          ),
                          IconButton(
                            tooltip: 'Cursiva',
                            onPressed: () => _insertarFormatoTexto(
                              _historiaController,
                              '*',
                              '*',
                            ),
                            icon: const Icon(Icons.format_italic),
                          ),
                          IconButton(
                            tooltip: 'Agregar viñeta',
                            onPressed: () =>
                                _insertarBulletTexto(_historiaController),
                            icon: const Icon(Icons.format_list_bulleted),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _historiaController,
                    decoration: const InputDecoration(
                      labelText: 'Descripción de la historia',
                      alignLabelWithHint: true,
                    ),
                    maxLines: 6,
                  ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // --- SECCIÓN: Gestión de salud ---
                  const Divider(height: 32),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        const Icon(Icons.favorite_outline, color: AppColors.navy),
                        const SizedBox(width: 8),
                        Text(
                          'Gestión de Salud',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Ficha médica',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            tooltip: 'Negrita',
                            onPressed: () => _insertarFormatoTexto(
                              _fichaMedicaController,
                              '**',
                              '**',
                            ),
                            icon: const Icon(Icons.format_bold),
                          ),
                          IconButton(
                            tooltip: 'Cursiva',
                            onPressed: () => _insertarFormatoTexto(
                              _fichaMedicaController,
                              '*',
                              '*',
                            ),
                            icon: const Icon(Icons.format_italic),
                          ),
                          IconButton(
                            tooltip: 'Agregar viñeta',
                            onPressed: () =>
                                _insertarBulletTexto(_fichaMedicaController),
                            icon: const Icon(Icons.format_list_bulleted),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _fichaMedicaController,
                    decoration: const InputDecoration(
                      labelText: 'Detalles médicos',
                      alignLabelWithHint: true,
                    ),
                    maxLines: 6,
                  ),
                  const SizedBox(height: 24),
                  // --- SECCIÓN: Tratamientos (activos y pausados) ---
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Agregar registro médico',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      const espacio = 12.0;
                      final anchoCelda = (constraints.maxWidth - espacio) / 2;
                      return Wrap(
                        spacing: espacio,
                        runSpacing: espacio,
                        children: [
                          SizedBox(
                            width: anchoCelda,
                            child: _botonCategoriaSalud(
                              etiqueta: 'Tratamiento Diario',
                              icono: Icons.medication,
                              color: CategoryColors.base('diario'),
                              categoria: 'diario',
                            ),
                          ),
                          SizedBox(
                            width: anchoCelda,
                            child: _botonCategoriaSalud(
                              etiqueta: 'Dosis Única',
                              icono: Icons.vaccines,
                              color: CategoryColors.base('unico'),
                              categoria: 'unico',
                            ),
                          ),
                          SizedBox(
                            width: anchoCelda,
                            child: _botonCategoriaSalud(
                              etiqueta: 'Higiene',
                              icono: Icons.shower,
                              color: CategoryColors.base('higiene'),
                              categoria: 'higiene',
                            ),
                          ),
                          SizedBox(
                            width: anchoCelda,
                            child: _botonCategoriaSalud(
                              etiqueta: 'Evento Médico',
                              icono: Icons.monitor_heart,
                              color: CategoryColors.base('evento'),
                              categoria: 'evento',
                            ),
                          ),
                          SizedBox(
                            width: anchoCelda,
                            child: _botonCategoriaSalud(
                              etiqueta: 'Veterinaria',
                              icono: Icons.local_hospital,
                              color: CategoryColors.base('veterinaria'),
                              categoria: 'veterinaria',
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  // --- SECCIÓN 1: Tratamientos Diarios (solo categoría diario) ---
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _tituloSeccion(
                      'Tratamientos Diarios',
                      _tratamientos.where((t) => t.categoria == 'diario').length,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      final diariosActivos = _tratamientos
                          .asMap()
                          .entries
                          .where(
                            (e) =>
                                e.value.categoria == 'diario' && e.value.activo,
                          )
                          .toList();
                      final diariosPausados = _tratamientos
                          .asMap()
                          .entries
                          .where(
                            (e) =>
                                e.value.categoria == 'diario' &&
                                !e.value.activo,
                          )
                          .toList();
                      final textTheme = Theme.of(context).textTheme;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (diariosActivos.isEmpty)
                            _estadoVacioSalud(
                              Icons.medication_outlined,
                              'Sin tratamientos diarios activos.',
                            )
                          else
                            AnimatedSize(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOutCubic,
                              alignment: Alignment.topCenter,
                              clipBehavior: Clip.none,
                              child: Column(
                                children: [
                                  for (var n = 0; n < diariosActivos.length; n++)
                                    EntradaEscalonada(
                                      indice: n,
                                      child: _tarjetaTratamientoDiario(
                                        i: diariosActivos[n].key,
                                        t: diariosActivos[n].value,
                                        pausado: false,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          if (diariosPausados.isNotEmpty)
                            ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              shape: const Border(),
                              collapsedShape: const Border(),
                              collapsedIconColor: AppColors.textoSecundario,
                              iconColor: AppColors.textoSecundario,
                              title: Row(
                                children: [
                                  const Icon(
                                    Icons.pause_circle_outline,
                                    size: 20,
                                    color: AppColors.pausado,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Pausados (${diariosPausados.length})',
                                    style: textTheme.titleMedium?.copyWith(
                                      color: AppColors.textoSecundario,
                                    ),
                                  ),
                                ],
                              ),
                              children: [
                                AnimatedSize(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOutCubic,
                                  alignment: Alignment.topCenter,
                                  clipBehavior: Clip.none,
                                  child: Column(
                                    children: [
                                      for (var n = 0; n < diariosPausados.length; n++)
                                        EntradaEscalonada(
                                          indice: n,
                                          child: _tarjetaTratamientoDiario(
                                            i: diariosPausados[n].key,
                                            t: diariosPausados[n].value,
                                            pausado: true,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  // --- SECCIÓN 2: Eventos y Visitas (categoría != diario) ---
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _tituloSeccion(
                      'Eventos y Visitas',
                      _tratamientos.where((t) => t.categoria != 'diario').length,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      final eventos = _tratamientos
                          .asMap()
                          .entries
                          .where((e) => e.value.categoria != 'diario')
                          .toList()
                        ..sort((a, b) {
                          final fechaA = a.value.fechaInicio ??
                              DateTime.fromMillisecondsSinceEpoch(0);
                          final fechaB = b.value.fechaInicio ??
                              DateTime.fromMillisecondsSinceEpoch(0);
                          return fechaB.compareTo(fechaA);
                        });
                      if (eventos.isEmpty) {
                        return _estadoVacioSalud(
                          Icons.event_note_outlined,
                          'Sin eventos ni visitas registrados.',
                        );
                      }

                      return AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        clipBehavior: Clip.none,
                        child: Column(
                          children: [
                            for (var n = 0; n < eventos.length; n++)
                              EntradaEscalonada(
                                indice: n,
                                child: _filaEvento(eventos[n].key, eventos[n].value),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  // --- SECCIÓN: Ubicación (en casa / refugio) ---
                  Card(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    child: CheckboxListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      secondary: const Icon(Icons.home_outlined, color: AppColors.navy),
                      title: const Text('Este perrito/a está en casa'),
                      value: _enCasa,
                      onChanged: (valor) =>
                          setState(() => _enCasa = valor ?? false),
                    ),
                  ),
                  if (widget.idDocumento != null) ...[
                    const SizedBox(height: 24),
                    TextButton.icon(
                      onPressed: _confirmarEliminarFicha,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Eliminar ficha'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        // --- SECCIÓN: Acción de guardado (barra inferior fija) ---
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: AppColors.superficie,
            border: Border(top: BorderSide(color: AppColors.bordeTarjeta)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: FilledButton(
                onPressed: _estaGuardando ? null : _guardarDatos,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  textStyle: Theme.of(context).textTheme.titleMedium,
                ),
                child: _estaGuardando
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.6,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      )
                    : Text(esEdicion ? 'Guardar Cambios' : 'Crear Ficha'),
              ),
            ),
          ),
        ),
      ), // cierra Scaffold
    ); // cierra PopScope
  }
}
```

