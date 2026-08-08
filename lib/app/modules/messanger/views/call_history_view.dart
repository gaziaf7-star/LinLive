import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../controllers/call_history_controller.dart';

class CallHistoryView extends GetView {
  CallHistoryView({Key? key}) : super(key: key);
  final CallHistoryController _callHistoryController =
      Get.put(CallHistoryController());

  @override
  Widget build(BuildContext context) {
    Future.delayed(Duration.zero, () {
      _callHistoryController.loadCallHistoryList();
    });

    return Scaffold(
      // backgroundColor: Colors.purple.shade100,
      body: Obx(() {
        if (_callHistoryController.callHistoryLoading.value) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  "images/default/shokh_live_logo_loading.png",
                  height: 65,
                ),
                const SpinKitThreeInOut(
                  color: Colors.blueAccent,
                  size: 45,
                )
              ],
            ),
          );
        }
        return ListView.separated(
          physics: const BouncingScrollPhysics(),
          itemCount: _callHistoryController.callHistories.length,
          itemBuilder: (context, index) {
            dynamic callHistory = _callHistoryController.callHistories[index];
            IconData iconData;
            Color color = Colors.green;
            if (callHistory['is_outgoing_call'] == true) {
              iconData = Icons.phone_forwarded_outlined;
              color = Colors.grey;
            } else if (callHistory['is_missed_call'] == true) {
              iconData = Icons.phone_missed_outlined;
              color = Colors.red;
            } else {
              // Incoming call
              iconData = Icons.phone_callback_outlined;
            }

            return ListTile(
              horizontalTitleGap: 0.0,
              leading: Icon(
                iconData,
                color: color,
              ),
              title: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(50.0),
                    child: Image.asset(
                      'images/default/profile.jpg',
                      width: 46,
                      height: 46,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        callHistory['peer_user_profile']['full_name'],
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        timeago.format(
                            DateTime.parse(callHistory['datetime']).toLocal()),
                        // '${DateFormat.yMMMEd().format(DateTime.parse(callHistory['datetime']).toLocal())}, ${DateFormat.jm().format(DateTime.parse(callHistory['datetime']).toLocal())}',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              trailing: Icon(
                callHistory['call_type'] == 'audio'
                    ? Icons.call
                    : Icons.video_call,
                color: Colors.blue,
              ),
              // trailing: Column(
              //   mainAxisAlignment: MainAxisAlignment.center,
              //   crossAxisAlignment: CrossAxisAlignment.center,
              //   children: [
              //     Text(
              //       DateFormat.yMMMEd().format(
              //           DateTime.parse(callHistory['datetime']).toLocal()),
              //       style: const TextStyle(
              //         color: Colors.white,
              //         fontSize: 12,
              //         fontWeight: FontWeight.w500,
              //       ),
              //     ),
              //     Text(
              //       DateFormat.jms().format(
              //           DateTime.parse(callHistory['datetime']).toLocal()),
              //       style: const TextStyle(
              //         color: Colors.white,
              //         fontSize: 12,
              //         fontWeight: FontWeight.w500,
              //       ),
              //     ),
              //   ],
              // ),
            );
          },
          separatorBuilder: (BuildContext context, int index) {
            return Container(
              height: 1,
              color: Colors.grey.shade300,
            );
          },
        );
      }),
    );
  }
}
