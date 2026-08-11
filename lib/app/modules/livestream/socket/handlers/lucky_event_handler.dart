part of '../websocket_controller.dart';

extension LuckyEventHandler on WebsocketController {
  void _handleLuckyGiftResult(Map<String, dynamic> payload) {
    try {
      _forceGiftPrint('🍀 LUCKY GIFT RESULT RAW PAYLOAD', payload);

      final Map<String, dynamic> data = payload['data'] is Map
          ? Map<String, dynamic>.from(payload['data'])
          : Map<String, dynamic>.from(payload);

      final livestreamId =
          data['livestream_id'] ??
          data['stream_id'] ??
          payload['livestream_id'] ??
          payload['stream_id'];

      _forceGiftPrint('🍀 LUCKY GIFT RESULT ROOT PARSED', {
        'resolved_livestream_id': livestreamId,
        'is_current_stream': livestreamId == null
            ? true
            : _isCurrentStream(livestreamId),
        'root_payload': payload,
        'parsed_data': data,
      });

      if (livestreamId != null && !_isCurrentStream(livestreamId)) {
        liveLog('⛔ Lucky gift ignored: not current stream => $livestreamId');
        return;
      }

      int luckyInt(dynamic value, {int fallback = 0}) {
        if (value == null) return fallback;
        if (value is int) return value;
        if (value is double) return value.toInt();
        return int.tryParse(value.toString()) ?? fallback;
      }

      double luckyDouble(dynamic value, {double fallback = 0}) {
        if (value == null) return fallback;
        if (value is double) return value;
        if (value is int) return value.toDouble();
        return double.tryParse(value.toString()) ?? fallback;
      }

      bool truthy(dynamic value) {
        final v = value?.toString().toLowerCase().trim() ?? '';
        return value == true ||
            v == '1' ||
            v == 'true' ||
            v == 'yes' ||
            v == 'win';
      }

      Map<String, dynamic> toMap(dynamic value) {
        if (value is Map<String, dynamic>) return value;
        if (value is Map) return Map<String, dynamic>.from(value);
        return <String, dynamic>{};
      }

      final sender = data['sender'] is Map
          ? toMap(data['sender'])
          : data['user'] is Map
          ? toMap(data['user'])
          : data['sender_user'] is Map
          ? toMap(data['sender_user'])
          : <String, dynamic>{
              'id': data['sender_id'] ?? data['user_id'],
              'name': data['sender_name'] ?? data['name'] ?? 'User',
              'profile_image':
                  data['sender_profile_image'] ?? data['profile_image'],
              'level': data['sender_level'] ?? data['level'] ?? 0,
            };

      final gift = data['gift'] is Map
          ? toMap(data['gift'])
          : data['gift_data'] is Map
          ? toMap(data['gift_data'])
          : <String, dynamic>{
              'id': data['gift_id'],
              'name': data['gift_name'] ?? 'Lucky Gift',
              'coin': data['gift_coin'] ?? data['coin'] ?? data['coins'],
              'image': data['gift_image'] ?? data['image'],
              'gift_image': data['gift_image'] ?? data['image'],
              'show_image': data['show_image'],
              'category': 'Lucky',
            };

      // Always mark the gift object itself, so GiftAnimationWidget can
      // reliably render Lucky gifts at 100x100 instead of full screen.
      gift['is_lucky_gift'] = true;
      gift['category'] ??= 'Lucky';

      final List luckyResults = <dynamic>[];
      void addLuckyResultList(dynamic value) {
        if (value is List) luckyResults.addAll(value);
      }

      addLuckyResultList(data['big_win_events'] ?? payload['big_win_events']);
      addLuckyResultList(data['lucky_results'] ?? payload['lucky_results']);
      addLuckyResultList(data['result'] ?? payload['result']);

      final Map<String, dynamic> luckyResult = data['lucky_result'] is Map
          ? toMap(data['lucky_result'])
          : payload['lucky_result'] is Map
          ? toMap(payload['lucky_result'])
          : <String, dynamic>{};

      _forceGiftPrint('🍀 LUCKY SENDER GIFT RESULT PARTS', {
        'sender': sender,
        'receiver': data['receiver'],
        'gift': gift,
        'lucky_results': luckyResults,
        'big_win_events': data['big_win_events'] ?? payload['big_win_events'],
        'lucky_result': luckyResult,
        'direct_multiplier': data['multiplier'],
        'direct_win_amount': data['win_amount'],
        'direct_back_coin': data['back_coin'],
        'direct_win_coin': data['win_coin'],
        'direct_is_win': data['is_win'],
      });

      final bool hasActualLuckyResult =
          luckyResults.isNotEmpty ||
          luckyResult.isNotEmpty ||
          data['multiplier'] != null ||
          data['win_amount'] != null ||
          data['back_coin'] != null ||
          data['win_coin'] != null;

      if (!hasActualLuckyResult) {
        liveLog(
          '🍀 Lucky result skipped: no multiplier/win_amount/lucky_results found',
        );
        return;
      }

      /// Keep the running Lucky gift animation alive.
      /// Result data will be merged into the same GiftAnimationWidget below,
      /// so the image never restarts/cuts when lucky_gift_result arrives.
      try {
        final current = giftsData.isNotEmpty
            ? Map<String, dynamic>.from(giftsData)
            : <String, dynamic>{};
        final currentGift = _mapFrom(current['gift']);

        giftsData.value = {
          ...current,
          'sender': current['sender'] is Map ? current['sender'] : sender,
          'receiver': current['receiver'] is Map
              ? current['receiver']
              : (data['receiver'] is Map
                    ? toMap(data['receiver'])
                    : <String, dynamic>{}),
          'gift': {
            ...gift,
            ...currentGift,
            'is_lucky_gift': true,
            'category': 'Lucky',
          },
          'is_lucky_gift': true,
        };
        giftsData.refresh();
        if (!isGiftAnimationShowing.value) {
          isGiftAnimationShowing.value = true;
        }
      } catch (e) {
        liveLog('⚠️ Lucky normal gift animation merge failed => $e');
      }

      final List<Map<String, dynamic>> normalizedResults = [];

      if (luckyResults.isNotEmpty) {
        for (final item in luckyResults) {
          if (item is Map) {
            normalizedResults.add(Map<String, dynamic>.from(item));
          }
        }
      } else if (luckyResult.isNotEmpty) {
        normalizedResults.add(luckyResult);
      } else {
        normalizedResults.add(<String, dynamic>{
          'is_win':
              data['is_win'] ??
              data['is_win_lucky'] ??
              (luckyInt(
                    data['win_amount'] ?? data['back_coin'] ?? data['win_coin'],
                  ) >
                  0),
          'win_type': data['win_type'],
          'win_amount':
              data['win_amount'] ??
              data['back_coin'] ??
              data['win_coin'] ??
              data['bonus_coin'],
          'back_coin': data['back_coin'] ?? data['win_coin'],
          'win_coin': data['win_coin'] ?? data['back_coin'],
          'multiplier':
              data['multiplier'] ??
              data['multiple'] ??
              data['x'] ??
              data['gun'],
          'gift_coin': data['gift_coin'] ?? gift['coin'],
        });
      }

      _forceGiftPrint('🍀 LUCKY NORMALIZED RESULTS BEFORE TARGET RESOLVE', {
        'normalized_results': normalizedResults,
        'current_gifts_data_before_result': giftsData,
        'is_gift_animation_showing': isGiftAnimationShowing.value,
      });

      /// Audience-side lucky gift target fix:
      /// Lucky result websocket can arrive without the original selected
      /// receiver list. Sender device already has selected receiver ids, but
      /// audience devices may only get lucky_results. Normalize receiver ids and
      /// seat numbers here so GiftAnimationWidget can send particles to every
      /// selected receiver seat on every device.
      List<int> _luckyTargetsFromAny(dynamic value, {bool seat = false}) {
        final result = <int>[];
        final seen = <int>{};

        void addOne(dynamic raw) {
          if (raw == null) return;

          if (raw is Iterable) {
            for (final item in raw) addOne(item);
            return;
          }

          if (raw is Map) {
            final map = Map<String, dynamic>.from(raw);
            final keys = seat
                ? <String>[
                    'seat_no',
                    'seat',
                    'seat_number',
                    'receiver_seat_no',
                    'receiver_seat',
                    'receiver_seat_number',
                    'to_seat_no',
                    'target_seat_no',
                  ]
                : <String>[
                    'receiver_id',
                    'receiver_user_id',
                    'to_user_id',
                    'target_user_id',
                    'winner_user_id',
                    'user_id',
                    'id',
                  ];
            for (final key in keys) addOne(map[key]);
            addOne(map['receiver']);
            addOne(map['receiver_user']);
            addOne(map['to_user']);
            addOne(map['target_user']);
            addOne(map['winner']);
            return;
          }

          final text = raw.toString().trim();
          if (text.isEmpty || text.toLowerCase() == 'null') return;
          if (text.contains(',')) {
            for (final part in text.split(',')) addOne(part);
            return;
          }
          final id = _toInt(text);
          if (id > 0 && seen.add(id)) result.add(id);
        }

        addOne(value);
        return result;
      }

      final List<int> luckyAnimationReceiverIds = <int>[];
      void _addLuckyReceiverIds(dynamic value, {dynamic single}) {
        final extracted = _giftReceiverIdsFromPayload(
          value is Map<String, dynamic>
              ? value
              : value is Map
              ? Map<String, dynamic>.from(value)
              : <String, dynamic>{},
          single,
          allowReceiverList: true,
        );
        for (final id in extracted) {
          if (id > 0 && !luckyAnimationReceiverIds.contains(id)) {
            luckyAnimationReceiverIds.add(id);
          }
        }
        for (final id in _luckyTargetsFromAny(value)) {
          if (id > 0 && !luckyAnimationReceiverIds.contains(id)) {
            luckyAnimationReceiverIds.add(id);
          }
        }
      }

      _addLuckyReceiverIds(
        data,
        single: data['receiver_id'] ?? data['to_user_id'],
      );
      _addLuckyReceiverIds(
        payload,
        single: payload['receiver_id'] ?? payload['to_user_id'],
      );
      _addLuckyReceiverIds(
        luckyResult,
        single: luckyResult['receiver_id'] ?? luckyResult['to_user_id'],
      );
      for (final item in luckyResults) {
        _addLuckyReceiverIds(
          item,
          single: item is Map
              ? (item['receiver_id'] ?? item['to_user_id'] ?? item['user_id'])
              : null,
        );
      }

      try {
        final current = giftsData.isNotEmpty
            ? Map<String, dynamic>.from(giftsData)
            : <String, dynamic>{};
        _addLuckyReceiverIds(
          current,
          single: current['receiver_id'] ?? current['to_user_id'],
        );
        final existingIds =
            current['animation_receiver_ids'] ??
            current['receiver_ids_for_animation'] ??
            current['all_receiver_ids'];
        for (final id in _luckyTargetsFromAny(existingIds)) {
          if (id > 0 && !luckyAnimationReceiverIds.contains(id)) {
            luckyAnimationReceiverIds.add(id);
          }
        }
      } catch (_) {}

      final List<int> luckyAnimationSeatNos = <int>[];
      void _addLuckySeatNos(dynamic value) {
        for (final seat in _luckyTargetsFromAny(value, seat: true)) {
          if (seat > 0 && !luckyAnimationSeatNos.contains(seat)) {
            luckyAnimationSeatNos.add(seat);
          }
        }
      }

      _addLuckySeatNos(data['animation_receiver_seat_nos']);
      _addLuckySeatNos(data['receiver_seats_for_animation']);
      _addLuckySeatNos(data['receiver_seat_nos']);
      _addLuckySeatNos(data['receiver_seats']);
      _addLuckySeatNos(data['receiver_seat_no']);
      _addLuckySeatNos(data['seat_no']);
      _addLuckySeatNos(payload['animation_receiver_seat_nos']);
      _addLuckySeatNos(payload['receiver_seats_for_animation']);
      _addLuckySeatNos(payload['receiver_seat_nos']);
      _addLuckySeatNos(payload['receiver_seat_no']);
      _addLuckySeatNos(luckyResult);
      for (final item in luckyResults) _addLuckySeatNos(item);

      for (final int rid in luckyAnimationReceiverIds) {
        final seatNo = _giftSeatNoForUser(rid, data);
        if (seatNo > 0 && !luckyAnimationSeatNos.contains(seatNo)) {
          luckyAnimationSeatNos.add(seatNo);
        }
      }

      _forceGiftPrint('🍀 LUCKY ANIMATION TARGETS RESOLVED', {
        'receiver_ids': luckyAnimationReceiverIds,
        'receiver_seat_nos': luckyAnimationSeatNos,
        'current_live_call_list': liveCallList.toList(),
        'current_gifts_data': giftsData,
      });

      final String baseEventId =
          (data['event_id'] ??
                  data['lucky_event_id'] ??
                  '${data['action_type'] ?? 'lucky'}_${livestreamId}_${sender['id']}_${gift['id']}_${data['timestamp'] ?? DateTime.now().millisecondsSinceEpoch}')
              .toString();

      /// Prefix with action type so gift_sent and lucky_gift_result do not block each other.
      final String eventId =
          'lucky_${data['action_type'] ?? 'result'}_$baseEventId';

      if (processedGiftIds.contains(eventId)) {
        liveLog('ℹ️ Duplicate lucky gift result skipped: $eventId');
        return;
      }

      processedGiftIds.add(eventId);
      if (processedGiftIds.length > 120) {
        processedGiftIds.remove(processedGiftIds.first);
      }

      final List<Map<String, dynamic>> commentsToAdd = [];
      Map<String, dynamic>? bestResult;

      for (final result in normalizedResults) {
        final int parsedWinAmount = luckyInt(
          result['win_amount'] ??
              result['back_coin'] ??
              result['win_coin'] ??
              data['win_amount'] ??
              data['back_coin'] ??
              data['win_coin'],
        );

        final double multiplier = luckyDouble(
          result['multiplier'] ??
              result['multiple'] ??
              result['x'] ??
              data['multiplier'] ??
              data['multiple'] ??
              data['x'],
        );

        final bool isWin =
            truthy(result['is_win']) ||
            truthy(data['is_win']) ||
            parsedWinAmount > 0 ||
            multiplier > 0;

        final String winType =
            (result['win_type'] ??
                    data['win_type'] ??
                    (multiplier >= 100 || parsedWinAmount >= 10000
                        ? 'jackpot'
                        : isWin
                        ? 'small_win'
                        : 'loss'))
                .toString()
                .toLowerCase();

        final bool isBigWin =
            winType.contains('big') ||
            winType.contains('jackpot') ||
            multiplier >= 100 ||
            parsedWinAmount >= 10000 ||
            data['is_big_win'] == true ||
            data['is_jackpot'] == true;

        final String senderName = (sender['name'] ?? 'User').toString();

        final String multiplierText = multiplier <= 0
            ? ''
            : multiplier % 1 == 0
            ? '${multiplier.toInt()} Times'
            : '${multiplier.toStringAsFixed(1)} Times';

        final String comment = isWin
            ? '$senderName won ${multiplierText.isEmpty ? '' : '$multiplierText '}+$parsedWinAmount coins 🎉'
            : '$senderName tried Lucky Gift. Better luck next time';

        final normalized = <String, dynamic>{
          ...data,
          ...result,
          'type': 'lucky_gift_card',
          'event_id': '${eventId}_${commentsToAdd.length}',
          'livestream_id': livestreamId,
          'user': sender,
          'sender': sender,
          'gift': gift,
          'comment': comment,
          'is_lucky_gift': true,
          'is_win': isWin,
          'win_amount': parsedWinAmount,
          'back_coin': parsedWinAmount,
          'win_coin': parsedWinAmount,
          'multiplier': multiplier,
          'win_type': winType,
          'is_big_win': isBigWin,
          'animation_receiver_ids': luckyAnimationReceiverIds,
          'receiver_ids_for_animation': luckyAnimationReceiverIds,
          'all_receiver_ids': luckyAnimationReceiverIds,
          'animation_receiver_seat_nos': luckyAnimationSeatNos,
          'receiver_seats_for_animation': luckyAnimationSeatNos,
          'multi_receiver_gift':
              luckyAnimationReceiverIds.length > 1 ||
              luckyAnimationSeatNos.length > 1,
          'timestamp': data['timestamp'] ?? DateTime.now().toIso8601String(),
        };

        _forceGiftPrint(
          '🍀 LUCKY SINGLE RESULT NORMALIZED #${commentsToAdd.length + 1}',
          {
            'source_result': result,
            'parsed_win_amount': parsedWinAmount,
            'parsed_multiplier': multiplier,
            'parsed_is_win': isWin,
            'parsed_win_type': winType,
            'parsed_is_big_win': isBigWin,
            'normalized_result': normalized,
          },
        );

        // Lucky loss/try rows must not enter live comments. A timeline card
        // is created only when the backend confirms an actual coin win.
        final bool shouldShowLuckyWinCard = isWin && parsedWinAmount > 0;
        if (shouldShowLuckyWinCard) {
          commentsToAdd.add(normalized);

          if (bestResult == null) {
            bestResult = normalized;
          } else {
            final oldAmount = luckyInt(bestResult['win_amount']);
            final oldMultiplier = luckyDouble(bestResult['multiplier']);

            if (isBigWin ||
                parsedWinAmount > oldAmount ||
                multiplier > oldMultiplier) {
              bestResult = normalized;
            }
          }
        }
      }

      _forceGiftPrint('🍀 LUCKY FINAL RESULT COLLECTION', {
        'all_normalized_results': commentsToAdd,
        'best_result': bestResult,
        'result_count': commentsToAdd.length,
      });

      // One Lucky result event creates at most one comment card. Even if the
      // payload contains several result representations, show only the best
      // confirmed win and never duplicate it across the timeline.
      if (bestResult != null) {
        _queueGiftTimelineRow(
          Map<String, dynamic>.from(bestResult),
          alsoAddToComments: true,
        );
      }

      if (bestResult != null) {
        try {
          final current = giftsData.isNotEmpty
              ? Map<String, dynamic>.from(giftsData)
              : <String, dynamic>{};
          final currentGift = _mapFrom(current['gift']);
          final resultGift = _mapFrom(bestResult['gift']);
          final int resultSerial = DateTime.now().microsecondsSinceEpoch;

          giftsData.value = {
            ...current,
            'sender': current['sender'] is Map
                ? current['sender']
                : bestResult['sender'],
            'receiver': current['receiver'] is Map
                ? current['receiver']
                : bestResult['receiver'],
            'gift': {
              ...resultGift,
              ...currentGift,
              'is_lucky_gift': true,
              'category': 'Lucky',
            },
            'is_lucky_gift': true,
            'is_win': bestResult['is_win'],
            'win_amount': bestResult['win_amount'],
            'back_coin': bestResult['back_coin'],
            'win_coin': bestResult['win_coin'],
            'multiplier': bestResult['multiplier'],
            'win_type': bestResult['win_type'],
            'is_big_win': bestResult['is_big_win'],
            'lucky_result': Map<String, dynamic>.from(bestResult),
            'animation_receiver_ids': luckyAnimationReceiverIds,
            'receiver_ids_for_animation': luckyAnimationReceiverIds,
            'all_receiver_ids': luckyAnimationReceiverIds,
            'animation_receiver_seat_nos': luckyAnimationSeatNos,
            'receiver_seats_for_animation': luckyAnimationSeatNos,
            'multi_receiver_gift':
                luckyAnimationReceiverIds.length > 1 ||
                luckyAnimationSeatNos.length > 1,
            'lucky_result_serial': resultSerial,
            'result_event_id': bestResult['event_id'],
          };
          giftsData.refresh();
          _forceGiftPrint('🍀 LUCKY FINAL GIFTS DATA BOUND TO ANIMATION', {
            'gifts_data': giftsData,
            'best_result': bestResult,
            'animation_receiver_ids': luckyAnimationReceiverIds,
            'animation_receiver_seat_nos': luckyAnimationSeatNos,
            'result_serial': resultSerial,
            'is_gift_animation_showing': isGiftAnimationShowing.value,
          });
          liveLog(
            '🍀 Lucky HUD bind => ${bestResult['multiplier']} Times coin:${bestResult['win_amount']} serial:$resultSerial',
          );

          if (!isGiftAnimationShowing.value) {
            isGiftAnimationShowing.value = true;
          }
        } catch (e) {
          liveLog('⚠️ Lucky badge/counter merge failed => $e');
        }

        try {
          final dynamic live = Get.find<LivestreamController>();

          try {
            live.showLuckyGiftVideoStyleResult(bestResult);
          } catch (_) {
            try {
              live.showLuckyGiftResult(bestResult);
            } catch (_) {}
          }
        } catch (e) {
          liveLog('⚠️ Lucky result controller show skipped => $e');
        }

        liveLog(
          '✅ Lucky gift result shown => win:${bestResult['is_win']} amount:${bestResult['win_amount']} multiplier:${bestResult['multiplier']} type:${bestResult['win_type']}',
        );
      }
    } catch (e, st) {
      liveLog('❌ _handleLuckyGiftResult error => $e\n$st\npayload=$payload');
    }
  }
}
