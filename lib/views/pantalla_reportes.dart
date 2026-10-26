import 'package:flutter/material.dart';

import '../controllers/perro_controller.dart';
import '../controllers/reportes_controller.dart';
import '../models/perro_model.dart';
import '../theme/app_colors.dart';
import '../utils/fundacion_refugio.dart';
import '../widgets/grafico_poblacion.dart';
import 'ficha_detalle_perro.dart';

const _nombresMes = [
  'Enero',
  'Febrero',
  'Marzo',
  'Abril',
  'Mayo',
  'Junio',
  'Julio',
  'Agosto',
  'Septiembre',
  'Octubre',
  'Noviembre',
  'Diciembre',
];

class PantallaReportes extends StatefulWidget {
  const PantallaReportes({super.key});

  @override
  State<PantallaReportes> createState() => _PantallaReportesState();
}

class _PantallaReportesState extends State<PantallaReportes> {
  final PerroController _perros = PerroController();
  late DateTime _mes;

  @override
  void initState() {
    super.initState();
    final hoy = DateTime.now();
    _mes = DateTime(hoy.year, hoy.month);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Reportes',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.arena,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: StreamBuilder<List<PerroModel>>(
        stream: _perros.observarPerros(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('No se pudieron cargar los reportes.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final hoy = DateTime.now();
          final reporte = ReportesController.calcular(snapshot.data!, hoy: hoy, mes: _mes);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Text(
                'Impacto histórico desde el 29 de abril de 2000',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: context.paleta.lienzo),
              ),
              const SizedBox(height: 4),
              Text(
                textoAniosCuidando(calcularAniosServicio(hoy)),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.paleta.textoSuave),
              ),
              const SizedBox(height: 16),
              _tarjeta(
                context,
                titulo: 'Hoy en el refugio',
                icono: Icons.pets,
                hijo: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ayuda(context, 'Perros a cargo ahora, en el predio o en una casa.'),
                    _numero(context, '${reporte.poblacion.activos}'),
                    const SizedBox(height: 8),
                    Text(
                      '${reporte.poblacion.enRefugio} en el refugio · ${reporte.poblacion.enCasa} en casa',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.paleta.texto),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _tarjeta(
                context,
                titulo: 'Población por año',
                icono: Icons.show_chart,
                hijo: _poblacion(context, reporte.serie),
              ),
              const SizedBox(height: 12),
              _tarjeta(
                context,
                titulo: 'Cuánto hace que están',
                icono: Icons.hourglass_bottom,
                hijo: _estadia(context, reporte.estadia),
              ),
              const SizedBox(height: 12),
              _tarjeta(
                context,
                titulo: 'A lo largo del tiempo',
                icono: Icons.history,
                hijo: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ayuda(context, 'Desde ${fundacionRefugio.year}. Una adopción cuenta aunque el perro haya vuelto.'),
                    _fila(context, Icons.volunteer_activism, 'Adoptados', reporte.balance.adoptados),
                    _fila(context, Icons.home, 'Reencontrados', reporte.balance.reencontrados),
                    _fila(context, Icons.local_florist, 'En memoria', reporte.balance.difuntos),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _tarjeta(
                context,
                titulo: 'Este mes',
                icono: Icons.calendar_month,
                hijo: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ayuda(context, 'Movimientos con fecha en el mes elegido.'),
                    _selectorMes(context),
                    const SizedBox(height: 16),
                    _fila(context, Icons.login, 'Ingresos', reporte.mes.ingresos),
                    _fila(context, Icons.favorite, 'Adopciones', reporte.mes.adopciones),
                    _fila(context, Icons.home, 'Reencuentros', reporte.mes.reencuentros),
                    _fila(context, Icons.local_florist, 'Fallecimientos', reporte.mes.fallecimientos),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _verAnio(PuntoPoblacion punto) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final alto = MediaQuery.sizeOf(ctx).height * 0.72;
        final grupos = <(String, List<PerroAnio>)>[
          ('Entraron', punto.quienesEntraron),
          ('Salieron', punto.quienesSalieron),
          ('Quedaron', punto.quienesQuedaron),
        ].where((grupo) => grupo.$2.isNotEmpty).toList();
        return SafeArea(
          child: SizedBox(
            height: alto,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                Text('${punto.anio}', style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 12),
                if (grupos.isEmpty)
                  Text(
                    'No hay perros para mostrar.',
                    style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(color: ctx.paleta.textoSuave),
                  )
                else
                  for (final grupo in grupos) ...[
                    Text(grupo.$1, style: Theme.of(ctx).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    for (final perro in grupo.$2)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(perro.nombre),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FichaDetallePerro(idDocumento: perro.id),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 12),
                  ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _poblacion(BuildContext context, SeriePoblacion serie) {
    final sinFecha = serie.sinFecha;
    final aviso = sinFecha == 1
        ? '1 perro no entra porque le falta una fecha.'
        : '$sinFecha perros no entran porque les falta una fecha.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ayuda(context, 'Perros a cargo al cierre de cada año.'),
        if (serie.puntos.isEmpty)
          Text(
            'No hay ingresos con fecha para armar la curva.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.paleta.texto),
          )
        else
          GraficoPoblacion(puntos: serie.puntos, alVer: _verAnio),
        if (sinFecha > 0) ...[
          const SizedBox(height: 8),
          Text(
            aviso,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.paleta.textoSuave),
          ),
        ],
      ],
    );
  }

  Widget _estadia(BuildContext context, LargaEstadia estadia) {
    final promedio = estadia.mesesPromedio;
    final lectura = promedio == null ? 'Sin fecha de ingreso' : '${ReportesController.textoMeses(promedio)} en promedio';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ayuda(context, 'Promedio de los perros activos que tienen fecha de ingreso.'),
        _numero(context, lectura),
        if (estadia.conFecha > 0) ...[
          const SizedBox(height: 8),
          Text(
            '${estadia.residentes} de ${estadia.conFecha} llevan más de 5 años',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.paleta.texto),
          ),
        ],
        if (estadia.sinFecha > 0) ...[
          const SizedBox(height: 4),
          Text(
            estadia.sinFecha == 1 ? '1 sin fecha de ingreso' : '${estadia.sinFecha} sin fecha de ingreso',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.paleta.textoSuave),
          ),
        ],
      ],
    );
  }

