#!/usr/bin/env dart
/// Complete audit with PDF generation
/// Tests full engine capabilities for casoon.de
import 'dart:io';
import 'dart:async';
import 'package:auditmysite_engine/desktop_integration.dart';
import 'package:auditmysite_engine/core/sitemap_loader.dart';

void main(List<String> arguments) async {
  print('🚀 Starting Complete Audit for casoon.de');
  print('═' * 60);
  
  // Setup
  final integration = DesktopIntegration();
  final outputDir = Directory('./test_output_casoon');
  
  if (await outputDir.exists()) {
    print('🗑️  Cleaning old output directory...');
    await outputDir.delete(recursive: true);
  }
  
  await outputDir.create(recursive: true);
  print('📁 Output directory: ${outputDir.absolute.path}');
  
  try {
    print('\n📊 Loading sitemap...');
    final baseUrl = Uri.parse('https://www.casoon.de');
    
    // Try to load sitemap, fallback to base URL
    List<Uri> urls;
    try {
      final sitemapUrl = Uri.parse('https://www.casoon.de/sitemap.xml');
      urls = await loadSitemapUris(sitemapUrl);
      print('✅ Loaded ${urls.length} URLs from sitemap');
    } catch (e) {
      print('⚠️  Sitemap not found, using base URL only');
      urls = [baseUrl];
    }
    
    print('\n📊 Configuration:');
    print('  • URLs: ${urls.length}');
    print('  • Audits: ALL (Performance, SEO, Accessibility, Mobile, Content)');
    print('  • Output: JSON + PDF');
    print('');
    
    // Create configuration
    final config = AuditConfiguration(
      urls: urls,
      outputPath: outputDir.path,
      concurrency: 2,
      maxRetries: 2,
      delayMs: 1000,
      rateLimit: null,
      performanceBudget: 'default',
      skipRedirects: false,
      maxRedirectsToFollow: 5,
      enablePerformance: true,
      enableSEO: true,
      enableContentWeight: true,
      enableContentQuality: true,
      enableMobile: true,
      enableWCAG21: true,
      enableARIA: true,
      enableAccessibility: true,
      enableScreenshots: false,
      useAdvancedAudits: true,
    );
    
    // Run audit
    print('🔍 Starting audit session...');
    final session = await integration.startAudit(config);
    
    print('✅ Session created: ${session.sessionId}');
    print('');
    
    // Monitor progress
    var pagesCompleted = 0;
    var pagesStarted = 0;
    var totalUrls = urls.length;
    
    print('🔄 Monitoring audit progress...');
    
    // Listen to events in parallel with processing
    final eventMonitor = session.eventStream.listen((event) {
      switch (event.type) {
        case EngineEventType.pageStarted:
          pagesStarted++;
          stdout.write('\r🔄 Progress: [$pagesCompleted/$totalUrls] - Processing: ${event.url}');
          break;
        case EngineEventType.pageFinished:
          pagesCompleted++;
          stdout.write('\r✅ Progress: [$pagesCompleted/$totalUrls] - Last: ${event.url}         ');
          break;
        case EngineEventType.pageError:
          print('\n⚠️  Error on ${event.url}: ${event.error}');
          break;
        case EngineEventType.pageSkipped:
          print('\n⏩ Skipped: ${event.url} (${event.message})');
          break;
        case EngineEventType.pageRedirected:
          print('\n➡️  Redirect: ${event.url} -> ${event.redirectUrl}');
          break;
        default:
          break;
      }
    });
    
    // Wait for processing to complete
    await session.processFuture;
    await eventMonitor.cancel();
    
    print('\n');
    print('═' * 60);
    print('✅ Audit Complete!');
    print('═' * 60);
    print('');
    print('📈 Results:');
    print('  • Total URLs: $totalUrls');
    print('  • Processed: $pagesCompleted');
    print('');
    print('📄 Output Files:');
    
    // List generated files
    final files = await outputDir
        .list(recursive: true)
        .where((e) => e is File)
        .cast<File>()
        .toList();
    
    final jsonFiles = files.where((f) => f.path.endsWith('.json')).toList();
    final pdfFiles = files.where((f) => f.path.endsWith('.pdf')).toList();
    
    print('  • JSON files: ${jsonFiles.length}');
    for (final file in jsonFiles) {
      final size = await file.length();
      print('    - ${file.path.split('/').last} (${(size / 1024).toStringAsFixed(1)} KB)');
    }
    
    print('  • PDF files: ${pdfFiles.length}');
    for (final file in pdfFiles) {
      final size = await file.length();
      print('    - ${file.path.split('/').last} (${(size / 1024).toStringAsFixed(1)} KB)');
    }
    
    print('');
    print('🎉 All done! Check the output directory for results.');
    
    // Validate PDF content
    if (pdfFiles.isNotEmpty) {
      print('');
      print('📋 PDF Validation:');
      for (final pdf in pdfFiles) {
        final size = await pdf.length();
        if (size < 1024) {
          print('  ⚠️  ${pdf.path.split('/').last} seems too small (${size} bytes)');
        } else {
          print('  ✅ ${pdf.path.split('/').last} generated successfully');
        }
      }
    }
    
  } catch (e, stackTrace) {
    print('');
    print('❌ Error during audit:');
    print(e);
    print('');
    print('Stack trace:');
    print(stackTrace);
    exit(1);
  }
  
  exit(0);
}
