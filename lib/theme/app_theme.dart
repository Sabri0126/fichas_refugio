import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

TextTheme _buildTextTheme(PaletaApp paleta) {
  final base = GoogleFonts.nunitoTextTheme().apply(
    bodyColor: paleta.texto,
    displayColor: paleta.texto,
  );

  return base.copyWith(
    headlineMedium: base.headlineMedium?.copyWith(fontSize: 28, fontWeight: FontWeight.w800),
    titleLarge: base.titleLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.w700),
    titleMedium: base.titleMedium?.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
    bodyMedium: base.bodyMedium?.copyWith(fontSize: 15, height: 1.4),
    labelMedium: base.labelMedium?.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
  );
}

ThemeData buildAppTheme({bool oscuro = false}) {
  final paleta = oscuro ? PaletaApp.oscura : PaletaApp.clara;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.navy,
    brightness: oscuro ? Brightness.dark : Brightness.light,
    primary: AppColors.navy,
    onPrimary: AppColors.arena,
    secondary: AppColors.terracota,
    onSecondary: Colors.white,
    surface: paleta.superficie,
    onSurface: paleta.texto,
    error: AppColors.error,
  );

  final textTheme = _buildTextTheme(paleta);

  OutlineInputBorder bordeInput(Color color, [double ancho = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: ancho),
      );

  WidgetStateProperty<Color?> seleccionTerracota({Color? noSeleccionado}) =>
      WidgetStateProperty.resolveWith((estados) {
        if (estados.contains(WidgetState.disabled)) return null;
        if (estados.contains(WidgetState.selected)) return AppColors.terracota;
        return noSeleccionado;
      });

  return ThemeData(
    useMaterial3: true,
    extensions: [paleta],
    colorScheme: colorScheme,
    scaffoldBackgroundColor: paleta.fondo,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.navy,
      foregroundColor: AppColors.arena,
      iconTheme: const IconThemeData(color: AppColors.arena),
      actionsIconTheme: const IconThemeData(color: AppColors.arena),
      titleTextStyle: textTheme.titleLarge?.copyWith(color: AppColors.arena),
    ),
    cardTheme: CardThemeData(
      color: paleta.superficie,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: paleta.borde),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: paleta.texto,
        side: BorderSide(color: paleta.borde),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: paleta.texto,
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: paleta.relleno,
      hintStyle: textTheme.bodyMedium?.copyWith(color: paleta.textoSuave),
      labelStyle: textTheme.bodyMedium?.copyWith(color: paleta.textoSuave),
      border: bordeInput(paleta.borde),
      enabledBorder: bordeInput(paleta.borde),
      focusedBorder: bordeInput(paleta.lienzo, 1.6),
      errorBorder: bordeInput(AppColors.error),
      focusedErrorBorder: bordeInput(AppColors.error, 1.6),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((estados) =>
          estados.contains(WidgetState.selected) ? Colors.white : null),
      trackColor: seleccionTerracota(),
      trackOutlineColor: WidgetStateProperty.resolveWith((estados) =>
          estados.contains(WidgetState.selected) ? AppColors.terracota : null),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: seleccionTerracota(),
      checkColor: const WidgetStatePropertyAll(Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: paleta.relleno,
      selectedColor: AppColors.terracota.withValues(alpha: oscuro ? 0.32 : 0.16),
      checkmarkColor: oscuro ? paleta.texto : AppColors.terracota,
      side: BorderSide(color: paleta.borde),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      labelStyle: textTheme.labelLarge?.copyWith(color: paleta.texto),
      secondaryLabelStyle: textTheme.labelLarge?.copyWith(color: paleta.texto),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(paleta.texto),
        backgroundColor: WidgetStateProperty.resolveWith((estados) {
          if (estados.contains(WidgetState.selected)) return paleta.relleno;
          return paleta.superficie;
        }),
        side: WidgetStatePropertyAll(BorderSide(color: paleta.borde)),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      showDragHandle: true,
      backgroundColor: paleta.superficie,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: oscuro
          ? Color.lerp(AppColors.terracota, Colors.black, 0.35)
          : AppColors.terracota,
      foregroundColor: Colors.white,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: paleta.superficie,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: paleta.borde),
      ),
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyMedium,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.navy,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(48, 48),
        elevation: 0,
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.arena,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: paleta.superficie,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: AppColors.navy,
      headerForegroundColor: AppColors.arena,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: paleta.superficie,
      dialBackgroundColor: paleta.relleno,
      hourMinuteColor: paleta.relleno,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    expansionTileTheme: const ExpansionTileThemeData(
      shape: Border(),
      collapsedShape: Border(),
    ),
    dividerTheme: DividerThemeData(color: paleta.borde),
  );
}
