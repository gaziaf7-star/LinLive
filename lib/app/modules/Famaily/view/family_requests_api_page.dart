import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../Controller/FamilyConroller.dart';
import '../Models/family_models.dart';
import '../Widgets/family_common_widgets.dart';
import '../Widgets/family_shimmer.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class FamilyRequestsApiPage extends StatefulWidget {
  const FamilyRequestsApiPage({super.key});

  @override
  State<FamilyRequestsApiPage> createState() => _FamilyRequestsApiPageState();
}

class _FamilyRequestsApiPageState extends State<FamilyRequestsApiPage> with SingleTickerProviderStateMixin {
  final FamilyController controller = Get.put(Familyconroller(), permanent: true);
  late final TabController tabController;

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 2, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadAll();
    });
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    if (controller.myFamily.value == null) {
      await controller.loadHome(silent: true);
    }

    final familyId = controller.myFamily.value?.id ?? 0;
    if (controller.canManageRequests && familyId > 0) {
      await controller.loadRequests(
        familyId: familyId,
        status: 'pending',
        silent: controller.requests.isNotEmpty,
      );
    }
    await controller.loadRequests(status: 'pending', silent: controller.ownRequests.isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    final r = FamilyUi.r;
    return Scaffold(
      backgroundColor: const Color(0xffF7F7FA),
      body: SafeArea(
        child: Column(
          children: [
            FamilyTopBar(
              title: ('Family Requests').appTr,
              trailing: InkWell(
                onTap: _loadAll,
                borderRadius: BorderRadius.circular(30),
                child: Padding(
                  padding: EdgeInsets.all(r(context, 7)),
                  child: Icon(Icons.refresh_rounded, size: r(context, 22), color: Colors.black),
                ),
              ),
            ),
            _tabs(context),
            Expanded(
              child: TabBarView(
                controller: tabController,
                physics: const BouncingScrollPhysics(),
                children: [
                  _adminRequests(context),
                  _myRequests(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabs(BuildContext context) {
    final r = FamilyUi.r;
    return Container(
      height: r(context, 44),
      margin: EdgeInsets.symmetric(horizontal: r(context, 12)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(r(context, 12)),
      ),
      child: TabBar(
        controller: tabController,
        indicatorColor: const Color(0xff7C45F3),
        indicatorWeight: r(context, 3),
        labelColor: const Color(0xff7C45F3),
        unselectedLabelColor: const Color(0xff777782),
        labelStyle: TextStyle(fontSize: r(context, 12.5), fontWeight: FontWeight.w900),
        unselectedLabelStyle: TextStyle(fontSize: r(context, 12), fontWeight: FontWeight.w800),
        tabs:  [
          Tab(text: ('Join Requests').appTr),
          Tab(text: ('My Requests').appTr),
        ],
      ),
    );
  }

  Widget _adminRequests(BuildContext context) {
    return Obx(() {
      if (!controller.canManageRequests) {
        return _empty(('Only family owner/admin can manage join requests.').appTr);
      }

      if (controller.requestStatus.value == FamilyPageStatus.loading && controller.requests.isEmpty) {
        return const FamilyListShimmer();
      }

      final list = controller.requests;
      if (list.isEmpty) return _empty(('No pending request').appTr);

      return RefreshIndicator(
        onRefresh: () async => controller.loadRequests(
          familyId: controller.myFamily.value?.id,
          status: 'pending',
        ),
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: EdgeInsets.fromLTRB(
            FamilyUi.r(context, 14),
            FamilyUi.r(context, 14),
            FamilyUi.r(context, 14),
            FamilyUi.r(context, 24),
          ),
          itemCount: list.length,
          separatorBuilder: (_, __) => SizedBox(height: FamilyUi.r(context, 12)),
          itemBuilder: (_, i) => _requestCard(context, list[i], ownerMode: true),
        ),
      );
    });
  }

  Widget _myRequests(BuildContext context) {
    return Obx(() {
      if (controller.requestStatus.value == FamilyPageStatus.loading && controller.ownRequests.isEmpty) {
        return const FamilyListShimmer();
      }

      final list = controller.ownRequests;
      if (list.isEmpty) return _empty(('No pending request from you').appTr);

      return RefreshIndicator(
        onRefresh: () async => controller.loadRequests(status: 'pending'),
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: EdgeInsets.fromLTRB(
            FamilyUi.r(context, 14),
            FamilyUi.r(context, 14),
            FamilyUi.r(context, 14),
            FamilyUi.r(context, 24),
          ),
          itemCount: list.length,
          separatorBuilder: (_, __) => SizedBox(height: FamilyUi.r(context, 12)),
          itemBuilder: (_, i) => _requestCard(context, list[i], ownerMode: false),
        ),
      );
    });
  }

  Widget _requestCard(BuildContext context, FamilyRequestModel request, {required bool ownerMode}) {
    final r = FamilyUi.r;
    return Container(
      padding: EdgeInsets.all(r(context, 12)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(r(context, 14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          FamilyNetworkImage(
            url: request.userAvatarUrl,
            size: r(context, 46),
            radius: 23,
            placeholderIcon: Icons.person,
          ),
          SizedBox(width: r(context, 10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.userName.isEmpty ? ('Unknown User').appTr: request.userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: r(context, 14), fontWeight: FontWeight.w900),
                ),
                SizedBox(height: r(context, 4)),
                Text(
                  request.message.isEmpty ? ('Status: ${request.status.isEmpty ? 'pending' : request.status}').appTr : request.message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: r(context, 12),
                    color: const Color(0xff777782),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Obx(() {
            final disabled = controller.isActionLoading.value;
            if (ownerMode) {
              return Row(
                children: [
                  _circleAction(
                    context,
                    icon: Icons.close_rounded,
                    color: const Color(0xffEF4444),
                    disabled: disabled,
                    onTap: () => _confirmReject(request),
                  ),
                  SizedBox(width: r(context, 7)),
                  _circleAction(
                    context,
                    icon: Icons.check_rounded,
                    color: const Color(0xff22C55E),
                    disabled: disabled,
                    onTap: () => _confirmAccept(request),
                  ),
                ],
              );
            }

            return InkWell(
              onTap: disabled ? null : () => _confirmCancel(request),
              borderRadius: BorderRadius.circular(30),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: r(context, 12), vertical: r(context, 8)),
                decoration: BoxDecoration(
                  color: const Color(0xffFFF1F2),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  ('Cancel').appTr,
                  style: TextStyle(
                    fontSize: r(context, 11.5),
                    color: const Color(0xffE11D48),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _circleAction(
      BuildContext context, {
        required IconData icon,
        required Color color,
        required bool disabled,
        required VoidCallback onTap,
      }) {
    final r = FamilyUi.r;
    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        width: r(context, 36),
        height: r(context, 36),
        decoration: BoxDecoration(
          color: color.withOpacity(.11),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: r(context, 21)),
      ),
    );
  }

  Future<void> _confirmAccept(FamilyRequestModel request) async {
    final ok = await _confirm(
      title: ('Accept Request?').appTr,
      message: ('Accept ${request.userName} into your family?').appTr,
      confirmText: ('Accept').appTr,
      color: const Color(0xff22C55E),
    );
    if (ok) await controller.acceptRequest(request.id);
  }

  Future<void> _confirmReject(FamilyRequestModel request) async {
    final ok = await _confirm(
      title: ('Reject Request?').appTr,
      message: ("Reject ${request.userName}'s family join request?").appTr,
      confirmText: ('Reject').appTr,
      color: const Color(0xffEF4444),
    );
    if (ok) await controller.rejectRequest(request.id);
  }

  Future<void> _confirmCancel(FamilyRequestModel request) async {
    final ok = await _confirm(
      title: ('Cancel Request?').appTr,
      message: ('Cancel your pending family join request?').appTr,
      confirmText: ('Cancel Request').appTr,
      color: const Color(0xffEF4444),
    );
    if (ok) await controller.cancelRequest(request.id);
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmText,
    required Color color,
  }) async {
    final result = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child:  Text(('No').appTr)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
            onPressed: () => Get.back(result: true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result == true;
  }

  Widget _empty(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }
}
