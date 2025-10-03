import '../events.dart';
import 'audit_base.dart';

class TestAudit extends Audit {
  @override
  String get name => 'test';

  @override
  Future<void> run(AuditContext ctx) async {
    final page = ctx.page;
    
    // Simple test
    final result = await page.evaluate(r'''
() => {
  return { test: 'hello', number: 42 };
}
    ''');
    
    print('Test result: $result');
  }
}