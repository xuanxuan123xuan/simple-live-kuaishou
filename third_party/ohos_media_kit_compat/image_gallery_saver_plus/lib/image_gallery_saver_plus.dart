import 'dart:typed_data';

class ImageGallerySaverPlus {
  static Future<Map<String, dynamic>> saveImage(
    Uint8List imageBytes, {
    int quality = 80,
    String? name,
    bool isReturnImagePathOfIOS = false,
  }) async {
    return <String, dynamic>{
      'isSuccess': false,
      'errorMessage': 'image_gallery_saver_plus is not available on OHOS shim',
    };
  }
}