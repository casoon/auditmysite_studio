import 'package:puppeteer/puppeteer.dart';
import '../events.dart';
import 'audit_base.dart';
import 'dart:math' as math;

/// Advanced Content Quality Audit with NLP-like analysis
class ContentQualityAudit extends Audit {
  @override
  String get name => 'content_quality';

  @override
  Future<void> run(AuditContext ctx) async {
    final page = ctx.page as Page;

    // Extract comprehensive content data
    final contentData = await page.evaluate(r'''
() => {
  const result = {
    textContent: '',
    wordCount: 0,
    sentenceCount: 0,
    paragraphCount: 0,
    avgWordsPerSentence: 0,
    avgWordsPerParagraph: 0,
    avgSentencesPerParagraph: 0,
    uniqueWords: 0,
    lexicalDiversity: 0,
    headingStructure: [],
    contentSections: [],
    listsCount: 0,
    tablesCount: 0,
    mediaCount: 0,
    codeBlocksCount: 0,
    quotesCount: 0,
    emphasisCount: 0,
    formElements: 0
  };

  // Get main content (try to identify article/main content area)
  const contentSelectors = [
    'main', 
    'article', 
    '[role="main"]', 
    '#content', 
    '.content',
    '.post-content',
    '.entry-content'
  ];
  
  let contentElement = null;
  for (const selector of contentSelectors) {
    const elem = document.querySelector(selector);
    if (elem) {
      contentElement = elem;
      break;
    }
  }
  
  // Fallback to body if no specific content area found
  if (!contentElement) {
    contentElement = document.body;
  }
  
  // Clone and clean the content
  const cleanedContent = contentElement.cloneNode(true);
  
  // Remove non-content elements
  const removeSelectors = [
    'script', 'style', 'noscript', 'iframe', 
    'nav', 'header', 'footer', 'aside',
    '.advertisement', '.ad', '.banner',
    '.cookie-notice', '.popup', '.modal'
  ];
  
  removeSelectors.forEach(selector => {
    cleanedContent.querySelectorAll(selector).forEach(el => el.remove());
  });
  
  // Extract text content
  result.textContent = cleanedContent.textContent || '';
  const text = result.textContent.trim();
  
  // Word analysis
  const words = text.split(/\s+/).filter(w => w.length > 0);
  result.wordCount = words.length;
  
  // Unique words and lexical diversity
  const wordFrequency = {};
  const uniqueWordsSet = new Set();
  
  words.forEach(word => {
    const normalized = word.toLowerCase().replace(/[^a-z0-9]/g, '');
    if (normalized.length > 0) {
      uniqueWordsSet.add(normalized);
      wordFrequency[normalized] = (wordFrequency[normalized] || 0) + 1;
    }
  });
  
  result.uniqueWords = uniqueWordsSet.size;
  result.lexicalDiversity = result.wordCount > 0 ? 
    (result.uniqueWords / result.wordCount).toFixed(3) : 0;
  
  // Sentence analysis
  const sentences = text.split(/[.!?]+/).filter(s => s.trim().length > 10);
  result.sentenceCount = sentences.length;
  
  // Paragraph analysis
  const paragraphs = contentElement.querySelectorAll('p');
  result.paragraphCount = paragraphs.length;
  
  // Calculate averages
  if (result.sentenceCount > 0) {
    result.avgWordsPerSentence = Math.round((result.wordCount / result.sentenceCount) * 10) / 10;
  }
  
  if (result.paragraphCount > 0) {
    result.avgWordsPerParagraph = Math.round((result.wordCount / result.paragraphCount) * 10) / 10;
    result.avgSentencesPerParagraph = Math.round((result.sentenceCount / result.paragraphCount) * 10) / 10;
  }
  
  // Heading structure analysis
  const headings = contentElement.querySelectorAll('h1, h2, h3, h4, h5, h6');
  const headingStructure = [];
  let lastLevel = 0;
  let properHierarchy = true;
  
  headings.forEach(heading => {
    const level = parseInt(heading.tagName.charAt(1));
    const text = heading.textContent.trim();
    
    // Check for proper hierarchy (no skipping levels)
    if (lastLevel > 0 && level > lastLevel + 1) {
      properHierarchy = false;
    }
    lastLevel = level;
    
    headingStructure.push({
      level: level,
      text: text,
      wordCount: text.split(/\s+/).length
    });
  });
  
  result.headingStructure = headingStructure;
  result.properHeadingHierarchy = properHierarchy;
  
  // Content sections analysis
  const contentSections = [];
  let currentSection = null;
  
  contentElement.childNodes.forEach(node => {
    if (node.nodeType === 1) { // Element node
      if (node.tagName && node.tagName.match(/^H[1-6]$/)) {
        // Start new section
        if (currentSection) {
          contentSections.push(currentSection);
        }
        currentSection = {
          heading: node.textContent.trim(),
          level: parseInt(node.tagName.charAt(1)),
          contentLength: 0,
          hasMedia: false,
          hasLists: false,
          hasTables: false
        };
      } else if (currentSection) {
        // Add to current section
        const text = node.textContent || '';
        currentSection.contentLength += text.length;
        
        if (node.querySelector('img, video, audio, picture')) {
          currentSection.hasMedia = true;
        }
        if (node.querySelector('ul, ol, dl')) {
          currentSection.hasLists = true;
        }
        if (node.querySelector('table')) {
          currentSection.hasTables = true;
        }
      }
    }
  });
  
  if (currentSection) {
    contentSections.push(currentSection);
  }
  
  result.contentSections = contentSections;
  
  // Count content elements
  result.listsCount = contentElement.querySelectorAll('ul, ol, dl').length;
  result.tablesCount = contentElement.querySelectorAll('table').length;
  result.mediaCount = contentElement.querySelectorAll('img, video, audio, picture, iframe[src*="youtube"], iframe[src*="vimeo"]').length;
  result.codeBlocksCount = contentElement.querySelectorAll('pre, code').length;
  result.quotesCount = contentElement.querySelectorAll('blockquote, q').length;
  result.emphasisCount = contentElement.querySelectorAll('strong, b, em, i, mark').length;
  result.formElements = contentElement.querySelectorAll('form, input, textarea, select').length;
  
  // Readability calculations
  // Flesch Reading Ease Score
  const avgSyllablesPerWord = 1.5; // Simplified estimation
  const fleschScore = 206.835 - 1.015 * result.avgWordsPerSentence - 84.6 * avgSyllablesPerWord;
  result.fleschReadingEase = Math.max(0, Math.min(100, Math.round(fleschScore)));
  
  // Flesch-Kincaid Grade Level
  const fkGrade = 0.39 * result.avgWordsPerSentence + 11.8 * avgSyllablesPerWord - 15.59;
  result.fleschKincaidGrade = Math.max(0, Math.round(fkGrade * 10) / 10);
  
  // Gunning Fog Index (simplified)
  const complexWords = words.filter(w => w.length > 6).length;
  const fogIndex = 0.4 * (result.avgWordsPerSentence + (100 * complexWords / result.wordCount));
  result.gunningFogIndex = Math.round(fogIndex * 10) / 10;
  
  // Find most frequent words (excluding stop words)
  const stopWords = new Set([
    'the', 'be', 'to', 'of', 'and', 'a', 'in', 'that', 'have',
    'i', 'it', 'for', 'not', 'on', 'with', 'he', 'as', 'you',
    'do', 'at', 'this', 'but', 'his', 'by', 'from', 'is', 'was',
    'are', 'been', 'or', 'an', 'will', 'my', 'would', 'there',
    'their', 'what', 'so', 'up', 'out', 'if', 'about', 'who',
    'get', 'which', 'go', 'me', 'when', 'make', 'can', 'like',
    'no', 'just', 'him', 'know', 'take', 'into', 'your', 'some',
    'could', 'them', 'see', 'other', 'than', 'then', 'now', 'only'
  ]);
  
  const meaningfulWords = [];
  for (const [word, count] of Object.entries(wordFrequency)) {
    if (!stopWords.has(word) && word.length > 3) {
      meaningfulWords.push({ word, count });
    }
  }
  
  meaningfulWords.sort((a, b) => b.count - a.count);
  result.topKeywords = meaningfulWords.slice(0, 10);
  
  return result;
}
    ''');

    // Calculate content quality score
    final score = _calculateContentQualityScore(contentData);
    final grade = _calculateGrade(score);
    final issues = _identifyContentIssues(contentData);
    final recommendations = _generateRecommendations(contentData, issues);

    // Store comprehensive result
    ctx.contentQualityResult = {
      'score': score,
      'grade': grade,
      'metrics': contentData,
      'issues': issues,
      'recommendations': recommendations,
      'readability': {
        'fleschReadingEase': contentData['fleschReadingEase'],
        'fleschKincaidGrade': contentData['fleschKincaidGrade'],
        'gunningFogIndex': contentData['gunningFogIndex'],
        'interpretation': _interpretReadability(contentData),
      },
      'contentStructure': {
        'headings': contentData['headingStructure'],
        'sections': contentData['contentSections'],
        'properHierarchy': contentData['properHeadingHierarchy'],
      },
      'contentRichness': {
        'lists': contentData['listsCount'],
        'tables': contentData['tablesCount'],
        'media': contentData['mediaCount'],
        'codeBlocks': contentData['codeBlocksCount'],
        'quotes': contentData['quotesCount'],
      },
      'keywords': contentData['topKeywords'],
      'lexicalDiversity': contentData['lexicalDiversity'],
    };
  }

