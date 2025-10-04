import 'package:pdf/widgets.dart' as pw;
import '../pdf_section.dart';
import '../pdf_template.dart';

class PerformanceSection extends PdfSection {
  PerformanceSection(super.data);
  
  @override
  String get title => 'Performance Analysis';
  
  @override
  List<pw.Widget> build() {
    if (!hasData) return [];
    
    final widgets = <pw.Widget>[];
    
    // Section header
    widgets.add(PdfTemplate.buildSectionHeader(
      title,
      subtitle: 'Core Web Vitals and loading performance',
    ));
    
    // Score badge (handle both int and double from JSON)
    final scoreValue = data['score'];
    final score = scoreValue is num ? scoreValue.toInt() : 0;
    widgets.add(pw.Row(
      children: [
        PdfTemplate.buildScoreBadge(score, size: 70),
        pw.SizedBox(width: 20),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Performance Score',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                _getScoreDescription(score),
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfTemplate.subtleColor,
                ),
              ),
            ],
          ),
        ),
      ],
    ));
    
    widgets.add(pw.SizedBox(height: 20));
    
    // Core Web Vitals (check both locations)
    final cwv = data['coreWebVitals'] as Map<String, dynamic>? ?? 
                data['metrics'] as Map<String, dynamic>?;
    
    if (cwv != null) {
      widgets.add(pw.Text(
        'Core Web Vitals',
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
          if (cwv['LCP'] != null)
            PdfTemplate.buildMetricCard(
              'LCP',
              '${cwv['LCP']}ms',
              color: PdfTemplate.getPerformanceColor((cwv['LCP'] as num).toInt()),
            ),
          if (cwv['FCP'] != null)
            PdfTemplate.buildMetricCard(
              'FCP',
              '${cwv['FCP']}ms',
              color: PdfTemplate.getPerformanceColor((cwv['FCP'] as num).toInt()),
            ),
          if (cwv['TBT'] != null)
            PdfTemplate.buildMetricCard(
              'TBT',
              '${cwv['TBT']}ms',
              color: PdfTemplate.getPerformanceColor((cwv['TBT'] as num).toInt()),
            ),
          if (cwv['CLS'] != null)
            PdfTemplate.buildMetricCard(
              'CLS',
              '${cwv['CLS']}',
              color: PdfTemplate.successColor,
            ),
        ],
      ));
      
      widgets.add(pw.SizedBox(height: 20));
    }
    
    // Page load metrics (check both locations)
    final metrics = data['loadMetrics'] as Map<String, dynamic>? ?? 
                    data['metrics'] as Map<String, dynamic>?;
    
    if (metrics != null) {
      widgets.add(pw.Text(
        'Page Load Metrics',
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
          if (metrics['ttfb'] != null || metrics['TTFB'] != null)
            PdfTemplate.buildMetricCard('TTFB', '${metrics['ttfb'] ?? metrics['TTFB']}ms'),
          if (metrics['domContentLoaded'] != null)
            PdfTemplate.buildMetricCard('DOM Ready', '${metrics['domContentLoaded']}ms'),
          if (metrics['loadComplete'] != null)
            PdfTemplate.buildMetricCard('Load Complete', '${metrics['loadComplete']}ms'),
          if (metrics['firstContentfulPaint'] != null)
            PdfTemplate.buildMetricCard('FCP', '${metrics['firstContentfulPaint']}ms'),
        ],
      ));
      
      widgets.add(pw.SizedBox(height: 20));
    }
    
    // Resource size breakdown
    if (data['resources'] != null) {
      final resources = data['resources'] as Map<String, dynamic>;
      widgets.add(pw.Text(
        'Resource Breakdown',
        style: pw.TextStyle(
          fontSize: 14,
          fontWeight: pw.FontWeight.bold,
        ),
      ));
      widgets.add(pw.SizedBox(height: 10));
      
      final rows = <List<String>>[];
      if (resources['totalSize'] != null) {
        rows.add(['Total Page Size', _formatBytes((resources['totalSize'] as num).toInt())]);
      }
      if (resources['javascript'] != null) {
        rows.add(['JavaScript', _formatBytes((resources['javascript'] as num).toInt())]);
      }
      if (resources['css'] != null) {
        rows.add(['CSS', _formatBytes((resources['css'] as num).toInt())]);
      }
      if (resources['images'] != null) {
        rows.add(['Images', _formatBytes((resources['images'] as num).toInt())]);
      }
      if (resources['fonts'] != null) {
        rows.add(['Fonts', _formatBytes((resources['fonts'] as num).toInt())]);
      }
      
      if (rows.isNotEmpty) {
        widgets.add(PdfTemplate.buildDataTable(
          headers: ['Resource Type', 'Size'],
          rows: rows,
        ));
      }
    }
    
    // Performance issues
    if (data['issues'] != null) {
      final issues = data['issues'] as List;
      if (issues.isNotEmpty) {
        widgets.add(pw.SizedBox(height: 20));
        widgets.add(pw.Text(
          'Performance Issues',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: PdfTemplate.errorColor,
          ),
        ));
        widgets.add(pw.SizedBox(height: 10));
        
        for (final issue in issues.take(5)) {
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
  
  String _getScoreDescription(int score) {
    if (score >= 90) return 'Excellent performance!';
    if (score >= 75) return 'Good performance';
    if (score >= 50) return 'Needs improvement';
    return 'Poor performance - immediate action needed';
  }
  
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}
