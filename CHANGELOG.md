## Unreleased

* Adds `OrtSessionOptions.disableCpuMemArena()` and `OrtSessionOptions.disableMemPattern()`, wrapping the existing native `DisableCpuMemArena`/`DisableMemPattern` ORT C API calls. Useful for sessions that run infrequently and variable-shaped inputs, where the default arena/mem-pattern behavior retains memory without a matching reuse benefit.

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
