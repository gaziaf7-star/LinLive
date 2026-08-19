part of '../popular_live_view.dart';

/// Live-broadcast filter/beauty sheet launcher, PK launcher icon, and
/// the gift-sending bottom sheet. Extracted from _PopularLiveViewState
/// during file-splitting refactor — pure logic move only, no behavior
/// changes.
extension PopularLiveFilterGift on _PopularLiveViewState {
  Future<void> _openLiveFilterSheet() async {
    if (!widget.isBroadcaster || !mounted) return;

    await showProfessionalVideoEffectsSheet(
      context,
      initialSection: VideoEffectsSection.presets,
      controller: _liveVideoEffectsController,
    );

    // Android can reveal navigation controls when a modal sheet closes.
    // Hide only the bottom system controls again, keeping the status bar.
    if (mounted) {
      await _enterVideoLiveSystemUi();
    }
  }

  Widget _buildBottomPkLauncher() {
    final bool running = liveController.pkIsRunning.value;

    Widget visual({required bool active}) {
      return Container(
        width: 44,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(.12),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            ShaderMask(
              shaderCallback: (Rect bounds) {
                return const LinearGradient(
                  colors: [
                    Color(0xFFFFD34E),
                    Color(0xFFFF8B32),
                    Color(0xFFFF4AA8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds);
              },
              blendMode: BlendMode.srcIn,
              child: const Text(
                'PK',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  height: 1,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.5,
                ),
              ),
            ),
            if (active)
              Positioned(
                right: 1,
                top: 2,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF32E6A1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    if (running) {
      return visual(active: true);
    }

    // PkRequestButton already contains all the existing PK request/business
    // logic. Keep it as the tap target but paint the compact reference-style
    // PK icon above it so no PK behavior is duplicated or changed.
    return SizedBox(
      width: 44,
      height: 42,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRect(
            child: Opacity(
              opacity: .01,
              child: FittedBox(
                fit: BoxFit.fill,
                child: SizedBox(
                  width: 44,
                  height: 42,
                  child: PkRequestButton(
                    currentLivestreamId: _safeStreamId(),
                    currentHostId:
                    authController.userProfile.value.user?.id?.toInt() ?? 0,
                  ),
                ),
              ),
            ),
          ),
          IgnorePointer(child: visual(active: false)),
        ],
      ),
    );
  }

  Future giftBottomSheet(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Color(0xff16261c),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // **Premium Banner**
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: IconButton(
                    onPressed: () => Get.back(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xff24a177),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    icon: Icon(Icons.close, color: Colors.red),
                  ),
                ),
              ],
            ),

            SizedBox(height: 12),

            // **Title**
            Text(
              ("Choose Your Gift 🎁").appTr,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 12),

            // **Gift GridView**
            Obx(() {
              return livestreamController.giftList.isEmpty
                  ? Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  ("No gifts available 😔").appTr,
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              )
                  : Padding(
                padding: const EdgeInsets.all(8.0),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisExtent: 120,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: livestreamController.giftList.length,
                  itemBuilder: (context, index) {
                    final gift = livestreamController.giftList[index];
                    bool isSelected =
                        livestreamController.selectedGiftId.value ==
                            gift['id'];
                    return GestureDetector(
                      onTap: () {
                        livestreamController.selectedGiftId.value =
                        gift['id'];
                        setState(() {});
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Color(0xff16261c)
                              : Color(0xff16261c),
                          border: Border.all(
                            color: isSelected
                                ? Color(0xff24a177)
                                : Color(0xff16261c),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // **Gift Image**
                            gift['gift_image'].toString().endsWith(
                              '.svga',
                            )
                                ? SizedBox(
                              height: kHeight * 0.05,
                              width: kHeight * 0.05,
                              child: SVGAEasyPlayer(
                                resUrl:
                                "$kDomainUrl/${gift['gift_image']}",
                                fit: BoxFit.cover,
                              ),
                            )
                                : ClipRRect(
                              borderRadius: BorderRadius.circular(
                                10,
                              ),
                              child: Image.network(
                                "$kDomainUrl/${gift['gift_image']}",
                                height: 50,
                                width: 50,
                                fit: BoxFit.cover,
                              ),
                            ),
                            SizedBox(height: 8),

                            // **Gift Name**
                            Text(
                              gift['name'],
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 4),

                            // **Gift Coin Price**
                            Center(
                              child: Row(
                                mainAxisAlignment:
                                MainAxisAlignment.center,
                                children: [
                                  Image(
                                    image: AssetImage(
                                      'assets/icons/coin.png',
                                    ),
                                    height: 10,
                                  ),
                                  SizedBox(width: 7),
                                  Text(
                                    "${gift['coin']}  ",
                                    style: TextStyle(
                                      color: Colors.white38,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            }),

            SizedBox(height: 16),

            Obx(() {
              return livestreamController.selectedGiftId.value != 0
                  ? Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      final int selectedGiftPrice =
                      _selectedGiftCoinPrice();
                      if (selectedGiftPrice <= 0) {
                        Fluttertoast.showToast(
                          msg: ('Gift price not found').appTr,
                          gravity: ToastGravity.BOTTOM,
                        );
                        return;
                      }

                      livestreamController.tryToSendGift(
                        receiverId:
                        livestreamController.broadcasterId.value,
                        giftId: livestreamController.selectedGiftId.value,
                        giftPrice: selectedGiftPrice,
                      );

                      Get.back();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        vertical: 1,
                        horizontal: 10,
                      ),
                      backgroundColor: Colors.greenAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Text(
                        ("Send").appTr,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              )
                  : SizedBox();
            }),
          ],
        ),
      ),
    );
  }
}