#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DISTRO="${DISTRO:-bookworm}"
IMAGE_PREFIX="freediameter-builder"
OUTPUT_DIR="${SCRIPT_DIR}/out"

usage() {
    cat <<EOF
Usage: $(basename "$0") [compile|package|all] [OPTIONS]

Targets:
  compile   Build freeDiameter from source inside Docker.
  package   Build Debian .deb packages inside Docker.
  all       Run both compile and package (default).

Options:
  -d DISTRO   Debian suite to use (default: bookworm).
  -o DIR      Output directory for artifacts (default: ./out).
  -h          Show this help.

Environment:
  DISTRO      Same as -d (overridden by flag).
EOF
    exit 0
}

# ── argument parsing ──────────────────────────────────────────────────
TARGET="all"
if [[ ${1:-} =~ ^(compile|package|all)$ ]]; then
    TARGET="$1"; shift
fi

while getopts "d:o:h" opt; do
    case "$opt" in
        d) DISTRO="$OPTARG" ;;
        o) OUTPUT_DIR="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

mkdir -p "$OUTPUT_DIR"

# ── compile target ────────────────────────────────────────────────────
do_compile() {
    echo "==> Building freeDiameter (compile) for ${DISTRO}…"
    docker build \
        --build-arg "DISTRO=${DISTRO}" \
        --target build \
        -t "${IMAGE_PREFIX}:compile-${DISTRO}" \
        -f "${SCRIPT_DIR}/Dockerfile.build" \
        "${SCRIPT_DIR}"

    echo "==> Extracting compiled binaries to ${OUTPUT_DIR}/compile/"
    local cid
    cid="$(docker create "${IMAGE_PREFIX}:compile-${DISTRO}")"
    mkdir -p "${OUTPUT_DIR}/compile"
    docker cp "${cid}:/build/" "${OUTPUT_DIR}/compile/"
    docker rm "$cid" >/dev/null
    echo "==> Compile artifacts written to ${OUTPUT_DIR}/compile/"
}

# ── package target ────────────────────────────────────────────────────
do_package() {
    echo "==> Building freeDiameter Debian packages for ${DISTRO}…"
    docker build \
        --build-arg "DISTRO=${DISTRO}" \
        --target package \
        -t "${IMAGE_PREFIX}:package-${DISTRO}" \
        -f "${SCRIPT_DIR}/Dockerfile.build" \
        "${SCRIPT_DIR}"

    echo "==> Extracting .deb packages to ${OUTPUT_DIR}/debs/"
    local cid
    cid="$(docker create "${IMAGE_PREFIX}:package-${DISTRO}")"
    mkdir -p "${OUTPUT_DIR}/debs"
    docker cp "${cid}:/debs/" "${OUTPUT_DIR}/debs/"
    docker rm "$cid" >/dev/null
    echo "==> Debian packages written to ${OUTPUT_DIR}/debs/"
    ls -lh "${OUTPUT_DIR}/debs/"*.deb 2>/dev/null || ls -lh "${OUTPUT_DIR}/debs/debs/"*.deb 2>/dev/null || true
}

# ── dispatch ──────────────────────────────────────────────────────────
case "$TARGET" in
    compile) do_compile ;;
    package) do_package ;;
    all)     do_compile; do_package ;;
esac

echo "==> Done."
