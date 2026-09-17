import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/redeem_code_service.dart';

/// "Tengo un código": canjea un código promocional para activar premium sin
/// pasar por Play Billing (ver volley_stats_app_backend, función
/// `redeemPromoCode`). Accesible desde Configuración de la cuenta.
class RedeemCodeScreen extends StatefulWidget {
  const RedeemCodeScreen({super.key});

  @override
  State<RedeemCodeScreen> createState() => _RedeemCodeScreenState();
}

class _RedeemCodeScreenState extends State<RedeemCodeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    final outcome = await redeemPromoCode(context, _codeController.text);
    if (!mounted) return;
    setState(() => _submitting = false);

    switch (outcome) {
      case RedeemOutcome.success:
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(const SnackBar(content: Text('¡Listo! Ya tenés premium activo.')));
      case RedeemOutcome.invalidCode:
        _showError('Ese código no existe. Revisá que esté bien escrito.');
      case RedeemOutcome.expired:
        _showError('Ese código ya venció.');
      case RedeemOutcome.quotaExceeded:
        _showError('Ese código ya alcanzó su cupo de usos.');
      case RedeemOutcome.alreadyUsedByAccount:
        _showError('Esta cuenta ya usó este código antes.');
      case RedeemOutcome.networkError:
        _showError('No se pudo canjear el código. Revisá tu conexión y probá de nuevo.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tengo un código')),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Si tenés un código promocional, ingresalo acá para activar tu premium.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _codeController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
                  decoration: const InputDecoration(
                    labelText: 'Código',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresá un código' : null,
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Activar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
