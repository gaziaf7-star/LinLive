import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class VipMediaView extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;

  const VipMediaView({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.borderRadius,
    this.placeholder,
  });

  String get _cleanUrl => url.trim();

  String get _extension {
    if (_cleanUrl.isEmpty) return '';
    final path = Uri.tryParse(_cleanUrl)?.path ?? _cleanUrl;
    final parts = path.split('.');
    if (parts.length < 2) return '';
    return parts.last.toLowerCase().trim();
  }

  bool get _isSvga => _extension == 'svga';
  bool get _isSvg => _extension == 'svg';
  bool get _isVideo => ['mp4', 'webm', 'mov', 'mkv', 'ogg'].contains(_extension);
  bool get _isAudio => ['mp3', 'wav', 'm4a', 'aac'].contains(_extension);

  @override
  Widget build(BuildContext context) {
    final br = borderRadius ?? BorderRadius.circular(16);

    return ClipRRect(
      borderRadius: br,
      child: SizedBox(
        width: width,
        height: height,
        child: _buildChild(context),
      ),
    );
  }

  Widget _buildChild(BuildContext context) {
    if (_cleanUrl.isEmpty) {
      return placeholder ?? _fallback(icon: Icons.diamond_outlined, text: ('VIP').appTr);
    }

    if (_isSvga) {
      return Container(
        color: const Color(0xff1f1305),
        child: SVGAEasyPlayer(
          resUrl: _cleanUrl,
          fit: fit,
          useCache: true,
          isMute: true,
        ),
      );
    }

    if (_isSvg) {
      return Container(
        color: const Color(0xff1f1305),
        child: SvgPicture.network(
          _cleanUrl,
          fit: fit,
          placeholderBuilder: (_) => _loading(),
        ),
      );
    }

    if (_isVideo) {
      return _fallback(icon: Icons.play_circle_fill_rounded, text: _extension.toUpperCase());
    }

    if (_isAudio) {
      return _fallback(icon: Icons.music_note_rounded, text: _extension.toUpperCase());
    }

    return CachedNetworkImage(
      imageUrl: _cleanUrl,
      fit: fit,
      width: width,
      height: height,
      placeholder: (_, __) => _loading(),
      errorWidget: (_, __, ___) => _fallback(icon: Icons.image_not_supported_rounded, text: _extension.isEmpty ? ('IMG').appTr: _extension.toUpperCase()),
    );
  }

  Widget _loading() {
    return Container(
      alignment: Alignment.center,
      color: const Color(0xff1f1305),
      child: const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xffffd76a)),
      ),
    );
  }

  Widget _fallback({required IconData icon, required String text}) {
    return Container(
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xff3b2508), Color(0xff8b5a18), Color(0xff2c1702)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xffffd76a), size: 26),
          const SizedBox(height: 4),
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xffffd76a),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
