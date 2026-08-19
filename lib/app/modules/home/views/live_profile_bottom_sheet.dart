part of '../controllers/home_controller.dart';

/// Live profile bottom-sheet UI is kept outside HomeController so the
/// controller contains data/API logic instead of hundreds of widget lines.
extension LiveProfileBottomSheetView on HomeController {
  void showLiveProfileBottomSheet() {
    Get.bottomSheet(
      SafeArea(
        top: false,
        child: Obx(() {
          final Map<String, dynamic> liveProfileRootNow =
          Map<String, dynamic>.from(liveProfileVisitor.value);
          final Map<String, dynamic> user = Map<String, dynamic>.from(
            liveProfileRootNow['User Data'] ?? {},
          );

          // ✅ Current user id for all live-profile widgets
          final int targetVipIdForCard = _safeLiveInt(
            user['id'] ?? user['user_id'],
          );

          final Map<String, dynamic> cpMiniCardData =
              liveProfileCpCache[targetVipIdForCard] ??
                  _extractProfileCpMap(
                    user: user,
                    root: liveProfileRootNow,
                  );

          final Map<String, dynamic> familyMiniCardData =
              liveProfileFamilyCache[targetVipIdForCard] ??
                  _extractProfileFamilyMap(
                    user: user,
                    root: liveProfileRootNow,
                  );

          final Map<String, dynamic> agencyMiniCardData =
          _extractProfileAgencyMap(
            user: user,
            root: liveProfileRootNow,
          );

          if (targetVipIdForCard > 0 &&
              cpMiniCardData.isEmpty &&
              !liveProfileCpLoadingIds.contains(targetVipIdForCard)) {
            fetchLiveProfileCp(userId: targetVipIdForCard);
          }

          if (targetVipIdForCard > 0 &&
              familyMiniCardData.isEmpty &&
              !liveProfileFamilyLoadingIds.contains(targetVipIdForCard)) {
            fetchLiveProfileFamily(userId: targetVipIdForCard);
          }

          // ✅ Current VIP API থেকে real profile_card_image_url
          final Map<String, dynamic>? liveVipForCard =
              userCurrentVipCache[targetVipIdForCard] ??
                  currentVipForUser(targetVipIdForCard);
          final Map<String, dynamic> liveVipLevelForCard =
          _vipLevelMap(liveVipForCard);
          final String profileCardImageUrlForSheet = _cleanVipImageUrl(
            liveVipLevelForCard['profile_card_image_url'] ??
                liveVipLevelForCard['profile_card_image'],
          );

          // ✅ First screenshot-এর SVIP frame-এর current position ঠিক আছে।
          // শুধু VIP 1 asset-এর artwork নিচের দিকে হওয়ায় তার জন্য
          // আলাদা vertical correction ব্যবহার করা হচ্ছে। অন্য VIP/SVIP
          // frame-এর position একদম পরিবর্তন হবে না।
          final String liveVipTypeForCard =
          (liveVipLevelForCard['type'] ??
              liveVipLevelForCard['vip_type'] ??
              liveVipForCard?['vip_type'] ??
              '')
              .toString()
              .trim()
              .toLowerCase()
              .replaceAll(RegExp(r'[\s_-]+'), '');
          final int liveVipLevelNoForCard = _profileSafeInt(
            liveVipLevelForCard['level_no'] ??
                liveVipLevelForCard['vip_level_no'],
          );
          final bool isVipOneProfileCard =
              liveVipTypeForCard == 'vip1' ||
                  (liveVipTypeForCard.startsWith('vip') &&
                      !liveVipTypeForCard.startsWith('svip') &&
                      liveVipLevelNoForCard == 1);

          // ✅ VIP 2 আলাদা করে detect করা হচ্ছে।
          // VIP 1 এবং SVIP-এর existing position/size এতে পরিবর্তন হবে না।
          final bool isVipTwoProfileCard =
              liveVipTypeForCard == 'vip2' ||
                  (liveVipTypeForCard.startsWith('vip') &&
                      !liveVipTypeForCard.startsWith('svip') &&
                      liveVipLevelNoForCard == 2);

          // ✅ VIP 3 আলাদা detect করা হচ্ছে।
          // VIP 3 bottom frame safe centered scale-এ extra ছোট হবে।
          final bool isVipThreeProfileCard =
              liveVipTypeForCard == 'vip3' ||
                  (liveVipTypeForCard.startsWith('vip') &&
                      !liveVipTypeForCard.startsWith('svip') &&
                      liveVipLevelNoForCard == 3);

          // ✅ VIP 4 আলাদা detect করা হচ্ছে।
          // VIP 4 bottom frame VIP 2-এর same size/position/fit ব্যবহার করবে।
          final bool isVipFourProfileCard =
              liveVipTypeForCard == 'vip4' ||
                  (liveVipTypeForCard.startsWith('vip') &&
                      !liveVipTypeForCard.startsWith('svip') &&
                      liveVipLevelNoForCard == 4);

          // ✅ VIP 5, 6, 7, 8 আলাদা detect করা হচ্ছে।
          // এদের bottom frame VIP 4-এর exact same size/position/fit ব্যবহার করবে।
          final bool isVipFiveProfileCard =
              liveVipTypeForCard == 'vip5' ||
                  (liveVipTypeForCard.startsWith('vip') &&
                      !liveVipTypeForCard.startsWith('svip') &&
                      liveVipLevelNoForCard == 5);

          final bool isVipSixProfileCard =
              liveVipTypeForCard == 'vip6' ||
                  (liveVipTypeForCard.startsWith('vip') &&
                      !liveVipTypeForCard.startsWith('svip') &&
                      liveVipLevelNoForCard == 6);

          final bool isVipSevenProfileCard =
              liveVipTypeForCard == 'vip7' ||
                  (liveVipTypeForCard.startsWith('vip') &&
                      !liveVipTypeForCard.startsWith('svip') &&
                      liveVipLevelNoForCard == 7);

          final bool isVipEightProfileCard =
              liveVipTypeForCard == 'vip8' ||
                  (liveVipTypeForCard.startsWith('vip') &&
                      !liveVipTypeForCard.startsWith('svip') &&
                      liveVipLevelNoForCard == 8);

          final bool usesVipThreeFrameLayout =
              isVipThreeProfileCard;

          final bool usesVipFourFrameLayout =
              isVipFourProfileCard ||
                  isVipFiveProfileCard ||
                  isVipSixProfileCard ||
                  isVipSevenProfileCard ||
                  isVipEightProfileCard;

          // VIP/SVIP profile-card background এখন bottom-sheet container-এর
          // সাথে fixed থাকবে। Image position container-এর বাইরে shift হবে না।
          final Alignment vipProfileCardAlignment =
          (isVipOneProfileCard ||
              isVipTwoProfileCard ||
              usesVipFourFrameLayout)
              ? Alignment.topCenter
              : Alignment.center;

          final bool isOwnProfile =
              user['id']?.toString() ==
                  authController.userProfile.value.user?.id?.toString();

          final bool profileUserInCall = websocketController.liveCallList
              .where(
                (call) =>
            call['caller_id']?.toString() == user['id']?.toString(),
          )
              .isNotEmpty;

          final int currentUserIdForManage =
              authController.userProfile.value.user?.id?.toInt() ?? 0;
          final bool canModerateProfile =
              livestreamController.isCurrentUserCurrentLiveOwner ||
                  livestreamController.isBroadcaster.value ||
                  livestreamController.isMyGuardian.value == true ||
                  livestreamController.roomGuardianMap[currentUserIdForManage] == true;

          final String manageText = () {
            // ✅ Own profile: if user is on mic OR host, show manage so
            // View profile + Leave live mic + Mute/Unmute mic options appear.
            if (isOwnProfile &&
                (profileUserInCall || livestreamController.isBroadcaster.value)) {
              return 'Manage';
            }

            if (isOwnProfile && !profileUserInCall) return '';

            // ✅ Host/Guardian can manage other users.
            if (canModerateProfile && !isOwnProfile) {
              return 'Manage';
            }

            return 'Report';
          }();

          Future<void> openFullProfileFromLiveSheet() async {
            final String targetProfileUserId =
            '${user['id'] ?? user['user_id'] ?? ''}'.trim();

            if (targetProfileUserId.isEmpty ||
                targetProfileUserId == '0' ||
                targetProfileUserId.toLowerCase() == 'null') {
              Fluttertoast.showToast(
                msg: ('Invalid user').appTr,
                backgroundColor: Colors.red,
                textColor: Colors.white,
              );
              return;
            }

            // Bottom sheet open থাকলে নতুন profile route তার নিচে চলে যেতে পারে।
            // তাই আগে sheet close করে, তারপর full profile page open করা হচ্ছে।
            if (Get.isBottomSheetOpen == true) {
              Get.back();
              await Future.delayed(const Duration(milliseconds: 180));
            }

            visitProfile(userId: targetProfileUserId);
          }

          return Padding(
            padding: EdgeInsets.only(top: kHeight * 0.085),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: double.infinity,
                  // ✅ Bottom sheet পুরো screen width জুড়ে থাকবে।
                  margin: EdgeInsets.only(
                    bottom: kHeight * 0.008,
                  ),
                  constraints: BoxConstraints(maxHeight: Get.height * 0.90),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.14),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),

                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    // VIP/SVIP frame top-e uthle jeno kata na jay.
                    clipBehavior: Clip.none,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // ✅ VIP/SVIP profile-card এখন পুরো bottom-sheet
                        // container-এর fixed background।
                        // Content scroll করবে, background নড়বে না।
                        // BoxFit.cover দিয়ে top/bottom gap ছাড়াই পুরো card cover হবে।
                        if (_isActiveVipMap(liveVipForCard) &&
                            profileCardImageUrlForSheet.isNotEmpty)
                          Positioned(
                            // ✅ VIP 1 top border-এর সাথে থাকবে, তবে width/size
                            // আগের চেয়ে ছোট করা হয়েছে।
                            //
                            // ✅ SVIP এবং অন্য VIP frame একদম unchanged।
                            // ✅ VIP 1: আগের approved position/size unchanged.
                            // ✅ VIP 2: আরও উপরে এবং আরও বড় করা হয়েছে.
                            // top 180px থেকে 80px করা হয়েছে.
                            // left/right inset 4.5% থেকে 2% করা হয়েছে.
                            // ✅ VIP 2 bottom inset 0 রাখা হয়েছে যাতে
                            // frame-এর নিচের artwork আর কাটা/ঢাকা না যায়.
                            // ✅ SVIP/other VIP: আগের position unchanged.
                            top: isVipOneProfileCard
                                ? -300
                                : (isVipTwoProfileCard || usesVipFourFrameLayout)
                                ? -120
                                : usesVipThreeFrameLayout
                                ? -750
                                : -220,
                            bottom: isVipOneProfileCard
                                ? kHeight * 0.020
                                : (isVipTwoProfileCard || usesVipFourFrameLayout)
                                ? 0
                                : usesVipThreeFrameLayout
                                ? -430.0
                                : 0,
                            left: isVipOneProfileCard
                                ? kWeight * 0.010
                                : (isVipTwoProfileCard || usesVipFourFrameLayout)
                                ? 0
                                : usesVipThreeFrameLayout
                                ? 152.5
                                : 0,
                            right: isVipOneProfileCard
                                ? kWeight * 0.010
                                : (isVipTwoProfileCard || usesVipFourFrameLayout)
                                ? 0
                                : usesVipThreeFrameLayout
                                ? 152.5
                                : 0,
                            child: IgnorePointer(
                              child: RepaintBoundary(
                                child: Transform.scale(
                                  // ✅ VIP 3 current width box already খুব ছোট।
                                  // আর literal 200px inset দিলে ছোট phone-এ
                                  // negative width/layout crash হতে পারে।
                                  // তাই শুধু VIP 3 artwork safe centered scale-এ
                                  // আরও ছোট করা হচ্ছে।
                                  scale: isVipThreeProfileCard ? 7.50 : 1.0,
                                  alignment: Alignment.center,
                                  child: profileCardImageUrlForSheet
                                      .toLowerCase()
                                      .endsWith('.svga')
                                      ? SVGAEasyPlayer(
                                    resUrl: profileCardImageUrlForSheet,
                                    fit: (isVipOneProfileCard ||
                                        isVipTwoProfileCard ||
                                        isVipThreeProfileCard ||
                                        usesVipFourFrameLayout)
                                        ? BoxFit.contain
                                        : BoxFit.cover,
                                  )
                                      : CachedNetworkImage(
                                    imageUrl: profileCardImageUrlForSheet,
                                    width: double.infinity,
                                    height: double.infinity,
                                    fit: (isVipOneProfileCard ||
                                        isVipTwoProfileCard ||
                                        isVipThreeProfileCard ||
                                        usesVipFourFrameLayout)
                                        ? BoxFit.contain
                                        : BoxFit.cover,
                                    alignment: (isVipOneProfileCard ||
                                        isVipTwoProfileCard ||
                                        usesVipFourFrameLayout)
                                        ? Alignment.topCenter
                                        : Alignment.center,
                                    fadeInDuration: Duration.zero,
                                    fadeOutDuration: Duration.zero,
                                    placeholder: (_, __) =>
                                    const SizedBox.shrink(),
                                    errorWidget: (_, __, ___) =>
                                    const SizedBox.shrink(),
                                  ),
                                ),
                              ),
                            ),
                          ),

                        SingleChildScrollView(
                          clipBehavior: Clip.none,
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.zero,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(height: kHeight * 0.012),

                              Container(
                                width: double.infinity,
                                margin: EdgeInsets.symmetric(
                                  horizontal: kWeight * 0.025,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.fromLTRB(
                                        kWeight * 0.035,
                                        kHeight * 0.014,
                                        kWeight * 0.035,
                                        kHeight * 0.018,
                                      ),
                                      child: Column(
                                        children: [

                                          // Header Part
                                          Row(
                                            children: [

                                              Padding(
                                                padding: EdgeInsets.only(top: kHeight * 0.018),
                                                child: SizedBox(
                                                  width: 68,
                                                  child: manageText.isEmpty
                                                      ? const SizedBox.shrink()
                                                      : GestureDetector(
                                                    onTap: () async {
                                                      if (manageText == 'Manage' || manageText == 'Report') {
                                                        // ✅ Manage/Report এ গেলে আগে profile bottom sheet close হবে,
                                                        // তারপর Manage popup open হবে। Report option এখান থেকেই কাজ করবে।
                                                        final userDataPopup = Map<String, dynamic>.from(
                                                          liveProfileVisitor,
                                                        );

                                                        if (Get.isBottomSheetOpen == true) {
                                                          Get.back();
                                                        }

                                                        await Future.delayed(
                                                          const Duration(milliseconds: 180),
                                                        );

                                                        showManagePopup(
                                                          userDataPopup: userDataPopup,
                                                        );
                                                      }
                                                    },
                                                    child: Container(
                                                      padding: EdgeInsets.symmetric(vertical: 3,horizontal: kWeight*0.015),
                                                      decoration: BoxDecoration(
                                                          borderRadius: BorderRadius.circular(6),
                                                          color: const Color(0xffeeeeee)
                                                      ),
                                                      child: Text(
                                                        manageText.appTr,
                                                        style:
                                                        GoogleFonts.poppins(
                                                          color: Colors
                                                              .black87
                                                          ,
                                                          fontSize:
                                                          kHeight *
                                                              0.012,
                                                          fontWeight:
                                                          FontWeight
                                                              .w700,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),

                                              const Spacer(),


                                              const Spacer(),

                                              SizedBox(
                                                width: 68,
                                                child: Align(
                                                  alignment:
                                                  Alignment.centerRight,
                                                  child: GestureDetector(
                                                    onTap: () => Get.back(),
                                                    child: Container(
                                                      height: 30,
                                                      width: 30,
                                                      decoration: BoxDecoration(
                                                        color: Colors.grey.withOpacity(.16),
                                                        shape: BoxShape.circle,
                                                        border: Border.all(
                                                          color: Colors.black.withOpacity(.12),
                                                          width: 1,
                                                        ),
                                                      ),
                                                      child: const Icon(
                                                        Icons.close_rounded,
                                                        color: Colors.black87,
                                                        size: 18,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),

                                          /// Avatar এখন frame-এর নিচে sheet-এর ভিতরে থাকবে।
                                          /// তাই name/content avatar-এর নিচ থেকে শুরু করার
                                          /// জন্য যথেষ্ট fixed space রাখা হয়েছে।
                                          SizedBox(height: kHeight * 0.120),

                                          Row(
                                            mainAxisAlignment:
                                            MainAxisAlignment.center,
                                            children: [
                                              Flexible(
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      '${user['name'] ?? ''}',
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: GoogleFonts.poppins(
                                                        color: Colors.black87,
                                                        fontSize: kHeight * 0.025,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),

                                                    SizedBox(
                                                      width: kWeight * 0.015,
                                                    ),

                                                    Container(
                                                      padding: EdgeInsets.all(
                                                        kHeight * 0.004,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        borderRadius:
                                                        BorderRadius.circular(
                                                          20,
                                                        ),
                                                        color:
                                                        user['gender']
                                                            .toString()
                                                            .toLowerCase() ==
                                                            'female'
                                                            ? const Color(
                                                          0xffff5fb7,
                                                        )
                                                            : const Color(
                                                          0xff31b6ff,
                                                        ),
                                                      ),
                                                      child: Icon(
                                                        user['gender']
                                                            .toString()
                                                            .toLowerCase() ==
                                                            'female'
                                                            ? Icons.female
                                                            : Icons.male,
                                                        color: Colors.white,
                                                        size: kHeight * 0.017,
                                                      ),
                                                    ),

                                                    SizedBox(
                                                      width: kWeight * 0.018,
                                                    ),

                                                    Text(
                                                      getCountryFlag(
                                                        user['country'],
                                                      ),
                                                      style: TextStyle(
                                                        fontSize: kHeight * 0.023,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),

                                          SizedBox(height: kHeight * 0.007),

                                          _profileLevelVipBaseRow(user),

                                          /// ID + Level row-এর নিচে current user এবং
                                          /// CP partner-এর smooth connection card।
                                          _profileCpConnectionCard(
                                            user: user,
                                            cpData: cpMiniCardData,
                                          ),

                                          SizedBox(height: kHeight * 0.004),

                                          // ✅ Base images agency card-এর নিচে middle/center-এ থাকবে।
                                          _profileBaseBadgesRow(user),

                                          SizedBox(height: kHeight * 0.006),

                                          Row(
                                            mainAxisAlignment:
                                            MainAxisAlignment.spaceAround,
                                            children: [
                                              _statBox(
                                                '${user['total_following'] ?? 0}',
                                                ('Following').appTr,
                                                onTap: () {
                                                  Get.to(
                                                    FollowinfList(),
                                                    transition:
                                                    Transition.rightToLeft,
                                                  );
                                                },
                                              ),

                                              _statBox(
                                                formatNumber(
                                                  user['earned_coins'] ?? 0,
                                                ),
                                                ('Receive').appTr,
                                              ),

                                              _statBox(
                                                formatNumber(
                                                  user['gifts_coins'] ?? 0,
                                                ),
                                                ('Send').appTr,
                                              ),

                                              _statBox(
                                                '${user['total_followers'] ?? 0}',
                                                ('Followers').appTr,
                                                onTap: () {
                                                  Get.to(
                                                    Follower(),
                                                    transition:
                                                    Transition.rightToLeft,
                                                  );
                                                },
                                              ),
                                            ],
                                          ),

                                          if (!isOwnProfile) ...[
                                            SizedBox(height: kHeight * 0.018),

                                            Row(
                                              children: [
                                                Expanded(
                                                  child: _followButton(user),
                                                ),

                                                SizedBox(width: kWeight * 0.022),

                                                _circleActionButton(
                                                  icon: Icons
                                                      .alternate_email_rounded,
                                                  onTap: () {
                                                    mentionLiveProfileUserFromSheet(user);
                                                  },
                                                ),

                                                SizedBox(width: kWeight * 0.018),

                                                _circleActionButton(
                                                  icon: Icons
                                                      .chat_bubble_outline_rounded,
                                                  onTap: () {
                                                    Get.to(
                                                          () => ChatPage(
                                                        receiverId: '${user['id']}',
                                                        receiverName: '${user['name'] ?? ''}',
                                                        receiverImage: user['profile_image'] == null
                                                            ? '$kDomainUrl/${authController.userProfile.value.user?.profileImage ?? ''}'
                                                            : '$kDomainUrl/${user['profile_image']}',
                                                      ),
                                                      transition: Transition.rightToLeft,
                                                    );

                                                  },
                                                ),

                                                SizedBox(width: kWeight * 0.018),

                                                _circleActionButton(
                                                  icon: Icons.home_rounded,
                                                  onTap: () {
                                                    visitProfile(userId: user['id'].toString());
                                                  },
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              SizedBox(height: kHeight * 0.018),
                            ],
                          ),
                        ),

                      ],
                    ),
                  ),
                ),

                /// Profile avatar আর frame-এর মাঝখানে overlap করবে না।
                /// এটি আরও একটু নিচে, sheet-এর ভিতরে frame-এর নিচে center-এ fixed থাকবে।
                Positioned(
                  top: kHeight * 0.042,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: openFullProfileFromLiveSheet,
                      child: Obx(() {
                        final int targetVipId = _safeLiveInt(
                          user['id'] ?? user['user_id'],
                        );
                        final vip = userCurrentVipCache[targetVipId] ??
                            currentVipForUser(targetVipId);

                        return _premiumProfileAvatar(
                          user,
                          vipData: vip,
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.45),
      enableDrag: true,
      isDismissible: true,
      enterBottomSheetDuration: const Duration(milliseconds: 260),
      exitBottomSheetDuration: const Duration(milliseconds: 220),
    );
  }
}

/// Live profile bottom-sheet helper widgets and data mappers.
String formatNumber(dynamic value) {
  // Convert to number if it's a string
  double number = value is String
      ? double.tryParse(value) ?? 0
      : value.toDouble();

  if (number >= 1000000) {
    // For millions
    double millions = number / 1000000;
    return '${millions.toStringAsFixed(millions.truncateToDouble() == millions ? 0 : 1)}M';
  } else if (number >= 1000) {
    // For thousands
    double thousands = number / 1000;
    return '${thousands.toStringAsFixed(thousands.truncateToDouble() == thousands ? 0 : 1)}K';
  } else {
    // For numbers less than 1000
    return number.toStringAsFixed(number.truncateToDouble() == number ? 0 : 1);
  }
}

Widget _premiumProfileAvatar(dynamic user, {Map<String, dynamic>? vipData}) {
  final double size = Get.height * 0.145;

  /// VIP profile-card background এবং purchased avatar frame দুইটি আলাদা item.
  /// আগে active VIP থাকলে `!hasActiveVip` condition-এর কারণে purchased
  /// profile frame hide হয়ে যেত। এখন active/valid purchased frame থাকলে
  /// VIP/SVIP background-এর সাথেও avatar-এর উপরে frame show হবে।
  final Map<String, dynamic> purchaseHistory = _safeMap(
    user['asset_purchase_history'],
  );
  final Map<String, dynamic> purchasedAsset = _safeMap(
    purchaseHistory['asset'],
  );

  final String purchaseStatus = _cleanTextValue(
    purchaseHistory['status'],
  ).toLowerCase();
  final String assetType = _cleanTextValue(
    purchasedAsset['type'],
  ).toLowerCase();
  final String framePath = _cleanTextValue(
    purchasedAsset['asset'] ?? purchasedAsset['image'],
  );
  final String frameUrl = _cleanVipImageUrl(framePath);

  final bool frameStatusAllowed = purchaseStatus.isEmpty ||
      purchaseStatus == 'active' ||
      purchaseStatus == '1' ||
      purchaseStatus == 'true';
  final bool frameTypeAllowed = assetType.isEmpty ||
      assetType == 'frame' ||
      assetType.contains('profile');
  final bool hasProfileFrame = frameUrl.isNotEmpty &&
      frameStatusAllowed &&
      frameTypeAllowed;

  return SizedBox(
    height: size,
    width: size,
    child: Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        ClipOval(
          child: CachedNetworkImage(
            imageUrl: ImageHelper.getImageUrl('${user['profile_image']}'),
            fit: BoxFit.cover,
            height: size * .74,
            width: size * .74,
            fadeInDuration: Duration.zero,
            fadeOutDuration: Duration.zero,
            errorWidget: (context, url, error) => Image.asset(
              'assets/images/support_user.png',
              fit: BoxFit.cover,
              height: size * .74,
              width: size * .74,
            ),
          ),
        ),

        // ✅ Active VIP থাকলেও purchased profile frame show হবে।
        if (hasProfileFrame)
          frameUrl.toLowerCase().endsWith('.svga')
              ? Positioned.fill(
            child: SVGAEasyPlayer(
              resUrl: frameUrl,
              fit: BoxFit.cover,
            ),
          )
              : Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: frameUrl,
              fit: BoxFit.cover,
              fadeInDuration: Duration.zero,
              fadeOutDuration: Duration.zero,
              placeholder: (_, __) => const SizedBox.shrink(),
              errorWidget: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
      ],
    ),
  );
}
bool _isActiveVipMap(dynamic value) {
  if (value is! Map) return false;
  final map = Map<String, dynamic>.from(value);
  final status = (map['status'] ?? '').toString().trim().toLowerCase();
  final raw = map['is_active'];
  final active = raw == true ||
      raw == 1 ||
      raw?.toString().trim().toLowerCase() == 'true' ||
      status == 'active';
  return active && map['vip_level'] is Map;
}

Map<String, dynamic> _vipLevelMap(dynamic vipData) {
  if (!_isActiveVipMap(vipData)) return <String, dynamic>{};
  final level = (vipData as Map)['vip_level'];
  if (level is Map<String, dynamic>) return level;
  if (level is Map) return Map<String, dynamic>.from(level);
  return <String, dynamic>{};
}

String _cleanVipImageUrl(dynamic value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty || text.toLowerCase() == 'null') return '';
  if (text.startsWith('http://') || text.startsWith('https://')) return text;
  return ImageHelper.getImageUrl(text);
}

String _vipTitleText(dynamic vipData) {
  if (!_isActiveVipMap(vipData)) return '';
  final level = _vipLevelMap(vipData);
  final title = (level['title'] ?? level['name'] ?? (vipData as Map)['vip_type'] ?? '')
      .toString()
      .trim();
  return title;
}

String _vipRemainingText(dynamic vipData) {
  if (!_isActiveVipMap(vipData)) return '';
  final days = (vipData as Map)['remaining_days'];
  final daysText = days?.toString().trim() ?? '';
  if (daysText.isNotEmpty && daysText != 'null') return '$daysText days left';
  return 'Active';
}

Widget _vipImage(String url, {BoxFit fit = BoxFit.contain}) {
  final cleanUrl = _cleanVipImageUrl(url);
  if (cleanUrl.isEmpty) return const SizedBox.shrink();

  final lower = cleanUrl.toLowerCase();
  if (lower.endsWith('.svga')) {
    return SVGAEasyPlayer(
      resUrl: cleanUrl,
      fit: fit,
    );
  }

  return CachedNetworkImage(
    imageUrl: cleanUrl,
    fit: fit,
    fadeInDuration: Duration.zero,
    fadeOutDuration: Duration.zero,
    errorWidget: (_, __, ___) => const SizedBox.shrink(),
    placeholder: (_, __) => const SizedBox.shrink(),
  );
}


Widget _vipTitleInlineBadge({
  required dynamic vipData,
  bool loading = false,
}) {
  if (loading && !_isActiveVipMap(vipData)) {
    return SizedBox(
      height: kHeight * 0.035,
      width: kWeight * 0.24,
      child: const Center(
        child: SizedBox(
          height: 14,
          width: 14,
          child: CircularProgressIndicator(
            strokeWidth: 1.6,
            color: Colors.white70,
          ),
        ),
      ),
    );
  }

  if (!_isActiveVipMap(vipData)) return const SizedBox.shrink();

  final Map<String, dynamic> level = _vipLevelMap(vipData);
  final String titleUrl = _cleanVipImageUrl(
    level['title_image_url'] ?? level['title_image'],
  );
  final String title = _vipTitleText(vipData);

  // ✅ Level frame er পাশে শুধু VIP title image দেখাবে
  // ✅ কোন background / border / gradient নেই
  if (titleUrl.isNotEmpty) {
    return SizedBox(
      height: kHeight * 0.043,
      width: kWeight * 0.255,
      child: Center(
        child: _vipImage(
          titleUrl,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  return SizedBox(
    height: kHeight * 0.032,
    width: kWeight * 0.18,
    child: Center(
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.poppins(
          color: const Color(0xFFFFD36A),
          fontSize: kHeight * 0.014,
          fontWeight: FontWeight.w900,
        ),
      ),
    ),
  );
}

class VipLiveProfileShowcase extends StatelessWidget {
  const VipLiveProfileShowcase({
    super.key,
    required this.vipData,
    required this.loading,
  });

  final Map<String, dynamic>? vipData;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading && !_isActiveVipMap(vipData)) {
      return SizedBox(
        height: kHeight * 0.040,
        child: Center(
          child: SizedBox(
            height: kHeight * 0.018,
            width: kHeight * 0.018,
            child: const CircularProgressIndicator(
              strokeWidth: 1.7,
              color: Colors.white70,
            ),
          ),
        ),
      );
    }

    if (!_isActiveVipMap(vipData)) return const SizedBox.shrink();

    final Map<String, dynamic> level = _vipLevelMap(vipData);
    final String badgeUrl = _cleanVipImageUrl(
      level['badge_image_url'] ?? level['badge_image'],
    );

    if (badgeUrl.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: kHeight * 0.038,
      width: double.infinity,
      child: Center(
        child: SizedBox(
          height: kHeight * 0.036,
          child: _vipImage(
            badgeUrl,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

Map<String, dynamic> _safeMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

Map<String, dynamic> _firstMapValue(Map<String, dynamic> source, List<String> keys) {
  for (final key in keys) {
    final dynamic value = source[key];
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is List && value.isNotEmpty && value.first is Map) {
      return Map<String, dynamic>.from(value.first as Map);
    }
  }
  return <String, dynamic>{};
}

bool _mapHasAnyKey(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    if (map.containsKey(key) && map[key] != null) return true;
  }
  return false;
}

Map<String, dynamic> _findCpMapDeep(dynamic value, {int depth = 0}) {
  if (depth > 5 || value == null) return <String, dynamic>{};

  if (value is Map) {
    final map = Map<String, dynamic>.from(value);
    if (_looksLikeCpMap(map)) return map;

    final preferredKeys = [
      'cp',
      'CP',
      'cp_data',
      'cpData',
      'current_cp',
      'currentCp',
      'couple',
      'partner',
      'cp_partner',
      'cpPartner',
      'sender',
      'receiver',
      'sender_user',
      'receiver_user',
    ];

    for (final key in preferredKeys) {
      if (map.containsKey(key)) {
        final found = _findCpMapDeep(map[key], depth: depth + 1);
        if (found.isNotEmpty) return found;
      }
    }

    for (final item in map.values) {
      final found = _findCpMapDeep(item, depth: depth + 1);
      if (found.isNotEmpty) return found;
    }
  }

  if (value is List) {
    for (final item in value) {
      final found = _findCpMapDeep(item, depth: depth + 1);
      if (found.isNotEmpty) return found;
    }
  }

  return <String, dynamic>{};
}

Map<String, dynamic> _extractProfileFamilyMap({
  required Map<String, dynamic> user,
  Map<String, dynamic>? root,
}) {
  final List<Map<String, dynamic>> sources = [
    user,
    if (root != null) root,
  ];

  const familyKeys = [
    'family',
    'Family',
    'Family Data',
    'family data',
    'family_data',
    'familyData',
    'family_info',
    'familyInfo',
    'family_detail',
    'familyDetail',
    'family_details',
    'user_family',
    'userFamily',
    'my_family',
    'myFamily',
    'family_profile',
  ];

  const memberKeys = [
    'user_member',
    'family_member',
    'member',
    'my_member',
    'family_user',
  ];

  for (final source in sources) {
    final direct = _firstMapValue(source, familyKeys);
    if (_looksLikeFamilyMap(direct)) return direct;

    for (final key in memberKeys) {
      final member = _safeMap(source[key]);
      final family = _safeMap(member['family'] ?? member['Family']);
      if (_looksLikeFamilyMap(family)) return family;
    }

    final data = _safeMap(source['data']);
    if (data.isNotEmpty && !identical(data, source)) {
      final nested = _extractProfileFamilyMap(user: data);
      if (nested.isNotEmpty) return nested;
    }

    if (_looksLikeFamilyMap(source)) return source;
  }

  return <String, dynamic>{};
}

bool _looksLikeFamilyMap(Map<String, dynamic> map) {
  if (map.isEmpty) return false;
  return _mapHasAnyKey(map, [
    'family_code',
    'familyCode',
    'family_id',
    'familyId',
    'owner_id',
    'ownerId',
    'member_limit',
    'members_count',
    'logo',
    'logo_url',
  ]) ||
      (_mapHasAnyKey(map, ['id', 'name']) &&
          _mapHasAnyKey(map, ['members', 'owner', 'badge', 'country', 'slug']));
}

Map<String, dynamic> _extractProfileCpMap({
  required Map<String, dynamic> user,
  Map<String, dynamic>? root,
}) {
  final List<Map<String, dynamic>> sources = [
    user,
    if (root != null) root,
  ];

  const cpKeys = [
    'cp',
    'CP',
    'CP Data',
    'Cp Data',
    'cp data',
    'couple',
    'Couple Data',
    'couple_data',
    'cp_data',
    'cpData',
    'cp_info',
    'cpInfo',
    'current_cp',
    'currentCp',
    'current_cp_data',
    'currentCpData',
    'user_cp',
    'userCp',
    'active_cp',
    'activeCp',
    'accepted_cp',
    'cp_request',
  ];

  const listKeys = [
    'requests',
    'request_list',
    'cp_requests',
    'cp_request_list',
    'sent_requests',
    'received_requests',
    'accepted_requests',
    'pending_requests',
    'list',
    'items',
  ];

  for (final source in sources) {
    final direct = _firstMapValue(source, cpKeys);
    if (_looksLikeCpMap(direct)) return direct;

    for (final key in listKeys) {
      final list = source[key];
      if (list is List) {
        for (final item in list) {
          final map = _safeMap(item);
          if (map.isEmpty) continue;
          final status = _cleanTextValue(map['status']).toLowerCase();
          if (status == 'accepted' || status == 'active' || _looksLikeCpMap(map)) {
            return map;
          }
        }
      }
    }

    final data = _safeMap(source['data']);
    if (data.isNotEmpty && !identical(data, source)) {
      final nested = _extractProfileCpMap(user: data);
      if (nested.isNotEmpty) return nested;
    }

    if (_looksLikeCpMap(source)) return source;
  }

  for (final source in sources) {
    final deep = _findCpMapDeep(source);
    if (deep.isNotEmpty) return deep;
  }

  return <String, dynamic>{};
}

bool _looksLikeCpMap(Map<String, dynamic> map) {
  if (map.isEmpty) return false;
  return _mapHasAnyKey(map, [
    'has_cp',
    'hasCp',
    'cp_partner',
    'cpPartner',
    'partner',
    'partner_id',
    'partner_name',
    'partner_image',
    'cp_name',
    'cp_image',
    'cp_profile_image',
    'cp_profile_image_url',
    'receiver',
    'receiver_user',
    'receiverUser',
    'sender',
    'sender_user',
    'senderUser',
    'sender_id',
    'receiver_id',
    'couple_id',
    'days_together',
    'love_points',
    'lovePoints',
    'cp_level',
    'cpLevel',
  ]);
}

String _cleanTextValue(dynamic value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty || text.toLowerCase() == 'null') return '';
  return text;
}

String _profileImageFromMap(Map<String, dynamic> map) {
  final String url = _cleanTextValue(
    map['profile_image_url'] ??
        map['cp_profile_image_url'] ??
        map['partner_image_url'] ??
        map['cp_image_url'] ??
        map['avatar_url'] ??
        map['image_url'] ??
        map['logo_url'],
  );
  if (url.isNotEmpty) return _cleanVipImageUrl(url);

  final String path = _cleanTextValue(
    map['profile_image'] ??
        map['cp_profile_image'] ??
        map['partner_image'] ??
        map['cp_image'] ??
        map['avatar'] ??
        map['image'] ??
        map['logo'],
  );
  if (path.isNotEmpty) return ImageHelper.getImageUrl(path);

  return '';
}

bool _sameUserId(dynamic a, dynamic b) {
  final aa = _cleanTextValue(a);
  final bb = _cleanTextValue(b);
  if (aa.isEmpty || bb.isEmpty) return false;
  return aa == bb;
}

Map<String, dynamic> _resolveCpPartnerForUser({
  required Map<String, dynamic> cp,
  required Map<String, dynamic> user,
}) {
  if (cp.isEmpty) return <String, dynamic>{};

  final Map<String, dynamic> currentCp = _safeMap(
    cp['current_cp'] ?? cp['currentCp'] ?? cp['cp'] ?? cp['couple'],
  );

  /// Profile visitor API returns sender/receiver/cp_partner on cp_data root.
  /// current_cp normally contains IDs and status only.
  final Map<String, dynamic> sender = _safeMap(
    cp['sender'] ??
        cp['sender_user'] ??
        cp['senderUser'] ??
        currentCp['sender'] ??
        currentCp['sender_user'],
  );
  final Map<String, dynamic> receiver = _safeMap(
    cp['receiver'] ??
        cp['receiver_user'] ??
        cp['receiverUser'] ??
        currentCp['receiver'] ??
        currentCp['receiver_user'],
  );
  final Map<String, dynamic> directPartner = _safeMap(
    cp['cp_partner'] ??
        cp['cpPartner'] ??
        cp['partner'] ??
        cp['partner_user'] ??
        cp['partnerUser'] ??
        currentCp['cp_partner'] ??
        currentCp['partner'],
  );

  final dynamic myId = user['id'];
  final dynamic myUserId = user['user_id'];

  bool isMe(Map<String, dynamic> person) {
    if (person.isEmpty) return false;

    return _sameUserId(person['id'], myId) ||
        _sameUserId(person['id'], myUserId) ||
        _sameUserId(person['user_id'], myId) ||
        _sameUserId(person['user_id'], myUserId);
  }

  final bool senderIsMe = isMe(sender) ||
      _sameUserId(currentCp['sender_id'] ?? cp['sender_id'], myId) ||
      _sameUserId(currentCp['sender_id'] ?? cp['sender_id'], myUserId);

  final bool receiverIsMe = isMe(receiver) ||
      _sameUserId(currentCp['receiver_id'] ?? cp['receiver_id'], myId) ||
      _sameUserId(currentCp['receiver_id'] ?? cp['receiver_id'], myUserId);

  if (senderIsMe && receiver.isNotEmpty) return receiver;
  if (receiverIsMe && sender.isNotEmpty) return sender;

  /// Backend's resolved other user.
  if (directPartner.isNotEmpty && !isMe(directPartner)) {
    return directPartner;
  }

  if (receiver.isNotEmpty && !isMe(receiver)) return receiver;
  if (sender.isNotEmpty && !isMe(sender)) return sender;
  if (directPartner.isNotEmpty) return directPartner;

  return <String, dynamic>{};
}


int _profileSafeInt(dynamic value, {int fallback = 0}) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is double) return value.toInt();
  return int.tryParse(value.toString()) ?? fallback;
}


Widget _profileLevelVipBaseRow(Map<String, dynamic> user) {
  return SizedBox(
    width: double.infinity,
    height: kHeight * 0.052,
    child: LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                _profileLiveIdCompact(user),
                SizedBox(width: kWeight * 0.065),
                LevelFrame(
                    levelImage:user['level_image']?['image'] ,
                    level: '${user['level']}'),
                SizedBox(width: kWeight * 0.008),
                Obx(() {
                  final HomeController controller = Get.find<HomeController>();
                  final int targetVipId = controller._safeLiveInt(
                    user['id'] ?? user['user_id'],
                  );
                  final vip = controller.userCurrentVipCache[targetVipId] ??
                      controller.currentVipForUser(targetVipId);
                  final loading =
                  controller.userCurrentVipLoadingIds.contains(targetVipId);

                  // ✅ UID + Level + VIP title + VIP badge এক লাইনে থাকবে।
                  // ✅ VIP title আর badge/base image এর gap কমানো হয়েছে।
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _vipTitleInlineBadge(
                        vipData: vip,
                        loading: loading,
                      ),

                      _vipBadgeInlineImage(
                        vipData: vip,
                        loading: loading,
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        );
      },
    ),
  );
}

Widget _profileLiveIdCompact(Map<String, dynamic> user) {
  Widget idBadge() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: kWeight * 0.009,
        vertical: kHeight * 0.0015,
      ),
      decoration: BoxDecoration(
        color: const Color(0xffeeeeee),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.08),
            blurRadius: 7,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        ('ID').appTr,
        style: GoogleFonts.poppins(
          fontSize: kHeight * 0.0125,
          fontWeight: FontWeight.w800,
          color: Colors.black87,
          height: 1.0,
        ),
      ),
    );
  }

  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      idBadge(),
      SizedBox(width: kWeight * 0.007),
      user['unique_id'] == null
          ? Text(
        '${user['user_id'] ?? ''}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.poppins(
          fontSize: kHeight * 0.0135,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
          height: 1.0,
          shadows: const [
            Shadow(
              blurRadius: 7,
              color: Color(0xFFFFD700),
              offset: Offset(0, 0),
            ),
          ],
        ),
      )
          : SizedBox(
        width: kWeight * 0.125,
        child: ShimmerUserId(
          user: user,
          kHeight: kHeight * 0.78,
          kWeight: kWeight,
        ),
      ),
      SizedBox(width: kWeight * 0.007),
      GestureDetector(
        onTap: () {
          Clipboard.setData(
            ClipboardData(text: '${user['user_id'] ?? ''}'),
          );
        },
        child: Icon(
          Icons.copy,
          size: kHeight * 0.015,
          color: Colors.black54,
        ),
      ),
    ],
  );
}

Widget _vipBadgeInlineImage({
  required dynamic vipData,
  bool loading = false,
}) {
  if (loading && !_isActiveVipMap(vipData)) {
    return SizedBox(
      height: kHeight * 0.034,
      width: kWeight * 0.070,
      child: const Center(
        child: SizedBox(
          height: 12,
          width: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.4,
            color: Colors.white70,
          ),
        ),
      ),
    );
  }

  if (!_isActiveVipMap(vipData)) return const SizedBox.shrink();

  final Map<String, dynamic> level = _vipLevelMap(vipData);
  final String badgeUrl = _cleanVipImageUrl(
    level['badge_image_url'] ?? level['badge_image'],
  );

  if (badgeUrl.isEmpty) return const SizedBox.shrink();

  return SizedBox(
    height: kHeight * 0.040,
    width: kWeight * 0.088,
    child: Center(
      child: _vipImage(
        badgeUrl,
        fit: BoxFit.contain,
      ),
    ),
  );
}


Widget _baseInlineImageBadge(dynamic item) {
  String imageUrl = '';

  if (item is Map) {
    imageUrl = item['image_url']?.toString() ?? '';

    if (imageUrl.isEmpty) {
      final imagePath = item['image']?.toString() ?? '';
      if (imagePath.isNotEmpty) {
        final cleanDomain = kDomainUrl.replaceAll(RegExp(r'/+$'), '');
        final cleanPath = imagePath.replaceAll(RegExp(r'^/+'), '');
        imageUrl = '$cleanDomain/$cleanPath';
      }
    }
  }

  if (imageUrl.isEmpty) return const SizedBox.shrink();

  return SizedBox(
    width: kWeight * 0.130,
    height: kHeight * 0.040,
    child: CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.contain,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholder: (_, __) => const SizedBox.shrink(),
      errorWidget: (_, __, ___) => const SizedBox.shrink(),
    ),
  );
}


bool _profileHasActiveCp(Map<String, dynamic> cpData) {
  if (cpData.isEmpty) return false;

  final Map<String, dynamic> currentCp = _safeMap(
    cpData['current_cp'] ?? cpData['currentCp'],
  );
  final String status =
  _cleanTextValue(currentCp['status'] ?? cpData['status']).toLowerCase();
  final String hasCp =
  _cleanTextValue(cpData['has_cp'] ?? cpData['hasCp']).toLowerCase();

  return hasCp == 'true' ||
      hasCp == '1' ||
      status == 'accepted' ||
      status == 'active' ||
      _safeMap(cpData['cp_partner'] ?? cpData['cpPartner']).isNotEmpty;
}

Widget _profileCpConnectionCard({
  required Map<String, dynamic> user,
  required Map<String, dynamic> cpData,
}) {
  final Map<String, dynamic> partner = _resolveCpPartnerForUser(
    cp: cpData,
    user: user,
  );

  final bool hasCp = _profileHasActiveCp(cpData) && partner.isNotEmpty;
  final String partnerId = _cleanTextValue(
    partner['id'] ?? partner['user_id'],
  );

  return AnimatedSwitcher(
    duration: const Duration(milliseconds: 320),
    switchInCurve: Curves.easeOutCubic,
    switchOutCurve: Curves.easeInCubic,
    transitionBuilder: (child, animation) {
      final slide = Tween<Offset>(
        begin: const Offset(0, .10),
        end: Offset.zero,
      ).animate(animation);

      return FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: slide,
          child: child,
        ),
      );
    },
    child: !hasCp
        ? const SizedBox.shrink(key: ValueKey('no_live_cp'))
        : _profileCpConnectionCardBody(
      key: ValueKey('live_cp_$partnerId'),
      user: user,
      partner: partner,
      cpData: cpData,
    ),
  );
}

Widget _profileCpConnectionCardBody({
  required Key key,
  required Map<String, dynamic> user,
  required Map<String, dynamic> partner,
  required Map<String, dynamic> cpData,
}) {
  final String myName = _cleanTextValue(user['name']).isEmpty
      ? ('User').appTr
      : _cleanTextValue(user['name']);
  final String partnerName = _cleanTextValue(partner['name']).isEmpty
      ? ('Partner').appTr
      : _cleanTextValue(partner['name']);

  final String myImage = _profileImageFromMap(user);
  final String partnerImage = _profileImageFromMap(partner);

  final Map<String, dynamic> cpLevel = _safeMap(
    cpData['cp_level'] ?? cpData['cpLevel'],
  );
  final int level = _profileSafeInt(
    cpLevel['level_no'] ?? cpLevel['level'] ?? 1,
    fallback: 1,
  );
  final int days = _profileSafeInt(
    cpData['cp_days'] ?? cpData['days_together'] ?? 0,
  );

  return Container(
    key: key,
    width: double.infinity,
    height: kHeight * 0.118,
    margin: EdgeInsets.only(
      top: kHeight * 0.003,
      left: kWeight * 0.010,
      right: kWeight * 0.010,
      bottom: kHeight * 0.004,
    ),
    padding: EdgeInsets.symmetric(
      horizontal: kWeight * 0.025,
      vertical: kHeight * 0.010,
    ),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFF7FB),
          Color(0xFFFFEEF6),
          Color(0xFFF5F1FF),
        ],
      ),
      border: Border.all(
        color: const Color(0xFFFF8FBC).withOpacity(.45),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFFFF6FAE).withOpacity(.12),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Row(
      children: [
        Expanded(
          child: _profileCpPerson(
            name: myName,
            imageUrl: myImage,
            label: ('You').appTr,
          ),
        ),
        SizedBox(
          width: kWeight * 0.29,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 1.5,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0x00FF5A9D),
                            Color(0xFFFF5A9D),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    height: kHeight * 0.034,
                    width: kHeight * 0.034,
                    margin: EdgeInsets.symmetric(horizontal: kWeight * 0.008),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFFF6AAC),
                          Color(0xFFFF377E),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF4C91).withOpacity(.28),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.favorite_rounded,
                      color: Colors.white,
                      size: kHeight * 0.018,
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 1.5,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFFFF5A9D),
                            Color(0x00FF5A9D),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: kHeight * 0.006),
              Text(
                ('CP Connection').appTr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: Colors.black87,
                  fontSize: kHeight * 0.0105,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: kHeight * 0.002),
              Text(
                days > 0 ? 'Lv.$level  •  $days Days' : 'Lv.$level',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: const Color(0xFFE53878),
                  fontSize: kHeight * 0.0095,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _profileCpPerson(
            name: partnerName,
            imageUrl: partnerImage,
            label: ('Partner').appTr,
          ),
        ),
      ],
    ),
  );
}

Widget _profileCpPerson({
  required String name,
  required String imageUrl,
  required String label,
}) {
  final double avatarSize = kHeight * 0.050;

  return Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(
        height: avatarSize,
        width: avatarSize,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFB0CF),
              Color(0xFFFF4C91),
              Color(0xFF9A66FF),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF5A9D).withOpacity(.20),
              blurRadius: 9,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipOval(
          child: imageUrl.isEmpty
              ? Container(
            color: const Color(0xFFF3F3F5),
            child: Icon(
              Icons.person_rounded,
              color: Colors.black38,
              size: avatarSize * .55,
            ),
          )
              : CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            fadeInDuration: const Duration(milliseconds: 120),
            fadeOutDuration: Duration.zero,
            placeholder: (_, __) => Container(
              color: const Color(0xFFF3F3F5),
            ),
            errorWidget: (_, __, ___) => Container(
              color: const Color(0xFFF3F3F5),
              child: Icon(
                Icons.person_rounded,
                color: Colors.black38,
                size: avatarSize * .55,
              ),
            ),
          ),
        ),
      ),
      SizedBox(height: kHeight * 0.004),
      Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          color: Colors.black87,
          fontSize: kHeight * 0.0105,
          fontWeight: FontWeight.w700,
        ),
      ),
      Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.poppins(
          color: Colors.black45,
          fontSize: kHeight * 0.008,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

Widget _profileFamilyAgencyCards(
    Map<String, dynamic> user, {
      Map<String, dynamic>? familyData,
      Map<String, dynamic>? agencyData,
    }) {
  // ✅ Family card আর দেখাবে না।
  // ✅ শুধু Agency card show হবে, profile page-এর মতো clean ছোট card।
  final agencyCard = _profileAgencyMiniCard(
    user,
    agencyData: agencyData,
  );

  return Center(
    child: SizedBox(
      width: kWeight * 0.58,
      child: agencyCard,
    ),
  );
}

Map<String, dynamic> _extractProfileAgencyMap({
  required Map<String, dynamic> user,
  Map<String, dynamic>? root,
}) {
  final List<Map<String, dynamic>> sources = [
    user,
    if (root != null) root,
  ];

  const agencyKeys = [
    'agency',
    'Agency',
    'agency_data',
    'agencyData',
    'agency_info',
    'agencyInfo',
    'my_agency',
    'myAgency',
    'host_agency',
    'hostAgency',
    'agency_under_host',
    'agencyUnderHost',
  ];

  for (final source in sources) {
    final direct = _firstMapValue(source, agencyKeys);
    if (_looksLikeAgencyMap(direct)) return direct;

    final data = _safeMap(source['data']);
    if (data.isNotEmpty && !identical(data, source)) {
      final nested = _extractProfileAgencyMap(user: data);
      if (nested.isNotEmpty) return nested;
    }

    if (_looksLikeAgencyMap(source)) return source;
  }

  return <String, dynamic>{};
}

bool _looksLikeAgencyMap(Map<String, dynamic> map) {
  if (map.isEmpty) return false;
  return _mapHasAnyKey(map, [
    'agency_id',
    'agencyId',
    'agency_code',
    'agencyCode',
    'agency_name',
    'agencyName',
    'agency_type',
    'host_type',
    'logo',
    'logo_url',
  ]) ||
      (_mapHasAnyKey(map, ['id', 'name']) &&
          _mapHasAnyKey(map, ['owner', 'host', 'members', 'hosts', 'country']));
}

Widget _profileAgencyMiniCard(
    Map<String, dynamic> user, {
      Map<String, dynamic>? agencyData,
    }) {
  final Map<String, dynamic> agency =
  (agencyData != null && agencyData.isNotEmpty)
      ? agencyData
      : _extractProfileAgencyMap(user: user);

  final String hostType = _cleanTextValue(
    user['host_type'] ?? user['hostType'] ?? agency['host_type'],
  ).toLowerCase();
  final String agencyType = _cleanTextValue(
    user['agency_type'] ?? user['agencyType'] ?? agency['agency_type'],
  ).toLowerCase();

  final bool hasAgencyRole = hostType == 'host' ||
      agencyType == 'agency' ||
      agencyType == 'agent' ||
      agency.isNotEmpty;

  if (!hasAgencyRole) {
    return const SizedBox.shrink();
  }

  final String titleValue = _cleanTextValue(
    agency['name'] ??
        agency['agency_name'] ??
        agency['agencyName'] ??
        user['agency_name'] ??
        user['agencyName'] ??
        user['host_name'],
  );
  final String title = titleValue.isNotEmpty
      ? titleValue
      : (hostType == 'host' ? 'Host Agency' : 'Agency');

  final String imageUrl = _profileImageFromMap(agency);

  return _profileSmallInfoCard(
    label: ('Agency').appTr,
    title: title,
    imageUrl: imageUrl,
    fallbackIcon: Icons.verified_user_rounded,
    colors: const [
      Color(0xFF4A2300),
      Color(0xFFC56A16),
    ],
  );
}





Widget _profileSmallInfoCard({
  required String label,
  required String title,
  required String imageUrl,
  required IconData fallbackIcon,
  required List<Color> colors,
  VoidCallback? onTap,
}) {
  final card = Container(
    height: kHeight * 0.052,
    padding: EdgeInsets.symmetric(horizontal: kWeight * 0.022),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      gradient: LinearGradient(
        colors: [
          colors.first.withOpacity(.70),
          colors.last.withOpacity(.42),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      border: Border.all(
        color: Colors.white.withOpacity(.14),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: colors.last.withOpacity(.12),
          blurRadius: 12,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          height: kHeight * 0.032,
          width: kHeight * 0.032,
          alignment: Alignment.center,
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(.12),
            border: Border.all(
              color: Colors.white.withOpacity(.18),
              width: 1,
            ),
          ),
          child: imageUrl.isNotEmpty
              ? CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            fadeInDuration: Duration.zero,
            fadeOutDuration: Duration.zero,
            placeholder: (_, __) => const SizedBox.shrink(),
            errorWidget: (_, __, ___) => Icon(
              fallbackIcon,
              color: Colors.white,
              size: kHeight * 0.018,
            ),
          )
              : Icon(
            fallbackIcon,
            color: Colors.white,
            size: kHeight * 0.018,
          ),
        ),
        SizedBox(width: kWeight * 0.016),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: Colors.white.withOpacity(.62),
                  fontSize: kHeight * 0.0085,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                ),
              ),
              SizedBox(height: kHeight * 0.003),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: kHeight * 0.0115,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  if (onTap == null) return card;

  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: card,
  );
}

