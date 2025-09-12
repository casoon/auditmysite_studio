import 'package:puppeteer/puppeteer.dart';
import '../events.dart';
import 'audit_base.dart';

/// SEO issue detected during analysis
class SEOIssue {
  final String type;
  final String severity;
  final String message;
  final String? selector;

  SEOIssue({
    required this.type,
    required this.severity,
    required this.message,
    this.selector,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'severity': severity,
    'message': message,
    'selector': selector,
  };
}

/// SEO optimal length thresholds
class SEOThresholds {
  static const int titleMinLength = 30;
  static const int titleMaxLength = 60;
  static const int descriptionMinLength = 120;
  static const int descriptionMaxLength = 160;
}

class SEOAudit implements Audit {
  @override
  String get name => 'seo';

  @override
  Future<void> run(AuditContext ctx) async {
    final page = ctx.page as Page;

    // Extract comprehensive SEO data
    final seoData = await page.evaluate(r'''
() => {
  const result = {
    title: null,
    metaDescription: null,
    canonical: null,
    openGraph: {},
    twitterCard: {},
    headings: {
      h1: [],
      h2: [],
      h3: [],
      h4: [],
      h5: [],
      h6: []
    },
    images: {
      total: 0,
      withAlt: 0,
      withoutAlt: 0,
      emptyAlt: 0
    }
  };

  // Extract title
  const titleElement = document.querySelector('title');
  if (titleElement) {
    result.title = {
      content: titleElement.textContent.trim(),
      length: titleElement.textContent.trim().length
    };
  }

  // Extract meta description
  const descriptionElement = document.querySelector('meta[name="description"]');
  if (descriptionElement) {
    const content = descriptionElement.getAttribute('content') || '';
    result.metaDescription = {
      content: content.trim(),
      length: content.trim().length
    };
  }

  // Extract canonical URL
  const canonicalElement = document.querySelector('link[rel="canonical"]');
  if (canonicalElement) {
    result.canonical = canonicalElement.getAttribute('href');
  }

  // Extract Open Graph tags
  const ogTags = document.querySelectorAll('meta[property^="og:"]');
  ogTags.forEach(tag => {
    const property = tag.getAttribute('property').replace('og:', '');
    const content = tag.getAttribute('content');
    if (content) {
      result.openGraph[property] = content;
    }
  });

  // Extract Twitter Card tags
  const twitterTags = document.querySelectorAll('meta[name^="twitter:"]');
  twitterTags.forEach(tag => {
    const name = tag.getAttribute('name').replace('twitter:', '');
    const content = tag.getAttribute('content');
    if (content) {
      result.twitterCard[name] = content;
    }
  });

  // Extract headings structure
  ['h1', 'h2', 'h3', 'h4', 'h5', 'h6'].forEach(tagName => {
    const headings = document.querySelectorAll(tagName);
    headings.forEach(heading => {
      result.headings[tagName].push({
        text: heading.textContent.trim(),
        id: heading.id || null
      });
    });
  });

  // Analyze images
  const images = document.querySelectorAll('img');
  result.images.total = images.length;
  
  images.forEach(img => {
    const alt = img.getAttribute('alt');
    if (alt === null) {
      result.images.withoutAlt++;
    } else if (alt.trim() === '') {
      result.images.emptyAlt++;
    } else {
      result.images.withAlt++;
    }
  });

  return result;
}
''');

    // Generate comprehensive SEO result
    final seoResult = _generateSEOResult(seoData);
    
    // Store SEO result in context
    ctx.seoResult = seoResult;
  }
  
