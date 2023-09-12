import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class RecordManager {
  final int _sampleRate = 16000;
  final _numChannels = 1;
  final int _bitsPerSample = 16;
  String? _pcmPath;
  String? _wavPath;
  final _record = Record();
  StreamSubscription<RecordState>? _recordSub;
  StreamSubscription<Amplitude>? _amplitudeSub;
  static final _instance = RecordManager._();

  static RecordManager get instance => _instance;

  RecordManager._();

  Future<List<String>?> start() async {
    if(!await _record.hasPermission()) {
      print('Permission not granted!');
      return null;
    }
    _recordSub = _record.onStateChanged().listen((event) {
      print('event=$event');
    });
    _amplitudeSub = _record.onAmplitudeChanged(const Duration(milliseconds: 100)).listen((event) {
      final volume = event.current + 90;
      print('Volume: ${event.current} dBFS');
      print('Volume: $volume dB');
    });
    final fileName = DateTime.now().millisecondsSinceEpoch.toString();
    _pcmPath = '${(await getTemporaryDirectory()).path}/$fileName.pcm';
    _wavPath = '${(await getTemporaryDirectory()).path}/$fileName.wav';
    _record.start(path: _pcmPath, encoder: AudioEncoder.pcm16bit, samplingRate: _sampleRate, numChannels: _numChannels);
    return [_pcmPath!, _wavPath!];
  }

  stop() {
    _recordSub?.cancel();
    _amplitudeSub?.cancel();
    _record.stop();
    _saveAsWave();
  }

  _saveAsWave() async {
    final bytes = await File(_pcmPath!).readAsBytes();
    final pcmData = Int16List.view(bytes.buffer);
    final byteBuffer = ByteData(pcmData.length * 2);

    for (var i = 0; i < pcmData.length; i++) {
      byteBuffer.setInt16(i * 2, pcmData[i], Endian.little);
    }

    final ByteData wavHeader = ByteData(44);
    final pcmBytes = byteBuffer.buffer.asUint8List();

    // RIFF
    wavHeader.setUint8(0x00, 0x52); // 'R'
    wavHeader.setUint8(0x01, 0x49); // 'I'
    wavHeader.setUint8(0x02, 0x46); // 'F'
    wavHeader.setUint8(0x03, 0x46); // 'F'
    wavHeader.setUint32(4, 36 + pcmBytes.length, Endian.little); // ChunkSize
    wavHeader.setUint8(0x08, 0x57); // 'W'
    wavHeader.setUint8(0x09, 0x41); // 'A'
    wavHeader.setUint8(0x0A, 0x56); // 'V'
    wavHeader.setUint8(0x0B, 0x45); // 'E'
    wavHeader.setUint8(0x0C, 0x66); // 'f'
    wavHeader.setUint8(0x0D, 0x6D); // 'm'
    wavHeader.setUint8(0x0E, 0x74); // 't'
    wavHeader.setUint8(0x0F, 0x20); // ' '
    wavHeader.setUint32(16, 16, Endian.little); // Subchunk1Size
    wavHeader.setUint16(20, 1, Endian.little); // AudioFormat
    wavHeader.setUint16(22, _numChannels, Endian.little); // NumChannels
    wavHeader.setUint32(24, _sampleRate, Endian.little); // SampleRate
    wavHeader.setUint32(28, _sampleRate * _numChannels * _bitsPerSample ~/ 8,
        Endian.little); // ByteRate
    wavHeader.setUint16(
        32, _numChannels * _bitsPerSample ~/ 8, Endian.little); // BlockAlign
    wavHeader.setUint16(34, _bitsPerSample, Endian.little); // BitsPerSample

    // data
    wavHeader.setUint8(0x24, 0x64); // 'd'
    wavHeader.setUint8(0x25, 0x61); // 'a'
    wavHeader.setUint8(0x26, 0x74); // 't'
    wavHeader.setUint8(0x27, 0x61); // 'a'
    wavHeader.setUint32(40, pcmBytes.length, Endian.little); // Subchunk2Size

    final File wavFile = File(_wavPath!);
    wavFile.writeAsBytesSync(wavHeader.buffer.asUint8List() + pcmBytes);
  }

}