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
      subtitle: 'WCAG 2.1 compliance and accessibility analysis',
    ));
    
    // Get data from different sources
    final wcag21 = data['wcag21'] as Map<String, dynamic>?;
    final aria = data['aria'] as Map<String, dynamic>?;
    final axe = data['a11y'] as Map<String, dynamic>?;
    
    // Overall Score from WCAG21
    if (wcag21 != null) {
      final scoreValue = wcag21['totalScore'];
      final score = scoreValue is num ? scoreValue.toInt() : 0;
      final grade = wcag21['grade'] ?? 'N/A';
      
      widgets.add(pw.Row(
        children: [
          PdfTemplate.buildScoreBadge(score, size: 70),
          pw.SizedBox(width: 20),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'WCAG 2.1 Score: $grade',
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
      
      // WCAG 2.1 Principles Summary
      widgets.add(pw.Text(
        'WCAG 2.1 Four Principles',
        style: pw.TextStyle(
          fontSize: 14,
          fontWeight: pw.FontWeight.bold,
        ),
      ));
      widgets.add(pw.SizedBox(height: 10));
      
      final principles = [
        {'name': 'Perceivable', 'key': 'perceivable', 'icon': '⏺'},
        {'name': 'Operable', 'key': 'operable', 'icon': '⚙'},
        {'name': 'Understandable', 'key': 'understandable', 'icon': '📖'},
        {'name': 'Robust', 'key': 'robust', 'icon': '🔧'},
      ];
      
      for (final principle in principles) {
        final key = principle['key'] as String;
        final principleData = wcag21[key] as Map<String, dynamic>?;
        if (principleData != null && principleData.isNotEmpty) {
          final totalViolations = principleData.values
              .where((v) => v is Map)
              .map((v) => (v as Map)['violations'] ?? 0)
              .fold<int>(0, (sum, v) => sum + (v as int));
          
          widgets.add(PdfTemplate.buildMetricCard(
            '${principle['name']}',
            '$totalViolations issues',
            color: totalViolations == 0 ? PdfTemplate.successColor : PdfTemplate.warningColor,
          ));
        }
      }
      
      widgets.add(pw.SizedBox(height: 20));
    }
    
    // ARIA Landmarks
    if (aria != null && aria['landmarks'] != null) {
      final landmarks = aria['landmarks'] as Map<String, dynamic>;
      final present = landmarks['present'] as List? ?? [];
      final missing = landmarks['missing'] as List? ?? [];
      
      widgets.add(pw.Text(
        'ARIA Landmarks',
        style: pw.TextStyle(
          fontSize: 14,
          fontWeight: pw.FontWeight.bold,
        ),
      ));
      widgets.add(pw.SizedBox(height: 10));
      
      widgets.add(pw.Row(
        children: [
          PdfTemplate.buildMetricCard(
            'Present',
            '${present.length}',
            color: PdfTemplate.successColor,
          ),
          pw.SizedBox(width: 10),
          PdfTemplate.buildMetricCard(
            'Missing',
            '${missing.length}',
            color: missing.isEmpty ? PdfTemplate.successColor : PdfTemplate.warningColor,
          ),
        ],
      ));
      
      widgets.add(pw.SizedBox(height: 20));
    }
    
    // Axe-core Violations
    if (axe != null && axe['summary'] != null) {
      final summary = axe['summary'] as Map<String, dynamic>;
      final violationsByImpact = summary['violationsByImpact'] as Map<String, dynamic>? ?? {};
      
      widgets.add(pw.Text(
        'Axe-Core Analysis',
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
          PdfTemplate.buildMetricCard(
            'Critical',
            '${violationsByImpact['critical'] ?? 0}',
            color: violationsByImpact['critical'] == 0 ? PdfTemplate.successColor : PdfTemplate.errorColor,
          ),
          PdfTemplate.buildMetricCard(
            'Serious',
            '${violationsByImpact['serious'] ?? 0}',
            color: violationsByImpact['serious'] == 0 ? PdfTemplate.successColor : PdfTemplate.warningColor,
          ),
          PdfTemplate.buildMetricCard(
            'Moderate',
            '${violationsByImpact['moderate'] ?? 0}',
            color: PdfTemplate.primaryColor,
          ),
          PdfTemplate.buildMetricCard(
            'Minor',
            '${violationsByImpact['minor'] ?? 0}',
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
