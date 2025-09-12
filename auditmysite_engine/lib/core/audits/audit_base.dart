import '../events.dart';

abstract class Audit {
  String get name;
  Future<void> run(AuditContext ctx);
}
