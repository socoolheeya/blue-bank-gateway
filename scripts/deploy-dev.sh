#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${ENV_FILE:-${PROJECT_DIR}/.env.dev}"
DOCKER_BIN="${DOCKER_BIN:-docker}"
BASE_COMPOSE_FILE="${PROJECT_DIR}/docker-compose.yml"
DEV_COMPOSE_FILE="${PROJECT_DIR}/docker-compose.dev.yml"

if ! command -v "${DOCKER_BIN}" >/dev/null 2>&1; then
  echo "Error: Docker command was not found: ${DOCKER_BIN}" >&2
  exit 1
fi

for required_file in "${ENV_FILE}" "${BASE_COMPOSE_FILE}" "${DEV_COMPOSE_FILE}"; do
  if [[ ! -f "${required_file}" ]]; then
    echo "Error: required file not found: ${required_file}" >&2
    exit 1
  fi
done

cd "${PROJECT_DIR}"

exec "${DOCKER_BIN}" compose \
  --env-file "${ENV_FILE}" \
  -f "${BASE_COMPOSE_FILE}" \
  -f "${DEV_COMPOSE_FILE}" \
  up --build -d
