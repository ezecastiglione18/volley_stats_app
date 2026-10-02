import '../models/visual_stats.dart';
import 'storage_service.dart';

/// Qué estadística visual se muestra, en pantalla y en el PDF. Elegirla es
/// una función premium (Configuración → Estadística visual en pantalla /
/// del PDF): la selección guardada se respeta solo con premium; sin premium
/// (o si se dejó de serlo) se muestra todo.
class VisualStatsPreferences {
  VisualStatsPreferences._();

  static Set<VisualChart> screenCharts({required bool isPremium}) =>
      isPremium ? StorageService.instance.loadScreenVisualCharts() : VisualChart.values.toSet();

  static Set<ShotKind> screenMaps({required bool isPremium}) =>
      isPremium ? StorageService.instance.loadScreenCourtMaps() : ShotKind.values.toSet();

  static Set<VisualChart> pdfCharts({required bool isPremium}) =>
      isPremium ? StorageService.instance.loadPdfVisualCharts() : VisualChart.values.toSet();

  static Set<ShotKind> pdfMaps({required bool isPremium}) =>
      isPremium ? StorageService.instance.loadPdfCourtMaps() : ShotKind.values.toSet();
}
