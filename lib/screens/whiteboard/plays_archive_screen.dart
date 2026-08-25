import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/play.dart';
import '../../state/app_data_controller.dart';
import '../../widgets/theme_toggle_switch.dart';
import 'whiteboard_screen.dart';

/// Archivo de jugadas guardadas de la pizarra táctica, análogo al archivo
/// de partidos ([MatchArchiveScreen]).
///
/// Si [pickMode] es `true`, tocar una jugada la devuelve con
/// `Navigator.pop(context, play)` en vez de abrirla en una pantalla nueva
/// (usado por [WhiteboardScreen] para "abrir jugada guardada" sin perder el
/// dibujo actual en pantalla hasta confirmar).
class PlaysArchiveScreen extends StatelessWidget {
  final bool pickMode;
  const PlaysArchiveScreen({super.key, this.pickMode = false});

  @override
  Widget build(BuildContext context) {
    final plays = context.watch<AppDataController>().plays;
    final df = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Archivo de Jugadas'),
        actions: const [ThemeToggleSwitch()],
      ),
      body: SafeArea(
        top: false,
        child: plays.isEmpty
            ? const Center(
                child: Text('Todavía no hay jugadas guardadas', style: TextStyle(color: Colors.grey)))
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: plays.length,
                itemBuilder: (context, i) {
                  final p = plays[i];
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.draw_outlined)),
                      title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${df.format(p.date)} · ${p.strokes.length} trazos'),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'delete') {
                            await context.read<AppDataController>().deletePlay(p.id);
                          } else if (v == 'edit') {
                            _open(context, p);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Abrir / editar')),
                          PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                        ],
                      ),
                      onTap: () => _open(context, p),
                    ),
                  );
                },
              ),
      ),
    );
  }

  void _open(BuildContext context, Play play) {
    if (pickMode) {
      Navigator.pop(context, play);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => WhiteboardScreen(initialPlay: play)),
      );
    }
  }
}
