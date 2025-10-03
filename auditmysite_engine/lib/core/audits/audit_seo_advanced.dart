import 'package:puppeteer/puppeteer.dart';
import '../events.dart';
import 'audit_base.dart';
import 'dart:math' as math;

/// Advanced SEO Audit with feature parity to NPM tool
class AdvancedSEOAudit extends Audit {
  @override
  String get name => 'seo_advanced';

  @override
  Future<void> run(AuditContext ctx) async {
    final page = ctx.page as Page;

    // Comprehensive SEO data extraction
    final seoData = await page.evaluate(r'''
() => {
  const result = {
    // Meta tags
    title: null,
    metaDescription: null,
    metaKeywords: null,
    canonical: null,
    robots: null,
    viewport: null,
    
    // Open Graph
    openGraph: {},
    
    // Twitter Card
    twitterCard: {},
    
    // Headings
    headings: {
      h1: [],
      h2: [],
      h3: [],
      h4: [],
      h5: [],
      h6: []
    },
    
    // Images
    images: {
      total: 0,
      withAlt: 0,
      withoutAlt: 0,
      emptyAlt: 0,
      lazyLoaded: 0
    },
    
    // Links
    links: {
      internal: 0,
      external: 0,
      nofollow: 0,
      total: 0,
      anchors: []
    },
    
    // Content metrics
    textContent: '',
    wordCount: 0,
    paragraphCount: 0,
    
    // Structured data
    structuredData: [],
    
    // Page metrics
    htmlSize: 0
  };

  // Extract title
  const titleElement = document.querySelector('title');
  if (titleElement) {
    result.title = {
      content: titleElement.textContent.trim(),
      length: titleElement.textContent.trim().length
    };
  }

  // Extract meta tags
  const metaDescription = document.querySelector('meta[name="description"]');
  if (metaDescription) {
    const content = metaDescription.getAttribute('content') || '';
    result.metaDescription = {
      content: content.trim(),
      length: content.trim().length
    };
  }

  const metaKeywords = document.querySelector('meta[name="keywords"]');
  if (metaKeywords) {
    result.metaKeywords = metaKeywords.getAttribute('content');
  }

  const canonical = document.querySelector('link[rel="canonical"]');
  if (canonical) {
    result.canonical = canonical.getAttribute('href');
  }

  const robots = document.querySelector('meta[name="robots"]');
  if (robots) {
    result.robots = robots.getAttribute('content');
  }

  const viewport = document.querySelector('meta[name="viewport"]');
  if (viewport) {
    result.viewport = viewport.getAttribute('content');
  }

  // Extract Open Graph tags
  document.querySelectorAll('meta[property^="og:"]').forEach(tag => {
    const property = tag.getAttribute('property').replace('og:', '');
    const content = tag.getAttribute('content');
    if (content) {
      result.openGraph[property] = content;
    }
  });

  // Extract Twitter Card tags
  document.querySelectorAll('meta[name^="twitter:"]').forEach(tag => {
    const name = tag.getAttribute('name').replace('twitter:', '');
    const content = tag.getAttribute('content');
    if (content) {
      result.twitterCard[name] = content;
    }
  });

  // Extract headings
  ['h1', 'h2', 'h3', 'h4', 'h5', 'h6'].forEach(tag => {
    const headings = document.querySelectorAll(tag);
    headings.forEach(heading => {
      result.headings[tag].push({
        text: heading.textContent.trim(),
        id: heading.id || null,
        length: heading.textContent.trim().length
      });
    });
  });

  // Analyze images
  const images = document.querySelectorAll('img');
  result.images.total = images.length;
  
  images.forEach(img => {
    const alt = img.getAttribute('alt');
    const loading = img.getAttribute('loading');
    
    if (alt === null) {
      result.images.withoutAlt++;
    } else if (alt.trim() === '') {
      result.images.emptyAlt++;
    } else {
      result.images.withAlt++;
    }
    
    if (loading === 'lazy') {
      result.images.lazyLoaded++;
    }
  });

  // Analyze links
  const links = document.querySelectorAll('a[href]');
  const currentHost = window.location.hostname;
  
  links.forEach(link => {
    const href = link.getAttribute('href') || '';
    const rel = link.getAttribute('rel') || '';
    const text = link.textContent.trim();
    
    result.links.total++;
    result.links.anchors.push(text);
    
    if (rel.includes('nofollow')) {
      result.links.nofollow++;
    }
    
    try {
      if (href.startsWith('http://') || href.startsWith('https://')) {
        const url = new URL(href);
        if (url.hostname === currentHost || url.hostname === 'www.' + currentHost) {
          result.links.internal++;
        } else {
          result.links.external++;
        }
      } else if (!href.startsWith('mailto:') && !href.startsWith('tel:') && !href.startsWith('javascript:') && !href.startsWith('#')) {
        result.links.internal++;
      }
    } catch (e) {
      result.links.internal++;
    }
  });

  // Extract text content for analysis
  const bodyElement = document.body;
  if (bodyElement) {
    // Remove script and style content
    const clonedBody = bodyElement.cloneNode(true);
    clonedBody.querySelectorAll('script, style, noscript').forEach(el => el.remove());
    
    result.textContent = clonedBody.textContent || '';
    const words = result.textContent.split(/\s+/).filter(w => w.length > 0);
    result.wordCount = words.length;
    
    const paragraphs = bodyElement.querySelectorAll('p');
    result.paragraphCount = paragraphs.length;
  }

  // Extract structured data
  const structuredDataScripts = document.querySelectorAll('script[type="application/ld+json"]');
  structuredDataScripts.forEach(script => {
    try {
      const data = JSON.parse(script.textContent);
      result.structuredData.push(data);
    } catch (e) {
      // Invalid JSON
    }
  });

  // Calculate HTML size
  result.htmlSize = document.documentElement.outerHTML.length;

  return result;
}
    ''');

    // Perform comprehensive analysis
    final analysis = _performComprehensiveSEOAnalysis(seoData);
    
    // Store result in context
    ctx.seoResult = analysis;
  }

