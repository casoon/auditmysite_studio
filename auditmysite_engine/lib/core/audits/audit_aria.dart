import 'package:puppeteer/puppeteer.dart';
import '../events.dart';
import 'audit_base.dart';

/// ARIA Analysis Result
class ARIAAnalysis {
  final int totalViolations;
  final ARIALandmarks landmarks;
  final ARIARoles roles;
  final ARIAProperties properties;
  final ARIALiveRegions liveRegions;
  final double score;
  final String grade;

  ARIAAnalysis({
    required this.totalViolations,
    required this.landmarks,
    required this.roles,
    required this.properties,
    required this.liveRegions,
    required this.score,
    required this.grade,
  });

  Map<String, dynamic> toJson() => {
    'totalViolations': totalViolations,
    'landmarks': landmarks.toJson(),
    'roles': roles.toJson(),
    'properties': properties.toJson(),
    'liveRegions': liveRegions.toJson(),
    'score': score,
    'grade': grade,
  };
}

class ARIALandmarks {
  final List<String> present;
  final List<String> missing;
  final double score;

  ARIALandmarks({
    required this.present,
    required this.missing,
    required this.score,
  });

  Map<String, dynamic> toJson() => {
    'present': present,
    'missing': missing,
    'score': score,
  };
}

class ARIARoles {
  final int correct;
  final int incorrect;
  final int missing;
  final double score;
  final List<String> issues;

  ARIARoles({
    required this.correct,
    required this.incorrect,
    required this.missing,
    required this.score,
    required this.issues,
  });

  Map<String, dynamic> toJson() => {
    'correct': correct,
    'incorrect': incorrect,
    'missing': missing,
    'score': score,
    'issues': issues,
  };
}

class ARIAProperties {
  final int correct;
  final int incorrect;
  final int missing;
  final double score;
  final List<String> issues;

  ARIAProperties({
    required this.correct,
    required this.incorrect,
    required this.missing,
    required this.score,
    required this.issues,
  });

  Map<String, dynamic> toJson() => {
    'correct': correct,
    'incorrect': incorrect,
    'missing': missing,
    'score': score,
    'issues': issues,
  };
}

class ARIALiveRegions {
  final int present;
  final int appropriate;
  final double score;
  final List<String> issues;

  ARIALiveRegions({
    required this.present,
    required this.appropriate,
    required this.score,
    required this.issues,
  });

  Map<String, dynamic> toJson() => {
    'present': present,
    'appropriate': appropriate,
    'score': score,
    'issues': issues,
  };
}

class ARIAAudit extends Audit {
  @override
  String get name => 'aria';

