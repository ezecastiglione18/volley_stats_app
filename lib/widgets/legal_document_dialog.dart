import 'package:flutter/material.dart';

import '../legal/legal_section.dart';

/// Muestra un documento legal (política de privacidad, términos y
/// condiciones) completo en un diálogo scrolleable, con botones "Cerrar" y
/// "Aceptar". Devuelve `true` solo si se tocó "Aceptar" — el llamador debe
/// usar eso para tildar el checkbox de consentimiento correspondiente;
/// "Cerrar" (o cerrar el diálogo tocando afuera) no cambia nada.
///
/// [showAcceptButton] en `false` es para documentos puramente informativos
/// (p. ej. la guía de "Cómo gestionar tu suscripción") que no piden ningún
/// consentimiento: deja sólo un botón "Entendido", y el valor de retorno no
/// tiene uso para ese caso.
Future<bool> showLegalDocumentDialog({
  required BuildContext context,
  required String title,
  required String subtitle,
  required List<LegalSection> sections,
  bool showAcceptButton = true,
}) async {
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final section in sections) ...[
                      Text(section.title,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(section.body, style: const TextStyle(fontSize: 13, height: 1.4)),
                      const SizedBox(height: 18),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(showAcceptButton ? 'Cerrar' : 'Entendido'),
                  ),
                  if (showAcceptButton) ...[
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Aceptar'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  return accepted ?? false;
}
