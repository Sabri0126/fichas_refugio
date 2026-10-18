/// El Refugio Milagros de Amor se fundó este día.
final fundacionRefugio = DateTime(2000, 4, 29);

/// Años ya cumplidos desde [fundacionRefugio]. Antes del 29 de abril resta uno.
int calcularAniosServicio([DateTime? hoy]) {
  final ahora = hoy ?? DateTime.now();
  final dia = DateTime(ahora.year, ahora.month, ahora.day);
  var anios = dia.year - fundacionRefugio.year;
  final cumple = DateTime(dia.year, fundacionRefugio.month, fundacionRefugio.day);
  if (dia.isBefore(cumple)) anios--;
  if (anios < 0) return 0;
  return anios;
}

/// Línea del menú. Un año se lee en singular.
String textoAniosCuidando(int anios) {
  if (anios == 1) return '1 año cuidando perritos';
  return '$anios años cuidando perritos';
}
