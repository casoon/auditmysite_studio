import 'dart:convert';
import 'package:puppeteer/puppeteer.dart';
import 'package:logging/logging.dart';

/// Sammelt Performance-Metriken über Chrome DevTools Protocol
class CdpMetricsCollector {
  final Logger _logger = Logger('CdpMetricsCollector');
  final Page page;
  
  CdpMetricsCollector(this.page);

  /// Sammelt alle Performance-Metriken
  Future<Map<String, dynamic>> collectAllMetrics() async {
    final metrics = <String, dynamic>{};
    
    try {
      // Enable necessary domains
      await page.target.createCDPSession().then((session) async {
        await session.send('Performance.enable');
        await session.send('Network.enable');
        await session.send('Page.enable');
        await session.send('Runtime.enable');
        await session.send('Security.enable');
        await session.send('Emulation.clearDeviceMetricsOverride');
      });

      // Collect Core Web Vitals
      metrics['coreWebVitals'] = await _collectCoreWebVitals();
      
      // Collect Performance Timing
      metrics['performanceTiming'] = await _collectPerformanceTiming();
      
      // Collect Resource Timing
      metrics['resourceTiming'] = await _collectResourceTiming();
      
      // Collect Network Info
      metrics['networkInfo'] = await _collectNetworkInfo();
      
      // Collect JavaScript Coverage
      metrics['coverage'] = await _collectCoverage();
      
      // Collect Memory Usage
      metrics['memory'] = await _collectMemoryUsage();
      
      // Collect Console Messages
      metrics['consoleMessages'] = await _collectConsoleMessages();
      
      // Collect Security Info
      metrics['security'] = await _collectSecurityInfo();
      
    } catch (e) {
      _logger.warning('Error collecting CDP metrics: $e');
    }
    
    return metrics;
  }

  /// Sammelt Core Web Vitals (LCP, FID, CLS, FCP, TTFB)
  Future<Map<String, dynamic>> _collectCoreWebVitals() async {
    try {
      final webVitals = await page.evaluate('''() => {
        return new Promise((resolve) => {
          const result = {
            lcp: null,
            fid: null,
            cls: null,
            fcp: null,
            ttfb: null,
            inp: null
          };
          
          // Largest Contentful Paint
          new PerformanceObserver((list) => {
            const entries = list.getEntries();
            const lastEntry = entries[entries.length - 1];
            result.lcp = lastEntry.renderTime || lastEntry.loadTime;
          }).observe({type: 'largest-contentful-paint', buffered: true});
          
          // First Input Delay
          new PerformanceObserver((list) => {
            const entries = list.getEntries();
            if (entries.length > 0) {
              result.fid = entries[0].processingStart - entries[0].startTime;
            }
          }).observe({type: 'first-input', buffered: true});
          
          // Cumulative Layout Shift
          let clsValue = 0;
          let clsEntries = [];
          let sessionValue = 0;
          let sessionEntries = [];
          new PerformanceObserver((list) => {
            for (const entry of list.getEntries()) {
              if (!entry.hadRecentInput) {
                const firstSessionEntry = sessionEntries[0];
                const lastSessionEntry = sessionEntries[sessionEntries.length - 1];
                if (sessionValue && entry.startTime - lastSessionEntry.startTime < 1000 && 
                    entry.startTime - firstSessionEntry.startTime < 5000) {
                  sessionValue += entry.value;
                  sessionEntries.push(entry);
                } else {
                  sessionValue = entry.value;
                  sessionEntries = [entry];
                }
                if (sessionValue > clsValue) {
                  clsValue = sessionValue;
                  clsEntries = sessionEntries;
                }
              }
            }
            result.cls = clsValue;
          }).observe({type: 'layout-shift', buffered: true});
          
          // First Contentful Paint
          const fcpEntry = performance.getEntriesByName('first-contentful-paint')[0];
          if (fcpEntry) {
            result.fcp = fcpEntry.startTime;
          }
          
          // Time to First Byte
          const navTiming = performance.getEntriesByType('navigation')[0];
          if (navTiming) {
            result.ttfb = navTiming.responseStart - navTiming.requestStart;
          }
          
          // Interaction to Next Paint (INP)
          let inp = 0;
          new PerformanceObserver((list) => {
            for (const entry of list.getEntries()) {
              if (entry.duration > inp) {
                inp = entry.duration;
              }
            }
            result.inp = inp;
          }).observe({type: 'event', buffered: true});
          
          // Wait a bit for observers to collect data
          setTimeout(() => resolve(result), 2000);
        });
      }''');
      
      return Map<String, dynamic>.from(webVitals as Map);
    } catch (e) {
      _logger.warning('Error collecting Core Web Vitals: $e');
      return {};
    }
  }