  Map<String, dynamic> _performComprehensiveSEOAnalysis(Map<String, dynamic> data) {
    final issues = <Map<String, dynamic>>[];
    final recommendations = <String>[];
    
    // Title analysis
    final titleAnalysis = _analyzeTitleTag(data['title']);
    issues.addAll(titleAnalysis['issues'] as List<Map<String, dynamic>>);
    recommendations.addAll(titleAnalysis['recommendations'] as List<String>);
    
    // Meta description analysis
    final descAnalysis = _analyzeMetaDescription(data['metaDescription']);
    issues.addAll(descAnalysis['issues'] as List<Map<String, dynamic>>);
    recommendations.addAll(descAnalysis['recommendations'] as List<String>);
    
    // Heading structure analysis
    final headingAnalysis = _analyzeHeadingStructure(data['headings'] as Map<String, dynamic>);
    
    // Image optimization analysis
    final imageAnalysis = _analyzeImages(data['images'] as Map<String, dynamic>);
    
    // Link structure analysis
    final linkAnalysis = _analyzeLinkStructure(data['links'] as Map<String, dynamic>);
    
    // Content quality analysis
    final contentAnalysis = _analyzeContentQuality(
      data['textContent'] as String? ?? '',
      data['wordCount'] as int? ?? 0,
      data['title']?['content'] as String? ?? ''
    );
    
    // Readability analysis
    final readabilityScore = _calculateReadabilityScore(
      data['textContent'] as String? ?? '',
      data['wordCount'] as int? ?? 0
    );
    
    // Keyword density analysis
    final keywordAnalysis = _analyzeKeywordDensity(
      data['textContent'] as String? ?? '',
      data['title']?['content'] as String? ?? ''
    );
    
    // Semantic SEO analysis
    final semanticAnalysis = _analyzeSemanticSEO(
      data['textContent'] as String? ?? '',
      data['title']?['content'] as String? ?? ''
    );
    
    // Voice search optimization
    final voiceSearchAnalysis = _analyzeVoiceSearchOptimization(
      data['textContent'] as String? ?? '',
      data['headings'] as Map<String, dynamic>
    );
    
    // E-A-T analysis
    final eatAnalysis = _analyzeEAT(
      data['textContent'] as String? ?? '',
      data['structuredData'] as List? ?? []
    );
    
    // Search visibility estimation
    final searchVisibility = _estimateSearchVisibility(
      titleAnalysis,
      descAnalysis,
      contentAnalysis,
      linkAnalysis
    );
    
    // Calculate overall SEO score
    final seoScore = _calculateSEOScore(
      titleAnalysis,
      descAnalysis,
      headingAnalysis,
      imageAnalysis,
      linkAnalysis,
      contentAnalysis,
      semanticAnalysis
    );
    
    final seoGrade = _calculateGrade(seoScore);
    
    return {
      'score': seoScore,
      'grade': seoGrade,
      'title': titleAnalysis,
      'metaDescription': descAnalysis,
      'headings': headingAnalysis,
      'images': imageAnalysis,
      'links': linkAnalysis,
      'content': contentAnalysis,
      'readabilityScore': readabilityScore,
      'keywords': keywordAnalysis,
      'semantic': semanticAnalysis,
      'voiceSearch': voiceSearchAnalysis,
      'eat': eatAnalysis,
      'searchVisibility': searchVisibility,
      'openGraph': data['openGraph'],
      'twitterCard': data['twitterCard'],
      'structuredData': data['structuredData'],
      'issues': issues,
      'recommendations': recommendations,
      'textToCodeRatio': _calculateTextToCodeRatio(
        data['textContent']?.toString().length ?? 0,
        data['htmlSize'] as int? ?? 1
      ),
    };
  }

