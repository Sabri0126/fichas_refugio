import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../controllers/reportes_controller.dart';
import '../theme/app_colors.dart';

/// Línea de perros a cargo al cierre de cada año.
class GraficoPoblacion extends StatefulWidget {
  final List<PuntoPoblacion> puntos;
  final ValueChanged<PuntoPoblacion> alVer;

  const GraficoPoblacion({super.key, required this.puntos, required this.alVer});

  @override
  State<GraficoPoblacion> createState() => _GraficoPoblacionState();
}

class _GraficoPoblacionState extends State<GraficoPoblacion> {
  static const _alto = 200.0;
  static const _altoEjeX = 32.0;
  late int _indice;

  @override
  void initState() {
    super.initState();
    _indice = widget.puntos.length - 1;
  }

  @override
  void didUpdateWidget(GraficoPoblacion anterior) {
    super.didUpdateWidget(anterior);
    if (_indice >= widget.puntos.length) _indice = widget.puntos.length - 1;
  }

  @override
  Widget build(BuildContext context) {
    final puntos = widget.puntos;
    if (puntos.isEmpty) return const SizedBox.shrink();
    final paleta = context.paleta;
    final maximo = puntos.map((punto) => punto.quedaron).reduce((a, b) => a > b ? a : b);
    final maxY = maximo <= 4 ? 4.0 : (maximo * 1.2).ceilToDouble();
    final intervaloY = (maxY / 4).ceilToDouble().clamp(1.0, maxY);
    final colorLinea = paleta.lienzo;
    final estiloEje = TextStyle(fontSize: 11, color: paleta.textoSuave);
    final uno = puntos.length == 1;
    final elegido = puntos[_indice.clamp(0, puntos.length - 1)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: _alto,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final indices = _indicesAnio(puntos.length, constraints.maxWidth - 42);
              return LineChart(
                LineChartData(
                  minX: uno ? -0.5 : 0,
                  maxX: uno ? 0.5 : (puntos.length - 1).toDouble(),
                  minY: 0,
                  maxY: maxY,
                  clipData: const FlClipData.all(),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: intervaloY,
                    getDrawingHorizontalLine: (_) => FlLine(color: paleta.borde, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        interval: intervaloY,
                        getTitlesWidget: (valor, _) {
                          final entero = valor.round();
                          if ((valor - entero).abs() > 0.01) return const SizedBox.shrink();
                          return Text('$entero', maxLines: 1, softWrap: false, style: estiloEje);
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: _altoEjeX,
                        interval: 1,
                        getTitlesWidget: (valor, _) {
                          final indice = valor.round();
                          if ((valor - indice).abs() > 0.01) return const SizedBox.shrink();
                          if (indice < 0 || indice >= puntos.length || !indices.contains(indice)) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text('${puntos[indice].anio}', maxLines: 1, softWrap: false, style: estiloEje),
                          );
                        },
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    touchCallback: (evento, respuesta) {
                      final spots = respuesta?.lineBarSpots;
                      if (spots == null || spots.isEmpty) return;
                      final indice = spots.first.spotIndex;
                      if (indice < 0 || indice >= puntos.length || indice == _indice) return;
                      setState(() => _indice = indice);
                    },
                    touchTooltipData: LineTouchTooltipData(
                      tooltipBorderRadius: BorderRadius.circular(8),
                      tooltipBorder: BorderSide(color: paleta.borde),
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      maxContentWidth: 220,
                      getTooltipColor: (_) => paleta.superficie,
                      getTooltipItems: (spots) {
                        return [
                          for (final spot in spots)
                            spot.spotIndex < 0 || spot.spotIndex >= puntos.length
                                ? null
                                : LineTooltipItem(
                                    _detalle(puntos[spot.spotIndex]),
                                    TextStyle(color: paleta.texto, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                        ];
                      },
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (var i = 0; i < puntos.length; i++) FlSpot(i.toDouble(), puntos[i].quedaron.toDouble()),
                      ],
                      isCurved: puntos.length > 2,
                      preventCurveOverShooting: true,
                      color: colorLinea,
                      barWidth: 2.5,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        getDotPainter: (spot, percent, bar, index) {
                          final activo = index == _indice;
                          return FlDotCirclePainter(
                            radius: activo ? 5.5 : 3.5,
                            color: activo ? AppColors.terracota : colorLinea,
                            strokeWidth: 0,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(show: true, color: colorLinea.withValues(alpha: 0.08)),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => widget.alVer(elegido),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _detalle(elegido),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: paleta.texto),
                  ),
                ),
                Icon(Icons.chevron_right, color: paleta.textoSuave),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _detalle(PuntoPoblacion punto) {
    return '${punto.anio}: Entraron ${punto.entraron} · Salieron ${punto.salieron} · Quedaron ${punto.quedaron}';
  }

  /// Primera y última siempre. La del medio solo si quedan unos 72 px.
  Set<int> _indicesAnio(int total, double anchoPlot) {
    if (total <= 0) return const {};
    final ultimo = total - 1;
    if (total <= 2) return {0, if (total == 2) ultimo};
    final medio = ultimo ~/ 2;
    double px(int indice) => anchoPlot * indice / ultimo;
    final cabeMedio = px(medio) - px(0) >= 72 && px(ultimo) - px(medio) >= 72;
    return {0, ultimo, if (cabeMedio) medio};
  }
}
