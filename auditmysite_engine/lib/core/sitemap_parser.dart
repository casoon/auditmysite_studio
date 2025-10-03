import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

/// Parser for sitemap.xml files
class SitemapParser {
  /// Parse sitemap from URL
  static Future<List<String>> parseSitemapFromUrl(String baseUrl) async {
    final urls = <String>[];
    
    try {
      // Clean base URL
      var sitemapUrl = baseUrl.trim();
      if (!sitemapUrl.startsWith('http://') && !sitemapUrl.startsWith('https://')) {
        sitemapUrl = 'https://$sitemapUrl';
      }
      
      // Remove trailing slash
      if (sitemapUrl.endsWith('/')) {
        sitemapUrl = sitemapUrl.substring(0, sitemapUrl.length - 1);
      }
      
      // Try common sitemap locations
      final sitemapLocations = [
        '$sitemapUrl/sitemap.xml',
        '$sitemapUrl/sitemap_index.xml',
        '$sitemapUrl/sitemap-index.xml',
        '$sitemapUrl/sitemap1.xml',
        '$sitemapUrl/wp-sitemap.xml',
      ];
      
      for (final location in sitemapLocations) {
        try {
          final response = await http.get(
            Uri.parse(location),
            headers: {
              'User-Agent': 'AuditMySite/1.0 (Desktop Studio; +https://auditmysite.io)',
            },
          ).timeout(Duration(seconds: 10));
          
          if (response.statusCode == 200) {
            final parsedUrls = await _parseSitemapContent(response.body);
            if (parsedUrls.isNotEmpty) {
              urls.addAll(parsedUrls);
              print('Found sitemap at: $location with ${parsedUrls.length} URLs');
              break;
            }
          }
        } catch (e) {
          // Try next location
          continue;
        }
      }
      
      // If no sitemap found, try robots.txt
      if (urls.isEmpty) {
        final robotsUrls = await _checkRobotsTxt('$sitemapUrl/robots.txt');
        for (final robotsSitemapUrl in robotsUrls) {
          try {
            final response = await http.get(
              Uri.parse(robotsSitemapUrl),
              headers: {
                'User-Agent': 'AuditMySite/1.0 (Desktop Studio; +https://auditmysite.io)',
              },
            ).timeout(Duration(seconds: 10));
            
            if (response.statusCode == 200) {
              final parsedUrls = await _parseSitemapContent(response.body);
              urls.addAll(parsedUrls);
            }
          } catch (e) {
            // Ignore and continue
          }
        }
      }
    } catch (e) {
      print('Error parsing sitemap: $e');
    }
    
    // Remove duplicates and sort
    final uniqueUrls = urls.toSet().toList();
    uniqueUrls.sort();
    
    return uniqueUrls;
  }
  
  /// Check robots.txt for sitemap locations
  static Future<List<String>> _checkRobotsTxt(String robotsUrl) async {
    final sitemapUrls = <String>[];
    
    try {
      final response = await http.get(
        Uri.parse(robotsUrl),
        headers: {
          'User-Agent': 'AuditMySite/1.0 (Desktop Studio; +https://auditmysite.io)',
        },
      ).timeout(Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final lines = response.body.split('\n');
        for (final line in lines) {
          if (line.toLowerCase().startsWith('sitemap:')) {
            final url = line.substring(8).trim();
            if (url.isNotEmpty) {
              sitemapUrls.add(url);
            }
          }
        }
      }
    } catch (e) {
      // Ignore robots.txt errors
    }
    
    return sitemapUrls;
  }
  
  /// Parse sitemap content
  static Future<List<String>> _parseSitemapContent(String content) async {
    final urls = <String>[];
    
    try {
      final document = XmlDocument.parse(content);
      
      // Check if it's a sitemap index
      final sitemapElements = document.findAllElements('sitemap');
      if (sitemapElements.isNotEmpty) {
        // It's a sitemap index, parse each sitemap
        for (final sitemap in sitemapElements) {
          final locElement = sitemap.findElements('loc').firstOrNull;
          if (locElement != null && locElement.text.isNotEmpty) {
            try {
              final response = await http.get(
                Uri.parse(locElement.text),
                headers: {
                  'User-Agent': 'AuditMySite/1.0 (Desktop Studio; +https://auditmysite.io)',
                },
              ).timeout(Duration(seconds: 10));
              
              if (response.statusCode == 200) {
                final subUrls = await _parseSitemapContent(response.body);
                urls.addAll(subUrls);
              }
            } catch (e) {
              // Ignore sub-sitemap errors
            }
          }
        }
      }
      
      // Parse regular URL entries
      final urlElements = document.findAllElements('url');
      for (final urlElement in urlElements) {
        final locElement = urlElement.findElements('loc').firstOrNull;
        if (locElement != null && locElement.text.isNotEmpty) {
          urls.add(locElement.text);
        }
      }
    } catch (e) {
      print('Error parsing sitemap XML: $e');
    }
    
    return urls;
  }
  
  /// Parse sitemap from local file content
  static List<String> parseSitemapFromContent(String xmlContent) {
    final urls = <String>[];
    
    try {
      final document = XmlDocument.parse(xmlContent);
      
      // Parse URL entries
      final urlElements = document.findAllElements('url');
      for (final urlElement in urlElements) {
        final locElement = urlElement.findElements('loc').firstOrNull;
        if (locElement != null && locElement.text.isNotEmpty) {
          urls.add(locElement.text);
        }
      }
    } catch (e) {
      print('Error parsing sitemap content: $e');
    }
    
    return urls;
  }
}