import 'dart:io';
import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'pdf_template.dart';
import 'sections/overview_section.dart';
import 'sections/performance_section.dart';
import 'sections/seo_section.dart';
import 'sections/accessibility_section.dart';

/// Main PDF report generator
class PdfReportGenerator {
  /// Generate PDF report from audit directory
  static Future<void> generateFromDirectory({
    required String outputDir,
    required String runId,
  }) async {
    print('[PDF] Reading audit data from: $outputDir');
    
    // Read summary file
    final summaryFile = File('$outputDir/summary_${DateTime.now().toString().split(' ')[0]}.json');
    if (!await summaryFile.exists()) {
      print('[PDF] ❌ Summary file not found: ${summaryFile.path}');
      throw Exception('Summary file not found');
    }
    
    final summaryData = jsonDecode(await summaryFile.readAsString());
    print('[PDF] ✅ Summary loaded');
    
    // Read all page JSON files
    final pageFiles = await Directory(outputDir)
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.json') && !entity.path.contains('summary'))
        .map((entity) => entity as File)
        .toList();
    
    print('[PDF] Found ${pageFiles.length} page files');
    
    final pagesData = <Map<String, dynamic>>[];
    for (final file in pageFiles) {
      try {
        final data = jsonDecode(await file.readAsString());
        pagesData.add(data);
      } catch (e) {
        print('[PDF] ⚠️  Failed to read ${file.path}: $e');
      }
    }
    
    print('[PDF] Loaded ${pagesData.length} pages');
    
    // Generate PDF
    await _generatePdf(
      outputPath: '$outputDir/audit_report.pdf',
      summaryData: summaryData,
      pagesData: pagesData,
    );
    
    print('[PDF] ✅ PDF generated: $outputDir/audit_report.pdf');
  }
  
  static Future<void> _generatePdf({
    required String outputPath,
    required Map<String, dynamic> summaryData,
    required List<Map<String, dynamic>> pagesData,
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');
    
    // Extract URLs
    final urls = (summaryData['urls'] as List?)?.map((u) => u.toString()).toList() ?? [];
    final firstUrl = urls.isNotEmpty ? urls.first : 'Unknown URL';
    
    // Cover Page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header with gradient
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(30),
              decoration: pw.BoxDecoration(
                gradient: pw.LinearGradient(
                  colors: [PdfTemplate.primaryColor, PdfColor.fromHex('#1e40af')],
                ),
                borderRadius: pw.BorderRadius.circular(12),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Website Audit Report',
                    style: pw.TextStyle(
                      fontSize: 32,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Text(
                    firstUrl,
                    style: pw.TextStyle(
                      fontSize: 18,
                      color: PdfColors.white.shade(0.9),
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'Generated: ${dateFormat.format(DateTime.now())}',
                    style: pw.TextStyle(
                      fontSize: 14,
                      color: PdfColors.white.shade(0.7),
                    ),
                  ),
                ],
              ),
            ),
            
            pw.SizedBox(height: 40),
            
            // Summary statistics
            pw.Text(
              'Audit Summary',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: PdfTemplate.textColor,
              ),
            ),
            pw.SizedBox(height: 20),
            
            pw.Wrap(
              spacing: 15,
              runSpacing: 15,
              children: [
                PdfTemplate.buildMetricCard(
                  'Pages Audited',
                  '${summaryData['pages']?['successful'] ?? 0}',
                  color: PdfTemplate.successColor,
                ),
                PdfTemplate.buildMetricCard(
                  'Total Issues',
                  '${summaryData['violations']?['total'] ?? 0}',
                  color: PdfTemplate.errorColor,
                ),
                PdfTemplate.buildMetricCard(
                  'Avg Performance',
                  '${summaryData['performance']?['averageScore'] ?? 0}',
                  color: PdfTemplate.primaryColor,
                ),
                PdfTemplate.buildMetricCard(
                  'Avg SEO',
                  '${summaryData['seo']?['averageScore'] ?? 0}',
                  color: PdfTemplate.primaryColor,
                ),
              ],
            ),
            
            pw.SizedBox(height: 40),
            
            // Overall assessment
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                color: PdfTemplate.backgroundColor,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(
                  color: PdfTemplate.subtleColor,
                  width: 1,
                ),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Overall Assessment',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    _generateAssessment(summaryData),
                    style: pw.TextStyle(
                      fontSize: 12,
                      color: PdfTemplate.textColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    
    // Add detail pages for each audited page
    for (var i = 0; i < pagesData.length && i < 10; i++) {
      final pageData = pagesData[i];
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (context) {
            final widgets = <pw.Widget>[];
            
            // Page header
            widgets.add(PdfTemplate.buildHeader(
              'Page ${i + 1}: ${_truncateUrl(pageData['url'] ?? 'Unknown')}',
            ));
            widgets.add(pw.SizedBox(height: 20));
            
            // Add overview section first
            final overview = OverviewSection(pageData);
            if (overview.hasData) {
              widgets.addAll(overview.build());
              widgets.add(pw.SizedBox(height: 30));
            }
            
            // Add sections based on available data
            if (pageData['performance'] != null) {
              final section = PerformanceSection(pageData['performance']);
              widgets.addAll(section.build());
            }
            
            if (pageData['seo'] != null) {
              final section = SeoSection(pageData['seo']);
              widgets.addAll(section.build());
            }
            
            if (pageData['accessibility'] != null || pageData['a11y'] != null) {
              final a11yData = pageData['accessibility'] ?? pageData['a11y'];
              final section = AccessibilitySection(a11yData);
              widgets.addAll(section.build());
            }
            
            return widgets;
          },
        ),
      );
    }
    
    // Save PDF
    final file = File(outputPath);
    await file.writeAsBytes(await pdf.save());
  }
  
  static String _generateAssessment(Map<String, dynamic> summary) {
    final pages = summary['pages'];
    final violations = summary['violations'];
    final performance = summary['performance'];
    
    if (pages?['successful'] == 0) {
      return 'No pages were successfully audited. Please check the audit configuration and ensure the URLs are accessible.';
    }
    
    final issues = violations?['total'] ?? 0;
    final avgPerf = performance?['averageScore'] ?? 0;
    
    if (issues == 0 && avgPerf >= 90) {
      return 'Excellent! The website shows strong performance with no critical issues detected. Continue monitoring and maintaining current best practices.';
    } else if (issues < 10 && avgPerf >= 75) {
      return 'Good overall health with minor issues to address. Focus on the highlighted recommendations to further improve user experience.';
    } else if (issues < 50 && avgPerf >= 50) {
      return 'The website has several areas requiring attention. Prioritize fixing critical and serious issues first for the best impact.';
    } else {
      return 'Significant issues detected that may impact user experience and search engine visibility. Immediate action recommended to address critical problems.';
    }
  }
  
  static String _truncateUrl(String url, {int maxLength = 60}) {
    if (url.length <= maxLength) return url;
    return '${url.substring(0, maxLength)}...';
  }
}
