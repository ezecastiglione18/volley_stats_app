import 'package:flutter/material.dart';

import '../widgets/premium_gate.dart';
import '../widgets/sign_out_confirmation.dart';
import '../widgets/theme_toggle_switch.dart';
import 'matches/match_archive_screen.dart';
import 'new_match/new_match_screen.dart';
import 'subscription/subscription_screen.dart';
import 'teams/team_list_screen.dart';
import 'whiteboard/whiteboard_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RallyStats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () => confirmAndSignOut(context),
          ),
          const ThemeToggleSwitch(),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Image.asset('assets/icon/app_icon_petals.png', width: 84, height: 84),
              const SizedBox(height: 8),
              const Center(
                child: Text('RallyStats',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 32),
              _HomeButton(
                icon: Icons.add_circle_outline,
                label: 'Nuevo Partido',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NewMatchScreen()),
                ),
              ),
              const SizedBox(height: 14),
              _HomeButton(
                icon: Icons.folder_open,
                label: 'Archivo de Partidos',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MatchArchiveScreen()),
                ),
              ),
              const SizedBox(height: 14),
              _HomeButton(
                icon: Icons.draw_outlined,
                label: 'Pizarra',
                onTap: () => runIfPremium(
                  context,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const WhiteboardScreen()),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _HomeButton(
                icon: Icons.groups,
                label: 'Equipos',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TeamListScreen()),
                ),
              ),
              const SizedBox(height: 14),
              _HomeButton(
                icon: Icons.workspace_premium_outlined,
                label: 'Mi suscripción',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _HomeButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Row(
            children: [
              const SizedBox(width: 20),
              Icon(icon, size: 32, color: Theme.of(context).colorScheme.secondary),
              const SizedBox(width: 18),
              Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const Spacer(),
              const Icon(Icons.chevron_right, color: Colors.grey),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}
