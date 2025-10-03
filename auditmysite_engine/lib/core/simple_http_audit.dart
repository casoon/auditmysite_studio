import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';

/// Simple HTTP-based audit without browser automation
/// This is a fallback when Puppeteer fails
class SimpleHttpAudit {
  /// Perform a simple HTTP audit of a URL
  static Future<Map<String, dynamic>> auditUrl(String url) async {
    final results = <String, dynamic>{
      'url': url,
      'timestamp': DateTime.now().toIso8601String(),
      'audits': {},
    };
    
    try {
      // Make HTTP request
      final stopwatch = Stopwatch()..start();
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'AuditMySite/1.0 (Desktop Studio; +https://auditmysite.io)',
        },
      ).timeout(Duration(seconds: 30));
      stopwatch.stop();
      
      // Basic HTTP audit
      results['audits']['http'] = {
        'statusCode': response.statusCode,
        'statusText': _getStatusText(response.statusCode),
        'responseTime': stopwatch.elapsedMilliseconds,
        'contentLength': response.contentLength ?? response.body.length,
        'headers': response.headers,
      };
      
      // Basic performance metrics
      results['audits']['performance'] = {
        'responseTime': stopwatch.elapsedMilliseconds,
        'size': response.body.length,
        'compression': response.headers['content-encoding'],
      };
      
      // Basic SEO checks
      final body = response.body.toLowerCase();
      results['audits']['seo'] = {
        'hasTitle': body.contains('<title>') && body.contains('</title>'),
        'hasDescription': body.contains('meta name="description"'),
        'hasH1': body.contains('<h1>') || body.contains('<h1 '),
        'hasCanonical': body.contains('rel="canonical"'),
      };
      
      // Content analysis
      results['audits']['content'] = {
        'htmlLength': response.body.length,
        'wordCount': _countWords(response.body),
        'hasImages': body.contains('<img '),
        'hasLinks': body.contains('<a '),
      };
      
