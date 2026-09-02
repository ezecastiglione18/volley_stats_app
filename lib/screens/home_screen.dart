import 'package:flutter/material.dart';

import '../utils/theme.dart';
import '../widgets/premium_gate.dart';
import '../widgets/theme_toggle_switch.dart';
import 'matches/match_archive_screen.dart';
import 'matches/rival_scouting_screen.dart';
import 'new_match/new_match_screen.dart';
import 'settings/account_settings_screen.dart';
import 'subscription/subscription_screen.dart';
import 'teams/team_list_screen.dart';
import 'whiteboard/whiteboard_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('RallyStats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Configuración',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AccountSettingsScreen()),
            ),
          ),
          const ThemeToggleSwitch(),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _Header(scheme: scheme),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SectionLabel('Armar y jugar'),
                  const SizedBox(height: 10),
                  _HomeButton(
                    icon: Icons.add_circle_outline,
                    label: 'Nuevo Partido',
                    subtitle: 'Configurar rival, planilla y formación',
                    color: scheme.secondary,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NewMatchScreen()),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _HomeButton(
                    icon: Icons.folder_open,
                    label: 'Archivo de Partidos',
                    subtitle: 'Partidos guardados, terminados o en curso',
                    color: scheme.secondary,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MatchArchiveScreen()),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _HomeButton(
                    icon: Icons.assessment_outlined,
                    label: 'Scouting de rivales',
                    subtitle: 'Estadística acumulada de cada rival ya enfrentado',
                    color: warningColor(context),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RivalScoutingScreen()),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _HomeButton(
                    icon: Icons.draw_outlined,
                    label: 'Pizarra',
                    subtitle: 'Dibujar formaciones y jugadas',
                    color: successColor(context),
                    onTap: () => runIfPremium(
                      context,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const WhiteboardScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  _SectionLabel('Mi cuenta'),
                  const SizedBox(height: 10),
                  _HomeButton(
                    icon: Icons.groups,
                    label: 'Equipos',
                    subtitle: 'Planteles y datos del cuerpo técnico',
                    color: warningColor(context),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TeamListScreen()),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _HomeButton(
                    icon: Icons.workspace_premium_outlined,
                    label: 'Mi suscripción',
                    subtitle: 'Estado del plan y funciones premium',
                    color: scheme.primary,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Franja superior de marca (logo + nombre) con degradé sutil entre el
/// primario y el acento de la paleta, para que la pantalla principal no
/// arranque directo con la lista de accesos.
class _Header extends StatelessWidget {
  final ColorScheme scheme;
  const _Header({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 34),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, scheme.primary.withValues(alpha: 0.82)],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Image.asset('assets/icon/app_icon_petals.png', width: 60, height: 60),
          ),
          const SizedBox(height: 14),
          const Text('RallyStats',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          Text('Estadísticas de vóley en vivo',
              style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.78))),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.6,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _HomeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _HomeButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 24, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