  Widget _selectorMes(BuildContext context) {
    final anioActual = DateTime.now().year;
    final anios = [for (var anio = anioActual; anio >= fundacionRefugio.year; anio--) anio];
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<int>(
            initialValue: _mes.month,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Mes'),
            items: [
              for (var mes = 1; mes <= 12; mes++)
                DropdownMenuItem(value: mes, child: Text(_nombresMes[mes - 1])),
            ],
            onChanged: (mes) {
              if (mes == null) return;
              setState(() => _mes = DateTime(_mes.year, mes));
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<int>(
            initialValue: _mes.year,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Año'),
            items: [
              for (final anio in anios) DropdownMenuItem(value: anio, child: Text('$anio')),
            ],
            onChanged: (anio) {
              if (anio == null) return;
              setState(() => _mes = DateTime(anio, _mes.month));
            },
          ),
        ),
      ],
    );
  }

  Widget _ayuda(BuildContext context, String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        texto,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.paleta.textoSuave),
      ),
    );
  }

  Widget _numero(BuildContext context, String texto) {
    final esFrase = texto.length > 12;
    return Text(
      texto,
      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
        color: AppColors.terracota,
        fontWeight: FontWeight.w800,
        fontSize: esFrase ? 28 : 40,
      ),
    );
  }

  Widget _fila(BuildContext context, IconData icono, String etiqueta, int cantidad) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icono, color: context.paleta.lienzo),
          const SizedBox(width: 12),
          Expanded(
            child: Text(etiqueta, style: Theme.of(context).textTheme.titleMedium),
          ),
          Text(
            '$cantidad',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.terracota,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjeta(BuildContext context, {required String titulo, required IconData icono, required Widget hijo}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icono, color: context.paleta.lienzo),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    titulo,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: context.paleta.lienzo),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            hijo,
          ],
        ),
      ),
    );
  }
}
