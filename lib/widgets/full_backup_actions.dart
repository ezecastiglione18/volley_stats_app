import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/full_backup.dart';
import '../services/full_backup_service.dart';
import '../state/app_data_controller.dart';
import '../state/subscription_controller.dart';

/// "Exportar todo": equipos, partidos, jugadas y fixture de la cuenta abierta
/// en un solo archivo (ver [FullBackup]).
Future<void> exportAllData(BuildContext context) async {
  final json = context.read<AppDataController>().buildBackupJson();
  try {
    await FullBackupService.exportAll(json);
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('No se pudo exportar la copia: $e')));
  }
}

/// "Importar copia completa": agrega a la cuenta abierta lo que no tiene
/// (por id), sin pisar ni borrar nada. Sin premium, los partidos respetan el
/// tope de 3 del archivo, igual que al crear uno.
Future<void> importFullBackup(BuildContext context) async {
  final FullBackup? backup;
  try {
    backup = await FullBackupService.pickBackup();
  } catch (e) {
    if (context.mounted) await _showMessage(context, 'No se pudo importar', e.toString());
    return;
  }
  if (backup == null || !context.mounted) return;
  final isPremium = context.read<SubscriptionController>().isPremium;
  await _import(context, backup, applyFreeCap: !isPremium);
}

/// "Restaurar copia automática": lista las copias de `rallystats_backups/`
/// (la previa a la versión con datos por cuenta) y agrega la elegida a la
/// cuenta abierta sin tope: son datos que ya estaban en este dispositivo.
Future<void> restoreAutoBackup(BuildContext context) async {
  final files = await FullBackupService.listAutoBackups();
  if (!context.mounted) return;
  if (files.isEmpty) {
    await _showMessage(context, 'Restaurar copia automática', 'No hay copias automáticas en este dispositivo.');
    return;
  }
  final df = DateFormat('dd/MM/yyyy HH:mm');
  final chosen = await showDialog<File>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: const Text('Elegí una copia'),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Text(
            'Se agrega a esta cuenta lo que no tenga. No se pisa ni se borra nada.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
        for (final f in files)
          SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop(f),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history),
              title: Text(f.uri.pathSegments.last),
              subtitle: Text(
                  '${df.format(f.statSync().modified)} · ${(f.lengthSync() / 1024).toStringAsFixed(0)} KB'),
            ),
          ),
      ],
    ),
  );
  if (chosen == null || !context.mounted) return;
  final FullBackup backup;
  try {
    backup = await FullBackupService.readBackupFile(chosen);
  } catch (e) {
    if (context.mounted) await _showMessage(context, 'No se pudo restaurar', e.toString());
    return;
  }
  if (!context.mounted) return;
  await _import(context, backup, applyFreeCap: false);
}

Future<void> _import(BuildContext context, FullBackup backup, {required bool applyFreeCap}) async {
  try {
    final summary = await context.read<AppDataController>().importBackup(backup, applyFreeCap: applyFreeCap);
    if (context.mounted) await _showMessage(context, 'Importación terminada', summary.describe());
  } catch (e) {
    if (context.mounted) await _showMessage(context, 'No se pudo importar', e.toString());
  }
}

Future<void> _showMessage(BuildContext context, String title, String message) => showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Aceptar')),
        ],
      ),
    );
