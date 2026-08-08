import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../../../apis/api_endpoints.dart';
import '../Models/family_models.dart';
import 'family_api_endpoints.dart' hide kFamilyLeave, kFamilyUpdate, kFamilyRequestAccept, kFamilyRequestReject, kFamilyRequestCancel, kFamilyMemberKick, kFamilyMemberRole, kFamilyLevelList, kFamilyCurrentLevel, kFamilyBadgeList, kFamilyAnnouncements, kFamilyCoinLogs, kFamilyContribute, kFamilyRequestList, kFamilyCreate, kFamilyJoin, kFamilyRanking, kFamilyDetail, kFamilyList, kFamilyMyFamily;

class FamilyApiException implements Exception {
  final String message;
  final int? statusCode;
  const FamilyApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class FamilyRepository {
  FamilyRepository({required String Function() tokenProvider}) : _tokenProvider = tokenProvider {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 18),
        receiveTimeout: const Duration(seconds: 18),
        sendTimeout: const Duration(seconds: 18),
        headers: const {'Accept': 'application/json'},
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _tokenProvider().trim();
          options.headers['Accept'] = 'application/json';
          if (token.isNotEmpty) options.headers['Authorization'] = 'Bearer $token';
          handler.next(options);
        },
      ),
    );
  }

  final String Function() _tokenProvider;
  late final Dio _dio;

  String get _baseUrlForImage {
    try {
      return kDomainUrl;
    } catch (_) {
      return '';
    }
  }

  dynamic _payload(dynamic body) {
    // Standard response: {status: true, message: '', data: ...}
    if (body is Map && body.containsKey('data')) return body['data'];
    return body;
  }

  /// Safely extracts list data from all API formats:
  /// 1) [ {...}, {...} ]
  /// 2) { data: [ {...}, {...} ] }
  /// 3) Laravel paginate: { data: { current_page: 1, data: [ {...} ] } }
  /// 4) Nested list keys used by some APIs: items/result/results/list
  List<dynamic> _payloadList(dynamic body) {
    dynamic value = body;

    for (int i = 0; i < 5; i++) {
      if (value is List) return value;

      if (value is Map) {
        final map = Map<dynamic, dynamic>.from(value);

        if (map['data'] is List) return map['data'] as List;

        if (map['data'] is Map) {
          final inner = Map<dynamic, dynamic>.from(map['data'] as Map);
          if (inner['data'] is List) return inner['data'] as List;
          if (inner['items'] is List) return inner['items'] as List;
          if (inner['result'] is List) return inner['result'] as List;
          if (inner['results'] is List) return inner['results'] as List;
          if (inner['list'] is List) return inner['list'] as List;
          value = inner;
          continue;
        }

        if (map['items'] is List) return map['items'] as List;
        if (map['result'] is List) return map['result'] as List;
        if (map['results'] is List) return map['results'] as List;
        if (map['list'] is List) return map['list'] as List;
      }

      break;
    }

    return <dynamic>[];
  }

  String _message(dynamic body, {String fallback = 'Something went wrong'}) {
    if (body is Map) {
      return (body['message'] ?? body['error'] ?? body['errors'] ?? fallback).toString();
    }
    return fallback;
  }

  void _check(Response response) {
    final code = response.statusCode ?? 0;
    if (code >= 200 && code < 300) return;
    if (code == 401) throw FamilyApiException('Session expired. Please login again.', statusCode: 401);
    if (code == 403) throw FamilyApiException('You do not have permission for this action.', statusCode: 403);
    if (code == 422) throw FamilyApiException(_message(response.data, fallback: 'Invalid information. Please check again.'), statusCode: 422);
    throw FamilyApiException(_message(response.data), statusCode: code);
  }

  Future<T> _request<T>(Future<Response> Function() call, T Function(dynamic body) parse) async {
    try {
      final response = await call();
      _check(response);
      return parse(response.data);
    } on FamilyApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout || e.type == DioExceptionType.sendTimeout) {
        throw const FamilyApiException('Network timeout. Please try again.');
      }
      if (e.type == DioExceptionType.connectionError) {
        throw const FamilyApiException('No internet connection.');
      }
      throw FamilyApiException(e.response == null ? 'Server connection failed.' : _message(e.response?.data));
    } catch (_) {
      throw const FamilyApiException('Unexpected error. Please try again.');
    }
  }

  Future<FamilyModel?> myFamily() {
    return _request(
          () => _dio.get(kFamilyMyFamily),
          (body) {
        final data = _payload(body);
        if (data == null || data == false || (data is Map && data.isEmpty)) return null;
        return FamilyModel.fromJson(data, baseUrl: _baseUrlForImage);
      },
    );
  }

  Future<List<FamilyModel>> familyList({String search = '', String sort = 'ranking', int page = 1, int perPage = 20}) {
    return _request(
          () => _dio.get(kFamilyList, queryParameters: {
        'search': search,
        'sort': sort,
        'page': page,
        'per_page': perPage,
      }),
          (body) => _payloadList(body).map((e) => FamilyModel.fromJson(e, baseUrl: _baseUrlForImage)).toList(),
    );
  }

  Future<FamilyModel> familyDetail(int familyId) {
    return _request(
          () => _dio.get(kFamilyDetail(familyId)),
          (body) => FamilyModel.fromJson(_payload(body), baseUrl: _baseUrlForImage),
    );
  }

  Future<List<FamilyModel>> ranking({int perPage = 50}) {
    return _request(
          () => _dio.get(kFamilyRanking, queryParameters: {'per_page': perPage}),
          (body) => _payloadList(body).map((e) => FamilyModel.fromJson(e, baseUrl: _baseUrlForImage)).toList(),
    );
  }

  Future<bool> joinFamily(int familyId, {String message = ''}) {
    return _request(
          () => _dio.post(kFamilyJoin(familyId), data: message.trim().isEmpty ? null : {'message': message.trim()}),
          (_) => true,
    );
  }

  Future<bool> leaveFamily() {
    return _request(() => _dio.post(kFamilyLeave), (_) => true);
  }

  Future<FamilyModel> createFamily({
    required String name,
    String familyCode = '',
    String description = '',
    String notice = '',
    String joinType = 'approval',
    String country = '',
    File? logo,
    File? cover,
  }) async {
    final form = await _familyFormData(
      name: name,
      familyCode: familyCode,
      description: description,
      notice: notice,
      joinType: joinType,
      country: country,
      logo: logo,
      cover: cover,
    );
    return _request(
          () => _dio.post(kFamilyCreate, data: form),
          (body) => FamilyModel.fromJson(_payload(body), baseUrl: _baseUrlForImage),
    );
  }

  Future<FamilyModel> updateFamily({
    required int familyId,
    required String name,
    String familyCode = '',
    String description = '',
    String notice = '',
    String joinType = 'approval',
    String country = '',
    File? logo,
    File? cover,
  }) async {
    final form = await _familyFormData(
      name: name,
      familyCode: familyCode,
      description: description,
      notice: notice,
      joinType: joinType,
      country: country,
      logo: logo,
      cover: cover,
    );
    return _request(
          () => _dio.post(kFamilyUpdate(familyId), data: form),
          (body) => FamilyModel.fromJson(_payload(body), baseUrl: _baseUrlForImage),
    );
  }

  Future<FormData> _familyFormData({
    required String name,
    required String familyCode,
    required String description,
    required String notice,
    required String joinType,
    required String country,
    File? logo,
    File? cover,
  }) async {
    final map = <String, dynamic>{
      'name': name,
      'family_code': familyCode,
      'description': description,
      'notice': notice,
      'join_type': joinType,
      'country': country,
    };
    if (logo != null) map['logo'] = await MultipartFile.fromFile(logo.path, filename: logo.path.split('/').last);
    if (cover != null) map['cover'] = await MultipartFile.fromFile(cover.path, filename: cover.path.split('/').last);
    return FormData.fromMap(map);
  }

  Future<List<FamilyRequestModel>> requestList({int? familyId, String status = ''}) {
    final query = <String, dynamic>{};
    if (familyId != null && familyId > 0) query['family_id'] = familyId;
    if (status.isNotEmpty) query['status'] = status;
    return _request(
          () => _dio.get(kFamilyRequestList, queryParameters: query),
          (body) => _payloadList(body).map((e) => FamilyRequestModel.fromJson(e, baseUrl: _baseUrlForImage)).toList(),
    );
  }

  Future<bool> acceptRequest(int requestId) => _request(() => _dio.post(kFamilyRequestAccept(requestId)), (_) => true);
  Future<bool> rejectRequest(int requestId) => _request(() => _dio.post(kFamilyRequestReject(requestId)), (_) => true);
  Future<bool> cancelRequest(int requestId) => _request(() => _dio.post(kFamilyRequestCancel(requestId)), (_) => true);
  Future<bool> kickMember(int memberId) => _request(() => _dio.post(kFamilyMemberKick(memberId)), (_) => true);

  Future<bool> changeMemberRole(int memberId, String role) {
    return _request(() => _dio.post(kFamilyMemberRole(memberId), data: {'role': role}), (_) => true);
  }

  Future<List<FamilyLevelModel>> levelList() {
    return _request(
          () => _dio.get(kFamilyLevelList),
          (body) => _payloadList(body).map((e) => FamilyLevelModel.fromJson(e, baseUrl: _baseUrlForImage)).toList(),
    );
  }

  Future<FamilyLevelModel?> currentLevel({required int points}) {
    return _request(
          () => _dio.get(kFamilyCurrentLevel, queryParameters: {'points': points}),
          (body) {
        final data = _payload(body);
        if (data == null) return null;
        return FamilyLevelModel.fromJson(data, baseUrl: _baseUrlForImage);
      },
    );
  }

  Future<List<FamilyBadgeModel>> badgeList() {
    return _request(
          () => _dio.get(kFamilyBadgeList),
          (body) => _payloadList(body).map((e) => FamilyBadgeModel.fromJson(e, baseUrl: _baseUrlForImage)).toList(),
    );
  }

  Future<List<FamilyAnnouncementModel>> announcements(int familyId) {
    return _request(
          () => _dio.get(kFamilyAnnouncements(familyId)),
          (body) => _payloadList(body).map((e) => FamilyAnnouncementModel.fromJson(e)).toList(),
    );
  }

  Future<List<FamilyCoinLogModel>> coinLogs() {
    return _request(
          () => _dio.get(kFamilyCoinLogs),
          (body) => _payloadList(body).map((e) => FamilyCoinLogModel.fromJson(e)).toList(),
    );
  }

  Future<bool> contribute({required int points, int coins = 0, required String actionType, String note = ''}) {
    return _request(
          () => _dio.post(kFamilyContribute, data: {
        'points': points,
        'coins': coins,
        'action_type': actionType,
        'note': note,
      }),
          (_) => true,
    );
  }
}
