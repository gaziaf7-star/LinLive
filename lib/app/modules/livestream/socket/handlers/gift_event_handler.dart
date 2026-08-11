part of '../websocket_controller.dart';

extension GiftEventHandler on WebsocketController {
  Future<void> fetchInitialGiftTotal({dynamic streamId}) async {
    try {
      final int sid =
          int.tryParse((streamId ?? streamID.value).toString()) ?? 0;

      if (sid <= 0) {
        liveLog('Skipping gift total fetch - invalid stream ID: $sid');
        return;
      }

      final response = await dio.get(kGetTotalGiftCoins(sid));
      if (response.statusCode == 200) {
        final data = response.data is Map
            ? Map<String, dynamic>.from(response.data)
            : <String, dynamic>{};

        final dynamic coinRaw =
            data['total_gift_coins'] ??
            data['total_coins'] ??
            data['gifts_coins'] ??
            data['gift_amount'] ??
            data['stream_coins'];

        final int coins = _toInt(coinRaw);

        /// Do not let a partial/empty response reset a live that already has coins.
        if (coins > 0 || totalGiftCoins.value <= 0) {
          totalGiftCoins.value = coins;
        }

        // Load user gift counts if available
        if (data['user_gift_counts'] != null) {
          userGiftCounts.value = Map<String, Map<String, dynamic>>.from(
            data['user_gift_counts'].map(
              (key, value) =>
                  MapEntry(key.toString(), Map<String, dynamic>.from(value)),
            ),
          );
        }

        liveLog('Initial gift total loaded: ${totalGiftCoins.value}');
        liveLog('Initial user gift counts loaded: $userGiftCounts');
      }
    } catch (e) {
      if (e.toString().contains('404')) {
        liveLog('Livestream not found for ID: ${streamId ?? streamID.value}');
      } else {
        liveLog('Error fetching initial gift total: $e');
      }
    }
  }

  bool _looksLikeViewerOnlyPayloadForCoin(
    Map<String, dynamic> payload,
    Map<String, dynamic> data,
  ) {
    /// viewer/user join payload may contain user.balance/coins/gifts_coins = 0.
    /// That is NOT the live received gift total, so never sync live total from it.
    final action = (payload['action_type'] ?? payload['action'] ?? '')
        .toString()
        .toLowerCase();

    if (action.contains('viewer') ||
        action.contains('join_live') ||
        action.contains('user_joined')) {
      return true;
    }

    if ((payload.containsKey('viewer') || payload.containsKey('viewer_data')) &&
        !payload.containsKey('livestream') &&
        !payload.containsKey('live_stream')) {
      return true;
    }

    if ((data.containsKey('viewer_id') || data.containsKey('is_active')) &&
        !data.containsKey('total_gift_coins') &&
        !data.containsKey('gift_amount') &&
        !data.containsKey('stream_coins')) {
      return true;
    }

    return false;
  }

  void syncGiftCoinsFromPayload(
    Map<String, dynamic> payload, {
    String source = 'payload',
  }) {
    try {
      final Map<String, dynamic> data = payload['data'] is Map
          ? Map<String, dynamic>.from(payload['data'])
          : payload['livestream'] is Map
          ? Map<String, dynamic>.from(payload['livestream'])
          : payload['live_stream'] is Map
          ? Map<String, dynamic>.from(payload['live_stream'])
          : Map<String, dynamic>.from(payload);

      if (_looksLikeViewerOnlyPayloadForCoin(payload, data)) {
        liveLog('🪙 Gift coin sync skipped viewer-only payload from $source');
        return;
      }

      final bool hasLiveCoinKey =
          data.containsKey('total_gift_coins') ||
          data.containsKey('total_coins') ||
          data.containsKey('gift_amount') ||
          data.containsKey('stream_coins') ||
          data.containsKey('received_coins');

      /// Do NOT treat data['gifts_coins'] alone as live total when it comes
      /// from viewer/user object. User.gifts_coins is often 0 for late viewers.
      final bool hasOnlyUserGiftCoins =
          data.containsKey('gifts_coins') &&
          !hasLiveCoinKey &&
          (data.containsKey('id') ||
              data.containsKey('user_id') ||
              data.containsKey('profile_image'));

      if (!hasLiveCoinKey && hasOnlyUserGiftCoins) {
        liveLog('🪙 Gift coin sync skipped user.gifts_coins from $source');
        return;
      }

      final dynamic coinRaw =
          data['total_gift_coins'] ??
          data['total_coins'] ??
          data['gift_amount'] ??
          data['stream_coins'] ??
          data['received_coins'] ??
          data['gifts_coins'];

      if (coinRaw == null) return;

      final int coins = _toInt(coinRaw);
      final int payloadStreamId = _toInt(
        payload['livestream_id'] ??
            payload['stream_id'] ??
            data['livestream_id'] ??
            data['stream_id'] ??
            data['id'],
      );
      final int currentStreamId = _toInt(streamID.value);

      /// IMPORTANT FIX:
      /// Global live_stream_created/list events from another room must never reset
      /// the current room gift total. Example: current=6810, event=6931.
      if (currentStreamId > 0 &&
          payloadStreamId > 0 &&
          payloadStreamId != currentStreamId) {
        liveLog(
          '⛔ Gift coins ignored from other stream '
          '=> event=$payloadStreamId current=$currentStreamId source=$source keep=${totalGiftCoins.value}',
        );
        return;
      }

      /// Partial/late response must not reset old total to 0.
      if (coins == 0 && totalGiftCoins.value > 0) {
        liveLog(
          '🪙 Gift coins zero reset ignored from $source, keep=${totalGiftCoins.value}',
        );
        return;
      }

      if (coins > 0 || totalGiftCoins.value <= 0) {
        totalGiftCoins.value = coins;
      }
    } catch (e) {
      liveLog('⚠️ syncGiftCoinsFromPayload error => $e');
    }
  }

  // Gift tracking variables
  // Gift tracking state remains transport-authoritative on WebsocketController.

  /// ✅ Realtime per-user received gift coins for seat UI.
  ///
  /// IMPORTANT:
  /// The key is room-scoped: "livestreamId:userId".
  /// Using only userId allowed coins from room A to appear when the same user
  /// entered room B. Seat UI must show only coins received inside the currently
  /// open broadcast, never the user's lifetime earned_coins/gifts_coins.

  int _giftCoinRoomId({int? livestreamId}) {
    final int requested = _toInt(livestreamId);
    if (requested > 0) return requested;

    final int websocketStream = _toInt(streamID.value);
    if (websocketStream > 0) return websocketStream;

    final int activeStream = _toInt(activeAudioStreamId.value);
    if (activeStream > 0) return activeStream;

    try {
      final int controllerStream = _toInt(livestreamController.streamId.value);
      if (controllerStream > 0) return controllerStream;
    } catch (_) {}

    return 0;
  }

  String _liveUserGiftCoinKey({required int userId, int? livestreamId}) {
    final int roomId = _giftCoinRoomId(livestreamId: livestreamId);
    return '$roomId:$userId';
  }

  int _rowLivestreamId(Map<String, dynamic> row) {
    final Map<String, dynamic> livestream = row['livestream'] is Map
        ? Map<String, dynamic>.from(row['livestream'])
        : <String, dynamic>{};
    final Map<String, dynamic> livestreamData = row['livestreamdata'] is Map
        ? Map<String, dynamic>.from(row['livestreamdata'])
        : <String, dynamic>{};

    return _toInt(
      row['livestream_id'] ??
          row['stream_id'] ??
          row['live_stream_id'] ??
          row['live_id'] ??
          livestream['livestream_id'] ??
          livestream['stream_id'] ??
          livestream['id'] ??
          livestreamData['livestream_id'] ??
          livestreamData['stream_id'] ??
          livestreamData['id'],
    );
  }

  bool _rowBelongsToGiftRoom(Map<String, dynamic> row, int roomId) {
    if (roomId <= 0) return true;
    final int rowRoomId = _rowLivestreamId(row);

    // Call-list rows from the current room can omit livestream_id. They are safe
    // because the whole call list is cleared whenever the room changes.
    return rowRoomId <= 0 || rowRoomId == roomId;
  }

  int? _explicitCurrentLiveGiftCoins(Map<String, dynamic> row) {
    final Map<String, dynamic> user = row['user'] is Map
        ? Map<String, dynamic>.from(row['user'])
        : <String, dynamic>{};
    final Map<String, dynamic> caller = row['caller'] is Map
        ? Map<String, dynamic>.from(row['caller'])
        : <String, dynamic>{};

    final List<dynamic> values = <dynamic>[
      row['current_gift_coins'],
      row['current_live_gift_coins'],
      row['live_gift_coins'],
      row['stream_gift_coins'],
      row['livestream_gift_coins'],
      row['room_gift_coins'],
      user['current_gift_coins'],
      user['current_live_gift_coins'],
      user['live_gift_coins'],
      user['stream_gift_coins'],
      user['livestream_gift_coins'],
      user['room_gift_coins'],
      caller['current_gift_coins'],
      caller['current_live_gift_coins'],
      caller['live_gift_coins'],
      caller['stream_gift_coins'],
      caller['livestream_gift_coins'],
      caller['room_gift_coins'],
    ];

    for (final dynamic value in values) {
      if (value == null) continue;
      return _toInt(value);
    }

    return null;
  }