  Map<String, dynamic> _analyzeTitleTag(dynamic titleData) {
    final issues = <Map<String, dynamic>>[];
    final recommendations = <String>[];
    
    if (titleData == null) {
      issues.add({
        'type': 'title-missing',
        'severity': 'error',
        'message': 'Title tag is missing',
      });
      recommendations.add('Add a descriptive title tag (30-60 characters)');
      return {
        'present': false,
        'content': null,
        'length': 0,
        'optimal': false,
        'issues': issues,
        'recommendations': recommendations,
      };
    }
    
    final content = titleData['content'] as String;
    final length = titleData['length'] as int;
    var optimal = true;
    
    if (length < 30) {
      optimal = false;
      issues.add({
        'type': 'title-short',
        'severity': 'warning',
        'message': 'Title is too short ($length characters)',
      });
      recommendations.add('Expand title to 30-60 characters for optimal SEO');
    } else if (length > 60) {
      optimal = false;
      issues.add({
        'type': 'title-long',
        'severity': 'warning',
        'message': 'Title is too long ($length characters)',
      });
      recommendations.add('Shorten title to under 60 characters to prevent truncation');
    }
    
    // Check for keyword stuffing
    final words = content.toLowerCase().split(' ');
    final uniqueWords = words.toSet();
    if (words.length > 5 && uniqueWords.length < words.length * 0.7) {
      optimal = false;
      issues.add({
        'type': 'title-repetitive',
        'severity': 'warning',
        'message': 'Title contains repetitive words',
      });
      recommendations.add('Avoid keyword stuffing in title');
    }
    
    return {
      'present': true,
      'content': content,
      'length': length,
      'optimal': optimal,
      'issues': issues,
      'recommendations': recommendations,
    };
  }

