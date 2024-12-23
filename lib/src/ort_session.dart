import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';

import 'package:ffi/ffi.dart';
import 'package:onnxruntime/src/bindings/bindings.dart';
import 'package:onnxruntime/src/bindings/onnxruntime_bindings_generated.dart'
    as bg;
import 'package:onnxruntime/src/ort_env.dart';
import 'package:onnxruntime/src/ort_isolate_session.dart';
import 'package:onnxruntime/src/ort_status.dart';
import 'package:onnxruntime/src/ort_value.dart';
import 'package:onnxruntime/src/ort_provider.dart';
import 'package:onnxruntime/src/providers/ort_flags.dart';

class OrtSession {
  late ffi.Pointer<bg.OrtSession> _ptr;
  late int _inputCount;
  late List<String> _inputNames;
  late int _outputCount;
  late List<String> _outputNames;
  OrtIsolateSession? _isolateSession;

  int get address => _ptr.address;
  int get inputCount => _inputCount;
  List<String> get inputNames => _inputNames;
  int get outputCount => _outputCount;
  List<String> get outputNames => _outputNames;
  OrtIsolateSession? get isolateSession => _isolateSession;

  /// Creates a session from a file.
  OrtSession.fromFile(File modelFile, OrtSessionOptions options) {
    final pp = calloc<ffi.Pointer<bg.OrtSession>>();
    final statusPtr = OrtEnv.instance.ortApiPtr.ref.CreateSession.asFunction<
            bg.OrtStatusPtr Function(
                ffi.Pointer<bg.OrtEnv>,
                ffi.Pointer<ffi.Char>,
                ffi.Pointer<bg.OrtSessionOptions>,
                ffi.Pointer<ffi.Pointer<bg.OrtSession>>)>()(OrtEnv.instance.ptr,
        modelFile.path.toNativeUtf8().cast<ffi.Char>(), options._ptr, pp);
    OrtStatus.checkOrtStatus(statusPtr);
    _ptr = pp.value;
    calloc.free(pp);
    _init();
  }

  /// Creates a session from buffer.
  OrtSession.fromBuffer(Uint8List modelBuffer, OrtSessionOptions options) {
    final pp = calloc<ffi.Pointer<bg.OrtSession>>();
    final size = modelBuffer.length;
    final bufferPtr = calloc<ffi.Uint8>(size);
    bufferPtr.asTypedList(size).setRange(0, size, modelBuffer);
    final statusPtr = OrtEnv.instance.ortApiPtr.ref.CreateSessionFromArray
            .asFunction<
                bg.OrtStatusPtr Function(
                    ffi.Pointer<bg.OrtEnv>,
                    ffi.Pointer<ffi.Void>,
                    int,
                    ffi.Pointer<bg.OrtSessionOptions>,
                    ffi.Pointer<ffi.Pointer<bg.OrtSession>>)>()(
        OrtEnv.instance.ptr, bufferPtr.cast(), size, options._ptr, pp);
    OrtStatus.checkOrtStatus(statusPtr);
    _ptr = pp.value;
    calloc.free(pp);
    calloc.free(bufferPtr);
    _init();
  }

  /// Creates a session from a pointer's address.
  OrtSession.fromAddress(int address) {
    _ptr = ffi.Pointer.fromAddress(address);
    _init();
  }

  void _init() {
    _inputCount = _getInputCount();
    _inputNames = _getInputNames();
    _outputCount = _getOutputCount();
    _outputNames = _getOutputNames();
  }

  int _getInputCount() {
    final countPtr = calloc<ffi.Size>();
    final statusPtr = OrtEnv.instance.ortApiPtr.ref.SessionGetInputCount
        .asFunction<
            bg.OrtStatusPtr Function(ffi.Pointer<bg.OrtSession>,
                ffi.Pointer<ffi.Size>)>()(_ptr, countPtr);
    OrtStatus.checkOrtStatus(statusPtr);
    final count = countPtr.value;
    calloc.free(countPtr);
    return count;
  }

