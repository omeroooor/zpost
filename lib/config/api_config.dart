class ApiConfig {
  // Available API endpoints
  static const String localUrl = 'http://localhost:3050/api';
  static const String devUrl = 'http://10.0.2.2:3100/api';
  static const String prodUrl = 'https://zpost.kbunet.net/api';
  
  // Set the active base URL here
  static const String baseUrl = prodUrl;
  
  // Server base URLs (without /api path)
  static String get localServerBase => 'http://localhost:3050';
  static String get devServerBase => 'http://10.0.2.2:3100';
  static String get prodServerBase => 'https://zpost.kbunet.net';
  
  // Get the active server base URL
  static String get serverBaseUrl {
    if (baseUrl == localUrl) return localServerBase;
    if (baseUrl == devUrl) return devServerBase;
    return prodServerBase;
  }
  
  // Common API paths
  static const String authPath = '/auth';
  static const String postsPath = '/posts';
  static const String profilesPath = '/profiles';
  static const String mediaPath = '/';
  static const String socialPath = '/social';
  
  // Full endpoint URLs
  static String get authEndpoint => '$baseUrl$authPath';
  static String get postsEndpoint => '$baseUrl$postsPath';
  static String get profilesEndpoint => '$baseUrl$profilesPath';
  static String get mediaEndpoint => '$baseUrl$mediaPath';
  static String get socialEndpoint => '$baseUrl$socialPath';
  
  // Helper method to get media URL directly from server
  static String getMediaUrl(String mediaPath) {
    if (mediaPath.startsWith('http')) {
      return mediaPath;
    }
    
    // Remove any leading slashes from mediaPath to prevent double slashes
    final cleanPath = mediaPath.startsWith('/') ? mediaPath.substring(1) : mediaPath;
    return '$serverBaseUrl/$cleanPath';
  }
  
  // Helper method to get alternative media URL
  static String getAlternativeMediaUrl(String mediaPath) {
    if (mediaPath.startsWith('http')) {
      return mediaPath;
    }
    
    // Remove any leading slashes from mediaPath to prevent double slashes
    final cleanPath = mediaPath.startsWith('/') ? mediaPath.substring(1) : mediaPath;
    
    // Check if the path already includes 'uploads/' to prevent duplication
    if (cleanPath.startsWith('uploads/')) {
      return '$serverBaseUrl/$cleanPath';
    } else {
      return '$serverBaseUrl/uploads/$cleanPath';
    }
  }
}