  @override
  Future<void> run(AuditContext ctx) async {
    final page = ctx.page as Page;

    // Run comprehensive ARIA analysis
    final ariaData = await page.evaluate(r'''
() => {
  const analysis = {
    landmarks: {
      present: [],
      missing: [],
      issues: []
    },
    roles: {
      correct: 0,
      incorrect: 0,
      missing: 0,
      issues: []
    },
    properties: {
      correct: 0,
      incorrect: 0,
      missing: 0,
      issues: []
    },
    liveRegions: {
      present: 0,
      appropriate: 0,
      issues: []
    }
  };

  // Define expected landmarks
  const expectedLandmarks = ['main', 'navigation', 'banner', 'contentinfo', 'search', 'complementary'];
  
  // Check for landmarks
  expectedLandmarks.forEach(landmark => {
    // Build selector dynamically
    let selector = `[role="${landmark}"]`;
    
    // Add native HTML elements for certain landmarks
    if (landmark === 'main') selector += ', main';
    if (landmark === 'navigation') selector += ', nav';
    if (landmark === 'banner') selector += ', header[role="banner"], header:not([role])';
    if (landmark === 'contentinfo') selector += ', footer[role="contentinfo"], footer:not([role])';
    
    const elements = document.querySelectorAll(selector);
    
    if (elements.length > 0) {
      analysis.landmarks.present.push(landmark);
      
      // Check for multiple main landmarks (should only be one)
      if (landmark === 'main' && elements.length > 1) {
        analysis.landmarks.issues.push(`Multiple main landmarks found (${elements.length})`);
      }
    } else {
      analysis.landmarks.missing.push(landmark);
    }
  });

  // Analyze ARIA roles
  const elementsWithRoles = document.querySelectorAll('[role]');
  const validRoles = [
    'alert', 'alertdialog', 'application', 'article', 'banner', 'button',
    'checkbox', 'complementary', 'contentinfo', 'definition', 'dialog',
    'directory', 'document', 'feed', 'figure', 'form', 'grid', 'gridcell',
    'group', 'heading', 'img', 'link', 'list', 'listbox', 'listitem',
    'log', 'main', 'marquee', 'math', 'menu', 'menubar', 'menuitem',
    'menuitemcheckbox', 'menuitemradio', 'navigation', 'none', 'note',
    'option', 'presentation', 'progressbar', 'radio', 'radiogroup',
    'region', 'row', 'rowgroup', 'rowheader', 'scrollbar', 'search',
    'searchbox', 'separator', 'slider', 'spinbutton', 'status', 'switch',
    'tab', 'table', 'tablist', 'tabpanel', 'term', 'textbox', 'timer',
    'toolbar', 'tooltip', 'tree', 'treegrid', 'treeitem'
  ];

  elementsWithRoles.forEach(element => {
    const role = element.getAttribute('role');
    
    if (validRoles.includes(role)) {
      // Check if role is appropriate for the element
      const tagName = element.tagName.toLowerCase();
      let isAppropriate = true;
      
      // Check for redundant roles
      if ((role === 'button' && tagName === 'button') ||
          (role === 'link' && tagName === 'a') ||
          (role === 'heading' && tagName.match(/^h[1-6]$/)) ||
          (role === 'list' && (tagName === 'ul' || tagName === 'ol')) ||
          (role === 'listitem' && tagName === 'li')) {
        analysis.roles.incorrect++;
        analysis.roles.issues.push(`Redundant role="${role}" on <${tagName}>`);
        isAppropriate = false;
      }
      
      // Check for conflicting roles
      if ((role === 'presentation' || role === 'none') && 
          (element.hasAttribute('aria-label') || element.hasAttribute('aria-labelledby'))) {
        analysis.roles.incorrect++;
        analysis.roles.issues.push(`Element with role="${role}" should not have aria-label/labelledby`);
        isAppropriate = false;
      }
      
      if (isAppropriate) {
        analysis.roles.correct++;
      }
    } else {
      analysis.roles.incorrect++;
      analysis.roles.issues.push(`Invalid role="${role}" on ${element.tagName}`);
    }
  });

  // Check elements that should have roles but don't
  const interactiveElements = document.querySelectorAll('div[onclick], span[onclick], div[tabindex], span[tabindex]');
  interactiveElements.forEach(element => {
    if (!element.hasAttribute('role')) {
      analysis.roles.missing++;
      analysis.roles.issues.push(`Interactive ${element.tagName} missing role attribute`);
    }
  });

  // Analyze ARIA properties and states
  const ariaAttributes = [
    'aria-label', 'aria-labelledby', 'aria-describedby', 'aria-controls',
    'aria-expanded', 'aria-hidden', 'aria-selected', 'aria-checked',
    'aria-disabled', 'aria-readonly', 'aria-required', 'aria-invalid',
    'aria-live', 'aria-atomic', 'aria-relevant', 'aria-busy',
    'aria-current', 'aria-haspopup', 'aria-pressed', 'aria-valuemin',
    'aria-valuemax', 'aria-valuenow', 'aria-valuetext', 'aria-level',
    'aria-multiline', 'aria-multiselectable', 'aria-orientation',
    'aria-placeholder', 'aria-sort', 'aria-autocomplete', 'aria-colcount',
    'aria-colindex', 'aria-colspan', 'aria-rowcount', 'aria-rowindex',
    'aria-rowspan', 'aria-setsize', 'aria-posinset'
  ];

  ariaAttributes.forEach(attr => {
    const elements = document.querySelectorAll(`[${attr}]`);
    
    elements.forEach(element => {
      const value = element.getAttribute(attr);
      let isCorrect = true;
      
      // Check for empty values
      if (value === '' || value === null) {
        analysis.properties.incorrect++;
        analysis.properties.issues.push(`Empty ${attr} attribute on ${element.tagName}`);
        isCorrect = false;
      }
      
      // Check aria-hidden on focusable elements
      if (attr === 'aria-hidden' && value === 'true') {
        if (element.matches('a[href], button, input, select, textarea, [tabindex]:not([tabindex="-1"])')) {
          analysis.properties.incorrect++;
          analysis.properties.issues.push(`aria-hidden="true" on focusable element ${element.tagName}`);
          isCorrect = false;
        }
      }
      
      // Check aria-labelledby and aria-describedby references
      if ((attr === 'aria-labelledby' || attr === 'aria-describedby') && value) {
        const ids = value.split(' ');
        ids.forEach(id => {
          if (!document.getElementById(id)) {
            analysis.properties.incorrect++;
            analysis.properties.issues.push(`${attr} references non-existent ID: ${id}`);
            isCorrect = false;
          }
        });
      }
      
      // Check boolean ARIA attributes
      const booleanAttrs = ['aria-expanded', 'aria-selected', 'aria-checked', 
                           'aria-disabled', 'aria-hidden', 'aria-readonly',
                           'aria-required', 'aria-pressed'];
      if (booleanAttrs.includes(attr)) {
        if (value !== 'true' && value !== 'false' && value !== 'mixed' && value !== 'undefined') {
          analysis.properties.incorrect++;
          analysis.properties.issues.push(`Invalid value "${value}" for boolean ${attr}`);
          isCorrect = false;
        }
      }
      
      if (isCorrect) {
        analysis.properties.correct++;
      }
    });
  });

  // Check for missing required ARIA properties
  const buttonsAndLinks = document.querySelectorAll('button, a[href], [role="button"], [role="link"]');
  buttonsAndLinks.forEach(element => {
    const text = element.textContent?.trim();
    const ariaLabel = element.getAttribute('aria-label');
    const ariaLabelledby = element.getAttribute('aria-labelledby');
    
    if (!text && !ariaLabel && !ariaLabelledby) {
      analysis.properties.missing++;
      analysis.properties.issues.push(`${element.tagName} missing accessible name`);
    }
  });

  // Analyze live regions
  const liveRegions = document.querySelectorAll('[aria-live]');
  liveRegions.forEach(region => {
    analysis.liveRegions.present++;
    
    const liveValue = region.getAttribute('aria-live');
    const role = region.getAttribute('role');
    
    // Check if live region is appropriate
    if (liveValue === 'polite' || liveValue === 'assertive') {
      analysis.liveRegions.appropriate++;
    } else if (liveValue === 'off') {
      // This is valid but doesn't count as an active live region
      analysis.liveRegions.present--;
    } else {
      analysis.liveRegions.issues.push(`Invalid aria-live value: ${liveValue}`);
    }
    
    // Check for alert roles (implicit live regions)
    if (role === 'alert' || role === 'status' || role === 'log') {
      if (!region.hasAttribute('aria-live')) {
        analysis.liveRegions.appropriate++;
        analysis.liveRegions.present++;
      }
    }
  });

  // Check for implicit live regions without aria-live
  const implicitLiveRegions = document.querySelectorAll('[role="alert"], [role="status"], [role="log"], [role="progressbar"], [role="timer"]');
  implicitLiveRegions.forEach(region => {
    if (!region.hasAttribute('aria-live')) {
      analysis.liveRegions.present++;
      analysis.liveRegions.appropriate++;
    }
  });

  return analysis;
}
    ''');

    // Calculate ARIA analysis score
    final analysis = _calculateARIAAnalysis(ariaData);
    
    // Store in context
    ctx.ariaAnalysis = analysis;
  }