  int _getOutputCount() {
    final countPtr = calloc<ffi.Size>();
    final statusPtr = OrtEnv.instance.ortApiPtr.ref.SessionGetOutputCount
        .asFunction<
            bg.OrtStatusPtr Function(ffi.Pointer<bg.OrtSession>,
                ffi.Pointer<ffi.Size>)>()(_ptr, countPtr);
    OrtStatus.checkOrtStatus(statusPtr);
    final count = countPtr.value;
    calloc.free(countPtr);
    return count;
  }

  List<String> _getInputNames() {
    final list = <String>[];
    for (var i = 0; i < _inputCount; ++i) {
      final namePtrPtr = calloc<ffi.Pointer<ffi.Char>>();
      var statusPtr = OrtEnv.instance.ortApiPtr.ref.SessionGetInputName
              .asFunction<
                  bg.OrtStatusPtr Function(
                      ffi.Pointer<bg.OrtSession>,
                      int,
                      ffi.Pointer<bg.OrtAllocator>,
                      ffi.Pointer<ffi.Pointer<ffi.Char>>)>()(
          _ptr, i, OrtAllocator.instance.ptr, namePtrPtr);
      OrtStatus.checkOrtStatus(statusPtr);
      final name = namePtrPtr.value.cast<Utf8>().toDartString();
      list.add(name);
      statusPtr = OrtEnv.instance.ortApiPtr.ref.AllocatorFree.asFunction<
              bg.OrtStatusPtr Function(
                  ffi.Pointer<bg.OrtAllocator>, ffi.Pointer<ffi.Void>)>()(
          OrtAllocator.instance.ptr, namePtrPtr.value.cast());
      OrtStatus.checkOrtStatus(statusPtr);
      calloc.free(namePtrPtr);
    }
    return list;
  }

  List<String> _getOutputNames() {
    final list = <String>[];
    for (var i = 0; i < _outputCount; ++i) {
      final namePtrPtr = calloc<ffi.Pointer<ffi.Char>>();
      var statusPtr = OrtEnv.instance.ortApiPtr.ref.SessionGetOutputName
              .asFunction<
                  bg.OrtStatusPtr Function(
                      ffi.Pointer<bg.OrtSession>,
                      int,
                      ffi.Pointer<bg.OrtAllocator>,
                      ffi.Pointer<ffi.Pointer<ffi.Char>>)>()(
          _ptr, i, OrtAllocator.instance.ptr, namePtrPtr);
      OrtStatus.checkOrtStatus(statusPtr);
      final name = namePtrPtr.value.cast<Utf8>().toDartString();
      list.add(name);
      statusPtr = OrtEnv.instance.ortApiPtr.ref.AllocatorFree.asFunction<
              bg.OrtStatusPtr Function(
                  ffi.Pointer<bg.OrtAllocator>, ffi.Pointer<ffi.Void>)>()(
          OrtAllocator.instance.ptr, namePtrPtr.value.cast());
      OrtStatus.checkOrtStatus(statusPtr);
      calloc.free(namePtrPtr);
    }
    return list;
  }

