import 'package:fichas_refugio/controllers/veterinaria_controller.dart';
import 'package:fichas_refugio/models/contacto_veterinario_model.dart';
import 'package:fichas_refugio/theme/app_colors.dart';
import 'package:fichas_refugio/views/pantalla_menu.dart';
import 'package:fichas_refugio/views/pantalla_veterinarias.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ContactoVeterinarioModel _contacto({
  String notas = 'Atiende urgencias',
  String email = '',
}) {
  return ContactoVeterinarioModel(
    id: 'v1',
    nombre: 'Ana Pérez',
    ubicacion: 'Av. San Martín 120',
    telefono: '+54 9 11 5555-5555',
    email: email,
    notas: notas,
  );
}

void main() {
  test('el mapa guarda los datos y los vuelve a leer', () {
    final contacto = _contacto(email: 'ana@vet.test');
    final leido = ContactoVeterinarioModel.fromMap(
      contacto.toMap(),
      contacto.id,
    );
    expect(leido.nombre, contacto.nombre);
    expect(leido.ubicacion, contacto.ubicacion);
    expect(leido.telefono, contacto.telefono);
    expect(leido.email, contacto.email);
    expect(leido.notas, contacto.notas);
    expect(leido.id, contacto.id);
  });

  test('fromMap sin email sigue leyendo el contacto', () {
    final leido = ContactoVeterinarioModel.fromMap({
      'nombre': 'Ana',
      'ubicacion': 'Centro',
      'telefono': '1155555555',
      'notas': '',
    }, 'v1');
    expect(leido.email, isEmpty);
  });

  test('toMap sin email no incluye la clave', () {
    final mapa = _contacto().toMap();
    expect(mapa.containsKey('email'), isFalse);
    expect(_contacto(email: 'ana@vet.test').toMap()['email'], 'ana@vet.test');
  });

  test('un contacto sin nombre no se lee', () {
    expect(
      () => ContactoVeterinarioModel.fromMap({
        'nombre': '  ',
        'ubicacion': 'Centro',
        'telefono': '1155555555',
      }, 'v1'),
      throwsFormatException,
    );
  });

  test('el teléfono con espacios y guiones queda listo para marcar', () {
    expect(
      VeterinariaController.uriTelefono('+54 9 11 5555-5555'),
      'tel:+5491155555555',
    );
    expect(
      VeterinariaController.uriTelefono('(011) 15-1234-5678'),
      'tel:0111512345678',
    );
  });

  test('un teléfono corto no se puede marcar', () {
    expect(VeterinariaController.uriTelefono('123'), isNull);
    expect(VeterinariaController.uriTelefono('sin número'), isNull);
    expect(
      VeterinariaController.validar(
        nombre: 'Ana',
        ubicacion: 'Centro',
        telefono: '123',
        email: '',
        notas: '',
      ),
      'El teléfono no se puede marcar.',
    );
  });

  test('el email vacío se acepta y el inválido no', () {
    expect(VeterinariaController.uriEmail(''), isNull);
    expect(VeterinariaController.uriEmail('ana@vet.test'), 'mailto:ana@vet.test');
    expect(
      VeterinariaController.validar(
        nombre: 'Ana',
        ubicacion: 'Centro',
        telefono: '1155555555',
        email: 'mal',
        notas: '',
      ),
      'El email no tiene un formato válido.',
    );
    expect(
      VeterinariaController.validar(
        nombre: 'Ana',
        ubicacion: 'Centro',
        telefono: '1155555555',
        email: '${'a' * 112}@vet.test',
        notas: '',
      ),
      'El email es demasiado largo.',
    );
  });

  test('las notas vacías no salen en el texto para compartir', () {
    expect(
      VeterinariaController.textoCompartir(_contacto()),
      'Ana Pérez\nAv. San Martín 120\nTeléfono: +54 9 11 5555-5555\nNotas: Atiende urgencias',
    );
    expect(
      VeterinariaController.textoCompartir(_contacto(notas: '   ', email: 'ana@vet.test')),
      'Ana Pérez\nAv. San Martín 120\nTeléfono: +54 9 11 5555-5555\nEmail: ana@vet.test',
    );
  });

  test('faltan el nombre y la ubicación', () {
    expect(
      VeterinariaController.validar(
        nombre: ' ',
        ubicacion: 'Centro',
        telefono: '1155555555',
        email: '',
        notas: '',
      ),
      'Ingresá el nombre del veterinario.',
    );
    expect(
      VeterinariaController.validar(
        nombre: 'Ana',
        ubicacion: ' ',
        telefono: '1155555555',
        email: '',
        notas: '',
      ),
      'Ingresá la ubicación de la veterinaria.',
    );
    expect(
      VeterinariaController.validar(
        nombre: 'Ana',
        ubicacion: 'Centro',
        telefono: '1155555555',
        email: '',
        notas: '',
      ),
      isNull,
    );
  });

  testWidgets('al tocar el contacto se puede llamar o compartir', (
    tester,
  ) async {
    var llamo = false;
    var compartio = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HojaContactoVeterinario(
            contacto: _contacto(),
            puedeLlamar: true,
            onLlamar: () => llamo = true,
            onCompartir: () => compartio = true,
          ),
        ),
      ),
    );

    expect(find.text('Llamar'), findsOneWidget);
    expect(find.text('Compartir'), findsOneWidget);
    expect(find.text('Ana Pérez'), findsOneWidget);
    expect(find.text('Atiende urgencias'), findsOneWidget);

    await tester.tap(find.text('Llamar'));
    await tester.tap(find.text('Compartir'));
    expect(llamo, isTrue);
    expect(compartio, isTrue);
  });

  testWidgets('el botón de veterinarias usa el color del menú con texto blanco', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          body: BotonMenu(
            label: 'Veterinarias y contactos',
            detalle: 'Llamar o compartir',
            icon: Icons.local_hospital_outlined,
            color: AppColors.veterinariasMenu,
            colorOscuro: AppColors.veterinariasMenuOscuro,
            onTap: () {},
          ),
        ),
      ),
    );

    final boton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(boton.style?.backgroundColor?.resolve({}), AppColors.veterinariasMenu);
    expect(boton.style?.foregroundColor?.resolve({}), Colors.white);
    expect(find.text('Veterinarias y contactos'), findsOneWidget);
  });

  testWidgets('en oscuro el botón de veterinarias usa el color oscuro', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: BotonMenu(
            label: 'Veterinarias y contactos',
            detalle: 'Llamar o compartir',
            icon: Icons.local_hospital_outlined,
            color: AppColors.veterinariasMenu,
            colorOscuro: AppColors.veterinariasMenuOscuro,
            onTap: () {},
          ),
        ),
      ),
    );

    final boton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(boton.style?.backgroundColor?.resolve({}), AppColors.veterinariasMenuOscuro);
    expect(boton.style?.foregroundColor?.resolve({}), Colors.white);
  });
}