Widget _profileBaseBadgesRow(Map<String, dynamic> user) {
  final List<dynamic> bases = user['base_list'] is List
      ? List<dynamic>.from(user['base_list'])
      : [];

  if (bases.isEmpty) {
    return const SizedBox.shrink();
  }

  return SizedBox(
    height: kHeight * 0.064,
    width: double.infinity,
    child: LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: bases.map((item) {
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: kWeight * 0.010),
                  child: _baseSmallImageBadge(item),
                );
              }).toList(),
            ),
          ),
        );
      },
    ),
  );
}

Widget _baseSmallImageBadge(dynamic item) {
  String imageUrl = '';

  if (item is Map) {
    imageUrl = item['image_url']?.toString() ?? '';

    if (imageUrl.isEmpty) {
      final imagePath = item['image']?.toString() ?? '';
      if (imagePath.isNotEmpty) {
        final cleanDomain = kDomainUrl.replaceAll(RegExp(r'/+$'), '');
        final cleanPath = imagePath.replaceAll(RegExp(r'^/+'), '');
        imageUrl = '$cleanDomain/$cleanPath';
      }
    }
  }

  if (imageUrl.isEmpty) return const SizedBox.shrink();

  return Container(
    width: kWeight * 0.180,
    height: kHeight * 0.056,
    alignment: Alignment.center,
    clipBehavior: Clip.none,
    child: CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.contain,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholder: (_, __) => const SizedBox.shrink(),
      errorWidget: (_, __, ___) => const SizedBox.shrink(),
    ),
  );
}



