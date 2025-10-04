import 'package:pdf/widgets.dart' as pw;

/// Base class for PDF report sections
abstract class PdfSection {
  final Map<String, dynamic> data;
  
  PdfSection(this.data);
  
  /// Generate the section content
  List<pw.Widget> build();
  
  /// Get section title
  String get title;
  
  /// Check if this section has data to display
  bool get hasData => data.isNotEmpty;
}
