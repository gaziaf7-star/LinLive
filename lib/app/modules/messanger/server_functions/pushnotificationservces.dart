class ChatNotificationState {
  ChatNotificationState._();

  static String _activeChatId = '';

  static String get activeChatId => _activeChatId;

  static void open(String chatId) {
    _activeChatId = chatId.trim();
  }

  static void close(String chatId) {
    if (_activeChatId == chatId.trim()) {
      _activeChatId = '';
    }
  }

  static bool isOpen(String chatId) {
    final clean = chatId.trim();
    return clean.isNotEmpty && clean == _activeChatId;
  }
}
