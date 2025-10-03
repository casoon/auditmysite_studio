import 'dart:convert';
import 'dart:io';
import 'package:logging/logging.dart';
import '../audits/audit_base.dart';

/// JSON Output Formatter for AuditMySite compatibility
/// Generates the exact same JSON format as the npm tool
class JsonFormatter {
  final Logger _logger = Logger('JsonFormatter');
  
  /// Format complete audit results to match npm tool structure
  Map<String, dynamic> formatAuditResults(AuditContext ctx) {
    final output = <String, dynamic>{
      'version': '2.0.0',
      'timestamp': DateTime.now().toIso8601String(),
      'url': ctx.url.toString(),
      'metadata': _formatMetadata(ctx),
      'scores': _formatScores(ctx),
      'categories': _formatCategories(ctx),
      'audits': _formatAudits(ctx),
      'entities': _formatEntities(ctx),
      'configSettings': _formatConfigSettings(ctx),
      'i18n': _formatI18n(),
      'timing': _formatTiming(ctx),
      'stackPacks': []
    };
    
    return output;
  }
  
  /// Format metadata section
  Map<String, dynamic> _formatMetadata(AuditContext ctx) {
    return {
      'url': ctx.url.toString(),
      'fetchTime': DateTime.now().toIso8601String(),
      'userAgent': ctx.userAgent ?? 'AuditMySite/1.0.0 (Dart)',
      'environment': {
        'networkUserAgent': ctx.userAgent ?? '',
        'hostUserAgent': 'AuditMySite/1.0.0',
        'benchmarkIndex': 1000
      },
      'lighthouseVersion': '11.0.0', // Compatibility version
      'toolName': 'AuditMySite',
      'requestedUrl': ctx.url.toString(),
      'finalUrl': ctx.finalUrl?.toString() ?? ctx.url.toString(),
      'runWarnings': ctx.warnings ?? []
    };
  }
  
  /// Format scores section
  Map<String, dynamic> _formatScores(AuditContext ctx) {
    final scores = <String, dynamic>{};
    
    // Performance score
    if (ctx.performance != null) {
      scores['performance'] = _calculatePerformanceScore(ctx);
    }
    
    // Accessibility score  
    if (ctx.accessibility != null) {
      scores['accessibility'] = _calculateAccessibilityScore(ctx);
    }
    
    // Best Practices score
    if (ctx.security != null || ctx.bestPractices != null) {
      scores['best-practices'] = _calculateBestPracticesScore(ctx);
    }
    
    // SEO score
    if (ctx.seo != null) {
      scores['seo'] = _calculateSeoScore(ctx);
    }
    
    // PWA score
    if (ctx.pwa != null) {
      scores['pwa'] = _calculatePwaScore(ctx);
    }
    
    return scores;
  }
  
  /// Format categories section
  Map<String, dynamic> _formatCategories(AuditContext ctx) {
    return {
      'performance': {
        'id': 'performance',
        'title': 'Performance',
        'score': _calculatePerformanceScore(ctx),
        'scoreDisplayMode': 'numeric',
        'auditRefs': _getPerformanceAudits(ctx)
      },
      'accessibility': {
        'id': 'accessibility', 
        'title': 'Accessibility',
        'score': _calculateAccessibilityScore(ctx),
        'scoreDisplayMode': 'numeric',
        'manualDescription': 'These items address areas which an automated testing tool cannot cover.',
        'auditRefs': _getAccessibilityAudits(ctx)
      },
      'best-practices': {
        'id': 'best-practices',
        'title': 'Best Practices',
        'score': _calculateBestPracticesScore(ctx),
        'scoreDisplayMode': 'numeric',
        'auditRefs': _getBestPracticesAudits(ctx)
      },
      'seo': {
        'id': 'seo',
        'title': 'SEO',
        'score': _calculateSeoScore(ctx),
        'scoreDisplayMode': 'numeric',
        'manualDescription': 'Run these additional validators for more SEO insights.',
        'auditRefs': _getSeoAudits(ctx)
      },
      'pwa': {
        'id': 'pwa',
        'title': 'PWA',
        'score': _calculatePwaScore(ctx),
        'scoreDisplayMode': 'numeric',
        'manualDescription': 'These checks validate the aspects of a Progressive Web App.',
        'auditRefs': _getPwaAudits(ctx)
      }
    };
  }
  
