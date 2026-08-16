import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../backpack/controllers/store_controller.dart';
import '../../backpack/views/BackPack.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';

import 'mall_items_page.dart';

class MallCategoryPage extends StatelessWidget {
  const MallCategoryPage({super.key});

  /// Ekhane apiType-gula apnar backend-e /asset-list response-er "type"

  static final List<_MallCategory> _categories = [
    _MallCategory(
      title: 'Ring',
      apiType: 'Ring',
      image: 'assets/flaticons/ring.png',
      icon: Icons.diamond_rounded,
      colors: const [Color(0xffB88CFF), Color(0xff6A3FD1)],
    ),
    _MallCategory(
      title: 'Frame',
      apiType: 'Frame',
      image: 'assets/flaticons/frame.png',
      icon: Icons.shield_rounded,
      colors: const [Color(0xffFFC15E), Color(0xffFF7A45)],
    ),
    _MallCategory(
      title: 'Car',
      apiType: 'Car',
      image: 'assets/flaticons/car.png',
      icon: Icons.directions_car_filled_rounded,
      colors: const [Color(0xff9C7BFF), Color(0xff5A3FD6)],
    ),
    _MallCategory(
      title: 'Entrance Show',
      apiType: 'Entry Care',
      image: 'assets/flaticons/entry.png',
      icon: Icons.auto_awesome_rounded,
      colors: const [Color(0xffFFC1DA), Color(0xffFF7AA8)],
    ),
    _MallCategory(
      title: 'Card',
      apiType: 'Card',
      image: 'assets/flaticons/card.png',
      icon: Icons.style_rounded,
      colors: const [Color(0xffFF9A8B), Color(0xffE4544B)],
    ),
    _MallCategory(
      title: 'Bubble',
      apiType: 'Bubble',
      image: 'assets/flaticons/chatbabut.png',
      icon: Icons.chat_bubble_rounded,
      colors: const [Color(0xff8FE3FF), Color(0xff3FA6E0)],
    ),
  ];

  /// Mall page open howar shathe shathe asset list-er request pathiye
  void _prefetchAssets() {
    final storeController = Get.isRegistered<StoreController>()
        ? Get.find<StoreController>()
        : Get.put(StoreController());
    if (storeController.assetList.isEmpty) {
      storeController.getAssetList();
    }
  }

  @override
  Widget build(BuildContext context) {
    _prefetchAssets();
    return Scaffold(
      backgroundColor: const Color(0xff0F0B08),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: Get.back,
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
        ),
        title: Text(
          ('Mall').appTr,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _buildBackpackBanner(),
          const SizedBox(height: 22),
          Text(
            ('Single item purchase').appTr,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _categories.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 1.72,
            ),
            itemBuilder: (context, index) {
              return _MallCategoryTile(category: _categories[index]);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBackpackBanner() {
    return GestureDetector(
      onTap: () => Get.to(Backpack(), transition: Transition.rightToLeft),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xffFFC94A), width: 1.4),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xff6B4A22), Color(0xff2A1B10)],
          ),
        ),
        child: Row(
          children: [
            Image.asset(
              'assets/flaticons/bag.png',
              height: 46,
              width: 46,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: const Color(0xffFFC94A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.backpack_rounded,
                    color: Color(0xff5A3B12), size: 26),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                ('My backpack').appTr,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xffFFC94A),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                ('Click to view').appTr,
                style: GoogleFonts.poppins(
                  color: const Color(0xff5A3B12),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MallCategoryTile extends StatelessWidget {
  final _MallCategory category;

  const _MallCategoryTile({required this.category});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Get.to(
              () => MallItemsPage(
            title: category.title,
            apiType: category.apiType,
          ),
          transition: Transition.rightToLeft,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xff17130F),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(.06)),
        ),
        child: Row(
          children: [
            Container(
              height: 58,
              width: 58,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: category.colors.first.withOpacity(.14),
                border: Border.all(color: Colors.white.withOpacity(.08)),
              ),
              child: Image.asset(
                category.image,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(
                  category.icon,
                  color: Colors.white.withOpacity(.85),
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                category.title.appTr,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: const Color(0xffFFC94A),
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MallCategory {
  final String title;
  final String apiType;
  final String image;
  final IconData icon;
  final List<Color> colors;

  const _MallCategory({
    required this.title,
    required this.apiType,
    required this.image,
    required this.icon,
    required this.colors,
  });
}