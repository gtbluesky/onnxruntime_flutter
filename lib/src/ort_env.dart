import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';
import 'package:onnxruntime/src/bindings/bindings.dart';
import 'package:onnxruntime/src/bindings/onnxruntime_bindings_generated.dart'
    as bindings;
import 'package:onnxruntime/src/ort_provider.dart';
import 'package:onnxruntime/src/ort_status.dart';

class OrtEnv {
  static final OrtEnv _instance = OrtEnv._();

  static OrtEnv get instance => _instance;

  ffi.Pointer<bindings.OrtEnv>? _ptr;

  late ffi.Pointer<bindings.OrtApi> _ortApiPtr;

  OrtEnv._() {
    _ortApiPtr = onnxRuntimeBinding.OrtGetApiBase()
            .ref
            .GetApi
            .asFunction<ffi.Pointer<bindings.OrtApi> Function(int)>()(
        _OrtApiVersion.api14.value);
  }

  init(
      {OrtLoggingLevel level = OrtLoggingLevel.warning,
      String logId = 'DartOnnxRuntime',
      OrtThreadingOptions? options}) {
    final pp = calloc<ffi.Pointer<bindings.OrtEnv>>();
    bindings.OrtStatusPtr statusPtr;
    if (options == null) {
      statusPtr = _ortApiPtr.ref.CreateEnv.asFunction<
              bindings.OrtStatusPtr Function(int, ffi.Pointer<ffi.Char>,
                  ffi.Pointer<ffi.Pointer<bindings.OrtEnv>>)>()(
          level.value,
          logId.toNativeUtf8().cast<ffi.Char>(),
          pp);
    } else {
      statusPtr = _ortApiPtr.ref.CreateEnvWithGlobalThreadPools.asFunction<
              bindings.OrtStatusPtr Function(
                  int,
                  ffi.Pointer<ffi.Char>,
                  ffi.Pointer<bindings.OrtThreadingOptions>,
                  ffi.Pointer<ffi.Pointer<bindings.OrtEnv>>)>()(
          level.value,
          logId.toNativeUtf8().cast<ffi.Char>(),
          options._ptr,
          pp
      );
    }
    OrtStatus.checkOrtStatus(statusPtr);
    _ptr = pp.value;
    _setLanguageProjection();
    calloc.free(pp);
  }

  release() {
    if (_ptr == null) {
      return;
    }
    _ortApiPtr.ref.ReleaseEnv
        .asFunction<void Function(ffi.Pointer<bindings.OrtEnv>)>()(_ptr!);
    _ptr = null;
  }

  static String get version => onnxRuntimeBinding.OrtGetApiBase()
      .ref
      .GetVersionString
      .asFunction<ffi.Pointer<ffi.Char> Function()>()()
      .cast<Utf8>()
      .toDartString();

  ffi.Pointer<bindings.OrtApi> get ortApiPtr => _ortApiPtr;

  ffi.Pointer<bindings.OrtEnv> get ptr {
    if (_ptr == null) {
      init();
    }
    return _ptr!;
  }

  List<OrtProvider> availableProviders() {
    final providersPtr = calloc<ffi.Pointer<ffi.Pointer<ffi.Char>>>();
    final lengthPtr = calloc<ffi.Int>();
    var statusPtr = ortApiPtr.ref.GetAvailableProviders.asFunction<
        bindings.OrtStatusPtr Function(
            ffi.Pointer<ffi.Pointer<ffi.Pointer<ffi.Char>>>,
            ffi.Pointer<ffi.Int>)>()(providersPtr, lengthPtr);
    OrtStatus.checkOrtStatus(statusPtr);
    int length = lengthPtr.value;
    final list = List<OrtProvider>.generate(length, (index) {
      final provider = providersPtr.value[index].cast<Utf8>().toDartString();
      return OrtProvider.valueOf(provider);
    });
    statusPtr = ortApiPtr.ref.ReleaseAvailableProviders.asFunction<
        bindings.OrtStatusPtr Function(ffi.Pointer<ffi.Pointer<ffi.Char>>,
            int)>()(providersPtr.value, lengthPtr.value);
    OrtStatus.checkOrtStatus(statusPtr);
    calloc.free(providersPtr);
    calloc.free(lengthPtr);
    return list;
  }

  _setLanguageProjection() {
    if (_ptr == null) {
      init();
    }
    final status = _ortApiPtr.ref.SetLanguageProjection.asFunction<
        bindings.OrtStatusPtr Function(ffi.Pointer<bindings.OrtEnv>,
            int)>()(_ptr!, bindings.OrtLanguageProjection.ORT_PROJECTION_C);
    OrtStatus.checkOrtStatus(status);
  }
}

enum _OrtApiVersion {
  /// The initial release of the ORT API.
  api1(1),

  /// Post 1.0 builds of the ORT API.
  api2(2),

  /// Post 1.3 builds of the ORT API
  api3(3),

