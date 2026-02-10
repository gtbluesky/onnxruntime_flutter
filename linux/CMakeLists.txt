# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

# Project-level configuration.
set(PROJECT_NAME "onnxruntime")
project(${PROJECT_NAME} LANGUAGES CXX)

# Invoke the build for native code shared with the other target platforms.
# This can be changed to accommodate different builds.
# add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/../src" "${CMAKE_CURRENT_BINARY_DIR}/shared")

# List of absolute paths to libraries that should be bundled with the plugin.
# This list could contain prebuilt libraries, or libraries created by an
# external build triggered from this build file.
#
# Includes GPU-enabled library for CUDA, TensorRT, and ROCm acceleration.
# The GPU library is optional - if CUDA/ROCm runtime is not available,
# ONNX Runtime will gracefully fall back to CPU execution.
set(onnxruntime_bundled_libraries
  "${CMAKE_CURRENT_SOURCE_DIR}/libonnxruntime.so.1.22.0"
  PARENT_SCOPE
)

# Optional: Use GPU-enabled library instead
# Note: GPU library is located in thirdparty/onnxruntime-linux-x64-gpu-1.22.0/lib/
# Copy it to the linux/ directory and uncomment below to enable GPU support:
#
# "${CMAKE_CURRENT_SOURCE_DIR}/libonnxruntime.so.1.22.0"  # Replace with GPU version
# "${CMAKE_CURRENT_SOURCE_DIR}/libonnxruntime_providers_cuda.so"
# "${CMAKE_CURRENT_SOURCE_DIR}/libonnxruntime_providers_shared.so"
# "${CMAKE_CURRENT_SOURCE_DIR}/libonnxruntime_providers_tensorrt.so"
