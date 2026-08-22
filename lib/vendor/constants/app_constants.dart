class AppConstants {
  static const String appName = 'sadat delivery vendor';
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'https://delivery-sadatcity.duckdns.org/api',
  );
  static const String tenantId = 'SADAT';

  // API Endpoints
  static const String loginEndpoint = '/auth/login/vendor';
  static const String signupEndpoint = '/auth/signup/vendor';
  static const String refreshTokenEndpoint = '/auth/refresh-token';
  static const String logoutEndpoint = '/auth/logout';
  static const String deleteAccountEndpoint = '/vendors/account';

  // Vendor Endpoints
  static const String vendorProfileEndpoint = '/vendors/profile';
  static const String vendorStatusEndpoint = '/vendors/status';

  // Menu Endpoints
  static const String menusEndpoint = '/menus';
  static const String menuStatsEndpoint = '/menus/stats';

  static const String itemsEndpoint = '/items';

  // Order Endpoints
  static const String vendorOrdersEndpoint = '/vendors/orders'; // for fetching
  static const String createOrderByVendorEndpoint = '/orders/create-by-vendor';
  static const String ordersEndpoint = '/orders';
  static const String fcmTokenEndpoint = '/vendors/fcm-token';

  // Storage Keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userDataKey = 'user_data';
  static const String languageKey = 'language';
  static const String themeKey = 'theme';

  // Regex Patterns
  static const String phoneRegex = r'^\+?[0-9]{10,15}$';
  static const String emailRegex =
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';

  // Validation
  static const int minPasswordLength = 6;
  static const int maxPasswordLength = 50;
  static const int minNameLength = 2;
  static const int maxNameLength = 100;
  static const int maxAddressLength = 200;
  static const int maxDescriptionLength = 500;

  // Timeouts
  static const int connectionTimeout = 30; // seconds
  static const int receiveTimeout = 30; // seconds

  // Image
  static const int maxImageSize = 5 * 1024 * 1024; // 5MB
  static const List<String> allowedImageTypes = ['jpg', 'jpeg', 'png'];

  // Location
  static const double locationAccuracy = 100.0; // meters
  static const int locationTimeout = 30; // seconds

  // Wasabi S3 Configuration
  // Mirrors the user app's config: attachments are uploaded straight from the
  // device to the bucket, so the app needs the keys. Note these ship inside
  // the APK and grant full bucket access — the durable fix is a backend-issued
  // pre-signed upload URL (wasabiService.generatePreSignedUrl already exists
  // server-side), which would keep the credentials off the device entirely.
  static const String wasabiAccessKey = 'RM7Z7JVNTNZ5CBI4BGKH';
  static const String wasabiSecretKey =
      'O0l5jOmAQHaAOOenncAdeWDHvvouv9GhJP5zD3fB';
  static const String wasabiBucket = 'deliveryapp';
  static const String wasabiEndpoint = 'https://s3.wasabisys.com';
  static const String wasabiRegion = 'eu-south-1';

  // Attachment Constraints
  static const int maxImages = 5;
  static const int maxVoiceNoteDuration = 300; // 5 minutes in seconds
  static const int maxImageSizeMB = 5;
  static const int maxVoiceNoteSizeMB = 10;
}
