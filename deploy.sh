#!/bin/bash
# Job 3 - PRODUCTION
# Deploys the tested image to the production agent.
# Should only be triggered for the master branch (enforced in the Jenkins job's
# branch/when condition, not in this script).

set -e

echo "Removing any existing abode-web production container..."
docker rm -f abode-web || true

echo "Starting abode-web:${BUILD_NUMBER} on port 80..."
docker run -d \
  --name abode-web \
  -p 80:80 \
  abode-web:${BUILD_NUMBER}

echo "Deployment complete. Verifying..."
docker ps
curl -f http://localhost

echo "Job 3 complete."
