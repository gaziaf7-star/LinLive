import 'package:country_picker/country_picker.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart' hide FormData, MultipartFile;
import 'package:image_picker/image_picker.dart';

import '../../../../apis/api_endpoints.dart';
import '../../../../constants/constants.dart';
import '../../registersteps/controllers/registersteps_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class MyprofileController extends GetxController {
  final dio = Dio();

  var selectedCountry = Rx<Country>(
    Country(
      countryCode: 'BD',
      phoneCode: '880',
      e164Sc: 0,
      geographic: true,
      level: 1,
      name: 'Bangladesh',
      example: '',
      displayName: 'Bangladesh',
      displayNameNoCountryCode: 'Bangladesh',
      e164Key: '',
    ),
  );

  final profileGiftList = [].obs;
  final profileGiftReceverList = [].obs;
  final profileContributionList = [].obs;

  /// ✅ Profile page family card data
  final profileFamilyData = Rxn<Map<String, dynamic>>();
  final isProfileFamilyLoading = false.obs;
  final profileFamilyError = ''.obs;

  final isLoading = false.obs;
  final isProfileSaving = false.obs;

  final profileUpdateData = {}.obs;

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();

  final selectedGender = ''.obs;

  var profileImage = ''.obs;
  final picProfileImage = ''.obs;
  final picProfileImageCover = ''.obs;

  @override
  void onInit() {
    super.onInit();
    syncProfileFormFromAuth(force: true);
  }

  @override
  void onClose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    super.onClose();
  }

  Options _authOptions() {
    return Options(
      headers: {
        'Authorization': 'Bearer ${authController.userProfile.value.token}',
        'Accept': 'application/json',
      },
    );
  }

  void syncProfileFormFromAuth({bool force = false}) {
    final user = authController.userProfile.value.user;
    if (user == null) return;

    if (force || nameController.text.trim().isEmpty) {
      nameController.text = user.name?.toString() ?? '';
    }

    if (force || emailController.text.trim().isEmpty) {
      emailController.text = user.email?.toString() ?? '';
    }

    if (force || phoneController.text.trim().isEmpty) {
      phoneController.text = user.phone?.toString() ?? '';
    }

    final gender = user.gender?.toString() ?? '';
    if (force || selectedGender.value.trim().isEmpty) {
      if (gender.toLowerCase() == 'male') {
        selectedGender.value = ('Male').appTr;
      } else if (gender.toLowerCase() == 'female') {
        selectedGender.value = ('Female').appTr;
      } else {
        selectedGender.value = '';
      }
    }

    final country = user.country?.toString() ?? '';
    if (country.trim().isNotEmpty &&
        country.toLowerCase() != 'null' &&
        country.toLowerCase() != 'add country') {
      selectedCountry.value = Country(
        countryCode: '',
        phoneCode: '',
        e164Sc: 0,
        geographic: true,
        level: 1,
        name: country,
        example: '',
        displayName: country,
        displayNameNoCountryCode: country,
        e164Key: '',
      );
    }
  }

  Future<void> _refreshAuthUserSilently() async {
    try {
      if (Get.isRegistered<RegisterstepsController>()) {
        await Get.find<RegisterstepsController>().refreshAuthUserData();
      } else {
        await registerstepsController.refreshAuthUserData();
      }
    } catch (_) {
      authController.userProfile.refresh();
    }
  }

  void _patchAuthUserLocally({
    required String name,
    required String email,
    required String phone,
    required String gender,
    required String country,
  }) {
    try {
      final dynamic user = authController.userProfile.value.user;
      if (user == null) return;

      user.name = name;
      user.email = email;
      user.phone = phone;
      user.gender = gender;
      user.country = country;

      authController.userProfile.refresh();
    } catch (_) {
      authController.userProfile.refresh();
    }
  }

  Future showProfileGiftList() async {
    isLoading.value = true;
    try {
      final response = await dio.get(
        kProfileGiftList,
        options: _authOptions(),
      );

      if (response.statusCode == 200) {
        profileGiftList.value = response.data['giftsr_data'] ?? [];
        isLoading.value = false;
      } else {
        isLoading.value = false;
        Get.snackbar(
          ('Failed').appTr,
          ("Your credentials doesn't match.").appTr,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      isLoading.value = false;
      Fluttertoast.showToast(
        msg: ("Something went wrong").appTr,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  //user family Profile

  Future<Map<String, dynamic>?> showProfileFamilyData({required String userID}) async {
    final uid = userID.toString().trim();

    if (uid.isEmpty || uid == 'null') {
      profileFamilyData.value = null;
      profileFamilyError.value = '';
      return null;
    }

    isProfileFamilyLoading.value = true;
    profileFamilyError.value = '';

    try {
      final response = await dio.get(
        userFamily(id: uid),
        options: _authOptions(),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data;
        final dynamic data = body is Map ? body['data'] : null;

        if (data is Map && data.isNotEmpty) {
          final map = Map<String, dynamic>.from(data);
          profileFamilyData.value = map;
          return map;
        }

        profileFamilyData.value = null;
        return null;
      }

      profileFamilyData.value = null;
      profileFamilyError.value = 'Family not found';
      return null;
    } on DioException catch (e) {
      profileFamilyData.value = null;

      final code = e.response?.statusCode ?? 0;
      if (code == 404 || code == 204) {
        profileFamilyError.value = '';
        return null;
      }

      profileFamilyError.value = ('Something went wrong').appTr;

      // Profile card optional, tai no-family/server issue hole pura profile disturb korbe na.
      Fluttertoast.showToast(
        msg: ("Something went wrong").appTr,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      return null;
    } catch (e) {
      profileFamilyData.value = null;
      profileFamilyError.value = ('Something went wrong').appTr;

      Fluttertoast.showToast(
        msg: ("Something went wrong").appTr,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      return null;
    } finally {
      isProfileFamilyLoading.value = false;
    }
  }


  Future showProfileReciverList({required String  userID}) async {
    isLoading.value = true;
    try {
      final response = await dio.get(
        kProfileReceverList(id: userID),
        options: _authOptions(),
      );

      if (response.statusCode == 200) {
        profileGiftReceverList.value = response.data['giftsr_data'] ?? [];
        isLoading.value = false;
      } else {
        isLoading.value = false;
        Get.snackbar(
          ('Failed').appTr,
          ("Your credentials doesn't match.").appTr,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      isLoading.value = false;
      Fluttertoast.showToast(
        msg: ("Something went wrong").appTr,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  Future<void> showProfileContributionList({
    required String userId,
    String key = 'all',
  }) async {
    isLoading.value = true;
    try {
      final response = await dio.get(
        kProfileCombinationList(userId: userId.toString(), key: key),
        options: _authOptions(),
      );

      if (response.statusCode == 200) {
        profileContributionList.value = response.data['giftsr_data'] ?? [];
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: ("Something went wrong").appTr,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    } finally {
      isLoading.value = false;
    }
  }
  Future<void> profileUpdate({required int id}) async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final phone = phoneController.text.trim();
    final gender = selectedGender.value.trim();
    final country = selectedCountry.value.name.trim();

    if (name.isEmpty) {
      Fluttertoast.showToast(
        msg: ("Name required").appTr,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      return;
    }

    isProfileSaving.value = true;

    final data = {
      'name': name,
      'email': email,
      'phone': phone,
      'gender': gender,
      'country': country,
    };

    try {
      final response = await dio.post(
        kProfileUpdate(id: id),
        data: data,
        options: _authOptions(),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        profileUpdateData.value = response.data;

        _patchAuthUserLocally(
          name: name,
          email: email,
          phone: phone,
          gender: gender,
          country: country,
        );

        await _refreshAuthUserSilently();

        Fluttertoast.showToast(
          msg: ("Profile updated successfully ✅").appTr,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      } else {
        Fluttertoast.showToast(
          msg: ("Profile update failed ❌").appTr,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      }
    } on DioException catch (e) {
      String msg = "Profile update failed";

      if (e.response != null) {
        final data = e.response?.data;
        if (data is Map && data['message'] != null) {
          msg = data['message'].toString();
        } else {
          msg = ("Server error: ${e.response?.statusCode}").appTr;
        }
      } else {
        msg = ("Network error: ${e.message}").appTr;
      }

      Fluttertoast.showToast(
        msg: msg,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: ("Unexpected error: $e").appTr,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    } finally {
      isProfileSaving.value = false;
    }
  }

  Future<void> profileImageUpdate({required int id}) async {
    if (profileImage.value.isEmpty) {
      Fluttertoast.showToast(
        msg: ("Please select image first").appTr,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      return;
    }

    FormData data = FormData.fromMap({
      'profile_image': await MultipartFile.fromFile(
        profileImage.value,
        filename: "upload.jpg",
      ),
    });

    try {
      final response = await dio.post(
        kProfileUpdate(id: id),
        data: data,
        options: _authOptions(),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        profileUpdateData.value = response.data;

        await _refreshAuthUserSilently();
        authController.userProfile.refresh();

        Fluttertoast.showToast(
          msg: ("Profile image updated ✅").appTr,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      } else {
        Fluttertoast.showToast(
          msg: ("Profile image update failed ❌").appTr,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      }
    } on DioException catch (e) {
      Fluttertoast.showToast(
        msg: e.response != null
            ? ("Server error: ${e.response?.statusCode}").appTr: ("Network error: ${e.message}").appTr,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: ("Image update error: $e").appTr,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  Future<void> updateProfile() async {
    final ImagePicker picker = ImagePicker();

    await Get.bottomSheet(
      SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.camera_alt,
                color: Colors.white,
              ),
              title:  Text(
                ('Take Photo').appTr,
                style: TextStyle(color: Colors.white),
              ),
              onTap: () async {
                Get.back();

                final XFile? photo = await picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 50,
                );

                if (photo != null) {
                  profileImage.value = photo.path;

                  final id = authController.userProfile.value.user?.id?.toInt();
                  if (id != null) {
                    profileImageUpdate(id: id);
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: Colors.white,
              ),
              title:  Text(
                ('Choose from Gallery').appTr,
                style: TextStyle(color: Colors.white),
              ),
              onTap: () async {
                Get.back();

                final XFile? photo = await picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 50,
                );

                if (photo != null) {
                  profileImage.value = photo.path;

                  final id = authController.userProfile.value.user?.id?.toInt();
                  if (id != null) {
                    profileImageUpdate(id: id);
                  }
                }
              },
            ),
          ],
        ),
      ),
      backgroundColor: const Color(0xff8A4CF7),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    );
  }

  Future<void> updateProfileCover() async {
    final ImagePicker picker = ImagePicker();

    await Get.bottomSheet(
      SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.camera_alt,
                color: Colors.white,
              ),
              title:  Text(
                ('Take Photo').appTr,
                style: TextStyle(color: Colors.white),
              ),
              onTap: () async {
                Get.back();

                final XFile? photo = await picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 50,
                );

                if (photo != null) {
                  picProfileImageCover.value = photo.path;

                  final id = authController.userProfile.value.user?.id?.toInt();
                  if (id != null) {
                    profileImageCoverUpdate(id: id);
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: Colors.white,
              ),
              title:  Text(
                ('Choose from Gallery').appTr,
                style: TextStyle(color: Colors.white),
              ),
              onTap: () async {
                Get.back();

                final XFile? photo = await picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 50,
                );

                if (photo != null) {
                  picProfileImageCover.value = photo.path;

                  final id = authController.userProfile.value.user?.id?.toInt();
                  if (id != null) {
                    profileImageCoverUpdate(id: id);
                  }
                }
              },
            ),
          ],
        ),
      ),
      backgroundColor: const Color(0xff8A4CF7),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    );
  }

  Future<void> profileImageCoverUpdate({required int id}) async {
    if (picProfileImageCover.value.isEmpty) {
      Fluttertoast.showToast(
        msg: ("Please select cover image first").appTr,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      return;
    }

    FormData data = FormData.fromMap({
      'cover_images': await MultipartFile.fromFile(
        picProfileImageCover.value,
        filename: "cover.jpg",
      ),
    });

    try {
      final response = await dio.post(
        kProfileUpdate(id: id),
        data: data,
        options: _authOptions(),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        profileUpdateData.value = response.data;

        await _refreshAuthUserSilently();
        authController.userProfile.refresh();

        Fluttertoast.showToast(
          msg: ("Cover updated ✅").appTr,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      } else {
        Fluttertoast.showToast(
          msg: ("Cover update failed ❌").appTr,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      }
    } on DioException catch (e) {
      Fluttertoast.showToast(
        msg: e.response != null
            ? ("Server error: ${e.response?.statusCode}").appTr: ("Network error: ${e.message}").appTr,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: ("Cover update error: $e").appTr,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }
}