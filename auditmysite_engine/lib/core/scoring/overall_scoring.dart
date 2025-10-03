import 'dart:math' as math;
import '../audits/audit_base.dart';

/// Overall Scoring System - combines all audit results
class OverallScoring {
  // Weight distribution (must sum to 100)
  static const Map<String, double> categoryWeights = {
    'performance': 30.0,
    'accessibility': 25.0,
    'seo': 20.0,
    'bestPractices': 15.0,
    'pwa': 10.0,
  };
  
  // Individual audit weights within categories
  static const Map<String, Map<String, double>> auditWeights = {
    'performance': {
      'coreWebVitals': 0.40,
      'resourceOptimization': 0.25,
      'networkPerformance': 0.20,
      'renderBlocking': 0.15,
    },
    'accessibility': {
      'wcagCompliance': 0.50,
      'ariaValidation': 0.20,
      'colorContrast': 0.15,
      'keyboardNavigation': 0.15,
    },
    'seo': {
      'metaTags': 0.25,
      'structuredData': 0.20,
      'crawlability': 0.20,
      'contentOptimization': 0.20,
      'technicalSEO': 0.15,
    },
    'bestPractices': {
      'security': 0.35,
      'modernWeb': 0.25,
      'errorHandling': 0.20,
      'performance': 0.20,
    },
    'pwa': {
      'installability': 0.35,
      'offlineCapability': 0.25,
      'engagement': 0.20,
      'capabilities': 0.20,
    },
  };
  
  /// Calculate the overall score from all audit results
  static Map<String, dynamic> calculateOverallScore(AuditContext ctx) {
    final scores = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'categories': {},
      'overall': 0,
      'grade': 'F',
      'passed': false,
      'details': {},
      'summary': {},
    };
    
    // Calculate Performance Score
    scores['categories']['performance'] = _calculatePerformanceScore(ctx);
    
    // Calculate Accessibility Score
    scores['categories']['accessibility'] = _calculateAccessibilityScore(ctx);
    
    // Calculate SEO Score
    scores['categories']['seo'] = _calculateSEOScore(ctx);
    
    // Calculate Best Practices Score
    scores['categories']['bestPractices'] = _calculateBestPracticesScore(ctx);
    
    // Calculate PWA Score
    scores['categories']['pwa'] = _calculatePWAScore(ctx);
    
    // Calculate weighted overall score
    double overallScore = 0;
    categoryWeights.forEach((category, weight) {
      final categoryScore = scores['categories'][category]['score'] ?? 0;
      overallScore += (categoryScore * weight / 100);
    });
    
    scores['overall'] = overallScore.round();
    scores['grade'] = _getGrade(scores['overall']);
    scores['passed'] = scores['overall'] >= 70;
    
    // Generate summary
    scores['summary'] = _generateSummary(scores);
    
    // Add detailed metrics
    scores['details'] = _collectDetailedMetrics(ctx);
    
    // Add recommendations
    scores['recommendations'] = _generateOverallRecommendations(scores, ctx);
    
    // Add comparative benchmarks
    scores['benchmarks'] = _getBenchmarks(scores['overall']);
    
