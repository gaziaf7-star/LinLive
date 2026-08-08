import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart' hide Response;
import 'package:meetlivepro/app/localization/app_localizer.dart';

import '../../../../../apis/api_endpoints.dart';
import '../../../../../constants/constants.dart';


class BaishunGameController extends GetxController {
  BaishunGameController({
    Dio? dio,
    this.roomId = '',
    this.gameMode = '3',
  }) : _dio = dio ??
      Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 25),
          sendTimeout: const Duration(seconds: 20),
          headers: const <String, dynamic>{
            'Accept': 'application/json',
          },
        ),
      );

  final Dio _dio;
  final String roomId;
  final String gameMode;

  final RxList<BaishunGame> games = <BaishunGame>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isRefreshing = false.obs;
  final RxInt openingGameId = 0.obs;
  final RxString errorMessage = ''.obs;

  String get _token =>
      authController.userProfile.value.token?.toString().trim() ?? '';

  @override
  void onInit() {
    super.onInit();
    loadGames();
  }

  Future<void> loadGames({bool refresh = false}) async {
    if (isLoading.value || isRefreshing.value) return;

    if (refresh) {
      isRefreshing.value = true;
    } else {
      isLoading.value = true;
    }

    errorMessage.value = '';

    try {
      final String token = _token;
      if (token.isEmpty) {
        throw const BaishunGameException(
          'Login session not found. Please login again.',
        );
      }

      final Response<dynamic> response = await _dio.get<dynamic>(
        '$kMainUrl/baishun/games',
        options: Options(
          headers: <String, dynamic>{
            'Authorization': 'Bearer $token',
          },
        ),
      );

      final Map<String, dynamic> body = _asMap(response.data);
      if (body['success'] != true) {
        throw BaishunGameException(
          _firstNonEmpty(<dynamic>[
            body['message'],
            'Unable to load games.',
          ]),
        );
      }

      final List<dynamic> rawGames = body['data'] is List<dynamic>
          ? body['data'] as List<dynamic>
          : const <dynamic>[];

      final List<BaishunGame> parsedGames = rawGames
          .whereType<Map<dynamic, dynamic>>()
          .map(
            (Map<dynamic, dynamic> item) => BaishunGame.fromJson(
          Map<String, dynamic>.from(item),
        ),
      )
          .where((BaishunGame game) => game.ready)
          .toList(growable: false);

      games.assignAll(parsedGames);

      if (games.isEmpty) {
        errorMessage.value = ('No games are available right now.').appTr;
      }
    } on DioException catch (error, stackTrace) {
      debugPrint('BAISHUN GAME LIST ERROR => $error');
      debugPrint('$stackTrace');
      errorMessage.value = _dioMessage(error);
    } on BaishunGameException catch (error) {
      errorMessage.value = error.message.appTr;
    } catch (error, stackTrace) {
      debugPrint('BAISHUN GAME LIST UNKNOWN ERROR => $error');
      debugPrint('$stackTrace');
      errorMessage.value = ('Failed to load games. Please try again.').appTr;
    } finally {
      isLoading.value = false;
      isRefreshing.value = false;
    }
  }

  Future<BaishunGameSession?> createSession(BaishunGame game) async {
    if (openingGameId.value != 0) return null;

    openingGameId.value = game.gameId;

    try {
      final String token = _token;
      if (token.isEmpty) {
        throw const BaishunGameException(
          'Login session not found. Please login again.',
        );
      }

      final Response<dynamic> response = await _dio.post<dynamic>(
        '$kMainUrl/baishun/sessions',
        data: <String, dynamic>{
          'game_id': game.gameId,
          'room_id': roomId,
          'game_mode': gameMode,
          'language': '2',
          'scene_mode': 0,
        },
        options: Options(
          headers: <String, dynamic>{
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      final Map<String, dynamic> body = _asMap(response.data);
      if (body['success'] != true) {
        throw BaishunGameException(
          _firstNonEmpty(<dynamic>[
            body['message'],
            'Unable to start the game.',
          ]),
        );
      }

      final Map<String, dynamic> data = _asMap(body['data']);
      final BaishunGameSession session = BaishunGameSession.fromJson(data);

      if (session.launchUrl.isEmpty || session.getConfig.isEmpty) {
        throw const BaishunGameException(
          'Game session data is incomplete.',
        );
      }

      return session;
    } on DioException catch (error, stackTrace) {
      debugPrint('BAISHUN GAME SESSION ERROR => $error');
      debugPrint('$stackTrace');
      _showError(_dioMessage(error));
    } on BaishunGameException catch (error) {
      _showError(error.message.appTr);
    } catch (error, stackTrace) {
      debugPrint('BAISHUN GAME SESSION UNKNOWN ERROR => $error');
      debugPrint('$stackTrace');
      _showError(('Failed to start the game. Please try again.').appTr);
    } finally {
      openingGameId.value = 0;
    }

    return null;
  }

  void _showError(String message) {
    Get.snackbar(
      ('Game Error').appTr,
      message,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 4),
    );
  }

  String _dioMessage(DioException error) {
    final Map<String, dynamic> responseBody = _asMap(error.response?.data);
    final String serverMessage = _firstNonEmpty(<dynamic>[
      responseBody['message'],
      responseBody['error'],
    ]);

    if (serverMessage.isNotEmpty) return serverMessage.appTr;

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ('Connection timeout. Please try again.').appTr;
      case DioExceptionType.connectionError:
        return ('No internet connection. Please try again.').appTr;
      case DioExceptionType.badCertificate:
        return ('Secure connection failed.').appTr;
      case DioExceptionType.cancel:
        return ('Request cancelled.').appTr;
      case DioExceptionType.badResponse:
        if (error.response?.statusCode == 401) {
          return ('Login expired. Please login again.').appTr;
        }
        return ('Server error. Please try again.').appTr;
      case DioExceptionType.unknown:
      default:
        return ('Failed to connect to the game server.').appTr;
    }
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map<dynamic, dynamic>) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  static String _firstNonEmpty(List<dynamic> values) {
    for (final dynamic value in values) {
      final String text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return '';
  }
}

class BaishunGame {
  const BaishunGame({
    required this.gameId,
    required this.name,
    required this.previewUrl,
    required this.gameVersion,
    required this.downloadUrl,
    required this.gameModes,
    required this.gameOrientation,
    required this.safeHeight,
    required this.ready,
  });

  final int gameId;
  final String name;
  final String previewUrl;
  final String gameVersion;
  final String downloadUrl;
  final List<int> gameModes;
  final int gameOrientation;
  final int safeHeight;
  final bool ready;

  factory BaishunGame.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawModes = json['game_modes'] is List<dynamic>
        ? json['game_modes'] as List<dynamic>
        : const <dynamic>[];

    return BaishunGame(
      gameId: int.tryParse(json['game_id']?.toString() ?? '') ?? 0,
      name: json['name']?.toString().trim() ?? 'Game',
      previewUrl: json['preview_url']?.toString().trim() ?? '',
      gameVersion: json['game_version']?.toString().trim() ?? '',
      downloadUrl: json['download_url']?.toString().trim() ?? '',
      gameModes: rawModes
          .map((dynamic item) => int.tryParse(item.toString()) ?? 0)
          .where((int item) => item > 0)
          .toList(growable: false),
      gameOrientation:
      int.tryParse(json['game_orientation']?.toString() ?? '') ?? 1,
      safeHeight: int.tryParse(json['safe_height']?.toString() ?? '') ?? 0,
      ready: json['ready'] == true || json['ready']?.toString() == '1',
    );
  }
}

class BaishunGameSession {
  const BaishunGameSession({
    required this.game,
    required this.launchUrl,
    required this.downloadUrl,
    required this.gameVersion,
    required this.getConfig,
    required this.codeExpiresInSeconds,
  });

  final BaishunGame game;
  final String launchUrl;
  final String downloadUrl;
  final String gameVersion;
  final Map<String, dynamic> getConfig;
  final int codeExpiresInSeconds;

  String get userId => getConfig['userId']?.toString() ?? '';

  factory BaishunGameSession.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> gameJson =
    BaishunGameController._asMap(json['game']);

    return BaishunGameSession(
      game: BaishunGame.fromJson(gameJson),
      launchUrl: json['launch_url']?.toString().trim() ?? '',
      downloadUrl: json['download_url']?.toString().trim() ?? '',
      gameVersion: json['game_version']?.toString().trim() ?? '',
      getConfig: BaishunGameController._asMap(json['get_config']),
      codeExpiresInSeconds:
      int.tryParse(json['code_expires_in_seconds']?.toString() ?? '') ??
          120,
    );
  }
}

class BaishunGameException implements Exception {
  const BaishunGameException(this.message);

  final String message;

  @override
  String toString() => message;
}
