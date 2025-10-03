import 'dart:convert';
import 'package:puppeteer/puppeteer.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'package:logging/logging.dart';
import 'audit_base.dart';

/// HTML5 Validation and Semantic HTML Audit
class HTMLValidationAudit implements Audit {
  @override
  String get name => 'html_validation';
  
  final Logger _logger = Logger('HTMLValidationAudit');
  
  // HTML5 semantic elements
  static const Set<String> semanticElements = {
    'article', 'aside', 'details', 'figcaption', 'figure',
    'footer', 'header', 'main', 'mark', 'nav', 'section',
    'summary', 'time', 'dialog', 'menu', 'menuitem'
  };
  
  // Deprecated HTML elements
  static const Set<String> deprecatedElements = {
    'acronym', 'applet', 'basefont', 'bgsound', 'big', 'blink',
    'center', 'dir', 'font', 'frame', 'frameset', 'isindex',
    'keygen', 'listing', 'marquee', 'multicol', 'nextid', 'nobr',
    'noembed', 'noframes', 'plaintext', 's', 'spacer', 'strike',
    'tt', 'u', 'xmp'
  };
  
  // ARIA roles
  static const Set<String> ariaRoles = {
    'alert', 'alertdialog', 'application', 'article', 'banner',
    'button', 'checkbox', 'columnheader', 'combobox', 'command',
    'complementary', 'composite', 'contentinfo', 'definition',
    'dialog', 'directory', 'document', 'feed', 'figure', 'form',
    'grid', 'gridcell', 'group', 'heading', 'img', 'input',
    'landmark', 'link', 'list', 'listbox', 'listitem', 'log',
    'main', 'marquee', 'math', 'menu', 'menubar', 'menuitem',
    'menuitemcheckbox', 'menuitemradio', 'navigation', 'none',
    'note', 'option', 'presentation', 'progressbar', 'radio',
    'radiogroup', 'range', 'region', 'roletype', 'row', 'rowgroup',
    'rowheader', 'scrollbar', 'search', 'searchbox', 'section',
    'sectionhead', 'select', 'separator', 'slider', 'spinbutton',
    'status', 'structure', 'switch', 'tab', 'tablist', 'tabpanel',
    'term', 'textbox', 'timer', 'toolbar', 'tooltip', 'tree',
    'treegrid', 'treeitem', 'widget', 'window'
  };

  @override
  Future<void> run(AuditContext ctx) async {
    final page = ctx.page as Page;
    final url = ctx.url.toString();
    
    final validationResults = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'url': url,
      'doctype': {},
      'structure': {},
      'semanticHTML': {},
      'aria': {},
      'forms': {},
      'duplicates': {},
      'deprecated': {},
      'metadata': {},
      'links': {},
      'images': {},
      'tables': {},
      'lists': {},
      'headings': {},
      'score': 0,
      'issues': [],
      'recommendations': []
    };
    
