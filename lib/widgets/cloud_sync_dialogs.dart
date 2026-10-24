import 'package:flutter/material.dart';

import '../legal/privacy_policy_text.dart';
import '../services/match_sync_service.dart';
import 'legal_document_dialog.dart';

/// Diálogos del interruptor "Partidos y equipos en la nube"
/// ([MatchSyncService]): el aviso único después del login, y activarlo o
/// apagarlo desde Configuración.

void _openPrivacyPolicy(BuildContext context) => showLegalDocumentDialog(
      context: context,
      title: 'Política de Privacidad',
      subtitle: 'Vigente desde $kPrivacyPolicyEffectiveDate · Versión $kPrivacyPolicyVersion',
      sections: privacyPolicySections,
      showAcceptButton: false,
    );

Future<bool?> _askEnable(BuildContext context, {required bool firstTime}) => showDialog<bool>(
      context: context,
      barrierDismissible: !firstTime,
      builder: (ctx) => AlertDialog(
        title: const Text('Partidos y equipos en la nube'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  '¿Querés guardar tus partidos y equipos en la nube para verlos en todos tus dispositivos?'),
              const SizedBox(height: 12),
              const Text(
                'Se suben los partidos terminados (completos, con sus notas) y los equipos con sus '
                'jugadores: nombres, números, posiciones, medidas y fechas de nacimiento. Las fotos, '
                'las jugadas de la pizarra y el fixture no se suben. Los partidos en curso tampoco: '
                'para pasarlos a otro dispositivo seguí usando Exportar.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 8),
              const Text(
                'Lo podés apagar cuando quieras desde Configuración, y ahí elegir si borrar la copia '
                'de la nube.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  onPressed: () => _openPrivacyPolicy(ctx),
                  child: const Text('Ver la política de privacidad'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(firstTime ? 'Ahora no' : 'Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(firstTime ? 'Sí' : 'Activar'),
          ),
        ],
      ),
    );

/// Aviso único (la cuenta nunca contestó): "Sí" activa la nube y arranca la
/// subida inicial; "Ahora no" guarda que no (no se vuelve a preguntar; se
/// puede activar desde Configuración).
Future<void> showCloudSyncPrompt(BuildContext context, MatchSyncService sync) async {
  final yes = await _askEnable(context, firstTime: true);
  if (yes == null) return;
  await sync.setCloudSync(yes);
  if (yes && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Nube activada: tus partidos y equipos se están subiendo (ver Configuración).')));
  }
}

/// Desde el switch de Configuración: activar (con el mismo aviso y la
/// política) o apagar (preguntando aparte si borrar la copia de la nube).
Future<void> toggleCloudSync(BuildContext context, MatchSyncService sync, bool turnOn) async {
  if (turnOn) {
    if (await _askEnable(context, firstTime: false) == true) await sync.setCloudSync(true);
    return;
  }
  var deleteRemote = false;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Apagar la nube'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Se deja de subir y de bajar en todos tus dispositivos. Lo que ya está en este '
                'dispositivo no se toca.'),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: deleteRemote,
              onChanged: (v) => setState(() => deleteRemote = v ?? false),
              title: const Text('Borrar también la copia de la nube (partidos y equipos)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Apagar')),
        ],
      ),
    ),
  );
  if (confirmed != true) return;
  try {
    await sync.setCloudSync(false, deleteRemoteCopy: deleteRemote);
    if (deleteRemote && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Se borró la copia de la nube.')));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('La nube quedó apagada, pero no se pudo borrar la copia (revisá tu conexión). '
              'Volvé a activarla y apagarla para intentar de nuevo.')));
    }
  }
}
