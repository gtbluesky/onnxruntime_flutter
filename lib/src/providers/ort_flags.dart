abstract class OrtFlags {
  int get value;
}

/// A flag for [OrtProvider.cpu].
enum CPUFlags implements OrtFlags {
  useNone(0x000),
  useArena(0x001);

  final int _value;

  const CPUFlags(this._value);

  @override
  int get value => _value;
}

/// A flag for [OrtProvider.nnapi].
enum NnapiFlags implements OrtFlags {
  useNone(0x000),
  useFp16(0x001),
  useNCHW(0x002),
  cpuDisabled(0x004),
  cpuOnly(0x008);

  final int _value;

  const NnapiFlags(this._value);

  @override
  int get value => _value;
}

/// A flag for [OrtProvider.coreml].
enum CoreMLFlags implements OrtFlags {
  useNone(0x000),
  useCpuOnly(0x001),
  enableOnSubgraph(0x002),
  onlyEnableDeviceWithANE(0x004);

  final int _value;

  const CoreMLFlags(this._value);

  @override
  int get value => _value;
}

/// A flag for [OrtProvider.cuda].
/// CUDA provides GPU acceleration using NVIDIA GPUs.
enum CUDAFlags implements OrtFlags {
  /// Use default CUDA provider options
  useNone(0x000),
  
  /// Use CUDA memory arena for allocations
  /// Can improve performance by reducing allocation overhead
  useArena(0x001),
  
  /// Enable CUDNN convolution algorithm search
  /// Finds the fastest convolution algorithm for your model
  useCudnnConvAlgoSearch(0x002),
  
  /// Copy inputs/outputs on the same stream as compute
  /// Can improve performance in some cases
  doCopyInDefaultStream(0x004),
  
  /// Enable CUDA graph capture for better performance
  /// Reduces kernel launch overhead
  enableCudaGraph(0x008);

  final int _value;

  const CUDAFlags(this._value);

  @override
  int get value => _value;
}

/// A flag for [OrtProvider.tensorrt].
/// TensorRT provides optimized inference on NVIDIA GPUs with additional optimizations.
enum TensorRTFlags implements OrtFlags {
  /// Use default TensorRT provider options
  useNone(0x000),
  
  /// Enable TensorRT FP16 (half precision) mode
  /// Faster inference with minimal accuracy loss
  useFp16(0x001),
  
  /// Enable TensorRT INT8 quantization
  /// Even faster with calibration, more accuracy loss
  useInt8(0x002),
  
  /// Force sequential engine building
  /// More stable but slower model initialization
  forceSequentialEngineBuild(0x004);

  final int _value;

  const TensorRTFlags(this._value);

  @override
  int get value => _value;
}

/// A flag for [OrtProvider.directml].
/// DirectML provides GPU acceleration on Windows using DirectX 12.
/// Works with AMD, Intel, and NVIDIA GPUs.
enum DirectMLFlags implements OrtFlags {
  /// Use default DirectML provider options
  useNone(0x000),
  
  /// Disable metacommands (may improve compatibility)
  disableMetacommands(0x001);

  final int _value;

  const DirectMLFlags(this._value);

  @override
  int get value => _value;
}

/// A flag for [OrtProvider.rocm].
/// ROCm provides GPU acceleration for AMD GPUs on Linux.
enum ROCmFlags implements OrtFlags {
  /// Use default ROCm provider options
  useNone(0x000),
  
  /// Use ROCm memory arena for allocations
  useArena(0x001),
  
  /// Enable MIOpen convolution algorithm search
  useMiopenConvAlgoSearch(0x002);

  final int _value;

  const ROCmFlags(this._value);

  @override
  int get value => _value;
}

/// A flag for [OrtProvider.openvino].
/// OpenVINO provides optimized inference on Intel hardware.
enum OpenVINOFlags implements OrtFlags {
  /// Use default OpenVINO provider options
  useNone(0x000),
  
  /// Use CPU device
  useCpu(0x001),
  
  /// Use GPU device (Intel integrated graphics)
  useGpu(0x002),
  
  /// Use VPU device (Intel Movidius)
  useVpu(0x004);

  final int _value;

  const OpenVINOFlags(this._value);

  @override
  int get value => _value;
}

/// A flag for [OrtProvider.dnnl].
/// DNNL (Deep Neural Network Library) provides optimized CPU operations for Intel processors.
/// Formerly known as MKL-DNN.
enum DNNLFlags implements OrtFlags {
  /// Use default DNNL provider options
  useNone(0x000),
  
  /// Use DNNL memory arena for allocations
  useArena(0x001);

  final int _value;

  const DNNLFlags(this._value);

  @override
  int get value => _value;
}

/// A flag for [OrtProvider.migraphx].
/// MIGraphX provides AMD GPU acceleration with graph optimizations.
enum MIGraphXFlags implements OrtFlags {
  /// Use default MIGraphX provider options
  useNone(0x000),
  
  /// Enable FP16 mode for faster inference
  useFp16(0x001);

  final int _value;

  const MIGraphXFlags(this._value);

  @override
  int get value => _value;
}

/// A flag for [OrtProvider.cann].
/// CANN provides acceleration on Huawei Ascend AI processors.
enum CANNFlags implements OrtFlags {
  /// Use default CANN provider options
  useNone(0x000),
  
  /// Use CANN memory arena for allocations
  useArena(0x001);

  final int _value;

  const CANNFlags(this._value);

  @override
  int get value => _value;
}