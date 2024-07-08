import 'package:flutter/material.dart';
import 'package:file_compressor/file_compressor.dart';

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

  Future<void> compressFiles() async {
    try {
      final compressedImage = await fileCompressor.compressFile(
        filePath: 'assets/test_image.jpg',
        quality: 0.8,
        compressionType: CompressionType.image,
      );

      final compressedVideo = await fileCompressor.compressFile(
        filePath: 'assets/test_video.mp4',
        quality: 0.8,
        compressionType: CompressionType.video,
      );

      final compressedAudio = await fileCompressor.compressFile(
        filePath: 'assets/test_audio.mp3',
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
