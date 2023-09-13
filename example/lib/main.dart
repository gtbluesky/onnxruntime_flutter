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
  static const frameSize = 64;

  @override
  void initState() {
    super.initState();
    _version = OrtEnv.version;

    _vadIterator = VadIterator(frameSize, RecordManager.sampleRate);
    _vadIterator?.initModel();
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
    // print('out=${(await ModelTypeTest.testBool())[0].value}');
    // print('out=${(await ModelTypeTest.testFloat())[0].value}');
    // print('out=${(await ModelTypeTest.testInt64())[0].value}');
    // print('out=${(await ModelTypeTest.testString())[0].value}');
    // final endTime = DateTime.now().millisecondsSinceEpoch;
    // print('infer cost time=${endTime - startTime}ms');
    const windowByteCount = frameSize * 2 * RecordManager.sampleRate ~/ 1000;
    final bytes = await File(_pcmPath!).readAsBytes();
    var start = 0;
    var end = start + windowByteCount;
    List<int> frameBuffer;
    final startTime = DateTime.now().millisecondsSinceEpoch;
    while(end <= bytes.length) {
      frameBuffer = bytes.sublist(start, end).toList();
      final floatBuffer =
      _transformBuffer(frameBuffer).map((e) => e / 32768).toList();
      await _vadIterator?.predict(Float32List.fromList(floatBuffer));
      start += windowByteCount;
      end = start + windowByteCount;
    }
    _vadIterator?.reset();
    final endTime = DateTime.now().millisecondsSinceEpoch;
    print('vad cost time=${endTime - startTime}ms');
  }

  Int16List _transformBuffer(List<int> buffer) {
    final bytes = Uint8List.fromList(buffer);
    return Int16List.view(bytes.buffer);
  }

  @override
  void dispose() {
    _vadIterator?.release();
    super.dispose();
  }
}