  double _calculateContentQualityScore(Map<String, dynamic> data) {
    double score = 100.0;
    
    // Word count scoring (25 points)
    final wordCount = data['wordCount'] as int? ?? 0;
    if (wordCount < 300) {
      score -= 25; // Thin content
    } else if (wordCount < 500) {
      score -= 15;
    } else if (wordCount < 1000) {
      score -= 5;
    } else if (wordCount > 2500) {
      score += 5; // Long-form content bonus
    }
    
    // Readability scoring (20 points)
    final fleschScore = data['fleschReadingEase'] as int? ?? 0;
    if (fleschScore < 30) {
      score -= 15; // Very difficult
    } else if (fleschScore < 50) {
      score -= 10; // Difficult
    } else if (fleschScore > 70) {
      score += 5; // Easy to read bonus
    }
    
    // Structure scoring (15 points)
    final headings = data['headingStructure'] as List? ?? [];
    final properHierarchy = data['properHeadingHierarchy'] as bool? ?? false;
    
    if (headings.isEmpty) {
      score -= 10;
    } else if (!properHierarchy) {
      score -= 5;
    }
    
    // Content richness (15 points)
    final hasMedia = (data['mediaCount'] as int? ?? 0) > 0;
    final hasLists = (data['listsCount'] as int? ?? 0) > 0;
    final hasTables = (data['tablesCount'] as int? ?? 0) > 0;
    
    if (!hasMedia && !hasLists && !hasTables) {
      score -= 10; // Plain text only
    } else if (hasMedia && (hasLists || hasTables)) {
      score += 5; // Rich content bonus
    }
    
    // Lexical diversity (10 points)
    final lexicalDiversity = double.tryParse(data['lexicalDiversity'].toString()) ?? 0;
    if (lexicalDiversity < 0.3) {
      score -= 10; // Very repetitive
    } else if (lexicalDiversity < 0.5) {
      score -= 5;
    } else if (lexicalDiversity > 0.7) {
      score += 5; // Good variety
    }
    
    // Paragraph structure (10 points)
    final avgWordsPerParagraph = data['avgWordsPerParagraph'] as num? ?? 0;
    if (avgWordsPerParagraph > 150) {
      score -= 10; // Wall of text
    } else if (avgWordsPerParagraph > 100) {
      score -= 5;
    }
    
    // Sentence complexity (5 points)
    final avgWordsPerSentence = data['avgWordsPerSentence'] as num? ?? 0;
    if (avgWordsPerSentence > 25) {
      score -= 5; // Too complex
    } else if (avgWordsPerSentence < 10) {
      score -= 3; // Too simple
    }
    
    return score.clamp(0, 100);
  }