  /// Format individual audits section
  Map<String, dynamic> _formatAudits(AuditContext ctx) {
    final audits = <String, dynamic>{};
    
    // Performance audits
    if (ctx.performance != null) {
      audits.addAll(_formatPerformanceAudits(ctx));
    }
    
    // Core Web Vitals
    if (ctx.coreWebVitals != null) {
      audits.addAll(_formatCoreWebVitalsAudits(ctx));
    }
    
    // Network audits
    if (ctx.networkExtended != null) {
      audits.addAll(_formatNetworkAudits(ctx));
    }
    
    // Resource audits
    if (ctx.resources != null) {
      audits.addAll(_formatResourceAudits(ctx));
    }
    
    // Accessibility audits
    if (ctx.accessibility != null) {
      audits.addAll(_formatAccessibilityAudits(ctx));
    }
    
    // SEO audits
    if (ctx.seo != null) {
      audits.addAll(_formatSeoAudits(ctx));
    }
    
    // Security audits
    if (ctx.security != null) {
      audits.addAll(_formatSecurityAudits(ctx));
    }
    
    // PWA audits
    if (ctx.pwa != null) {
      audits.addAll(_formatPwaAudits(ctx));
    }
    
    // Mobile audits
    if (ctx.mobile != null) {
      audits.addAll(_formatMobileAudits(ctx));
    }
    
    // HTML validation
    if (ctx.htmlValidation != null) {
      audits.addAll(_formatHtmlValidationAudits(ctx));
    }
    
    return audits;
  }
  
  /// Format performance audits
  Map<String, dynamic> _formatPerformanceAudits(AuditContext ctx) {
    final audits = <String, dynamic>{};
    final perf = ctx.performance!;
    
    // First Contentful Paint
    audits['first-contentful-paint'] = {
      'id': 'first-contentful-paint',
      'title': 'First Contentful Paint',
      'description': 'First Contentful Paint marks the time at which the first text or image is painted.',
      'score': _normalizeScore(perf['metrics']?['firstContentfulPaint'], 0, 3000),
      'scoreDisplayMode': 'numeric',
      'numericValue': perf['metrics']?['firstContentfulPaint'] ?? 0,
      'numericUnit': 'millisecond',
      'displayValue': '${(perf['metrics']?['firstContentfulPaint'] ?? 0) / 1000} s'
    };
    
    // Speed Index
    audits['speed-index'] = {
      'id': 'speed-index',
      'title': 'Speed Index',
      'description': 'Speed Index shows how quickly the contents of a page are visibly populated.',
      'score': _normalizeScore(perf['metrics']?['speedIndex'], 0, 5800),
      'scoreDisplayMode': 'numeric',
      'numericValue': perf['metrics']?['speedIndex'] ?? 0,
      'numericUnit': 'millisecond',
      'displayValue': '${(perf['metrics']?['speedIndex'] ?? 0) / 1000} s'
    };
    
    // Time to Interactive
    audits['interactive'] = {
      'id': 'interactive',
      'title': 'Time to Interactive',
      'description': 'Time to interactive is the amount of time it takes for the page to become fully interactive.',
      'score': _normalizeScore(perf['metrics']?['interactive'], 0, 7300),
      'scoreDisplayMode': 'numeric',
      'numericValue': perf['metrics']?['interactive'] ?? 0,
      'numericUnit': 'millisecond',
      'displayValue': '${(perf['metrics']?['interactive'] ?? 0) / 1000} s'
    };
    
    // Total Blocking Time
    audits['total-blocking-time'] = {
      'id': 'total-blocking-time',
      'title': 'Total Blocking Time',
      'description': 'Sum of all time periods between FCP and Time to Interactive.',
      'score': _normalizeScore(perf['metrics']?['totalBlockingTime'], 0, 600),
      'scoreDisplayMode': 'numeric',
      'numericValue': perf['metrics']?['totalBlockingTime'] ?? 0,
      'numericUnit': 'millisecond',
      'displayValue': '${perf['metrics']?['totalBlockingTime'] ?? 0} ms'
    };
    
    return audits;
  }
  
