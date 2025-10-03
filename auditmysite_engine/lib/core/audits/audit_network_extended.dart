import 'dart:convert';
import 'package:puppeteer/puppeteer.dart';
import 'package:logging/logging.dart';
import 'audit_base.dart';

/// Extended Network Analysis with HAR Generation
class NetworkExtendedAudit implements Audit {
  @override
  String get name => 'network_extended';
  
  final Logger _logger = Logger('NetworkExtendedAudit');
  
  // Known CDN domains
  static const Set<String> cdnDomains = {
    'cloudflare.com', 'cloudflare.net', 'cloudflare-dns.com',
    'amazonaws.com', 'cloudfront.net', 
    'akamai.net', 'akamaihd.net', 'akamaized.net',
    'fastly.net', 'fastly.com',
    'stackpathcdn.com', 'stackpath.com',
    'bunnycdn.com', 'b-cdn.net',
    'jsdelivr.net', 'unpkg.com',
    'cdnjs.cloudflare.com',
    'bootstrapcdn.com',
    'googleusercontent.com',
    'azureedge.net',
    'kxcdn.com',
    'maxcdn.com',
    'netdna-cdn.com',
    'edgecastcdn.net',
    'cachefly.net'
  };

  @override
  Future<void> run(AuditContext ctx) async {
    final page = ctx.page as Page;
    final url = ctx.url.toString();
    
    final networkResults = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'url': url,
      'har': {},
      'requests': [],
      'waterfall': {},
      'thirdParty': {},
      'cdn': {},
      'protocols': {},
      'performance': {},
      'blocking': {},
      'timing': {},
      'score': 0,
      'issues': [],
      'recommendations': []
    };
    
