part of '../popular_live_view.dart';

/// Draggable-UI (video-panel show/hide swipe) gesture handlers, and the
/// debounced setState scheduler. Extracted from _PopularLiveViewState
/// during file-splitting refactor — pure logic move only, no behavior
/// changes. Fields (_uiOffset, _isUIVisible, _uiUpdateTimer,
/// _needsUIUpdate) remain in the main state class, as Dart extensions
/// cannot declare instance fields.
extension PopularLiveUiDrag on _PopularLiveViewState {
  void _handleDragUpdate(DragUpdateDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;

    setState(() {
      _uiOffset += details.delta.dx;
      _uiOffset = _uiOffset.clamp(0.0, screenWidth);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    final velocity = details.velocity.pixelsPerSecond.dx;

    setState(() {
      // left swipe করলে show হবে
      if (velocity < -300 || _uiOffset < screenWidth * 0.7) {
        _uiOffset = 0;
        _isUIVisible = true;
      }
      // right swipe করলে hide হবে
      else {
        _uiOffset = screenWidth;
        _isUIVisible = false;
      }
    });
  }

  void _scheduleUIUpdate() {
    if (_videoExitCleanupStarted) return;
    if (_uiUpdateTimer?.isActive == true) return;

    _needsUIUpdate = true;
    _uiUpdateTimer = Timer(const Duration(milliseconds: 100), () {
      if (_needsUIUpdate && mounted) {
        setState(() {});
        _needsUIUpdate = false;
      }
    });
  }
}