  /// Public room-scoped reader used by every seat, including the owner seat.
  /// Generic account fields (earned_coins, earn_coins, gifts_coins,
  /// received_coins) are intentionally ignored because they may be lifetime
  /// wallet totals and were the reason a wrong value appeared in another room.
  int currentLiveGiftCoinsForUser({required int userId, int? livestreamId}) {
    if (userId <= 0) return 0;

    final int roomId = _giftCoinRoomId(livestreamId: livestreamId);
    final String key = _liveUserGiftCoinKey(
      userId: userId,
      livestreamId: roomId,
    );

    if (liveUserGiftCoins.containsKey(key)) {
      return _toInt(liveUserGiftCoins[key]);
    }

    for (final dynamic raw in liveCallList) {
      if (raw is! Map) continue;
      final Map<String, dynamic> call = Map<String, dynamic>.from(raw);
      if (!_rowBelongsToGiftRoom(call, roomId)) continue;

      final Map<String, dynamic> user = call['user'] is Map
          ? Map<String, dynamic>.from(call['user'])
          : <String, dynamic>{};
      final Map<String, dynamic> caller = call['caller'] is Map
          ? Map<String, dynamic>.from(call['caller'])
          : <String, dynamic>{};
      final int callUserId = _toInt(
        call['caller_id'] ??
            call['user_id'] ??
            call['viewer_id'] ??
            user['id'] ??
            user['user_id'] ??
            caller['id'] ??
            caller['user_id'],
      );
      if (callUserId != userId) continue;

      return _explicitCurrentLiveGiftCoins(call) ?? 0;
    }

    return 0;
  }

  int _currentGiftCoinsForUser(int userId) {
    return currentLiveGiftCoinsForUser(userId: userId);
  }

  Map<int, int> giftCoinSnapshotForUsers(Iterable<int> userIds) {
    final Map<int, int> snapshot = <int, int>{};
    for (final int rawId in userIds) {
      final int id = _toInt(rawId);
      if (id <= 0 || snapshot.containsKey(id)) continue;
      snapshot[id] = _currentGiftCoinsForUser(id);
    }
    return snapshot;
  }

  /// Sender-side API reconciliation for one physical tap.
  ///
  /// The old containsKey fallback stopped working after the first gift because
  /// the receiver key remained in liveUserGiftCoins forever. This method uses
  /// the value captured before that tap and guarantees at least +giftPrice,
  /// while still avoiding a double increment when WebSocket already applied it.
  void ensureSenderGiftCoinsAtLeast({
    required List<int> receiverIds,
    required Map<int, int> baselineCoins,
    required int coinValue,
  }) {
    if (coinValue <= 0 || receiverIds.isEmpty) return;

    final Map<int, int> missingDelta = <int, int>{};
    for (final int rawId in receiverIds) {
      final int id = _toInt(rawId);
      if (id <= 0) continue;

      final int expected = (baselineCoins[id] ?? 0) + coinValue;
      final int current = _currentGiftCoinsForUser(id);
      if (current < expected) {
        missingDelta[id] = expected - current;
      }
    }

    if (missingDelta.isEmpty) return;
    _applyReceiverGiftCoinDeltas(missingDelta);
  }

  /// Entry animation duplicate/safety guard.
  /// viewer_joined + live_comment + rebuild একসাথে আসলে একই user এর entry বারবার
  /// restart/print হবে না। SVGA onFinished না এলেও fallback hide হবে।

  // Broadcaster status monitoring
  // show animation when user joined the stream

  /// Entry animation show korbe only.
  /// Hide/clear hobe EntryAnimation widget er SVGA onFinished callback theke.
  /// Tai ekhane kono fixed 3 seconds timer rakha jabe na.

  void showGiftsAnimation() {
    _giftAnimationHideTimer?.cancel();
    if (giftsData.isNotEmpty) {
      isGiftAnimationShowing.value = true;
    } else {
      _showNextQueuedGiftAnimation();
    }
  }

  bool _isLuckyAnimationMap(Map<String, dynamic> data) {
    final Map<String, dynamic> gift = data['gift'] is Map
        ? Map<String, dynamic>.from(data['gift'])
        : <String, dynamic>{};
    final String category =
        (data['gift_category'] ??
                data['gift_type'] ??
                data['type'] ??
                gift['category'] ??
                gift['gift_category'] ??
                gift['gift_type'] ??
                gift['type'] ??
                gift['name'] ??
                '')
            .toString()
            .toLowerCase();
    return data['is_lucky_gift'] == true ||
        data['is_lucky_gift'].toString() == '1' ||
        gift['is_lucky_gift'] == true ||
        gift['is_lucky_gift'].toString() == '1' ||
        category.contains('lucky');
  }

  void _mountLuckyQueueItemWithoutClosingCard(Map<String, dynamic> next) {
    _luckyCardHideTimer?.cancel();
    _luckyCurrentFlightComplete = false;
    giftsData.value = Map<String, dynamic>.from(next);
    giftsData.refresh();
    isGiftAnimationShowing.value = true;
    isGiftAnimationShowing.refresh();
  }

  /// Normal gifts close after each animation.
  /// Lucky gifts keep one horizontal card mounted for 7 seconds. Every fast
  /// Combo tap only changes the values inside that same card and starts the next
  /// queued flight, so the card never flashes or recreates.
  void hideGiftAnimation({bool clearData = true}) {
    _giftAnimationHideTimer?.cancel();

    final Map<String, dynamic> current = giftsData.isNotEmpty
        ? Map<String, dynamic>.from(giftsData)
        : <String, dynamic>{};

    if (_isLuckyAnimationMap(current)) {
      _luckyCurrentFlightComplete = true;

      if (_giftAnimationQueue.isNotEmpty) {
        final Map<String, dynamic> next = Map<String, dynamic>.from(
          _giftAnimationQueue.removeFirst(),
        );
        // Mount synchronously. A microtask gap allowed a new rapid tap to
        // overtake this queued item and could overwrite/reorder animations.
        _mountLuckyQueueItemWithoutClosingCard(next);
        return;
      }

      _luckyCardHideTimer?.cancel();
      _luckyCardHideTimer = Timer(const Duration(seconds: 7), () {
        if (_giftAnimationQueue.isNotEmpty) {
          final Map<String, dynamic> next = Map<String, dynamic>.from(
            _giftAnimationQueue.removeFirst(),
          );
          _mountLuckyQueueItemWithoutClosingCard(next);
          return;
        }

        _luckyCurrentFlightComplete = false;
        isGiftAnimationShowing.value = false;
        giftsData.value = <String, dynamic>{};
      });
      return;
    }

    isGiftAnimationShowing.value = false;
    if (clearData) {
      giftsData.value = <String, dynamic>{};
    }

    if (_giftAnimationQueue.isNotEmpty) {
      Future.microtask(_showNextQueuedGiftAnimation);
    }
  }

  // Show gift animation
  void showGiftAnimation(Map<String, dynamic> giftData) {
    try {
      _handleUnifiedGift({...giftData, 'force_show': true});
    } catch (e) {
      liveLog("❌ Error showing gift animation: $e");
    }
  }

  // Red Packet Methods

  Map<String, dynamic> _mapFrom(dynamic value) {
    if (value is Map<String, dynamic>) return Map<String, dynamic>.from(value);
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  bool _giftValueOk(dynamic value) {
    if (value == null) return false;
    final v = value.toString().trim();
    return v.isNotEmpty && v.toLowerCase() != 'null' && v != '0';
  }

  dynamic _pickGiftValue(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (_giftValueOk(value) || value is Map || value is List) return value;
    }
    return null;
  }

  Map<String, dynamic> _mergeGiftUserMaps(List<Map<String, dynamic>> maps) {
    final merged = <String, dynamic>{};
    for (final map in maps) {
      map.forEach((key, value) {
        if (_giftValueOk(value) || value is Map || value is List) {
          merged[key.toString()] = value;
        }
      });
    }
    return merged;
  }

