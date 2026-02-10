/// An enumerated value of ort provider.
/// 
/// Execution providers enable hardware-accelerated inference across different platforms:
/// - **CPU**: Standard CPU inference (all platforms)
/// - **CUDA**: NVIDIA GPU acceleration (Windows/Linux, requires CUDA runtime)
/// - **TensorRT**: NVIDIA GPU with optimizations (Windows/Linux, requires TensorRT)
/// - **DirectML**: DirectX 12 GPU acceleration (Windows, AMD/Intel/NVIDIA)
/// - **ROCm**: AMD GPU acceleration (Linux, requires ROCm runtime)
/// - **CoreML**: Apple Neural Engine/GPU (iOS/macOS)
/// - **NNAPI**: Android Neural Networks API (Android, Google's mobile acceleration)
/// - **OpenVINO**: Intel optimization toolkit (Windows/Linux, Intel hardware)
/// - **DNNL**: Intel Deep Neural Network Library (all platforms with Intel CPUs)
/// - **MIGraphX**: AMD graph optimization (Linux, AMD GPUs)
/// - **CANN**: Huawei Ascend AI processor (Linux, Huawei NPUs)
/// - **QNN**: Qualcomm Neural Network (Android/Windows, Qualcomm chips)
/// - **XNNPACK**: Optimized CPU operations (all platforms)
enum OrtProvider {
  cpu('CPUExecutionProvider'),
  cuda('CUDAExecutionProvider'),
  tensorrt('TensorrtExecutionProvider'),
  directml('DmlExecutionProvider'),
  rocm('ROCMExecutionProvider'),
  coreml('CoreMLExecutionProvider'),
  nnapi('NnapiExecutionProvider'),
  openvino('OpenVINOExecutionProvider'),
  dnnl('DnnlExecutionProvider'),
  migraphx('MIGraphXExecutionProvider'),
  cann('CANNExecutionProvider'),
  qnn('QNNExecutionProvider'),
  xnnpack('XnnpackExecutionProvider');

  final String value;

  const OrtProvider(this.value);

  static OrtProvider valueOf(String value) {
    if (value == cpu.value) {
      return cpu;
    }
    if (value == cuda.value) {
      return cuda;
    }
    if (value == tensorrt.value) {
      return tensorrt;
    }
    if (value == directml.value) {
      return directml;
    }
    if (value == rocm.value) {
      return rocm;
    }
    if (value == coreml.value) {
      return coreml;
    }
    if (value == nnapi.value) {
      return nnapi;
    }
    if (value == openvino.value) {
      return openvino;
    }
    if (value == dnnl.value) {
      return dnnl;
    }
    if (value == migraphx.value) {
      return migraphx;
    }
    if (value == cann.value) {
      return cann;
    }
    if (value == qnn.value) {
      return qnn;
    }
    if (value == xnnpack.value) {
      return xnnpack;
    }
    return OrtProvider.cpu;
  }
}
