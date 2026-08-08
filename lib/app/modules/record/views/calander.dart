import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:meetlivepro/app/modules/appmenu/views/widgets/imageColor.dart';

import '../controllers/record_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class DiamondLogPage extends StatefulWidget {
  @override
  _DiamondLogPageState createState() => _DiamondLogPageState();
}

class _DiamondLogPageState extends State<DiamondLogPage> {
  DateTime fromDate = DateTime(2025, 10, 1);
  DateTime toDate = DateTime(2025, 10, 31);

  Future<void> _selectDate(BuildContext context, bool isFrom) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? fromDate : toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          fromDate = picked;
        } else {
          toDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final recordController = Get.find<RecordController>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 Date pickers
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildDatePicker(
                    "From", fromDate, () => _selectDate(context, true)),
                _buildDatePicker(
                    "To", toDate, () => _selectDate(context, false)),
              ],
            ),
            const SizedBox(height: 10),

            // 🔹 Table header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children:  [
                  Expanded(
                      child: Text(("Date").appTr,
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(
                      child: Text(("Duration").appTr,
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(
                      child: Text(("Gift").appTr,
                          style: TextStyle(fontWeight: FontWeight.bold))),
                ],
              ),
            ),

            // 🔹 Data List (Now flush with top)
            Expanded(
              child: Obx(() {
                final data = recordController.filteredSessionWiseLiveRecord;

                if (data.isEmpty) {
                  return  Center(child: Text(("No records found").appTr));
                }

                return ListView.builder(
                  padding: EdgeInsets.zero, // removes default ListView padding
                  itemCount: data.length,
                  itemBuilder: (context, index) {
                    final item = data[index];
                    final date = item['live_end_time'] ?? '';
                    final gift = item['gift_amount'] ?? '0.00';
                    final durationInSeconds = item['livestream_duration'] ?? 0;

                    // 🔹 Convert seconds → hours, minutes, seconds
                    final hours = durationInSeconds ~/ 3600;
                    final minutes = (durationInSeconds % 3600) ~/ 60;
                    final seconds = durationInSeconds % 60;

                    // 🔹 Format: e.g. "1H 23M 15S" or "12M 5S"
                    String formattedDuration = '';
                    if (hours > 0) {
                      formattedDuration = '${hours}H ${minutes}M';
                    } else if (minutes > 0) {
                      formattedDuration = '${minutes}M ${seconds}S';
                    } else {
                      formattedDuration = '${seconds}S';
                    }

                    return _buildRow(date, formattedDuration, gift);
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker(String label, DateTime date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          gradient: const LinearGradient(
            colors: [
             kAppColor2,kAppColor1


            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Row(
          children: [
            Text(
              DateFormat('yyyy-MM-dd').format(date),
              style: const TextStyle(color: Colors.white),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String date, String duration, String gift) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Expanded(child: Text(date)),
          Expanded(child: Text(duration)),
          Expanded(child: Text(gift)),
        ],
      ),
    );
  }
}