  /// Format Core Web Vitals audits
  Map<String, dynamic> _formatCoreWebVitalsAudits(AuditContext ctx) {
    final audits = <String, dynamic>{};
    final cwv = ctx.coreWebVitals!;
    
    // Largest Contentful Paint
    audits['largest-contentful-paint'] = {
      'id': 'largest-contentful-paint',
      'title': 'Largest Contentful Paint',
      'description': 'Largest Contentful Paint marks the time at which the largest text or image is painted.',
      'score': cwv['lcp']?['score'] ?? 0,
      'scoreDisplayMode': 'numeric',
      'numericValue': cwv['lcp']?['value'] ?? 0,
      'numericUnit': 'millisecond',
      'displayValue': '${(cwv['lcp']?['value'] ?? 0) / 1000} s',
      'details': {
        'type': 'debugdata',
        'items': [cwv['lcp']?['element']]
      }
    };
    
    // First Input Delay
    audits['max-potential-fid'] = {
      'id': 'max-potential-fid',
      'title': 'Max Potential First Input Delay',
      'description': 'The maximum potential First Input Delay that your users could experience.',
      'score': cwv['fid']?['score'] ?? 0,
      'scoreDisplayMode': 'numeric',
      'numericValue': cwv['fid']?['value'] ?? 0,
      'numericUnit': 'millisecond',
      'displayValue': '${cwv['fid']?['value'] ?? 0} ms'
    };
    
    // Cumulative Layout Shift
    audits['cumulative-layout-shift'] = {
      'id': 'cumulative-layout-shift',
      'title': 'Cumulative Layout Shift',
      'description': 'Cumulative Layout Shift measures the movement of visible elements within the viewport.',
      'score': cwv['cls']?['score'] ?? 0,
      'scoreDisplayMode': 'numeric',
      'numericValue': cwv['cls']?['value'] ?? 0,
      'numericUnit': 'unitless',
      'displayValue': cwv['cls']?['value']?.toStringAsFixed(3) ?? '0',
      'details': {
        'type': 'debugdata',
        'items': cwv['cls']?['shifts'] ?? []
      }
    };
    
    return audits;
  }
  
  /// Format network audits
  Map<String, dynamic> _formatNetworkAudits(AuditContext ctx) {
    final audits = <String, dynamic>{};
    final network = ctx.networkExtended!;
    
    // Network requests
    audits['network-requests'] = {
      'id': 'network-requests',
      'title': 'Network Requests',
      'description': 'Lists all network requests made by the page.',
      'score': null,
      'scoreDisplayMode': 'informative',
      'details': {
        'type': 'table',
        'headings': [
          {'key': 'url', 'itemType': 'url', 'text': 'URL'},
          {'key': 'protocol', 'itemType': 'text', 'text': 'Protocol'},
          {'key': 'statusCode', 'itemType': 'numeric', 'text': 'Status'},
          {'key': 'mimeType', 'itemType': 'text', 'text': 'Type'},
          {'key': 'resourceSize', 'itemType': 'bytes', 'text': 'Size'},
          {'key': 'startTime', 'itemType': 'ms', 'text': 'Time'}
        ],
        'items': network['requests'] ?? []
      }
    };
    
    // Third-party summary
    audits['third-party-summary'] = {
      'id': 'third-party-summary',
      'title': 'Minimize third-party usage',
      'description': 'Third-party code can significantly impact load performance.',
      'score': network['thirdParty']?['percentage'] > 50 ? 0 : 1,
      'scoreDisplayMode': 'binary',
      'displayValue': '${network['thirdParty']?['count'] ?? 0} Third-Parties',
      'details': {
        'type': 'table',
        'headings': [
          {'key': 'entity', 'itemType': 'text', 'text': 'Third-Party'},
          {'key': 'transferSize', 'itemType': 'bytes', 'text': 'Transfer Size'},
          {'key': 'blockingTime', 'itemType': 'ms', 'text': 'Main-Thread Blocking Time'}
        ],
        'items': _formatThirdPartyItems(network['thirdParty'])
      }
    };
    
    // Uses HTTP/2
    audits['uses-http2'] = {
      'id': 'uses-http2',
      'title': network['protocols']?['http2Support'] == true ? 'Uses HTTP/2' : 'Does not use HTTP/2',
      'description': 'HTTP/2 offers many benefits over HTTP/1.1.',
      'score': network['protocols']?['http2Support'] == true ? 1 : 0,
      'scoreDisplayMode': 'binary',
      'displayValue': _getProtocolDisplay(network['protocols'])
    };
    
    return audits;
  }
  
