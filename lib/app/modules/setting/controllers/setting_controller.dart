import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;
import 'package:get_storage/get_storage.dart';
import 'package:meetlivepro/app/modules/auth/controllers/auth_controller.dart';

import '../../../../apis/api_endpoints.dart';

class SettingController {
  SettingController()
      : _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 25),
      headers: const <String, dynamic>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );

  final Dio _dio;

  final TextEditingController newPasswordController =
  TextEditingController();
  final TextEditingController confirmPasswordController =
  TextEditingController();

  final RxBool isLoading = false.obs;
  final RxBool hideNewPassword = true.obs;
  final RxBool hideConfirmPassword = true.obs;

  final RxString newPasswordError = ''.obs;
  final RxString confirmPasswordError = ''.obs;
  final RxString generalError = ''.obs;
  final RxString successMessage = 'Password changed successfully.'.obs;

  String get firstVisibleError {
    if (newPasswordError.value.trim().isNotEmpty) {
      return newPasswordError.value.trim();
    }

    if (confirmPasswordError.value.trim().isNotEmpty) {
      return confirmPasswordError.value.trim();
    }

    if (generalError.value.trim().isNotEmpty) {
      return generalError.value.trim();
    }

    return 'Unable to change password. Please try again.';
  }

  void toggleNewPasswordVisibility() {
    hideNewPassword.value = !hideNewPassword.value;
  }

  void toggleConfirmPasswordVisibility() {
    hideConfirmPassword.value = !hideConfirmPassword.value;
  }

  void onNewPasswordChanged(String _) {
    newPasswordError.value = '';
    generalError.value = '';

    if (confirmPasswordController.text.isNotEmpty) {
      _validateConfirmPassword(showEmptyError: false);
    }
  }

  void onConfirmPasswordChanged(String _) {
    confirmPasswordError.value = '';
    generalError.value = '';
  }

  bool validateForm() {
    generalError.value = '';

    final bool newPasswordValid = _validateNewPassword();
    final bool confirmPasswordValid = _validateConfirmPassword();

    return newPasswordValid && confirmPasswordValid;
  }

  bool _validateNewPassword() {
    final String password = newPasswordController.text;

    if (password.trim().isEmpty) {
      newPasswordError.value = 'New password is required.';
      return false;
    }

    if (password.length < 6) {
      newPasswordError.value =
      'New password must be at least 6 characters.';
      return false;
    }

    newPasswordError.value = '';
    return true;
  }

  bool _validateConfirmPassword({bool showEmptyError = true}) {
    final String password = newPasswordController.text;
    final String confirmPassword = confirmPasswordController.text;

    if (confirmPassword.trim().isEmpty) {
      if (showEmptyError) {
        confirmPasswordError.value = 'Confirm password is required.';
      }
      return false;
    }

    if (password != confirmPassword) {
      confirmPasswordError.value =
      'New password and confirm password do not match.';
      return false;
    }

    confirmPasswordError.value = '';
    return true;
  }

  Future<bool> changePassword() async {
    if (isLoading.value) return false;

    if (!validateForm()) {
      return false;
    }

    final String token = _readAccessToken();

    if (token.isEmpty) {
      generalError.value =
      'Your login session has expired. Please login again.';
      return false;
    }

    try {
      isLoading.value = true;
      generalError.value = '';

      final Response<dynamic> response = await _dio.post(
        passwordSet,
        data: <String, dynamic>{
          'new_password': newPasswordController.text,
          'confirm_password': confirmPasswordController.text,
        },
        options: Options(
          headers: <String, dynamic>{
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          validateStatus: (int? status) {
            return status != null && status >= 200 && status < 600;
          },
        ),
      );

      debugPrint('CHANGE PASSWORD URL: $passwordSet');
      debugPrint('CHANGE PASSWORD STATUS: ${response.statusCode}');
      debugPrint('CHANGE PASSWORD RESPONSE: ${response.data}');

      final Map<String, dynamic> responseData = _asMap(response.data);
      final int statusCode = response.statusCode ?? 0;

      if ((statusCode == 200 || statusCode == 201) &&
          _isSuccessfulResponse(responseData)) {
        successMessage.value = _messageFrom(
          responseData,
          fallback: 'Password changed successfully.',
        );
        return true;
      }

      _applyServerError(
        statusCode: statusCode,
        responseData: responseData,
      );
      return false;
    } on DioException catch (error) {
      debugPrint('CHANGE PASSWORD DIO ERROR TYPE: ${error.type}');
      debugPrint(
        'CHANGE PASSWORD DIO STATUS: ${error.response?.statusCode}',
      );
      debugPrint(
        'CHANGE PASSWORD DIO RESPONSE: ${error.response?.data}',
      );

      final Map<String, dynamic> responseData =
      _asMap(error.response?.data);

      if (responseData.isNotEmpty) {
        _applyServerError(
          statusCode: error.response?.statusCode ?? 0,
          responseData: responseData,
        );
      } else {
        generalError.value = _dioErrorMessage(error);
      }

      return false;
    } catch (error, stackTrace) {
      debugPrint('CHANGE PASSWORD ERROR: $error');
      debugPrintStack(stackTrace: stackTrace);

      generalError.value =
      'Something went wrong. Please try again.';
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  String _readAccessToken() {
    try {
      final GetStorage storage = GetStorage();

      const List<String> tokenKeys = <String>[
        'access_token',
        'token',
        'auth_token',
      ];

      for (final String key in tokenKeys) {
        final dynamic savedToken = storage.read<dynamic>(key);
        final String token = savedToken?.toString().trim() ?? '';

        if (token.isNotEmpty && token.toLowerCase() != 'null') {
          return token.replaceFirst(
            RegExp(r'^Bearer\s+', caseSensitive: false),
            '',
          );
        }
      }
    } catch (error) {
      debugPrint('PASSWORD TOKEN STORAGE ERROR: $error');
    }

    try {
      if (Get.isRegistered<AuthController>()) {
        final AuthController authController =
        Get.find<AuthController>();

        final String token = authController
            .userProfile.value.token
            ?.toString()
            .trim() ??
            '';

        if (token.isNotEmpty && token.toLowerCase() != 'null') {
          return token.replaceFirst(
            RegExp(r'^Bearer\s+', caseSensitive: false),
            '',
          );
        }
      }
    } catch (error) {
      debugPrint('PASSWORD AUTH TOKEN ERROR: $error');
    }

    return '';
  }

  bool _isSuccessfulResponse(Map<String, dynamic> responseData) {
    if (!responseData.containsKey('success')) {
      return true;
    }

    final dynamic success = responseData['success'];

    return success == true ||
        success == 1 ||
        success?.toString().toLowerCase() == 'true' ||
        success?.toString() == '1';
  }

  void _applyServerError({
    required int statusCode,
    required Map<String, dynamic> responseData,
  }) {
    newPasswordError.value = '';
    confirmPasswordError.value = '';
    generalError.value = '';

    final Map<String, dynamic> errors =
    _asMap(responseData['errors']);

    final String newPasswordServerError =
    _firstValidationError(errors['new_password']);
    final String confirmPasswordServerError =
    _firstValidationError(errors['confirm_password']);

    if (newPasswordServerError.isNotEmpty) {
      newPasswordError.value = newPasswordServerError;
    }

    if (confirmPasswordServerError.isNotEmpty) {
      confirmPasswordError.value = confirmPasswordServerError;
    }

    if (statusCode == 401 || statusCode == 403) {
      generalError.value =
      'Your login session has expired. Please login again.';
      return;
    }

    if (newPasswordError.value.isNotEmpty ||
        confirmPasswordError.value.isNotEmpty) {
      return;
    }

    generalError.value = _messageFrom(
      responseData,
      fallback: statusCode >= 500
          ? 'Server error. Please try again later.'
          : 'Unable to change password. Please try again.',
    );
  }

  String _dioErrorMessage(DioException error) {
    final String typeName = error.type.toString().toLowerCase();

    if (typeName.contains('timeout')) {
      return 'Connection timeout. Please check your internet connection.';
    }

    if (typeName.contains('connectionerror')) {
      return 'No internet connection. Please try again.';
    }

    if (typeName.contains('badcertificate')) {
      return 'Secure connection failed. Please try again later.';
    }

    if (typeName.contains('cancel')) {
      return 'Request was cancelled.';
    }

    if (typeName.contains('badresponse')) {
      return 'Unable to complete the request. Please try again.';
    }

    return 'Unable to connect to the server. Please try again.';
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return <String, dynamic>{};
  }

  String _firstValidationError(dynamic value) {
    if (value is List && value.isNotEmpty) {
      return value.first.toString().trim();
    }

    if (value is String) {
      return value.trim();
    }

    return '';
  }

  String _messageFrom(
      Map<String, dynamic> responseData, {
        required String fallback,
      }) {
    final dynamic value =
        responseData['message'] ?? responseData['error'];
    final String message = value?.toString().trim() ?? '';

    return message.isEmpty ? fallback : message;
  }

  void clearForm() {
    newPasswordController.clear();
    confirmPasswordController.clear();
    newPasswordError.value = '';
    confirmPasswordError.value = '';
    generalError.value = '';
    hideNewPassword.value = true;
    hideConfirmPassword.value = true;
  }

  void dispose() {
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    _dio.close(force: true);
  }
}
