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
    final videoInfo = await getVideoInfo(filePath);
    final videoStream = videoInfo['streams']
        .firstWhere((stream) => stream['codec_type'] == 'video');
    final codecName = videoStream['codec_name'];

    String codec;
    if (codecName == 'h264') {
      codec = 'libx264';
    } else {
      codec = 'mpeg4'; // default to mpeg4 for unsupported codecs
    }

    final bitrate = (quality * 1000).toInt();
    final extension = path.extension(filePath).toLowerCase();
    final fileNameWithoutExtension = path.basenameWithoutExtension(filePath);
    final compressedFilePath = path.join(path.dirname(filePath),
        'compressed_$fileNameWithoutExtension$extension');

    final session = await FFmpegKit.execute(
        '-y -i $filePath -c:v $codec -b:v ${bitrate}k -maxrate ${bitrate}k -bufsize ${bitrate}k $compressedFilePath');

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
}

Future<Map<String, dynamic>> getVideoInfo(String filePath) async {
  getCodecInfo(filePath);
  final session = await FFmpegKit.execute('-v quiet -print_format json -show_format -show_streams "$filePath"');
  final returnCode = await session.getReturnCode();
  final sessionOutput = await session.getOutput();
  final sessionLogs = await session.getAllLogsAsString();
  final sessionFailStackTrace = await session.getFailStackTrace();

  print("FFprobe return code: $returnCode");
  print("FFprobe session output: $sessionOutput");
  print("FFprobe session logs: $sessionLogs");
  print("FFprobe fail stack trace: $sessionFailStackTrace");

  if (!ReturnCode.isSuccess(returnCode)) {
    throw Exception('Failed to get video info');
  }

  return jsonDecode(sessionOutput ?? '{}') as Map<String, dynamic>;
}

void getCodecInfo(String videoPath) {
  String command = "-i $videoPath";

  FFmpegKit.execute(command).then((session) async {
    final returnCode = await session.getReturnCode();
    final output = await session.getLogsAsString();

    if (ReturnCode.isSuccess(returnCode)) {
      // Command executed successfully, parse the output for codec info
      final codecInfo = parseCodecInfo(output);
      print("Codec Info: $codecInfo");
    } else {
      // Command failed, handle the error
      print("FFmpeg command failed with return code: $returnCode");
    }
  }).catchError((error) {
    print("Error executing FFmpeg command: $error");
  });
}

String parseCodecInfo(String output) {
  // Parsing logic to extract codec information
  final regex = RegExp(r'Stream #0:0.*: Video: (\w+)', multiLine: true);
  final match = regex.firstMatch(output);
  if (match != null) {
    return match.group(1) ?? 'Unknown codec';
  } else {
    return 'Codec information not found';
  }
}





