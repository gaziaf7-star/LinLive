import 'dart:async';
import 'dart:math' as math;

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/agora_service.dart';

/// Responsive voice mixer for audio live rooms.
///
/// The sheet keeps its own bottom safe-area padding so it never sits under
/// Android's gesture/navigation bar. System back closes only this sheet.
class VoiceMixerBottomSheet extends StatefulWidget {
  const VoiceMixerBottomSheet({
    super.key,
    this.rtcEngine,
  });

  final RtcEngine? rtcEngine;

  static Future<void> show(
      BuildContext context, {
        RtcEngine? rtcEngine,
      }) async {
    FocusManager.instance.primaryFocus?.unfocus();

    // Always resolve the app/root navigator context before opening the sheet.
    // The caller can come from another bottom sheet that is being dismissed;
    // using that old element causes MediaQuery null-context crashes.
    final NavigatorState rootNavigator = Navigator.of(
      context,
      rootNavigator: true,
    );
    if (!rootNavigator.mounted) return;
    final BuildContext safeRootContext = rootNavigator.context;

    await showModalBottomSheet<void>(
      context: safeRootContext,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(.46),
      builder: (sheetContext) {
        final MediaQueryData media = MediaQuery.of(sheetContext);
        final double systemBottom = math.max(
          media.padding.bottom,
          media.viewPadding.bottom,
        );
        final double heightFactor;
        if (media.size.height < 620) {
          heightFactor = .90;
        } else if (media.size.height < 760) {
          heightFactor = .84;
        } else {
          heightFactor = .78;
        }

        return Padding(
          padding: EdgeInsets.only(bottom: systemBottom),
          child: FractionallySizedBox(
            heightFactor: heightFactor,
            widthFactor: 1,
            alignment: Alignment.bottomCenter,
            child: VoiceMixerBottomSheet(rtcEngine: rtcEngine),
          ),
        );
      },
    );
  }

  @override
  State<VoiceMixerBottomSheet> createState() =>
      _VoiceMixerBottomSheetState();
}

class _VoiceMixerBottomSheetState extends State<VoiceMixerBottomSheet> {
  static double _savedMicVolume = 100;
  static int _savedMusicIndex = 0;
  static int _savedEqualizerIndex = 0;
  static int _savedVoiceIndex = 0;

  late double _micVolume;
  bool _previewEnabled = false;
  bool _applying = false;
  late int _selectedMusicIndex;
  late int _selectedEqualizerIndex;
  late int _selectedVoiceIndex;
  Timer? _volumeDebounce;

  RtcEngine? get _engine => widget.rtcEngine ?? AgoraService().engine;

  static const Color _accent = Color(0xff19D2C5);
  static const Color _textPrimary = Color(0xff34353B);
  static const Color _textSecondary = Color(0xff92939A);

  final List<_MixerChoice> _musicEffects = const <_MixerChoice>[
    _MixerChoice(
      title: 'Original',
      icon: Icons.block_rounded,
      colors: <Color>[Color(0xffF7F8FA), Color(0xffE9EBEF)],
      audioPreset: AudioEffectPreset.audioEffectOff,
      isNone: true,
    ),
    _MixerChoice(
      title: 'Reverb',
      icon: Icons.surround_sound_rounded,
      colors: <Color>[Color(0xff23B9E8), Color(0xff5939D8)],
      audioPreset: AudioEffectPreset.roomAcousticsStudio,
    ),
    _MixerChoice(
      title: 'Live\nConcert',
      icon: Icons.festival_rounded,
      colors: <Color>[Color(0xffFF7C23), Color(0xffEE2F49)],
      audioPreset: AudioEffectPreset.roomAcousticsVocalConcert,
    ),
    _MixerChoice(
      title: 'KTV',
      icon: Icons.mic_external_on_rounded,
      colors: <Color>[Color(0xff7B184E), Color(0xff32114C)],
      audioPreset: AudioEffectPreset.roomAcousticsKtv,
    ),
    _MixerChoice(
      title: 'Ethereal',
      icon: Icons.auto_awesome_rounded,
      colors: <Color>[Color(0xffFFE1C2), Color(0xffD89A70)],
      audioPreset: AudioEffectPreset.roomAcousticsEthereal,
    ),
    _MixerChoice(
      title: 'Concert\nHall',
      icon: Icons.piano_rounded,
      colors: <Color>[Color(0xffB76338), Color(0xff4A241A)],
      audioPreset: AudioEffectPreset.roomAcousticsSpacial,
    ),
  ];

