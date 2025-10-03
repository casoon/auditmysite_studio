import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

class PdfReportGeneratorEnhanced {
  static Future<void> generateReport({
    required String outputPath,
    required Map<String, dynamic> auditData,
    required String url,
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');
    final timestamp = DateTime.now();
    
    // Extract data
    final audits = auditData['audits'] ?? {};
    final scores = auditData['scores'] ?? {};
    final recommendations = auditData['recommendations'] ?? {};
    
    // Theme configuration
    final primaryColor = PdfColor.fromHex('#2563eb');
    final successColor = PdfColor.fromHex('#10b981');
    final warningColor = PdfColor.fromHex('#f59e0b');
    final errorColor = PdfColor.fromHex('#ef4444');
    final textColor = PdfColor.fromHex('#1f2937');
    final subtleColor = PdfColor.fromHex('#6b7280');
    
    // Add cover page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                padding: pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  gradient: pw.LinearGradient(
                    colors: [primaryColor, PdfColor.fromHex('#1e40af')],
                  ),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Website Audit Report',
                      style: pw.TextStyle(
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 20),
                    pw.Text(
                      url,
                      style: pw.TextStyle(
                        fontSize: 16,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      'Generated: ${dateFormat.format(timestamp)}',
                      style: pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.white.shade(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 40),
              
              // Overall Score Card
              pw.Container(
                padding: pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: primaryColor, width: 2),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Overall Score',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        pw.Text(
                          'Weighted average of all analyses',
                          style: pw.TextStyle(
                            fontSize: 10,
                            color: subtleColor,
                          ),
                        ),
                      ],
                    ),
                    pw.Text(
                      '${scores['overallScore'] ?? 0}/100',
                      style: pw.TextStyle(
                        fontSize: 36,
                        fontWeight: pw.FontWeight.bold,
                        color: _getScoreColor(scores['overallScore'] ?? 0),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),
              
              // Score Breakdown
              pw.Text(
                'Score Breakdown',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: textColor,
                ),
              ),
              pw.SizedBox(height: 15),
              
