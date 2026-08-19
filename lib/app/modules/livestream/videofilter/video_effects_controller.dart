import 'dart:async';

import 'package:flutter/foundation.dart';


import '../../../services/agora_service.dart';
import 'video_effect_models.dart';

class VideoEffectsController extends ChangeNotifier {
  VideoEffectsController({AgoraService? agoraService})
      : _agoraService = agoraService ?? AgoraService();

  final AgoraService _agoraService;
  Timer? _sliderDebounce;
  bool _disposed = false;

  String selectedLookId = 'smart_beauty';
  VideoEffectsSection selectedSection = VideoEffectsSection.presets;

  double lightening = .48;
  double smoothness = .50;
  double redness = .18;
  double sharpness = .38;
  double colorStrength = .24;
  double skinProtect = .50;
  double filterStrength = .36;
  AgoraLutFilter activeFilter = AgoraLutFilter.fresh;
  bool lowLight = true;
  bool denoise = true;
  bool applying = false;

  void setSection(VideoEffectsSection section) {
    selectedSection = section;
    _safeNotify();
  }

  Future<void> applyLook(VideoEffectLook look) async {
    selectedLookId = look.id;
    lightening = look.lightening;
    smoothness = look.smoothness;
    redness = look.redness;
    sharpness = look.sharpness;
    colorStrength = look.colorStrength;
    skinProtect = look.skinProtect;
    filterStrength = look.filterStrength;
    activeFilter = look.filter;
    lowLight = look.lowLight;
    denoise = look.denoise;

    applying = true;
    _safeNotify();

    try {
      if (look.id == 'none') {
        await _agoraService.resetProfessionalVideoEffects();
      } else {
        await _applyCurrent();
      }
    } finally {
      applying = false;
      _safeNotify();
    }
  }

  void updateLightening(double value) {
    lightening = value;
    _markCustomAndSchedule();
  }

  void updateSmoothness(double value) {
    smoothness = value;
    _markCustomAndSchedule();
  }

  void updateRedness(double value) {
    redness = value;
    _markCustomAndSchedule();
  }

  void updateSharpness(double value) {
    sharpness = value;
    _markCustomAndSchedule();
  }

  void updateColorStrength(double value) {
    colorStrength = value;
    _markCustomAndSchedule();
  }

  void updateSkinProtect(double value) {
    skinProtect = value;
    _markCustomAndSchedule();
  }

  void updateFilterStrength(double value) {
    filterStrength = value;
    _markCustomAndSchedule(delay: const Duration(milliseconds: 120));
  }

  Future<void> setEnhancement({
    bool? lowLightEnabled,
    bool? denoiseEnabled,
  }) async {
    if (lowLightEnabled != null) lowLight = lowLightEnabled;
    if (denoiseEnabled != null) denoise = denoiseEnabled;
    _safeNotify();
    await _applyCurrent();
  }

  void _markCustomAndSchedule({
    Duration delay = const Duration(milliseconds: 70),
  }) {
    selectedLookId = 'custom';
    _safeNotify();
    _sliderDebounce?.cancel();
    _sliderDebounce = Timer(delay, () {
      unawaited(_applyCurrent());
    });
  }

  Future<void> _applyCurrent() {
    return _agoraService.applyProfessionalVideoLook(
      lightening: lightening,
      smoothness: smoothness,
      redness: redness,
      sharpness: sharpness,
      colorStrength: colorStrength,
      skinProtect: skinProtect,
      filter: activeFilter,
      filterStrength: filterStrength,
      lowLight: lowLight,
      denoise: denoise,
    );
  }

  Future<void> resetAll() async {
    _sliderDebounce?.cancel();
    selectedLookId = 'none';
    lightening = 0;
    smoothness = 0;
    redness = 0;
    sharpness = 0;
    colorStrength = 0;
    skinProtect = 0;
    filterStrength = 0;
    activeFilter = AgoraLutFilter.none;
    lowLight = false;
    denoise = false;
    _safeNotify();
    await _agoraService.resetProfessionalVideoEffects();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sliderDebounce?.cancel();
    super.dispose();
  }
}
