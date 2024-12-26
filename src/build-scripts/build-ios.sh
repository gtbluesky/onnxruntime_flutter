#!/bin/bash

./prepare.sh

# We need to make minor tweaks in order to make this buildable
sed -i 's/"--apple_deploy_target=14.0"/"--apple_deploy_target=16.0"/' tools/ci_build/github/apple/default_full_ios_framework_build_settings.json
sed -i 's/"--apple_deploy_target=13.0"/"--apple_deploy_target=13.3"/' tools/ci_build/github/apple/default_full_ios_framework_build_settings.json

python3 tools/ci_build/github/apple/build_and_assemble_apple_pods.py --staging-dir build --build-settings-file tools/ci_build/github/apple/default_full_ios_framework_build_settings.json