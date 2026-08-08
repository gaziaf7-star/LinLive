import 'package:auto_size_text/auto_size_text.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../constants/image_helper.dart';
import '../../../../../constants/layout_constant.dart';
import '../../../home/controllers/home_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class FullGiftReceiverPage extends StatefulWidget {
  final List<dynamic> list;
  const FullGiftReceiverPage({super.key, required this.list});

  @override
  State<FullGiftReceiverPage> createState() => _FullGiftReceiverPageState();
}

class _FullGiftReceiverPageState extends State<FullGiftReceiverPage> {
  final HomeController homeController = Get.find();
  final TextEditingController searchController = TextEditingController();
  List<dynamic> filteredList = [];

  @override
  void initState() {
    super.initState();
    filteredList = widget.list; // Initially full list
    searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = searchController.text.toLowerCase();
    setState(() {
      filteredList = widget.list.where((item) {
        final name = item['sender']['name'].toString().toLowerCase();
        final id = item['sender']['id'].toString();
        return name.contains(query) || id.contains(query);
      }).toList();
    });
  }

  @override
  void dispose() {
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffd0c8fb),
      appBar: AppBar(
        leading: IconButton(
            onPressed: () {
              Get.back();
            },
            icon: Icon(
              Icons.arrow_back_ios,
              color: Colors.white,
            )),
        title: Text(
          ('All Gift Receivers').appTr,
          style: GoogleFonts.roboto(
              fontSize: kHeight * 0.018, color: Colors.white),
        ),
        backgroundColor: const Color(0xff8A4CF7),
        centerTitle: true,
      ),
      body: Padding(
        padding:
            EdgeInsets.symmetric(horizontal: kWeight * 0.022, vertical: 12),
        child: Column(
          children: [
            // 🔹 Search Bar
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: ('Search by Name or ID').appTr,
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // 🔹 GridView
            Expanded(
              child: filteredList.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.sentiment_dissatisfied,
                              size: kHeight * 0.1, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                           Text(
                            ('No Receivers Found').appTr,
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Colors.black54),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      itemCount: filteredList.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        mainAxisExtent: kHeight * 0.11,
                        childAspectRatio: 0.7,
                      ),
                      itemBuilder: (context, index) {
                        final item = filteredList[index];
                        return GestureDetector(
                          onTap: () {
                            homeController.visitProfile(
                                userId: '${item['sender']['id']}');
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                  colors: [
                                    Color(0x85c7a2f4),
                                    Color(0xca8c6af0)
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0x85461dd6),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const SizedBox(height: 2),
                                // Gift Image
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: CachedNetworkImage(
                                    imageUrl: ImageHelper.getImageUrl(
                                        '${item['gift']['gift_image']}'),
                                    height: kHeight * 0.05,
                                    width: kHeight * 0.05,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) =>
                                        Container(color: Colors.grey.shade300),
                                    errorWidget: (context, url, error) =>
                                        const Icon(Icons.error),
                                  ),
                                ),
                                // Profile + Name
                                Row(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          left: 0, bottom: 8, right: 2),
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          // Frame
                                          Container(
                                            height: kHeight * 0.04,
                                            width: kHeight * 0.04,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              image: item['sender'][
                                                          'asset_purchase_history'] ==
                                                      null
                                                  ? null
                                                  : DecorationImage(
                                                      image: NetworkImage(
                                                          ImageHelper.getImageUrl(
                                                              '${item['sender']['asset_purchase_history']['asset']['asset']}')),
                                                      fit: BoxFit.cover,
                                                    ),
                                            ),
                                          ),
                                          // Profile
                                          ClipOval(
                                            child: CachedNetworkImage(
                                              imageUrl: ImageHelper.getImageUrl(
                                                  '${item['sender']['profile_image']}'),
                                              height: kHeight * 0.025,
                                              width: kHeight * 0.025,
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) =>
                                                  Container(
                                                      color:
                                                          Colors.grey.shade300),
                                              errorWidget:
                                                  (context, url, error) =>
                                                      const Icon(Icons.person),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 8.0),
                                        child: AutoSizeText(
                                          '${item['sender']['name']}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          minFontSize: 6,
                                          maxFontSize:
                                              (kHeight * 0.013).roundToDouble(),
                                          stepGranularity: 0.1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
