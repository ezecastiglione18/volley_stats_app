import 'package:flutter/material.dart';

class RivalActionOption {
  final String value;
  final String label;
  const RivalActionOption(this.value, this.label);
}

/// Bottom sheet simple para elegir con qué tocó el rival (saque, ataque,
/// contra, genérico), usado al marcar Punto Rival o Error Rival.
Future<void> showRivalActionDialog({
  required BuildContext context,
  required String title,
  required List<RivalActionOption> options,
  required void Function(String value) onSelected,
}) async {
  await showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: options.map((o) {
                  return ActionChip(
                    label: Text(o.label),
                    onPressed: () {
                      Navigator.pop(ctx);
                      onSelected(o.value);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      );
    },
  );
}