  List<Map<String, dynamic>> _identifyContentIssues(Map<String, dynamic> data) {
    final issues = <Map<String, dynamic>>[];
    
    final wordCount = data['wordCount'] as int? ?? 0;
    if (wordCount < 300) {
      issues.add({
        'type': 'thin-content',
        'severity': 'error',
        'message': 'Content is too thin ($wordCount words). Aim for at least 500 words.',
      });
    } else if (wordCount < 500) {
      issues.add({
        'type': 'short-content',
        'severity': 'warning',
        'message': 'Content is relatively short ($wordCount words). Consider expanding to 1000+ words.',
      });
    }
    
    final fleschScore = data['fleschReadingEase'] as int? ?? 0;
    if (fleschScore < 30) {
      issues.add({
        'type': 'readability-poor',
        'severity': 'error',
        'message': 'Content is very difficult to read (Flesch score: $fleschScore).',
      });
    } else if (fleschScore < 50) {
      issues.add({
        'type': 'readability-difficult',
        'severity': 'warning',
        'message': 'Content is fairly difficult to read (Flesch score: $fleschScore).',
      });
    }
    
    final headings = data['headingStructure'] as List? ?? [];
    if (headings.isEmpty) {
      issues.add({
        'type': 'no-headings',
        'severity': 'error',
        'message': 'No headings found. Use headings to structure your content.',
      });
    }
    
    final properHierarchy = data['properHeadingHierarchy'] as bool? ?? false;
    if (!properHierarchy && headings.isNotEmpty) {
      issues.add({
        'type': 'heading-hierarchy',
        'severity': 'warning',
        'message': 'Heading hierarchy is improper. Don\'t skip heading levels.',
      });
    }
    
    final lexicalDiversity = double.tryParse(data['lexicalDiversity'].toString()) ?? 0;
    if (lexicalDiversity < 0.3) {
      issues.add({
        'type': 'repetitive-content',
        'severity': 'warning',
        'message': 'Content is very repetitive (lexical diversity: ${(lexicalDiversity * 100).toStringAsFixed(1)}%).',
      });
    }
    
    final avgWordsPerParagraph = data['avgWordsPerParagraph'] as num? ?? 0;
    if (avgWordsPerParagraph > 150) {
      issues.add({
        'type': 'long-paragraphs',
        'severity': 'warning',
        'message': 'Paragraphs are too long (avg: ${avgWordsPerParagraph.toInt()} words). Break them up.',
      });
    }
    
    final avgWordsPerSentence = data['avgWordsPerSentence'] as num? ?? 0;
    if (avgWordsPerSentence > 25) {
      issues.add({
        'type': 'complex-sentences',
        'severity': 'warning',
        'message': 'Sentences are too complex (avg: ${avgWordsPerSentence.toInt()} words).',
      });
    }
    
    final mediaCount = data['mediaCount'] as int? ?? 0;
    if (wordCount > 500 && mediaCount == 0) {
      issues.add({
        'type': 'no-media',
        'severity': 'info',
        'message': 'No images or media found. Consider adding visuals.',
      });
    }
    
    return issues;
  }

