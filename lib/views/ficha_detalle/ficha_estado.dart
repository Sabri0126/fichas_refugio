part of '../ficha_detalle_perro.dart';

/// Campos de la ficha. Los mixins de cada sección leen estos mismos datos.
mixin _FichaEstado on ConsumerState<FichaDetallePerro> {
  PerroController get _perroController => ref.read(perroControllerProvider);
  EstudioController get _estudioController => ref.read(estudioControllerProvider);
  TratamientoController get _tratamientoController => ref.read(tratamientoControllerProvider);
  RecordatorioController get _recordatorioController => ref.read(recordatorioControllerProvider);
  PesoController get _pesoController => ref.read(pesoControllerProvider);
  FotosService get _fotos => ref.read(fotosServiceProvider);
  final MarcaArchivado _marcaArchivado = MarcaArchivado();
  final Set<String> _cerrandoSeguimiento = {};
  bool _guardandoPeso = false;
  final PageController _controladorCarrusel = PageController();
  bool _subiendoFoto = false;
  bool _generandoPdf = false;
  bool _modoReordenar = false;
  int? _egresoEnCurso;
  int _paginaActual = 0;
  List<Map<String, dynamic>> _fotosReordenar = [];
  bool _hojaDosisMostrada = false;
  final ValueNotifier<PerroModel?> _perroVisible = ValueNotifier<PerroModel?>(null);
  final GlobalKey _claveSalud = GlobalKey();
  final GlobalKey _claveHistoria = GlobalKey();

  static const inicialesDia = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
  static const nombresDia = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
}
