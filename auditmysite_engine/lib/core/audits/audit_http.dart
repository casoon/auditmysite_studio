import 'package:puppeteer/puppeteer.dart';
import '../events.dart';
import 'audit_base.dart';

class HttpAudit implements Audit {
  @override
  String get name => 'http';

  @override
  Future<void> run(AuditContext ctx) async {
    final page = ctx.page as Page;
    Map<String, String>? responseHeaders;
    int redirectCount = 0;
    List<Map<String, dynamic>> redirectChain = [];
    final startTime = DateTime.now();

    page.onResponse.listen((resp) {
      final respUrl = resp.url;
      final status = resp.status;
      
      // Prüfe ob es sich um einen Redirect handelt
      if (status >= 300 && status < 400) {
        redirectCount++;
        final location = resp.headers['location'] ?? '';
        redirectChain.add({
          'from': respUrl,
          'to': location,
          'status': status,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
      
      // Hauptresponse oder finale Response nach Redirects
      if (respUrl == ctx.url.toString() || respUrl == page.url || redirectCount == 0) {
        ctx.statusCode = resp.status;
        
        // Sammle wichtige Header (erweitert)
        try {
          responseHeaders = {
            'content-type': resp.headers['content-type'] ?? 'unknown',
            'server': resp.headers['server'] ?? 'unknown',
            'x-frame-options': resp.headers['x-frame-options'] ?? '',
            'x-content-type-options': resp.headers['x-content-type-options'] ?? '',
            'strict-transport-security': resp.headers['strict-transport-security'] ?? '',
            'content-security-policy': resp.headers['content-security-policy'] ?? '',
            'x-xss-protection': resp.headers['x-xss-protection'] ?? '',
            'referrer-policy': resp.headers['referrer-policy'] ?? '',
            'location': resp.headers['location'] ?? '',
            'cache-control': resp.headers['cache-control'] ?? '',
            'expires': resp.headers['expires'] ?? '',
            'etag': resp.headers['etag'] ?? '',
            'last-modified': resp.headers['last-modified'] ?? '',
            'content-encoding': resp.headers['content-encoding'] ?? '',
            'content-length': resp.headers['content-length'] ?? '',
          };
          // Entferne leere Header
          responseHeaders!.removeWhere((key, value) => value.isEmpty);
          ctx.headers = responseHeaders;
        } catch (e) {
          // Header-Parsing fehlgeschlagen, ignorieren
        }
      }
    });

    try {
      // Starte Timer für Response-Zeit
      final navigationStart = DateTime.now();
      
      await page.goto(ctx.url.toString(), wait: Until.networkIdle, timeout: Duration(seconds: 30));
      
      // Response-Zeit berechnen
      final navigationEnd = DateTime.now();
      final responseTimeMs = navigationEnd.difference(navigationStart).inMilliseconds;
      ctx.responseTimeMs = responseTimeMs;
      
      // Nach Navigation: finale URL prüfen (für Redirect-Tracking)
      final currentUrl = page.url;
      if (currentUrl != ctx.url.toString()) {
        ctx.redirectedTo = currentUrl;
      }
      
      // Redirect-Statistiken speichern
      ctx.redirectCount = redirectCount;
      ctx.redirectChain = redirectChain;
      
      // SSL/TLS-Informationen sammeln (wenn HTTPS)
      if (currentUrl != null && currentUrl.startsWith('https://')) {
        try {
          // Evaluiere JavaScript im Browser für SSL-Info
          final sslInfo = await page.evaluate(r'''
            () => {
              try {
                const connection = navigator.connection;
                const protocol = location.protocol;
                return {
                  protocol: protocol,
                  isSecure: protocol === 'https:',
                  // Browser-spezifische SSL-Details sind limitiert verfügbar
                };
              } catch (e) {
                return { protocol: location.protocol, isSecure: location.protocol === 'https:' };
              }
            }
          ''');
          ctx.sslInfo = sslInfo;
        } catch (e) {
          // SSL-Info-Sammlung fehlgeschlagen, ignorieren
          ctx.sslInfo = {
            'protocol': 'https:',
            'isSecure': true,
            'error': 'Could not retrieve detailed SSL info'
          };
        }
      }
      
    } catch (e) {
      // Navigation fehlgeschlagen
      final navigationEnd = DateTime.now();
      final responseTimeMs = navigationEnd.difference(startTime).inMilliseconds;
      ctx.responseTimeMs = responseTimeMs;
      ctx.navigationError = e.toString();
      rethrow;
    }
  }
}
