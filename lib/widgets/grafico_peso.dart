import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../controllers/peso_controller.dart';
import '../models/peso_model.dart';
import '../theme/app_colors.dart';
import '../util/plataforma.dart';

/// Evolución del peso. Los puntos estimados se dibujan huecos.
class GraficoPeso extends StatelessWidget {
  final List<PesoModel> pesos;

  const GraficoPeso({super.key, required this.pesos});

  static const _alto = 200.0;
  static const _altoEjeX = 32.0;
  static const _separacionY = 36.0;

  @override
  Widget build(BuildContext context) {
    final ordenados = [...pesos]..sort((a, b) {
        final porFecha = a.fecha.compareTo(b.fecha);
        if (porFecha != 0) return porFecha;
        return a.id.compareTo(b.id);
      });
    if (ordenados.length < 2) return const SizedBox.shrink();

    final paleta = context.paleta;
    final kilos = ordenados.map((peso) => peso.kg);
    final minKg = kilos.reduce((a, b) => a < b ? a : b);
    final maxKg = kilos.reduce((a, b) => a > b ? a : b);
    final rango = maxKg - minKg;
    final margen = rango == 0 ? (maxKg * 0.1).clamp(0.5, 20.0) : rango * 0.1;
    final minY = (minKg - margen).clamp(0.0, minKg);
    final maxY = maxKg + margen;
    final etiquetasY = _etiquetasY(minY, maxY);
    final etiquetasEje = esWindows ? _espaciarEtiquetas(etiquetasY, minY, maxY) : etiquetasY;
    final intervaloY = etiquetasY.length < 2 ? (maxY - minY).clamp(0.5, 80.0) : (maxY - minY) / (etiquetasY.length - 1);
    final ticksEje = esWindows ? _ticksGanadores(etiquetasEje, minY, maxY, intervaloY) : const <double>[];
    final anchoEjeY = _anchoEjeY(etiquetasEje);
    final cruzaAnio = ordenados.first.fecha.year != ordenados.last.fecha.year;
    final colorLinea = paleta.lienzo;
    final hayEstimado = ordenados.any((peso) => peso.estimado);
    final estiloEje = TextStyle(fontSize: 11, color: paleta.textoSuave);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: _alto,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final anchoPlot = (constraints.maxWidth - anchoEjeY).clamp(0.0, constraints.maxWidth);
              final indicesX = _indicesFecha(ordenados.length, anchoPlot, cruzaAnio);
              return LineChart(
                LineChartData(
                  minX: 0,
                  maxX: (ordenados.length - 1).toDouble(),
                  minY: minY,
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
                        reservedSize: anchoEjeY,
                        interval: intervaloY,
                        getTitlesWidget: (valor, _) {
                          if (esWindows) {
                            final margen = (intervaloY * 0.08).clamp(0.001, 0.05);
                            final gana = ticksEje.any((tick) => (tick - valor).abs() <= margen);
                            if (!gana) return const SizedBox.shrink();
                            final texto = _textoSiCabe(valor, etiquetasEje, minY, maxY) ?? formatearKg(valor);
                            return Text(
                              texto,
                              maxLines: 1,
                              softWrap: false,
                              style: estiloEje,
                            );
                          }
                          if (!_cercaDeEtiqueta(valor, etiquetasY, intervaloY)) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            formatearKg(valor),
                            maxLines: 1,
                            softWrap: false,
                            style: estiloEje,
                          );
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
                          if (!indicesX.contains(indice)) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              _etiquetaFecha(ordenados[indice].fecha, cruzaAnio),
                              maxLines: 1,
                              softWrap: false,
                              style: estiloEje,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      tooltipBorderRadius: BorderRadius.circular(8),
                      tooltipBorder: BorderSide(color: paleta.borde),
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      maxContentWidth: 160,
                      getTooltipColor: (_) => paleta.superficie,
                      getTooltipItems: (spots) {
                        return [
                          for (final spot in spots)
                            spot.spotIndex < 0 || spot.spotIndex >= ordenados.length
                                ? null
                                : LineTooltipItem(
                                    _tooltip(ordenados[spot.spotIndex]),
                                    TextStyle(color: paleta.texto, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                        ];
                      },
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (var i = 0; i < ordenados.length; i++) FlSpot(i.toDouble(), ordenados[i].kg),
                      ],
                      isCurved: ordenados.length > 2,
                      preventCurveOverShooting: true,
                      color: colorLinea,
                      barWidth: 2.5,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        getDotPainter: (spot, percent, bar, index) {
                          final estimado = index >= 0 && index < ordenados.length && ordenados[index].estimado;
                          return FlDotCirclePainter(
                            radius: 4.5,
                            color: estimado ? Colors.transparent : colorLinea,
                            strokeWidth: 2,
                            strokeColor: estimado ? AppColors.terracota : colorLinea,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: colorLinea.withValues(alpha: 0.08),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        if (hayEstimado) ...[
          const SizedBox(height: 8),
          Text(
            'El punto hueco es un peso estimado.',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: paleta.textoSuave),
          ),
        ],
      ],
    );
  }

  /// Como máximo cuatro valores, con al menos 36 px entre rótulos.
  List<double> _etiquetasY(double minY, double maxY) {
    final span = maxY - minY;
    if (span <= 0) return [minY];
    final altoPlot = _alto - _altoEjeX;
    final huecos = (altoPlot / _separacionY).floor().clamp(1, 3);
    final textos = <String>{};
    final valores = <double>[];
    for (var i = 0; i <= huecos; i++) {
      final valor = minY + span * i / huecos;
      final texto = formatearKg(valor);
      if (texto.isEmpty || textos.contains(texto)) continue;
      textos.add(texto);
      valores.add(valor);
    }
    return valores;
  }

  /// Un solo tick por etiqueta, para que dos valores cercanos no se dibujen juntos.
  List<double> _ticksGanadores(List<double> etiquetas, double minY, double maxY, double intervalo) {
    if (etiquetas.isEmpty || intervalo <= 0) return etiquetas;
    final candidatos = <double>[minY, maxY];
    var tick = (minY / intervalo).floor() * intervalo;
    if (tick < minY - intervalo * 0.01) tick += intervalo;
    for (var i = 0; i < 24 && tick <= maxY + intervalo * 0.01; i++) {
      if (tick >= minY - 0.0001) candidatos.add(tick);
      tick += intervalo;
    }
    final span = (maxY - minY).abs();
    final altoPlot = _alto - _altoEjeX;
    final ganadores = <double>[];
    final usados = <int>{};
    for (final etiqueta in etiquetas) {
      var mejor = -1;
      var distancia = double.infinity;
      for (var i = 0; i < candidatos.length; i++) {
        if (usados.contains(i)) continue;
        final d = (candidatos[i] - etiqueta).abs();
        if (d < distancia) {
          distancia = d;
          mejor = i;
        }
      }
      if (mejor < 0 || span <= 0 || altoPlot <= 0) continue;
      final px = distancia / span * altoPlot;
      if (px > 14) continue;
      usados.add(mejor);
      ganadores.add(candidatos[mejor]);
    }
    return ganadores;
  }

  /// En Windows deja al menos 28 px entre rótulos para que no se pisen.
  List<double> _espaciarEtiquetas(List<double> valores, double minY, double maxY) {
    const minPx = 28.0;
    final span = maxY - minY;
    final altoPlot = _alto - _altoEjeX;
    if (valores.length < 2 || span <= 0 || altoPlot <= 0) return valores;
    bool cabe(double a, double b) => (a - b).abs() / span * altoPlot >= minPx;
    final elegidos = <double>[valores.first];
    for (var i = 1; i < valores.length - 1; i++) {
      if (cabe(valores[i], elegidos.last)) elegidos.add(valores[i]);
    }
    final ultimo = valores.last;
    if (cabe(ultimo, elegidos.last)) {
      elegidos.add(ultimo);
    } else if (elegidos.length == 1) {
      elegidos[0] = ultimo;
    } else {
      elegidos.removeLast();
      if (elegidos.isEmpty || cabe(ultimo, elegidos.last)) {
        elegidos.add(ultimo);
      } else {
        elegidos[elegidos.length - 1] = ultimo;
      }
    }
    return elegidos;
  }

  /// Solo el tick pegado a una etiqueta ya espaciada. El texto es el de esa etiqueta.
  String? _textoSiCabe(double valor, List<double> etiquetas, double minY, double maxY) {
    if (etiquetas.isEmpty) return null;
    final span = (maxY - minY).abs();
    final altoPlot = _alto - _altoEjeX;
    if (span <= 0 || altoPlot <= 0) return null;
    double? mejor;
    var distancia = double.infinity;
    for (final etiqueta in etiquetas) {
      final d = (valor - etiqueta).abs();
      if (d < distancia) {
        distancia = d;
        mejor = etiqueta;
      }
    }
    if (mejor == null) return null;
    final px = distancia / span * altoPlot;
    if (px > 12) return null;
    return formatearKg(mejor);
  }

  bool _cercaDeEtiqueta(double valor, List<double> etiquetas, double intervalo) {
    if (etiquetas.isEmpty) return false;
    final tolerancia = intervalo * 0.35;
    for (final etiqueta in etiquetas) {
      if ((valor - etiqueta).abs() <= tolerancia) return true;
    }
    return false;
  }

  double _anchoEjeY(List<double> etiquetas) {
    var caracteres = 2;
    for (final valor in etiquetas) {
      final largo = formatearKg(valor).length;
      if (largo > caracteres) caracteres = largo;
    }
    return (caracteres * 8.0 + 10).clamp(36.0, 56.0);
  }

  /// Primera y última siempre. La del medio solo si quedan 72 px (o más, si lleva año).
  Set<int> _indicesFecha(int total, double anchoPlot, bool cruzaAnio) {
    if (total <= 0) return const {};
    final ultimo = total - 1;
    if (total == 1) return {0};
    final medio = ultimo ~/ 2;
    final separacion = cruzaAnio ? 96.0 : 72.0;
    double px(int indice) => anchoPlot * indice / ultimo;
    final cabeMedio = medio != 0 &&
        medio != ultimo &&
        px(medio) - px(0) >= separacion &&
        px(ultimo) - px(medio) >= separacion;
    return {0, ultimo, if (cabeMedio) medio};
  }

  String _etiquetaFecha(DateTime fecha, bool cruzaAnio) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    if (!cruzaAnio) return '$dia/$mes';
    final anio = (fecha.year % 100).toString().padLeft(2, '0');
    return '$dia/$mes/$anio';
  }

  String _tooltip(PesoModel peso) {
    final aprox = peso.estimado ? ' aprox.' : '';
    final nota = peso.nota.trim();
    final base = '${PesoController.formatearFecha(peso.fecha)}\n${formatearKg(peso.kg)} kg$aprox';
    if (nota.isEmpty) return base;
    return '$base\n$nota';
  }
}