  /// Performs inference synchronously.
  List<OrtValue?> run(OrtRunOptions runOptions, Map<String, OrtValue> inputs,
      [List<String>? outputNames]) {
    final inputLength = inputs.length;
    final inputNamePtrs = calloc<ffi.Pointer<ffi.Char>>(inputLength);
    final inputPtrs = calloc<ffi.Pointer<bg.OrtValue>>(inputLength);
    var i = 0;
    for (final entry in inputs.entries) {
      inputNamePtrs[i] = entry.key.toNativeUtf8().cast<ffi.Char>();
      inputPtrs[i] = entry.value.ptr;
      ++i;
    }
    outputNames ??= _outputNames;
    final outputLength = outputNames.length;
    final outputNamePtrs = calloc<ffi.Pointer<ffi.Char>>(outputLength);
    final outputPtrs = calloc<ffi.Pointer<bg.OrtValue>>(outputLength);
    for (int i = 0; i < outputLength; ++i) {
      outputNamePtrs[i] = outputNames[i].toNativeUtf8().cast<ffi.Char>();
      outputPtrs[i] = ffi.nullptr;
    }
    var statusPtr = OrtEnv.instance.ortApiPtr.ref.Run.asFunction<
            bg.OrtStatusPtr Function(
                ffi.Pointer<bg.OrtSession>,
                ffi.Pointer<bg.OrtRunOptions>,
                ffi.Pointer<ffi.Pointer<ffi.Char>>,
                ffi.Pointer<ffi.Pointer<bg.OrtValue>>,
                int,
                ffi.Pointer<ffi.Pointer<ffi.Char>>,
                int,
                ffi.Pointer<ffi.Pointer<bg.OrtValue>>)>()(
        _ptr,
        runOptions._ptr,
        inputNamePtrs,
        inputPtrs,
        inputLength,
        outputNamePtrs,
        outputLength,
        outputPtrs);
    OrtStatus.checkOrtStatus(statusPtr);
    final outputs = List<OrtValue?>.generate(outputLength, (index) {
      final ortValuePtr = outputPtrs[index];
      final onnxTypePtr = calloc<ffi.Int32>();
      statusPtr = OrtEnv.instance.ortApiPtr.ref.GetValueType.asFunction<
          bg.OrtStatusPtr Function(ffi.Pointer<bg.OrtValue>,
              ffi.Pointer<ffi.Int32>)>()(ortValuePtr, onnxTypePtr);
      OrtStatus.checkOrtStatus(statusPtr);
      final onnxType = ONNXType.valueOf(onnxTypePtr.value);
      calloc.free(onnxTypePtr);
      switch (onnxType) {
        case ONNXType.tensor:
          return OrtValueTensor(ortValuePtr);
        case ONNXType.sequence:
          return OrtValueSequence(ortValuePtr);
        case ONNXType.map:
          return OrtValueMap(ortValuePtr);
        case ONNXType.sparseTensor:
          return OrtValueSparseTensor(ortValuePtr);
        case ONNXType.unknown:
        case ONNXType.opaque:
        case ONNXType.optional:
          return null;
      }
    });
    calloc.free(inputNamePtrs);
    calloc.free(inputPtrs);
    calloc.free(outputNamePtrs);
    calloc.free(outputPtrs);
    return outputs;
  }

  /// Performs inference asynchronously.
  Future<List<OrtValue?>>? runAsync(
      OrtRunOptions runOptions, Map<String, OrtValue> inputs,
      [List<String>? outputNames]) {
    _isolateSession ??= OrtIsolateSession(this);
    return _isolateSession?.run(runOptions, inputs, outputNames);
  }

  String getMetadatas(String key) {
    final metaPtr = calloc<ffi.Pointer<bg.OrtModelMetadata>>();
    var statusPtr = OrtEnv.instance.ortApiPtr.ref.SessionGetModelMetadata
            .asFunction<
                bg.OrtStatusPtr Function(ffi.Pointer<bg.OrtSession>,
                    ffi.Pointer<ffi.Pointer<bg.OrtModelMetadata>>)>()(
        _ptr, metaPtr);
    OrtStatus.checkOrtStatus(statusPtr);
    final meta = metaPtr.value;
    final namePtrPtr = calloc<ffi.Pointer<ffi.Char>>();
    statusPtr = OrtEnv
            .instance.ortApiPtr.ref.ModelMetadataLookupCustomMetadataMap
            .asFunction<
                bg.OrtStatusPtr Function(
                    ffi.Pointer<bg.OrtModelMetadata> model_metadata,
                    ffi.Pointer<bg.OrtAllocator> allocator,
                    ffi.Pointer<ffi.Char> key,
                    ffi.Pointer<ffi.Pointer<ffi.Char>> value)>()(
        meta,
        OrtAllocator.instance.ptr,
        key.toNativeUtf8().cast<ffi.Char>(),
        namePtrPtr);
    final name = namePtrPtr.value.cast<Utf8>().toDartString();
    calloc.free(metaPtr);
    calloc.free(namePtrPtr);
    return name;
  }

