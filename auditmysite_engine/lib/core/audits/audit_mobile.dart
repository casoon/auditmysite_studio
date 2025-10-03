import '../events.dart';
import 'audit_base.dart';

class MobileAudit extends Audit {
  @override
  String get name => 'mobile';

  @override
  Future<void> run(AuditContext ctx) async {
    final page = ctx.page;
    
    // Mobile-spezifische Checks durchführen
    final mobileData = await page.evaluate(r'''
() => {
        const issues = [];
        let score = 100;
        
        // 1. Viewport Meta-Tag prüfen
        const viewportMeta = document.querySelector('meta[name="viewport"]');
        const viewportCheck = {
          exists: !!viewportMeta,
          content: viewportMeta ? viewportMeta.getAttribute('content') : null,
          isResponsive: false,
          hasUserScalable: true
        };
        
        if (viewportMeta) {
          const content = viewportMeta.getAttribute('content') || '';
          viewportCheck.isResponsive = content.includes('width=device-width');
          viewportCheck.hasUserScalable = !content.includes('user-scalable=no') && !content.includes('user-scalable=0');
          
          if (!viewportCheck.isResponsive) {
            issues.push({
              category: 'viewport',
              severity: 'error',
              message: 'Viewport meta tag missing width=device-width',
              impact: 'Page will not be responsive on mobile devices'
            });
            score -= 25;
          }
          
          if (!viewportCheck.hasUserScalable) {
            issues.push({
              category: 'accessibility',
              severity: 'warning', 
              message: 'User scaling is disabled',
              impact: 'Users cannot zoom for better readability'
            });
            score -= 10;
          }
        } else {
          issues.push({
            category: 'viewport',
            severity: 'error',
            message: 'Viewport meta tag is missing',
            impact: 'Page will not display correctly on mobile devices'
          });
          score -= 30;
        }
        
        // 2. Touch-Target-Größe prüfen
        const touchTargets = [];
        const clickableElements = document.querySelectorAll('a, button, input[type="button"], input[type="submit"], input[type="reset"], [onclick], [role="button"]');
        let smallTouchTargets = 0;
        
        clickableElements.forEach((el, index) => {
          const rect = el.getBoundingClientRect();
          const computedStyle = window.getComputedStyle(el);
          const padding = {
            top: parseFloat(computedStyle.paddingTop),
            right: parseFloat(computedStyle.paddingRight),
            bottom: parseFloat(computedStyle.paddingBottom),
            left: parseFloat(computedStyle.paddingLeft)
          };
          
          const touchArea = {
            width: rect.width + padding.left + padding.right,
            height: rect.height + padding.top + padding.bottom
          };
          
          const isVisible = rect.width > 0 && rect.height > 0 && 
                           computedStyle.visibility !== 'hidden' && 
                           computedStyle.display !== 'none';
          
          if (isVisible) {
            const isTooSmall = touchArea.width < 44 || touchArea.height < 44; // 44px ist Apple's Empfehlung
            
            if (isTooSmall) {
              smallTouchTargets++;
              touchTargets.push({
                element: el.tagName.toLowerCase() + (el.id ? '#' + el.id : '') + (el.className ? '.' + el.className.split(' ')[0] : ''),
                width: Math.round(touchArea.width),
                height: Math.round(touchArea.height),
                text: el.textContent?.trim().substring(0, 50) || 'No text',
                isTooSmall: true
              });
            }
          }
        });
        
        if (smallTouchTargets > 0) {
          issues.push({
            category: 'touch_targets',
            severity: smallTouchTargets > 5 ? 'error' : 'warning',
            message: `\${smallTouchTargets} touch targets smaller than 44px`,
            impact: 'Small touch targets are difficult to tap on mobile',
            count: smallTouchTargets
          });
          score -= Math.min(smallTouchTargets * 3, 20);
        }
        
        // 3. Text-Lesbarkeit prüfen  
        const textElements = document.querySelectorAll('p, span, div, h1, h2, h3, h4, h5, h6, li, td, th');
        let smallTextElements = 0;
        const textSizes = [];
        
        textElements.forEach(el => {
          const computedStyle = window.getComputedStyle(el);
          const fontSize = parseFloat(computedStyle.fontSize);
          const isVisible = el.offsetParent !== null;
          
          if (isVisible && fontSize > 0) {
            textSizes.push(fontSize);
            if (fontSize < 16) { // Unter 16px ist auf Mobile schwer lesbar
              smallTextElements++;
            }
          }
        });
        
        if (smallTextElements > textElements.length * 0.3) { // Mehr als 30% kleiner Text
          issues.push({
            category: 'text_size',
            severity: 'warning',
            message: `\${smallTextElements} elements with text smaller than 16px`,
            impact: 'Small text is hard to read on mobile devices'
          });
          score -= 15;
        }
        
        // 4. Horizontales Scrolling prüfen
        const hasHorizontalScroll = document.documentElement.scrollWidth > window.innerWidth;
        
        if (hasHorizontalScroll) {
          issues.push({
            category: 'horizontal_scroll',
            severity: 'warning', 
            message: 'Page has horizontal scrolling',
            impact: 'Horizontal scrolling creates poor mobile UX',
            pageWidth: document.documentElement.scrollWidth,
            viewportWidth: window.innerWidth
          });
          score -= 10;
        }
        
        // 5. Flash/Plugin Content prüfen
        const flashElements = document.querySelectorAll('object, embed, applet');
        if (flashElements.length > 0) {
          issues.push({
            category: 'plugins',
            severity: 'error',
            message: `\${flashElements.length} Flash/Plugin elements found`,
            impact: 'Flash and plugins are not supported on mobile devices'
          });
          score -= 20;
        }
        
        // 6. Responsive Images prüfen
        const images = document.querySelectorAll('img');
        let nonResponsiveImages = 0;
        
        images.forEach(img => {
          const hasResponsiveAttributes = img.hasAttribute('srcset') || 
                                        img.hasAttribute('sizes') ||
                                        img.style.maxWidth === '100%' ||
                                        img.style.width === '100%';
          
          if (!hasResponsiveAttributes && img.offsetParent !== null) {
            nonResponsiveImages++;
          }
        });
        
        if (nonResponsiveImages > 0 && images.length > 0) {
          const ratio = nonResponsiveImages / images.length;
          if (ratio > 0.5) { // Mehr als 50% nicht-responsive
            issues.push({
              category: 'responsive_images',
              severity: 'warning',
              message: `\${nonResponsiveImages}/\${images.length} images may not be responsive`,
              impact: 'Non-responsive images can cause horizontal scrolling'
            });
            score -= 8;
          }
        }
        
        // 7. Mobile-optimierte Input-Types prüfen
        const inputs = document.querySelectorAll('input');
        let nonOptimizedInputs = 0;
        
        inputs.forEach(input => {
          const type = input.type.toLowerCase();
          const name = input.name?.toLowerCase() || '';
          const id = input.id?.toLowerCase() || '';
          
          // Prüfe ob passender Input-Type verwendet wird
          if ((name.includes('email') || id.includes('email')) && type !== 'email') {
            nonOptimizedInputs++;
          } else if ((name.includes('tel') || name.includes('phone') || id.includes('tel') || id.includes('phone')) && type !== 'tel') {
            nonOptimizedInputs++;
          } else if ((name.includes('number') || id.includes('number')) && type !== 'number') {
            nonOptimizedInputs++;
          }
        });
        
        if (nonOptimizedInputs > 0) {
          issues.push({
            category: 'input_types',
            severity: 'info',
            message: `\${nonOptimizedInputs} inputs could use mobile-optimized types`,
            impact: 'Proper input types show better mobile keyboards'
          });
          score -= 5;
        }
        
        // Empfehlungen generieren
        const recommendations = [];
        
        if (!viewportCheck.exists || !viewportCheck.isResponsive) {
          recommendations.push({
            category: 'viewport',
            priority: 'critical',
            message: 'Add responsive viewport meta tag',
            implementation: '<meta name="viewport" content="width=device-width, initial-scale=1">'
          });
        }
        
        if (smallTouchTargets > 0) {
          recommendations.push({
            category: 'touch_targets', 
            priority: 'high',
            message: 'Increase touch target sizes to at least 44px',
            implementation: 'Use CSS padding or min-width/min-height properties'
          });
        }
        
        if (smallTextElements > 5) {
          recommendations.push({
            category: 'typography',
            priority: 'medium', 
            message: 'Increase text size for better mobile readability',
            implementation: 'Use font-size: 16px or larger for body text'
          });
        }
        
        if (hasHorizontalScroll) {
          recommendations.push({
            category: 'layout',
            priority: 'high',
            message: 'Eliminate horizontal scrolling',
            implementation: 'Use flexible layouts, CSS Grid, or Flexbox'
          });
        }
        
        // Score begrenzen
        score = Math.max(0, Math.min(100, score));
        
        // Grade zuweisen
        let grade;
        if (score >= 90) grade = 'A';
        else if (score >= 80) grade = 'B'; 
        else if (score >= 70) grade = 'C';
        else if (score >= 60) grade = 'D';
        else grade = 'F';
        
        return {
          viewport: viewportCheck,
          touchTargets: {
            total: clickableElements.length,
            tooSmall: smallTouchTargets,
            details: touchTargets.slice(0, 10) // Limit für Performance
          },
          textReadability: {
            totalElements: textElements.length,
            smallTextElements: smallTextElements,
            averageFontSize: textSizes.length > 0 ? Math.round(textSizes.reduce((a, b) => a + b) / textSizes.length) : 0
          },
          layout: {
            hasHorizontalScroll: hasHorizontalScroll,
            pageWidth: document.documentElement.scrollWidth,
            viewportWidth: window.innerWidth
          },
          images: {
            total: images.length,
            nonResponsive: nonResponsiveImages
          },
          inputs: {
            total: inputs.length,
            nonOptimized: nonOptimizedInputs
          },
          issues: issues,
          recommendations: recommendations,
          score: Math.round(score),
          grade: grade,
          timestamp: new Date().toISOString()
        };
}
    ''');
    
    ctx.mobileResult = mobileData;
  }
}
