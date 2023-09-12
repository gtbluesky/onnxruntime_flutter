import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:onnxruntime_example/record_manager.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:onnxruntime_example/model_type_test.dart';
import 'package:onnxruntime_example/vad_iterator.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late String _version;
  String? _pcmPath;
  String? _wavPath;
  AudioPlayer? _audioPlayer;
  VadIterator? _vadIterator;

  @override
  void initState() {
    super.initState();
    _version = OrtEnv.version;
  }

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(fontSize: 16);
    return MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('OnnxRuntime'),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'OnnxRuntime Version = $_version',
                  style: textStyle,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(
                  height: 50,
                ),
                TextButton(
                    onPressed: () async {
                      final audioSource = await RecordManager.instance.start();
                      _pcmPath = audioSource?[0];
                      _wavPath = audioSource?[1];
                    },
                    child: const Text('Start Recording')),
                const SizedBox(
                  height: 50,
                ),
                TextButton(
                    onPressed: () {
                      RecordManager.instance.stop();
                    },
                    child: const Text('Stop Recording')),
                const SizedBox(
                  height: 50,
                ),
                TextButton(
                    onPressed: () async {
                      _audioPlayer = AudioPlayer();
                      await _audioPlayer?.play(DeviceFileSource(_wavPath!));
                    },
                    child: const Text('Start Playing')),
                const SizedBox(
                  height: 50,
                ),
                TextButton(
                    onPressed: () {
                      _audioPlayer?.stop();
                    },
                    child: const Text('Stop Playing')),
                const SizedBox(
                  height: 50,
                ),
                TextButton(
                    onPressed: () {
                      infer();
                    },
                    child: const Text('Start Inferring')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  infer() async {
    // final startTime = DateTime.now().millisecondsSinceEpoch;
    // print('out=${(await ModelTypeTest.testFloat())[0].value}');
    // final endTime = DateTime.now().millisecondsSinceEpoch;
    // print('infer cost time=${endTime - startTime}ms');

    const frameSize = 64;
    const sampleRate = 16000;
    _vadIterator = VadIterator(frameSize, sampleRate);
    await _vadIterator?.initModel();
    final bytes = await File(_pcmPath!).readAsBytes();
    final frameBuffer = <int>[...bytes];
    final startTime = DateTime.now().millisecondsSinceEpoch;
    const windowByteCount = frameSize * 2 * sampleRate ~/ 1000;
    while (frameBuffer.length >= windowByteCount) {
      final data = frameBuffer.take(windowByteCount).toList();
      frameBuffer.removeRange(0, windowByteCount);
      final floatBuffer =
          _transformBuffer(data).map((e) => e / 32768).toList();
      _vadIterator?.predict(Float32List.fromList(floatBuffer));
    }
    _vadIterator?.release();
    final endTime = DateTime.now().millisecondsSinceEpoch;
    print('vad cost time=${endTime - startTime}ms');
  }

  Int16List _transformBuffer(List<int> buffer) {
    final bytes = Uint8List.fromList(buffer);
    return Int16List.view(bytes.buffer);
  }
}
