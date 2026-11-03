part of '../ficha_detalle_perro.dart';

/// Foto a pantalla completa, con la descripción debajo y fuera del zoom.
class VisorFoto extends StatelessWidget {
  final String url;
  final String? descripcion;

  /// Imagen ya cargada. La usa el test para no salir a la red.
  final ImageProvider? imagen;

  const VisorFoto({super.key, required this.url, this.descripcion, this.imagen});

  @override
  Widget build(BuildContext context) {
    final pie = descripcionFotoVisible(descripcion);
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                clipBehavior: Clip.none,
                boundaryMargin: const EdgeInsets.all(double.infinity),
                child: SizedBox(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  child: Image(
                    image: imagen ?? NetworkImage(url),
                    fit: BoxFit.contain,
                  ),
                ),
              );
            },
          ),
        ),
        if (pie != null)
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.3),
            child: ColoredBox(
              color: const Color(0xB8000000),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(
                      pie,
                      style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.35),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _VisorEstudio extends ConsumerWidget {
  final String ruta;
  final String? descripcion;
  final Uint8List? inicial;

  const _VisorEstudio({required this.ruta, this.descripcion, this.inicial});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(estudioBytesProvider(ruta));
    final bytes = async.asData?.value ?? inicial;
    if (async.hasError || (async.hasValue && bytes == null)) {
      return const Center(child: Icon(Icons.broken_image_outlined, color: Colors.white));
    }
    if (bytes == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    return VisorFoto(url: '', descripcion: descripcion, imagen: MemoryImage(bytes));
  }
}
