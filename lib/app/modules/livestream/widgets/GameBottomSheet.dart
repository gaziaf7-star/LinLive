import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meetlivepro/app/localization/app_localizer.dart';
import 'game/RacinCarGAmeBottom.dart';
import 'game/baishun_game_controller.dart';
import 'game/baishun_game_webview.dart';
import 'game/fruitsLoopsGamebottom.dart';
import 'game/gradyBabyGameBottom.dart';
import 'game/greadyLion.dart';
import 'game/jackportGameBottom.dart';
import 'game/lodoking.dart';
import 'game/lucky&&GameBottomView.dart';
import 'game/lucky99BottomGameView.dart';
import 'game/rolleteGameBottomSheet.dart';
import 'game/teenPattiBottomGame.dart';
import 'gamewebView.dart';

class GameBottomSheet extends StatefulWidget {
  const GameBottomSheet({
    super.key,
    required this.isGame,
  });

  final bool isGame;

  @override
  State<GameBottomSheet> createState() => _GameBottomSheetState();
}

class _GameBottomSheetState extends State<GameBottomSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final String _controllerTag;
  late final BaishunGameController _baishunController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _controllerTag = 'baishun_game_${identityHashCode(this)}';
    _baishunController = Get.put<BaishunGameController>(
      BaishunGameController(
        roomId: '',
        gameMode: '3',
      ),
      tag: _controllerTag,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    if (Get.isRegistered<BaishunGameController>(tag: _controllerTag)) {
      Get.delete<BaishunGameController>(
        tag: _controllerTag,
        force: true,
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.sizeOf(context);
    final double horizontalPadding =
    (screenSize.width * 0.035).clamp(12.0, 18.0).toDouble();
    final double verticalPadding =
    (screenSize.height * 0.014).clamp(10.0, 15.0).toDouble();
    final double gridSpacing =
    (screenSize.width * 0.018).clamp(6.0, 10.0).toDouble();

    return Container(
      width: double.infinity,
      height: (screenSize.height * 0.56).clamp(390.0, 570.0).toDouble(),
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        verticalPadding,
        horizontalPadding,
        verticalPadding,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Color(0xffE8E8E8),
            width: 1,
          ),
        ),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Center(
            child: Text(
              ('GAME CENTER').appTr,
              style: GoogleFonts.lato(
                fontSize: (screenSize.width * 0.045)
                    .clamp(16.0, 19.0)
                    .toDouble(),
                color: Colors.black,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(
            height: (screenSize.height * 0.010)
                .clamp(7.0, 10.0)
                .toDouble(),
          ),
          // Container(
          //   height: 42,
          //   padding: const EdgeInsets.all(4),
          //   decoration: BoxDecoration(
          //     color: const Color(0xFFF2F2F4),
          //     borderRadius: BorderRadius.circular(12),
          //   ),
          //   child: TabBar(
          //     controller: _tabController,
          //     indicator: BoxDecoration(
          //       color: Colors.white,
          //       borderRadius: BorderRadius.circular(9),
          //       boxShadow: const <BoxShadow>[
          //         BoxShadow(
          //           color: Color(0x16000000),
          //           blurRadius: 8,
          //           offset: Offset(0, 2),
          //         ),
          //       ],
          //     ),
          //     indicatorSize: TabBarIndicatorSize.tab,
          //     dividerColor: Colors.transparent,
          //     labelColor: const Color(0xFF6D2CE8),
          //     unselectedLabelColor: Colors.black54,
          //     labelStyle: GoogleFonts.lato(
          //       fontWeight: FontWeight.w800,
          //       fontSize: 13,
          //     ),
          //     unselectedLabelStyle: GoogleFonts.lato(
          //       fontWeight: FontWeight.w600,
          //       fontSize: 13,
          //     ),
          //     tabs: <Widget>[
          //       Tab(text: ('Top').appTr),
          //       Tab(text: ('Top1').appTr),
          //     ],
          //   ),
          // ),
          SizedBox(
            height: (screenSize.height * 0.012)
                .clamp(8.0, 12.0)
                .toDouble(),
          ),

          Expanded(
            child: _buildBaishunGames(context, gridSpacing),
          ),
          // Expanded(
          //   child: TabBarView(
          //     controller: _tabController,
          //     children: <Widget>[
          //       _buildLocalGames(context, gridSpacing),
          //
          //     ],
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget _buildLocalGames(BuildContext context, double gridSpacing) {
    return GridView.count(
      crossAxisCount: 4,
      physics: const BouncingScrollPhysics(),
      mainAxisSpacing: gridSpacing,
      crossAxisSpacing: gridSpacing,
      childAspectRatio: 1,
      padding: EdgeInsets.zero,
      children: <Widget>[
        _ResponsiveGameCard(
          onPress: () {
            Get.back<void>();
            GreadyBabyGameBottom(context);
          },
          image: 'assets/Pk/gredybaby.jfif',
          text: ('Greedy Baby').appTr,
        ),
        _ResponsiveGameCard(
          onPress: () {
            Get.back<void>();
            RacingGameBottomSheet(context);
          },
          image: 'assets/Pk/racing.jfif',
          text: ('Racing Car').appTr,
        ),
        _ResponsiveGameCard(
          onPress: () {
            Get.back<void>();
            FruitsLoopsBottomGameView(context);
          },
          image: 'assets/Pk/fruits.jfif',
          text: ('Fruits Loop').appTr,
        ),
        _ResponsiveGameCard(
          onPress: () {
            Get.back<void>();
            openKingGameBottomWebView(context);
          },
          image: 'assets/game/greadyGeme.png',
          text: ('Greedy Game').appTr,
        ),
        _ResponsiveGameCard(
          onPress: () {
            Get.back<void>();
            LodoKingBottomGameView(context);
          },
          image: 'assets/game/lodu.png',
          text: ('Ludo').appTr,
        ),
        _ResponsiveGameCard(
          onPress: () {
            Get.back<void>();
            jackport77BottomGameView(context);
          },
          image: 'assets/Pk/jhack.jfif',
          text: ('Jackpot').appTr,
        ),
        _ResponsiveGameCard(
          onPress: () {
            Get.back<void>();
            Lucky77BottomGameView(context);
          },
          image: 'assets/Pk/lucky77.jfif',
          text: ('Lucky 77').appTr,
        ),
        _ResponsiveGameCard(
          onPress: () {
            Get.back<void>();
            Lucky99BottomGameView(context);
          },
          image: 'assets/Pk/lucky99.jfif',
          text: ('Lucky 99').appTr,
        ),
        _ResponsiveGameCard(
          onPress: () {
            Get.back<void>();
            TeenPattiBottomGameView(context);
          },
          image: 'assets/Pk/theenpatti.jfif',
          text: ('Teen Patti').appTr,
        ),
        _ResponsiveGameCard(
          onPress: () {
            Get.back<void>();
            RolleteBottomGameView(context);
          },
          image: 'assets/Pk/rollet.jfif',
          text: ('Rollete Game').appTr,
        ),
        _ResponsiveGameCard(
          onPress: () {
            Get.back<void>();
            GreedyLionBottomGameView(context);
          },
          image: 'assets/Pk/gradyLion.jfif',
          text: ('Greedy Lion').appTr,
        ),
      ],
    );
  }

  Widget _buildBaishunGames(BuildContext context, double gridSpacing) {
    return Obx(() {
      if (_baishunController.isLoading.value &&
          _baishunController.games.isEmpty) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      }

      if (_baishunController.games.isEmpty) {
        return _GameListError(
          message: _baishunController.errorMessage.value.isNotEmpty
              ? _baishunController.errorMessage.value
              : ('No games are available right now.').appTr,
          onRetry: () => _baishunController.loadGames(),
        );
      }

      return RefreshIndicator(
        onRefresh: () => _baishunController.loadGames(refresh: true),
        child: GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: gridSpacing,
            crossAxisSpacing: gridSpacing,
            childAspectRatio: 1,
          ),
          itemCount: _baishunController.games.length,
          itemBuilder: (BuildContext context, int index) {
            final BaishunGame game = _baishunController.games[index];
            final bool isOpening =
                _baishunController.openingGameId.value == game.gameId;

            return _NetworkGameCard(
              game: game,
              isLoading: isOpening,
              onPress: isOpening
                  ? null
                  : () async {
                final BaishunGameSession? session =
                await _baishunController.createSession(game);

                if (session == null) return;

                if (!mounted) return;

                final NavigatorState currentNavigator =
                Navigator.of(context);
                final NavigatorState rootNavigator = Navigator.of(
                  context,
                  rootNavigator: true,
                );

                currentNavigator.pop<void>();

                await Future<void>.delayed(
                  const Duration(milliseconds: 180),
                );

                if (!rootNavigator.mounted) return;

                await showBaishunGameHalfScreen(
                  context: rootNavigator.context,
                  session: session,
                );
              },
            );
          },
        ),
      );
    });
  }
}

class _ResponsiveGameCard extends StatelessWidget {
  const _ResponsiveGameCard({
    required this.onPress,
    required this.image,
    required this.text,
  });

  final VoidCallback onPress;
  final String image;
  final String text;

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final double radius =
    (screenWidth * 0.025).clamp(8.0, 12.0).toDouble();
    final double fontSize =
    (screenWidth * 0.026).clamp(9.0, 11.0).toDouble();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: onPress,
        borderRadius: BorderRadius.circular(radius),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: const Color(0xffE9E9E9),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Column(
              children: <Widget>[
                Expanded(
                  child: SizedBox(
                    width: double.infinity,
                    child: Image.asset(
                      image,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const ColoredBox(
                          color: Color(0xffF2F2F2),
                          child: Center(
                            child: Icon(
                              Icons.sports_esports_rounded,
                              color: Colors.black38,
                              size: 24,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                _GameNameBar(
                  text: text,
                  fontSize: fontSize,
                  screenWidth: screenWidth,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NetworkGameCard extends StatelessWidget {
  const _NetworkGameCard({
    required this.game,
    required this.isLoading,
    required this.onPress,
  });

  final BaishunGame game;
  final bool isLoading;
  final VoidCallback? onPress;

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final double radius =
    (screenWidth * 0.025).clamp(8.0, 12.0).toDouble();
    final double fontSize =
    (screenWidth * 0.026).clamp(9.0, 11.0).toDouble();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: onPress,
        borderRadius: BorderRadius.circular(radius),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: isLoading
                  ? const Color(0xFF7B2CFF)
                  : const Color(0xffE9E9E9),
              width: isLoading ? 1.5 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Column(
              children: <Widget>[
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      if (game.previewUrl.isNotEmpty)
                        Image.network(
                          game.previewUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const ColoredBox(
                              color: Color(0xffF2F2F2),
                              child: Center(
                                child: Icon(
                                  Icons.sports_esports_rounded,
                                  color: Colors.black38,
                                  size: 24,
                                ),
                              ),
                            );
                          },
                          loadingBuilder: (
                              BuildContext context,
                              Widget child,
                              ImageChunkEvent? progress,
                              ) {
                            if (progress == null) return child;
                            return const ColoredBox(
                              color: Color(0xffF7F7F7),
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            );
                          },
                        )
                      else
                        const ColoredBox(
                          color: Color(0xffF2F2F2),
                          child: Center(
                            child: Icon(
                              Icons.sports_esports_rounded,
                              color: Colors.black38,
                              size: 24,
                            ),
                          ),
                        ),
                      if (isLoading)
                        ColoredBox(
                          color: Colors.black.withOpacity(0.48),
                          child: const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                _GameNameBar(
                  text: game.name,
                  fontSize: fontSize,
                  screenWidth: screenWidth,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GameNameBar extends StatelessWidget {
  const _GameNameBar({
    required this.text,
    required this.fontSize,
    required this.screenWidth,
  });

  final String text;
  final double fontSize;
  final double screenWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: (screenWidth * 0.064).clamp(23.0, 29.0).toDouble(),
      padding: const EdgeInsets.symmetric(horizontal: 3),
      alignment: Alignment.center,
      color: Colors.white,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: GoogleFonts.lato(
          color: Colors.black,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
    );
  }
}

class _GameListError extends StatelessWidget {
  const _GameListError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.sports_esports_outlined,
              size: 46,
              color: Colors.black38,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.lato(
                color: Colors.black54,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(('Retry').appTr),
            ),
          ],
        ),
      ),
    );
  }
}
