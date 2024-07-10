import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/return_code.dart';
import 'package:path/path.dart' as path;

enum CompressionType { image, video, audio }
enum ResizingOption {
  maintainAspectRatio,
  ignoreAspectRatio,
  stretchToFill,
  centerCrop,
  customScaling
}

class FileCompressor {
  /// Compresses a file at [filePath] with the given [quality] and [compressionType].
  /// Additional options for [CompressionType.image] include [maintainAspectRatio] 
  /// and custom resizing options.
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

    final resizedImage = _resizeImage(
      image: image,
      quality: quality,
      resizingOption: resizingOption,
      widthScaleFactor: widthScaleFactor,
      heightScaleFactor: heightScaleFactor,
    );

    final compressedFilePath = _getCompressedFilePath(filePath);
    final bytes = img.encodeNamedImage(compressedFilePath, resizedImage);
    if (bytes == null) throw UnsupportedError('Unsupported image format');

    File(compressedFilePath).writeAsBytesSync(bytes);
    return compressedFilePath;
  }

  /// Resizes the image based on the provided resizing options.
  img.Image _resizeImage({
    required img.Image image,
    required double quality,
    required ResizingOption resizingOption,
    required double widthScaleFactor,
    required double heightScaleFactor,
  }) {
    switch (resizingOption) {
      case ResizingOption.maintainAspectRatio:
        return img.copyResize(image, width: (image.width * quality).toInt());
      case ResizingOption.ignoreAspectRatio:
      case ResizingOption.stretchToFill:
        return img.copyResize(
          image,
          width: (image.width * quality).toInt(),
          height: (image.height * quality).toInt(),
        );
      case ResizingOption.centerCrop:
        return img.copyResizeCropSquare(
            image, size: (image.width * quality).toInt());
      case ResizingOption.customScaling:
        return img.copyResize(
          image,
          width: (image.width * widthScaleFactor).toInt(),
          height: (image.height * heightScaleFactor).toInt(),
        );
    }
  }

  /// Compresses a video file at [filePath] with the given [quality].
  Future<String> _compressVideo(
      {required String filePath, required double quality}) async {
    final originalVideoBitrate = await _getBitrate(filePath, 'Video');
    final originalAudioBitrate = await _getBitrate(filePath, 'Audio');
    final gopSize = await _getGopSize(filePath);

    // Calculate target bitrates
    final targetVideoBitrate = (originalVideoBitrate * quality).toInt();
    final targetAudioBitrate = (originalAudioBitrate * quality).toInt();

    final compressedFilePath = _getCompressedFilePath(filePath);

    final session = await FFmpegKit.execute(
        '-y -i $filePath -c:v mpeg4 -b:v ${targetVideoBitrate}k -g $gopSize '
            '-b:a ${targetAudioBitrate}k $compressedFilePath'
    );

    return _handleFFmpegSession(session, compressedFilePath);
  }

  /// Compresses an audio file at [filePath] with the given [quality].
  Future<String> _compressAudio(
      {required String filePath, required double quality}) async {
    final originalBitrate = await _getBitrate(filePath, 'Audio');
    final targetBitrate = (originalBitrate * quality).toInt();

    final compressedFilePath = _getCompressedFilePath(filePath);

    final session = await FFmpegKit.execute(
        '-y -i $filePath -c:a libmp3lame -b:a ${targetBitrate}k $compressedFilePath'
    );

    return _handleFFmpegSession(session, compressedFilePath);
  }

  /// Retrieves the bitrate for the given [filePath] and [streamType].
  Future<int> _getBitrate(String filePath, String streamType) async {
    final session = await FFmpegKit.execute("-i $filePath");
    final logs = await session.getAllLogsAsString();
    if (logs == null) throw Exception('Error executing logs from $streamType');

    return _parseBitrate(logs, streamType);
  }

  /// Parses bitrate information from the FFmpeg logs [output].
  int _parseBitrate(String output, String streamType) {
    final regex = RegExp(
        r'Stream.*: ' + streamType + r': .*? (\d+) kb/s', multiLine: true);
    final match = regex.firstMatch(output);
    if (match != null) {
      return int.parse(match.group(1) ?? '0');
    } else {
      throw Exception('Bitrate information not found for $streamType');
    }
  }

  /// Retrieves the GOP size for the given [filePath].
  Future<int> _getGopSize(String filePath) async {
    final session = await FFprobeKit.execute(
        "-v error -select_streams v:0 -show_entries stream=r_frame_rate "
            "-of default=nw=1:nk=1 $filePath"
    );

    final logs = await session.getOutput();
    if (logs == null) throw Exception(
        'Error executing logs from video for GOP size');

    final frameRates = logs.trim().split('/');
    if (frameRates.length != 2) throw Exception(
        'Error parsing frame rates for GOP size');

    final fps = int.parse(frameRates[0]) / int.parse(frameRates[1]);
    return (fps * 10).toInt();
  }

  /// Constructs the compressed file path based on the original [filePath].
  String _getCompressedFilePath(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    final fileNameWithoutExtension = path.basenameWithoutExtension(filePath);
    return path.join(path.dirname(filePath),
        'compressed_$fileNameWithoutExtension$extension');
  }

  /// Handles the FFmpeg session and checks for success or failure.
  Future<String> _handleFFmpegSession(dynamic session,
      String compressedFilePath) async {
    final returnCode = await session.getReturnCode();
    final sessionLog = await session.getAllLogsAsString();

    if (ReturnCode.isSuccess(returnCode)) {
      return compressedFilePath;
    } else {
      final failStackTrace = await session.getFailStackTrace();
      throw Exception([
        "Failed to compress file",
        "FFmpeg Log: $sessionLog",
        "Compression failed with stack trace: $failStackTrace"
      ].join("\n"));
    }
  }
}
