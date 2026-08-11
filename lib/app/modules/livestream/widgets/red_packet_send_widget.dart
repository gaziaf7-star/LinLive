import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/livestream_controller.dart';
import '../socket/websocket_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class RedPacketSendWidget extends StatefulWidget {
  final int streamId;

  const RedPacketSendWidget({
    Key? key,
    required this.streamId,
  }) : super(key: key);

  @override
  State<RedPacketSendWidget> createState() => _RedPacketSendWidgetState();
}

class _RedPacketSendWidgetState extends State<RedPacketSendWidget> {
  final LivestreamController liveController = Get.find();
  final WebsocketController websocketController = Get.find();

  final TextEditingController amountController = TextEditingController();
  final TextEditingController messageController = TextEditingController();

  int selectedCoin = 20000;
  int selectedCount = 10;

  final List<int> coinOptions = [20000, 50000, 70000, 100000, 200000];
  final List<int> countOptions = [10, 20, 30, 50, 100];

  // Backend duration is expiry time. User can OPEN after 30s,
  // so backend expiry must be longer to prevent expired/finished errors.
  int selectedDurationSeconds = 120;
  final int openAfterSeconds = 30;
  String selectedScope = 'Current Stream';

  bool isLoading = false;

  // Bottom sheet top image.
  // Put this image in: assets/audio_live/coinRedpoket.png
  static const String topCoinAsset = 'assets/audio_live/coinRedpoket.png';

  // Small coin icon for balance and background watermark.
  static const String coinIconAsset = 'assets/frame/coin.png';

  @override
  void initState() {
    super.initState();
    amountController.text = selectedCoin.toString();
  }

  @override
  void dispose() {
    amountController.dispose();
    messageController.dispose();
    super.dispose();
  }

