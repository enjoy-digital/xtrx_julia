#! /usr/bin/env bash

export SOAPY_SDR_PLUGIN_PATH=$(pwd)/../software/soapysdr/build

echo "Testing CPU DMA"
julia --project=../software/scripts/ ../software/scripts/test_pattern.jl

echo "Testing GPU DMA"
julia --project=../software/scripts/ ../software/scripts/test_pattern.jl gpu
