import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/return_code.dart';
import 'package:path/path.dart' as path;

enum CompressionType { image, video, audio }

enum ResizingOption {
  maintainAspectRatio,
  ignoreAspectRatio,
  stretchToFill,
  centerCrop,
  customScaling,
}

class FileCompressor {
  /// Compresses a file at [filePath] with the given [quality] and [compressionType].
  /// Additional options for [CompressionType.image] include [maintainAspectRatio] and custom resizing options.
  Future<String> compressFile({
    required String filePath,
    required double quality,
    required CompressionType compressionType,
    ResizingOption resizingOption = ResizingOption.maintainAspectRatio,
    double widthScaleFactor = 1.0,
    double heightScaleFactor = 1.0,
  }) async {
    switch (compressionType) {
      case CompressionType.image:
        return _compressImage(
          filePath: filePath,
          quality: quality,
          resizingOption: resizingOption,
          widthScaleFactor: widthScaleFactor,
          heightScaleFactor: heightScaleFactor,
        );
      case CompressionType.video:
        return _compressVideo(filePath: filePath, quality: quality);
      case CompressionType.audio:
        return _compressAudio(filePath: filePath, quality: quality);
      default:
        throw UnsupportedError('Unsupported compression type');
    }
  }

  /// Compresses an image file at [filePath] with the given [quality].
  /// Uses the specified [resizingOption] for resizing the image.
  Future<String> _compressImage({
    required String filePath,
    required double quality,
    ResizingOption resizingOption = ResizingOption.maintainAspectRatio,
    double widthScaleFactor = 1.0,
    double heightScaleFactor = 1.0,
  }) async {
    final image = img.decodeImage(File(filePath).readAsBytesSync());
    if (image == null) throw Exception('Failed to decode image');

    img.Image resizedImage;

    switch (resizingOption) {
      case ResizingOption.maintainAspectRatio:
        resizedImage = img.copyResize(
          image,
          width: (image.width * quality).toInt(),
          height: null,
        );
        break;
      case ResizingOption.ignoreAspectRatio:
        resizedImage = img.copyResize(
          image,
          width: (image.width * quality).toInt(),
          height: (image.height * quality).toInt(),
        );
        break;
      case ResizingOption.stretchToFill:
        resizedImage = img.copyResize(
          image,
          width: (image.width * quality).toInt(),
          height: (image.height * quality).toInt(),
        );
        break;
      case ResizingOption.centerCrop:
        final size = (image.width * quality).toInt();
        resizedImage = img.copyResizeCropSquare(
          image,
          size: size,
        );
        break;
      case ResizingOption.customScaling:
        resizedImage = img.copyResize(
          image,
          width: (image.width * widthScaleFactor).toInt(),
          height: (image.height * heightScaleFactor).toInt(),
        );
        break;
    }

    final extension = path.extension(filePath).toLowerCase();
    final fileNameWithoutExtension = path.basenameWithoutExtension(filePath);
    final compressedFilePath = path.join(path.dirname(filePath), 'compressed_$fileNameWithoutExtension$extension');

    final compressedFile = File(compressedFilePath);
    final bytes = img.encodeNamedImage(compressedFilePath, resizedImage);
    if (bytes == null) throw UnsupportedError('Unsupported image format');

    compressedFile.writeAsBytesSync(bytes);

    return compressedFile.path;
  }

  /// Compresses a video file at [filePath] with the given [quality].
  Future<String> _compressVideo({required String filePath, required double quality}) async {
    final codecName = await _getVideoCodec(filePath);
    final originalBitrate = await _getBitrate(filePath, 'Video');
    final bitrate = (originalBitrate * quality).toInt();

    final extension = path.extension(filePath).toLowerCase();
    final fileNameWithoutExtension = path.basenameWithoutExtension(filePath);
    final compressedFilePath = path.join(path.dirname(filePath), 'compressed_$fileNameWithoutExtension$extension');

    final session = await FFmpegKit.execute(
        '-y -i $filePath -c:v $codecName -b:v ${bitrate}k -maxrate ${bitrate}k -bufsize ${bitrate}k $compressedFilePath');

    final returnCode = await session.getReturnCode();
    final sessionLog = await session.getAllLogsAsString();

    if (ReturnCode.isSuccess(returnCode)) {
      return compressedFilePath;
    } else {
      final failStackTrace = await session.getFailStackTrace();
      throw Exception([
        "Failed to compress video",
        "FFmpeg Log: $sessionLog",
        "Compression failed with stack trace: $failStackTrace"
      ].join("\n"));
    }
  }

  /// Compresses an audio file at [filePath] with the given [quality].
  Future<String> _compressAudio({required String filePath, required double quality}) async {
    final extension = path.extension(filePath).toLowerCase();
    final fileNameWithoutExtension = path.basenameWithoutExtension(filePath);
    final compressedFilePath = path.join(path.dirname(filePath), 'compressed_$fileNameWithoutExtension$extension');

    final codecName = _getAudioCodec(extension);
    final originalBitrate = await _getBitrate(filePath, 'Audio');
    final bitrate = (originalBitrate * quality).toInt();

    final session = await FFmpegKit.execute(
        '-y -i $filePath -c:a $codecName -b:a ${bitrate}k $compressedFilePath');

    final returnCode = await session.getReturnCode();
    final sessionLog = await session.getAllLogsAsString();

    if (ReturnCode.isSuccess(returnCode)) {
      return compressedFilePath;
    } else {
      final failStackTrace = await session.getFailStackTrace();
      throw Exception([
        "Failed to compress audio",
        "FFmpeg Log: $sessionLog",
        "Compression failed with stack trace: $failStackTrace"
      ].join("\n"));
    }
  }

  /// Retrieves codec information for video by the given [filePath].
  Future<String> _getVideoCodec(String filePath) async {
    final command = "-i $filePath";
    final session = await FFmpegKit.execute(command);

    final logs = await session.getAllLogsAsString();
    if (logs == null) {
      throw Exception('Error executing logs from video');
    }

    return _parseCodecInfo(logs, 'Video');
  }

  /// Returns the appropriate audio codec based on the file [extension].
  String _getAudioCodec(String extension) {
    switch (extension) {
      case '.mp3':
        return 'libmp3lame';
      case '.aac':
        return 'aac';
      case '.wav':
        return 'pcm_s16le'; // WAV typically uses PCM
      case '.ogg':
        return 'libvorbis';
      case '.flac':
        return 'flac';
      default:
        throw UnsupportedError('Unsupported audio format: $extension');
    }
  }

  /// Parses codec information from the FFmpeg logs [output] for the specified [streamType].
  String _parseCodecInfo(String output, String streamType) {
    final regex = RegExp(r'Stream #0:0.*: ' + streamType + r': (\w+)', multiLine: true);
    final match = regex.firstMatch(output);
    if (match != null) {
      return match.group(1) ?? '';
    } else {
      throw Exception('Codec information not found for $streamType');
    }
  }

  /// Retrieves the bitrate for the given [filePath] and [streamType].
  Future<int> _getBitrate(String filePath, String streamType) async {
    final command = "-i $filePath";
    final session = await FFmpegKit.execute(command);

    final logs = await session.getAllLogsAsString();
    if (logs == null) {
      throw Exception('Error executing logs from $streamType');
    }

    return _parseBitrate(logs);
  }

  /// Parses bitrate information from the FFmpeg logs [output].
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
