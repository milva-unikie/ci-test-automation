#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2023-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0

set -e

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

run_tool() {
    if command -v "$1" >/dev/null 2>&1; then
        "$1"
    elif command -v nix >/dev/null 2>&1; then
        nix develop -c "$1"
    else
        echo "$1 not found in PATH and nix is unavailable" >&2
        exit 1
    fi
}

run_tool organize-robot-tags
run_tool organize-robot-settings

if ! git diff --quiet -- '*.robot' '*.resource'; then
    echo "Organized Robot tags/settings and restaged updated .robot/.resource files."
    git add -u -- '*.robot' '*.resource'
fi
