# 04 — Código de vistas clave (8 de 9)

Código fuente copiado tal cual. Cada bloque indica archivo y rango de líneas.

### `lib/views/pantalla_perros.dart` — parte 1/1, líneas 1–398 de 398

```dart
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../controllers/perro_controller.dart';
import '../models/perro_model.dart';
import '../services/notificaciones_service.dart';
import '../theme/app_colors.dart';
import '../theme/entrada_escalonada.dart';
import 'ficha_detalle_perro.dart';
import 'formulario_perro.dart';
import 'pantalla_login.dart';

class PantallaPerros extends StatefulWidget {
  final bool soloInactivos;

  const PantallaPerros({super.key, this.soloInactivos = false});

  @override
  State<PantallaPerros> createState() => _PantallaPerrosState();
}

class _PantallaPerrosState extends State<PantallaPerros> {
  final PerroController _perroController = PerroController();
  final TextEditingController _busquedaController = TextEditingController();
  String _textoBusqueda = '';
  String _filtroUbicacion = 'Todos';
  StreamSubscription<List<PerroModel>>? _suscripcionTratamientos;

  @override
  void initState() {
    super.initState();
    final bool esInvitado = FirebaseAuth.instance.currentUser == null;
    // Los visitantes no deben programar notificaciones locales.
    if (!esInvitado) {
      _suscripcionTratamientos = _perroController.observarPerros().listen((perros) {
        final perrosConId = perros.map((p) => {...p.toMap(), 'id': p.id}).toList();
        NotificacionesService.instance.programarRecordatorios(perrosConId);
      });
    }
  }

  @override
  void dispose() {
    _suscripcionTratamientos?.cancel();
    _busquedaController.dispose();
    super.dispose();
  }

  Widget _estadoVacio(String texto, {IconData icono = Icons.pets}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.navy.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icono, size: 30, color: AppColors.navy),
            ),
            const SizedBox(height: 12),
            Text(
              texto,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textoSecundario),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool esInvitado = FirebaseAuth.instance.currentUser == null;

    return Scaffold(
      // --- SECCIÓN: AppBar (título y botón de cerrar sesión) ---
      appBar: AppBar(
        title: Text(
          widget.soloInactivos ? 'Difuntos' : 'Perritos del refugio',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.arena,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              if (!esInvitado) {
                await FirebaseAuth.instance.signOut();
              }
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const PantallaLogin()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // --- SECCIÓN: Barra de búsqueda por nombre ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _busquedaController,
              onChanged: (value) => setState(() => _textoBusqueda = value),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre...',
                prefixIcon: const Icon(Icons.search),
                fillColor: AppColors.superficie,
                suffixIcon: _textoBusqueda.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _busquedaController.clear();
                          setState(() => _textoBusqueda = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Todos'),
                  selected: _filtroUbicacion == 'Todos',
                  onSelected: (_) => setState(() => _filtroUbicacion = 'Todos'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Refugio'),
                  selected: _filtroUbicacion == 'Refugio',
                  onSelected: (_) => setState(() => _filtroUbicacion = 'Refugio'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('En casa'),
                  selected: _filtroUbicacion == 'En casa',
                  onSelected: (_) => setState(() => _filtroUbicacion = 'En casa'),
                ),
              ],
            ),
          ),
          // --- SECCIÓN: Listado de perros (filtrado, orden y grilla) ---
          Expanded(
            child: StreamBuilder<List<PerroModel>>(
        stream: _perroController.observarPerros(),
        builder: (context, AsyncSnapshot<List<PerroModel>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _estadoVacio(widget.soloInactivos ? 'No hay difuntos registrados.' : 'No hay perritos registrados aún.');
          }

          final perrosPorEstado = snapshot.data!.where((perro) {
            if (widget.soloInactivos) {
              return perro.estado == 'inactivo';
            } else {
              return perro.estado == 'activo';
            }
          }).toList();

          final totalEnCasa = perrosPorEstado.where((p) => p.enCasa).length;
          final totalRefugio = perrosPorEstado.length - totalEnCasa;

          final perros = perrosPorEstado.where((perro) {
            if (_filtroUbicacion == 'En casa') {
              return perro.enCasa;
            }
            if (_filtroUbicacion == 'Refugio') {
              return !perro.enCasa;
            }
            return true;
          }).where((perro) {
            if (_textoBusqueda.isEmpty) return true;
            return perro.nombre.toLowerCase().contains(_textoBusqueda.toLowerCase());
          }).toList();

          perros.sort((a, b) {
            final dtA = a.fechaIngreso;
            final dtB = b.fechaIngreso;
            if (dtA == null && dtB == null) return 0;
            if (dtA == null) return 1;
            if (dtB == null) return -1;
            return dtB.compareTo(dtA);
          });

          if (perros.isEmpty) {
            return _estadoVacio(
              _textoBusqueda.isNotEmpty ? 'No se encontraron resultados.' : widget.soloInactivos ? 'No hay difuntos registrados.' : 'No hay perritos registrados aún.',
              icono: _textoBusqueda.isNotEmpty ? Icons.search_off : Icons.pets,
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth >= 900
                  ? 3
                  : constraints.maxWidth >= 600
                      ? 2
                      : 1;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Text(
                      'Perritos del refugio ($totalRefugio) | En casa ($totalEnCasa)',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.navy),
                    ),
                  ),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 104),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.9,
                      ),
                      itemCount: perros.length,
                      itemBuilder: (context, index) {
                        final idDocumento = perros[index].id;
                        final perro = perros[index];
                        final estiloDato = Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                          height: 1.35,
                          color: Colors.white.withValues(alpha: 0.88),
                        );

                        return EntradaEscalonada(
                          indice: index,
                          child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FichaDetallePerro(idDocumento: idDocumento),
                              ),
                            );
                          },
                          child: Card(
                            margin: EdgeInsets.zero,
                            clipBehavior: Clip.antiAlias,
                            elevation: 3,
                            shadowColor: Colors.black.withValues(alpha: 0.35),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Positioned.fill(
                                  child: perro.fotoPerfil != null && perro.fotoPerfil!.isNotEmpty
                                      ? Image.network(
                                          perro.fotoPerfil!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => Container(
                                            color: Theme.of(context).colorScheme.primary,
                                            child: Icon(
                                              Icons.pets,
                                              color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.4),
                                              size: 80,
                                            ),
                                          ),
                                        )
                                      : Container(
                                          color: Theme.of(context).colorScheme.primary,
                                          child: Icon(
                                            Icons.pets,
                                            color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.4),
                                            size: 80,
                                          ),
                                        ),
                                ),
                                Positioned.fill(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        stops: const [0.0, 0.35, 0.65, 1.0],
                                        colors: [
                                          Colors.transparent,
                                          Colors.black.withValues(alpha: 0.10),
                                          Colors.black.withValues(alpha: 0.60),
                                          Colors.black.withValues(alpha: 0.90),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 12,
                                  right: 12,
                                  bottom: 12,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        perro.nombre.isNotEmpty ? perro.nombre : 'Sin nombre',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                          fontSize: 26,
                                          color: Colors.white,
                                          shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Fecha de ingreso: ${_perroController.formatearFecha(perro.fechaIngreso)}',
                                        style: estiloDato,
                                      ),
                                      Text(
                                        perro.sexo == 'hembra' ? 'Sexo: Hembra' : 'Sexo: Macho',
                                        style: estiloDato,
                                      ),
                                      Text(
                                        _perroController.formatearEdadTexto(perro),
                                        style: estiloDato,
                                      ),
                                      Text(
                                        perro.castrado ? 'Castrado: Sí' : 'Castrado: No',
                                        style: estiloDato,
                                      ),
                                      if (widget.soloInactivos && perro.fechaFallecimiento != null)
                                        Text(
                                          'Fallecimiento: ${_perroController.formatearFecha(perro.fechaFallecimiento)}',
                                          style: estiloDato,
                                        ),
                                    ],
                                  ),
                                ),
                                if (!esInvitado)
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.white),
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.black54,
                                      ),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => FormularioPerro(idDocumento: idDocumento, perroActual: perro),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
        ),
        ],
      ),
      // --- SECCIÓN: Botón flotante para dar de alta un nuevo perro ---
      floatingActionButton: esInvitado
          ? null
          : FloatingActionButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FormularioPerro())),
              tooltip: 'Nuevo ingreso',
              child: const Icon(Icons.add),
            ),
    );
  }
}
```

### `lib/theme/app_theme.dart` — parte 1/1, líneas 1–133 de 133

```dart
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
```