  List<String> _generateRecommendations(Map<String, dynamic> data, List<Map<String, dynamic>> issues) {
    final recommendations = <String>[];
    
    // Based on issues
    for (final issue in issues) {
      switch (issue['type']) {
        case 'thin-content':
          recommendations.add('Expand your content to at least 500-1000 words for better SEO value');
          break;
        case 'readability-poor':
          recommendations.add('Simplify sentences and use shorter words to improve readability');
          break;
        case 'no-headings':
          recommendations.add('Add H2 and H3 headings every 150-300 words to structure content');
          break;
        case 'repetitive-content':
          recommendations.add('Use synonyms and vary your vocabulary to improve content quality');
          break;
        case 'long-paragraphs':
          recommendations.add('Break paragraphs into 50-100 word chunks for better readability');
          break;
        case 'no-media':
          recommendations.add('Add relevant images, charts, or videos to enhance user engagement');
          break;
      }
    }
    
    // General recommendations
    final wordCount = data['wordCount'] as int? ?? 0;
    if (wordCount > 2000) {
      recommendations.add('Consider adding a table of contents for long-form content');
    }
    
    final listsCount = data['listsCount'] as int? ?? 0;
    if (listsCount == 0 && wordCount > 500) {
      recommendations.add('Use bullet points or numbered lists to break up content');
    }
    
    final quotesCount = data['quotesCount'] as int? ?? 0;
    if (quotesCount == 0 && wordCount > 1000) {
      recommendations.add('Consider adding expert quotes or citations for authority');
    }
    
    return recommendations;
  }

  String _interpretReadability(Map<String, dynamic> data) {
    final fleschScore = data['fleschReadingEase'] as int? ?? 0;
    final gradeLevel = data['fleschKincaidGrade'] as num? ?? 0;
    
    String interpretation = '';
    
    if (fleschScore >= 90) {
      interpretation = 'Very easy to read (5th grade level)';
    } else if (fleschScore >= 80) {
      interpretation = 'Easy to read (6th grade level)';
    } else if (fleschScore >= 70) {
      interpretation = 'Fairly easy to read (7th grade level)';
    } else if (fleschScore >= 60) {
      interpretation = 'Standard readability (8th-9th grade)';
    } else if (fleschScore >= 50) {
      interpretation = 'Fairly difficult (10th-12th grade)';
    } else if (fleschScore >= 30) {
      interpretation = 'Difficult to read (college level)';
    } else {
      interpretation = 'Very difficult (graduate level)';
    }
    
    interpretation += ' | Grade level: ${gradeLevel.toStringAsFixed(1)}';
    
    return interpretation;
  }

  String _calculateGrade(double score) {
    if (score >= 90) return 'A';
    if (score >= 80) return 'B';
    if (score >= 70) return 'C';
    if (score >= 60) return 'D';
    return 'F';
  }
}