      results['success'] = true;
      results['error'] = null;
      
    } catch (e) {
      results['success'] = false;
      results['error'] = e.toString();
    }
    
    return results;
  }
  
  /// Audit multiple URLs
  static Stream<Map<String, dynamic>> auditUrls(List<String> urls) async* {
    for (final url in urls) {
      yield await auditUrl(url);
    }
  }
  
  static int _countWords(String html) {
    // Remove HTML tags
    final text = html.replaceAll(RegExp(r'<[^>]*>'), ' ');
    // Count words
    final words = text.split(RegExp(r'\s+'));
    return words.where((w) => w.isNotEmpty).length;
  }
  
  static String _getStatusText(int statusCode) {
    switch (statusCode) {
      case 200: return 'OK';
      case 201: return 'Created';
      case 204: return 'No Content';
      case 301: return 'Moved Permanently';
      case 302: return 'Found';
      case 304: return 'Not Modified';
      case 400: return 'Bad Request';
      case 401: return 'Unauthorized';
      case 403: return 'Forbidden';
      case 404: return 'Not Found';
      case 500: return 'Internal Server Error';
      case 502: return 'Bad Gateway';
      case 503: return 'Service Unavailable';
      default: return 'Status $statusCode';
    }
  }
  
  /// Enhanced audit with more detailed analysis
  static Future<Map<String, dynamic>> auditUrlEnhanced(String url) async {
    final results = <String, dynamic>{
      'url': url,
      'timestamp': DateTime.now().toIso8601String(),
      'audits': {},
      'scores': {},
      'recommendations': {
        'high': <Map<String, dynamic>>[],
        'medium': <Map<String, dynamic>>[],
        'low': <Map<String, dynamic>>[],
      },
    };
    
    try {
      // Make HTTP request with detailed timing
      final stopwatch = Stopwatch()..start();
      final ttfbStopwatch = Stopwatch()..start();
      
      // First, make a HEAD request to measure TTFB
      try {
        await http.head(
          Uri.parse(url),
          headers: {
            'User-Agent': 'AuditMySite/1.0 (Desktop Studio; +https://auditmysite.io)',
          },
        ).timeout(Duration(seconds: 5));
        ttfbStopwatch.stop();
      } catch (_) {
        // Ignore HEAD errors
      }
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'AuditMySite/1.0 (Desktop Studio; +https://auditmysite.io)',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.5',
          'Accept-Encoding': 'gzip, deflate',
          'Connection': 'keep-alive',
        },
      ).timeout(Duration(seconds: 30));
      stopwatch.stop();
      
      // Calculate real TTFB
      final realTtfb = ttfbStopwatch.isRunning ? stopwatch.elapsedMilliseconds : ttfbStopwatch.elapsedMilliseconds;
      
      // Parse HTML
      final document = html_parser.parse(response.body);
      
      // Enhanced HTTP audit
      results['audits']['http'] = {
        'statusCode': response.statusCode,
        'statusText': _getStatusText(response.statusCode),
        'responseTime': stopwatch.elapsedMilliseconds,
        'contentLength': response.contentLength ?? response.body.length,
        'contentType': response.headers['content-type'],
        'server': response.headers['server'],
        'cacheControl': response.headers['cache-control'],
        'expires': response.headers['expires'],
        'lastModified': response.headers['last-modified'],
        'etag': response.headers['etag'],
        'headers': response.headers,
        'redirects': response.isRedirect,
        'secure': url.startsWith('https'),
      };
      
      // Enhanced performance metrics with real data
      final sizeKb = (response.body.length / 1024).toStringAsFixed(2);
      
      // Count actual external resources
      final scriptTags = document.querySelectorAll('script');
      final externalScripts = scriptTags.where((s) => s.attributes['src'] != null).length;
      final inlineScripts = scriptTags.length - externalScripts;
      
      final stylesheets = document.querySelectorAll('link[rel="stylesheet"]');
      final styleBlocks = document.querySelectorAll('style').length;
      
      // Analyze resource loading hints
      final preloads = document.querySelectorAll('link[rel="preload"]').length;
      final preconnects = document.querySelectorAll('link[rel="preconnect"]').length;
      final dnsPrefetch = document.querySelectorAll('link[rel="dns-prefetch"]').length;
      
      results['audits']['performance'] = {
        'responseTime': stopwatch.elapsedMilliseconds,
        'size': response.body.length,
        'sizeKb': sizeKb,
        'compression': response.headers['content-encoding'],
        'ttfb': realTtfb, // Use real TTFB
        'domElements': document.querySelectorAll('*').length,
        'scripts': scriptTags.length,
        'externalScripts': externalScripts,
        'inlineScripts': inlineScripts,
        'stylesheets': stylesheets.length,
        'styleBlocks': styleBlocks,
        'images': document.querySelectorAll('img').length,
        'iframes': document.querySelectorAll('iframe').length,
        'preloads': preloads,
        'preconnects': preconnects,
        'dnsPrefetch': dnsPrefetch,
      };
      
      // Enhanced SEO analysis
      final title = document.querySelector('title')?.text ?? '';
      final description = document.querySelector('meta[name="description"]')?.attributes['content'] ?? '';
      final keywords = document.querySelector('meta[name="keywords"]')?.attributes['content'] ?? '';
      final canonical = document.querySelector('link[rel="canonical"]')?.attributes['href'];
      final robots = document.querySelector('meta[name="robots"]')?.attributes['content'];
      final viewport = document.querySelector('meta[name="viewport"]')?.attributes['content'];
      
      final h1Tags = document.querySelectorAll('h1');
      final h2Tags = document.querySelectorAll('h2');
      final h3Tags = document.querySelectorAll('h3');
      
      // Open Graph tags
      final ogTitle = document.querySelector('meta[property="og:title"]')?.attributes['content'];
      final ogDescription = document.querySelector('meta[property="og:description"]')?.attributes['content'];
      final ogImage = document.querySelector('meta[property="og:image"]')?.attributes['content'];
      
      results['audits']['seo'] = {
        'hasTitle': title.isNotEmpty,
        'title': title,
        'titleLength': title.length,
        'hasDescription': description.isNotEmpty,
        'description': description,
        'descriptionLength': description.length,
        'hasKeywords': keywords.isNotEmpty,
        'keywords': keywords,
        'hasCanonical': canonical != null,
        'canonical': canonical,
        'hasRobots': robots != null,
        'robots': robots,
        'h1Count': h1Tags.length,
        'h1Text': h1Tags.map((e) => e.text).toList(),
        'h2Count': h2Tags.length,
        'h3Count': h3Tags.length,
        'hasOgTitle': ogTitle != null,
        'ogTitle': ogTitle,
        'hasOgDescription': ogDescription != null,
        'ogDescription': ogDescription,
        'hasOgImage': ogImage != null,
        'ogImage': ogImage,
        'hasViewport': document.querySelector('meta[name="viewport"]') != null,
        'hasLang': document.querySelector('html')?.attributes['lang'] != null,
        'lang': document.querySelector('html')?.attributes['lang'],
      };
      
      // Enhanced content analysis
      final links = document.querySelectorAll('a[href]');
      final internalLinks = links.where((link) {
        final href = link.attributes['href'] ?? '';
        return href.startsWith('/') || href.contains(Uri.parse(url).host);
      }).toList();
      final externalLinks = links.where((link) {
        final href = link.attributes['href'] ?? '';
        return href.startsWith('http') && !href.contains(Uri.parse(url).host);
      }).toList();
      
      final images = document.querySelectorAll('img');
      final imagesWithAlt = images.where((img) => img.attributes['alt']?.isNotEmpty ?? false);
      
      results['audits']['content'] = {
        'htmlLength': response.body.length,
        'textContent': document.body?.text.length ?? 0,
        'wordCount': _countWords(response.body),
        'hasImages': images.isNotEmpty,
        'imageCount': images.length,
        'imagesWithAlt': imagesWithAlt.length,
        'imagesWithoutAlt': images.length - imagesWithAlt.length,
        'hasLinks': links.isNotEmpty,
        'linkCount': links.length,
        'internalLinks': internalLinks.length,
        'externalLinks': externalLinks.length,
        'forms': document.querySelectorAll('form').length,
        'videos': document.querySelectorAll('video').length,
        'tables': document.querySelectorAll('table').length,
      };
      
      // Enhanced Accessibility analysis (simulated without axe-core)
      final buttons = document.querySelectorAll('button');
      final buttonsWithoutLabel = buttons.where((btn) => 
        btn.text.isEmpty && btn.attributes['aria-label'] == null
      ).length;
      
      final inputs = document.querySelectorAll('input');
      final inputsWithoutLabel = inputs.where((input) {
        final id = input.attributes['id'];
        if (id == null) return true;
        final label = document.querySelector('label[for="$id"]');
        return label == null && input.attributes['aria-label'] == null;
      }).length;
      
      // Check for ARIA landmarks
      final hasMain = document.querySelector('main') != null || 
                      document.querySelector('[role="main"]') != null;
      final hasNav = document.querySelector('nav') != null || 
                     document.querySelector('[role="navigation"]') != null;
      final hasFooter = document.querySelector('footer') != null || 
                        document.querySelector('[role="contentinfo"]') != null;
      
      results['audits']['accessibility'] = {
        'imagesWithoutAlt': images.length - imagesWithAlt.length,
        'buttonsWithoutLabel': buttonsWithoutLabel,
        'inputsWithoutLabel': inputsWithoutLabel,
        'hasMainLandmark': hasMain,
        'hasNavLandmark': hasNav,
        'hasFooterLandmark': hasFooter,
        'hasLangAttribute': document.querySelector('html')?.attributes['lang'] != null,
        'langValue': document.querySelector('html')?.attributes['lang'],
        'hasViewport': viewport != null,
        'viewportContent': viewport,
        // Simulated scores (in real implementation, use axe-core)
        'estimatedA11yScore': _calculateA11yScore({
          'imagesWithoutAlt': images.length - imagesWithAlt.length,
          'buttonsWithoutLabel': buttonsWithoutLabel,
          'hasLang': document.querySelector('html')?.attributes['lang'] != null,
          'hasViewport': viewport != null,
          'hasMain': hasMain,
        }),
        'wcagLevel': 'Unknown (Manual check required)',
      };
      
      // Mobile friendliness analysis
      final hasResponsiveViewport = viewport?.contains('width=device-width') ?? false;
      final hasScalableViewport = !(viewport?.contains('user-scalable=no') ?? false);
      
      results['audits']['mobile'] = {
        'hasViewport': viewport != null,
        'hasResponsiveViewport': hasResponsiveViewport,
        'isScalable': hasScalableViewport,
        'viewportContent': viewport,
        // Check for common mobile-unfriendly patterns
        'hasFlash': response.body.contains('.swf') || response.body.contains('flash'),
        'usesPlugins': response.body.contains('<object') || response.body.contains('<embed'),
        'estimatedMobileScore': _calculateMobileScore({
          'hasViewport': viewport != null,
          'hasResponsiveViewport': hasResponsiveViewport,
          'isScalable': hasScalableViewport,
        }),
      };
      
      // Use real performance data from above
      final jsFiles = externalScripts;
      final cssFiles = stylesheets.length;
      final fonts = document.querySelectorAll('link[rel="preload"][as="font"]').length +
                    document.querySelectorAll('link[rel="preconnect"]').where((link) => 
                      link.attributes['href']?.contains('fonts') ?? false
                    ).length;
      
      // Estimate Core Web Vitals using real metrics
      final estimatedLCP = _estimateLCP(response.body.length, realTtfb, jsFiles, cssFiles);
      final estimatedFCP = _estimateFCP(realTtfb, response.body.length);
      final estimatedTBT = _estimateTBT(jsFiles, response.body.length);
      
      results['audits']['coreWebVitals'] = {
        'lcp': estimatedLCP,
        'fcp': estimatedFCP,
        'cls': 0.0, // Cannot measure without browser
        'tbt': estimatedTBT,
        'tti': estimatedLCP + 500, // Rough estimate
        'speedIndex': estimatedFCP + 200, // Rough estimate
        'note': 'Values are estimated without real browser metrics',
      };
      
      // Resource breakdown
      results['audits']['resources'] = {
        'totalRequests': 1 + jsFiles + cssFiles + images.length, // Main doc + resources
        'javascriptFiles': jsFiles,
        'stylesheets': cssFiles,
        'images': images.length,
        'fonts': fonts,
        'videos': document.querySelectorAll('video').length,
        'iframes': document.querySelectorAll('iframe').length,
      };
      
      // Calculate scores
      results['scores'] = _calculateScores(results['audits']);
      
      // Generate recommendations
      results['recommendations'] = _generateRecommendations(results['audits']);
      
      results['success'] = true;
      results['error'] = null;
      
    } catch (e) {
      results['success'] = false;
      results['error'] = e.toString();
      
      // Add basic error info
      results['audits']['http'] = {
        'statusCode': 0,
        'statusText': 'Failed',
        'error': e.toString(),
      };
    }
    
    return results;
  }
  
  static Map<String, int> _calculateScores(Map<String, dynamic> audits) {
    final scores = <String, int>{};
    
    // Performance score (enhanced with Core Web Vitals)
    int perfScore = 100;
    if (audits['coreWebVitals'] != null) {
      final cwv = audits['coreWebVitals'];
      final lcp = cwv['lcp'] ?? 0;
      final fcp = cwv['fcp'] ?? 0;
      final tbt = cwv['tbt'] ?? 0;
      
      // LCP scoring
      if (lcp > 4000) perfScore -= 30;
      else if (lcp > 2500) perfScore -= 15;
      
      // FCP scoring
      if (fcp > 3000) perfScore -= 20;
      else if (fcp > 1800) perfScore -= 10;
      
      // TBT scoring
      if (tbt > 600) perfScore -= 20;
      else if (tbt > 300) perfScore -= 10;
    } else if (audits['performance'] != null) {
      final perf = audits['performance'];
      if (perf['responseTime'] > 3000) perfScore -= 30;
      else if (perf['responseTime'] > 1000) perfScore -= 10;
      
      if (perf['size'] > 1000000) perfScore -= 20;
      else if (perf['size'] > 500000) perfScore -= 10;
      
      if (perf['compression'] == null) perfScore -= 10;
      if (perf['images'] > 20) perfScore -= 10;
    }
    scores['performanceScore'] = perfScore.clamp(0, 100);
    
    // SEO score
    int seoScore = 100;
    if (audits['seo'] != null) {
      final seo = audits['seo'];
      if (!(seo['hasTitle'] ?? false)) seoScore -= 30;
      if (!(seo['hasDescription'] ?? false)) seoScore -= 20;
      if (seo['h1Count'] == 0) seoScore -= 15;
      if (seo['h1Count'] > 1) seoScore -= 5;
      if (!(seo['hasViewport'] ?? false)) seoScore -= 15;
      if (!(seo['hasLang'] ?? false)) seoScore -= 10;
      if (!(seo['hasCanonical'] ?? false)) seoScore -= 5;
      
      // Title length checks
      final titleLength = seo['titleLength'] ?? 0;
      if (titleLength < 30 || titleLength > 60) seoScore -= 10;
      
      // Description length checks
      final descLength = seo['descriptionLength'] ?? 0;
      if (descLength < 120 || descLength > 160) seoScore -= 10;
    }
    scores['seoScore'] = seoScore.clamp(0, 100);
    
    // Accessibility score (use dedicated score if available)
    int a11yScore = 100;
    if (audits['accessibility'] != null) {
      a11yScore = audits['accessibility']['estimatedA11yScore'] ?? 100;
    } else if (audits['content'] != null) {
      final content = audits['content'];
      final imagesWithoutAlt = content['imagesWithoutAlt'] ?? 0;
      if (imagesWithoutAlt > 0) {
        final deduction = (imagesWithoutAlt * 5).clamp(0, 50).toInt();
        a11yScore = (a11yScore - deduction).toInt();
      }
    }
    if (audits['seo'] != null && audits['accessibility'] == null) {
      final seo = audits['seo'];
      if (!(seo['hasLang'] ?? false)) a11yScore = (a11yScore - 10).toInt();
      if (!(seo['hasViewport'] ?? false)) a11yScore = (a11yScore - 10).toInt();
    }
    scores['a11yScore'] = a11yScore.clamp(0, 100);
    
    // Best practices score
    int bestScore = 100;
    if (audits['http'] != null) {
      final http = audits['http'];
      if (!(http['secure'] ?? false)) bestScore -= 30;
      if (http['statusCode'] >= 400) bestScore -= 50;
      if (http['cacheControl'] == null) bestScore -= 10;
    }
    scores['bestPracticesScore'] = bestScore.clamp(0, 100);
    
    // Mobile score
    int mobileScore = 100;
    if (audits['mobile'] != null) {
      mobileScore = audits['mobile']['estimatedMobileScore'] ?? 100;
    }
    scores['mobileScore'] = mobileScore.clamp(0, 100);
    
    // Content Weight score
    int contentScore = 100;
    if (audits['performance'] != null) {
      final size = audits['performance']['size'] ?? 0;
      if (size > 5000000) contentScore -= 50;
      else if (size > 3000000) contentScore -= 30;
      else if (size > 2000000) contentScore -= 20;
      else if (size > 1000000) contentScore -= 10;
    }
    scores['contentWeightScore'] = contentScore.clamp(0, 100);
    
    // Calculate overall score (weighted average)
    final overallScore = (
      scores['a11yScore']! * 0.35 + // 35% weight for accessibility
      scores['performanceScore']! * 0.25 + // 25% weight for performance
      scores['seoScore']! * 0.20 + // 20% weight for SEO
      scores['contentWeightScore']! * 0.10 + // 10% weight for content
      scores['mobileScore']! * 0.10 // 10% weight for mobile
    ).round();
    scores['overallScore'] = overallScore.clamp(0, 100);
    
    return scores;
  }
  
  static Map<String, List<Map<String, dynamic>>> _generateRecommendations(
    Map<String, dynamic> audits,
  ) {
    final high = <Map<String, dynamic>>[];
    final medium = <Map<String, dynamic>>[];
    final low = <Map<String, dynamic>>[];
    
    // HTTP recommendations
    if (audits['http'] != null) {
      final http = audits['http'];
      if (!(http['secure'] ?? false)) {
        high.add({
          'title': 'Use HTTPS',
          'description': 'Your site is not using HTTPS. This is critical for security and SEO.',
        });
      }
      if (http['statusCode'] >= 400) {
        high.add({
          'title': 'Fix HTTP errors',
          'description': 'Page returned status code ${http['statusCode']}. This needs immediate attention.',
        });
      }
      if (http['cacheControl'] == null) {
        low.add({
          'title': 'Add cache headers',
          'description': 'Implement cache-control headers to improve performance.',
        });
      }
    }
    
    // SEO recommendations
    if (audits['seo'] != null) {
      final seo = audits['seo'];
      if (!(seo['hasTitle'] ?? false)) {
        high.add({
          'title': 'Add page title',
          'description': 'Page is missing a title tag. This is critical for SEO.',
        });
      } else if ((seo['titleLength'] ?? 0) < 30 || (seo['titleLength'] ?? 0) > 60) {
        medium.add({
          'title': 'Optimize title length',
          'description': 'Title should be between 30-60 characters. Current: ${seo['titleLength']}',
        });
      }
      
      if (!(seo['hasDescription'] ?? false)) {
        high.add({
          'title': 'Add meta description',
          'description': 'Page is missing meta description. This is important for SEO.',
        });
      } else if ((seo['descriptionLength'] ?? 0) < 120 || (seo['descriptionLength'] ?? 0) > 160) {
        medium.add({
          'title': 'Optimize description length',
          'description': 'Description should be between 120-160 characters. Current: ${seo['descriptionLength']}',
        });
      }
      
      if ((seo['h1Count'] ?? 0) == 0) {
        high.add({
          'title': 'Add H1 heading',
          'description': 'Page is missing an H1 heading. Every page should have exactly one H1.',
        });
      } else if ((seo['h1Count'] ?? 0) > 1) {
        medium.add({
          'title': 'Use single H1',
          'description': 'Page has ${seo['h1Count']} H1 tags. Use only one H1 per page.',
        });
      }
      
      if (!(seo['hasViewport'] ?? false)) {
        high.add({
          'title': 'Add viewport meta tag',
          'description': 'Missing viewport meta tag. This is required for mobile optimization.',
        });
      }
    }
    
    // Performance recommendations
    if (audits['performance'] != null) {
      final perf = audits['performance'];
      if ((perf['responseTime'] ?? 0) > 3000) {
        high.add({
          'title': 'Improve server response time',
          'description': 'Server response time is ${perf['responseTime']}ms. Should be under 600ms.',
        });
      }
      if ((perf['size'] ?? 0) > 1000000) {
        medium.add({
          'title': 'Reduce page size',
          'description': 'Page size is ${perf['sizeKb']}KB. Consider optimizing resources.',
        });
      }
      if (perf['compression'] == null) {
        medium.add({
          'title': 'Enable compression',
          'description': 'Enable gzip or brotli compression to reduce transfer size.',
        });
      }
      if ((perf['images'] ?? 0) > 20) {
        low.add({
          'title': 'Optimize images',
          'description': 'Page has ${perf['images']} images. Consider lazy loading or optimization.',
        });
      }
    }
    
    // Content recommendations
    if (audits['content'] != null) {
      final content = audits['content'];
      if ((content['imagesWithoutAlt'] ?? 0) > 0) {
        high.add({
          'title': 'Add alt text to images',
          'description': '${content['imagesWithoutAlt']} images are missing alt text. This is important for accessibility.',
        });
      }
      if ((content['wordCount'] ?? 0) < 300) {
        medium.add({
          'title': 'Add more content',
          'description': 'Page has only ${content['wordCount']} words. Consider adding more valuable content.',
        });
      }
    }
    
    return {
      'high': high,
      'medium': medium,
      'low': low,
    };
  }
  
  static int _calculateA11yScore(Map<String, dynamic> factors) {
    int score = 100;
    
    // Deduct for missing alt text
    final imagesWithoutAlt = factors['imagesWithoutAlt'] ?? 0;
    if (imagesWithoutAlt > 0) {
      final deduction = (imagesWithoutAlt * 10).clamp(0, 30).toInt();
      score = (score - deduction) as int;
    }
    
    // Deduct for unlabeled buttons
    final buttonsWithoutLabel = factors['buttonsWithoutLabel'] ?? 0;
    if (buttonsWithoutLabel > 0) {
      final deduction = (buttonsWithoutLabel * 5).clamp(0, 20).toInt();
      score = (score - deduction) as int;
    }
    
    // Deduct for missing language attribute
    if (!(factors['hasLang'] ?? false)) {
      score = score - 15;
    }
    
    // Deduct for missing viewport
    if (!(factors['hasViewport'] ?? false)) {
      score = score - 10;
    }
    
    // Deduct for missing main landmark
    if (!(factors['hasMain'] ?? false)) {
      score = score - 10;
    }
    
    return score.clamp(0, 100);
  }
  
  static int _calculateMobileScore(Map<String, dynamic> factors) {
    int score = 100;
    
    // Must have viewport
    if (!(factors['hasViewport'] ?? false)) {
      score = score - 30;
    }
    
    // Must be responsive
    if (!(factors['hasResponsiveViewport'] ?? false)) {
      score = score - 20;
    }
    
    // Should be scalable
    if (!(factors['isScalable'] ?? true)) {
      score = score - 15;
    }
    
    return score.clamp(0, 100);
  }
  
  static int _estimateLCP(int bodySize, int responseTime, int jsFiles, int cssFiles) {
    // More realistic estimate based on multiple factors
    // Base: network latency + server response
    int baseLCP = responseTime + 200; // Add typical render overhead
    
    // Add parsing time based on HTML size
    if (bodySize > 1000000) {
      baseLCP += 1500; // Large page
    } else if (bodySize > 500000) {
      baseLCP += 800; // Medium page  
    } else if (bodySize > 100000) {
      baseLCP += 400; // Normal page
    } else {
      baseLCP += 200; // Small page
    }
    
    // Add time for JS/CSS blocking resources
    baseLCP += (jsFiles * 150); // Each JS file adds ~150ms
    baseLCP += (cssFiles * 100); // Each CSS file adds ~100ms
    
    // Typical range is 1000-4000ms for most sites
    return baseLCP.clamp(800, 10000);
  }
  
  static int _estimateFCP(int responseTime, int bodySize) {
    // FCP is typically faster than LCP
    // Base: time to first byte + initial render
    int fcp = responseTime + 100;
    
    // Add initial parse time
    if (bodySize > 500000) {
      fcp += 400;
    } else if (bodySize > 100000) {
      fcp += 200;
    } else {
      fcp += 100;
    }
    
    // Typical range is 500-3000ms
    return fcp.clamp(300, 6000);
  }
  
  static int _estimateTBT(int jsFiles, int bodySize) {
    // Total Blocking Time estimate
    // Each JS file can block the main thread
    int tbt = 0;
    
    if (jsFiles > 10) {
      tbt = 600; // Heavy JS usage
    } else if (jsFiles > 5) {
      tbt = 300; // Moderate JS
    } else if (jsFiles > 2) {
      tbt = 150; // Light JS
    } else {
      tbt = 50; // Minimal JS
    }
    
    // Large pages typically have more blocking
    if (bodySize > 1000000) {
      tbt = (tbt * 1.5).round();
    }
    
    return tbt;
  }
}
