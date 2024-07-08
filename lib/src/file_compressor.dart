import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:path/path.dart' as path;

enum CompressionType { image, video, audio }

class FileCompressor {
  Future<String> compressFile({
    required String filePath,
    required double quality,
    required CompressionType compressionType,
    bool maintainAspectRatio = true,
  }) async {
    switch (compressionType) {
      case CompressionType.image:
        return _compressImage(filePath, quality, maintainAspectRatio);
      case CompressionType.video:
        return _compressVideo(filePath, quality);
      case CompressionType.audio:
        return _compressAudio(filePath, quality);
      default:
        throw UnsupportedError('Unsupported compression type');
    }
  }

  Future<String> _compressImage(
      String filePath, double quality, bool maintainAspectRatio) async {
    final image = img.decodeImage(File(filePath).readAsBytesSync());
    if (image == null) throw Exception('Failed to decode image');

    final resizedImage = img.copyResize(
      image,
      width: (image.width * quality).toInt(),
      height: maintainAspectRatio ? null : (image.height * quality).toInt(),
    );

    final extension = path.extension(filePath).toLowerCase();
    final fileNameWithoutExtension = path.basenameWithoutExtension(filePath);
    final compressedFilePath = path.join(path.dirname(filePath),
        'compressed_$fileNameWithoutExtension$extension');

    final compressedFile = File(compressedFilePath);
    final bytes = img.encodeNamedImage(compressedFilePath, resizedImage);
    if (bytes == null) throw UnsupportedError('Unsupported image format');

    compressedFile.writeAsBytesSync(bytes);

    return compressedFile.path;
  }

  Future<String> _compressVideo(String filePath, double quality) async {
    final extension = path.extension(filePath).toLowerCase();
    final fileNameWithoutExtension = path.basenameWithoutExtension(filePath);
    final compressedFilePath = path.join(path.dirname(filePath),
        'compressed_$fileNameWithoutExtension$extension');
    final int bitrate = (quality * 1000).toInt();

    await FFmpegKit.execute(
        '-i $filePath -b:v ${bitrate}k -bufsize ${bitrate}k $compressedFilePath');

    return compressedFilePath;
  }

  Future<String> _compressAudio(String filePath, double quality) async {
    final extension = path.extension(filePath).toLowerCase();
    final fileNameWithoutExtension = path.basenameWithoutExtension(filePath);
    final compressedFilePath = path.join(path.dirname(filePath),
        'compressed_$fileNameWithoutExtension$extension');
    final int bitrate = (quality * 320).toInt();

    await FFmpegKit.execute(
        '-i $filePath -b:a ${bitrate}k $compressedFilePath');

    return compressedFilePath;
  }
}
