import 'package:puppeteer/puppeteer.dart';
import '../events.dart';
import 'audit_base.dart';

/// Performance thresholds based on Core Web Vitals
class PerformanceThresholds {
  static const double lcpGoodMs = 2500.0;
  static const double lcpNeedsImprovementMs = 4000.0;
  static const double fcpGoodMs = 1800.0;
  static const double fcpNeedsImprovementMs = 3000.0;
  static const double clsGood = 0.1;
  static const double clsNeedsImprovement = 0.25;
  static const double ttfbGoodMs = 800.0;
  static const double ttfbNeedsImprovementMs = 1800.0;
  static const double inpGoodMs = 200.0;
  static const double inpNeedsImprovementMs = 500.0;
}

/// Performance issue detected during analysis
class PerformanceIssue {
  final String type;
  final String severity;
  final String message;
  final double value;
  final double threshold;

  PerformanceIssue({
    required this.type,
    required this.severity,
    required this.message,
    required this.value,
    required this.threshold,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'severity': severity,
    'message': message,
    'value': value,
    'threshold': threshold,
  };
}

class PerfAudit implements Audit {
  @override
  String get name => 'perf';

  @override
  Future<void> run(AuditContext ctx) async {
    final page = ctx.page as Page;

    // Enhanced performance metrics collection
    final perfData = await page.evaluate(r'''
() => {
  const nav = performance.getEntriesByType('navigation')[0] || {};
  const fcp = performance.getEntriesByName('first-contentful-paint')[0];
  const lcp = performance.getEntriesByType('largest-contentful-paint').slice(-1)[0];
  
  // Try to get CLS (Cumulative Layout Shift)
  let cls = 0;
  try {
    const clsEntries = performance.getEntriesByType('layout-shift');
    cls = clsEntries.reduce((acc, entry) => acc + (entry.hadRecentInput ? 0 : entry.value), 0);
  } catch (e) {
    // CLS not available in older browsers
  }
  
  // Try to get INP (Interaction to Next Paint) - experimental
  let inp = null;
  try {
    const inpObserver = new PerformanceObserver(() => {});
    // INP is still experimental, fallback to null
  } catch (e) {
    // INP not available
  }
  
  return {
    ttfb: nav.responseStart || null,
    fcp: fcp ? fcp.startTime : null,
    lcp: lcp ? lcp.startTime : null,
    dcl: nav.domContentLoadedEventEnd || null,
    loadEnd: nav.loadEventEnd || null,
    cls: cls,
    inp: inp,
    // Additional useful metrics
    firstPaint: performance.getEntriesByName('first-paint')[0]?.startTime || null,
    redirectTime: nav.redirectEnd ? (nav.redirectEnd - nav.redirectStart) : 0,
    dnsTime: nav.domainLookupEnd ? (nav.domainLookupEnd - nav.domainLookupStart) : 0,
    connectTime: nav.connectEnd ? (nav.connectEnd - nav.connectStart) : 0,
  };
}
''');

    // Store basic metrics
    ctx.ttfbMs = (perfData['ttfb'] as num?)?.toDouble();
    ctx.fcpMs = (perfData['fcp'] as num?)?.toDouble();
    ctx.lcpMs = (perfData['lcp'] as num?)?.toDouble();
    ctx.dclMs = (perfData['dcl'] as num?)?.toDouble();
    ctx.loadEndMs = (perfData['loadEnd'] as num?)?.toDouble();
    
    // Store enhanced metrics
    final clsValue = (perfData['cls'] as num?)?.toDouble() ?? 0.0;
    final inpValue = (perfData['inp'] as num?)?.toDouble();
    final firstPaintMs = (perfData['firstPaint'] as num?)?.toDouble();
    final redirectTimeMs = (perfData['redirectTime'] as num?)?.toDouble() ?? 0.0;
    final dnsTimeMs = (perfData['dnsTime'] as num?)?.toDouble() ?? 0.0;
    final connectTimeMs = (perfData['connectTime'] as num?)?.toDouble() ?? 0.0;
    
    // Generate comprehensive performance result
    final performanceResult = _generatePerformanceResult(
      ttfb: ctx.ttfbMs,
      fcp: ctx.fcpMs,
      lcp: ctx.lcpMs,
      cls: clsValue,
      inp: inpValue,
      dcl: ctx.dclMs,
      loadEnd: ctx.loadEndMs,
      firstPaint: firstPaintMs,
      redirectTime: redirectTimeMs,
      dnsTime: dnsTimeMs,
      connectTime: connectTimeMs,
    );
    
    // Store complete performance result in context
    ctx.performanceResult = performanceResult;
  }
  
