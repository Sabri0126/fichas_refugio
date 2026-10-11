import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../main.dart';
import '../theme/app_colors.dart';
import 'ficha_detalle_perro.dart';
import 'pantalla_menu.dart';

class PantallaBloqueo extends StatefulWidget {
  const PantallaBloqueo({super.key});

  @override
  State<PantallaBloqueo> createState() => _PantallaBloqueoState();
}

class _PantallaBloqueoState extends State<PantallaBloqueo> {
  final LocalAuthentication _auth = LocalAuthentication();
  bool _autenticando = false;
  String? _mensajeError;

  @override
  void initState() {
    super.initState();
    // Intentar autenticación biométrica automáticamente al entrar
    WidgetsBinding.instance.addPostFrameCallback((_) => _desbloquear());
  }

  Future<void> _desbloquear() async {
    if (_autenticando) return;
    setState(() {
      _autenticando = true;
      _mensajeError = null;
    });

    try {
      final disponible = await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
      if (!disponible) {
        setState(() => _mensajeError = 'Este dispositivo no soporta autenticación biométrica.');
        return;
      }

      final autenticado = await _auth.authenticate(
        localizedReason: 'Verificá tu identidad para acceder a Fichas Refugio',
        biometricOnly: false, // permite PIN/patrón como fallback
        persistAcrossBackgrounding: true,
      );

      if (autenticado && mounted) {
        final idPendiente = EstadoNotificacion.payloadPendiente;
        EstadoNotificacion.payloadPendiente = null;

        navigatorKey.currentState?.pushReplacement(
          MaterialPageRoute(builder: (_) => const PantallaMenu()),
        );
        if (idPendiente != null && idPendiente.isNotEmpty) {
          navigatorKey.currentState?.push(
            MaterialPageRoute(builder: (_) => FichaDetallePerro(idDocumento: idPendiente)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _mensajeError = 'No se pudo autenticar. Intentá de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _autenticando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/PortonRefugio.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.25),
                  Colors.black.withValues(alpha: 0.72),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 80,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Pantalla bloqueada',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontSize: 24,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Usá biometría o Windows Hello para acceder',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    if (_mensajeError != null) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Color.alphaBlend(
                            AppColors.error.withValues(alpha: 0.12),
                            AppColors.superficie,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.error),
                        ),
                        child: Text(
                          _mensajeError!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.error),
                        ),
                      ),
                    ],
                    const SizedBox(height: 36),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _autenticando ? null : _desbloquear,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.terracota,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(52),
                        ),
                        icon: _autenticando
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Icon(Icons.fingerprint),
                        label: Text(_autenticando ? 'Verificando...' : 'Desbloquear'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