  void release() {
    _isolateSession?.release();
    _isolateSession = null;
    OrtEnv.instance.ortApiPtr.ref.ReleaseSession
        .asFunction<void Function(ffi.Pointer<bg.OrtSession>)>()(_ptr);
  }
}

class OrtSessionOptions {
  late ffi.Pointer<bg.OrtSessionOptions> _ptr;
  int _intraOpNumThreads = 0;

  OrtSessionOptions() {
    _create();
  }

  void _create() {
    final pp = calloc<ffi.Pointer<bg.OrtSessionOptions>>();
    final statusPtr = OrtEnv.instance.ortApiPtr.ref.CreateSessionOptions
        .asFunction<
            bg.OrtStatusPtr Function(
                ffi.Pointer<ffi.Pointer<bg.OrtSessionOptions>>)>()(pp);
    OrtStatus.checkOrtStatus(statusPtr);
    _ptr = pp.value;
    calloc.free(pp);
  }

  void release() {
    OrtEnv.instance.ortApiPtr.ref.ReleaseSessionOptions
        .asFunction<void Function(ffi.Pointer<bg.OrtSessionOptions>)>()(_ptr);
  }

  /// Sets the number of intra op threads.
  void setIntraOpNumThreads(int numThreads) {
    _intraOpNumThreads = numThreads;
    final statusPtr = OrtEnv.instance.ortApiPtr.ref.SetIntraOpNumThreads
        .asFunction<
            bg.OrtStatusPtr Function(
                ffi.Pointer<bg.OrtSessionOptions>, int)>()(_ptr, numThreads);
    OrtStatus.checkOrtStatus(statusPtr);
  }

  /// Sets the number of inter op threads.
  void setInterOpNumThreads(int numThreads) {
    final statusPtr = OrtEnv.instance.ortApiPtr.ref.SetInterOpNumThreads
        .asFunction<
            bg.OrtStatusPtr Function(
                ffi.Pointer<bg.OrtSessionOptions>, int)>()(_ptr, numThreads);
    OrtStatus.checkOrtStatus(statusPtr);
  }

  /// Sets the level of session graph optimization.
  void setSessionGraphOptimizationLevel(GraphOptimizationLevel level) {
    final statusPtr = OrtEnv
        .instance.ortApiPtr.ref.SetSessionGraphOptimizationLevel
        .asFunction<
            bg.OrtStatusPtr Function(
                ffi.Pointer<bg.OrtSessionOptions>, int)>()(_ptr, level.value);
    OrtStatus.checkOrtStatus(statusPtr);
  }

  bool _appendExecutionProvider(OrtProvider provider, OrtFlags flags) {
    var result = false;
    bg.OrtStatusPtr? statusPtr;
    switch (provider) {
      case OrtProvider.cpu:
        statusPtr =
            onnxRuntimeBinding.OrtSessionOptionsAppendExecutionProvider_CPU(
                _ptr, flags.value);
        result = true;
        break;
      case OrtProvider.coreml:
        statusPtr =
            onnxRuntimeBinding.OrtSessionOptionsAppendExecutionProvider_CoreML(
                _ptr, flags.value);
        result = true;
        break;
      case OrtProvider.nnapi:
        statusPtr =
            onnxRuntimeBinding.OrtSessionOptionsAppendExecutionProvider_Nnapi(
                _ptr, flags.value);
        result = true;
        break;
      default:
        break;
    }
    OrtStatus.checkOrtStatus(statusPtr);
    return result;
  }

