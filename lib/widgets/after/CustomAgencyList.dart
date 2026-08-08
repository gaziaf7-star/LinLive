import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomAgencyList extends StatelessWidget {
  final IconData leading;
  final IconData? trailing;
  final String text;
  final VoidCallback? onTap;
  final int? badgeCount; // Badge count
  final List<dynamic>? requestList; // Request list to filter pending

  const CustomAgencyList({
    super.key,
    required this.leading,
    this.trailing,
    required this.text,
    this.onTap,
    this.badgeCount,
    this.requestList,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate pending count from requestList if provided
    int displayCount = badgeCount ?? 0;

    if (requestList != null) {
      displayCount =
          requestList!.where((item) => item['status'] == 'Pending').length;
    }

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            leading,
            color: Colors.blueAccent,
          ),
          title: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 15,
              color: Colors.black.withOpacity(0.5),
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Badge with count
              if (displayCount > 0)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: displayCount > 9 ? 6 : 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    displayCount > 99 ? '99+' : displayCount.toString(),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              SizedBox(width: 8),
              // Arrow icon
              Icon(
                trailing ?? Icons.arrow_forward_ios_rounded,
                color: Colors.black.withOpacity(0.5),
                size: 15,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