  /// Format resource audits
  Map<String, dynamic> _formatResourceAudits(AuditContext ctx) {
    final audits = <String, dynamic>{};
    final resources = ctx.resources!;
    
    // Render-blocking resources
    audits['render-blocking-resources'] = {
      'id': 'render-blocking-resources',
      'title': 'Eliminate render-blocking resources',
      'description': 'Resources are blocking the first paint of your page.',
      'score': resources['renderBlocking']?.isEmpty == true ? 1 : 0,
      'scoreDisplayMode': 'numeric',
      'displayValue': '${resources['renderBlocking']?.length ?? 0} resources',
      'details': {
        'type': 'opportunity',
        'headings': [
          {'key': 'url', 'valueType': 'url', 'label': 'URL'},
          {'key': 'totalBytes', 'valueType': 'bytes', 'label': 'Transfer Size'},
          {'key': 'wastedMs', 'valueType': 'timespanMs', 'label': 'Potential Savings'}
        ],
        'items': resources['renderBlocking'] ?? []
      }
    };
    
    // Unused CSS
    audits['unused-css-rules'] = {
      'id': 'unused-css-rules',
      'title': 'Remove unused CSS',
      'description': 'Remove dead rules from stylesheets.',
      'score': _calculateUnusedCssScore(resources),
      'scoreDisplayMode': 'numeric',
      'displayValue': '${resources['css']?['unusedPercentage'] ?? 0}% unused',
      'details': {
        'type': 'opportunity',
        'headings': [
          {'key': 'url', 'valueType': 'url', 'label': 'URL'},
          {'key': 'totalBytes', 'valueType': 'bytes', 'label': 'Transfer Size'},
          {'key': 'wastedBytes', 'valueType': 'bytes', 'label': 'Potential Savings'}
        ],
        'items': resources['css']?['files'] ?? []
      }
    };
    
    // Image optimization
    audits['uses-optimized-images'] = {
      'id': 'uses-optimized-images',
      'title': 'Efficiently encode images',
      'description': 'Optimized images load faster and consume less cellular data.',
      'score': _calculateImageOptimizationScore(resources),
      'scoreDisplayMode': 'numeric',
      'details': {
        'type': 'opportunity',
        'headings': [
          {'key': 'url', 'valueType': 'url', 'label': 'URL'},
          {'key': 'totalBytes', 'valueType': 'bytes', 'label': 'Original'},
          {'key': 'wastedBytes', 'valueType': 'bytes', 'label': 'Potential Savings'}
        ],
        'items': resources['images']?['unoptimized'] ?? []
      }
    };
    
    return audits;
  }
  
  /// Format accessibility audits
  Map<String, dynamic> _formatAccessibilityAudits(AuditContext ctx) {
    final audits = <String, dynamic>{};
    final a11y = ctx.accessibility!;
    
    // Process axe violations
    if (a11y['violations'] != null) {
      for (final violation in a11y['violations']) {
        final id = violation['id'];
        audits[id] = {
          'id': id,
          'title': violation['description'],
          'description': violation['help'],
          'score': 0,
          'scoreDisplayMode': 'binary',
          'details': {
            'type': 'table',
            'headings': [
              {'key': 'node', 'itemType': 'node', 'text': 'Failing Elements'}
            ],
            'items': violation['nodes'] ?? []
          }
        };
      }
    }
    
    // Process axe passes
    if (a11y['passes'] != null) {
      for (final pass in a11y['passes']) {
        final id = pass['id'];
        audits[id] = {
          'id': id,
          'title': pass['description'],
          'description': pass['help'],
          'score': 1,
          'scoreDisplayMode': 'binary'
        };
      }
    }
    
    return audits;
  }
  
