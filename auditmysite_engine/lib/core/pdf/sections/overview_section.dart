import 'package:pdf/widgets.dart' as pw;
import '../pdf_section.dart';
import '../pdf_template.dart';

class OverviewSection extends PdfSection {
  OverviewSection(super.data);
  
  @override
  String get title => 'Overview';
  
  @override
  List<pw.Widget> build() {
    final widgets = <pw.Widget>[];
    
    // HTTP Status
    final httpStatus = data['http']?['statusCode'];
    final statusColor = httpStatus == 200 ? PdfTemplate.successColor : 
                       (httpStatus != null && httpStatus >= 300 && httpStatus < 400) ? PdfTemplate.warningColor :
                       PdfTemplate.errorColor;
    
    widgets.add(pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // HTTP Status Card
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfTemplate.backgroundColor,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: statusColor, width: 2),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'HTTP Status',
                  style: pw.TextStyle(
                    fontSize: 12,
                    color: PdfTemplate.subtleColor,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  httpStatus?.toString() ?? 'N/A',
                  style: pw.TextStyle(
                    fontSize: 32,
                    fontWeight: pw.FontWeight.bold,
                    color: statusColor,
                  ),
                ),
                if (data['http']?['responseTimeMs'] != null) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Response: ${data['http']['responseTimeMs']}ms',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfTemplate.subtleColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        
        pw.SizedBox(width: 16),
        
        // Performance Score
        if (data['performance']?['score'] != null) ...[
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfTemplate.backgroundColor,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: PdfTemplate.primaryColor, width: 2),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Performance',
                    style: pw.TextStyle(
                      fontSize: 12,
                      color: PdfTemplate.subtleColor,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        '${(data['performance']['score'] as num).toInt()}',
                        style: pw.TextStyle(
                          fontSize: 32,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfTemplate.getScoreColor((data['performance']['score'] as num).toInt()),
                        ),
                      ),
                      pw.Text(
                        '/100',
                        style: pw.TextStyle(
                          fontSize: 16,
                          color: PdfTemplate.subtleColor,
                        ),
                      ),
                    ],
                  ),
                  if (data['performance']?['grade'] != null) ...[
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Grade: ${data['performance']['grade']}',
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfTemplate.subtleColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
        
        pw.SizedBox(width: 16),
        
        // SEO Score
        if (data['seo']?['score'] != null) ...[
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfTemplate.backgroundColor,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: PdfTemplate.primaryColor, width: 2),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'SEO',
                    style: pw.TextStyle(
                      fontSize: 12,
                      color: PdfTemplate.subtleColor,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        '${(data['seo']['score'] as num).toInt()}',
                        style: pw.TextStyle(
                          fontSize: 32,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfTemplate.getScoreColor((data['seo']['score'] as num).toInt()),
                        ),
                      ),
                      pw.Text(
                        '/100',
                        style: pw.TextStyle(
                          fontSize: 16,
                          color: PdfTemplate.subtleColor,
                        ),
                      ),
                    ],
                  ),
                  if (data['seo']?['grade'] != null) ...[
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Grade: ${data['seo']['grade']}',
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfTemplate.subtleColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    ));
    
    widgets.add(pw.SizedBox(height: 20));
    
    // Key Metrics Row
    final keyMetrics = <pw.Widget>[];
    
    if (data['performance']?['metrics']?['ttfb'] != null) {
      keyMetrics.add(PdfTemplate.buildMetricCard(
        'TTFB',
        '${data['performance']['metrics']['ttfb']}ms',
        color: PdfTemplate.getPerformanceColor((data['performance']['metrics']['ttfb'] as num).toInt()),
      ));
    }
    
    if (data['performance']?['metrics']?['lcp'] != null) {
      keyMetrics.add(PdfTemplate.buildMetricCard(
        'LCP',
        '${data['performance']['metrics']['lcp']}ms',
        color: PdfTemplate.getPerformanceColor((data['performance']['metrics']['lcp'] as num).toInt()),
      ));
    }
    
    if (data['performance']?['metrics']?['cls'] != null) {
      keyMetrics.add(PdfTemplate.buildMetricCard(
        'CLS',
        '${(data['performance']['metrics']['cls'] as num).toStringAsFixed(3)}',
        color: PdfTemplate.successColor,
      ));
    }
    
    if (data['mobile']?['score'] != null) {
      keyMetrics.add(PdfTemplate.buildMetricCard(
        'Mobile',
        '${(data['mobile']['score'] as num).toInt()}/100',
        color: PdfTemplate.primaryColor,
      ));
    }
    
    if (keyMetrics.isNotEmpty) {
      widgets.add(PdfTemplate.buildSectionHeader('Key Metrics'));
      widgets.add(pw.Wrap(
        spacing: 10,
        runSpacing: 10,
        children: keyMetrics,
      ));
    }
    
    return widgets;
  }
}
