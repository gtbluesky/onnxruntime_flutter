#!/bin/bash

./prepare-extensions.sh

./tools/android/build_aar.py --output_dir build --config Release --mode build_aar --api_level 21 --sdk_path="$ANDROID_HOME/Sdk" --ndk_path="$ANDROID_HOME/Sdk/ndk/22.1.7171670"
# Output is ./build/aar_out/Release/com/microsoft/onnxruntime/onnxruntime-extensions-android/0.13.0/onnxruntime-extensions-android-0.13.0.aar