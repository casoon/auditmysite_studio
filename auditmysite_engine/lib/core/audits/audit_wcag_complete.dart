import 'package:puppeteer/puppeteer.dart';
import 'package:logging/logging.dart';
import 'audit_base.dart';
import '../events.dart';
import 'audit_wcag22_a.dart';
import 'audit_wcag22_aa.dart';
import 'audit_wcag_advanced.dart';

/// Complete WCAG Audit Suite
/// Combines all WCAG 2.1, 2.2, and 3.0 audits for comprehensive compliance testing
class WCAGCompleteAudit implements Audit {
  @override
  String get name => 'wcag_complete';
  
  final Logger _logger = Logger('WCAGComplete');
  
  // Configuration options
  final bool includeLevel_A;
  final bool includeLevel_AA;
  final bool includeLevel_AAA;
  final bool includeWCAG30;
  final bool takeScreenshots;
  
  WCAGCompleteAudit({
    this.includeLevel_A = true,
    this.includeLevel_AA = true,
    this.includeLevel_AAA = false,
    this.includeWCAG30 = false,
    this.takeScreenshots = false,
  });
  
  @override
  Future<void> run(AuditContext ctx) async {
    final page = ctx.page as Page;
    
    _logger.info('Running Complete WCAG Audit Suite');
    _logger.info('  Level A: $includeLevel_A');
    _logger.info('  Level AA: $includeLevel_AA');
    _logger.info('  Level AAA: $includeLevel_AAA');
    _logger.info('  WCAG 3.0: $includeWCAG30');
    
    // Results storage
    final Map<String, dynamic> completeResults = {
      'timestamp': DateTime.now().toIso8601String(),
      'url': page.url,
      'levels': {},
      'summary': {},
      'violations': [],
      'warnings': [],
      'passes': [],
      'compliance': {},
    };
    
    // Run Level A audit
    if (includeLevel_A) {
      _logger.info('Executing WCAG 2.2 Level A audit...');
      final levelAAudit = WCAG22LevelAAudit();
      await levelAAudit.run(ctx);
      
      if (ctx.wcag22LevelA != null) {
        completeResults['levels']['A'] = ctx.wcag22LevelA;
        _mergeResults(completeResults, ctx.wcag22LevelA!, 'A');
      }
    }
    
    // Run Level AA audit
    if (includeLevel_AA) {
      _logger.info('Executing WCAG 2.2 Level AA audit...');
      final levelAAAudit = WCAG22LevelAAAudit();
      await levelAAAudit.run(ctx);
      
      if (ctx.wcag22LevelAA != null) {
        completeResults['levels']['AA'] = ctx.wcag22LevelAA;
        _mergeResults(completeResults, ctx.wcag22LevelAA!, 'AA');
      }
    }
    
    // Run Level AAA and WCAG 3.0 audits if requested
    if (includeLevel_AAA || includeWCAG30) {
      _logger.info('Executing Advanced WCAG audits (AAA + 3.0)...');
      final advancedAudit = WCAGAdvancedAudit();
      await advancedAudit.run(ctx);
      
      if (ctx.wcagAdvanced != null) {
        if (includeLevel_AAA) {
          completeResults['levels']['AAA'] = ctx.wcagAdvanced!['levelAAA'] ?? {};
        }
        if (includeWCAG30) {
          completeResults['levels']['WCAG30'] = ctx.wcagAdvanced!['wcag30'] ?? {};
        }
        _mergeAdvancedResults(completeResults, ctx.wcagAdvanced!);
      }
    }
    
    // Take screenshots of violations if requested
    if (takeScreenshots && completeResults['violations'].isNotEmpty) {
      await _captureViolationScreenshots(ctx, page, completeResults['violations']);
    }
    
    // Calculate overall compliance
    _calculateCompliance(completeResults);
    
    // Generate summary report
    _generateSummary(completeResults);
    
    // Store complete results
    ctx.wcagComplete = completeResults;
    
    // Log final summary
    _logSummary(completeResults);
  }
  
  void _mergeResults(Map<String, dynamic> target, Map<String, dynamic> source, String level) {
    // Merge violations
    if (source['violations'] != null) {
      for (var violation in source['violations']) {
        (target['violations'] as List).add({
          ...violation,
          'level': level,
        });
      }
    }
    
    // Merge warnings
    if (source['warnings'] != null) {
      for (var warning in source['warnings']) {
        (target['warnings'] as List).add({
          ...warning,
          'level': level,
        });
      }
    }
    
    // Merge passes
    if (source['passes'] != null) {
      for (var pass in source['passes']) {
        (target['passes'] as List).add({
          ...pass,
          'level': level,
        });
      }
    }
  }
  
