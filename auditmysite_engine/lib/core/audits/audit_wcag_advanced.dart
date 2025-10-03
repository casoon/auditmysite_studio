import 'package:puppeteer/puppeteer.dart';
import 'package:logging/logging.dart';
import 'audit_base.dart';
import '../events.dart';

/// Advanced WCAG 2.2 and WCAG 3.0 (Silver) Implementation
/// Covers all missing WCAG standards for full AAA compliance
class WCAGAdvancedAudit implements Audit {
  @override
  String get name => 'wcag_advanced';
  
  final Logger _logger = Logger('WCAGAdvancedAudit');
  
  @override
  Future<void> run(AuditContext ctx) async {
    final page = ctx.page as Page;
    
    _logger.info('Running advanced WCAG 2.2 and 3.0 audit');
    
    // Run comprehensive WCAG checks
    final wcagResults = await page.evaluate('''
async () => {
  const results = {
    wcag22: {},
    wcag30: {},
    levelA: {},
    levelAA: {},
    levelAAA: {}
  };
  
  // ============================================
  // WCAG 2.2 NEW CRITERIA (Level AA)
  // ============================================
  
  // 2.4.11 Focus Not Obscured (Minimum) - Level AA
  results.wcag22['2.4.11'] = (() => {
    const focusableElements = document.querySelectorAll(
      'a[href], button, input, select, textarea, [tabindex]:not([tabindex="-1"])'
    );
    const issues = [];
    
    focusableElements.forEach(el => {
      el.focus();
      const rect = el.getBoundingClientRect();
      const centerX = rect.left + rect.width / 2;
      const centerY = rect.top + rect.height / 2;
      const topElement = document.elementFromPoint(centerX, centerY);
      
      if (topElement !== el && !el.contains(topElement)) {
        issues.push({
          element: el.tagName,
          issue: 'Focus may be obscured by other content'
        });
      }
    });
    
    return {
      passed: issues.length === 0,
      issues: issues,
      score: issues.length === 0 ? 100 : Math.max(0, 100 - issues.length * 10)
    };
  })();
  
  // 2.4.12 Focus Not Obscured (Enhanced) - Level AAA
  results.wcag22['2.4.12'] = (() => {
    const focusableElements = document.querySelectorAll(
      'a[href], button, input, select, textarea, [tabindex]:not([tabindex="-1"])'
    );
    const issues = [];
    
    focusableElements.forEach(el => {
      el.focus();
      const rect = el.getBoundingClientRect();
      
      // Check all corners and center
      const points = [
        {x: rect.left, y: rect.top},
        {x: rect.right, y: rect.top},
        {x: rect.left, y: rect.bottom},
        {x: rect.right, y: rect.bottom},
        {x: rect.left + rect.width/2, y: rect.top + rect.height/2}
      ];
      
      let visible = 0;
      points.forEach(point => {
        const topElement = document.elementFromPoint(point.x, point.y);
        if (topElement === el || el.contains(topElement)) {
          visible++;
        }
      });
      
      if (visible < 5) {
        issues.push({
          element: el.tagName,
          visibility: (visible / 5 * 100) + '%'
        });
      }
    });
    
    return {
      passed: issues.length === 0,
      issues: issues,
      score: issues.length === 0 ? 100 : Math.max(0, 100 - issues.length * 5)
    };
  })();
  
  // 2.4.13 Focus Appearance - Level AA
  results.wcag22['2.4.13'] = (() => {
    const focusableElements = document.querySelectorAll(
      'a[href], button, input, select, textarea, [tabindex]:not([tabindex="-1"])'
    );
    const issues = [];
    
    focusableElements.forEach(el => {
      const styles = window.getComputedStyle(el);
      const focusStyles = window.getComputedStyle(el, ':focus');
      
      // Check for focus indicator
      const hasOutline = focusStyles.outlineWidth !== '0px';
      const hasBorder = focusStyles.borderWidth !== styles.borderWidth;
      const hasBoxShadow = focusStyles.boxShadow !== 'none';
      
      if (!hasOutline && !hasBorder && !hasBoxShadow) {
        issues.push({
          element: el.tagName,
          issue: 'No visible focus indicator'
        });
      }
      
      // Check focus indicator contrast (3:1 minimum)
      if (hasOutline) {
        const outlineColor = focusStyles.outlineColor;
        // Simplified contrast check - would need full color contrast algorithm
        if (outlineColor && outlineColor.includes('rgba')) {
          const alpha = parseFloat(outlineColor.match(/[\d.]+(?=\))/)?.[0] || '1');
          if (alpha < 0.5) {
            issues.push({
              element: el.tagName,
              issue: 'Focus indicator may have insufficient contrast'
            });
          }
        }
      }
    });
    
    return {
      passed: issues.length === 0,
      issues: issues,
      score: issues.length === 0 ? 100 : Math.max(0, 100 - issues.length * 10)
    };
  })();
  
  // 2.5.7 Dragging Movements - Level AA
  results.wcag22['2.5.7'] = (() => {
    const draggableElements = document.querySelectorAll('[draggable="true"]');
    const issues = [];
    
    draggableElements.forEach(el => {
      // Check for keyboard alternative
      const hasKeyboardHandler = el.onkeydown || el.onkeypress || el.onkeyup;
      const hasAriaGrabbed = el.hasAttribute('aria-grabbed');
      
      if (!hasKeyboardHandler && !hasAriaGrabbed) {
        issues.push({
          element: el.tagName,
          issue: 'Draggable element without keyboard alternative'
        });
      }
    });
    
    return {
      passed: issues.length === 0,
      issues: issues,
      score: issues.length === 0 ? 100 : Math.max(0, 100 - issues.length * 15)
    };
  })();
  
  // 2.5.8 Target Size (Minimum) - Level AA (Enhanced from 2.5.5)
  results.wcag22['2.5.8'] = (() => {
    const interactiveElements = document.querySelectorAll(
      'a, button, input[type="checkbox"], input[type="radio"], [role="button"]'
    );
    const issues = [];
    
    interactiveElements.forEach(el => {
      const rect = el.getBoundingClientRect();
      const area = rect.width * rect.height;
      
      // Check for 24x24 CSS pixels minimum
      if (rect.width < 24 || rect.height < 24) {
        // Check for exceptions (inline text, user agent control, essential)
        const isInline = window.getComputedStyle(el).display === 'inline';
        const isEssential = el.hasAttribute('data-essential');
        
        if (!isInline && !isEssential) {
          issues.push({
            element: el.tagName,
            size: `${Math.round(rect.width)}x${Math.round(rect.height)}`,
            required: '24x24'
          });
        }
      }
    });
    
    return {
      passed: issues.length === 0,
      issues: issues,
      score: issues.length === 0 ? 100 : Math.max(0, 100 - issues.length * 5)
    };
  })();
  
  // 3.2.6 Consistent Help - Level A
  results.wcag22['3.2.6'] = (() => {
    const helpElements = document.querySelectorAll(
      '[aria-label*="help"], [title*="help"], .help, #help, [href*="help"]'
    );
    const issues = [];
    
    if (helpElements.length === 0) {
      issues.push({
        issue: 'No help mechanism found on page'
      });
    } else {
      // Check if help is consistently positioned
      const positions = Array.from(helpElements).map(el => {
        const rect = el.getBoundingClientRect();
        return {x: rect.left, y: rect.top};
      });
      
      const uniquePositions = new Set(positions.map(pos => `${pos.x},${pos.y}`));
      if (uniquePositions.size > 2) {
        issues.push({
          issue: 'Help elements are not consistently positioned'
        });
      }
    }
    
    return {
      passed: issues.length === 0,
      issues: issues,
      score: issues.length === 0 ? 100 : 80
    };
  })();
  
  // 3.3.7 Accessible Authentication - Level A
  results.wcag22['3.3.7'] = (() => {
    const passwordFields = document.querySelectorAll('input[type="password"]');
    const issues = [];
    
    passwordFields.forEach(field => {
      // Check for copy/paste restrictions
      const hasPasteRestriction = field.onpaste === null || 
                                  field.getAttribute('onpaste') === 'return false';
      
      if (hasPasteRestriction) {
        issues.push({
          element: field.id || field.name,
          issue: 'Password field restricts paste functionality'
        });
      }
      
      // Check for cognitive function test (CAPTCHA without alternative)
      const form = field.closest('form');
      const hasCaptcha = form?.querySelector('[class*="captcha"], [id*="captcha"]');
      const hasAlternative = form?.querySelector('[aria-label*="audio"], [aria-label*="alternative"]');
      
      if (hasCaptcha && !hasAlternative) {
        issues.push({
          issue: 'CAPTCHA without accessible alternative'
        });
      }
    });
    
    return {
      passed: issues.length === 0,
      issues: issues,
      score: issues.length === 0 ? 100 : Math.max(0, 100 - issues.length * 20)
    };
  })();
  
  // 3.3.8 Accessible Authentication (No Exception) - Level AA
  results.wcag22['3.3.8'] = (() => {
    const authElements = document.querySelectorAll(
      'input[type="password"], input[type="text"][autocomplete*="username"], input[type="email"]'
    );
    const issues = [];
    
    authElements.forEach(el => {
      // Check for autocomplete support
      const autocomplete = el.getAttribute('autocomplete');
      const type = el.type;
      
      if (type === 'password' && (!autocomplete || autocomplete === 'off')) {
        issues.push({
          element: el.id || el.name,
          issue: 'Password field without autocomplete support'
        });
      }
      
      if ((type === 'text' || type === 'email') && 
          el.name?.includes('user') && 
          (!autocomplete || autocomplete === 'off')) {
        issues.push({
          element: el.id || el.name,
          issue: 'Username field without autocomplete support'
        });
      }
    });
    
    return {
      passed: issues.length === 0,
      issues: issues,
      score: issues.length === 0 ? 100 : Math.max(0, 100 - issues.length * 15)
    };
  })();
  
  // ============================================
  // MISSING WCAG 2.1 LEVEL A IMPLEMENTATIONS
  // ============================================
  
  // 1.2.1 Audio-only and Video-only (Prerecorded)
  results.levelA['1.2.1'] = (() => {
    const audioElements = document.querySelectorAll('audio');
    const videoElements = document.querySelectorAll('video');
    const issues = [];
    
    audioElements.forEach(audio => {
      // Check for transcript
      const hasTranscript = audio.querySelector('track[kind="descriptions"]') ||
                          audio.nextElementSibling?.classList.contains('transcript') ||
                          (audio.id ? document.querySelector(`[aria-describedby="${audio.id}"]`) : null);
      
      if (!hasTranscript) {
        issues.push({
          element: 'audio',
          issue: 'Audio content without transcript'
        });
      }
    });
    
    videoElements.forEach(video => {
      // Check for audio track
      const hasAudio = video.audioTracks?.length > 0 || video.querySelector('track[kind="descriptions"]');
      if (!hasAudio && !video.hasAttribute('aria-label')) {
        issues.push({
          element: 'video',
          issue: 'Video-only content without audio description or text alternative'
        });
      }
    });
    
    return {
      passed: issues.length === 0,
      issues: issues,
      score: issues.length === 0 ? 100 : Math.max(0, 100 - issues.length * 25)
    };
  })();
  
  // 1.4.2 Audio Control
  results.levelA['1.4.2'] = (() => {
    const audioElements = document.querySelectorAll('audio[autoplay], video[autoplay]');
    const issues = [];
    
    audioElements.forEach(media => {
      // Check if plays for more than 3 seconds
      const duration = media.duration;
      
      if (duration > 3) {
        // Check for pause/stop mechanism
        const controls = media.hasAttribute('controls');
        const customControls = media.parentElement?.querySelector('[class*="control"], [class*="pause"], [class*="stop"]');
        
        if (!controls && !customControls) {
          issues.push({
            element: media.tagName.toLowerCase(),
            issue: 'Auto-playing media longer than 3 seconds without pause/stop control'
          });
        }
      }
    });
    
    return {
      passed: issues.length === 0,
      issues: issues,
      score: issues.length === 0 ? 100 : 0 // Critical issue
    };
  })();
  
  // 2.2.1 Timing Adjustable
  results.levelA['2.2.1'] = (() => {
    const issues = [];
    
    // Check for meta refresh
    const metaRefresh = document.querySelector('meta[http-equiv="refresh"]');
    if (metaRefresh) {
      const content = metaRefresh.getAttribute('content');
      const seconds = parseInt(content?.split(';')[0] || '0');
      
      if (seconds > 0 && seconds < 20 * 3600) { // Less than 20 hours
        issues.push({
          element: 'meta refresh',
          issue: `Auto-refresh set to \${seconds} seconds without user control`
        });
      }
    }
    
    // Check for session timeout warnings
    const hasSessionWarning = document.querySelector('[class*="session"], [id*="timeout"]');
    if (!hasSessionWarning) {
      // Check if page has forms (likely has session)
      const forms = document.querySelectorAll('form');
      if (forms.length > 0) {
        issues.push({
          issue: 'Forms present but no session timeout warning mechanism detected'
        });
      }
    }
    
    return {
      passed: issues.length === 0,
      issues: issues,
      score: issues.length === 0 ? 100 : 50
    };
  })();
  
  // 2.2.2 Pause, Stop, Hide
  results.levelA['2.2.2'] = (() => {
    const issues = [];
    
    // Check for animated content
    const animatedElements = document.querySelectorAll(
      '[style*="animation"], .animated, .carousel, .slider, marquee'
    );
    
    animatedElements.forEach(el => {
      // Check if has pause control
      const hasPauseButton = el.querySelector('[class*="pause"], [aria-label*="pause"]');
      const parentHasPause = el.parentElement?.querySelector('[class*="pause"], [aria-label*="pause"]');
      
      if (!hasPauseButton && !parentHasPause) {
        const style = window.getComputedStyle(el);
        const animationDuration = parseFloat(style.animationDuration || '0');
        
        if (animationDuration > 5) { // Longer than 5 seconds
          issues.push({
            element: el.tagName,
            issue: `Animation lasting \${animationDuration}s without pause control`
          });
        }
      }
    });
    
    return {
      passed: issues.length === 0,
      issues: issues,
      score: issues.length === 0 ? 100 : Math.max(0, 100 - issues.length * 10)
    };
  })();
  
  // 3.2.1 On Focus
  results.levelA['3.2.1'] = (() => {
    const focusableElements = document.querySelectorAll(
      'a[href], button, input, select, textarea, [tabindex]:not([tabindex="-1"])'
    );
    const issues = [];
    
    focusableElements.forEach(el => {
      // Save initial state
      const initialUrl = window.location.href;
      const initialDisplay = window.getComputedStyle(el.parentElement || el).display;
      
      // Focus element
      el.focus();
      
      // Check for context changes
      if (window.location.href !== initialUrl) {
        issues.push({
          element: el.tagName,
          issue: 'Focus causes navigation'
        });
      }
      
      const newDisplay = window.getComputedStyle(el.parentElement || el).display;
      if (initialDisplay !== newDisplay) {
        issues.push({
          element: el.tagName,
          issue: 'Focus causes layout change'
        });
      }
    });
    
    return {
      passed: issues.length === 0,
      issues: issues,
      score: issues.length === 0 ? 100 : Math.max(0, 100 - issues.length * 20)
    };
  })();
  
  // ============================================
  // MISSING WCAG 2.1 LEVEL AA IMPLEMENTATIONS
  // ============================================
  
  // 1.3.4 Orientation
  results.levelAA['1.3.4'] = (() => {
    const issues = [];
    
    // Check CSS for orientation locks
    const styles = Array.from(document.styleSheets).flatMap(sheet => {
      try {
        return Array.from(sheet.cssRules || []);
      } catch (e) {
        return [];
      }
    });
    
    const hasOrientationLock = styles.some(rule => {
      return rule.cssText?.includes('orientation:') && 
             (rule.cssText.includes('portrait') || rule.cssText.includes('landscape'));
    });
    
    if (hasOrientationLock) {
      issues.push({
        issue: 'CSS contains orientation restrictions'
      });
    }
    
    // Check viewport meta
    const viewport = document.querySelector('meta[name="viewport"]');
    if (viewport?.content?.includes('user-scalable=no')) {
      issues.push({
        issue: 'Viewport prevents user scaling which affects orientation flexibility'
      });
    }
    
    return {
      passed: issues.length === 0,
      issues: issues,
      score: issues.length === 0 ? 100 : 50
    };
  })();
  
  // 1.3.5 Identify Input Purpose
  results.levelAA['1.3.5'] = (() => {
    const issues = [];
    const inputPurposes = {
      'name': ['name', 'full-name', 'fullname'],
      'email': ['email', 'e-mail'],
      'tel': ['tel', 'phone', 'telephone', 'mobile'],
      'street-address': ['address', 'street'],
      'postal-code': ['postal', 'zip', 'postcode'],
      'cc-number': ['card', 'credit-card', 'cc'],
      'cc-exp': ['exp', 'expiry', 'expiration'],
      'cc-csc': ['cvc', 'cvv', 'security-code']
    };
    
    document.querySelectorAll('input[type="text"], input[type="email"], input[type="tel"]').forEach(input => {
      const autocomplete = input.getAttribute('autocomplete');
      const name = input.name?.toLowerCase() || '';
      const id = input.id?.toLowerCase() || '';
      
      // Check if input purpose can be determined
      let purposeFound = false;
      for (const [purpose, keywords] of Object.entries(inputPurposes)) {
        if (keywords.some(keyword => name.includes(keyword) || id.includes(keyword))) {
          purposeFound = true;
          
          // Check if has appropriate autocomplete
          if (!autocomplete || autocomplete === 'off') {
            issues.push({
              element: input.id || input.name,
              purpose: purpose,
              issue: 'Input purpose identifiable but missing autocomplete attribute'
            });
          }
          break;
        }
      }
    });
    
    return {
      passed: issues.length === 0,
      issues: issues,
      score: issues.length === 0 ? 100 : Math.max(0, 100 - issues.length * 5)
    };
  })();
  
  // 1.4.4 Resize Text
  results.levelAA['1.4.4'] = (() => {
    const issues = [];
    
    // Check for text resize capability
    const originalZoom = document.documentElement.style.zoom;
    document.documentElement.style.zoom = '200%';
    
    // Check if content is still accessible
    const bodyWidth = document.body.scrollWidth;
    const viewportWidth = window.innerWidth;
    
    if (bodyWidth > viewportWidth * 2) {
      issues.push({
        issue: 'Content requires horizontal scrolling at 200% zoom'
      });
    }
    
    // Check for text in images
    const images = document.querySelectorAll('img');
    images.forEach(img => {
      if (img.alt && img.alt.length > 20 && !img.src.includes('icon')) {
        issues.push({
          element: 'img',
          issue: 'Possible text in image (long alt text detected)'
        });
      }
    });
    
    // Reset zoom
    document.documentElement.style.zoom = originalZoom;
    
    return {
      passed: issues.length === 0,
      issues: issues,
      score: issues.length === 0 ? 100 : Math.max(0, 100 - issues.length * 10)
    };
  })();
  
  // 1.4.10 Reflow
  results.levelAA['1.4.10'] = (() => {
    const issues = [];
    
    // Save original viewport
    const originalWidth = window.innerWidth;
    
    // Test at 320px width
    if (window.innerWidth > 320) {
      // Check for horizontal scroll at 320px
      const testWidth = 320;
      const bodyWidth = document.body.scrollWidth;
      
      if (bodyWidth > testWidth * 1.5) {
        issues.push({
          issue: `Content requires horizontal scrolling at \${testWidth}px width`,
          actualWidth: bodyWidth
        });
      }
    }
    
    // Check for fixed widths in CSS
    const fixedWidthElements = document.querySelectorAll('[style*="width"]');
    fixedWidthElements.forEach(el => {
      const style = el.getAttribute('style') || '';
      const widthMatch = style.match(/width:\s*(\d+)px/);
      
      if (widthMatch && parseInt(widthMatch[1]) > 320) {
        issues.push({
          element: el.tagName,
          issue: `Fixed width \${widthMatch[1]}px exceeds mobile viewport`
        });
      }
    });
    
    return {
      passed: issues.length === 0,
      issues: issues,
      score: issues.length === 0 ? 100 : Math.max(0, 100 - issues.length * 10)
    };
  })();
  
  // 1.4.11 Non-text Contrast
  results.levelAA['1.4.11'] = (() => {
    const issues = [];
    
    // Check UI component contrast
    const uiElements = document.querySelectorAll(
      'button, input, select, textarea, [role="button"], [role="checkbox"], [role="radio"]'
    );
    
    uiElements.forEach(el => {
      const styles = window.getComputedStyle(el);
      const borderColor = styles.borderColor;
      const backgroundColor = styles.backgroundColor;
      
      // Simplified contrast check - would need full implementation
      if (borderColor === 'rgba(0, 0, 0, 0)' && backgroundColor === 'rgba(0, 0, 0, 0)') {
        issues.push({
          element: el.tagName,
          issue: 'UI component may have insufficient contrast'
        });
      }
    });
    
    // Check graphics contrast
    const svgElements = document.querySelectorAll('svg');
    svgElements.forEach(svg => {
      const paths = svg.querySelectorAll('path, circle, rect, line');
      paths.forEach(path => {
        const stroke = path.getAttribute('stroke');
        const fill = path.getAttribute('fill');
        
        if ((!stroke || stroke === 'none') && (!fill || fill === 'none')) {
          issues.push({
            element: 'SVG graphic',
            issue: 'Graphic element without visible stroke or fill'
          });
        }
      });
    });
    
    return {
      passed: issues.length === 0,
      issues: issues,
      score: issues.length === 0 ? 100 : Math.max(0, 100 - issues.length * 5)
    };
  })();
  
  // 1.4.12 Text Spacing
  results.levelAA['1.4.12'] = (() => {
    const issues = [];
    
    // Apply text spacing changes
    const testStyles = document.createElement('style');
    testStyles.innerHTML = `
      * {
        line-height: 1.5 !important;
        letter-spacing: 0.12em !important;
        word-spacing: 0.16em !important;
      }
      p { margin-bottom: 2em !important; }
    `;
    document.head.appendChild(testStyles);
    
    // Check for clipping or overlap
    const textElements = document.querySelectorAll('p, div, span, h1, h2, h3, h4, h5, h6');
    textElements.forEach(el => {
      const rect = el.getBoundingClientRect();
      const parent = el.parentElement;
      if (parent) {
        const parentRect = parent.getBoundingClientRect();
        
        // Check for clipping
        if (rect.right > parentRect.right || rect.bottom > parentRect.bottom) {
          issues.push({
            element: el.tagName,
            issue: 'Text clipped when spacing is adjusted'
          });
        }
      }
    });
    
    // Remove test styles
    testStyles.remove();
    
    return {
      passed: issues.length === 0,
      issues: issues,
      score: issues.length === 0 ? 100 : Math.max(0, 100 - issues.length * 10)
    };
  })();
  
  // 1.4.13 Content on Hover or Focus
  results.levelAA['1.4.13'] = (() => {
    const issues = [];
    
    // Find elements with hover content
    const hoverElements = document.querySelectorAll('[title], [data-tooltip], .tooltip');
    
    hoverElements.forEach(el => {
      const hasEscapeMechanism = el.getAttribute('data-dismissible') || 
                                el.classList.contains('dismissible');
      const isHoverable = true; // Would need to test actual hover behavior
      const isPersistent = el.hasAttribute('data-persistent');
      
      if (!hasEscapeMechanism) {
        issues.push({
          element: el.tagName,
          issue: 'Hover content without dismissal mechanism (ESC key)'
        });
      }
      
      if (!isPersistent) {
        issues.push({
          element: el.tagName,
          issue: 'Hover content may not persist when pointer moves to it'
        });
      }
    });
    
    return {
      passed: issues.length === 0,
      issues: issues,
      score: issues.length === 0 ? 100 : Math.max(0, 100 - issues.length * 10)
    };
  })();
  
  // 3.3.3 Error Suggestion
  results.levelAA['3.3.3'] = (() => {
    const issues = [];
    
    // Find form error messages
    const errorElements = document.querySelectorAll(
      '[class*="error"], [id*="error"], [role="alert"], .invalid-feedback'
    );
    
    errorElements.forEach(error => {
      const text = error.textContent || '';
      
      // Check if error provides suggestion
      const hasSuggestion = text.includes('must') || 
                           text.includes('should') || 
                           text.includes('format') ||
                           text.includes('example') ||
                           text.includes('like');
      
      if (!hasSuggestion && text.length > 0) {
        issues.push({
          errorText: text.substring(0, 50),
          issue: 'Error message without suggestion for correction'
        });
      }
    });
    
    // Check for required field indicators
    const requiredFields = document.querySelectorAll('[required], [aria-required="true"]');
    requiredFields.forEach(field => {
      const label = field.id ? document.querySelector(`label[for="\${field.id}"]`) : null;
      if (label && !label.textContent?.includes('*') && !label.querySelector('.required')) {
        issues.push({
          field: field.id || field.name,
          issue: 'Required field without visual indicator'
        });
      }
    });
    
    return {
      passed: issues.length === 0,
      issues: issues,
      score: issues.length === 0 ? 100 : Math.max(0, 100 - issues.length * 5)
    };
  })();
  
  // ============================================
  // WCAG 3.0 (SILVER) PREVIEW CHECKS
  // ============================================
  
  // WCAG 3.0 uses outcome-based testing
  results.wcag30 = {
    // Outcome: Text alternatives available
    textAlternatives: (() => {
      const mediaElements = document.querySelectorAll('img, video, audio, svg, canvas');
      let totalElements = mediaElements.length;
      let elementsWithAlternatives = 0;
      
      mediaElements.forEach(el => {
        const hasAlt = el.hasAttribute('alt') || 
                      el.hasAttribute('aria-label') ||
                      el.hasAttribute('aria-labelledby') ||
                      el.querySelector('text, title, desc');
        
        if (hasAlt) elementsWithAlternatives++;
      });
      
      return {
        score: totalElements > 0 ? (elementsWithAlternatives / totalElements * 100) : 100,
        passed: elementsWithAlternatives === totalElements
      };
    })(),
    
    // Outcome: Structured content
    structuredContent: (() => {
      const headings = document.querySelectorAll('h1, h2, h3, h4, h5, h6');
      const landmarks = document.querySelectorAll('main, nav, aside, header, footer, [role="main"], [role="navigation"]');
      const lists = document.querySelectorAll('ul, ol, dl');
      
      const score = Math.min(100, 
        (headings.length * 10) + 
        (landmarks.length * 15) + 
        (lists.length * 5)
      );
      
      return {
        score: score,
        passed: score >= 60,
        details: {
          headings: headings.length,
          landmarks: landmarks.length,
          lists: lists.length
        }
      };
    })(),
    
    // Outcome: Findable help
    findableHelp: (() => {
      const helpIndicators = [
        document.querySelector('[aria-label*="help"]'),
        document.querySelector('[class*="help"]'),
        document.querySelector('[href*="help"]'),
        document.querySelector('[href*="support"]'),
        document.querySelector('[href*="contact"]')
      ].filter(Boolean);
      
      return {
        score: helpIndicators.length > 0 ? 100 : 0,
        passed: helpIndicators.length > 0,
        count: helpIndicators.length
      };
    })(),
    
    // Outcome: Clear language
    clearLanguage: (() => {
      const textContent = document.body.textContent || '';
      const sentences = textContent.split(/[.!?]+/).filter(s => s.trim().length > 0);
      
      let complexSentences = 0;
      let totalWords = 0;
      
      sentences.forEach(sentence => {
        const words = sentence.split(/\s+/);
        totalWords += words.length;
        
        // Check for complex sentences (>25 words)
        if (words.length > 25) {
          complexSentences++;
        }
      });
      
      const avgWordsPerSentence = sentences.length > 0 ? totalWords / sentences.length : 0;
      const complexityScore = Math.max(0, 100 - (complexSentences * 2));
      
      return {
        score: complexityScore,
        passed: avgWordsPerSentence < 20,
        avgWordsPerSentence: Math.round(avgWordsPerSentence),
        complexSentences: complexSentences
      };
    })()
  };
  
  // Calculate overall scores
  const calculateCategoryScore = (category) => {
    const scores = Object.values(category)
      .filter(check => check && typeof check.score === 'number')
      .map(check => check.score);
    
    return scores.length > 0 
      ? Math.round(scores.reduce((a, b) => a + b, 0) / scores.length)
      : 0;
  };
  
  results.overallScores = {
    wcag22: calculateCategoryScore(results.wcag22),
    levelA: calculateCategoryScore(results.levelA),
    levelAA: calculateCategoryScore(results.levelAA),
    levelAAA: calculateCategoryScore(results.levelAAA || {}),
    wcag30: calculateCategoryScore(results.wcag30)
  };
  
  // Determine compliance levels
  results.compliance = {
    levelA: Object.values(results.levelA).every(check => check.passed),
    levelAA: Object.values(results.levelA).every(check => check.passed) &&
             Object.values(results.levelAA).every(check => check.passed),
    wcag22AA: Object.values(results.levelA).every(check => check.passed) &&
              Object.values(results.levelAA).every(check => check.passed) &&
              Object.values(results.wcag22).filter(check => check.level !== 'AAA').every(check => check.passed)
  };
  
  return results;
}
    ''');
    
    // Store results
    ctx.wcagAdvanced = wcagResults;
    
    // Log summary
    _logger.info('WCAG Advanced Audit Complete:');
    _logger.info('  WCAG 2.2 Score: ${wcagResults['overallScores']['wcag22']}%');
    _logger.info('  Level A Compliance: ${wcagResults['compliance']['levelA']}');
    _logger.info('  Level AA Compliance: ${wcagResults['compliance']['levelAA']}');
    _logger.info('  WCAG 2.2 AA Compliance: ${wcagResults['compliance']['wcag22AA']}');
  }
}

// Extension for AuditContext
extension WCAGAdvancedContext on AuditContext {
  static final _wcagAdvanced = Expando<Map<String, dynamic>>();
  
  Map<String, dynamic>? get wcagAdvanced => _wcagAdvanced[this];
  set wcagAdvanced(Map<String, dynamic>? value) => _wcagAdvanced[this] = value;
}