import 'dart:convert';
import 'package:puppeteer/puppeteer.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import 'package:xml/xml.dart' as xml;
import 'package:logging/logging.dart';
import 'audit_base.dart';

/// Comprehensive SEO Audit matching npm tool functionality
class CompleteSEOAudit implements Audit {
  @override
  String get name => 'seo_complete';
  
  final Logger _logger = Logger('CompleteSEOAudit');

  @override
  Future<void> run(AuditContext ctx) async {
    final page = ctx.page as Page;
    final url = ctx.url.toString();
    final domain = ctx.url.host;
    
    final seoResults = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'url': url,
    };
    
    try {
      // Get page HTML content
      final html = await page.content();
      final document = html_parser.parse(html);
      
      // 1. Meta Tags Analysis
      seoResults['metaTags'] = await _analyzeMetaTags(document, page);
      
      // 2. Open Graph Tags
      seoResults['openGraph'] = _analyzeOpenGraph(document);
      
      // 3. Twitter Cards
      seoResults['twitterCard'] = _analyzeTwitterCard(document);
      
      // 4. Structured Data (JSON-LD, Microdata, RDFa)
      seoResults['structuredData'] = await _analyzeStructuredData(page);
      
      // 5. Headings Analysis
      seoResults['headings'] = _analyzeHeadings(document);
      
      // 6. Links Analysis
      seoResults['links'] = await _analyzeLinks(document, url);
      
      // 7. Images Analysis
      seoResults['images'] = _analyzeImages(document);
      
      // 8. Canonical URL
      seoResults['canonical'] = _analyzeCanonical(document, url);
      
      // 9. Hreflang Tags
      seoResults['hreflang'] = _analyzeHreflang(document);
      
      // 10. Robots Meta
      seoResults['robotsMeta'] = _analyzeRobotsMeta(document);
      
      // 11. Sitemap.xml Check
      seoResults['sitemap'] = await _checkSitemap(domain);
      
      // 12. Robots.txt Check
      seoResults['robotsTxt'] = await _checkRobotsTxt(domain);
      
      // 13. Page Speed Insights
      seoResults['pageSpeed'] = await _analyzePageSpeed(page);
      
      // 14. Mobile Friendliness
      seoResults['mobileFriendly'] = await _checkMobileFriendliness(page);
      
      // 15. Content Analysis
      seoResults['content'] = _analyzeContent(document);
      
      // 16. Social Media Integration
      seoResults['socialMedia'] = _analyzeSocialIntegration(document);
      
      // 17. Schema.org Implementation
      seoResults['schemaOrg'] = await _analyzeSchemaOrg(page);
      
      // 18. AMP Support
      seoResults['amp'] = _checkAMPSupport(document);
      
      // 19. Language and Localization
      seoResults['language'] = _analyzeLanguage(document);
      
      // 20. Calculate SEO Score
      seoResults['score'] = _calculateSEOScore(seoResults);
      
      // 21. Generate Recommendations
      seoResults['recommendations'] = _generateRecommendations(seoResults);
      
      // Store in context
      ctx.seoComplete = seoResults;
      
    } catch (e) {
      _logger.severe('Error in SEO audit: $e');
      seoResults['error'] = e.toString();
      ctx.seoComplete = seoResults;
    }
  }
  
  Map<String, dynamic> _analyzeMetaTags(Document document, Page page) async {
    final metaTags = <String, dynamic>{};
    
    // Title tag
    final titleElement = document.querySelector('title');
    metaTags['title'] = {
      'content': titleElement?.text ?? '',
      'length': titleElement?.text.length ?? 0,
      'isOptimal': (titleElement?.text.length ?? 0) >= 30 && 
                   (titleElement?.text.length ?? 0) <= 60,
      'recommendations': []
    };
    
    if (metaTags['title']['length'] == 0) {
      metaTags['title']['recommendations'].add('Missing title tag');
    } else if (metaTags['title']['length'] < 30) {
      metaTags['title']['recommendations'].add('Title too short (recommended: 30-60 characters)');
    } else if (metaTags['title']['length'] > 60) {
      metaTags['title']['recommendations'].add('Title too long (recommended: 30-60 characters)');
    }
    
    // Meta description
    final descElement = document.querySelector('meta[name="description"]');
    metaTags['description'] = {
      'content': descElement?.attributes['content'] ?? '',
      'length': descElement?.attributes['content']?.length ?? 0,
      'isOptimal': (descElement?.attributes['content']?.length ?? 0) >= 120 && 
                   (descElement?.attributes['content']?.length ?? 0) <= 160,
      'recommendations': []
    };
    
    if (metaTags['description']['length'] == 0) {
      metaTags['description']['recommendations'].add('Missing meta description');
    } else if (metaTags['description']['length'] < 120) {
      metaTags['description']['recommendations'].add('Description too short (recommended: 120-160 characters)');
    } else if (metaTags['description']['length'] > 160) {
      metaTags['description']['recommendations'].add('Description too long (recommended: 120-160 characters)');
    }
    
    // Keywords (deprecated but still check)
    final keywordsElement = document.querySelector('meta[name="keywords"]');
    metaTags['keywords'] = {
      'content': keywordsElement?.attributes['content'] ?? '',
      'present': keywordsElement != null,
      'recommendation': keywordsElement != null ? 
        'Keywords meta tag is deprecated and ignored by search engines' : null
    };
    
    // Viewport
    final viewportElement = document.querySelector('meta[name="viewport"]');
    metaTags['viewport'] = {
      'content': viewportElement?.attributes['content'] ?? '',
      'present': viewportElement != null,
      'isMobileOptimized': viewportElement?.attributes['content']
              ?.contains('width=device-width') ?? false
    };
    
    // Author
    final authorElement = document.querySelector('meta[name="author"]');
    metaTags['author'] = authorElement?.attributes['content'] ?? '';
    
    // Robots
    final robotsElement = document.querySelector('meta[name="robots"]');
    metaTags['robots'] = {
      'content': robotsElement?.attributes['content'] ?? 'index,follow',
      'isIndexable': !(robotsElement?.attributes['content']?.contains('noindex') ?? false),
      'isFollowable': !(robotsElement?.attributes['content']?.contains('nofollow') ?? false)
    };
    
    // Charset
    final charsetElement = document.querySelector('meta[charset]');
    metaTags['charset'] = {
      'value': charsetElement?.attributes['charset'] ?? '',
      'isUTF8': charsetElement?.attributes['charset']?.toLowerCase() == 'utf-8'
    };
    
    return metaTags;
  }
  
  Map<String, dynamic> _analyzeOpenGraph(Document document) {
    final openGraph = <String, dynamic>{
      'present': false,
      'tags': {},
      'missingRequired': [],
      'score': 0
    };
    
    final requiredOGTags = ['og:title', 'og:type', 'og:url', 'og:image'];
    final ogTags = document.querySelectorAll('meta[property^="og:"]');
    
    if (ogTags.isNotEmpty) {
      openGraph['present'] = true;
      
      for (final tag in ogTags) {
        final property = tag.attributes['property'] ?? '';
        final content = tag.attributes['content'] ?? '';
        openGraph['tags'][property] = content;
      }
      
      // Check for required tags
      for (final required in requiredOGTags) {
        if (!openGraph['tags'].containsKey(required)) {
          openGraph['missingRequired'].add(required);
        }
      }
      
      // Calculate score
      final presentRequired = requiredOGTags.where(
        (tag) => openGraph['tags'].containsKey(tag)
      ).length;
      openGraph['score'] = (presentRequired / requiredOGTags.length * 100).round();
    }
    
    return openGraph;
  }
  
  Map<String, dynamic> _analyzeTwitterCard(Document document) {
    final twitterCard = <String, dynamic>{
      'present': false,
      'type': '',
      'tags': {},
      'missingRequired': [],
      'score': 0
    };
    
    final twitterTags = document.querySelectorAll('meta[name^="twitter:"]');
    
    if (twitterTags.isNotEmpty) {
      twitterCard['present'] = true;
      
      for (final tag in twitterTags) {
        final name = tag.attributes['name'] ?? '';
        final content = tag.attributes['content'] ?? '';
        twitterCard['tags'][name] = content;
        
        if (name == 'twitter:card') {
          twitterCard['type'] = content;
        }
      }
      
      // Check required tags based on card type
      final requiredTags = ['twitter:card', 'twitter:title', 'twitter:description'];
      if (twitterCard['type'] == 'summary_large_image' || 
          twitterCard['type'] == 'summary') {
        requiredTags.add('twitter:image');
      }
      
      for (final required in requiredTags) {
        if (!twitterCard['tags'].containsKey(required)) {
          twitterCard['missingRequired'].add(required);
        }
      }
      
      // Calculate score
      final presentRequired = requiredTags.where(
        (tag) => twitterCard['tags'].containsKey(tag)
      ).length;
      twitterCard['score'] = (presentRequired / requiredTags.length * 100).round();
    }
    
    return twitterCard;
  }
  
  Future<Map<String, dynamic>> _analyzeStructuredData(Page page) async {
    final structuredData = <String, dynamic>{
      'jsonLd': [],
      'microdata': {},
      'rdfa': {},
      'score': 0,
      'types': [],
      'errors': []
    };
    
    try {
      // Extract JSON-LD
      final jsonLdData = await page.evaluate('''() => {
        const scripts = document.querySelectorAll('script[type="application/ld+json"]');
        const data = [];
        scripts.forEach(script => {
          try {
            const parsed = JSON.parse(script.textContent);
            data.push(parsed);
          } catch (e) {
            data.push({error: e.toString(), content: script.textContent});
          }
        });
        return data;
      }''');
      
      structuredData['jsonLd'] = jsonLdData as List;
      
      // Extract Microdata
      final microdataResult = await page.evaluate('''() => {
        const items = document.querySelectorAll('[itemscope]');
        const data = [];
        items.forEach(item => {
          const itemData = {
            type: item.getAttribute('itemtype'),
            properties: {}
          };
          const props = item.querySelectorAll('[itemprop]');
          props.forEach(prop => {
            const name = prop.getAttribute('itemprop');
            const content = prop.getAttribute('content') || 
                           prop.textContent || 
                           prop.getAttribute('href') || 
                           prop.getAttribute('src');
            if (!itemData.properties[name]) {
              itemData.properties[name] = [];
            }
            itemData.properties[name].push(content);
          });
          data.push(itemData);
        });
        return data;
      }''');
      
      structuredData['microdata'] = microdataResult;
      
      // Analyze RDFa
      final rdfaResult = await page.evaluate('''() => {
        const elements = document.querySelectorAll('[vocab], [typeof], [property]');
        return elements.length > 0;
      }''');
      
      structuredData['rdfa']['present'] = rdfaResult as bool;
      
      // Extract types
      if (structuredData['jsonLd'] is List) {
        for (final item in structuredData['jsonLd']) {
          if (item is Map && item['@type'] != null) {
            structuredData['types'].add(item['@type']);
          }
        }
      }
      
      // Calculate score
      int score = 0;
      if ((structuredData['jsonLd'] as List).isNotEmpty) score += 40;
      if ((structuredData['microdata'] as List).isNotEmpty) score += 30;
      if (structuredData['rdfa']['present'] == true) score += 30;
      structuredData['score'] = score;
      
    } catch (e) {
      _logger.warning('Error analyzing structured data: $e');
      structuredData['errors'].add(e.toString());
    }
    
    return structuredData;
  }
  
  Map<String, dynamic> _analyzeHeadings(Document document) {
    final headings = <String, dynamic>{
      'h1': [],
      'h2': [],
      'h3': [],
      'h4': [],
      'h5': [],
      'h6': [],
      'hierarchy': [],
      'issues': []
    };
    
    // Collect all headings
    for (int i = 1; i <= 6; i++) {
      final elements = document.querySelectorAll('h$i');
      for (final element in elements) {
        headings['h$i'].add({
          'text': element.text.trim(),
          'length': element.text.trim().length
        });
        headings['hierarchy'].add({
          'level': i,
          'text': element.text.trim()
        });
      }
    }
    
    // Check for issues
    if ((headings['h1'] as List).isEmpty) {
      headings['issues'].add('Missing H1 tag');
    } else if ((headings['h1'] as List).length > 1) {
      headings['issues'].add('Multiple H1 tags found (${(headings['h1'] as List).length})');
    }
    
    // Check hierarchy
    bool skippedLevel = false;
    int previousLevel = 0;
    for (final heading in headings['hierarchy']) {
      if (heading['level'] > previousLevel + 1 && previousLevel > 0) {
        skippedLevel = true;
        break;
      }
      previousLevel = heading['level'];
    }
    
    if (skippedLevel) {
      headings['issues'].add('Heading hierarchy has gaps (skipped levels)');
    }
    
    // Calculate statistics
    headings['statistics'] = {
      'total': (headings['hierarchy'] as List).length,
      'h1Count': (headings['h1'] as List).length,
      'averageLength': _calculateAverageLength(headings['hierarchy'])
    };
    
    return headings;
  }
  
  Future<Map<String, dynamic>> _analyzeLinks(Document document, String currentUrl) async {
    final links = <String, dynamic>{
      'internal': [],
      'external': [],
      'broken': [],
      'nofollow': [],
      'statistics': {}
    };
    
    final allLinks = document.querySelectorAll('a[href]');
    final currentUri = Uri.parse(currentUrl);
    
    for (final link in allLinks) {
      final href = link.attributes['href'] ?? '';
      final text = link.text.trim();
      final rel = link.attributes['rel'] ?? '';
      final title = link.attributes['title'] ?? '';
      
      if (href.isEmpty) continue;
      
      final linkData = {
        'href': href,
        'text': text,
        'title': title,
        'hasTitle': title.isNotEmpty,
        'hasText': text.isNotEmpty,
        'isNofollow': rel.contains('nofollow'),
        'isSponsored': rel.contains('sponsored'),
        'isUGC': rel.contains('ugc')
      };
      
      // Classify link
      try {
        final linkUri = Uri.parse(href.startsWith('http') ? href : 
                                   currentUri.resolve(href).toString());
        
        if (linkUri.host == currentUri.host) {
          links['internal'].add(linkData);
        } else {
          links['external'].add(linkData);
        }
        
        if (linkData['isNofollow'] == true) {
          links['nofollow'].add(linkData);
        }
      } catch (e) {
        links['broken'].add({...linkData, 'error': e.toString()});
      }
    }
    
    // Calculate statistics
    links['statistics'] = {
      'totalLinks': allLinks.length,
      'internalLinks': (links['internal'] as List).length,
      'externalLinks': (links['external'] as List).length,
      'nofollowLinks': (links['nofollow'] as List).length,
      'brokenLinks': (links['broken'] as List).length,
      'linksWithoutText': allLinks.where((l) => l.text.trim().isEmpty).length,
      'linksWithoutTitle': allLinks.where((l) => 
        (l.attributes['title'] ?? '').isEmpty).length
    };
    
    return links;
  }
  
  Map<String, dynamic> _analyzeImages(Document document) {
    final images = <String, dynamic>{
      'total': 0,
      'withAlt': [],
      'withoutAlt': [],
      'lazy': [],
      'statistics': {},
      'issues': []
    };
    
    final allImages = document.querySelectorAll('img');
    images['total'] = allImages.length;
    
    for (final img in allImages) {
      final src = img.attributes['src'] ?? '';
      final alt = img.attributes['alt'];
      final title = img.attributes['title'] ?? '';
      final loading = img.attributes['loading'] ?? '';
      final width = img.attributes['width'] ?? '';
      final height = img.attributes['height'] ?? '';
      
      final imageData = {
        'src': src,
        'alt': alt,
        'title': title,
        'hasAlt': alt != null,
        'altText': alt ?? '',
        'isLazy': loading == 'lazy',
        'hasExplicitDimensions': width.isNotEmpty && height.isNotEmpty,
        'width': width,
        'height': height
      };
      
      if (alt != null) {
        images['withAlt'].add(imageData);
      } else {
        images['withoutAlt'].add(imageData);
        images['issues'].add('Image without alt text: $src');
      }
      
      if (loading == 'lazy') {
        images['lazy'].add(imageData);
      }
    }
    
    // Calculate statistics
    images['statistics'] = {
      'totalImages': images['total'],
      'imagesWithAlt': (images['withAlt'] as List).length,
      'imagesWithoutAlt': (images['withoutAlt'] as List).length,
      'lazyLoadedImages': (images['lazy'] as List).length,
      'altTextCoverage': images['total'] > 0 ? 
        ((images['withAlt'] as List).length / images['total'] * 100).round() : 100
    };
    
    return images;
  }
  
  Map<String, dynamic> _analyzeCanonical(Document document, String currentUrl) {
    final canonical = <String, dynamic>{
      'present': false,
      'url': '',
      'isValid': false,
      'isSelfReferencing': false,
      'issues': []
    };
    
    final canonicalElement = document.querySelector('link[rel="canonical"]');
    
    if (canonicalElement != null) {
      canonical['present'] = true;
      canonical['url'] = canonicalElement.attributes['href'] ?? '';
      
      try {
        final canonicalUri = Uri.parse(canonical['url']);
        canonical['isValid'] = canonicalUri.isAbsolute;
        canonical['isSelfReferencing'] = canonical['url'] == currentUrl;
        
        if (!canonical['isValid']) {
          canonical['issues'].add('Canonical URL is not absolute');
        }
      } catch (e) {
        canonical['isValid'] = false;
        canonical['issues'].add('Invalid canonical URL format');
      }
    } else {
      canonical['issues'].add('No canonical URL specified');
    }
    
    return canonical;
  }
  
  Map<String, dynamic> _analyzeHreflang(Document document) {
    final hreflang = <String, dynamic>{
      'present': false,
      'tags': [],
      'languages': [],
      'issues': []
    };
    
    final hreflangElements = document.querySelectorAll('link[rel="alternate"][hreflang]');
    
    if (hreflangElements.isNotEmpty) {
      hreflang['present'] = true;
      
      for (final element in hreflangElements) {
        final lang = element.attributes['hreflang'] ?? '';
        final href = element.attributes['href'] ?? '';
        
        hreflang['tags'].add({
          'language': lang,
          'url': href,
          'isXDefault': lang == 'x-default'
        });
        
        if (!hreflang['languages'].contains(lang)) {
          hreflang['languages'].add(lang);
        }
      }
      
      // Check for x-default
      if (!hreflang['languages'].contains('x-default')) {
        hreflang['issues'].add('Missing x-default hreflang tag');
      }
    }
    
    return hreflang;
  }
  
  Map<String, dynamic> _analyzeRobotsMeta(Document document) {
    final robots = <String, dynamic>{
      'metaTag': {},
      'xRobotsTag': null, // Would need response headers
      'directives': []
    };
    
    final robotsElement = document.querySelector('meta[name="robots"]');
    if (robotsElement != null) {
      final content = robotsElement.attributes['content'] ?? '';
      robots['metaTag'] = {
        'content': content,
        'directives': content.split(',').map((s) => s.trim()).toList()
      };
      robots['directives'] = robots['metaTag']['directives'];
    }
    
    // Analyze directives
    final directives = robots['directives'] as List;
    robots['analysis'] = {
      'isIndexable': !directives.contains('noindex'),
      'isFollowable': !directives.contains('nofollow'),
      'allowsSnippet': !directives.contains('nosnippet'),
      'allowsArchive': !directives.contains('noarchive'),
      'allowsImageIndex': !directives.contains('noimageindex')
    };
    
    return robots;
  }
  
  Future<Map<String, dynamic>> _checkSitemap(String domain) async {
    final sitemap = <String, dynamic>{
      'found': false,
      'url': '',
      'accessible': false,
      'error': null
    };
    
    try {
      // Check common sitemap locations
      final sitemapUrls = [
        'https://$domain/sitemap.xml',
        'https://$domain/sitemap_index.xml',
        'https://$domain/sitemap.xml.gz',
        'http://$domain/sitemap.xml'
      ];
      
      for (final url in sitemapUrls) {
        try {
          final response = await http.head(Uri.parse(url))
              .timeout(Duration(seconds: 5));
          
          if (response.statusCode == 200) {
            sitemap['found'] = true;
            sitemap['url'] = url;
            sitemap['accessible'] = true;
            break;
          }
        } catch (e) {
          // Continue to next URL
        }
      }
    } catch (e) {
      sitemap['error'] = e.toString();
    }
    
    return sitemap;
  }
  
  Future<Map<String, dynamic>> _checkRobotsTxt(String domain) async {
    final robotsTxt = <String, dynamic>{
      'found': false,
      'url': '',
      'accessible': false,
      'content': '',
      'sitemapReference': null,
      'crawlDelay': null,
      'userAgents': [],
      'error': null
    };
    
    try {
      final url = 'https://$domain/robots.txt';
      robotsTxt['url'] = url;
      
      final response = await http.get(Uri.parse(url))
          .timeout(Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        robotsTxt['found'] = true;
        robotsTxt['accessible'] = true;
        robotsTxt['content'] = response.body;
        
        // Parse robots.txt
        final lines = response.body.split('\n');
        for (final line in lines) {
          if (line.toLowerCase().startsWith('sitemap:')) {
            robotsTxt['sitemapReference'] = line.substring(8).trim();
          } else if (line.toLowerCase().startsWith('crawl-delay:')) {
            robotsTxt['crawlDelay'] = line.substring(12).trim();
          } else if (line.toLowerCase().startsWith('user-agent:')) {
            robotsTxt['userAgents'].add(line.substring(11).trim());
          }
        }
      }
    } catch (e) {
      robotsTxt['error'] = e.toString();
    }
    
    return robotsTxt;
  }
  
  Future<Map<String, dynamic>> _analyzePageSpeed(Page page) async {
    // This would integrate with the CDP metrics collector
    return {
      'metrics': {
        'FCP': 0,
        'LCP': 0,
        'CLS': 0,
        'TBT': 0,
        'TTI': 0
      },
      'score': 0
    };
  }
  
  Future<Map<String, dynamic>> _checkMobileFriendliness(Page page) async {
    final mobile = <String, dynamic>{
      'viewport': {},
      'textSize': {},
      'tapTargets': {},
      'horizontalScroll': false
    };
    
    try {
      final result = await page.evaluate('''() => {
        const viewport = document.querySelector('meta[name="viewport"]');
        const viewportContent = viewport ? viewport.getAttribute('content') : '';
        
        return {
          hasViewport: viewport !== null,
          viewportContent: viewportContent,
          isResponsive: viewportContent.includes('width=device-width'),
          bodyScrollWidth: document.body.scrollWidth,
          windowWidth: window.innerWidth,
          hasHorizontalScroll: document.body.scrollWidth > window.innerWidth
        };
      }''');
      
      mobile['viewport'] = result;
      
    } catch (e) {
      mobile['error'] = e.toString();
    }
    
    return mobile;
  }
  
  Map<String, dynamic> _analyzeContent(Document document) {
    final content = <String, dynamic>{
      'wordCount': 0,
      'paragraphs': 0,
      'readingTime': 0,
      'textToHtmlRatio': 0
    };
    
    // Count words in body text
    final body = document.querySelector('body');
    if (body != null) {
      final text = body.text;
      content['wordCount'] = text.split(RegExp(r'\s+')).length;
      content['paragraphs'] = document.querySelectorAll('p').length;
      content['readingTime'] = (content['wordCount'] / 200).round(); // Average reading speed
      
      // Calculate text to HTML ratio
      final htmlLength = document.outerHtml.length;
      final textLength = text.length;
      content['textToHtmlRatio'] = htmlLength > 0 ? 
        (textLength / htmlLength * 100).round() : 0;
    }
    
    return content;
  }
  
  Map<String, dynamic> _analyzeSocialIntegration(Document document) {
    return {
      'facebook': document.querySelector('[href*="facebook.com"]') != null,
      'twitter': document.querySelector('[href*="twitter.com"]') != null,
      'linkedin': document.querySelector('[href*="linkedin.com"]') != null,
      'instagram': document.querySelector('[href*="instagram.com"]') != null,
      'youtube': document.querySelector('[href*="youtube.com"]') != null
    };
  }
  
  Future<Map<String, dynamic>> _analyzeSchemaOrg(Page page) async {
    try {
      final result = await page.evaluate('''() => {
        const scripts = document.querySelectorAll('script[type="application/ld+json"]');
        const schemas = [];
        
        scripts.forEach(script => {
          try {
            const data = JSON.parse(script.textContent);
            if (data['@context'] && data['@context'].includes('schema.org')) {
              schemas.push({
                type: data['@type'],
                context: data['@context']
              });
            }
          } catch (e) {}
        });
        
        return {
          hasSchema: schemas.length > 0,
          schemas: schemas
        };
      }''');
      
      return result as Map<String, dynamic>;
    } catch (e) {
      return {'hasSchema': false, 'error': e.toString()};
    }
  }
  
  Map<String, dynamic> _checkAMPSupport(Document document) {
    final amp = <String, dynamic>{
      'isAMP': false,
      'hasAMPLink': false,
      'ampUrl': ''
    };
    
    // Check if this is an AMP page
    final html = document.querySelector('html');
    amp['isAMP'] = html?.attributes['amp'] != null || 
                   html?.attributes['⚡'] != null;
    
    // Check for AMP link
    final ampLink = document.querySelector('link[rel="amphtml"]');
    if (ampLink != null) {
      amp['hasAMPLink'] = true;
      amp['ampUrl'] = ampLink.attributes['href'] ?? '';
    }
    
    return amp;
  }
  
  Map<String, dynamic> _analyzeLanguage(Document document) {
    final language = <String, dynamic>{
      'htmlLang': '',
      'contentLanguage': '',
      'hasLangAttribute': false
    };
    
    final html = document.querySelector('html');
    if (html != null) {
      language['htmlLang'] = html.attributes['lang'] ?? '';
      language['hasLangAttribute'] = language['htmlLang'].isNotEmpty;
    }
    
    final contentLang = document.querySelector('meta[http-equiv="content-language"]');
    if (contentLang != null) {
      language['contentLanguage'] = contentLang.attributes['content'] ?? '';
    }
    
    return language;
  }
  
  double _calculateAverageLength(List headings) {
    if (headings.isEmpty) return 0;
    int totalLength = 0;
    for (final heading in headings) {
      totalLength += (heading['text'] as String).length;
    }
    return totalLength / headings.length;
  }
  
  int _calculateSEOScore(Map<String, dynamic> results) {
    int score = 0;
    int maxScore = 0;
    
    // Meta tags (20 points)
    maxScore += 20;
    if (results['metaTags'] != null) {
      if (results['metaTags']['title']['isOptimal'] == true) score += 10;
      if (results['metaTags']['description']['isOptimal'] == true) score += 10;
    }
    
    // Open Graph (10 points)
    maxScore += 10;
    if (results['openGraph']?['present'] == true) {
      score += (results['openGraph']['score'] / 10).round();
    }
    
    // Twitter Card (10 points)
    maxScore += 10;
    if (results['twitterCard']?['present'] == true) {
      score += (results['twitterCard']['score'] / 10).round();
    }
    
    // Structured Data (15 points)
    maxScore += 15;
    if (results['structuredData'] != null) {
      score += (results['structuredData']['score'] * 0.15).round();
    }
    
    // Headings (10 points)
    maxScore += 10;
    if (results['headings'] != null) {
      if ((results['headings']['h1'] as List).length == 1) score += 5;
      if ((results['headings']['issues'] as List).isEmpty) score += 5;
    }
    
    // Images (10 points)
    maxScore += 10;
    if (results['images'] != null) {
      final altCoverage = results['images']['statistics']['altTextCoverage'] ?? 0;
      score += (altCoverage / 10).round();
    }
    
    // Canonical (5 points)
    maxScore += 5;
    if (results['canonical']?['present'] == true && 
        results['canonical']?['isValid'] == true) {
      score += 5;
    }
    
    // Mobile (10 points)
    maxScore += 10;
    if (results['mobileFriendly']?['viewport']?['isResponsive'] == true) {
      score += 10;
    }
    
    // Sitemap & Robots (10 points)
    maxScore += 10;
    if (results['sitemap']?['found'] == true) score += 5;
    if (results['robotsTxt']?['found'] == true) score += 5;
    
    return ((score / maxScore) * 100).round();
  }
  
  List<Map<String, dynamic>> _generateRecommendations(Map<String, dynamic> results) {
    final recommendations = <Map<String, dynamic>>[];
    
    // Title recommendations
    if (results['metaTags']?['title']?['recommendations'] != null) {
      for (final rec in results['metaTags']['title']['recommendations']) {
        recommendations.add({
          'category': 'Meta Tags',
          'priority': 'high',
          'issue': rec,
          'impact': 'Title tags are crucial for SEO and user experience'
        });
      }
    }
    
    // Description recommendations  
    if (results['metaTags']?['description']?['recommendations'] != null) {
      for (final rec in results['metaTags']['description']['recommendations']) {
        recommendations.add({
          'category': 'Meta Tags',
          'priority': 'high',
          'issue': rec,
          'impact': 'Meta descriptions affect click-through rates from search results'
        });
      }
    }
    
    // Open Graph
    if (results['openGraph']?['present'] != true) {
      recommendations.add({
        'category': 'Social Media',
        'priority': 'medium',
        'issue': 'Missing Open Graph tags',
        'impact': 'Open Graph tags control how your content appears when shared on social media'
      });
    }
    
    // Structured Data
    if ((results['structuredData']?['jsonLd'] as List?)?.isEmpty ?? true) {
      recommendations.add({
        'category': 'Structured Data',
        'priority': 'medium',
        'issue': 'No structured data (JSON-LD) found',
        'impact': 'Structured data helps search engines understand your content and can enable rich snippets'
      });
    }
    
    // Images without alt text
    if ((results['images']?['withoutAlt'] as List?)?.isNotEmpty ?? false) {
      recommendations.add({
        'category': 'Accessibility',
        'priority': 'high',
        'issue': 'Images without alt text found',
        'impact': 'Alt text improves accessibility and helps search engines understand image content',
        'count': (results['images']['withoutAlt'] as List).length
      });
    }
    
    // Missing H1
    if ((results['headings']?['h1'] as List?)?.isEmpty ?? true) {
      recommendations.add({
        'category': 'Content Structure',
        'priority': 'high',
        'issue': 'Missing H1 tag',
        'impact': 'H1 tags help search engines understand the main topic of your page'
      });
    }
    
    // No canonical URL
    if (results['canonical']?['present'] != true) {
      recommendations.add({
        'category': 'Technical SEO',
        'priority': 'medium',
        'issue': 'No canonical URL specified',
        'impact': 'Canonical URLs help prevent duplicate content issues'
      });
    }
    
    // Mobile viewport
    if (results['mobileFriendly']?['viewport']?['isResponsive'] != true) {
      recommendations.add({
        'category': 'Mobile',
        'priority': 'high',
        'issue': 'Page is not mobile-friendly',
        'impact': 'Mobile-friendliness is a ranking factor and affects user experience'
      });
    }
    
    // Sitemap
    if (results['sitemap']?['found'] != true) {
      recommendations.add({
        'category': 'Technical SEO',
        'priority': 'medium',
        'issue': 'XML sitemap not found',
        'impact': 'Sitemaps help search engines discover and index your pages'
      });
    }
    
    return recommendations;
  }
}

// Extension for AuditContext to hold SEO results
extension SEOContext on AuditContext {
  static final _seoComplete = Expando<Map<String, dynamic>>();
  
  Map<String, dynamic>? get seoComplete => _seoComplete[this];
  set seoComplete(Map<String, dynamic>? value) => _seoComplete[this] = value;
}