import 'package:puppeteer/puppeteer.dart';
import '../events.dart';
import 'audit_base.dart';

/// WCAG 2.1 Principle Analysis
class WCAG21Analysis {
  final Map<String, WCAGPrinciple> perceivable;
  final Map<String, WCAGPrinciple> operable;
  final Map<String, WCAGPrinciple> understandable;
  final Map<String, WCAGPrinciple> robust;
  final double totalScore;
  final String grade;

  WCAG21Analysis({
    required this.perceivable,
    required this.operable,
    required this.understandable,
    required this.robust,
    required this.totalScore,
    required this.grade,
  });

  Map<String, dynamic> toJson() => {
    'perceivable': perceivable.map((k, v) => MapEntry(k, v.toJson())),
    'operable': operable.map((k, v) => MapEntry(k, v.toJson())),
    'understandable': understandable.map((k, v) => MapEntry(k, v.toJson())),
    'robust': robust.map((k, v) => MapEntry(k, v.toJson())),
    'totalScore': totalScore,
    'grade': grade,
  };
}

class WCAGPrinciple {
  final int violations;
  final double score;
  final List<String> issues;

  WCAGPrinciple({
    required this.violations,
    required this.score,
    required this.issues,
  });

  Map<String, dynamic> toJson() => {
    'violations': violations,
    'score': score,
    'issues': issues,
  };
}

class WCAG21Audit extends Audit {
  @override
  String get name => 'wcag21';