    try {
      // Get the HTML content
      final htmlContent = await page.content();
      final document = html_parser.parse(htmlContent);
      
      // 1. Check DOCTYPE
      validationResults['doctype'] = _checkDoctype(htmlContent);
      
      // 2. Validate HTML structure
      validationResults['structure'] = _validateStructure(document);
      
      // 3. Check semantic HTML usage
      validationResults['semanticHTML'] = _checkSemanticHTML(document);
      
      // 4. ARIA validation
      validationResults['aria'] = await _validateARIA(page, document);
      
      // 5. Form validation
      validationResults['forms'] = _validateForms(document);
      
      // 6. Check for duplicate IDs
      validationResults['duplicates'] = _checkDuplicates(document);
      
      // 7. Check deprecated elements
      validationResults['deprecated'] = _checkDeprecatedElements(document);
      
      // 8. Validate metadata
      validationResults['metadata'] = _validateMetadata(document);
      
      // 9. Validate links
      validationResults['links'] = _validateLinks(document);
      
      // 10. Validate images
      validationResults['images'] = _validateImages(document);
      
      // 11. Validate tables
      validationResults['tables'] = _validateTables(document);
      
      // 12. Validate lists
      validationResults['lists'] = _validateLists(document);
      
      // 13. Validate heading hierarchy
      validationResults['headings'] = _validateHeadings(document);
      
      // 14. Check for inline styles and scripts
      validationResults['inline'] = _checkInlineContent(document);
      
      // 15. Validate language attributes
      validationResults['language'] = _validateLanguage(document);
      
      // Calculate score
      final scoring = _calculateScore(validationResults);
      validationResults['score'] = scoring['score'];
      validationResults['grade'] = scoring['grade'];
      validationResults['summary'] = scoring['summary'];
      
      // Identify issues
      validationResults['issues'] = _identifyIssues(validationResults);
      
      // Generate recommendations
      validationResults['recommendations'] = _generateRecommendations(validationResults);
      
      // Store in context
      ctx.htmlValidation = validationResults;
      
    } catch (e) {
      _logger.severe('Error in HTML validation audit: $e');
      validationResults['error'] = e.toString();
      ctx.htmlValidation = validationResults;
    }
  }
  
  Map<String, dynamic> _checkDoctype(String html) {
    final doctype = <String, dynamic>{
      'present': false,
      'isHTML5': false,
      'value': '',
      'issues': []
    };
    
    // Check for DOCTYPE declaration
    final doctypeRegex = RegExp(r'<!DOCTYPE\s+([^>]+)>', caseSensitive: false);
    final match = doctypeRegex.firstMatch(html);
    
    if (match != null) {
      doctype['present'] = true;
      doctype['value'] = match.group(1)?.trim() ?? '';
      
      // Check if it's HTML5 doctype
      if (doctype['value'].toLowerCase() == 'html') {
        doctype['isHTML5'] = true;
      } else {
        doctype['issues'].add('Non-HTML5 DOCTYPE detected');
      }
    } else {
      doctype['issues'].add('Missing DOCTYPE declaration');
    }
    
    return doctype;
  }
  
  Map<String, dynamic> _validateStructure(dom.Document document) {
    final structure = <String, dynamic>{
      'hasHtml': false,
      'hasHead': false,
      'hasBody': false,
      'hasTitle': false,
      'hasCharset': false,
      'hasViewport': false,
      'issues': []
    };
    
    // Check for essential elements
    structure['hasHtml'] = document.querySelector('html') != null;
    structure['hasHead'] = document.querySelector('head') != null;
    structure['hasBody'] = document.querySelector('body') != null;
    structure['hasTitle'] = document.querySelector('title') != null;
    structure['hasCharset'] = document.querySelector('meta[charset]') != null;
    structure['hasViewport'] = document.querySelector('meta[name="viewport"]') != null;
    
    // Generate issues
    if (!structure['hasHtml']) {
      structure['issues'].add('Missing <html> element');
    }
    if (!structure['hasHead']) {
      structure['issues'].add('Missing <head> element');
    }
    if (!structure['hasBody']) {
      structure['issues'].add('Missing <body> element');
    }
    if (!structure['hasTitle']) {
      structure['issues'].add('Missing <title> element');
    }
    if (!structure['hasCharset']) {
      structure['issues'].add('Missing charset meta tag');
    }
    
    // Check for proper nesting
    final bodyInHead = document.querySelector('head body');
    if (bodyInHead != null) {
      structure['issues'].add('Improper nesting: <body> found inside <head>');
    }
    
    final headInBody = document.querySelector('body head');
    if (headInBody != null) {
      structure['issues'].add('Improper nesting: <head> found inside <body>');
    }
    
    return structure;
  }
  
  Map<String, dynamic> _checkSemanticHTML(dom.Document document) {
    final semantic = <String, dynamic>{
      'usesSemanticElements': false,
      'elements': {},
      'score': 0,
      'issues': []
    };
    
    // Count semantic elements
    for (final element in semanticElements) {
      final elements = document.querySelectorAll(element);
      if (elements.isNotEmpty) {
        semantic['usesSemanticElements'] = true;
        semantic['elements'][element] = elements.length;
      }
    }
    
    // Check for non-semantic patterns
    final divSoup = document.querySelectorAll('div').length;
    final totalElements = document.querySelectorAll('*').length;
    
    if (totalElements > 0) {
      final divRatio = divSoup / totalElements;
      if (divRatio > 0.3) {
        semantic['issues'].add('High ratio of <div> elements (${(divRatio * 100).round()}%)');
      }
    }
    
    // Check for missing semantic elements
    if (document.querySelector('nav') == null) {
      semantic['issues'].add('No <nav> element found');
    }
    
    if (document.querySelector('main') == null) {
      semantic['issues'].add('No <main> element found');
    }
    
    if (document.querySelector('header') == null && 
        document.querySelector('[role="banner"]') == null) {
      semantic['issues'].add('No <header> element found');
    }
    
    if (document.querySelector('footer') == null &&
        document.querySelector('[role="contentinfo"]') == null) {
      semantic['issues'].add('No <footer> element found');
    }
    
    // Calculate semantic score
    int score = 0;
    if (semantic['usesSemanticElements']) score += 50;
    if (document.querySelector('nav') != null) score += 10;
    if (document.querySelector('main') != null) score += 15;
    if (document.querySelector('header') != null) score += 10;
    if (document.querySelector('footer') != null) score += 10;
    if (document.querySelector('article') != null) score += 5;
    
    semantic['score'] = score;
    
    return semantic;
  }
  
  Future<Map<String, dynamic>> _validateARIA(Page page, dom.Document document) async {
    final aria = <String, dynamic>{
      'rolesUsed': [],
      'invalidRoles': [],
      'missingLabels': [],
      'invalidAttributes': [],
      'issues': []
    };
    
    // Check ARIA roles
    final elementsWithRoles = document.querySelectorAll('[role]');
    for (final element in elementsWithRoles) {
      final role = element.attributes['role'];
      if (role != null) {
        aria['rolesUsed'].add(role);
        if (!ariaRoles.contains(role)) {
          aria['invalidRoles'].add({
            'element': element.localName,
            'role': role
          });
        }
      }
    }
    
    // Check for elements that need labels
    final interactiveElements = document.querySelectorAll(
      'button, input, select, textarea, [role="button"], [role="checkbox"], [role="radio"]'
    );
    
    for (final element in interactiveElements) {
      final hasLabel = element.attributes['aria-label'] != null ||
                       element.attributes['aria-labelledby'] != null ||
                       _hasAssociatedLabel(element, document);
      
      if (!hasLabel) {
        aria['missingLabels'].add({
          'element': element.localName,
          'id': element.attributes['id'],
          'type': element.attributes['type']
        });
      }
    }
    
    // Check for invalid ARIA attribute combinations via JavaScript
    final ariaValidation = await page.evaluate('''() => {
      const issues = [];
      
      // Check for aria-hidden on focusable elements
      document.querySelectorAll('[aria-hidden="true"]').forEach(el => {
        if (el.tabIndex >= 0 || el.matches('a[href], button, input, select, textarea')) {
          issues.push({
            type: 'aria-hidden-focusable',
            element: el.tagName.toLowerCase(),
            message: 'aria-hidden used on focusable element'
          });
        }
      });
      
      // Check for required ARIA properties
      document.querySelectorAll('[role]').forEach(el => {
        const role = el.getAttribute('role');
        
        // Check for required properties based on role
        if (role === 'checkbox' || role === 'radio') {
          if (!el.hasAttribute('aria-checked')) {
            issues.push({
              type: 'missing-required-aria',
              element: el.tagName.toLowerCase(),
              role: role,
              message: 'Missing required aria-checked'
            });
          }
        }
        
        if (role === 'combobox') {
          if (!el.hasAttribute('aria-expanded')) {
            issues.push({
              type: 'missing-required-aria',
              element: el.tagName.toLowerCase(),
              role: role,
              message: 'Missing required aria-expanded'
            });
          }
        }
      });
      
      return issues;
    }''');
    
    if (ariaValidation is List) {
      aria['invalidAttributes'] = ariaValidation;
    }
    
    // Generate issues
    if (aria['invalidRoles'].isNotEmpty) {
      aria['issues'].add('Invalid ARIA roles found: ${aria['invalidRoles'].length}');
    }
    
    if (aria['missingLabels'].isNotEmpty) {
      aria['issues'].add('Interactive elements without labels: ${aria['missingLabels'].length}');
    }
    
    if (aria['invalidAttributes'].isNotEmpty) {
      aria['issues'].add('Invalid ARIA attribute usage: ${aria['invalidAttributes'].length}');
    }
    
    return aria;
  }
  
  Map<String, dynamic> _validateForms(dom.Document document) {
    final forms = <String, dynamic>{
      'count': 0,
      'issues': [],
      'missingLabels': [],
      'missingNames': [],
      'emptyActions': [],
      'noSubmitButton': []
    };
    
    final formElements = document.querySelectorAll('form');
    forms['count'] = formElements.length;
    
    for (final form in formElements) {
      // Check for action attribute
      if (form.attributes['action'] == null || form.attributes['action']!.isEmpty) {
        forms['emptyActions'].add({
          'id': form.attributes['id'],
          'class': form.attributes['class']
        });
      }
      
      // Check for submit button
      final hasSubmit = form.querySelector('button[type="submit"], input[type="submit"]') != null;
      if (!hasSubmit) {
        forms['noSubmitButton'].add({
          'id': form.attributes['id'],
          'class': form.attributes['class']
        });
      }
      
      // Check form inputs
      final inputs = form.querySelectorAll('input, select, textarea');
      for (final input in inputs) {
        // Skip certain input types that don't need labels
        final type = input.attributes['type'] ?? 'text';
        if (['submit', 'button', 'reset', 'hidden'].contains(type)) continue;
        
        // Check for name attribute
        if (input.attributes['name'] == null) {
          forms['missingNames'].add({
            'element': input.localName,
            'type': type,
            'id': input.attributes['id']
          });
        }
        
        // Check for labels
        if (!_hasAssociatedLabel(input, document)) {
          forms['missingLabels'].add({
            'element': input.localName,
            'type': type,
            'id': input.attributes['id'],
            'name': input.attributes['name']
          });
        }
      }
    }
    
    // Generate issues
    if (forms['missingLabels'].isNotEmpty) {
      forms['issues'].add('Form inputs without labels: ${forms['missingLabels'].length}');
    }
    
    if (forms['missingNames'].isNotEmpty) {
      forms['issues'].add('Form inputs without name attribute: ${forms['missingNames'].length}');
    }
    
    if (forms['emptyActions'].isNotEmpty) {
      forms['issues'].add('Forms without action attribute: ${forms['emptyActions'].length}');
    }
    
    if (forms['noSubmitButton'].isNotEmpty) {
      forms['issues'].add('Forms without submit button: ${forms['noSubmitButton'].length}');
    }
    
    return forms;
  }
  
  Map<String, dynamic> _checkDuplicates(dom.Document document) {
    final duplicates = <String, dynamic>{
      'duplicateIds': [],
      'totalDuplicates': 0,
      'issues': []
    };
    
    final idMap = <String, List<dom.Element>>{};
    
    // Find all elements with IDs
    final elementsWithIds = document.querySelectorAll('[id]');
    for (final element in elementsWithIds) {
      final id = element.attributes['id'];
      if (id != null && id.isNotEmpty) {
        if (!idMap.containsKey(id)) {
          idMap[id] = [];
        }
        idMap[id]!.add(element);
      }
    }
    
    // Find duplicates
    idMap.forEach((id, elements) {
      if (elements.length > 1) {
        duplicates['duplicateIds'].add({
          'id': id,
          'count': elements.length,
          'elements': elements.map((e) => e.localName).toList()
        });
        duplicates['totalDuplicates'] += elements.length - 1;
      }
    });
    
    // Generate issues
    if (duplicates['duplicateIds'].isNotEmpty) {
      duplicates['issues'].add(
        'Found ${duplicates['duplicateIds'].length} duplicate IDs affecting ${duplicates['totalDuplicates']} elements'
      );
    }
    
    return duplicates;
  }
  
  Map<String, dynamic> _checkDeprecatedElements(dom.Document document) {
    final deprecated = <String, dynamic>{
      'elements': {},
      'total': 0,
      'issues': []
    };
    
    // Check for deprecated elements
    for (final tag in deprecatedElements) {
      final elements = document.querySelectorAll(tag);
      if (elements.isNotEmpty) {
        deprecated['elements'][tag] = elements.length;
        deprecated['total'] += elements.length;
      }
    }
    
    // Check for deprecated attributes
    final deprecatedAttrs = {
      'align': document.querySelectorAll('[align]').length,
      'bgcolor': document.querySelectorAll('[bgcolor]').length,
      'border': document.querySelectorAll('[border]').length,
      'cellpadding': document.querySelectorAll('[cellpadding]').length,
      'cellspacing': document.querySelectorAll('[cellspacing]').length,
      'width': document.querySelectorAll('table[width], td[width], th[width]').length,
    };
    
    deprecatedAttrs.forEach((attr, count) {
      if (count > 0) {
        deprecated['elements']['@$attr'] = count;
        deprecated['total'] += count;
      }
    });
    
    // Generate issues
    if (deprecated['total'] > 0) {
      deprecated['issues'].add(
        'Found ${deprecated['total']} deprecated HTML elements/attributes'
      );
    }
    
    return deprecated;
  }
  
  Map<String, dynamic> _validateMetadata(dom.Document document) {
    final metadata = <String, dynamic>{
      'title': '',
      'description': '',
      'keywords': '',
      'author': '',
      'robots': '',
      'canonical': '',
      'issues': []
    };
    
    // Get title
    final title = document.querySelector('title');
    if (title != null) {
      metadata['title'] = title.text.trim();
      if (metadata['title'].length > 60) {
        metadata['issues'].add('Title too long (${metadata['title'].length} chars, recommended < 60)');
      } else if (metadata['title'].length < 30) {
        metadata['issues'].add('Title too short (${metadata['title'].length} chars, recommended 30-60)');
      }
    } else {
      metadata['issues'].add('Missing title tag');
    }
    
    // Get meta tags
    final description = document.querySelector('meta[name="description"]');
    if (description != null) {
      metadata['description'] = description.attributes['content'] ?? '';
      if (metadata['description'].length > 160) {
        metadata['issues'].add('Description too long (${metadata['description'].length} chars, recommended < 160)');
      } else if (metadata['description'].length < 50) {
        metadata['issues'].add('Description too short (${metadata['description'].length} chars, recommended 50-160)');
      }
    } else {
      metadata['issues'].add('Missing meta description');
    }
    
    final keywords = document.querySelector('meta[name="keywords"]');
    if (keywords != null) {
      metadata['keywords'] = keywords.attributes['content'] ?? '';
    }
    
    final author = document.querySelector('meta[name="author"]');
    if (author != null) {
      metadata['author'] = author.attributes['content'] ?? '';
    }
    
    final robots = document.querySelector('meta[name="robots"]');
    if (robots != null) {
      metadata['robots'] = robots.attributes['content'] ?? '';
    }
    
    final canonical = document.querySelector('link[rel="canonical"]');
    if (canonical != null) {
      metadata['canonical'] = canonical.attributes['href'] ?? '';
    }
    
    return metadata;
  }
  
  Map<String, dynamic> _validateLinks(dom.Document document) {
    final links = <String, dynamic>{
      'total': 0,
      'internal': 0,
      'external': 0,
      'emptyHref': [],
      'javascriptLinks': [],
      'noFollowLinks': [],
      'issues': []
    };
    
    final linkElements = document.querySelectorAll('a');
    links['total'] = linkElements.length;
    
    for (final link in linkElements) {
      final href = link.attributes['href'];
      
      if (href == null || href.isEmpty || href == '#') {
        links['emptyHref'].add({
          'text': link.text.trim().substring(0, 50),
          'id': link.attributes['id']
        });
      } else if (href.startsWith('javascript:')) {
        links['javascriptLinks'].add({
          'text': link.text.trim().substring(0, 50),
          'href': href.substring(0, 50)
        });
      } else if (href.startsWith('http://') || href.startsWith('https://')) {
        links['external']++;
      } else {
        links['internal']++;
      }
      
      if (link.attributes['rel']?.contains('nofollow') == true) {
        links['noFollowLinks'].add(href);
      }
    }
    
    // Generate issues
    if (links['emptyHref'].isNotEmpty) {
      links['issues'].add('Links with empty href: ${links['emptyHref'].length}');
    }
    
    if (links['javascriptLinks'].isNotEmpty) {
      links['issues'].add('JavaScript links found: ${links['javascriptLinks'].length}');
    }
    
    return links;
  }
  
  Map<String, dynamic> _validateImages(dom.Document document) {
    final images = <String, dynamic>{
      'total': 0,
      'withAlt': 0,
      'withoutAlt': [],
      'decorative': 0,
      'lazyLoaded': 0,
      'issues': []
    };
    
    final imageElements = document.querySelectorAll('img');
    images['total'] = imageElements.length;
    
    for (final img in imageElements) {
      final alt = img.attributes['alt'];
      final src = img.attributes['src'] ?? '';
      
      if (alt != null) {
        images['withAlt']++;
        if (alt.isEmpty) {
          images['decorative']++;
        }
      } else {
        images['withoutAlt'].add({
          'src': src.length > 50 ? src.substring(0, 50) + '...' : src,
          'id': img.attributes['id'],
          'class': img.attributes['class']
        });
      }
      
      if (img.attributes['loading'] == 'lazy') {
        images['lazyLoaded']++;
      }
    }
    
    // Generate issues
    if (images['withoutAlt'].isNotEmpty) {
      images['issues'].add('Images without alt attribute: ${images['withoutAlt'].length}');
    }
    
    final altPercentage = images['total'] > 0 
      ? (images['withAlt'] / images['total'] * 100).round()
      : 100;
    
    if (altPercentage < 90) {
      images['issues'].add('Only $altPercentage% of images have alt text');
    }
    
    return images;
  }
  
  Map<String, dynamic> _validateTables(dom.Document document) {
    final tables = <String, dynamic>{
      'total': 0,
      'withCaption': 0,
      'withHeaders': 0,
      'layoutTables': 0,
      'issues': []
    };
    
    final tableElements = document.querySelectorAll('table');
    tables['total'] = tableElements.length;
    
    for (final table in tableElements) {
      // Check for caption
      if (table.querySelector('caption') != null) {
        tables['withCaption']++;
      }
      
      // Check for headers
      final headers = table.querySelectorAll('th');
      if (headers.isNotEmpty) {
        tables['withHeaders']++;
        
        // Check for scope attributes
        bool hasScope = false;
        for (final th in headers) {
          if (th.attributes['scope'] != null) {
            hasScope = true;
            break;
          }
        }
        
        if (!hasScope && headers.length > 1) {
          tables['issues'].add('Table headers without scope attributes');
        }
      }
      
      // Check if it's a layout table (no headers, no caption)
      if (headers.isEmpty && table.querySelector('caption') == null) {
        tables['layoutTables']++;
      }
    }
    
    // Generate issues
    if (tables['total'] > 0) {
      if (tables['withCaption'] == 0) {
        tables['issues'].add('No tables have captions');
      }
      
      if (tables['layoutTables'] > 0) {
        tables['issues'].add('${tables['layoutTables']} tables appear to be used for layout');
      }
    }
    
    return tables;
  }
  
  Map<String, dynamic> _validateLists(dom.Document document) {
    final lists = <String, dynamic>{
      'ul': 0,
      'ol': 0,
      'dl': 0,
      'nestedLists': 0,
      'improperNesting': [],
      'issues': []
    };
    
    lists['ul'] = document.querySelectorAll('ul').length;
    lists['ol'] = document.querySelectorAll('ol').length;
    lists['dl'] = document.querySelectorAll('dl').length;
    
    // Check for nested lists
    lists['nestedLists'] = document.querySelectorAll('li ul, li ol').length;
    
    // Check for improper nesting
    final improperUl = document.querySelectorAll('ul > :not(li)');
    final improperOl = document.querySelectorAll('ol > :not(li)');
    
    for (final element in improperUl) {
      lists['improperNesting'].add({
        'parent': 'ul',
        'child': element.localName
      });
    }
    
    for (final element in improperOl) {
      lists['improperNesting'].add({
        'parent': 'ol',
        'child': element.localName
      });
    }
    
    // Generate issues
    if (lists['improperNesting'].isNotEmpty) {
      lists['issues'].add('Improper list nesting: ${lists['improperNesting'].length} cases');
    }
    
    return lists;
  }
  
  Map<String, dynamic> _validateHeadings(dom.Document document) {
    final headings = <String, dynamic>{
      'h1': [],
      'h2': [],
      'h3': [],
      'h4': [],
      'h5': [],
      'h6': [],
      'hierarchy': true,
      'issues': []
    };
    
    // Collect all headings
    for (int i = 1; i <= 6; i++) {
      final elements = document.querySelectorAll('h$i');
      headings['h$i'] = elements.map((e) => e.text.trim()).toList();
    }
    
    // Check for multiple H1s
    if (headings['h1'].length > 1) {
      headings['issues'].add('Multiple H1 tags found (${headings['h1'].length})');
    } else if (headings['h1'].isEmpty) {
      headings['issues'].add('No H1 tag found');
    }
    
    // Check heading hierarchy
    int previousLevel = 0;
    bool skippedLevel = false;
    
    for (int i = 1; i <= 6; i++) {
      if ((headings['h$i'] as List).isNotEmpty) {
        if (previousLevel > 0 && i > previousLevel + 1) {
          skippedLevel = true;
          headings['issues'].add('Heading hierarchy broken: H$previousLevel followed by H$i');
        }
        previousLevel = i;
      }
    }
    
    headings['hierarchy'] = !skippedLevel;
    
    return headings;
  }
  
  Map<String, dynamic> _checkInlineContent(dom.Document document) {
    final inline = <String, dynamic>{
      'inlineStyles': 0,
      'inlineScripts': 0,
      'inlineEventHandlers': 0,
      'issues': []
    };
    
    // Count inline styles
    inline['inlineStyles'] = document.querySelectorAll('[style]').length;
    
    // Count inline scripts
    inline['inlineScripts'] = document.querySelectorAll('script:not([src])').length;
    
    // Count inline event handlers
    final eventAttributes = [
      'onclick', 'onload', 'onmouseover', 'onmouseout', 'onmousedown',
      'onmouseup', 'onkeydown', 'onkeyup', 'onkeypress', 'onchange',
      'onsubmit', 'onfocus', 'onblur'
    ];
    
    for (final attr in eventAttributes) {
      inline['inlineEventHandlers'] += document.querySelectorAll('[$attr]').length;
    }
    
    // Generate issues
    if (inline['inlineStyles'] > 10) {
      inline['issues'].add('High number of inline styles: ${inline['inlineStyles']}');
    }
    
    if (inline['inlineScripts'] > 0) {
      inline['issues'].add('Inline scripts found: ${inline['inlineScripts']}');
    }
    
    if (inline['inlineEventHandlers'] > 0) {
      inline['issues'].add('Inline event handlers found: ${inline['inlineEventHandlers']}');
    }
    
    return inline;
  }
  
  Map<String, dynamic> _validateLanguage(dom.Document document) {
    final language = <String, dynamic>{
      'htmlLang': '',
      'hasLang': false,
      'langChanges': 0,
      'issues': []
    };
    
    // Check HTML lang attribute
    final html = document.querySelector('html');
    if (html != null) {
      final lang = html.attributes['lang'];
      if (lang != null && lang.isNotEmpty) {
        language['hasLang'] = true;
        language['htmlLang'] = lang;
      } else {
        language['issues'].add('Missing lang attribute on <html> element');
      }
    }
    
    // Count language changes
    language['langChanges'] = document.querySelectorAll('[lang]:not(html)').length;
    
    return language;
  }
  
  bool _hasAssociatedLabel(dom.Element input, dom.Document document) {
    // Check for explicit label
    final id = input.attributes['id'];
    if (id != null) {
      final label = document.querySelector('label[for="$id"]');
      if (label != null) return true;
    }
    
    // Check for implicit label (input inside label)
    dom.Element? parent = input.parent;
    while (parent != null) {
      if (parent.localName == 'label') return true;
      parent = parent.parent;
    }
    
    // Check for aria-label or aria-labelledby
    if (input.attributes['aria-label'] != null ||
        input.attributes['aria-labelledby'] != null) {
      return true;
    }
    
    // Check for placeholder (not ideal but sometimes used)
    if (input.attributes['placeholder'] != null) {
      return true; // Consider this as having some label
    }
    
    return false;
  }
  
  Map<String, dynamic> _calculateScore(Map<String, dynamic> results) {
    int score = 100;
    final summary = <String, dynamic>{};
    
    // Doctype and structure (20 points)
    if (results['doctype']['isHTML5'] != true) score -= 10;
    if (results['structure']['issues'].isNotEmpty) {
      score -= results['structure']['issues'].length * 5;
    }
    summary['structure'] = results['structure']['issues'].isEmpty;
    
    // Semantic HTML (15 points)
    if (results['semanticHTML']['score'] < 50) score -= 15;
    else if (results['semanticHTML']['score'] < 80) score -= 7;
    summary['semantic'] = results['semanticHTML']['usesSemanticElements'];
    
    // ARIA (15 points)
    if (results['aria']['invalidRoles'].isNotEmpty) score -= 10;
    if (results['aria']['missingLabels'].isNotEmpty) {
      score -= (results['aria']['missingLabels'].length * 2).clamp(0, 10);
    }
    summary['aria'] = results['aria']['issues'].isEmpty;
    
    // Forms (10 points)
    if (results['forms']['issues'].isNotEmpty) {
      score -= (results['forms']['issues'].length * 3).clamp(0, 10);
    }
    summary['forms'] = results['forms']['issues'].isEmpty;
    
    // Duplicate IDs (15 points)
    if (results['duplicates']['duplicateIds'].isNotEmpty) {
      score -= (results['duplicates']['duplicateIds'].length * 5).clamp(0, 15);
    }
    summary['noDuplicates'] = results['duplicates']['duplicateIds'].isEmpty;
    
    // Deprecated elements (10 points)
    if (results['deprecated']['total'] > 0) {
      score -= (results['deprecated']['total'] * 2).clamp(0, 10);
    }
    summary['noDeprecated'] = results['deprecated']['total'] == 0;
    
    // Images (10 points)
    final imageIssues = results['images']['withoutAlt'].length;
    if (imageIssues > 0) {
      score -= (imageIssues * 2).clamp(0, 10);
    }
    summary['imageAlt'] = imageIssues == 0;
    
    // Headings (5 points)
    if (!results['headings']['hierarchy']) score -= 5;
    summary['headingHierarchy'] = results['headings']['hierarchy'];
    
    score = score.clamp(0, 100);
    
    // Calculate grade
    String grade;
    if (score >= 90) grade = 'A';
    else if (score >= 80) grade = 'B';
    else if (score >= 70) grade = 'C';
    else if (score >= 60) grade = 'D';
    else grade = 'F';
    
    return {
      'score': score,
      'grade': grade,
      'summary': summary
    };
  }
  
  List<Map<String, dynamic>> _identifyIssues(Map<String, dynamic> results) {
    final issues = <Map<String, dynamic>>[];
    
    // Critical issues
    if (results['doctype']['present'] != true) {
      issues.add({
        'severity': 'critical',
        'category': 'Structure',
        'issue': 'Missing DOCTYPE declaration',
        'impact': 'Browser may render in quirks mode'
      });
    }
    
    if (results['structure']['hasTitle'] != true) {
      issues.add({
        'severity': 'critical',
        'category': 'Structure',
        'issue': 'Missing title tag',
        'impact': 'Poor SEO and accessibility'
      });
    }
    
    if (results['duplicates']['duplicateIds'].isNotEmpty) {
      issues.add({
        'severity': 'critical',
        'category': 'HTML Validity',
        'issue': 'Duplicate IDs found',
        'count': results['duplicates']['duplicateIds'].length,
        'impact': 'JavaScript and CSS selectors may fail'
      });
    }
    
    // High priority issues
    if (results['images']['withoutAlt'].isNotEmpty) {
      issues.add({
        'severity': 'high',
        'category': 'Accessibility',
        'issue': 'Images without alt text',
        'count': results['images']['withoutAlt'].length,
        'impact': 'Screen readers cannot describe images'
      });
    }
    
    if (results['aria']['invalidRoles'].isNotEmpty) {
      issues.add({
        'severity': 'high',
        'category': 'ARIA',
        'issue': 'Invalid ARIA roles',
        'count': results['aria']['invalidRoles'].length,
        'impact': 'Assistive technologies may not work correctly'
      });
    }
    
    // Medium priority issues
    if (results['deprecated']['total'] > 0) {
      issues.add({
        'severity': 'medium',
        'category': 'HTML Standards',
        'issue': 'Deprecated HTML elements/attributes',
        'count': results['deprecated']['total'],
        'impact': 'May not work in future browsers'
      });
    }
    
    if (!results['semanticHTML']['usesSemanticElements']) {
      issues.add({
        'severity': 'medium',
        'category': 'Semantic HTML',
        'issue': 'No semantic HTML5 elements used',
        'impact': 'Poor document structure and SEO'
      });
    }
    
    // Low priority issues
    if (results['inline']['inlineStyles'] > 10) {
      issues.add({
        'severity': 'low',
        'category': 'Best Practices',
        'issue': 'Many inline styles',
        'count': results['inline']['inlineStyles'],
        'impact': 'Hard to maintain, poor performance'
      });
    }
    
    return issues;
  }
  
  List<Map<String, dynamic>> _generateRecommendations(Map<String, dynamic> results) {
    final recommendations = <Map<String, dynamic>>[];
    
    // DOCTYPE
    if (!results['doctype']['isHTML5']) {
      recommendations.add({
        'priority': 'critical',
        'category': 'Structure',
        'recommendation': 'Use HTML5 DOCTYPE',
        'implementation': '<!DOCTYPE html>',
        'benefit': 'Ensures standards mode rendering'
      });
    }
    
    // Semantic HTML
    if (!results['semanticHTML']['usesSemanticElements']) {
      recommendations.add({
        'priority': 'high',
        'category': 'Semantic HTML',
        'recommendation': 'Use semantic HTML5 elements',
        'implementation': 'Replace <div> with <nav>, <main>, <article>, <section>, etc.',
        'benefit': 'Better SEO, accessibility, and maintainability'
      });
    }
    
    // Duplicate IDs
    if (results['duplicates']['duplicateIds'].isNotEmpty) {
      recommendations.add({
        'priority': 'critical',
        'category': 'HTML Validity',
        'recommendation': 'Fix duplicate IDs',
        'affectedIds': results['duplicates']['duplicateIds'].take(5).toList(),
        'benefit': 'Ensures JavaScript and CSS work correctly'
      });
    }
    
    // Images
    if (results['images']['withoutAlt'].isNotEmpty) {
      recommendations.add({
        'priority': 'high',
        'category': 'Accessibility',
        'recommendation': 'Add alt text to all images',
        'implementation': 'Add alt="" for decorative images, descriptive text for content images',
        'affectedCount': results['images']['withoutAlt'].length,
        'benefit': 'Improves accessibility and SEO'
      });
    }
    
    // Forms
    if (results['forms']['missingLabels'].isNotEmpty) {
      recommendations.add({
        'priority': 'high',
        'category': 'Forms',
        'recommendation': 'Add labels to all form inputs',
        'implementation': 'Use <label for="id"> or aria-label',
        'affectedCount': results['forms']['missingLabels'].length,
        'benefit': 'Improves form accessibility'
      });
    }
    
    // Headings
    if (!results['headings']['hierarchy']) {
      recommendations.add({
        'priority': 'medium',
        'category': 'Document Structure',
        'recommendation': 'Fix heading hierarchy',
        'implementation': 'Use headings in sequential order (H1, H2, H3...)',
        'benefit': 'Better document outline and accessibility'
      });
    }
    
    // Language
    if (!results['language']['hasLang']) {
      recommendations.add({
        'priority': 'high',
        'category': 'Internationalization',
        'recommendation': 'Add lang attribute to HTML element',
        'implementation': '<html lang="en"> or appropriate language code',
        'benefit': 'Helps screen readers and search engines'
      });
    }
    
    // Deprecated elements
    if (results['deprecated']['total'] > 0) {
      recommendations.add({
        'priority': 'medium',
        'category': 'Modern HTML',
        'recommendation': 'Replace deprecated HTML',
        'elements': Object.keys(results['deprecated']['elements']).take(5).toList(),
        'benefit': 'Future-proof your HTML'
      });
    }
    
    return recommendations;
  }
}

// Extension for AuditContext to hold HTML validation results
extension HTMLValidationContext on AuditContext {
  static final _htmlValidation = Expando<Map<String, dynamic>>();
  
  Map<String, dynamic>? get htmlValidation => _htmlValidation[this];
  set htmlValidation(Map<String, dynamic>? value) => _htmlValidation[this] = value;
}