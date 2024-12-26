#!/bin/bash

./prepare-extensions.sh

# Tests fail with xcode build system
rm cmake/ext_tests.cmake
touch cmake/ext_tests.cmake

python3 tools/ios/build_xcframework.py --output_dir build --mode build_xcframework --config Release --ios_deployment_target 13.3 --macos_deployment_target 16 -- --skip_tests --parallel