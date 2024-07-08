import 'dart:io';
import 'dart:convert';
import 'package:image/image.dart' as img;
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
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
    final codecName = await _getCodecInfo(filePath);
    final originalBitrate = await _getBitrate(filePath);
    final bitrate = (originalBitrate * quality).toInt();
    final extension = path.extension(filePath).toLowerCase();
    final fileNameWithoutExtension = path.basenameWithoutExtension(filePath);
    final compressedFilePath = path.join(path.dirname(filePath),
        'compressed_$fileNameWithoutExtension$extension');

    final session = await FFmpegKit.execute(
        '-y -i $filePath -c:v $codecName -b:v ${bitrate}k -maxrate ${bitrate}k -bufsize ${bitrate}k $compressedFilePath');

    final returnCode = await session.getReturnCode();
    final sessionLog = await session.getAllLogsAsString();

    if (ReturnCode.isSuccess(returnCode)) {
      print("Compression completed successfully.");
    } else {
      final failStackTrace = await session.getFailStackTrace();
      print("Compression failed with stack trace: $failStackTrace");
      print("FFmpeg Log: $sessionLog");
      throw Exception('Failed to compress video');
    }

    return compressedFilePath;
  }

  Future<String> _compressAudio(String filePath, double quality) async {
    final extension = path.extension(filePath).toLowerCase();
    final fileNameWithoutExtension = path.basenameWithoutExtension(filePath);
    final compressedFilePath = path.join(path.dirname(filePath),
        'compressed_$fileNameWithoutExtension$extension');
    final bitrate = (quality * 320).toInt();

    final session = await FFmpegKit.execute(
        '-y -i $filePath -b:a ${bitrate}k $compressedFilePath');

    final returnCode = await session.getReturnCode();
    final sessionLog = await session.getAllLogsAsString();

    if (ReturnCode.isSuccess(returnCode)) {
      print("Compression completed successfully.");
    } else {
      final failStackTrace = await session.getFailStackTrace();
      print("Compression failed with stack trace: $failStackTrace");
      print("FFmpeg Log: $sessionLog");
      throw Exception('Failed to compress audio');
    }

    return compressedFilePath;
  }

  Future<String> _getCodecInfo(String videoPath) async {
    final command = "-i $videoPath";
    final session = await FFmpegKit.execute(command);

    final logs = await session.getAllLogsAsString();
    if (logs == null) {
      throw Exception('Error getting logs from video');
    }

    return _parseCodecInfo(logs);
  }

  Future<int> _getBitrate(String videoPath) async {
    final command = "-i $videoPath";
    final session = await FFmpegKit.execute(command);

    final logs = await session.getAllLogsAsString();
    if (logs == null) {
      throw Exception('Error getting logs from video');
    }

    return _parseBitrate(logs);
  }

  String _parseCodecInfo(String output) {
    final regex = RegExp(r'Stream #0:0.*: Video: (\w+)', multiLine: true);
    final match = regex.firstMatch(output);
    if (match != null) {
      return match.group(1) ?? '';
    } else {
      throw Exception('Codec information not found');
    }
  }

  int _parseBitrate(String output) {
    final regex = RegExp(r'bitrate: (\d+) kb/s', multiLine: true);
    final match = regex.firstMatch(output);
    if (match != null) {
      return int.parse(match.group(1) ?? '0');
    } else {
      throw Exception('Bitrate information not found');
    }
  }
}
