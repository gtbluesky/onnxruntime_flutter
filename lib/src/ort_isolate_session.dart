import 'dart:async';
import 'dart:isolate';

import 'package:onnxruntime/src/ort_session.dart';
import 'package:onnxruntime/src/ort_value.dart';

/// Isolate wrapper for OrtSession to enable non-blocking async inference.
///
/// **Memory Architecture:**
/// ```
/// ┌─────────────────────────────────────────────────────────┐
/// │                    Flutter App Process                    │
/// ├─────────────────────────┬─────────────────────────────────┤
/// │   Main Isolate (UI)     │     Worker Isolate(s)          │
/// │   - UI rendering        │     - Inference orchestration  │
/// │   - User interaction    │     - Pre/post-processing      │
/// │                         │     - Sends pointers via FFI   │
/// ├─────────────────────────┴─────────────────────────────────┤
/// │                     Dart VM Memory                        │
/// ╞═══════════════════════════════════════════════════════════╡
/// │                     Native Memory (C++)                   │
/// │  ┌──────────────────────────────────────────────────┐    │
/// │  │            ONNX Runtime Session                   │    │
/// │  │  - Model weights (shared)                        │    │
/// │  │  - Computation graph                             │    │
/// │  │  - Native thread pool (inter/intra-op threads)   │    │
/// │  │  - Actual neural network computation             │    │
/// │  └──────────────────────────────────────────────────┘    │
/// └───────────────────────────────────────────────────────────┘
/// ```
///
/// Key Points:
/// - Dart isolates communicate via message passing (no shared memory)
/// - ONNX Runtime lives in native memory (outside Dart heap)
/// - Multiple isolates can call the same ONNX session (via address/pointer)
/// - The actual ML computation happens in native C++ threads, not Dart

class OrtIsolateSession {
  int address;
  final String debugName;
  late Isolate _newIsolate;
  late SendPort _newIsolateSendPort;
  late StreamSubscription _streamSubscription;
  final _outputController = StreamController<List<MapEntry>>.broadcast();

  // Timeout configuration for isolate operations
  final Duration timeout;
  Timer? _timeoutTimer;

  // Queue to handle multiple concurrent calls safely
  final List<Completer<List<MapEntry>>> _pendingRequests = [];
  bool _isProcessing = false;

  // Configuration for handling concurrent calls
  final bool allowQueueing;

  IsolateSessionState get state => _state;
  var _state = IsolateSessionState.idle;
  var _initialized = false;
  final _completer = Completer();

  /// Creates an isolate session for async inference.
  ///
  /// **IMPORTANT: Isolates process messages sequentially!**
  /// Even though an isolate can receive multiple messages, it processes them
  /// one at a time because session.run() is a synchronous, blocking call.
  ///
  /// - Set [allowQueueing] to true to queue concurrent requests (sequential execution)
  /// - Set [allowQueueing] to false to throw an error on concurrent calls (safer)
  /// - For true parallel execution, use multiple isolates via runOnceAsync()
  OrtIsolateSession(
    OrtSession session, {
    this.debugName = 'OnnxRuntimeSessionIsolate',
    this.timeout = const Duration(seconds: 60), // Default 60 second timeout
    this.allowQueueing = false, // Default: reject concurrent calls
  }) : address = session.address;

  Future<void> _init() async {
    // Create a receive port for communication with the new isolate
    final rootIsolateReceivePort = ReceivePort();
    final rootIsolateSendPort = rootIsolateReceivePort.sendPort;

    // Spawn the new isolate for running inference
    _newIsolate = await Isolate.spawn(
        createNewIsolateContext, rootIsolateSendPort,
        debugName: debugName);

    // Listen for messages from the new isolate
    _streamSubscription = rootIsolateReceivePort.listen((message) {
      // Handle initial SendPort message for bidirectional communication
      if (message is SendPort) {
        _newIsolateSendPort = message;
        // Only complete the completer if it hasn't been completed yet
        // This prevents the "Future already completed" error
        if (!_completer.isCompleted) {
          _completer.complete();
        }
      }
      // Handle inference output results
      if (message is List<MapEntry>) {
        // Complete the first pending request with this result
        // This ensures results go to the correct caller
        if (_pendingRequests.isNotEmpty) {
          final completer = _pendingRequests.removeAt(0);
          if (!completer.isCompleted) {
            completer.complete(message);
          }
          _isProcessing = false;
        }
        // Also add to broadcast stream for backward compatibility
        _outputController.add(message);
      }
    });
  }

  static Future<void> createNewIsolateContext(
      SendPort rootIsolateSendPort) async {
    final newIsolateReceivePort = ReceivePort();
    final newIsolateSendPort = newIsolateReceivePort.sendPort;
    rootIsolateSendPort.send(newIsolateSendPort);
    await for (final _IsolateSessionData data in newIsolateReceivePort) {
      final session = OrtSession.fromAddress(data.session);
      final runOptions = OrtRunOptions.fromAddress(data.runOptions);
      final inputs = data.inputs.map(
          (key, value) => MapEntry(key, OrtValueTensor.fromAddress(value)));
      final outputNames = data.outputNames;
      final outputs = session.run(runOptions, inputs, outputNames).map((e) {
        ONNXType onnxType;
        if (e is OrtValueTensor) {
          onnxType = ONNXType.tensor;
        } else if (e is OrtValueSequence) {
          onnxType = ONNXType.sequence;
        } else if (e is OrtValueMap) {
          onnxType = ONNXType.map;
        } else if (e is OrtValueSparseTensor) {
          onnxType = ONNXType.sparseTensor;
        } else {
          onnxType = ONNXType.tensor;
        }
        return MapEntry(onnxType.value, e?.address);
      }).toList();
      rootIsolateSendPort.send(outputs);
    }
  }