  void _mergeAdvancedResults(Map<String, dynamic> target, Map<String, dynamic> advanced) {
    // Merge WCAG 2.2 new criteria
    if (advanced['wcag22'] != null) {
      target['levels']['WCAG22_New'] = advanced['wcag22'];
      
      // Add violations from new criteria
      advanced['wcag22'].forEach((criterion, result) {
        if (result is Map && result['passed'] == false) {
          (target['violations'] as List).add({
            'criterion': criterion,
            'description': 'WCAG 2.2 New Criterion',
            'level': _determineLevelForCriterion(criterion),
            'issues': result['issues'] ?? [],
          });
        }
      });
    }
    
    // Merge WCAG 3.0 results
    if (advanced['wcag30'] != null && includeWCAG30) {
      target['wcag30'] = advanced['wcag30'];
    }
  }
  
  String _determineLevelForCriterion(String criterion) {
    // WCAG 2.2 new criteria level mapping
    final levelMapping = {
      '2.4.11': 'AA',
      '2.4.12': 'AAA',
      '2.4.13': 'AA',
      '2.5.7': 'AA',
      '2.5.8': 'AA',
      '3.2.6': 'A',
      '3.3.7': 'A',
      '3.3.8': 'AA',
    };
    
    return levelMapping[criterion] ?? 'Unknown';
  }
  
  Future<void> _captureViolationScreenshots(
    AuditContext ctx,
    Page page,
    List violations,
  ) async {
    _logger.info('Capturing screenshots for ${violations.length} violations...');
    
    for (var i = 0; i < violations.length && i < 10; i++) {
      final violation = violations[i];
      
      try {
        // Try to highlight the violating element if possible
        if (violation['elements'] != null && violation['elements'].isNotEmpty) {
          await page.evaluate('''
            (selector) => {
              const element = document.querySelector(selector);
              if (element) {
                element.style.outline = '3px solid red';
                element.style.outlineOffset = '2px';
              }
            }
          ''', args: [violation['elements'][0].toString()]);
        }
        
        // Take screenshot
        final screenshot = await page.screenshot(
          format: ScreenshotFormat.png,
          fullPage: false,
        );
        
        violation['screenshot'] = screenshot;
        
      } catch (e) {
        _logger.warning('Failed to capture screenshot for violation: $e');
      }
    }
  }
  
  void _calculateCompliance(Map<String, dynamic> results) {
    final violations = results['violations'] as List;
    
    // Count violations by level
    int levelAViolations = 0;
    int levelAAViolations = 0;
    int levelAAAViolations = 0;
    
    for (var violation in violations) {
      switch (violation['level']) {
        case 'A':
          levelAViolations++;
          break;
        case 'AA':
          levelAAViolations++;
          break;
        case 'AAA':
          levelAAAViolations++;
          break;
      }
    }
    
    // Determine compliance levels
    results['compliance'] = {
      'wcag21_A': levelAViolations == 0,
      'wcag21_AA': levelAViolations == 0 && levelAAViolations == 0,
      'wcag21_AAA': levelAViolations == 0 && levelAAViolations == 0 && levelAAAViolations == 0,
      'wcag22_A': levelAViolations == 0,
      'wcag22_AA': levelAViolations == 0 && levelAAViolations == 0,
    };
    
    // Calculate compliance score (0-100)
    final totalChecks = (results['violations'] as List).length + 
                       (results['warnings'] as List).length + 
                       (results['passes'] as List).length;
    
    if (totalChecks > 0) {
      final passRate = (results['passes'] as List).length / totalChecks;
      results['compliance']['score'] = (passRate * 100).round();
    } else {
      results['compliance']['score'] = 0;
    }
  }
  
  void _generateSummary(Map<String, dynamic> results) {
    final violations = results['violations'] as List;
    final warnings = results['warnings'] as List;
    final passes = results['passes'] as List;
    
    // Group violations by criterion
    final violationsByCriterion = <String, List>{};
    for (var violation in violations) {
      final criterion = violation['criterion'] ?? 'Unknown';
      violationsByCriterion.putIfAbsent(criterion, () => []).add(violation);
    }
    
    // Create priority issues (most critical violations)
    final priorityIssues = violations
      .where((v) => v['level'] == 'A')
      .take(5)
      .toList();
    
    results['summary'] = {
      'totalViolations': violations.length,
      'totalWarnings': warnings.length,
      'totalPasses': passes.length,
      'violationsByLevel': {
        'A': violations.where((v) => v['level'] == 'A').length,
        'AA': violations.where((v) => v['level'] == 'AA').length,
        'AAA': violations.where((v) => v['level'] == 'AAA').length,
      },
      'violationsByCriterion': violationsByCriterion.map((k, v) => MapEntry(k, v.length)),
      'priorityIssues': priorityIssues,
      'complianceLevel': _determineComplianceLevel(results['compliance']),
      'recommendations': _generateRecommendations(violationsByCriterion),
    };
  }
  
