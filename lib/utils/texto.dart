/// Minúsculas sin tildes ni diéresis. La ñ se convierte en n.
String normalizarBusqueda(String texto) {
  final base = texto.toLowerCase();
  const desde = 'áàäâéèëêíìïîóòöôúùüûñ';
  const hacia = 'aaaaeeeeiiiioooouuuun';
  final buffer = StringBuffer();
  for (final rune in base.runes) {
    final letra = String.fromCharCode(rune);
    final i = desde.indexOf(letra);
    buffer.write(i >= 0 ? hacia[i] : letra);
  }
  return buffer.toString();
}