  bool _appendExecutionProvider2(
      OrtProvider provider, Map<String, String> providerOptions) {
    bg.OrtStatusPtr? statusPtr;
    var providerName = '';
    switch (provider) {
      case OrtProvider.xnnpack:
        providerName = 'XNNPACK';
        break;
      default:
        return false;
    }
    final providerNamePtr = providerName.toNativeUtf8().cast<ffi.Char>();
    var size = providerOptions.length;
    final keyPtrPtr = calloc<ffi.Pointer<ffi.Char>>(size);
    final valuePtrPtr = calloc<ffi.Pointer<ffi.Char>>(size);
    var i = 0;
    for (final entry in providerOptions.entries) {
      keyPtrPtr[i] = entry.key.toNativeUtf8().cast<ffi.Char>();
      valuePtrPtr[i] = entry.value.toNativeUtf8().cast<ffi.Char>();
      ++i;
    }
    statusPtr = OrtEnv
        .instance.ortApiPtr.ref.SessionOptionsAppendExecutionProvider
        .asFunction<
            bg.OrtStatusPtr Function(
                ffi.Pointer<bg.OrtSessionOptions>,
                ffi.Pointer<ffi.Char>,
                ffi.Pointer<ffi.Pointer<ffi.Char>>,
                ffi.Pointer<ffi.Pointer<ffi.Char>>,
                int)>()(_ptr, providerNamePtr, keyPtrPtr, valuePtrPtr, size);
    OrtStatus.checkOrtStatus(statusPtr);
    calloc.free(keyPtrPtr);
    calloc.free(valuePtrPtr);
    return true;
  }

  /// Appends cpu provider.
  bool appendCPUProvider(CPUFlags flags) {
    return _appendExecutionProvider(OrtProvider.cpu, flags);
  }

  /// Appends CoreML provider.
  bool appendCoreMLProvider(CoreMLFlags flags) {
    return _appendExecutionProvider(OrtProvider.coreml, flags);
  }

  /// Appends Nnapi provider.
  bool appendNnapiProvider(NnapiFlags flags) {
    return _appendExecutionProvider(OrtProvider.nnapi, flags);
  }

  /// Appends QNN provider.
  bool appendQnnProvider() {
    return _appendExecutionProvider2(OrtProvider.qnn, {});
  }

  /// Appends Xnnpack provider.
  bool appendXnnpackProvider() {
    return _appendExecutionProvider2(OrtProvider.xnnpack,
        {'intra_op_num_threads': _intraOpNumThreads.toString()});
  }
}

class OrtRunOptions {
  late ffi.Pointer<bg.OrtRunOptions> _ptr;

  int get address => _ptr.address;

  OrtRunOptions() {
    _create();
  }

  OrtRunOptions.fromAddress(int address) {
    _ptr = ffi.Pointer.fromAddress(address);
  }

  void _create() {
    final pp = calloc<ffi.Pointer<bg.OrtRunOptions>>();
    final statusPtr = OrtEnv.instance.ortApiPtr.ref.CreateRunOptions.asFunction<
        bg.OrtStatusPtr Function(
            ffi.Pointer<ffi.Pointer<bg.OrtRunOptions>>)>()(pp);
    OrtStatus.checkOrtStatus(statusPtr);
    _ptr = pp.value;
    calloc.free(pp);
  }

  void release() {
    OrtEnv.instance.ortApiPtr.ref.ReleaseRunOptions
        .asFunction<void Function(ffi.Pointer<bg.OrtRunOptions> input)>()(_ptr);
  }

  void setRunLogVerbosityLevel(int level) {
    final statusPtr = OrtEnv
        .instance.ortApiPtr.ref.RunOptionsSetRunLogVerbosityLevel
        .asFunction<
            bg.OrtStatusPtr Function(
                ffi.Pointer<bg.OrtRunOptions>, int)>()(_ptr, level);
    OrtStatus.checkOrtStatus(statusPtr);
  }

