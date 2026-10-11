# 04 — Código de vistas clave (5 de 9)

Código fuente copiado tal cual. Cada bloque indica archivo y rango de líneas.

### `lib/views/formulario_perro.dart` — parte 2/4, líneas 501–1000 de 1978

```dart
            FilledButton(
              onPressed: seleccionadoId == null
                  ? null
                  : () {
                      setState(() {
                        _parientes.add({
                          'id': seleccionadoId,
                          'id_documento': seleccionadoId,
                          'nombre': seleccionadoNombre,
                          'relacion': seleccionadaRelacion,
                        });
                        _hayCambios = true;
                      });
                      Navigator.pop(ctx);
                    },
              child: const Text('Añadir'),
            ),
          ],
        ),
      ),
    );
  }

  String _tituloDialogoAgregar(String categoria) {
    switch (categoria) {
      case 'unico':
        return 'Agregar dosis única';
      case 'higiene':
        return 'Agregar higiene';
      case 'evento':
        return 'Agregar evento médico';
      case 'veterinaria':
        return 'Agregar visita veterinaria';
      default:
        return 'Agregar tratamiento diario';
    }
  }

  Widget _botonCategoriaSalud({
    required String etiqueta,
    required IconData icono,
    required Color color,
    required String categoria,
  }) {
    final colorTexto = CategoryColors.texto(categoria);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () => _mostrarDialogoAgregarTratamiento(categoria: categoria),
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.superficie,
          foregroundColor: colorTexto,
          side: const BorderSide(color: AppColors.bordeTarjeta),
          minimumSize: const Size.fromHeight(56),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          alignment: Alignment.centerLeft,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icono, size: 20, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                etiqueta,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorTexto,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaFormulario({
    String? titulo,
    IconData? icono,
    Widget? accion,
    required List<Widget> children,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (titulo != null) ...[
              Row(
                children: [
                  if (icono != null) ...[
                    Icon(icono, size: 22, color: AppColors.navy),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      titulo,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  ?accion,
                ],
              ),
              const SizedBox(height: 16),
            ],
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _estadoVacioSalud(IconData icono, String texto) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.rellenoInput,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.bordeTarjeta),
      ),
      child: Row(
        children: [
          Icon(icono, color: AppColors.pendiente),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              texto,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textoSecundario,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tituloSeccion(String titulo, int cantidad) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Flexible(
          child: Text(
            titulo,
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.navy.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$cantidad',
            style: textTheme.labelMedium?.copyWith(color: AppColors.navy),
          ),
        ),
      ],
    );
  }

  Widget _chipEstado({required bool activo}) {
    final color = activo ? AppColors.activo : AppColors.pausado;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        activo ? 'Activo' : 'Pausado',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: activo ? const Color(0xFF2E6B44) : const Color(0xFF8A6414),
        ),
      ),
    );
  }

  Widget _tarjetaTratamientoDiario({
    required int i,
    required TratamientoModel t,
    required bool pausado,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final dias = t.diasDuracion;
    final fechaTexto = t.fechaInicio != null
        ? '${t.fechaInicio!.day.toString().padLeft(2, '0')}/${t.fechaInicio!.month.toString().padLeft(2, '0')}/${t.fechaInicio!.year}'
        : '';
    final horaRecordatorio = t.horaRecordatorio ?? '';
    final subtitulo = pausado
        ? '${t.indicaciones} · ${dias > 0 ? '$dias días' : 'Indefinido'}'
        : '${t.indicaciones} · ${dias > 0 ? '$dias días' : 'Indefinido'} · Desde $fechaTexto'
            '${horaRecordatorio.isNotEmpty ? ' · Recordatorio $horaRecordatorio' : ''}';
    final colorIcono = pausado ? AppColors.pausado : CategoryColors.base('diario');

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      opacity: pausado ? 0.65 : 1,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: pausado ? null : () => _mostrarDialogoEditarTratamiento(i),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colorIcono.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        pausado ? Icons.pause_circle_outline : Icons.medication,
                        size: 22,
                        color: colorIcono,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _capitalizarPrimera(t.medicacion),
                            style: textTheme.titleMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitulo,
                            style: textTheme.bodyMedium?.copyWith(
                              color: AppColors.textoSecundario,
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _chipEstado(activo: !pausado),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: pausado
                      ? [
                          FilledButton.tonalIcon(
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Reanudar'),
                            onPressed: () => _alternarPausaTratamiento(i),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_forever,
                              color: AppColors.error,
                            ),
                            tooltip: 'Eliminar definitivamente',
                            onPressed: () => setState(() {
                              _tratamientos.removeAt(i);
                              _hayCambios = true;
                            }),
                          ),
                        ]
                      : [
                          FilledButton.tonalIcon(
                            icon: const Icon(Icons.pause),
                            label: const Text('Pausar'),
                            onPressed: () => _alternarPausaTratamiento(i),
                          ),
                          const SizedBox(width: 4),
                          IconButton.outlined(
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: 'Editar',
                            onPressed: () =>
                                _mostrarDialogoEditarTratamiento(i),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: AppColors.error,
                            ),
                            tooltip: 'Eliminar',
                            onPressed: () =>
                                _mostrarDialogoEliminarTratamiento(i),
                          ),
                        ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _filaEvento(int i, TratamientoModel t) {
    final textTheme = Theme.of(context).textTheme;
    final fechaTexto = t.fechaInicio != null
        ? '${t.fechaInicio!.day.toString().padLeft(2, '0')}/${t.fechaInicio!.month.toString().padLeft(2, '0')}/${t.fechaInicio!.year}'
        : 'Sin fecha';
    final color = _colorCategoria(t.categoria);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.superficie,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.bordeTarjeta),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: () => _mostrarDialogoEditarTratamiento(i),
          contentPadding: const EdgeInsets.only(left: 12, right: 4),
          leading: CircleAvatar(
            radius: 20,
            backgroundColor: CategoryColors.tinte(t.categoria),
            child: Icon(_iconoCategoria(t.categoria), size: 20, color: color),
          ),
          title: Text(
            _capitalizarPrimera(t.medicacion),
            style: textTheme.titleMedium?.copyWith(fontSize: 15),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${_etiquetaCategoria(t.categoria)} · $fechaTexto'
            '${t.indicaciones.isNotEmpty ? ' · ${t.indicaciones}' : ''}',
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.textoSecundario,
              fontSize: 13,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                tooltip: 'Editar',
                color: AppColors.textoSecundario,
                onPressed: () => _mostrarDialogoEditarTratamiento(i),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                tooltip: 'Eliminar',
                color: AppColors.error,
                onPressed: () => _mostrarDialogoEliminarTratamiento(i),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _capitalizarPrimera(String texto) {
    final limpio = texto.trim();
    if (limpio.isEmpty) return limpio;
    return limpio[0].toUpperCase() + limpio.substring(1);
  }

  String _etiquetaCategoria(String categoria) {
    return switch (categoria) {
      'unico' => 'Dosis única',
      'higiene' => 'Higiene',
      'evento' => 'Evento médico',
      'veterinaria' => 'Veterinaria',
      _ => 'Tratamiento diario',
    };
  }

  IconData _iconoCategoria(String categoria) {
    return switch (categoria) {
      'unico' => Icons.vaccines,
      'higiene' => Icons.shower,
      'evento' => Icons.monitor_heart,
      'veterinaria' => Icons.local_hospital,
      _ => Icons.medication,
    };
  }

  Color _colorCategoria(String categoria) => CategoryColors.base(categoria);

  Future<void> _alternarPausaTratamiento(int indice) async {
    final actual = _tratamientos[indice];
    if (actual.categoria != 'diario') return;

    setState(() {
      _tratamientos[indice] = _tratamientoController.alternarPausa(actual);
      _hayCambios = true;
    });

    final idDocumento = widget.idDocumento;
    if (idDocumento == null || idDocumento.isEmpty) return;

    try {
      await _tratamientoController.persistirAlternarPausa(idDocumento, actual.id);
    } catch (_) {
      if (!mounted) return;
      setState(() => _tratamientos[indice] = actual);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo actualizar el estado del tratamiento')),
      );
    }
  }

  Future<void> _mostrarDialogoAgregarTratamiento({
    required String categoria,
  }) async {
    final medicacionController = TextEditingController();
    final indicacionesController = TextEditingController();
    final diasController = TextEditingController(text: '0');
    DateTime fechaInicio = DateTime.now();
    TimeOfDay horaRecordatorio = const TimeOfDay(hour: 9, minute: 0);
    DateTime? fechaProximoRecordatorio;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final esEventoUnico = categoria != 'diario';
          final permiteProximoRecordatorio =
              categoria == 'unico' || categoria == 'higiene';
          final labelPrimerCampo = switch (categoria) {
            'veterinaria' => 'Motivo de la visita',
            'unico' => 'Medicación / Aplicación',
            'higiene' => 'Procedimiento / Cuidado',
            'evento' => 'Evento / Motivo',
            _ => 'Medicación',
          };
          final labelSegundoCampo = switch (categoria) {
            'veterinaria' => 'Diagnóstico / Indicaciones',
            'evento' => 'Notas / Indicaciones',
            _ => 'Indicaciones',
          };
          final labelFecha = switch (categoria) {
            'veterinaria' => 'Fecha de visita',
            'unico' => 'Fecha de aplicación',
            'higiene' => 'Fecha',
            'evento' => 'Fecha del evento',
            _ => 'Fecha de inicio',
          };

          return AlertDialog(
            title: Text(_tituloDialogoAgregar(categoria)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: medicacionController,
                    decoration: InputDecoration(
                      labelText: labelPrimerCampo,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: indicacionesController,
                    decoration: InputDecoration(
                      labelText: labelSegundoCampo,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!esEventoUnico)
                    TextField(
                      controller: diasController,
                      keyboardType: TextInputType.number,
```