              // Individual scores
              _buildScoreItem('Accessibility', scores['a11yScore'] ?? 0, '35%', 
                'WCAG compliance, screen reader support'),
              _buildScoreItem('Performance', scores['performanceScore'] ?? 0, '25%',
                'Core Web Vitals, loading speed'),
              _buildScoreItem('SEO', scores['seoScore'] ?? 0, '20%',
                'Meta tags, heading structure'),
              _buildScoreItem('Content Weight', scores['contentWeightScore'] ?? 0, '10%',
                'Resource sizes, optimization'),
              _buildScoreItem('Mobile', scores['mobileScore'] ?? 0, '10%',
                'Responsive design, touch targets'),
            ],
          );
        },
      ),
    );
    
    // Add Executive Summary page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Executive Summary'),
              pw.SizedBox(height: 20),
              
              // Key Metrics Grid
              pw.Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildMetricCard('HTTP Status', 
                    '${audits['http']?['statusCode'] ?? 'N/A'}',
                    audits['http']?['statusCode'] == 200 ? successColor : errorColor),
                  _buildMetricCard('Response Time',
                    '${audits['http']?['responseTime'] ?? 0}ms',
                    _getPerformanceColor(audits['http']?['responseTime'] ?? 0)),
                  _buildMetricCard('Page Size',
                    '${((audits['performance']?['size'] ?? 0) / 1024).toStringAsFixed(1)} KB',
                    _getSizeColor(audits['performance']?['size'] ?? 0)),
                  _buildMetricCard('Images',
                    '${audits['content']?['imageCount'] ?? 0}',
                    primaryColor),
                  _buildMetricCard('Scripts',
                    '${audits['performance']?['scripts'] ?? 0}',
                    primaryColor),
                  _buildMetricCard('Word Count',
                    '${audits['content']?['wordCount'] ?? 0}',
                    primaryColor),
                ],
              ),
              
              pw.SizedBox(height: 30),
              
              // High Priority Recommendations
              if ((recommendations['high'] as List?)?.isNotEmpty ?? false) ...[
                _buildSectionHeader('Critical Issues'),
                pw.SizedBox(height: 10),
                ...((recommendations['high'] as List).take(5).map((rec) =>
                  _buildRecommendation(rec, errorColor)
                ).toList()),
              ],
              
              pw.SizedBox(height: 20),
              
              // Medium Priority Recommendations
              if ((recommendations['medium'] as List?)?.isNotEmpty ?? false) ...[
                _buildSectionHeader('Important Improvements'),
                pw.SizedBox(height: 10),
                ...((recommendations['medium'] as List).take(3).map((rec) =>
                  _buildRecommendation(rec, warningColor)
                ).toList()),
              ],
            ],
          );
        },
      ),
    );
    
    // Add Accessibility Analysis page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          final a11y = audits['accessibility'] ?? {};
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Accessibility Analysis'),
              pw.SizedBox(height: 20),
              
              // Accessibility Score
              pw.Container(
                padding: pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Accessibility Score',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      '${scores['a11yScore'] ?? 0}/100',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: _getScoreColor(scores['a11yScore'] ?? 0),
                      ),
                    ),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 20),
              
              // Accessibility Metrics
              pw.Text(
                'Key Accessibility Metrics',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              
              _buildDetailRow('Images without alt text', 
                '${a11y['imagesWithoutAlt'] ?? 0}',
                (a11y['imagesWithoutAlt'] ?? 0) == 0 ? successColor : errorColor),
              _buildDetailRow('Buttons without labels',
                '${a11y['buttonsWithoutLabel'] ?? 0}',
                (a11y['buttonsWithoutLabel'] ?? 0) == 0 ? successColor : errorColor),
              _buildDetailRow('Form inputs without labels',
                '${a11y['inputsWithoutLabel'] ?? 0}',
                (a11y['inputsWithoutLabel'] ?? 0) == 0 ? successColor : errorColor),
              _buildDetailRow('Language attribute',
                a11y['hasLangAttribute'] == true ? 'Present' : 'Missing',
                a11y['hasLangAttribute'] == true ? successColor : errorColor),
              _buildDetailRow('Viewport meta tag',
                a11y['hasViewport'] == true ? 'Present' : 'Missing',
                a11y['hasViewport'] == true ? successColor : errorColor),
              _buildDetailRow('Main landmark',
                a11y['hasMainLandmark'] == true ? 'Present' : 'Missing',
                a11y['hasMainLandmark'] == true ? successColor : warningColor),
              
              pw.SizedBox(height: 20),
              
              pw.Container(
                padding: pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.amber50,
                  border: pw.Border.all(color: warningColor),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  'Note: This is a simplified accessibility check. For comprehensive WCAG compliance testing, please use specialized tools like axe DevTools or WAVE.',
                  style: pw.TextStyle(fontSize: 10, color: textColor),
                ),
              ),
            ],
          );
        },
      ),
    );
    
    // Add Performance Analysis page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          final perf = audits['performance'] ?? {};
          final cwv = audits['coreWebVitals'] ?? {};
          final resources = audits['resources'] ?? {};
          
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Performance Analysis'),
              pw.SizedBox(height: 20),
              
              // Performance Score
              pw.Container(
                padding: pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Performance Score',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      '${scores['performanceScore'] ?? 0}/100',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: _getScoreColor(scores['performanceScore'] ?? 0),
                      ),
                    ),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 20),
              
              // Core Web Vitals
              pw.Text(
                'Core Web Vitals (Estimated)',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              
              _buildDetailRow('Largest Contentful Paint (LCP)',
                '${cwv['lcp'] ?? 'N/A'} ms',
                _getLCPColor(cwv['lcp'] ?? 0)),
              _buildDetailRow('First Contentful Paint (FCP)',
                '${cwv['fcp'] ?? 'N/A'} ms',
                _getFCPColor(cwv['fcp'] ?? 0)),
              _buildDetailRow('Total Blocking Time (TBT)',
                '${cwv['tbt'] ?? 'N/A'} ms',
                _getTBTColor(cwv['tbt'] ?? 0)),
              _buildDetailRow('Time to Interactive (TTI)',
                '${cwv['tti'] ?? 'N/A'} ms',
                primaryColor),
              
              pw.SizedBox(height: 20),
              
              // Resource Breakdown
              pw.Text(
                'Resource Breakdown',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              
              _buildDetailRow('Total Requests',
                '${resources['totalRequests'] ?? 0}',
                primaryColor),
              _buildDetailRow('JavaScript Files',
                '${resources['javascriptFiles'] ?? 0}',
                primaryColor),
              _buildDetailRow('Stylesheets',
                '${resources['stylesheets'] ?? 0}',
                primaryColor),
              _buildDetailRow('Images',
                '${resources['images'] ?? 0}',
                primaryColor),
              _buildDetailRow('Fonts',
                '${resources['fonts'] ?? 0}',
                primaryColor),
              
              pw.SizedBox(height: 20),
              
              // Performance Metrics
              pw.Text(
                'Performance Metrics',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              
              _buildDetailRow('Response Time',
                '${perf['responseTime'] ?? 0} ms',
                _getPerformanceColor(perf['responseTime'] ?? 0)),
              _buildDetailRow('Page Size',
                '${((perf['size'] ?? 0) / 1024).toStringAsFixed(1)} KB',
                _getSizeColor(perf['size'] ?? 0)),
              _buildDetailRow('Compression',
                perf['compression'] ?? 'None',
                perf['compression'] != null ? successColor : warningColor),
            ],
          );
        },
      ),
    );
    
    // Add SEO Analysis page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          final seo = audits['seo'] ?? {};
          
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('SEO Analysis'),
              pw.SizedBox(height: 20),
              
              // SEO Score
              pw.Container(
                padding: pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'SEO Score',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      '${scores['seoScore'] ?? 0}/100',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: _getScoreColor(scores['seoScore'] ?? 0),
                      ),
                    ),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 20),
              
              // Meta Tags
              pw.Text(
                'Meta Tags',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              
              _buildDetailRow('Title',
                seo['hasTitle'] == true ? 'Present (${seo['titleLength']} chars)' : 'Missing',
                seo['hasTitle'] == true ? successColor : errorColor),
              if (seo['title']?.isNotEmpty ?? false)
                pw.Container(
                  margin: pw.EdgeInsets.only(left: 20, bottom: 5),
                  child: pw.Text(
                    '"${seo['title']}"',
                    style: pw.TextStyle(fontSize: 10, color: subtleColor),
                  ),
                ),
              
              _buildDetailRow('Description',
                seo['hasDescription'] == true ? 'Present (${seo['descriptionLength']} chars)' : 'Missing',
                seo['hasDescription'] == true ? successColor : errorColor),
              if (seo['description']?.isNotEmpty ?? false)
                pw.Container(
                  margin: pw.EdgeInsets.only(left: 20, bottom: 5),
                  child: pw.Text(
                    '"${(seo['description'] as String).substring(0, (seo['description'] as String).length.clamp(0, 100))}..."',
                    style: pw.TextStyle(fontSize: 10, color: subtleColor),
                  ),
                ),
              
              _buildDetailRow('Canonical URL',
                seo['hasCanonical'] == true ? 'Present' : 'Missing',
                seo['hasCanonical'] == true ? successColor : warningColor),
              
              pw.SizedBox(height: 20),
              
              // Heading Structure
              pw.Text(
                'Heading Structure',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              
              _buildDetailRow('H1 Tags',
                '${seo['h1Count'] ?? 0}',
                seo['h1Count'] == 1 ? successColor : 
                seo['h1Count'] == 0 ? errorColor : warningColor),
              _buildDetailRow('H2 Tags',
                '${seo['h2Count'] ?? 0}',
                primaryColor),
              _buildDetailRow('H3 Tags',
                '${seo['h3Count'] ?? 0}',
                primaryColor),
              
              pw.SizedBox(height: 20),
              
              // Open Graph
              pw.Text(
                'Open Graph Tags',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              
              _buildDetailRow('OG Title',
                seo['hasOgTitle'] == true ? 'Present' : 'Missing',
                seo['hasOgTitle'] == true ? successColor : warningColor),
              _buildDetailRow('OG Description',
                seo['hasOgDescription'] == true ? 'Present' : 'Missing',
                seo['hasOgDescription'] == true ? successColor : warningColor),
              _buildDetailRow('OG Image',
                seo['hasOgImage'] == true ? 'Present' : 'Missing',
                seo['hasOgImage'] == true ? successColor : warningColor),
            ],
          );
        },
      ),
    );
    
    // Add Mobile & Content page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          final mobile = audits['mobile'] ?? {};
          final content = audits['content'] ?? {};
          
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Mobile Friendliness'),
              pw.SizedBox(height: 20),
              
              // Mobile Score
              pw.Container(
                padding: pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Mobile Score',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      '${scores['mobileScore'] ?? 0}/100',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: _getScoreColor(scores['mobileScore'] ?? 0),
                      ),
                    ),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 15),
              
              _buildDetailRow('Viewport Tag',
                mobile['hasViewport'] == true ? 'Present' : 'Missing',
                mobile['hasViewport'] == true ? successColor : errorColor),
              _buildDetailRow('Responsive Design',
                mobile['hasResponsiveViewport'] == true ? 'Yes' : 'No',
                mobile['hasResponsiveViewport'] == true ? successColor : errorColor),
              _buildDetailRow('User Scalable',
                mobile['isScalable'] == true ? 'Yes' : 'No',
                mobile['isScalable'] == true ? successColor : warningColor),
              
              pw.SizedBox(height: 30),
              
              _buildSectionHeader('Content Analysis'),
              pw.SizedBox(height: 20),
              
              // Content Metrics
              _buildDetailRow('Word Count',
                '${content['wordCount'] ?? 0}',
                (content['wordCount'] ?? 0) > 300 ? successColor : warningColor),
              _buildDetailRow('Total Links',
                '${content['linkCount'] ?? 0}',
                primaryColor),
              _buildDetailRow('Internal Links',
                '${content['internalLinks'] ?? 0}',
                primaryColor),
              _buildDetailRow('External Links',
                '${content['externalLinks'] ?? 0}',
                primaryColor),
              _buildDetailRow('Images',
                '${content['imageCount'] ?? 0}',
                primaryColor),
              _buildDetailRow('Forms',
                '${content['forms'] ?? 0}',
                primaryColor),
              _buildDetailRow('Videos',
                '${content['videos'] ?? 0}',
                primaryColor),
              _buildDetailRow('Tables',
                '${content['tables'] ?? 0}',
                primaryColor),
            ],
          );
        },
      ),
    );
    
    // Add Detailed Recommendations page
    if (recommendations.isNotEmpty) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('Detailed Recommendations'),
                pw.SizedBox(height: 20),
                
                // High Priority
                if ((recommendations['high'] as List?)?.isNotEmpty ?? false) ...[
                  pw.Text(
                    'Critical Issues',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: errorColor,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  ...((recommendations['high'] as List).map((rec) =>
                    _buildDetailedRecommendation(rec, errorColor)
                  ).toList()),
                  pw.SizedBox(height: 20),
                ],
                
                // Medium Priority
                if ((recommendations['medium'] as List?)?.isNotEmpty ?? false) ...[
                  pw.Text(
                    'Important Improvements',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: warningColor,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  ...((recommendations['medium'] as List).map((rec) =>
                    _buildDetailedRecommendation(rec, warningColor)
                  ).toList()),
                  pw.SizedBox(height: 20),
                ],
                
                // Low Priority
                if ((recommendations['low'] as List?)?.isNotEmpty ?? false) ...[
                  pw.Text(
                    'Nice to Have',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  ...((recommendations['low'] as List).take(3).map((rec) =>
                    _buildDetailedRecommendation(rec, primaryColor)
                  ).toList()),
                ],
              ],
            );
          },
        ),
      );
    }
    
    // Save the PDF
    final file = File(outputPath);
    await file.writeAsBytes(await pdf.save());
  }
  
  static pw.Widget _buildSectionHeader(String title) {
    return pw.Container(
      padding: pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: pw.BoxDecoration(
        gradient: pw.LinearGradient(
          colors: [PdfColor.fromHex('#f8fafc'), PdfColor.fromHex('#e2e8f0')],
        ),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 18,
          fontWeight: pw.FontWeight.bold,
          color: PdfColor.fromHex('#1f2937'),
        ),
      ),
    );
  }
  
  static pw.Widget _buildScoreItem(String label, int score, String weight, String description) {
    return pw.Container(
      margin: pw.EdgeInsets.only(bottom: 10),
      padding: pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  children: [
                    pw.Text(
                      label,
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(width: 10),
                    pw.Text(
                      weight,
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
                pw.Text(
                  description,
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          ),
          pw.Text(
            '$score/100',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: _getScoreColor(score),
            ),
          ),
        ],
      ),
    );
  }
  
  static pw.Widget _buildMetricCard(String label, String value, PdfColor color) {
    return pw.Container(
      width: 100,
      padding: pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey600,
            ),
          ),
        ],
      ),
    );
  }
  
  static pw.Widget _buildDetailRow(String label, String value, PdfColor valueColor) {
    return pw.Container(
      padding: pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 11),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
  
  static pw.Widget _buildRecommendation(Map<String, dynamic> rec, PdfColor color) {
    return pw.Container(
      margin: pw.EdgeInsets.only(bottom: 8),
      padding: pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border(left: pw.BorderSide(color: color, width: 3)),
        color: PdfColors.grey50,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            rec['title'] ?? '',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            rec['description'] ?? '',
            style: pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey700,
            ),
          ),
        ],
      ),
    );
  }
  
  static pw.Widget _buildDetailedRecommendation(Map<String, dynamic> rec, PdfColor color) {
    return pw.Container(
      margin: pw.EdgeInsets.only(bottom: 10),
      padding: pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border(left: pw.BorderSide(color: color, width: 4)),
        color: PdfColors.grey50,
        borderRadius: pw.BorderRadius.only(
          topRight: pw.Radius.circular(4),
          bottomRight: pw.Radius.circular(4),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            rec['title'] ?? '',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#1f2937'),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            rec['description'] ?? '',
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey700,
            ),
          ),
        ],
      ),
    );
  }
  
  static PdfColor _getScoreColor(int score) {
    if (score >= 90) return PdfColor.fromHex('#10b981');
    if (score >= 75) return PdfColor.fromHex('#3b82f6');
    if (score >= 50) return PdfColor.fromHex('#f59e0b');
    return PdfColor.fromHex('#ef4444');
  }
  
  static PdfColor _getPerformanceColor(int ms) {
    if (ms < 1000) return PdfColor.fromHex('#10b981');
    if (ms < 3000) return PdfColor.fromHex('#f59e0b');
    return PdfColor.fromHex('#ef4444');
  }
  
  static PdfColor _getSizeColor(int bytes) {
    if (bytes < 500000) return PdfColor.fromHex('#10b981');
    if (bytes < 1000000) return PdfColor.fromHex('#059669');
    if (bytes < 2000000) return PdfColor.fromHex('#f59e0b');
    return PdfColor.fromHex('#ef4444');
  }
  
  static PdfColor _getLCPColor(int ms) {
    if (ms < 2500) return PdfColor.fromHex('#10b981');
    if (ms < 4000) return PdfColor.fromHex('#f59e0b');
    return PdfColor.fromHex('#ef4444');
  }
  
  static PdfColor _getFCPColor(int ms) {
    if (ms < 1800) return PdfColor.fromHex('#10b981');
    if (ms < 3000) return PdfColor.fromHex('#f59e0b');
    return PdfColor.fromHex('#ef4444');
  }
  
  static PdfColor _getTBTColor(int ms) {
    if (ms < 300) return PdfColor.fromHex('#10b981');
    if (ms < 600) return PdfColor.fromHex('#f59e0b');
    return PdfColor.fromHex('#ef4444');
  }
}