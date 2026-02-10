# The Flutter tooling requires that developers have a version of Visual Studio
# installed that includes CMake 3.14 or later. You should not increase this
# version, as doing so will cause the plugin to fail to compile for some
# customers of the plugin.
cmake_minimum_required(VERSION 3.14)

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
# Includes GPU provider DLLs for CUDA, TensorRT, and DirectML acceleration.
# These DLLs are optional - if the GPU runtime is not available on the target
# system, ONNX Runtime will gracefully fall back to CPU execution.
set(onnxruntime_bundled_libraries
  "${CMAKE_CURRENT_SOURCE_DIR}/onnxruntime.dll"
  PARENT_SCOPE
)

# Optional: Uncomment to bundle GPU provider DLLs
# Note: These files are located in thirdparty/onnxruntime-win-x64-gpu-1.22.0/lib/
# Copy them to the windows/ directory if you want to enable GPU support by default
#
# "${CMAKE_CURRENT_SOURCE_DIR}/onnxruntime_providers_cuda.dll"
# "${CMAKE_CURRENT_SOURCE_DIR}/onnxruntime_providers_shared.dll"
# "${CMAKE_CURRENT_SOURCE_DIR}/onnxruntime_providers_tensorrt.dll"