  /// Generate complete PerformanceResult according to TypeScript interface
  Map<String, dynamic> _generatePerformanceResult({
    double? ttfb,
    double? fcp,
    double? lcp,
    double? cls,
    double? inp,
    double? dcl,
    double? loadEnd,
    double? firstPaint,
    double? redirectTime,
    double? dnsTime,
    double? connectTime,
  }) {
    final issues = <PerformanceIssue>[];
    
    // Detect performance issues
    if (lcp != null && lcp > PerformanceThresholds.lcpNeedsImprovementMs) {
      issues.add(PerformanceIssue(
        type: 'lcp-slow',
        severity: 'error',
        message: 'Largest Contentful Paint is too slow (${lcp.round()}ms). Should be under ${PerformanceThresholds.lcpGoodMs.round()}ms for good performance.',
        value: lcp,
        threshold: PerformanceThresholds.lcpGoodMs,
      ));
    } else if (lcp != null && lcp > PerformanceThresholds.lcpGoodMs) {
      issues.add(PerformanceIssue(
        type: 'lcp-slow',
        severity: 'warning',
        message: 'Largest Contentful Paint needs improvement (${lcp.round()}ms). Should be under ${PerformanceThresholds.lcpGoodMs.round()}ms for good performance.',
        value: lcp,
        threshold: PerformanceThresholds.lcpGoodMs,
      ));
    }
    
    if (fcp != null && fcp > PerformanceThresholds.fcpNeedsImprovementMs) {
      issues.add(PerformanceIssue(
        type: 'fcp-slow',
        severity: 'error',
        message: 'First Contentful Paint is too slow (${fcp.round()}ms). Should be under ${PerformanceThresholds.fcpGoodMs.round()}ms for good performance.',
        value: fcp,
        threshold: PerformanceThresholds.fcpGoodMs,
      ));
    } else if (fcp != null && fcp > PerformanceThresholds.fcpGoodMs) {
      issues.add(PerformanceIssue(
        type: 'fcp-slow',
        severity: 'warning',
        message: 'First Contentful Paint needs improvement (${fcp.round()}ms). Should be under ${PerformanceThresholds.fcpGoodMs.round()}ms for good performance.',
        value: fcp,
        threshold: PerformanceThresholds.fcpGoodMs,
      ));
    }
    
    if (cls != null && cls > PerformanceThresholds.clsNeedsImprovement) {
      issues.add(PerformanceIssue(
        type: 'cls-high',
        severity: 'error',
        message: 'Cumulative Layout Shift is too high (${cls.toStringAsFixed(3)}). Should be under ${PerformanceThresholds.clsGood.toStringAsFixed(1)} for good performance.',
        value: cls,
        threshold: PerformanceThresholds.clsGood,
      ));
    } else if (cls != null && cls > PerformanceThresholds.clsGood) {
      issues.add(PerformanceIssue(
        type: 'cls-high',
        severity: 'warning',
        message: 'Cumulative Layout Shift needs improvement (${cls.toStringAsFixed(3)}). Should be under ${PerformanceThresholds.clsGood.toStringAsFixed(1)} for good performance.',
        value: cls,
        threshold: PerformanceThresholds.clsGood,
      ));
    }
    
    if (ttfb != null && ttfb > PerformanceThresholds.ttfbNeedsImprovementMs) {
      issues.add(PerformanceIssue(
        type: 'ttfb-slow',
        severity: 'error',
        message: 'Time to First Byte is too slow (${ttfb.round()}ms). Should be under ${PerformanceThresholds.ttfbGoodMs.round()}ms for good performance.',
        value: ttfb,
        threshold: PerformanceThresholds.ttfbGoodMs,
      ));
    } else if (ttfb != null && ttfb > PerformanceThresholds.ttfbGoodMs) {
      issues.add(PerformanceIssue(
        type: 'ttfb-slow',
        severity: 'warning',
        message: 'Time to First Byte needs improvement (${ttfb.round()}ms). Should be under ${PerformanceThresholds.ttfbGoodMs.round()}ms for good performance.',
        value: ttfb,
        threshold: PerformanceThresholds.ttfbGoodMs,
      ));
    }
    
    // Calculate performance score (0-100)
    final score = _calculatePerformanceScore(ttfb, fcp, lcp, cls, inp);
    
    // Calculate grade (A-F)
    final grade = _calculateGrade(score);
    
    return {
      'score': score,
      'grade': grade,
      'coreWebVitals': {
        'largestContentfulPaint': lcp?.round(),
        'firstContentfulPaint': fcp?.round(),
        'cumulativeLayoutShift': cls,
        'interactionToNextPaint': inp?.round(),
        'timeToFirstByte': ttfb?.round(),
      },
      'metrics': {
        'domContentLoaded': dcl?.round(),
        'loadComplete': loadEnd?.round(),
        'firstPaint': firstPaint?.round(),
        'redirectTime': redirectTime?.round(),
        'dnsTime': dnsTime?.round(),
        'connectTime': connectTime?.round(),
      },
      'issues': issues.map((issue) => issue.toJson()).toList(),
    };
  }
  
  /// Calculate overall performance score (0-100) based on Core Web Vitals
  int _calculatePerformanceScore(double? ttfb, double? fcp, double? lcp, double? cls, double? inp) {
    var score = 100;
    
    // LCP scoring (40% weight)
    if (lcp != null) {
      if (lcp > PerformanceThresholds.lcpNeedsImprovementMs) {
        score -= 40;
      } else if (lcp > PerformanceThresholds.lcpGoodMs) {
        score -= 20;
      }
    }
    
    // FCP scoring (30% weight)
    if (fcp != null) {
      if (fcp > PerformanceThresholds.fcpNeedsImprovementMs) {
        score -= 30;
      } else if (fcp > PerformanceThresholds.fcpGoodMs) {
        score -= 15;
      }
    }
    
    // CLS scoring (15% weight)
    if (cls != null) {
      if (cls > PerformanceThresholds.clsNeedsImprovement) {
        score -= 15;
      } else if (cls > PerformanceThresholds.clsGood) {
        score -= 8;
      }
    }
    
    // TTFB scoring (15% weight)
    if (ttfb != null) {
      if (ttfb > PerformanceThresholds.ttfbNeedsImprovementMs) {
        score -= 15;
      } else if (ttfb > PerformanceThresholds.ttfbGoodMs) {
        score -= 8;
      }
    }
    
    return (score < 0) ? 0 : score;
  }
  
  /// Calculate grade (A-F) from score
  String _calculateGrade(int score) {
    if (score >= 90) return 'A';
    if (score >= 80) return 'B';
    if (score >= 70) return 'C';
    if (score >= 60) return 'D';
    return 'F';
  }
}
