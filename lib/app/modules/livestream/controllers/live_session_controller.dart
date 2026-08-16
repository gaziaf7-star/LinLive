import 'package:get/get.dart';

import 'livestream_controller.dart';

/// Owns the identity of the currently authoritative livestream session.
///
/// Joining, exiting, cleanup, Agora and WebSocket transport lifecycle remain
/// with their existing owners. This controller only supplies shared identity,
/// role and generation state used to reject stale room work.
class LiveSessionController extends GetxController {
  LiveSessionController(LivestreamController owner);

  final streamId = 0.obs;
  final isHost = false.obs;
  final isBroadcaster = false.obs;
  final broadcasterId = 0.obs;

  int _generation = 0;
  int _activeSessionStreamId = 0;
  int _transitionTargetStreamId = 0;
  bool _transitionInProgress = false;

  int get generation => _generation;
  int get activeSessionStreamId => _activeSessionStreamId;
  int get transitionTargetStreamId => _transitionTargetStreamId;
  bool get transitionInProgress => _transitionInProgress;

  int beginRoomTransition({required int targetStreamId}) {
    _generation++;
    _activeSessionStreamId = 0;
    _transitionTargetStreamId = targetStreamId > 0 ? targetStreamId : 0;
    _transitionInProgress = true;
    return _generation;
  }

  void activateRoomSession({required int streamId, required int generation}) {
    if (generation != _generation || streamId <= 0) return;
    _activeSessionStreamId = streamId;
    _transitionTargetStreamId = 0;
    _transitionInProgress = false;
  }

  /// ✅ FIX: beginRoomTransition() locks out all room mutations
  /// (acceptsRoomMutation) until a matching activateRoomSession() call for
  /// the SAME generation arrives. If the join flow that called
  /// beginRoomTransition then aborts early (a guard/assert fails, or an
  /// exception is thrown) without ever reaching activateRoomSession, this
  /// lock stays stuck forever — every future join into that room (or any
  /// room) silently has its viewer/seat/entry updates dropped. This clears
  /// the lock, but only for the generation that actually opened it, so a
  /// newer, still-legitimate transition is never clobbered.
  void abortRoomSession({required int generation}) {
    if (generation != _generation) return;
    _transitionInProgress = false;
    _transitionTargetStreamId = 0;
  }

  bool acceptsRoomMutation(int candidateStreamId) {
    if (_transitionInProgress || candidateStreamId <= 0) return false;
    final activeStreamId = _activeSessionStreamId > 0
        ? _activeSessionStreamId
        : streamId.value;
    return activeStreamId == 0 || activeStreamId == candidateStreamId;
  }

  bool isRoomSessionCurrent({required int streamId, required int generation}) {
    return generation == _generation &&
        _activeSessionStreamId == streamId &&
        !_transitionInProgress;
  }
}