  Future<List<OrtValue?>> run(
      OrtRunOptions runOptions, Map<String, OrtValue> inputs,
      [List<String>? outputNames]) async {
    // Initialize isolate if not already initialized
    if (!_initialized) {
      await _init();
      await _completer.future;
      _initialized = true;
    }

    // Check if already processing a request
    // For persistent isolates, we need to queue or reject concurrent calls
    if (_isProcessing) {
      if (allowQueueing) {
        // Option 1: Queue the request (will process sequentially)
        // WARNING: This does NOT give parallel execution!
        // The isolate will process these one by one, not concurrently
        final resultCompleter = Completer<List<MapEntry>>();
        _pendingRequests.add(resultCompleter);

        // Wait for our turn in the queue
        final result = await resultCompleter.future.timeout(
          timeout,
          onTimeout: () {
            _pendingRequests.remove(resultCompleter);
            throw TimeoutException(
              'Queued request timed out after ${timeout.inSeconds} seconds',
              timeout,
            );
          },
        );
        return _processResult(result);
      } else {
        // Option 2: Throw an error for concurrent calls (default, safer)
        throw StateError(
          'This isolate session is already processing a request. '
          'Isolates process requests SEQUENTIALLY, not in parallel. '
          'Use runOnceAsync() for true parallel inference, or await the previous call.'
        );
      }
    }

    _isProcessing = true;

    // Transform inputs to addresses for sending to isolate
    final transformedInputs =
        inputs.map((key, value) => MapEntry(key, value.address));
    _state = IsolateSessionState.loading;

    // Prepare data to send to isolate
    final data = _IsolateSessionData(
        session: address,
        runOptions: runOptions.address,
        inputs: transformedInputs,
        outputNames: outputNames);

    // Create a completer for this specific request
    final resultCompleter = Completer<List<MapEntry>>();
    _pendingRequests.add(resultCompleter);

    // Start timeout timer for this inference run
    _startTimeoutTimer();

    try {
      // Send data to isolate for processing
      _newIsolateSendPort.send(data);

      // Wait for result with timeout
      final result = await resultCompleter.future.timeout(
        timeout,
        onTimeout: () {
          // Clean up and throw timeout error
          _cancelTimeoutTimer();
          _isProcessing = false;
          // Remove this request from pending
          _pendingRequests.remove(resultCompleter);
          throw TimeoutException(
            'Isolate inference timed out after ${timeout.inSeconds} seconds',
            timeout,
          );
        },
      );

      // Process the result from isolate
      final outputs = _processResult(result);
      _state = IsolateSessionState.idle;
      // Cancel timeout timer on successful completion
      _cancelTimeoutTimer();
      return outputs;
    } catch (e) {
      // Handle timeout or other errors
      _state = IsolateSessionState.idle;
      _cancelTimeoutTimer();
      _isProcessing = false;

      // If it's a timeout, optionally kill and restart the isolate
      if (e is TimeoutException) {
        // Kill the potentially stuck isolate
        _newIsolate.kill(priority: Isolate.immediate);
        // Mark as uninitialized so it will be recreated on next run
        _initialized = false;
        // Clear any pending requests
        _pendingRequests.clear();
      }

      rethrow;
    }
  }

  /// Process the raw result from the isolate into OrtValue objects
  List<OrtValue?> _processResult(List<MapEntry> result) {
    return result.map((e) {
      final onnxType = ONNXType.valueOf(e.key);
      switch (onnxType) {
        case ONNXType.tensor:
          return OrtValueTensor.fromAddress(e.value);
        case ONNXType.sequence:
          return OrtValueSparseTensor.fromAddress(e.value);
        case ONNXType.map:
          return OrtValueMap.fromAddress(e.value);
        case ONNXType.sparseTensor:
          return OrtValueSparseTensor.fromAddress(e.value);
        default:
          return null;
      }
    }).toList();
  }

  /// Starts a timeout timer that will kill the isolate if it doesn't respond
  void _startTimeoutTimer() {
    _cancelTimeoutTimer(); // Cancel any existing timer
    _timeoutTimer = Timer(timeout, () {
      // If timer fires, kill the isolate as it might be stuck
      if (_state == IsolateSessionState.loading) {
        _newIsolate.kill(priority: Isolate.immediate);
        _initialized = false;
        _state = IsolateSessionState.idle;
      }
    });
  }

  /// Cancels the timeout timer
  void _cancelTimeoutTimer() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
  }

  Future<void> release() async {
    // Cancel any pending timeout timer
    _cancelTimeoutTimer();
    // Clean up resources
    await _streamSubscription.cancel();
    await _outputController.close();
    _newIsolate.kill();
  }
}

enum IsolateSessionState {
  idle,
  loading,
}

class _IsolateSessionData {
  _IsolateSessionData(
      {required this.session,
      required this.runOptions,
      required this.inputs,
      this.outputNames});

  final int session;
  final int runOptions;
  final Map<String, int> inputs;
  final List<String>? outputNames;
}
