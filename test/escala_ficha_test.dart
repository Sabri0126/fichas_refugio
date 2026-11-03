import 'package:fichas_refugio/providers/escala_ficha_provider.dart';
import 'package:fichas_refugio/providers/theme_mode_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('el notifier persiste y respeta los límites', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(container.read(escalaFichaProvider), escalaFichaMin);

    await container.read(escalaFichaProvider.notifier).agrandar();
    expect(container.read(escalaFichaProvider), closeTo(1.15, 0.001));
    expect(prefs.getDouble(claveEscalaFicha), closeTo(1.15, 0.001));

    await container.read(escalaFichaProvider.notifier).fijar(9);
    expect(container.read(escalaFichaProvider), escalaFichaMax);

    await container.read(escalaFichaProvider.notifier).fijar(0.1);
    expect(container.read(escalaFichaProvider), escalaFichaMin);

    await container.read(escalaFichaProvider.notifier).normal();
    expect(container.read(escalaFichaProvider), escalaFichaMin);
  });

  test('la escala efectiva respeta el tope 2.0', () {
    expect(escalaFichaEfectiva(1.6, 1.8), escalaFichaTopeEfectivo);
    expect(escalaFichaEfectiva(1.0, 1.0), 1.0);
    expect(escalaFichaEfectiva(1.3, 1.0), closeTo(1.3, 0.001));
  });
}
