import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../services/device_addon_service.dart';
import '../../services/paywall_launcher.dart';
import '../../services/purchase_service.dart';
import '../../services/subscription_management_launcher.dart';
import '../../services/subscription_tiers.dart';
import '../../state/subscription_controller.dart';
import '../../widgets/restore_purchases_button.dart';
import '../../widgets/theme_toggle_switch.dart';

/// "Mi suscripción": estado del plan premium y, si ya está activo, la
/// compra del próximo dispositivo adicional (se habilitan de a uno: recién
/// se puede comprar el segundo complemento una vez que el primero está
/// activo, y así con el tercero).
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _buying = false;

  Future<void> _buyNextAddOn() async {
    setState(() => _buying = true);
    final outcome = await purchaseNextDeviceAddOn(context);
    if (!mounted) return;
    setState(() => _buying = false);
    switch (outcome) {
      case PurchaseOutcome.purchased:
      case PurchaseOutcome.cancelled:
        break; // nada que avisar: el estado se actualiza solo, o el usuario canceló.
      case PurchaseOutcome.productNotFound:
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(const SnackBar(
            content: Text('Este complemento todavía no está disponible. Probá de nuevo más tarde.'),
          ));
      case PurchaseOutcome.error:
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(const SnackBar(
            content: Text('No se pudo completar la compra. Probá de nuevo.'),
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final subscription = context.watch<SubscriptionController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi suscripción'),
        actions: const [ThemeToggleSwitch()],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: subscription.isPremium
              ? _PremiumContent(deviceLimit: subscription.deviceLimit, buying: _buying, onBuy: _buyNextAddOn)
              : const _NotPremiumContent(),
        ),
      ),
    );
  }
}

class _NotPremiumContent extends StatelessWidget {
  const _NotPremiumContent();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium_outlined, size: 48, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(height: 16),
          const Text(
            'Todavía no tenés la suscripción premium activa',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Suscribite para desbloquear estadísticas, pizarra, archivo ilimitado de partidos y '
            'la posibilidad de sumar dispositivos adicionales.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => showRallyStatsPaywall(context),
            child: const Text('Ver planes'),
          ),
          const SizedBox(height: 4),
          const RestorePurchasesButton(),
        ],
      ),
    );
  }
}

class _PremiumContent extends StatelessWidget {
  final int deviceLimit;
  final bool buying;
  final VoidCallback onBuy;

  const _PremiumContent({required this.deviceLimit, required this.buying, required this.onBuy});

  @override
  Widget build(BuildContext context) {
    final nextProductId = nextDeviceAddOnProductId(deviceLimit);

    return ListView(
      children: [
        const Text('Plan', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        const Text('Premium activo', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 24),
        const Text('Dispositivos', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('$deviceLimit de ${kDeviceAddOnProductIds.length + 1} dispositivos habilitados',
            style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 16),
        if (nextProductId == null)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('Ya alcanzaste el máximo de dispositivos para tu cuenta.'),
                  ),
                ],
              ),
            ),
          )
        else
          _AddOnCard(productId: nextProductId, buying: buying, onBuy: onBuy),
        const SizedBox(height: 24),
        Center(
          child: TextButton(
            onPressed: () => openSubscriptionManagement(context),
            child: const Text('Gestionar o cancelar suscripción'),
          ),
        ),
      ],
    );
  }
}

class _AddOnCard extends StatelessWidget {
  final String productId;
  final bool buying;
  final VoidCallback onBuy;

  const _AddOnCard({required this.productId, required this.buying, required this.onBuy});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Sumar un dispositivo más', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            FutureBuilder<List<StoreProduct>>(
              future: Purchases.getProducts([productId]),
              builder: (context, snapshot) {
                final products = snapshot.data;
                final price =
                    (products != null && products.isNotEmpty) ? products.first.priceString : null;
                return Text(
                  price != null ? '$price/mes adicionales' : 'Suscripción recurrente aparte',
                  style: const TextStyle(color: Colors.grey),
                );
              },
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: buying ? null : onBuy,
              child: buying
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Agregar dispositivo adicional'),
            ),
          ],
        ),
      ),
    );
  }
}