  Map<String, dynamic> _findGiftUserById(dynamic userId) {
    final uid = _toInt(userId);
    if (uid <= 0) return <String, dynamic>{};

    final cached = _liveUserProfileCache[uid];
    if (cached != null && cached.isNotEmpty)
      return Map<String, dynamic>.from(cached);

    try {
      final currentUser = authController.userProfile.value.user;
      if (currentUser != null && _toInt(currentUser.id) == uid) {
        return {
          'id': currentUser.id,
          'user_id': currentUser.userId,
          'name': currentUser.name,
          'level': currentUser.level,
          'profile_image': currentUser.profileImage,
          // 'asset_purchase_history': currentUser.assetPurchaseHistory,
        };
      }
    } catch (_) {}

    for (final raw in liveCallList) {
      final item = _mapFrom(raw);
      final user = _mapFrom(item['user'] ?? item['caller'] ?? item['viewer']);
      final itemId = _toInt(
        user['id'] ??
            user['user_id'] ??
            item['caller_id'] ??
            item['user_id'] ??
            item['viewer_id'] ??
            item['id'],
      );
      if (itemId == uid) return _mergeGiftUserMaps([item, user]);
    }

    try {
      for (final raw in livestreamController.liveViewerList) {
        final item = _mapFrom(raw);
        final user = _mapFrom(
          item['user'] ?? item['viewer'] ?? item['viewer_data'],
        );
        final itemId = _toInt(
          user['id'] ??
              user['user_id'] ??
              item['viewer_id'] ??
              item['user_id'] ??
              item['caller_id'] ??
              item['id'],
        );
        if (itemId == uid) return _mergeGiftUserMaps([item, user]);
      }
    } catch (_) {}

    return <String, dynamic>{};
  }

  Map<String, dynamic> _normalizeGiftUser({
    required Map<String, dynamic> data,
    required String role,
    required dynamic fallbackId,
  }) {
    final direct = _mapFrom(
      _pickGiftValue(
        data,
        role == 'sender'
            ? ['sender', 'gifter', 'from_user', 'user']
            : [
                'receiver',
                'receiver_user',
                'to_user',
                'host',
                'broadcaster',
                'livestream_user',
              ],
      ),
    );

    final id =
        direct['id'] ??
        direct['user_id'] ??
        fallbackId ??
        _pickGiftValue(
          data,
          role == 'sender'
              ? ['sender_id', 'gifter_id', 'user_id']
              : ['receiver_id', 'to_user_id', 'host_id', 'broadcaster_id'],
        );

    final cached = _findGiftUserById(id);

    return _mergeGiftUserMaps([
      cached,
      direct,
      {
        'id': id,
        'user_id': direct['user_id'] ?? id,
        'name': _pickGiftValue(
          data,
          role == 'sender'
              ? ['sender_name', 'gifter_name', 'user_name', 'name']
              : [
                  'receiver_name',
                  'to_user_name',
                  'host_name',
                  'broadcaster_name',
                ],
        ),
        'level': _pickGiftValue(
          data,
          role == 'sender'
              ? ['sender_level', 'gifter_level', 'level']
              : [
                  'receiver_level',
                  'to_user_level',
                  'host_level',
                  'broadcaster_level',
                ],
        ),
        'profile_image': _pickGiftValue(
          data,
          role == 'sender'
              ? [
                  'sender_profile_image',
                  'gifter_profile_image',
                  'profile_image',
                  'avatar',
                ]
              : [
                  'receiver_profile_image',
                  'to_user_profile_image',
                  'host_profile_image',
                  'broadcaster_profile_image',
                ],
        ),
      },
    ]);
  }

  Map<String, dynamic> _normalizeGiftAsset(Map<String, dynamic> data) {
    final direct = _mapFrom(
      _pickGiftValue(data, ['gift', 'gift_data', 'gift_info', 'asset']),
    );
    return _mergeGiftUserMaps([
      direct,
      {
        'id':
            direct['id'] ?? _pickGiftValue(data, ['gift_id', 'asset_id', 'id']),
        'name':
            direct['name'] ??
            _pickGiftValue(data, ['gift_name', 'asset_name', 'name']),
        'image':
            direct['image'] ??
            direct['gift_image'] ??
            direct['show_image'] ??
            _pickGiftValue(data, [
              'gift_image',
              'image',
              'show_image',
              'thumbnail',
              'icon',
              'svga',
            ]),
        'gift_image':
            direct['gift_image'] ??
            direct['image'] ??
            _pickGiftValue(data, [
              'gift_image',
              'image',
              'show_image',
              'thumbnail',
              'icon',
              'svga',
            ]),
        'show_image':
            direct['show_image'] ??
            direct['image'] ??
            _pickGiftValue(data, [
              'show_image',
              'gift_image',
              'image',
              'thumbnail',
              'icon',
              'svga',
            ]),
        'coin':
            direct['coin'] ??
            direct['coins'] ??
            _pickGiftValue(data, ['gift_coin', 'coin', 'coins', 'total_coins']),
        'audio':
            direct['audio'] ??
            direct['gift_audio'] ??
            direct['sound'] ??
            direct['audio_url'] ??
            _pickGiftValue(data, [
              'audio',
              'gift_audio',
              'sound',
              'sound_url',
              'audio_url',
              'gift_sound',
            ]),
        'gift_audio':
            direct['gift_audio'] ??
            direct['audio'] ??
            direct['sound'] ??
            direct['audio_url'] ??
            _pickGiftValue(data, [
              'gift_audio',
              'audio',
              'sound',
              'sound_url',
              'audio_url',
              'gift_sound',
            ]),
        'sound':
            direct['sound'] ??
            direct['audio'] ??
            direct['gift_audio'] ??
            _pickGiftValue(data, [
              'sound',
              'audio',
              'gift_audio',
              'sound_url',
              'audio_url',
              'gift_sound',
            ]),
        'category':
            direct['category'] ??
            direct['gift_category'] ??
            direct['gift_type'] ??
            _pickGiftValue(data, [
              'category',
              'gift_category',
              'gift_type',
              'type',
            ]),
        'gift_category':
            direct['gift_category'] ??
            direct['category'] ??
            _pickGiftValue(data, ['gift_category', 'category']),
        'gift_type':
            direct['gift_type'] ??
            direct['type'] ??
            _pickGiftValue(data, ['gift_type', 'type']),
        'is_lucky': direct['is_lucky'] ?? _pickGiftValue(data, ['is_lucky']),
        'is_lucky_gift':
            direct['is_lucky_gift'] ?? _pickGiftValue(data, ['is_lucky_gift']),
        'lucky': direct['lucky'] ?? _pickGiftValue(data, ['lucky']),
        'lucky_ratio':
            direct['lucky_ratio'] ?? _pickGiftValue(data, ['lucky_ratio']),
        'lucky_coin':
            direct['lucky_coin'] ?? _pickGiftValue(data, ['lucky_coin']),
        'back_coin': direct['back_coin'] ?? _pickGiftValue(data, ['back_coin']),
      },
    ]);
  }

  String _normalGiftMediaPath(Map<String, dynamic> gift) {
    final String path =
        (gift['gift_image'] ??
                gift['image'] ??
                gift['show_image'] ??
                gift['svga'] ??
                gift['animation'] ??
                gift['animation_url'] ??
                '')
            .toString()
            .trim();

    if (path.isEmpty || path.toLowerCase() == 'null' || path == 'file:///') {
      return '';
    }
    return path;
  }

  bool _normalGiftHasPlayableMedia(Map<String, dynamic> gift) {
    return _normalGiftMediaPath(gift).isNotEmpty;
  }

  bool _mountedNormalGiftIsInvalid() {
    if (!isGiftAnimationShowing.value || giftsData.isEmpty) return false;

    final Map<String, dynamic> current = Map<String, dynamic>.from(giftsData);
    if (_isLuckyAnimationMap(current)) return false;

    final Map<String, dynamic> currentGift = _normalizeGiftAsset(current);
    return !_normalGiftHasPlayableMedia(currentGift);
  }

  /// Sender-side instant animation is shown before the API/WebSocket finishes.
  /// The timestamp map is kept as a safety timeout; echo credits are counted so
  /// five fast Combo taps can suppress five confirmed echoes, not only the first.

  /// Exact sender request identity echoed by the optimized backend.
  /// Keeping it alive for the whole response window suppresses every
  /// multi-receiver echo belonging to the same physical tap.

  /// One RxMap cannot represent several fast taps: assigning the second event
  /// used to overwrite/cut the first widget. Every event is now stored here and
  /// mounted only after the previous GiftAnimationWidget calls hideGiftAnimation.

  /// Lucky reference-video card stays mounted while its individual gift flights
  /// are consumed one by one.

