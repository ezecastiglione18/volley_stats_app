import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../services/purchase_service.dart';
import '../../services/subscription_tiers.dart';

const _kFeatures = [
  'Acceso a partidos de 5 sets',
  'Selección de zonas para el ataque, saque y contraataque',
  'Generación de reportes post-partido',
  'Estadísticas post set',
  'Pizarra virtual',
];

/// Paywall propio (no el visual de RevenueCat) para poder probar el flujo
/// de compra completo sin depender de que el Paywall Builder del dashboard
/// esté configurado — misma información y la misma compra real por debajo
/// (`Purchases.purchase`), sólo que armada acá en vez de en RevenueCat.
///
/// Devuelve `true` por [Navigator.pop] si la compra se completó, `false`/
/// `null` si se canceló o se cerró sin comprar.
class PremiumPaywallScreen extends StatefulWidget {
  const PremiumPaywallScreen({super.key});

  @override
  State<PremiumPaywallScreen> createState() => _PremiumPaywallScreenState();
}

class _PremiumPaywallScreenState extends State<PremiumPaywallScreen> {
  bool _buying = false;

  Future<void> _buy() async {
    setState(() => _buying = true);
    final outcome = await purchaseProductById(context, kBasePremiumProductId);
    if (!mounted) return;
    setState(() => _buying = false);
    switch (outcome) {
      case PurchaseOutcome.purchased:
        Navigator.pop(context, true);
      case PurchaseOutcome.cancelled:
        break; // el usuario canceló, no hace falta avisar nada.
      case PurchaseOutcome.productNotFound:
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(const SnackBar(
            content: Text('El plan premium todavía no está disponible. Probá de nuevo más tarde.'),
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
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ],
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Image.asset('assets/icon/app_icon_petals.png', width: 64, height: 64),
                      const SizedBox(height: 16),
                      const Text(
                        'Desbloqueá Premium HOY',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'y accedé a todas nuestras funcionalidades',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: scheme.outlineVariant),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final feature in _kFeatures)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.check, color: scheme.secondary, size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(child: Text(feature)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<StoreProduct>>(
                future: Purchases.getProducts([kBasePremiumProductId]),
                builder: (context, snapshot) {
                  final products = snapshot.data;
                  final price =
                      (products != null && products.isNotEmpty) ? products.first.priceString : null;
                  return Text(
                    price != null
                        ? 'Tu suscripción se autorenueva por $price/mes hasta que la canceles.'
                        : 'Suscripción mensual, se autorenueva hasta que la canceles.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  );
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _buying ? null : _buy,
                  child: _buying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Actualizate a Premium'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
