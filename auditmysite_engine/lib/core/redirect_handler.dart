import 'dart:async';
import 'package:puppeteer/puppeteer.dart';
import 'events.dart';

/// Redirect information for a URL
class RedirectInfo {
  final Uri originalUrl;
  final Uri finalUrl;
  final int statusCode;
  final String type; // 'http_redirect', 'javascript_redirect', 'meta_redirect'
  final DateTime timestamp;
  final List<RedirectChain> chain;

  RedirectInfo({
    required this.originalUrl,
    required this.finalUrl,
    required this.statusCode,
    required this.type,
    required this.timestamp,
    this.chain = const [],
  });

  Map<String, dynamic> toJson() => {
    'originalUrl': originalUrl.toString(),
    'finalUrl': finalUrl.toString(),
    'statusCode': statusCode,
    'type': type,
    'timestamp': timestamp.toIso8601String(),
    'chain': chain.map((c) => c.toJson()).toList(),
  };
}

/// Single redirect in a chain
class RedirectChain {
  final Uri from;
  final Uri to;
  final int statusCode;

  RedirectChain({
    required this.from,
    required this.to,
    required this.statusCode,
  });

  Map<String, dynamic> toJson() => {
    'from': from.toString(),
    'to': to.toString(),
    'statusCode': statusCode,
  };
}

/// Redirect statistics tracker
class RedirectStatistics {
  final List<RedirectInfo> redirects = [];
  final Set<Uri> redirectedUrls = {};
  final Set<Uri> skippedUrls = {};
  
  int get totalRedirects => redirects.length;
  int get httpRedirects => redirects.where((r) => r.type == 'http_redirect').length;
  int get jsRedirects => redirects.where((r) => r.type == 'javascript_redirect').length;
  int get metaRedirects => redirects.where((r) => r.type == 'meta_redirect').length;
  
  void addRedirect(RedirectInfo info) {
    redirects.add(info);
    redirectedUrls.add(info.originalUrl);
    // DON'T automatically skip - let the audit process handle it
  }
  
  bool isRedirected(Uri url) => redirectedUrls.contains(url);
  
  Map<String, dynamic> toJson() => {
    'totalRedirects': totalRedirects,
    'httpRedirects': httpRedirects,
    'javascriptRedirects': jsRedirects,
    'metaRedirects': metaRedirects,
    'redirects': redirects.map((r) => r.toJson()).toList(),
    'skippedUrls': skippedUrls.map((u) => u.toString()).toList(),
  };
}

/// Handles redirect detection and tracking
class RedirectHandler {
  final RedirectStatistics stats = RedirectStatistics();
  final bool skipRedirects;
  final int maxRedirectsToFollow;
  
  RedirectHandler({
    this.skipRedirects = true,
    this.maxRedirectsToFollow = 5,
  });
  