  /// Sammelt Performance Timing API Daten
  Future<Map<String, dynamic>> _collectPerformanceTiming() async {
    try {
      final timing = await page.evaluate('''() => {
        const timing = performance.timing;
        const navigation = performance.getEntriesByType('navigation')[0] || {};
        
        return {
          // Navigation Timing
          navigationStart: timing.navigationStart,
          unloadEventStart: timing.unloadEventStart,
          unloadEventEnd: timing.unloadEventEnd,
          redirectStart: timing.redirectStart,
          redirectEnd: timing.redirectEnd,
          fetchStart: timing.fetchStart,
          domainLookupStart: timing.domainLookupStart,
          domainLookupEnd: timing.domainLookupEnd,
          connectStart: timing.connectStart,
          connectEnd: timing.connectEnd,
          secureConnectionStart: timing.secureConnectionStart,
          requestStart: timing.requestStart,
          responseStart: timing.responseStart,
          responseEnd: timing.responseEnd,
          domLoading: timing.domLoading,
          domInteractive: timing.domInteractive,
          domContentLoadedEventStart: timing.domContentLoadedEventStart,
          domContentLoadedEventEnd: timing.domContentLoadedEventEnd,
          domComplete: timing.domComplete,
          loadEventStart: timing.loadEventStart,
          loadEventEnd: timing.loadEventEnd,
          
          // Calculated metrics
          dns: timing.domainLookupEnd - timing.domainLookupStart,
          tcp: timing.connectEnd - timing.connectStart,
          ssl: timing.secureConnectionStart > 0 ? timing.connectEnd - timing.secureConnectionStart : 0,
          ttfb: timing.responseStart - timing.requestStart,
          download: timing.responseEnd - timing.responseStart,
          domParse: timing.domInteractive - timing.domLoading,
          domContentLoaded: timing.domContentLoadedEventEnd - timing.domContentLoadedEventStart,
          domComplete: timing.domComplete - timing.domInteractive,
          loadEvent: timing.loadEventEnd - timing.loadEventStart,
          totalTime: timing.loadEventEnd - timing.navigationStart,
          
          // Navigation API v2
          serverTiming: navigation.serverTiming || [],
          nextHopProtocol: navigation.nextHopProtocol,
          transferSize: navigation.transferSize,
          encodedBodySize: navigation.encodedBodySize,
          decodedBodySize: navigation.decodedBodySize,
          workerStart: navigation.workerStart
        };
      }''');
      
      return Map<String, dynamic>.from(timing as Map);
    } catch (e) {
      _logger.warning('Error collecting Performance Timing: $e');
      return {};
    }
  }

  /// Sammelt Resource Timing Daten
  Future<List<Map<String, dynamic>>> _collectResourceTiming() async {
    try {
      final resources = await page.evaluate('''() => {
        return performance.getEntriesByType('resource').map(entry => ({
          name: entry.name,
          entryType: entry.entryType,
          startTime: entry.startTime,
          duration: entry.duration,
          initiatorType: entry.initiatorType,
          nextHopProtocol: entry.nextHopProtocol,
          workerStart: entry.workerStart,
          redirectStart: entry.redirectStart,
          redirectEnd: entry.redirectEnd,
          fetchStart: entry.fetchStart,
          domainLookupStart: entry.domainLookupStart,
          domainLookupEnd: entry.domainLookupEnd,
          connectStart: entry.connectStart,
          connectEnd: entry.connectEnd,
          secureConnectionStart: entry.secureConnectionStart,
          requestStart: entry.requestStart,
          responseStart: entry.responseStart,
          responseEnd: entry.responseEnd,
          transferSize: entry.transferSize,
          encodedBodySize: entry.encodedBodySize,
          decodedBodySize: entry.decodedBodySize,
          serverTiming: entry.serverTiming || [],
          renderBlockingStatus: entry.renderBlockingStatus
        }));
      }''');
      
      return List<Map<String, dynamic>>.from(resources as List);
    } catch (e) {
      _logger.warning('Error collecting Resource Timing: $e');
      return [];
    }
  }

  /// Sammelt Netzwerk-Informationen
  Future<Map<String, dynamic>> _collectNetworkInfo() async {
    try {
      final networkInfo = await page.evaluate('''() => {
        const connection = navigator.connection || navigator.mozConnection || navigator.webkitConnection;
        if (connection) {
          return {
            effectiveType: connection.effectiveType,
            rtt: connection.rtt,
            downlink: connection.downlink,
            saveData: connection.saveData
          };
        }
        return {};
      }''');
      
      return Map<String, dynamic>.from(networkInfo as Map);
    } catch (e) {
      _logger.warning('Error collecting Network Info: $e');
      return {};
    }
  }

