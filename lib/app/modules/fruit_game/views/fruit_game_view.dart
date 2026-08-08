import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
class FruitGameView extends StatefulWidget {
  const FruitGameView({Key? key}) : super(key: key);
  // removed: final List<dynamic> activeUsers;

  @override
  State<FruitGameView> createState() => _FruitGameViewState();
}

class _FruitGameViewState extends State<FruitGameView> {
  StreamController<int> controller = StreamController<int>.broadcast();
  final fruitController = Get.put(FruitGameController());
  AuthController authController = Get.find();
  List items = [];

  int selectedNumBerCount = 0,
      selectedNumber1 = 0,
      selectedNumber2 = 0,
      selectedAmount = 0;
  bool winDone = false;

  int coinsFor1 = 0, coinsFor2 = 0, coinsFor3 = 0;

  bool pot1Selected = false, pot2Selected = false, pot3Selected = false;
  int totalBetAmount = 0, totalWinAmount = 0;

  // Game state reset logic moved to controller observer
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
    animationImage.value = '';
    stopCoinsAudio();
    if (mounted) {
      setState(() {});
    }
  }

  final AudioPlayer audioPlayerBackground = AudioPlayer();
  final AudioPlayer audioPlayerCoins = AudioPlayer();

  Future<void> stopCoinsAudio() async {
    await audioPlayerCoins.stop();
  }

  final animationImage = ''.obs;

  // Controller observers will handle WebSocket events
  void setupControllerObservers() {
    // Listen to winner number changes
    ever(fruitController.winnerNumber, (winnerNum) {
      controller.add(winnerNum);
      if (mounted) {
        setState(() {});
      }
    });

    // Listen to remaining time changes
    DateTime? lastResetTime; // Class এর top এ declare করুন

    ever(fruitController.remainingTime, (int time) {
      switch (time) {
        case 20: // New round start (Backend থেকে automatically আসবে)
          if (lastResetTime != null) {
            final difference = DateTime.now().difference(lastResetTime!);
            print(
                "⏰ Next round আসতে সময় লেগেছে: ${difference.inSeconds} seconds");
          }

          print("game reset called");
          resetGameState();
          lastResetTime = DateTime.now(); // Reset time record করুন
          break;

        case 1:
          print("game reset time (case 1 hit)");
          fruitController.playSpinSound();
          Future.delayed(const Duration(milliseconds: 500), () {
            try {
              controller.add(fruitController.winnerNumber.value);
            } catch (_) {}
          });
          break;

        case 25:
          print("game reset win (case 24 hit)");
          Future.delayed(const Duration(milliseconds: 200), () async {
            await fruitController.fetchUserCoins();

            if (totalBetAmount > 0) {
              showWinDialog(
                context: context,
                bitAmount: totalBetAmount,
                winAmount: totalWinAmount,
              );
            }
            setState(() {});
          });
          break;

        default:
          print("⏱️ remainingTime: $time"); // সব time value দেখতে পারবেন
          break;
      }
    });
    // Listen to bet amounts changes
    ever(fruitController.amount1, (amount) {
      if (mounted) setState(() {});
    });
    ever(fruitController.amount2, (amount) {
      if (mounted) setState(() {});
    });
    ever(fruitController.amount3, (amount) {
      if (mounted) setState(() {});
    });

    // Listen to users list changes
    ever(fruitController.activeUsers, (usersList) {
      if (mounted) setState(() {});
    });
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
  void initState() {
    fruitController.userCurrentCoins.value =
        int.parse(authController.userProfile.value.user!.coins!);
    setupControllerObservers();
    // Join fruit game and fetch initial status
    fruitController.joinGame(
        userId: authController.userProfile.value.user!.id!.toInt());
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    fruitController.stopBgm();
    // Leave fruit game via API
    fruitController.leaveGame(
        userId: authController.userProfile.value.user!.id!.toInt());

    controller.close();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
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

    // Auto dispose the dialog after 1 second
    Future.delayed(const Duration(seconds: 4), () {
      Get.back();
    });
  }

  bool isLoading = true;
  final isMute = false.obs;

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    });
    return isLoading
        ? Scaffold(
            body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xff301d53),
                  Color(0xFFd85466),
                  Color(0xFF080e6f),
                  Color(0xFF080e6f),
                  Color(0xFFd85466),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  height: 20,
                ),
                Image.asset(
                  "assets/game/fruitloop.png",
                  height: 275,
                ),
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 55, left: 35),
                    alignment: Alignment.bottomCenter,
                    child: LinearPercentIndicator(
                      width: kWeight * 1.9,
                      animation: true,
                      animationDuration: 2000,
                      lineHeight: 18.0,
                      percent: 1,
                      center: const Text("100.0%"),
                      barRadius: const Radius.circular(15),
                      linearStrokeCap: LinearStrokeCap.roundAll,
                      progressColor: const Color(0xffCE6D1B),
                      backgroundColor: const Color(0xff613479),
                      curve: Curves.bounceIn,
                    ),
                  ),
                ),
              ],
            ),
          ))
        : WillPopScope(
            onWillPop: () async {
              bool? exitApp = await showGeneralDialog(
                context: context,
                barrierDismissible: false,
                barrierLabel: '',
                transitionDuration: const Duration(milliseconds: 300),
                pageBuilder: (context, anim1, anim2) {
                  return Center(
                    child: Container(
                      width: MediaQuery.of(context).size.width *
                          0.45, // ✅ 80% of screen width
                      height: MediaQuery.of(context).size.height *
                          0.52, // ✅ ~33% of screen height
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xff57195c), Color(0xff2b2740)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 25),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    color: Colors.yellowAccent.shade700,
                                    size: 60,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    ("Exit Game?").appTr,
                                    style: GoogleFonts.roboto(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    ("Are you sure you want to quit the game?").appTr,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.roboto(
                                      fontSize: 15,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.redAccent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 30, vertical: 12),
                                      elevation: 5,
                                    ),
                                    onPressed: () {
                                      Navigator.of(context).pop(false);
                                    },
                                    child: Text(
                                      ("No").appTr,
                                      style: GoogleFonts.roboto(
                                        fontSize: 16,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          Colors.greenAccent.shade400,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 30, vertical: 12),
                                      elevation: 5,
                                    ),
                                    onPressed: () {
                                      Navigator.of(context).pop(true);
                                    },
                                    child: Text(
                                      ("Yes").appTr,
                                      style: GoogleFonts.roboto(
                                        fontSize: 16,
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
                transitionBuilder: (context, anim1, anim2, child) {
                  return Transform.scale(
                    scale: Curves.easeOutBack.transform(anim1.value),
                    child: Opacity(
                      opacity: anim1.value,
                      child: child,
                    ),
                  );
                },
              );

              return exitApp ?? false;
            },
            child: Scaffold(
              body: Stack(
                alignment: Alignment.center,
                children: [
                  const SizedBox.expand(
                    child: Image(
                      image: AssetImage(
                        "assets/game/frootsloopsbgi,age.png",
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: 50,
                            width: 50,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                fruitController.activeUsers.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: ImageHelper.getImageUrl(
                                            fruitController.activeUsers[0]
                                                ['profile_image']),
                                        height: 40,
                                        fit: BoxFit.contain,
                                      )
                                    : Container(),
                                const Image(
                                  image: AssetImage(
                                      "assets/game/profile_frame.png"),
                                  fit: BoxFit.fill,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(
                            height: 30,
                          ),
                          SizedBox(
                            height: 50,
                            width: 50,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                fruitController.activeUsers.length >= 2
                                    ? CachedNetworkImage(
                                        imageUrl: ImageHelper.getImageUrl(
                                            fruitController.activeUsers[1]
                                                ['profile_image']),
                                        height: 40,
                                        fit: BoxFit.contain,
                                      )
                                    : Container(),
                                const Image(
                                  image: AssetImage(
                                      "assets/game/profile_frame.png"),
                                  fit: BoxFit.fill,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(
                            height: 30,
                          ),
                          SizedBox(
                            height: 50,
                            width: 50,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                fruitController.activeUsers.length >= 3
                                    ? CachedNetworkImage(
                                        imageUrl: ImageHelper.getImageUrl(
                                            fruitController.activeUsers[2]
                                                ['profile_image']),
                                        height: 40,
                                        fit: BoxFit.contain,
                                      )
                                    : Container(),
                                const Image(
                                  image: AssetImage(
                                      "assets/game/profile_frame.png"),
                                  fit: BoxFit.fill,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(
                        width: 15,
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 80),
                        height: 158,
                        width: size.width * .6,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: const Color(0xff54a9cd),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            InkWell(
                              onTap: () async {
                                if (selectedAmount > 0 &&
                                    fruitController.remainingTime.value > 1 &&
                                    fruitController.remainingTime.value < 20) {
                                  if (selectedAmount >
                                      fruitController.userCurrentCoins.value) {
                                    debugPrint(
                                        'Bet blocked: selectedAmount=$selectedAmount exceeds available coins=${fruitController.userCurrentCoins.value}');
                                    Get.snackbar(('Insufficient Balance').appTr,
                                        ('Please recharge').appTr,
                                        snackPosition: SnackPosition.BOTTOM,
                                        duration: const Duration(seconds: 2));
                                    return;
                                  }
                                  await fruitController.placeBet(
                                    userId: authController
                                        .userProfile.value.user!.id!
                                        .toInt(),
                                    betType: 1,
                                    amount: selectedAmount,
                                  );

                                  setState(() {
                                    if (pot1Selected == true) {
                                      coinsFor1 = coinsFor1 + selectedAmount;
                                      totalBetAmount =
                                          totalBetAmount + selectedAmount;
                                    } else {
                                      if (selectedNumBerCount >= 2) {
                                        // already selected 2
                                      } else {
                                        pot1Selected = true;
                                        selectedNumBerCount =
                                            selectedNumBerCount + 1;
                                        coinsFor1 = coinsFor1 + selectedAmount;
                                        totalBetAmount =
                                            totalBetAmount + selectedAmount;
                                      }
                                    }
                                  });
                                }
                              },
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(top: 5),
                                    height: 32,
                                    width: 32,
                                    decoration: const BoxDecoration(
                                        shape: BoxShape.circle),
                                    child: const Image(
                                      image:
                                          AssetImage("assets/game/orange.png"),
                                      fit: BoxFit.fill,
                                    ),
                                  ),
                                  Stack(
                                    children: [
                                      Container(
                                        height: 120,
                                        width: 140,
                                        decoration: BoxDecoration(
                                          color: (winDone == true &&
                                                      fruitController
                                                              .winnerNumber
                                                              .value !=
                                                          1) ==
                                                  true
                                              ? Colors.blueGrey
                                              : Colors.orange,
                                        ),
                                        child: const Image(
                                          image: AssetImage(
                                              "assets/game/potframe.png"),
                                          fit: BoxFit.fill,
                                        ),
                                      ),
                                      Positioned(
                                        top: 7,
                                        left: 7,
                                        child: Row(
                                          children: [
                                            Text(
                                              (' Pot: ').appTr,
                                              style: GoogleFonts.roboto(
                                                color: Colors.white,
                                              ),
                                            ),
                                            Text(
                                              fruitController.amount1.value
                                                  .toString(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 17,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 7,
                                        left: 7,
                                        child: Row(
                                          children: [
                                             Text(
                                              ("YOU:").appTr,
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 17,
                                                  fontStyle: FontStyle.italic),
                                            ),
                                            Text(
                                              coinsFor1.toString(),
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 17,
                                                  fontStyle: FontStyle.italic),
                                            ),
                                          ],
                                        ),
                                      ),
                                       Positioned(
                                          top: 40,
                                          bottom: 20,
                                          left: 55,
                                          right: 25,
                                          child: Text(
                                            ("x3").appTr,
                                            style: TextStyle(
                                                color: Colors.black38,
                                                fontSize: 35),
                                          )),
                                      Positioned(
                                          top: 16,
                                          bottom: 30,
                                          left: 40,
                                          right: 25,
                                          child: Opacity(
                                            opacity: 0.3,
                                            child: Image.asset(
                                              'assets/game/orange.png',
                                              fit: BoxFit.fill,
                                            ),
                                          )),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: () async {
                                if (selectedAmount > 0 &&
                                    fruitController.remainingTime.value > 1 &&
                                    fruitController.remainingTime.value < 20) {
                                  final int userCoins = int.tryParse(
                                          authController.userProfile.value.user
                                                  ?.coins ??
                                              '0') ??
                                      0;
                                  if (selectedAmount > userCoins) {
                                    debugPrint(
                                        'Bet blocked: selectedAmount=$selectedAmount exceeds available coins=$userCoins');
                                    Get.snackbar(('Insufficient Balance').appTr,
                                        ('Please recharge').appTr,
                                        snackPosition: SnackPosition.BOTTOM,
                                        duration: const Duration(seconds: 2));
                                    return;
                                  }
                                  await fruitController.placeBet(
                                    userId: authController
                                        .userProfile.value.user!.id!
                                        .toInt(),
                                    betType: 2,
                                    amount: selectedAmount,
                                  );
                                  setState(() {
                                    if (pot2Selected == true) {
                                      coinsFor2 = coinsFor2 + selectedAmount;
                                      totalBetAmount =
                                          totalBetAmount + selectedAmount;
                                    } else {
                                      if (selectedNumBerCount >= 2) {
                                      } else {
                                        pot2Selected = true;
                                        selectedNumBerCount =
                                            selectedNumBerCount + 1;
                                        coinsFor2 = coinsFor2 + selectedAmount;
                                        totalBetAmount =
                                            totalBetAmount + selectedAmount;
                                      }
                                    }
                                  });
                                }
                              },
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(top: 5),
                                    height: 32,
                                    width: 32,
                                    decoration: const BoxDecoration(
                                        shape: BoxShape.circle),
                                    child: const Image(
                                      image: AssetImage(
                                          "assets/game/watermelon.png"),
                                      fit: BoxFit.fill,
                                    ),
                                  ),
                                  Stack(
                                    children: [
                                      Container(
                                        height: 120,
                                        width: 140,
                                        decoration: BoxDecoration(
                                          color: (winDone == true &&
                                                      fruitController
                                                              .winnerNumber
                                                              .value !=
                                                          2) ==
                                                  true
                                              ? Colors.blueGrey
                                              : Colors.green,
                                        ),
                                        child: const Image(
                                          image: AssetImage(
                                              "assets/game/potframe.png"),
                                          fit: BoxFit.fill,
                                        ),
                                      ),
                                      Positioned(
                                        top: 7,
                                        left: 7,
                                        child: Row(
                                          children: [
                                            Text(
                                              (' Pot: ').appTr,
                                              style: GoogleFonts.roboto(
                                                color: Colors.white,
                                              ),
                                            ),
                                            Text(
                                              fruitController.amount2.value
                                                  .toString(),
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 17,
                                                  fontStyle: FontStyle.italic),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 7,
                                        left: 7,
                                        child: Row(
                                          children: [
                                             Text(
                                              ("YOU:").appTr,
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 17,
                                                  fontStyle: FontStyle.italic),
                                            ),
                                            Text(
                                              coinsFor2.toString(),
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 17,
                                                  fontStyle: FontStyle.italic),
                                            ),
                                          ],
                                        ),
                                      ),
                                       Positioned(
                                          top: 40,
                                          bottom: 20,
                                          left: 55,
                                          right: 25,
                                          child: Text(
                                            ("x3").appTr,
                                            style: TextStyle(
                                                color: Colors.black38,
                                                fontSize: 35),
                                          )),
                                      Positioned(
                                        top: 16,
                                        bottom: 30,
                                        left: 40,
                                        right: 25,
                                        child: Opacity(
                                          opacity: 0.3,
                                          child: Image.asset(
                                            'assets/game/watermelon.png',
                                            fit: BoxFit.fill,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: () async {
                                if (selectedAmount > 0 &&
                                    fruitController.remainingTime.value > 1 &&
                                    fruitController.remainingTime.value < 20) {
                                  if (selectedAmount >
                                      fruitController.userCurrentCoins.value) {
                                    debugPrint(
                                        'Bet blocked: selectedAmount=$selectedAmount exceeds available coins=${fruitController.userCurrentCoins.value}');
                                    Get.snackbar(('Insufficient Balance').appTr,
                                        ('Please recharge').appTr,
                                        snackPosition: SnackPosition.BOTTOM,
                                        duration: const Duration(seconds: 2));
                                    return;
                                  }
                                  await fruitController.placeBet(
                                    userId: authController
                                        .userProfile.value.user!.id!
                                        .toInt(),
                                    betType: 3,
                                    amount: selectedAmount,
                                  );
                                  setState(() {
                                    if (pot3Selected == true) {
                                      coinsFor3 = coinsFor3 + selectedAmount;
                                      totalBetAmount =
                                          totalBetAmount + selectedAmount;
                                    } else {
                                      if (selectedNumBerCount >= 2) {
                                        // already selected 2
                                      } else {
                                        pot3Selected = true;
                                        selectedNumBerCount =
                                            selectedNumBerCount + 1;
                                        coinsFor3 = coinsFor3 + selectedAmount;
                                        totalBetAmount =
                                            totalBetAmount + selectedAmount;
                                      }
                                    }
                                  });
                                }
                              },
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(top: 5),
                                    height: 32,
                                    width: 32,
                                    decoration: const BoxDecoration(
                                        shape: BoxShape.circle),
                                    child: const Image(
                                      image:
                                          AssetImage("assets/game/apple.png"),
                                      fit: BoxFit.fill,
                                    ),
                                  ),
                                  Stack(
                                    children: [
                                      Container(
                                        height: 120,
                                        width: 140,
                                        decoration: BoxDecoration(
                                          color: (winDone == true &&
                                                      fruitController
                                                              .winnerNumber
                                                              .value !=
                                                          3) ==
                                                  true
                                              ? Colors.blueGrey
                                              : Colors.red,
                                        ),
                                        child: const Image(
                                          image: AssetImage(
                                              "assets/game/potframe.png"),
                                          fit: BoxFit.fill,
                                        ),
                                      ),
                                      Positioned(
                                        top: 7,
                                        left: 7,
                                        child: Row(
                                          children: [
                                            Text(
                                              (' Pot: ').appTr,
                                              style: GoogleFonts.roboto(
                                                color: Colors.white,
                                              ),
                                            ),
                                            Text(
                                              fruitController.amount3.value
                                                  .toString(),
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 17,
                                                  fontStyle: FontStyle.italic),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 7,
                                        left: 7,
                                        child: Row(
                                          children: [
                                             Text(
                                              ("YOU:").appTr,
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 17,
                                                  fontStyle: FontStyle.italic),
                                            ),
                                            Text(
                                              coinsFor3.toString(),
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 17,
                                                  fontStyle: FontStyle.italic),
                                            ),
                                          ],
                                        ),
                                      ),
                                       Positioned(
                                          top: 40,
                                          bottom: 20,
                                          left: 55,
                                          right: 25,
                                          child: Text(
                                            ("x3").appTr,
                                            style: TextStyle(
                                                color: Colors.black38,
                                                fontSize: 35),
                                          )),
                                      Positioned(
                                          top: 16,
                                          bottom: 30,
                                          left: 40,
                                          right: 25,
                                          child: Opacity(
                                            opacity: 0.3,
                                            child: Image.asset(
                                              'assets/game/apple.png',
                                              fit: BoxFit.fill,
                                            ),
                                          )),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(
                        width: 15,
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: 50,
                            width: 50,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                fruitController.activeUsers.length >= 4
                                    ? CachedNetworkImage(
                                        imageUrl: ImageHelper.getImageUrl(
                                            fruitController.activeUsers[3]
                                                ['profile_image']),
                                        height: 40,
                                        fit: BoxFit.contain,
                                      )
                                    : Container(),
                                const Image(
                                  image: AssetImage(
                                      "assets/game/profile_frame.png"),
                                  fit: BoxFit.fill,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(
                            height: 30,
                          ),
                          SizedBox(
                              height: 50,
                              width: 50,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  fruitController.activeUsers.length >= 5
                                      ? CachedNetworkImage(
                                          imageUrl: ImageHelper.getImageUrl(
                                              fruitController.activeUsers[4]
                                                  ['profile_image']),
                                          height: 40,
                                          fit: BoxFit.contain,
                                        )
                                      : Container(),
                                  const Image(
                                    image: AssetImage(
                                        "assets/game/profile_frame.png"),
                                    fit: BoxFit.fill,
                                  ),
                                ],
                              )),
                          const SizedBox(
                            height: 30,
                          ),
                          SizedBox(
                            height: 50,
                            width: 50,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                fruitController.activeUsers.length >= 6
                                    ? CachedNetworkImage(
                                        imageUrl: ImageHelper.getImageUrl(
                                            fruitController.activeUsers[5]
                                                ['profile_image']),
                                        height: 40,
                                        fit: BoxFit.contain,
                                      )
                                    : Container(),
                                const Image(
                                  image: AssetImage(
                                      "assets/game/profile_frame.png"),
                                  fit: BoxFit.fill,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Positioned(
                    bottom: 0,
                    child: Center(
                      //coin side
                      child: Container(
                        decoration: const BoxDecoration(
                          borderRadius: BorderRadius.only(
                            topRight: Radius.circular(20),
                            topLeft: Radius.circular(20),
                          ),
                          color: Colors.greenAccent,
                        ),
                        margin: EdgeInsets.only(
                            left: size.width * .1, right: size.height * .1),
                        height: 60,
                        width: size.width * .8,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Container(
                              height: 40,
                              width: size.width * .15,
                              decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(9)),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  Image.asset(
                                    "assets/game/diamond.png",
                                    height: 30,
                                  ),
                                  Text(
                                    formatNumber(
                                        fruitController.userCurrentCoins.value),
                                    // userCoins.toString(),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: fruitController
                                                  .userCurrentCoins.value <
                                              100000
                                          ? 25
                                          : 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  selectedAmount = 500;
                                });
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Image(
                                      image: const AssetImage(
                                          "assets/game/casino2.png"),
                                      height: selectedAmount == 500 ? 95 : 70,
                                      width: selectedAmount == 500 ? 95 : 70,
                                    ),
                                    const Text(
                                      "500",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold),
                                    )
                                  ],
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  selectedAmount = 1000;
                                });
                                print(selectedAmount);
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Image(
                                      image: const AssetImage(
                                          "assets/game/casino3.png"),
                                      height: selectedAmount == 1000 ? 95 : 70,
                                      width: selectedAmount == 1000 ? 95 : 70,
                                    ),
                                     Text(
                                      ("1k").appTr,
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold),
                                    )
                                  ],
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  selectedAmount = 10000;
                                });
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Image(
                                      image: const AssetImage(
                                          "assets/game/casino2.png"),
                                      height: selectedAmount == 10000 ? 95 : 70,
                                      width: selectedAmount == 10000 ? 95 : 70,
                                    ),
                                     Text(
                                      ("10k").appTr,
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold),
                                    )
                                  ],
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  selectedAmount = 50000;
                                });
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Image(
                                      image: const AssetImage(
                                          "assets/game/casino3.png"),
                                      height: selectedAmount == 50000 ? 95 : 70,
                                      width: selectedAmount == 50000 ? 95 : 70,
                                    ),
                                     Text(
                                      ("50k").appTr,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  selectedAmount = 100000;
                                });
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Image(
                                      image: const AssetImage(
                                          "assets/game/casino2.png"),
                                      height:
                                          selectedAmount == 100000 ? 95 : 70,
                                      width: selectedAmount == 100000 ? 95 : 70,
                                    ),
                                     Text(
                                      ("100k").appTr,
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold),
                                    )
                                  ],
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return Stack(
                                      children: [
                                        AlertDialog(
                                          backgroundColor: Color(0xff232b52),
                                          alignment: Alignment.center,
                                          shadowColor: Colors.black38,
                                          title:  Center(
                                            child: Text(
                                              ('Fruits Trending').appTr,
                                              style: TextStyle(
                                                  color: Colors.white),
                                            ),
                                          ),
                                          content: SingleChildScrollView(
                                            child: Column(
                                              children: [
                                                Container(
                                                  height: 25,
                                                  width: 250,
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceAround,
                                                    children: [
                                                      Image.asset(
                                                          "assets/game/orange.png"),
                                                      Image.asset(
                                                          "assets/game/watermelon.png"),
                                                      Image.asset(
                                                          "assets/game/apple.png"),
                                                    ],
                                                  ),
                                                ),
                                                SizedBox(
                                                  height: 4,
                                                ),
                                                SizedBox(
                                                  width:
                                                      MediaQuery.sizeOf(context)
                                                              .width *
                                                          .3,
                                                  height:
                                                      MediaQuery.sizeOf(context)
                                                              .height *
                                                          .9,
                                                  child: Obx(() {
                                                    return ListView.builder(
                                                        itemCount:
                                                            fruitController
                                                                .winnerTrend
                                                                .length,
                                                        itemBuilder:
                                                            (context, index) {
                                                          return Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .only(
                                                                    top: 2,
                                                                    bottom: 2),
                                                            child: Container(
                                                              height: 25,
                                                              decoration:
                                                                  BoxDecoration(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            8),
                                                                color: const Color(
                                                                    0xff442c68),
                                                              ),
                                                              child: Padding(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .only(
                                                                        left:
                                                                            4.0,
                                                                        right:
                                                                            4),
                                                                child: Row(
                                                                  mainAxisAlignment:
                                                                      MainAxisAlignment
                                                                          .spaceBetween,
                                                                  children: [
                                                                    Text(
                                                                      fruitController.winnerTrend[index]['field1'] == 'Win'
                                                                          ? ('Win').appTr: '-',
                                                                      style: TextStyle(
                                                                          color: fruitController.winnerTrend[index]['field1'] == 'Win'
                                                                              ? Colors.pink
                                                                              : Colors.white),
                                                                    ),
                                                                    Text(
                                                                      fruitController.winnerTrend[index]['field2'] == 'Win'
                                                                          ? ('Win').appTr: '-',
                                                                      style: TextStyle(
                                                                          color: fruitController.winnerTrend[index]['field2'] == 'Win'
                                                                              ? Colors.pink
                                                                              : Colors.white),
                                                                    ),
                                                                    Text(
                                                                      fruitController.winnerTrend[index]['field3'] == 'Win'
                                                                          ? ('Win').appTr: '-',
                                                                      style: TextStyle(
                                                                          fontWeight: FontWeight
                                                                              .bold,
                                                                          fontSize: kHeight *
                                                                              0.016,
                                                                          color: fruitController.winnerTrend[index]['field3'] == 'Win'
                                                                              ? Colors.pink
                                                                              : Colors.white),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                          );
                                                        });
                                                  }),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                              child: Container(
                                height: 45,
                                width: 45,
                                decoration: const BoxDecoration(
                                  color: Colors.pink,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.trending_up,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 20,
                    right: 30,
                    child: Row(
                      children: [
                        InkWell(
                          onTap: () {
                            showGeneralDialog(
                              context: context,
                              barrierDismissible: true,
                              barrierLabel: '',
                              barrierColor: Colors.black.withOpacity(0.5),
                              transitionDuration:
                                  const Duration(milliseconds: 300),
                              pageBuilder: (context, anim1, anim2) {
                                return Center(
                                  child: ScaleTransition(
                                    scale: CurvedAnimation(
                                      parent: anim1,
                                      curve: Curves.easeOutBack,
                                    ),
                                    child: Container(
                                      width: 280,
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(2),
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF6A11CB),
                                            Color(0xFF2575FC)
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.25),
                                            blurRadius: 20,
                                            offset: const Offset(0, 10),
                                          ),
                                        ],
                                      ),
                                      child: Material(
                                        // 👈 this fixes the InkWell error
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
                                                letterSpacing: 1,
                                                decoration: TextDecoration.none,
                                                fontFamily: 'Poppins',
                                              ),
                                            ),
                                            const SizedBox(height: 20),
                                            InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(15),
                                              onTap: () {
                                                if (isMute.value) {
                                                  // playCoinsAudio();
                                                  // playBackgroundMusic();
                                                } else {
                                                  stopCoinsAudio();
                                                }
                                                isMute.value = !isMute.value;
                                              },
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 20,
                                                        vertical: 12),
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(15),
                                                  color: Colors.white
                                                      .withOpacity(0.15),
                                                  border: Border.all(
                                                      color: Colors.white24,
                                                      width: 1.5),
                                                ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Obx(() => Icon(
                                                          isMute.value
                                                              ? Icons
                                                                  .volume_off_rounded
                                                              : Icons
                                                                  .volume_up_rounded,
                                                          size: 35,
                                                          color: Colors.white,
                                                        )),
                                                    const SizedBox(width: 12),
                                                     Text(
                                                      ("ON / OFF").appTr,
                                                      style: TextStyle(
                                                        fontSize: 18,
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        letterSpacing: 1,
                                                        decoration:
                                                            TextDecoration.none,
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
                                                backgroundColor: Colors.white,
                                                foregroundColor:
                                                    Colors.blueAccent,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(15),
                                                ),
                                              ),
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              child:  Padding(
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: 25,
                                                    vertical: 10),
                                                child: Text(
                                                  ('Close').appTr,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
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
                          },
                          child: Container(
                            height: 40,
                            width: 40,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                            ),
                            child: const Image(
                              image: AssetImage("assets/game/setting.png"),
                              fit: BoxFit.fill,
                            ),
                          ),
                        ),
                        const SizedBox(
                          width: 15,
                        ),
                        InkWell(
                          child: Container(
                            height: 35,
                            width: 35,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                            ),
                            child: const Image(
                              image:
                                  AssetImage("assets/game/question-mark.png"),
                              fit: BoxFit.fill,
                            ),
                          ),
                        ),
                        const SizedBox(
                          width: 15,
                        ),
                        InkWell(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return Stack(
                                  children: [
                                    AlertDialog(
                                      alignment: Alignment.center,
                                      shadowColor: Colors.black38,
                                      title:  Center(
                                        child: Text(('Player List').appTr),
                                      ),
                                      content: SizedBox(
                                        width:
                                            MediaQuery.sizeOf(context).width *
                                                .3,
                                        child: Column(
                                          children: [
                                            // Other widgets
                                            Expanded(
                                              child: GridView.builder(
                                                shrinkWrap: true,
                                                gridDelegate:
                                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                                  crossAxisCount: 3,
                                                  crossAxisSpacing: 8.0,
                                                  mainAxisSpacing: 8.0,
                                                ),
                                                itemCount: fruitController
                                                    .activeUsers.length,
                                                itemBuilder:
                                                    (BuildContext context,
                                                        int index) {
                                                  // Build individual grid items here
                                                  return Container(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            left: 4.0,
                                                            right: 4,
                                                            top: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.teal,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              5),
                                                    ),
                                                    child: Column(
                                                      children: [
                                                        Stack(
                                                          alignment:
                                                              Alignment.center,
                                                          children: [
                                                            CachedNetworkImage(
                                                              imageUrl: ImageHelper.getImageUrl(
                                                                  fruitController
                                                                              .activeUsers[
                                                                          index]
                                                                      [
                                                                      'profile_image']),
                                                              height: 50,
                                                              fit: BoxFit
                                                                  .contain,
                                                            ),
                                                            const Image(
                                                              image: AssetImage(
                                                                  "assets/game/profile_frame.png"),
                                                              height: 55,
                                                              fit: BoxFit.fill,
                                                            ),
                                                          ],
                                                        ),
                                                        Text(
                                                          fruitController
                                                                  .activeUsers[
                                                              index]['full_name'],
                                                          style:
                                                              const TextStyle(
                                                                  fontSize: 12,
                                                                  color: Colors
                                                                      .white),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                            // Other widgets
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                          child: Container(
                            height: 50,
                            width: 50,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                            ),
                            child: const Image(
                              image: AssetImage("assets/game/group.png"),
                              fit: BoxFit.fill,
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                  Positioned(
                    top: 20,
                    left: 20,
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).pop(true);
                      },
                      child: Container(
                        height: kHeight * 0.05,
                        width: kHeight * 0.05,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                        ),
                        child: const Image(
                          image:
                              AssetImage("assets/game/less-than_18757930.png"),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  //Spinning section
                  Positioned(
                    top: -60,
                    child: SizedBox(
                      height: 200,
                      width: 300,
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
                            child: TriangleIndicator(
                              color: Colors.deepOrange,
                            ),
                          ),
                        ],
                        onAnimationEnd: () {
                          // ১. চাকা থামা মাত্রই সাউন্ড বন্ধ হবে
                          fruitController.stopSpinSound();

                          // ২. বাকি ক্যালকুলেশন শুরু হবে
                          setState(() {
                            winDone = true;
                            if (fruitController.winnerNumber.value == 1) {
                              fruitController.userCurrentCoins.value =
                                  fruitController.userCurrentCoins.value +
                                      (coinsFor1 * 3);
                              totalWinAmount = totalWinAmount + (coinsFor1 * 3);
                            }

                            if (fruitController.winnerNumber.value == 2) {
                              totalWinAmount = totalWinAmount + (coinsFor2 * 3);
                              fruitController.userCurrentCoins.value =
                                  fruitController.userCurrentCoins.value +
                                      (coinsFor2 * 3);
                            }

                            if (fruitController.winnerNumber.value == 3) {
                              totalWinAmount = totalWinAmount + (coinsFor3 * 3);
                              fruitController.userCurrentCoins.value =
                                  fruitController.userCurrentCoins.value +
                                      (coinsFor3 * 3);
                            }
                          });
                        },
                        animateFirst: false,
                        items: [
                          FortuneItem(
                            child: Container(
                              margin: const EdgeInsets.only(left: 20),
                              child: Image.asset(
                                'assets/game/apple.png',
                                height: 40,
                              ),
                            ),
                          ),
                          FortuneItem(
                            child: Container(
                              margin: const EdgeInsets.only(left: 20),
                              child: Image.asset(
                                'assets/game/orange.png',
                                height: 40,
                              ),
                            ),
                          ),
                          FortuneItem(
                            child: Container(
                              margin: const EdgeInsets.only(left: 20),
                              child: Image.asset(
                                'assets/game/watermelon.png',
                                height: 40,
                              ),
                            ),
                          ),
                          FortuneItem(
                            child: Container(
                              margin: const EdgeInsets.only(left: 20),
                              child: Image.asset(
                                'assets/game/apple.png',
                                height: 40,
                              ),
                            ),
                          ),
                          FortuneItem(
                            child: Image.asset(
                              'assets/game/orange.png',
                              height: 40,
                            ),
                          ),
                          FortuneItem(
                            child: Container(
                              margin: const EdgeInsets.only(left: 20),
                              child: Image.asset(
                                'assets/game/watermelon.png',
                                height: 40,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    child: Image.asset(
                      'assets/game/spin_frame.png',
                      height: 195,
                    ),
                  ),
                  // এই অংশটুকু আপনার কোডের নিচের দিকে আছে, সেখানে আপডেট করুন
                  fruitController.remainingTime.value <= 20 &&
                          fruitController.remainingTime.value > 0
                      ? Positioned(
                          top: size.height * .25,
                          right: size.width * .2,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Image.asset(
                                'assets/game/stopwatch.png',
                                height: 60,
                              ),
                              Container(
                                margin: const EdgeInsets.only(top: 6),
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  // এখানে .ceil() ব্যবহার করলে ২০ থাকলে ১০ দেখাবে, ১৯ থাকলেও ১০ দেখাবে
                                  // আর .floor() দিলে ২০ থাকলে ১০ দেখাবে কিন্তু ১৯ থাকলে ৯ দেখাবে
                                  ((fruitController.remainingTime.value) / 2)
                                      .ceil()
                                      .toString(),
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Container(),
                  fruitController.remainingTime.value == 22
                      ? Positioned(
                          top: size.height * .33,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Image.asset(
                                'assets/game/waitingframe.png',
                                height: size.height * .25,
                              ),
                              Text(
                                ('Start Bet').appTr,
                                style: GoogleFonts.roboto(
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 25,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Container(),
                  fruitController.remainingTime.value == 24
                      ? Positioned(
                          top: size.height * .33,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Image.asset(
                                'assets/game/waitingframe.png',
                                height: size.height * .25,
                              ),
                              Text(
                                ('Waiting for next Round').appTr,
                                style: GoogleFonts.roboto(
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 25,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Container(),
                  fruitController.remainingTime.value == 0
                      ? Positioned(
                          top: size.height * .33,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Image.asset(
                                'assets/game/waitingframe.png',
                                height: size.height * .25,
                              ),
                              Text(
                                ('Stop Bet').appTr,
                                style: GoogleFonts.roboto(
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 25,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Container(),
                ],
              ),
            ),
          );
  }
}
