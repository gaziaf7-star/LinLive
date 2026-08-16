import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;

import '../../../../apis/api_endpoints.dart';
import 'package:meetlivepro/app/modules/livestream/utils/live_performance_config.dart';

import '../utils/LiveTestingLogger.dart';

class AgoraTokenController extends GetxController {
  final Dio dio = Dio();

  @override
  void onInit() {
    LiveTestingLogger.installDio(dio, owner: 'AgoraTokenController');
    super.onInit();
  }

  final RxMap<String, dynamic> agoraToken = <String, dynamic>{}.obs;
  final RxBool tokenIsLoading = false.obs;

  final Map<String, Future<Map<String, dynamic>?>> _inFlightRequests =
      <String, Future<Map<String, dynamic>?>>{};

  String _lastSuccessfulRequestKey = '';
  DateTime? _lastSuccessfulAt;
  int _loadingRequestCount = 0;

  Future<bool> tryToGenerateBroadcasterToken({
    required bool isBroadcaster,
    required int userId,
    required String channelName,
    required String streamId,
    int? pkId,
    bool forceRefresh = false,
  }) async {
    final Map<String, dynamic>? result = await requestAgoraToken(
      isBroadcaster: isBroadcaster,
      userId: userId,
      channelName: channelName,
      streamId: streamId,
      pkId: pkId,
      forceRefresh: forceRefresh,
    );

    return result != null && getTokenStringFrom(result).isNotEmpty;
  }

  /// Reuses a valid RTC token already returned by a join/create endpoint.
  /// This avoids a second network round-trip while preserving the dedicated
  /// token endpoint as the fallback and renewal source.
  bool adoptTokenResponseIfValid({
    required Map<String, dynamic> response,
    required bool isBroadcaster,
    required int userId,
    required String channelName,
    required String streamId,
    int? pkId,
  }) {
    final candidates = <Map<String, dynamic>>[];
    void collect(dynamic raw, int depth) {
      if (raw is! Map || depth > 4) return;
      final candidate = Map<String, dynamic>.from(raw);
      candidates.add(candidate);
      for (final key in const <String>[
        '_bootstrap_response',
        'data',
        'agora',
        'rtc',
        'token_data',
        'livestream',
        'livestreamdata',
      ]) {
        collect(candidate[key], depth + 1);
      }
    }

    collect(response, 0);

    final String requestedChannel = channelName.trim();
    for (final candidate in candidates) {
      final Map<String, dynamic> nestedCandidate = _nestedData(candidate);
      final bool explicitlyRtc =
          candidate.containsKey('agora_token') ||
          candidate.containsKey('rtc_token') ||
          nestedCandidate.containsKey('agora_token') ||
          nestedCandidate.containsKey('rtc_token') ||
          candidate.containsKey('channel_name') ||
          nestedCandidate.containsKey('channel_name') ||
          candidate.containsKey('app_id') ||
          nestedCandidate.containsKey('app_id');
      if (!explicitlyRtc) continue;
      final String token = getTokenStringFrom(candidate).trim();
      if (token.isEmpty) continue;

      final String returnedChannel = getChannelNameStringFrom(candidate).trim();
      final int returnedUid = getUidIntFrom(candidate);
      if (returnedChannel.isNotEmpty && returnedChannel != requestedChannel) {
        continue;
      }
      if (returnedUid > 0 && returnedUid != userId) continue;

      agoraToken.value = Map<String, dynamic>.from(candidate);
      _lastSuccessfulRequestKey =
          '${isBroadcaster ? 'b' : 'a'}|$userId|$requestedChannel|$streamId|${pkId ?? 0}';
      _lastSuccessfulAt = DateTime.now();
      liveLog('✅ Reused valid Agora token from join response');
      return true;
    }
    return false;
  }