  final List<_MixerChoice> _equalizerEffects = const <_MixerChoice>[
    _MixerChoice(
      title: 'None',
      icon: Icons.block_rounded,
      colors: <Color>[Color(0xffF7F8FA), Color(0xffE9EBEF)],
      audioPreset: AudioEffectPreset.audioEffectOff,
      isNone: true,
    ),
    _MixerChoice(
      title: 'Custom',
      icon: Icons.graphic_eq_rounded,
      colors: <Color>[Color(0xff7A2F8F), Color(0xffF06951)],
      audioPreset: AudioEffectPreset.styleTransformationRnb,
    ),
    _MixerChoice(
      title: 'Electronic',
      icon: Icons.electric_bolt_rounded,
      colors: <Color>[Color(0xff922CD0), Color(0xff2B1669)],
      audioPreset: AudioEffectPreset.pitchCorrection,
    ),
    _MixerChoice(
      title: 'Rock',
      icon: Icons.music_note_rounded,
      colors: <Color>[Color(0xffA44BE8), Color(0xffE6427F)],
      audioPreset: AudioEffectPreset.styleTransformationPopular,
    ),
    _MixerChoice(
      title: 'Bass',
      icon: Icons.speaker_rounded,
      colors: <Color>[Color(0xffD74A30), Color(0xff53251F)],
      audioPreset: AudioEffectPreset.roomAcousticsPhonograph,
    ),
    _MixerChoice(
      title: 'Jazz',
      icon: Icons.music_note_rounded,
      colors: <Color>[Color(0xffFF8B8B), Color(0xffF23C7D)],
      audioPreset: AudioEffectPreset.roomAcousticsVirtualStereo,
    ),
  ];