  void _enqueueGiftAnimation(Map<String, dynamic> rawData) {
    final Map<String, dynamic> data = Map<String, dynamic>.from(rawData);

    final bool incomingLucky = _isLuckyAnimationMap(data);
    final Map<String, dynamic> incomingGift = _normalizeGiftAsset(data);

    /// Never put an image-less normal gift into FIFO. The previous first-tap
    /// delay happened because a temporary fallback gift (`Gift`, no image URL)
    /// occupied the active slot until the long safety timer fired.
    if (!incomingLucky && !_normalGiftHasPlayableMedia(incomingGift)) {
      liveLog(
        '⚡ Empty normal gift animation skipped immediately '
        '=> giftId=${incomingGift['id'] ?? data['gift_id']}',
      );
      return;
    }

    /// Repair an old/stale invisible item immediately before mounting the new
    /// valid gift. Do not wait 8-20 seconds for a safety timeout.
    if (_mountedNormalGiftIsInvalid()) {
      liveLog('⚡ Stale empty normal gift cleared before next animation');
      isGiftAnimationShowing.value = false;
      giftsData.value = <String, dynamic>{};
      giftsData.refresh();
    }

    final int serial = ++_giftAnimationSerial;

    // Preserve the sender-side physical tap serial. The queue serial is only
    // an internal ordering number; replacing the physical serial made the same
    // tap look new again when local/API/WebSocket copies reached this queue.
    final dynamic physicalSerial =
        data['gift_animation_serial'] ??
        data['animation_serial'] ??
        data['client_combo_serial'] ??
        data['combo_serial'] ??
        data['tap_serial'] ??
        data['send_serial'];
    data['gift_animation_serial'] ??= physicalSerial ?? serial;
    data['animation_serial'] ??= data['gift_animation_serial'];
    data['timestamp'] ??= DateTime.now().toIso8601String();
    data['animation_queue_serial'] = serial;

    final bool currentLucky =
        giftsData.isNotEmpty &&
        _isLuckyAnimationMap(Map<String, dynamic>.from(giftsData));

    /// Card is still visible but the previous Lucky flight has already ended:
    /// put the new tap directly into the same mounted widget.
    if (incomingLucky &&
        currentLucky &&
        isGiftAnimationShowing.value &&
        _luckyCurrentFlightComplete) {
      _mountLuckyQueueItemWithoutClosingCard(data);
      return;
    }

    // Keep the exact first 200 rapid taps. Beyond that, replace the oldest
    // not-yet-mounted item instead of allowing unbounded Map/list growth to
    // terminate low-memory devices. Normal use (including 100 taps) is exact.
    if (_giftAnimationQueue.length >= 200) {
      _giftAnimationQueue.removeFirst();
    }
    _giftAnimationQueue.addLast(data);

    _forceGiftPrint('GIFT ANIMATION QUEUE ITEM ADDED', {
      'queue_serial': serial,
      'incoming_is_lucky': incomingLucky,
      'current_is_lucky': currentLucky,
      'queue_length_after_add': _giftAnimationQueue.length,
      'is_animation_showing': isGiftAnimationShowing.value,
      'queued_data': data,
    });

    // Never drop a physical Combo tap. Queue.removeFirst() keeps processing O(1)
    // even when many taps are waiting, so exact tap count is preserved smoothly.

    if (!isGiftAnimationShowing.value && !_giftAnimationQueueMounting) {
      _showNextQueuedGiftAnimation();
    }
  }

  void _showNextQueuedGiftAnimation() {
    if (_giftAnimationQueueMounting || isGiftAnimationShowing.value) return;
    if (_giftAnimationQueue.isEmpty) return;

    _giftAnimationQueueMounting = true;
    try {
      Map<String, dynamic>? next;

      /// Old queued fallback rows may already exist from an earlier tap. Skip
      /// every invalid normal row in the same microtask so the first real SVGA
      /// mounts without a safety-timer delay.
      while (_giftAnimationQueue.isNotEmpty) {
        final Map<String, dynamic> candidate = Map<String, dynamic>.from(
          _giftAnimationQueue.removeFirst(),
        );
        final bool lucky = _isLuckyAnimationMap(candidate);
        final Map<String, dynamic> candidateGift = _normalizeGiftAsset(
          candidate,
        );

        if (lucky || _normalGiftHasPlayableMedia(candidateGift)) {
          next = candidate;
          break;
        }

        liveLog(
          '⚡ Invalid queued normal gift discarded '
          '=> giftId=${candidateGift['id'] ?? candidate['gift_id']}',
        );
      }

      if (next == null) return;

      _luckyCardHideTimer?.cancel();
      _luckyCurrentFlightComplete = false;
      giftsData.value = next;
      giftsData.refresh();

      _forceGiftPrint('GIFT ANIMATION MOUNTED FINAL DATA', {
        'mounted_gifts_data': next,
        'remaining_queue_length': _giftAnimationQueue.length,
        'gift_animation_serial': next['gift_animation_serial'],
        'animation_serial': next['animation_serial'],
      });

      isGiftAnimationShowing.value = true;
      isGiftAnimationShowing.refresh();
    } finally {
      _giftAnimationQueueMounting = false;
    }
  }

  int _giftInt(dynamic value) => _toInt(value);