    return scores;
  }
  
  static Map<String, dynamic> _calculatePerformanceScore(AuditContext ctx) {
    final performance = <String, dynamic>{
      'score': 0,
      'metrics': {},
      'issues': [],
      'grade': 'F',
    };
    
    double totalScore = 0;
    double totalWeight = 0;
    
    // Core Web Vitals (40%)
    if (ctx.performanceMetrics != null) {
      final metrics = ctx.performanceMetrics!;
      
      // LCP Score
      final lcp = metrics['largestContentfulPaint'] ?? 0;
      final lcpScore = _getMetricScore(lcp, 2500, 4000); // Good < 2.5s, Poor > 4s
      
      // FID/TBT Score (using Time to Interactive as proxy)
      final tti = metrics['timeToInteractive'] ?? 0;
      final fidScore = _getMetricScore(tti, 3800, 7300); // Good < 3.8s, Poor > 7.3s
      
      // CLS Score
      final cls = metrics['cumulativeLayoutShift'] ?? 0.0;
      final clsScore = _getMetricScore(cls * 1000, 100, 250); // Good < 0.1, Poor > 0.25
      
      // FCP Score
      final fcp = metrics['firstContentfulPaint'] ?? 0;
      final fcpScore = _getMetricScore(fcp, 1800, 3000); // Good < 1.8s, Poor > 3s
      
      // TTFB Score
      final ttfb = metrics['timeToFirstByte'] ?? 0;
      final ttfbScore = _getMetricScore(ttfb, 800, 1800); // Good < 0.8s, Poor > 1.8s
      
      // Speed Index
      final si = metrics['speedIndex'] ?? 0;
      final siScore = _getMetricScore(si, 3400, 5800); // Good < 3.4s, Poor > 5.8s
      
      // Weighted average
      final coreWebVitalsScore = (
        lcpScore * 0.25 +
        fidScore * 0.25 +
        clsScore * 0.25 +
        fcpScore * 0.15 +
        ttfbScore * 0.05 +
        siScore * 0.05
      );
      
      performance['metrics']['coreWebVitals'] = {
        'lcp': {'value': lcp, 'score': lcpScore},
        'fid': {'value': tti, 'score': fidScore},
        'cls': {'value': cls, 'score': clsScore},
        'fcp': {'value': fcp, 'score': fcpScore},
        'ttfb': {'value': ttfb, 'score': ttfbScore},
        'si': {'value': si, 'score': siScore},
        'overall': coreWebVitalsScore,
      };
      
      totalScore += coreWebVitalsScore * auditWeights['performance']!['coreWebVitals']!;
      totalWeight += auditWeights['performance']!['coreWebVitals']!;
    }
    
    // Resource Optimization (25%)
    if (ctx.resourcesExtended != null) {
      final resources = ctx.resourcesExtended!;
      final resourceScore = resources['score'] ?? 50;
      
      performance['metrics']['resources'] = {
        'score': resourceScore,
        'totalSize': resources['javascript']['totalSize'] ?? 0,
        'unusedCSS': resources['unused']['css']['unusedPercentage'] ?? 0,
        'unusedJS': resources['unused']['javascript']['unusedPercentage'] ?? 0,
      };
      
      totalScore += resourceScore * auditWeights['performance']!['resourceOptimization']!;
      totalWeight += auditWeights['performance']!['resourceOptimization']!;
      
      // Add resource issues
      if (resources['issues'] != null) {
        performance['issues'].addAll(resources['issues']);
      }
    }
    
    // Network Performance (20%)
    if (ctx.networkMetrics != null) {
      final network = ctx.networkMetrics!;
      int networkScore = 100;
      
      // Penalize for slow requests
      if (network['slowRequests'] > 5) networkScore -= 20;
      if (network['failedRequests'] > 0) networkScore -= 30;
      if (network['totalTransferred'] > 5000000) networkScore -= 20; // > 5MB
      
      performance['metrics']['network'] = {
        'score': networkScore,
        'requests': network['totalRequests'],
        'transferred': network['totalTransferred'],
        'failed': network['failedRequests'],
      };
      
      totalScore += networkScore * auditWeights['performance']!['networkPerformance']!;
      totalWeight += auditWeights['performance']!['networkPerformance']!;
    }
    
    // Render Blocking (15%)
    if (ctx.resourcesExtended != null) {
      final critical = ctx.resourcesExtended!['critical'] ?? {};
      final renderBlocking = critical['renderBlocking'] ?? [];
      
      int renderScore = 100;
      renderScore -= math.min(renderBlocking.length * 10, 50);
      
      performance['metrics']['renderBlocking'] = {
        'score': renderScore,
        'count': renderBlocking.length,
      };
      
      totalScore += renderScore * auditWeights['performance']!['renderBlocking']!;
      totalWeight += auditWeights['performance']!['renderBlocking']!;
    }
    
    // Calculate final score
    if (totalWeight > 0) {
      performance['score'] = (totalScore / totalWeight).round();
    }
    
    performance['grade'] = _getGrade(performance['score']);
    
    return performance;
  }
  
  static Map<String, dynamic> _calculateAccessibilityScore(AuditContext ctx) {
    final accessibility = <String, dynamic>{
      'score': 0,
      'metrics': {},
      'issues': [],
      'grade': 'F',
    };
    
    double totalScore = 0;
    double totalWeight = 0;
    
    // WCAG Compliance (50%)
    if (ctx.accessibilityAxe != null) {
      final axe = ctx.accessibilityAxe!;
      final violations = axe['violations'] ?? [];
      final passes = axe['passes'] ?? [];
      
      // Calculate score based on violations and passes
      int wcagScore = 100;
      
      // Count critical violations
      int critical = 0;
      int serious = 0;
      int moderate = 0;
      int minor = 0;
      
      for (final violation in violations) {
        switch (violation['impact']) {
          case 'critical':
            critical++;
            break;
          case 'serious':
            serious++;
            break;
          case 'moderate':
            moderate++;
            break;
          case 'minor':
            minor++;
            break;
        }
      }
      
      // Deduct points based on violation severity
      wcagScore -= critical * 20;
      wcagScore -= serious * 10;
      wcagScore -= moderate * 5;
      wcagScore -= minor * 2;
      
      wcagScore = math.max(0, wcagScore);
      
      accessibility['metrics']['wcag'] = {
        'score': wcagScore,
        'violations': {
          'critical': critical,
          'serious': serious,
          'moderate': moderate,
          'minor': minor,
          'total': violations.length,
        },
        'passes': passes.length,
      };
      
      totalScore += wcagScore * auditWeights['accessibility']!['wcagCompliance']!;
      totalWeight += auditWeights['accessibility']!['wcagCompliance']!;
      
      // Add issues
      accessibility['issues'].addAll(
        violations.map((v) => {
          'type': v['id'],
          'impact': v['impact'],
          'help': v['help'],
        })
      );
    }
    
    // ARIA Validation (20%)
    if (ctx.accessibilityAxe != null) {
      final axe = ctx.accessibilityAxe!;
      int ariaScore = 100;
      
      // Check for ARIA-related violations
      final violations = axe['violations'] ?? [];
      final ariaViolations = violations.where((v) => 
        v['id'].toString().contains('aria') ||
        v['tags'].toString().contains('aria')
      ).length;
      
      ariaScore -= ariaViolations * 15;
      ariaScore = math.max(0, ariaScore);
      
      accessibility['metrics']['aria'] = {
        'score': ariaScore,
        'violations': ariaViolations,
      };
      
      totalScore += ariaScore * auditWeights['accessibility']!['ariaValidation']!;
      totalWeight += auditWeights['accessibility']!['ariaValidation']!;
    }
    
    // Color Contrast (15%)
    if (ctx.accessibilityAxe != null) {
      final axe = ctx.accessibilityAxe!;
      int contrastScore = 100;
      
      // Check for color contrast violations
      final violations = axe['violations'] ?? [];
      final contrastViolations = violations.where((v) => 
        v['id'].toString().contains('color-contrast')
      ).length;
      
      contrastScore -= contrastViolations * 20;
      contrastScore = math.max(0, contrastScore);
      
      accessibility['metrics']['colorContrast'] = {
        'score': contrastScore,
        'violations': contrastViolations,
      };
      
      totalScore += contrastScore * auditWeights['accessibility']!['colorContrast']!;
      totalWeight += auditWeights['accessibility']!['colorContrast']!;
    }
    
    // Keyboard Navigation (15%)
    if (ctx.accessibilityAxe != null) {
      final axe = ctx.accessibilityAxe!;
      int keyboardScore = 100;
      
      // Check for keyboard-related violations
      final violations = axe['violations'] ?? [];
      final keyboardViolations = violations.where((v) => 
        v['tags'].toString().contains('keyboard') ||
        v['id'].toString().contains('focus') ||
        v['id'].toString().contains('tabindex')
      ).length;
      
      keyboardScore -= keyboardViolations * 15;
      keyboardScore = math.max(0, keyboardScore);
      
      accessibility['metrics']['keyboard'] = {
        'score': keyboardScore,
        'violations': keyboardViolations,
      };
      
      totalScore += keyboardScore * auditWeights['accessibility']!['keyboardNavigation']!;
      totalWeight += auditWeights['accessibility']!['keyboardNavigation']!;
    }
    
    // Calculate final score
    if (totalWeight > 0) {
      accessibility['score'] = (totalScore / totalWeight).round();
    }
    
    accessibility['grade'] = _getGrade(accessibility['score']);
    
    return accessibility;
  }
  
  static Map<String, dynamic> _calculateSEOScore(AuditContext ctx) {
    final seo = <String, dynamic>{
      'score': 0,
      'metrics': {},
      'issues': [],
      'grade': 'F',
    };
    
    // Use the SEO analysis results if available
    if (ctx.seoAnalysis != null) {
      final seoData = ctx.seoAnalysis!;
      seo['score'] = seoData['score'] ?? 0;
      seo['metrics'] = seoData['summary'] ?? {};
      
      if (seoData['issues'] != null) {
        seo['issues'] = seoData['issues'];
      }
    } else {
      // Fallback calculation
      seo['score'] = 50; // Default middle score if no data
    }
    
    seo['grade'] = _getGrade(seo['score']);
    
    return seo;
  }
  
  static Map<String, dynamic> _calculateBestPracticesScore(AuditContext ctx) {
    final bestPractices = <String, dynamic>{
      'score': 0,
      'metrics': {},
      'issues': [],
      'grade': 'F',
    };
    
    double totalScore = 0;
    double totalWeight = 0;
    
    // Security (35%)
    if (ctx.securityHeaders != null) {
      final security = ctx.securityHeaders!;
      final securityScore = security['score'] ?? 0;
      
      bestPractices['metrics']['security'] = {
        'score': securityScore,
        'grade': security['grade'],
        'vulnerabilities': security['vulnerabilities']?.length ?? 0,
      };
      
      totalScore += securityScore * auditWeights['bestPractices']!['security']!;
      totalWeight += auditWeights['bestPractices']!['security']!;
      
      // Add security issues
      if (security['vulnerabilities'] != null) {
        bestPractices['issues'].addAll(
          (security['vulnerabilities'] as List).map((v) => {
            'type': 'security',
            'severity': v['severity'],
            'description': v['description'],
          })
        );
      }
    }
    
    // Modern Web (25%)
    int modernWebScore = 100;
    
    // Check for deprecated features
    if (ctx.jsErrors != null) {
      final deprecations = ctx.jsErrors!['deprecationWarnings'] ?? [];
      modernWebScore -= deprecations.length * 10;
    }
    
    // Check for modern protocols
    if (ctx.securityHeaders != null) {
      if (ctx.securityHeaders!['https'] == true) {
        modernWebScore += 0; // Already at 100
      } else {
        modernWebScore -= 30;
      }
    }
    
    modernWebScore = math.max(0, math.min(100, modernWebScore));
    
    bestPractices['metrics']['modernWeb'] = {
      'score': modernWebScore,
    };
    
    totalScore += modernWebScore * auditWeights['bestPractices']!['modernWeb']!;
    totalWeight += auditWeights['bestPractices']!['modernWeb']!;
    
    // Error Handling (20%)
    if (ctx.jsErrors != null) {
      final errors = ctx.jsErrors!;
      int errorScore = 100;
      
      final errorCount = errors['errors']?.length ?? 0;
      errorScore -= math.min(errorCount * 10, 50);
      
      bestPractices['metrics']['errorHandling'] = {
        'score': errorScore,
        'errors': errorCount,
        'warnings': errors['warnings']?.length ?? 0,
      };
      
      totalScore += errorScore * auditWeights['bestPractices']!['errorHandling']!;
      totalWeight += auditWeights['bestPractices']!['errorHandling']!;
    }
    
    // Performance best practices (20%)
    int perfBestPractices = 100;
    
    // Check for performance anti-patterns
    if (ctx.resourcesExtended != null) {
      final resources = ctx.resourcesExtended!;
      
      // Check for duplicate resources
      if (resources['duplicates']['hasDuplicates'] == true) {
        perfBestPractices -= 20;
      }
      
      // Check for missing compression
      if (resources['compression']['uncompressedResources'].length > 5) {
        perfBestPractices -= 15;
      }
      
      // Check for missing caching
      if (resources['caching']['uncachedResources'].length > 10) {
        perfBestPractices -= 15;
      }
    }
    
    perfBestPractices = math.max(0, perfBestPractices);
    
    bestPractices['metrics']['performance'] = {
      'score': perfBestPractices,
    };
    
    totalScore += perfBestPractices * auditWeights['bestPractices']!['performance']!;
    totalWeight += auditWeights['bestPractices']!['performance']!;
    
    // Calculate final score
    if (totalWeight > 0) {
      bestPractices['score'] = (totalScore / totalWeight).round();
    }
    
    bestPractices['grade'] = _getGrade(bestPractices['score']);
    
    return bestPractices;
  }
  
  static Map<String, dynamic> _calculatePWAScore(AuditContext ctx) {
    final pwa = <String, dynamic>{
      'score': 0,
      'metrics': {},
      'issues': [],
      'grade': 'F',
      'isPWA': false,
    };
    
    // Use the PWA analysis results if available
    if (ctx.pwa != null) {
      final pwaData = ctx.pwa!;
      pwa['score'] = pwaData['score'] ?? 0;
      pwa['isPWA'] = pwaData['isPWA'] ?? false;
      pwa['metrics'] = pwaData['summary'] ?? {};
      
      if (pwaData['issues'] != null) {
        pwa['issues'] = pwaData['issues'];
      }
    } else {
      // Fallback: basic PWA check
      pwa['score'] = 0; // No PWA features without analysis
    }
    
    pwa['grade'] = _getGrade(pwa['score']);
    
    return pwa;
  }
  
  /// Calculate score based on metric thresholds
  static double _getMetricScore(num value, num goodThreshold, num poorThreshold) {
    if (value <= goodThreshold) {
      return 100;
    } else if (value >= poorThreshold) {
      return 0;
    } else {
      // Linear interpolation between good and poor
      final ratio = (value - goodThreshold) / (poorThreshold - goodThreshold);
      return 100 * (1 - ratio);
    }
  }
  
  /// Get letter grade from numeric score
  static String _getGrade(int score) {
    if (score >= 90) return 'A';
    if (score >= 80) return 'B';
    if (score >= 70) return 'C';
    if (score >= 60) return 'D';
    return 'F';
  }
  
  /// Generate overall summary
  static Map<String, dynamic> _generateSummary(Map<String, dynamic> scores) {
    return {
      'strengths': _identifyStrengths(scores),
      'weaknesses': _identifyWeaknesses(scores),
      'criticalIssues': _identifyCriticalIssues(scores),
      'quickWins': _identifyQuickWins(scores),
    };
  }
  
  static List<String> _identifyStrengths(Map<String, dynamic> scores) {
    final strengths = <String>[];
    
    scores['categories'].forEach((category, data) {
      if (data['score'] >= 90) {
        strengths.add('Excellent $category (${data['score']}/100)');
      } else if (data['score'] >= 80) {
        strengths.add('Good $category (${data['score']}/100)');
      }
    });
    
    return strengths;
  }
  
  static List<String> _identifyWeaknesses(Map<String, dynamic> scores) {
    final weaknesses = <String>[];
    
    scores['categories'].forEach((category, data) {
      if (data['score'] < 60) {
        weaknesses.add('Poor $category (${data['score']}/100)');
      } else if (data['score'] < 70) {
        weaknesses.add('Below average $category (${data['score']}/100)');
      }
    });
    
    return weaknesses;
  }
  
  static List<Map<String, dynamic>> _identifyCriticalIssues(Map<String, dynamic> scores) {
    final criticalIssues = <Map<String, dynamic>>[];
    
    scores['categories'].forEach((category, data) {
      if (data['issues'] != null) {
        for (final issue in data['issues']) {
          if (issue['severity'] == 'critical' || issue['impact'] == 'critical') {
            criticalIssues.add({
              'category': category,
              ...issue,
            });
          }
        }
      }
    });
    
    // Sort by category weight
    criticalIssues.sort((a, b) {
      final weightA = categoryWeights[a['category']] ?? 0;
      final weightB = categoryWeights[b['category']] ?? 0;
      return weightB.compareTo(weightA);
    });
    
    return criticalIssues.take(10).toList(); // Top 10 critical issues
  }
  
  static List<Map<String, dynamic>> _identifyQuickWins(Map<String, dynamic> scores) {
    final quickWins = <Map<String, dynamic>>[];
    
    // Performance quick wins
    if (scores['categories']['performance']['score'] < 80) {
      quickWins.add({
        'category': 'performance',
        'action': 'Enable text compression',
        'impact': 'Can reduce transfer size by 60-80%',
        'effort': 'low',
      });
      
      quickWins.add({
        'category': 'performance',
        'action': 'Optimize images',
        'impact': 'Can reduce image sizes by 30-50%',
        'effort': 'medium',
      });
    }
    
    // Accessibility quick wins
    if (scores['categories']['accessibility']['score'] < 80) {
      quickWins.add({
        'category': 'accessibility',
        'action': 'Add missing alt text to images',
        'impact': 'Improves screen reader experience',
        'effort': 'low',
      });
    }
    
    // SEO quick wins
    if (scores['categories']['seo']['score'] < 80) {
      quickWins.add({
        'category': 'seo',
        'action': 'Add meta descriptions',
        'impact': 'Improves click-through rates',
        'effort': 'low',
      });
    }
    
    // Security quick wins
    if (scores['categories']['bestPractices']['metrics']['security']['score'] < 80) {
      quickWins.add({
        'category': 'security',
        'action': 'Add security headers',
        'impact': 'Protects against common attacks',
        'effort': 'low',
      });
    }
    
    return quickWins;
  }
  
  /// Collect detailed metrics from all audits
  static Map<String, dynamic> _collectDetailedMetrics(AuditContext ctx) {
    return {
      'performance': {
        'metrics': ctx.performanceMetrics,
        'resources': ctx.resourcesExtended?['summary'],
        'network': ctx.networkMetrics,
      },
      'accessibility': {
        'axe': ctx.accessibilityAxe?['summary'],
        'violations': ctx.accessibilityAxe?['violations']?.length,
      },
      'seo': {
        'meta': ctx.seoAnalysis?['meta'],
        'structured': ctx.seoAnalysis?['structuredData'],
      },
      'security': {
        'headers': ctx.securityHeaders?['summary'],
        'https': ctx.securityHeaders?['https'],
      },
      'pwa': {
        'manifest': ctx.pwa?['manifest']['found'],
        'serviceWorker': ctx.pwa?['serviceWorker']['registered'],
        'offline': ctx.pwa?['offline']['hasOfflinePage'],
      },
      'mobile': {
        'viewport': ctx.mobileResult?['viewport'],
        'touchTargets': ctx.mobileResult?['touchTargets'],
      },
    };
  }
  
  /// Generate overall recommendations based on scores
  static List<Map<String, dynamic>> _generateOverallRecommendations(
    Map<String, dynamic> scores,
    AuditContext ctx,
  ) {
    final recommendations = <Map<String, dynamic>>[];
    
    // Sort categories by score (worst first)
    final sortedCategories = scores['categories'].entries.toList()
      ..sort((a, b) => a.value['score'].compareTo(b.value['score']));
    
    for (final entry in sortedCategories.take(3)) { // Focus on worst 3
      final category = entry.key;
      final score = entry.value['score'];
      
      if (score < 70) {
        recommendations.add({
          'category': category,
          'priority': score < 50 ? 'critical' : 'high',
          'currentScore': score,
          'targetScore': 80,
          'estimatedImpact': ((80 - score) * categoryWeights[category]! / 100).round(),
          'focus': _getCategoryFocusAreas(category, entry.value),
        });
      }
    }
    
    return recommendations;
  }
  
  static List<String> _getCategoryFocusAreas(String category, Map<String, dynamic> data) {
    switch (category) {
      case 'performance':
        return [
          'Optimize Core Web Vitals (LCP, FID, CLS)',
          'Reduce JavaScript execution time',
          'Minimize main thread work',
          'Optimize resource loading',
        ];
      case 'accessibility':
        return [
          'Fix WCAG 2.1 violations',
          'Improve keyboard navigation',
          'Ensure proper ARIA labels',
          'Fix color contrast issues',
        ];
      case 'seo':
        return [
          'Optimize meta tags',
          'Implement structured data',
          'Improve content quality',
          'Fix crawlability issues',
        ];
      case 'bestPractices':
        return [
          'Implement security headers',
          'Fix JavaScript errors',
          'Remove deprecated APIs',
          'Implement caching strategy',
        ];
      case 'pwa':
        return [
          'Add web app manifest',
          'Register service worker',
          'Implement offline support',
          'Make app installable',
        ];
      default:
        return [];
    }
  }
  
  /// Get industry benchmarks for comparison
  static Map<String, dynamic> _getBenchmarks(int overallScore) {
    return {
      'score': overallScore,
      'percentile': _getPercentile(overallScore),
      'industryAverage': 65,
      'topPerformers': 90,
      'comparison': overallScore >= 90 
          ? 'Top performer'
          : overallScore >= 75
              ? 'Above average'
              : overallScore >= 60
                  ? 'Average'
                  : 'Below average',
    };
  }
  
  static int _getPercentile(int score) {
    // Simplified percentile calculation based on typical distributions
    if (score >= 95) return 95;
    if (score >= 90) return 90;
    if (score >= 85) return 80;
    if (score >= 80) return 70;
    if (score >= 75) return 60;
    if (score >= 70) return 50;
    if (score >= 65) return 40;
    if (score >= 60) return 30;
    if (score >= 55) return 20;
    if (score >= 50) return 15;
    return 10;
  }
}