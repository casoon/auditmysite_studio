import 'package:pdf/widgets.dart' as pw;
import '../pdf_section.dart';
import '../pdf_template.dart';

class SeoSection extends PdfSection {
  SeoSection(super.data);
  
  @override
  String get title => 'SEO Analysis';
  
  @override
  List<pw.Widget> build() {
    if (!hasData) return [];
    
    final widgets = <pw.Widget>[];
    
    // Section header
    widgets.add(PdfTemplate.buildSectionHeader(
      'SEO Analysis',
      subtitle: 'Search engine optimization and discoverability',
    ));
    
    // Score (handle both int and double from JSON)
    final scoreValue = data['score'];
    final score = scoreValue is num ? scoreValue.toInt() : 0;
    widgets.add(pw.Row(
      children: [
        PdfTemplate.buildScoreBadge(score, size: 70),
        pw.SizedBox(width: 20),
        pw.Expanded(
          child: pw.Text(
            'SEO Score',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      ],
    ));
    
    widgets.add(pw.SizedBox(height: 20));
    
    // Meta tags (check both metaTags and direct fields)
    final meta = data['metaTags'] as Map<String, dynamic>? ?? {};
    final title = data['title'] ?? meta['title'];
    final description = data['metaDescription'] ?? meta['description'];
    
    if (title != null || description != null) {
      widgets.add(pw.Text(
        'Meta Tags',
        style: pw.TextStyle(
          fontSize: 14,
          fontWeight: pw.FontWeight.bold,
        ),
      ));
      widgets.add(pw.SizedBox(height: 10));
      
      final rows = <List<String>>[];
      if (title != null) {
        final titleText = title is Map 
          ? (title as Map)['text']?.toString() ?? title.toString()
          : title.toString();
        rows.add(['Title', titleText]);
      }
      if (description != null) {
        final descText = description is Map
            ? (description as Map)['content']?.toString() ?? description.toString()
            : description.toString();
        rows.add(['Description', descText]);
      }
      if (data['keywords'] != null) {
        rows.add(['Keywords', data['keywords'].toString()]);
      }
      if (data['canonical'] != null || meta['canonical'] != null) {
        rows.add(['Canonical', (data['canonical'] ?? meta['canonical']).toString()]);
      }
      
      if (rows.isNotEmpty) {
        widgets.add(PdfTemplate.buildDataTable(
          headers: ['Tag', 'Content'],
          rows: rows,
        ));
      }
    }
    
    widgets.add(pw.SizedBox(height: 20));
    
    // Heading structure
    if (data['headings'] != null) {
      final headings = data['headings'] as Map<String, dynamic>;
      widgets.add(pw.Text(
        'Heading Structure',
        style: pw.TextStyle(
          fontSize: 14,
          fontWeight: pw.FontWeight.bold,
        ),
      ));
      widgets.add(pw.SizedBox(height: 10));
      
      widgets.add(pw.Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          if (headings['h1Count'] != null)
            PdfTemplate.buildMetricCard('H1', '${headings['h1Count']}'),
          if (headings['h2Count'] != null)
            PdfTemplate.buildMetricCard('H2', '${headings['h2Count']}'),
          if (headings['h3Count'] != null)
            PdfTemplate.buildMetricCard('H3', '${headings['h3Count']}'),
          if (headings['h4Count'] != null)
            PdfTemplate.buildMetricCard('H4', '${headings['h4Count']}'),
        ],
      ));
    }
    
    widgets.add(pw.SizedBox(height: 20));
    
    // SEO issues
    if (data['issues'] != null) {
      final issues = data['issues'] as List;
      if (issues.isNotEmpty) {
        widgets.add(pw.Text(
          'SEO Issues',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: PdfTemplate.errorColor,
          ),
        ));
        widgets.add(pw.SizedBox(height: 10));
        
        for (final issue in issues.take(10)) {
          widgets.add(PdfTemplate.buildIssueItem(
            title: issue['title'] ?? '',
            severity: issue['severity'] ?? 'moderate',
            description: issue['description'],
          ));
        }
      }
    }
    
    return widgets;
  }
}