  bool _payloadHasAuthoritativeGiftTotal(Map<String, dynamic> payload) {
    try {
      final List<Map<String, dynamic>> maps = <Map<String, dynamic>>[payload];

      for (final key in [
        'data',
        'livestream',
        'livestreamdata',
        'live_stream',
      ]) {
        final dynamic value = payload[key];
        if (value is Map<String, dynamic>) {
          maps.add(value);
        } else if (value is Map) {
          maps.add(Map<String, dynamic>.from(value));
        }
      }

      for (final map in maps) {
        if (map.containsKey('total_gift_coins') ||
            map.containsKey('total_coins') ||
            map.containsKey('gift_amount') ||
            map.containsKey('stream_coins') ||
            map.containsKey('received_coins')) {
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  List<int> _giftReceiverIdsFromPayload(
    Map<String, dynamic> data,
    dynamic singleReceiverId, {
    bool allowReceiverList = false,
  }) {
    final ids = <int>[];

    void addOne(dynamic value) {
      final id = _giftInt(value);
      if (id > 0 && !ids.contains(id)) ids.add(id);
    }

    /// ✅ Important multi-receiver rule:
    /// - Local optimistic sender-side payload can use receiver_ids so every
    ///   selected user gets instant animation.
    /// - Backend/websocket echo must normally use only receiver_id, otherwise
    ///   every single receiver event adds the gift price to all selected users
    ///   again and seat coin becomes multiplied.
    if (allowReceiverList) {
      final rawList =
          data['animation_receiver_ids'] ??
          data['receiver_ids_for_animation'] ??
          data['lucky_receiver_ids'] ??
          data['all_receiver_ids'] ??
          data['receiver_ids'] ??
          data['receiverIds'] ??
          data['to_user_ids'] ??
          data['receiver_id_list'];

      if (rawList is List) {
        for (final id in rawList) {
          addOne(id);
        }
      }
    }

    addOne(singleReceiverId);
    return ids;
  }

  Map<String, dynamic> _findLiveUserForGift(dynamic rawUserId) {
    final idText = rawUserId?.toString() ?? '';
    if (idText.isEmpty || idText == 'null') return <String, dynamic>{};

    Map<String, dynamic> userFromMap(Map item) {
      final user = item['user'];
      final caller = item['caller'];
      final viewer = item['viewer'];
      final sender = item['sender'];
      final receiver = item['receiver'];

      final nested = user is Map
          ? Map<String, dynamic>.from(user)
          : caller is Map
          ? Map<String, dynamic>.from(caller)
          : viewer is Map
          ? Map<String, dynamic>.from(viewer)
          : sender is Map
          ? Map<String, dynamic>.from(sender)
          : receiver is Map
          ? Map<String, dynamic>.from(receiver)
          : <String, dynamic>{};

      final ids = [
        item['id'],
        item['user_id'],
        item['caller_id'],
        item['viewer_id'],
        nested['id'],
        nested['user_id'],
      ];

      final matched = ids.any((v) => v?.toString() == idText);
      if (!matched) return <String, dynamic>{};

      if (nested.isNotEmpty) return nested;
      return Map<String, dynamic>.from(item);
    }

    for (final list in [
      liveCallList,
      pendingCall,
      commentsList,
      giftMessagesList,
    ]) {
      for (final raw in list) {
        if (raw is! Map) continue;
        final found = userFromMap(Map<String, dynamic>.from(raw));
        if (found.isNotEmpty) return found;
      }
    }

    final currentUser = authController.userProfile.value.user;
    final currentUserId = currentUser?.id?.toInt() ?? 0;
    if (currentUserId.toString() == idText) {
      return {
        'id': currentUserId,
        'user_id': currentUserId,
        'name': currentUser?.name ?? 'You',
        'profile_image': currentUser?.profileImage ?? '',
        'level': currentUser?.level ?? 0,
        'coins': currentUser?.coins,
        'earned_coins': currentUser?.earnedCoins,
      };
    }

    return {'id': _giftInt(rawUserId), 'user_id': _giftInt(rawUserId)};
  }

  /// Sender side fallback: backend sometimes sends bulk receiver_ids but
  /// websocket broadcasts only the first receiver_id. This method updates
  /// only receivers that did not arrive through websocket within fallback delay.
  void applySenderGiftCoinFallback({
    required List<int> receiverIds,
    required int coinValue,
  }) {
    final missing = <int>[];

    for (final id in receiverIds) {
      if (id <= 0) continue;
      final key = _liveUserGiftCoinKey(userId: id);

      /// If websocket already updated this receiver in THIS room, don't add
      /// again. A key from another room can never suppress the current room.
      if (liveUserGiftCoins.containsKey(key)) continue;

      missing.add(id);
    }

    if (missing.isEmpty) {
      return;
    }

    _addReceiverGiftCoins(receiverIds: missing, coinValue: coinValue);
  }

  void _applyReceiverGiftCoinDeltas(Map<int, int> deltas) {
    if (deltas.isEmpty) return;

    final List<dynamic> rows = liveCallList;

    for (final MapEntry<int, int> entry in deltas.entries) {
      final int receiverId = entry.key;
      final int delta = entry.value;
      if (receiverId <= 0 || delta <= 0) continue;

      final String key = _liveUserGiftCoinKey(userId: receiverId);
      final int oldValue = _currentGiftCoinsForUser(receiverId);
      final int nextRoomCoins = oldValue + delta;
      liveUserGiftCoins[key] = nextRoomCoins;

      for (int index = 0; index < rows.length; index++) {
        final dynamic raw = rows[index];
        if (raw is! Map) continue;

        final Map<String, dynamic> call = Map<String, dynamic>.from(raw);
        final Map<String, dynamic> oldUser = call['user'] is Map
            ? Map<String, dynamic>.from(call['user'])
            : <String, dynamic>{};

        final int callUserId = _toInt(
          call['caller_id'] ??
              call['user_id'] ??
              call['viewer_id'] ??
              oldUser['id'] ??
              oldUser['user_id'],
        );
        if (callUserId != receiverId) continue;

        /// Update only room-scoped coin fields. Never overwrite
        /// earned_coins/earn_coins/gifts_coins/received_coins here because those
        /// can be lifetime wallet totals from the user profile.
        call['current_gift_coins'] = nextRoomCoins;
        call['current_live_gift_coins'] = nextRoomCoins;
        call['live_gift_coins'] = nextRoomCoins;
        call['stream_gift_coins'] = nextRoomCoins;

        if (oldUser.isNotEmpty) {
          oldUser['current_gift_coins'] = nextRoomCoins.toString();
          oldUser['current_live_gift_coins'] = nextRoomCoins.toString();
          oldUser['live_gift_coins'] = nextRoomCoins.toString();
          oldUser['stream_gift_coins'] = nextRoomCoins.toString();
          call['user'] = oldUser;
        }

        // Mutate the RxList's underlying value and notify once after every
        // receiver is processed. liveCallList[index] = ... emitted one rebuild
        // per receiver and became expensive for 8/20/100 receiver gifts.
        rows[index] = call;
        break;
      }
    }

    liveUserGiftCoins.refresh();
    _refreshLiveCallListSmooth();
  }

  void _addReceiverGiftCoins({
    required List<int> receiverIds,
    required int coinValue,
  }) {
    if (coinValue <= 0 || receiverIds.isEmpty) return;

    final Map<int, int> deltas = <int, int>{};
    for (final int rawId in receiverIds) {
      final int receiverId = _toInt(rawId);
      if (receiverId <= 0) continue;
      deltas[receiverId] = (deltas[receiverId] ?? 0) + coinValue;
    }

    _applyReceiverGiftCoinDeltas(deltas);
  }

  int _giftSeatNoForUser(dynamic rawUserId, Map<String, dynamic> payload) {
    final int userId = _toInt(rawUserId);
    if (userId <= 0) return 0;

    final Map<String, dynamic> sender = _mapFrom(
      payload['sender'] ?? payload['gifter'] ?? payload['from_user'],
    );
    final Map<String, dynamic> receiver = _mapFrom(
      payload['receiver'] ?? payload['receiver_user'] ?? payload['to_user'],
    );

    final int senderId = _toInt(sender['id'] ?? sender['user_id']);
    final int receiverId = _toInt(receiver['id'] ?? receiver['user_id']);

    if (senderId == userId) {
      final int senderSeat = _toInt(
        payload['sender_seat_no'] ??
            payload['sender_seat'] ??
            sender['seat_no'] ??
            sender['seat'] ??
            sender['seat_number'],
      );
      if (senderSeat > 0) return senderSeat;
    }

    if (receiverId == userId) {
      final int receiverSeat = _toInt(
        payload['receiver_seat_no'] ??
            payload['receiver_seat'] ??
            payload['seat_no'] ??
            receiver['seat_no'] ??
            receiver['seat'] ??
            receiver['seat_number'],
      );
      if (receiverSeat > 0) return receiverSeat;
    }

    for (final raw in liveCallList) {
      if (raw is! Map) continue;

      final Map<String, dynamic> call = Map<String, dynamic>.from(raw);
      final Map<String, dynamic> user = _mapFrom(
        call['user'] ?? call['caller'] ?? call['viewer'],
      );

      final int callUserId = _toInt(
        call['caller_id'] ??
            call['user_id'] ??
            call['viewer_id'] ??
            user['id'] ??
            user['user_id'],
      );

      if (callUserId != userId) continue;

      return _toInt(
        call['seat_no'] ??
            call['seat'] ??
            call['seat_number'] ??
            user['seat_no'] ??
            user['seat'] ??
            user['seat_number'],
      );
    }

    return 0;
  }

  int _giftQuantityFromPayload(
    Map<String, dynamic> giftData,
    Map<String, dynamic> gift,
  ) {
    final int quantity = _toInt(
      giftData['quantity'] ??
          giftData['qty'] ??
          giftData['count'] ??
          giftData['gift_count'] ??
          giftData['gift_quantity'] ??
          giftData['total_gift'] ??
          giftData['total_quantity'] ??
          giftData['combo_count'] ??
          giftData['combo'] ??
          gift['quantity'] ??
          gift['qty'] ??
          gift['count'] ??
          gift['gift_count'],
    );

    return quantity > 0 ? quantity : 1;
  }

  void _printGiftOnlyLog({
    required Map<String, dynamic> giftData,
    required Map<String, dynamic> sender,
    required Map<String, dynamic> receiver,
    required Map<String, dynamic> gift,
  }) {
    final int senderId = _toInt(sender['id'] ?? sender['user_id']);
    final int receiverId = _toInt(receiver['id'] ?? receiver['user_id']);
    final int senderSeat = _giftSeatNoForUser(senderId, {
      ...giftData,
      'sender': sender,
    });
    final int receiverSeat = _giftSeatNoForUser(receiverId, {
      ...giftData,
      'receiver': receiver,
    });
    final int quantity = _giftQuantityFromPayload(giftData, gift);

    final String senderName =
        (sender['name'] ?? sender['username'] ?? ('User').appTr).toString();
    final String receiverName =
        (receiver['name'] ?? receiver['username'] ?? ('User').appTr).toString();
    final String giftName =
        (gift['name'] ?? gift['gift_name'] ?? ('Gift').appTr).toString();

    final String senderSeatText = senderSeat > 0 ? '$senderSeat' : 'none';
    final String receiverSeatText = receiverSeat > 0 ? '$receiverSeat' : 'none';

    liveLog(
      '🎁 GIFT => $senderName(ID:$senderId, seat:$senderSeatText) '
      '→ $receiverName(ID:$receiverId, seat:$receiverSeatText) '
      '| gift:$giftName | quantity:$quantity',
    );
  }

  /// Public entry for sender-side instant animation only.
  /// Coins, history and final totals still come from the confirmed WebSocket event.
  void handleOptimisticGift(Map<String, dynamic> payload) {
    _forceGiftPrint('GIFT OPTIMISTIC HANDLER INPUT ALL DATA', {
      'payload': payload,
      'current_stream_id': streamID.value,
      'active_audio_stream_id': activeAudioStreamId.value,
      'queue_length_before': _giftAnimationQueue.length,
      'current_gifts_data_before': giftsData,
    });

    _handleUnifiedGift({
      ...payload,
      'client_optimistic': true,
      'optimistic_local': true,
      'source': 'local_send',
      'force_show': true,
      'animation_only': true,
    });
  }

  void cancelOptimisticGiftAnimation({String? clientEventId}) {
    try {
      final String target = clientEventId?.trim() ?? '';

      if (target.isNotEmpty) {
        _optimisticClientEventUntilMs.remove(target);
        _giftAnimationQueue.removeWhere((Map<String, dynamic> item) {
          final String itemId =
              (item['client_event_id'] ?? item['client_request_id'] ?? '')
                  .toString()
                  .trim();
          return itemId == target && item['optimistic_local'] == true;
        });

        final String currentId =
            (giftsData['client_event_id'] ??
                    giftsData['client_request_id'] ??
                    '')
                .toString()
                .trim();

        if (currentId == target && giftsData['optimistic_local'] == true) {
          hideGiftAnimation();
        }
        return;
      }

      if (giftsData['optimistic_local'] == true) {
        hideGiftAnimation();
      }
    } catch (_) {}
  }

  void _handleUnifiedGift(Map<String, dynamic> payload) {
    _forceGiftPrint('🎁 HANDLE UNIFIED GIFT RAW PAYLOAD', payload);

    final giftData = <String, dynamic>{
      ...payload,
      ..._mapFrom(payload['data']),
      ..._mapFrom(payload['gift_data']),
      ..._mapFrom(payload['gift_info']),
    };

    _forceGiftPrint('🎁 HANDLE UNIFIED GIFT MERGED DATA', {
      'raw_payload': payload,
      'merged_gift_data': giftData,
      'raw_data': payload['data'],
      'raw_gift': payload['gift'],
      'raw_gift_data': payload['gift_data'],
      'raw_gift_info': payload['gift_info'],
      'raw_lucky_result': payload['lucky_result'],
      'raw_lucky_results': payload['lucky_results'],
    });

    final livestreamId =
        giftData['livestream_id'] ??
        giftData['stream_id'] ??
        payload['livestream_id'] ??
        payload['stream_id'];

    /// ✅ PK gift guard:
    /// During PK, gift can be sent to opponent livestream id. That is not the
    /// current stream id, but it still belongs to current PK battle and must
    /// update PK progress bar / animation. Normal single-live behavior remains
    /// unchanged.
    bool isPkGiftForCurrentBattle = false;
    try {
      final bool looksPkGift =
          payload['is_pk'] == true ||
          payload['is_pk'] == 1 ||
          payload['is_pk']?.toString() == '1' ||
          giftData['is_pk'] == true ||
          giftData['is_pk'] == 1 ||
          giftData['is_pk']?.toString() == '1' ||
          _toInt(payload['pk_id'] ?? giftData['pk_id']) > 0 ||
          (payload['pk_channel'] ??
                  payload['pk_channel_name'] ??
                  giftData['pk_channel'] ??
                  giftData['pk_channel_name'] ??
                  '')
              .toString()
              .trim()
              .isNotEmpty;

      if (looksPkGift) {
        final int eventStreamId = _toInt(livestreamId);
        final int eventPkId = _toInt(payload['pk_id'] ?? giftData['pk_id']);
        final String eventChannel =
            (payload['pk_channel_name'] ??
                    payload['pk_channel'] ??
                    giftData['pk_channel_name'] ??
                    giftData['pk_channel'] ??
                    '')
                .toString()
                .trim();

        final int currentPkId = livestreamController.currentPkId.value;
        final bool pkIdMatch =
            eventPkId > 0 && currentPkId > 0 && eventPkId == currentPkId;
        final bool pkChannelMatch =
            eventChannel.isNotEmpty &&
            livestreamController.pkChannelName.value.trim().isNotEmpty &&
            eventChannel == livestreamController.pkChannelName.value.trim();
        final bool pkStreamMatch =
            eventStreamId > 0 &&
            (eventStreamId == livestreamController.pkSenderLivestreamId.value ||
                eventStreamId ==
                    livestreamController.pkReceiverLivestreamId.value);

        isPkGiftForCurrentBattle = pkIdMatch || pkChannelMatch || pkStreamMatch;
      }
    } catch (e) {
      liveLog('⚠️ PK gift guard check skipped => $e');
    }

    if (livestreamId != null &&
        !_isCurrentStream(livestreamId) &&
        !isPkGiftForCurrentBattle) {
      liveLog('⛔ GIFT ignored: not current stream => $livestreamId');
      return;
    }

    final Map<String, dynamic> giftForLuckyCheck = _mapFrom(
      giftData['gift'] ??
          giftData['gift_data'] ??
          giftData['gift_info'] ??
          giftData['asset'],
    );

    String luckyText(dynamic value) =>
        value?.toString().trim().toLowerCase() ?? '';

    bool luckyTrue(dynamic value) {
      final text = luckyText(value);
      return value == true ||
          text == '1' ||
          text == 'true' ||
          text == 'yes' ||
          text == 'lucky';
    }

    final String luckyCategory = luckyText(
      giftForLuckyCheck['category'] ??
          giftForLuckyCheck['gift_category'] ??
          giftForLuckyCheck['gift_type'] ??
          giftForLuckyCheck['type'] ??
          giftData['category'] ??
          giftData['gift_category'] ??
          giftData['gift_type'],
    );

    final bool isLuckyGiftPayload =
        luckyText(payload['action_type']).contains('lucky') ||
        luckyText(giftData['action_type']).contains('lucky') ||
        luckyCategory.contains('lucky') ||
        luckyText(giftForLuckyCheck['name']).contains('lucky') ||
        luckyTrue(payload['is_lucky_gift']) ||
        luckyTrue(giftData['is_lucky_gift']) ||
        luckyTrue(giftForLuckyCheck['is_lucky_gift']) ||
        luckyTrue(giftForLuckyCheck['is_lucky']) ||
        luckyTrue(giftForLuckyCheck['lucky']) ||
        giftForLuckyCheck['lucky_ratio'] != null ||
        giftForLuckyCheck['lucky_coin'] != null ||
        giftForLuckyCheck['back_coin'] != null ||
        payload['lucky_results'] is List ||
        giftData['lucky_results'] is List ||
        payload['big_win_events'] is List ||
        giftData['big_win_events'] is List ||
        payload['lucky_result'] is Map ||
        giftData['lucky_result'] is Map;

    if (isLuckyGiftPayload) {
      _forceGiftPrint('🍀 LUCKY GIFT_SENT / UNIFIED GIFT FULL DATA', {
        'raw_payload': payload,
        'merged_gift_data': giftData,
        'gift_for_lucky_check': giftForLuckyCheck,
        'resolved_livestream_id': livestreamId,
        'is_pk_gift_for_current_battle': isPkGiftForCurrentBattle,
        'lucky_category': luckyCategory,
        'detected_is_lucky_gift': isLuckyGiftPayload,
        'current_gifts_data_before_handle': giftsData,
        'gift_animation_queue_length': _giftAnimationQueue.length,
      });
    }

    final bool hasLuckyResultData =
        payload['lucky_result'] is Map ||
        giftData['lucky_result'] is Map ||
        (payload['lucky_results'] is List &&
            (payload['lucky_results'] as List).isNotEmpty) ||
        (giftData['lucky_results'] is List &&
            (giftData['lucky_results'] as List).isNotEmpty) ||
        (payload['big_win_events'] is List &&
            (payload['big_win_events'] as List).isNotEmpty) ||
        (giftData['big_win_events'] is List &&
            (giftData['big_win_events'] as List).isNotEmpty) ||
        payload['multiplier'] != null ||
        giftData['multiplier'] != null ||
        payload['win_amount'] != null ||
        giftData['win_amount'] != null ||
        payload['back_coin'] != null ||
        giftData['back_coin'] != null ||
        payload['win_coin'] != null ||
        giftData['win_coin'] != null;

    if (isLuckyGiftPayload) {
      _forceGiftPrint('🍀 LUCKY GIFT DETECTION DECISION', {
        'is_lucky_gift_payload': isLuckyGiftPayload,
        'has_lucky_result_data': hasLuckyResultData,
        'action_type': payload['action_type'] ?? giftData['action_type'],
        'lucky_result': payload['lucky_result'] ?? giftData['lucky_result'],
        'lucky_results': payload['lucky_results'] ?? giftData['lucky_results'],
        'big_win_events':
            payload['big_win_events'] ?? giftData['big_win_events'],
        'multiplier': payload['multiplier'] ?? giftData['multiplier'],
        'win_amount': payload['win_amount'] ?? giftData['win_amount'],
        'back_coin': payload['back_coin'] ?? giftData['back_coin'],
        'win_coin': payload['win_coin'] ?? giftData['win_coin'],
      });
    }

    if (isLuckyGiftPayload && hasLuckyResultData) {
      try {
        _handleLuckyGiftResult({...payload, ...giftData});
      } catch (e) {
        liveLog('⚠️ lucky result from gift payload failed => $e');
      }
    } else if (isLuckyGiftPayload) {
      liveLog(
        '🍀 Lucky normal gift event received. Waiting for lucky_gift_result event...',
      );
    }

    final String unifiedAction =
        (giftData['action_type'] ??
                payload['action_type'] ??
                giftData['type'] ??
                '')
            .toString()
            .trim()
            .toLowerCase();
    final bool luckyResultOnlyAction =
        unifiedAction == 'lucky_gift_result' ||
        unifiedAction == 'lucky_gift_back_coin' ||
        unifiedAction == 'lucky_gift_card' ||
        unifiedAction.contains('lucky_result');

    // Result frames update WIN/times/coin only. They are not another physical
    // send and must never enter the visual queue.
    if (isLuckyGiftPayload && luckyResultOnlyAction) {
      return;
    }

    final senderId =
        _pickGiftValue(giftData, ['sender_id', 'gifter_id', 'user_id']) ??
        _mapFrom(
          giftData['sender'] ?? giftData['gifter'] ?? giftData['user'],
        )['id'] ??
        '';

    final receiverId =
        _pickGiftValue(giftData, [
          'receiver_id',
          'to_user_id',
          'host_id',
          'broadcaster_id',
        ]) ??
        _mapFrom(
          giftData['receiver'] ??
              giftData['receiver_user'] ??
              giftData['to_user'] ??
              giftData['host'] ??
              giftData['broadcaster'],
        )['id'] ??
        '';

    final giftId =
        _pickGiftValue(giftData, ['gift_id', 'asset_id']) ??
        _mapFrom(
          giftData['gift'] ??
              giftData['gift_data'] ??
              giftData['gift_info'] ??
              giftData['asset'],
        )['id'] ??
        '';

    /// ✅ Multi receiver fix:
    /// Only sender-side optimistic payload may expand receiver_ids.
    /// Backend/websocket echo may contain receiver_ids too, but it can also
    /// send one event per receiver. If we expand that again, 300 gift x 3
    /// receivers becomes 900 on each seat.
    final bool isClientOptimisticGift =
        giftData['client_optimistic'] == true ||
        giftData['optimistic_local'] == true ||
        giftData['is_optimistic'] == true ||
        giftData['source']?.toString() == 'local_send';
    final bool alreadyExpanded = giftData['__expanded_receiver'] == true;

    /// ✅ Multi receiver robust fix:
    /// 1) If backend sends one event per receiver, use receiver_id only.
    /// 2) If backend sends one confirmed event with only receiver_ids, expand it once.
    /// 3) Local optimistic payload is normally disabled now, but kept supported.
    final bool hasConcreteSingleReceiver = _toInt(receiverId) > 0;
    final bool mayExpandReceiverList =
        !alreadyExpanded &&
        (isClientOptimisticGift || !hasConcreteSingleReceiver);

    final List<int> expandedReceiverIds = _giftReceiverIdsFromPayload(
      giftData,
      receiverId,
      allowReceiverList: mayExpandReceiverList,
    );
    // Lucky gift rule: one physical tap creates one sender-to-center image.
    // Do NOT recursively create one animation event per receiver. The single
    // Lucky request carries every receiver target and fans out in the widget.
    // Normal gifts keep the existing receiver-wise expansion behavior.
    if (!isLuckyGiftPayload &&
        !alreadyExpanded &&
        expandedReceiverIds.length > 1) {
      for (final rid in expandedReceiverIds) {
        final receiverUser = _findLiveUserForGift(rid);
        _handleUnifiedGift({
          ...giftData,
          'receiver_id': rid,
          'receiver': receiverUser,
          'receiver_user': receiverUser,
          'animation_receiver_ids': expandedReceiverIds,
          'receiver_ids_for_animation': expandedReceiverIds,
          'all_receiver_ids': expandedReceiverIds,
          'multi_receiver_gift': expandedReceiverIds.length > 1,
          '__expanded_receiver': true,
          'event_id':
              '${giftData['event_id'] ?? 'gift'}_${rid}_${DateTime.now().microsecondsSinceEpoch}',
        });
      }
      return;
    }

    /// ✅ Backend/WebSocket sometimes sends same gift event twice very fast.
    /// 800ms er moddhe same stream + sender + receiver + gift duplicate hole ignore.
    /// But user abar button click kore same gift send korle 800ms er por allow hobe.
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    final String clientEventId =
        (giftData['client_event_id'] ??
                giftData['client_request_id'] ??
                giftData['request_uuid'] ??
                '')
            .toString()
            .trim();

    _optimisticClientEventUntilMs.removeWhere(
      (String _, int until) => until <= nowMs,
    );

    final String shortDuplicateKey =
        '${livestreamId}_${senderId}_${receiverId}_${giftId}';
    final String luckySenderGiftKey =
        'lucky_${livestreamId}_${senderId}_${giftId}';

    final bool animationOnly = giftData['animation_only'] == true;
    final int optimisticUntil =
        _optimisticGiftAnimationUntilMs[shortDuplicateKey] ?? 0;
    final int optimisticCredits =
        _optimisticGiftEchoCredits[shortDuplicateKey] ?? 0;

    // A Lucky multi-receiver send can be echoed once per receiver. On the
    // sender device the visual already started optimistically, therefore every
    // matching confirmed echo must update data/coins only and never enqueue a
    // second image. The group key intentionally excludes receiver_id.
    final int luckyOptimisticUntil =
        _optimisticGiftAnimationUntilMs[luckySenderGiftKey] ?? 0;
    final int currentUserId =
        authController.userProfile.value.user?.id?.toInt() ?? 0;
    final bool senderIsCurrentUser =
        currentUserId > 0 && _toInt(senderId) == currentUserId;
    final bool suppressLuckySenderEcho =
        isLuckyGiftPayload &&
        !animationOnly &&
        senderIsCurrentUser &&
        luckyOptimisticUntil > nowMs;

    final bool suppressExactClientEcho =
        !animationOnly &&
        senderIsCurrentUser &&
        clientEventId.isNotEmpty &&
        (_optimisticClientEventUntilMs[clientEventId] ?? 0) > nowMs;

    final bool suppressConfirmedEchoAnimation =
        suppressLuckySenderEcho ||
        suppressExactClientEcho ||
        (!animationOnly && optimisticUntil > nowMs && optimisticCredits > 0);

    if (suppressConfirmedEchoAnimation && !suppressLuckySenderEcho) {
      if (optimisticCredits <= 1) {
        _optimisticGiftEchoCredits.remove(shortDuplicateKey);
        _optimisticGiftAnimationUntilMs.remove(shortDuplicateKey);
      } else {
        _optimisticGiftEchoCredits[shortDuplicateKey] = optimisticCredits - 1;
      }
    }

    final String rawServerEventId =
        (giftData['event_id'] ??
                giftData['gift_event_id'] ??
                giftData['transaction_id'] ??
                giftData['gift_history_id'] ??
                giftData['request_id'] ??
                giftData['client_event_id'] ??
                giftData['client_request_id'] ??
                giftData['timestamp'] ??
                '')
            .toString()
            .trim();
    final String duplicateEventKey =
        rawServerEventId.isNotEmpty && rawServerEventId != 'null'
        ? '${shortDuplicateKey}_$rawServerEventId'
        : shortDuplicateKey;
    final int lastMs = _recentGiftEventMs[duplicateEventKey] ?? 0;

    final bool forceShowGift =
        giftData['force_show'] == true || giftData['client_optimistic'] == true;

    /// Distinct server event ids are always accepted. When an old backend does
    /// not send an id, only a tiny 120ms duplicate window is used; the previous
    /// 800ms guard incorrectly deleted legitimate rapid Combo gifts.
    if (!animationOnly && !forceShowGift && nowMs - lastMs < 120) {
      liveLog('ℹ️ Exact fast duplicate gift ignored => $duplicateEventKey');
      return;
    }

    if (!animationOnly) {
      _recentGiftEventMs[duplicateEventKey] = nowMs;

      if (_recentGiftEventMs.length > 80) {
        _recentGiftEventMs.remove(_recentGiftEventMs.keys.first);
      }
    }

    if (_optimisticGiftAnimationUntilMs.length > 80) {
      _optimisticGiftAnimationUntilMs.remove(
        _optimisticGiftAnimationUntilMs.keys.first,
      );
    }

    /// ✅ Unique event id, so same gift repeatedly can still show.
    final String eventId =
        '${shortDuplicateKey}_${DateTime.now().microsecondsSinceEpoch}';

    processedGiftIds.add(eventId);

    if (processedGiftIds.length > 100) {
      processedGiftIds.remove(processedGiftIds.first);
    }

    final sender = _normalizeGiftUser(
      data: giftData,
      role: 'sender',
      fallbackId: senderId,
    );

    var receiver = _normalizeGiftUser(
      data: giftData,
      role: 'receiver',
      fallbackId: receiverId,
    );

    if ((_toInt(receiver['id'] ?? receiver['user_id']) <= 0 ||
            !_giftValueOk(receiver['profile_image'])) &&
        _toInt(receiverId) > 0 &&
        _toInt(receiverId) == _toInt(sender['id'] ?? sender['user_id'])) {
      receiver = Map<String, dynamic>.from(sender);
    }

    if (_toInt(receiver['id'] ?? receiver['user_id']) <= 0 ||
        !_giftValueOk(receiver['name']) ||
        !_giftValueOk(receiver['profile_image'])) {
      receiver = _mergeGiftUserMaps([
        _findLiveUserForGift(receiverId),
        receiver,
        {'id': receiverId, 'user_id': receiverId},
      ]);
    }

    final gift = _normalizeGiftAsset(giftData);

    if (isLuckyGiftPayload) {
      gift['is_lucky_gift'] = true;
      gift['category'] ??= 'Lucky';
    }

    final bool animationAssetReady =
        isLuckyGiftPayload || _normalGiftHasPlayableMedia(gift);

    /// Lucky animation target fix:
    /// For multi receiver gifts, backend may dispatch/confirm one event per receiver.
    /// We still keep the original selected receiver list only for animation targeting,
    /// so small gift particles can split into every selected receiver profile,
    /// including self-gift/profile.
    final List<int> animationReceiverIds = _giftReceiverIdsFromPayload(
      giftData,
      receiverId,
      allowReceiverList: true,
    );
    final List<int> animationReceiverSeatNos = <int>[];
    for (final int rid in animationReceiverIds) {
      final int seat = _giftSeatNoForUser(rid, giftData);
      if (seat > 0 && !animationReceiverSeatNos.contains(seat)) {
        animationReceiverSeatNos.add(seat);
      }
    }

    final Map<String, dynamic> normalizedAnimationData = {
      "sender": sender,
      "receiver": receiver,
      "gift": gift,
      "is_lucky_gift": isLuckyGiftPayload,
      "event_id": eventId,
      "animation_receiver_ids": animationReceiverIds,
      "receiver_ids_for_animation": animationReceiverIds,
      "all_receiver_ids": animationReceiverIds,
      "animation_receiver_seat_nos": animationReceiverSeatNos,
      "receiver_seats_for_animation": animationReceiverSeatNos,
      "multi_receiver_gift": animationReceiverIds.length > 1,
      "action_type": giftData['action_type'] ?? giftData['type'],
      "client_optimistic": giftData['client_optimistic'] == true,
      "optimistic_local": giftData['optimistic_local'] == true,
      "client_event_id": clientEventId,
      "client_request_id": giftData['client_request_id'] ?? clientEventId,
      "client_combo_serial": giftData['client_combo_serial'],
      "combo_serial": giftData['combo_serial'],
      "combo_count": giftData['combo_count'],
      "tap_serial": giftData['tap_serial'],
      "send_serial": giftData['send_serial'],
      "gift_animation_serial":
          giftData['gift_animation_serial'] ??
          giftData['animation_serial'] ??
          giftData['client_combo_serial'] ??
          giftData['combo_serial'],
      "source_event_id": rawServerEventId,
    };

    if (animationOnly) {
      /// Do not reserve/suppress the later confirmed WebSocket echo when the
      /// local optimistic object has no animation URL. The confirmed event can
      /// then play normally instead of being hidden behind an invisible item.
      if (!animationAssetReady) {
        liveLog(
          '⚡ Optimistic normal gift skipped: media not ready '
          '=> giftId=${gift['id'] ?? giftId}',
        );
        return;
      }

      _optimisticGiftAnimationUntilMs[shortDuplicateKey] = nowMs + 30000;
      if (clientEventId.isNotEmpty) {
        _optimisticClientEventUntilMs[clientEventId] = nowMs + 30000;
      }
      if (isLuckyGiftPayload) {
        _optimisticGiftAnimationUntilMs[luckySenderGiftKey] = nowMs + 30000;
      }
      _optimisticGiftEchoCredits[shortDuplicateKey] =
          (_optimisticGiftEchoCredits[shortDuplicateKey] ?? 0) + 1;

      normalizedAnimationData['timestamp'] = DateTime.now().toIso8601String();
      normalizedAnimationData['quantity'] = _toInt(
        giftData['quantity'] ?? giftData['gift_quantity'] ?? 1,
      ).clamp(1, 100);

      _enqueueGiftAnimation(normalizedAnimationData);
      return;
    }

    /// If the sender already started this exact animation locally, keep it
    /// running. The confirmed WebSocket event may still update data/coins below,
    /// but it must not restart or cut the SVGA.
    if (!suppressConfirmedEchoAnimation && animationAssetReady) {
      normalizedAnimationData['timestamp'] = DateTime.now().toIso8601String();
      normalizedAnimationData['quantity'] = _toInt(
        giftData['quantity'] ?? giftData['gift_quantity'] ?? 1,
      ).clamp(1, 100);
      _enqueueGiftAnimation(normalizedAnimationData);
    } else if (!suppressConfirmedEchoAnimation && !animationAssetReady) {
      liveLog(
        '⚡ Confirmed normal gift had no playable media; '
        'timeline/coins kept, animation skipped',
      );
    }

    _printGiftOnlyLog(
      giftData: giftData,
      sender: sender,
      receiver: receiver,
      gift: gift,
    );

    final giftMessage = {
      'type': 'gift',
      'livestream_id': livestreamId,
      'event_id': eventId,
      'user': sender,
      'sender': sender,
      'receiver': receiver,
      'gift': gift,
      'comment':
          '${sender['name'] ?? 'User'} sent ${gift['name'] ?? 'Gift'} to ${receiver['name'] ?? 'User'}',
      'timestamp': DateTime.now().toIso8601String(),
    };

    // Normal gifts always appear in the live Gift/All timeline. Lucky gifts
    // are intentionally hidden here; only a confirmed WIN result is allowed
    // to create one timeline card inside _handleLuckyGiftResult(). This avoids
    // 50 rapid Lucky taps rebuilding and auto-scrolling the comment list.
    if (!isLuckyGiftPayload) {
      _queueGiftTimelineRow(Map<String, dynamic>.from(giftMessage));
    }

    final Map<String, dynamic> luckyResultForCoin = _mapFrom(
      giftData['lucky_result'],
    );
    final coinValue = _toInt(
      gift['coin'] ??
          gift['coins'] ??
          giftData['gift_coin'] ??
          giftData['gift_price'] ??
          giftData['coin'] ??
          giftData['coins'] ??
          luckyResultForCoin['gift_coin'] ??
          luckyResultForCoin['gift_cost'],
    );

    if (coinValue > 0) {
      final bool hasAuthoritativeTotal = _payloadHasAuthoritativeGiftTotal(
        giftData,
      );

      /// If backend already sends stream_coins/total_gift_coins/received_coins,
      /// do NOT add locally first. Otherwise UI jumps 22560 -> 14520.
      if (!hasAuthoritativeTotal) {
        totalGiftCoins.value += coinValue;
      } else {}

      /// ✅ Coin update must be receiver-wise, not multiplied by selected count.
      /// After optimistic expansion each recursive item has one receiver_id,
      /// so every seat receives exactly gift price once.
      final bool optimizedLuckyBatch =
          isLuckyGiftPayload &&
          (giftData['optimized_lucky_batch'] == true ||
              giftData['optimized_lucky_batch']?.toString() == '1' ||
              giftData['animate_once'] == true);

      final List<int> receiverIdsForCoin = _giftReceiverIdsFromPayload(
        giftData,
        receiverId,
        allowReceiverList: optimizedLuckyBatch,
      );
      _addReceiverGiftCoins(
        receiverIds: receiverIdsForCoin.isNotEmpty
            ? receiverIdsForCoin
            : [_toInt(receiverId)],
        coinValue: coinValue,
      );

      try {
        final currentUser = authController.userProfile.value.user;
        final currentUserId = currentUser?.id?.toInt() ?? 0;
        final int receiverInt = _toInt(receiverId);

        if (currentUser != null &&
            currentUserId > 0 &&
            (receiverInt == currentUserId ||
                livestreamController.isBroadcaster.value)) {
          final oldEarned = _toInt(currentUser.earnedCoins);

          /// ✅ copyWith nai, tai direct user model update
          currentUser.earnedCoins = (oldEarned + coinValue).toString();

          authController.userProfile.refresh();
        }
      } catch (e) {
        liveLog('⚠️ Local earned coin update skipped => $e');
      }
    }

    syncGiftCoinsFromPayload(giftData, source: 'gift_event');

    try {
      livestreamController.syncLiveGiftCoinsFromPayload(
        giftData,
        source: 'gift_event',
      );
    } catch (_) {}

    /// Slow network refresh must not delay the animation/seat coin UI.
    /// Refresh later only for backend-confirmed final totals.
    _scheduleGiftTotalsRefresh();

    /// ✅ Smooth animation control.
    /// Duplicate backend event ignored above, so animation cut/cut hobe na.
    /// Fixed 5 seconds timer removed.
    /// GiftAnimationWidget er SVGA onFinished callback theke hideGiftAnimation() call hobe.
    if (suppressConfirmedEchoAnimation) {
      return;
    }

    /// Non-suppressed animations were already queued above. The current
    /// GiftAnimationWidget will mount the next item after its own completion.
  }

  Map<String, dynamic>? _extractCallerUserFromPayload(
    Map<String, dynamic> payload,
    Map<String, dynamic> callData,
  ) {
    bool looksLikeUser(Map data) {
      return data['name'] != null ||
          data['profile_image'] != null ||
          data['level'] != null ||
          data['user_id'] != null;
    }

    Map<String, dynamic>? asUser(dynamic value) {
      if (value is! Map) return null;

      final map = Map<String, dynamic>.from(value);

      if (map['user'] is Map) {
        return Map<String, dynamic>.from(map['user']);
      }

      if (map['caller_user'] is Map) {
        return Map<String, dynamic>.from(map['caller_user']);
      }

      if (map['caller_info'] is Map) {
        return Map<String, dynamic>.from(map['caller_info']);
      }

      if (map['sender'] is Map) {
        return Map<String, dynamic>.from(map['sender']);
      }

      if (map['from_user'] is Map) {
        return Map<String, dynamic>.from(map['from_user']);
      }

      if (looksLikeUser(map)) {
        return map;
      }

      return null;
    }

    final candidates = [
      callData['user'],
      callData['caller_user'],
      callData['caller_info'],
      callData['caller'],
      callData['caller_data'],
      payload['user'],
      payload['caller_user'],
      payload['caller_info'],
      payload['caller'],
      payload['caller_data'],
      payload['sender'],
      payload['from_user'],
      payload['data'],
      payload['call_data'],
      payload['livestream_call'],
      payload['live_call'],
      payload['call'],
    ];

    for (final candidate in candidates) {
      final user = asUser(candidate);
      if (user != null) return user;
    }

    return null;
  }
}
