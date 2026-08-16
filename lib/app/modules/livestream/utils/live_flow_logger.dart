import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Structured, debug-only lifecycle logging with recursive credential redaction.
class LiveFlowLogger {
  LiveFlowLogger._();

  static const Set<String> _secretKeys = <String>{
    'authorization', 'password', 'room_password', 'secret', 'secret_key',
    'api_secret', 'firebase_token', 'fcm_token', 'access_token',
    'refresh_token', 'agora_token', 'rtc_token', 'token',
  };

  static dynamic safe(dynamic value, {String? key}) {
    final normalizedKey = key?.toLowerCase().trim() ?? '';
    if (_secretKeys.contains(normalizedKey) ||
        normalizedKey.endsWith('_secret') ||
        normalizedKey.endsWith('_password')) {
      final length = value?.toString().length ?? 0;
      return <String, dynamic>{'present': length > 0, 'length': length};
    }
    if (value is Map) {
      return value.map<String, dynamic>(
        (dynamic k, dynamic v) => MapEntry('$k', safe(v, key: '$k')),
      );
    }
    if (value is Iterable) return value.map((v) => safe(v)).toList();
    return value;
  }

  static void log(String event, Map<String, dynamic> fields) {
    if (!kDebugMode) return;
    final payload = <String, dynamic>{
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      ...fields,
    };
    debugPrint('[LIVE_FLOW][$event] ${jsonEncode(safe(payload))}');
  }

  static Map<String, dynamic> tokenMetadata(
    dynamic token, {
    String source = 'unknown',
  }) {
    final value = token?.toString() ?? '';
    return <String, dynamic>{
      'token_present': value.isNotEmpty,
      'token_length': value.length,
      'token_source': source,
    };
  }
}
