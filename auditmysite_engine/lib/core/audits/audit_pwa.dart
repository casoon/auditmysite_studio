import 'dart:convert';
import 'package:puppeteer/puppeteer.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'audit_base.dart';

/// Progressive Web App (PWA) Audit
class PWAAudit implements Audit {
  @override
  String get name => 'pwa';
  
  final Logger _logger = Logger('PWAAudit');

  @override
  Future<void> run(AuditContext ctx) async {
    final page = ctx.page as Page;
    final url = ctx.url.toString();
    
    final pwaResults = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'url': url,
      'manifest': {},
      'serviceWorker': {},
      'installability': {},
      'capabilities': {},
      'score': 0,
      'issues': [],
      'recommendations': [],
      'isPWA': false
    };
    
    try {
      // 1. Check Web App Manifest
      pwaResults['manifest'] = await _checkManifest(page, ctx.url);
      
      // 2. Check Service Worker
      pwaResults['serviceWorker'] = await _checkServiceWorker(page);
      
      // 3. Check HTTPS
      pwaResults['https'] = _checkHTTPS(url);
      
      // 4. Check Installability Criteria
      pwaResults['installability'] = await _checkInstallability(page, pwaResults);
      
      // 5. Check App Capabilities
      pwaResults['capabilities'] = await _checkCapabilities(page);
      
      // 6. Check Offline Support
      pwaResults['offline'] = await _checkOfflineSupport(page);
      
      // 7. Check Push Notifications
      pwaResults['pushNotifications'] = await _checkPushNotifications(page);
      
      // 8. Check App-like Features
      pwaResults['appFeatures'] = await _checkAppFeatures(page);
      
      // 9. Check Icons
      pwaResults['icons'] = await _checkIcons(pwaResults['manifest']);
      
      // 10. Check Splash Screen
      pwaResults['splashScreen'] = _checkSplashScreen(pwaResults['manifest']);
      
      // 11. Check Viewport Meta
      pwaResults['viewport'] = await _checkViewport(page);
      
      // 12. Check Mobile Friendliness
      pwaResults['mobileFriendly'] = await _checkMobileFriendly(page);
      
      // 13. Check Loading Performance
      pwaResults['performance'] = await _checkPerformance(ctx);
      
      // 14. Check App Shell Architecture
      pwaResults['appShell'] = await _checkAppShell(page);
      
      // 15. Check Web Share API
      pwaResults['webShare'] = await _checkWebShareAPI(page);
      
      // Calculate score and determine if it's a PWA
      final scoring = _calculateScore(pwaResults);
      pwaResults['score'] = scoring['score'];
      pwaResults['isPWA'] = scoring['isPWA'];
      pwaResults['grade'] = scoring['grade'];
      pwaResults['summary'] = scoring['summary'];
      
      // Identify issues
      pwaResults['issues'] = _identifyIssues(pwaResults);
      
      // Generate recommendations
      pwaResults['recommendations'] = _generateRecommendations(pwaResults);
      
      // Store in context
      ctx.pwa = pwaResults;
      
    } catch (e) {
      _logger.severe('Error in PWA audit: $e');
      pwaResults['error'] = e.toString();
      ctx.pwa = pwaResults;
    }
  }
  
  Future<Map<String, dynamic>> _checkManifest(Page page, Uri pageUrl) async {
    final manifest = <String, dynamic>{
      'found': false,
      'url': '',
      'content': {},
      'valid': false,
      'errors': [],
      'warnings': []
    };
    
    try {
      // Check for manifest link in HTML
      final manifestUrl = await page.evaluate('''() => {
        const link = document.querySelector('link[rel="manifest"]');
        return link ? link.href : null;
      }''');
      
      if (manifestUrl != null && manifestUrl != '') {
        manifest['found'] = true;
        manifest['url'] = manifestUrl;
        
        // Fetch and parse manifest
        final response = await http.get(Uri.parse(manifestUrl as String))
            .timeout(Duration(seconds: 10));
        
        if (response.statusCode == 200) {
          try {
            manifest['content'] = json.decode(response.body);
            manifest['valid'] = true;
            
            // Validate manifest properties
            final content = manifest['content'] as Map;
            
            // Required fields
            if (!content.containsKey('name') && !content.containsKey('short_name')) {
              manifest['errors'].add('Missing name or short_name');
            }
            
            if (!content.containsKey('icons') || (content['icons'] as List).isEmpty) {
              manifest['errors'].add('Missing icons');
            }
            
            if (!content.containsKey('start_url')) {
              manifest['errors'].add('Missing start_url');
            }
            
            if (!content.containsKey('display')) {
              manifest['warnings'].add('Missing display mode');
            }
            
            // Check display mode
            if (content.containsKey('display')) {
              final display = content['display'];
              if (!['fullscreen', 'standalone', 'minimal-ui', 'browser'].contains(display)) {
                manifest['errors'].add('Invalid display mode: $display');
              }
            }
            
            // Check theme and background colors
            if (!content.containsKey('theme_color')) {
              manifest['warnings'].add('Missing theme_color');
            }
            
            if (!content.containsKey('background_color')) {
              manifest['warnings'].add('Missing background_color');
            }
            
            // Check orientation
            if (content.containsKey('orientation')) {
              final orientation = content['orientation'];
              final validOrientations = [
                'any', 'natural', 'landscape', 'portrait',
                'portrait-primary', 'portrait-secondary',
                'landscape-primary', 'landscape-secondary'
              ];
              if (!validOrientations.contains(orientation)) {
                manifest['errors'].add('Invalid orientation: $orientation');
              }
            }
            
            // Check scope
            if (content.containsKey('scope')) {
              final scope = content['scope'];
              final startUrl = content['start_url'] ?? '/';
              if (!startUrl.toString().startsWith(scope.toString())) {
                manifest['warnings'].add('start_url is not within scope');
              }
            }
            
            // Check for advanced features
            manifest['features'] = {
              'shortcuts': content.containsKey('shortcuts'),
              'screenshots': content.containsKey('screenshots'),
              'categories': content.containsKey('categories'),
              'iarc_rating_id': content.containsKey('iarc_rating_id'),
              'related_applications': content.containsKey('related_applications'),
              'prefer_related_applications': content['prefer_related_applications'] ?? false,
              'file_handlers': content.containsKey('file_handlers'),
              'protocol_handlers': content.containsKey('protocol_handlers'),
              'share_target': content.containsKey('share_target')
            };
            
          } catch (e) {
            manifest['valid'] = false;
            manifest['errors'].add('Invalid JSON: $e');
          }
        } else {
          manifest['errors'].add('Failed to fetch manifest: HTTP ${response.statusCode}');
        }
      } else {
        manifest['errors'].add('No manifest link found in HTML');
      }
    } catch (e) {
      _logger.warning('Error checking manifest: $e');
      manifest['errors'].add('Error checking manifest: $e');
    }
    
    return manifest;
  }
  
  Future<Map<String, dynamic>> _checkServiceWorker(Page page) async {
    final sw = <String, dynamic>{
      'registered': false,
      'active': false,
      'scope': '',
      'scriptURL': '',
      'updateViaCache': '',
      'navigationPreload': false,
      'backgroundSync': false,
      'periodicSync': false,
      'pushManager': false
    };
    
    try {
      final result = await page.evaluate('''async () => {
        if (!('serviceWorker' in navigator)) {
          return { supported: false };
        }
        
        const registrations = await navigator.serviceWorker.getRegistrations();
        if (registrations.length === 0) {
          return { supported: true, registered: false };
        }
        
        const reg = registrations[0];
        const sw = reg.active || reg.waiting || reg.installing;
        
        const result = {
          supported: true,
          registered: true,
          active: reg.active !== null,
          scope: reg.scope,
          scriptURL: sw ? sw.scriptURL : '',
          updateViaCache: reg.updateViaCache || 'imports'
        };
        
        // Check for advanced features
        if (reg.navigationPreload) {
          try {
            const state = await reg.navigationPreload.getState();
            result.navigationPreload = state.enabled;
          } catch (e) {
            result.navigationPreload = false;
          }
        }
        
        // Check for background sync
        if ('sync' in reg) {
          result.backgroundSync = true;
        }
        
        // Check for periodic background sync
        if ('periodicSync' in reg) {
          result.periodicSync = true;
        }
        
        // Check for push notifications
        if (reg.pushManager) {
          result.pushManager = true;
          try {
            const subscription = await reg.pushManager.getSubscription();
            result.pushSubscription = subscription !== null;
          } catch (e) {
            result.pushSubscription = false;
          }
        }
        
        return result;
      }''');
      
      if (result != null && result is Map) {
        sw.addAll(result);
      }
    } catch (e) {
      _logger.warning('Error checking service worker: $e');
    }
    
    return sw;
  }
  
  bool _checkHTTPS(String url) {
    return url.startsWith('https://') || url.startsWith('http://localhost');
  }
  
  Future<Map<String, dynamic>> _checkInstallability(Page page, Map<String, dynamic> pwaResults) async {
    final installability = <String, dynamic>{
      'meetsCriteria': false,
      'criteria': {},
      'missingRequirements': []
    };
    
    // Check Chrome's installability criteria
    installability['criteria'] = {
      'https': pwaResults['https'] ?? false,
      'manifest': pwaResults['manifest']['found'] ?? false,
      'serviceWorker': pwaResults['serviceWorker']['registered'] ?? false,
      'icons': false,
      'name': false,
      'startUrl': false,
      'display': false,
      'preferRelatedApps': false
    };
    
    // Check manifest requirements
    if (pwaResults['manifest']['content'] != null && pwaResults['manifest']['content'] is Map) {
      final manifest = pwaResults['manifest']['content'] as Map;
      
      // Name or short_name
      installability['criteria']['name'] = 
          manifest.containsKey('name') || manifest.containsKey('short_name');
      
      // Start URL
      installability['criteria']['startUrl'] = manifest.containsKey('start_url');
      
      // Display mode
      if (manifest.containsKey('display')) {
        final display = manifest['display'];
        installability['criteria']['display'] = 
            display == 'standalone' || display == 'fullscreen' || display == 'minimal-ui';
      }
      
      // Icons (need at least one 192x192 and one 512x512)
      if (manifest.containsKey('icons') && manifest['icons'] is List) {
        final icons = manifest['icons'] as List;
        bool has192 = false;
        bool has512 = false;
        
        for (final icon in icons) {
          if (icon is Map && icon.containsKey('sizes')) {
            final sizes = icon['sizes'].toString();
            if (sizes.contains('192x192')) has192 = true;
            if (sizes.contains('512x512')) has512 = true;
          }
        }
        
        installability['criteria']['icons'] = has192 && has512;
      }
      
      // Prefer related apps
      installability['criteria']['preferRelatedApps'] = 
          !(manifest['prefer_related_applications'] ?? false);
    }
    
    // Check if meets all criteria
    bool meetsCriteria = true;
    installability['criteria'].forEach((key, value) {
      if (key != 'preferRelatedApps' && value == false) {
        meetsCriteria = false;
        installability['missingRequirements'].add(key);
      }
    });
    
    // Special check for prefer_related_applications
    if (installability['criteria']['preferRelatedApps'] == false) {
      installability['missingRequirements'].add('prefer_related_applications is set to true');
    }
    
    installability['meetsCriteria'] = meetsCriteria;
    
    // Check for install prompt support
    try {
      installability['beforeInstallPromptSupported'] = await page.evaluate('''() => {
        return 'BeforeInstallPromptEvent' in window;
      }''');
    } catch (e) {
      installability['beforeInstallPromptSupported'] = false;
    }
    
    return installability;
  }
  
  Future<Map<String, dynamic>> _checkCapabilities(Page page) async {
    final capabilities = <String, dynamic>{};
    
    try {
      final result = await page.evaluate('''() => {
        const caps = {};
        
        // Check for various APIs
        caps.notifications = 'Notification' in window;
        caps.pushAPI = 'PushManager' in window;
        caps.backgroundSync = 'SyncManager' in window;
        caps.periodicBackgroundSync = 'PeriodicSyncManager' in window;
        caps.backgroundFetch = 'BackgroundFetchManager' in window;
        caps.paymentRequest = 'PaymentRequest' in window;
        caps.credentials = 'CredentialsContainer' in window;
        caps.webShare = 'share' in navigator;
        caps.webShareTarget = false; // Checked via manifest
        caps.fileAPI = 'showOpenFilePicker' in window;
        caps.contactPicker = 'ContactsManager' in window;
        caps.getInstalledRelatedApps = 'getInstalledRelatedApps' in navigator;
        caps.contentIndexing = 'ContentIndex' in window;
        caps.screenWakeLock = 'wakeLock' in navigator;
        caps.idleDetection = 'IdleDetector' in window;
        caps.fileSystemAccess = 'showOpenFilePicker' in window;
        caps.badging = 'setAppBadge' in navigator || 'setClientBadge' in navigator;
        caps.windowControls = 'windowControlsOverlay' in navigator;
        caps.displayMode = 'standalone' in window.matchMedia('(display-mode: standalone)');
        
        // Check for device APIs
        caps.geolocation = 'geolocation' in navigator;
        caps.deviceOrientation = 'DeviceOrientationEvent' in window;
        caps.deviceMotion = 'DeviceMotionEvent' in window;
        caps.vibration = 'vibrate' in navigator;
        caps.battery = 'getBattery' in navigator;
        caps.networkInformation = 'connection' in navigator;
        caps.bluetooth = 'bluetooth' in navigator;
        caps.usb = 'usb' in navigator;
        caps.nfc = 'NDEFReader' in window;
        caps.serial = 'serial' in navigator;
        caps.hid = 'hid' in navigator;
        
        // Media capabilities
        caps.mediaDevices = 'mediaDevices' in navigator;
        caps.getUserMedia = navigator.mediaDevices && 'getUserMedia' in navigator.mediaDevices;
        caps.audioContext = 'AudioContext' in window || 'webkitAudioContext' in window;
        caps.webRTC = 'RTCPeerConnection' in window;
        caps.pictureInPicture = 'pictureInPictureEnabled' in document;
        caps.mediaSession = 'mediaSession' in navigator;
        
        // Storage APIs
        caps.localStorage = 'localStorage' in window;
        caps.sessionStorage = 'sessionStorage' in window;
        caps.indexedDB = 'indexedDB' in window;
        caps.cacheAPI = 'caches' in window;
        caps.storageManager = 'storage' in navigator && 'estimate' in navigator.storage;
        
        return caps;
      }''');
      
      capabilities.addAll(result as Map);
      
      // Count available capabilities
      int availableCount = 0;
      capabilities.forEach((key, value) {
        if (value == true) availableCount++;
      });
      capabilities['availableCount'] = availableCount;
      capabilities['totalCount'] = capabilities.length - 1; // Exclude availableCount
      
    } catch (e) {
      _logger.warning('Error checking capabilities: $e');
    }
    
    return capabilities;
  }
  
  Future<Map<String, dynamic>> _checkOfflineSupport(Page page) async {
    final offline = <String, dynamic>{
      'hasOfflinePage': false,
      'cacheStrategy': 'none',
      'cachedResources': []
    };
    
    try {
      // Check if service worker implements offline support
      final result = await page.evaluate('''async () => {
        if (!('caches' in window)) {
          return { supported: false };
        }
        
        const cacheNames = await caches.keys();
        const cachedUrls = [];
        
        for (const cacheName of cacheNames) {
          const cache = await caches.open(cacheName);
          const requests = await cache.keys();
          for (const request of requests) {
            cachedUrls.push(request.url);
          }
        }
        
        return {
          supported: true,
          cacheNames: cacheNames,
          cachedUrls: cachedUrls,
          cacheCount: cachedUrls.length
        };
      }''');
      
      if (result != null && result is Map) {
        offline['cacheAPI'] = result;
        
        // Determine cache strategy based on cached resources
        if ((result['cacheCount'] ?? 0) > 0) {
          offline['hasOfflinePage'] = true;
          
          // Simple heuristic for cache strategy
          if ((result['cacheCount'] ?? 0) > 20) {
            offline['cacheStrategy'] = 'comprehensive';
          } else if ((result['cacheCount'] ?? 0) > 5) {
            offline['cacheStrategy'] = 'basic';
          } else {
            offline['cacheStrategy'] = 'minimal';
          }
        }
      }
    } catch (e) {
      _logger.warning('Error checking offline support: $e');
    }
    
    return offline;
  }
  
  Future<Map<String, dynamic>> _checkPushNotifications(Page page) async {
    final push = <String, dynamic>{
      'supported': false,
      'permission': 'default',
      'subscribed': false
    };
    
    try {
      final result = await page.evaluate('''async () => {
        if (!('Notification' in window)) {
          return { supported: false };
        }
        
        const permission = Notification.permission;
        
        let subscribed = false;
        if ('serviceWorker' in navigator && 'PushManager' in window) {
          try {
            const reg = await navigator.serviceWorker.ready;
            const subscription = await reg.pushManager.getSubscription();
            subscribed = subscription !== null;
          } catch (e) {
            // Silent fail
          }
        }
        
        return {
          supported: true,
          permission: permission,
          subscribed: subscribed,
          pushAPISupported: 'PushManager' in window
        };
      }''');
      
      if (result != null && result is Map) {
        push.addAll(result);
      }
    } catch (e) {
      _logger.warning('Error checking push notifications: $e');
    }
    
    return push;
  }
  
  Future<Map<String, dynamic>> _checkAppFeatures(Page page) async {
    final features = <String, dynamic>{};
    
    try {
      final result = await page.evaluate('''() => {
        const features = {};
        
        // Check if running in standalone mode
        features.isStandalone = window.matchMedia('(display-mode: standalone)').matches ||
                               window.navigator.standalone === true;
        
        // Check for app-like meta tags
        const metas = {};
        document.querySelectorAll('meta').forEach(meta => {
          const name = meta.getAttribute('name');
          const content = meta.getAttribute('content');
          if (name && content) {
            if (name === 'apple-mobile-web-app-capable') {
              metas.appleMobileWebAppCapable = content;
            } else if (name === 'apple-mobile-web-app-status-bar-style') {
              metas.appleStatusBarStyle = content;
            } else if (name === 'mobile-web-app-capable') {
              metas.mobileWebAppCapable = content;
            } else if (name === 'apple-mobile-web-app-title') {
              metas.appleTitle = content;
            } else if (name === 'application-name') {
              metas.applicationName = content;
            } else if (name === 'msapplication-TileColor') {
              metas.msTileColor = content;
            } else if (name === 'msapplication-TileImage') {
              metas.msTileImage = content;
            }
          }
        });
        features.metaTags = metas;
        
        // Check for apple touch icons
        const touchIcons = [];
        document.querySelectorAll('link[rel*="apple-touch-icon"]').forEach(link => {
          touchIcons.push({
            href: link.href,
            sizes: link.getAttribute('sizes')
          });
        });
        features.appleTouchIcons = touchIcons;
        
        // Check for splash screens (apple)
        const splashScreens = [];
        document.querySelectorAll('link[rel="apple-touch-startup-image"]').forEach(link => {
          splashScreens.push({
            href: link.href,
            media: link.getAttribute('media')
          });
        });
        features.appleSplashScreens = splashScreens;
        
        return features;
      }''');
      
      features.addAll(result as Map);
    } catch (e) {
      _logger.warning('Error checking app features: $e');
    }
    
    return features;
  }
  
  Future<Map<String, dynamic>> _checkIcons(Map<String, dynamic> manifest) async {
    final icons = <String, dynamic>{
      'hasIcons': false,
      'sizes': [],
      'purposes': [],
      'types': [],
      'issues': []
    };
    
    if (manifest['content'] != null && manifest['content'] is Map) {
      final content = manifest['content'] as Map;
      
      if (content.containsKey('icons') && content['icons'] is List) {
        final iconsList = content['icons'] as List;
        icons['hasIcons'] = iconsList.isNotEmpty;
        
        final sizes = <String>{};
        final purposes = <String>{};
        final types = <String>{};
        
        bool has192 = false;
        bool has512 = false;
        bool hasMaskable = false;
        
        for (final icon in iconsList) {
          if (icon is Map) {
            // Sizes
            if (icon.containsKey('sizes')) {
              final iconSizes = icon['sizes'].toString().split(' ');
              sizes.addAll(iconSizes);
              
              if (iconSizes.contains('192x192')) has192 = true;
              if (iconSizes.contains('512x512')) has512 = true;
            }
            
            // Purpose
            if (icon.containsKey('purpose')) {
              final iconPurposes = icon['purpose'].toString().split(' ');
              purposes.addAll(iconPurposes);
              
              if (iconPurposes.contains('maskable')) hasMaskable = true;
            }
            
            // Type
            if (icon.containsKey('type')) {
              types.add(icon['type']);
            }
          }
        }
        
        icons['sizes'] = sizes.toList();
        icons['purposes'] = purposes.toList();
        icons['types'] = types.toList();
        
        // Check for issues
        if (!has192) {
          icons['issues'].add('Missing 192x192 icon');
        }
        
        if (!has512) {
          icons['issues'].add('Missing 512x512 icon');
        }
        
        if (!hasMaskable) {
          icons['issues'].add('No maskable icon for adaptive icon support');
        }
        
        // Check for recommended sizes
        final recommendedSizes = [
          '72x72', '96x96', '128x128', '144x144', '152x152',
          '192x192', '384x384', '512x512'
        ];
        
        for (final size in recommendedSizes) {
          if (!sizes.contains(size)) {
            icons['issues'].add('Missing recommended size: $size');
          }
        }
      } else {
        icons['issues'].add('No icons defined in manifest');
      }
    }
    
    return icons;
  }
  
  Map<String, dynamic> _checkSplashScreen(Map<String, dynamic> manifest) {
    final splash = <String, dynamic>{
      'configured': false,
      'hasName': false,
      'hasBackgroundColor': false,
      'hasThemeColor': false,
      'hasIcon': false
    };
    
    if (manifest['content'] != null && manifest['content'] is Map) {
      final content = manifest['content'] as Map;
      
      // Chrome generates splash screen from these manifest properties
      splash['hasName'] = content.containsKey('name') || content.containsKey('short_name');
      splash['hasBackgroundColor'] = content.containsKey('background_color');
      splash['hasThemeColor'] = content.containsKey('theme_color');
      
      // Need at least one 512x512 icon for splash screen
      if (content.containsKey('icons') && content['icons'] is List) {
        final iconsList = content['icons'] as List;
        for (final icon in iconsList) {
          if (icon is Map && icon.containsKey('sizes')) {
            if (icon['sizes'].toString().contains('512x512')) {
              splash['hasIcon'] = true;
              break;
            }
          }
        }
      }
      
      splash['configured'] = splash['hasName'] && 
                            splash['hasBackgroundColor'] && 
                            splash['hasIcon'];
    }
    
    return splash;
  }
  
  Future<Map<String, dynamic>> _checkViewport(Page page) async {
    final viewport = <String, dynamic>{
      'hasViewportMeta': false,
      'content': '',
      'isResponsive': false,
      'issues': []
    };
    
    try {
      final result = await page.evaluate('''() => {
        const meta = document.querySelector('meta[name="viewport"]');
        if (!meta) {
          return { hasViewportMeta: false };
        }
        
        const content = meta.getAttribute('content') || '';
        const params = {};
        
        // Parse viewport content
        content.split(',').forEach(param => {
          const [key, value] = param.trim().split('=');
          if (key && value) {
            params[key] = value;
          }
        });
        
        return {
          hasViewportMeta: true,
          content: content,
          params: params
        };
      }''');
      
      if (result != null && result is Map) {
        viewport['hasViewportMeta'] = result['hasViewportMeta'];
        viewport['content'] = result['content'] ?? '';
        
        if (result['params'] != null && result['params'] is Map) {
          final params = result['params'] as Map;
          
          // Check if responsive
          viewport['isResponsive'] = params['width'] == 'device-width' &&
                                    (params['initial-scale'] == '1' || 
                                     params['initial-scale'] == '1.0');
          
          // Check for issues
          if (params['maximum-scale'] == '1' || params['user-scalable'] == 'no') {
            viewport['issues'].add('Viewport prevents user scaling');
          }
          
          if (params['width'] != 'device-width') {
            viewport['issues'].add('Width not set to device-width');
          }
        }
      }
    } catch (e) {
      _logger.warning('Error checking viewport: $e');
    }
    
    return viewport;
  }
  
  Future<Map<String, dynamic>> _checkMobileFriendly(Page page) async {
    final mobile = <String, dynamic>{
      'tapTargetSize': true,
      'textReadability': true,
      'contentWidth': true,
      'issues': []
    };
    
    try {
      final result = await page.evaluate('''() => {
        const issues = [];
        
        // Check tap target sizes (minimum 48x48px)
        const interactiveElements = document.querySelectorAll('a, button, input, select, textarea');
        let smallTargets = 0;
        interactiveElements.forEach(el => {
          const rect = el.getBoundingClientRect();
          if (rect.width < 48 || rect.height < 48) {
            smallTargets++;
          }
        });
        
        if (smallTargets > 0) {
          issues.push('${smallTargets} tap targets are smaller than 48x48px');
        }
        
        // Check text readability (minimum 12px)
        const allElements = document.querySelectorAll('*');
        let smallText = 0;
        allElements.forEach(el => {
          const fontSize = window.getComputedStyle(el).fontSize;
          if (fontSize && parseFloat(fontSize) < 12) {
            smallText++;
          }
        });
        
        if (smallText > 0) {
          issues.push('${smallText} elements have font size smaller than 12px');
        }
        
        // Check content width
        const contentWidth = document.documentElement.scrollWidth;
        const viewportWidth = window.innerWidth;
        
        if (contentWidth > viewportWidth) {
          issues.push('Content is wider than viewport');
        }
        
        return {
          smallTargets: smallTargets,
          smallText: smallText,
          contentWider: contentWidth > viewportWidth,
          issues: issues
        };
      }''');
      
      if (result != null && result is Map) {
        mobile['tapTargetSize'] = (result['smallTargets'] ?? 0) == 0;
        mobile['textReadability'] = (result['smallText'] ?? 0) == 0;
        mobile['contentWidth'] = !(result['contentWider'] ?? false);
        mobile['issues'] = result['issues'] ?? [];
      }
    } catch (e) {
      _logger.warning('Error checking mobile friendliness: $e');
    }
    
    return mobile;
  }
  
  Future<Map<String, dynamic>> _checkPerformance(AuditContext ctx) async {
    final performance = <String, dynamic>{
      'fastLoading': false,
      'metrics': {}
    };
    
    // Get performance metrics from context if available
    if (ctx.performanceMetrics != null) {
      final metrics = ctx.performanceMetrics!;
      
      // Check if fast enough for PWA (FCP < 2s, TTI < 5s)
      final fcp = metrics['firstContentfulPaint'] ?? 0;
      final tti = metrics['timeToInteractive'] ?? 0;
      
      performance['fastLoading'] = fcp < 2000 && tti < 5000;
      performance['metrics'] = {
        'fcp': fcp,
        'tti': tti,
        'fcpFast': fcp < 2000,
        'ttiFast': tti < 5000
      };
    }
    
    return performance;
  }
  
  Future<Map<String, dynamic>> _checkAppShell(Page page) async {
    final appShell = <String, dynamic>{
      'hasAppShell': false,
      'shellElements': []
    };
    
    try {
      // Check for common app shell patterns
      final result = await page.evaluate('''() => {
        const shellElements = [];
        
        // Check for common app shell elements
        if (document.querySelector('header, [role="banner"]')) {
          shellElements.push('header');
        }
        
        if (document.querySelector('nav, [role="navigation"]')) {
          shellElements.push('navigation');
        }
        
        if (document.querySelector('main, [role="main"], #app, #root, .app-container')) {
          shellElements.push('main-content');
        }
        
        if (document.querySelector('footer, [role="contentinfo"]')) {
          shellElements.push('footer');
        }
        
        // Check for loading indicators
        if (document.querySelector('.loader, .spinner, .loading, .skeleton')) {
          shellElements.push('loading-indicator');
        }
        
        return {
          hasShellElements: shellElements.length >= 2,
          shellElements: shellElements
        };
      }''');
      
      if (result != null && result is Map) {
        appShell['hasAppShell'] = result['hasShellElements'] ?? false;
        appShell['shellElements'] = result['shellElements'] ?? [];
      }
    } catch (e) {
      _logger.warning('Error checking app shell: $e');
    }
    
    return appShell;
  }
  
  Future<Map<String, dynamic>> _checkWebShareAPI(Page page) async {
    final webShare = <String, dynamic>{
      'supported': false,
      'canShare': false,
      'shareTarget': false
    };
    
    try {
      final result = await page.evaluate('''() => {
        const share = {
          supported: 'share' in navigator,
          canShare: false
        };
        
        if (share.supported) {
          // Check if can share basic data
          if ('canShare' in navigator) {
            try {
              share.canShare = navigator.canShare({ 
                title: 'Test', 
                text: 'Test', 
                url: window.location.href 
              });
            } catch (e) {
              share.canShare = false;
            }
          } else {
            // Older API without canShare method
            share.canShare = true;
          }
        }
        
        return share;
      }''');
      
      webShare['supported'] = result['supported'] ?? false;
      webShare['canShare'] = result['canShare'] ?? false;
      
      // Check for share target in manifest
      if (pwaResults['manifest']['content'] != null) {
        final manifest = pwaResults['manifest']['content'] as Map;
        webShare['shareTarget'] = manifest.containsKey('share_target');
      }
    } catch (e) {
      _logger.warning('Error checking Web Share API: $e');
    }
    
    return webShare;
  }
  
  Map<String, dynamic> _calculateScore(Map<String, dynamic> results) {
    int score = 0;
    final summary = <String, dynamic>{};
    
    // Core PWA requirements (60 points total)
    
    // HTTPS (15 points)
    if (results['https'] == true) {
      score += 15;
      summary['https'] = true;
    }
    
    // Valid manifest (15 points)
    if (results['manifest']['valid'] == true) {
      score += 10;
      if (results['manifest']['errors'].isEmpty) {
        score += 5;
      }
      summary['manifest'] = true;
    }
    
    // Service worker (15 points)
    if (results['serviceWorker']['registered'] == true) {
      score += 10;
      if (results['serviceWorker']['active'] == true) {
        score += 5;
      }
      summary['serviceWorker'] = true;
    }
    
    // Installability (15 points)
    if (results['installability']['meetsCriteria'] == true) {
      score += 15;
      summary['installable'] = true;
    }
    
    // Additional PWA features (40 points total)
    
    // Offline support (10 points)
    if (results['offline']['hasOfflinePage'] == true) {
      score += 5;
      if (results['offline']['cacheStrategy'] == 'comprehensive') {
        score += 5;
      }
      summary['offline'] = true;
    }
    
    // Icons (5 points)
    if (results['icons']['hasIcons'] == true && results['icons']['issues'].length < 3) {
      score += 5;
      summary['icons'] = true;
    }
    
    // Splash screen (5 points)
    if (results['splashScreen']['configured'] == true) {
      score += 5;
      summary['splashScreen'] = true;
    }
    
    // Viewport (5 points)
    if (results['viewport']['isResponsive'] == true) {
      score += 5;
      summary['viewport'] = true;
    }
    
    // Mobile friendly (5 points)
    if (results['mobileFriendly']['tapTargetSize'] == true &&
        results['mobileFriendly']['textReadability'] == true &&
        results['mobileFriendly']['contentWidth'] == true) {
      score += 5;
      summary['mobileFriendly'] = true;
    }
    
    // Performance (5 points)
    if (results['performance']['fastLoading'] == true) {
      score += 5;
      summary['performance'] = true;
    }
    
    // App shell (5 points)
    if (results['appShell']['hasAppShell'] == true) {
      score += 5;
      summary['appShell'] = true;
    }
    
    // Calculate grade
    String grade;
    if (score >= 90) {
      grade = 'A+';
    } else if (score >= 80) {
      grade = 'A';
    } else if (score >= 70) {
      grade = 'B';
    } else if (score >= 60) {
      grade = 'C';
    } else if (score >= 50) {
      grade = 'D';
    } else {
      grade = 'F';
    }
    
    // Determine if it's a PWA (meets minimum criteria)
    final isPWA = results['https'] == true &&
                  results['manifest']['valid'] == true &&
                  results['serviceWorker']['registered'] == true &&
                  results['installability']['meetsCriteria'] == true;
    
    return {
      'score': score,
      'grade': grade,
      'isPWA': isPWA,
      'summary': summary
    };
  }
  
  List<Map<String, dynamic>> _identifyIssues(Map<String, dynamic> results) {
    final issues = <Map<String, dynamic>>[];
    
    // Critical issues
    if (results['https'] != true) {
      issues.add({
        'severity': 'critical',
        'category': 'Security',
        'issue': 'Not served over HTTPS',
        'impact': 'PWAs require HTTPS for security and many APIs'
      });
    }
    
    if (results['manifest']['found'] != true) {
      issues.add({
        'severity': 'critical',
        'category': 'Manifest',
        'issue': 'No web app manifest found',
        'impact': 'Required for installation and app-like experience'
      });
    }
    
    if (results['serviceWorker']['registered'] != true) {
      issues.add({
        'severity': 'critical',
        'category': 'Service Worker',
        'issue': 'No service worker registered',
        'impact': 'Required for offline functionality and advanced features'
      });
    }
    
    // High priority issues
    if (results['installability']['meetsCriteria'] != true) {
      issues.add({
        'severity': 'high',
        'category': 'Installability',
        'issue': 'Does not meet installability criteria',
        'missingRequirements': results['installability']['missingRequirements']
      });
    }
    
    if (results['offline']['hasOfflinePage'] != true) {
      issues.add({
        'severity': 'high',
        'category': 'Offline',
        'issue': 'No offline support',
        'impact': 'Users cannot access app without network connection'
      });
    }
    
    // Medium priority issues
    if (results['icons']['issues'].length > 0) {
      issues.add({
        'severity': 'medium',
        'category': 'Icons',
        'issue': 'Icon configuration issues',
        'details': results['icons']['issues']
      });
    }
    
    if (results['viewport']['isResponsive'] != true) {
      issues.add({
        'severity': 'medium',
        'category': 'Viewport',
        'issue': 'Viewport not configured for responsive design',
        'details': results['viewport']['issues']
      });
    }
    
    if (results['mobileFriendly']['issues'].length > 0) {
      issues.add({
        'severity': 'medium',
        'category': 'Mobile',
        'issue': 'Mobile usability issues',
        'details': results['mobileFriendly']['issues']
      });
    }
    
    // Low priority issues
    if (results['splashScreen']['configured'] != true) {
      issues.add({
        'severity': 'low',
        'category': 'Splash Screen',
        'issue': 'Splash screen not configured',
        'impact': 'Less polished installation experience'
      });
    }
    
    if (results['performance']['fastLoading'] != true) {
      issues.add({
        'severity': 'low',
        'category': 'Performance',
        'issue': 'Page loads slowly',
        'impact': 'Poor user experience, especially on mobile'
      });
    }
    
    return issues;
  }
  
  List<Map<String, dynamic>> _generateRecommendations(Map<String, dynamic> results) {
    final recommendations = <Map<String, dynamic>>[];
    
    // HTTPS
    if (results['https'] != true) {
      recommendations.add({
        'priority': 'critical',
        'category': 'Security',
        'recommendation': 'Serve your app over HTTPS',
        'howTo': 'Use services like Let\'s Encrypt for free SSL certificates',
        'documentation': 'https://letsencrypt.org/'
      });
    }
    
    // Manifest
    if (results['manifest']['found'] != true) {
      recommendations.add({
        'priority': 'critical',
        'category': 'Manifest',
        'recommendation': 'Add a web app manifest',
        'howTo': 'Create a manifest.json file and link it in your HTML',
        'example': '<link rel="manifest" href="/manifest.json">',
        'documentation': 'https://web.dev/add-manifest/'
      });
    } else if (results['manifest']['errors'].length > 0) {
      recommendations.add({
        'priority': 'high',
        'category': 'Manifest',
        'recommendation': 'Fix manifest errors',
        'errors': results['manifest']['errors'],
        'documentation': 'https://web.dev/installable-manifest/'
      });
    }
    
    // Service Worker
    if (results['serviceWorker']['registered'] != true) {
      recommendations.add({
        'priority': 'critical',
        'category': 'Service Worker',
        'recommendation': 'Register a service worker',
        'howTo': 'Create a service worker file and register it in your app',
        'example': 'navigator.serviceWorker.register(\'/sw.js\')',
        'documentation': 'https://web.dev/service-worker/'
      });
    }
    
    // Offline
    if (results['offline']['hasOfflinePage'] != true) {
      recommendations.add({
        'priority': 'high',
        'category': 'Offline',
        'recommendation': 'Implement offline functionality',
        'howTo': 'Use service worker to cache essential resources',
        'strategies': ['Cache First', 'Network First', 'Stale While Revalidate'],
        'documentation': 'https://web.dev/offline-cookbook/'
      });
    }
    
    // Icons
    if (!results['icons']['hasIcons'] || results['icons']['issues'].length > 2) {
      recommendations.add({
        'priority': 'medium',
        'category': 'Icons',
        'recommendation': 'Add appropriate icon sizes',
        'requiredSizes': ['192x192', '512x512'],
        'recommendedSizes': ['72x72', '96x96', '128x128', '144x144', '152x152'],
        'maskable': 'Include a maskable icon for adaptive icon support',
        'documentation': 'https://web.dev/maskable-icon/'
      });
    }
    
    // Viewport
    if (!results['viewport']['hasViewportMeta']) {
      recommendations.add({
        'priority': 'high',
        'category': 'Viewport',
        'recommendation': 'Add viewport meta tag',
        'example': '<meta name="viewport" content="width=device-width, initial-scale=1">',
        'documentation': 'https://web.dev/viewport/'
      });
    }
    
    // Performance
    if (results['performance']['fastLoading'] != true) {
      recommendations.add({
        'priority': 'medium',
        'category': 'Performance',
        'recommendation': 'Improve loading performance',
        'targets': {
          'FCP': 'Less than 2 seconds',
          'TTI': 'Less than 5 seconds'
        },
        'techniques': [
          'Code splitting',
          'Lazy loading',
          'Resource hints (preload, prefetch)',
          'Image optimization'
        ],
        'documentation': 'https://web.dev/fast/'
      });
    }
    
    // Push Notifications
    if (results['pushNotifications']['supported'] != true) {
      recommendations.add({
        'priority': 'low',
        'category': 'Engagement',
        'recommendation': 'Consider implementing push notifications',
        'howTo': 'Use Push API with service worker',
        'bestPractices': 'Ask for permission at the right time, provide value',
        'documentation': 'https://web.dev/push-notifications/'
      });
    }
    
    // App Shell
    if (results['appShell']['hasAppShell'] != true) {
      recommendations.add({
        'priority': 'low',
        'category': 'Architecture',
        'recommendation': 'Implement app shell architecture',
        'benefits': 'Instant loading, reliable performance, native-like experience',
        'documentation': 'https://web.dev/app-shell/'
      });
    }
    
    // Advanced capabilities
    const advancedCaps = ['webShare', 'backgroundSync', 'periodicSync'];
    const missingCaps = [];
    for (final cap in advancedCaps) {
      if (results['capabilities'][cap] != true) {
        missingCaps.add(cap);
      }
    }
    
    if (missingCaps.isNotEmpty) {
      recommendations.add({
        'priority': 'low',
        'category': 'Capabilities',
        'recommendation': 'Consider adding advanced PWA capabilities',
        'available': missingCaps,
        'documentation': 'https://web.dev/progressive-web-apps/'
      });
    }
    
    return recommendations;
  }
}

// Extension for AuditContext to hold PWA results
extension PWAContext on AuditContext {
  static final _pwa = Expando<Map<String, dynamic>>();
  
  Map<String, dynamic>? get pwa => _pwa[this];
  set pwa(Map<String, dynamic>? value) => _pwa[this] = value;
}