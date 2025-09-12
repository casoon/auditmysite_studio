import '../events.dart';
import 'audit_base.dart';

class ContentWeightAudit extends Audit {
  @override
  String get name => 'content_weight';

  @override
  Future<void> run(AuditContext ctx) async {
    final page = ctx.page;
    
    // Performance API für detaillierte Ressourcen-Informationen nutzen
    final resourceData = await page.evaluate('''
      () => {
        const resources = performance.getEntriesByType('resource');
        const navigation = performance.getEntriesByType('navigation')[0];
        
        let totalSize = 0;
        let totalRequests = 0;
        const resourcesByType = {};
        const largeResources = [];
        const slowResources = [];
        
        // Ressourcen nach Typ kategorisieren
        resources.forEach(resource => {
          const type = getResourceType(resource.name, resource.initiatorType);
          const size = resource.transferSize || resource.decodedBodySize || 0;
          const duration = resource.responseEnd - resource.requestStart;
          
          if (!resourcesByType[type]) {
            resourcesByType[type] = {
              count: 0,
              totalSize: 0,
              avgDuration: 0,
              resources: []
            };
          }
          
          resourcesByType[type].count++;
          resourcesByType[type].totalSize += size;
          resourcesByType[type].resources.push({
            url: resource.name,
            size: size,
            duration: duration,
            cached: resource.transferSize === 0
          });
          
          totalSize += size;
          totalRequests++;
          
          // Große Ressourcen (>500KB) identifizieren
          if (size > 500 * 1024) {
            largeResources.push({
              url: resource.name,
              type: type,
              size: size,
              sizeFormatted: formatBytes(size)
            });
          }
          
          // Langsame Ressourcen (>2s) identifizieren
          if (duration > 2000) {
            slowResources.push({
              url: resource.name,
              type: type,
              duration: Math.round(duration),
              size: size
            });
          }
        });
        
        // Durchschnittliche Ladezeiten berechnen
        Object.keys(resourcesByType).forEach(type => {
          const typeData = resourcesByType[type];
          typeData.avgDuration = typeData.resources.reduce((sum, r) => sum + r.duration, 0) / typeData.count;
          typeData.avgDuration = Math.round(typeData.avgDuration);
        });
        
        function getResourceType(url, initiatorType) {
          if (url.match(/\.(css)(\$|\?)/)) return 'css';
          if (url.match(/\.(js)(\$|\?)/)) return 'javascript';
          if (url.match(/\.(jpg|jpeg|png|gif|svg|webp|avif)(\$|\?)/i)) return 'image';
          if (url.match(/\.(woff|woff2|ttf|eot|otf)(\$|\?)/i)) return 'font';
          if (url.match(/\.(mp4|webm|ogg|avi)(\$|\?)/i)) return 'video';
          if (url.match(/\.(mp3|wav|ogg)(\$|\?)/i)) return 'audio';
          if (initiatorType === 'xmlhttprequest' || initiatorType === 'fetch') return 'xhr';
          return 'other';
        }
        
        function formatBytes(bytes) {
          if (bytes === 0) return '0 B';
          const k = 1024;
          const sizes = ['B', 'KB', 'MB', 'GB'];
          const i = Math.floor(Math.log(bytes) / Math.log(k));
          return Math.round((bytes / Math.pow(k, i)) * 100) / 100 + ' ' + sizes[i];
        }
        
        return {
          totalSize,
          totalSizeFormatted: formatBytes(totalSize),
          totalRequests,
          resourcesByType,
          largeResources,
          slowResources,
          navigationTiming: {
            domContentLoaded: navigation ? Math.round(navigation.domContentLoadedEventEnd - navigation.navigationStart) : null,
            loadComplete: navigation ? Math.round(navigation.loadEventEnd - navigation.navigationStart) : null,
            firstByte: navigation ? Math.round(navigation.responseStart - navigation.navigationStart) : null
          }
        };
      }
    ''');
    
    // Content Weight Score berechnen
    final totalSize = resourceData['totalSize'] as num;
    final totalRequests = resourceData['totalRequests'] as num;
    final largeResources = resourceData['largeResources'] as List;
    final slowResources = resourceData['slowResources'] as List;
    
    final issues = <Map<String, dynamic>>[];
    double score = 100.0;
    
    // Penalties für große Gesamtgröße
    if (totalSize > 5 * 1024 * 1024) { // > 5MB
      score -= 30;
      issues.add({
        'category': 'total_size',
        'severity': 'error',
        'message': 'Total page size exceeds 5MB (${_formatBytes(totalSize.toInt())})',
        'impact': 'Very slow loading, especially on mobile connections'
      });
    } else if (totalSize > 2 * 1024 * 1024) { // > 2MB
      score -= 15;
      issues.add({
        'category': 'total_size',
        'severity': 'warning',
        'message': 'Total page size exceeds 2MB (${_formatBytes(totalSize.toInt())})',
        'impact': 'May cause slow loading on mobile connections'
      });
    }
    
    // Penalties für zu viele Requests
    if (totalRequests > 100) {
      score -= 20;
      issues.add({
        'category': 'request_count',
        'severity': 'error',
        'message': 'Too many HTTP requests ($totalRequests)',
        'impact': 'High latency due to connection overhead'
      });
    } else if (totalRequests > 50) {
      score -= 10;
      issues.add({
        'category': 'request_count',
        'severity': 'warning',
        'message': 'Many HTTP requests ($totalRequests)',
        'impact': 'Could benefit from resource bundling'
      });
    }
    
    // Penalties für große einzelne Ressourcen
    if (largeResources.isNotEmpty) {
      score -= (largeResources.length * 5).toDouble();
      issues.add({
        'category': 'large_resources',
        'severity': 'warning',
        'message': '${largeResources.length} large resources (>500KB) found',
        'impact': 'Large resources delay page rendering',
        'details': largeResources
      });
    }
    
    // Penalties für langsame Ressourcen
    if (slowResources.isNotEmpty) {
      score -= (slowResources.length * 8).toDouble();
      issues.add({
        'category': 'slow_resources',
        'severity': 'error',
        'message': '${slowResources.length} slow-loading resources (>2s) found',
        'impact': 'Slow resources block page completion',
        'details': slowResources
      });
    }
    
    // Score begrenzen
    score = score.clamp(0.0, 100.0);
    
    // Grade zuweisen
    String grade;
    if (score >= 90) grade = 'A';
    else if (score >= 80) grade = 'B';
    else if (score >= 70) grade = 'C';
    else if (score >= 60) grade = 'D';
    else grade = 'F';
    
    // Zusätzliche Optimierungsempfehlungen
    final recommendations = <Map<String, dynamic>>[];
    
    final resourcesByType = resourceData['resourcesByType'] as Map;
    
    // Empfehlungen basierend auf Ressourcentypen
    if (resourcesByType['image'] != null) {
      final imageData = resourcesByType['image'] as Map;
      final imageSize = (imageData['totalSize'] as num).toInt();
      if (imageSize > 1024 * 1024) { // > 1MB Bilder
        recommendations.add({
          'category': 'images',
          'priority': 'high',
          'message': 'Optimize images (${_formatBytes(imageSize)} total)',
          'suggestions': [
            'Use modern formats like WebP or AVIF',
            'Implement responsive images with srcset',
            'Compress images without quality loss',
            'Consider lazy loading for below-fold images'
          ]
        });
      }
    }
    
    if (resourcesByType['javascript'] != null) {
      final jsData = resourcesByType['javascript'] as Map;
      final jsCount = jsData['count'] as int;
      if (jsCount > 10) {
        recommendations.add({
          'category': 'javascript',
          'priority': 'medium',
          'message': 'Many JavaScript files ($jsCount)',
          'suggestions': [
            'Bundle and minify JavaScript files',
            'Implement code splitting',
            'Remove unused JavaScript',
            'Use dynamic imports for non-critical code'
          ]
        });
      }
    }
    
    if (resourcesByType['css'] != null) {
      final cssData = resourcesByType['css'] as Map;
      final cssCount = cssData['count'] as int;
      if (cssCount > 5) {
        recommendations.add({
          'category': 'css',
          'priority': 'medium',
          'message': 'Many CSS files ($cssCount)',
          'suggestions': [
            'Combine and minify CSS files',
            'Remove unused CSS',
            'Inline critical CSS',
            'Use CSS preprocessing for optimization'
          ]
        });
      }
    }
    
    // Resultat zusammenstellen
    final contentWeightResult = {
      'summary': {
        'totalSize': totalSize,
        'totalSizeFormatted': _formatBytes(totalSize.toInt()),
        'totalRequests': totalRequests,
        'avgRequestSize': totalRequests > 0 ? _formatBytes((totalSize / totalRequests).round()) : '0 B',
      },
      'resourcesByType': resourcesByType,
      'largeResources': largeResources,
      'slowResources': slowResources,
      'navigationTiming': resourceData['navigationTiming'],
      'issues': issues,
      'recommendations': recommendations,
      'score': score.round(),
      'grade': grade,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    ctx.contentWeightResult = contentWeightResult;
  }
  
  String _formatBytes(int bytes) {
    if (bytes == 0) return '0 B';
    const sizes = ['B', 'KB', 'MB', 'GB'];
    final i = (bytes.bitLength - 1) ~/ 10;
    return '${(bytes / (1 << (i * 10))).toStringAsFixed(1)} ${sizes[i]}';
  }
}
