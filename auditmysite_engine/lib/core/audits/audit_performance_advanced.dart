import 'package:puppeteer/puppeteer.dart';
import '../events.dart';
import 'audit_base.dart';
import '../performance_budgets.dart';

/// Advanced Performance Audit with feature parity to NPM tool
class AdvancedPerformanceAudit extends Audit {
  final PerformanceBudget? budget;
  
  AdvancedPerformanceAudit({this.budget});
  
  @override
  String get name => 'performance_advanced';

  @override
  Future<void> run(AuditContext ctx) async {
    final page = ctx.page as Page;
    
    // Inject Web Vitals measurement script
    await page.evaluateOnNewDocument(r'''
      window.__webVitals = {
        lcp: 0,
        fcp: 0,
        cls: 0,
        fid: 0,
        inp: 0,
        ttfb: 0,
        tbt: 0,
        interactions: []
      };
      
      // Performance Observer for Web Vitals
      if (typeof PerformanceObserver !== 'undefined') {
        // LCP Observer
        try {
          const lcpObserver = new PerformanceObserver((list) => {
            const entries = list.getEntries();
            const lastEntry = entries[entries.length - 1];
            window.__webVitals.lcp = Math.round(lastEntry.startTime);
          });
          lcpObserver.observe({ type: 'largest-contentful-paint', buffered: true });
        } catch(e) {}
        
        // FCP Observer
        try {
          const fcpObserver = new PerformanceObserver((list) => {
            const entries = list.getEntries();
            for (const entry of entries) {
              if (entry.name === 'first-contentful-paint') {
                window.__webVitals.fcp = Math.round(entry.startTime);
              }
            }
          });
          fcpObserver.observe({ type: 'paint', buffered: true });
        } catch(e) {}
        
        // CLS Observer
        try {
          let clsValue = 0;
          let clsEntries = [];
          const clsObserver = new PerformanceObserver((list) => {
            for (const entry of list.getEntries()) {
              if (!entry.hadRecentInput) {
                clsValue += entry.value;
                clsEntries.push({
                  time: entry.startTime,
                  value: entry.value
                });
              }
            }
            window.__webVitals.cls = Math.round(clsValue * 1000) / 1000;
          });
          clsObserver.observe({ type: 'layout-shift', buffered: true });
        } catch(e) {}
        
        // FID Observer
        try {
          const fidObserver = new PerformanceObserver((list) => {
            for (const entry of list.getEntries()) {
              window.__webVitals.fid = Math.round(entry.processingStart - entry.startTime);
            }
          });
          fidObserver.observe({ type: 'first-input', buffered: true });
        } catch(e) {}
      }
      
      // Track interactions for INP
      window.addEventListener('click', (e) => {
        const startTime = performance.now();
        requestAnimationFrame(() => {
          const duration = performance.now() - startTime;
          window.__webVitals.interactions.push(duration);
        });
      });
      
      window.addEventListener('keydown', (e) => {
        const startTime = performance.now();
        requestAnimationFrame(() => {
          const duration = performance.now() - startTime;
          window.__webVitals.interactions.push(duration);
        });
      });
    ''');
    
    // Navigate if needed (assuming page is already loaded)
    // Wait for load metrics
    await Future.delayed(Duration(milliseconds: 2000));
    
    // Simulate user interactions for INP/FID
    await _simulateInteractions(page);
    
    // Collect all performance metrics
    final metrics = await _collectPerformanceMetrics(page);
    
    // Calculate Total Blocking Time (TBT)
    final tbt = await _calculateTBT(page);
    metrics['tbt'] = tbt;
    
    // Calculate Speed Index
    final speedIndex = await _calculateSpeedIndex(page);
    metrics['speedIndex'] = speedIndex;
    
    // Get resource timings
    final resourceTimings = await _collectResourceTimings(page);
    metrics['resourceTimings'] = resourceTimings;
    
    // Analyze against budget if provided
    Map<String, dynamic>? budgetAnalysis;
    if (budget != null) {
      budgetAnalysis = _analyzeBudgetCompliance(metrics, budget!);
    }
    
    // Calculate scores and grades
    final performanceScore = _calculatePerformanceScore(metrics);
    final performanceGrade = _calculateGrade(performanceScore);
    
    // Generate recommendations
    final recommendations = _generateRecommendations(metrics, budgetAnalysis);
    
    // Build comprehensive result
    final result = {
      'metrics': metrics,
      'score': performanceScore,
      'grade': performanceGrade,
      'budgetAnalysis': budgetAnalysis,
      'recommendations': recommendations,
      'resourceTimings': resourceTimings,
    };
    
    // Store in context
    ctx.performanceResult = result;
  }
  
