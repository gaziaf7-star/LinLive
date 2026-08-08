import 'package:flutter/foundation.dart';

/// Turn this on only when debugging a live-room issue.
/// Keeping it false prevents console JSON/log spam from slowing the live room.
const bool kLiveDebug = false;

void liveLog(Object? message, {int? wrapWidth}) {
  if (!kLiveDebug) return;
  debugPrint(message?.toString(), wrapWidth: wrapWidth);
}