  /// Format SEO audits
  Map<String, dynamic> _formatSeoAudits(AuditContext ctx) {
    final audits = <String, dynamic>{};
    final seo = ctx.seo!;
    
    // Document has title
    audits['document-title'] = {
      'id': 'document-title',
      'title': seo['meta']?['title'] != null ? 'Document has a title element' : 'Document doesn\'t have a title element',
      'description': 'The title element is critical for SEO.',
      'score': seo['meta']?['title'] != null ? 1 : 0,
      'scoreDisplayMode': 'binary'
    };
    
    // Meta description
    audits['meta-description'] = {
      'id': 'meta-description',
      'title': seo['meta']?['description'] != null ? 'Document has a meta description' : 'Document does not have a meta description',
      'description': 'Meta descriptions may be included in search results to concisely summarize page content.',
      'score': seo['meta']?['description'] != null ? 1 : 0,
      'scoreDisplayMode': 'binary'
    };
    
    // Viewport
    audits['viewport'] = {
      'id': 'viewport',
      'title': seo['meta']?['viewport'] != null ? 'Has a viewport meta tag' : 'Does not have a viewport meta tag',
      'description': 'A viewport meta tag optimizes your app for mobile screens.',
      'score': seo['meta']?['viewport'] != null ? 1 : 0,
      'scoreDisplayMode': 'binary'
    };
    
    // Structured data
    audits['structured-data'] = {
      'id': 'structured-data',
      'title': 'Structured data is valid',
      'description': 'Search engines use structured data to understand page content.',
      'score': seo['structuredData']?['valid'] == true ? 1 : 0,
      'scoreDisplayMode': 'binary',
      'details': {
        'type': 'table',
        'headings': [
          {'key': 'type', 'itemType': 'text', 'text': 'Schema Type'},
          {'key': 'errors', 'itemType': 'text', 'text': 'Errors'}
        ],
        'items': seo['structuredData']?['schemas'] ?? []
      }
    };
    
    return audits;
  }
  
  /// Format security audits
  Map<String, dynamic> _formatSecurityAudits(AuditContext ctx) {
    final audits = <String, dynamic>{};
    final security = ctx.security!;
    
    // HTTPS
    audits['is-on-https'] = {
      'id': 'is-on-https',
      'title': ctx.url.scheme == 'https' ? 'Uses HTTPS' : 'Does not use HTTPS',
      'description': 'All sites should be protected with HTTPS.',
      'score': ctx.url.scheme == 'https' ? 1 : 0,
      'scoreDisplayMode': 'binary'
    };
    
    // Security headers
    final headers = security['headers'] ?? {};
    
    audits['csp-xss'] = {
      'id': 'csp-xss',
      'title': headers['content-security-policy'] != null ? 
        'Has Content Security Policy' : 'Missing Content Security Policy',
      'description': 'CSP helps prevent XSS attacks.',
      'score': headers['content-security-policy'] != null ? 1 : 0,
      'scoreDisplayMode': 'binary'
    };
    
    return audits;
  }
  
  /// Format PWA audits
  Map<String, dynamic> _formatPwaAudits(AuditContext ctx) {
    final audits = <String, dynamic>{};
    final pwa = ctx.pwa!;
    
    // Service Worker
    audits['service-worker'] = {
      'id': 'service-worker',
      'title': pwa['serviceWorker'] == true ? 
        'Registers a service worker' : 'Does not register a service worker',
      'description': 'Service workers enable offline functionality.',
      'score': pwa['serviceWorker'] == true ? 1 : 0,
      'scoreDisplayMode': 'binary'
    };
    
    // Web app manifest
    audits['webapp-install-banner'] = {
      'id': 'webapp-install-banner',
      'title': pwa['manifest'] != null ? 
        'Web app manifest meets installability requirements' : 
        'Web app manifest does not meet installability requirements',
      'description': 'A web app manifest is required for installability.',
      'score': pwa['installable'] == true ? 1 : 0,
      'scoreDisplayMode': 'binary',
      'details': {
        'type': 'debugdata',
        'items': [pwa['manifest']]
      }
    };
    
    return audits;
  }
  