  Map<String, dynamic> _analyzeMetaDescription(dynamic descData) {
    final issues = <Map<String, dynamic>>[];
    final recommendations = <String>[];
    
    if (descData == null) {
      issues.add({
        'type': 'description-missing',
        'severity': 'error',
        'message': 'Meta description is missing',
      });
      recommendations.add('Add a compelling meta description (120-160 characters)');
      return {
        'present': false,
        'content': null,
        'length': 0,
        'optimal': false,
        'issues': issues,
        'recommendations': recommendations,
      };
    }
    
    final content = descData['content'] as String;
    final length = descData['length'] as int;
    var optimal = true;
    
    if (length < 120) {
      optimal = false;
      issues.add({
        'type': 'description-short',
        'severity': 'warning',
        'message': 'Description is too short ($length characters)',
      });
      recommendations.add('Expand description to 120-160 characters');
    } else if (length > 160) {
      optimal = false;
      issues.add({
        'type': 'description-long',
        'severity': 'warning',
        'message': 'Description is too long ($length characters)',
      });
      recommendations.add('Shorten description to under 160 characters');
    }
    
    return {
      'present': true,
      'content': content,
      'length': length,
      'optimal': optimal,
      'issues': issues,
      'recommendations': recommendations,
    };
  }

  Map<String, dynamic> _analyzeHeadingStructure(Map<String, dynamic> headings) {
    final issues = <Map<String, dynamic>>[];
    final recommendations = <String>[];
    
    final h1Count = (headings['h1'] as List).length;
    final h2Count = (headings['h2'] as List).length;
    final h3Count = (headings['h3'] as List).length;
    
    // Check H1
    if (h1Count == 0) {
      issues.add({
        'type': 'h1-missing',
        'severity': 'error',
        'message': 'No H1 tag found',
      });
      recommendations.add('Add a single H1 tag with main topic');
    } else if (h1Count > 1) {
      issues.add({
        'type': 'h1-multiple',
        'severity': 'warning',
        'message': 'Multiple H1 tags found ($h1Count)',
      });
      recommendations.add('Use only one H1 tag per page');
    }
    
    // Check hierarchy
    if (h3Count > 0 && h2Count == 0) {
      issues.add({
        'type': 'heading-hierarchy',
        'severity': 'warning',
        'message': 'H3 tags without H2 tags',
      });
      recommendations.add('Maintain proper heading hierarchy (H1 → H2 → H3)');
    }
    
    return {
      'h1Count': h1Count,
      'h2Count': h2Count,
      'h3Count': h3Count,
      'hierarchyValid': h1Count > 0 && (h3Count == 0 || h2Count > 0),
      'issues': issues,
      'recommendations': recommendations,
    };
  }

  Map<String, dynamic> _analyzeImages(Map<String, dynamic> images) {
    final total = images['total'] as int? ?? 0;
    final withAlt = images['withAlt'] as int? ?? 0;
    final withoutAlt = images['withoutAlt'] as int? ?? 0;
    final lazyLoaded = images['lazyLoaded'] as int? ?? 0;
    
    final issues = <Map<String, dynamic>>[];
    final recommendations = <String>[];
    
    if (withoutAlt > 0) {
      issues.add({
        'type': 'images-no-alt',
        'severity': 'error',
        'message': '$withoutAlt images without alt text',
      });
      recommendations.add('Add descriptive alt text to all images');
    }
    
    if (total > 0 && lazyLoaded == 0) {
      recommendations.add('Consider lazy loading images to improve performance');
    }
    
    final score = total > 0 ? (withAlt / total * 100).round() : 100;
    
    return {
      'total': total,
      'withAlt': withAlt,
      'withoutAlt': withoutAlt,
      'lazyLoaded': lazyLoaded,
      'score': score,
      'issues': issues,
      'recommendations': recommendations,
    };
  }

