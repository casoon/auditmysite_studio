# AuditMySite Engine API Documentation

## Overview

The AuditMySite Engine provides a REST API and WebSocket interface for web accessibility auditing. It crawls sitemaps, audits pages using Chrome DevTools Protocol and axe-core, and provides real-time progress updates.

**Base URL**: `http://localhost:3000` (default)  
**API Version**: v1.0  
**Content-Type**: `application/json`

## Authentication

Currently, no authentication is required. For production deployments, implement authentication via reverse proxy or API gateway.

## REST API Endpoints

### Health Check

**GET** `/health`

Check if the engine is running and healthy.

**Response**:
```json
{
  "status": "ok",
  "version": "0.1.0",
  "uptime": 12345
}
```

### Start Audit

**POST** `/audit`

Start a new audit job.

**Request Body**:
```json
{
  "sitemap_url": "https://example.com/sitemap.xml",
  "concurrency": 4,
  "collect_perf": true,
  "screenshots": false,
  "include_patterns": [".*"],
  "exclude_patterns": [".*\\.pdf$", ".*admin.*"],
  "max_pages": 100,
  "rate_limit": 10,
  "delay_ms": 100
}
```

**Parameters**:
- `sitemap_url` (required): URL to the XML sitemap
- `concurrency` (optional, default: 4): Number of parallel workers
- `collect_perf` (optional, default: true): Collect performance metrics
- `screenshots` (optional, default: false): Take page screenshots
- `include_patterns` (optional): Array of regex patterns to include URLs
- `exclude_patterns` (optional): Array of regex patterns to exclude URLs
- `max_pages` (optional): Maximum number of pages to audit
- `rate_limit` (optional, default: 10): Requests per second limit
- `delay_ms` (optional, default: 0): Delay between requests in milliseconds

**Response**:
```json
{
  "run_id": "20231201-143022-abc123",
  "status": "started",
  "sitemap_url": "https://example.com/sitemap.xml",
  "discovered_urls": 156,
  "filtered_urls": 142,
  "settings": {
    "concurrency": 4,
    "collect_perf": true,
    "screenshots": false
  }
}
```

### Get Audit Status

**GET** `/audit/{run_id}/status`

Get the current status of an audit job.

**Response**:
```json
{
  "run_id": "20231201-143022-abc123",
  "status": "running",
  "progress": {
    "total_pages": 142,
    "completed": 89,
    "failed": 2,
    "remaining": 51
  },
  "started_at": "2023-12-01T14:30:22Z",
  "estimated_completion": "2023-12-01T14:45:30Z"
}
```

### Get Audit Results

**GET** `/audit/{run_id}/results`

Get the final results of a completed audit.

**Response**:
```json
{
  "run_id": "20231201-143022-abc123",
  "status": "completed",
  "summary": {
    "total_pages": 142,
    "successful": 140,
    "failed": 2,
    "total_violations": 1247,
    "average_ttfb_ms": 245,
    "average_lcp_ms": 1850
  },
  "pages": [
    {
      "url": "https://example.com/",
      "status_code": 200,
      "audit_result": "success",
      "violations": 12,
      "performance": {
        "ttfb_ms": 180,
        "fcp_ms": 1200,
        "lcp_ms": 1800,
        "dcl_ms": 1500
      },
      "screenshot_path": "/artifacts/20231201-143022-abc123/screenshots/home.png"
    }
  ]
}
```

### List Audit Runs

**GET** `/audits`

List all audit runs.

**Query Parameters**:
- `limit` (optional, default: 20): Number of results
- `offset` (optional, default: 0): Offset for pagination
- `status` (optional): Filter by status (running, completed, failed)

**Response**:
```json
{
  "audits": [
    {
      "run_id": "20231201-143022-abc123",
      "sitemap_url": "https://example.com/sitemap.xml",
      "status": "completed",
      "started_at": "2023-12-01T14:30:22Z",
      "completed_at": "2023-12-01T14:42:15Z",
      "total_pages": 142,
      "total_violations": 1247
    }
  ],
  "total": 1,
  "has_more": false
}
```

### Delete Audit Results

**DELETE** `/audit/{run_id}`

Delete audit results and associated artifacts.

**Response**:
```json
{
  "status": "deleted",
  "run_id": "20231201-143022-abc123"
}
```

## WebSocket Events

Connect to `/ws` for real-time audit progress updates.

### Connection

```javascript
const ws = new WebSocket('ws://localhost:3000/ws');
```

### Event Types

All WebSocket messages follow this structure:
```json
{
  "event": "event_type",
  "run_id": "20231201-143022-abc123",
  "url": "https://example.com/page",
  "timestamp": "2023-12-01T14:30:22.123Z",
  "data": { /* event-specific data */ }
}
```

#### `audit_started`
Sent when a new audit job begins.
```json
{
  "event": "audit_started",
  "run_id": "20231201-143022-abc123",
  "timestamp": "2023-12-01T14:30:22.123Z",
  "data": {
    "sitemap_url": "https://example.com/sitemap.xml",
    "total_pages": 142,
    "settings": { /* audit settings */ }
  }
}
```

