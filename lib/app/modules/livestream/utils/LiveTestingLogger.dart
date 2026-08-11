import 'dart:convert';

import 'package:dio/dio.dart';

import 'live_performance_config.dart';

/// Temporary live-room testing logger.
///
/// Keep [enabled] true only while testing. Every request/event is printed with
/// sensitive values masked. Large payloads are chunked and capped so Logcat does
/// not silently truncate one long line or freeze the UI during gift bursts.
class LiveTestingLogger {
  LiveTestingLogger._();

  // Building/sanitizing large websocket and API payloads is expensive even
  // when the final log sink is disabled. Keep the entire diagnostics pipeline
  // behind the same compile-time live-debug switch.
  static const bool enabled = kLiveDebug;
  static const int defaultMaxChars = 16000;
  static const int _chunkSize = 850;

  static final Set<int> _installedDioClients = <int>{};
  static int _apiSequence = 0;
  static int _eventSequence = 0;

  static int nextEventSequence() => ++_eventSequence;

  static bool _isSensitiveKey(String key) {
    final value = key.toLowerCase().replaceAll('-', '_');
    return value.contains('authorization') ||
        value == 'token' ||
        value.endsWith('_token') ||
        value.contains('access_token') ||
        value.contains('refresh_token') ||
        value.contains('password') ||
        value.contains('secret') ||
        value == 'auth' ||
        value.contains('api_key') ||
        value.contains('credential') ||
        value == 'otp' ||
        value.endsWith('_otp');
  }

  static dynamic sanitize(dynamic value, {String parentKey = ''}) {
    if (_isSensitiveKey(parentKey)) return '***MASKED***';
    if (value == null || value is num || value is bool) return value;
    if (value is DateTime) return value.toIso8601String();

    if (value is String) {
      if (parentKey.toLowerCase().contains('header') &&
          value.toLowerCase().startsWith('bearer ')) {
        return 'Bearer ***MASKED***';
      }
      return value;
    }

    if (value is FormData) {
      return <String, dynamic>{
        'fields': <String, dynamic>{
          for (final field in value.fields)
            field.key: sanitize(field.value, parentKey: field.key),
        },
        'files': value.files
            .map((entry) => <String, dynamic>{
          'field': entry.key,
          'filename': entry.value.filename,
          'content_type': entry.value.contentType.toString(),
        })
            .toList(),
      };
    }

    if (value is Map) {
      final map = <String, dynamic>{};
      value.forEach((dynamic key, dynamic item) {
        final stringKey = key.toString();
        map[stringKey] = sanitize(item, parentKey: stringKey);
      });
      return map;
    }

    if (value is Iterable) {
      return value.map((item) => sanitize(item, parentKey: parentKey)).toList();
    }

    return value.toString();
  }

  static String compact(dynamic value, {int maxChars = defaultMaxChars}) {
    String text;
    try {
      text = const JsonEncoder.withIndent('  ').convert(sanitize(value));
    } catch (_) {
      text = sanitize(value).toString();
    }

    if (text.length <= maxChars) return text;
    return '${text.substring(0, maxChars)}\n...<TRUNCATED ${text.length - maxChars} CHARS>';
  }

  static void printBlock(
      String title,
      dynamic data, {
        int maxChars = defaultMaxChars,
      }) {
    if (!enabled) return;
    final String text = compact(data, maxChars: maxChars);
    _printLong('\n================ $title ================');
    _printLong(text);
    _printLong('================ END $title ================\n');
  }

  static void line(String text) {
    if (!enabled) return;
    _printLong(text);
  }

  static void _printLong(String text) {
    if (text.length <= _chunkSize) {
      liveLog(text, wrapWidth: 1024);
      return;
    }

    for (int start = 0; start < text.length; start += _chunkSize) {
      final int end = (start + _chunkSize < text.length)
          ? start + _chunkSize
          : text.length;
      liveLog(text.substring(start, end), wrapWidth: 1024);
    }
  }

