# File Compressor Package

A Flutter package for compressing images, videos, and audio files with options for specifying
compression quality and maintaining aspect ratios. Supports common formats for each media type.

## Features

- Compress images while maintaining aspect ratios.
- Compress videos.
- Compress audio files.
- Supports both Android and iOS platforms.
- Handles multiple formats for images (BMP, CUR, GIF, ICO, JPG, PNG, TGA, TIFF).
- Handles multiple formats for videos (MP4, AVI, MOV, MKV, WMV).
- Handles multiple formats for audio (MP3, AAC, WAV, OGG, FLAC).

## Installation

Add this to your package's pubspec.yaml file:

```yaml
dependencies:
  file_compression:
    git:
      url: https://github.com/IhorSavva/file_compressor.git
      ref: main
```

Then, run flutter pub get to install the package.

## Usage

### Import the package

```import 'package:file_compression/file_compression.dart';```

### Compressing a File

```
final fileCompressor = FileCompressor();

// Compress an image
final compressedImage = await fileCompressor.compressFile(
  filePath: 'path/to/your/image.jpg',
  quality: 0.8,
  compressionType: CompressionType.image,
);

// Compress a video
final compressedVideo = await fileCompressor.compressFile(
  filePath: 'path/to/your/video.mp4',
  quality: 0.8,
  compressionType: CompressionType.video,
);

// Compress an audio file
final compressedAudio = await fileCompressor.compressFile(
  filePath: 'path/to/your/audio.mp3',
  quality: 0.8,
  compressionType: CompressionType.audio,
);

print('Compressed image path: $compressedImage');
print('Compressed video path: $compressedVideo');
print('Compressed audio path: $compressedAudio');
```

## API Documentation

### compressFile

```
Future<String> compressFile({
  required String filePath,
  required double quality,
  required CompressionType compressionType,
  bool maintainAspectRatio = true,
})
```

- `filePath`: The path of the file to be compressed.
- `quality`: The quality of compression (e.g., percentage or specific value).
- `compressionType`: The type of compression (e.g., image, video, audio).
- `maintainAspectRatio`: Whether to maintain the aspect ratio during image compression.

Returns the file path of the compressed file.

## Platform-specific Instructions

### Android

Ensure that your `android/app/build.gradle` is configured to support the necessary dependencies. Add the following lines to your `android/app/build.gradle file`:

```
android {
    // Your existing configurations

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }
}
```

### iOS

Ensure that your `ios/Podfile` is configured to support the necessary dependencies. Add the following lines to your `ios/Podfile` file:

```
platform :ios, '10.0'
use_frameworks!
```

### Example

You can find an example usage of this package in the example directory.

### License

[MIT License](LICENSE)