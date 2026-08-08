import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meetlivepro/app/modules/verified/views/verify_page_2.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../apis/api_endpoints.dart';
import '../../../../constants/constants.dart';
import '../../../../constants/layout_constant.dart';
import '../../../../widgets/after/CastomText.dart';
import '../../../../widgets/after/castom appbar.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class VerifyPage3 extends StatefulWidget {
  const VerifyPage3({super.key});

  @override
  State<VerifyPage3> createState() => _VerifyPage3State();
}

class _VerifyPage3State extends State<VerifyPage3> {
  Map<String, dynamic>? selectedAgency;
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();

    /// API call build-er vitore na rekhe initState e rakhlam.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      homeController.showingAgencyList();
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void _showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.black87,
      textColor: Colors.white,
      fontSize: 13,
    );
  }

  String _cleanImageUrl(dynamic imagePath) {
    final String path = imagePath?.toString() ?? '';
    if (path.isEmpty || path == 'null') return '';

    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }

    final String baseUrl = kDomainUrl.replaceAll(RegExp(r'/+$'), '');
    final String cleanPath = path.replaceAll(RegExp(r'^/+'), '');

    return '$baseUrl/$cleanPath';
  }

  void searchAgency(String value) {
    final String keyword = value.trim().toLowerCase();

    if (keyword.isEmpty) {
      setState(() => selectedAgency = null);
      return;
    }

    try {
      final agency = homeController.agencyList.firstWhere(
            (item) {
          final String agencyId = item['agency_id']?.toString().toLowerCase() ?? '';
          final String userId = item['user_id']?.toString().toLowerCase() ?? '';
          final String id = item['id']?.toString().toLowerCase() ?? '';
          final String name = item['name']?.toString().toLowerCase() ?? '';

          return agencyId.contains(keyword) ||
              userId.contains(keyword) ||
              id.contains(keyword) ||
              name.contains(keyword);
        },
      );

      setState(() {
        selectedAgency = Map<String, dynamic>.from(agency);
      });
    } catch (_) {
      setState(() => selectedAgency = null);
    }
  }

  void _goToHostApply(Map<String, dynamic> agencyData) {
    Get.to(
      const VerifyPage2(),
      arguments: agencyData,
      transition: Transition.rightToLeft,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: ('Host Verify').appTr,
      ),
      body: Column(
        children: [
          Container(
            margin: EdgeInsets.symmetric(
              horizontal: MediaQuery.of(context).size.width * 0.03,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(50),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: searchController,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.search,
              onChanged: searchAgency,
              decoration: InputDecoration(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: kHeight * 0.025,
                  vertical: kHeight * 0.012,
                ),
                hintText: ('Search by agency name or ID').appTr,
                hintStyle: TextStyle(
                  fontSize: kHeight * 0.014,
                  color: Colors.grey[600],
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Colors.grey,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(50),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              style: const TextStyle(fontSize: 16),
            ),
          ),

          if (selectedAgency != null)
            _agencyCard(
              context: context,
              agencyData: selectedAgency!,
              imageSize: 72,
              onTap: () => _goToHostApply(selectedAgency!),
            ),

          Expanded(
            child: Obx(
                  () {
                final agencyList = homeController.agencyList;

                if (agencyList.isEmpty) {
                  return _emptyOrLoadingView();
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    await homeController.showingAgencyList();
                  },
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: agencyList.length,
                    itemBuilder: (BuildContext context, int index) {
                      final Map<String, dynamic> agencyData =
                      Map<String, dynamic>.from(agencyList[index]);

                      return _agencyCard(
                        context: context,
                        agencyData: agencyData,
                        imageSize: 60,
                        onTap: () => _goToHostApply(agencyData),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyOrLoadingView() {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      itemCount: 5,
      itemBuilder: (_, __) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            height: 92,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.grey[300],
            ),
          ),
        );
      },
    );
  }

  Widget _agencyCard({
    required BuildContext context,
    required Map<String, dynamic> agencyData,
    required double imageSize,
    required VoidCallback onTap,
  }) {
    final String imageUrl = _cleanImageUrl(agencyData['profile_image']);
    final String agencyId =
        agencyData['agency_id']?.toString() ??
            agencyData['user_id']?.toString() ??
            agencyData['id']?.toString() ??
            'N/A';

    final String agencyName = agencyData['name']?.toString() ?? 'N/A';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.grey[100],
      ),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(14.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                _agencyAvatar(imageUrl, imageSize),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Castontext(
                        fontSize: Get.height * 0.016,
                        fontWeight: FontWeight.w600,
                        textColor: Colors.black.withOpacity(.65),
                        text: ('ID: $agencyId').appTr,
                      ),
                      const SizedBox(height: 5),
                      Castontext(
                        fontSize: Get.height * 0.015,
                        fontWeight: FontWeight.w400,
                        textColor: Colors.black.withOpacity(.65),
                        text: ('Name: $agencyName').appTr,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.045,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
              ),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xff8A4CF7),
                      Color(0xffB460F0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 18,
                  ),
                  child: Text(
                    ('Apply').appTr,
                    style: GoogleFonts.lato(
                      color: Colors.white,
                      fontSize: kHeight * 0.014,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _agencyAvatar(String imageUrl, double size) {
    if (imageUrl.isEmpty) {
      return _defaultAvatar(size);
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      imageBuilder: (context, imageProvider) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          image: DecorationImage(
            image: imageProvider,
            fit: BoxFit.cover,
          ),
        ),
      ),
      placeholder: (context, url) => Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: _defaultAvatar(size),
      ),
      errorWidget: (context, url, error) => _defaultAvatar(size),
    );
  }

  Widget _defaultAvatar(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.25),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.business_center_rounded,
        color: Colors.grey,
        size: size * 0.45,
      ),
    );
  }
}