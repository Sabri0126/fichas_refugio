import 'package:fichas_refugio/theme/app_theme.dart';
import 'package:fichas_refugio/theme/entrada_escalonada.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  testWidgets('el tema carga y EntradaEscalonada muestra el texto', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(
          body: EntradaEscalonada(
            indice: 0,
            child: Text('Fichas Refugio'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Fichas Refugio'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
