#!/bin/bash
# Job 2 - TEST
# Runs the built image on the test agent, verifies it responds, then cleans up.

set -e

echo "Removing any existing abode-test container..."
docker rm -f abode-test || true

echo "Starting abode-web:${BUILD_NUMBER} as abode-test..."
docker run -d \
  --name abode-test \
  -p 8080:80 \
  abode-web:${BUILD_NUMBER}

echo "Waiting for the application to start..."
sleep 5

echo "Testing application response..."
curl -f http://localhost:8080

echo "Test passed. Cleaning up..."
docker rm -f abode-test

echo "Job 2 complete."
