import 'dart:io';
import 'dart:convert';
import 'package:puppeteer/puppeteer.dart';
import '../events.dart';
import 'audit_base.dart';

class A11yAxeAudit implements Audit {
  @override
  String get name => 'a11y_axe';

  final bool screenshots;
  final String axeSourceFile;
  A11yAxeAudit({required this.screenshots, required this.axeSourceFile});

  @override
  Future<void> run(AuditContext ctx) async {
    final page = ctx.page as Page;
    final axeSource = await File(axeSourceFile).readAsString();

    // Console Errors sammeln
    page.onConsole.listen((msg) {
      if (msg.type == ConsoleMessageType.error) {
        ctx.consoleErrors.add(msg.text ?? 'Console error without message');
      }
    });

    await page.addScriptTag(content: axeSource);

    final axeJsonStr = await page.evaluate(r'''
async () => {
  const result = await axe.run(document, { resultTypes: ['violations'] });
  return JSON.stringify(result);
}''') as String;

    ctx.axeJson = (axeJsonStr.isNotEmpty)
        ? jsonDecode(axeJsonStr) as Map<String, dynamic>
        : null;

    if (screenshots) {
      final safe = ctx.url.toString().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final out = 'artifacts/screenshots/$safe.png';
      await File(out).parent.create(recursive: true);
      final screenshotData = await page.screenshot(format: ScreenshotFormat.png, fullPage: true);
      await File(out).writeAsBytes(screenshotData);
      ctx.screenshotPath = out;
    }
  }
}