  int getRunLogVerbosityLevel() {
    final levelPtr = calloc<ffi.Int>();
    final statusPtr = OrtEnv
        .instance.ortApiPtr.ref.RunOptionsGetRunLogVerbosityLevel
        .asFunction<
            bg.OrtStatusPtr Function(ffi.Pointer<bg.OrtRunOptions>,
                ffi.Pointer<ffi.Int>)>()(_ptr, levelPtr);
    OrtStatus.checkOrtStatus(statusPtr);
    final level = levelPtr.value;
    calloc.free(levelPtr);
    return level;
  }

  void setRunLogSeverityLevel(int level) {
    final statusPtr = OrtEnv
        .instance.ortApiPtr.ref.RunOptionsSetRunLogSeverityLevel
        .asFunction<
            bg.OrtStatusPtr Function(
                ffi.Pointer<bg.OrtRunOptions>, int)>()(_ptr, level);
    OrtStatus.checkOrtStatus(statusPtr);
  }

  int getRunLogSeverityLevel() {
    final levelPtr = calloc<ffi.Int>();
    final statusPtr = OrtEnv
        .instance.ortApiPtr.ref.RunOptionsGetRunLogSeverityLevel
        .asFunction<
            bg.OrtStatusPtr Function(ffi.Pointer<bg.OrtRunOptions>,
                ffi.Pointer<ffi.Int>)>()(_ptr, levelPtr);
    OrtStatus.checkOrtStatus(statusPtr);
    final level = levelPtr.value;
    calloc.free(levelPtr);
    return level;
  }

  void setRunTag(String tag) {
    final statusPtr = OrtEnv.instance.ortApiPtr.ref.RunOptionsSetRunTag
            .asFunction<
                bg.OrtStatusPtr Function(
                    ffi.Pointer<bg.OrtRunOptions>, ffi.Pointer<ffi.Char>)>()(
        _ptr, tag.toNativeUtf8().cast<ffi.Char>());
    OrtStatus.checkOrtStatus(statusPtr);
  }

  String getRunTag() {
    final tagPtr = calloc<ffi.Pointer<ffi.Char>>();
    final statusPtr = OrtEnv.instance.ortApiPtr.ref.RunOptionsGetRunTag
        .asFunction<
            bg.OrtStatusPtr Function(ffi.Pointer<bg.OrtRunOptions>,
                ffi.Pointer<ffi.Pointer<ffi.Char>>)>()(_ptr, tagPtr);
    OrtStatus.checkOrtStatus(statusPtr);
    final tag = tagPtr.value.cast<Utf8>().toDartString();
    calloc.free(tagPtr);
    return tag;
  }

  void setTerminate() {
    final statusPtr = OrtEnv.instance.ortApiPtr.ref.RunOptionsSetTerminate
        .asFunction<
            bg.OrtStatusPtr Function(ffi.Pointer<bg.OrtRunOptions>)>()(_ptr);
    OrtStatus.checkOrtStatus(statusPtr);
  }

  void unsetTerminate() {
    final statusPtr = OrtEnv.instance.ortApiPtr.ref.RunOptionsUnsetTerminate
        .asFunction<
            bg.OrtStatusPtr Function(ffi.Pointer<bg.OrtRunOptions>)>()(_ptr);
    OrtStatus.checkOrtStatus(statusPtr);
  }
}

enum GraphOptimizationLevel {
  ortDisableAll(bg.GraphOptimizationLevel.ORT_DISABLE_ALL),
  ortEnableBasic(bg.GraphOptimizationLevel.ORT_ENABLE_BASIC),
  ortEnableExtended(bg.GraphOptimizationLevel.ORT_ENABLE_EXTENDED),
  ortEnableAll(bg.GraphOptimizationLevel.ORT_ENABLE_ALL);

  final int value;

  const GraphOptimizationLevel(this.value);
}
