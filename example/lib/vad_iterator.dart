import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';

class VadIterator {
  final _threshold = 0.5;
  final _minSilenceDurationMs = 0;
  final int _sampleRate;

  final int _frameSize;
  final _speechPadMs = 0;
  late int _minSilenceSamples;
  late int _speechPadSamples;
  /// support 256 512 768 for 8k; 512 1024 1536 for 16k
  late int _windowSizeSamples;

  OrtSessionOptions? _sessionOptions;
  OrtSession? _session;

  /// model states
  var _triggered = false;
  var _tempEnd = 0;
  var _currentSample = 0;

  static const int _batch = 1;
  /// model inputs
  var _hide = List.filled(2, List.filled(_batch, Float32List.fromList(List.filled(64, 0.0))));
  var _cell = List.filled(2, List.filled(_batch, Float32List.fromList(List.filled(64, 0.0))));

  VadIterator(this._frameSize, this._sampleRate) {
    final srPerMs = _sampleRate ~/ 1000;
    _minSilenceSamples = srPerMs * _minSilenceDurationMs;
    _speechPadSamples = srPerMs * _speechPadMs;
    _windowSizeSamples = srPerMs * _frameSize;
    OrtEnv.instance.init();
    OrtEnv.instance.availableProviders().forEach((element) {
      print('onnx provider=$element');
    });
  }

  reset() {
    _triggered = false;
    _tempEnd = 0;
    _currentSample = 0;
    _hide = List.filled(2, List.filled(_batch, Float32List.fromList(List.filled(64, 0.0))));
    _cell = List.filled(2, List.filled(_batch, Float32List.fromList(List.filled(64, 0.0))));
  }

  release() {
    _sessionOptions?.release();
    _sessionOptions = null;
    _session?.release();
    _session = null;
    OrtEnv.instance.release();
  }

  initModel() async {
    _sessionOptions = OrtSessionOptions()
      ..setInterOpNumThreads(1)
      ..setIntraOpNumThreads(1)
      ..setSessionGraphOptimizationLevel(GraphOptimizationLevel.ortEnableAll);
    
    // 🚀 Automatically select the best execution provider available!
    // Priority: GPU (CUDA/DirectML/ROCm) > NPU (CoreML/NNAPI) > Optimized CPU (DNNL/XNNPACK) > CPU
    // This will use GPU acceleration if available, otherwise falls back to CPU
    // Now async so it doesn't block the UI thread during capability detection
    await _sessionOptions!.appendDefaultProviders();
    
    const assetFileName = 'assets/models/silero_vad.onnx';
    final rawAssetFile = await rootBundle.load(assetFileName);
    final bytes = rawAssetFile.buffer.asUint8List();
    _session = OrtSession.fromBuffer(bytes, _sessionOptions!);
  }

  Future<bool> predict(Float32List data, bool concurrent) async {
    final inputOrt =
        OrtValueTensor.createTensorWithDataList(data, [_batch, _windowSizeSamples]);
    final srOrt = OrtValueTensor.createTensorWithData(_sampleRate);
    final hOrt = OrtValueTensor.createTensorWithDataList(_hide);
    final cOrt = OrtValueTensor.createTensorWithDataList(_cell);
    final runOptions = OrtRunOptions();
    final inputs = {'input': inputOrt, 'sr': srOrt, 'h': hOrt, 'c': cOrt};
    final List<OrtValue?>? outputs;
    if (concurrent) {
      outputs = await _session?.runAsync(runOptions, inputs);
    } else {
      outputs = _session?.run(runOptions, inputs);
    }
    inputOrt.release();
    srOrt.release();
    hOrt.release();
    cOrt.release();
    runOptions.release();
    /// Output probability & update h,c recursively
    final output = (outputs?[0]?.value as List<List<double>>)[0][0];
    _hide = (outputs?[1]?.value as List<List<List<double>>>).map((e) => e.map((e) => Float32List.fromList(e)).toList()).toList();
    _cell = (outputs?[2]?.value as List<List<List<double>>>).map((e) => e.map((e) => Float32List.fromList(e)).toList()).toList();
    outputs?.forEach((element) {
      element?.release();
    });
    /// Push forward sample index
    _currentSample += _windowSizeSamples;

    /// Reset temp_end when > threshold
    if (output >= _threshold && _tempEnd != 0) {
      _tempEnd = 0;
    }

    /// 1) Silence
    if ((output < _threshold) && !_triggered) {
      print('vad silence: ${_currentSample / _sampleRate}s');
    }

    /// 2) Speaking
    if ((output >= (_threshold - 0.15)) && _triggered) {
      print('vad speaking2: ${_currentSample / _sampleRate}s');
    }

    /// 3) Start
    if (output >= _threshold && !_triggered) {
      _triggered = true;
      /// minus window_size_samples to get precise start time point.
      final speechStart = _currentSample - _windowSizeSamples - _speechPadSamples;
      print('vad start: ${speechStart / _sampleRate}s');
    }

    /// 4) End
    if (output < (_threshold - 0.15) && _triggered) {
      if (_tempEnd == 0) {
        _tempEnd = _currentSample;
      }
      /// a. silence < min_slience_samples, continue speaking
      if (_currentSample - _tempEnd < _minSilenceSamples) {
        print('vad speaking4: ${_currentSample / _sampleRate}s');
      }
      /// b. silence >= min_slience_samples, end speaking
      else {
        final speechEnd = _tempEnd > 0 ? _tempEnd + _speechPadSamples : _currentSample + _speechPadSamples;
        _tempEnd = 0;
        _triggered = false;
        print('vad end: ${speechEnd / _sampleRate}s');
      }
    }
    return _triggered;
  }
}
