import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../main.dart';
import '../models/dosis_avisada.dart';
import '../providers/auth_providers.dart';
import '../services/cerrar_sesion.dart';
import '../services/mensaje_login.dart';
import '../theme/app_colors.dart';
import 'ficha_detalle_perro.dart';
import 'pantalla_login.dart';
import 'pantalla_menu.dart';

class PantallaBloqueo extends ConsumerStatefulWidget {
  const PantallaBloqueo({super.key});

  @override
  ConsumerState<PantallaBloqueo> createState() => _PantallaBloqueoState();
}

class _PantallaBloqueoState extends ConsumerState<PantallaBloqueo> {
  bool _autenticando = false;
  String? _mensajeError;

  LocalAuthentication get _auth => ref.read(localAuthProvider);

  @override
  void initState() {
    super.initState();
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
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );

      if (autenticado && mounted) {
        _entrar();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _mensajeError = 'No se pudo autenticar. Intentá de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _autenticando = false);
    }
  }

  void _entrar() {
    final idPendiente = EstadoNotificacion.payloadPendiente;
    EstadoNotificacion.payloadPendiente = null;

    navigatorKey.currentState?.pushReplacement(
      MaterialPageRoute(builder: (_) => const PantallaMenu()),
    );
    if (idPendiente != null && idPendiente.isNotEmpty) {
      final aviso = AvisoFicha.desdePayload(idPendiente);
      if (aviso != null) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => FichaDetallePerro(idDocumento: aviso.idPerro, dosisAvisada: aviso.dosis),
          ),
        );
      }
    }
  }

  Future<void> _ingresarConContrasena() async {
    final usuario = ref.read(firebaseAuthProvider).currentUser;
    final email = usuario?.email ?? '';
    if (usuario == null || email.isEmpty) {
      await _cerrarSesion();
      return;
    }

    final password = await showDialog<String>(
      context: context,
      builder: (context) => _DialogoContrasena(email: email),
    );
    if (password == null || !mounted) return;

    setState(() {
      _autenticando = true;
      _mensajeError = null;
    });
    try {
      await usuario.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
      if (!mounted) return;
      _entrar();
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _mensajeError = mensajeErrorLogin(e.code));
    } catch (_) {
      if (mounted) {
        setState(() => _mensajeError = 'No se pudo autenticar. Intentá de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _autenticando = false);
    }
  }

  Future<void> _cerrarSesion() async {
    await cerrarSesion(ref);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const PantallaLogin()),
      (_) => false,
    );
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
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _autenticando ? null : _ingresarConContrasena,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.7)),
                          minimumSize: const Size.fromHeight(48),
                        ),
                        icon: const Icon(Icons.password_outlined),
                        label: const Text('Ingresar con contraseña'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: _autenticando ? null : _cerrarSesion,
                        style: TextButton.styleFrom(foregroundColor: AppColors.arena),
                        icon: const Icon(Icons.logout),
                        label: const Text('Cerrar sesión'),
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

class _DialogoContrasena extends StatefulWidget {
  final String email;

  const _DialogoContrasena({required this.email});

  @override
  State<_DialogoContrasena> createState() => _DialogoContrasenaState();
}

class _DialogoContrasenaState extends State<_DialogoContrasena> {
  final _password = TextEditingController();
  bool _ver = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _aceptar() {
    final valor = _password.text;
    if (valor.isEmpty) return;
    Navigator.pop(context, valor);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ingresar con contraseña'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            child: Text(widget.email),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            autofocus: true,
            obscureText: !_ver,
            onSubmitted: (_) => _aceptar(),
            decoration: InputDecoration(
              labelText: 'Contraseña',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_ver ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _ver = !_ver),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _aceptar,
          child: const Text('Ingresar'),
        ),
      ],
    );
  }
}
