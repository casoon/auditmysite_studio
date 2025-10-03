import 'package:puppeteer/puppeteer.dart';
import 'package:logging/logging.dart';
import 'audit_base.dart';
import '../events.dart';

/// WCAG 2.2 Level A Compliance Audit
/// Implements all WCAG 2.2 Level A success criteria
class WCAG22LevelAAudit implements Audit {
  @override
  String get name => 'wcag22_level_a';
  
  final Logger _logger = Logger('WCAG22LevelA');
  
  @override
  Future<void> run(AuditContext ctx) async {
    final page = ctx.page as Page;
    
    _logger.info('Running WCAG 2.2 Level A audit');
    
    final results = await page.evaluate('''
async () => {
  const violations = [];
  const warnings = [];
  const passes = [];
  
  // Helper function to add result
  const addResult = (type, criterion, description, elements = []) => {
    const result = { criterion, description, elements: elements.slice(0, 5) };
    if (type === 'violation') violations.push(result);
    else if (type === 'warning') warnings.push(result);
    else if (type === 'pass') passes.push(result);
  };
  
  // ============================================
  // 1. PERCEIVABLE
  // ============================================
  
  // 1.1.1 Non-text Content (Level A)
  (() => {
    const images = document.querySelectorAll('img');
    const imagesWithoutAlt = [];
    const decorativeImagesWrongAlt = [];
    
    images.forEach(img => {
      if (!img.hasAttribute('alt')) {
        if (!img.hasAttribute('role') || img.getAttribute('role') !== 'presentation') {
          imagesWithoutAlt.push({
            src: img.src,
            location: img.getBoundingClientRect()
          });
        }
      } else if (img.getAttribute('role') === 'presentation' && img.alt !== '') {
        decorativeImagesWrongAlt.push({
          src: img.src,
          alt: img.alt
        });
      }
    });
    
    if (imagesWithoutAlt.length > 0) {
      addResult('violation', '1.1.1', 'Images without alt text', imagesWithoutAlt);
    } else {
      addResult('pass', '1.1.1', 'All images have appropriate alt text');
    }
    
    if (decorativeImagesWrongAlt.length > 0) {
      addResult('warning', '1.1.1', 'Decorative images should have empty alt text', decorativeImagesWrongAlt);
    }
  })();
  
  // 1.2.1 Audio-only and Video-only (Prerecorded) (Level A)
  (() => {
    const audioElements = document.querySelectorAll('audio');
    const videoElements = document.querySelectorAll('video');
    const mediaWithoutAlternatives = [];
    
    audioElements.forEach(audio => {
      const hasTranscript = audio.querySelector('track[kind="captions"]') ||
                          audio.querySelector('track[kind="descriptions"]') ||
                          (audio.id ? document.querySelector(`[aria-describedby="${audio.id}"]`) : null);
      
      if (!hasTranscript && audio.src) {
        mediaWithoutAlternatives.push({
          type: 'audio',
          src: audio.src
        });
      }
    });
    
    videoElements.forEach(video => {
      const hasCaptions = video.querySelector('track[kind="captions"]');
      const hasAudioDescription = video.querySelector('track[kind="descriptions"]');
      
      if (!hasCaptions && !hasAudioDescription && video.src) {
        mediaWithoutAlternatives.push({
          type: 'video',
          src: video.src
        });
      }
    });
    
    if (mediaWithoutAlternatives.length > 0) {
      addResult('violation', '1.2.1', 'Media content without text alternatives', mediaWithoutAlternatives);
    } else if (audioElements.length > 0 || videoElements.length > 0) {
      addResult('pass', '1.2.1', 'Media content has appropriate alternatives');
    }
  })();
  
  // 1.2.2 Captions (Prerecorded) (Level A)
  (() => {
    const videos = document.querySelectorAll('video');
    const videosWithoutCaptions = [];
    
    videos.forEach(video => {
      const hasCaptions = video.querySelector('track[kind="captions"]') ||
                         video.querySelector('track[kind="subtitles"]');
      
      // Check if video has audio track
      const hasAudio = !video.muted && video.volume > 0;
      
      if (hasAudio && !hasCaptions) {
        videosWithoutCaptions.push({
          src: video.src || 'inline video',
          hasControls: video.hasAttribute('controls')
        });
      }
    });
    
    if (videosWithoutCaptions.length > 0) {
      addResult('violation', '1.2.2', 'Videos with audio lack captions', videosWithoutCaptions);
    } else if (videos.length > 0) {
      addResult('pass', '1.2.2', 'Videos have appropriate captions');
    }
  })();
  
  // 1.2.3 Audio Description or Media Alternative (Prerecorded) (Level A)
  (() => {
    const videos = document.querySelectorAll('video');
    const videosNeedingDescription = [];
    
    videos.forEach(video => {
      const hasAudioDescription = video.querySelector('track[kind="descriptions"]');
      const hasTranscript = video.id ? document.querySelector(`[aria-describedby="${video.id}"]`) : null;
      
      if (!hasAudioDescription && !hasTranscript && video.src) {
        videosNeedingDescription.push({
          src: video.src || 'inline video'
        });
      }
    });
    
    if (videosNeedingDescription.length > 0) {
      addResult('warning', '1.2.3', 'Videos may need audio description', videosNeedingDescription);
    } else if (videos.length > 0) {
      addResult('pass', '1.2.3', 'Videos have audio descriptions or alternatives');
    }
  })();
  
  // 1.3.1 Info and Relationships (Level A)
  (() => {
    const issues = [];
    
    // Check heading structure
    const headings = document.querySelectorAll('h1, h2, h3, h4, h5, h6');
    let lastLevel = 0;
    let skippedLevels = false;
    
    headings.forEach(heading => {
      const level = parseInt(heading.tagName[1]);
      if (lastLevel > 0 && level > lastLevel + 1) {
        skippedLevels = true;
        issues.push({
          type: 'heading_skip',
          from: 'h' + lastLevel,
          to: heading.tagName.toLowerCase()
        });
      }
      lastLevel = level;
    });
    
    // Check for multiple h1s
    const h1s = document.querySelectorAll('h1');
    if (h1s.length > 1) {
      issues.push({
        type: 'multiple_h1',
        count: h1s.length
      });
    }
    
    // Check form labels
    const inputs = document.querySelectorAll('input:not([type="hidden"]):not([type="submit"]):not([type="button"]), select, textarea');
    const inputsWithoutLabels = [];
    
    inputs.forEach(input => {
      const inputId = input.id;
      const label = inputId ? document.querySelector(`label[for="${inputId}"]`) : null;
      const ariaLabel = input.getAttribute('aria-label');
      const ariaLabelledBy = input.getAttribute('aria-labelledby');
      const title = input.getAttribute('title');
      
      if (!label && !ariaLabel && !ariaLabelledBy && !title) {
        inputsWithoutLabels.push({
          type: input.type || input.tagName.toLowerCase(),
          name: input.name
        });
      }
    });
    
    if (inputsWithoutLabels.length > 0) {
      addResult('violation', '1.3.1', 'Form inputs without labels', inputsWithoutLabels);
    }
    
    if (skippedLevels) {
      addResult('violation', '1.3.1', 'Heading levels skipped', issues.filter(i => i.type === 'heading_skip'));
    }
    
    if (issues.filter(i => i.type === 'multiple_h1').length > 0) {
      addResult('warning', '1.3.1', 'Multiple H1 elements found', issues.filter(i => i.type === 'multiple_h1'));
    }
    
    if (issues.length === 0 && inputsWithoutLabels.length === 0) {
      addResult('pass', '1.3.1', 'Information and relationships properly conveyed');
    }
  })();
  
  // 1.3.2 Meaningful Sequence (Level A)
  (() => {
    // Check for layout tables without role="presentation"
    const tables = document.querySelectorAll('table');
    const layoutTables = [];
    
    tables.forEach(table => {
      const hasHeaders = table.querySelector('th') || table.querySelector('[scope]');
      const hasCaption = table.querySelector('caption');
      const role = table.getAttribute('role');
      
      // If no headers or caption, likely a layout table
      if (!hasHeaders && !hasCaption && role !== 'presentation') {
        layoutTables.push({
          classes: table.className,
          cellCount: table.querySelectorAll('td').length
        });
      }
    });
    
    if (layoutTables.length > 0) {
      addResult('warning', '1.3.2', 'Tables used for layout should have role="presentation"', layoutTables);
    } else {
      addResult('pass', '1.3.2', 'Content sequence is meaningful');
    }
  })();
  
  // 1.3.3 Sensory Characteristics (Level A)
  (() => {
    const issues = [];
    const bodyText = document.body.innerText.toLowerCase();
    
    // Check for sensory-only instructions
    const sensoryPhrases = [
      'click the red button',
      'click the green button',
      'click the blue button',
      'on the right',
      'on the left',
      'above',
      'below',
      'round button',
      'square button',
      'triangular'
    ];
    
    sensoryPhrases.forEach(phrase => {
      if (bodyText.includes(phrase)) {
        issues.push({
          phrase: phrase,
          context: bodyText.substring(bodyText.indexOf(phrase) - 20, bodyText.indexOf(phrase) + phrase.length + 20)
        });
      }
    });
    
    if (issues.length > 0) {
      addResult('warning', '1.3.3', 'Content may rely on sensory characteristics', issues);
    } else {
      addResult('pass', '1.3.3', 'Content does not rely solely on sensory characteristics');
    }
  })();
  
  // 1.4.1 Use of Color (Level A)
  (() => {
    const links = document.querySelectorAll('a');
    const linksOnlyColor = [];
    
    links.forEach(link => {
      const styles = window.getComputedStyle(link);
      const parentStyles = link.parentElement ? window.getComputedStyle(link.parentElement) : null;
      
      // Check if link is only distinguished by color
      const hasUnderline = styles.textDecoration.includes('underline');
      const hasBorder = styles.borderBottomStyle !== 'none';
      const hasBackground = styles.backgroundColor !== 'rgba(0, 0, 0, 0)' && 
                          (!parentStyles || styles.backgroundColor !== parentStyles.backgroundColor);
      const hasIcon = link.querySelector('img, svg, i, span[class*="icon"]');
      
      if (!hasUnderline && !hasBorder && !hasBackground && !hasIcon) {
        // Check if color is different from surrounding text
        if (parentStyles && styles.color !== parentStyles.color) {
          linksOnlyColor.push({
            text: link.textContent?.substring(0, 50),
            href: link.href
          });
        }
      }
    });
    
    if (linksOnlyColor.length > 0) {
      addResult('warning', '1.4.1', 'Links may be distinguished only by color', linksOnlyColor);
    } else {
      addResult('pass', '1.4.1', 'Color is not the only visual means of conveying information');
    }
  })();
  
  // 1.4.2 Audio Control (Level A)
  (() => {
    const autoplayMedia = document.querySelectorAll('audio[autoplay], video[autoplay]');
    const issues = [];
    
    autoplayMedia.forEach(media => {
      const hasControls = media.hasAttribute('controls');
      const duration = media.duration;
      
      // Check if plays for more than 3 seconds
      if (!hasControls || duration > 3) {
        const customControls = media.parentElement?.querySelector('[class*="pause"], [class*="stop"], [class*="mute"]');
        
        if (!customControls) {
          issues.push({
            type: media.tagName.toLowerCase(),
            duration: duration || 'unknown',
            hasControls: hasControls
          });
        }
      }
    });
    
    if (issues.length > 0) {
      addResult('violation', '1.4.2', 'Auto-playing audio without proper controls', issues);
    } else if (autoplayMedia.length > 0) {
      addResult('pass', '1.4.2', 'Auto-playing audio has proper controls');
    }
  })();
  
  // ============================================
  // 2. OPERABLE
  // ============================================
  
  // 2.1.1 Keyboard (Level A)
  (() => {
    const interactiveElements = document.querySelectorAll(
      'a[href], button, input, select, textarea, [onclick], [tabindex]'
    );
    const keyboardTraps = [];
    const inaccessibleElements = [];
    
    interactiveElements.forEach(element => {
      // Check for keyboard traps (elements with tabindex > 0)
      const tabindex = element.getAttribute('tabindex');
      if (tabindex && parseInt(tabindex) > 0) {
        keyboardTraps.push({
          element: element.tagName.toLowerCase(),
          tabindex: tabindex,
          text: element.textContent?.substring(0, 30)
        });
      }
      
      // Check for click handlers without keyboard handlers
      if (element.onclick && !element.onkeydown && !element.onkeypress && !element.onkeyup) {
        if (!['a', 'button', 'input', 'select', 'textarea'].includes(element.tagName.toLowerCase())) {
          inaccessibleElements.push({
            element: element.tagName.toLowerCase(),
            hasClick: true,
            hasKeyboard: false
          });
        }
      }
    });
    
    if (keyboardTraps.length > 0) {
      addResult('violation', '2.1.1', 'Potential keyboard traps (positive tabindex)', keyboardTraps);
    }
    
    if (inaccessibleElements.length > 0) {
      addResult('violation', '2.1.1', 'Interactive elements not keyboard accessible', inaccessibleElements);
    }
    
    if (keyboardTraps.length === 0 && inaccessibleElements.length === 0) {
      addResult('pass', '2.1.1', 'All functionality is keyboard accessible');
    }
  })();
  
  // 2.1.2 No Keyboard Trap (Level A)
  (() => {
    // Check for potential keyboard traps
    const iframes = document.querySelectorAll('iframe');
    const plugins = document.querySelectorAll('object, embed');
    const issues = [];
    
    iframes.forEach(iframe => {
      if (!iframe.title) {
        issues.push({
          type: 'iframe',
          src: iframe.src || 'inline'
        });
      }
    });
    
    if (plugins.length > 0) {
      issues.push({
        type: 'plugins',
        count: plugins.length
      });
    }
    
    if (issues.length > 0) {
      addResult('warning', '2.1.2', 'Potential keyboard trap areas', issues);
    } else {
      addResult('pass', '2.1.2', 'No keyboard traps detected');
    }
  })();
  
  // 2.1.4 Character Key Shortcuts (Level A) - WCAG 2.1
  (() => {
    const issues = [];
    
    // Check for single-key shortcuts
    const hasKeyListeners = document.body.onkeypress || document.body.onkeydown || document.body.onkeyup;
    
    if (hasKeyListeners) {
      issues.push({
        type: 'potential_shortcuts',
        note: 'Page has keyboard event listeners that may implement single-key shortcuts'
      });
    }
    
    // Look for common shortcut implementations
    const scripts = document.querySelectorAll('script');
    let hasShortcuts = false;
    
    scripts.forEach(script => {
      const content = script.textContent || '';
      if (content.includes('keyCode') || content.includes('which') || content.includes('key')) {
        if (content.match(/keyCode\\s*===?\\s*\\d{1,2}(?!\\d)/)) {
          hasShortcuts = true;
        }
      }
    });
    
    if (hasShortcuts) {
      addResult('warning', '2.1.4', 'Single character key shortcuts detected - ensure they can be turned off or remapped', []);
    } else {
      addResult('pass', '2.1.4', 'No problematic keyboard shortcuts detected');
    }
  })();
  
  // 2.2.1 Timing Adjustable (Level A)
  (() => {
    const issues = [];
    
    // Check for meta refresh
    const metaRefresh = document.querySelector('meta[http-equiv="refresh"]');
    if (metaRefresh) {
      const content = metaRefresh.getAttribute('content');
      const seconds = parseInt(content?.split(';')[0] || '0');
      
      if (seconds > 0) {
        issues.push({
          type: 'meta_refresh',
          seconds: seconds
        });
      }
    }
    
    // Check for session timeout indicators
    const sessionElements = document.querySelectorAll('[class*="session"], [id*="timeout"], [class*="expire"]');
    if (sessionElements.length === 0 && document.querySelectorAll('form').length > 0) {
      issues.push({
        type: 'no_timeout_warning',
        note: 'Forms present but no session timeout warning detected'
      });
    }
    
    if (issues.length > 0) {
      addResult('violation', '2.2.1', 'Time limits without user control', issues);
    } else {
      addResult('pass', '2.2.1', 'Time limits are adjustable or not present');
    }
  })();
  
  // 2.2.2 Pause, Stop, Hide (Level A)
  (() => {
    const issues = [];
    
    // Check for moving, blinking, scrolling content
    const animatedElements = document.querySelectorAll(
      '[style*="animation"], .carousel, .slider, marquee, blink'
    );
    
    animatedElements.forEach(element => {
      const controls = element.querySelector('[class*="pause"], [class*="stop"], button');
      const parentControls = element.parentElement?.querySelector('[class*="pause"], [class*="stop"], button');
      
      if (!controls && !parentControls) {
        const styles = window.getComputedStyle(element);
        const animationDuration = parseFloat(styles.animationDuration || '0');
        
        if (animationDuration > 5 || element.tagName === 'MARQUEE') {
          issues.push({
            type: element.tagName.toLowerCase(),
            duration: animationDuration || 'continuous'
          });
        }
      }
    });
    
    // Check for auto-updating content
    const liveRegions = document.querySelectorAll('[aria-live]:not([aria-live="off"])');
    liveRegions.forEach(region => {
      if (!region.querySelector('[class*="pause"], [class*="stop"]')) {
        issues.push({
          type: 'live_region',
          ariaLive: region.getAttribute('aria-live')
        });
      }
    });
    
    if (issues.length > 0) {
      addResult('violation', '2.2.2', 'Moving/auto-updating content without pause mechanism', issues);
    } else {
      addResult('pass', '2.2.2', 'Moving content can be paused or is not present');
    }
  })();
  
  // 2.3.1 Three Flashes or Below Threshold (Level A)
  (() => {
    // Check for potential flashing content
    const animatedElements = document.querySelectorAll('[style*="animation"]');
    const warnings = [];
    
    animatedElements.forEach(element => {
      const styles = window.getComputedStyle(element);
      const animationDuration = parseFloat(styles.animationDuration || '0');
      const animationIterationCount = styles.animationIterationCount;
      
      // Fast animations that repeat could cause flashing
      if (animationDuration > 0 && animationDuration < 0.5) {
        if (animationIterationCount === 'infinite' || parseInt(animationIterationCount) > 3) {
          warnings.push({
            duration: animationDuration,
            iterations: animationIterationCount
          });
        }
      }
    });
    
    // Check for GIFs (can't analyze content but flag for manual review)
    const gifs = document.querySelectorAll('img[src*=".gif"]');
    if (gifs.length > 0) {
      warnings.push({
        type: 'gif_images',
        count: gifs.length,
        note: 'GIF images should be reviewed for flashing content'
      });
    }
    
    if (warnings.length > 0) {
      addResult('warning', '2.3.1', 'Content may contain flashing', warnings);
    } else {
      addResult('pass', '2.3.1', 'No flashing content detected');
    }
  })();
  
  // 2.4.1 Bypass Blocks (Level A)
  (() => {
    const issues = [];
    
    // Check for skip links
    const skipLinks = document.querySelectorAll('a[href^="#"]:not([href="#"])');
    let hasSkipLink = false;
    
    skipLinks.forEach(link => {
      const text = link.textContent?.toLowerCase() || '';
      if (text.includes('skip') || text.includes('jump')) {
        hasSkipLink = true;
      }
    });
    
    // Check for landmarks
    const landmarks = document.querySelectorAll('main, nav, [role="main"], [role="navigation"]');
    
    // Check for heading structure
    const headings = document.querySelectorAll('h1, h2, h3, h4, h5, h6');
    
    if (!hasSkipLink && landmarks.length === 0 && headings.length < 3) {
      issues.push({
        hasSkipLink: false,
        landmarkCount: landmarks.length,
        headingCount: headings.length
      });
    }
    
    if (issues.length > 0) {
      addResult('violation', '2.4.1', 'No mechanism to bypass blocks of content', issues);
    } else {
      addResult('pass', '2.4.1', 'Bypass blocks mechanism present');
    }
  })();
  
  // 2.4.2 Page Titled (Level A)
  (() => {
    const title = document.title;
    
    if (!title || title.trim().length === 0) {
      addResult('violation', '2.4.2', 'Page has no title');
    } else if (title.length < 10 || title === 'Untitled' || title === 'Document') {
      addResult('warning', '2.4.2', 'Page title may not be descriptive', [{title: title}]);
    } else {
      addResult('pass', '2.4.2', 'Page has a descriptive title');
    }
  })();
  
  // 2.4.3 Focus Order (Level A)
  (() => {
    const issues = [];
    
    // Check for positive tabindex
    const positiveTabindex = document.querySelectorAll('[tabindex]:not([tabindex="0"]):not([tabindex="-1"])');
    
    positiveTabindex.forEach(element => {
      const tabindex = parseInt(element.getAttribute('tabindex') || '0');
      if (tabindex > 0) {
        issues.push({
          element: element.tagName.toLowerCase(),
          tabindex: tabindex,
          text: element.textContent?.substring(0, 30)
        });
      }
    });
    
    if (issues.length > 0) {
      addResult('violation', '2.4.3', 'Focus order may not be logical (positive tabindex used)', issues);
    } else {
      addResult('pass', '2.4.3', 'Focus order appears logical');
    }
  })();
  
  // 2.4.4 Link Purpose (In Context) (Level A)
  (() => {
    const issues = [];
    const links = document.querySelectorAll('a[href]');
    
    links.forEach(link => {
      const text = link.textContent?.trim() || '';
      const ariaLabel = link.getAttribute('aria-label');
      const title = link.getAttribute('title');
      
      // Check for non-descriptive link text
      const genericTexts = ['click here', 'read more', 'more', 'link', 'here', 'download', 'click'];
      
      if (genericTexts.includes(text.toLowerCase()) && !ariaLabel && !title) {
        issues.push({
          text: text,
          href: link.href.substring(0, 50)
        });
      }
      
      // Check for empty links
      if (!text && !ariaLabel && !link.querySelector('img')) {
        issues.push({
          text: 'Empty link',
          href: link.href.substring(0, 50)
        });
      }
    });
    
    if (issues.length > 0) {
      addResult('violation', '2.4.4', 'Links with unclear purpose', issues);
    } else {
      addResult('pass', '2.4.4', 'Link purposes are clear from context');
    }
  })();
  
  // 2.5.1 Pointer Gestures (Level A) - WCAG 2.1
  (() => {
    // Check for complex gestures
    const hasComplexGestures = 
      document.querySelector('[onswipe]') ||
      document.querySelector('[onpinch]') ||
      document.querySelector('[data-swipe]') ||
      document.querySelector('.swiper-container') ||
      document.querySelector('.carousel');
    
    if (hasComplexGestures) {
      addResult('warning', '2.5.1', 'Complex pointer gestures detected - ensure alternatives exist');
    } else {
      addResult('pass', '2.5.1', 'No complex pointer gestures detected');
    }
  })();
  
  // 2.5.2 Pointer Cancellation (Level A) - WCAG 2.1
  (() => {
    // Check for mousedown handlers without mouseup
    const elementsWithMousedown = document.querySelectorAll('[onmousedown]');
    const issues = [];
    
    elementsWithMousedown.forEach(element => {
      if (!element.onmouseup && !element.onclick) {
        issues.push({
          element: element.tagName.toLowerCase()
        });
      }
    });
    
    if (issues.length > 0) {
      addResult('warning', '2.5.2', 'Elements may activate on down-event', issues);
    } else {
      addResult('pass', '2.5.2', 'Pointer cancellation properly implemented');
    }
  })();
  
  // 2.5.3 Label in Name (Level A) - WCAG 2.1
  (() => {
    const issues = [];
    const labeledElements = document.querySelectorAll('button, a[href], [role="button"], [role="link"]');
    
    labeledElements.forEach(element => {
      const visibleText = element.textContent?.trim() || '';
      const ariaLabel = element.getAttribute('aria-label');
      
      if (visibleText && ariaLabel) {
        // Check if aria-label includes visible text
        if (!ariaLabel.toLowerCase().includes(visibleText.toLowerCase())) {
          issues.push({
            visibleText: visibleText.substring(0, 30),
            ariaLabel: ariaLabel.substring(0, 30)
          });
        }
      }
    });
    
    if (issues.length > 0) {
      addResult('violation', '2.5.3', 'Accessible name does not contain visible label', issues);
    } else {
      addResult('pass', '2.5.3', 'Labels match accessible names');
    }
  })();
  
  // 2.5.4 Motion Actuation (Level A) - WCAG 2.1
  (() => {
    // Check for device motion events
    const hasMotionEvents = 
      window.DeviceMotionEvent || 
      window.DeviceOrientationEvent;
    
    if (hasMotionEvents) {
      // Check if there's a way to disable motion
      const hasMotionToggle = document.querySelector('[class*="motion"], [id*="motion"], [aria-label*="motion"]');
      
      if (!hasMotionToggle) {
        addResult('warning', '2.5.4', 'Device motion may be used - ensure alternatives and disable option exist');
      } else {
        addResult('pass', '2.5.4', 'Motion actuation has alternatives');
      }
    } else {
      addResult('pass', '2.5.4', 'No motion actuation detected');
    }
  })();
  
  // ============================================
  // 3. UNDERSTANDABLE
  // ============================================
  
  // 3.1.1 Language of Page (Level A)
  (() => {
    const html = document.documentElement;
    const lang = html.getAttribute('lang') || html.getAttribute('xml:lang');
    
    if (!lang) {
      addResult('violation', '3.1.1', 'Page language not specified');
    } else if (lang.length < 2) {
      addResult('violation', '3.1.1', 'Invalid language code', [{lang: lang}]);
    } else {
      addResult('pass', '3.1.1', 'Page language properly specified');
    }
  })();
  
  // 3.2.1 On Focus (Level A)
  (() => {
    // This is difficult to test statically
    // Flag interactive elements for manual review
    const focusableElements = document.querySelectorAll(
      'a[href], button, input, select, textarea, [tabindex]:not([tabindex="-1"])'
    );
    
    if (focusableElements.length > 0) {
      addResult('warning', '3.2.1', 'Review that focus does not trigger context changes', [{count: focusableElements.length}]);
    }
  })();
  
  // 3.2.2 On Input (Level A)
  (() => {
    // Check for forms without submit buttons (might auto-submit)
    const forms = document.querySelectorAll('form');
    const issues = [];
    
    forms.forEach(form => {
      const submitButton = form.querySelector('input[type="submit"], button[type="submit"], button:not([type])');
      const hasOnChange = form.querySelector('[onchange]');
      
      if (!submitButton && hasOnChange) {
        issues.push({
          formName: form.name || form.id || 'unnamed'
        });
      }
    });
    
    if (issues.length > 0) {
      addResult('warning', '3.2.2', 'Forms may auto-submit on input', issues);
    } else {
      addResult('pass', '3.2.2', 'Input does not cause unexpected context changes');
    }
  })();
  
  // 3.3.1 Error Identification (Level A)
  (() => {
    // Check for error message patterns
    const errorPatterns = document.querySelectorAll(
      '[class*="error"], [id*="error"], [role="alert"], .invalid, .validation-message'
    );
    
    if (errorPatterns.length > 0) {
      // Check if errors are properly associated
      const issues = [];
      
      errorPatterns.forEach(error => {
        const isHidden = window.getComputedStyle(error).display === 'none';
        const hasText = error.textContent?.trim().length > 0;
        
        if (!isHidden && !hasText) {
          issues.push({
            type: 'empty_error'
          });
        }
      });
      
      if (issues.length > 0) {
        addResult('warning', '3.3.1', 'Error messages may not be properly identified', issues);
      } else {
        addResult('pass', '3.3.1', 'Errors are properly identified');
      }
    }
  })();
  
  // 3.3.2 Labels or Instructions (Level A)
  (() => {
    const issues = [];
    const inputs = document.querySelectorAll('input:not([type="hidden"]):not([type="submit"]):not([type="button"]), select, textarea');
    
    inputs.forEach(input => {
      const label = input.id ? document.querySelector(`label[for="${input.id}"]`) : null;
      const ariaLabel = input.getAttribute('aria-label');
      const placeholder = input.getAttribute('placeholder');
      const title = input.getAttribute('title');
      
      // Check if input has any labeling
      if (!label && !ariaLabel && !title) {
        if (placeholder) {
          // Placeholder alone is not sufficient
          issues.push({
            type: input.type || input.tagName.toLowerCase(),
            placeholder: placeholder
          });
        } else {
          issues.push({
            type: input.type || input.tagName.toLowerCase(),
            name: input.name
          });
        }
      }
    });
    
    if (issues.length > 0) {
      addResult('violation', '3.3.2', 'Form inputs lack proper labels or instructions', issues);
    } else {
      addResult('pass', '3.3.2', 'Form inputs have proper labels or instructions');
    }
  })();
  
  // ============================================
  // 4. ROBUST
  // ============================================
  
  // 4.1.1 Parsing (Level A) - Deprecated in WCAG 2.2
  (() => {
    // Still check for basic parsing issues
    const issues = [];
    
    // Check for duplicate IDs
    const ids = {};
    document.querySelectorAll('[id]').forEach(element => {
      const id = element.id;
      if (ids[id]) {
        issues.push({
          type: 'duplicate_id',
          id: id
        });
      }
      ids[id] = true;
    });
    
    if (issues.length > 0) {
      addResult('warning', '4.1.1', 'HTML parsing issues found', issues);
    } else {
      addResult('pass', '4.1.1', 'No parsing issues detected');
    }
  })();
  
  // 4.1.2 Name, Role, Value (Level A)
  (() => {
    const issues = [];
    
    // Check custom controls
    const customControls = document.querySelectorAll('[role="button"], [role="checkbox"], [role="radio"], [role="slider"]');
    
    customControls.forEach(control => {
      const role = control.getAttribute('role');
      const ariaLabel = control.getAttribute('aria-label');
      const ariaLabelledBy = control.getAttribute('aria-labelledby');
      const text = control.textContent?.trim();
      
      // Check for accessible name
      if (!ariaLabel && !ariaLabelledBy && !text) {
        issues.push({
          role: role,
          element: control.tagName.toLowerCase()
        });
      }
      
      // Check for required ARIA states
      if (role === 'checkbox' || role === 'radio') {
        if (!control.hasAttribute('aria-checked')) {
          issues.push({
            role: role,
            missing: 'aria-checked'
          });
        }
      }
      
      if (role === 'slider') {
        if (!control.hasAttribute('aria-valuenow')) {
          issues.push({
            role: role,
            missing: 'aria-valuenow'
          });
        }
      }
    });
    
    if (issues.length > 0) {
      addResult('violation', '4.1.2', 'Custom controls missing name, role, or value', issues);
    } else {
      addResult('pass', '4.1.2', 'Controls have proper name, role, and value');
    }
  })();
  
  // ============================================
  // WCAG 2.2 NEW CRITERIA - LEVEL A
  // ============================================
  
  // 3.2.6 Consistent Help (Level A) - NEW in WCAG 2.2
  (() => {
    const helpElements = document.querySelectorAll(
      '[aria-label*="help"], [title*="help"], [href*="help"], [href*="support"], [href*="contact"], .help, #help'
    );
    
    if (helpElements.length === 0) {
      addResult('warning', '3.2.6', 'No help mechanism found on page');
    } else {
      // Check consistency (position)
      const positions = Array.from(helpElements).map(el => {
        const rect = el.getBoundingClientRect();
        return {
          top: Math.round(rect.top),
          left: Math.round(rect.left)
        };
      });
      
      // Check if help is in consistent location (header or footer typically)
      const uniquePositions = new Set(positions.map(pos => `${pos.top},${pos.left}`));
      
      if (uniquePositions.size > 3) {
        addResult('warning', '3.2.6', 'Help mechanisms may not be consistently positioned', [{count: uniquePositions.size}]);
      } else {
        addResult('pass', '3.2.6', 'Help mechanism is consistently available');
      }
    }
  })();
  
  // 3.3.7 Redundant Entry (Level A) - NEW in WCAG 2.2
  (() => {
    // Check for proper autocomplete attributes
    const personalInfoFields = document.querySelectorAll(
      'input[type="text"], input[type="email"], input[type="tel"]'
    );
    const issues = [];
    
    personalInfoFields.forEach(field => {
      const name = field.name?.toLowerCase() || '';
      const id = field.id?.toLowerCase() || '';
      const autocomplete = field.getAttribute('autocomplete');
      
      // Check if field appears to be for personal info
      const personalPatterns = ['name', 'email', 'phone', 'address', 'postal', 'zip'];
      const isPersonalInfo = personalPatterns.some(pattern => 
        name.includes(pattern) || id.includes(pattern)
      );
      
      if (isPersonalInfo && (!autocomplete || autocomplete === 'off')) {
        issues.push({
          field: field.name || field.id,
          type: field.type
        });
      }
    });
    
    if (issues.length > 0) {
      addResult('violation', '3.3.7', 'Personal information fields should support autocomplete', issues);
    } else {
      addResult('pass', '3.3.7', 'Redundant entry is avoided');
    }
  })();
  
  // ============================================
  // SUMMARY
  // ============================================
  
  return {
    level: 'A',
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
    ctx.wcag22LevelA = results;
    
    // Log summary
    _logger.info('WCAG 2.2 Level A Audit Complete:');
    _logger.info('  Violations: ${results['summary']['totalViolations']}');
    _logger.info('  Warnings: ${results['summary']['totalWarnings']}');
    _logger.info('  Passes: ${results['summary']['totalPasses']}');
    _logger.info('  Compliance: ${results['summary']['compliance']}');
  }
}

// Extension for AuditContext
extension WCAG22LevelAContext on AuditContext {
  static final _wcag22LevelA = Expando<Map<String, dynamic>>();
  
  Map<String, dynamic>? get wcag22LevelA => _wcag22LevelA[this];
  set wcag22LevelA(Map<String, dynamic>? value) => _wcag22LevelA[this] = value;
}