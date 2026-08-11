import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../socket/websocket_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class EmojiAnimationWidget extends StatelessWidget {
  final WebsocketController websocketController = Get.find();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!websocketController.showEmojiAnimation.value ||
          websocketController.emojiAnimations.isEmpty) {
        return SizedBox.shrink();
      }

      return Positioned(
        top: 100,
        left: 20,
        right: 20,
        child: Container(
          height: 260,
          child: Stack(
            children: websocketController.emojiAnimations.map((emojiData) {
              return AnimatedPositioned(
                duration: Duration(milliseconds: 500),
                top: 0,
                left: (websocketController.emojiAnimations.indexOf(emojiData) * 60.0) %
                    (MediaQuery.of(context).size.width - 100),
                child: TweenAnimationBuilder<double>(
                  duration: Duration(milliseconds: 4200),
                  tween: Tween(begin: 0.0, end: 1.0),
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(0, -value * 190),
                      child: Opacity(
                        opacity: 1.0 - value,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                emojiData['emoji'],
                                style: TextStyle(fontSize: 42),
                              ),
                              SizedBox(width: 8),
                              Text(
                                emojiData['user']['name'] ?? ('User').appTr,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            }).toList(),
          ),
        ),
      );
    });
  }
}
