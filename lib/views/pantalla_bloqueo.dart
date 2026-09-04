import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../main.dart';
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
          Container(color: Colors.black.withValues(alpha: 0.6)),
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
                    const Text(
                      'Pantalla bloqueada',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Usá biometría o Windows Hello para acceder',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    if (_mensajeError != null) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          _mensajeError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                        ),
                      ),
                    ],
                    const SizedBox(height: 36),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _autenticando ? null : _desbloquear,
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
                        label: Text(
                          _autenticando ? 'Verificando...' : 'Desbloquear',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepOrange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
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
