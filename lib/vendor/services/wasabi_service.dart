import 'dart:io';
import 'dart:typed_data';
import 'package:minio/minio.dart';
import 'package:path/path.dart' as path;
import '../constants/app_constants.dart';

/// Uploads order attachments straight from the device to Wasabi, mirroring
/// the user app's service so both produce the same `order-attachments/<key>`
/// object layout the backend expects.
class WasabiService {
  static final WasabiService _instance = WasabiService._internal();
  factory WasabiService() => _instance;
  WasabiService._internal();

  Minio? _minioClient;

  Minio get _client {
    if (_minioClient == null) {
      final endpointUri = Uri.parse(AppConstants.wasabiEndpoint);
      _minioClient = Minio(
        endPoint: 's3.${AppConstants.wasabiRegion}.wasabisys.com',
        accessKey: AppConstants.wasabiAccessKey,
        secretKey: AppConstants.wasabiSecretKey,
        useSSL: endpointUri.scheme == 'https',
        region: AppConstants.wasabiRegion,
      );
    }
    return _minioClient!;
  }

  /// Uploads [file] and returns its S3 object key (not a signed URL).
  ///
  /// Throws with the real reason on failure rather than returning null —
  /// a caller that treats "no result" as "no attachment" would silently drop
  /// the upload and give the vendor no feedback at all.
  Future<String> uploadFile({
    required File file,
    required String fileName,
  }) async {
    final objectName = 'order-attachments/$fileName';
    final contentType = _getContentType(fileName);

    final bytes = await file.readAsBytes();
    final stream = Stream<Uint8List>.value(Uint8List.fromList(bytes));

    // putObject throws on any S3/network/auth failure, so reaching the return
    // means the upload genuinely succeeded.
    await _client.putObject(
      AppConstants.wasabiBucket,
      objectName,
      stream,
      size: bytes.length,
      metadata: {'Content-Type': contentType},
    );

    return objectName;
  }

  String generateFileName({
    required String orderId,
    required String extension,
    int? index,
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    if (index != null) return '${timestamp}_$index.$extension';
    return '$timestamp.$extension';
  }

  String _getContentType(String fileName) {
    switch (path.extension(fileName).toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.m4a':
        return 'audio/m4a';
      case '.aac':
        return 'audio/aac';
      case '.mp3':
        return 'audio/mpeg';
      default:
        return 'application/octet-stream';
    }
  }
}