  static void installDio(Dio dio, {required String owner}) {
    if (!enabled) return;
    final int clientId = identityHashCode(dio);
    if (!_installedDioClients.add(clientId)) return;

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
          final int requestId = ++_apiSequence;
          final int startedAtMs = DateTime.now().millisecondsSinceEpoch;
          options.extra['_live_test_request_id'] = requestId;
          options.extra['_live_test_started_at_ms'] = startedAtMs;

          printBlock('LIVE API REQUEST #$requestId [$owner]', <String, dynamic>{
            'time': DateTime.now().toIso8601String(),
            'method': options.method,
            'url': options.uri.toString(),
            'base_url': options.baseUrl,
            'path': options.path,
            'query': options.queryParameters,
            'headers': options.headers,
            'data': options.data,
            'connect_timeout_ms': options.connectTimeout?.inMilliseconds,
            'send_timeout_ms': options.sendTimeout?.inMilliseconds,
            'receive_timeout_ms': options.receiveTimeout?.inMilliseconds,
          });
          handler.next(options);
        },
        onResponse: (Response<dynamic> response, ResponseInterceptorHandler handler) {
          final RequestOptions request = response.requestOptions;
          final int requestId =
              (request.extra['_live_test_request_id'] as int?) ?? 0;
          final int startedAtMs =
              (request.extra['_live_test_started_at_ms'] as int?) ?? 0;
          final int elapsedMs = startedAtMs > 0
              ? DateTime.now().millisecondsSinceEpoch - startedAtMs
              : -1;

          printBlock(
            'LIVE API RESPONSE #$requestId [$owner]',
            <String, dynamic>{
              'time': DateTime.now().toIso8601String(),
              'method': request.method,
              'url': request.uri.toString(),
              'status_code': response.statusCode,
              'status_message': response.statusMessage,
              'elapsed_ms': elapsedMs,
              'headers': response.headers.map,
              'data': response.data,
              'last_ping_at': findFirstByKeys(response.data, const <String>[
                'last_ping_at',
                'last_ping',
                'ping_at',
                'last_seen_at',
              ]),
            },
          );
          handler.next(response);
        },
        onError: (DioException error, ErrorInterceptorHandler handler) {
          final RequestOptions request = error.requestOptions;
          final int requestId =
              (request.extra['_live_test_request_id'] as int?) ?? 0;
          final int startedAtMs =
              (request.extra['_live_test_started_at_ms'] as int?) ?? 0;
          final int elapsedMs = startedAtMs > 0
              ? DateTime.now().millisecondsSinceEpoch - startedAtMs
              : -1;

          printBlock('LIVE API ERROR #$requestId [$owner]', <String, dynamic>{
            'time': DateTime.now().toIso8601String(),
            'method': request.method,
            'url': request.uri.toString(),
            'elapsed_ms': elapsedMs,
            'dio_type': error.type.toString(),
            'message': error.message,
            'error': error.error?.toString(),
            'status_code': error.response?.statusCode,
            'status_message': error.response?.statusMessage,
            'request_query': request.queryParameters,
            'request_data': request.data,
            'response_headers': error.response?.headers.map,
            'response_data': error.response?.data,
          });
          handler.next(error);
        },
      ),
    );

    line('🧪 LIVE TEST Dio logger installed => owner=$owner client=$clientId');
  }

  static dynamic findFirstByKeys(dynamic value, List<String> keys) {
    final Set<String> wanted = keys.map((key) => key.toLowerCase()).toSet();

    dynamic walk(dynamic current, int depth) {
      if (depth > 8 || current == null) return null;
      if (current is Map) {
        for (final entry in current.entries) {
          if (wanted.contains(entry.key.toString().toLowerCase()) &&
              entry.value != null &&
              entry.value.toString().trim().isNotEmpty) {
            return entry.value;
          }
        }
        for (final entry in current.entries) {
          final dynamic found = walk(entry.value, depth + 1);
          if (found != null) return found;
        }
      } else if (current is Iterable) {
        for (final item in current) {
          final dynamic found = walk(item, depth + 1);
          if (found != null) return found;
        }
      }
      return null;
    }

    return walk(value, 0);
  }

  static DateTime? parseServerDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is int) {
      final int millis = value > 9999999999 ? value : value * 1000;
      return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true).toLocal();
    }
    final String text = value.toString().trim();
    if (text.isEmpty) return null;
    final int? numeric = int.tryParse(text);
    if (numeric != null) {
      final int millis = numeric > 9999999999 ? numeric : numeric * 1000;
      return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true).toLocal();
    }
    return DateTime.tryParse(text)?.toLocal();
  }

  static int? ageSeconds(dynamic serverDate) {
    final DateTime? parsed = parseServerDate(serverDate);
    if (parsed == null) return null;
    return DateTime.now().difference(parsed).inSeconds;
  }
}
