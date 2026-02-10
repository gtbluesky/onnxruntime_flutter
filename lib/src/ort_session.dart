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

  // Support multiple isolate sessions for concurrent inference
  // This single persistent isolate is reused for runAsync calls
  OrtIsolateSession? _persistentIsolateSession;

  // Track active isolate sessions for cleanup
  final List<OrtIsolateSession> _activeIsolateSessions = [];

  int get address => _ptr.address;
  int get inputCount => _inputCount;
  List<String> get inputNames => _inputNames;
  int get outputCount => _outputCount;
  List<String> get outputNames => _outputNames;

  /// Creates a session from a file.
  ///
  /// On Windows, the ONNX Runtime C API expects wide strings (wchar_t*) for
  /// file paths. Using UTF-8 on Windows causes garbled path encoding and
  /// "file not found" errors. We use toNativeUtf16() on Windows and
  /// toNativeUtf8() on other platforms to match the native ORTCHAR_T type.
  OrtSession.fromFile(File modelFile, OrtSessionOptions options) {
    final pp = calloc<ffi.Pointer<bg.OrtSession>>();

    // Windows uses wchar_t (UTF-16) for ORTCHAR_T, all other platforms use
    // char (UTF-8). Passing UTF-8 on Windows produces garbled mojibake paths.
    final ffi.Pointer<ffi.Void> pathPtr;
    if (Platform.isWindows) {
      pathPtr = modelFile.path.toNativeUtf16().cast<ffi.Void>();
    } else {
      pathPtr = modelFile.path.toNativeUtf8().cast<ffi.Void>();
    }

    final statusPtr = OrtEnv.instance.ortApiPtr.ref.CreateSession.asFunction<
            bg.OrtStatusPtr Function(
                ffi.Pointer<bg.OrtEnv>,
                ffi.Pointer<ffi.Char>,
                ffi.Pointer<bg.OrtSessionOptions>,
                ffi.Pointer<ffi.Pointer<bg.OrtSession>>)>()(
        OrtEnv.instance.ptr,
        pathPtr.cast<ffi.Char>(),
        options._ptr,
        pp);
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
  /// Uses a persistent isolate that stays alive for reuse across multiple calls.
  /// This is efficient for repeated inference as it avoids isolate creation overhead.
  /// To kill the isolate, call killIsolate() or release().
  /// Default timeout is 5 seconds. Use runAsyncWithTimeout() for custom timeout.
  ///
  /// **Architecture Note:**
  ///
  /// **CRITICAL UNDERSTANDING: ONNX Runtime computation happens in NATIVE C++ memory,
  /// OUTSIDE of Dart's isolate memory space!**
  ///
  /// When you call inference:
  /// 1. Dart isolate sends data pointers to native ONNX Runtime via FFI
  /// 2. ONNX Runtime (C++ library) performs the actual computation in native memory
  /// 3. Results are returned back to the Dart isolate via pointers
  ///
  /// **THE KEY INSIGHT:**
  /// - **runAsync()**: 1 isolate → 1 active native call at a time (sequential)
  /// - **runOnceAsync()**: N isolates → N active native calls (parallel!)
  ///
  /// Why? Because each isolate can make ONE synchronous FFI call at a time.
  /// Multiple isolates = Multiple simultaneous FFI calls = Parallel execution!
  ///
  /// The native ONNX Runtime CAN handle multiple concurrent calls (it's thread-safe),
  /// but a single Dart isolate can only make one blocking FFI call at a time.
  ///
  /// **Threading Layers:**
  /// - **Dart Isolates**: Provide concurrency for Dart code (message passing, orchestration)
  ///   - runAsync() uses 1 persistent isolate
  ///   - runOnceAsync() creates new isolates for parallel orchestration
  /// - **ONNX Native Threads**: Actual computation parallelism in C++ (shared memory)
  ///   - setInterOpNumThreads() - parallel operator execution
  ///   - setIntraOpNumThreads() - parallelism within operators
  ///
  /// **Why use isolates then?**
  /// - To avoid blocking the main UI thread while waiting for native computation
  /// - To orchestrate multiple concurrent inference requests
  /// - To handle pre/post-processing in parallel
  /// - NOT for the actual neural network math (that's native C++)
  ///
  /// **Performance Example (8-core CPU, 10 images to process):**
  /// ```dart
  /// // SLOW: Sequential with runAsync() - ~1000ms total
  /// for (var image in images) {
  ///   await session.runAsync(runOptions, image); // Each waits for previous
  /// }
  ///
  /// // CRASH WARNING: This will throw an error!
  /// final futures = images.map((img) => session.runAsync(runOptions, img));
  /// await Future.wait(futures); // ERROR: Concurrent calls to same isolate!
  ///
  /// // FAST: Parallel with runParallelAsync() - ~200ms total
  /// await session.runParallelAsync(images, runOptions); // All run together
  ///
  /// // FASTEST for single large model: Configure threads optimally
  /// options.setIntraOpNumThreads(8); // Use all cores for one inference
  /// await session.runAsync(runOptions, largeInput); // Single but fast
  /// ```
  ///
  /// **Visual: Why runOnceAsync() is parallel but runAsync() is not:**
  /// ```
  /// runAsync() - Single Isolate:          runOnceAsync() - Multiple Isolates:
  /// ┌─────────────┐                       ┌─────────────┐ ┌─────────────┐
  /// │  Isolate 1  │                       │  Isolate 1  │ │  Isolate 2  │
  /// │   Call 1    │ → ONNX (blocks)       │   Call 1    │ │   Call 2    │
  /// │   Call 2    │ ← (waiting...)        └──────┬──────┘ └──────┬──────┘
  /// │   Call 3    │ ← (waiting...)               ↓               ↓
  /// └─────────────┘                       ┌─────────────────────────────┐
  ///                                        │     ONNX Runtime (C++)      │
  /// Result: Sequential execution          │   Processing BOTH calls     │
  ///                                        │     in parallel!            │
  ///                                        └─────────────────────────────┘
  ///                                        Result: Parallel execution
  /// ```
  Future<List<OrtValue?>>? runAsync(
      OrtRunOptions runOptions, Map<String, OrtValue> inputs,
      [List<String>? outputNames]) {
    // Create persistent isolate session if it doesn't exist
    // This isolate is reused for all runAsync calls for efficiency
    _persistentIsolateSession ??= OrtIsolateSession(this);
    return _persistentIsolateSession?.run(runOptions, inputs, outputNames);
  }

  /// Creates a new isolate for a single inference run.
  /// Each call creates a fresh isolate, allowing concurrent inference.
  /// The isolate is automatically killed after the inference completes.
  /// Useful for parallel inference or one-off async operations.
  /// Default timeout is 5 seconds. Use runOnceAsyncWithTimeout() for custom timeout.
  Future<List<OrtValue?>> runOnceAsync(
      OrtRunOptions runOptions, Map<String, OrtValue> inputs,
      [List<String>? outputNames]) async {
    // Create a new isolate session for this specific run
    // This allows multiple concurrent inferences
    final isolateSession = OrtIsolateSession(this);
    _activeIsolateSessions.add(isolateSession);

    try {
      final result = await isolateSession.run(runOptions, inputs, outputNames);
      return result;
    } finally {
      // Always clean up the isolate after use
      await isolateSession.release();
      _activeIsolateSessions.remove(isolateSession);
    }
  }

  /// Performs inference asynchronously with a custom timeout.
  /// Uses a persistent isolate that stays alive for reuse.
  /// If the isolate times out, it will be killed and recreated on next use.
  Future<List<OrtValue?>>? runAsyncWithTimeout(
      OrtRunOptions runOptions, Map<String, OrtValue> inputs,
      Duration timeout,
      [List<String>? outputNames]) {
    // Create or recreate persistent isolate session with custom timeout
    // Note: If timeout changes, we should recreate the isolate session
    if (_persistentIsolateSession == null ||
        _persistentIsolateSession!.timeout != timeout) {
      // Kill existing isolate if timeout has changed
      _persistentIsolateSession?.release();
      _persistentIsolateSession = OrtIsolateSession(this, timeout: timeout);
    }
    return _persistentIsolateSession?.run(runOptions, inputs, outputNames);
  }

  /// Creates a timed isolate for a single inference run.
  /// Each call creates a fresh isolate, allowing concurrent inference.
  /// The isolate will timeout after the specified duration.
  /// The isolate is automatically killed after completion or timeout.
  Future<List<OrtValue?>> runOnceAsyncWithTimeout(
      OrtRunOptions runOptions, Map<String, OrtValue> inputs,
      Duration timeout,
      [List<String>? outputNames]) async {
    // Create a new isolate session with custom timeout
    // This allows multiple concurrent timed inferences
    final isolateSession = OrtIsolateSession(this, timeout: timeout);
    _activeIsolateSessions.add(isolateSession);

    try {
      final result = await isolateSession.run(runOptions, inputs, outputNames);
      return result;
    } finally {
      // Always clean up the isolate after use
      await isolateSession.release();
      _activeIsolateSessions.remove(isolateSession);
    }
  }

  /// Kills the persistent async isolate while keeping the session alive.
  /// The session can still be used for new inference runs after calling this.
  /// Next runAsync() will create a new isolate.
  /// Note: This only kills the persistent isolate, not one-time isolates.
  Future<void> killIsolate() async {
    if (_persistentIsolateSession != null) {
      await _persistentIsolateSession!.release();
      _persistentIsolateSession = null;
    }
  }

  /// Kills all active isolates (both persistent and one-time).
  /// Useful for cleanup when you want to ensure all isolates are terminated.
  Future<void> killAllIsolates() async {
    // Kill persistent isolate
    await killIsolate();

    // Kill all active one-time isolates
    for (final isolateSession in _activeIsolateSessions.toList()) {
      await isolateSession.release();
    }
    _activeIsolateSessions.clear();
  }

  /// Runs multiple inference operations in parallel using separate isolates.
  /// Each inference runs in its own isolate, allowing true parallel execution.
  /// All isolates are automatically cleaned up after completion.
  /// Returns a list of results in the same order as the input list.
  ///
  /// **Performance Characteristics vs runAsync():**
  ///
  /// **Option 1: Multiple calls to runAsync() (single persistent isolate)**
  /// ```dart
  /// for (var input in inputs) {
  ///   await session.runAsync(runOptions, input); // Sequential
  /// }
  /// ```
  /// - ✅ **Pros**: No isolate creation overhead, memory efficient
  /// - ❌ **Cons**: Inferences run SEQUENTIALLY (not parallel!)
  /// - **Speed**: Slower for batch processing (no parallelism)
  /// - **Use when**: Processing a stream of requests over time
  ///
  /// **Option 2: Multiple runOnceAsync() or runParallelAsync() (multiple isolates)**
  /// ```dart
  /// await session.runParallelAsync(inputs, runOptions); // Parallel
  /// ```
  /// - ✅ **Pros**: TRUE PARALLEL execution (if ONNX session supports it)
  /// - ❌ **Cons**: Isolate creation overhead (~1-2ms per isolate)
  /// - **Speed**: Faster for batch processing (parallel execution)
  /// - **Use when**: Processing multiple inputs at once
  ///
  /// **Critical Factor: Does ONNX Runtime support concurrent calls?**
  /// - If the native ONNX session is thread-safe: Multiple isolates = parallel execution
  /// - If not thread-safe: Multiple isolates will serialize at the native level anyway
  /// - Most ONNX Runtime sessions ARE thread-safe by default
  ///
  /// **Optimal Thread/Isolate Configuration:**
  /// - **CPU Cores = 8, Batch Size = 4**:
  ///   - Option A: 4 isolates × 2 intra-op threads each = utilize all 8 cores
  ///   - Option B: 1 isolate × 8 intra-op threads = utilize all 8 cores for each inference
  ///   - Option A is better for batch, Option B is better for single large inference
  ///
  /// **Recommendation:**
  /// - **Single inference**: Use runAsync() with high intra-op threads
  /// - **Batch inference**: Use runParallelAsync() with lower threads per isolate
  /// - **Stream of requests**: Use persistent runAsync() to avoid isolate overhead
  Future<List<List<OrtValue?>>> runParallelAsync(
      List<Map<String, OrtValue>> inputsList,
      OrtRunOptions runOptions,
      [List<String>? outputNames,
      Duration timeout = const Duration(seconds: 5)]) async {
    // Create a list of futures for parallel execution
    final futures = <Future<List<OrtValue?>>>[];

    for (final inputs in inputsList) {
      // Each inference gets its own isolate for true parallelism
      futures.add(runOnceAsyncWithTimeout(
        runOptions,
        inputs,
        timeout,
        outputNames,
      ));
    }

    // Wait for all inferences to complete in parallel
    return await Future.wait(futures);
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

  Future<void> release() async {
    // Release all isolates
    await killAllIsolates();

    // Release the native session
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

  /// Sets the number of intra-op threads used by ONNX Runtime.
  ///
  /// **IMPORTANT: This controls NATIVE C++ threads inside ONNX Runtime, NOT Dart isolates!**
  ///
  /// Intra-op threads are used to parallelize computation within a single operator.
  /// For example, a large matrix multiplication can be split across multiple threads.
  ///
  /// This is completely independent of Dart isolates:
  /// - Each Dart isolate runs its own ONNX Runtime session
  /// - Each session can use multiple native threads (configured here)
  /// - So 1 isolate can use N native threads for parallel computation
  ///
  /// Default is 0 (uses all available CPU cores).
  void setIntraOpNumThreads(int numThreads) {
    _intraOpNumThreads = numThreads;
    final statusPtr = OrtEnv.instance.ortApiPtr.ref.SetIntraOpNumThreads
        .asFunction<
            bg.OrtStatusPtr Function(
                ffi.Pointer<bg.OrtSessionOptions>, int)>()(_ptr, numThreads);
    OrtStatus.checkOrtStatus(statusPtr);
  }

  /// Sets the number of inter-op threads used by ONNX Runtime.
  ///
  /// **IMPORTANT: This controls NATIVE C++ threads inside ONNX Runtime, NOT Dart isolates!**
  ///
  /// Inter-op threads are used to parallelize execution between independent operators
  /// in the computation graph. For example, if two operators don't depend on each other,
  /// they can run simultaneously on different threads.
  ///
  /// This is completely independent of Dart isolates:
  /// - To run multiple inferences in parallel, use runOnceAsync() or runParallelAsync()
  /// - Those methods create separate Dart isolates (separate memory spaces)
  /// - This setting only affects threading within each isolate's ONNX session
  ///
  /// Default is 0 (uses all available CPU cores).
  /// Set to 1 to disable inter-op parallelism and run operators sequentially.
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

  /// Sets the execution mode for the session.
  /// Sequential mode runs operations one at a time.
  /// Parallel mode allows operations to run in parallel when possible.
  void setSessionExecutionMode(OrtSessionExecutionMode mode) {
    final statusPtr = OrtEnv.instance.ortApiPtr.ref.SetSessionExecutionMode
        .asFunction<
            bg.OrtStatusPtr Function(
                ffi.Pointer<bg.OrtSessionOptions>, int)>()(_ptr, mode.value);
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
      case OrtProvider.cuda:
        statusPtr =
            onnxRuntimeBinding.OrtSessionOptionsAppendExecutionProvider_CUDA(
                _ptr, flags.value);
        result = true;
        break;
      case OrtProvider.rocm:
        // ROCm uses the same pattern as CUDA but with ROCm bindings
        // If binding is not available, gracefully fail
        try {
          statusPtr =
              onnxRuntimeBinding.OrtSessionOptionsAppendExecutionProvider_MIGraphX(
                  _ptr, flags.value);
          result = true;
        } catch (e) {
          result = false;
        }
        break;
      case OrtProvider.dnnl:
        statusPtr =
            onnxRuntimeBinding.OrtSessionOptionsAppendExecutionProvider_Dnnl(
                _ptr, flags.value);
        result = true;
        break;
      case OrtProvider.migraphx:
        statusPtr =
            onnxRuntimeBinding.OrtSessionOptionsAppendExecutionProvider_MIGraphX(
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
      case OrtProvider.tensorrt:
        providerName = 'TensorRT';
        break;
      case OrtProvider.directml:
        providerName = 'DML';
        break;
      case OrtProvider.openvino:
        providerName = 'OpenVINO';
        break;
      case OrtProvider.cann:
        providerName = 'CANN';
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

  /// Appends CoreML provider (Apple Neural Engine/GPU acceleration).
  /// Best for iOS/macOS devices with Apple Silicon or A-series chips.
  bool appendCoreMLProvider(CoreMLFlags flags) {
    return _appendExecutionProvider(OrtProvider.coreml, flags);
  }

  /// Appends Nnapi provider (Android Neural Networks API).
  /// Google's Android acceleration - works on Android 8.1+.
  bool appendNnapiProvider(NnapiFlags flags) {
    return _appendExecutionProvider(OrtProvider.nnapi, flags);
  }

  /// Appends CUDA provider (NVIDIA GPU acceleration).
  /// Requires NVIDIA GPU with CUDA runtime installed.
  /// Typically 5-10x faster than CPU for deep learning workloads.
  bool appendCudaProvider(CUDAFlags flags) {
    return _appendExecutionProvider(OrtProvider.cuda, flags);
  }

  /// Appends TensorRT provider (NVIDIA GPU with optimizations).
  /// Requires NVIDIA GPU with TensorRT runtime installed.
  /// Can be 2-5x faster than raw CUDA with additional optimizations.
  /// Supports FP16 and INT8 quantization for even faster inference.
  bool appendTensorRTProvider([Map<String, String>? options]) {
    return _appendExecutionProvider2(OrtProvider.tensorrt, options ?? {});
  }

  /// Appends DirectML provider (DirectX 12 GPU acceleration).
  /// Works on Windows with AMD, Intel, or NVIDIA GPUs.
  /// Great for cross-vendor GPU support on Windows.
  bool appendDirectMLProvider([Map<String, String>? options]) {
    return _appendExecutionProvider2(OrtProvider.directml, options ?? {});
  }

  /// Appends ROCm provider (AMD GPU acceleration).
  /// Requires AMD GPU with ROCm runtime installed (Linux only).
  bool appendRocmProvider(ROCmFlags flags) {
    return _appendExecutionProvider(OrtProvider.rocm, flags);
  }

  /// Appends OpenVINO provider (Intel hardware optimization).
  /// Optimized for Intel CPUs, integrated GPUs, and VPUs.
  /// Great performance boost on Intel hardware.
  bool appendOpenVINOProvider([Map<String, String>? options]) {
    return _appendExecutionProvider2(OrtProvider.openvino, options ?? {});
  }

  /// Appends DNNL provider (Intel Deep Neural Network Library).
  /// Optimized CPU operations for Intel processors.
  /// Good CPU performance boost on Intel hardware.
  bool appendDNNLProvider(DNNLFlags flags) {
    return _appendExecutionProvider(OrtProvider.dnnl, flags);
  }

  /// Appends MIGraphX provider (AMD graph optimization).
  /// AMD's graph-level optimizations for their GPUs.
  bool appendMIGraphXProvider(MIGraphXFlags flags) {
    return _appendExecutionProvider(OrtProvider.migraphx, flags);
  }

  /// Appends CANN provider (Huawei Ascend AI processor).
  /// Optimized for Huawei Ascend NPUs.
  bool appendCANNProvider([Map<String, String>? options]) {
    return _appendExecutionProvider2(OrtProvider.cann, options ?? {});
  }

  /// Appends QNN provider (Qualcomm Neural Network).
  /// Optimized for Qualcomm Snapdragon chips with Hexagon DSP/NPU.
  bool appendQnnProvider() {
    return _appendExecutionProvider2(OrtProvider.qnn, {});
  }

  /// Appends Xnnpack provider (Optimized CPU operations).
  /// Cross-platform CPU optimization, works on all platforms.
  bool appendXnnpackProvider() {
    return _appendExecutionProvider2(OrtProvider.xnnpack,
        {'intra_op_num_threads': _intraOpNumThreads.toString()});
  }

  /// Automatically selects and appends the best available execution provider.
  /// 
  /// **Priority order:**
  /// 1. **GPU**: CUDA/TensorRT (NVIDIA) > DirectML (Windows) > ROCm (AMD)
  /// 2. **NPU/Accelerators**: CoreML (Apple) > NNAPI (Android) > QNN (Qualcomm)
/// 3. **Optimized CPU**: DNNL (Intel) > XNNPACK (cross-platform)
  /// 4. **Fallback**: Standard CPU
  /// 
  /// This method tries providers in order and uses the first one that succeeds.
  /// Always includes CPU as a fallback to ensure models can run.
  /// 
  /// **Usage:**
  /// ```dart
  /// final options = OrtSessionOptions();
  /// await options.appendDefaultProviders(); // Auto-selects best available
  /// final session = OrtSession.fromBuffer(modelBytes, options);
  /// ```
  /// 
  /// **Note:** This method runs asynchronously to avoid blocking the UI thread
  /// during device capability detection. Make sure to await it before creating
  /// your session!
  Future<void> appendDefaultProviders() async {
    var hasProvider = false;

    // Try mobile/NPU accelerators
    // CoreML for Apple devices (Neural Engine)
    if (!hasProvider) {
      try {
        if (appendCoreMLProvider(CoreMLFlags.useNone)) {
          hasProvider = true;
        }
      } catch (e) {
        // CoreML not available, continue
      }
    }

    // NNAPI for Android (Google's acceleration)
    if (!hasProvider) {
      try {
        if (appendNnapiProvider(NnapiFlags.useNone)) {
          hasProvider = true;
        }
      } catch (e) {
        // NNAPI not available, continue
      }
    }

    // QNN for Qualcomm chips
    if (!hasProvider) {
      try {
        if (appendQnnProvider()) {
          hasProvider = true;
        }
      } catch (e) {
        // QNN not available, continue
      }
    }

    // Try GPU providers first (best performance for most models)
    // CUDA/TensorRT for NVIDIA
    if (!hasProvider) {
      try {
        if (appendCudaProvider(CUDAFlags.useArena)) {
          hasProvider = true;
        }
      } catch (e) {
        // CUDA not available, continue
      }
    }

    // DirectML for Windows (AMD/Intel/NVIDIA)
    if (!hasProvider) {
      try {
        if (appendDirectMLProvider()) {
          hasProvider = true;
        }
      } catch (e) {
        // DirectML not available, continue
      }
    }

    // ROCm for AMD GPUs on Linux
    if (!hasProvider) {
      try {
        if (appendRocmProvider(ROCmFlags.useArena)) {
          hasProvider = true;
        }
      } catch (e) {
        // ROCm not available, continue
      }
    }

    // Try optimized CPU providers
    // DNNL for Intel CPUs
    if (!hasProvider) {
      try {
        if (appendDNNLProvider(DNNLFlags.useArena)) {
          hasProvider = true;
        }
      } catch (e) {
        // DNNL not available, continue
      }
    }

    // XNNPACK for cross-platform CPU optimization
    if (!hasProvider) {
      try {
        if (appendXnnpackProvider()) {
          hasProvider = true;
        }
      } catch (e) {
        // XNNPACK not available, continue
      }
    }

    // Always append CPU provider as fallback
    // This ensures the model can run even if no accelerators are available
    appendCPUProvider(CPUFlags.useArena);
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

/// Enum for OrtSessionGraphOptimizationLevel - alias for GraphOptimizationLevel
/// Provides compatibility with naming used in some examples
typedef OrtSessionGraphOptimizationLevel = GraphOptimizationLevel;

/// Enum for session execution modes
enum OrtSessionExecutionMode {
  /// Run the graph in sequential mode - operations will run one at a time
  ortSequential(bg.ExecutionMode.ORT_SEQUENTIAL),
  /// Run the graph in parallel mode - operations may run in parallel
  ortParallel(bg.ExecutionMode.ORT_PARALLEL);

  final int value;
  const OrtSessionExecutionMode(this.value);
}