  void _selectCoin(int coin) {
    setState(() {
      selectedCoin = coin;
      amountController.text = coin.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: viewInsets),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Container(
              width: double.infinity,
              constraints: BoxConstraints(
                maxHeight: screenHeight * 0.74,
              ),
              margin: const EdgeInsets.only(left: 6, right: 6, top: 42),
              decoration: BoxDecoration(
                color: const Color(0xFFFF9D00),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(26),
                ),
                border: Border.all(
                  color: const Color(0xFFFFC400),
                  width: 5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 18,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _header(),
                  Flexible(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFF8D9),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(10),
                          topRight: Radius.circular(10),
                        ),
                      ),
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Stack(
                          children: [
                            Positioned(
                              right: -30,
                              bottom: -20,
                              child: Opacity(
                                opacity: 0.10,
                                child: Image.asset(
                                  coinIconAsset,
                                  width: 130,
                                  height: 130,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) {
                                    return const Icon(
                                      Icons.monetization_on,
                                      size: 120,
                                      color: Color(0xFFFFC107),
                                    );
                                  },
                                ),
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ('Coins').appTr,
                                  style: TextStyle(
                                    color: Color(0xFF3C2100),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _coinOptions(),
                                const SizedBox(height: 18),
                                Text(
                                  ('Number of Users').appTr,
                                  style: TextStyle(
                                    color: Color(0xFF3C2100),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _countOptions(),
                                const SizedBox(height: 22),
                                Center(
                                  child: _sendButton(),
                                ),
                                const SizedBox(height: 12),
                                Center(
                                  child: _balanceRow(),
                                ),
                                const SizedBox(height: 6),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Only your top image will show above the bottom sheet.
            Positioned(
              top: -62,
              child: _topCoinDecoration(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topCoinDecoration() {
    return SizedBox(
      width: 330,
      height: 125,
      child: Center(
        child: Image.asset(
          topCoinAsset,
          width: 330,
          height: 125,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) {
            return const SizedBox();
          },
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFFFF4A00),
            Color(0xFFFF9A00),
          ],
        ),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 23,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            decoration: BoxDecoration(
              color: const Color(0xFFFFC23A).withOpacity(0.95),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.35),
                width: 1,
              ),
            ),
            alignment: Alignment.center,
            child:  Text(
              ('Record').appTr,
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              ('Lucky Bag').appTr,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => Get.back(),
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFFC23A),
                border: Border.all(
                  color: Colors.white.withOpacity(0.45),
                  width: 1,
                ),
              ),
              alignment: Alignment.center,
              child: const Text(
                '?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _coinOptions() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: coinOptions.map((coin) {
          final bool selected = selectedCoin == coin;

          return Padding(
            padding: const EdgeInsets.only(right: 9),
            child: _optionPill(
              text: '$coin',
              selected: selected,
              onTap: () => _selectCoin(coin),
              minWidth: 68,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _countOptions() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: countOptions.map((count) {
          final bool selected = selectedCount == count;

          return Padding(
            padding: const EdgeInsets.only(right: 9),
            child: _optionPill(
              text: '$count',
              selected: selected,
              onTap: () {
                setState(() => selectedCount = count);
              },
              minWidth: 60,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _optionPill({
    required String text,
    required bool selected,
    required VoidCallback onTap,
    required double minWidth,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 33,
        constraints: BoxConstraints(minWidth: minWidth),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFF7A42),
              Color(0xFFFF3D16),
            ],
          )
              : const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFF0BB),
              Color(0xFFFFE29A),
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? const Color(0xFFFF6231) : const Color(0xFFFFE6A3),
            width: 1,
          ),
          boxShadow: selected
              ? [
            BoxShadow(
              color: const Color(0xFFFF3D16).withOpacity(0.25),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF9B6A13),
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _sendButton() {
    return GestureDetector(
      onTap: isLoading ? null : _sendRedPacket,
      child: Container(
        width: 245,
        height: 43,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFF59D),
              Color(0xFFFFB300),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF3D00).withOpacity(0.30),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(3),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFF6D21),
                Color(0xFFFF2100),
                Color(0xFFD91500),
              ],
            ),
            border: Border.all(
              color: const Color(0xFFFFF2A0),
              width: 1.2,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 12,
                right: 12,
                top: 4,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              Center(
                child: isLoading
                    ? const SizedBox(
                  width: 19,
                  height: 19,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                  ),
                )
                    :  Text(
                  ('Send').appTr,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(
                        color: Color(0x99000000),
                        offset: Offset(0, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _balanceRow() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          coinIconAsset,
          width: 15,
          height: 15,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) {
            return const Icon(
              Icons.monetization_on,
              size: 15,
              color: Color(0xFFFFC107),
            );
          },
        ),
        const SizedBox(width: 2),
        Text(
          _getCoinBalance(),
          style: const TextStyle(
            color: Color(0xFF7A4B00),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          ('Recharge >').appTr,
          style: TextStyle(
            color: Color(0xFFFF3D16),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  String _getCoinBalance() {
    try {
      final dynamic controller = liveController;

      final dynamic user =
          controller.user?.value ??
              controller.authUser?.value ??
              controller.currentUser?.value ??
              controller.profile?.value;

      final dynamic coins =
          user?.coins ??
              user?.balance ??
              user?.wallet ??
              controller.coins?.value ??
              0;

      return _formatCoins(coins);
    } catch (_) {
      return '0';
    }
  }

  String _formatCoins(dynamic value) {
    final raw = value == null ? '0' : value.toString().replaceAll(',', '');
    final number = double.tryParse(raw);

    if (number == null) return value.toString();

    final int coins = number.round();
    final String text = coins.toString();

    final buffer = StringBuffer();
    int count = 0;

    for (int i = text.length - 1; i >= 0; i--) {
      buffer.write(text[i]);
      count++;

      if (count == 3 && i != 0) {
        buffer.write(',');
        count = 0;
      }
    }

    return buffer.toString().split('').reversed.join();
  }



  Future<void> _sendRedPacket() async {
    if (isLoading) return;

    final String amountText = amountController.text.trim();
    final String messageText = messageController.text.trim();

    if (amountText.isEmpty) {
      Get.snackbar(
        ("Error").appTr,
        ("Please select coins").appTr,
        backgroundColor: Colors.red.withOpacity(0.85),
        colorText: Colors.white,
      );
      return;
    }

    final double? amount = double.tryParse(amountText);

    if (amount == null || amount <= 0) {

      return;
    }

    final int safeCount = selectedCount <= 0 ? 1 : selectedCount;
    final int safeDuration =
    selectedDurationSeconds <= 0 ? 120 : selectedDurationSeconds;

    /// ✅ Always global: all app pages + all live rooms will show the banner.
    final bool sendAsGlobal = true;

    final Map<String, dynamic> debugPayload = {
      'amount': amount.round(),
      'quantity': safeCount,
      'duration_seconds': safeDuration,
      'is_global': sendAsGlobal,
      'selected_scope': selectedScope,
      'message': messageText.isNotEmpty ? messageText : ('Sent you a Lucky Bag').appTr,
    };


    setState(() => isLoading = true);

    try {
      final bool success = await liveController.sendRedPacket(
        amount: amount,
        quantity: safeCount,
        durationSeconds: safeDuration,
        openAfterSeconds: openAfterSeconds,
        isGlobal: sendAsGlobal,
        message: messageText.isNotEmpty ? messageText : ('Sent you a Lucky Bag').appTr,
      );

      if (success) {
        if (Get.isBottomSheetOpen == true || Get.isDialogOpen == true) {
          Get.back();
        }

      } else {

      }
    } catch (e, stackTrace) {

    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }
}