  String _determineComplianceLevel(Map<String, dynamic> compliance) {
    if (compliance['wcag22_AA'] == true) {
      return 'WCAG 2.2 Level AA Compliant';
    } else if (compliance['wcag22_A'] == true) {
      return 'WCAG 2.2 Level A Compliant';
    } else if (compliance['wcag21_AA'] == true) {
      return 'WCAG 2.1 Level AA Compliant';
    } else if (compliance['wcag21_A'] == true) {
      return 'WCAG 2.1 Level A Compliant';
    } else {
      return 'Non-Compliant';
    }
  }
  
  List<String> _generateRecommendations(Map<String, List> violationsByCriterion) {
    final recommendations = <String>[];
    
    // Check for common issues and provide recommendations
    if (violationsByCriterion.containsKey('1.1.1')) {
      recommendations.add('Add alt text to all informative images');
    }
    
    if (violationsByCriterion.containsKey('1.3.1')) {
      recommendations.add('Ensure all form inputs have associated labels');
    }
    
    if (violationsByCriterion.containsKey('1.4.3')) {
      recommendations.add('Improve color contrast ratios for text elements');
    }
    
    if (violationsByCriterion.containsKey('2.1.1')) {
      recommendations.add('Ensure all interactive elements are keyboard accessible');
    }
    
    if (violationsByCriterion.containsKey('2.4.1')) {
      recommendations.add('Implement skip navigation links or landmarks');
    }
    
    if (violationsByCriterion.containsKey('2.4.4')) {
      recommendations.add('Make link text more descriptive');
    }
    
    if (violationsByCriterion.containsKey('3.1.1')) {
      recommendations.add('Specify the page language in the HTML element');
    }
    
    if (violationsByCriterion.containsKey('4.1.2')) {
      recommendations.add('Ensure custom controls have proper ARIA attributes');
    }
    
    // Add priority recommendation based on most common issues
    if (recommendations.isEmpty && violationsByCriterion.isNotEmpty) {
      final mostCommon = violationsByCriterion.entries
        .reduce((a, b) => a.value.length > b.value.length ? a : b);
      recommendations.add('Priority: Fix ${mostCommon.key} violations (${mostCommon.value.length} issues)');
    }
    
    return recommendations;
  }
  
  void _logSummary(Map<String, dynamic> results) {
    final summary = results['summary'];
    
    _logger.info('');
    _logger.info('============================================');
    _logger.info('WCAG Complete Audit Summary');
    _logger.info('============================================');
    _logger.info('Compliance Level: ${summary['complianceLevel']}');
    _logger.info('Compliance Score: ${results['compliance']['score']}%');
    _logger.info('');
    _logger.info('Results:');
    _logger.info('  ✗ Violations: ${summary['totalViolations']}');
    _logger.info('    - Level A: ${summary['violationsByLevel']['A']}');
    _logger.info('    - Level AA: ${summary['violationsByLevel']['AA']}');
    _logger.info('    - Level AAA: ${summary['violationsByLevel']['AAA']}');
    _logger.info('  ⚠ Warnings: ${summary['totalWarnings']}');
    _logger.info('  ✓ Passes: ${summary['totalPasses']}');
    _logger.info('');
    
    if (summary['priorityIssues'].isNotEmpty) {
      _logger.info('Priority Issues:');
      for (var issue in summary['priorityIssues']) {
        _logger.info('  - ${issue['criterion']}: ${issue['description']}');
      }
      _logger.info('');
    }
    
    if (summary['recommendations'].isNotEmpty) {
      _logger.info('Recommendations:');
      for (var rec in summary['recommendations']) {
        _logger.info('  • $rec');
      }
    }
    
    _logger.info('============================================');
  }
}

// Extension for AuditContext to store complete WCAG results
extension WCAGCompleteContext on AuditContext {
  static final _wcagComplete = Expando<Map<String, dynamic>>();
  
  Map<String, dynamic>? get wcagComplete => _wcagComplete[this];
  set wcagComplete(Map<String, dynamic>? value) => _wcagComplete[this] = value;
}