Widget _statBox(String value, String title, {VoidCallback? onTap}) {
  return GestureDetector(
    onTap: onTap,
    child: SizedBox(
      width: kWeight * 0.18,
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: Colors.black87,
              fontSize: kHeight * 0.013,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: Colors.black54,
              fontSize: kHeight * 0.009,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _followButton(Map<String, dynamic> user) {
  final HomeController controller = Get.find<HomeController>();

  return Obx(() {
    final int userId = controller._safeLiveInt(user['id'] ?? user['user_id']);
    final bool loading = userId > 0 && controller.liveFollowLoadingIds.contains(userId);
    final bool following = controller.isLiveFollowing(
      user['follow_status'] ?? user['is_following'],
    );

    return GestureDetector(
      onTap: loading ? null : () => controller.toggleLiveProfileFollow(user),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: kHeight * 0.052,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(50),
          color: following
              ? const Color(0xfff1f2f4)
              : const Color(0xffe8f1ff),
          border: Border.all(
            color: following
                ? Colors.black.withOpacity(.10)
                : const Color(0xffb8d2ff),
          ),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black87,
                  ),
                )
              else
                Icon(
                  following
                      ? Icons.person_remove_alt_1_rounded
                      : Icons.person_add_alt_1_rounded,
                  color: Colors.black87,
                  size: 18,
                ),
              const SizedBox(width: 7),
              Text(
                loading ? ('Updating...').appTr: (following ? ('Unfollow').appTr: ('Follow').appTr),
                style: GoogleFonts.poppins(
                  color: Colors.black87,
                  fontSize: kHeight * 0.014,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  });
}

Widget _circleActionButton({
  required IconData icon,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      height: kHeight * 0.052,
      width: kHeight * 0.052,
      decoration: BoxDecoration(
        color: const Color(0xfff1f2f4),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black.withOpacity(.10)),
      ),
      child: Icon(icon, color: Colors.black87, size: 22),
    ),
  );
}
