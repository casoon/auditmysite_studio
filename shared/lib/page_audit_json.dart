import 'package:json_annotation/json_annotation.dart';

part 'page_audit_json.g.dart';

@JsonSerializable(explicitToJson: true)
class PageAuditJson {
  final String schemaVersion;
  final String runId;
  final String url;
  final PageHttp http;
  final PagePerf perf;
  final AxeReport? a11y;
  final List<String> consoleErrors;
  final String? screenshotPath;
  final DateTime startedAt;
  final DateTime finishedAt;

  PageAuditJson({
    required this.schemaVersion,
    required this.runId,
    required this.url,
    required this.http,
    required this.perf,
    required this.a11y,
    required this.consoleErrors,
    required this.screenshotPath,
    required this.startedAt,
    required this.finishedAt,
  });

  factory PageAuditJson.fromJson(Map<String, dynamic> json)
    => _$PageAuditJsonFromJson(json);
  Map<String, dynamic> toJson() => _$PageAuditJsonToJson(this);
}

@JsonSerializable()
class PageHttp {
  final int? statusCode;
  final Map<String, String>? headers;

  PageHttp({this.statusCode, this.headers});

  factory PageHttp.fromJson(Map<String, dynamic> json)
    => _$PageHttpFromJson(json);
  Map<String, dynamic> toJson() => _$PageHttpToJson(this);
}

@JsonSerializable(explicitToJson: true)
class PagePerf {
  final double? ttfbMs;
  final double? fcpMs;
  final double? lcpMs;
  final double? domContentLoadedMs;
  final double? loadEventEndMs;
  final EngineFootprint engine;

  PagePerf({
    this.ttfbMs,
    this.fcpMs,
    this.lcpMs,
    this.domContentLoadedMs,
    this.loadEventEndMs,
    required this.engine,
  });

  factory PagePerf.fromJson(Map<String, dynamic> json)
    => _$PagePerfFromJson(json);
  Map<String, dynamic> toJson() => _$PagePerfToJson(this);
}

@JsonSerializable()
class EngineFootprint {
  final double? cpuUserMs;
  final double? cpuSystemMs;
  final int? peakRssBytes;
  final double? taskDurationMs;

  EngineFootprint({
    this.cpuUserMs,
    this.cpuSystemMs,
    this.peakRssBytes,
    this.taskDurationMs,
  });

  factory EngineFootprint.fromJson(Map<String, dynamic> json)
    => _$EngineFootprintFromJson(json);
  Map<String, dynamic> toJson() => _$EngineFootprintToJson(this);
}

@JsonSerializable(explicitToJson: true)
class AxeReport {
  final List<AxeViolation> violations;

  AxeReport({required this.violations});

  factory AxeReport.fromJson(Map<String, dynamic> json)
    => _$AxeReportFromJson(json);
  Map<String, dynamic> toJson() => _$AxeReportToJson(this);
}

@JsonSerializable(explicitToJson: true)
class AxeViolation {
  final String id;
  final String? impact; // minor|moderate|serious|critical|null
  final String help;
  final String description;
  final List<AxeNode> nodes;

  AxeViolation({
    required this.id,
    required this.impact,
    required this.help,
    required this.description,
    required this.nodes,
  });

  factory AxeViolation.fromJson(Map<String, dynamic> json)
    => _$AxeViolationFromJson(json);
  Map<String, dynamic> toJson() => _$AxeViolationToJson(this);
}

@JsonSerializable()
class AxeNode {
  final String html;
  final List<String> target;

  AxeNode({required this.html, required this.target});

  factory AxeNode.fromJson(Map<String, dynamic> json)
    => _$AxeNodeFromJson(json);
  Map<String, dynamic> toJson() => _$AxeNodeToJson(this);
}