  /// Format mobile audits
  Map<String, dynamic> _formatMobileAudits(AuditContext ctx) {
    final audits = <String, dynamic>{};
    final mobile = ctx.mobile!;
    
    // Mobile-friendly
    audits['mobile-friendly'] = {
      'id': 'mobile-friendly',
      'title': mobile['isMobileFriendly'] == true ? 
        'Page is mobile-friendly' : 'Page is not mobile-friendly',
      'description': 'Mobile-friendly pages are easier to read and use on mobile devices.',
      'score': mobile['score'] ?? 0,
      'scoreDisplayMode': 'numeric',
      'details': {
        'type': 'debugdata',
        'items': mobile['issues'] ?? []
      }
    };
    
    // Tap targets
    audits['tap-targets'] = {
      'id': 'tap-targets',
      'title': mobile['tapTargets']?['appropriate'] == true ? 
        'Tap targets are sized appropriately' : 
        'Tap targets are not sized appropriately',
      'description': 'Interactive elements should be large enough and have enough space around them.',
      'score': mobile['tapTargets']?['appropriate'] == true ? 1 : 0,
      'scoreDisplayMode': 'binary',
      'details': {
        'type': 'table',
        'headings': [
          {'key': 'tapTarget', 'itemType': 'node', 'text': 'Tap Target'},
          {'key': 'size', 'itemType': 'text', 'text': 'Size'},
          {'key': 'overlappingTarget', 'itemType': 'node', 'text': 'Overlapping Target'}
        ],
        'items': mobile['tapTargets']?['failing'] ?? []
      }
    };
    
    return audits;
  }
  
  /// Format HTML validation audits
  Map<String, dynamic> _formatHtmlValidationAudits(AuditContext ctx) {
    final audits = <String, dynamic>{};
    final html = ctx.htmlValidation!;
    
    // HTML validation
    audits['valid-html'] = {
      'id': 'valid-html',
      'title': html['errors']?.isEmpty == true ? 
        'HTML is valid' : 'HTML has validation errors',
      'description': 'Valid HTML helps ensure compatibility.',
      'score': html['errors']?.isEmpty == true ? 1 : 0,
      'scoreDisplayMode': 'binary',
      'displayValue': '${html['errors']?.length ?? 0} errors, ${html['warnings']?.length ?? 0} warnings',
      'details': {
        'type': 'table',
        'headings': [
          {'key': 'level', 'itemType': 'text', 'text': 'Level'},
          {'key': 'message', 'itemType': 'text', 'text': 'Message'},
          {'key': 'line', 'itemType': 'numeric', 'text': 'Line'},
          {'key': 'column', 'itemType': 'numeric', 'text': 'Column'}
        ],
        'items': [
          ...?(html['errors'] ?? []),
          ...?(html['warnings'] ?? [])
        ]
      }
    };
    
    return audits;
  }
  
  /// Format entities (third-party providers)
  List<Map<String, dynamic>> _formatEntities(AuditContext ctx) {
    final entities = <Map<String, dynamic>>[];
    
    if (ctx.networkExtended != null) {
      final thirdParty = ctx.networkExtended!['thirdParty'];
      if (thirdParty != null && thirdParty['domains'] != null) {
        (thirdParty['domains'] as Map).forEach((domain, count) {
          entities.add({
            'name': domain,
            'homepage': 'https://$domain',
            'category': _categorizeEntity(domain),
            'isFirstParty': false,
            'isUnrecognized': false
          });
        });
      }
    }
    
    return entities;
  }
  
  /// Format config settings
  Map<String, dynamic> _formatConfigSettings(AuditContext ctx) {
    return {
      'output': ['json'],
      'channel': 'node',
      'budgets': null,
      'locale': 'en-US',
      'blockedUrlPatterns': null,
      'additionalTraceCategories': null,
      'extraHeaders': null,
      'precomputedLanternData': null,
      'onlyCategories': null,
      'onlyAudits': null,
      'skipAudits': null,
      'formFactor': 'desktop',
      'throttling': {
        'rttMs': 40,
        'throughputKbps': 10240,
        'requestLatencyMs': 0,
        'downloadThroughputKbps': 0,
        'uploadThroughputKbps': 0,
        'cpuSlowdownMultiplier': 1
      },
      'throttlingMethod': 'devtools',
      'screenEmulation': {
        'mobile': false,
        'width': 1920,
        'height': 1080,
        'deviceScaleFactor': 1,
        'disabled': false
      },
      'emulatedUserAgent': ctx.userAgent ?? ''
    };
  }
  
