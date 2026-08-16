class AppThemeModel {
  const AppThemeModel({
    this.backgroundImage,
    this.footerImage,
    this.homeIcon,
    this.momentIcon,
    this.videoIcon,
    this.messageIcon,
    this.profileIcon,
  });

  final String? backgroundImage;
  final String? footerImage;
  final String? homeIcon;
  final String? momentIcon;
  final String? videoIcon;
  final String? messageIcon;
  final String? profileIcon;

  factory AppThemeModel.fromJson(Map<String, dynamic> json) {
    return AppThemeModel(
      backgroundImage: normalizeThemeUrl(json['background_image']),
      footerImage: normalizeThemeUrl(json['footer_image']),
      homeIcon: normalizeThemeUrl(json['home_icon']),
      momentIcon: normalizeThemeUrl(json['moment_icon']),
      videoIcon: normalizeThemeUrl(json['video_icon']),
      messageIcon: normalizeThemeUrl(json['message_icon']),
      profileIcon: normalizeThemeUrl(json['profile_icon']),
    );
  }

  bool get hasAnyImage => imageUrls.isNotEmpty;

  List<String> changedUrlsFrom(AppThemeModel? previous) {
    final List<String> changed = <String>[];
    void addIfChanged(String? current, String? old) {
      if (current != null && current != old) changed.add(current);
    }

    addIfChanged(backgroundImage, previous?.backgroundImage);
    addIfChanged(footerImage, previous?.footerImage);
    addIfChanged(homeIcon, previous?.homeIcon);
    addIfChanged(momentIcon, previous?.momentIcon);
    addIfChanged(videoIcon, previous?.videoIcon);
    addIfChanged(messageIcon, previous?.messageIcon);
    addIfChanged(profileIcon, previous?.profileIcon);
    return changed;
  }

  bool hasSameUrls(AppThemeModel other) =>
      backgroundImage == other.backgroundImage &&
      footerImage == other.footerImage &&
      homeIcon == other.homeIcon &&
      momentIcon == other.momentIcon &&
      videoIcon == other.videoIcon &&
      messageIcon == other.messageIcon &&
      profileIcon == other.profileIcon;

  List<String> get imageUrls => <String?>[
    backgroundImage,
    footerImage,
    homeIcon,
    momentIcon,
    videoIcon,
    messageIcon,
    profileIcon,
  ].whereType<String>().toList(growable: false);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'background_image': backgroundImage,
    'footer_image': footerImage,
    'home_icon': homeIcon,
    'moment_icon': momentIcon,
    'video_icon': videoIcon,
    'message_icon': messageIcon,
    'profile_icon': profileIcon,
  };
}

String? normalizeThemeUrl(dynamic value) {
  String url = value?.toString().trim() ?? '';
  if (url.isEmpty || url.toLowerCase() == 'null') return null;

  final RegExpMatch? markdownMatch = RegExp(
    r'^\[[^\]]*\]\((https?://[^)]+)\)$',
    caseSensitive: false,
  ).firstMatch(url);
  if (markdownMatch != null) {
    url = markdownMatch.group(1)?.trim() ?? '';
  }

  final Uri? uri = Uri.tryParse(url);
  if (uri == null ||
      !(uri.isScheme('http') || uri.isScheme('https')) ||
      uri.host.isEmpty) {
    return null;
  }
  return uri.toString();
}
