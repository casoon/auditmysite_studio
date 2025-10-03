import 'dart:convert';
import 'package:puppeteer/puppeteer.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'audit_base.dart';

/// Comprehensive Security Headers Audit
class SecurityHeadersAudit implements Audit {
  @override
  String get name => 'security_headers';
  
  final Logger _logger = Logger('SecurityHeadersAudit');

  @override
  Future<void> run(AuditContext ctx) async {
    final page = ctx.page as Page;
    final url = ctx.url.toString();
    
    final securityResults = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'url': url,
      'headers': {},
      'score': 0,
      'vulnerabilities': [],
      'recommendations': [],
      'grade': 'F'
    };
    
    try {
      // Get response headers
      final response = await http.head(ctx.url).timeout(Duration(seconds: 10));
      final headers = response.headers;
      
      // 1. Content Security Policy (CSP)
      securityResults['headers']['csp'] = _analyzeCSP(headers);
      
      // 2. Strict Transport Security (HSTS)
      securityResults['headers']['hsts'] = _analyzeHSTS(headers);
      
      // 3. X-Frame-Options
      securityResults['headers']['xFrameOptions'] = _analyzeXFrameOptions(headers);
      
      // 4. X-Content-Type-Options
      securityResults['headers']['xContentTypeOptions'] = _analyzeXContentTypeOptions(headers);
      
      // 5. X-XSS-Protection
      securityResults['headers']['xXssProtection'] = _analyzeXSSProtection(headers);
      
      // 6. Referrer-Policy
      securityResults['headers']['referrerPolicy'] = _analyzeReferrerPolicy(headers);
      
      // 7. Permissions-Policy (formerly Feature-Policy)
      securityResults['headers']['permissionsPolicy'] = _analyzePermissionsPolicy(headers);
      
      // 8. Cross-Origin Headers
      securityResults['headers']['cors'] = _analyzeCORS(headers);
      
      // 9. Expect-CT
      securityResults['headers']['expectCT'] = _analyzeExpectCT(headers);
      
      // 10. X-Permitted-Cross-Domain-Policies
      securityResults['headers']['xPermittedCrossDomainPolicies'] = 
          _analyzeXPermittedCrossDomainPolicies(headers);
      
      // 11. Clear-Site-Data
      securityResults['headers']['clearSiteData'] = _analyzeClearSiteData(headers);
      
      // 12. Cross-Origin-Embedder-Policy
      securityResults['headers']['coep'] = _analyzeCOEP(headers);
      
      // 13. Cross-Origin-Opener-Policy
      securityResults['headers']['coop'] = _analyzeCOOP(headers);
      
      // 14. Cross-Origin-Resource-Policy
      securityResults['headers']['corp'] = _analyzeCORP(headers);
      
      // 15. Check for sensitive headers that shouldn't be exposed
      securityResults['headers']['exposedHeaders'] = _checkExposedHeaders(headers);
      
      // 16. Check HTTPS usage
      securityResults['https'] = _checkHTTPS(url);
      
      // 17. Check for mixed content
      securityResults['mixedContent'] = await _checkMixedContent(page);
      
      // 18. Check for insecure cookies
      securityResults['cookies'] = await _analyzeCookies(page);
      
      // 19. Check for security.txt
      securityResults['securityTxt'] = await _checkSecurityTxt(ctx.url.host);
      
      // 20. Subresource Integrity (SRI)
      securityResults['sri'] = await _checkSubresourceIntegrity(page);
      
      // Calculate score and grade
      final scoring = _calculateScore(securityResults);
      securityResults['score'] = scoring['score'];
      securityResults['grade'] = scoring['grade'];
      securityResults['summary'] = scoring['summary'];
      
      // Generate vulnerabilities list
      securityResults['vulnerabilities'] = _identifyVulnerabilities(securityResults);
      
      // Generate recommendations
      securityResults['recommendations'] = _generateRecommendations(securityResults);
      
      // Store in context
      ctx.securityHeaders = securityResults;
      
    } catch (e) {
      _logger.severe('Error in security headers audit: $e');
      securityResults['error'] = e.toString();
      ctx.securityHeaders = securityResults;
    }
  }
  
  Map<String, dynamic> _analyzeCSP(Map<String, String> headers) {
    final csp = <String, dynamic>{
      'present': false,
      'value': '',
      'directives': {},
      'issues': [],
      'score': 0
    };
    
    final cspHeader = headers['content-security-policy'] ?? 
                      headers['Content-Security-Policy'];
    
    if (cspHeader != null && cspHeader.isNotEmpty) {
      csp['present'] = true;
      csp['value'] = cspHeader;
      
      // Parse CSP directives
      final directives = cspHeader.split(';');
      for (final directive in directives) {
        final parts = directive.trim().split(' ');
        if (parts.isNotEmpty) {
          final name = parts[0];
          final values = parts.sublist(1);
          csp['directives'][name] = values;
        }
      }
      
      // Check for important directives
      if (!csp['directives'].containsKey('default-src')) {
        csp['issues'].add('Missing default-src directive');
      }
      
      if (csp['directives'].containsKey('unsafe-inline')) {
        csp['issues'].add('Uses unsafe-inline which allows inline scripts');
      }
      
      if (csp['directives'].containsKey('unsafe-eval')) {
        csp['issues'].add('Uses unsafe-eval which allows eval()');
      }
      
      if (!csp['directives'].containsKey('upgrade-insecure-requests')) {
        csp['issues'].add('Missing upgrade-insecure-requests directive');
      }
      
      // Calculate score
      csp['score'] = csp['issues'].isEmpty ? 100 : 
                     100 - (csp['issues'].length * 20);
    } else {
      csp['issues'].add('No Content Security Policy header found');
    }
    
    return csp;
  }
  
  Map<String, dynamic> _analyzeHSTS(Map<String, String> headers) {
    final hsts = <String, dynamic>{
      'present': false,
      'value': '',
      'maxAge': 0,
      'includeSubDomains': false,
      'preload': false,
      'issues': [],
      'score': 0
    };
    
    final hstsHeader = headers['strict-transport-security'] ?? 
                       headers['Strict-Transport-Security'];
    
    if (hstsHeader != null && hstsHeader.isNotEmpty) {
      hsts['present'] = true;
      hsts['value'] = hstsHeader;
      
      // Parse HSTS directives
      final parts = hstsHeader.split(';');
      for (final part in parts) {
        final trimmed = part.trim();
        if (trimmed.startsWith('max-age=')) {
          hsts['maxAge'] = int.tryParse(
            trimmed.substring(8).replaceAll(RegExp(r'[^0-9]'), '')
          ) ?? 0;
        } else if (trimmed == 'includeSubDomains') {
          hsts['includeSubDomains'] = true;
        } else if (trimmed == 'preload') {
          hsts['preload'] = true;
        }
      }
      
      // Check for issues
      if (hsts['maxAge'] < 31536000) { // Less than 1 year
        hsts['issues'].add('max-age should be at least 31536000 seconds (1 year)');
      }
      
      if (!hsts['includeSubDomains']) {
        hsts['issues'].add('Consider adding includeSubDomains directive');
      }
      
      if (!hsts['preload']) {
        hsts['issues'].add('Consider adding preload directive for HSTS preload list');
      }
      
      // Calculate score
      int score = 50; // Base score for having HSTS
      if (hsts['maxAge'] >= 31536000) score += 20;
      if (hsts['includeSubDomains']) score += 15;
      if (hsts['preload']) score += 15;
      hsts['score'] = score;
    } else {
      hsts['issues'].add('No Strict-Transport-Security header found');
    }
    
    return hsts;
  }
  
  Map<String, dynamic> _analyzeXFrameOptions(Map<String, String> headers) {
    final xfo = <String, dynamic>{
      'present': false,
      'value': '',
      'issues': [],
      'score': 0
    };
    
    final xfoHeader = headers['x-frame-options'] ?? headers['X-Frame-Options'];
    
    if (xfoHeader != null && xfoHeader.isNotEmpty) {
      xfo['present'] = true;
      xfo['value'] = xfoHeader.toUpperCase();
      
      if (xfo['value'] == 'DENY' || xfo['value'] == 'SAMEORIGIN') {
        xfo['score'] = 100;
      } else if (xfo['value'].startsWith('ALLOW-FROM')) {
        xfo['score'] = 75;
        xfo['issues'].add('ALLOW-FROM is deprecated, use CSP frame-ancestors instead');
      } else {
        xfo['score'] = 0;
        xfo['issues'].add('Invalid X-Frame-Options value');
      }
    } else {
      xfo['issues'].add('No X-Frame-Options header found (clickjacking protection)');
    }
    
    return xfo;
  }
  
  Map<String, dynamic> _analyzeXContentTypeOptions(Map<String, String> headers) {
    final xcto = <String, dynamic>{
      'present': false,
      'value': '',
      'issues': [],
      'score': 0
    };
    
    final xctoHeader = headers['x-content-type-options'] ?? 
                       headers['X-Content-Type-Options'];
    
    if (xctoHeader != null && xctoHeader.isNotEmpty) {
      xcto['present'] = true;
      xcto['value'] = xctoHeader;
      
      if (xctoHeader.toLowerCase() == 'nosniff') {
        xcto['score'] = 100;
      } else {
        xcto['score'] = 0;
        xcto['issues'].add('X-Content-Type-Options should be set to "nosniff"');
      }
    } else {
      xcto['issues'].add('No X-Content-Type-Options header found (MIME sniffing protection)');
    }
    
    return xcto;
  }
  
  Map<String, dynamic> _analyzeXSSProtection(Map<String, String> headers) {
    final xxp = <String, dynamic>{
      'present': false,
      'value': '',
      'issues': [],
      'score': 0,
      'deprecated': true
    };
    
    final xxpHeader = headers['x-xss-protection'] ?? headers['X-XSS-Protection'];
    
    if (xxpHeader != null && xxpHeader.isNotEmpty) {
      xxp['present'] = true;
      xxp['value'] = xxpHeader;
      
      // X-XSS-Protection is deprecated and can introduce vulnerabilities
      xxp['issues'].add('X-XSS-Protection is deprecated. Use Content-Security-Policy instead');
      
      if (xxpHeader == '0') {
        xxp['score'] = 50; // Disabled is actually safer than enabled
      } else if (xxpHeader.contains('1')) {
        xxp['score'] = 25;
        if (xxpHeader.contains('mode=block')) {
          xxp['score'] = 30;
        }
      }
    }
    
    return xxp;
  }
  
  Map<String, dynamic> _analyzeReferrerPolicy(Map<String, String> headers) {
    final rp = <String, dynamic>{
      'present': false,
      'value': '',
      'issues': [],
      'score': 0
    };
    
    final rpHeader = headers['referrer-policy'] ?? headers['Referrer-Policy'];
    
    if (rpHeader != null && rpHeader.isNotEmpty) {
      rp['present'] = true;
      rp['value'] = rpHeader;
      
      // Score based on policy strictness
      final policies = {
        'no-referrer': 100,
        'same-origin': 90,
        'strict-origin': 85,
        'strict-origin-when-cross-origin': 80,
        'no-referrer-when-downgrade': 60,
        'origin': 50,
        'origin-when-cross-origin': 50,
        'unsafe-url': 0
      };
      
      rp['score'] = policies[rpHeader.toLowerCase()] ?? 0;
      
      if (rpHeader.toLowerCase() == 'unsafe-url') {
        rp['issues'].add('unsafe-url policy exposes full URL to all requests');
      }
    } else {
      rp['issues'].add('No Referrer-Policy header found');
    }
    
    return rp;
  }
  
  Map<String, dynamic> _analyzePermissionsPolicy(Map<String, String> headers) {
    final pp = <String, dynamic>{
      'present': false,
      'value': '',
      'directives': [],
      'issues': [],
      'score': 0
    };
    
    final ppHeader = headers['permissions-policy'] ?? 
                     headers['Permissions-Policy'] ??
                     headers['feature-policy'] ?? 
                     headers['Feature-Policy'];
    
    if (ppHeader != null && ppHeader.isNotEmpty) {
      pp['present'] = true;
      pp['value'] = ppHeader;
      
      // Parse directives
      final directives = ppHeader.split(',');
      for (final directive in directives) {
        pp['directives'].add(directive.trim());
      }
      
      // Check for important restrictions
      final importantFeatures = [
        'camera', 'microphone', 'geolocation', 'payment', 
        'usb', 'bluetooth', 'accelerometer', 'gyroscope'
      ];
      
      int restrictedCount = 0;
      for (final feature in importantFeatures) {
        if (ppHeader.contains('$feature=()') || 
            ppHeader.contains('$feature \'none\'')) {
          restrictedCount++;
        }
      }
      
      pp['score'] = (restrictedCount / importantFeatures.length * 100).round();
      
      if (restrictedCount < 4) {
        pp['issues'].add('Consider restricting more sensitive features');
      }
    } else {
      pp['issues'].add('No Permissions-Policy header found');
    }
    
    return pp;
  }
  
  Map<String, dynamic> _analyzeCORS(Map<String, String> headers) {
    final cors = <String, dynamic>{
      'accessControlAllowOrigin': '',
      'accessControlAllowCredentials': '',
      'accessControlAllowMethods': '',
      'accessControlAllowHeaders': '',
      'issues': [],
      'score': 100
    };
    
    cors['accessControlAllowOrigin'] = headers['access-control-allow-origin'] ?? '';
    cors['accessControlAllowCredentials'] = headers['access-control-allow-credentials'] ?? '';
    cors['accessControlAllowMethods'] = headers['access-control-allow-methods'] ?? '';
    cors['accessControlAllowHeaders'] = headers['access-control-allow-headers'] ?? '';
    
    // Check for issues
    if (cors['accessControlAllowOrigin'] == '*') {
      cors['issues'].add('Access-Control-Allow-Origin is set to wildcard (*)');
      cors['score'] -= 30;
      
      if (cors['accessControlAllowCredentials'] == 'true') {
        cors['issues'].add('CRITICAL: Wildcard origin with credentials is a security vulnerability');
        cors['score'] = 0;
      }
    }
    
    return cors;
  }
  
  Map<String, dynamic> _analyzeExpectCT(Map<String, String> headers) {
    final ect = <String, dynamic>{
      'present': false,
      'value': '',
      'maxAge': 0,
      'enforce': false,
      'reportUri': '',
      'score': 0
    };
    
    final ectHeader = headers['expect-ct'] ?? headers['Expect-CT'];
    
    if (ectHeader != null && ectHeader.isNotEmpty) {
      ect['present'] = true;
      ect['value'] = ectHeader;
      
      // Parse directives
      final parts = ectHeader.split(',');
      for (final part in parts) {
        final trimmed = part.trim();
        if (trimmed.startsWith('max-age=')) {
          ect['maxAge'] = int.tryParse(
            trimmed.substring(8).replaceAll(RegExp(r'[^0-9]'), '')
          ) ?? 0;
        } else if (trimmed == 'enforce') {
          ect['enforce'] = true;
        } else if (trimmed.startsWith('report-uri=')) {
          ect['reportUri'] = trimmed.substring(11);
        }
      }
      
      ect['score'] = ect['enforce'] ? 100 : 50;
    }
    
    return ect;
  }
  
  Map<String, dynamic> _analyzeXPermittedCrossDomainPolicies(Map<String, String> headers) {
    final xpcdp = <String, dynamic>{
      'present': false,
      'value': '',
      'score': 0
    };
    
    final xpcdpHeader = headers['x-permitted-cross-domain-policies'] ?? 
                        headers['X-Permitted-Cross-Domain-Policies'];
    
    if (xpcdpHeader != null && xpcdpHeader.isNotEmpty) {
      xpcdp['present'] = true;
      xpcdp['value'] = xpcdpHeader;
      
      if (xpcdpHeader.toLowerCase() == 'none') {
        xpcdp['score'] = 100;
      } else if (xpcdpHeader.toLowerCase() == 'master-only') {
        xpcdp['score'] = 75;
      } else {
        xpcdp['score'] = 50;
      }
    }
    
    return xpcdp;
  }
  
  Map<String, dynamic> _analyzeClearSiteData(Map<String, String> headers) {
    final csd = <String, dynamic>{
      'present': false,
      'value': '',
      'types': []
    };
    
    final csdHeader = headers['clear-site-data'] ?? headers['Clear-Site-Data'];
    
    if (csdHeader != null && csdHeader.isNotEmpty) {
      csd['present'] = true;
      csd['value'] = csdHeader;
      
      // Parse types
      if (csdHeader.contains('cache')) csd['types'].add('cache');
      if (csdHeader.contains('cookies')) csd['types'].add('cookies');
      if (csdHeader.contains('storage')) csd['types'].add('storage');
      if (csdHeader.contains('executionContexts')) csd['types'].add('executionContexts');
      if (csdHeader.contains('*')) csd['types'].add('all');
    }
    
    return csd;
  }
  
  Map<String, dynamic> _analyzeCOEP(Map<String, String> headers) {
    final coep = <String, dynamic>{
      'present': false,
      'value': '',
      'score': 0
    };
    
    final coepHeader = headers['cross-origin-embedder-policy'] ?? 
                       headers['Cross-Origin-Embedder-Policy'];
    
    if (coepHeader != null && coepHeader.isNotEmpty) {
      coep['present'] = true;
      coep['value'] = coepHeader;
      coep['score'] = coepHeader == 'require-corp' ? 100 : 50;
    }
    
    return coep;
  }
  
  Map<String, dynamic> _analyzeCOOP(Map<String, String> headers) {
    final coop = <String, dynamic>{
      'present': false,
      'value': '',
      'score': 0
    };
    
    final coopHeader = headers['cross-origin-opener-policy'] ?? 
                       headers['Cross-Origin-Opener-Policy'];
    
    if (coopHeader != null && coopHeader.isNotEmpty) {
      coop['present'] = true;
      coop['value'] = coopHeader;
      
      final scores = {
        'same-origin': 100,
        'same-origin-allow-popups': 75,
        'unsafe-none': 0
      };
      
      coop['score'] = scores[coopHeader] ?? 0;
    }
    
    return coop;
  }
  
  Map<String, dynamic> _analyzeCORP(Map<String, String> headers) {
    final corp = <String, dynamic>{
      'present': false,
      'value': '',
      'score': 0
    };
    
    final corpHeader = headers['cross-origin-resource-policy'] ?? 
                       headers['Cross-Origin-Resource-Policy'];
    
    if (corpHeader != null && corpHeader.isNotEmpty) {
      corp['present'] = true;
      corp['value'] = corpHeader;
      
      final scores = {
        'same-site': 100,
        'same-origin': 90,
        'cross-origin': 25
      };
      
      corp['score'] = scores[corpHeader] ?? 0;
    }
    
    return corp;
  }
  
  Map<String, dynamic> _checkExposedHeaders(Map<String, String> headers) {
    final exposed = <String, dynamic>{
      'sensitiveHeaders': [],
      'serverInfo': {},
      'issues': []
    };
    
    // Check for sensitive headers that shouldn't be exposed
    final sensitivePatterns = [
      'x-powered-by', 'server', 'x-aspnet-version', 
      'x-aspnetmvc-version', 'x-generator'
    ];
    
    for (final pattern in sensitivePatterns) {
      final value = headers[pattern] ?? headers[pattern.split('-').map((s) => 
        s[0].toUpperCase() + s.substring(1)).join('-')];
      if (value != null && value.isNotEmpty) {
        exposed['sensitiveHeaders'].add({
          'header': pattern,
          'value': value
        });
        exposed['issues'].add('Exposes $pattern header with value: $value');
      }
    }
    
    // Check for server information disclosure
    final serverHeader = headers['server'] ?? headers['Server'];
    if (serverHeader != null && serverHeader.isNotEmpty) {
      exposed['serverInfo']['server'] = serverHeader;
      
      // Check if version info is exposed
      if (RegExp(r'\d+\.\d+').hasMatch(serverHeader)) {
        exposed['issues'].add('Server header exposes version information');
      }
    }
    
    return exposed;
  }
  
  bool _checkHTTPS(String url) {
    return url.startsWith('https://');
  }
  
  Future<Map<String, dynamic>> _checkMixedContent(Page page) async {
    final mixedContent = <String, dynamic>{
      'hasMixedContent': false,
      'insecureRequests': [],
      'types': []
    };
    
    try {
      final result = await page.evaluate('''() => {
        const insecure = [];
        const types = new Set();
        
        // Check for HTTP resources on HTTPS page
        if (window.location.protocol === 'https:') {
          // Check images
          document.querySelectorAll('img[src^="http:"]').forEach(img => {
            insecure.push({type: 'image', url: img.src});
            types.add('image');
          });
          
          // Check scripts
          document.querySelectorAll('script[src^="http:"]').forEach(script => {
            insecure.push({type: 'script', url: script.src});
            types.add('script');
          });
          
          // Check stylesheets
          document.querySelectorAll('link[href^="http:"]').forEach(link => {
            if (link.rel === 'stylesheet') {
              insecure.push({type: 'stylesheet', url: link.href});
              types.add('stylesheet');
            }
          });
          
          // Check iframes
          document.querySelectorAll('iframe[src^="http:"]').forEach(iframe => {
            insecure.push({type: 'iframe', url: iframe.src});
            types.add('iframe');
          });
        }
        
        return {
          hasMixedContent: insecure.length > 0,
          insecureRequests: insecure,
          types: Array.from(types)
        };
      }''');
      
      mixedContent.addAll(result as Map);
    } catch (e) {
      _logger.warning('Error checking mixed content: $e');
    }
    
    return mixedContent;
  }
  
  Future<Map<String, dynamic>> _analyzeCookies(Page page) async {
    final cookies = <String, dynamic>{
      'total': 0,
      'secure': 0,
      'httpOnly': 0,
      'sameSite': 0,
      'insecureCookies': [],
      'issues': []
    };
    
    try {
      final pageCookies = await page.cookies();
      cookies['total'] = pageCookies.length;
      
      for (final cookie in pageCookies) {
        if (cookie.secure == true) cookies['secure']++;
        if (cookie.httpOnly == true) cookies['httpOnly']++;
        if (cookie.sameSite != null && cookie.sameSite != SameSite.none) {
          cookies['sameSite']++;
        }
        
        // Check for insecure cookies
        if (cookie.secure != true || cookie.httpOnly != true) {
          cookies['insecureCookies'].add({
            'name': cookie.name,
            'secure': cookie.secure,
            'httpOnly': cookie.httpOnly,
            'sameSite': cookie.sameSite?.toString()
          });
        }
      }
      
      // Generate issues
      if (cookies['secure'] < cookies['total']) {
        cookies['issues'].add('${cookies['total'] - cookies['secure']} cookies without Secure flag');
      }
      
      if (cookies['httpOnly'] < cookies['total']) {
        cookies['issues'].add('${cookies['total'] - cookies['httpOnly']} cookies without HttpOnly flag');
      }
      
      if (cookies['sameSite'] < cookies['total']) {
        cookies['issues'].add('${cookies['total'] - cookies['sameSite']} cookies without SameSite attribute');
      }
    } catch (e) {
      _logger.warning('Error analyzing cookies: $e');
    }
    
    return cookies;
  }
  
  Future<Map<String, dynamic>> _checkSecurityTxt(String domain) async {
    final securityTxt = <String, dynamic>{
      'found': false,
      'url': '',
      'content': '',
      'wellKnown': false,
      'root': false
    };
    
    try {
      // Check /.well-known/security.txt (preferred location)
      var url = 'https://$domain/.well-known/security.txt';
      var response = await http.get(Uri.parse(url))
          .timeout(Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        securityTxt['found'] = true;
        securityTxt['wellKnown'] = true;
        securityTxt['url'] = url;
        securityTxt['content'] = response.body;
      } else {
        // Check /security.txt (alternative location)
        url = 'https://$domain/security.txt';
        response = await http.get(Uri.parse(url))
            .timeout(Duration(seconds: 5));
        
        if (response.statusCode == 200) {
          securityTxt['found'] = true;
          securityTxt['root'] = true;
          securityTxt['url'] = url;
          securityTxt['content'] = response.body;
        }
      }
    } catch (e) {
      // Not found or error
    }
    
    return securityTxt;
  }
  
  Future<Map<String, dynamic>> _checkSubresourceIntegrity(Page page) async {
    final sri = <String, dynamic>{
      'totalExternal': 0,
      'withIntegrity': 0,
      'withoutIntegrity': [],
      'coverage': 0
    };
    
    try {
      final result = await page.evaluate('''() => {
        const external = [];
        const withIntegrity = [];
        const withoutIntegrity = [];
        
        // Check scripts
        document.querySelectorAll('script[src]').forEach(script => {
          const src = script.src;
          if (!src.startsWith(window.location.origin)) {
            external.push({type: 'script', url: src});
            if (script.integrity) {
              withIntegrity.push({type: 'script', url: src, integrity: script.integrity});
            } else {
              withoutIntegrity.push({type: 'script', url: src});
            }
          }
        });
        
        // Check stylesheets
        document.querySelectorAll('link[rel="stylesheet"]').forEach(link => {
          const href = link.href;
          if (!href.startsWith(window.location.origin)) {
            external.push({type: 'stylesheet', url: href});
            if (link.integrity) {
              withIntegrity.push({type: 'stylesheet', url: href, integrity: link.integrity});
            } else {
              withoutIntegrity.push({type: 'stylesheet', url: href});
            }
          }
        });
        
        return {
          totalExternal: external.length,
          withIntegrity: withIntegrity.length,
          withoutIntegrity: withoutIntegrity,
          coverage: external.length > 0 ? 
            (withIntegrity.length / external.length * 100) : 100
        };
      }''');
      
      sri.addAll(result as Map);
    } catch (e) {
      _logger.warning('Error checking SRI: $e');
    }
    
    return sri;
  }
  
  Map<String, dynamic> _calculateScore(Map<String, dynamic> results) {
    int totalScore = 0;
    int maxScore = 0;
    final summary = <String, dynamic>{};
    
    // CSP (20 points)
    maxScore += 20;
    if (results['headers']['csp']['present'] == true) {
      totalScore += (results['headers']['csp']['score'] / 100 * 20).round();
    }
    summary['csp'] = results['headers']['csp']['present'];
    
    // HSTS (20 points)
    maxScore += 20;
    if (results['headers']['hsts']['present'] == true) {
      totalScore += (results['headers']['hsts']['score'] / 100 * 20).round();
    }
    summary['hsts'] = results['headers']['hsts']['present'];
    
    // X-Frame-Options (10 points)
    maxScore += 10;
    if (results['headers']['xFrameOptions']['present'] == true) {
      totalScore += (results['headers']['xFrameOptions']['score'] / 100 * 10).round();
    }
    summary['xFrameOptions'] = results['headers']['xFrameOptions']['present'];
    
    // X-Content-Type-Options (10 points)
    maxScore += 10;
    if (results['headers']['xContentTypeOptions']['present'] == true) {
      totalScore += (results['headers']['xContentTypeOptions']['score'] / 100 * 10).round();
    }
    summary['xContentTypeOptions'] = results['headers']['xContentTypeOptions']['present'];
    
    // Referrer-Policy (10 points)
    maxScore += 10;
    if (results['headers']['referrerPolicy']['present'] == true) {
      totalScore += (results['headers']['referrerPolicy']['score'] / 100 * 10).round();
    }
    summary['referrerPolicy'] = results['headers']['referrerPolicy']['present'];
    
    // Permissions-Policy (10 points)
    maxScore += 10;
    if (results['headers']['permissionsPolicy']['present'] == true) {
      totalScore += (results['headers']['permissionsPolicy']['score'] / 100 * 10).round();
    }
    summary['permissionsPolicy'] = results['headers']['permissionsPolicy']['present'];
    
    // HTTPS (10 points)
    maxScore += 10;
    if (results['https'] == true) {
      totalScore += 10;
    }
    summary['https'] = results['https'];
    
    // No mixed content (5 points)
    maxScore += 5;
    if (results['mixedContent']['hasMixedContent'] != true) {
      totalScore += 5;
    }
    summary['noMixedContent'] = !results['mixedContent']['hasMixedContent'];
    
    // SRI (5 points)
    maxScore += 5;
    if (results['sri']['coverage'] >= 80) {
      totalScore += 5;
    } else if (results['sri']['coverage'] >= 50) {
      totalScore += 3;
    }
    summary['sri'] = results['sri']['coverage'];
    
    final score = (totalScore / maxScore * 100).round();
    
    // Calculate grade
    String grade;
    if (score >= 90) {
      grade = 'A+';
    } else if (score >= 80) {
      grade = 'A';
    } else if (score >= 70) {
      grade = 'B';
    } else if (score >= 60) {
      grade = 'C';
    } else if (score >= 50) {
      grade = 'D';
    } else {
      grade = 'F';
    }
    
    return {
      'score': score,
      'grade': grade,
      'summary': summary
    };
  }
  
  List<Map<String, dynamic>> _identifyVulnerabilities(Map<String, dynamic> results) {
    final vulnerabilities = <Map<String, dynamic>>[];
    
    // Critical vulnerabilities
    if (results['headers']['csp']['present'] != true) {
      vulnerabilities.add({
        'severity': 'critical',
        'type': 'Missing CSP',
        'description': 'No Content Security Policy header found',
        'impact': 'Vulnerable to XSS and data injection attacks'
      });
    }
    
    if (results['https'] != true) {
      vulnerabilities.add({
        'severity': 'critical',
        'type': 'No HTTPS',
        'description': 'Site is not served over HTTPS',
        'impact': 'Data transmitted in plain text, vulnerable to MITM attacks'
      });
    }
    
    if (results['mixedContent']['hasMixedContent'] == true) {
      vulnerabilities.add({
        'severity': 'high',
        'type': 'Mixed Content',
        'description': 'HTTPS page loads insecure HTTP resources',
        'impact': 'Undermines HTTPS security, vulnerable to MITM attacks',
        'resources': results['mixedContent']['insecureRequests']
      });
    }
    
    // High severity
    if (results['headers']['hsts']['present'] != true) {
      vulnerabilities.add({
        'severity': 'high',
        'type': 'Missing HSTS',
        'description': 'No Strict-Transport-Security header',
        'impact': 'Vulnerable to protocol downgrade attacks'
      });
    }
    
    if (results['headers']['xFrameOptions']['present'] != true) {
      vulnerabilities.add({
        'severity': 'high',
        'type': 'Clickjacking',
        'description': 'No X-Frame-Options header',
        'impact': 'Page can be embedded in iframes, vulnerable to clickjacking'
      });
    }
    
    // Medium severity
    if (results['headers']['xContentTypeOptions']['present'] != true) {
      vulnerabilities.add({
        'severity': 'medium',
        'type': 'MIME Sniffing',
        'description': 'No X-Content-Type-Options header',
        'impact': 'Browser may incorrectly detect MIME types'
      });
    }
    
    if (results['sri']['withoutIntegrity'].length > 0) {
      vulnerabilities.add({
        'severity': 'medium',
        'type': 'No SRI',
        'description': 'External resources loaded without Subresource Integrity',
        'impact': 'Vulnerable to compromised CDN attacks',
        'resources': results['sri']['withoutIntegrity']
      });
    }
    
    // Low severity
    if (results['securityTxt']['found'] != true) {
      vulnerabilities.add({
        'severity': 'low',
        'type': 'No security.txt',
        'description': 'No security.txt file found',
        'impact': 'Security researchers cannot easily report vulnerabilities'
      });
    }
    
    return vulnerabilities;
  }
  
  List<Map<String, dynamic>> _generateRecommendations(Map<String, dynamic> results) {
    final recommendations = <Map<String, dynamic>>[];
    
    // CSP recommendations
    if (results['headers']['csp']['present'] != true) {
      recommendations.add({
        'priority': 'critical',
        'category': 'Content Security Policy',
        'recommendation': 'Implement Content Security Policy',
        'example': "Content-Security-Policy: default-src 'self'; script-src 'self' 'unsafe-inline'",
        'documentation': 'https://developer.mozilla.org/en-US/docs/Web/HTTP/CSP'
      });
    }
    
    // HSTS recommendations
    if (results['headers']['hsts']['present'] != true) {
      recommendations.add({
        'priority': 'high',
        'category': 'Transport Security',
        'recommendation': 'Add Strict-Transport-Security header',
        'example': 'Strict-Transport-Security: max-age=31536000; includeSubDomains; preload',
        'documentation': 'https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Strict-Transport-Security'
      });
    } else if (results['headers']['hsts']['maxAge'] < 31536000) {
      recommendations.add({
        'priority': 'medium',
        'category': 'Transport Security',
        'recommendation': 'Increase HSTS max-age to at least 1 year (31536000 seconds)',
        'current': results['headers']['hsts']['maxAge'],
        'recommended': 31536000
      });
    }
    
    // Frame options
    if (results['headers']['xFrameOptions']['present'] != true) {
      recommendations.add({
        'priority': 'high',
        'category': 'Clickjacking Protection',
        'recommendation': 'Add X-Frame-Options header',
        'example': 'X-Frame-Options: DENY',
        'alternative': "Content-Security-Policy: frame-ancestors 'none'"
      });
    }
    
    // Content type options
    if (results['headers']['xContentTypeOptions']['present'] != true) {
      recommendations.add({
        'priority': 'medium',
        'category': 'MIME Type Security',
        'recommendation': 'Add X-Content-Type-Options header',
        'example': 'X-Content-Type-Options: nosniff'
      });
    }
    
    // Referrer policy
    if (results['headers']['referrerPolicy']['present'] != true) {
      recommendations.add({
        'priority': 'medium',
        'category': 'Privacy',
        'recommendation': 'Add Referrer-Policy header',
        'example': 'Referrer-Policy: strict-origin-when-cross-origin'
      });
    }
    
    // Permissions policy
    if (results['headers']['permissionsPolicy']['present'] != true) {
      recommendations.add({
        'priority': 'medium',
        'category': 'Feature Control',
        'recommendation': 'Add Permissions-Policy header',
        'example': 'Permissions-Policy: geolocation=(), microphone=(), camera=()'
      });
    }
    
    // SRI recommendations
    if (results['sri']['withoutIntegrity'].length > 0) {
      recommendations.add({
        'priority': 'medium',
        'category': 'Subresource Integrity',
        'recommendation': 'Add integrity attributes to external resources',
        'affectedResources': results['sri']['withoutIntegrity'].length,
        'example': '<script src="https://cdn.example.com/script.js" integrity="sha384-..." crossorigin="anonymous"></script>'
      });
    }
    
    // Cookie recommendations
    if (results['cookies']['insecureCookies'].length > 0) {
      recommendations.add({
        'priority': 'high',
        'category': 'Cookie Security',
        'recommendation': 'Set Secure and HttpOnly flags on all cookies',
        'affectedCookies': results['cookies']['insecureCookies'].length
      });
    }
    
    // Mixed content
    if (results['mixedContent']['hasMixedContent'] == true) {
      recommendations.add({
        'priority': 'critical',
        'category': 'Mixed Content',
        'recommendation': 'Load all resources over HTTPS',
        'affectedResources': results['mixedContent']['insecureRequests'].length,
        'types': results['mixedContent']['types']
      });
    }
    
    return recommendations;
  }
}

// Extension for AuditContext to hold security headers results
extension SecurityContext on AuditContext {
  static final _securityHeaders = Expando<Map<String, dynamic>>();
  
  Map<String, dynamic>? get securityHeaders => _securityHeaders[this];
  set securityHeaders(Map<String, dynamic>? value) => _securityHeaders[this] = value;
}