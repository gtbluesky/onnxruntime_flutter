import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'model_type_test.dart';
import 'vad_iterator.dart';

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
  VadIterator? _vadIterator;
  static const frameSize = 64;
  static const sampleRate = 16000;

  @override
  void initState() {
    super.initState();
    _version = OrtEnv.version;
    _vadIterator = VadIterator(frameSize, sampleRate);
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
                    onPressed: () {
                      _typeTest();
                    },
                    child: const Text('Mode Type Test')),
                const SizedBox(
                  height: 50,
                ),
                TextButton(
                    onPressed: () {
                      _vad(false);
                    },
                    child: const Text('VAD')),
                const SizedBox(
                  height: 50,
                ),
                TextButton(
                    onPressed: () {
                      _vad(true);
                    },
                    child: const Text('VAD Concurrency')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  _typeTest() async {
    final startTime = DateTime.now().millisecondsSinceEpoch;
    List<OrtValue?>? outputs;
    outputs = await ModelTypeTest.testBool();
    print('out=${outputs[0]?.value}');
    outputs.forEach((element) {
      element?.release();
    });
    outputs = await ModelTypeTest.testFloat();
    print('out=${outputs[0]?.value}');
    outputs.forEach((element) {
      element?.release();
    });
    outputs = await ModelTypeTest.testInt64();
    print('out=${outputs[0]?.value}');
    outputs.forEach((element) {
      element?.release();
    });
    outputs = await ModelTypeTest.testString();
    print('out=${outputs[0]?.value}');
    outputs.forEach((element) {
      element?.release();
    });
    final endTime = DateTime.now().millisecondsSinceEpoch;
    print('infer cost time=${endTime - startTime}ms');
  }

  _vad(bool concurrent) async {
    const windowByteCount = frameSize * 2 * sampleRate ~/ 1000;
    final rawAssetFile = await rootBundle.load('assets/audio/vad_example.pcm');
    final bytes = rawAssetFile.buffer.asUint8List();
    var start = 0;
    var end = start + windowByteCount;
    List<int> frameBuffer;
    final startTime = DateTime.now().millisecondsSinceEpoch;
    while (end <= bytes.length) {
      frameBuffer = bytes.sublist(start, end).toList();
      final floatBuffer =
          _transformBuffer(frameBuffer).map((e) => e / 32768).toList();
      await _vadIterator?.predict(
          Float32List.fromList(floatBuffer), concurrent);
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
