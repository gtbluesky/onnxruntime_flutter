#!/bin/bash

dir_name="onnxruntime"
onnx_version=v1.20.1

if [ ! -d "$dir_name" ]; then
    echo "Cloning onnxruntime..."
    git clone https://github.com/microsoft/onnxruntime -b "$onnx_version" "$dir_name"

    if [ ! $? -eq 0 ]; then
        echo "Failed to clone the onnxruntime repository."
        exit 1
    fi
fi