#### `page_queued`
Sent when a page is queued for processing.
```json
{
  "event": "page_queued",
  "run_id": "20231201-143022-abc123",
  "url": "https://example.com/page",
  "timestamp": "2023-12-01T14:30:23.456Z",
  "data": {}
}
```

#### `page_started`
Sent when processing of a page begins.
```json
{
  "event": "page_started",
  "run_id": "20231201-143022-abc123",
  "url": "https://example.com/page",
  "timestamp": "2023-12-01T14:30:24.789Z",
  "data": {
    "worker_id": 2
  }
}
```

#### `page_finished`
Sent when a page audit completes successfully.
```json
{
  "event": "page_finished",
  "run_id": "20231201-143022-abc123",
  "url": "https://example.com/page",
  "timestamp": "2023-12-01T14:30:28.123Z",
  "data": {
    "status_code": 200,
    "violation_count": 8,
    "performance": {
      "ttfb_ms": 180,
      "lcp_ms": 1800
    },
    "processing_time_ms": 3334
  }
}
```

#### `page_error`
Sent when a page audit fails.
```json
{
  "event": "page_error",
  "run_id": "20231201-143022-abc123",
  "url": "https://example.com/page",
  "timestamp": "2023-12-01T14:30:25.456Z",
  "data": {
    "error": "Navigation timeout",
    "error_code": "TIMEOUT"
  }
}
```

#### `page_retry`
Sent when a page audit is being retried.
```json
{
  "event": "page_retry",
  "run_id": "20231201-143022-abc123",
  "url": "https://example.com/page",
  "timestamp": "2023-12-01T14:30:26.789Z",
  "data": {
    "attempt": 2,
    "max_attempts": 3,
    "reason": "Navigation timeout"
  }
}
```

#### `audit_completed`
Sent when the entire audit job finishes.
```json
{
  "event": "audit_completed",
  "run_id": "20231201-143022-abc123",
  "timestamp": "2023-12-01T14:42:15.123Z",
  "data": {
    "status": "completed",
    "total_pages": 142,
    "successful": 140,
    "failed": 2,
    "duration_ms": 713000,
    "artifacts_path": "/artifacts/20231201-143022-abc123/"
  }
}
```

## Error Responses

All API endpoints return standardized error responses:

```json
{
  "error": {
    "code": "INVALID_SITEMAP",
    "message": "The provided sitemap URL is not accessible",
    "details": {
      "sitemap_url": "https://example.com/sitemap.xml",
      "http_status": 404
    }
  }
}
```

### Common Error Codes

- `INVALID_REQUEST`: Malformed request body or missing required fields
- `INVALID_SITEMAP`: Sitemap URL is not accessible or invalid
- `AUDIT_NOT_FOUND`: The specified audit run_id does not exist
- `AUDIT_RUNNING`: Cannot perform operation while audit is running
- `RATE_LIMITED`: Too many requests (if rate limiting is enabled)
- `INTERNAL_ERROR`: Unexpected server error

## Rate Limiting

The API implements rate limiting to prevent abuse:

- Default: 100 requests per minute per IP
- Headers included in responses:
  - `X-RateLimit-Limit`: Request limit per window
  - `X-RateLimit-Remaining`: Requests remaining in current window
  - `X-RateLimit-Reset`: Time when rate limit resets (Unix timestamp)

## File Artifacts

Audit results include file artifacts stored on the server:

- **JSON Results**: `/artifacts/{run_id}/pages/{url_hash}.json`
- **Screenshots**: `/artifacts/{run_id}/screenshots/{url_hash}.png`
- **Run Summary**: `/artifacts/{run_id}/run_summary.json`

Files are accessible via HTTP when using the nginx configuration:
`http://localhost/reports/{run_id}/...`

## Usage Examples

### cURL Examples

Start an audit:
```bash
curl -X POST http://localhost:3000/audit \
  -H "Content-Type: application/json" \
  -d '{
    "sitemap_url": "https://example.com/sitemap.xml",
    "concurrency": 4,
    "collect_perf": true
  }'
```

Check audit status:
```bash
curl http://localhost:3000/audit/20231201-143022-abc123/status
```

### JavaScript Example

```javascript
// Start audit
const response = await fetch('http://localhost:3000/audit', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    sitemap_url: 'https://example.com/sitemap.xml',
    concurrency: 4,
    collect_perf: true
  })
});
const { run_id } = await response.json();

// Listen to WebSocket events
const ws = new WebSocket('ws://localhost:3000/ws');
ws.onmessage = (event) => {
  const data = JSON.parse(event.data);
  if (data.run_id === run_id) {
    console.log(`Event: ${data.event}`, data);
  }
};
```

## Production Considerations

1. **Authentication**: Implement authentication via reverse proxy
2. **HTTPS**: Use SSL/TLS encryption for production deployments
3. **Rate Limiting**: Configure appropriate rate limits
4. **Monitoring**: Implement logging and monitoring
5. **Backup**: Regular backup of audit artifacts
6. **Scaling**: Use load balancer for multiple engine instances