  /// Post 1.6 builds of the ORT API
  api7(7),

  /// Post 1.7 builds of the ORT API
  api8(8),

  /// Post 1.10 builds of the ORT API
  api11(11),

  /// Post 1.12 builds of the ORT API
  api13(13),

  /// Post 1.13 builds of the ORT API
  api14(14),

  /// The initial release of the ORT training API.
  trainingApi1(1);

  final int value;

  const _OrtApiVersion(this.value);

}

enum OrtLoggingLevel {
  verbose(bindings.OrtLoggingLevel.ORT_LOGGING_LEVEL_VERBOSE),
  info(bindings.OrtLoggingLevel.ORT_LOGGING_LEVEL_INFO),
  warning(bindings.OrtLoggingLevel.ORT_LOGGING_LEVEL_WARNING),
  error(bindings.OrtLoggingLevel.ORT_LOGGING_LEVEL_ERROR),
  fatal(bindings.OrtLoggingLevel.ORT_LOGGING_LEVEL_FATAL);

  final int value;

  const OrtLoggingLevel(this.value);
}

class OrtThreadingOptions {
  late ffi.Pointer<bindings.OrtThreadingOptions> _ptr;

  OrtThreadingOptions() {
    _create();
  }

  _create() {
    final pp = calloc<ffi.Pointer<bindings.OrtThreadingOptions>>();
    final statusPtr = OrtEnv.instance.ortApiPtr.ref.CreateThreadingOptions.asFunction<
        bindings.OrtStatusPtr Function(
            ffi.Pointer<ffi.Pointer<bindings.OrtThreadingOptions>>)>()(pp);
    OrtStatus.checkOrtStatus(statusPtr);
    _ptr = pp.value;
    calloc.free(pp);
  }

  release() {
    OrtEnv.instance.ortApiPtr.ref.ReleaseThreadingOptions.asFunction<
        void Function(ffi.Pointer<bindings.OrtThreadingOptions>)>()(_ptr);
  }

  setGlobalIntraOpNumThreads(int numThreads) {
    final statusPtr = OrtEnv.instance.ortApiPtr.ref.SetGlobalIntraOpNumThreads.asFunction<
        bindings.OrtStatusPtr Function(
            ffi.Pointer<bindings.OrtThreadingOptions>,
            int)>()(_ptr, numThreads);
    OrtStatus.checkOrtStatus(statusPtr);
  }

  setGlobalInterOpNumThreads(int numThreads) {
    final statusPtr = OrtEnv.instance.ortApiPtr.ref.SetGlobalInterOpNumThreads.asFunction<
        bindings.OrtStatusPtr Function(
            ffi.Pointer<bindings.OrtThreadingOptions>,
            int)>()(_ptr, numThreads);
    OrtStatus.checkOrtStatus(statusPtr);
  }

  setGlobalSpinControl(bool allowSpinning) {
    final statusPtr = OrtEnv.instance.ortApiPtr.ref.SetGlobalSpinControl.asFunction<
        bindings.OrtStatusPtr Function(
            ffi.Pointer<bindings.OrtThreadingOptions>,
            int)>()(_ptr, allowSpinning ? 1 : 0);
    OrtStatus.checkOrtStatus(statusPtr);
  }

  setGlobalDenormalAsZero() {
    final statusPtr = OrtEnv.instance.ortApiPtr.ref.SetGlobalDenormalAsZero.asFunction<
        bindings.OrtStatusPtr Function(
            ffi.Pointer<bindings.OrtThreadingOptions>)>()(_ptr);
    OrtStatus.checkOrtStatus(statusPtr);
  }

  setGlobalIntraOpThreadAffinity(String affinity) {
    final statusPtr = OrtEnv.instance.ortApiPtr.ref.SetGlobalIntraOpThreadAffinity.asFunction<
            bindings.OrtStatusPtr Function(
                ffi.Pointer<bindings.OrtThreadingOptions>,
                ffi.Pointer<ffi.Char>)>()(
        _ptr, affinity.toNativeUtf8().cast<ffi.Char>());
    OrtStatus.checkOrtStatus(statusPtr);
  }
}

class OrtAllocator {
  late ffi.Pointer<bindings.OrtAllocator> _ptr;

  static final OrtAllocator _instance = OrtAllocator._();

  static OrtAllocator get instance => _instance;

  ffi.Pointer<bindings.OrtAllocator> get ptr => _ptr;

  OrtAllocator._() {
    final pp = calloc<ffi.Pointer<bindings.OrtAllocator>>();
    final statusPtr = OrtEnv.instance.ortApiPtr.ref.GetAllocatorWithDefaultOptions.asFunction<
        bindings.OrtStatusPtr Function(
            ffi.Pointer<ffi.Pointer<bindings.OrtAllocator>>)>()(pp);
    OrtStatus.checkOrtStatus(statusPtr);
    _ptr = pp.value;
    calloc.free(pp);
  }
}
