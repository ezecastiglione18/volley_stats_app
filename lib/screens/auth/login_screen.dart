import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../legal/privacy_policy_text.dart';
import '../../legal/terms_conditions_text.dart';
import '../../services/auth_service.dart';
import '../../widgets/legal_document_dialog.dart';

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
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _registering = false;
  bool _busy = false;
  bool _obscurePassword = true;
  bool _acceptedPrivacy = false;
  bool _acceptedTerms = false;
  String? _error;

  late final TapGestureRecognizer _privacyLinkRecognizer;
  late final TapGestureRecognizer _termsLinkRecognizer;

  @override
  void initState() {
    super.initState();
    _privacyLinkRecognizer = TapGestureRecognizer()..onTap = _openPrivacyPolicy;
    _termsLinkRecognizer = TapGestureRecognizer()..onTap = _openTermsAndConditions;
    // Si esta pantalla es la que aparece después de un `signOut` forzado por
    // `DeviceConflictException` (ver `AuthService.lastLoginError`), mostrar
    // ese mensaje: la instancia de `LoginScreen` que hizo el intento ya se
    // desmontó para cuando el conflicto se detectó, así que no pudo
    // mostrarlo ella misma.
    final pendingError = AuthService.instance.lastLoginError.value;
    if (pendingError != null) {
      _error = pendingError;
      AuthService.instance.lastLoginError.value = null;
    }
  }

  @override
  void dispose() {
    _privacyLinkRecognizer.dispose();
    _termsLinkRecognizer.dispose();
    super.dispose();
  }

  Future<void> _openPrivacyPolicy() async {
    final accepted = await showLegalDocumentDialog(
      context: context,
      title: 'Política de Privacidad',
      subtitle: 'Vigente desde $kPrivacyPolicyEffectiveDate · Versión $kPrivacyPolicyVersion',
      sections: privacyPolicySections,
    );
    if (accepted && mounted) setState(() => _acceptedPrivacy = true);
  }

  Future<void> _openTermsAndConditions() async {
    final accepted = await showLegalDocumentDialog(
      context: context,
      title: 'Términos y Condiciones',
      subtitle: 'Vigente desde $kTermsEffectiveDate · Versión $kTermsVersion',
      sections: termsConditionsSections,
    );
    if (accepted && mounted) setState(() => _acceptedTerms = true);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_registering && (!_acceptedPrivacy || !_acceptedTerms)) {
      setState(() => _error =
          'Tenés que aceptar la política de privacidad y los términos y condiciones para crear una cuenta.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_registering) {
        await AuthService.instance.register(
          email: _email.text.trim(),
          password: _password.text,
          firstName: _firstName.text.trim(),
          lastName: _lastName.text.trim(),
          privacyPolicyVersion: kPrivacyPolicyVersion,
          termsVersion: kTermsVersion,
        );
      } else {
        await AuthService.instance.signIn(email: _email.text.trim(), password: _password.text);
      }
      // Si el login/registro sale bien, `authStateChanges` en `main.dart`
      // saca esta pantalla automáticamente.
    } on DeviceConflictException catch (e) {
      // Normalmente esta pantalla ya se desmontó para cuando este catch se
      // ejecuta (ver `AuthService.lastLoginError`), así que este `setState`
      // es sobre todo defensivo; el mensaje real se muestra vía
      // `lastLoginError` en el `initState` de la próxima instancia.
      if (mounted) setState(() => _error = e.toString());
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _friendlyAuthError(e));
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo conectar. Revisá tu conexión a internet.\n($e)');
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

  Future<void> _showForgotPasswordDialog() async {
    final emailController = TextEditingController(text: _email.text.trim());
    final dialogFormKey = GlobalKey<FormState>();
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restablecer contraseña'),
        content: Form(
          key: dialogFormKey,
          child: TextFormField(
            controller: emailController,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
            validator: (v) => (v == null || !v.contains('@')) ? 'Ingresá un email válido' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (dialogFormKey.currentState!.validate()) {
                Navigator.of(context).pop(emailController.text.trim());
              }
            },
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    if (email == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AuthService.instance.sendPasswordResetEmail(email);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Te enviamos un email a $email con instrucciones para restablecer tu contraseña. '
            'Si no lo ves en la bandeja de entrada, revisá también la carpeta de spam / correo no deseado.',
          ),
          duration: const Duration(seconds: 7),
        ),
      );
    } on FirebaseAuthException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_friendlyResetError(e))));
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo enviar el email. Revisá tu conexión a internet.')),
      );
    }
  }

  String _friendlyResetError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No existe una cuenta con ese email.';
      case 'invalid-email':
        return 'El email no es válido.';
      default:
        return 'No se pudo enviar el email (${e.code}).';
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
                    if (_registering) ...[
                      TextFormField(
                        controller: _firstName,
                        decoration:
                            const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder()),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Ingresá tu nombre' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _lastName,
                        decoration:
                            const InputDecoration(labelText: 'Apellido', border: OutlineInputBorder()),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Ingresá tu apellido' : null,
                      ),
                      const SizedBox(height: 12),
                    ],
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
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                          tooltip: _obscurePassword ? 'Mostrar contraseña' : 'Ocultar contraseña',
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.length < 6) ? 'Al menos 6 caracteres' : null,
                    ),
                    if (_registering) ...[
                      const SizedBox(height: 8),
                      _consentRow(
                        value: _acceptedPrivacy,
                        onChanged: (v) => setState(() => _acceptedPrivacy = v),
                        prefix: 'He leído y acepto la ',
                        link: 'política de privacidad',
                        recognizer: _privacyLinkRecognizer,
                      ),
                      _consentRow(
                        value: _acceptedTerms,
                        onChanged: (v) => setState(() => _acceptedTerms = v),
                        prefix: 'He leído y aceptado los ',
                        link: 'términos y condiciones',
                        recognizer: _termsLinkRecognizer,
                      ),
                    ],
                    if (!_registering) ...[
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _busy ? null : _showForgotPasswordDialog,
                          child: const Text('¿Olvidaste tu contraseña?'),
                        ),
                      ),
                    ],
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

  /// Fila de checkbox de consentimiento con un texto parcialmente
  /// clickeable (abre el documento completo en un diálogo; "Aceptar" ahí
  /// tilda el checkbox). El checkbox también se puede tildar/destildar
  /// tocándolo directo, sin pasar por el diálogo.
  Widget _consentRow({
    required bool value,
    required ValueChanged<bool> onChanged,
    required String prefix,
    required String link,
    required TapGestureRecognizer recognizer,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: value,
          onChanged: _busy ? null : (v) => onChanged(v ?? false),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 13),
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 13, color: scheme.onSurface),
                children: [
                  TextSpan(text: prefix),
                  TextSpan(
                    text: link,
                    style: TextStyle(
                      color: scheme.primary,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.w600,
                    ),
                    recognizer: recognizer,
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
