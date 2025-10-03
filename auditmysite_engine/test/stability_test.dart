#!/usr/bin/env dart

import 'dart:io';
import 'dart:convert';

/// Comprehensive stability test for AuditMySite Engine
void main(List<String> args) async {
  print('🧪 AuditMySite Engine Stability Test\n');
  
  final tests = <Test>[
    // Basic functionality
    Test('Basic audit with test URL', 
      ['--sitemap=test', '--concurrency=1'], 
      expectSuccess: true),
    
    // Redirect handling
    Test('Redirect detection and skipping',
      ['--sitemap=test-redirect.xml', '--concurrency=1'],
      setup: () => createRedirectTestSitemap(),
      expectSuccess: true,
      expectRedirects: true),
    
    // Performance budgets
    Test('Performance budget - default',
      ['--sitemap=test', '--budget=default'],
      expectSuccess: true),
    
    Test('Performance budget - ecommerce',
      ['--sitemap=test', '--budget=ecommerce'],
      expectSuccess: true),
    
    // Feature flags
    Test('Disable specific audits',
      ['--sitemap=test', '--no-perf', '--no-seo'],
      expectSuccess: true,
      expectAudits: ['http', 'content_weight', 'content_quality', 'mobile', 'wcag21', 'aria', 'a11y_axe']),
    
    // Concurrency
    Test('Parallel processing',
      ['--sitemap=test-multi.xml', '--concurrency=4'],
      setup: () => createMultiUrlSitemap(),
      expectSuccess: true),
    
    // Error handling
    Test('Invalid URL handling',
      ['--sitemap=test-invalid.xml', '--concurrency=1'],
      setup: () => createInvalidUrlSitemap(),
      expectSuccess: true,
      expectErrors: true),
    
    // Rate limiting
    Test('Rate limiting',
      ['--sitemap=test', '--rate-limit=1', '--delay=1000'],
      expectSuccess: true,
      expectSlowExecution: true),
  ];
  
  var passed = 0;
  var failed = 0;
  
  for (final test in tests) {
    print('Running: ${test.name}');
    
    // Setup
    if (test.setup != null) {
      test.setup!();
    }
    
    // Run test
    final result = await runTest(test);
    
    if (result.success) {
      print('  ✅ PASSED');
      passed++;
    } else {
      print('  ❌ FAILED: ${result.error}');
      failed++;
    }
    
    // Cleanup
    if (test.cleanup != null) {
      test.cleanup!();
    }
    
    print('');
  }
  
  print('\n📊 Results:');
  print('  Passed: $passed');
  print('  Failed: $failed');
  print('  Total: ${tests.length}');
  
  if (failed > 0) {
    exit(1);
  }
}

Future<TestResult> runTest(Test test) async {
  try {
    final startTime = DateTime.now();
    
    // Run audit command
    final process = await Process.run(
      './bin/audit',
      test.args,
      workingDirectory: Directory.current.path,
    );
    
    final duration = DateTime.now().difference(startTime);
    final output = process.stdout.toString();
    final error = process.stderr.toString();
    
    // Check basic success
    if (test.expectSuccess && process.exitCode != 0) {
      return TestResult(false, 'Process exited with code ${process.exitCode}');
    }
    
    // Check for expected audits
    if (test.expectAudits != null) {
      for (final audit in test.expectAudits!) {
        if (!output.contains(audit)) {
          return TestResult(false, 'Expected audit "$audit" not found in output');
        }
      }
    }
    
    // Check for redirects
    if (test.expectRedirects == true) {
      if (!output.contains('Redirect') && !output.contains('redirect')) {
        return TestResult(false, 'Expected redirects not detected');
      }
    }
    
    // Check for errors
    if (test.expectErrors == true) {
      if (!output.contains('ERROR') && !error.isNotEmpty) {
        return TestResult(false, 'Expected errors not found');
      }
    } else if (test.expectSuccess) {
      // No errors expected
      if (output.contains('ERROR') && !output.contains('✅')) {
        return TestResult(false, 'Unexpected errors in output');
      }
    }
    
    // Check execution time
    if (test.expectSlowExecution == true) {
      if (duration.inSeconds < 2) {
        return TestResult(false, 'Expected slow execution due to rate limiting');
      }
    }
    
    // Check artifacts were created
    if (test.expectSuccess) {
      final artifactsMatch = RegExp(r'artifacts/([^/]+)').firstMatch(output);
      if (artifactsMatch != null) {
        final artifactDir = Directory('artifacts/${artifactsMatch.group(1)}');
        if (!await artifactDir.exists()) {
          return TestResult(false, 'Artifacts directory not created');
        }
        
        // Check for JSON files
        final pagesDir = Directory('${artifactDir.path}/pages');
        if (await pagesDir.exists()) {
          final jsonFiles = await pagesDir.list()
            .where((f) => f.path.endsWith('.json'))
            .toList();
          if (jsonFiles.isEmpty) {
            return TestResult(false, 'No JSON output files created');
          }
        }
      }
    }
    
    return TestResult(true);
  } catch (e) {
    return TestResult(false, e.toString());
  }
}

void createRedirectTestSitemap() {
  File('test-redirect.xml').writeAsStringSync('''<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url><loc>http://example.com/</loc></url>
  <url><loc>https://example.com/</loc></url>
</urlset>''');
}

void createMultiUrlSitemap() {
  File('test-multi.xml').writeAsStringSync('''<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url><loc>https://example.com/</loc></url>
  <url><loc>https://example.com/page1</loc></url>
  <url><loc>https://example.com/page2</loc></url>
  <url><loc>https://example.com/page3</loc></url>
</urlset>''');
}

void createInvalidUrlSitemap() {
  File('test-invalid.xml').writeAsStringSync('''<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url><loc>https://invalid-domain-that-does-not-exist-12345.com/</loc></url>
  <url><loc>https://example.com/404-not-found</loc></url>
</urlset>''');
}

class Test {
  final String name;
  final List<String> args;
  final Function()? setup;
  final Function()? cleanup;
  final bool expectSuccess;
  final bool? expectRedirects;
  final bool? expectErrors;
  final bool? expectSlowExecution;
  final List<String>? expectAudits;
  
  Test(this.name, this.args, {
    this.setup,
    this.cleanup,
    this.expectSuccess = true,
    this.expectRedirects,
    this.expectErrors,
    this.expectSlowExecution,
    this.expectAudits,
  });
}

class TestResult {
  final bool success;
  final String? error;
  
  TestResult(this.success, [this.error]);
}