  Map<String, dynamic> _analyzeLinkStructure(Map<String, dynamic> links) {
    final internal = links['internal'] as int? ?? 0;
    final external = links['external'] as int? ?? 0;
    final total = links['total'] as int? ?? 0;
    final nofollow = links['nofollow'] as int? ?? 0;
    
    final recommendations = <String>[];
    
    if (internal == 0) {
      recommendations.add('Add internal links to improve site structure');
    } else if (internal < 3) {
      recommendations.add('Consider adding more internal links');
    }
    
    if (external > internal * 2) {
      recommendations.add('Balance external links with more internal links');
    }
    
    final linkRatio = total > 0 ? (internal / total * 100).round() : 0;
    
    return {
      'internal': internal,
      'external': external,
      'total': total,
      'nofollow': nofollow,
      'linkRatio': linkRatio,
      'recommendations': recommendations,
    };
  }

  Map<String, dynamic> _analyzeContentQuality(String content, int wordCount, String title) {
    final recommendations = <String>[];
    var qualityScore = 50;
    
    // Word count analysis
    if (wordCount < 300) {
      recommendations.add('Content is too short. Aim for at least 300 words');
      qualityScore -= 20;
    } else if (wordCount >= 300 && wordCount < 600) {
      recommendations.add('Consider expanding content to 600+ words for better SEO');
      qualityScore += 10;
    } else if (wordCount >= 600 && wordCount < 1500) {
      qualityScore += 30;
    } else if (wordCount >= 1500) {
      qualityScore += 40;
    }
    
    // Check for keyword presence in content
    if (title.isNotEmpty) {
      final titleWords = title.toLowerCase().split(' ')
        .where((w) => w.length > 3).toList();
      var keywordMatches = 0;
      for (final word in titleWords) {
        if (content.toLowerCase().contains(word)) {
          keywordMatches++;
        }
      }
      
      final keywordCoverage = titleWords.isNotEmpty ? 
        (keywordMatches / titleWords.length * 100).round() : 0;
      
      if (keywordCoverage < 50) {
        recommendations.add('Improve keyword consistency between title and content');
        qualityScore -= 10;
      }
    }
    
    return {
      'wordCount': wordCount,
      'qualityScore': qualityScore.clamp(0, 100),
      'recommendations': recommendations,
    };
  }

  double _calculateReadabilityScore(String text, int wordCount) {
    if (text.isEmpty || wordCount == 0) return 0;
    
    // Count sentences
    final sentences = text.split(RegExp(r'[.!?]+'))
      .where((s) => s.trim().isNotEmpty).length;
    
    if (sentences == 0) return 0;
    
    // Count syllables (simplified)
    var syllableCount = 0;
    final words = text.toLowerCase().split(RegExp(r'\s+'));
    for (final word in words) {
      syllableCount += _countSyllables(word);
    }
    
    // Flesch Reading Ease formula
    final avgWordsPerSentence = wordCount / sentences;
    final avgSyllablesPerWord = syllableCount / wordCount;
    
    final fleschScore = 206.835 - 
      1.015 * avgWordsPerSentence - 
      84.6 * avgSyllablesPerWord;
    
    return fleschScore.clamp(0, 100);
  }

  int _countSyllables(String word) {
    if (word.isEmpty) return 0;
    
    // Simple syllable counting
    final vowels = 'aeiouy';
    var count = 0;
    var previousWasVowel = false;
    
    for (var i = 0; i < word.length; i++) {
      final isVowel = vowels.contains(word[i]);
      if (isVowel && !previousWasVowel) {
        count++;
      }
      previousWasVowel = isVowel;
    }
    
    // Adjust for silent e
    if (word.endsWith('e')) {
      count--;
    }
    
    // Ensure at least one syllable
    return count < 1 ? 1 : count;
  }

  Map<String, dynamic> _analyzeKeywordDensity(String text, String title) {
    final words = text.toLowerCase().split(RegExp(r'\s+'))
      .where((w) => w.length > 3)
      .map((w) => w.replaceAll(RegExp(r'[^a-z0-9]'), ''))
      .where((w) => w.isNotEmpty)
      .toList();
    
    final wordFreq = <String, int>{};
    for (final word in words) {
      wordFreq[word] = (wordFreq[word] ?? 0) + 1;
    }
    
    var topKeywords = wordFreq.entries
      .map((e) => {
        'word': e.key,
        'count': e.value,
        'density': (e.value / words.length * 100).toStringAsFixed(2),
      })
      .toList();
    
    topKeywords.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    
    return {
      'topKeywords': topKeywords.take(10).toList(),
      'totalWords': words.length,
    };
  }

