import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../constants/layout_constant.dart';
import '../controllers/livestream_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class RoomExtensionDialog extends StatefulWidget {
  final int currentSeatCount;
  final String livestreamId;

  const RoomExtensionDialog({
    Key? key,
    required this.currentSeatCount,
    required this.livestreamId,
  }) : super(key: key);

  @override
  State<RoomExtensionDialog> createState() => _RoomExtensionDialogState();
}

class _RoomExtensionDialogState extends State<RoomExtensionDialog> {
  int selectedSeatCount = 6;
  bool isCustom = false;
  final TextEditingController customSeatController = TextEditingController();
  final LivestreamController livestreamController = Get.find<LivestreamController>();

  @override
  void initState() {
    super.initState();
    // Set default to next available option
    if (widget.currentSeatCount >= 12) {
      selectedSeatCount = widget.currentSeatCount + 4;
      isCustom = true;
      customSeatController.text = selectedSeatCount.toString();
    } else if (widget.currentSeatCount >= 8) {
      selectedSeatCount = 12;
    } else if (widget.currentSeatCount >= 6) {
      selectedSeatCount = 8;
    } else {
      selectedSeatCount = 6;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: kHeight * 0.03,
        horizontal: kWeight * 0.05,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xffad77e6), width: 2),
        ),
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            Color(0xff1a0c2d),
            Color(0xff5e07b8),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      width: double.infinity,
      height: kHeight * 0.5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                ('Room Extension').appTr,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                onPressed: () => Get.back(),
                icon: Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),
          
          SizedBox(height: kHeight * 0.02),
          
          // Current seat info
          Container(
            padding: EdgeInsets.all(kWeight * 0.03),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Color(0xffad77e6),
                  size: 20,
                ),
                SizedBox(width: kWeight * 0.02),
                Text(
                  ('Current seats: ${widget.currentSeatCount}').appTr,
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(height: kHeight * 0.03),
          
          // Seat selection options
          Text(
            ('Select new seat count:').appTr,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          
          SizedBox(height: kHeight * 0.02),
          
          // Preset options
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (widget.currentSeatCount < 6)
                _buildSeatOption(6),
              if (widget.currentSeatCount < 8)
                _buildSeatOption(8),
              if (widget.currentSeatCount < 12)
                _buildSeatOption(12),
              _buildCustomOption(),
            ],
          ),
          
          // Custom input field
          if (isCustom) ...[
            SizedBox(height: kHeight * 0.02),
            TextField(
              controller: customSeatController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: ('Custom seat count').appTr,
                labelStyle: TextStyle(color: Colors.white70),
                hintText: ('Enter number (max 50)').appTr,
                hintStyle: TextStyle(color: Colors.white54),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Color(0xffad77e6)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Color(0xffad77e6)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Color(0xffad77e6), width: 2),
                ),
              ),
              onChanged: (value) {
                final intValue = int.tryParse(value);
                if (intValue != null && intValue > widget.currentSeatCount) {
                  selectedSeatCount = intValue;
                }
              },
            ),
          ],
          
          Spacer(),
          
          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Get.back(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.withOpacity(0.3),
                    padding: EdgeInsets.symmetric(vertical: kHeight * 0.015),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    ('Cancel').appTr,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              SizedBox(width: kWeight * 0.03),
              Expanded(
                child: ElevatedButton(
                  onPressed: _canExtend() ? _extendRoom : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _canExtend() 
                        ? Color(0xffad77e6) 
                        : Colors.grey.withOpacity(0.3),
                    padding: EdgeInsets.symmetric(vertical: kHeight * 0.015),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    ('Extend Room').appTr,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSeatOption(int seatCount) {
    final isSelected = selectedSeatCount == seatCount && !isCustom;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedSeatCount = seatCount;
          isCustom = false;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: kWeight * 0.04,
          vertical: kHeight * 0.015,
        ),
        decoration: BoxDecoration(
          color: isSelected 
              ? Color(0xffad77e6) 
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected 
                ? Color(0xffad77e6) 
                : Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Text(
          '$seatCount',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 16,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildCustomOption() {
    return GestureDetector(
      onTap: () {
        setState(() {
          isCustom = true;
          if (customSeatController.text.isEmpty) {
            customSeatController.text = (widget.currentSeatCount + 4).toString();
            selectedSeatCount = widget.currentSeatCount + 4;
          }
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: kWeight * 0.04,
          vertical: kHeight * 0.015,
        ),
        decoration: BoxDecoration(
          color: isCustom 
              ? Color(0xffad77e6) 
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isCustom 
                ? Color(0xffad77e6) 
                : Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Text(
          ('Custom').appTr,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 16,
            fontWeight: isCustom ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  bool _canExtend() {
    if (isCustom) {
      final customValue = int.tryParse(customSeatController.text);
      return customValue != null && 
             customValue > widget.currentSeatCount && 
             customValue <= 50;
    }
    return selectedSeatCount > widget.currentSeatCount;
  }

  void _extendRoom() async {
    try {
      final newSeatCount = isCustom 
          ? int.parse(customSeatController.text) 
          : selectedSeatCount;
      
      await livestreamController.extendRoom(widget.livestreamId, newSeatCount);
      
      Get.back();
      
      Get.snackbar(
        ('Success').appTr,
        ('Room extended to $newSeatCount seats successfully!').appTr,
        backgroundColor: Colors.green.withOpacity(0.8),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
    } catch (e) {
      Get.snackbar(
        ('Error').appTr,
        ('Failed to extend room: ${e.toString()}').appTr,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
    }
  }

  @override
  void dispose() {
    customSeatController.dispose();
    super.dispose();
  }
}
