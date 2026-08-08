import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart' hide FormData, MultipartFile;
import 'package:image_picker/image_picker.dart';

import '../../../../apis/api_endpoints.dart';
import '../../../../constants/constants.dart';
import '../views/agencySuccessPage.dart';

import '../../verified/controllers/verified_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class InformationcollectionController extends GetxController {
  final VerifiedController verifiedController = Get.put(VerifiedController());
  final Dio dio = Dio();

  final agencyData = {}.obs;
  final RxBool agencyHomeLoading = false.obs;
  final RxString agencyHomeError = ''.obs;
  bool _agencyHomeLoaded = false;

  static const String _authAgencyHomeUrl = '$kMainUrl/auth_agency_home';
  static const String _agencyDeleteHostUrl = '$kMainUrl/agency_delete_host';

  final RxInt currentAgencyId = 0.obs;
  final RxInt deletingHostId = 0.obs;

  final agencyName = TextEditingController();

  // Creator ID হিসেবে user_id দেখাতে চাইলে userId রাখুন।
  // যদি database id দিতে চান, তাহলে .user!.id.toString() করবেন।
  final agencyId = TextEditingController(
    text: authController.userProfile.value.user!.userId.toString(),
  );

  final whatsappNumber = TextEditingController();
  final email = TextEditingController();
  final address = TextEditingController();

  final ownerSearchController = TextEditingController();

  final RxBool isFormFilled = false.obs;
  final RxBool createLoading = false.obs;
  final RxBool ownerLoading = false.obs;

  // শুধু profile image path থাকবে
  final RxString profileImagePath = ''.obs;

  final allPermissionOwners = <Map<String, dynamic>>[].obs;
  final filteredPermissionOwners = <Map<String, dynamic>>[].obs;

  final selectedOwner = Rxn<Map<String, dynamic>>();
  final RxString selectedOwnerId = ''.obs;
  final RxString selectedOwnerName = ''.obs;
  final RxString selectedOwnerRole = ''.obs;
  final RxString selectedOwnerImage = ''.obs;

  Map<String, String> get _authHeaders => {
    'Authorization': 'Bearer ${authController.userProfile.value.token}',
    'Accept': 'application/json',
  };

  @override
  void onInit() {
    super.onInit();

    agencyName.addListener(validateForm);
    agencyId.addListener(validateForm);
    whatsappNumber.addListener(validateForm);
    email.addListener(validateForm);
    address.addListener(validateForm);
    ownerSearchController.addListener(_filterPermissionOwnerList);

    showAuthAgencyHome();
  }


  Map<String, dynamic> _mapFrom(dynamic raw) {
    try {
      if (raw is Map) {
        return raw.map<String, dynamic>(
              (key, value) => MapEntry(key.toString(), value),
        );
      }
    } catch (_) {}

    return <String, dynamic>{};
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString().replaceAll(',', '').trim()) ?? 0;
  }

  int agencyHostIdFrom(dynamic item) {
    final map = _mapFrom(item);
    final hostMap = _mapFrom(map['host']);
    final userMap = _mapFrom(map['user']);

    return _toInt(
      map['host_id'] ??
          map['id'] ??
          hostMap['host_id'] ??
          hostMap['id'] ??
          userMap['host_id'],
    );
  }

  bool _sameAgencyHost(dynamic item, int hostId) {
    if (hostId <= 0) return false;
    return agencyHostIdFrom(item) == hostId;
  }

  int _readCurrentAgencyIdFromHome() {
    final home = _mapFrom(agencyData);
    final data = _mapFrom(home['data']);
    final agency = _mapFrom(data['agency']).isNotEmpty ? _mapFrom(data['agency']) : data;
    final authUser = _mapFrom(data['auth_user']);

    return _toInt(
      agency['agency_id'] ??
          authUser['user_id'] ??
          data['agency_id'] ??
          agency['id'],
    );
  }

  String _messageFromResponse(dynamic body, String fallback) {
    if (body is Map && body['message'] != null) {
      final message = body['message'].toString().trim();
      if (message.isNotEmpty && message != 'null') return message;
    }
    return fallback;
  }

  Future<void> showAuthAgencyHome({bool force = false}) async {
    if (agencyHomeLoading.value) return;
    if (!force && _agencyHomeLoaded && agencyData.isNotEmpty) return;

    try {
      agencyHomeLoading.value = true;
      agencyHomeError.value = '';

      final response = await dio.get(
        _authAgencyHomeUrl,
        options: Options(
          headers: _authHeaders,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      final body = response.data;

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (body is Map) {
          final parsed = body.map<String, dynamic>(
                (key, value) => MapEntry(key.toString(), value),
          );

          agencyData
            ..clear()
            ..assignAll(parsed);
          _agencyHomeLoaded = true;

          final data = _mapFrom(parsed['data']);
          final agency = _mapFrom(data['agency']).isNotEmpty
              ? _mapFrom(data['agency'])
              : data;
          final authUser = _mapFrom(data['auth_user']);

          final int resolvedAgencyId = _toInt(
            agency['agency_id'] ??
                authUser['user_id'] ??
                data['agency_id'] ??
                agency['id'],
          );

          if (resolvedAgencyId > 0) {
            currentAgencyId.value = resolvedAgencyId;
            showRequestAgenctList(agencyId: resolvedAgencyId);
            showAgencyHostList(agencyId: resolvedAgencyId);
          }
        } else {
          agencyHomeError.value = 'Invalid agency home data';
        }
      } else {
        agencyHomeError.value = _messageFromResponse(
          body,
          ("Your credentials doesn't match.").appTr,
        );
      }
    } on DioException catch (e) {
      print('Auth agency home Dio error: ${e.response?.data ?? e.message}');
      agencyHomeError.value = _messageFromResponse(
        e.response?.data,
        'Unable to load agency data',
      );
    } catch (e, stackTrace) {
      print('Auth agency home error: $e');
      print(stackTrace);
      agencyHomeError.value = ('Something went wrong').appTr;
    } finally {
      agencyHomeLoading.value = false;
    }
  }

  void validateForm() {
    // Permission Owner optional. তাই selectedOwnerId validation-এ নেই।
    isFormFilled.value =
        agencyName.text.trim().isNotEmpty &&
            agencyId.text.trim().isNotEmpty &&
            whatsappNumber.text.trim().isNotEmpty &&
            address.text.trim().isNotEmpty &&
            profileImagePath.value.trim().isNotEmpty;
  }

  String imageUrl(dynamic value) {
    final img = value?.toString().trim() ?? '';

    if (img.isEmpty || img == 'No Photo' || img == 'null') {
      return '';
    }

    if (img.startsWith('http://') || img.startsWith('https://')) {
      return img;
    }

    return 'https://linlive.fr/$img';
  }

  String roleText(Map<String, dynamic> user) {
    final values = [
      user['user_type'],
      user['agency_type'],
      user['reseler_type'],
      user['host_type'],
      user['designation'],
    ].map((e) => e?.toString().toLowerCase().trim() ?? '').toList();

    if (values.contains('super_admin') || values.contains('super admin')) {
      return ('Super Admin').appTr;
    }

    if (values.contains('bd_admin') || values.contains('bd admin')) {
      return ('BD Admin').appTr;
    }

    return 'Admin';
  }

  bool isPermissionOwner(Map<String, dynamic> user) {
    final values = [
      user['user_type'],
      user['agency_type'],
      user['reseler_type'],
      user['host_type'],
      user['designation'],
    ].map((e) => e?.toString().toLowerCase().trim() ?? '').toList();

    return values.contains('super_admin') ||
        values.contains('super admin') ||
        values.contains('bd_admin') ||
        values.contains('bd admin');
  }

  Future<void> showPermissionOwnerList() async {
    try {
      ownerLoading.value = true;

      final response = await dio.get(
        kAllUserList,
        options: Options(headers: _authHeaders),
      );

      final dynamic body = response.data;
      final dynamic data = body is Map ? body['data'] : body;

      if (data is List) {
        final list = data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .where(isPermissionOwner)
            .toList();

        allPermissionOwners.assignAll(list);
        filteredPermissionOwners.assignAll(list);
      } else {
        allPermissionOwners.clear();
        filteredPermissionOwners.clear();
      }
    } on DioException catch (e) {
      print('Owner list Dio error: ${e.response?.data}');

    } catch (e) {
      print('Owner list error: $e');
      Fluttertoast.showToast(
        msg: ('Something went wrong').appTr,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      ownerLoading.value = false;
    }
  }

  void _filterPermissionOwnerList() {
    final query = ownerSearchController.text.toLowerCase().trim();

    if (query.isEmpty) {
      filteredPermissionOwners.assignAll(allPermissionOwners);
      return;
    }

    filteredPermissionOwners.assignAll(
      allPermissionOwners.where((user) {
        final name = user['name']?.toString().toLowerCase() ?? '';
        final id = user['id']?.toString().toLowerCase() ?? '';
        final userId = user['user_id']?.toString().toLowerCase() ?? '';
        final phone = user['phone']?.toString().toLowerCase() ?? '';
        final country = user['country']?.toString().toLowerCase() ?? '';
        final role = roleText(user).toLowerCase();

        return name.contains(query) ||
            id.contains(query) ||
            userId.contains(query) ||
            phone.contains(query) ||
            country.contains(query) ||
            role.contains(query);
      }).toList(),
    );
  }

  void selectPermissionOwner(Map<String, dynamic> user) {
    selectedOwner.value = user;

    // এই database id যাবে permisiononerid field এ
    selectedOwnerId.value = user['id']?.toString() ?? '';

    selectedOwnerName.value = user['name']?.toString() ?? ('Unknown').appTr;
    selectedOwnerRole.value = roleText(user);
    selectedOwnerImage.value = imageUrl(user['profile_image']);

    validateForm();

    Get.back();

    Fluttertoast.showToast(
      msg: ('${selectedOwnerRole.value} selected').appTr,
      backgroundColor: Colors.green,
      textColor: Colors.white,
    );
  }

  Future<void> pickProfileImage() async {
    final ImagePicker picker = ImagePicker();

    await Get.bottomSheet(
      SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.white),
              title:  Text(
                ('Take Profile Photo').appTr,
                style: TextStyle(color: Colors.white),
              ),
              onTap: () async {
                Get.back();

                final XFile? photo = await picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 70,
                  maxWidth: 900,
                );

                if (photo != null) {
                  profileImagePath.value = photo.path;
                  validateForm();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white),
              title:  Text(
                ('Choose Profile Image').appTr,
                style: TextStyle(color: Colors.white),
              ),
              onTap: () async {
                Get.back();

                final XFile? photo = await picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 70,
                  maxWidth: 900,
                );

                if (photo != null) {
                  profileImagePath.value = photo.path;
                  validateForm();
                }
              },
            ),
          ],
        ),
      ),
      backgroundColor: const Color(0xff8A4CF7),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
    );
  }

  Future<void> createAgency() async {
    if (!isFormFilled.value) {
      Fluttertoast.showToast(
        msg: ('Please fill all required fields').appTr,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    if (createLoading.value) return;

    try {
      createLoading.value = true;

      final Map<String, dynamic> formMap = {
        'name': agencyName.text.trim(),
        'agency_id': agencyId.text.trim(),
        'email': email.text.trim(),
        'phone': whatsappNumber.text.trim(),
        'address': address.text.trim(),
        'profile_image': await MultipartFile.fromFile(
          profileImagePath.value,
          filename: 'profile_image.jpg',
        ),
      };

      // Permission Owner select করলে শুধু তখনই field পাঠানো হবে।
      // Select না করলে permisiononerid request-এর মধ্যে থাকবে না।
      if (selectedOwnerId.value.trim().isNotEmpty) {
        formMap['permisiononerid'] = selectedOwnerId.value.trim();
      }

      final FormData data = FormData.fromMap(formMap);

      print('=== Agency Create FormData Fields ===');
      for (final field in data.fields) {
        print('${field.key}: ${field.value}');
      }

      print('=== Agency Create FormData Files ===');
      for (final file in data.files) {
        print('${file.key}: ${file.value.filename}');
      }

      final response = await dio.post(
        kAgencyPostUrl,
        data: data,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
            'Accept': 'application/json',
            'Content-Type': 'multipart/form-data',
          },
          validateStatus: (status) => status != null && status < 500,
          followRedirects: false,
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        agencyData.value = response.data;

        Fluttertoast.showToast(
          msg: ('Agency create success').appTr,
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );

        await verifiedController.showNewAgenctList();
        await showAuthAgencyHome(force: true);

        Get.offAll(
              () => AgencySuccessView(
            agencyName: agencyName.text.trim(),
            creatorId: agencyId.text.trim(),
          ),
          transition: Transition.fadeIn,
        );
      } else {
        print('=== Agency Create Error Response ===');
        print(response.statusCode);
        print(response.data);

        Fluttertoast.showToast(
          msg: response.data is Map && response.data['message'] != null
              ? response.data['message'].toString()
              : ("Your credentials doesn't match.").appTr,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } catch (e, stackTrace) {
      print('=== Agency Create Exception ===');
      print(e);
      print(stackTrace);

      Fluttertoast.showToast(
        msg: ('Something went wrong').appTr,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      createLoading.value = false;
    }
  }

  ///----------------------- Agency Request List -----------------------

  final newAgencyRequestList = [].obs;

  Future<void> showRequestAgenctList({required int agencyId}) async {
    try {
      final response = await dio.get(
        kAgencyRequestListUrl(id: agencyId),
        options: Options(
          headers: {
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = _mapFrom(response.data);
        final data = _mapFrom(body['data']);
        final hostRequests = data['hostRequests'];

        if (hostRequests is List) {
          newAgencyRequestList.assignAll(hostRequests);
        } else {
          newAgencyRequestList.clear();
        }


      } else {
        Fluttertoast.showToast(
          msg: ("Your credentials doesn't match.").appTr,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      print(e);

      Fluttertoast.showToast(
        msg: ('Something went wrong').appTr,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  final newAgencyhostList = [].obs;
  final newAgencyManthly = [].obs;

  Future<void> showAgencyHostList({required int agencyId}) async {
    try {

      final response = await dio.get(
        kAgencyHostListUrl(id: agencyId),

        options: Options(
          headers: {
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = _mapFrom(response.data);
        final data = _mapFrom(body['data']);
        final dailyUsers = data['daily_sorted_users'];
        final monthlyUsers = data['monthly_sorted_users'];

        if (dailyUsers is List) {
          newAgencyhostList.assignAll(dailyUsers);
        } else {
          newAgencyhostList.clear();
        }

        if (monthlyUsers is List) {
          newAgencyManthly.assignAll(monthlyUsers);
        } else {
          newAgencyManthly.clear();
        }


      } else {

      }
    } catch (e) {
      print(e);

      Fluttertoast.showToast(
        msg: ('Something went wrong').appTr,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  Future<bool> deleteAgencyHost({required int hostId}) async {
    if (hostId <= 0) {
      Fluttertoast.showToast(
        msg: ('Host id not found').appTr,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return false;
    }

    if (deletingHostId.value == hostId) return false;

    final oldRequestList = List<dynamic>.from(newAgencyRequestList);
    final oldDailyList = List<dynamic>.from(newAgencyhostList);
    final oldMonthlyList = List<dynamic>.from(newAgencyManthly);

    try {
      deletingHostId.value = hostId;

      // Fast UI update: remove first, then sync with real API response.
      newAgencyRequestList.removeWhere((item) => _sameAgencyHost(item, hostId));
      newAgencyhostList.removeWhere((item) => _sameAgencyHost(item, hostId));
      newAgencyManthly.removeWhere((item) => _sameAgencyHost(item, hostId));

      final response = await dio.post(
        _agencyDeleteHostUrl,
        data: {'host_id': hostId},
        options: Options(
          headers: {
            ..._authHeaders,
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      final body = response.data;
      final okStatus = response.statusCode == 200 || response.statusCode == 201;
      final apiSuccess = body is Map ? body['success'] != false : true;

      if (okStatus && apiSuccess) {
        Fluttertoast.showToast(
          msg: _messageFromResponse(body, 'Host delete success'),
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );

        await showAuthAgencyHome(force: true);

        final int agencyId = currentAgencyId.value > 0
            ? currentAgencyId.value
            : _readCurrentAgencyIdFromHome();

        if (agencyId > 0) {
          await showRequestAgenctList(agencyId: agencyId);
          await showAgencyHostList(agencyId: agencyId);
        }

        return true;
      }

      newAgencyRequestList.assignAll(oldRequestList);
      newAgencyhostList.assignAll(oldDailyList);
      newAgencyManthly.assignAll(oldMonthlyList);

      Fluttertoast.showToast(
        msg: _messageFromResponse(body, 'Host delete failed'),
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return false;
    } on DioException catch (e) {
      newAgencyRequestList.assignAll(oldRequestList);
      newAgencyhostList.assignAll(oldDailyList);
      newAgencyManthly.assignAll(oldMonthlyList);

      print('Agency host delete Dio error: ${e.response?.data ?? e.message}');
      Fluttertoast.showToast(
        msg: _messageFromResponse(e.response?.data, 'Host delete failed'),
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return false;
    } catch (e, stackTrace) {
      newAgencyRequestList.assignAll(oldRequestList);
      newAgencyhostList.assignAll(oldDailyList);
      newAgencyManthly.assignAll(oldMonthlyList);

      print('Agency host delete error: $e');
      print(stackTrace);
      Fluttertoast.showToast(
        msg: ('Something went wrong').appTr,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return false;
    } finally {
      if (deletingHostId.value == hostId) {
        deletingHostId.value = 0;
      }
    }
  }

  final agencyAcept = {}.obs;

  void AceptCreate({required int hostId}) async {
    final data = {
      'host_id': hostId,
    };

    try {
      final response = await dio.post(
        kAgencyAceptUrl,
        data: data,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        agencyAcept.value = response.data;

        final body = _mapFrom(response.data);
        final host = _mapFrom(body['Host']);
        final int agencyId = _toInt(host['agency_id']) > 0
            ? _toInt(host['agency_id'])
            : currentAgencyId.value;

        if (agencyId > 0) {
          currentAgencyId.value = agencyId;
          await showRequestAgenctList(agencyId: agencyId);
          await showAgencyHostList(agencyId: agencyId);
        }

        await showAuthAgencyHome(force: true);

        Fluttertoast.showToast(
          msg: ('Accept Success').appTr,
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
      } else {
        Get.snackbar(
          ('Failed').appTr,
          ("Your credentials doesn't match.").appTr,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      print(e);
    }
  }

  final agencyReject = {}.obs;

  void ARejectCreate({required int hostId}) async {
    final data = {
      'host_id': hostId,
    };

    try {
      final response = await dio.post(
        kAgencyRejectUrl,
        data: data,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        agencyReject.value = response.data;

        final body = _mapFrom(response.data);
        final host = _mapFrom(body['Host']);
        final int agencyId = _toInt(host['agency_id']) > 0
            ? _toInt(host['agency_id'])
            : currentAgencyId.value;

        if (agencyId > 0) {
          currentAgencyId.value = agencyId;
          await showRequestAgenctList(agencyId: agencyId);
          await showAgencyHostList(agencyId: agencyId);
        }

        await showAuthAgencyHome(force: true);

        Fluttertoast.showToast(
          msg: ('Reject Success').appTr,
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
      } else {
        Get.snackbar(
          ('Failed').appTr,
          ("Your credentials doesn't match.").appTr,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      print(e);
    }
  }

  @override
  void dispose() {
    agencyName.dispose();
    agencyId.dispose();
    whatsappNumber.dispose();
    email.dispose();
    address.dispose();
    ownerSearchController.dispose();
    super.dispose();
  }
}