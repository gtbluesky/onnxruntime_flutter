## 1.22.0

* Updated to ONNX Runtime 1.22.0
* Added support for `setSessionExecutionMode` to control sequential/parallel execution
* Added `OrtSessionExecutionMode` enum with `ortSequential` and `ortParallel` options
* Added `OrtSessionGraphOptimizationLevel` type alias for compatibility
* Enhanced session configuration options for better performance control

## 1.4.1

* Fixes a memory leak when creating tensor.

## 1.4.0

* Fixes a memory leak when creating tensor.

## 1.3.0

* Attempts to support macOS, Windows and Linux.

## 1.2.0

* Compatible with Gradle8.

## 1.1.0

* Exposes some methods of input and output name.
* Adds some documentation comments.

## 1.0.0

* Initial release.