  /// Detect if a page will redirect before fully loading it
  Future<RedirectInfo?> detectRedirect(
    Page page, 
    Uri url,
    StreamController<AuditEvent>? controller,
  ) async {
    RedirectInfo? redirectInfo;
    final chain = <RedirectChain>[];
    Uri? finalUrl;
    int? lastStatusCode;
    
    // Listen for HTTP redirects
    final responseCompleter = Completer<void>();
    StreamSubscription? responseSubscription;
    
    responseSubscription = page.onResponse.listen((response) {
      final status = response.status;
      
      // Check for redirect status codes
      if (status >= 300 && status < 400) {
        final location = response.headers['location'];
        if (location != null) {
          try {
            final fromUrl = Uri.parse(response.url);
            final toUrl = Uri.parse(location);
            chain.add(RedirectChain(
              from: fromUrl,
              to: toUrl,
              statusCode: status,
            ));
            lastStatusCode = status;
          } catch (e) {
            // Invalid URL in location header
          }
        }
      }
      
      // Check if we've reached the final destination
      if (status >= 200 && status < 300) {
        finalUrl = Uri.parse(response.url);
        if (!responseCompleter.isCompleted) {
          responseCompleter.complete();
        }
      }
    });
    
    try {
      // Navigate with shorter timeout for redirect detection
      await page.goto(
        url.toString(), 
        wait: Until.domContentLoaded,
        timeout: Duration(seconds: 10),
      );
      
      // Wait a bit for potential redirects to complete
      await Future.any([
        responseCompleter.future,
        Future.delayed(Duration(seconds: 2)),
      ]);
      
      // Check if we were redirected
      final currentUrl = Uri.parse(page.url ?? url.toString());
      
      // Log redirect if URL changed (for 301, 302, etc.)
      if (chain.isNotEmpty || currentUrl.toString() != url.toString()) {
        // We were redirected - log it but CONTINUE processing the final URL
        redirectInfo = RedirectInfo(
          originalUrl: url,
          finalUrl: currentUrl,
          statusCode: lastStatusCode ?? 302,
          type: 'http_redirect',
          timestamp: DateTime.now(),
          chain: chain,
        );
        
        // Track the redirect but DON'T skip the URL
        stats.redirects.add(redirectInfo);
        stats.redirectedUrls.add(url);
        // Note: NOT adding to skippedUrls!
        
        if (controller != null) {
          controller.add(PageRedirected(url, currentUrl, redirectInfo));
        }
      }
      
      // Also check for meta refresh redirects
      final metaRefresh = await page.evaluate(r'''
        () => {
          const meta = document.querySelector('meta[http-equiv="refresh"]');
          if (meta) {
            const content = meta.getAttribute('content');
            if (content) {
              const match = content.match(/\d+;\s*url=(.+)/i);
              if (match) {
                return match[1];
              }
            }
          }
          return null;
        }
      ''');
      
      if (metaRefresh != null && metaRefresh.toString().isNotEmpty) {
        try {
          final metaUrl = Uri.parse(metaRefresh.toString());
          redirectInfo = RedirectInfo(
            originalUrl: url,
            finalUrl: metaUrl,
            statusCode: 200, // Meta refresh happens after page load
            type: 'meta_redirect',
            timestamp: DateTime.now(),
            chain: [],
          );
          
          stats.addRedirect(redirectInfo);
          
          if (controller != null) {
            controller.add(PageRedirected(url, metaUrl, redirectInfo));
          }
        } catch (e) {
          // Invalid meta refresh URL
        }
      }
      
      // Check for JavaScript redirects (common patterns)
      final jsRedirect = await page.evaluate(r'''
        () => {
          // Check if page will redirect via JavaScript
          const scripts = document.querySelectorAll('script');
          for (const script of scripts) {
            const text = script.textContent || '';
            // Common redirect patterns
            if (text.includes('window.location.href') ||
                text.includes('window.location.replace') ||
                text.includes('window.location =')) {
              // Try to extract the URL
              const match = text.match(/["']([^"']+)["']/);
              if (match && match[1].startsWith('http')) {
                return match[1];
              }
            }
          }
          return null;
        }
      ''');
      
      if (jsRedirect != null && jsRedirect.toString().isNotEmpty && redirectInfo == null) {
        try {
          final jsUrl = Uri.parse(jsRedirect.toString());
          redirectInfo = RedirectInfo(
            originalUrl: url,
            finalUrl: jsUrl,
            statusCode: 200,
            type: 'javascript_redirect',
            timestamp: DateTime.now(),
            chain: [],
          );
          
          stats.addRedirect(redirectInfo);
          
          if (controller != null) {
            controller.add(PageRedirected(url, jsUrl, redirectInfo));
          }
        } catch (e) {
          // Invalid JavaScript redirect URL
        }
      }
      
    } catch (e) {
      // Navigation failed, but that's ok for redirect detection
    } finally {
      await responseSubscription?.cancel();
    }
    
    return redirectInfo;
  }
  
  /// Check if a URL should be skipped due to redirect
  bool shouldSkip(Uri url) {
    // NEVER skip URLs just because they redirect
    // We want to audit the final destination
    return false;
  }
  
  /// Get summary for reports
  Map<String, dynamic> getSummary() => {
    'redirectHandling': {
      'enabled': skipRedirects,
      'maxRedirectsToFollow': maxRedirectsToFollow,
      'statistics': stats.toJson(),
    }
  };
}

/// New event for redirects
class PageRedirected extends AuditEvent {
  final Uri finalUrl;
  final RedirectInfo info;
  
  PageRedirected(Uri originalUrl, this.finalUrl, this.info) : super(originalUrl);
}