  final List<_MixerChoice> _voiceEffects = const <_MixerChoice>[
    _MixerChoice(
      title: 'None',
      icon: Icons.block_rounded,
      colors: <Color>[Color(0xffF7F8FA), Color(0xffE9EBEF)],
      conversionPreset: VoiceConversionPreset.voiceConversionOff,
      isNone: true,
    ),
    _MixerChoice(
      title: 'Female\nVoice',
      icon: Icons.face_3_rounded,
      colors: <Color>[Color(0xffFF91C8), Color(0xffA943C5)],
      // Dedicated male-to-girlish conversion. This is much more suitable
      // than the old generic Sister audio-effect preset.
      conversionPreset: VoiceConversionPreset.voiceChangerGirlishMan,
    ),
    _MixerChoice(
      title: 'Male\nVoice',
      icon: Icons.face_6_rounded,
      colors: <Color>[Color(0xff4B8DFF), Color(0xff243B82)],
      // Clear/steady male timbre instead of an over-deep distorted preset.
      conversionPreset: VoiceConversionPreset.voiceChangerSolid,
    ),
    _MixerChoice(
      title: 'Deep\nMale',
      icon: Icons.record_voice_over_rounded,
      colors: <Color>[Color(0xff3258A8), Color(0xff17254F)],
      conversionPreset: VoiceConversionPreset.voiceChangerBass,
    ),
    _MixerChoice(
      title: 'Sweet\nVoice',
      icon: Icons.favorite_rounded,
      colors: <Color>[Color(0xffF176B5), Color(0xff8F3EA8)],
      conversionPreset: VoiceConversionPreset.voiceChangerSweet,
    ),
    _MixerChoice(
      title: 'Child\nVoice',
      icon: Icons.child_care_rounded,
      colors: <Color>[Color(0xffFFD96B), Color(0xffD6A931)],
      conversionPreset: VoiceConversionPreset.voiceChangerChildlike,
    ),
    _MixerChoice(
      title: 'Cartoon',
      icon: Icons.emoji_emotions_rounded,
      colors: <Color>[Color(0xffF08A5D), Color(0xffB83B5E)],
      conversionPreset: VoiceConversionPreset.voiceChangerCartoon,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _micVolume = _savedMicVolume;
    _selectedMusicIndex = _savedMusicIndex;
    _selectedEqualizerIndex = _savedEqualizerIndex;
    _selectedVoiceIndex = _savedVoiceIndex;
  }

  @override
  void dispose() {
    _volumeDebounce?.cancel();
    if (_previewEnabled) {
      unawaited(_setPreview(false, updateUi: false));
    }
    super.dispose();
  }

  Future<void> _setRecordingVolume(int value) async {
    final RtcEngine? engine = _engine;
    if (engine == null) return;

    try {
      await engine.adjustRecordingSignalVolume(
        value.clamp(0, 100).toInt(),
      );
    } catch (error) {
      debugPrint('Voice mixer volume failed: $error');
    }
  }

  void _scheduleRecordingVolume(double value) {
    _volumeDebounce?.cancel();
    _volumeDebounce = Timer(const Duration(milliseconds: 90), () {
      unawaited(_setRecordingVolume(value.round()));
    });
  }

  Future<void> _resetVolume() async {
    setState(() => _micVolume = 100);
    _savedMicVolume = 100;
    await _setRecordingVolume(100);
  }

  Future<void> _setPreview(
      bool enabled, {
        bool updateUi = true,
      }) async {
    final RtcEngine? rtcEngine = _engine;
    if (rtcEngine == null) {
      if (updateUi && mounted) {
        Fluttertoast.showToast(msg: 'Agora audio is not ready');
      }
      return;
    }

    if (updateUi && mounted) {
      setState(() => _previewEnabled = enabled);
    }

    final dynamic engine = rtcEngine;
    try {
      await engine.enableInEarMonitoring(
        enabled: enabled,
        includeAudioFilters: true,
      );
    } catch (_) {
      try {
        await engine.enableInEarMonitoring(enabled: enabled);
      } catch (error) {
        if (updateUi && mounted) {
          setState(() => _previewEnabled = false);
          Fluttertoast.showToast(
            msg: 'Preview is not supported on this device',
          );
        }
        debugPrint('Voice mixer preview failed: $error');
      }
    }
  }

  Future<void> _resetAllVoiceEffects(RtcEngine engine) async {
    // Agora supports only one vocal preset at a time. Reset every preset family
    // first so an old music/voice preset cannot distort the next selection.
    await engine.setAudioEffectPreset(AudioEffectPreset.audioEffectOff);
    await engine.setVoiceBeautifierPreset(
      VoiceBeautifierPreset.voiceBeautifierOff,
    );
    await engine.setVoiceConversionPreset(
      VoiceConversionPreset.voiceConversionOff,
    );

    // Restore custom voice controls to Agora's real natural/original defaults.
    // Pitch default = 1.0 (no pitch change).
    // Formant default = 0.0 (no timbre change).
    //
    // IMPORTANT:
    // The old code used setLocalVoiceFormant(1.0). Agora's formant range is
    // [-1.0, 1.0], and 1.0 is a strong/sharp voice transformation, NOT the
    // original voice. That is why selecting Original/None did not restore the
    // user's natural microphone voice after using Female/Male/etc.
    await engine.setLocalVoicePitch(1.0);
    try {
      await engine.setLocalVoiceFormant(0.0);
    } catch (_) {
      // Some older native builds may not expose formant tuning.
    }
  }

  Future<void> _applyPreset({
    required _MixerSection section,
    required int index,
    required _MixerChoice choice,
  }) async {
    if (_applying) return;

    setState(() {
      _applying = true;
      if (choice.isNone) {
        _selectedMusicIndex = 0;
        _selectedEqualizerIndex = 0;
        _selectedVoiceIndex = 0;
      } else {
        switch (section) {
          case _MixerSection.music:
            _selectedMusicIndex = index;
            _selectedEqualizerIndex = 0;
            _selectedVoiceIndex = 0;
            break;
          case _MixerSection.equalizer:
            _selectedMusicIndex = 0;
            _selectedEqualizerIndex = index;
            _selectedVoiceIndex = 0;
            break;
          case _MixerSection.voice:
            _selectedMusicIndex = 0;
            _selectedEqualizerIndex = 0;
            _selectedVoiceIndex = index;
            break;
        }
      }
    });

    _savedMusicIndex = _selectedMusicIndex;
    _savedEqualizerIndex = _selectedEqualizerIndex;
    _savedVoiceIndex = _selectedVoiceIndex;

    final RtcEngine? engine = _engine;
    if (engine == null) {
      if (mounted) setState(() => _applying = false);
      Fluttertoast.showToast(msg: 'Agora audio is not ready');
      return;
    }

    try {
      await _resetAllVoiceEffects(engine);

      if (!choice.isNone) {
        if (section == _MixerSection.voice &&
            choice.conversionPreset != null) {
          await engine.setVoiceConversionPreset(choice.conversionPreset!);
        } else if (choice.audioPreset != null) {
          await engine.setAudioEffectPreset(choice.audioPreset!);
        }
      }

      debugPrint(
        'Voice mixer effect applied => section=$section title=${choice.title}',
      );
    } catch (error) {
      debugPrint('Voice mixer preset failed: $error');
      Fluttertoast.showToast(msg: 'Unable to apply this voice effect');
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final double bottomSafe = math.max(
      media.padding.bottom,
      media.viewPadding.bottom,
    );

    return PopScope(
      canPop: true,
      child: Material(
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: ColoredBox(
            color: Colors.white,
            child: SafeArea(
              top: false,
              bottom: false,
              child: Column(
                children: <Widget>[
                  _buildHeader(context),
                  Expanded(
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: <Widget>[
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            22,
                            10,
                            22,
                            bottomSafe + 18,
                          ),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate.fixed(
                              <Widget>[
                                _buildVolumeSection(),
                                const SizedBox(height: 18),
                                _buildPreviewSection(),
                                const SizedBox(height: 18),
                                _buildSection(
                                  title: 'Music Effects',
                                  choices: _musicEffects,
                                  selectedIndex: _selectedMusicIndex,
                                  section: _MixerSection.music,
                                ),
                                const SizedBox(height: 18),
                                _buildSection(
                                  title: 'Equalizer',
                                  choices: _equalizerEffects,
                                  selectedIndex: _selectedEqualizerIndex,
                                  section: _MixerSection.equalizer,
                                ),
                                const SizedBox(height: 18),
                                _buildSection(
                                  title: 'Voice changer',
                                  choices: _voiceEffects,
                                  selectedIndex: _selectedVoiceIndex,
                                  section: _MixerSection.voice,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 64,
      padding: const EdgeInsets.fromLTRB(18, 7, 8, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.black.withOpacity(.045)),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Positioned(
            top: 0,
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xffD9DADF),
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
          Text(
            'Mixer',
            style: GoogleFonts.poppins(
              color: _textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          Positioned(
            right: 0,
            top: 7,
            child: Material(
              color: const Color(0xffF2F3F6),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.of(context).maybePop(),
                child: const SizedBox(
                  width: 42,
                  height: 42,
                  child: Icon(
                    Icons.close_rounded,
                    color: _textPrimary,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
          if (_applying)
            const Positioned(
              left: 0,
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _accent,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVolumeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Mic Volume',
                style: _sectionTitleStyle,
              ),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _resetVolume,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 5,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.refresh_rounded,
                      color: _textSecondary,
                      size: 25,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Volume Reset',
                      style: GoogleFonts.poppins(
                        color: _textSecondary,
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: <Widget>[
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: _accent,
                  inactiveTrackColor: const Color(0xffE6E8EC),
                  thumbColor: _accent,
                  overlayColor: _accent.withOpacity(.13),
                  trackHeight: 5,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 8,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 18,
                  ),
                ),
                child: Slider(
                  min: 0,
                  max: 100,
                  value: _micVolume,
                  onChanged: (double value) {
                    setState(() => _micVolume = value);
                    _savedMicVolume = value;
                    _scheduleRecordingVolume(value);
                  },
                  onChangeEnd: (double value) {
                    unawaited(_setRecordingVolume(value.round()));
                  },
                ),
              ),
            ),
            SizedBox(
              width: 48,
              child: Text(
                _micVolume.round().toString(),
                textAlign: TextAlign.right,
                style: GoogleFonts.poppins(
                  color: _textSecondary,
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPreviewSection() {
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Preview', style: _sectionTitleStyle),
              const SizedBox(height: 4),
              Text(
                'Preview the tuned sound effect.',
                style: GoogleFonts.poppins(
                  color: _textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        Transform.scale(
          scale: .92,
          child: Switch.adaptive(
            value: _previewEnabled,
            activeColor: _accent,
            onChanged: (bool value) => unawaited(_setPreview(value)),
          ),
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required List<_MixerChoice> choices,
    required int selectedIndex,
    required _MixerSection section,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: _sectionTitleStyle),
        const SizedBox(height: 11),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double visibleItems =
            constraints.maxWidth < 345 ? 4.85 : 5.75;
            final double itemWidth =
            (constraints.maxWidth / visibleItems).clamp(52.0, 72.0);
            final double circleSize =
            (itemWidth - 8).clamp(44.0, 56.0);

            return SizedBox(
              height: circleSize + 45,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: choices.length,
                separatorBuilder: (_, __) => const SizedBox(width: 2),
                itemBuilder: (BuildContext context, int index) {
                  final _MixerChoice choice = choices[index];
                  return SizedBox(
                    width: itemWidth,
                    child: _buildChoice(
                      choice: choice,
                      circleSize: circleSize,
                      selected: index == selectedIndex,
                      onTap: () => _applyPreset(
                        section: section,
                        index: index,
                        choice: choice,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildChoice({
    required _MixerChoice choice,
    required double circleSize,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _applying ? null : onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: circleSize,
            height: circleSize,
            padding: EdgeInsets.all(selected ? 3 : 0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? _accent : Colors.transparent,
              boxShadow: selected
                  ? <BoxShadow>[
                BoxShadow(
                  color: _accent.withOpacity(.23),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
                  : const <BoxShadow>[],
            ),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: choice.colors,
                ),
                border: Border.all(
                  color: choice.isNone
                      ? const Color(0xffE1E3E7)
                      : Colors.white.withOpacity(.35),
                  width: 1,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Icon(
                    choice.icon,
                    color: choice.isNone
                        ? const Color(0xffCDD0D6)
                        : Colors.white,
                    size: circleSize * (choice.isNone ? .46 : .50),
                  ),
                  if (choice.isNone)
                    Transform.rotate(
                      angle: -.73,
                      child: Container(
                        width: circleSize * .55,
                        height: 2,
                        decoration: BoxDecoration(
                          color: const Color(0xffD4D6DB),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Flexible(
            child: Text(
              choice.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: selected ? _textPrimary : _textSecondary,
                fontSize: 11.5,
                height: 1.2,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  TextStyle get _sectionTitleStyle => GoogleFonts.poppins(
    color: _textPrimary,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );
}

enum _MixerSection { music, equalizer, voice }

class _MixerChoice {
  const _MixerChoice({
    required this.title,
    required this.icon,
    required this.colors,
    this.audioPreset,
    this.conversionPreset,
    this.isNone = false,
  }) : assert(
  audioPreset != null || conversionPreset != null || isNone,
  'A mixer choice needs an audio or conversion preset',
  );

  final String title;
  final IconData icon;
  final List<Color> colors;
  final AudioEffectPreset? audioPreset;
  final VoiceConversionPreset? conversionPreset;
  final bool isNone;
}
