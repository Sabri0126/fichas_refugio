# 04 — Código de vistas clave (2 de 9)

Código fuente copiado tal cual. Cada bloque indica archivo y rango de líneas.

### `lib/views/ficha_detalle_perro.dart` — parte 2/3, líneas 501–1000 de 1452

```dart
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: fondo,
                          shape: BoxShape.circle,
                          border: esHoy ? Border.all(color: AppColors.navy, width: 2) : null,
                        ),
                        child: icono == null ? null : Icon(icono, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                  Text(
                    _inicialesDia[diaSoloFecha.weekday - 1],
                    style: textTheme.labelMedium?.copyWith(
                      color: esHoy ? AppColors.navy : AppColors.textoSecundario,
                      fontWeight: esHoy ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Row(mainAxisAlignment: MainAxisAlignment.start, children: circulos);
  }

  Widget _tarjetaSeccion({required String titulo, required IconData icono, required List<Widget> children}) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icono, size: 22, color: AppColors.navy),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(titulo, textScaler: _escala, style: Theme.of(context).textTheme.titleLarge),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _chipDato(IconData icono, String texto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.rellenoInput,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.bordeTarjeta),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 18, color: AppColors.navy),
          const SizedBox(width: 6),
          Text(
            texto,
            textScaler: _escala,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _filaDato(String etiqueta, String valor) {
    final textTheme = Theme.of(context).textTheme;
    final sinDato = valor == 'No registrada';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etiqueta, textScaler: _escala, style: textTheme.labelMedium?.copyWith(color: AppColors.textoSecundario)),
        const SizedBox(height: 2),
        Text(
          valor,
          textScaler: _escala,
          style: sinDato
              ? textTheme.bodyLarge?.copyWith(color: AppColors.textoSecundario, fontStyle: FontStyle.italic)
              : textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildDatosBasicos(PerroModel perro) {
    final esHembra = perro.sexo == 'hembra';
    final edadTexto = _formatearEdadTexto(perro);
    final partesEdad = edadTexto.split(':');
    final edadValor = partesEdad.length > 1 ? partesEdad.sublist(1).join(':').trim() : edadTexto;
    final edadChip = edadTexto.startsWith('Edad estimada') ? '$edadValor aprox.' : edadValor;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chipDato(esHembra ? Icons.female : Icons.male, esHembra ? 'Hembra' : 'Macho'),
                _chipDato(Icons.cake_outlined, edadChip),
                _chipDato(
                  perro.castrado ? Icons.check_circle_outline : Icons.remove_circle_outline,
                  perro.castrado ? 'Castrado' : 'No castrado',
                ),
              ],
            ),
            const SizedBox(height: 16),
            _filaDato('Fecha de ingreso', _formatearFecha(perro.fechaIngreso)),
            if (perro.fechaFallecimiento != null) ...[
              const SizedBox(height: 12),
              _filaDato('Fecha de fallecimiento', _formatearFecha(perro.fechaFallecimiento)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTarjetaTratamiento(TratamientoModel t, String fechaHoy, bool esInvitado) {
    final textTheme = Theme.of(context).textTheme;
    final marcadoHoy = t.registroDosis.contains(fechaHoy);
    final diasDuracion = t.diasDuracion;
    final ValueChanged<bool?>? alCambiar = esInvitado ? null : (_) => _toggleDosis(t, DateTime.now());

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: marcadoHoy ? AppColors.dosisDada.withValues(alpha: 0.08) : AppColors.rellenoInput,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: marcadoHoy ? AppColors.dosisDada.withValues(alpha: 0.4) : AppColors.bordeTarjeta,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: alCambiar == null ? null : () => alCambiar(!marcadoHoy),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(value: marcadoHoy, onChanged: alCambiar),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutCubic,
                              style: (textTheme.titleMedium ?? const TextStyle()).copyWith(
                                color: marcadoHoy ? AppColors.textoSecundario : AppColors.texto,
                                decoration: marcadoHoy ? TextDecoration.lineThrough : TextDecoration.none,
                                decorationColor: AppColors.textoSecundario,
                              ),
                              child: Text(
                                t.medicacion,
                                textScaler: _escala,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${t.indicaciones} \u00b7 ${diasDuracion > 0 ? '$diasDuracion d\u00edas' : 'Indefinido'}',
                              textScaler: _escala,
                              style: textTheme.bodyMedium?.copyWith(color: AppColors.textoSecundario),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _buildHistorialDosis(t, esInvitado),
            ),
          ],
        ),
      ),
    );
  }

  /// Marca como inactivos los tratamientos diarios cuyo ciclo (fecha_inicio + dias_duracion) ya venció,
  /// persistiendo el cambio en Firestore para que dejen de listarse en "Tratamientos activos".
  PerroModel _procesarAutoArchivado(PerroModel perro) {
    if (perro.tratamientos.isEmpty) return perro;

    final actualizados = _tratamientoController.autoArchivarVencidos(perro.tratamientos);
    if (!_tratamientoController.huboCambiosDeArchivado(perro.tratamientos, actualizados)) return perro;

    _tratamientoController.guardarTratamientos(widget.idDocumento, actualizados).catchError((_) {});

    return perro.copyWith(tratamientos: actualizados);
  }

  Widget _buildSeccionSalud(PerroModel perro, bool esInvitado) {
    final tratamientos = perro.tratamientos;
    final fechaHoy = _fechaHoyISO();
    // Las dosis únicas y visitas veterinarias no requieren seguimiento diario con checkbox.
    final tratamientosActivos = _tratamientoController.obtenerActivosDiarios(tratamientos);
    final tieneHistorial = tratamientos.isNotEmpty;
    final textTheme = Theme.of(context).textTheme;

    return _tarjetaSeccion(
      titulo: 'Ficha médica',
      icono: Icons.favorite_outline,
      children: [
        _construirTextoFormateado(
          perro.fichaMedica.isNotEmpty ? perro.fichaMedica : 'No hay ficha médica registrada.',
          _escalaTexto,
        ),
        if (tieneHistorial) ...[
          const SizedBox(height: 24),
          Text('Tratamientos activos', textScaler: _escala, style: textTheme.titleLarge),
          const SizedBox(height: 12),
          if (tratamientosActivos.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'No hay tratamientos diarios activos.',
                textScaler: _escala,
                style: textTheme.bodyMedium?.copyWith(color: AppColors.textoSecundario),
              ),
            ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            clipBehavior: Clip.none,
            child: Column(
              children: [
                for (var n = 0; n < tratamientosActivos.length; n++)
                  EntradaEscalonada(
                    indice: n,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildTarjetaTratamiento(tratamientosActivos[n], fechaHoy, esInvitado),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text('Ver Historial Médico', textScaler: _escala),
              onPressed: () => _mostrarHistorialCompleto(tratamientos),
            ),
          ),
        ],
      ],
    );
  }

  void _mostrarHistorialCompleto(List<TratamientoModel> tratamientos) {
    final eventosCalendario = _tratamientoController.construirEventosCalendario(tratamientos);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, controladorScroll) => PrimaryScrollController(
          controller: controladorScroll,
          child: CalendarioHistorialWidget(eventosCalendario: eventosCalendario),
        ),
      ),
    );
  }

  Column _buildInfoContenido(PerroModel perro, bool esInvitado) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Text(
          perro.nombre.isNotEmpty ? perro.nombre : 'Sin nombre',
          textScaler: _escala,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        _buildDatosBasicos(perro),
        const SizedBox(height: 12),
        _tarjetaSeccion(
          titulo: 'Historia y observaciones',
          icono: Icons.menu_book_outlined,
          children: [
            _construirTextoFormateado(perro.historia.isNotEmpty ? perro.historia : 'No hay historia registrada.', _escalaTexto),
          ],
        ),
        const SizedBox(height: 12),
        _buildSeccionSalud(perro, esInvitado),
        if (perro.parientes.isNotEmpty) ...[
          const SizedBox(height: 12),
          _tarjetaSeccion(
            titulo: 'Familiares en el refugio',
            icono: Icons.people_outline,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: perro.parientes.map((familiar) {
                  final nombre = familiar['nombre']?.toString() ?? '';
                  final relacion = familiar['relacion']?.toString() ?? '';
                  final idDoc = familiar['id_documento']?.toString() ?? '';
                  return ActionChip(
                    backgroundColor: AppColors.rellenoInput,
                    avatar: const Icon(Icons.pets, size: 18, color: AppColors.navy),
                    label: Text('$nombre ($relacion)', textScaler: _escala),
                    onPressed: idDoc.isEmpty
                        ? null
                        : () => Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FichaDetallePerro(idDocumento: idDoc),
                              ),
                            ),
                  );
                }).toList(),
              ),
            ],
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildGaleria(List<Map<String, dynamic>> galeria, bool esInvitado, PerroModel perro) {
    if (_modoReordenar) {
      final fotosReordenables = _fotosReordenar.isNotEmpty ? _fotosReordenar : _construirListaReordenamiento(perro);
      if (fotosReordenables.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Aún no hay fotos para ordenar.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        );
      }

      return Container(
        padding: const EdgeInsets.all(16),
        child: ReorderableListView.builder(
          itemCount: fotosReordenables.length,
          onReorderItem: (oldIndex, newIndex) {
            if (oldIndex == newIndex) return;

            setState(() {
              if (oldIndex < newIndex) {
                newIndex -= 1;
              }
              final elemento = _fotosReordenar.removeAt(oldIndex);
              _fotosReordenar.insert(newIndex, elemento);
            });
          },
          itemBuilder: (context, index) {
            final foto = fotosReordenables[index];
            final url = foto['url']?.toString() ?? '';
            final titulo = foto['texto']?.toString().isNotEmpty == true
                ? foto['texto']
                : (foto['descripcion']?.toString().isNotEmpty == true ? foto['descripcion'] : 'Sin descripción');

            return Card(
              key: ValueKey('$url-$index'),
              margin: const EdgeInsets.only(bottom: 12),
              child: Stack(
                children: [
                  ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(url, width: 56, height: 56, fit: BoxFit.cover),
                    ),
                    title: Text(titulo),
                    subtitle: Text(index == 0 ? 'Portada actual' : 'Arrastrá para cambiar el orden'),
                    trailing: const Icon(Icons.drag_handle),
                  ),
                  if (index == 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Portada actual',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      );
    }

    if (galeria.isEmpty) {
      final textTheme = Theme.of(context).textTheme;
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
                child: const Icon(Icons.photo_camera_outlined, size: 30, color: AppColors.navy),
              ),
              const SizedBox(height: 12),
              Text('Aún no hay fotos en la galería', style: textTheme.titleMedium, textAlign: TextAlign.center),
              if (!esInvitado) ...[
                const SizedBox(height: 4),
                Text(
                  'Tocá el ícono de cámara arriba para agregar una.',
                  style: textTheme.bodyMedium?.copyWith(color: AppColors.textoSecundario),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      );
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        PageView.builder(
          controller: _controladorCarrusel,
          itemCount: galeria.length,
          onPageChanged: (index) => setState(() => _paginaActual = index),
          itemBuilder: (context, index) {
            final foto = galeria[index];
            return Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Center(
                          child: GestureDetector(
                            onTap: () => _abrirFotoPantallaCompleta(foto['url']?.toString() ?? ''),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(foto['url'] ?? '', fit: BoxFit.contain),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (foto['texto'] != null && foto['texto'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
```

