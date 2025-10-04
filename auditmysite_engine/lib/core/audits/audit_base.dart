import '../events.dart';

abstract class Audit {
  String get name;
  Future<void> run(AuditContext ctx);
}

/// Wrapper to add error handling to any audit
class SafeAudit implements Audit {
  final Audit _audit;
  
  SafeAudit(this._audit);
  
  @override
  String get name => _audit.name;
  
  @override
  Future<void> run(AuditContext ctx) async {
    try {
      print('[Audit] Running: $name');
      await _audit.run(ctx);
      print('[Audit] ✅ Completed: $name');
    } catch (e, stack) {
      print('[Audit] ❌ Failed: $name');
      print('[Audit] Error: $e');
      print('[Audit] Stack: ${stack.toString().split('\n').take(5).join('\n')}');
      // Store error in context but continue with other audits
      ctx.auditErrors ??= {};
      ctx.auditErrors![name] = e.toString();
    }
  }
}