  Map<String, dynamic> _analyzeSemanticSEO(String content, String title) {
    final words = content.toLowerCase().split(RegExp(r'\s+'))
      .where((w) => w.length > 3).toList();
    
    // Simplified topic clustering
    final topicClusters = <String>[];
    final commonTopics = {
      'technology': ['software', 'computer', 'digital', 'tech', 'system'],
      'business': ['company', 'business', 'enterprise', 'corporate', 'market'],
      'marketing': ['marketing', 'advertising', 'campaign', 'brand', 'promotion'],
      'health': ['health', 'medical', 'wellness', 'fitness', 'doctor'],
      'education': ['learning', 'education', 'school', 'university', 'course'],
    };
    
    for (final topic in commonTopics.entries) {
      var matchCount = 0;
      for (final keyword in topic.value) {
        if (words.contains(keyword)) {
          matchCount++;
        }
      }
      if (matchCount >= 2) {
        topicClusters.add(topic.key);
      }
    }
    
    // Content depth score
    var contentDepthScore = 50;
    if (words.length > 1500) contentDepthScore += 30;
    if (topicClusters.length > 2) contentDepthScore += 20;
    
    final semanticScore = (contentDepthScore * 0.7 + topicClusters.length * 10)
      .clamp(0, 100).round();
    
    return {
      'semanticScore': semanticScore,
      'topicClusters': topicClusters,
      'contentDepthScore': contentDepthScore,
    };
  }

  Map<String, dynamic> _analyzeVoiceSearchOptimization(String content, Map<String, dynamic> headings) {
    var voiceSearchScore = 0;
    final recommendations = <String>[];
    
    // Count question phrases
    final questionWords = ['what', 'how', 'why', 'when', 'where', 'who'];
    var questionPhrases = 0;
    
    for (final word in questionWords) {
      final regex = RegExp('\\b$word\\b', caseSensitive: false);
      questionPhrases += regex.allMatches(content).length;
    }
    
    // Check for conversational tone
    final conversationalWords = ['you', 'your', 'we', 'our'];
    var conversationalCount = 0;
    
    for (final word in conversationalWords) {
      final regex = RegExp('\\b$word\\b', caseSensitive: false);
      conversationalCount += regex.allMatches(content).length;
    }
    
    final conversationalContent = conversationalCount > content.split(' ').length * 0.01;
    
    // Calculate score
    if (questionPhrases > 0) voiceSearchScore += 30;
    if (questionPhrases > 3) voiceSearchScore += 20;
    if (conversationalContent) voiceSearchScore += 30;
    
    // Check headings for questions
    var questionHeadings = 0;
    for (final level in headings.values) {
      if (level is List) {
        for (final heading in level) {
          final text = heading['text']?.toString().toLowerCase() ?? '';
          if (questionWords.any((w) => text.startsWith(w))) {
            questionHeadings++;
          }
        }
      }
    }
    
    if (questionHeadings > 0) voiceSearchScore += 20;
    
    if (questionPhrases < 2) {
      recommendations.add('Add question-based content for voice search optimization');
    }
    if (!conversationalContent) {
      recommendations.add('Use more conversational language');
    }
    
    return {
      'voiceSearchScore': voiceSearchScore.clamp(0, 100),
      'questionPhrases': questionPhrases,
      'conversationalContent': conversationalContent,
      'recommendations': recommendations,
    };
  }