  Future<void> _simulateInteractions(Page page) async {
    try {
      // Move mouse to trigger potential hover effects
      await page.mouse.move(Point(100, 100));
      await Future.delayed(Duration(milliseconds: 100));
      
      // Simulate click
      await page.mouse.click(Point(200, 200));
      await Future.delayed(Duration(milliseconds: 100));
      
      // Simulate keyboard
      await page.keyboard.press(Key.tab);
      await Future.delayed(Duration(milliseconds: 100));
      
      // Simulate scroll for CLS
      await page.evaluate('window.scrollTo(0, 100)');
      await Future.delayed(Duration(milliseconds: 500));
      await page.evaluate('window.scrollTo(0, 0)');
      await Future.delayed(Duration(milliseconds: 500));
    } catch (e) {
      // Ignore interaction errors
    }
  }
  
  Future<Map<String, dynamic>> _collectPerformanceMetrics(Page page) async {
    // Get Web Vitals data
    final webVitals = await page.evaluate(r'''
() => {
        const vitals = window.__webVitals || {};
        
        // Calculate INP from interactions
        const interactions = vitals.interactions || [];
        let inp = 0;
        if (interactions.length > 0) {
          interactions.sort((a, b) => b - a);
          // INP is the 98th percentile of interactions
          const index = Math.floor(interactions.length * 0.98);
          inp = Math.round(interactions[index] || 0);
        }
        
        return {
          lcp: vitals.lcp || 0,
          fcp: vitals.fcp || 0,
          cls: vitals.cls || 0,
          fid: vitals.fid || 0,
          inp: inp
        };
}
    ''');
    
    // Get navigation timing metrics
    final timingMetrics = await page.evaluate(r'''
() => {
        const nav = performance.getEntriesByType('navigation')[0];
        const paint = performance.getEntriesByType('paint');
        
        const firstPaint = paint.find(p => p.name === 'first-paint');
        const firstContentfulPaint = paint.find(p => p.name === 'first-contentful-paint');
        
        if (!nav) return {};
        
        return {
          ttfb: Math.round(nav.responseStart - nav.requestStart),
          domContentLoaded: Math.round(nav.domContentLoadedEventEnd - nav.fetchStart),
          loadComplete: Math.round(nav.loadEventEnd - nav.fetchStart),
          firstPaint: firstPaint ? Math.round(firstPaint.startTime) : 0,
          firstContentfulPaint: firstContentfulPaint ? Math.round(firstContentfulPaint.startTime) : 0,
          domInteractive: Math.round(nav.domInteractive - nav.fetchStart),
          dns: Math.round(nav.domainLookupEnd - nav.domainLookupStart),
          tcp: Math.round(nav.connectEnd - nav.connectStart),
          ssl: nav.secureConnectionStart > 0 ? Math.round(nav.connectEnd - nav.secureConnectionStart) : 0,
          serverResponse: Math.round(nav.responseEnd - nav.requestStart),
          transferSize: nav.transferSize || 0,
          encodedBodySize: nav.encodedBodySize || 0,
          decodedBodySize: nav.decodedBodySize || 0
        };
}
    ''');
    
    // Try to get LCP from performance entries if not captured
    if (webVitals['lcp'] == 0) {
      final lcpFromEntries = await page.evaluate(r'''
() => {
          const entries = performance.getEntriesByType('largest-contentful-paint');
          if (entries && entries.length > 0) {
            return Math.round(entries[entries.length - 1].startTime);
          }
          return 0;
}
      ''');
      if (lcpFromEntries > 0) {
        webVitals['lcp'] = lcpFromEntries;
      }
    }
    
    // Merge all metrics
    final merged = <String, dynamic>{};
    merged.addAll(webVitals as Map<String, dynamic>);
    merged.addAll(timingMetrics as Map<String, dynamic>);
    return merged;
  }
  
