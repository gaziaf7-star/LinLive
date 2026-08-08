import '../apis/api_endpoints.dart';

/// Helper class for handling image URLs
class ImageHelper {
  /// Returns the complete image URL
  /// If the image URL starts with 'http', returns it as is
  /// Otherwise, prepends the domain URL
  static String getImageUrl(String? imageUrl) {
    // Handle null or empty strings
    if (imageUrl == null || imageUrl.isEmpty) {
      return '';
    }
    
    // If URL already starts with http or https, return as is
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return imageUrl;
    }
    
    // Otherwise, prepend domain URL
    return '$kDomainUrl/$imageUrl';
  }
  
  /// Returns the complete image URL with fallback
  /// If the image URL is null/empty, returns the fallback URL
  static String getImageUrlWithFallback(String? imageUrl, String fallbackUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return fallbackUrl;
    }
    
    return getImageUrl(imageUrl);
  }
}