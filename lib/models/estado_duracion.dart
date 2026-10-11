enum FaseTratamiento { indefinido, noIniciado, enCurso, ultimoDia, finalizado }

class EstadoDuracion {
  final FaseTratamiento fase;
  final int diaActual;
  final int total;
  final int restantes;
  final DateTime? ultimoDia;
  final int diasParaInicio;

  const EstadoDuracion({
    required this.fase,
    this.diaActual = 0,
    this.total = 0,
    this.restantes = 0,
    this.ultimoDia,
    this.diasParaInicio = 0,
  });
}
