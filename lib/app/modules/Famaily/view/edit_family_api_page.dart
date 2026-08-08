import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../Controller/FamilyConroller.dart';
import '../Models/family_models.dart';
import '../Widgets/family_common_widgets.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class EditFamilyApiPage extends StatefulWidget {
  const EditFamilyApiPage({super.key, this.family});

  final FamilyModel? family;

  @override
  State<EditFamilyApiPage> createState() => _EditFamilyApiPageState();
}

class _EditFamilyApiPageState extends State<EditFamilyApiPage>
    with SingleTickerProviderStateMixin {
  final FamilyController controller = Get.put(Familyconroller(), permanent: true);
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController codeController = TextEditingController();
  final TextEditingController countryController = TextEditingController();
  final TextEditingController noticeController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  File? logoFile;
  File? coverFile;
  String joinType = 'approval';
  FamilyModel? family;

  late final AnimationController _bgController;

  static const Color _primary = Color(0xFF190522);
  static const Color _secondary = Color(0xFF3B072F);
  static const Color _accent = Color(0xFFFF3D8B);
  static const Color _purple = Color(0xFF7C3AED);
  static const Color _gold1 = Color(0xFFFFC400);
  static const Color _gold2 = Color(0xFFFFF238);
  static const Color _pageBg = Color(0xFFFFF7FD);
  static const Color _cardBg = Color(0xFFFFFFFF);
  static const Color _textDark = Color(0xFF211625);
  static const Color _muted = Color(0xFF827484);

  double _s(BuildContext context, double value) {
    final width = MediaQuery.of(context).size.width;
    final scale = (width / 390.0).clamp(0.86, 1.18);
    return value * scale;
  }

  @override
  void initState() {
    super.initState();
    family = widget.family ?? controller.myFamily.value;
    _fillData(family);
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat(reverse: true);
  }

  void _fillData(FamilyModel? data) {
    if (data == null) return;
    nameController.text = data.name;
    codeController.text = data.familyCode;
    countryController.text = data.country.isEmpty ? 'Bangladesh' : data.country;
    noticeController.text = data.notice;
    descriptionController.text = data.description;
    joinType = data.joinType.isEmpty ? 'approval' : data.joinType;
    if (!['approval', 'auto', 'closed'].contains(joinType)) {
      joinType = 'approval';
    }
  }

  void _toast(String message, {bool isError = false}) {
    Fluttertoast.cancel();
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: isError ? const Color(0xFFE11D48) : const Color(0xFF16A34A),
      textColor: Colors.white,
      fontSize: 14,
    );
  }

  Future<void> _pickImage({required bool isLogo}) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: isLogo ? 900 : 1600,
        maxHeight: isLogo ? 900 : 1200,
      );

      if (file == null) return;

      setState(() {
        if (isLogo) {
          logoFile = File(file.path);
        } else {
          coverFile = File(file.path);
        }
      });

      _toast(isLogo ? ('New family logo selected.').appTr: ('New family cover selected.').appTr);
    } catch (_) {
      _toast(
        isLogo
            ? ('Family logo select korte problem hocche.').appTr: ('Family cover select korte problem hocche.').appTr,
        isError: true,
      );
    }
  }

  String _joinTypeText(String value) {
    switch (value) {
      case 'auto':
        return ('Join Freely').appTr;
      case 'closed':
        return ('Closed').appTr;
      default:
        return ('Need Approval').appTr;
    }
  }

  IconData _joinTypeIcon(String value) {
    switch (value) {
      case 'auto':
        return Icons.lock_open_rounded;
      case 'closed':
        return Icons.lock_rounded;
      default:
        return Icons.verified_user_rounded;
    }
  }

  @override
  void dispose() {
    _bgController.dispose();
    nameController.dispose();
    codeController.dispose();
    countryController.dispose();
    noticeController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      body: Stack(
        children: [
          _animatedPageBackground(context),
          SafeArea(
            child: Obx(() {
              final currentFamily = family ?? controller.myFamily.value;

              if (currentFamily == null) {
                return Column(
                  children: [
                    _buildHeader(context),
                    Expanded(child: _emptyState(('No family found').appTr)),
                  ],
                );
              }

              if (!controller.canEditFamily) {
                return Column(
                  children: [
                    _buildHeader(context),
                    Expanded(
                      child: _emptyState(
                        'Only family owner/admin can edit family information.',
                      ),
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  _buildHeader(context),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        _s(context, 16),
                        _s(context, 14),
                        _s(context, 16),
                        _s(context, 120),
                      ),
                      child: Form(
                        key: formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLogoCoverEditor(context, currentFamily),
                            SizedBox(height: _s(context, 22)),
                            _familyQuickInfo(context, currentFamily),
                            SizedBox(height: _s(context, 16)),
                            _premiumSection(
                              context,
                              title: ('Family Information').appTr,
                              icon: Icons.groups_2_rounded,
                              children: [
                                _sectionTitle(context, ('Family Name').appTr),
                                SizedBox(height: _s(context, 10)),
                                _roundedTextField(
                                  context,
                                  controller: nameController,
                                  hint: 'Enter your family name',
                                  icon: Icons.favorite_rounded,
                                  maxLength: 15,
                                  validator: (v) {
                                    if ((v ?? '').trim().length < 3) {
                                      return 'Family name minimum 3 letters';
                                    }
                                    return null;
                                  },
                                ),
                                SizedBox(height: _s(context, 14)),
                                _roundedTextField(
                                  context,
                                  controller: codeController,
                                  hint: ('Family Code').appTr,
                                  icon: Icons.tag_rounded,
                                  maxLength: 30,
                                ),
                              ],
                            ),
                            SizedBox(height: _s(context, 16)),
                            _premiumSection(
                              context,
                              title: ('Announcement').appTr,
                              icon: Icons.campaign_rounded,
                              children: [
                                _roundedTextField(
                                  context,
                                  controller: noticeController,
                                  hint: 'Enter your family announcement',
                                  icon: Icons.edit_note_rounded,
                                  maxLines: 5,
                                  minLines: 5,
                                  maxLength: 200,
                                ),
                              ],
                            ),
                            SizedBox(height: _s(context, 16)),
                            _premiumSection(
                              context,
                              title: ('Family Settings').appTr,
                              icon: Icons.tune_rounded,
                              children: [
                                _settingsTile(
                                  context,
                                  title: ('Join Mode').appTr,
                                  value: _joinTypeText(joinType),
                                  icon: _joinTypeIcon(joinType),
                                  onTap: _showJoinTypeSheet,
                                ),
                                _settingsTile(
                                  context,
                                  title: ('Country').appTr,
                                  value: countryController.text.trim().isEmpty
                                      ? 'Bangladesh'
                                      : countryController.text.trim(),
                                  icon: Icons.public_rounded,
                                  onTap: () async {
                                    final result = await _showCountryEditDialog();
                                    if (result != null && result.trim().isNotEmpty) {
                                      setState(() => countryController.text = result.trim());
                                    }
                                  },
                                ),
                              ],
                            ),
                            SizedBox(height: _s(context, 16)),
                            _premiumSection(
                              context,
                              title: ('Description').appTr,
                              icon: Icons.description_rounded,
                              children: [
                                _roundedTextField(
                                  context,
                                  controller: descriptionController,
                                  hint: 'Write something about your family',
                                  icon: Icons.notes_rounded,
                                  maxLines: 3,
                                  minLines: 3,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _bottomSaveButton(context, currentFamily),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _animatedPageBackground(BuildContext context) {
    return AnimatedBuilder(
      animation: _bgController,
      builder: (context, child) {
        final value = _bgController.value;
        return Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFFEFF8),
                    Color(0xFFFFFFFF),
                    Color(0xFFFFF7FD),
                  ],
                ),
              ),
            ),
            Positioned(
              top: -_s(context, 80) + (value * 18),
              right: -_s(context, 90),
              child: _blurCircle(_s(context, 210), _accent.withOpacity(.16)),
            ),
            Positioned(
              top: _s(context, 180) - (value * 22),
              left: -_s(context, 110),
              child: _blurCircle(_s(context, 230), _purple.withOpacity(.12)),
            ),
            Positioned(
              bottom: -_s(context, 90),
              right: _s(context, 30) + (value * 20),
              child: _blurCircle(_s(context, 180), _gold1.withOpacity(.10)),
            ),
          ],
        );
      },
    );
  }

  Widget _blurCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        _s(context, 12),
        _s(context, 8),
        _s(context, 12),
        _s(context, 6),
      ),
      padding: EdgeInsets.fromLTRB(
        _s(context, 10),
        _s(context, 10),
        _s(context, 12),
        _s(context, 10),
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primary, _secondary, _accent],
        ),
        borderRadius: BorderRadius.circular(_s(context, 26)),
        boxShadow: [
          BoxShadow(
            color: _secondary.withOpacity(.24),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          InkWell(
            onTap: Get.back,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: _s(context, 42),
              height: _s(context, 42),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.14),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(.16)),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: _s(context, 18),
              ),
            ),
          ),
          SizedBox(width: _s(context, 12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ('Edit Family').appTr,
                  style: TextStyle(
                    fontSize: _s(context, 20),
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
                SizedBox(height: _s(context, 5)),
                Text(
                  ('Update logo, cover & family info').appTr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: _s(context, 12),
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withOpacity(.72),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: _s(context, 42),
            height: _s(context, 42),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [_gold1, _gold2]),
              boxShadow: [
                BoxShadow(
                  color: _gold1.withOpacity(.28),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              Icons.edit_rounded,
              color: _textDark,
              size: _s(context, 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoCoverEditor(BuildContext context, FamilyModel data) {
    final coverHeight = _s(context, 205);
    final logoSize = _s(context, 104);
    final hasCover = coverFile != null || data.coverUrl.trim().isNotEmpty;
    final hasLogo = logoFile != null || data.logoUrl.trim().isNotEmpty;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(_s(context, 28)),
            onTap: () => _pickImage(isLogo: false),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  width: double.infinity,
                  height: coverHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(_s(context, 28)),
                    border: Border.all(color: Colors.white.withOpacity(.70), width: 1.2),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_primary, _secondary, _accent],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _secondary.withOpacity(.18),
                        blurRadius: 28,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      Positioned.fill(child: _coverImage(context, data)),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withOpacity(.08),
                                _primary.withOpacity(.20),
                                Colors.black.withOpacity(.42),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: -_s(context, 35),
                        top: -_s(context, 30),
                        child: _premiumRing(context, _s(context, 145)),
                      ),
                      Positioned(
                        left: -_s(context, 45),
                        bottom: -_s(context, 42),
                        child: _premiumRing(context, _s(context, 160)),
                      ),
                      Center(
                        child: Padding(
                          padding: EdgeInsets.only(bottom: _s(context, 20)),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: _s(context, 12),
                                  vertical: _s(context, 8),
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(.14),
                                  borderRadius: BorderRadius.circular(99),
                                  border: Border.all(color: Colors.white.withOpacity(.16)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.add_photo_alternate_rounded,
                                      color: Colors.white,
                                      size: _s(context, 17),
                                    ),
                                    SizedBox(width: _s(context, 6)),
                                    Text(
                                      coverFile == null ? ('Tap to change cover').appTr: ('New cover selected').appTr,
                                      style: TextStyle(
                                        fontSize: _s(context, 12.5),
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: _s(context, 10)),
                              Text(
                                nameController.text.trim().isEmpty
                                    ? (data.name.isEmpty ? ('Family Name').appTr: data.name.toUpperCase())
                                    : nameController.text.trim().toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: _s(context, 19),
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(.28),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: _s(context, 6)),
                              Text(
                                ('Family ID: ${data.familyCode.isEmpty ? '-' : data.familyCode}').appTr,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: _s(context, 12.5),
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white.withOpacity(.85),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: -_s(context, 42),
                  child: GestureDetector(
                    onTap: () => _pickImage(isLogo: true),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: logoSize,
                          height: logoSize,
                          padding: EdgeInsets.all(_s(context, 5)),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(colors: [Colors.white, Color(0xFFFFEFF8)]),
                            boxShadow: [
                              BoxShadow(
                                color: _accent.withOpacity(.24),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Container(
                            padding: EdgeInsets.all(_s(context, 3)),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(colors: [_gold1, _accent, _purple]),
                            ),
                            child: ClipOval(child: _logoImage(context, data)),
                          ),
                        ),
                        Positioned(
                          right: -_s(context, 2),
                          bottom: _s(context, 9),
                          child: Container(
                            width: _s(context, 35),
                            height: _s(context, 35),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(colors: [_gold1, _gold2]),
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: _gold1.withOpacity(.34),
                                  blurRadius: 12,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.edit_rounded,
                              color: _textDark,
                              size: _s(context, 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  right: _s(context, 14),
                  top: _s(context, 14),
                  child: _imagePill(
                    context,
                    icon: Icons.wallpaper_rounded,
                    text: hasCover ? ('Cover Ready').appTr: ('Add Cover').appTr,
                  ),
                ),
                Positioned(
                  left: _s(context, 14),
                  bottom: _s(context, 14),
                  child: _imagePill(
                    context,
                    icon: Icons.verified_rounded,
                    text: hasLogo ? ('Logo Ready').appTr: ('Add Logo').appTr,
                    isGold: hasLogo,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: _s(context, 48)),
          Text(
            logoFile == null && coverFile == null
                ? ('Tap cover or circle logo to upload new images').appTr: ('New image selected. Tap Save Changes to update.').appTr,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: _s(context, 13),
              color: logoFile == null && coverFile == null ? _muted : const Color(0xFF16A34A),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _coverImage(BuildContext context, FamilyModel data) {
    if (coverFile != null) {
      return Image.file(coverFile!, width: double.infinity, height: double.infinity, fit: BoxFit.cover);
    }

    if (data.coverUrl.trim().isNotEmpty) {
      return Image.network(
        data.coverUrl,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const CustomPaint(painter: FamilyPurpleHeaderPainter()),
      );
    }

    return const CustomPaint(painter: FamilyPurpleHeaderPainter());
  }

  Widget _logoImage(BuildContext context, FamilyModel data) {
    if (logoFile != null) {
      return Image.file(logoFile!, width: double.infinity, height: double.infinity, fit: BoxFit.cover);
    }

    if (data.logoUrl.trim().isNotEmpty) {
      return Image.network(
        data.logoUrl,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _logoFallback(context),
      );
    }

    return _logoFallback(context);
  }

  Widget _logoFallback(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primary, _secondary],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.camera_alt_rounded, color: Colors.white, size: _s(context, 28)),
          SizedBox(height: _s(context, 3)),
          Text(
            ('Logo').appTr,
            style: TextStyle(
              color: Colors.white,
              fontSize: _s(context, 10.5),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _premiumRing(BuildContext context, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(.10), width: _s(context, 18)),
      ),
    );
  }

  Widget _imagePill(
      BuildContext context, {
        required IconData icon,
        required String text,
        bool isGold = false,
      }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: _s(context, 11), vertical: _s(context, 7)),
      decoration: BoxDecoration(
        gradient: isGold ? const LinearGradient(colors: [_gold1, _gold2]) : null,
        color: isGold ? null : Colors.white.withOpacity(.88),
        borderRadius: BorderRadius.circular(99),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isGold ? _textDark : _secondary, size: _s(context, 15)),
          SizedBox(width: _s(context, 5)),
          Text(
            text,
            style: TextStyle(
              color: isGold ? _textDark : _secondary,
              fontSize: _s(context, 11.5),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _familyQuickInfo(BuildContext context, FamilyModel data) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(_s(context, 14)),
      decoration: BoxDecoration(
        color: _cardBg.withOpacity(.94),
        borderRadius: BorderRadius.circular(_s(context, 22)),
        border: Border.all(color: Colors.white.withOpacity(.82)),
        boxShadow: [
          BoxShadow(
            color: _secondary.withOpacity(.065),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          _quickItem(context, ('Level').appTr, 'Lv. ${data.levelNo}', Icons.military_tech_rounded),
          _softDivider(context),
          _quickItem(context, ('Members').appTr, data.memberText, Icons.people_alt_rounded),
          _softDivider(context),
          _quickItem(context, ('Points').appTr, FamilyUi.compact(data.points), Icons.auto_awesome_rounded),
        ],
      ),
    );
  }

  Widget _quickItem(BuildContext context, String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: _s(context, 34),
            height: _s(context, 34),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _secondary.withOpacity(.08),
            ),
            child: Icon(icon, color: _secondary, size: _s(context, 18)),
          ),
          SizedBox(height: _s(context, 7)),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: _s(context, 13.2),
              fontWeight: FontWeight.w900,
              color: _textDark,
            ),
          ),
          SizedBox(height: _s(context, 3)),
          Text(
            label,
            style: TextStyle(
              fontSize: _s(context, 11.2),
              fontWeight: FontWeight.w800,
              color: _muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _softDivider(BuildContext context) {
    return Container(
      width: 1,
      height: _s(context, 50),
      color: const Color(0xFFF0E0F2),
    );
  }

  Widget _premiumSection(
      BuildContext context, {
        required String title,
        required IconData icon,
        required List<Widget> children,
      }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(_s(context, 14)),
      decoration: BoxDecoration(
        color: _cardBg.withOpacity(.92),
        borderRadius: BorderRadius.circular(_s(context, 24)),
        border: Border.all(color: Colors.white.withOpacity(.82)),
        boxShadow: [
          BoxShadow(
            color: _secondary.withOpacity(.065),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: _s(context, 35),
                height: _s(context, 35),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_primary, _secondary]),
                  borderRadius: BorderRadius.circular(_s(context, 13)),
                ),
                child: Icon(icon, color: Colors.white, size: _s(context, 19)),
              ),
              SizedBox(width: _s(context, 10)),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: _s(context, 16),
                    fontWeight: FontWeight.w900,
                    color: _textDark,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: _s(context, 14)),
          ...children,
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: _s(context, 13.5),
        fontWeight: FontWeight.w900,
        color: _muted,
      ),
    );
  }

  Widget _roundedTextField(
      BuildContext context, {
        required TextEditingController controller,
        required String hint,
        IconData? icon,
        int maxLines = 1,
        int? minLines,
        int? maxLength,
        bool readOnly = false,
        String? Function(String?)? validator,
      }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      minLines: minLines,
      maxLength: maxLength,
      readOnly: readOnly,
      validator: validator,
      onChanged: (_) => setState(() {}),
      style: TextStyle(fontSize: _s(context, 15.2), fontWeight: FontWeight.w800, color: _textDark),
      cursorColor: _accent,
      decoration: InputDecoration(
        prefixIcon: icon == null
            ? null
            : Icon(icon, color: _secondary.withOpacity(.70), size: _s(context, 20)),
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: _s(context, 14.4),
          fontWeight: FontWeight.w700,
          color: const Color(0xffA796AA),
        ),
        counterStyle: TextStyle(
          color: const Color(0xff9C8FA0),
          fontWeight: FontWeight.w800,
          fontSize: _s(context, 12),
        ),
        filled: true,
        fillColor: const Color(0xFFFFF8FD),
        contentPadding: EdgeInsets.symmetric(horizontal: _s(context, 16), vertical: _s(context, 16)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_s(context, 18)),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_s(context, 18)),
          borderSide: const BorderSide(color: Color(0xFFF1E4F2), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_s(context, 18)),
          borderSide: const BorderSide(color: _accent, width: 1.35),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_s(context, 18)),
          borderSide: const BorderSide(color: Color(0xffEF4444), width: 1.25),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_s(context, 18)),
          borderSide: const BorderSide(color: Color(0xffEF4444), width: 1.25),
        ),
      ),
    );
  }

  Widget _settingsTile(
      BuildContext context, {
        required String title,
        required String value,
        required IconData icon,
        required VoidCallback onTap,
      }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(_s(context, 16)),
      child: Container(
        width: double.infinity,
        margin: EdgeInsets.only(bottom: _s(context, 10)),
        padding: EdgeInsets.all(_s(context, 12)),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8FD),
          borderRadius: BorderRadius.circular(_s(context, 16)),
          border: Border.all(color: const Color(0xFFF1E4F2)),
        ),
        child: Row(
          children: [
            Container(
              width: _s(context, 36),
              height: _s(context, 36),
              decoration: BoxDecoration(shape: BoxShape.circle, color: _secondary.withOpacity(.08)),
              child: Icon(icon, color: _secondary, size: _s(context, 19)),
            ),
            SizedBox(width: _s(context, 10)),
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontSize: _s(context, 14.2), fontWeight: FontWeight.w900, color: _textDark),
              ),
            ),
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: _s(context, 13.7),
                  fontWeight: FontWeight.w900,
                  color: _secondary.withOpacity(.72),
                ),
              ),
            ),
            SizedBox(width: _s(context, 6)),
            Icon(Icons.arrow_forward_ios_rounded, size: _s(context, 14), color: const Color(0xffB6B6BC)),
          ],
        ),
      ),
    );
  }

  void _showJoinTypeSheet() {
    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(color: const Color(0xFFE5DCE8), borderRadius: BorderRadius.circular(99)),
                ),
                const SizedBox(height: 18),
                 Text(
                  ('Select Join Mode').appTr,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _textDark),
                ),
                const SizedBox(height: 12),
                _joinModeOption('auto', ('Join Freely').appTr, Icons.lock_open_rounded),
                _joinModeOption('approval', ('Need Approval').appTr, Icons.verified_user_rounded),
                _joinModeOption('closed', ('Closed').appTr, Icons.lock_rounded),
              ],
            ),
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _joinModeOption(String value, String title, IconData icon) {
    final bool selected = joinType == value;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        gradient: selected ? const LinearGradient(colors: [_primary, _secondary, _accent]) : null,
        color: selected ? null : const Color(0xFFF8F3FA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: selected ? Colors.white.withOpacity(.12) : const Color(0xFFEDE3EF)),
      ),
      child: ListTile(
        onTap: () {
          setState(() => joinType = value);
          Get.back();
        },
        leading: CircleAvatar(
          backgroundColor: selected ? Colors.white.withOpacity(.16) : Colors.white,
          child: Icon(icon, color: selected ? Colors.white : _secondary),
        ),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.w900, color: selected ? Colors.white : _textDark),
        ),
        trailing: selected
            ? const Icon(Icons.check_circle_rounded, color: _gold1)
            : const Icon(Icons.circle_outlined, color: Color(0xffC4C4CC)),
      ),
    );
  }

  Future<String?> _showCountryEditDialog() async {
    final tempController = TextEditingController(text: countryController.text.trim());

    return Get.dialog<String>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title:  Text(('Country').appTr, style: TextStyle(fontWeight: FontWeight.w900)),
        content: TextField(
          controller: tempController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: ('Enter country name').appTr,
            filled: true,
            fillColor: const Color(0xFFFFF8FD),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child:  Text(('Cancel').appTr)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _secondary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Get.back(result: tempController.text),
            child:  Text(('Save').appTr),
          ),
        ],
      ),
    );
  }

  Widget _bottomSaveButton(BuildContext context, FamilyModel data) {
    return Obx(() {
      final isLoading = controller.isActionLoading.value;
      final bool hasNewImage = logoFile != null || coverFile != null;

      return Container(
        padding: EdgeInsets.fromLTRB(_s(context, 16), _s(context, 10), _s(context, 16), _s(context, 14)),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.92),
          boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 18, offset: Offset(0, -6))],
        ),
        child: InkWell(
          onTap: isLoading ? null : () => _submit(data),
          borderRadius: BorderRadius.circular(_s(context, 18)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: _s(context, 58),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isLoading
                    ? [const Color(0xffAAA4AD), const Color(0xff8C8590)]
                    : const [_primary, _secondary, _accent],
              ),
              borderRadius: BorderRadius.circular(_s(context, 18)),
              boxShadow: [
                BoxShadow(
                  color: _accent.withOpacity(.26),
                  blurRadius: 20,
                  offset: const Offset(0, 9),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: isLoading
                ? SizedBox(
              width: _s(context, 22),
              height: _s(context, 22),
              child: const CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
            )
                : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  hasNewImage ? Icons.cloud_upload_rounded : Icons.save_rounded,
                  color: Colors.white,
                  size: _s(context, 21),
                ),
                SizedBox(width: _s(context, 8)),
                Text(
                  hasNewImage ? ('Save Changes & Upload Images').appTr: ('Save Changes').appTr,
                  style: TextStyle(
                    fontSize: _s(context, 14.5),
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Future<void> _submit(FamilyModel data) async {
    if (!(formKey.currentState?.validate() ?? false)) return;

    final ok = await controller.updateFamily(
      familyId: data.id,
      name: nameController.text.trim(),
      familyCode: codeController.text.trim(),
      country: countryController.text.trim(),
      notice: noticeController.text.trim(),
      description: descriptionController.text.trim(),
      joinType: joinType,
      logo: logoFile,
      cover: coverFile,
    );

    if (ok) {
      Get.back();
    }
  }

  Widget _emptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.92),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFF1E4F2)),
            boxShadow: [
              BoxShadow(
                color: _secondary.withOpacity(.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xff777782),
            ),
          ),
        ),
      ),
    );
  }
}
