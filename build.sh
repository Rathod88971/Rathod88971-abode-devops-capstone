#!/bin/bash
# Job 1 - BUILD
# Checks out is handled by Jenkins SCM step; this script builds the Docker image.

set -e

echo "Building Docker image abode-web:${BUILD_NUMBER}..."

docker build -t abode-web:${BUILD_NUMBER} .

echo "Build complete: abode-web:${BUILD_NUMBER}"
