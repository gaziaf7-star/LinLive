import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meetlivepro/app/modules/appmenu/views/widgets/imageColor.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../constants/constants.dart';
import '../../../../constants/image_helper.dart';
import '../../../../constants/layout_constant.dart';
import '../../../../widgets/after/CastomText.dart';
import '../../trading/views/tradingsend.dart';
import '../controllers/reseller_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';

class ResellerView extends StatefulWidget {
  const ResellerView({super.key});

  @override
  State<ResellerView> createState() => _ResellerViewState();
}

class _ResellerViewState extends State<ResellerView> {
  late final ResellerController resellerController;

  Map<String, dynamic>? selectedUser;
  Timer? _searchDebounce;
  bool _searchingUser = false;
  bool _userNotFound = false;
  int _searchRequestId = 0;

  @override
  void initState() {
    super.initState();
    resellerController = Get.isRegistered<ResellerController>()
        ? Get.find<ResellerController>()
        : Get.put(ResellerController());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureUsersLoaded();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _ensureUsersLoaded() async {
    if (homeController.allUserData.isNotEmpty) return;

    try {
      await homeController.showAllUserData();
    } catch (e) {
      debugPrint('❌ Initial user list load failed => $e');
    }
  }

  void _onUserIdChanged(String value) {
    _searchDebounce?.cancel();

    final String uid = value.trim();
    if (uid.isEmpty) {
      _searchRequestId++;
      if (!mounted) return;
      setState(() {
        selectedUser = null;
        _searchingUser = false;
        _userNotFound = false;
      });
      return;
    }

    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
          () => searchUser(uid),
    );
  }

