import 'dart:io';
import 'dart:convert';
import 'package:puppeteer/puppeteer.dart';
import 'package:logging/logging.dart';
import '../events.dart';
import 'audit_base.dart';

/// Enhanced Accessibility audit using axe-core with full WCAG 2.1 support
class A11yAxeAudit implements Audit {
  @override
  String get name => 'a11y_axe';

  final bool screenshots;
  final String axeSourceFile;
  final Logger _logger = Logger('A11yAxeAudit');
  
  A11yAxeAudit({required this.screenshots, required this.axeSourceFile});

  @override
  Future<void> run(AuditContext ctx) async {
    final page = ctx.page as Page;
    
    try {
      // Check if axe-core file exists
      final axeFile = File(axeSourceFile);
      if (!axeFile.existsSync()) {
        _logger.warning('axe-core file not found at $axeSourceFile');
        ctx.axeJson = {'error': 'axe-core file not found'};
        return;
      }
      
      final axeSource = await axeFile.readAsString();

      // Console Errors sammeln
      page.onConsole.listen((msg) {
        if (msg.type == ConsoleMessageType.error) {
          ctx.consoleErrors.add(msg.text ?? 'Console error without message');
        }
      });

      // Load axe-core
      await page.addScriptTag(content: axeSource);
      
      // Configure axe for comprehensive WCAG 2.1 testing
      await page.evaluate(r'''
        () => {
          // Configure axe for maximum coverage
          axe.configure({
            branding: {
              application: 'AuditMySite Studio'
            },
            reporter: 'v2',
            checks: [
              { id: 'color-contrast-enhanced', enabled: true },
              { id: 'link-in-text-block', enabled: true },
              { id: 'p-as-heading', enabled: true }
            ],
            rules: [
              { id: 'color-contrast', enabled: true },
              { id: 'color-contrast-enhanced', enabled: true },
              { id: 'focus-order-semantics', enabled: true },
              { id: 'hidden-content', enabled: true },
              { id: 'label-content-name-mismatch', enabled: true },
              { id: 'link-in-text-block', enabled: true },
              { id: 'no-autoplay-audio', enabled: true },
              { id: 'p-as-heading', enabled: true },
              { id: 'table-fake-caption', enabled: true },
              { id: 'td-has-header', enabled: true },
              { id: 'avoid-inline-spacing', enabled: true },
              { id: 'target-size', enabled: true }
            ]
          });
        }
      ''');

      // Run comprehensive axe tests with all WCAG levels
      final axeJsonStr = await page.evaluate(r'''
        async () => {
          try {
            // Run axe with all WCAG 2.1 standards
            const result = await axe.run(document, {
              runOnly: {
                type: 'tag',
                values: [
                  'wcag2a',
                  'wcag2aa', 
                  'wcag2aaa',
                  'wcag21a',
                  'wcag21aa',
                  'wcag22aa',
                  'section508',
                  'best-practice',
                  'ACT',
                  'EN-301-549'
                ]
              },
              resultTypes: ['violations', 'passes', 'incomplete', 'inapplicable'],
              elementRef: true,
              selectors: true,
              xpath: true,
              ancestry: true
            });
            
            // Add metadata and statistics
            result.timestamp = new Date().toISOString();
            result.userAgent = navigator.userAgent;
            result.windowDimensions = {
              width: window.innerWidth,
              height: window.innerHeight,
              devicePixelRatio: window.devicePixelRatio
            };
            
            // Calculate summary statistics
            const summary = {
              violationsByImpact: {
                critical: 0,
                serious: 0,
                moderate: 0,
                minor: 0
              },
              violationsByWCAG: {
                'wcag2a': [],
                'wcag2aa': [],
                'wcag2aaa': [],
                'wcag21a': [],
                'wcag21aa': []
              },
              totalViolations: 0,
              totalPasses: result.passes ? result.passes.length : 0,
              totalIncomplete: result.incomplete ? result.incomplete.length : 0,
              totalInapplicable: result.inapplicable ? result.inapplicable.length : 0,
              elementsWithViolations: 0
            };
            
            // Process violations for statistics
            if (result.violations) {
              result.violations.forEach(violation => {
                const nodeCount = violation.nodes ? violation.nodes.length : 0;
                summary.totalViolations++;
                summary.elementsWithViolations += nodeCount;
                
                // Count by impact
                if (violation.impact && summary.violationsByImpact[violation.impact] !== undefined) {
                  summary.violationsByImpact[violation.impact] += nodeCount;
                }
                
                // Group by WCAG level
                if (violation.tags) {
                  violation.tags.forEach(tag => {
                    if (summary.violationsByWCAG[tag]) {
                      summary.violationsByWCAG[tag].push({
                        id: violation.id,
                        description: violation.description,
                        help: violation.help,
                        helpUrl: violation.helpUrl,
                        impact: violation.impact,
                        nodeCount: nodeCount
                      });
                    }
                  });
                }
              });
            }
            
            result.summary = summary;
            
            // Calculate accessibility score (0-100)
            const totalTests = summary.totalViolations + summary.totalPasses;
            result.accessibilityScore = totalTests > 0 
              ? Math.round((summary.totalPasses / totalTests) * 100)
              : 100;
            
            // Determine WCAG compliance levels
            result.compliance = {
              wcag2aCompliant: summary.violationsByWCAG['wcag2a'].length === 0,
              wcag2aaCompliant: summary.violationsByWCAG['wcag2a'].length === 0 && 
                               summary.violationsByWCAG['wcag2aa'].length === 0,
              wcag21aaCompliant: summary.violationsByWCAG['wcag2a'].length === 0 && 
                                summary.violationsByWCAG['wcag2aa'].length === 0 &&
                                summary.violationsByWCAG['wcag21a'].length === 0 &&
                                summary.violationsByWCAG['wcag21aa'].length === 0
            };
            
            // Add custom checks
            result.customChecks = {
              // Check for skip links
              hasSkipLinks: document.querySelector('a[href^="#"]:first-child, [role="navigation"] a[href^="#"]') !== null,
              
              // Check for landmark roles
              hasLandmarks: document.querySelectorAll('[role="main"], [role="navigation"], [role="banner"], main, nav, header, footer').length > 0,
              
              // Check for ARIA live regions
              hasAriaLive: document.querySelectorAll('[aria-live]').length > 0,
              
              // Check for focus indicators (requires CSS analysis)
              focusableElements: document.querySelectorAll('a[href], button, input, select, textarea, [tabindex]:not([tabindex="-1"])').length,
              
              // Check for motion preferences
              prefersReducedMotion: window.matchMedia('(prefers-reduced-motion: reduce)').matches,
              
              // Check for color scheme preferences
              prefersColorScheme: window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light',
              
              // Check for high contrast mode
              prefersHighContrast: window.matchMedia('(prefers-contrast: high)').matches
            };
            
            return JSON.stringify(result);
          } catch (error) {
            return JSON.stringify({
              error: error.toString(),
              timestamp: new Date().toISOString()
            });
          }
        }''') as String;

      ctx.axeJson = (axeJsonStr.isNotEmpty)
          ? jsonDecode(axeJsonStr) as Map<String, dynamic>
          : {'error': 'Empty axe results'};

      // Take screenshots if enabled
      if (screenshots) {
        await _captureScreenshots(page, ctx);
        
        // Capture violation element screenshots if available
        if (ctx.axeJson != null && ctx.axeJson!['violations'] != null) {
          await _captureViolationScreenshots(page, ctx);
        }
      }
      
    } catch (e) {
      _logger.severe('Error running axe-core: $e');
      ctx.axeJson = {'error': e.toString()};
    }
  }
  
