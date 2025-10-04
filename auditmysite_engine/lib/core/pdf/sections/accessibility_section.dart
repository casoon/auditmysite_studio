import 'package:pdf/widgets.dart' as pw;
import '../pdf_section.dart';
import '../pdf_template.dart';

class AccessibilitySection extends PdfSection {
  AccessibilitySection(super.data);
  
  @override
  String get title => 'Accessibility Analysis';
  
  @override
  List<pw.Widget> build() {
    if (!hasData) return [];
    
    final widgets = <pw.Widget>[];
    
    // Section header
    widgets.add(PdfTemplate.buildSectionHeader(
      title,
      subtitle: 'WCAG compliance and accessibility issues',
    ));
    
    // Score (handle both int and double from JSON)
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
                'Accessibility Score',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                _getComplianceLevel(score),
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
    
    // Violation summary by impact
    if (data['violationsByImpact'] != null) {
      final violations = data['violationsByImpact'] as Map<String, dynamic>;
      widgets.add(pw.Text(
        'Violations by Impact',
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
          if (violations['critical'] != null)
            PdfTemplate.buildMetricCard(
              'Critical',
              '${violations['critical']}',
              color: PdfTemplate.errorColor,
            ),
          if (violations['serious'] != null)
            PdfTemplate.buildMetricCard(
              'Serious',
              '${violations['serious']}',
              color: PdfTemplate.warningColor,
            ),
          if (violations['moderate'] != null)
            PdfTemplate.buildMetricCard(
              'Moderate',
              '${violations['moderate']}',
              color: PdfTemplate.primaryColor,
            ),
          if (violations['minor'] != null)
            PdfTemplate.buildMetricCard(
              'Minor',
              '${violations['minor']}',
              color: PdfTemplate.subtleColor,
            ),
        ],
      ));
      
      widgets.add(pw.SizedBox(height: 20));
    }
    
    // WCAG criteria
    if (data['wcagCriteria'] != null) {
      final wcag = data['wcagCriteria'] as Map<String, dynamic>;
      widgets.add(pw.Text(
        'WCAG 2.1 Criteria',
        style: pw.TextStyle(
          fontSize: 14,
          fontWeight: pw.FontWeight.bold,
        ),
      ));
      widgets.add(pw.SizedBox(height: 10));
      
      final rows = <List<String>>[];
      wcag.forEach((key, value) {
        rows.add([
          key,
          value['status'] ?? 'Unknown',
          value['description'] ?? '',
        ]);
      });
      
      if (rows.isNotEmpty) {
        widgets.add(PdfTemplate.buildDataTable(
          headers: ['Criterion', 'Status', 'Description'],
          rows: rows,
        ));
      }
    }
    
    widgets.add(pw.SizedBox(height: 20));
    
    // Accessibility violations
    if (data['violations'] != null) {
      final violations = data['violations'] as List;
      if (violations.isNotEmpty) {
        widgets.add(pw.Text(
          'Top Accessibility Issues',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: PdfTemplate.errorColor,
          ),
        ));
        widgets.add(pw.SizedBox(height: 10));
        
        for (final violation in violations.take(10)) {
          widgets.add(PdfTemplate.buildIssueItem(
            title: violation['description'] ?? '',
            severity: violation['impact'] ?? 'moderate',
            description: 'Affects ${violation['nodes']?.length ?? 0} elements',
          ));
        }
      }
    }
    
    return widgets;
  }
  
  String _getComplianceLevel(int score) {
    if (score >= 90) return 'WCAG 2.1 Level AA compliant';
    if (score >= 75) return 'Mostly compliant with minor issues';
    if (score >= 50) return 'Significant accessibility barriers';
    return 'Critical accessibility issues - not compliant';
  }
}