    try {
      final client = await page.target.createCDPSession();
      
      // Enable necessary CDP domains
      await client.send('Network.enable');
      await client.send('Page.enable');
      await client.send('Security.enable');
      
      // HAR data structure
      final har = {
        'log': {
          'version': '1.2',
          'creator': {
            'name': 'AuditMySite',
            'version': '1.0.0'
          },
          'pages': [],
          'entries': []
        }
      };
      
      final requests = <Map<String, dynamic>>[];
      final responses = <String, Map<String, dynamic>>{};
      final timings = <String, Map<String, dynamic>>{};
      
      // Track network events
      client.onMessage.listen((event) {
        switch (event.method) {
          case 'Network.requestWillBeSent':
            _handleRequestWillBeSent(event.params!, requests, har);
            break;
          case 'Network.responseReceived':
            _handleResponseReceived(event.params!, responses, har);
            break;
          case 'Network.loadingFinished':
            _handleLoadingFinished(event.params!, timings);
            break;
          case 'Network.loadingFailed':
            _handleLoadingFailed(event.params!, requests);
            break;
          case 'Security.securityStateChanged':
            _handleSecurityStateChanged(event.params!, networkResults);
            break;
        }
      });
      
      // Clear cache and cookies for clean measurement
      await client.send('Network.clearBrowserCache');
      await client.send('Network.clearBrowserCookies');
      
      // Navigate and collect data
      final startTime = DateTime.now();
      await page.goto(url, wait: Until.networkIdle);
      final loadTime = DateTime.now().difference(startTime).inMilliseconds;
      
      // Give time for all requests to complete
      await Future.delayed(Duration(seconds: 2));
      
      // Add page info to HAR
      har['log']['pages'].add({
        'startedDateTime': startTime.toIso8601String(),
        'id': 'page_1',
        'title': await page.title ?? url,
        'pageTimings': {
          'onContentLoad': loadTime ~/ 2, // Approximation
          'onLoad': loadTime
        }
      });
      
      // Process collected data
      networkResults['har'] = har;
      networkResults['requests'] = requests;
      
      // Analyze request waterfall
      networkResults['waterfall'] = _analyzeWaterfall(requests, startTime);
      
      // Analyze third-party resources
      networkResults['thirdParty'] = _analyzeThirdParty(requests, ctx.url);
      
      // Detect CDN usage
      networkResults['cdn'] = _detectCDN(requests);
      
      // Analyze protocols (HTTP/1.1, HTTP/2, HTTP/3)
      networkResults['protocols'] = await _analyzeProtocols(requests, responses);
      
      // Performance analysis
      networkResults['performance'] = _analyzeNetworkPerformance(requests, responses, timings);
      
      // Identify blocking resources
      networkResults['blocking'] = _identifyBlockingResources(requests);
      
      // Network timing breakdown
      networkResults['timing'] = await _getNetworkTiming(page);
      
      // Connection info
      networkResults['connections'] = await _getConnectionInfo(client);
      
      // Resource priorities
      networkResults['priorities'] = _analyzeResourcePriorities(requests);
      
      // Calculate score
      final scoring = _calculateScore(networkResults);
      networkResults['score'] = scoring['score'];
      networkResults['grade'] = scoring['grade'];
      networkResults['summary'] = scoring['summary'];
      
      // Identify issues
      networkResults['issues'] = _identifyIssues(networkResults);
      
      // Generate recommendations
      networkResults['recommendations'] = _generateRecommendations(networkResults);
      
      // Store in context
      ctx.networkExtended = networkResults;
      
    } catch (e) {
      _logger.severe('Error in network extended audit: $e');
      networkResults['error'] = e.toString();
      ctx.networkExtended = networkResults;
    }
  }
  
  void _handleRequestWillBeSent(Map<String, dynamic> params, List<Map<String, dynamic>> requests, Map<String, dynamic> har) {
    final request = params['request'];
    final requestId = params['requestId'];
    final timestamp = params['timestamp'];
    final initiator = params['initiator'];
    
    final requestData = {
      'requestId': requestId,
      'url': request['url'],
      'method': request['method'],
      'headers': request['headers'],
      'timestamp': timestamp,
      'initiator': initiator,
      'type': params['type'],
      'priority': request['initialPriority'] ?? 'Medium'
    };
    
    requests.add(requestData);
    
    // Add to HAR entries
    (har['log']['entries'] as List).add({
      '_requestId': requestId,
      'startedDateTime': DateTime.now().toIso8601String(),
      'request': {
        'method': request['method'],
        'url': request['url'],
        'httpVersion': 'HTTP/1.1', // Will be updated
        'headers': _convertHeaders(request['headers']),
        'queryString': _parseQueryString(request['url']),
        'cookies': [],
        'headersSize': -1,
        'bodySize': request['postData']?.length ?? 0
      },
      'response': {},
      'cache': {},
      'timings': {},
      'serverIPAddress': '',
      'connection': '',
      'pageref': 'page_1'
    });
  }
  
  void _handleResponseReceived(Map<String, dynamic> params, Map<String, dynamic> responses, Map<String, dynamic> har) {
    final response = params['response'];
    final requestId = params['requestId'];
    
    responses[requestId] = {
      'url': response['url'],
      'status': response['status'],
      'statusText': response['statusText'],
      'headers': response['headers'],
      'mimeType': response['mimeType'],
      'encodedDataLength': response['encodedDataLength'],
      'protocol': response['protocol'],
      'securityState': response['securityState'],
      'securityDetails': response['securityDetails'],
      'timing': response['timing']
    };
    
    // Update HAR entry
    final entries = har['log']['entries'] as List;
    final entry = entries.firstWhere(
      (e) => e['_requestId'] == requestId,
      orElse: () => <String, dynamic>{}
    );
    
    if (entry.isNotEmpty) {
      entry['response'] = {
        'status': response['status'],
        'statusText': response['statusText'],
        'httpVersion': response['protocol'] ?? 'HTTP/1.1',
        'headers': _convertHeaders(response['headers']),
        'cookies': [],
        'content': {
          'size': response['encodedDataLength'] ?? -1,
          'mimeType': response['mimeType'] ?? 'unknown',
          'compression': response['encodedDataLength'] != null && 
                        response['encodedDataLength'] < (response['dataLength'] ?? 0) 
                        ? response['encodedDataLength'] - (response['dataLength'] ?? 0) 
                        : 0
        },
        'redirectURL': response['headers']?['location'] ?? '',
        'headersSize': -1,
        'bodySize': response['encodedDataLength'] ?? -1
      };
      
      // Add timing if available
      if (response['timing'] != null) {
        final t = response['timing'];
        entry['timings'] = {
          'blocked': -1,
          'dns': (t['dnsEnd'] ?? 0) - (t['dnsStart'] ?? 0),
          'connect': (t['connectEnd'] ?? 0) - (t['connectStart'] ?? 0),
          'send': (t['sendEnd'] ?? 0) - (t['sendStart'] ?? 0),
          'wait': (t['receiveHeadersEnd'] ?? 0) - (t['sendEnd'] ?? 0),
          'receive': -1,
          'ssl': (t['sslEnd'] ?? 0) - (t['sslStart'] ?? 0)
        };
      }
      
      entry['serverIPAddress'] = response['remoteIPAddress'] ?? '';
      entry['connection'] = response['connectionId'] ?? '';
    }
  }
  
  void _handleLoadingFinished(Map<String, dynamic> params, Map<String, dynamic> timings) {
    final requestId = params['requestId'];
    timings[requestId] = {
      'encodedDataLength': params['encodedDataLength'],
      'timestamp': params['timestamp']
    };
  }
  
  void _handleLoadingFailed(Map<String, dynamic> params, List<Map<String, dynamic>> requests) {
    final requestId = params['requestId'];
    final errorText = params['errorText'];
    final canceled = params['canceled'] ?? false;
    
    final request = requests.firstWhere(
      (r) => r['requestId'] == requestId,
      orElse: () => <String, dynamic>{}
    );
    
    if (request.isNotEmpty) {
      request['failed'] = true;
      request['errorText'] = errorText;
      request['canceled'] = canceled;
    }
  }
  
  void _handleSecurityStateChanged(Map<String, dynamic> params, Map<String, dynamic> networkResults) {
    networkResults['securityState'] = params['securityState'];
    networkResults['certificateDetails'] = params['visibleSecurityState'];
  }
  
  Map<String, dynamic> _analyzeWaterfall(List<Map<String, dynamic>> requests, DateTime startTime) {
    final waterfall = <String, dynamic>{
      'totalTime': 0,
      'criticalPath': [],
      'parallelRequests': 0,
      'requestChains': []
    };
    
    if (requests.isEmpty) return waterfall;
    
    // Sort by timestamp
    requests.sort((a, b) => (a['timestamp'] as double).compareTo(b['timestamp'] as double));
    
    final firstTimestamp = requests.first['timestamp'] as double;
    final lastTimestamp = requests.last['timestamp'] as double;
    waterfall['totalTime'] = ((lastTimestamp - firstTimestamp) * 1000).round();
    
    // Identify critical path (main document and render-blocking resources)
    for (final request in requests) {
      final type = request['type'] as String;
      if (type == 'Document' || type == 'Stylesheet' || 
          (type == 'Script' && _isRenderBlocking(request))) {
        waterfall['criticalPath'].add({
          'url': request['url'],
          'type': type,
          'timestamp': request['timestamp']
        });
      }
    }
    
    // Count maximum parallel requests
    final activeRequests = <double>[];
    int maxParallel = 0;
    
    for (final request in requests) {
      final timestamp = request['timestamp'] as double;
      activeRequests.removeWhere((t) => t < timestamp - 1); // Remove completed
      activeRequests.add(timestamp);
      maxParallel = activeRequests.length > maxParallel ? activeRequests.length : maxParallel;
    }
    
    waterfall['parallelRequests'] = maxParallel;
    
    // Build request chains (initiator chains)
    waterfall['requestChains'] = _buildRequestChains(requests);
    
    return waterfall;
  }
  
  Map<String, dynamic> _analyzeThirdParty(List<Map<String, dynamic>> requests, Uri pageUrl) {
    final thirdParty = <String, dynamic>{
      'domains': {},
      'count': 0,
      'size': 0,
      'percentage': 0,
      'categories': {}
    };
    
    final pageDomain = pageUrl.host;
    int totalSize = 0;
    int firstPartySize = 0;
    
    for (final request in requests) {
      final requestUrl = Uri.tryParse(request['url'] as String);
      if (requestUrl == null) continue;
      
      final size = (request['encodedDataLength'] ?? 0) as int;
      totalSize += size;
      
      if (requestUrl.host != pageDomain && !requestUrl.host.endsWith('.$pageDomain')) {
        thirdParty['count']++;
        thirdParty['size'] += size;
        
        // Group by domain
        thirdParty['domains'][requestUrl.host] = 
          (thirdParty['domains'][requestUrl.host] ?? 0) + 1;
        
        // Categorize
        final category = _categorizeThirdParty(requestUrl.host);
        thirdParty['categories'][category] = 
          (thirdParty['categories'][category] ?? 0) + 1;
      } else {
        firstPartySize += size;
      }
    }
    
    if (totalSize > 0) {
      thirdParty['percentage'] = (thirdParty['size'] / totalSize * 100).round();
    }
    
    return thirdParty;
  }
  
  Map<String, dynamic> _detectCDN(List<Map<String, dynamic>> requests) {
    final cdn = <String, dynamic>{
      'used': false,
      'providers': <String>{},
      'resources': [],
      'count': 0
    };
    
    for (final request in requests) {
      final url = Uri.tryParse(request['url'] as String);
      if (url == null) continue;
      
      for (final cdnDomain in cdnDomains) {
        if (url.host.contains(cdnDomain)) {
          cdn['used'] = true;
          cdn['providers'].add(_getCDNProvider(cdnDomain));
          cdn['resources'].add({
            'url': request['url'],
            'cdn': _getCDNProvider(cdnDomain),
            'type': request['type']
          });
          cdn['count']++;
          break;
        }
      }
    }
    
    cdn['providers'] = (cdn['providers'] as Set).toList();
    
    return cdn;
  }
  
  Future<Map<String, dynamic>> _analyzeProtocols(
    List<Map<String, dynamic>> requests,
    Map<String, Map<String, dynamic>> responses
  ) async {
    final protocols = <String, dynamic>{
      'http1': 0,
      'http2': 0,
      'http3': 0,
      'mixed': false,
      'distribution': {}
    };
    
    final protocolCounts = <String, int>{};
    
    for (final request in requests) {
      final requestId = request['requestId'] as String;
      final response = responses[requestId];
      
      if (response != null) {
        final protocol = response['protocol'] ?? 'http/1.1';
        final normalizedProtocol = _normalizeProtocol(protocol);
        
        protocolCounts[normalizedProtocol] = 
          (protocolCounts[normalizedProtocol] ?? 0) + 1;
        
        if (normalizedProtocol.contains('h3') || normalizedProtocol.contains('quic')) {
          protocols['http3']++;
        } else if (normalizedProtocol.contains('h2')) {
          protocols['http2']++;
        } else {
          protocols['http1']++;
        }
      }
    }
    
    protocols['distribution'] = protocolCounts;
    protocols['mixed'] = protocolCounts.length > 1;
    
    // Check for HTTP/3 support
    protocols['http3Support'] = protocols['http3'] > 0;
    protocols['http2Support'] = protocols['http2'] > 0;
    
    return protocols;
  }
  
  Map<String, dynamic> _analyzeNetworkPerformance(
    List<Map<String, dynamic>> requests,
    Map<String, Map<String, dynamic>> responses,
    Map<String, Map<String, dynamic>> timings
  ) {
    final performance = <String, dynamic>{
      'totalRequests': requests.length,
      'totalSize': 0,
      'averageLatency': 0,
      'slowestRequests': [],
      'largestRequests': [],
      'failedRequests': 0,
      'cachedRequests': 0
    };
    
    int totalLatency = 0;
    int latencyCount = 0;
    
    for (final request in requests) {
      final requestId = request['requestId'] as String;
      final response = responses[requestId];
      final timing = timings[requestId];
      
      // Check if failed
      if (request['failed'] == true) {
        performance['failedRequests']++;
        continue;
      }
      
      // Calculate size
      final size = timing?['encodedDataLength'] ?? 
                   response?['encodedDataLength'] ?? 0;
      performance['totalSize'] += size;
      
      // Calculate latency
      if (response != null && response['timing'] != null) {
        final t = response['timing'];
        final latency = (t['receiveHeadersEnd'] ?? 0) - (t['requestTime'] ?? 0);
        if (latency > 0) {
          totalLatency += latency.round();
          latencyCount++;
        }
      }
      
      // Track large requests
      if (size > 100000) { // > 100KB
        performance['largestRequests'].add({
          'url': request['url'],
          'size': size,
          'type': request['type']
        });
      }
    }
    
    // Sort and limit largest requests
    (performance['largestRequests'] as List).sort((a, b) => 
      b['size'].compareTo(a['size']));
    performance['largestRequests'] = 
      (performance['largestRequests'] as List).take(10).toList();
    
    // Calculate average latency
    if (latencyCount > 0) {
      performance['averageLatency'] = (totalLatency / latencyCount).round();
    }
    
    return performance;
  }
  
  Map<String, dynamic> _identifyBlockingResources(List<Map<String, dynamic>> requests) {
    final blocking = <String, dynamic>{
      'renderBlocking': [],
      'parserBlocking': [],
      'count': 0
    };
    
    for (final request in requests) {
      if (_isRenderBlocking(request)) {
        blocking['renderBlocking'].add({
          'url': request['url'],
          'type': request['type']
        });
        blocking['count']++;
      }
      
      if (_isParserBlocking(request)) {
        blocking['parserBlocking'].add({
          'url': request['url'],
          'type': request['type']
        });
      }
    }
    
    return blocking;
  }
  
  Future<Map<String, dynamic>> _getNetworkTiming(Page page) async {
    return await page.evaluate('''() => {
      const timing = performance.timing;
      const navigation = performance.navigation;
      
      return {
        dns: timing.domainLookupEnd - timing.domainLookupStart,
        tcp: timing.connectEnd - timing.connectStart,
        ssl: timing.connectEnd - timing.secureConnectionStart,
        request: timing.responseStart - timing.requestStart,
        response: timing.responseEnd - timing.responseStart,
        domProcessing: timing.domComplete - timing.domLoading,
        domContentLoaded: timing.domContentLoadedEventEnd - timing.navigationStart,
        loadComplete: timing.loadEventEnd - timing.navigationStart,
        redirectCount: navigation.redirectCount
      };
    }''');
  }
  
  Future<Map<String, dynamic>> _getConnectionInfo(dynamic client) async {
    try {
      final info = await client.send('Network.getSecurityIsolationStatus');
      return info;
    } catch (e) {
      return {'error': e.toString()};
    }
  }
  
  Map<String, dynamic> _analyzeResourcePriorities(List<Map<String, dynamic>> requests) {
    final priorities = <String, dynamic>{
      'VeryHigh': 0,
      'High': 0,
      'Medium': 0,
      'Low': 0,
      'VeryLow': 0,
      'issues': []
    };
    
    for (final request in requests) {
      final priority = request['priority'] ?? 'Medium';
      priorities[priority] = (priorities[priority] ?? 0) + 1;
      
      // Check for potential priority issues
      final type = request['type'] as String;
      if (type == 'Image' && priority == 'High') {
        priorities['issues'].add('Image loaded with high priority: ${request['url']}');
      }
      if (type == 'Stylesheet' && priority != 'VeryHigh') {
        priorities['issues'].add('CSS not loaded with highest priority: ${request['url']}');
      }
    }
    
    return priorities;
  }
  
  List<Map<String, dynamic>> _convertHeaders(dynamic headers) {
    final result = <Map<String, dynamic>>[];
    if (headers is Map) {
      headers.forEach((name, value) {
        result.add({'name': name, 'value': value.toString()});
      });
    }
    return result;
  }
  
  List<Map<String, dynamic>> _parseQueryString(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return [];
    
    final result = <Map<String, dynamic>>[];
    uri.queryParameters.forEach((name, value) {
      result.add({'name': name, 'value': value});
    });
    return result;
  }
  
  bool _isRenderBlocking(Map<String, dynamic> request) {
    final type = request['type'] as String;
    
    if (type == 'Stylesheet') return true;
    
    if (type == 'Script') {
      final initiator = request['initiator'];
      if (initiator != null && initiator['type'] == 'parser') {
        // Script in head without async/defer
        return true;
      }
    }
    
    return false;
  }
  
  bool _isParserBlocking(Map<String, dynamic> request) {
    final type = request['type'] as String;
    if (type == 'Script') {
      final initiator = request['initiator'];
      if (initiator != null && initiator['type'] == 'parser') {
        return true;
      }
    }
    return false;
  }
  
  List<Map<String, dynamic>> _buildRequestChains(List<Map<String, dynamic>> requests) {
    // Simplified chain building - track initiator chains
    final chains = <Map<String, dynamic>>[];
    
    for (final request in requests) {
      if (request['type'] == 'Document') {
        chains.add({
          'root': request['url'],
          'length': 1,
          'children': _findChildren(request['url'], requests)
        });
      }
    }
    
    return chains;
  }
  
  List<String> _findChildren(String parentUrl, List<Map<String, dynamic>> requests) {
    final children = <String>[];
    
    for (final request in requests) {
      final initiator = request['initiator'];
      if (initiator != null && initiator['url'] == parentUrl) {
        children.add(request['url'] as String);
      }
    }
    
    return children;
  }
  
  String _categorizeThirdParty(String domain) {
    if (domain.contains('google') || domain.contains('youtube')) return 'Google';
    if (domain.contains('facebook') || domain.contains('instagram')) return 'Facebook';
    if (domain.contains('twitter')) return 'Twitter';
    if (domain.contains('amazon')) return 'Amazon';
    if (domain.contains('cloudflare')) return 'Cloudflare';
    if (domain.contains('cdn') || cdnDomains.any((cdn) => domain.contains(cdn))) return 'CDN';
    if (domain.contains('analytics')) return 'Analytics';
    if (domain.contains('ads') || domain.contains('doubleclick')) return 'Advertising';
    return 'Other';
  }
  
  String _getCDNProvider(String domain) {
    if (domain.contains('cloudflare')) return 'Cloudflare';
    if (domain.contains('amazon') || domain.contains('cloudfront')) return 'AWS CloudFront';
    if (domain.contains('akamai')) return 'Akamai';
    if (domain.contains('fastly')) return 'Fastly';
    if (domain.contains('stackpath')) return 'StackPath';
    if (domain.contains('bunny')) return 'BunnyCDN';
    if (domain.contains('jsdelivr')) return 'jsDelivr';
    if (domain.contains('unpkg')) return 'unpkg';
    if (domain.contains('azure')) return 'Azure CDN';
    if (domain.contains('maxcdn')) return 'MaxCDN';
    return domain;
  }
  
  String _normalizeProtocol(String protocol) {
    return protocol.toLowerCase()
      .replaceAll('/', '')
      .replaceAll('.', '');
  }
  
  Map<String, dynamic> _calculateScore(Map<String, dynamic> results) {
    int score = 100;
    final summary = <String, dynamic>{};
    
    // Protocol usage (20 points)
    if (results['protocols']['http3'] > 0) {
      summary['http3'] = true;
    } else if (results['protocols']['http2'] > 0) {
      summary['http2'] = true;
      score -= 5;
    } else {
      summary['http1'] = true;
      score -= 20;
    }
    
    // Performance (30 points)
    final perf = results['performance'];
    if (perf['failedRequests'] > 0) {
      score -= perf['failedRequests'] * 5;
      summary['hasFailedRequests'] = true;
    }
    
    if (perf['totalSize'] > 5000000) { // > 5MB
      score -= 15;
      summary['largePayload'] = true;
    } else if (perf['totalSize'] > 2000000) { // > 2MB
      score -= 7;
    }
    
    // Third-party (20 points)
    if (results['thirdParty']['percentage'] > 50) {
      score -= 20;
      summary['highThirdParty'] = true;
    } else if (results['thirdParty']['percentage'] > 30) {
      score -= 10;
    }
    
    // Blocking resources (15 points)
    if (results['blocking']['count'] > 5) {
      score -= 15;
      summary['manyBlockingResources'] = true;
    } else if (results['blocking']['count'] > 2) {
      score -= 7;
    }
    
    // CDN usage (15 points)
    if (results['cdn']['used']) {
      summary['usesCDN'] = true;
    } else {
      score -= 15;
    }
    
    score = score < 0 ? 0 : score;
    
    // Calculate grade
    String grade;
    if (score >= 90) grade = 'A';
    else if (score >= 80) grade = 'B';
    else if (score >= 70) grade = 'C';
    else if (score >= 60) grade = 'D';
    else grade = 'F';
    
    return {
      'score': score,
      'grade': grade,
      'summary': summary
    };
  }
  
  List<Map<String, dynamic>> _identifyIssues(Map<String, dynamic> results) {
    final issues = <Map<String, dynamic>>[];
    
    if (results['protocols']['http1'] > 0 && results['protocols']['http2'] == 0) {
      issues.add({
        'severity': 'high',
        'category': 'Protocol',
        'issue': 'No HTTP/2 support detected',
        'impact': 'Slower multiplexing and resource loading'
      });
    }
    
    if (results['performance']['failedRequests'] > 0) {
      issues.add({
        'severity': 'critical',
        'category': 'Reliability',
        'issue': '${results['performance']['failedRequests']} failed requests',
        'impact': 'Missing resources, broken functionality'
      });
    }
    
    if (results['thirdParty']['percentage'] > 50) {
      issues.add({
        'severity': 'high',
        'category': 'Third-party',
        'issue': 'Over ${results['thirdParty']['percentage']}% third-party resources',
        'impact': 'Performance depends on external services'
      });
    }
    
    if (results['blocking']['count'] > 5) {
      issues.add({
        'severity': 'high',
        'category': 'Performance',
        'issue': '${results['blocking']['count']} render-blocking resources',
        'impact': 'Delayed page rendering'
      });
    }
    
    if (!results['cdn']['used']) {
      issues.add({
        'severity': 'medium',
        'category': 'Performance',
        'issue': 'No CDN usage detected',
        'impact': 'Slower global resource delivery'
      });
    }
    
    return issues;
  }
  
  List<Map<String, dynamic>> _generateRecommendations(Map<String, dynamic> results) {
    final recommendations = <Map<String, dynamic>>[];
    
    if (results['protocols']['http1'] > 0 && results['protocols']['http2'] == 0) {
      recommendations.add({
        'priority': 'high',
        'category': 'Protocol',
        'recommendation': 'Enable HTTP/2',
        'benefit': 'Multiplexing, header compression, server push'
      });
    }
    
    if (results['protocols']['http3Support'] != true) {
      recommendations.add({
        'priority': 'low',
        'category': 'Protocol',
        'recommendation': 'Consider HTTP/3 (QUIC)',
        'benefit': 'Faster connection establishment, better packet loss handling'
      });
    }
    
    if (results['blocking']['count'] > 2) {
      recommendations.add({
        'priority': 'high',
        'category': 'Performance',
        'recommendation': 'Reduce render-blocking resources',
        'implementation': 'Inline critical CSS, defer non-critical JavaScript'
      });
    }
    
    if (!results['cdn']['used']) {
      recommendations.add({
        'priority': 'medium',
        'category': 'Performance',
        'recommendation': 'Use a CDN for static assets',
        'benefit': 'Faster global delivery, reduced server load'
      });
    }
    
    if (results['thirdParty']['percentage'] > 30) {
      recommendations.add({
        'priority': 'medium',
        'category': 'Optimization',
        'recommendation': 'Reduce third-party dependencies',
        'implementation': 'Self-host critical resources, lazy-load non-critical'
      });
    }
    
    return recommendations;
  }
}

// Extension for AuditContext
extension NetworkExtendedContext on AuditContext {
  static final _networkExtended = Expando<Map<String, dynamic>>();
  
  Map<String, dynamic>? get networkExtended => _networkExtended[this];
  set networkExtended(Map<String, dynamic>? value) => _networkExtended[this] = value;
}