  /// Format i18n data
  Map<String, dynamic> _formatI18n() {
    return {
      'rendererFormattedStrings': {
        'varianceDisclaimer': 'Values are estimated and may vary.',
        'opportunityResourceColumnLabel': 'Opportunity',
        'opportunitySavingsColumnLabel': 'Estimated Savings',
        'errorMissingAuditInfo': 'Report error: no audit information',
        'errorLabel': 'Error!',
        'warningHeader': 'Warnings: ',
        'auditGroupExpandTooltip': 'Show audits',
        'passedAuditsGroupTitle': 'Passed audits',
        'notApplicableAuditsGroupTitle': 'Not applicable',
        'manualAuditsGroupTitle': 'Additional items to manually check',
        'toplevelWarningsMessage': 'There were issues affecting this run',
        'crcLongestDurationLabel': 'Maximum critical path latency:',
        'crcInitialNavigation': 'Initial Navigation',
        'lsPerformanceCategoryDescription': 'These metrics measure performance.',
        'labDataTitle': 'Lab Data'
      },
      'icuMessagePaths': {}
    };
  }
  
  /// Format timing data
  Map<String, dynamic> _formatTiming(AuditContext ctx) {
    return {
      'entries': [
        {
          'name': 'lh:init:config',
          'duration': 10,
          'startTime': 0
        },
        {
          'name': 'lh:runner:run',
          'duration': ctx.timing?['total'] ?? 1000,
          'startTime': 10
        },
        {
          'name': 'lh:audit',
          'duration': ctx.timing?['audits'] ?? 500,
          'startTime': 100
        }
      ],
      'total': ctx.timing?['total'] ?? 1000
    };
  }
  
  // Helper methods
  
  double _normalizeScore(dynamic value, double min, double max) {
    if (value == null) return 0;
    final v = value is int ? value.toDouble() : value as double;
    if (v <= min) return 1.0;
    if (v >= max) return 0.0;
    return 1.0 - ((v - min) / (max - min));
  }
  
  double _calculatePerformanceScore(AuditContext ctx) {
    if (ctx.performance == null) return 0;
    return (ctx.performance!['score'] ?? 0).toDouble() / 100;
  }
  
  double _calculateAccessibilityScore(AuditContext ctx) {
    if (ctx.accessibility == null) return 0;
    final violations = ctx.accessibility!['violations']?.length ?? 0;
    final passes = ctx.accessibility!['passes']?.length ?? 1;
    return passes / (passes + violations);
  }
  
  double _calculateBestPracticesScore(AuditContext ctx) {
    double score = 1.0;
    
    if (ctx.url.scheme != 'https') score -= 0.2;
    
    if (ctx.security != null) {
      final headers = ctx.security!['headers'] ?? {};
      if (headers['content-security-policy'] == null) score -= 0.1;
      if (headers['x-frame-options'] == null) score -= 0.1;
    }
    
    return score < 0 ? 0 : score;
  }
  
  double _calculateSeoScore(AuditContext ctx) {
    if (ctx.seo == null) return 0;
    return (ctx.seo!['score'] ?? 0).toDouble() / 100;
  }
  
  double _calculatePwaScore(AuditContext ctx) {
    if (ctx.pwa == null) return 0;
    int score = 0;
    int total = 0;
    
    if (ctx.pwa!['serviceWorker'] == true) score++;
    total++;
    
    if (ctx.pwa!['manifest'] != null) score++;
    total++;
    
    if (ctx.url.scheme == 'https') score++;
    total++;
    
    if (ctx.pwa!['installable'] == true) score++;
    total++;
    
    return total > 0 ? score / total : 0;
  }
  
  List<Map<String, dynamic>> _getPerformanceAudits(AuditContext ctx) {
    return [
      {'id': 'first-contentful-paint', 'weight': 10, 'group': 'metrics'},
      {'id': 'largest-contentful-paint', 'weight': 25, 'group': 'metrics'},
      {'id': 'speed-index', 'weight': 10, 'group': 'metrics'},
      {'id': 'interactive', 'weight': 10, 'group': 'metrics'},
      {'id': 'total-blocking-time', 'weight': 30, 'group': 'metrics'},
      {'id': 'cumulative-layout-shift', 'weight': 15, 'group': 'metrics'}
    ];
  }
  