  @override
  Future<void> run(AuditContext ctx) async {
    final page = ctx.page as Page;

    // Run comprehensive WCAG 2.1 analysis
    final wcagData = await page.evaluate(r'''
() => {
  const analysis = {
    perceivable: {
      colorContrast: { violations: 0, issues: [] },
      textAlternatives: { violations: 0, issues: [] },
      captions: { violations: 0, issues: [] },
      adaptable: { violations: 0, issues: [] }
    },
    operable: {
      keyboardAccessible: { violations: 0, issues: [] },
      seizures: { violations: 0, issues: [] },
      navigable: { violations: 0, issues: [] },
      inputModalities: { violations: 0, issues: [] }
    },
    understandable: {
      readable: { violations: 0, issues: [] },
      predictable: { violations: 0, issues: [] },
      inputAssistance: { violations: 0, issues: [] }
    },
    robust: {
      compatible: { violations: 0, issues: [] },
      parsing: { violations: 0, issues: [] }
    }
  };

  // 1. Perceivable Checks
  // 1.1 Text Alternatives
  const imagesWithoutAlt = document.querySelectorAll('img:not([alt])');
  if (imagesWithoutAlt.length > 0) {
    analysis.perceivable.textAlternatives.violations = imagesWithoutAlt.length;
    imagesWithoutAlt.forEach(img => {
      analysis.perceivable.textAlternatives.issues.push(
        `Image missing alt text: ${img.src || 'unknown source'}`
      );
    });
  }

  // Check for decorative images with empty alt
  const decorativeImages = document.querySelectorAll('img[alt=""]');
  
  // 1.2 Color Contrast (simplified check - real implementation would use axe-core)
  const textElements = document.querySelectorAll('p, span, div, h1, h2, h3, h4, h5, h6, a, button');
  let contrastIssues = 0;
  textElements.forEach(el => {
    const style = window.getComputedStyle(el);
    const fontSize = parseFloat(style.fontSize);
    const fontWeight = style.fontWeight;
    
    // Check if text is large (14pt bold or 18pt regular)
    const isLargeText = (fontSize >= 18) || (fontSize >= 14 && parseInt(fontWeight) >= 700);
    
    // This is a placeholder - real contrast checking requires color analysis
    // We'll flag potential issues for manual review
    if (fontSize < 12) {
      contrastIssues++;
      analysis.perceivable.colorContrast.issues.push(
        `Small text (${fontSize}px) may have contrast issues`
      );
    }
  });
  analysis.perceivable.colorContrast.violations = contrastIssues;

  // 1.3 Captions and Audio Descriptions
  const videos = document.querySelectorAll('video');
  const videosWithoutCaptions = Array.from(videos).filter(video => {
    const tracks = video.querySelectorAll('track[kind="captions"], track[kind="subtitles"]');
    return tracks.length === 0;
  });
  
  if (videosWithoutCaptions.length > 0) {
    analysis.perceivable.captions.violations = videosWithoutCaptions.length;
    videosWithoutCaptions.forEach(video => {
      analysis.perceivable.captions.issues.push('Video element missing captions track');
    });
  }

  // 1.4 Adaptable - Check for proper semantic HTML
  const tablesWithoutHeaders = document.querySelectorAll('table:not(:has(th))');
  if (tablesWithoutHeaders.length > 0) {
    analysis.perceivable.adaptable.violations += tablesWithoutHeaders.length;
    analysis.perceivable.adaptable.issues.push(
      `${tablesWithoutHeaders.length} tables without header cells`
    );
  }

  // 2. Operable Checks
  // 2.1 Keyboard Accessible
  const focusableElements = document.querySelectorAll(
    'a[href], button, input, select, textarea, [tabindex]:not([tabindex="-1"])'
  );
  
  let keyboardIssues = 0;
  focusableElements.forEach(el => {
    // Check for positive tabindex (bad practice)
    const tabindex = el.getAttribute('tabindex');
    if (tabindex && parseInt(tabindex) > 0) {
      keyboardIssues++;
      analysis.operable.keyboardAccessible.issues.push(
        `Element with positive tabindex (${tabindex}): ${el.tagName}`
      );
    }
    
    // Check for click handlers without keyboard support
    if (el.onclick && !el.onkeydown && !el.onkeypress && !el.onkeyup) {
      keyboardIssues++;
      analysis.operable.keyboardAccessible.issues.push(
        `Click handler without keyboard support: ${el.tagName}`
      );
    }
  });
  analysis.operable.keyboardAccessible.violations = keyboardIssues;

  // 2.2 Seizures - Check for rapid flashing (simplified)
  const animatedElements = document.querySelectorAll('[style*="animation"]');
  animatedElements.forEach(el => {
    const style = el.getAttribute('style') || '';
    if (style.includes('animation-duration') && style.includes('0.') && !style.includes('animation-duration: 0')) {
      const duration = parseFloat(style.match(/animation-duration:\s*([\d.]+)/)?.[1] || '1');
      if (duration < 0.333) { // Less than 333ms could cause seizures
        analysis.operable.seizures.violations++;
        analysis.operable.seizures.issues.push(
          `Rapid animation detected (${duration}s): ${el.tagName}`
        );
      }
    }
  });

  // 2.3 Navigable - Check for skip links and landmarks
  const skipLink = document.querySelector('a[href="#main"], a[href="#content"], [role="navigation"] a:first-child');
  if (!skipLink) {
    analysis.operable.navigable.violations++;
    analysis.operable.navigable.issues.push('No skip navigation link found');
  }

  const landmarks = document.querySelectorAll('[role="main"], [role="navigation"], [role="banner"], main, nav, header');
  if (landmarks.length === 0) {
    analysis.operable.navigable.violations++;
    analysis.operable.navigable.issues.push('No landmark regions found');
  }

  // 2.4 Input Modalities - Check for touch target size
  const touchTargets = document.querySelectorAll('a, button, input, select, textarea');
  let smallTargets = 0;
  touchTargets.forEach(el => {
    const rect = el.getBoundingClientRect();
    if (rect.width < 44 || rect.height < 44) {
      smallTargets++;
    }
  });
  
  if (smallTargets > 0) {
    analysis.operable.inputModalities.violations = smallTargets;
    analysis.operable.inputModalities.issues.push(
      `${smallTargets} touch targets smaller than 44x44 pixels`
    );
  }

  // 3. Understandable Checks
  // 3.1 Readable - Check language attributes
  const htmlLang = document.documentElement.getAttribute('lang');
  if (!htmlLang) {
    analysis.understandable.readable.violations++;
    analysis.understandable.readable.issues.push('Missing lang attribute on html element');
  }

  // Check for complex language
  const paragraphs = document.querySelectorAll('p');
  paragraphs.forEach(p => {
    const text = p.textContent || '';
    const sentences = text.split(/[.!?]+/).filter(s => s.trim().length > 0);
    sentences.forEach(sentence => {
      const words = sentence.split(/\s+/);
      if (words.length > 30) { // Very long sentences
        analysis.understandable.readable.violations++;
        analysis.understandable.readable.issues.push(
          `Very long sentence (${words.length} words)`
        );
      }
    });
  });

  // 3.2 Predictable - Check for consistent navigation
  const navElements = document.querySelectorAll('nav, [role="navigation"]');
  if (navElements.length > 1) {
    // Check if navigation items are consistent (simplified check)
    const navContents = Array.from(navElements).map(nav => nav.textContent?.trim());
    const uniqueNavs = new Set(navContents);
    if (uniqueNavs.size === navElements.length) {
      analysis.understandable.predictable.violations++;
      analysis.understandable.predictable.issues.push(
        'Multiple navigation regions with different content'
      );
    }
  }

  // 3.3 Input Assistance - Check form labels and error messages
  const inputs = document.querySelectorAll('input, select, textarea');
  let unlabeledInputs = 0;
  inputs.forEach(input => {
    const id = input.id;
    const label = id ? document.querySelector(`label[for="${id}"]`) : null;
    const ariaLabel = input.getAttribute('aria-label');
    const ariaLabelledby = input.getAttribute('aria-labelledby');
    
    if (!label && !ariaLabel && !ariaLabelledby && input.type !== 'hidden' && input.type !== 'submit') {
      unlabeledInputs++;
    }
  });
  
  if (unlabeledInputs > 0) {
    analysis.understandable.inputAssistance.violations = unlabeledInputs;
    analysis.understandable.inputAssistance.issues.push(
      `${unlabeledInputs} form inputs without labels`
    );
  }

  // 4. Robust Checks
  // 4.1 Compatible - Check for deprecated elements
  const deprecatedElements = document.querySelectorAll('center, font, marquee, blink, big, strike');
  if (deprecatedElements.length > 0) {
    analysis.robust.compatible.violations = deprecatedElements.length;
    analysis.robust.compatible.issues.push(
      `${deprecatedElements.length} deprecated HTML elements found`
    );
  }

  // 4.2 Parsing - Check for duplicate IDs
  const allIds = Array.from(document.querySelectorAll('[id]')).map(el => el.id);
  const duplicateIds = allIds.filter((id, index) => allIds.indexOf(id) !== index);
  const uniqueDuplicates = [...new Set(duplicateIds)];
  
  if (uniqueDuplicates.length > 0) {
    analysis.robust.parsing.violations = uniqueDuplicates.length;
    uniqueDuplicates.forEach(id => {
      analysis.robust.parsing.issues.push(`Duplicate ID found: ${id}`);
    });
  }

  return analysis;
}
    ''');

    // Calculate scores for each principle
    final analysis = _calculateWCAG21Scores(wcagData);
    
    // Store in context
    ctx.wcag21Analysis = analysis;
  }

