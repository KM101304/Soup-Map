#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SWIFT_IMAGE="${SWIFT_IMAGE:-swift:6.2.3-noble}"
XCODEGEN_VERSION="${XCODEGEN_VERSION:-2.45.3}"

docker pull "${SWIFT_IMAGE}"

docker run --rm \
  -e USER="${USER:-codespace}" \
  -v "${REPO_ROOT}:/workspace" \
  -w /tmp \
  "${SWIFT_IMAGE}" \
  bash -lc "git clone --depth 1 --branch ${XCODEGEN_VERSION} https://github.com/yonaskolb/XcodeGen.git XcodeGen && cd XcodeGen && swift run xcodegen --spec /workspace/project.yml"
