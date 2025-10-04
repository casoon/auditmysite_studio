import 'dart:async';
import 'dart:collection';
import 'package:puppeteer/puppeteer.dart';

/// Simple, clean browser pool using Puppeteer's automatic browser management
class BrowserPool {
  Browser? _browser;
  final _availablePages = Queue<Page>();
  final _busyPages = <Page>{};
  Timer? _cleanupTimer;
  bool _disposed = false;

  Browser get browser => _browser!;

  BrowserPool._();

  /// Launch browser pool
  /// Puppeteer automatically downloads and manages Chromium
  static Future<BrowserPool> launch({
    bool headless = true,
  }) async {
    final pool = BrowserPool._();

    // Puppeteer handles browser download automatically
    pool._browser = await puppeteer.launch(
      headless: headless,
      args: [
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage',
        '--disable-gpu',
        '--window-size=1920,1080',
      ],
      defaultViewport: DeviceViewport(
        width: 1920,
        height: 1080,
      ),
    );

    // Pre-create pages
    for (var i = 0; i < 2; i++) {
      final page = await pool._browser!.newPage();
      pool._availablePages.add(page);
    }

    // Start cleanup timer
    pool._cleanupTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => pool._cleanup(),
    );

    return pool;
  }

  /// Get a page from the pool
  Future<Page> acquire() async {
    if (_disposed) throw StateError('Pool is disposed');

    if (_availablePages.isNotEmpty) {
      final page = _availablePages.removeFirst();
      _busyPages.add(page);
      return page;
    }

    if (_busyPages.length < 10) {
      final page = await _browser!.newPage();
      _busyPages.add(page);
      return page;
    }

    // Wait and retry
    await Future.delayed(const Duration(milliseconds: 100));
    return acquire();
  }

  /// Release page back to pool
  void release(Page page) {
    if (!_busyPages.remove(page)) return;

    if (_availablePages.length < 5) {
      _availablePages.add(page);
    } else {
      page.close().ignore();
    }
  }

  void _cleanup() {
    while (_availablePages.length > 2) {
      _availablePages.removeFirst().close().ignore();
    }
  }

  /// Close browser and all pages
  Future<void> close() async {
    if (_disposed) return;
    _disposed = true;

    _cleanupTimer?.cancel();

    for (final page in [..._availablePages, ..._busyPages]) {
      await page.close().catchError((_) {});
    }

    _availablePages.clear();
    _busyPages.clear();

    await _browser?.close();
  }
}
