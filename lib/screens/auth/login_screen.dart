import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';

/// Pantalla de login/registro previa al resto de la app (ver
/// `RallyStatsApp` en `main.dart`). Controla que una misma cuenta no se
/// use en más de un dispositivo a la vez (`AuthService`).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _registering = false;
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_registering) {
        await AuthService.instance.register(email: _email.text.trim(), password: _password.text);
      } else {
        await AuthService.instance.signIn(email: _email.text.trim(), password: _password.text);
      }
      // Si el login/registro sale bien, `authStateChanges` en `main.dart`
      // saca esta pantalla automáticamente.
    } on DeviceConflictException catch (e) {
      setState(() => _error = e.toString());
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _friendlyAuthError(e));
    } catch (e) {
      setState(() => _error = 'No se pudo conectar. Revisá tu conexión a internet.\n($e)');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email o contraseña incorrectos.';
      case 'email-already-in-use':
        return 'Ya existe una cuenta con ese email.';
      case 'weak-password':
        return 'La contraseña tiene que tener al menos 6 caracteres.';
      case 'invalid-email':
        return 'El email no es válido.';
      default:
        return 'Error de autenticación (${e.code}).';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.asset('assets/icon/app_icon_petals.png', width: 72, height: 72),
                    const SizedBox(height: 12),
                    Text(
                      _registering ? 'Crear cuenta' : 'Iniciar sesión',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'La cuenta solo puede estar activa en un dispositivo a la vez.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                      validator: (v) =>
                          (v == null || !v.contains('@')) ? 'Ingresá un email válido' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      decoration:
                          const InputDecoration(labelText: 'Contraseña', border: OutlineInputBorder()),
                      validator: (v) =>
                          (v == null || v.length < 6) ? 'Al menos 6 caracteres' : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_registering ? 'Crear cuenta' : 'Entrar'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _busy ? null : () => setState(() => _registering = !_registering),
                      child: Text(_registering
                          ? '¿Ya tenés cuenta? Iniciar sesión'
                          : '¿No tenés cuenta? Crear una'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
