part of '../ficha_detalle_perro.dart';

class _CuandoHayaLocale extends ConsumerWidget {
  final Widget child;

  const _CuandoHayaLocale({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeCalendarioProvider);
    if (locale.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return child;
  }
}