  List<Map<String, dynamic>> _getAccessibilityAudits(AuditContext ctx) {
    final auditRefs = <Map<String, dynamic>>[];
    
    if (ctx.accessibility != null) {
      // Add all axe audit IDs
      if (ctx.accessibility!['violations'] != null) {
        for (final v in ctx.accessibility!['violations']) {
          auditRefs.add({'id': v['id'], 'weight': 1});
        }
      }
      if (ctx.accessibility!['passes'] != null) {
        for (final p in ctx.accessibility!['passes']) {
          auditRefs.add({'id': p['id'], 'weight': 0});
        }
      }
    }
    
    return auditRefs;
  }
  
  List<Map<String, dynamic>> _getBestPracticesAudits(AuditContext ctx) {
    return [
      {'id': 'is-on-https', 'weight': 1},
      {'id': 'csp-xss', 'weight': 0}
    ];
  }
  
  List<Map<String, dynamic>> _getSeoAudits(AuditContext ctx) {
    return [
      {'id': 'document-title', 'weight': 1},
      {'id': 'meta-description', 'weight': 1},
      {'id': 'viewport', 'weight': 1},
      {'id': 'structured-data', 'weight': 0}
    ];
  }
  
  List<Map<String, dynamic>> _getPwaAudits(AuditContext ctx) {
    return [
      {'id': 'service-worker', 'weight': 1},
      {'id': 'webapp-install-banner', 'weight': 1}
    ];
  }
  
  List<Map<String, dynamic>> _formatThirdPartyItems(dynamic thirdParty) {
    if (thirdParty == null || thirdParty['categories'] == null) return [];
    
    final items = <Map<String, dynamic>>[];
    (thirdParty['categories'] as Map).forEach((category, count) {
      items.add({
        'entity': category,
        'transferSize': (thirdParty['size'] ?? 0) ~/ (thirdParty['categories'].length),
        'blockingTime': 0
      });
    });
    
    return items;
  }
  
  String _getProtocolDisplay(dynamic protocols) {
    if (protocols == null) return 'Unknown';
    
    if (protocols['http3'] > 0) return 'HTTP/3 (QUIC)';
    if (protocols['http2'] > 0) return 'HTTP/2';
    return 'HTTP/1.1';
  }
  
  double _calculateUnusedCssScore(Map<String, dynamic> resources) {
    final unused = resources['css']?['unusedPercentage'] ?? 0;
    if (unused < 10) return 1.0;
    if (unused < 30) return 0.8;
    if (unused < 50) return 0.5;
    return 0.0;
  }
  
  double _calculateImageOptimizationScore(Map<String, dynamic> resources) {
    final unoptimized = resources['images']?['unoptimized']?.length ?? 0;
    if (unoptimized == 0) return 1.0;
    if (unoptimized < 3) return 0.8;
    if (unoptimized < 5) return 0.5;
    return 0.0;
  }
  
  String _categorizeEntity(String domain) {
    if (domain.contains('google')) return 'Google';
    if (domain.contains('facebook')) return 'Facebook';
    if (domain.contains('amazon')) return 'CDN';
    if (domain.contains('cloudflare')) return 'CDN';
    return 'Other';
  }
  
  /// Save results to file
  Future<void> saveToFile(Map<String, dynamic> results, String filePath) async {
    try {
      final file = File(filePath);
      final encoder = JsonEncoder.withIndent('  ');
      await file.writeAsString(encoder.convert(results));
      _logger.info('Results saved to: $filePath');
    } catch (e) {
      _logger.severe('Error saving results to file: $e');
      rethrow;
    }
  }
  
  /// Load and validate JSON results
  static Future<Map<String, dynamic>> loadFromFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('File not found', filePath);
    }
    
    final content = await file.readAsString();
    final json = jsonDecode(content);
    
    // Validate structure
    if (json['version'] == null || json['audits'] == null) {
      throw FormatException('Invalid AuditMySite JSON format');
    }
    
    return json;
  }
}