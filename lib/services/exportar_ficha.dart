import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/egreso_model.dart';
import '../models/perro_model.dart';
import '../models/peso_model.dart';
import '../models/recordatorio_model.dart';
import '../models/tratamiento_model.dart';

/// Arma el PDF de una ficha y lo abre en la hoja de compartir.
abstract final class ExportarFicha {
  static const _navy = PdfColor.fromInt(0xFF2F4565);
  static const _arena = PdfColor.fromInt(0xFFEADDC0);
  static const _terracota = PdfColor.fromInt(0xFFC8553D);
  static const _texto = PdfColor.fromInt(0xFF191919);
  static const _suave = PdfColor.fromInt(0xFF6B6459);
  static const _relleno = PdfColor.fromInt(0xFFFAF8F3);
  static const _borde = PdfColor.fromInt(0xFFE2D5B5);

  static Future<void> compartir(PerroModel perro, {required String edad}) async {
    final archivo = await _archivo(perro, edad: edad);
    await Share.shareXFiles(
      [XFile(archivo.path, mimeType: 'application/pdf')],
      subject: 'Ficha de ${perro.nombre}',
      text: textoCompartir(perro, edad: edad),
    );
  }

  /// Texto que acompaña al PDF y a la imagen al compartir.
  static String textoCompartir(PerroModel perro, {required String edad}) {
    return _textoCorto(perro, edad);
  }

  static String _textoCorto(PerroModel perro, String edad) {
    final nombre = perro.nombre.trim().isEmpty ? 'Sin nombre' : perro.nombre.trim();
    final sexo = perro.sexo == 'hembra' ? 'Hembra' : 'Macho';
    final castrado = _castracion(perro);
    return '$nombre · $sexo · $edad · $castrado. Refugio Milagros de Amor.';
  }

  static pw.Font? _regular;
  static pw.Font? _bold;

  static Future<pw.ThemeData> _tema() async {
    final regular = _regular ??= pw.Font.ttf(await rootBundle.load('google_fonts/Nunito-Regular.ttf'));
    final bold = _bold ??= pw.Font.ttf(await rootBundle.load('google_fonts/Nunito-Bold.ttf'));
    return pw.ThemeData.withFont(base: regular, bold: bold);
  }

