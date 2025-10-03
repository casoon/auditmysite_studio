import 'package:puppeteer/puppeteer.dart';
import 'package:logging/logging.dart';
import 'audit_base.dart';
import '../events.dart';

/// WCAG 2.2 Level AA Compliance Audit
/// Implements all WCAG 2.2 Level AA success criteria
class WCAG22LevelAAAudit implements Audit {
  @override
  String get name => 'wcag22_level_aa';
  
  final Logger _logger = Logger('WCAG22LevelAA');
  
  @override
  Future<void> run(AuditContext ctx) async {
    final page = ctx.page as Page;
    
    _logger.info('Running WCAG 2.2 Level AA audit');
    
    final results = await page.evaluate('''
async () => {
  const violations = [];
  const warnings = [];
  const passes = [];
  
  const addResult = (type, criterion, description, elements = []) => {
    const result = { criterion, description, elements: elements.slice(0, 5) };
    if (type === 'violation') violations.push(result);
    else if (type === 'warning') warnings.push(result);
    else if (type === 'pass') passes.push(result);
  };
  
  // Helper function to calculate color contrast
  const getContrastRatio = (rgb1, rgb2) => {
    const getLuminance = (rgb) => {
      const [r, g, b] = rgb.match(/\\d+/g).map(n => parseInt(n) / 255);
      const vals = [r, g, b].map(v => v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4));
      return vals[0] * 0.2126 + vals[1] * 0.7152 + vals[2] * 0.0722;
    };
    
    const l1 = getLuminance(rgb1);
    const l2 = getLuminance(rgb2);
    return (Math.max(l1, l2) + 0.05) / (Math.min(l1, l2) + 0.05);
  };
  
  // ============================================
  // 1. PERCEIVABLE - LEVEL AA
  // ============================================
  
  // 1.2.4 Captions (Live) (Level AA)
  (() => {
    const liveMedia = document.querySelectorAll('video[autoplay], audio[autoplay], [aria-live]');
    const issues = [];
    
    liveMedia.forEach(media => {
      if (media.tagName === 'VIDEO' || media.tagName === 'AUDIO') {
        const hasCaptions = media.querySelector('track[kind="captions"]');
        if (!hasCaptions) {
          issues.push({
            type: media.tagName.toLowerCase(),
            src: media.src || 'inline'
          });
        }
      }
    });
    
    if (issues.length > 0) {
      addResult('warning', '1.2.4', 'Live media may need captions', issues);
    } else if (liveMedia.length > 0) {
      addResult('pass', '1.2.4', 'Live media has appropriate captions');
    }
  })();
  
  // 1.2.5 Audio Description (Prerecorded) (Level AA)
  (() => {
    const videos = document.querySelectorAll('video');
    const issues = [];
    
    videos.forEach(video => {
      const hasAudioDesc = video.querySelector('track[kind="descriptions"]');
      const hasAriaDesc = video.hasAttribute('aria-describedby');
      
      if (!hasAudioDesc && !hasAriaDesc) {
        issues.push({
          src: video.src || 'inline video'
        });
      }
    });
    
    if (issues.length > 0) {
      addResult('violation', '1.2.5', 'Videos lack audio description', issues);
    } else if (videos.length > 0) {
      addResult('pass', '1.2.5', 'Videos have audio description');
    }
  })();
  
  // 1.3.4 Orientation (Level AA) - WCAG 2.1
  (() => {
    const viewport = document.querySelector('meta[name="viewport"]');
    const issues = [];
    
    if (viewport) {
      const content = viewport.getAttribute('content') || '';
      
      // Check for orientation restrictions
      if (content.includes('user-scalable=no') || content.includes('maximum-scale=1')) {
        issues.push({
          type: 'viewport_restriction',
          content: content
        });
      }
    }
    
    // Check CSS for orientation locks
    const hasOrientationMedia = Array.from(document.styleSheets).some(sheet => {
      try {
        return Array.from(sheet.cssRules || []).some(rule => 
          rule.cssText?.includes('@media') && 
          rule.cssText?.includes('orientation')
        );
      } catch {
        return false;
      }
    });
    
    if (!hasOrientationMedia) {
      issues.push({
        type: 'no_responsive_design',
        note: 'No orientation media queries detected'
      });
    }
    
    if (issues.length > 0) {
      addResult('warning', '1.3.4', 'Orientation may be restricted', issues);
    } else {
      addResult('pass', '1.3.4', 'Content adapts to orientation');
    }
  })();
  
  // 1.3.5 Identify Input Purpose (Level AA) - WCAG 2.1
  (() => {
    const issues = [];
    const autofillTokens = [
      'name', 'email', 'username', 'new-password', 'current-password',
      'tel', 'street-address', 'address-line1', 'address-line2',
      'country', 'postal-code', 'cc-number', 'cc-exp', 'cc-csc'
    ];
    
    const inputs = document.querySelectorAll('input[type="text"], input[type="email"], input[type="tel"], input[type="password"]');
    
    inputs.forEach(input => {
      const autocomplete = input.getAttribute('autocomplete');
      const name = input.name?.toLowerCase() || '';
      const id = input.id?.toLowerCase() || '';
      
      // Check if input purpose can be programmatically determined
      const needsAutocomplete = autofillTokens.some(token => 
        name.includes(token.replace('-', '')) || 
        id.includes(token.replace('-', ''))
      );
      
      if (needsAutocomplete && (!autocomplete || autocomplete === 'off')) {
        issues.push({
          field: input.name || input.id || 'unnamed',
          type: input.type
        });
      }
    });
    
    if (issues.length > 0) {
      addResult('violation', '1.3.5', 'Input purposes not programmatically determinable', issues);
    } else {
      addResult('pass', '1.3.5', 'Input purposes are identifiable');
    }
  })();
  
  // 1.4.3 Contrast (Minimum) (Level AA)
  (() => {
    const issues = [];
    const textElements = document.querySelectorAll('p, span, div, h1, h2, h3, h4, h5, h6, a, button, label');
    
    textElements.forEach(element => {
      const styles = window.getComputedStyle(element);
      const fontSize = parseFloat(styles.fontSize);
      const fontWeight = styles.fontWeight;
      const isLargeText = fontSize >= 18 || (fontSize >= 14 && fontWeight === 'bold');
      
      const color = styles.color;
      const bgColor = styles.backgroundColor;
      
      if (color && bgColor && !bgColor.includes('transparent')) {
        try {
          const contrast = getContrastRatio(color, bgColor);
          const requiredRatio = isLargeText ? 3 : 4.5;
          
          if (contrast < requiredRatio) {
            issues.push({
              text: element.textContent?.substring(0, 30),
              contrast: contrast.toFixed(2),
              required: requiredRatio,
              fontSize: fontSize
            });
          }
        } catch (e) {
          // Skip if can't calculate
        }
      }
    });
    
    if (issues.length > 0) {
      addResult('violation', '1.4.3', 'Insufficient color contrast', issues);
    } else {
      addResult('pass', '1.4.3', 'Color contrast meets minimum requirements');
    }
  })();
  
  // 1.4.4 Resize Text (Level AA)
  (() => {
    const viewport = document.querySelector('meta[name="viewport"]');
    const issues = [];
    
    if (viewport) {
      const content = viewport.getAttribute('content') || '';
      if (content.includes('user-scalable=no') || content.includes('maximum-scale=1')) {
        issues.push({
          type: 'viewport_prevents_zoom',
          content: content
        });
      }
    }
    
    // Check for fixed font sizes
    const elementsWithFixedSize = document.querySelectorAll('[style*="font-size"]');
    elementsWithFixedSize.forEach(el => {
      const style = el.getAttribute('style') || '';
      if (style.includes('px') && !style.includes('em') && !style.includes('rem')) {
        issues.push({
          element: el.tagName.toLowerCase(),
          style: style.substring(0, 50)
        });
      }
    });
    
    if (issues.length > 0) {
      addResult('violation', '1.4.4', 'Text resize may be restricted', issues);
    } else {
      addResult('pass', '1.4.4', 'Text can be resized without loss of functionality');
    }
  })();
  
  // 1.4.5 Images of Text (Level AA)
  (() => {
    const images = document.querySelectorAll('img');
    const suspiciousImages = [];
    
    images.forEach(img => {
      const alt = img.alt || '';
      const src = img.src || '';
      
      // Check if image might contain text
      if (alt.length > 20 || src.includes('banner') || src.includes('header') || src.includes('logo')) {
        if (!src.includes('logo') && !src.includes('icon')) {
          suspiciousImages.push({
            src: src.substring(0, 50),
            alt: alt.substring(0, 30)
          });
        }
      }
    });
    
    if (suspiciousImages.length > 0) {
      addResult('warning', '1.4.5', 'Images may contain text', suspiciousImages);
    } else {
      addResult('pass', '1.4.5', 'Text is used instead of images of text');
    }
  })();
  
  // 1.4.10 Reflow (Level AA) - WCAG 2.1
  (() => {
    const issues = [];
    
    // Check for horizontal scrolling requirements
    const bodyWidth = document.body.scrollWidth;
    const viewportWidth = window.innerWidth;
    
    if (bodyWidth > viewportWidth + 50) {
      issues.push({
        type: 'horizontal_scroll',
        bodyWidth: bodyWidth,
        viewportWidth: viewportWidth
      });
    }
    
    // Check for fixed positioning that might cause issues
    const fixedElements = document.querySelectorAll('[style*="position: fixed"], [style*="position:fixed"]');
    if (fixedElements.length > 2) {
      issues.push({
        type: 'excessive_fixed_positioning',
        count: fixedElements.length
      });
    }
    
    if (issues.length > 0) {
      addResult('violation', '1.4.10', 'Content does not reflow properly', issues);
    } else {
      addResult('pass', '1.4.10', 'Content reflows without horizontal scrolling');
    }
  })();
  
  // 1.4.11 Non-text Contrast (Level AA) - WCAG 2.1
  (() => {
    const issues = [];
    
    // Check UI components
    const uiComponents = document.querySelectorAll('button, input, select, [role="button"]');
    
    uiComponents.forEach(component => {
      const styles = window.getComputedStyle(component);
      const borderColor = styles.borderColor;
      const backgroundColor = styles.backgroundColor;
      const parentBg = component.parentElement ? 
        window.getComputedStyle(component.parentElement).backgroundColor : 'rgb(255,255,255)';
      
      // Check border contrast
      if (borderColor && !borderColor.includes('transparent')) {
        try {
          const contrast = getContrastRatio(borderColor, parentBg);
          if (contrast < 3) {
            issues.push({
              element: component.tagName.toLowerCase(),
              type: 'border',
              contrast: contrast.toFixed(2)
            });
          }
        } catch (e) {}
      }
    });
    
    if (issues.length > 0) {
      addResult('violation', '1.4.11', 'UI components have insufficient contrast', issues);
    } else {
      addResult('pass', '1.4.11', 'UI components meet contrast requirements');
    }
  })();
  
  // 1.4.12 Text Spacing (Level AA) - WCAG 2.1
  (() => {
    // This is difficult to test automatically
    // Flag for manual review
    const hasTextContent = document.body.textContent?.trim().length > 100;
    
    if (hasTextContent) {
      addResult('warning', '1.4.12', 'Verify text spacing can be adjusted without loss of content');
    } else {
      addResult('pass', '1.4.12', 'Text spacing requirements met');
    }
  })();
  
  // 1.4.13 Content on Hover or Focus (Level AA) - WCAG 2.1
  (() => {
    const issues = [];
    
    // Check for tooltips and hover content
    const hoverElements = document.querySelectorAll('[title]:not([title=""]), [data-tooltip], .tooltip');
    
    hoverElements.forEach(element => {
      const title = element.getAttribute('title');
      
      if (title && title.length > 0) {
        // Can't fully test hover behavior, but check for potential issues
        issues.push({
          element: element.tagName.toLowerCase(),
          hasTitle: true,
          titleLength: title.length
        });
      }
    });
    
    if (issues.length > 0) {
      addResult('warning', '1.4.13', 'Hover content should be dismissible and hoverable', issues);
    } else {
      addResult('pass', '1.4.13', 'Content on hover/focus properly implemented');
    }
  })();
  
  // ============================================
  // 2. OPERABLE - LEVEL AA
  // ============================================
  
  // 2.4.5 Multiple Ways (Level AA)
  (() => {
    const navigation = document.querySelector('nav, [role="navigation"]');
    const search = document.querySelector('input[type="search"], [role="search"]');
    const sitemap = document.querySelector('a[href*="sitemap"]');
    const breadcrumb = document.querySelector('[aria-label*="breadcrumb"], .breadcrumb');
    
    const waysFound = [navigation, search, sitemap, breadcrumb].filter(Boolean).length;
    
    if (waysFound < 2) {
      addResult('violation', '2.4.5', 'Less than two ways to navigate', {
        hasNavigation: !!navigation,
        hasSearch: !!search,
        hasSitemap: !!sitemap,
        hasBreadcrumb: !!breadcrumb
      });
    } else {
      addResult('pass', '2.4.5', 'Multiple ways to navigate are provided');
    }
  })();
  
  // 2.4.6 Headings and Labels (Level AA)
  (() => {
    const issues = [];
    
    // Check heading descriptiveness
    const headings = document.querySelectorAll('h1, h2, h3, h4, h5, h6');
    const genericHeadingTexts = ['untitled', 'heading', 'title', 'section'];
    
    headings.forEach(heading => {
      const text = heading.textContent?.trim().toLowerCase() || '';
      if (genericHeadingTexts.includes(text) || text.length < 3) {
        issues.push({
          level: heading.tagName.toLowerCase(),
          text: text
        });
      }
    });
    
    // Check label descriptiveness
    const labels = document.querySelectorAll('label');
    labels.forEach(label => {
      const text = label.textContent?.trim() || '';
      if (text.length < 2) {
        issues.push({
          type: 'label',
          text: text
        });
      }
    });
    
    if (issues.length > 0) {
      addResult('violation', '2.4.6', 'Headings or labels are not descriptive', issues);
    } else {
      addResult('pass', '2.4.6', 'Headings and labels are descriptive');
    }
  })();
  
  // 2.4.7 Focus Visible (Level AA)
  (() => {
    // Check for focus suppression
    const hasOutlineNone = Array.from(document.styleSheets).some(sheet => {
      try {
        return Array.from(sheet.cssRules || []).some(rule => 
          rule.cssText?.includes('outline: none') || 
          rule.cssText?.includes('outline:none') ||
          rule.cssText?.includes('outline: 0') ||
          rule.cssText?.includes('outline:0')
        );
      } catch {
        return false;
      }
    });
    
    if (hasOutlineNone) {
      addResult('warning', '2.4.7', 'CSS may suppress focus indicators');
    } else {
      addResult('pass', '2.4.7', 'Focus is visible');
    }
  })();
  
  // 2.4.11 Focus Not Obscured (Minimum) (Level AA) - WCAG 2.2
  (() => {
    const fixedElements = document.querySelectorAll('[style*="position: fixed"], [style*="position:fixed"]');
    const stickyElements = document.querySelectorAll('[style*="position: sticky"], [style*="position:sticky"]');
    
    const potentialObscurers = fixedElements.length + stickyElements.length;
    
    if (potentialObscurers > 3) {
      addResult('warning', '2.4.11', 'Multiple fixed/sticky elements may obscure focus', {
        fixed: fixedElements.length,
        sticky: stickyElements.length
      });
    } else {
      addResult('pass', '2.4.11', 'Focus unlikely to be obscured');
    }
  })();
  
  // 2.4.13 Focus Appearance (Level AA) - WCAG 2.2
  (() => {
    // This requires visual testing - flag for manual review
    addResult('warning', '2.4.13', 'Manual review needed: Verify focus indicators have 2px minimum thickness and 3:1 contrast');
  })();
  
  // 2.5.5 Target Size (Level AA) - WCAG 2.1 (Enhanced in 2.2 as 2.5.8)
  (() => {
    const issues = [];
    const interactiveElements = document.querySelectorAll('a, button, input[type="checkbox"], input[type="radio"]');
    
    interactiveElements.forEach(element => {
      const rect = element.getBoundingClientRect();
      
      // Check for 44x44 CSS pixels minimum (AA) / 24x24 (2.2)
      if (rect.width < 44 || rect.height < 44) {
        const styles = window.getComputedStyle(element);
        
        // Check for exceptions
        const isInline = styles.display === 'inline';
        const isInSentence = element.parentElement?.tagName === 'P';
        
        if (!isInline || !isInSentence) {
          issues.push({
            element: element.tagName.toLowerCase(),
            size: `${Math.round(rect.width)}x${Math.round(rect.height)}`,
            text: element.textContent?.substring(0, 20)
          });
        }
      }
    });
    
    if (issues.length > 0) {
      addResult('violation', '2.5.5', 'Interactive elements below minimum target size', issues);
    } else {
      addResult('pass', '2.5.5', 'Target sizes meet minimum requirements');
    }
  })();
  
  // 2.5.7 Dragging Movements (Level AA) - WCAG 2.2
  (() => {
    const draggables = document.querySelectorAll('[draggable="true"]');
    const issues = [];
    
    draggables.forEach(element => {
      // Check for keyboard alternatives
      const hasKeyHandler = element.onkeydown || element.onkeypress || element.onkeyup;
      const hasAriaGrabbed = element.hasAttribute('aria-grabbed');
      
      if (!hasKeyHandler && !hasAriaGrabbed) {
        issues.push({
          element: element.tagName.toLowerCase(),
          id: element.id
        });
      }
    });
    
    if (issues.length > 0) {
      addResult('violation', '2.5.7', 'Draggable elements lack keyboard alternatives', issues);
    } else if (draggables.length > 0) {
      addResult('pass', '2.5.7', 'Dragging has keyboard alternatives');
    }
  })();
  
  // 2.5.8 Target Size (Minimum) (Level AA) - WCAG 2.2
  (() => {
    const issues = [];
    const targets = document.querySelectorAll('a, button, input, select, textarea, [role="button"]');
    
    targets.forEach(target => {
      const rect = target.getBoundingClientRect();
      
      // 24x24 minimum for WCAG 2.2
      if (rect.width < 24 || rect.height < 24) {
        const isException = 
          target.closest('p') || // Inline in text
          target.hasAttribute('data-essential') || // Essential
          window.getComputedStyle(target).display === 'inline'; // Inline
        
        if (!isException) {
          issues.push({
            element: target.tagName.toLowerCase(),
            size: `${Math.round(rect.width)}x${Math.round(rect.height)}`
          });
        }
      }
    });
    
    if (issues.length > 0) {
      addResult('violation', '2.5.8', 'Targets below 24x24 minimum size', issues);
    } else {
      addResult('pass', '2.5.8', 'Target sizes meet WCAG 2.2 minimum');
    }
  })();
  
  // ============================================
  // 3. UNDERSTANDABLE - LEVEL AA
  // ============================================
  
  // 3.1.2 Language of Parts (Level AA)
  (() => {
    const elementsWithLang = document.querySelectorAll('[lang]');
    const issues = [];
    
    elementsWithLang.forEach(element => {
      const lang = element.getAttribute('lang');
      
      // Basic validation of language code
      if (!lang || lang.length < 2 || !lang.match(/^[a-z]{2,3}(-[A-Z]{2})?\$/)) {
        issues.push({
          element: element.tagName.toLowerCase(),
          lang: lang
        });
      }
    });
    
    if (issues.length > 0) {
      addResult('violation', '3.1.2', 'Invalid language codes on page parts', issues);
    } else {
      addResult('pass', '3.1.2', 'Language of parts properly specified');
    }
  })();
  
  // 3.2.3 Consistent Navigation (Level AA)
  (() => {
    const navs = document.querySelectorAll('nav, [role="navigation"]');
    
    if (navs.length > 1) {
      // Check if navigation items appear consistent
      addResult('warning', '3.2.3', 'Multiple navigation areas found - verify consistency across pages');
    } else if (navs.length === 1) {
      addResult('pass', '3.2.3', 'Navigation structure present');
    } else {
      addResult('warning', '3.2.3', 'No navigation structure found');
    }
  })();
  
  // 3.2.4 Consistent Identification (Level AA)
  (() => {
    // Check for consistent component patterns
    const buttons = document.querySelectorAll('button, [role="button"]');
    const buttonClasses = new Set();
    
    buttons.forEach(button => {
      if (button.className) {
        buttonClasses.add(button.className);
      }
    });
    
    // If there are many different button classes, might indicate inconsistency
    if (buttonClasses.size > 10 && buttons.length > 10) {
      addResult('warning', '3.2.4', 'Many different button styles detected - verify consistency', {
        uniqueStyles: buttonClasses.size,
        totalButtons: buttons.length
      });
    } else {
      addResult('pass', '3.2.4', 'Components appear consistently identified');
    }
  })();
  
  // 3.3.3 Error Suggestion (Level AA)
  (() => {
    const errorElements = document.querySelectorAll('[class*="error"], [role="alert"], .invalid');
    const issues = [];
    
    errorElements.forEach(error => {
      const text = error.textContent || '';
      const hasSuggestion = 
        text.includes('must') || 
        text.includes('should') || 
        text.includes('please') || 
        text.includes('format') ||
        text.includes('example');
      
      if (text.length > 0 && !hasSuggestion) {
        issues.push({
          errorText: text.substring(0, 50)
        });
      }
    });
    
    if (issues.length > 0) {
      addResult('violation', '3.3.3', 'Error messages lack suggestions', issues);
    } else if (errorElements.length > 0) {
      addResult('pass', '3.3.3', 'Error suggestions provided');
    }
  })();
  
  // 3.3.4 Error Prevention (Legal, Financial, Data) (Level AA)
  (() => {
    const forms = document.querySelectorAll('form');
    const importantForms = [];
    
    forms.forEach(form => {
      const hasPasswordField = form.querySelector('input[type="password"]');
      const hasCreditCardField = form.querySelector('[name*="card"], [name*="cc"]');
      const hasSubmit = form.querySelector('[type="submit"], button');
      
      if ((hasPasswordField || hasCreditCardField) && hasSubmit) {
        const hasConfirmation = form.querySelector('[name*="confirm"], [type="checkbox"]');
        
        if (!hasConfirmation) {
          importantForms.push({
            hasPassword: !!hasPasswordField,
            hasCreditCard: !!hasCreditCardField
          });
        }
      }
    });
    
    if (importantForms.length > 0) {
      addResult('warning', '3.3.4', 'Important forms may lack confirmation step', importantForms);
    } else if (forms.length > 0) {
      addResult('pass', '3.3.4', 'Forms have appropriate error prevention');
    }
  })();
  
  // 3.3.8 Accessible Authentication (No Exception) (Level AA) - WCAG 2.2
  (() => {
    const passwordFields = document.querySelectorAll('input[type="password"]');
    const issues = [];
    
    passwordFields.forEach(field => {
      const autocomplete = field.getAttribute('autocomplete');
      const hasPasteHandler = field.onpaste !== undefined;
      
      if (!autocomplete || autocomplete === 'off') {
        issues.push({
          field: field.name || field.id,
          autocomplete: autocomplete
        });
      }
      
      if (hasPasteHandler) {
        issues.push({
          field: field.name || field.id,
          issue: 'paste_restricted'
        });
      }
    });
    
    if (issues.length > 0) {
      addResult('violation', '3.3.8', 'Authentication fields lack proper support', issues);
    } else if (passwordFields.length > 0) {
      addResult('pass', '3.3.8', 'Authentication is accessible');
    }
  })();
  
  // ============================================
  // 4. ROBUST - LEVEL AA
  // ============================================
  
  // 4.1.3 Status Messages (Level AA) - WCAG 2.1
  (() => {
    const liveRegions = document.querySelectorAll('[aria-live], [role="status"], [role="alert"]');
    const issues = [];
    
    liveRegions.forEach(region => {
      const ariaLive = region.getAttribute('aria-live');
      const role = region.getAttribute('role');
      
      // Check if properly configured
      if (!role && !ariaLive) {
        issues.push({
          element: region.tagName.toLowerCase(),
          hasRole: false,
          hasAriaLive: false
        });
      }
      
      // Check if visible
      const styles = window.getComputedStyle(region);
      if (styles.display === 'none' || styles.visibility === 'hidden') {
        issues.push({
          element: region.tagName.toLowerCase(),
          issue: 'hidden_status_message'
        });
      }
    });
    
    if (issues.length > 0) {
      addResult('violation', '4.1.3', 'Status messages not properly announced', issues);
    } else if (liveRegions.length > 0) {
      addResult('pass', '4.1.3', 'Status messages properly configured');
    } else {
      addResult('warning', '4.1.3', 'No status message regions found');
    }
  })();
  
  // ============================================
  // SUMMARY
  // ============================================
  
  return {
    level: 'AA',
    standard: 'WCAG 2.2',
    violations: violations,
    warnings: warnings,
    passes: passes,
    summary: {
      totalViolations: violations.length,
      totalWarnings: warnings.length,
      totalPasses: passes.length,
      violationsByCriterion: violations.reduce((acc, v) => {
        acc[v.criterion] = (acc[v.criterion] || 0) + 1;
        return acc;
      }, {}),
      compliance: violations.length === 0 ? 'PASS' : 'FAIL'
    }
  };
}
    ''');
    
    // Store results
    ctx.wcag22LevelAA = results;
    
    // Log summary
    _logger.info('WCAG 2.2 Level AA Audit Complete:');
    _logger.info('  Violations: ${results['summary']['totalViolations']}');
    _logger.info('  Warnings: ${results['summary']['totalWarnings']}');
    _logger.info('  Passes: ${results['summary']['totalPasses']}');
    _logger.info('  Compliance: ${results['summary']['compliance']}');
  }
}

// Extension for AuditContext
extension WCAG22LevelAAContext on AuditContext {
  static final _wcag22LevelAA = Expando<Map<String, dynamic>>();
  
  Map<String, dynamic>? get wcag22LevelAA => _wcag22LevelAA[this];
  set wcag22LevelAA(Map<String, dynamic>? value) => _wcag22LevelAA[this] = value;
}