  Future<void> searchUser(String uid) async {
    final String cleanUid = uid.trim();
    final int requestId = ++_searchRequestId;

    if (cleanUid.isEmpty) {
      if (!mounted) return;
      setState(() {
        selectedUser = null;
        _searchingUser = false;
        _userNotFound = false;
      });
      return;
    }

    if (mounted) {
      setState(() {
        _searchingUser = true;
        _userNotFound = false;
      });
    }

    Map<String, dynamic>? foundUser;

    try {
      // প্রথমে বর্তমানে load থাকা list থেকে খুঁজবে।
      foundUser = _findUserById(cleanUid);

      // List এখনো load না হলে API load শেষ হওয়া পর্যন্ত অপেক্ষা করবে।
      if (foundUser == null && homeController.allUserData.isEmpty) {
        await homeController.showAllUserData();
        foundUser = _findUserById(cleanUid);
      }

      // পুরোনো/stale list হলে একবার fresh data নিয়ে আবার খুঁজবে।
      if (foundUser == null) {
        try {
          await homeController.showAllUserData();
          foundUser = _findUserById(cleanUid);
        } catch (e) {
          debugPrint('⚠️ Fresh user list reload failed => $e');
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Search user error => $e');
      debugPrint('$stackTrace');
    }

    if (!mounted || requestId != _searchRequestId) return;

    setState(() {
      selectedUser = foundUser;
      _searchingUser = false;
      _userNotFound = foundUser == null;
    });

    debugPrint('🔎 Search UID => $cleanUid');
    debugPrint('👤 Selected user => $foundUser');
  }

  Map<String, dynamic>? _findUserById(String uid) {
    final String target = _normalizeId(uid);
    if (target.isEmpty) return null;

    for (final dynamic raw in homeController.allUserData) {
      final Map<String, dynamic> user = _normalizeUser(raw);
      if (user.isEmpty) continue;

      final String candidateId = _normalizeId(_userId(user));
      if (candidateId == target) {
        return user;
      }
    }

    return null;
  }

  Map<String, dynamic> _normalizeUser(dynamic raw) {
    final Map<String, dynamic> root = _asMap(raw);
    if (root.isEmpty) return <String, dynamic>{};

    for (final String key in const <String>[
      'user',
      'profile',
      'member',
      'receiver',
      'sender',
      'account',
    ]) {
      final Map<String, dynamic> nested = _asMap(root[key]);
      if (nested.isNotEmpty) {
        return <String, dynamic>{
          ...root,
          ...nested,
        };
      }
    }

    return root;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  String _normalizeId(dynamic value) {
    final String text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') return '';

    // Numeric ID হলে starting zero বাদ দিয়ে একই ID হিসেবে match করবে।
    final int? numeric = int.tryParse(text);
    return numeric?.toString() ?? text.toLowerCase();
  }

  String _userId(Map<String, dynamic> user) {
    return _firstText(<dynamic>[
      user['user_id'],
      user['uid'],
      user['unique_id'],
      user['userId'],
      user['id'],
      _asMap(user['profile'])['user_id'],
      _asMap(user['profile'])['id'],
    ]);
  }

  String _userName(Map<String, dynamic> user) {
    final String directName = _firstText(<dynamic>[
      user['name'],
      user['full_name'],
      user['display_name'],
      user['nickname'],
      user['user_name'],
      user['username'],
    ]);

    if (directName.isNotEmpty) return directName;

    final String firstName = _cleanText(
      user['first_name'] ?? user['fast_name'],
    );
    final String lastName = _cleanText(user['last_name']);
    final String combined = '$firstName $lastName'.trim();

    return combined.isEmpty ? 'N/A' : combined;
  }

  String _userLevel(Map<String, dynamic> user) {
    final Map<String, dynamic> levelMap = _asMap(user['level']);

    return _firstText(<dynamic>[
      user['level_no'],
      user['level_number'],
      user['current_level'],
      levelMap['level_no'],
      levelMap['level'],
      levelMap['title'],
      user['level'],
    ], fallback: 'N/A');
  }

  String _userImage(Map<String, dynamic> user) {
    final Map<String, dynamic> profile = _asMap(user['profile']);

    final String raw = _firstText(<dynamic>[
      user['profile_image_url'],
      user['profile_image'],
      user['avatar_url'],
      user['avatar'],
      user['image_url'],
      user['image'],
      profile['profile_image_url'],
      profile['profile_image'],
      profile['avatar'],
      profile['image'],
    ]);

    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;

    return ImageHelper.getImageUrl(raw);
  }

  String _firstText(List<dynamic> values, {String fallback = ''}) {
    for (final dynamic value in values) {
      final String text = _cleanText(value);
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }

  String _cleanText(dynamic value) {
    if (value == null) return '';
    final String text = value.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return '';
    return text;
  }

  Widget _buildUserSearchResult(BuildContext context) {
    if (_searchingUser) {
      return _buildUserShimmer();
    }

    final Map<String, dynamic>? user = selectedUser;
    if (user != null) {
      return _buildUserCard(context, user);
    }

    if (_userNotFound) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withOpacity(.18)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_search_rounded, color: Colors.red),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                ('User not found').appTr,
                textAlign: TextAlign.center,
                style: GoogleFonts.roboto(
                  fontSize: Get.height * 0.013,
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildUserShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.grey[300],
        ),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 105, height: 11, color: Colors.white),
                  const SizedBox(height: 6),
                  Container(width: 135, height: 10, color: Colors.white),
                  const SizedBox(height: 6),
                  Container(width: 90, height: 10, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(
      BuildContext context,
      Map<String, dynamic> user,
      ) {
    final String imageUrl = _userImage(user);
    final String id = _userId(user);
    final String name = _userName(user);
    final String level = _userLevel(user);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.grey[100],
      ),
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      child: Row(
        children: [
          _UserAvatar(imageUrl: imageUrl),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Castontext(
                  fontSize: Get.height * 0.014,
                  fontWeight: FontWeight.w600,
                  textColor: Colors.black.withOpacity(.65),
                  text: 'ID: ${id.isEmpty ? 'N/A' : id}',
                ),
                const SizedBox(height: 4),
                Castontext(
                  fontSize: Get.height * 0.0135,
                  fontWeight: FontWeight.w500,
                  textColor: Colors.black.withOpacity(.65),
                  text: 'Name: $name',
                ),
                const SizedBox(height: 4),
                Text(
                  'Level: $level',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool showResultArea =
        _searchingUser || selectedUser != null || _userNotFound;
    final double cardHeight = showResultArea
        ? (_userNotFound && !_searchingUser ? 56 : 108)
        : 0;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;

              return SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.only(
                  bottom: keyboardHeight + kHeight * 0.03,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(height: kHeight * 0.03),
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Castontext(
                              fontWeight: FontWeight.w600,
                              fontSize: kHeight * 0.016,
                              text: ('You Have').appTr,
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(50),
                                border: Border.all(color: Colors.black),
                              ),
                              child: Image(
                                image: const AssetImage('assets/audio_live/diamond.png'),
                                height: kHeight * 0.014,
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () {
                                Get.to(Tradingsend());
                              },
                              child: Castontext(
                                textColor: kAppColor2,
                                fontWeight: FontWeight.w600,
                                fontSize: 20,
                                text: '${authController.userProfile.value.user!.balance}',
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: kHeight * 0.02),
                      Container(
                        width: kWeight * 0.8,
                        padding: EdgeInsets.symmetric(horizontal: kHeight * 0.016),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: TextField(
                          controller: resellerController.searchController,
                          onChanged: _onUserIdChanged,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.search,
                          scrollPadding: EdgeInsets.only(
                            bottom: MediaQuery.viewInsetsOf(context).bottom + 150,
                          ),
                          onSubmitted: (value) {
                            _searchDebounce?.cancel();
                            searchUser(value);
                          },
                          decoration: InputDecoration(
                            icon: Icon(Icons.search, color: Colors.grey[600]),
                            hintText: ('Enter Uid number').appTr,
                            hintStyle: GoogleFonts.lato(fontSize: kHeight * 0.016),
                            border: InputBorder.none,
                            suffixIcon: resellerController.searchController.text.isEmpty
                                ? null
                                : IconButton(
                              onPressed: () {
                                resellerController.searchController.clear();
                                _onUserIdChanged('');
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: kHeight * 0.005),

                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                        height: cardHeight,
                        width: kWeight * 0.8,
                        child: ClipRect(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: _buildUserSearchResult(context),
                          ),
                        ),
                      ),

                      SizedBox(height: kHeight * 0.006),
                      Center(
                        child: Container(
                          width: kWeight * 0.8,
                          padding: EdgeInsets.symmetric(horizontal: kHeight * 0.016),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: TextField(
                            controller: resellerController.amount,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            scrollPadding: EdgeInsets.only(
                              bottom: MediaQuery.viewInsetsOf(context).bottom + 180,
                            ),
                            onSubmitted: (_) => FocusScope.of(context).unfocus(),
                            decoration: InputDecoration(
                              icon: Icon(Icons.currency_bitcoin, color: Colors.grey[600]),
                              hintText: ('Enter Coin amount').appTr,
                              hintStyle: GoogleFonts.lato(fontSize: kHeight * 0.016),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: kHeight * 0.02),
                      SizedBox(
                        width: kWeight * 0.7,
                        height: kHeight * 0.055,
                        child: Obx(
                              () => ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: resellerController.isButtonEnabled.value
                                  ? kAppColor2.withOpacity(.7)
                                  : Colors.grey.withOpacity(.2),
                            ),
                            onPressed: () {
                              if (!resellerController.isButtonEnabled.value) {
                                Fluttertoast.showToast(
                                  msg: ('Please fill User ID and Amount ❌').appTr,
                                  toastLength: Toast.LENGTH_SHORT,
                                  gravity: ToastGravity.BOTTOM,
                                  backgroundColor: Colors.red,
                                  textColor: Colors.white,
                                  fontSize: 13,
                                );
                                return;
                              }

                              if (selectedUser == null) {
                                Fluttertoast.showToast(
                                  msg: ('Please enter a valid User ID ❌').appTr,
                                  toastLength: Toast.LENGTH_SHORT,
                                  gravity: ToastGravity.BOTTOM,
                                  backgroundColor: Colors.red,
                                  textColor: Colors.white,
                                  fontSize: 13,
                                );
                                return;
                              }

                              resellerController.resellerBaanceTransfer();
                            },
                            child: Text(
                              ('Transfer').appTr,
                              style: GoogleFonts.roboto(
                                fontWeight: FontWeight.w400,
                                fontSize: Get.height * 0.015,
                                color: resellerController.isButtonEnabled.value
                                    ? Colors.white
                                    : Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey[300],
        ),
        child: Icon(
          Icons.person_rounded,
          size: 30,
          color: Colors.grey[600],
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      imageBuilder: (context, imageProvider) => Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          image: DecorationImage(
            image: imageProvider,
            fit: BoxFit.cover,
          ),
        ),
      ),
      placeholder: (context, url) => Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          width: 58,
          height: 58,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey[300],
        ),
        child: Icon(
          Icons.person_rounded,
          size: 30,
          color: Colors.grey[600],
        ),
      ),
    );
  }
}
