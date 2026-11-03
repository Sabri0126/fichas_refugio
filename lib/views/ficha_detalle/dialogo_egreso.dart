part of '../ficha_detalle_perro.dart';

class _DialogoEditarEgreso extends StatefulWidget {
  final EgresoModel egreso;

  const _DialogoEditarEgreso({required this.egreso});

  @override
  State<_DialogoEditarEgreso> createState() => _DialogoEditarEgresoState();
}

class _DialogoEditarEgresoState extends State<_DialogoEditarEgreso> {
  late String _motivo;
  DateTime? _fechaEgreso;
  DateTime? _fechaRegreso;
  late final TextEditingController _nota;
  String? _error;

  @override
  void initState() {
    super.initState();
    final motivo = widget.egreso.motivo;
    _motivo = motivo == 'familia' ? 'familia' : 'adopcion';
    _fechaEgreso = widget.egreso.fechaEgreso;
    _fechaRegreso = widget.egreso.fechaRegreso;
    _nota = TextEditingController(text: widget.egreso.nota ?? '');
  }

  @override
  void dispose() {
    _nota.dispose();
    super.dispose();
  }

  String _textoFecha(DateTime? fecha) {
    if (fecha == null) return 'Sin fecha';
    final dd = fecha.day.toString().padLeft(2, '0');
    final mm = fecha.month.toString().padLeft(2, '0');
    return '$dd/$mm/${fecha.year}';
  }

  Future<void> _elegirEgreso() async {
    final hoy = DateTime.now();
    final inicial = _fechaEgreso ?? hoy;
    final fecha = await showDatePicker(
      context: context,
      initialDate: inicial.isAfter(hoy) ? hoy : inicial,
      firstDate: DateTime(2000),
      lastDate: hoy,
    );
    if (fecha == null) return;
    setState(() => _fechaEgreso = fecha);
  }

  Future<void> _elegirRegreso() async {
    final hoy = DateTime.now();
    final inicial = _fechaRegreso ?? _fechaEgreso ?? hoy;
    final fecha = await showDatePicker(
      context: context,
      initialDate: inicial.isAfter(hoy) ? hoy : inicial,
      firstDate: DateTime(2000),
      lastDate: hoy,
    );
    if (fecha == null) return;
    setState(() => _fechaRegreso = fecha);
  }

  void _guardar() {
    final nota = _nota.text.trim();
    final nuevo = EgresoModel(
      motivo: _motivo,
      fechaEgreso: _fechaEgreso,
      nota: nota.isEmpty ? null : nota,
      fechaRegreso: _fechaRegreso,
    );
    final error = PerroController.validarEgreso(nuevo);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context, nuevo);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar egreso'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final ancho = constraints.maxWidth - 24;
                Widget chip(String valor, String texto) {
                  return ChoiceChip(
                    label: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: ancho),
                      child: Text(texto),
                    ),
                    selected: _motivo == valor,
                    onSelected: (_) => setState(() => _motivo = valor),
                  );
                }

                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    chip('adopcion', 'Adoptado'),
                    chip('familia', 'Volvió con su familia'),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Fecha de egreso'),
              subtitle: Text(_textoFecha(_fechaEgreso)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _elegirEgreso,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Fecha de regreso'),
              subtitle: Text(_textoFecha(_fechaRegreso)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _elegirRegreso,
            ),
            if (_fechaRegreso != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() => _fechaRegreso = null),
                  child: const Text('Quitar fecha de regreso'),
                ),
              ),
            TextField(
              controller: _nota,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Nota (opcional)',
                helperText: 'La ven también los visitantes. No cargues datos personales.',
                helperMaxLines: 3,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _guardar, child: const Text('Guardar')),
      ],
    );
  }
}