  Future<void> _captureScreenshots(Page page, AuditContext ctx) async {
    try {
      final safe = ctx.url.toString().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final out = 'artifacts/screenshots/$safe.png';
      await File(out).parent.create(recursive: true);
      final screenshotData = await page.screenshot(
        format: ScreenshotFormat.png, 
        fullPage: true
      );
      await File(out).writeAsBytes(screenshotData);
      ctx.screenshotPath = out;
    } catch (e) {
      _logger.warning('Failed to capture full page screenshot: $e');
    }
  }
  
  Future<void> _captureViolationScreenshots(Page page, AuditContext ctx) async {
    try {
      final violations = ctx.axeJson!['violations'] as List;
      final screenshotData = <Map<String, dynamic>>[];
      
      for (var i = 0; i < violations.length && i < 10; i++) {
        final violation = violations[i];
        if (violation['nodes'] != null) {
          final nodes = violation['nodes'] as List;
          if (nodes.isNotEmpty && nodes[0]['target'] != null) {
            try {
              final target = nodes[0]['target'][0];
              final element = await page.$(target);
              if (element != null) {
                final screenshot = await element.screenshot();
                screenshotData.add({
                  'violationId': violation['id'],
                  'selector': target,
                  'screenshot': base64Encode(screenshot),
                  'impact': violation['impact']
                });
              }
            } catch (e) {
              _logger.warning('Failed to capture violation screenshot: $e');
            }
          }
        }
      }
      
      if (screenshotData.isNotEmpty) {
        ctx.axeJson!['violationScreenshots'] = screenshotData;
      }
    } catch (e) {
      _logger.warning('Error capturing violation screenshots: $e');
    }
  }
}