  ARIAAnalysis _calculateARIAAnalysis(Map<String, dynamic> data) {
    // Calculate landmarks score
    final landmarksData = data['landmarks'] as Map<String, dynamic>;
    final landmarksPresent = List<String>.from(landmarksData['present'] ?? []);
    final landmarksMissing = List<String>.from(landmarksData['missing'] ?? []);
    final landmarksScore = landmarksPresent.isEmpty ? 0.0 : 
      (landmarksPresent.length / (landmarksPresent.length + landmarksMissing.length) * 100);

    final landmarks = ARIALandmarks(
      present: landmarksPresent,
      missing: landmarksMissing,
      score: landmarksScore,
    );

    // Calculate roles score
    final rolesData = data['roles'] as Map<String, dynamic>;
    final rolesCorrect = rolesData['correct'] as int? ?? 0;
    final rolesIncorrect = rolesData['incorrect'] as int? ?? 0;
    final rolesMissing = rolesData['missing'] as int? ?? 0;
    final rolesTotal = rolesCorrect + rolesIncorrect + rolesMissing;
    final rolesScore = rolesTotal == 0 ? 100.0 : (rolesCorrect / rolesTotal * 100);

    final roles = ARIARoles(
      correct: rolesCorrect,
      incorrect: rolesIncorrect,
      missing: rolesMissing,
      score: rolesScore,
      issues: List<String>.from(rolesData['issues'] ?? []),
    );

    // Calculate properties score
    final propsData = data['properties'] as Map<String, dynamic>;
    final propsCorrect = propsData['correct'] as int? ?? 0;
    final propsIncorrect = propsData['incorrect'] as int? ?? 0;
    final propsMissing = propsData['missing'] as int? ?? 0;
    final propsTotal = propsCorrect + propsIncorrect + propsMissing;
    final propsScore = propsTotal == 0 ? 100.0 : (propsCorrect / propsTotal * 100);

    final properties = ARIAProperties(
      correct: propsCorrect,
      incorrect: propsIncorrect,
      missing: propsMissing,
      score: propsScore,
      issues: List<String>.from(propsData['issues'] ?? []),
    );

    // Calculate live regions score
    final liveData = data['liveRegions'] as Map<String, dynamic>;
    final livePresent = liveData['present'] as int? ?? 0;
    final liveAppropriate = liveData['appropriate'] as int? ?? 0;
    final liveScore = livePresent == 0 ? 100.0 : (liveAppropriate / livePresent * 100);

    final liveRegions = ARIALiveRegions(
      present: livePresent,
      appropriate: liveAppropriate,
      score: liveScore,
      issues: List<String>.from(liveData['issues'] ?? []),
    );

    // Calculate total violations
    final totalViolations = rolesIncorrect + rolesMissing + propsIncorrect + propsMissing +
      landmarksMissing.length + (liveData['issues'] as List).length;

    // Calculate overall score
    final scores = [landmarksScore, rolesScore, propsScore, liveScore];
    final overallScore = scores.reduce((a, b) => a + b) / scores.length;

    // Calculate grade
    final grade = _calculateGrade(overallScore);

    return ARIAAnalysis(
      totalViolations: totalViolations,
      landmarks: landmarks,
      roles: roles,
      properties: properties,
      liveRegions: liveRegions,
      score: overallScore,
      grade: grade,
    );
  }

  String _calculateGrade(double score) {
    if (score >= 90) return 'A';
    if (score >= 80) return 'B';
    if (score >= 70) return 'C';
    if (score >= 60) return 'D';
    return 'F';
  }
}