import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart' hide FormData, MultipartFile;


import '../../../../apis/api_endpoints.dart';
import '../../../../constants/color_constants.dart';
import '../../../../constants/constants.dart';
import '../../bottomnav/views/bottomnav_view.dart';
import '../../store/controllers/store1_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class MomentsController extends GetxController {
  static const int minimumPostCoinBalance = 500;

  Store1Controller store1controller = Get.put(Store1Controller());

  Map<String, dynamic> _objectToMap(dynamic value) {
    if (value == null) {
      return <String, dynamic>{};
    }

    if (value is Map) {
      return value.map(
            (key, item) => MapEntry(key.toString(), item),
      );
    }

    try {
      final dynamic json = value.toJson();
      if (json is Map) {
        return json.map(
              (key, item) => MapEntry(key.toString(), item),
        );
      }
    } catch (_) {}

    try {
      final dynamic decoded = jsonDecode(jsonEncode(value));
      if (decoded is Map) {
        return decoded.map(
              (key, item) => MapEntry(key.toString(), item),
        );
      }
    } catch (_) {}

    return <String, dynamic>{};
  }

  int? _coinValueFromMap(Map<String, dynamic> data) {
    const balanceKeys = <String>[
      'coin',
      'coins',
      'balance',
      'coin_balance',
      'coinBalance',
      'wallet_balance',
      'walletBalance',
      'available_coin',
      'availableCoin',
      'total_coin',
      'totalCoin',
    ];

    for (final key in balanceKeys) {
      if (!data.containsKey(key)) {
        continue;
      }

      final dynamic rawValue = data[key];
      if (rawValue is num) {
        return rawValue.toInt();
      }

      final normalizedValue = rawValue
          ?.toString()
          .replaceAll(',', '')
          .trim();
      final parsedValue = int.tryParse(normalizedValue ?? '');
      if (parsedValue != null) {
        return parsedValue;
      }
    }

    const nestedKeys = <String>[
      'wallet',
      'user_wallet',
      'userWallet',
      'account',
      'data',
      'user',
    ];

    for (final key in nestedKeys) {
      final nestedMap = _objectToMap(data[key]);
      if (nestedMap.isEmpty) {
        continue;
      }

      final nestedBalance = _coinValueFromMap(nestedMap);
      if (nestedBalance != null) {
        return nestedBalance;
      }
    }

    return null;
  }

  int get currentUserCoinBalance {
    final userProfile = authController.userProfile.value;
    final userMap = _objectToMap(userProfile.user);
    final profileMap = _objectToMap(userProfile);

    return _coinValueFromMap(userMap) ??
        _coinValueFromMap(profileMap) ??
        0;
  }

  bool canCreatePost({bool showMessage = true}) {
    final balance = currentUserCoinBalance;
    final canPost = balance >= minimumPostCoinBalance;

    if (!canPost && showMessage) {
      Fluttertoast.showToast(
        msg:
        'You need at least $minimumPostCoinBalance coins to create a post. Current balance: $balance',

      );
    }

    return canPost;
  }

  final isLoading = false.obs;
  final _dio = Dio();

  final postList = [].obs;

  Future getPostList() async {
    final data = await _dio.get(
      kPostListUrl,
      options: Options(
        headers: {
          'Authorization': 'Bearer ${authController.userProfile.value.token}',
        },
      ),
    );

    postList.value = data.data['data'];
  }

  var followStatus = <String, bool>{}.obs;

  void followUser(String userId) {
    followStatus[userId] = true;
    // Call API
    momentsController.followCreate(userId: userId);
  }

  void unfollowUser(String userId) {
    followStatus[userId] = false;
    // Call API
    momentsController.unFollowCreate(id: int.parse(userId));
  }

  bool isFollowing(String userId) {
    return followStatus[userId] ?? false;
  }

  RxBool isFollowing1 = false.obs;

  ///-------------------------follow create -------------------
  final dio = Dio();
  final followData = {}.obs;
  void followCreate({required String userId}) async {
    final data = {
      'following_id': userId,
    };
    try {
      print(kFollowCteate);
      print('follow data $data');
      final response = await dio.post(
        kFollowCteate,
        data: data,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },
        ),
      );
      if (response.statusCode == 200) {
        followData.value = response.data;
        isFollowing1.value = true;

        // ✅ Keep follower/following pages realtime with Moments follow action.
        final int followedUserId = int.tryParse(userId.toString()) ?? 0;
        if (followedUserId > 0) {
          store1controller.followingUserIds.add(followedUserId);
          store1controller.followingUserIds.refresh();
          store1controller.totalFollowingCount.value =
              store1controller.totalFollowingCount.value + 1;
          store1controller.showFollowingList(silent: true);
        }

        Fluttertoast.showToast(
          msg: ("Follow Success").appTr,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          fontSize: 12.0,
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

  ///----------------------------------Follower list show ----------------------
  final momentAllFollowerList = [].obs;

  Future showAllFollowerList() async {
    try {
      final data = await dio.get(
        kMomentFollowerList,
      );
      momentAllFollowerList.value =
          data.data['follow_data'] ?? []; // initially same
    } catch (e) {
      print("Error: $e");
    }
  }

  ///----------------------------- Unfollow create ------------------
  final unfollowData = {}.obs;
  Future unFollowCreate({required int id}) async {
    try {
      print(unFollowUrl(id));
      final response = await dio.get(
        unFollowUrl(id),
        options: Options(
          headers: {
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },
        ),
      );

      if (response.statusCode == 200) {
        unfollowData.value = response.data;

        // ✅ Keep follower/following pages realtime with Moments unfollow action.
        store1controller.followingUserIds.remove(id);
        store1controller.followingUserIds.refresh();
        store1controller.followingList.removeWhere(
              (item) => store1controller.userIdFromFollowingItem(item) == id,
        );
        store1controller.filteredFollowingList.removeWhere(
              (item) => store1controller.userIdFromFollowingItem(item) == id,
        );
        if (store1controller.totalFollowingCount.value > 0) {
          store1controller.totalFollowingCount.value =
              store1controller.totalFollowingCount.value - 1;
        }

        Fluttertoast.showToast(
          msg: ("UnFollow Success").appTr,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          fontSize: 12.0,
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
    } catch (e) {}
  }

  ///---------------------------- post create --------------------------
  final postData = {}.obs;
  final titleController = TextEditingController();
  final discriptionController = TextEditingController();
  final selectImageController = ''.obs;

  Future postCreate() async {
    // Minimum 500 spendable coins are required to create a post.
    if (!canCreatePost()) {
      return;
    }

    // 🔹 validation check
    if (titleController.text.trim().isEmpty) {
      Fluttertoast.showToast(
        msg: ("Title required").appTr,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: kAppColor,
        textColor: Colors.white,
        fontSize: 12.0,
      );
      return; // stop execution
    }

    if (allPickedImage.isEmpty) {
      Fluttertoast.showToast(
        msg: ("Please select at least 1 image").appTr,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.orange,
        textColor: Colors.white,
        fontSize: 12.0,
      );
      return; // stop execution
    }

    isLoading.value = true;
    await Future.delayed(const Duration(seconds: 2));
    try {
      // Convert all picked images to MultipartFile
      List<MultipartFile> imageFiles = await Future.wait(
        allPickedImage.map(
              (path) =>
              MultipartFile.fromFile(path, filename: path.split('/').last),
        ),
      );

      // Build form data properly
      FormData data = FormData();
      data.fields.add(MapEntry('title', titleController.text));
      data.fields.add(MapEntry('description', 'halo'));

      // 🔹 add images one by one with correct field name
      for (var file in imageFiles) {
        data.files.add(MapEntry('post[]', file));
      }

      final response = await dio.post(
        kPostCreateUrl,
        data: data,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },
        ),
      );

      if (response.statusCode == 200) {
        isLoading.value = false;
        postData.value = response.data;

        Fluttertoast.showToast(
          msg: ("Post Success").appTr,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          fontSize: 12.0,
        );

        Get.offAll(BottomnavView(), transition: Transition.rightToLeft);
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
      print("Upload error: $e");
      Get.snackbar(
        ('Failed').appTr,
        ("Something went wrong").appTr,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  // single pick file

  final pickedImage = ''.obs; // Store file path as String

  Future<void> singleFilePicker() async {
    //file  ta k sudhu show korar jonno
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );
    pickedImage.value = result!.files.single.path!; // Store paths
  }

  void createAssets() async {
    if (pickedImage.value.isEmpty) {
      Get.snackbar(
        ('Error').appTr,
        ("Please select an image").appTr,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    try {
      // Create a FormData object
      FormData formData = FormData.fromMap({
        'name': 'alamin',
        'price': '500',
        'type': 'all',
        'status': 'active',
        'asset': await MultipartFile.fromFile(
          pickedImage.value,
          filename: "upload.jpg",
        ),
      });
      print(kAssetCreateUrl);

      final response = await dio.post(kAssetCreateUrl, data: formData);
      print(response.data);
      if (response.statusCode == 200) {
        Get.snackbar(
          ('Success').appTr,
          ("Image uploaded successfully!").appTr,
          backgroundColor: Colors.green,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        Get.snackbar(
          ('Failed').appTr,
          ("Upload failed. Try again.").appTr,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      print(e);
      Get.snackbar(
        ('Failed').appTr,
        ("Something went wrong: $e").appTr,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  var allPickedImage = <String>[].obs; // Store file paths as a list of Strings

  Future<void> allFilePicker() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );

    if (result != null) {
      allPickedImage.value =
          result.files.map((file) => file.path!).toList(); // Store paths
    }
  }

  ///--------------------------------  Post Like Create ----------------------------

  final likeData = {}.obs;
  void likeCreate({required String postId}) async {
    final data = {
      'post_id': postId,
    };
    print('Alamin');
    print(data);
    try {
      print(kLikeCreate);
      if (kDebugMode) {
        final String token =
            authController.userProfile.value.token?.toString().trim() ?? '';
        debugPrint(
          'Moments auth: token_present=${token.isNotEmpty} '
          'token_length=${token.length}',
        );
      }
      final response = await dio.post(
        kLikeCreate,
        data: data,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },
        ),
      );
      if (response.statusCode == 200) {
        likeData.value = response.data;
        await getPostList();
        print('Like Data $likeData');
        Fluttertoast.showToast(
          msg: ("Like Success").appTr,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          fontSize: 12.0,
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
      Get.snackbar(
        ('Failed').appTr,
        ("Something went wrong").appTr,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  final reactionData = {}.obs;

  void reactionCreate({
    required String postId,
    required String reactionType,
  }) async {
    final data = {
      'post_id': postId,
      'reaction_type': reactionType,
    };

    print("Reaction API Call: $data");

    try {
      final response = await dio.post(
        kLikeCreate,
        data: data,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },
        ),
      );

      if (response.statusCode == 200) {
        reactionData.value = response.data;

        /// Reload post list to refresh UI
        await getPostList();

        Fluttertoast.showToast(
          msg: ("Reaction updated").appTr,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          fontSize: 12.0,
        );
      } else {
        Get.snackbar(
          ('Failed').appTr,
          ("Failed to react.").appTr,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      Get.snackbar(
        ('Failed').appTr,
        ("Something went wrong").appTr,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  ///---------------------------- DisLike Create ---------------------
  final disLikeData = {}.obs;
  void disLikeCreate({required int id}) async {
    try {
      print('UnLike Id  ${unLikeUrl(id)}');
      final response = await dio.get(
        unLikeUrl(id),
        options: Options(
          headers: {
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },
        ),
      );
      if (response.statusCode == 200) {
        disLikeData.value = response.data;
        await getPostList();
        Fluttertoast.showToast(
          msg: ("Dis like Success").appTr,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          fontSize: 12.0,
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
      Get.snackbar(
        ('Failed').appTr,
        ("Something went wrong").appTr,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  ///-------------------------- comment create ---------------------------
  final comment = TextEditingController();
  final commentData = {}.obs;
  void commentCreate({required String postId, required int postIndex}) async {
    final data = {
      'post_id': postId,
      'comment': comment.text,
    };
    try {
      print(data);
      print(kCommentCreate);
      final response = await dio.post(
        kCommentCreate,
        data: data,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },
        ),
      );
      if (response.statusCode == 200) {
        commentData.value = response.data;
        print(commentData);
        Fluttertoast.showToast(
          msg: ("comment Success").appTr,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          fontSize: 12.0,
        );
        print(response.data['comment']);
        postList[postIndex]['comments'].add(response.data['comment']);
        postList.refresh();
        print('success');
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
      Get.snackbar(
        ('Failed').appTr,
        ("Something went wrong").appTr,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

///------------------- show comment list -------------------
}