  /// Returns the exact response for this request.
  ///
  /// Token renewal must use this method instead of reading only the global
  /// [agoraToken] map, because another Agora request can finish at the same
  /// time and overwrite that observable.
  Future<Map<String, dynamic>?> requestAgoraToken({
    required bool isBroadcaster,
    required int userId,
    required String channelName,
    required String streamId,
    int? pkId,
    bool forceRefresh = false,
  }) async {
    final String safeChannelName = channelName.trim();
    if (safeChannelName.isEmpty || userId <= 0) {
      if (!forceRefresh) {
        agoraToken.clear();
      }
      liveLog('❌ Agora token skipped: invalid channel/user');
      return null;
    }

    final String baseRequestKey =
        '${isBroadcaster ? 'b' : 'a'}|$userId|$safeChannelName|$streamId|${pkId ?? 0}';

    final DateTime? lastSuccessAt = _lastSuccessfulAt;
    final bool cacheStillFresh =
        lastSuccessAt != null &&
        DateTime.now().difference(lastSuccessAt) < const Duration(seconds: 20);
    if (!forceRefresh &&
        cacheStillFresh &&
        _lastSuccessfulRequestKey == baseRequestKey &&
        getTokenString().isNotEmpty) {
      return Map<String, dynamic>.from(agoraToken);
    }

    // Normal and renewal requests are separated. Multiple callbacks for the
    // same renewal are still coalesced into one network request.
    final String inFlightKey =
        '${forceRefresh ? 'renew' : 'initial'}|$baseRequestKey';
    final Future<Map<String, dynamic>?>? running =
        _inFlightRequests[inFlightKey];
    if (running != null) return running;

    final Future<Map<String, dynamic>?> request = _performTokenRequest(
      requestKey: baseRequestKey,
      isBroadcaster: isBroadcaster,
      userId: userId,
      safeChannelName: safeChannelName,
      streamId: streamId,
      pkId: pkId,
      forceRefresh: forceRefresh,
    );

    _inFlightRequests[inFlightKey] = request;
    return request.whenComplete(() => _inFlightRequests.remove(inFlightKey));
  }

  Future<Map<String, dynamic>?> _performTokenRequest({
    required String requestKey,
    required bool isBroadcaster,
    required int userId,
    required String safeChannelName,
    required String streamId,
    required int? pkId,
    required bool forceRefresh,
  }) async {
    final Map<String, dynamic> data = <String, dynamic>{
      'channel_name': safeChannelName,
      'uid': userId,
      'livestream_id': streamId,
      if (pkId != null && pkId > 0) 'pk_id': pkId,
    };

    _loadingRequestCount++;
    tokenIsLoading.value = true;

    try {
      liveLog('=============== AGORA TOKEN REQUEST ===============');
      liveLog(
        '📤 URL => ${isBroadcaster ? kAgoraTokenGenerateBroadcaster : kAgoraTokenGenerateAudience}',
      );
      liveLog('📤 BODY => $data');
      liveLog('📤 ROLE => ${isBroadcaster ? 'broadcaster' : 'audience'}');
      liveLog('📤 FORCE REFRESH => $forceRefresh');

      final Response<dynamic> response = await dio.post(
        isBroadcaster
            ? kAgoraTokenGenerateBroadcaster
            : kAgoraTokenGenerateAudience,
        data: data,
        queryParameters: forceRefresh
            ? <String, dynamic>{
                '_renew_ts': DateTime.now().millisecondsSinceEpoch,
              }
            : null,
        options: Options(
          headers: <String, dynamic>{
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            if (forceRefresh) 'Cache-Control': 'no-cache, no-store',
            if (forceRefresh) 'Pragma': 'no-cache',
          },
          validateStatus: (int? status) => status != null && status < 500,
        ),
      );

      liveLog('📥 STATUS => ${response.statusCode}');
      liveLog('📥 Agora token response received');

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.data is! Map) {
          liveLog('⚠️ Agora token response is not a map');
          if (!forceRefresh) agoraToken.clear();
          return null;
        }

        final Map<String, dynamic> responseMap = Map<String, dynamic>.from(
          response.data as Map,
        );
        final String token = getTokenStringFrom(responseMap).trim();

        if (token.isEmpty) {
          liveLog('⚠️ Agora token missing from successful response');
          if (!forceRefresh) agoraToken.clear();
          return null;
        }

        // Keep backward compatibility for all existing screens that read the
        // observable map after calling tryToGenerateBroadcasterToken().
        agoraToken.value = responseMap;
        _lastSuccessfulRequestKey = requestKey;
        _lastSuccessfulAt = DateTime.now();

        liveLog('✅ Agora token generated successfully');
        liveLog('✅ token app_id => ${getAppIdStringFrom(responseMap)}');
        liveLog('✅ token channel => ${getChannelNameStringFrom(responseMap)}');
        liveLog('✅ token uid => ${getUidIntFrom(responseMap)}');
        liveLog('✅ token pk_id => ${responseMap['pk_id']}');
        liveLog('✅ token source => ${responseMap['source']}');
        liveLog(
          '✅ token expires_in => ${getExpiresInSecondsFrom(responseMap)}',
        );
        return responseMap;
      }