  Future<double> _calculateTBT(Page page) async {
    // Calculate Total Blocking Time
    final tbt = await page.evaluate(r'''
() => {
        const longTasks = performance.getEntriesByType('longtask');
        let totalBlockingTime = 0;
        
        for (const task of longTasks) {
          // Only count time over 50ms as blocking
          const blockingTime = Math.max(0, task.duration - 50);
          // Only count tasks between FCP and TTI (simplified: before load)
          if (task.startTime < performance.timing.loadEventEnd - performance.timing.navigationStart) {
            totalBlockingTime += blockingTime;
          }
        }
        
        return Math.round(totalBlockingTime);
}
    ''');
    
    return tbt.toDouble();
  }
  
  Future<double> _calculateSpeedIndex(Page page) async {
    // Simplified Speed Index calculation
    // Real implementation would need visual progress tracking
    
    final fcp = await page.evaluate(r'''
() => {
        const paint = performance.getEntriesByType('paint');
        const fcp = paint.find(p => p.name === 'first-contentful-paint');
        return fcp ? fcp.startTime : 0;
}
    ''');
    
    final loadComplete = await page.evaluate(r'''
() => {
        const nav = performance.getEntriesByType('navigation')[0];
        return nav ? nav.loadEventEnd - nav.fetchStart : 0;
}
    ''');
    
    // Approximate Speed Index as weighted average
    // This is simplified - real Speed Index requires video analysis
    final speedIndex = (fcp * 0.3 + loadComplete * 0.7).round();
    
    return speedIndex.toDouble();
  }
  
  Future<List<Map<String, dynamic>>> _collectResourceTimings(Page page) async {
    final resources = await page.evaluate(r'''
() => {
        const resources = performance.getEntriesByType('resource');
        const timings = [];
        
        for (const resource of resources.slice(0, 100)) { // Limit to 100 resources
          const timing = {
            name: resource.name,
            type: resource.initiatorType,
            startTime: Math.round(resource.startTime),
            duration: Math.round(resource.duration),
            transferSize: resource.transferSize || 0,
            encodedBodySize: resource.encodedBodySize || 0,
            decodedBodySize: resource.decodedBodySize || 0,
            dns: Math.round(resource.domainLookupEnd - resource.domainLookupStart),
            tcp: Math.round(resource.connectEnd - resource.connectStart),
            ttfb: Math.round(resource.responseStart - resource.requestStart),
            download: Math.round(resource.responseEnd - resource.responseStart)
          };
          
          // Categorize by type
          if (resource.name.match(/\.(css|scss|sass|less)$/i)) {
            timing.category = 'css';
          } else if (resource.name.match(/\.(js|jsx|ts|tsx|mjs)$/i)) {
            timing.category = 'javascript';
          } else if (resource.name.match(/\.(jpg|jpeg|png|gif|webp|svg|ico)$/i)) {
            timing.category = 'image';
          } else if (resource.name.match(/\.(woff|woff2|ttf|otf|eot)$/i)) {
            timing.category = 'font';
          } else if (resource.initiatorType === 'xmlhttprequest' || resource.initiatorType === 'fetch') {
            timing.category = 'ajax';
          } else {
            timing.category = 'other';
          }
          
          timings.push(timing);
        }
        
        return timings;
}
    ''');
    
    return List<Map<String, dynamic>>.from(resources);
  }
  
  Map<String, dynamic> _analyzeBudgetCompliance(
    Map<String, dynamic> metrics,
    PerformanceBudget budget,
  ) {
    final results = <String, dynamic>{};
    final failures = <String>[];
    final warnings = <String>[];
    
    // Check each metric against budget
    budget.thresholds.forEach((metric, threshold) {
      final value = metrics[metric];
      if (value != null) {
        final numValue = value is num ? value.toDouble() : 0.0;
        final passes = budget.checkMetric(metric, numValue);
        final status = numValue <= threshold.goodValue ? 'good' :
                       numValue <= threshold.needsWorkValue ? 'needs-improvement' :
                       numValue <= threshold.maxValue ? 'poor' : 'failing';
        
        results[metric] = {
          'value': numValue,
          'status': status,
          'passes': passes,
          'threshold': {
            'good': threshold.goodValue,
            'needsWork': threshold.needsWorkValue,
            'max': threshold.maxValue,
          },
          'unit': threshold.unit,
        };
        
        if (!passes) {
          failures.add('$metric exceeds budget (${numValue}${threshold.unit} > ${threshold.maxValue}${threshold.unit})');
        } else if (status == 'needs-improvement' || status == 'poor') {
          warnings.add('$metric needs improvement (${numValue}${threshold.unit})');
        }
      }
    });
    
    // Convert metrics to doubles for budget calculations
    final doubleMetrics = <String, double>{};
    metrics.forEach((key, value) {
      if (value is num) {
        doubleMetrics[key] = value.toDouble();
      }
    });
    
    final score = budget.calculateScore(doubleMetrics);
    final grade = budget.getGrade(doubleMetrics);
    
    return {
      'budget': budget.name,
      'description': budget.description,
      'metrics': results,
      'score': score,
      'grade': grade,
      'passes': failures.isEmpty,
      'failures': failures,
      'warnings': warnings,
    };
  }
  