  /// Generate complete SEOResult according to TypeScript interface
  Map<String, dynamic> _generateSEOResult(Map<String, dynamic> seoData) {
    final issues = <SEOIssue>[];
    
    // Analyze title
    Map<String, dynamic>? titleAnalysis;
    final titleData = seoData['title'] as Map<String, dynamic>?;
    if (titleData != null) {
      final content = titleData['content'] as String;
      final length = titleData['length'] as int;
      final optimal = length >= SEOThresholds.titleMinLength && length <= SEOThresholds.titleMaxLength;
      
      titleAnalysis = {
        'content': content,
        'length': length,
        'optimal': optimal,
      };
      
      if (length < SEOThresholds.titleMinLength) {
        issues.add(SEOIssue(
          type: 'title-short',
          severity: 'warning',
          message: 'Title is too short ($length characters). Should be between ${SEOThresholds.titleMinLength}-${SEOThresholds.titleMaxLength} characters for optimal SEO.',
          selector: 'title',
        ));
      } else if (length > SEOThresholds.titleMaxLength) {
        issues.add(SEOIssue(
          type: 'title-long',
          severity: 'warning',
          message: 'Title is too long ($length characters). Should be between ${SEOThresholds.titleMinLength}-${SEOThresholds.titleMaxLength} characters for optimal SEO.',
          selector: 'title',
        ));
      }
    } else {
      issues.add(SEOIssue(
        type: 'title-missing',
        severity: 'error',
        message: 'Missing title tag. Every page should have a descriptive title.',
        selector: 'title',
      ));
    }
    
    // Analyze meta description
    Map<String, dynamic>? descriptionAnalysis;
    final descData = seoData['metaDescription'] as Map<String, dynamic>?;
    if (descData != null) {
      final content = descData['content'] as String;
      final length = descData['length'] as int;
      final optimal = length >= SEOThresholds.descriptionMinLength && length <= SEOThresholds.descriptionMaxLength;
      
      descriptionAnalysis = {
        'content': content,
        'length': length,
        'optimal': optimal,
      };
      
      if (length < SEOThresholds.descriptionMinLength) {
        issues.add(SEOIssue(
          type: 'description-short',
          severity: 'warning',
          message: 'Meta description is too short ($length characters). Should be between ${SEOThresholds.descriptionMinLength}-${SEOThresholds.descriptionMaxLength} characters for optimal SEO.',
          selector: 'meta[name="description"]',
        ));
      } else if (length > SEOThresholds.descriptionMaxLength) {
        issues.add(SEOIssue(
          type: 'description-long',
          severity: 'warning',
          message: 'Meta description is too long ($length characters). Should be between ${SEOThresholds.descriptionMinLength}-${SEOThresholds.descriptionMaxLength} characters for optimal SEO.',
          selector: 'meta[name="description"]',
        ));
      }
    } else {
      issues.add(SEOIssue(
        type: 'description-missing',
        severity: 'error',
        message: 'Missing meta description. Every page should have a descriptive meta description.',
        selector: 'meta[name="description"]',
      ));
    }
    
    // Analyze heading structure
    final headingsData = seoData['headings'] as Map<String, dynamic>;
    final h1Count = (headingsData['h1'] as List).length;
    final headingIssues = <String>[];
    
    if (h1Count == 0) {
      issues.add(SEOIssue(
        type: 'h1-missing',
        severity: 'error',
        message: 'Missing H1 heading. Every page should have exactly one H1 heading.',
        selector: 'h1',
      ));
      headingIssues.add('Missing H1 heading');
    } else if (h1Count > 1) {
      issues.add(SEOIssue(
        type: 'h1-multiple',
        severity: 'warning',
        message: 'Multiple H1 headings found ($h1Count). Pages should have only one H1 heading.',
        selector: 'h1',
      ));
      headingIssues.add('Multiple H1 headings ($h1Count found)');
    }
    
    // Analyze images
    final imagesData = seoData['images'] as Map<String, dynamic>;
    final totalImages = imagesData['total'] as int;
    final missingAlt = imagesData['withoutAlt'] as int;
    final emptyAlt = imagesData['emptyAlt'] as int;
    
    if (missingAlt > 0) {
      issues.add(SEOIssue(
        type: 'image-alt-missing',
        severity: 'error',
        message: '$missingAlt images are missing alt attributes. All images should have descriptive alt text for accessibility and SEO.',
        selector: 'img:not([alt])',
      ));
    }
    
    if (emptyAlt > 0) {
      issues.add(SEOIssue(
        type: 'image-alt-empty',
        severity: 'warning',
        message: '$emptyAlt images have empty alt attributes. Consider adding descriptive alt text or use alt="" only for decorative images.',
        selector: 'img[alt=""]',
      ));
    }
    
    // Calculate SEO score (0-100)
    final score = _calculateSEOScore(titleAnalysis != null, descriptionAnalysis != null, h1Count, missingAlt, emptyAlt, totalImages);
    
    // Calculate grade (A-F)
    final grade = _calculateGrade(score);
    
    return {
      'score': score,
      'grade': grade,
      'metaTags': {
        'title': titleAnalysis,
        'description': descriptionAnalysis,
        'canonical': seoData['canonical'],
        'openGraph': seoData['openGraph'] ?? {},
        'twitterCard': seoData['twitterCard'] ?? {},
      },
      'headings': {
        'h1': (headingsData['h1'] as List).map((h) => h['text']).toList(),
        'h2': (headingsData['h2'] as List).map((h) => h['text']).toList(),
        'h3': (headingsData['h3'] as List).map((h) => h['text']).toList(),
        'issues': headingIssues,
      },
      'images': {
        'total': totalImages,
        'missingAlt': missingAlt,
        'emptyAlt': emptyAlt,
      },
      'issues': issues.map((issue) => issue.toJson()).toList(),
    };
  }
  
  /// Calculate overall SEO score (0-100)
  int _calculateSEOScore(bool hasTitle, bool hasDescription, int h1Count, int missingAlt, int emptyAlt, int totalImages) {
    var score = 100;
    
    // Title scoring (25% weight)
    if (!hasTitle) {
      score -= 25;
    }
    
    // Meta description scoring (20% weight)
    if (!hasDescription) {
      score -= 20;
    }
    
    // H1 heading scoring (20% weight)
    if (h1Count == 0) {
      score -= 20;
    } else if (h1Count > 1) {
      score -= 10;
    }
    
    // Image alt text scoring (35% weight)
    if (totalImages > 0) {
      final altPenalty = ((missingAlt + (emptyAlt * 0.5)) / totalImages * 35).round();
      score -= altPenalty;
    }
    
    return (score < 0) ? 0 : score;
  }
  
  /// Calculate grade (A-F) from score
  String _calculateGrade(int score) {
    if (score >= 90) return 'A';
    if (score >= 80) return 'B';
    if (score >= 70) return 'C';
    if (score >= 60) return 'D';
    return 'F';
  }
}