  /// Sammelt JavaScript und CSS Coverage
  Future<Map<String, dynamic>> _collectCoverage() async {
    try {
      // Start coverage
      await page.coverage.startJSCoverage();
      await page.coverage.startCSSCoverage();
      
      // Wait a bit for execution
      await Future.delayed(Duration(seconds: 2));
      
      // Stop coverage
      final jsCoverage = await page.coverage.stopJSCoverage();
      final cssCoverage = await page.coverage.stopCSSCoverage();
      
      // Calculate coverage stats
      num totalJSBytes = 0;
      num usedJSBytes = 0;
      for (final entry in jsCoverage) {
        totalJSBytes += entry.text.length;
        for (final range in entry.ranges) {
          usedJSBytes += range.end - range.start;
        }
      }
      
      num totalCSSBytes = 0;
      num usedCSSBytes = 0;
      for (final entry in cssCoverage) {
        totalCSSBytes += entry.text.length;
        for (final range in entry.ranges) {
          usedCSSBytes += range.end - range.start;
        }
      }
      
      return {
        'js': {
          'total': totalJSBytes,
          'used': usedJSBytes,
          'unused': totalJSBytes - usedJSBytes,
          'percentage': totalJSBytes > 0 ? (usedJSBytes / totalJSBytes * 100).round() : 100
        },
        'css': {
          'total': totalCSSBytes,
          'used': usedCSSBytes,
          'unused': totalCSSBytes - usedCSSBytes,
          'percentage': totalCSSBytes > 0 ? (usedCSSBytes / totalCSSBytes * 100).round() : 100
        }
      };
    } catch (e) {
      _logger.warning('Error collecting Coverage: $e');
      return {};
    }
  }

  /// Sammelt Memory Usage
  Future<Map<String, dynamic>> _collectMemoryUsage() async {
    try {
      final memory = await page.evaluate('''() => {
        if (performance.memory) {
          return {
            usedJSHeapSize: performance.memory.usedJSHeapSize,
            totalJSHeapSize: performance.memory.totalJSHeapSize,
            jsHeapSizeLimit: performance.memory.jsHeapSizeLimit
          };
        }
        return {};
      }''');
      
      return Map<String, dynamic>.from(memory as Map);
    } catch (e) {
      _logger.warning('Error collecting Memory Usage: $e');
      return {};
    }
  }

  /// Sammelt Console Messages
  Future<List<Map<String, dynamic>>> _collectConsoleMessages() async {
    final messages = <Map<String, dynamic>>[];
    
    // Listen to console events
    page.onConsole.listen((msg) {
      messages.add({
        'type': msg.type?.toString() ?? 'log',
        'text': msg.text,
        'timestamp': DateTime.now().toIso8601String(),
        'location': msg.location?.toString() ?? '',
        'stackTrace': msg.stackTrace?.toString() ?? ''
      });
    });
    
    // Listen to page errors
    page.onError.listen((error) {
      messages.add({
        'type': 'error',
        'text': error.toString(),
        'timestamp': DateTime.now().toIso8601String()
      });
    });
    
    // Wait a bit to collect messages
    await Future.delayed(Duration(seconds: 2));
    
    return messages;
  }

  /// Sammelt Security Informationen
  Future<Map<String, dynamic>> _collectSecurityInfo() async {
    try {
      // Get protocol
      final url = page.url;
      final isHttps = url?.startsWith('https://') ?? false;
      
      // Check for mixed content
      final hasMixedContent = await page.evaluate('''() => {
        const resources = performance.getEntriesByType('resource');
        const pageProtocol = window.location.protocol;
        return resources.some(r => {
          if (pageProtocol === 'https:' && r.name.startsWith('http:')) {
            return true;
          }
          return false;
        });
      }''');
      
      return {
        'isHttps': isHttps,
        'hasMixedContent': hasMixedContent,
        'protocol': Uri.tryParse(url ?? '')?.scheme ?? 'unknown'
      };
    } catch (e) {
      _logger.warning('Error collecting Security Info: $e');
      return {};
    }
  }

  /// Sammelt Long Tasks
  Future<List<Map<String, dynamic>>> _collectLongTasks() async {
    try {
      final longTasks = await page.evaluate('''() => {
        return new Promise((resolve) => {
          const tasks = [];
          new PerformanceObserver((list) => {
            for (const entry of list.getEntries()) {
              tasks.push({
                name: entry.name,
                duration: entry.duration,
                startTime: entry.startTime,
                attribution: entry.attribution
              });
            }
          }).observe({type: 'longtask', buffered: true});
          
          setTimeout(() => resolve(tasks), 2000);
        });
      }''');
      
      return List<Map<String, dynamic>>.from(longTasks as List);
    } catch (e) {
      _logger.warning('Error collecting Long Tasks: $e');
      return [];
    }
  }
}