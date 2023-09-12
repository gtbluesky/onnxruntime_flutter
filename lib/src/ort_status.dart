import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart';
import 'package:onnxruntime/src/bindings/onnxruntime_bindings_generated.dart'
    as bindings;
import 'package:onnxruntime/src/ort_env.dart';

class OrtStatus {

  OrtStatus._();

  static void checkOrtStatus(bindings.OrtStatusPtr? ptr) {
    if (ptr == null || ptr == ffi.nullptr) {
      return;
    }
    final errorMessage = OrtEnv.instance.ortApiPtr.ref.GetErrorMessage
        .asFunction<ffi.Pointer<ffi.Char> Function(bindings.OrtStatusPtr)>()
        (ptr)
        .cast<Utf8>()
        .toDartString();
    final errorCode = OrtEnv.instance.ortApiPtr.ref.GetErrorCode
        .asFunction<int Function(bindings.OrtStatusPtr)>()(ptr);
    final ortErrorCode = _OrtErrorCode.valueOf(errorCode);
    OrtEnv.instance.ortApiPtr.ref.ReleaseStatus
        .asFunction<void Function(bindings.OrtStatusPtr)>()(ptr);
    if (ortErrorCode == _OrtErrorCode.ok) {
      return;
    }
    throw _OrtException(ortErrorCode, errorMessage);
  }
}

class _OrtException implements Exception {
  final String? message;
  final _OrtErrorCode code;

  const _OrtException([this.code = _OrtErrorCode.unknown, this.message]);

  @override
  String toString() {
    return 'code=${code.value}, message=$message';
  }
}

enum _OrtErrorCode {
  unknown(-1),
  ok(bindings.OrtErrorCode.ORT_OK),
  fail(bindings.OrtErrorCode.ORT_FAIL),
  invalidArgument(bindings.OrtErrorCode.ORT_INVALID_ARGUMENT),
  noSuchFile(bindings.OrtErrorCode.ORT_NO_SUCHFILE),
  noModel(bindings.OrtErrorCode.ORT_NO_MODEL),
  engineError(bindings.OrtErrorCode.ORT_ENGINE_ERROR),
  runtimeException(bindings.OrtErrorCode.ORT_RUNTIME_EXCEPTION),
  invalidProtobuf(bindings.OrtErrorCode.ORT_INVALID_PROTOBUF),
  modelLoaded(bindings.OrtErrorCode.ORT_MODEL_LOADED),
  notImplemented(bindings.OrtErrorCode.ORT_NOT_IMPLEMENTED),
  invalidGraph(bindings.OrtErrorCode.ORT_INVALID_GRAPH),
  epFail(bindings.OrtErrorCode.ORT_EP_FAIL);

  final int value;

  const _OrtErrorCode(this.value);

  static _OrtErrorCode valueOf(int type) {
    switch (type) {
      case bindings.OrtErrorCode.ORT_OK:
        return ok;
      case bindings.OrtErrorCode.ORT_FAIL:
        return fail;
      case bindings.OrtErrorCode.ORT_INVALID_ARGUMENT:
        return invalidArgument;
      case bindings.OrtErrorCode.ORT_NO_SUCHFILE:
        return noSuchFile;
      case bindings.OrtErrorCode.ORT_NO_MODEL:
        return noModel;
      case bindings.OrtErrorCode.ORT_ENGINE_ERROR:
        return engineError;
      case bindings.OrtErrorCode.ORT_RUNTIME_EXCEPTION:
        return runtimeException;
      case bindings.OrtErrorCode.ORT_INVALID_PROTOBUF:
        return invalidProtobuf;
      case bindings.OrtErrorCode.ORT_MODEL_LOADED:
        return modelLoaded;
      case bindings.OrtErrorCode.ORT_NOT_IMPLEMENTED:
        return notImplemented;
      case bindings.OrtErrorCode.ORT_INVALID_GRAPH:
        return invalidGraph;
      case bindings.OrtErrorCode.ORT_EP_FAIL:
        return epFail;
      default:
        return unknown;
    }
  }
}
