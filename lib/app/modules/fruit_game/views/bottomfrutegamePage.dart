import 'dart:async';
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_fortune_wheel/flutter_fortune_wheel.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gradient_borders/box_borders/gradient_box_border.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';

import '../../../../constants/image_helper.dart';
import '../../../../constants/layout_constant.dart';
import '../../auth/controllers/auth_controller.dart';
import '../controllers/fruit_game_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class BottomGamePage extends StatefulWidget {
  const BottomGamePage({Key? key}) : super(key: key);

  @override
  State<BottomGamePage> createState() => _BottomGamePageState();
}

class _BottomGamePageState extends State<BottomGamePage> {
  StreamController<int> controller = StreamController<int>.broadcast();
  final List<Worker> _controllerWorkers = <Worker>[];
  final fruitController = Get.put(FruitGameController());
  AuthController authController = Get.find();
  List items = [];

  int selectedNumBerCount = 0,
      selectedNumber1 = 0,
      selectedNumber2 = 0,
      selectedAmount = 0;
  bool winDone = false;

  // ✅ Professional 25s round config
  // Backend may send 25 directly, or old 50-style timer. Controller normalizes it.
  static const int gameRoundSeconds = 25;
  static const int bettingCloseAt = 5;
  static const int spinStartAt = 5;

  bool _roundResetDone = false;
  bool _spinStartedForRound = false;
  bool _resultDialogShownForRound = false;
  Timer? _loadingTimer;

  int coinsFor1 = 0, coinsFor2 = 0, coinsFor3 = 0;

  bool pot1Selected = false, pot2Selected = false, pot3Selected = false;
  int totalBetAmount = 0, totalWinAmount = 0;

  void resetGameState() {
    fruitController.amount1.value = 0;
    fruitController.amount2.value = 0;
    fruitController.amount3.value = 0;

    totalBetAmount = 0;
    totalWinAmount = 0;
    selectedNumBerCount = 0;
    selectedNumber1 = 0;
    selectedNumber2 = 0;
    coinsFor1 = 0;
    coinsFor2 = 0;
    coinsFor3 = 0;
    pot1Selected = false;
    pot2Selected = false;
    pot3Selected = false;
    winDone = false;
    _roundResetDone = false;
    _spinStartedForRound = false;
    _resultDialogShownForRound = false;
    animationImage.value = '';
    stopCoinsAudio();
    if (mounted) {
      setState(() {});
    }
  }

  final AudioPlayer audioPlayerBackground = AudioPlayer();
  final AudioPlayer audioPlayerCoins = AudioPlayer();

  Future<void> stopBackgroundAudio() async {
    await audioPlayerBackground.stop();
  }

  Future<void> stopCoinsAudio() async {
    await audioPlayerCoins.stop();
  }

  final animationImage = ''.obs;

  void setupControllerObservers() {
    _controllerWorkers.add(ever(fruitController.winnerNumber, (winnerNum) {
      final int winner = int.tryParse(winnerNum.toString()) ?? 0;
      if (winner > 0) {
        debugPrint('🏆 FruitGame winner received => $winner');
      }
      if (mounted) setState(() {});
    }));

    DateTime? lastRoundStartAt;

    _controllerWorkers.add(ever(fruitController.remainingTime, (int rawTime) {
      final int time = rawTime.clamp(0, gameRoundSeconds).toInt();
      debugPrint('⏱️ FruitGame remainingTime => $time');

      // ✅ New round: reset at 25/24. This keeps the UI ready fast and prevents 1s stuck.
      if (time >= gameRoundSeconds - 1) {
        if (!_roundResetDone) {
          if (lastRoundStartAt != null) {
            final diff = DateTime.now().difference(lastRoundStartAt!);
            debugPrint('⏰ Next round gap => ${diff.inSeconds}s');
          }

          debugPrint('✅ FruitGame new round reset');
          resetGameState();
          _roundResetDone = true;
          lastRoundStartAt = DateTime.now();
        }
      } else if (time <= gameRoundSeconds - 2) {
        _roundResetDone = false;
      }

      // ✅ Last 5 seconds: close bet and start spin once.
      if (time == spinStartAt && !_spinStartedForRound) {
        _spinStartedForRound = true;
        debugPrint('🎡 FruitGame spin start at ${spinStartAt}s');
        fruitController.playSpinSound();

        Future.delayed(const Duration(milliseconds: 250), () {
          final int winner = fruitController.winnerNumber.value;
          if (winner > 0 && !controller.isClosed) {
            try {
              controller.add(winner);
            } catch (_) {}
          }
        });
      }

      // ✅ At 0: stop sound and sync coin snapshot if wheel did not already finish.
      if (time == 0) {
        debugPrint('🛑 FruitGame round reached 0');
        Future.delayed(const Duration(milliseconds: 350), () async {
          await fruitController.fetchUserCoins();
          if (mounted) setState(() {});
        });
      }

      if (mounted) setState(() {});
    }));

    _controllerWorkers.add(ever(fruitController.amount1, (_) {
      if (mounted) setState(() {});
    }));
    _controllerWorkers.add(ever(fruitController.amount2, (_) {
      if (mounted) setState(() {});
    }));
    _controllerWorkers.add(ever(fruitController.amount3, (_) {
      if (mounted) setState(() {});
    }));
    _controllerWorkers.add(ever(fruitController.activeUsers, (_) {
      if (mounted) setState(() {});
    }));
  }


