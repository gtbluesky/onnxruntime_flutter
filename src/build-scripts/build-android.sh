#!/bin/bash

./prepare.sh

python3 tools/android_custom_build/build_custom_android_package.py --onnxruntime_branch_or_tag v1.20.1 --build_settings tools/ci_build/github/android/default_full_aar_build_settings.json build
# Output is ./build/output/aar_out/Release/com/microsoft/onnxruntime/onnxruntime-android/1.20.1/onnxruntime-android-1.20.1.aar