  WCAG21Analysis _calculateWCAG21Scores(Map<String, dynamic> data) {
    final perceivable = _scorePrinciple(data['perceivable'] as Map<String, dynamic>);
    final operable = _scorePrinciple(data['operable'] as Map<String, dynamic>);
    final understandable = _scorePrinciple(data['understandable'] as Map<String, dynamic>);
    final robust = _scorePrinciple(data['robust'] as Map<String, dynamic>);

    // Calculate total score (average of all principles)
    final scores = [
      ...perceivable.values.map((p) => p.score),
      ...operable.values.map((p) => p.score),
      ...understandable.values.map((p) => p.score),
      ...robust.values.map((p) => p.score),
    ];
    
    final totalScore = scores.isEmpty ? 100.0 : 
      scores.reduce((a, b) => a + b) / scores.length;
    
    // Calculate grade
    final grade = _calculateGrade(totalScore);

    return WCAG21Analysis(
      perceivable: perceivable,
      operable: operable,
      understandable: understandable,
      robust: robust,
      totalScore: totalScore,
      grade: grade,
    );
  }

  Map<String, WCAGPrinciple> _scorePrinciple(Map<String, dynamic> principleData) {
    final result = <String, WCAGPrinciple>{};
    
    principleData.forEach((key, value) {
      final data = value as Map<String, dynamic>;
      final violations = data['violations'] as int? ?? 0;
      final issues = List<String>.from(data['issues'] ?? []);
      
      // Calculate score based on violations
      double score = 100.0;
      if (violations > 0) {
        score = (100 - (violations * 10)).clamp(0, 100).toDouble();
      }
      
      result[key] = WCAGPrinciple(
        violations: violations,
        score: score,
        issues: issues,
      );
    });
    
    return result;
  }

  String _calculateGrade(double score) {
    if (score >= 90) return 'A';
    if (score >= 80) return 'B';
    if (score >= 70) return 'C';
    if (score >= 60) return 'D';
    return 'F';
  }
}