  final AudioPlayer audioPlayer = AudioPlayer();

  String formatNumber(int number) {
    if (number < 1000) {
      return number.toString();
    } else {
      double result = number / 1000;
      return '${result.toStringAsFixed(result.truncateToDouble() == result ? 0 : 1)}k';
    }
  }

  @override
  @override
  void initState() {
    super.initState();

    fruitController.userCurrentCoins.value =
        int.tryParse(authController.userProfile.value.user!.coins!.toString()) ?? 0;

    setupControllerObservers();

    _loadingTimer = Timer(const Duration(milliseconds: 850), () {
      if (!mounted) return;
      setState(() => isLoading = false);
    });

    fruitController.joinGame(
      userId: authController.userProfile.value.user!.id!.toInt(),
    );
    fruitController.fetchStatus();
  }


  @override
  @override
  void dispose() {
    _loadingTimer?.cancel();
    for (final Worker worker in _controllerWorkers) {
      worker.dispose();
    }
    _controllerWorkers.clear();
    fruitController.stopBgm();
    fruitController.leaveGame(
      userId: authController.userProfile.value.user!.id!.toInt(),
    );
    controller.close();
    super.dispose();
  }


  void showWinDialog({
    required BuildContext context,
    required int bitAmount,
    required int winAmount,
  }) {
    Get.dialog(
      Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
          height: 160,
          width: 260,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(0),
            border: GradientBoxBorder(
              gradient: LinearGradient(
                colors: [
                  Colors.purpleAccent,
                  Colors.blueAccent,
                  Colors.cyanAccent,
                ],
              ),
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 15,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                ("Your Bet: $bitAmount").appTr,
                style: const TextStyle(
                  decoration: TextDecoration.none,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                  fontSize: 18,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                ("You Win: $winAmount").appTr,
                style: const TextStyle(
                  decoration: TextDecoration.none,
                  color: Colors.deepPurple,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );

    Future.delayed(const Duration(seconds: 4), () {
      Get.back();
    });
  }

  bool isLoading = true;
  final isMute = false.obs;

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Scaffold(
      // Use Scaffold for a full-screen page
      body: Container(
        height: size.height, // Full height
        width: size.width, // Full width
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xff301d53),
              Color(0xFFd85466),
              Color(0xFF080e6f),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          // Removed borderRadius as it's a full screen, not a bottom sheet
          // borderRadius: BorderRadius.only(
          //   topLeft: Radius.circular(30),
          //   topRight: Radius.circular(30),
          // ),
        ),
        child: isLoading ? _buildLoadingScreen() : _buildGameScreen(size),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xff12001f), Color(0xff3b1168), Color(0xff080e6f)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.purpleAccent.withOpacity(.45),
                    blurRadius: 35,
                    spreadRadius: 8,
                  ),
                ],
              ),
              child: Image.asset(
                "assets/game/fruitloop.png",
                height: MediaQuery.of(context).size.height * 0.34,
              ),
            ),
            const SizedBox(height: 26),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: LinearPercentIndicator(
                width: MediaQuery.of(context).size.width * 0.75,
                animation: true,
                animationDuration: 800,
                lineHeight: 18.0,
                percent: 1,
                center: const Text(
                  "100%",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                barRadius: const Radius.circular(15),
                linearStrokeCap: LinearStrokeCap.roundAll,
                progressColor: const Color(0xffffc837),
                backgroundColor: const Color(0xff613479),
                curve: Curves.easeOutCubic,
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildGameScreen(Size size) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Background Image
        const SizedBox.expand(
          child: Image(
            image: AssetImage(
              "assets/audio_live/116398-abstract-dark-blue-blurred-bokeh-background-design.jpg",
            ),
            fit: BoxFit.cover,
          ),
        ),

        // Main Game Content
        Center(
          child: Padding(
            padding: EdgeInsets.only(
              left: kWeight * 0.01,
              right: kWeight * 0.01,
              top: kHeight * 0.04,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildPlayerColumn(0, 3),
                SizedBox(width: kWeight * 0.01),
                _buildGamePots(size),
                SizedBox(width: kWeight * 0.01),
                _buildPlayerColumn(3, 6),
              ],
            ),
          ),
        ),

        // Bottom Coin Selection Bar
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildCoinSelectionBar(size),
        ),

        // Top Action Buttons
        Positioned(
          top: kHeight * 0.015,
          right: kWeight * 0.01,
          child: _buildTopActionButtons(),
        ),

        // Back & Trending Buttons

        // Fortune Wheel
        Positioned(
          top: -MediaQuery.of(context).size.height * 0.04,
          left: 0,
          right: 0,
          child: Center(child: _buildFortuneWheel()),
        ),

        // Spin Frame
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Image.asset(
            'assets/game/spin_frame.png',
            height: kHeight * 0.17,
          ),
        ),

        // Timer (shows only when time <= 10)
        if (fruitController.remainingTime.value <= gameRoundSeconds &&
            fruitController.remainingTime.value > 0)
          Positioned(
            top: size.height * .07,
            right: size.width * .15,
            child: _buildTimerWidget(), // ✅ renamed for clarity
          ),

        // Game Status Messages
        Positioned(
          top: size.height * .093,
          left: 0,
          right: 0,
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: kWeight * 0.06),
              child: _buildGameStatusMessage(size),
            ),
          ),
        ),
        Positioned(
          top: kHeight * 0.015,
          left: kWeight * 0.01,
          child: Row(
            children: [
              _buildBackButton(),
              SizedBox(width: kWeight * 0.04),
              _buildTrendingButton(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimerWidget() {
    return Obx(() {
      final int time = fruitController.remainingTime.value.clamp(0, gameRoundSeconds).toInt();
      final bool isClosing = time <= bettingCloseAt && time > 0;

      final timerBox = Container(
        padding: EdgeInsets.symmetric(
          horizontal: isClosing ? 18 : 13,
          vertical: isClosing ? 8 : 6,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isClosing
                ? const [Color(0xffff512f), Color(0xffdd2476)]
                : const [Color(0xff24243e), Color(0xff302b63), Color(0xff0f0c29)],
          ),
          borderRadius: BorderRadius.circular(isClosing ? 16 : 12),
          border: Border.all(
            color: isClosing ? Colors.yellowAccent : Colors.white.withOpacity(.9),
            width: isClosing ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: (isClosing ? Colors.redAccent : Colors.indigoAccent)
                  .withOpacity(.45),
              blurRadius: isClosing ? 24 : 14,
              spreadRadius: isClosing ? 4 : 1,
              offset: const Offset(0, 8),
            ),
            const BoxShadow(
              color: Colors.black54,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          time.toString(), // ✅ 1 second = 1 second
          style: TextStyle(
            fontSize: isClosing ? 34 : 24,
            color: Colors.white,
            fontWeight: FontWeight.w900,
            shadows: const [
              Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2)),
            ],
          ),
        ),
      );

      if (!isClosing) return timerBox;

      return TweenAnimationBuilder<double>(
        key: ValueKey(time),
        tween: Tween<double>(begin: 0.7, end: 1.18),
        duration: const Duration(milliseconds: 420),
        curve: Curves.elasticOut,
        builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
        child: timerBox,
      );
    });
  }


  Widget _buildPlayerColumn(int start, int end) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        end - start,
            (index) => Padding(
          padding: EdgeInsets.only(bottom: kHeight * 0.025),
          child: SizedBox(
            height: kHeight * 0.045,
            width: kHeight * 0.045,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (fruitController.activeUsers.length > start + index)
                  CachedNetworkImage(
                    imageUrl: ImageHelper.getImageUrl(
                      fruitController.activeUsers[start + index]
                      ['profile_image'],
                    ),
                    height: kHeight * 0.04,
                    fit: BoxFit.contain,
                  )
                else
                  Container(),
                const Image(
                  image: AssetImage("assets/game/profile_frame.png"),
                  fit: BoxFit.fill,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGamePots(Size size) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      margin: EdgeInsets.only(top: 0, bottom: kHeight * 0.02),
      height: kHeight * 0.17,
      width: kWeight * 0.70,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff8f46ff), Color(0xff4b1dd8), Color(0xff1f1268)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xffffd45a), width: 1.7),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff6939fd).withOpacity(.55),
            blurRadius: 25,
            spreadRadius: 2,
            offset: const Offset(0, 10),
          ),
          const BoxShadow(
            color: Colors.black54,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildPot(
            fruitImage: "assets/game/orange.png",
            potColor: Colors.orange,
            potAmount: fruitController.amount1.value,
            userAmount: coinsFor1,
            onTap: () => _placeBet(1),
            isWinner: winDone && fruitController.winnerNumber.value == 1,
          ),
          _buildPot(
            fruitImage: "assets/game/watermelon.png",
            potColor: Colors.green,
            potAmount: fruitController.amount2.value,
            userAmount: coinsFor2,
            onTap: () => _placeBet(2),
            isWinner: winDone && fruitController.winnerNumber.value == 2,
          ),
          _buildPot(
            fruitImage: "assets/game/apple.png",
            potColor: Colors.red,
            potAmount: fruitController.amount3.value,
            userAmount: coinsFor3,
            onTap: () => _placeBet(3),
            isWinner: winDone && fruitController.winnerNumber.value == 3,
          ),
        ],
      ),
    );
  }


  Widget _buildPot({
    required String fruitImage,
    required Color potColor,
    required int potAmount,
    required int userAmount,
    required VoidCallback onTap,
    required bool isWinner,
  }) {
    final Color baseColor = (winDone && !isWinner) ? Colors.blueGrey : potColor;
    final bool isDimmed = winDone && !isWinner;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutBack,
        scale: isWinner ? 1.08 : 1.0,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              height: kHeight * 0.038,
              width: kHeight * 0.038,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(.95),
                    baseColor.withOpacity(.35),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: baseColor.withOpacity(.55),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Image.asset(fruitImage, fit: BoxFit.contain),
            ),
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: kHeight * 0.085,
                  width: kWeight * 0.205,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        baseColor.withOpacity(isDimmed ? .50 : .95),
                        baseColor.withOpacity(isDimmed ? .35 : .70),
                        Colors.black.withOpacity(.25),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isWinner
                          ? Colors.yellowAccent
                          : Colors.white.withOpacity(.35),
                      width: isWinner ? 2.4 : 1.1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: baseColor.withOpacity(isWinner ? .70 : .40),
                        blurRadius: isWinner ? 22 : 14,
                        spreadRadius: isWinner ? 3 : 1,
                        offset: const Offset(0, 9),
                      ),
                      const BoxShadow(
                        color: Colors.black54,
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Opacity(
                          opacity: .9,
                          child: Image.asset(
                            "assets/game/potframe.png",
                            fit: BoxFit.fill,
                          ),
                        ),
                      ),
                      Positioned(
                        right: -8,
                        bottom: -10,
                        child: Opacity(
                          opacity: .22,
                          child: Image.asset(
                            fruitImage,
                            height: kHeight * 0.075,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isWinner)
                  Positioned(
                    top: -9,
                    right: -5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.yellowAccent,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: const [
                          BoxShadow(color: Colors.black38, blurRadius: 8),
                        ],
                      ),
                      child:  Text(
                        ('WIN').appTr,
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: kHeight * 0.010,
                  left: kWeight * 0.012,
                  child: _potText('Pot: ', potAmount),
                ),
                Positioned(
                  bottom: kHeight * 0.013,
                  left: kWeight * 0.012,
                  child: _potText('YOU: ', userAmount),
                ),
                Positioned(
                  top: kHeight * 0.030,
                  right: kWeight * 0.018,
                  child: Text(
                    ('x3').appTr,
                    style: TextStyle(
                      color: Colors.white.withOpacity(.82),
                      fontSize: kHeight * 0.026,
                      fontWeight: FontWeight.w900,
                      shadows: const [
                        Shadow(
                          color: Colors.black45,
                          blurRadius: 5,
                          offset: Offset(1, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _potText(String label, int value) {
    return Row(
      children: [
        Text(
          label,
          style: GoogleFonts.roboto(
            color: Colors.white,
            fontSize: kHeight * 0.012,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          formatNumber(value),
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: kHeight * 0.012,
            fontStyle: FontStyle.italic,
            shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
          ),
        ),
      ],
    );
  }

  Future<void> _placeBet(int betType) async {
    final int time = fruitController.remainingTime.value;

    if (selectedAmount <= 0) {

      return;
    }

    // ✅ 25s round: bet from 25 -> 6. Last 5 seconds closed.
    if (time <= bettingCloseAt || time > gameRoundSeconds) {

      return;
    }

    final bool alreadySelected = betType == 1
        ? pot1Selected
        : betType == 2
        ? pot2Selected
        : pot3Selected;

    if (!alreadySelected && selectedNumBerCount >= 2) {
      Get.snackbar(
        ('Limit Reached').appTr,
        ('You can bet only 2 fruits in one round').appTr,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
      return;
    }

    if (selectedAmount > fruitController.userCurrentCoins.value) {
      Get.snackbar(
        ('Insufficient Balance').appTr,
        ('Please recharge').appTr,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
      return;
    }

    // ✅ API first. If server rejects, local UI will not fake-bet.
    final bool betOk = await fruitController.placeBet(
      userId: authController.userProfile.value.user!.id!.toInt(),
      betType: betType,
      amount: selectedAmount,
    );

    if (!betOk) {
      Get.snackbar(
        ('Bet Failed').appTr,
        ('Please try again').appTr,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
      return;
    }

    if (!mounted) return;

    setState(() {
      if (betType == 1) {
        coinsFor1 += selectedAmount;
        if (!pot1Selected) {
          pot1Selected = true;
          selectedNumBerCount++;
        }
      } else if (betType == 2) {
        coinsFor2 += selectedAmount;
        if (!pot2Selected) {
          pot2Selected = true;
          selectedNumBerCount++;
        }
      } else if (betType == 3) {
        coinsFor3 += selectedAmount;
        if (!pot3Selected) {
          pot3Selected = true;
          selectedNumBerCount++;
        }
      }

      totalBetAmount += selectedAmount;
    });
  }


  Widget _buildCoinSelectionBar(Size size) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: EdgeInsets.only(
          bottom: size.height * 0.018,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: size.width * 0.015,
        ),
        height: size.height * 0.07,
        // responsive height
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF41416E),
              const Color(0x7E9494E3),
              const Color(0xFF41416E),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.only(
              topRight: Radius.circular(kHeight * 0.03),
              topLeft: Radius.circular(kHeight * 0.03)),
          boxShadow: [
            BoxShadow(
              color: Colors.purpleAccent.withOpacity(0.4),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildCoinDisplay(),
            _buildCoinButton(500),
            _buildCoinButton(1000),
            _buildCoinButton(10000),
            _buildCoinButton(50000),
            _buildCoinButton(100000),
          ],
        ),
      ),
    );
  }

  Widget _buildCoinDisplay() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: kWeight * 0.008),
      height: kHeight * 0.04,
      width: MediaQuery.of(context).size.width * .15,
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset("assets/game/diamond.png", height: kHeight * 0.017),
          SizedBox(
            width: kWeight * 0.002,
          ),
          Flexible(
            child: Obx(
                  () {
                double fontSize = kHeight * 0.016;
                int coinValue = fruitController.userCurrentCoins.value;

                if (coinValue >= 10000000) {
                  fontSize = kHeight * 0.010; // 10M+
                } else if (coinValue >= 1000000) {
                  fontSize = kHeight * 0.011; // 1M+
                } else if (coinValue >= 100000) {
                  fontSize = kHeight * 0.012; // 100K+
                }

                return FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    formatNumber(coinValue),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoinButton(int amount) {
    String displayText =
    amount < 1000 ? amount.toString() : '${amount ~/ 1000}k';
    return InkWell(
      onTap: () => setState(() => selectedAmount = amount),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Image(
              image: AssetImage(
                amount == 1000 || amount == 50000
                    ? "assets/game/casino3.png"
                    : "assets/game/casino2.png",
              ),
              height:
              selectedAmount == amount ? kHeight * 0.07 : kHeight * 0.06,
              width: selectedAmount == amount ? kHeight * 0.07 : kHeight * 0.06,
            ),
            Text(
              displayText,
              style: TextStyle(
                color: Colors.white,
                fontSize: kHeight * 0.011,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendingButton() {
    return InkWell(
      onTap: () => _showTrendingDialog(),
      child: Container(
        height: kHeight * 0.03,
        width: kHeight * 0.03,
        decoration: const BoxDecoration(
          color: Colors.pink,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.trending_up, color: Colors.white),
      ),
    );
  }

  void _showTrendingDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            height: MediaQuery.of(context).size.height * 0.4, // Medium height
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF2A1A4D),
                  const Color(0xFF1A1335),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.purpleAccent.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.purpleAccent.withOpacity(0.3),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              children: [
                // Header Section
                Container(
                  padding: EdgeInsets.symmetric(
                    vertical: kHeight * 0.01,
                    horizontal: kWeight * 0.04,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.purpleAccent.withOpacity(0.2),
                        Colors.transparent,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.trending_up,
                            color: Colors.purpleAccent,
                            size: kHeight * 0.025,
                          ),
                          SizedBox(width: kWeight * 0.02),
                          Text(
                            ('Fruits Trending').appTr,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: kHeight * 0.02,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: EdgeInsets.all(kHeight * 0.008),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.close,
                            color: Colors.white70,
                            size: kHeight * 0.02,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Fruit Icons Section
                Container(
                  margin: EdgeInsets.symmetric(
                    vertical: kHeight * 0.01,
                    horizontal: kWeight * 0.04,
                  ),
                  padding: EdgeInsets.symmetric(
                    vertical: kHeight * 0.012,
                    horizontal: kWeight * 0.04,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D1F4A).withOpacity(0.5),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: Colors.purpleAccent.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildFruitIcon("assets/game/orange.png", "Orange"),
                      _buildFruitIcon("assets/game/watermelon.png", "Melon"),
                      _buildFruitIcon("assets/game/apple.png", "Apple"),
                    ],
                  ),
                ),

                // List Section
                Expanded(
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: kWeight * 0.04),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1335).withOpacity(0.3),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Obx(() {
                      if (fruitController.winnerTrend.isEmpty) {
                        return Center(
                          child: Text(
                            ('No trending data yet').appTr,
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: kHeight * 0.016,
                            ),
                          ),
                        );
                      }
                      return ListView.builder(
                        padding: EdgeInsets.all(kWeight * 0.01),
                        itemCount: fruitController.winnerTrend.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: EdgeInsets.only(bottom: kHeight * 0.006),
                            child: Container(
                              height: kHeight * 0.03,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF442C68).withOpacity(0.6),
                                    const Color(0xFF2D1F4A).withOpacity(0.4),
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.purpleAccent.withOpacity(0.1),
                                  width: 1,
                                ),
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: kWeight * 0.03,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceAround,
                                children: [
                                  _buildResultText(
                                    fruitController.winnerTrend[index]
                                    ['field1'],
                                  ),
                                  _buildResultText(
                                    fruitController.winnerTrend[index]
                                    ['field2'],
                                  ),
                                  _buildResultText(
                                    fruitController.winnerTrend[index]
                                    ['field3'],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    }),
                  ),
                ),

                SizedBox(height: kHeight * 0.015),
              ],
            ),
          ),
        );
      },
    );
  }

// Helper Widget for Fruit Icons
  Widget _buildFruitIcon(String assetPath, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.all(kHeight * 0.008),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.purpleAccent.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Image.asset(
            assetPath,
            width: kHeight * 0.025,
            height: kHeight * 0.025,
          ),
        ),
        SizedBox(height: kHeight * 0.005),
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: kHeight * 0.01,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

// Helper Widget for Result Text
  Widget _buildResultText(String? value) {
    bool isWin = value == 'Win';
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: kWeight * 0.025,
        vertical: kHeight * 0.004,
      ),
      decoration: BoxDecoration(
        color: isWin ? Colors.pink.withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isWin
            ? Border.all(color: Colors.pink.withOpacity(0.5), width: 1)
            : null,
      ),
      child: Text(
        isWin ? ('WIN').appTr: '—',
        style: TextStyle(
          color: isWin ? Colors.pink : Colors.white38,
          fontSize: kHeight * 0.01,
          fontWeight: isWin ? FontWeight.bold : FontWeight.normal,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTopActionButtons() {
    return Row(
      children: [
        _buildSettingButton(),
        SizedBox(width: kWeight * 0.03),
        // InkWell(
        //   child: Container(
        //     height: kHeight * 0.02,
        //     width: kHeight * 0.02,
        //     child: const Image(
        //       image: AssetImage("assets/game/question-mark.png"),
        //       fit: BoxFit.fill,
        //     ),
        //   ),
        // ),
        // const SizedBox(width: 15),
        _buildPlayerListButton(),
      ],
    );
  }

  Widget _buildSettingButton() {
    return InkWell(
      onTap: () => _showSettingsDialog(),
      child: Container(
        height: kHeight * 0.035,
        width: kHeight * 0.035,
        child: const Image(
          image: AssetImage("assets/game/setting.png"),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  void _showSettingsDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) {
        return Align(
          alignment: Alignment.bottomCenter, // 👈 নিচে show হবে
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1), // নিচ থেকে আসবে
              end: Offset.zero,
            ).animate(
                CurvedAnimation(parent: anim1, curve: Curves.easeOutBack)),
            child: Container(
              margin: const EdgeInsets.only(bottom: 25, left: 16, right: 16),
              padding: const EdgeInsets.all(20),
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                gradient: const LinearGradient(
                  colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueAccent.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                     Text(
                      ('🎵 Sound Setting').appTr,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        decoration: TextDecoration.none,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 20),
                    InkWell(
                      onTap: () {
                        if (isMute.value) {
                          // playAudio();
                        } else {
                          stopCoinsAudio();
                          stopBackgroundAudio();
                        }
                        isMute.value = !isMute.value;
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          color: Colors.white.withOpacity(0.15),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Obx(() => Icon(
                              isMute.value
                                  ? Icons.volume_off_rounded
                                  : Icons.volume_up_rounded,
                              size: 35,
                              color: Colors.white,
                            )),
                            const SizedBox(width: 12),
                             Text(
                              ("ON / OFF").appTr,
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                                decoration: TextDecoration.none,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child:  Text(
                        ('Close').appTr,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlayerListButton() {
    return InkWell(
      onTap: () => _showPlayerListDialog(),
      child: Container(
        height: kHeight * 0.03,
        width: kHeight * 0.03,
        child: const Image(
          image: AssetImage("assets/game/group.png"),
          fit: BoxFit.fill,
        ),
      ),
    );
  }

  void _showPlayerListDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) {
        final size = MediaQuery.of(context).size;

        return Align(
          alignment: Alignment.bottomCenter,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(
                CurvedAnimation(parent: anim1, curve: Curves.easeOutBack)),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(25),
                topRight: Radius.circular(25),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  width: size.width * 0.94,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF141E30).withOpacity(0.8),
                        const Color(0xFF243B55).withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(25),
                      topRight: Radius.circular(25),
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blueAccent.withOpacity(0.3),
                        blurRadius: 25,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 60,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                         Text(
                          ('👥 Player List').appTr,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: 'Poppins',
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          height: size.height * 0.42,
                          child: GridView.builder(
                            shrinkWrap: true,
                            gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: size.width > 600 ? 5 : 3,
                              crossAxisSpacing: 14.0,
                              mainAxisSpacing: 14.0,
                              childAspectRatio: 0.9,
                            ),
                            itemCount: fruitController.activeUsers.length,
                            itemBuilder: (BuildContext context, int index) {
                              final user = fruitController.activeUsers[index];
                              return Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF00C6FF),
                                      Color(0xFF0072FF)
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.lightBlueAccent
                                          .withOpacity(0.4),
                                      blurRadius: 10,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                          BorderRadius.circular(100),
                                          child: CachedNetworkImage(
                                            imageUrl: ImageHelper.getImageUrl(
                                                user['profile_image']),
                                            height: 55,
                                            width: 55,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        const Image(
                                          image: AssetImage(
                                              "assets/game/profile_frame.png"),
                                          height: 65,
                                          fit: BoxFit.fill,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      user['full_name'],
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.15),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 35, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () => Navigator.pop(context),
                          child:  Text(
                            ("Close").appTr,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBackButton() {
    return InkWell(
      onTap: () => Navigator.of(context).pop(true),
      child: Container(
        height: kHeight * 0.035,
        width: kHeight * 0.035,
        child: const Image(
          image: AssetImage("assets/game/less-than_18757930.png"),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildFortuneWheel() {
    return SizedBox(
      height: kHeight * 0.16,
      width: kHeight * 0.31,
      child: FortuneWheel(
        onAnimationStart: () {},
        selected: controller.stream,
        styleStrategy: const UniformStyleStrategy(
          borderColor: Colors.transparent,
          color: Colors.blueAccent,
        ),
        indicators: const <FortuneIndicator>[
          FortuneIndicator(
            alignment: Alignment.topCenter,
            child: TriangleIndicator(color: Colors.deepOrange),
          ),
        ],
        onAnimationEnd: () {
          fruitController.stopSpinSound();

          if (_resultDialogShownForRound) return;
          _resultDialogShownForRound = true;

          setState(() {
            winDone = true;

            // ✅ Bet amount আগেই balance থেকে কাটা হয়েছে।
            // ✅ Win হলে শুধু payout add হবে, loss হলে আর কিছু add হবে না।
            if (fruitController.winnerNumber.value == 1) {
              totalWinAmount += coinsFor1 * 3;
            } else if (fruitController.winnerNumber.value == 2) {
              totalWinAmount += coinsFor2 * 3;
            } else if (fruitController.winnerNumber.value == 3) {
              totalWinAmount += coinsFor3 * 3;
            }

            if (totalWinAmount > 0) {
              fruitController.userCurrentCoins.value += totalWinAmount;
            }
          });

          if (totalBetAmount > 0) {
            showWinDialog(
              context: context,
              bitAmount: totalBetAmount,
              winAmount: totalWinAmount,
            );
          }
        },
        animateFirst: false,
        items: [
          FortuneItem(
            child: Container(
              margin: const EdgeInsets.only(left: 20),
              child:
              Image.asset('assets/game/apple.png', height: kHeight * 0.022),
            ),
          ),
          FortuneItem(
            child: Container(
              margin: const EdgeInsets.only(left: 20),
              child: Image.asset('assets/game/orange.png',
                  height: kHeight * 0.022),
            ),
          ),
          FortuneItem(
            child: Container(
              margin: const EdgeInsets.only(left: 20),
              child: Image.asset('assets/game/watermelon.png',
                  height: kHeight * 0.022),
            ),
          ),
          FortuneItem(
            child: Container(
              margin: const EdgeInsets.only(left: 20),
              child:
              Image.asset('assets/game/apple.png', height: kHeight * 0.022),
            ),
          ),
          FortuneItem(
              child: Container(
                margin: const EdgeInsets.only(left: 20),
                child:
                Image.asset('assets/game/orange.png', height: kHeight * 0.022),
              )),
          FortuneItem(
            child: Container(
              margin: const EdgeInsets.only(left: 20),
              child: Image.asset('assets/game/watermelon.png',
                  height: kHeight * 0.022),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameStatusMessage(Size size) {
    String message = '';
    final int time = fruitController.remainingTime.value;

    if (time >= gameRoundSeconds - 1) {
      message = 'Start Bet';
    } else if (time <= bettingCloseAt && time > 0) {
      message = 'Stop Bet';
    } else if (time == 0) {
      message = 'Waiting for next Round';
    }

    if (message.isEmpty) return const SizedBox.shrink();

    return TweenAnimationBuilder<double>(
      key: ValueKey(message),
      tween: Tween<double>(begin: .85, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset('assets/game/waitingframe.png', height: size.height * .25),
          Text(
            message,
            style: GoogleFonts.roboto(
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              fontSize: kHeight * 0.02,
              shadows: const [
                Shadow(color: Colors.black87, blurRadius: 8, offset: Offset(0, 2)),
              ],
            ),
          ),
        ],
      ),
    );
  }

}