      if (!forceRefresh) agoraToken.clear();
      liveLog(
        '⚠️ Failed to generate agora token: status=${response.statusCode}',
      );
      return null;
    } on DioException catch (e) {
      // During renewal, keep the currently working token in memory. The Agora
      // service will retry before the active token expires.
      if (!forceRefresh) agoraToken.clear();
      liveLog(
        '❌ Agora token Dio error => status=${e.response?.statusCode} '
        'type=${e.type}',
      );
      return null;
    } catch (e) {
      if (!forceRefresh) agoraToken.clear();
      liveLog('❌ Agora token unexpected error => $e');
      return null;
    } finally {
      _loadingRequestCount--;
      if (_loadingRequestCount < 0) _loadingRequestCount = 0;
      tokenIsLoading.value = _loadingRequestCount > 0;
      liveLog('=============== AGORA TOKEN END ===================');
    }
  }

  String getTokenString() => getTokenStringFrom(agoraToken);

  String getTokenStringFrom(Map<String, dynamic> source) {
    final Map<String, dynamic> data = _nestedData(source);
    final dynamic token =
        source['token'] ??
        source['rtc_token'] ??
        source['agora_token'] ??
        data['token'] ??
        data['rtc_token'] ??
        data['agora_token'] ??
        '';
    return token?.toString() ?? '';
  }

  String getAppIdString() => getAppIdStringFrom(agoraToken);

  String getAppIdStringFrom(Map<String, dynamic> source) {
    final Map<String, dynamic> data = _nestedData(source);
    final dynamic appId = source['app_id'] ?? data['app_id'] ?? '';
    return appId?.toString() ?? '';
  }

  String getChannelNameString() => getChannelNameStringFrom(agoraToken);

  String getChannelNameStringFrom(Map<String, dynamic> source) {
    final Map<String, dynamic> data = _nestedData(source);
    final dynamic channel =
        source['channel_name'] ?? data['channel_name'] ?? '';
    return channel?.toString() ?? '';
  }

  int getUidInt() => getUidIntFrom(agoraToken);

  int getUidIntFrom(Map<String, dynamic> source) {
    final Map<String, dynamic> data = _nestedData(source);
    return int.tryParse((source['uid'] ?? data['uid'] ?? '').toString()) ?? 0;
  }

  int getExpiresInSeconds({int fallback = 3600}) {
    return getExpiresInSecondsFrom(agoraToken, fallback: fallback);
  }

  int getExpiresInSecondsFrom(
    Map<String, dynamic> source, {
    int fallback = 3600,
  }) {
    final Map<String, dynamic> data = _nestedData(source);
    final dynamic rawSeconds =
        source['expires_in'] ??
        source['expires_in_seconds'] ??
        source['token_expire_seconds'] ??
        source['expire_seconds'] ??
        source['privilege_expired_ts'] ??
        data['expires_in'] ??
        data['expires_in_seconds'] ??
        data['token_expire_seconds'] ??
        data['expire_seconds'] ??
        data['privilege_expired_ts'];

    final int parsedSeconds = int.tryParse(rawSeconds?.toString() ?? '') ?? 0;
    if (parsedSeconds > 0) {
      // Some backends return an absolute Unix timestamp instead of a duration.
      final int nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (parsedSeconds > nowSeconds + 60) {
        return (parsedSeconds - nowSeconds).clamp(60, 604800).toInt();
      }
      return parsedSeconds.clamp(60, 604800).toInt();
    }

    final dynamic rawExpiry =
        source['expires_at'] ??
        source['token_expires_at'] ??
        data['expires_at'] ??
        data['token_expires_at'];
    final DateTime? expiry = DateTime.tryParse(rawExpiry?.toString() ?? '');
    if (expiry != null) {
      final int seconds = expiry.difference(DateTime.now()).inSeconds;
      if (seconds > 0) return seconds.clamp(60, 604800).toInt();
    }

    return fallback;
  }

  Map<String, dynamic> _nestedData(Map<String, dynamic> source) {
    final dynamic rawData = source['data'];
    if (rawData is Map) {
      return Map<String, dynamic>.from(rawData);
    }
    return const <String, dynamic>{};
  }
}
