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
  const MyApp({Key? key}) : super(key: key);

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
  const MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final FileCompressor fileCompressor = FileCompressor();
  bool isLoading = false;

  Future<String> getFileFromAsset(String assetPath) async {
    final byteData = await rootBundle.load(assetPath);
    final tempDir = await getTemporaryDirectory();
    final file = File(path.join(tempDir.path, path.basename(assetPath)));
    await file.writeAsBytes(byteData.buffer
        .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
    return file.path;
  }

  Future<void> compressFiles() async {
    setState(() {
      isLoading = true;
    });

    try {
      final imageAssetPath = await getFileFromAsset('assets/test_image.jpg');
      final compressedImage = await fileCompressor.compressFile(
        filePath: imageAssetPath,
        quality: 0.3,
        compressionType: CompressionType.image,
        resizingOption: ResizingOption.centerCrop,
      );

      final audioAssetPath = await getFileFromAsset('assets/test_audio.mp3');
      final compressedAudio = await fileCompressor.compressFile(
        filePath: audioAssetPath,
        quality: 0.5,
        compressionType: CompressionType.audio,
      );

      final videoAssetPath = await getFileFromAsset('assets/test_video.mp4');
      final compressedVideo = await fileCompressor.compressFile(
        filePath: videoAssetPath,
        quality: 0.5,
        compressionType: CompressionType.video,
      );

      print('Compressed image path: $compressedImage');
      print('Compressed video path: $compressedVideo');
      print('Compressed audio path: $compressedAudio');
    } catch (e) {
      print('Error compressing files: $e');
    }

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('File Compression Example'),
        ),
        body: Center(
          child: SizedBox(
            width: 200,
            child: ElevatedButton(
              onPressed: isLoading ? null : compressFiles,
              child: isLoading
                  ? const LinearProgressIndicator()
                  : const Text('Compress Files'),
            ),
          ),
        ));
  }
}
