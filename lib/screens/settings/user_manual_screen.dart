import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

/// Dónde está publicado el manual de usuario (Firebase Hosting del proyecto,
/// `hosting/manual.pdf` + `firebase.json` de este repo, servido con
/// `Cache-Control: no-cache`). Cada vez que se regenera el manual hay que
/// volver a correr `firebase deploy --only hosting` (ver CLAUDE.md, proceso
/// de release): así este botón muestra siempre la versión más nueva sin
/// publicar otra versión de la app.
const kUserManualUrl = 'https://volleystatsapp-be835.web.app/manual.pdf';

/// Manual de usuario dentro de la app (Configuración → "Manual de usuario",
/// gratis para todos los planes). Baja el PDF publicado cada vez que se abre y lo muestra
/// con `PdfPreview` (del paquete `printing`, que ya se usa para el reporte),
/// con compartir e imprimir. Guarda la última copia bajada: sin conexión
/// muestra esa, avisando que puede no ser la más reciente.
class UserManualScreen extends StatefulWidget {
  const UserManualScreen({super.key});

  @override
  State<UserManualScreen> createState() => _UserManualScreenState();
}

class _UserManualScreenState extends State<UserManualScreen> {
  Uint8List? _pdf;
  bool _fromCache = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<File> _cacheFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}manual_usuario_rallystats.pdf');
  }

  /// Baja el manual publicado. Lanza si no hay conexión, si el servidor no
  /// responde 200 o si lo que llega no es un PDF.
  static Future<Uint8List> _download() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(Uri.parse(kUserManualUrl));
      final response = await request.close().timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) throw HttpException('HTTP ${response.statusCode}');
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response.timeout(const Duration(seconds: 30))) {
        builder.add(chunk);
      }
      final bytes = builder.takeBytes();
      // "%PDF": que una página de error no se muestre como si fuera el manual.
      if (bytes.length < 4 || String.fromCharCodes(bytes.sublist(0, 4)) != '%PDF') {
        throw const FormatException('La respuesta no es un PDF');
      }
      return bytes;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _load() async {
    setState(() {
      _failed = false;
      _pdf = null;
    });
    final cache = await _cacheFile();
    try {
      final bytes = await _download();
      await cache.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      setState(() {
        _pdf = bytes;
        _fromCache = false;
      });
    } catch (e) {
      debugPrint('UserManualScreen: no se pudo bajar el manual ($e)');
      final cached = await cache.exists() ? await cache.readAsBytes() : null;
      if (!mounted) return;
      setState(() {
        _pdf = cached;
        _fromCache = cached != null;
        _failed = cached == null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pdf = _pdf;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual de usuario'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Volver a bajar',
            onPressed: pdf == null && !_failed ? null : _load,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _failed
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wifi_off, size: 40, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text(
                        'No se pudo bajar el manual. Revisá tu conexión a internet y probá de nuevo.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _load, child: const Text('Reintentar')),
                    ],
                  ),
                ),
              )
            : pdf == null
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      if (_fromCache)
                        MaterialBanner(
                          content: const Text(
                              'Sin conexión: es la última copia que se bajó, puede no ser la más reciente.'),
                          actions: [TextButton(onPressed: _load, child: const Text('Reintentar'))],
                        ),
                      Expanded(
                        child: PdfPreview(
                          build: (_) async => pdf,
                          pdfFileName: 'manual_usuario_rallystats.pdf',
                          canChangeOrientation: false,
                          canChangePageFormat: false,
                          canDebug: false,
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
