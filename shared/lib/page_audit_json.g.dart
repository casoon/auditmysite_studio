// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'page_audit_json.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PageAuditJson _$PageAuditJsonFromJson(Map<String, dynamic> json) =>
    PageAuditJson(
      schemaVersion: json['schemaVersion'] as String,
      runId: json['runId'] as String,
      url: json['url'] as String,
      http: PageHttp.fromJson(json['http'] as Map<String, dynamic>),
      perf: PagePerf.fromJson(json['perf'] as Map<String, dynamic>),
      a11y: json['a11y'] == null
          ? null
          : AxeReport.fromJson(json['a11y'] as Map<String, dynamic>),
      consoleErrors: (json['consoleErrors'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      screenshotPath: json['screenshotPath'] as String?,
      startedAt: DateTime.parse(json['startedAt'] as String),
      finishedAt: DateTime.parse(json['finishedAt'] as String),
    );

Map<String, dynamic> _$PageAuditJsonToJson(PageAuditJson instance) =>
    <String, dynamic>{
      'schemaVersion': instance.schemaVersion,
      'runId': instance.runId,
      'url': instance.url,
      'http': instance.http.toJson(),
      'perf': instance.perf.toJson(),
      'a11y': instance.a11y?.toJson(),
      'consoleErrors': instance.consoleErrors,
      'screenshotPath': instance.screenshotPath,
      'startedAt': instance.startedAt.toIso8601String(),
      'finishedAt': instance.finishedAt.toIso8601String(),
    };

PageHttp _$PageHttpFromJson(Map<String, dynamic> json) => PageHttp(
      statusCode: (json['statusCode'] as num?)?.toInt(),
      headers: (json['headers'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ),
    );

Map<String, dynamic> _$PageHttpToJson(PageHttp instance) => <String, dynamic>{
      'statusCode': instance.statusCode,
      'headers': instance.headers,
    };

PagePerf _$PagePerfFromJson(Map<String, dynamic> json) => PagePerf(
      ttfbMs: (json['ttfbMs'] as num?)?.toDouble(),
      fcpMs: (json['fcpMs'] as num?)?.toDouble(),
      lcpMs: (json['lcpMs'] as num?)?.toDouble(),
      domContentLoadedMs: (json['domContentLoadedMs'] as num?)?.toDouble(),
      loadEventEndMs: (json['loadEventEndMs'] as num?)?.toDouble(),
      engine: EngineFootprint.fromJson(json['engine'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$PagePerfToJson(PagePerf instance) => <String, dynamic>{
      'ttfbMs': instance.ttfbMs,
      'fcpMs': instance.fcpMs,
      'lcpMs': instance.lcpMs,
      'domContentLoadedMs': instance.domContentLoadedMs,
      'loadEventEndMs': instance.loadEventEndMs,
      'engine': instance.engine.toJson(),
    };

EngineFootprint _$EngineFootprintFromJson(Map<String, dynamic> json) =>
    EngineFootprint(
      cpuUserMs: (json['cpuUserMs'] as num?)?.toDouble(),
      cpuSystemMs: (json['cpuSystemMs'] as num?)?.toDouble(),
      peakRssBytes: (json['peakRssBytes'] as num?)?.toInt(),
      taskDurationMs: (json['taskDurationMs'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$EngineFootprintToJson(EngineFootprint instance) =>
    <String, dynamic>{
      'cpuUserMs': instance.cpuUserMs,
      'cpuSystemMs': instance.cpuSystemMs,
      'peakRssBytes': instance.peakRssBytes,
      'taskDurationMs': instance.taskDurationMs,
    };

AxeReport _$AxeReportFromJson(Map<String, dynamic> json) => AxeReport(
      violations: (json['violations'] as List<dynamic>)
          .map((e) => AxeViolation.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$AxeReportToJson(AxeReport instance) => <String, dynamic>{
      'violations': instance.violations.map((e) => e.toJson()).toList(),
    };

AxeViolation _$AxeViolationFromJson(Map<String, dynamic> json) => AxeViolation(
      id: json['id'] as String,
      impact: json['impact'] as String?,
      help: json['help'] as String,
      description: json['description'] as String,
      nodes: (json['nodes'] as List<dynamic>)
          .map((e) => AxeNode.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$AxeViolationToJson(AxeViolation instance) =>
    <String, dynamic>{
      'id': instance.id,
      'impact': instance.impact,
      'help': instance.help,
      'description': instance.description,
      'nodes': instance.nodes.map((e) => e.toJson()).toList(),
    };

AxeNode _$AxeNodeFromJson(Map<String, dynamic> json) => AxeNode(
      html: json['html'] as String,
      target:
          (json['target'] as List<dynamic>).map((e) => e as String).toList(),
    );

Map<String, dynamic> _$AxeNodeToJson(AxeNode instance) => <String, dynamic>{
      'html': instance.html,
      'target': instance.target,
    };