  /// Bytes del PDF, para compartir y para comprobar que el texto entra.
  ///
  /// [descargar] reemplaza la descarga de fotos. Los tests lo usan para
  /// inyectar una imagen o simular un fallo sin salir a la red.
  static Future<Uint8List> generar({
    required PerroModel perro,
    required String edad,
    Future<pw.MemoryImage?> Function(String url)? descargar,
  }) async {
    final doc = pw.Document();
    final nombre = perro.nombre.trim().isEmpty ? 'Sin nombre' : perro.nombre.trim();
    final bajar = descargar ?? _foto;
    final perfilFuture = _bajar(perro.fotoPerfil, bajar);
    final galeriaFuture = Future.wait(perro.galeria.map((foto) => _bajarConPie(foto, bajar)));
    final estudiosFuture = Future.wait(perro.galeriaEstudios.map((foto) => _bajarConPie(foto, bajar)));
    final foto = await perfilFuture;
    final galeria = (await galeriaFuture).whereType<_FotoPdf>().toList();
    final estudios = (await estudiosFuture).whereType<_FotoPdf>().toList();
    final tema = await _tema();

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(36, 32, 36, 40),
          theme: tema,
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'Refugio Milagros de Amor  ·  ${context.pageNumber}',
            style: const pw.TextStyle(fontSize: 9, color: _suave),
          ),
        ),
        build: (context) => [
          _encabezado(),
          pw.SizedBox(height: 18),
          if (foto != null) ...[
            pw.Center(
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: _borde, width: 1),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                padding: const pw.EdgeInsets.all(4),
                child: pw.Image(foto, height: 180, fit: pw.BoxFit.contain),
              ),
            ),
            pw.SizedBox(height: 14),
          ],
          pw.Text(nombre, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: _navy)),
          pw.SizedBox(height: 10),
          _datos(perro, edad),
          pw.SizedBox(height: 16),
          _seccion('Historia', perro.historia.trim().isEmpty ? 'Sin historia cargada.' : perro.historia.trim()),
          if (_textoFamiliares(perro.parientes) case final familiares?) _seccion('Familiares', familiares),
          _seccion('Ficha médica', perro.fichaMedica.trim().isEmpty ? 'Sin ficha médica.' : perro.fichaMedica.trim()),
          if (perro.pesos.isNotEmpty) _pesos(perro.pesos),
          if (perro.tratamientos.isNotEmpty) _tratamientos(perro.tratamientos),
          if (perro.recordatorios.isNotEmpty) _recordatorios(perro.recordatorios),
          if (perro.estado == 'egresado' || perro.historialEgresos.isNotEmpty) _egresos(perro),
          if (galeria.isNotEmpty) ...[
            pw.NewPage(),
            _titulo('Galería de fotos'),
            pw.SizedBox(height: 10),
            ..._filasGaleria(galeria),
          ],
          if (estudios.isNotEmpty) ...[
            pw.NewPage(),
            _titulo('Estudios y registros médicos'),
            pw.SizedBox(height: 10),
            for (final estudio in estudios)
              _bloqueEstudio(estudio, alto: estudios.length == 1 ? _altoEstudioUnico : _altoEstudio),
          ],
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _encabezado() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: pw.BoxDecoration(
        color: _navy,
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Refugio Milagros de Amor',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: _arena),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            'Ficha de perfil canino',
            style: const pw.TextStyle(fontSize: 12, color: _arena),
          ),
        ],
      ),
    );
  }

  static pw.Widget _datos(PerroModel perro, String edad) {
    final sexo = perro.sexo == 'hembra' ? 'Hembra' : 'Macho';
    final chips = <String>[
      sexo,
      edad,
      _castracion(perro),
      perro.enCasa ? 'En casa' : 'En el refugio',
      'Ingreso: ${_fecha(perro.fechaIngreso)}',
      if (perro.fechaFallecimiento != null) 'Fallecimiento: ${_fecha(perro.fechaFallecimiento)}',
      _estado(perro),
    ];
    return pw.Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final chip in chips)
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: pw.BoxDecoration(
              color: _relleno,
              border: pw.Border.all(color: _borde),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Text(chip, style: const pw.TextStyle(fontSize: 10, color: _texto)),
          ),
      ],
    );
  }

  /// Relación tal como está guardada: «Luna — Madre».
  static String? _textoFamiliares(List<Map<String, dynamic>> parientes) {
    final lineas = <String>[];
    for (final familiar in parientes) {
      final nombre = (familiar['nombre'] ?? '').toString().trim();
      if (nombre.isEmpty) continue;
      final relacion = (familiar['relacion'] ?? '').toString().trim();
      lineas.add(relacion.isEmpty ? nombre : '$nombre — $relacion');
    }
    if (lineas.isEmpty) return null;
    return lineas.join('\n');
  }

  static pw.Widget _seccion(String titulo, String cuerpo) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 14),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _titulo(titulo),
          pw.SizedBox(height: 6),
          pw.Text(cuerpo, style: const pw.TextStyle(fontSize: 11, color: _texto, lineSpacing: 3)),
        ],
      ),
    );
  }

  static pw.Widget _titulo(String titulo) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(titulo, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: _navy)),
        pw.SizedBox(height: 3),
        pw.Container(width: 36, height: 2, color: _terracota),
      ],
    );
  }

  static pw.Widget _pesos(List<PesoModel> pesos) {
    final ordenados = [...pesos]..sort((a, b) => b.fecha.compareTo(a.fecha));
    final ultimo = ordenados.first;
    final aprox = ultimo.estimado ? ' (aprox.)' : '';
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 14),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _titulo('Peso'),
          pw.SizedBox(height: 6),
          pw.Text(
            'Último: ${formatearKg(ultimo.kg)} kg$aprox  ·  ${_fecha(ultimo.fecha)}',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _texto),
          ),
          pw.SizedBox(height: 6),
          for (final peso in ordenados)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Text(
                _lineaPeso(peso),
                style: const pw.TextStyle(fontSize: 11, color: _texto),
              ),
            ),
        ],
      ),
    );
  }

  static String _lineaPeso(PesoModel peso) {
    final nota = peso.nota.trim();
    final aprox = peso.estimado ? ' (aprox.)' : '';
    final base = '${_fecha(peso.fecha)}   ${formatearKg(peso.kg)} kg$aprox';
    if (nota.isEmpty) return base;
    return '$base   $nota';
  }

  static pw.Widget _tratamientos(List<TratamientoModel> tratamientos) {
    final diarios = tratamientos.where((t) => t.categoria == 'diario').toList();
    final eventos = tratamientos.where((t) => t.categoria != 'diario').toList();
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 14),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _titulo('Tratamientos'),
          pw.SizedBox(height: 8),
          if (diarios.isNotEmpty) ...[
            pw.Text('Medicación diaria', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _suave)),
            pw.SizedBox(height: 6),
            for (final tratamiento in diarios) _tarjetaTratamiento(tratamiento),
          ],
          if (eventos.isNotEmpty) ...[
            if (diarios.isNotEmpty) pw.SizedBox(height: 4),
            pw.Text('Eventos y visitas', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _suave)),
            pw.SizedBox(height: 6),
            for (final tratamiento in eventos) _tarjetaTratamiento(tratamiento),
          ],
        ],
      ),
    );
  }

  static pw.Widget _tarjetaTratamiento(TratamientoModel tratamiento) {
    final nombre = tratamiento.medicacion.trim().isEmpty ? 'Sin nombre' : tratamiento.medicacion.trim();
    final indicaciones = tratamiento.indicaciones.trim();
    final notas = tratamiento.notas.trim();
    final detalle = <String>[
      _categoria(tratamiento.categoria),
      if (tratamiento.fechaInicio != null) 'Desde ${_fecha(tratamiento.fechaInicio)}',
      if (tratamiento.categoria == 'diario' && tratamiento.diasDuracion > 0) '${tratamiento.diasDuracion} días',
      if (tratamiento.categoria == 'diario') (tratamiento.activo ? 'Activo' : 'Pausado'),
    ];
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 6),
      padding: const pw.EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: pw.BoxDecoration(
        color: _relleno,
        border: pw.Border.all(color: _borde),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(nombre, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _texto)),
          pw.SizedBox(height: 2),
          pw.Text(detalle.join('  ·  '), style: const pw.TextStyle(fontSize: 9, color: _suave)),
          if (indicaciones.isNotEmpty) ...[
            pw.SizedBox(height: 3),
            pw.Text(indicaciones, style: const pw.TextStyle(fontSize: 11, color: _texto, lineSpacing: 2)),
          ],
          if (notas.isNotEmpty) ...[
            pw.SizedBox(height: 3),
            pw.Text(notas, style: const pw.TextStyle(fontSize: 11, color: _texto, lineSpacing: 2)),
          ],
        ],
      ),
    );
  }

  static pw.Widget _recordatorios(List<RecordatorioModel> lista) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 14),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _titulo('Recordatorios'),
          pw.SizedBox(height: 6),
          for (final recordatorio in lista)
            pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      recordatorio.titulo,
                      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _texto),
                    ),
                    pw.Text(_cuando(recordatorio.fechaHora), style: const pw.TextStyle(fontSize: 9, color: _suave)),
                    if (recordatorio.nota.trim().isNotEmpty)
                      pw.Text(recordatorio.nota.trim(), style: const pw.TextStyle(fontSize: 11, color: _texto)),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  static pw.Widget _egresos(PerroModel perro) {
    final entradas = <EgresoModel>[
      if (perro.estado == 'egresado')
        EgresoModel(
          motivo: perro.motivoEgreso,
          fechaEgreso: perro.fechaEgreso,
          nota: perro.notaEgreso,
        ),
      ...perro.historialEgresos,
    ];
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _titulo('Egresos'),
        pw.SizedBox(height: 6),
        if (entradas.isEmpty)
          pw.Text('Sin egresos registrados.', style: const pw.TextStyle(fontSize: 11, color: _suave))
        else
          for (final egreso in entradas)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Text(
                _lineaEgreso(egreso),
                style: const pw.TextStyle(fontSize: 11, color: _texto, lineSpacing: 2),
              ),
            ),
      ],
    );
  }

  static String _lineaEgreso(EgresoModel egreso) {
    final motivo = _motivo(egreso.motivo);
    final partes = <String>[
      if (motivo.isNotEmpty) motivo,
      'Egreso: ${_fecha(egreso.fechaEgreso)}',
      if (egreso.fechaRegreso != null) 'Regreso: ${_fecha(egreso.fechaRegreso)}',
    ];
    final nota = egreso.nota?.trim() ?? '';
    final linea = partes.join('  ·  ');
    return nota.isEmpty ? linea : '$linea\n$nota';
  }

  static String _castracion(PerroModel perro) {
    final hembra = perro.sexo == 'hembra';
    if (perro.castrado) return hembra ? 'Castrada' : 'Castrado';
    return hembra ? 'No castrada' : 'No castrado';
  }

  static String _estado(PerroModel perro) {
    return switch (perro.estado) {
      'inactivo' => 'Fallecido',
      'egresado' => _motivo(perro.motivoEgreso).isEmpty ? 'Egresado' : _motivo(perro.motivoEgreso),
      _ => 'Activo',
    };
  }

  static String _motivo(String? motivo) {
    return switch (motivo) {
      'adopcion' => 'Adoptado',
      'familia' => 'Volvió con su familia',
      _ => '',
    };
  }

  static String _categoria(String categoria) {
    return switch (categoria) {
      'diario' => 'Diario',
      'unico' => 'Aplicación única',
      'higiene' => 'Higiene',
      'evento' => 'Evento médico',
      'veterinaria' => 'Veterinaria',
      'vacuna' => 'Vacuna',
      _ => categoria,
    };
  }

  static String _fecha(DateTime? fecha) {
    if (fecha == null) return 'Sin fecha';
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    return '$dia/$mes/${fecha.year}';
  }

  static String _cuando(DateTime fecha) {
    final hora = fecha.hour.toString().padLeft(2, '0');
    final minuto = fecha.minute.toString().padLeft(2, '0');
    return '${_fecha(fecha)}  $hora:$minuto';
  }

  static Future<File> _archivo(PerroModel perro, {required String edad}) async {
    final nombre = perro.nombre.trim().isEmpty ? 'Sin nombre' : perro.nombre.trim();
    final bytes = await generar(perro: perro, edad: edad);
    final dir = await getTemporaryDirectory();
    final seguro = nombre.replaceAll(RegExp(r'[^\w\-]+'), '_');
    final archivo = File('${dir.path}/ficha_$seguro.pdf');
    await archivo.writeAsBytes(bytes);
    return archivo;
  }

  static Future<pw.MemoryImage?> _foto(String url) async {
    if (url.isEmpty) return null;
    try {
      final respuesta = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (respuesta.statusCode != 200 || respuesta.bodyBytes.isEmpty) return null;
      return pw.MemoryImage(respuesta.bodyBytes);
    } catch (_) {
      return null;
    }
  }

  static Future<pw.MemoryImage?> _bajar(
    String? url,
    Future<pw.MemoryImage?> Function(String url) descargar,
  ) {
    if (url == null || url.isEmpty) return Future.value(null);
    return descargar(url);
  }

  static Future<_FotoPdf?> _bajarConPie(
    Map<String, dynamic> foto,
    Future<pw.MemoryImage?> Function(String url) descargar,
  ) async {
    final imagen = await _bajar(foto['url']?.toString(), descargar);
    if (imagen == null) return null;
    return _FotoPdf(imagen, _pieFoto(foto));
  }

  static String _pieFoto(Map<String, dynamic> foto) {
    final texto = (foto['texto'] ?? foto['descripcion'] ?? '').toString().trim();
    if (texto.isEmpty || texto == 'Sin descripción') return '';
    return texto;
  }

  static double get _anchoContenido => PdfPageFormat.a4.width - 72;

  static double get _anchoCelda => (_anchoContenido - 12) / 2;

  static double get _altoCelda => _anchoCelda * 3 / 4;

  static const _altoEstudio = 330.0;

  static const _altoEstudioUnico = 640.0;

  static List<pw.Widget> _filasGaleria(List<_FotoPdf> fotos) {
    final filas = <pw.Widget>[];
    for (var i = 0; i < fotos.length; i += 2) {
      final derecha = i + 1 < fotos.length ? fotos[i + 1] : null;
      filas.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 10),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _celdaGaleria(fotos[i]),
              pw.SizedBox(width: 12),
              if (derecha != null) _celdaGaleria(derecha) else pw.SizedBox(width: _anchoCelda),
            ],
          ),
        ),
      );
    }
    return filas;
  }

  static pw.Widget _celdaGaleria(_FotoPdf foto) {
    return pw.SizedBox(
      width: _anchoCelda,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: _anchoCelda,
            height: _altoCelda,
            padding: const pw.EdgeInsets.all(4),
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              color: _relleno,
              border: pw.Border.all(color: _borde),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Image(foto.imagen, fit: pw.BoxFit.contain),
          ),
          if (foto.pie.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              foto.pie,
              maxLines: 2,
              style: const pw.TextStyle(fontSize: 9, color: _suave),
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _bloqueEstudio(_FotoPdf foto, {required double alto}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (foto.pie.isNotEmpty) ...[
            pw.Text(
              foto.pie,
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _navy),
            ),
            pw.SizedBox(height: 4),
          ],
          pw.Container(
            width: _anchoContenido,
            height: alto,
            padding: const pw.EdgeInsets.all(6),
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              border: pw.Border.all(color: _borde),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Image(foto.imagen, fit: pw.BoxFit.contain),
          ),
        ],
      ),
    );
  }
}

class _FotoPdf {
  const _FotoPdf(this.imagen, this.pie);

  final pw.MemoryImage imagen;
  final String pie;
}
