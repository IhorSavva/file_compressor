import 'package:flutter/material.dart';
import 'package:file_compressor/file_compressor.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'File Compressor Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final FileCompressor fileCompressor = FileCompressor();

  Future<String> getFileFromAsset(String assetPath) async {
    final byteData = await rootBundle.load(assetPath);
    final tempDir = await getTemporaryDirectory();
    final file = File(path.join(tempDir.path, path.basename(assetPath)));
    await file.writeAsBytes(byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
    return file.path;
  }

  Future<void> compressFiles() async {
    try {
      final imageAssetPath = await getFileFromAsset('assets/test_image.jpg');
      final compressedImage = await fileCompressor.compressFile(
        filePath: imageAssetPath,
        quality: 0.3,
        compressionType: CompressionType.image,
      );

      final videoAssetPath = await getFileFromAsset('assets/test_video.mp4');
      final compressedVideo = await fileCompressor.compressFile(
        filePath: videoAssetPath,
        quality: 0.9,
        compressionType: CompressionType.video,
      );

      final audioAssetPath = await getFileFromAsset('assets/test_audio.mp3');
      final compressedAudio = await fileCompressor.compressFile(
        filePath: audioAssetPath,
        quality: 0.8,
        compressionType: CompressionType.audio,
      );

      print('Compressed image path: $compressedImage');
      print('Compressed video path: $compressedVideo');
      print('Compressed audio path: $compressedAudio');
    } catch (e) {
      print('Error compressing files: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('File Compression Example'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: compressFiles,
          child: Text('Compress Files'),
        ),
      ),
    );
  }
}
