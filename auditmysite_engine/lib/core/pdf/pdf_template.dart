import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// PDF Theme and Template Components
class PdfTemplate {
  // Color scheme
  static final primaryColor = PdfColor.fromHex('#2563eb');
  static final successColor = PdfColor.fromHex('#10b981');
  static final warningColor = PdfColor.fromHex('#f59e0b');
  static final errorColor = PdfColor.fromHex('#ef4444');
  static final textColor = PdfColor.fromHex('#1f2937');
  static final subtleColor = PdfColor.fromHex('#6b7280');
  static final backgroundColor = PdfColors.grey50;
  
  /// Build page header
  static pw.Widget buildHeader(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 20),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: primaryColor, width: 2),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: primaryColor,
            ),
          ),
          pw.Text(
            'AuditMySite',
            style: pw.TextStyle(
              fontSize: 12,
              color: subtleColor,
            ),
          ),
        ],
      ),
    );
  }
  
  /// Build section header
  static pw.Widget buildSectionHeader(String title, {String? subtitle}) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 20, bottom: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: textColor,
            ),
          ),
          if (subtitle != null) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              subtitle,
              style: pw.TextStyle(
                fontSize: 10,
                color: subtleColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  /// Build score badge
  static pw.Widget buildScoreBadge(int score, {double size = 60}) {
    final color = getScoreColor(score);
    return pw.Container(
      width: size,
      height: size,
      decoration: pw.BoxDecoration(
        shape: pw.BoxShape.circle,
        color: color,
      ),
      child: pw.Center(
        child: pw.Text(
          '$score',
          style: pw.TextStyle(
            fontSize: size * 0.4,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
        ),
      ),
    );
  }
  
  /// Build metric card
  static pw.Widget buildMetricCard(String label, String value, {PdfColor? color}) {
    return pw.Container(
      width: 120,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: backgroundColor,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(
          color: color ?? subtleColor,
          width: 1,
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 9,
              color: subtleColor,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: color ?? textColor,
            ),
          ),
        ],
      ),
    );
  }
  
  /// Build issue/recommendation item
  static pw.Widget buildIssueItem({
    required String title,
    required String severity,
    String? description,
  }) {
    final color = severity == 'critical' ? errorColor :
                  severity == 'serious' ? warningColor :
                  severity == 'moderate' ? PdfColor.fromHex('#3b82f6') :
                  subtleColor;
    
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border(left: pw.BorderSide(color: color, width: 4)),
        color: backgroundColor,
        borderRadius: const pw.BorderRadius.only(
          topRight: pw.Radius.circular(4),
          bottomRight: pw.Radius.circular(4),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: pw.BoxDecoration(
                  color: color,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  severity.toUpperCase(),
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.white,
                  ),
                ),
              ),
            ],
          ),
          if (description != null) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              description,
              style: pw.TextStyle(
                fontSize: 9,
                color: subtleColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  /// Build progress bar
  static pw.Widget buildProgressBar(double value, {PdfColor? color, double width = 200}) {
    final progress = value.clamp(0.0, 1.0);
    return pw.Container(
      width: width,
      height: 8,
      decoration: pw.BoxDecoration(
        color: PdfColors.grey300,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Stack(
        children: [
          pw.Container(
            width: width * progress,
            decoration: pw.BoxDecoration(
              color: color ?? primaryColor,
              borderRadius: pw.BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
  
  /// Build data table
  static pw.Widget buildDataTable({
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      children: [
        // Header row
        pw.TableRow(
          decoration: pw.BoxDecoration(color: backgroundColor),
          children: headers.map((header) => pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Text(
              header,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: textColor,
              ),
            ),
          )).toList(),
        ),
        // Data rows
        ...rows.map((row) => pw.TableRow(
          children: row.map((cell) => pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Text(
              cell,
              style: pw.TextStyle(
                fontSize: 9,
                color: textColor,
              ),
            ),
          )).toList(),
        )),
      ],
    );
  }
  
  // Helper methods for colors
  static PdfColor getScoreColor(int score) {
    if (score >= 90) return successColor;
    if (score >= 75) return PdfColor.fromHex('#3b82f6');
    if (score >= 50) return warningColor;
    return errorColor;
  }
  
  static PdfColor getPerformanceColor(int ms) {
    if (ms < 1000) return successColor;
    if (ms < 3000) return warningColor;
    return errorColor;
  }
  
  static PdfColor getSizeColor(int bytes) {
    if (bytes < 500000) return successColor;
    if (bytes < 1000000) return PdfColor.fromHex('#059669');
    if (bytes < 2000000) return warningColor;
    return errorColor;
  }
}