  double _calculatePerformanceScore(Map<String, dynamic> metrics) {
    double score = 0;
    
    // LCP (25%)
    final lcp = metrics['lcp'] ?? 0;
    if (lcp <= 2500) score += 25;
    else if (lcp <= 4000) score += 15;
    else score += 5;
    
    // FCP (20%)
    final fcp = metrics['fcp'] ?? 0;
    if (fcp <= 1800) score += 20;
    else if (fcp <= 3000) score += 12;
    else score += 4;
    
    // CLS (15%)
    final cls = metrics['cls'] ?? 0;
    if (cls <= 0.1) score += 15;
    else if (cls <= 0.25) score += 9;
    else score += 3;
    
    // TBT (25%)
    final tbt = metrics['tbt'] ?? 0;
    if (tbt <= 200) score += 25;
    else if (tbt <= 600) score += 15;
    else score += 5;
    
    // Speed Index (15%)
    final si = metrics['speedIndex'] ?? 0;
    if (si <= 3400) score += 15;
    else if (si <= 5800) score += 9;
    else score += 3;
    
    return score.clamp(0, 100);
  }
  
  String _calculateGrade(double score) {
    if (score >= 90) return 'A';
    if (score >= 80) return 'B';
    if (score >= 70) return 'C';
    if (score >= 60) return 'D';
    return 'F';
  }
  
  List<String> _generateRecommendations(
    Map<String, dynamic> metrics,
    Map<String, dynamic>? budgetAnalysis,
  ) {
    final recommendations = <String>[];
    
    // LCP recommendations
    final lcp = metrics['lcp'] ?? 0;
    if (lcp > 4000) {
      recommendations.add('Critical: LCP is ${lcp}ms. Optimize server response, use CDN, and optimize images');
    } else if (lcp > 2500) {
      recommendations.add('LCP needs improvement (${lcp}ms). Consider lazy loading and resource prioritization');
    }
    
    // FCP recommendations  
    final fcp = metrics['fcp'] ?? 0;
    if (fcp > 3000) {
      recommendations.add('FCP is slow (${fcp}ms). Reduce render-blocking resources and optimize critical CSS');
    }
    
    // CLS recommendations
    final cls = metrics['cls'] ?? 0;
    if (cls > 0.25) {
      recommendations.add('High layout shift (${cls}). Set dimensions for images/videos and avoid dynamic content injection');
    } else if (cls > 0.1) {
      recommendations.add('Some layout shift detected (${cls}). Review dynamic content loading');
    }
    
    // TBT recommendations
    final tbt = metrics['tbt'] ?? 0;
    if (tbt > 600) {
      recommendations.add('High blocking time (${tbt}ms). Split long tasks and optimize JavaScript execution');
    } else if (tbt > 200) {
      recommendations.add('Some blocking time (${tbt}ms). Consider code splitting and lazy loading');
    }
    
    // TTFB recommendations
    final ttfb = metrics['ttfb'] ?? 0;
    if (ttfb > 1800) {
      recommendations.add('Slow server response (${ttfb}ms). Optimize backend, use caching, consider CDN');
    }
    
    // Budget-based recommendations
    if (budgetAnalysis != null && budgetAnalysis['failures'] != null) {
      final failures = budgetAnalysis['failures'] as List;
      if (failures.isNotEmpty) {
        recommendations.add('Performance budget violations: ${failures.join(', ')}');
      }
    }
    
    // Resource recommendations
    final transferSize = metrics['transferSize'] ?? 0;
    if (transferSize > 1000000) {
      final sizeMB = (transferSize / 1048576).toStringAsFixed(1);
      recommendations.add('Page size is ${sizeMB}MB. Optimize images, minify code, enable compression');
    }
    
    return recommendations;
  }
}