  Map<String, dynamic> _analyzeEAT(String content, List structuredData) {
    var eatScore = 30; // Base score
    final signals = <String>[];
    
    // Check for author information
    if (content.contains('author') || content.contains('written by')) {
      eatScore += 20;
      signals.add('Author information present');
    }
    
    // Check for credentials
    final credentialKeywords = ['phd', 'md', 'expert', 'certified', 'professional'];
    for (final keyword in credentialKeywords) {
      if (content.toLowerCase().contains(keyword)) {
        eatScore += 10;
        signals.add('Credentials mentioned');
        break;
      }
    }
    
    // Check structured data for author/organization
    if (structuredData.isNotEmpty) {
      for (final data in structuredData) {
        if (data is Map) {
          if (data['@type'] == 'Person' || data['@type'] == 'Organization') {
            eatScore += 20;
            signals.add('Structured data for author/org');
          }
          if (data['author'] != null) {
            eatScore += 10;
            signals.add('Author in structured data');
          }
        }
      }
    }
    
    // Check for citations/sources
    if (content.contains('source') || content.contains('reference')) {
      eatScore += 10;
      signals.add('Sources/references mentioned');
    }
    
    return {
      'eatScore': eatScore.clamp(0, 100),
      'signals': signals,
    };
  }

  Map<String, dynamic> _estimateSearchVisibility(
    Map<String, dynamic> title,
    Map<String, dynamic> description,
    Map<String, dynamic> content,
    Map<String, dynamic> links,
  ) {
    var visibilityScore = 0;
    
    // Title optimization
    if (title['optimal'] == true) visibilityScore += 25;
    else if (title['present'] == true) visibilityScore += 15;
    
    // Description optimization
    if (description['optimal'] == true) visibilityScore += 20;
    else if (description['present'] == true) visibilityScore += 10;
    
    // Content quality
    final contentScore = content['qualityScore'] as int? ?? 0;
    visibilityScore += (contentScore * 0.3).round();
    
    // Link structure
    final linkRatio = links['linkRatio'] as int? ?? 0;
    if (linkRatio > 30 && linkRatio < 70) {
      visibilityScore += 15;
    }
    
    return {
      'score': visibilityScore.clamp(0, 100),
      'likelihood': visibilityScore > 70 ? 'high' : 
                   visibilityScore > 40 ? 'medium' : 'low',
    };
  }

  double _calculateTextToCodeRatio(int textLength, int htmlSize) {
    if (htmlSize == 0) return 0;
    return (textLength / htmlSize * 100);
  }

  double _calculateSEOScore(
    Map<String, dynamic> title,
    Map<String, dynamic> description,
    Map<String, dynamic> headings,
    Map<String, dynamic> images,
    Map<String, dynamic> links,
    Map<String, dynamic> content,
    Map<String, dynamic> semantic,
  ) {
    double score = 0;
    
    // Title score (20%)
    if (title['optimal'] == true) score += 20;
    else if (title['present'] == true) score += 10;
    
    // Description score (15%)
    if (description['optimal'] == true) score += 15;
    else if (description['present'] == true) score += 7;
    
    // Headings score (15%)
    if (headings['hierarchyValid'] == true) score += 15;
    else score += 5;
    
    // Images score (10%)
    final imageScore = images['score'] as int? ?? 0;
    score += imageScore * 0.1;
    
    // Links score (10%)
    final linkRatio = links['linkRatio'] as int? ?? 0;
    if (linkRatio > 30 && linkRatio < 70) score += 10;
    else score += 5;
    
    // Content quality (20%)
    final contentScore = content['qualityScore'] as int? ?? 0;
    score += contentScore * 0.2;
    
    // Semantic SEO (10%)
    final semanticScore = semantic['semanticScore'] as int? ?? 0;
    score += semanticScore * 0.1;
    
    return score.clamp(0, 100);
  }

  String _calculateGrade(double score) {
    if (score >= 90) return 'A';
    if (score >= 80) return 'B';
    if (score >= 70) return 'C';
    if (score >= 60) return 'D';
    return 'F';
  }
}