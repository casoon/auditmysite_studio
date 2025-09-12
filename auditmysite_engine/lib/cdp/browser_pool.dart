import 'package:puppeteer/puppeteer.dart';

class BrowserPool {
  final Browser browser;

  BrowserPool._(this.browser);

  static Future<BrowserPool> launch() async {
    final browser = await puppeteer.launch(headless: true);
    return BrowserPool._(browser);
  }

  Future<Page> newPage() => browser.newPage();

  Future<void> close() => browser.close();
}
