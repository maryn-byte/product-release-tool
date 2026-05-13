#!/usr/bin/env bash
set -euo pipefail

REPO="626635437662.dkr.ecr.us-east-2.amazonaws.com/project-planner"
REGION="us-east-2"
REGISTRY="${REPO%%/*}"

aws ecr get-login-password --region "$REGION" \
  | docker login --username AWS --password-stdin "$REGISTRY"

docker build -t "${REPO}:latest" .
docker push "${REPO}:latest"
