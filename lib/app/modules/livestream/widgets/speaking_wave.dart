import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';

/// Lightweight speaking decoration shared by host and audience seats.
///
/// The bundled movie is decoded once for the process. Each visible speaker
/// owns only a small animation controller; stopped speakers do not keep a
/// ticker or player alive.
class SpeakingWave extends StatefulWidget {
  const SpeakingWave({super.key, required this.size});

  static const String assetPath = 'assets/audio_live/Wave.svga';
  static MovieEntity? _cachedMovie;
  static final Future<MovieEntity?> _loadingFuture = _loadMovie();

  final double size;

  static Future<void> preload() async {
    await _loadingFuture;
  }

  static Future<MovieEntity?> _loadMovie() async {
    try {
      final MovieEntity movie = await SVGAParser.shared.decodeFromAssets(
        assetPath,
      );
      // This immutable movie is intentionally retained and reused by the
      // handful of currently speaking seats. Individual controllers must not
      // dispose the shared bitmap resources.
      movie.autorelease = false;
      return _cachedMovie = movie;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Speaking wave SVGA failed to load: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      return null;
    }
  }

  @override
  State<SpeakingWave> createState() => _SpeakingWaveState();
}

class _SpeakingWaveState extends State<SpeakingWave>
    with SingleTickerProviderStateMixin {
  late final SVGAAnimationController _controller;
  bool _ready = false;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _controller = SVGAAnimationController(vsync: this)..isMute = true;
    _attachSharedMovie();
  }

  Future<void> _attachSharedMovie() async {
    final MovieEntity? movie =
        SpeakingWave._cachedMovie ?? await SpeakingWave._loadingFuture;
    if (!mounted) return;
    if (movie == null) {
      setState(() => _loadFailed = true);
      return;
    }

    _controller.videoItem = movie;
    _controller.repeat();
    setState(() => _ready = true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: OverflowBox(
        alignment: Alignment.center,
        minWidth: widget.size,
        maxWidth: widget.size,
        minHeight: widget.size,
        maxHeight: widget.size,
        child: RepaintBoundary(
          child: SizedBox.square(
            dimension: widget.size,
            child: _ready
                ? SVGAImage(
                    _controller,
                    fit: BoxFit.contain,
                    allowDrawingOverflow: false,
                    preferredSize: Size.square(widget.size),
                  )
                : _loadFailed
                ? DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.greenAccent.withValues(alpha: .72),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.greenAccent.withValues(alpha: .22),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
