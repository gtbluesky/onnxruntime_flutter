<p align="center"><img width="50%" src="https://github.com/microsoft/onnxruntime/raw/main/docs/images/ONNX_Runtime_logo_dark.png" /></p>

# OnnxRuntime Plugin
[![pub package](https://img.shields.io/pub/v/onnxruntime.svg)](https://pub.dev/packages/onnxruntime)

## Overview

Flutter plugin for OnnxRuntime via `dart:ffi` provides an easy, flexible, and fast Dart API to integrate Onnx models in flutter apps across mobile and desktop platforms.

| **Platform**      | Android       | iOS | Linux | macOS | Windows |
|-------------------|---------------|-----|-------|-------|---------|
| **Compatibility** | API level 21+ | *   | *     | *     | *       |
| **Architecture**  | arm32/arm64   | *   | *     | *     | *       |

*: [Consistent with Flutter](https://docs.flutter.dev/reference/supported-platforms)

## Key Features

* Multi-platform Support for Android, iOS, Linux, macOS, Windows, and Web(Coming soon).
* Flexibility to use any Onnx Model.
* Acceleration using multi-threading.
* Similar structure as OnnxRuntime Java and C# API.
* Inference speed is not slower than native Android/iOS Apps built using the Java/Objective-C API.
* Run inference in different isolates to prevent jank in UI thread.

## Getting Started

In your flutter project add the dependency:

```yml
dependencies:
  ...
  onnxruntime: x.y.z
```

## Usage example

### Import

```dart
import 'package:onnxruntime/onnxruntime.dart';
```

### Initializing environment

```dart
OrtEnv.instance.init();
```

### Creating the Session

```dart
final sessionOptions = OrtSessionOptions();

// 🚀 NEW: Automatically use GPU acceleration if available!
// This will try GPU providers first, then fall back to CPU
sessionOptions.appendDefaultProviders();

const assetFileName = 'assets/models/test.onnx';
final rawAssetFile = await rootBundle.load(assetFileName);
final bytes = rawAssetFile.buffer.asUint8List();
final session = OrtSession.fromBuffer(bytes, sessionOptions);
```

### Performing inference

```dart
final shape = [1, 2, 3];
final inputOrt = OrtValueTensor.createTensorWithDataList(data, shape);
final inputs = {'input': inputOrt};
final runOptions = OrtRunOptions();
final outputs = await _session?.runAsync(runOptions, inputs);
inputOrt.release();
runOptions.release();
outputs?.forEach((element) {
  element?.release();
});
```

### Releasing environment

```dart
OrtEnv.instance.release();
```

## 🚀 GPU Acceleration

This fork includes full support for GPU and hardware acceleration across multiple platforms!

### Supported Execution Providers

| Provider | Platform | Hardware | Speedup |
|----------|----------|----------|---------|
| **CUDA** | Windows/Linux | NVIDIA GPU | 5-10x |
| **TensorRT** | Windows/Linux | NVIDIA GPU | 10-20x |
| **DirectML** | Windows | AMD/Intel/NVIDIA GPU | 3-8x |
| **ROCm** | Linux | AMD GPU | 5-10x |
| **CoreML** | iOS/macOS | Apple Neural Engine | 5-15x |
| **NNAPI** | Android | Google NPU/GPU | 3-7x |
| **OpenVINO** | Windows/Linux | Intel GPU/VPU | 3-6x |
| **DNNL** | All | Intel CPU | 2-4x |
| **XNNPACK** | All | CPU optimizations | 1.5-3x |

### Quick Start: Automatic GPU Selection

The easiest way to enable GPU acceleration:

```dart
final sessionOptions = OrtSessionOptions();
sessionOptions.appendDefaultProviders(); // 🎯 That's it!
```

This automatically selects the best available provider in this order:
1. **GPU**: CUDA → DirectML → ROCm
2. **NPU**: CoreML → NNAPI → QNN
3. **Optimized CPU**: DNNL → XNNPACK
4. **Fallback**: Standard CPU

### Manual Provider Selection

For fine-grained control:

```dart
// NVIDIA GPU (Windows/Linux)
sessionOptions.appendCudaProvider(CUDAFlags.useArena);

// NVIDIA with TensorRT optimizations + FP16
sessionOptions.appendTensorRTProvider({'trt_fp16_enable': '1'});

// DirectML for Windows (any GPU)
sessionOptions.appendDirectMLProvider();

// Apple Neural Engine (iOS/macOS)
sessionOptions.appendCoreMLProvider(CoreMLFlags.useNone);

// Android acceleration
sessionOptions.appendNnapiProvider(NnapiFlags.useNone);

// AMD GPU on Linux
sessionOptions.appendRocmProvider(ROCmFlags.useArena);

// Intel optimization
sessionOptions.appendDNNLProvider(DNNLFlags.useArena);

// Always add CPU as fallback
sessionOptions.appendCPUProvider(CPUFlags.useArena);
```

### Performance Tips

1. **Use `appendDefaultProviders()` first** - it handles everything automatically
2. **CUDA vs TensorRT**: TensorRT is faster but takes longer to initialize
3. **DirectML**: Great for cross-vendor support on Windows
4. **Mobile**: CoreML (iOS) and NNAPI (Android) provide massive speedups
5. **Thread count**: Set `setIntraOpNumThreads()` to your CPU core count for CPU inference

### GPU Setup Requirements

**Windows (NVIDIA)**:
- Install [CUDA Toolkit](https://developer.nvidia.com/cuda-downloads)
- Optional: [TensorRT](https://developer.nvidia.com/tensorrt) for extra speed

**Linux (NVIDIA)**:
- Install CUDA runtime: `apt install nvidia-cuda-toolkit`
- Optional: TensorRT

**Linux (AMD)**:
- Install [ROCm](https://www.amd.com/en/graphics/servers-solutions-rocm)

**Windows (Any GPU)**:
- DirectML works out-of-the-box on Windows 10+

**iOS/macOS**:
- CoreML works automatically (no setup needed)

**Android**:
- NNAPI works automatically on Android 8.1+ (no setup needed)

### Troubleshooting

If GPU acceleration isn't working:

1. Check available providers:
```dart
OrtEnv.instance.availableProviders().forEach((provider) {
  print('Available: $provider');
});
```

2. Catch provider errors gracefully:
```dart
try {
  sessionOptions.appendCudaProvider(CUDAFlags.useArena);
} catch (e) {
  print('CUDA not available, falling back to CPU');
  sessionOptions.appendCPUProvider(CPUFlags.useArena);
}
```

3. Verify GPU runtime is installed (CUDA, DirectML, etc.)

4. Check that you're using the GPU-enabled ONNX Runtime library

