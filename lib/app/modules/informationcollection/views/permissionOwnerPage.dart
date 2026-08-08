import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../constants/layout_constant.dart';
import '../../../../widgets/after/castom appbar.dart';
import '../controllers/informationcollection_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class PermissionOwnerSelectView extends StatelessWidget {
  PermissionOwnerSelectView({super.key});

  final InformationcollectionController controller =
  Get.find<InformationcollectionController>();

  Color roleColor(String role) {
    final r = role.toLowerCase();

    if (r.contains('super')) {
      return const Color(0xffFFB300);
    }

    if (r.contains('bd')) {
      return const Color(0xff26C6DA);
    }

    return const Color(0xffA78BFA);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.showPermissionOwnerList();
    });

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(title: ('Select Permission Owner').appTr),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              margin: EdgeInsets.fromLTRB(
                kWeight * 0.04,
                kHeight * 0.018,
                kWeight * 0.04,
                kHeight * 0.01,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xffF6F2FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xffE8DAFF)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: TextField(
                controller: controller.ownerSearchController,
                style: GoogleFonts.poppins(
                  color: Colors.black87,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: ('Search Super Admin / BD Admin').appTr,
                  hintStyle: GoogleFonts.poppins(
                    color: Colors.black38,
                    fontSize: 13,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xff8A4CF7),
                  ),
                ),
              ),
            ),

            Padding(
              padding: EdgeInsets.symmetric(horizontal: kWeight * 0.04),
              child: Row(
                children: [
                  _chip(('Super Admin').appTr, const Color(0xffFFB300)),
                  const SizedBox(width: 8),
                  _chip(('BD Admin').appTr, const Color(0xff26C6DA)),
                ],
              ),
            ),

            SizedBox(height: kHeight * 0.012),

            Expanded(
              child: Obx(() {
                if (controller.ownerLoading.value) {
                  return const _OwnerListShimmer();
                }

                if (controller.filteredPermissionOwners.isEmpty) {
                  return RefreshIndicator(
                    color: const Color(0xff8A4CF7),
                    onRefresh: controller.showPermissionOwnerList,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: kHeight * 0.20),
                        Center(
                          child: Text(
                            ('No Super Admin / BD Admin found').appTr,
                            style: GoogleFonts.poppins(
                              color: Colors.black54,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  color: const Color(0xff8A4CF7),
                  onRefresh: controller.showPermissionOwnerList,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: EdgeInsets.fromLTRB(
                      kWeight * 0.04,
                      4,
                      kWeight * 0.04,
                      20,
                    ),
                    itemCount: controller.filteredPermissionOwners.length,
                    itemBuilder: (context, index) {
                      final user = controller.filteredPermissionOwners[index];
                      final role = controller.roleText(user);
                      final img = controller.imageUrl(user['profile_image']);
                      final isSelected =
                          controller.selectedOwnerId.value ==
                              user['id'].toString();

                      return InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => controller.selectPermissionOwner(user),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            gradient: isSelected
                                ? const LinearGradient(
                              colors: [
                                Color(0xff7C3AED),
                                Color(0xffEC4899),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                                : null,
                            color: isSelected ? null : Colors.white,
                            border: Border.all(
                              color: isSelected
                                  ? Colors.white.withOpacity(0.55)
                                  : const Color(0xffEFE7FF),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isSelected
                                    ? const Color(0xff7C3AED).withOpacity(0.18)
                                    : Colors.black.withOpacity(0.055),
                                blurRadius: 14,
                                offset: const Offset(0, 7),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                height: 58,
                                width: 58,
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      roleColor(role),
                                      Colors.white.withOpacity(0.8),
                                    ],
                                  ),
                                ),
                                child: CircleAvatar(
                                  backgroundColor: const Color(0xffF6F2FF),
                                  backgroundImage:
                                  img.isNotEmpty ? NetworkImage(img) : null,
                                  child: img.isEmpty
                                      ? const Icon(
                                    Icons.person,
                                    color: Color(0xff8A4CF7),
                                  )
                                      : null,
                                ),
                              ),

                              const SizedBox(width: 12),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user['name']?.toString() ?? ('Unknown').appTr,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.poppins(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.black87,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      ('ID: ${user['id']}  •  UID: ${user['user_id'] ?? 'N/A'}').appTr,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.poppins(
                                        color: isSelected
                                            ? Colors.white70
                                            : Colors.black45,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 7),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 9,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: roleColor(role)
                                                .withOpacity(isSelected ? 0.25 : 0.14),
                                            borderRadius:
                                            BorderRadius.circular(20),
                                            border: Border.all(
                                              color: roleColor(role)
                                                  .withOpacity(0.40),
                                            ),
                                          ),
                                          child: Text(
                                            role,
                                            style: GoogleFonts.poppins(
                                              color: isSelected
                                                  ? Colors.white
                                                  : roleColor(role),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 7),
                                        Expanded(
                                          child: Text(
                                            user['country']?.toString() ??
                                                ('No country').appTr,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.poppins(
                                              color: isSelected
                                                  ? Colors.white70
                                                  : Colors.black45,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 8),

                              AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                height: 32,
                                width: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xffF6F2FF),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.white.withOpacity(0.20)
                                        : const Color(0xffE8DAFF),
                                  ),
                                ),
                                child: Icon(
                                  isSelected
                                      ? Icons.check
                                      : Icons.arrow_forward_ios_rounded,
                                  color: isSelected
                                      ? const Color(0xff7C3AED)
                                      : const Color(0xff8A4CF7),
                                  size: isSelected ? 20 : 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.11),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _OwnerListShimmer extends StatefulWidget {
  const _OwnerListShimmer();

  @override
  State<_OwnerListShimmer> createState() => _OwnerListShimmerState();
}

class _OwnerListShimmerState extends State<_OwnerListShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  LinearGradient _gradient() {
    final double value = _controller.value;

    return LinearGradient(
      begin: Alignment(-1.0 + value * 2, -0.3),
      end: Alignment(1.0 + value * 2, 0.3),
      colors: const [
        Color(0xffEEEEEE),
        Color(0xffFAFAFA),
        Color(0xffEEEEEE),
      ],
      stops: const [0.25, 0.50, 0.75],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            kWeight * 0.04,
            4,
            kWeight * 0.04,
            20,
          ),
          itemCount: 8,
          itemBuilder: (context, index) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xffEFE7FF)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.045),
                    blurRadius: 14,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _shimmerBox(
                    height: 58,
                    width: 58,
                    radius: 100,
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _shimmerBox(
                          height: 14,
                          width: Get.width * 0.36,
                          radius: 8,
                        ),
                        const SizedBox(height: 8),
                        _shimmerBox(
                          height: 10,
                          width: Get.width * 0.48,
                          radius: 8,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _shimmerBox(
                              height: 22,
                              width: 78,
                              radius: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _shimmerBox(
                                height: 10,
                                width: double.infinity,
                                radius: 8,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  _shimmerBox(
                    height: 32,
                    width: 32,
                    radius: 100,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _shimmerBox({
    required double height,
    required double width,
    required double radius,
  }) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        gradient: _gradient(),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}