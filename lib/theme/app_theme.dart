import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

TextTheme _buildTextTheme() {
  final base = GoogleFonts.nunitoTextTheme().apply(
    bodyColor: AppColors.texto,
    displayColor: AppColors.texto,
  );

  return base.copyWith(
    headlineMedium: base.headlineMedium?.copyWith(fontSize: 28, fontWeight: FontWeight.w800),
    titleLarge: base.titleLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.w700),
    titleMedium: base.titleMedium?.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
    bodyMedium: base.bodyMedium?.copyWith(fontSize: 15, height: 1.4),
    labelMedium: base.labelMedium?.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
  );
}

ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.navy,
    primary: AppColors.navy,
    onPrimary: AppColors.arena,
    secondary: AppColors.terracota,
    onSecondary: Colors.white,
    surface: AppColors.superficie,
    onSurface: AppColors.texto,
    error: AppColors.error,
  );

  final textTheme = _buildTextTheme();

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
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.arena,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.navy,
      foregroundColor: AppColors.arena,
      iconTheme: const IconThemeData(color: AppColors.arena),
      actionsIconTheme: const IconThemeData(color: AppColors.arena),
      titleTextStyle: textTheme.titleLarge?.copyWith(color: AppColors.arena),
    ),
    cardTheme: CardThemeData(
      color: AppColors.superficie,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.bordeTarjeta),
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
        foregroundColor: AppColors.navy,
        side: const BorderSide(color: AppColors.bordeInput),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.rellenoInput,
      border: bordeInput(AppColors.bordeInput),
      enabledBorder: bordeInput(AppColors.bordeInput),
      focusedBorder: bordeInput(AppColors.navy, 1.6),
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
      selectedColor: AppColors.terracota.withValues(alpha: 0.16),
      checkmarkColor: AppColors.terracota,
      side: const BorderSide(color: AppColors.bordeInput),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      labelStyle: textTheme.labelLarge,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      showDragHandle: true,
      backgroundColor: AppColors.superficie,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.terracota,
      foregroundColor: Colors.white,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.bordeTarjeta),
  );
}
