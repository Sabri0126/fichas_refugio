import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/contacto_veterinario_model.dart';
import 'firestore_providers.dart';

/// Se suelta al salir de la pantalla. Al abrirla, el spinner es el de hoy.
final veterinariasProvider = StreamProvider.autoDispose<List<ContactoVeterinarioModel>>((ref) {
  return ref.watch(veterinariaControllerProvider).observar();
}, retry: (_, _) => null);
