import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../fruit_game/views/fruit_game_view.dart';



class FruitGameBottomSheet extends StatefulWidget {
  final bool shouldRotate;

  const FruitGameBottomSheet({
    Key? key,
    this.shouldRotate = false,
  }) : super(key: key);

  @override
  State<FruitGameBottomSheet> createState() => _FruitGameBottomSheetState();
}

class _FruitGameBottomSheetState extends State<FruitGameBottomSheet> {
  @override
  void initState() {
    super.initState();
    // Only set landscape orientation if shouldRotate is true
    if (widget.shouldRotate) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }
  

  @override
  void dispose() {
    // Only reset orientation if we had set it to landscape
    if (widget.shouldRotate) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
    super.dispose();
  }

  void _closeBottomSheet() {
    // Only reset orientation if we had set it to landscape
    if (widget.shouldRotate) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return WillPopScope(
      onWillPop: () async {
        // Only reset orientation if we had set it to landscape

        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);

        return true;
      },
      child: Container(
        height: screenHeight,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          color: Colors.black,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          child: Stack(
            children: [
              // FruitGameView with perfect sizing for bottom sheet
              Positioned.fill(
                child: Container(
                  margin: EdgeInsets.only(
                    top: 50, // Space for close button and status bar
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    child: FruitGameView(),
                  ),
                ),
              ),
              // Close button positioned at top right
              Positioned(
                top: 10,
                right: 10,
                child: SafeArea(
                  child: GestureDetector(
                    onTap: _closeBottomSheet,
                    child: Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.8),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withOpacity(0.5), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
