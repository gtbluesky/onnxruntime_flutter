#!/bin/bash

dir_name="onnxruntime-extensions"
onnx_version=v0.13.0

if [ ! -d "$dir_name" ]; then
    echo "Cloning onnxruntime-extensions..."
    git clone https://github.com/microsoft/onnxruntime-extensions -b "$onnx_version" "$dir_name"

    if [ ! $? -eq 0 ]; then
        echo "Failed to clone the onnxruntime-extensions repository."
        exit 1
    fi
fi
