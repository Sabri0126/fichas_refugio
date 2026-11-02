import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:fichas_refugio/providers/firestore_providers.dart';
import 'package:fichas_refugio/providers/veterinarias_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ordena por nombre e ignora un documento inválido', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('veterinarias').doc('b').set({
      'nombre': 'Zeta',
      'ubicacion': 'Centro',
      'telefono': '111',
    });
    await firestore.collection('veterinarias').doc('a').set({
      'nombre': 'alfa',
      'ubicacion': 'Norte',
      'telefono': '222',
    });
    await firestore.collection('veterinarias').doc('roto').set({
      'nombre': '',
      'ubicacion': '',
      'telefono': '',
    });

    final container = ProviderContainer(
      overrides: [firestoreProvider.overrideWithValue(firestore)],
    );
    addTearDown(container.dispose);
    container.listen(veterinariasProvider, (_, _) {});

    List<String>? nombres;
    for (var i = 0; i < 20; i++) {
      nombres = container.read(veterinariasProvider).asData?.value.map((contacto) => contacto.nombre).toList();
      if (nombres != null) break;
      await pumpEventQueue();
    }

    expect(nombres, ['alfa', 'Zeta']);
  });
}
