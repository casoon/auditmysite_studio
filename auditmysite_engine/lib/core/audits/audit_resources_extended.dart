import 'dart:convert';
import 'dart:math' as math;
import 'package:puppeteer/puppeteer.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'audit_base.dart';

/// Extended Resource Analysis Audit
class ResourcesExtendedAudit implements Audit {
  @override
  String get name => 'resources_extended';
  
  final Logger _logger = Logger('ResourcesExtendedAudit');

  @override
  Future<void> run(AuditContext ctx) async {
    final page = ctx.page as Page;
    final url = ctx.url.toString();
    
    final resourceResults = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'url': url,
      'bundles': {},
      'images': {},
      'fonts': {},
      'css': {},
      'javascript': {},
      'caching': {},
      'compression': {},
      'thirdParty': {},
      'optimization': {},
      'score': 0,
      'issues': [],
      'recommendations': []
    };
    
    try {
      // Enable CDP domains for resource tracking
      final client = await page.target.createCDPSession();
      await client.send('Network.enable');
      await client.send('Performance.enable');
      
      // Collect network resources
      final resources = <Map<String, dynamic>>[];
      
      // Track all network requests
      client.onMessage.listen((event) {
        if (event.method == 'Network.responseReceived') {
          final response = event.params!['response'];
          final request = event.params!['requestId'];
          resources.add({
            'requestId': request,
            'url': response['url'],
            'status': response['status'],
            'mimeType': response['mimeType'],
            'headers': response['headers'],
            'encodedDataLength': response['encodedDataLength'] ?? 0,
            'timing': response['timing']
          });
        }
      });
      
      // Navigate and wait for load
      await page.reload();
      await page.waitForNavigation();
      
      // Give time for all resources to load
      await Future.delayed(Duration(seconds: 2));
      
      // 1. Analyze JavaScript bundles
      resourceResults['javascript'] = await _analyzeJavaScript(page, resources);
      
      // 2. Analyze CSS resources
      resourceResults['css'] = await _analyzeCSS(page, resources);
      
      // 3. Analyze images
      resourceResults['images'] = await _analyzeImages(page, resources);
      
      // 4. Analyze fonts
      resourceResults['fonts'] = await _analyzeFonts(page, resources);
      
      // 5. Analyze bundle sizes
      resourceResults['bundles'] = _analyzeBundles(resources);
      
      // 6. Check caching headers
      resourceResults['caching'] = _analyzeCaching(resources);
      
      // 7. Check compression
      resourceResults['compression'] = _analyzeCompression(resources);
      
      // 8. Analyze third-party resources
      resourceResults['thirdParty'] = _analyzeThirdParty(resources, ctx.url);
      
      // 9. Check for unused CSS/JS
      resourceResults['unused'] = await _analyzeUnusedCode(page, client);
      
      // 10. Analyze resource hints
      resourceResults['hints'] = await _analyzeResourceHints(page);
      
      // 11. Check lazy loading
      resourceResults['lazyLoading'] = await _analyzeLazyLoading(page);
      
      // 12. Analyze critical resources
      resourceResults['critical'] = await _analyzeCriticalResources(page, client);
      
      // 13. Check for WebP support
      resourceResults['webp'] = await _analyzeWebPSupport(page, resources);
      
      // 14. Analyze resource timing
      resourceResults['timing'] = await _analyzeResourceTiming(page);
      
      // 15. Check for duplicate resources
      resourceResults['duplicates'] = _analyzeDuplicates(resources);
      
      // Calculate optimization score
      final scoring = _calculateScore(resourceResults);
      resourceResults['score'] = scoring['score'];
      resourceResults['grade'] = scoring['grade'];
      resourceResults['summary'] = scoring['summary'];
      
      // Identify issues
      resourceResults['issues'] = _identifyIssues(resourceResults);
      
      // Generate recommendations
      resourceResults['recommendations'] = _generateRecommendations(resourceResults);
      
      // Store in context
      ctx.resourcesExtended = resourceResults;
      
    } catch (e) {
      _logger.severe('Error in extended resource audit: $e');
      resourceResults['error'] = e.toString();
      ctx.resourcesExtended = resourceResults;
    }
  }
  
  Future<Map<String, dynamic>> _analyzeJavaScript(Page page, List<Map<String, dynamic>> resources) async {
    final js = <String, dynamic>{
      'totalFiles': 0,
      'totalSize': 0,
      'minifiedFiles': 0,
      'unminifiedFiles': [],
      'largeFiles': [],
      'coverage': {},
      'bundleAnalysis': {}
    };
    
    try {
      // Filter JavaScript resources
      final jsResources = resources.where((r) => 
        r['mimeType'].toString().contains('javascript') ||
        r['url'].toString().endsWith('.js')
      ).toList();
      
      js['totalFiles'] = jsResources.length;
      
      for (final resource in jsResources) {
        final size = resource['encodedDataLength'] as int;
        js['totalSize'] += size;
        
        // Check if minified (simple heuristic: long lines)
        try {
          final response = await http.get(Uri.parse(resource['url']));
          if (response.statusCode == 200) {
            final lines = response.body.split('\n');
            final avgLineLength = response.body.length / math.max(lines.length, 1);
            
            if (avgLineLength > 500) {
              js['minifiedFiles']++;
            } else {
              js['unminifiedFiles'].add({
                'url': resource['url'],
                'size': size,
                'avgLineLength': avgLineLength
              });
            }
            
            // Check for large files (> 200KB)
            if (size > 200000) {
              js['largeFiles'].add({
                'url': resource['url'],
                'size': size,
                'sizeFormatted': _formatBytes(size)
              });
            }
            
            // Simple bundle detection
            if (response.body.contains('webpack') || 
                response.body.contains('webpackJsonp')) {
              js['bundleAnalysis']['webpack'] = true;
            }
            if (response.body.contains('__vite__')) {
              js['bundleAnalysis']['vite'] = true;
            }
            if (response.body.contains('parcelRequire')) {
              js['bundleAnalysis']['parcel'] = true;
            }
          }
        } catch (e) {
          _logger.warning('Could not analyze JS file: ${resource['url']}');
        }
      }
      
      // Get JavaScript coverage
      final coverage = await page.evaluate('''() => {
        const scripts = document.querySelectorAll('script');
        const inline = Array.from(scripts).filter(s => !s.src).length;
        const external = Array.from(scripts).filter(s => s.src).length;
        
        return {
          inlineScripts: inline,
          externalScripts: external,
          totalScripts: scripts.length
        };
      }''');
      
      js['coverage'] = coverage;
      
    } catch (e) {
      _logger.warning('Error analyzing JavaScript: $e');
    }
    
    return js;
  }
  
  Future<Map<String, dynamic>> _analyzeCSS(Page page, List<Map<String, dynamic>> resources) async {
    final css = <String, dynamic>{
      'totalFiles': 0,
      'totalSize': 0,
      'inlineStyles': 0,
      'criticalCSS': false,
      'unminifiedFiles': [],
      'largeFiles': [],
      'mediaQueries': {}
    };
    
    try {
      // Filter CSS resources
      final cssResources = resources.where((r) => 
        r['mimeType'].toString().contains('css') ||
        r['url'].toString().endsWith('.css')
      ).toList();
      
      css['totalFiles'] = cssResources.length;
      
      for (final resource in cssResources) {
        final size = resource['encodedDataLength'] as int;
        css['totalSize'] += size;
        
        // Check if minified
        try {
          final response = await http.get(Uri.parse(resource['url']));
          if (response.statusCode == 200) {
            final content = response.body;
            
            // Check for minification (no unnecessary whitespace)
            if (content.contains('  ') || content.contains('\n\n')) {
              css['unminifiedFiles'].add({
                'url': resource['url'],
                'size': size
              });
            }
            
            // Large CSS files (> 100KB)
            if (size > 100000) {
              css['largeFiles'].add({
                'url': resource['url'],
                'size': size,
                'sizeFormatted': _formatBytes(size)
              });
            }
            
            // Count media queries
            final mediaQueryCount = 'media'.allMatches(content).length;
            css['mediaQueries'][resource['url']] = mediaQueryCount;
          }
        } catch (e) {
          _logger.warning('Could not analyze CSS file: ${resource['url']}');
        }
      }
      
      // Check for inline styles and critical CSS
      final inlineAnalysis = await page.evaluate('''() => {
        const styles = document.querySelectorAll('style');
        const inlineStyleElements = document.querySelectorAll('[style]');
        const criticalCSS = document.querySelector('style[data-critical]') || 
                           document.querySelector('style.critical-css');
        
        return {
          inlineStyleBlocks: styles.length,
          elementsWithInlineStyle: inlineStyleElements.length,
          hasCriticalCSS: criticalCSS !== null,
          totalStylesheets: document.querySelectorAll('link[rel="stylesheet"]').length
        };
      }''');
      
      css['inlineStyles'] = inlineAnalysis['elementsWithInlineStyle'];
      css['criticalCSS'] = inlineAnalysis['hasCriticalCSS'];
      css['styleBlocks'] = inlineAnalysis['inlineStyleBlocks'];
      
    } catch (e) {
      _logger.warning('Error analyzing CSS: $e');
    }
    
    return css;
  }
  
  Future<Map<String, dynamic>> _analyzeImages(Page page, List<Map<String, dynamic>> resources) async {
    final images = <String, dynamic>{
      'totalImages': 0,
      'totalSize': 0,
      'formats': {},
      'largeImages': [],
      'missingAlt': [],
      'lazyLoaded': 0,
      'responsive': 0,
      'optimizationOpportunities': []
    };
    
    try {
      // Filter image resources
      final imageResources = resources.where((r) {
        final mimeType = r['mimeType'].toString();
        return mimeType.contains('image') || 
               ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.svg', '.avif']
                 .any((ext) => r['url'].toString().toLowerCase().endsWith(ext));
      }).toList();
      
      images['totalImages'] = imageResources.length;
      
      final formats = <String, int>{};
      
      for (final resource in imageResources) {
        final size = resource['encodedDataLength'] as int;
        final url = resource['url'] as String;
        images['totalSize'] += size;
        
        // Detect format
        String format = 'unknown';
        if (url.endsWith('.webp')) format = 'webp';
        else if (url.endsWith('.avif')) format = 'avif';
        else if (url.endsWith('.svg')) format = 'svg';
        else if (url.contains('.jpg') || url.contains('.jpeg')) format = 'jpeg';
        else if (url.endsWith('.png')) format = 'png';
        else if (url.endsWith('.gif')) format = 'gif';
        
        formats[format] = (formats[format] ?? 0) + 1;
        
        // Large images (> 100KB)
        if (size > 100000) {
          images['largeImages'].add({
            'url': url,
            'size': size,
            'sizeFormatted': _formatBytes(size),
            'format': format
          });
          
          // Optimization opportunities
          if (format != 'webp' && format != 'avif' && size > 50000) {
            final potentialSaving = (size * 0.3).round(); // Assume 30% reduction with WebP
            images['optimizationOpportunities'].add({
              'url': url,
              'currentFormat': format,
              'currentSize': size,
              'suggestedFormat': 'webp',
              'potentialSaving': potentialSaving,
              'potentialSavingFormatted': _formatBytes(potentialSaving)
            });
          }
        }
      }
      
      images['formats'] = formats;
      
      // Analyze images in DOM
      final domImages = await page.evaluate('''() => {
        const imgs = document.querySelectorAll('img');
        const missingAlt = [];
        let lazyLoaded = 0;
        let responsive = 0;
        
        imgs.forEach(img => {
          // Check alt text
          if (!img.alt || img.alt.trim() === '') {
            missingAlt.push({
              src: img.src,
              id: img.id || null,
              class: img.className || null
            });
          }
          
          // Check lazy loading
          if (img.loading === 'lazy' || 
              img.dataset.src || 
              img.classList.contains('lazyload')) {
            lazyLoaded++;
          }
          
          // Check responsive images
          if (img.srcset || img.sizes) {
            responsive++;
          }
        });
        
        // Check for picture elements
        const pictureElements = document.querySelectorAll('picture');
        
        return {
          totalImgElements: imgs.length,
          missingAlt: missingAlt,
          lazyLoaded: lazyLoaded,
          responsive: responsive,
          pictureElements: pictureElements.length
        };
      }''');
      
      images['missingAlt'] = domImages['missingAlt'];
      images['lazyLoaded'] = domImages['lazyLoaded'];
      images['responsive'] = domImages['responsive'];
      images['pictureElements'] = domImages['pictureElements'];
      
    } catch (e) {
      _logger.warning('Error analyzing images: $e');
    }
    
    return images;
  }
  
  Future<Map<String, dynamic>> _analyzeFonts(Page page, List<Map<String, dynamic>> resources) async {
    final fonts = <String, dynamic>{
      'totalFonts': 0,
      'totalSize': 0,
      'formats': {},
      'providers': [],
      'fontDisplay': {},
      'subsetting': false,
      'variableFonts': 0
    };
    
    try {
      // Filter font resources
      final fontResources = resources.where((r) {
        final url = r['url'].toString().toLowerCase();
        return url.contains('.woff') || url.contains('.woff2') || 
               url.contains('.ttf') || url.contains('.otf') || 
               url.contains('.eot') || url.contains('fonts.googleapis');
      }).toList();
      
      fonts['totalFonts'] = fontResources.length;
      
      final formats = <String, int>{};
      final providers = <String>[];
      
      for (final resource in fontResources) {
        final size = resource['encodedDataLength'] as int;
        final url = resource['url'] as String;
        fonts['totalSize'] += size;
        
        // Detect format
        String format = 'unknown';
        if (url.contains('.woff2')) format = 'woff2';
        else if (url.contains('.woff')) format = 'woff';
        else if (url.contains('.ttf')) format = 'ttf';
        else if (url.contains('.otf')) format = 'otf';
        else if (url.contains('.eot')) format = 'eot';
        
        formats[format] = (formats[format] ?? 0) + 1;
        
        // Detect font providers
        if (url.contains('fonts.googleapis.com')) {
          if (!providers.contains('Google Fonts')) {
            providers.add('Google Fonts');
          }
        } else if (url.contains('use.typekit.net')) {
          if (!providers.contains('Adobe Fonts')) {
            providers.add('Adobe Fonts');
          }
        } else if (url.contains('fonts.bunny.net')) {
          if (!providers.contains('Bunny Fonts')) {
            providers.add('Bunny Fonts');
          }
        }
        
        // Check for variable fonts
        if (url.contains('-vf') || url.contains('variable')) {
          fonts['variableFonts']++;
        }
      }
      
      fonts['formats'] = formats;
      fonts['providers'] = providers;
      
      // Analyze font-face declarations
      final fontFaceAnalysis = await page.evaluate('''() => {
        const sheets = document.styleSheets;
        const fontDisplay = {};
        let subsetting = false;
        
        try {
          for (const sheet of sheets) {
            try {
              const rules = sheet.cssRules || sheet.rules;
              for (const rule of rules) {
                if (rule.type === CSSRule.FONT_FACE_RULE) {
                  const display = rule.style.fontDisplay;
                  if (display) {
                    fontDisplay[display] = (fontDisplay[display] || 0) + 1;
                  }
                  
                  // Check for unicode-range (subsetting)
                  if (rule.style.unicodeRange) {
                    subsetting = true;
                  }
                }
              }
            } catch (e) {
              // Cross-origin stylesheets
            }
          }
        } catch (e) {
          // Error accessing stylesheets
        }
        
        return {
          fontDisplay: fontDisplay,
          subsetting: subsetting
        };
      }''');
      
      fonts['fontDisplay'] = fontFaceAnalysis['fontDisplay'];
      fonts['subsetting'] = fontFaceAnalysis['subsetting'];
      
    } catch (e) {
      _logger.warning('Error analyzing fonts: $e');
    }
    
    return fonts;
  }
  
  Map<String, dynamic> _analyzeBundles(List<Map<String, dynamic>> resources) {
    final bundles = <String, dynamic>{
      'totalBundles': 0,
      'jsBundle': {},
      'cssBundle': {},
      'totalBundleSize': 0,
      'chunks': [],
      'recommendations': []
    };
    
    try {
      // Identify JS bundles (main, vendor, chunks)
      final jsFiles = resources.where((r) => 
        r['mimeType'].toString().contains('javascript')
      ).toList();
      
      for (final js in jsFiles) {
        final url = js['url'].toString();
        final size = js['encodedDataLength'] as int;
        
        if (url.contains('vendor') || url.contains('vendors')) {
          bundles['jsBundle']['vendor'] = {
            'url': url,
            'size': size,
            'sizeFormatted': _formatBytes(size)
          };
        } else if (url.contains('main') || url.contains('app')) {
          bundles['jsBundle']['main'] = {
            'url': url,
            'size': size,
            'sizeFormatted': _formatBytes(size)
          };
        } else if (url.contains('chunk') || url.contains('lazy')) {
          bundles['chunks'].add({
            'url': url,
            'size': size,
            'sizeFormatted': _formatBytes(size)
          });
        }
        
        bundles['totalBundleSize'] += size;
      }
      
      // Identify CSS bundles
      final cssFiles = resources.where((r) => 
        r['mimeType'].toString().contains('css')
      ).toList();
      
      int totalCssSize = 0;
      for (final css in cssFiles) {
        totalCssSize += css['encodedDataLength'] as int;
      }
      
      bundles['cssBundle'] = {
        'files': cssFiles.length,
        'totalSize': totalCssSize,
        'sizeFormatted': _formatBytes(totalCssSize)
      };
      
      bundles['totalBundles'] = jsFiles.length + cssFiles.length;
      
      // Generate recommendations
      if (bundles['totalBundleSize'] > 1000000) { // > 1MB
        bundles['recommendations'].add({
          'issue': 'Large bundle size',
          'impact': 'Slow initial page load',
          'suggestion': 'Consider code splitting and lazy loading'
        });
      }
      
      if (bundles['jsBundle']['vendor'] != null &&
          bundles['jsBundle']['vendor']['size'] > 500000) {
        bundles['recommendations'].add({
          'issue': 'Large vendor bundle',
          'impact': 'Slow initial load',
          'suggestion': 'Review dependencies and remove unused libraries'
        });
      }
      
    } catch (e) {
      _logger.warning('Error analyzing bundles: $e');
    }
    
    return bundles;
  }
  
  Map<String, dynamic> _analyzeCaching(List<Map<String, dynamic>> resources) {
    final caching = <String, dynamic>{
      'cachedResources': 0,
      'uncachedResources': [],
      'cacheStrategies': {},
      'avgCacheDuration': 0,
      'recommendations': []
    };
    
    try {
      int totalCacheDuration = 0;
      int cachedCount = 0;
      
      for (final resource in resources) {
        final headers = resource['headers'] as Map?;
        if (headers == null) continue;
        
        final cacheControl = headers['cache-control'] ?? headers['Cache-Control'];
        final expires = headers['expires'] ?? headers['Expires'];
        final etag = headers['etag'] ?? headers['ETag'];
        final lastModified = headers['last-modified'] ?? headers['Last-Modified'];
        
        if (cacheControl != null) {
          caching['cachedResources']++;
          cachedCount++;
          
          // Parse cache duration
          final maxAgeMatch = RegExp(r'max-age=(\d+)').firstMatch(cacheControl.toString());
          if (maxAgeMatch != null) {
            final maxAge = int.parse(maxAgeMatch.group(1)!);
            totalCacheDuration += maxAge;
          }
          
          // Categorize cache strategy
          String strategy = 'custom';
          if (cacheControl.toString().contains('no-cache')) {
            strategy = 'no-cache';
          } else if (cacheControl.toString().contains('no-store')) {
            strategy = 'no-store';
          } else if (cacheControl.toString().contains('immutable')) {
            strategy = 'immutable';
          } else if (cacheControl.toString().contains('public')) {
            strategy = 'public';
          } else if (cacheControl.toString().contains('private')) {
            strategy = 'private';
          }
          
          caching['cacheStrategies'][strategy] = 
            (caching['cacheStrategies'][strategy] ?? 0) + 1;
        } else if (expires != null || etag != null || lastModified != null) {
          caching['cachedResources']++;
          cachedCount++;
        } else {
          // No caching headers
          final mimeType = resource['mimeType'].toString();
          if (_shouldBeCached(mimeType, resource['url'].toString())) {
            caching['uncachedResources'].add({
              'url': resource['url'],
              'type': mimeType,
              'size': resource['encodedDataLength']
            });
          }
        }
      }
      
      if (cachedCount > 0) {
        caching['avgCacheDuration'] = (totalCacheDuration / cachedCount).round();
      }
      
      // Generate recommendations
      if (caching['uncachedResources'].length > 5) {
        caching['recommendations'].add({
          'issue': 'Many resources without caching',
          'count': caching['uncachedResources'].length,
          'suggestion': 'Add Cache-Control headers for static resources'
        });
      }
      
      if (caching['avgCacheDuration'] < 86400 && caching['avgCacheDuration'] > 0) { // Less than 1 day
        caching['recommendations'].add({
          'issue': 'Short cache duration',
          'current': '${caching['avgCacheDuration']} seconds',
          'suggestion': 'Increase cache duration for static resources'
        });
      }
      
    } catch (e) {
      _logger.warning('Error analyzing caching: $e');
    }
    
    return caching;
  }
  
  Map<String, dynamic> _analyzeCompression(List<Map<String, dynamic>> resources) {
    final compression = <String, dynamic>{
      'compressedResources': 0,
      'uncompressedResources': [],
      'compressionTypes': {},
      'totalSaved': 0,
      'potentialSavings': 0
    };
    
    try {
      for (final resource in resources) {
        final headers = resource['headers'] as Map?;
        if (headers == null) continue;
        
        final contentEncoding = headers['content-encoding'] ?? headers['Content-Encoding'];
        final contentLength = headers['content-length'] ?? headers['Content-Length'];
        final mimeType = resource['mimeType'].toString();
        
        if (contentEncoding != null && contentEncoding != 'identity') {
          compression['compressedResources']++;
          
          // Track compression type
          compression['compressionTypes'][contentEncoding] = 
            (compression['compressionTypes'][contentEncoding] ?? 0) + 1;
        } else {
          // Check if should be compressed
          if (_shouldBeCompressed(mimeType)) {
            final size = resource['encodedDataLength'] as int;
            if (size > 1000) { // Only flag files > 1KB
              compression['uncompressedResources'].add({
                'url': resource['url'],
                'type': mimeType,
                'size': size,
                'sizeFormatted': _formatBytes(size),
                'potentialSaving': (size * 0.7).round() // Estimate 70% compression
              });
              
              compression['potentialSavings'] += (size * 0.7).round();
            }
          }
        }
      }
    } catch (e) {
      _logger.warning('Error analyzing compression: $e');
    }
    
    return compression;
  }
  
  Map<String, dynamic> _analyzeThirdParty(List<Map<String, dynamic>> resources, Uri pageUrl) {
    final thirdParty = <String, dynamic>{
      'totalRequests': 0,
      'totalSize': 0,
      'domains': {},
      'services': {},
      'percentage': 0
    };
    
    try {
      final pageDomain = pageUrl.host;
      int firstPartySize = 0;
      
      for (final resource in resources) {
        final resourceUrl = Uri.parse(resource['url'] as String);
        final resourceDomain = resourceUrl.host;
        final size = resource['encodedDataLength'] as int;
        
        if (resourceDomain != pageDomain && 
            !resourceDomain.endsWith('.$pageDomain')) {
          thirdParty['totalRequests']++;
          thirdParty['totalSize'] += size;
          
          // Track by domain
          thirdParty['domains'][resourceDomain] = 
            (thirdParty['domains'][resourceDomain] ?? 0) + size;
          
          // Identify known services
          final service = _identifyService(resourceDomain);
          if (service != null) {
            thirdParty['services'][service] = 
              (thirdParty['services'][service] ?? 0) + 1;
          }
        } else {
          firstPartySize += size;
        }
      }
      
      // Calculate percentage
      final totalSize = thirdParty['totalSize'] + firstPartySize;
      if (totalSize > 0) {
        thirdParty['percentage'] = 
          (thirdParty['totalSize'] / totalSize * 100).round();
      }
      
    } catch (e) {
      _logger.warning('Error analyzing third-party resources: $e');
    }
    
    return thirdParty;
  }
  
  Future<Map<String, dynamic>> _analyzeUnusedCode(Page page, dynamic client) async {
    final unused = <String, dynamic>{
      'css': {},
      'javascript': {},
      'totalUnused': 0
    };
    
    try {
      // Start CSS and JS coverage
      await client.send('CSS.enable');
      await client.send('CSS.startRuleUsageTracking');
      await client.send('Profiler.enable');
      await client.send('Profiler.startPreciseCoverage', {
        'callCount': false,
        'detailed': true
      });
      
      // Interact with the page to trigger more code execution
      await page.evaluate('''() => {
        // Scroll to trigger lazy loading
        window.scrollTo(0, document.body.scrollHeight);
        window.scrollTo(0, 0);
        
        // Trigger hover states
        document.querySelectorAll('a, button').forEach(el => {
          el.dispatchEvent(new MouseEvent('mouseover'));
        });
      }''');
      
      await Future.delayed(Duration(seconds: 2));
      
      // Get CSS coverage
      try {
        final cssUsage = await client.send('CSS.stopRuleUsageTracking');
        final ruleUsage = cssUsage['ruleUsage'] as List;
        
        int usedRules = 0;
        int totalRules = ruleUsage.length;
        
        for (final rule in ruleUsage) {
          if (rule['used'] == true) {
            usedRules++;
          }
        }
        
        unused['css'] = {
          'totalRules': totalRules,
          'usedRules': usedRules,
          'unusedRules': totalRules - usedRules,
          'unusedPercentage': totalRules > 0 ? 
            ((totalRules - usedRules) / totalRules * 100).round() : 0
        };
      } catch (e) {
        _logger.warning('Could not get CSS coverage: $e');
      }
      
      // Get JS coverage
      try {
        final jsCoverage = await client.send('Profiler.takePreciseCoverage');
        final result = jsCoverage['result'] as List;
        
        int totalBytes = 0;
        int usedBytes = 0;
        
        for (final script in result) {
          final functions = script['functions'] as List;
          for (final func in functions) {
            final ranges = func['ranges'] as List;
            for (final range in ranges) {
              final size = range['endOffset'] - range['startOffset'];
              totalBytes += size;
              if (range['count'] > 0) {
                usedBytes += size;
              }
            }
          }
        }
        
        unused['javascript'] = {
          'totalBytes': totalBytes,
          'usedBytes': usedBytes,
          'unusedBytes': totalBytes - usedBytes,
          'unusedPercentage': totalBytes > 0 ? 
            ((totalBytes - usedBytes) / totalBytes * 100).round() : 0
        };
        
        unused['totalUnused'] = 
          (unused['css']['unusedRules'] ?? 0) + 
          (unused['javascript']['unusedBytes'] ?? 0);
      } catch (e) {
        _logger.warning('Could not get JS coverage: $e');
      }
      
    } catch (e) {
      _logger.warning('Error analyzing unused code: $e');
    }
    
    return unused;
  }
  
  Future<Map<String, dynamic>> _analyzeResourceHints(Page page) async {
    final hints = <String, dynamic>{
      'preconnect': [],
      'prefetch': [],
      'preload': [],
      'dns-prefetch': [],
      'modulepreload': [],
      'prerender': [],
      'total': 0
    };
    
    try {
      final result = await page.evaluate('''() => {
        const hints = {
          preconnect: [],
          prefetch: [],
          preload: [],
          'dns-prefetch': [],
          modulepreload: [],
          prerender: []
        };
        
        document.querySelectorAll('link[rel]').forEach(link => {
          const rel = link.rel;
          const href = link.href;
          
          if (hints.hasOwnProperty(rel)) {
            hints[rel].push({
              href: href,
              as: link.as || null,
              type: link.type || null,
              crossorigin: link.crossOrigin || null
            });
          }
        });
        
        return hints;
      }''');
      
      hints.addAll(result as Map);
      
      // Count total hints
      int total = 0;
      result.forEach((key, value) {
        if (value is List) {
          total += value.length;
        }
      });
      hints['total'] = total;
      
    } catch (e) {
      _logger.warning('Error analyzing resource hints: $e');
    }
    
    return hints;
  }
  
  Future<Map<String, dynamic>> _analyzeLazyLoading(Page page) async {
    final lazy = <String, dynamic>{
      'images': 0,
      'iframes': 0,
      'nativeLazy': 0,
      'jsLazy': 0,
      'total': 0
    };
    
    try {
      final result = await page.evaluate('''() => {
        let nativeImages = 0;
        let jsImages = 0;
        let nativeIframes = 0;
        
        // Check images
        document.querySelectorAll('img').forEach(img => {
          if (img.loading === 'lazy') {
            nativeImages++;
          } else if (img.dataset.src || img.classList.contains('lazyload')) {
            jsImages++;
          }
        });
        
        // Check iframes
        document.querySelectorAll('iframe').forEach(iframe => {
          if (iframe.loading === 'lazy') {
            nativeIframes++;
          }
        });
        
        return {
          nativeImages: nativeImages,
          jsImages: jsImages,
          nativeIframes: nativeIframes
        };
      }''');
      
      lazy['images'] = result['nativeImages'] + result['jsImages'];
      lazy['iframes'] = result['nativeIframes'];
      lazy['nativeLazy'] = result['nativeImages'] + result['nativeIframes'];
      lazy['jsLazy'] = result['jsImages'];
      lazy['total'] = lazy['images'] + lazy['iframes'];
      
    } catch (e) {
      _logger.warning('Error analyzing lazy loading: $e');
    }
    
    return lazy;
  }
  
  Future<Map<String, dynamic>> _analyzeCriticalResources(Page page, dynamic client) async {
    final critical = <String, dynamic>{
      'renderBlocking': [],
      'criticalPath': [],
      'aboveFold': {}
    };
    
    try {
      // Get render blocking resources
      final renderBlocking = await page.evaluate('''() => {
        const blocking = [];
        
        // CSS in head without media query or with screen/all
        document.querySelectorAll('link[rel="stylesheet"]').forEach(link => {
          if (!link.media || link.media === 'all' || link.media === 'screen') {
            blocking.push({
              type: 'css',
              url: link.href,
              media: link.media
            });
          }
        });
        
        // Scripts in head without async/defer
        document.querySelectorAll('head script[src]').forEach(script => {
          if (!script.async && !script.defer) {
            blocking.push({
              type: 'javascript',
              url: script.src
            });
          }
        });
        
        return blocking;
      }''');
      
      critical['renderBlocking'] = renderBlocking;
      
    } catch (e) {
      _logger.warning('Error analyzing critical resources: $e');
    }
    
    return critical;
  }
  
  Future<Map<String, dynamic>> _analyzeWebPSupport(Page page, List<Map<String, dynamic>> resources) async {
    final webp = <String, dynamic>{
      'supported': false,
      'webpImages': 0,
      'nonWebpImages': 0,
      'conversionOpportunities': []
    };
    
    try {
      // Check browser WebP support
      webp['supported'] = await page.evaluate('''() => {
        const canvas = document.createElement('canvas');
        canvas.width = 1;
        canvas.height = 1;
        return canvas.toDataURL('image/webp').indexOf('image/webp') === 0;
      }''');
      
      // Count WebP vs non-WebP images
      for (final resource in resources) {
        if (resource['mimeType'].toString().contains('image')) {
          if (resource['url'].toString().contains('.webp')) {
            webp['webpImages']++;
          } else if (resource['url'].toString().contains('.jpg') ||
                     resource['url'].toString().contains('.jpeg') ||
                     resource['url'].toString().contains('.png')) {
            webp['nonWebpImages']++;
            
            final size = resource['encodedDataLength'] as int;
            if (size > 20000) { // Only for images > 20KB
              webp['conversionOpportunities'].add({
                'url': resource['url'],
                'currentSize': size,
                'estimatedWebpSize': (size * 0.7).round(),
                'potentialSaving': (size * 0.3).round()
              });
            }
          }
        }
      }
      
    } catch (e) {
      _logger.warning('Error analyzing WebP support: $e');
    }
    
    return webp;
  }
  
  Future<Map<String, dynamic>> _analyzeResourceTiming(Page page) async {
    final timing = <String, dynamic>{
      'entries': [],
      'slowestResources': [],
      'avgLoadTime': 0
    };
    
    try {
      final result = await page.evaluate('''() => {
        const entries = performance.getEntriesByType('resource');
        const timings = entries.map(entry => ({
          name: entry.name,
          duration: Math.round(entry.duration),
          transferSize: entry.transferSize || 0,
          initiatorType: entry.initiatorType
        }));
        
        // Sort by duration
        timings.sort((a, b) => b.duration - a.duration);
        
        const avgDuration = timings.length > 0 ? 
          timings.reduce((sum, t) => sum + t.duration, 0) / timings.length : 0;
        
        return {
          entries: timings.slice(0, 100), // Limit to 100 entries
          slowest: timings.slice(0, 10),
          avgLoadTime: Math.round(avgDuration)
        };
      }''');
      
      timing['entries'] = result['entries'];
      timing['slowestResources'] = result['slowest'];
      timing['avgLoadTime'] = result['avgLoadTime'];
      
    } catch (e) {
      _logger.warning('Error analyzing resource timing: $e');
    }
    
    return timing;
  }
  
  Map<String, dynamic> _analyzeDuplicates(List<Map<String, dynamic>> resources) {
    final duplicates = <String, dynamic>{
      'hasDuplicates': false,
      'duplicateResources': [],
      'wastedBytes': 0
    };
    
    try {
      final urlCounts = <String, List<Map<String, dynamic>>>{};
      
      // Group resources by URL
      for (final resource in resources) {
        final url = resource['url'] as String;
        if (!urlCounts.containsKey(url)) {
          urlCounts[url] = [];
        }
        urlCounts[url]!.add(resource);
      }
      
      // Find duplicates
      urlCounts.forEach((url, resourceList) {
        if (resourceList.length > 1) {
          duplicates['hasDuplicates'] = true;
          
          final size = resourceList.first['encodedDataLength'] as int;
          final wastedBytes = size * (resourceList.length - 1);
          
          duplicates['duplicateResources'].add({
            'url': url,
            'count': resourceList.length,
            'size': size,
            'wastedBytes': wastedBytes,
            'wastedBytesFormatted': _formatBytes(wastedBytes)
          });
          
          duplicates['wastedBytes'] += wastedBytes;
        }
      });
      
    } catch (e) {
      _logger.warning('Error analyzing duplicates: $e');
    }
    
    return duplicates;
  }
  
  Map<String, dynamic> _calculateScore(Map<String, dynamic> results) {
    int score = 100;
    final summary = <String, dynamic>{};
    
    // JavaScript optimization (20 points)
    if (results['javascript']['unminifiedFiles'].length > 0) {
      score -= 5;
      summary['jsMinified'] = false;
    }
    if (results['javascript']['largeFiles'].length > 0) {
      score -= 5;
      summary['jsLarge'] = true;
    }
    if ((results['unused']['javascript']['unusedPercentage'] ?? 0) > 50) {
      score -= 10;
      summary['jsUnused'] = true;
    }
    
    // CSS optimization (20 points)
    if (results['css']['unminifiedFiles'].length > 0) {
      score -= 5;
      summary['cssMinified'] = false;
    }
    if ((results['unused']['css']['unusedPercentage'] ?? 0) > 50) {
      score -= 10;
      summary['cssUnused'] = true;
    }
    if (results['css']['criticalCSS'] != true) {
      score -= 5;
      summary['criticalCSS'] = false;
    }
    
    // Image optimization (20 points)
    if (results['images']['largeImages'].length > 3) {
      score -= 10;
      summary['largeImages'] = true;
    }
    if (results['images']['formats']['webp'] == 0 && 
        results['images']['totalImages'] > 5) {
      score -= 5;
      summary['webpMissing'] = true;
    }
    if (results['images']['lazyLoaded'] < results['images']['totalImages'] / 2) {
      score -= 5;
      summary['lazyLoadingMissing'] = true;
    }
    
    // Compression (15 points)
    if (results['compression']['uncompressedResources'].length > 5) {
      score -= 10;
      summary['compressionMissing'] = true;
    }
    if (!results['compression']['compressionTypes'].containsKey('br') &&
        !results['compression']['compressionTypes'].containsKey('gzip')) {
      score -= 5;
      summary['noCompression'] = true;
    }
    
    // Caching (15 points)
    if (results['caching']['uncachedResources'].length > 5) {
      score -= 10;
      summary['cachingMissing'] = true;
    }
    if (results['caching']['avgCacheDuration'] < 86400) {
      score -= 5;
      summary['shortCache'] = true;
    }
    
    // Third-party (10 points)
    if (results['thirdParty']['percentage'] > 50) {
      score -= 10;
      summary['tooManyThirdParty'] = true;
    }
    
    score = math.max(0, score);
    
    // Calculate grade
    String grade;
    if (score >= 90) grade = 'A';
    else if (score >= 80) grade = 'B';
    else if (score >= 70) grade = 'C';
    else if (score >= 60) grade = 'D';
    else grade = 'F';
    
    return {
      'score': score,
      'grade': grade,
      'summary': summary
    };
  }
  
  List<Map<String, dynamic>> _identifyIssues(Map<String, dynamic> results) {
    final issues = <Map<String, dynamic>>[];
    
    // JavaScript issues
    if (results['javascript']['unminifiedFiles'].length > 0) {
      issues.add({
        'severity': 'medium',
        'category': 'JavaScript',
        'issue': 'Unminified JavaScript files',
        'count': results['javascript']['unminifiedFiles'].length,
        'impact': 'Larger file sizes, slower downloads'
      });
    }
    
    if ((results['unused']['javascript']['unusedPercentage'] ?? 0) > 50) {
      issues.add({
        'severity': 'high',
        'category': 'JavaScript',
        'issue': 'High percentage of unused JavaScript',
        'percentage': results['unused']['javascript']['unusedPercentage'],
        'impact': 'Unnecessary download and parse time'
      });
    }
    
    // CSS issues
    if ((results['unused']['css']['unusedPercentage'] ?? 0) > 50) {
      issues.add({
        'severity': 'medium',
        'category': 'CSS',
        'issue': 'High percentage of unused CSS',
        'percentage': results['unused']['css']['unusedPercentage'],
        'impact': 'Unnecessary download and render blocking'
      });
    }
    
    // Image issues
    if (results['images']['largeImages'].length > 0) {
      issues.add({
        'severity': 'high',
        'category': 'Images',
        'issue': 'Large image files',
        'count': results['images']['largeImages'].length,
        'totalSize': results['images']['largeImages']
          .fold(0, (sum, img) => sum + img['size']),
        'impact': 'Slow page load, high bandwidth usage'
      });
    }
    
    if (results['images']['missingAlt'].length > 0) {
      issues.add({
        'severity': 'medium',
        'category': 'Images',
        'issue': 'Images without alt text',
        'count': results['images']['missingAlt'].length,
        'impact': 'Poor accessibility, SEO impact'
      });
    }
    
    // Compression issues
    if (results['compression']['uncompressedResources'].length > 0) {
      issues.add({
        'severity': 'high',
        'category': 'Compression',
        'issue': 'Uncompressed text resources',
        'count': results['compression']['uncompressedResources'].length,
        'potentialSavings': results['compression']['potentialSavings'],
        'impact': 'Larger transfer sizes'
      });
    }
    
    // Caching issues
    if (results['caching']['uncachedResources'].length > 5) {
      issues.add({
        'severity': 'medium',
        'category': 'Caching',
        'issue': 'Resources without caching headers',
        'count': results['caching']['uncachedResources'].length,
        'impact': 'Repeated downloads, slower repeat visits'
      });
    }
    
    // Third-party issues
    if (results['thirdParty']['percentage'] > 50) {
      issues.add({
        'severity': 'high',
        'category': 'Third-party',
        'issue': 'High percentage of third-party resources',
        'percentage': results['thirdParty']['percentage'],
        'impact': 'Performance dependency on external services'
      });
    }
    
    // Duplicate resources
    if (results['duplicates']['hasDuplicates'] == true) {
      issues.add({
        'severity': 'medium',
        'category': 'Resources',
        'issue': 'Duplicate resource downloads',
        'count': results['duplicates']['duplicateResources'].length,
        'wastedBytes': results['duplicates']['wastedBytes'],
        'impact': 'Unnecessary network requests and bandwidth'
      });
    }
    
    return issues;
  }
  
  List<Map<String, dynamic>> _generateRecommendations(Map<String, dynamic> results) {
    final recommendations = <Map<String, dynamic>>[];
    
    // Bundle optimization
    if (results['bundles']['totalBundleSize'] > 500000) {
      recommendations.add({
        'priority': 'high',
        'category': 'Bundle Size',
        'recommendation': 'Implement code splitting',
        'details': 'Break large bundles into smaller chunks loaded on demand',
        'techniques': [
          'Dynamic imports',
          'Route-based splitting',
          'Component lazy loading'
        ]
      });
    }
    
    // Image optimization
    if (results['images']['formats']['webp'] == 0 && 
        results['images']['totalImages'] > 5) {
      recommendations.add({
        'priority': 'high',
        'category': 'Images',
        'recommendation': 'Use modern image formats',
        'details': 'Convert images to WebP or AVIF format',
        'potentialSaving': '25-35% file size reduction'
      });
    }
    
    if (results['images']['lazyLoaded'] < results['images']['totalImages'] / 2) {
      recommendations.add({
        'priority': 'medium',
        'category': 'Images',
        'recommendation': 'Implement lazy loading for images',
        'details': 'Use loading="lazy" attribute or JavaScript lazy loading',
        'benefit': 'Faster initial page load'
      });
    }
    
    // Compression
    if (results['compression']['uncompressedResources'].length > 0) {
      recommendations.add({
        'priority': 'high',
        'category': 'Compression',
        'recommendation': 'Enable text compression',
        'details': 'Enable gzip or Brotli compression on server',
        'potentialSaving': _formatBytes(results['compression']['potentialSavings'])
      });
    }
    
    // Caching
    if (results['caching']['avgCacheDuration'] < 86400) {
      recommendations.add({
        'priority': 'medium',
        'category': 'Caching',
        'recommendation': 'Implement long-term caching',
        'details': 'Use versioned URLs and set long cache durations',
        'suggestion': 'Cache-Control: public, max-age=31536000, immutable'
      });
    }
    
    // Unused code
    if ((results['unused']['css']['unusedPercentage'] ?? 0) > 50) {
      recommendations.add({
        'priority': 'medium',
        'category': 'CSS',
        'recommendation': 'Remove unused CSS',
        'details': 'Use tools like PurgeCSS or tree-shaking',
        'unusedPercentage': results['unused']['css']['unusedPercentage']
      });
    }
    
    if ((results['unused']['javascript']['unusedPercentage'] ?? 0) > 50) {
      recommendations.add({
        'priority': 'high',
        'category': 'JavaScript',
        'recommendation': 'Remove unused JavaScript',
        'details': 'Use tree-shaking and dead code elimination',
        'unusedPercentage': results['unused']['javascript']['unusedPercentage']
      });
    }
    
    // Font optimization
    if (results['fonts']['formats']['woff2'] == null && 
        results['fonts']['totalFonts'] > 0) {
      recommendations.add({
        'priority': 'low',
        'category': 'Fonts',
        'recommendation': 'Use WOFF2 font format',
        'details': 'Convert fonts to WOFF2 for better compression',
        'benefit': '30% smaller than WOFF'
      });
    }
    
    // Critical CSS
    if (results['css']['criticalCSS'] != true) {
      recommendations.add({
        'priority': 'medium',
        'category': 'CSS',
        'recommendation': 'Inline critical CSS',
        'details': 'Extract and inline above-the-fold CSS',
        'benefit': 'Eliminate render-blocking CSS'
      });
    }
    
    // Resource hints
    if (results['hints']['total'] == 0 && results['thirdParty']['totalRequests'] > 5) {
      recommendations.add({
        'priority': 'low',
        'category': 'Performance',
        'recommendation': 'Add resource hints',
        'details': 'Use preconnect for third-party origins',
        'example': '<link rel="preconnect" href="https://fonts.googleapis.com">'
      });
    }
    
    return recommendations;
  }
  
  bool _shouldBeCached(String mimeType, String url) {
    // Static resources that should typically be cached
    return mimeType.contains('image') ||
           mimeType.contains('css') ||
           mimeType.contains('javascript') ||
           mimeType.contains('font') ||
           url.endsWith('.woff') ||
           url.endsWith('.woff2');
  }
  
  bool _shouldBeCompressed(String mimeType) {
    // Text-based resources that benefit from compression
    return mimeType.contains('text') ||
           mimeType.contains('javascript') ||
           mimeType.contains('json') ||
           mimeType.contains('xml') ||
           mimeType.contains('css') ||
           mimeType.contains('svg');
  }
  
  String? _identifyService(String domain) {
    final services = {
      'googleapis.com': 'Google APIs',
      'google-analytics.com': 'Google Analytics',
      'googletagmanager.com': 'Google Tag Manager',
      'facebook.com': 'Facebook',
      'facebook.net': 'Facebook',
      'twitter.com': 'Twitter',
      'cloudflare.com': 'Cloudflare',
      'jsdelivr.net': 'jsDelivr CDN',
      'unpkg.com': 'unpkg CDN',
      'cdnjs.cloudflare.com': 'cdnjs',
      'ajax.googleapis.com': 'Google Hosted Libraries',
      'fonts.googleapis.com': 'Google Fonts',
      'youtube.com': 'YouTube',
      'vimeo.com': 'Vimeo',
      'stripe.com': 'Stripe',
      'paypal.com': 'PayPal',
      'amazon-adsystem.com': 'Amazon Ads',
      'doubleclick.net': 'Google Ads'
    };
    
    for (final entry in services.entries) {
      if (domain.contains(entry.key)) {
        return entry.value;
      }
    }
    
    return null;
  }
  
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

// Extension for AuditContext to hold extended resource results
extension ResourcesExtendedContext on AuditContext {
  static final _resourcesExtended = Expando<Map<String, dynamic>>();
  
  Map<String, dynamic>? get resourcesExtended => _resourcesExtended[this];
  set resourcesExtended(Map<String, dynamic>? value) => _resourcesExtended[this] = value;
}