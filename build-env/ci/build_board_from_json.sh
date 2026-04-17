#!/usr/bin/env bash
# Copyright (c) 2026 Kyland Inc.
# Intewell-RTOS is licensed under Mulan PSL v2.
# You can use this software according to the terms and conditions of the Mulan PSL v2.
# You may obtain a copy of Mulan PSL v2 at:
#          http://license.coscl.org.cn/MulanPSL2
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
# EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
# MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
# See the Mulan PSL v2 for more details.

set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <boards.json> <board-index>" >&2
  exit 1
fi

CONFIG_PATH="$1"
BOARD_INDEX="$2"

if ! [[ "$BOARD_INDEX" =~ ^[0-9]+$ ]]; then
  echo "board-index must be a non-negative integer, got: $BOARD_INDEX" >&2
  exit 1
fi

if [ ! -f "$CONFIG_PATH" ]; then
  echo "boards config file not found: $CONFIG_PATH" >&2
  exit 1
fi

mkdir -p build/artifacts

TMP_ENV="$(mktemp)"
TMP_PRE_CMDS="$(mktemp)"
TMP_POST_CMDS="$(mktemp)"
cleanup() {
  rm -f "$TMP_ENV" "$TMP_PRE_CMDS" "$TMP_POST_CMDS"
}
trap cleanup EXIT

is_writable_or_creatable_dir() {
  local dir="$1"
  if [ -d "$dir" ]; then
    [ -w "$dir" ]
    return
  fi

  local parent
  parent="$(dirname "$dir")"
  [ -d "$parent" ] && [ -w "$parent" ]
}

download_and_extract_toolchain() {
  local url="$1"
  local extract_to="$2"

  echo "[toolchain] download: $url"

  if is_writable_or_creatable_dir "$extract_to"; then
    mkdir -p "$extract_to"
    curl -fsSL "$url" | tar xzf - -C "$extract_to"
    return
  fi

  if [ "$(id -u)" -eq 0 ]; then
    mkdir -p "$extract_to"
    curl -fsSL "$url" | tar xzf - -C "$extract_to"
    return
  fi

  if ! command -v sudo >/dev/null 2>&1; then
    echo "[toolchain] no write permission to '$extract_to' and sudo is unavailable." >&2
    echo "[toolchain] either grant write permission, run as root, or change extract_to to a user-writable path." >&2
    exit 1
  fi

  echo "[toolchain] '$extract_to' requires elevated permission, retrying extract with sudo"
  sudo mkdir -p "$extract_to"
  curl -fsSL "$url" | sudo tar xzf - -C "$extract_to"
}

python3 - "$CONFIG_PATH" "$BOARD_INDEX" "$TMP_ENV" "$TMP_PRE_CMDS" "$TMP_POST_CMDS" <<'PY'
import json
import shlex
import sys

config_path, board_index_raw, env_path, pre_path, post_path = sys.argv[1:6]
board_index = int(board_index_raw)

with open(config_path, encoding="utf-8") as f:
    config = json.load(f)

boards = config.get("boards")
if not isinstance(boards, list):
    raise SystemExit("Invalid config: 'boards' must be a list.")
if board_index < 0 or board_index >= len(boards):
    raise SystemExit(f"board-index out of range: {board_index}, boards={len(boards)}")

board = boards[board_index]
if not isinstance(board, dict):
    raise SystemExit(f"Invalid board at index {board_index}: expected object.")

preset = str(board.get("preset", "")).strip()
if not preset:
    raise SystemExit(f"Invalid board at index {board_index}: missing 'preset'.")

desc = str(board.get("desc", "")).strip() or preset
toolchain_name = str(board.get("toolchain", "")).strip()

toolchain = {}
if toolchain_name:
    toolchains = config.get("toolchains")
    if not isinstance(toolchains, dict):
        raise SystemExit("Invalid config: 'toolchains' must be an object.")
    if toolchain_name not in toolchains:
        raise SystemExit(
            f"Toolchain '{toolchain_name}' referenced by board '{preset}' is not defined."
        )
    toolchain = toolchains[toolchain_name] or {}
    if not isinstance(toolchain, dict):
        raise SystemExit(f"Invalid toolchain '{toolchain_name}': expected object.")

global_pre_raw = config.get("global_pre", [])
if global_pre_raw is None:
    global_pre = []
elif isinstance(global_pre_raw, list):
    global_pre = global_pre_raw
else:
    raise SystemExit("Invalid config: 'global_pre' must be a list or null.")

board_pre_raw = board.get("pre", [])
if board_pre_raw is None:
    board_pre = []
elif isinstance(board_pre_raw, list):
    board_pre = board_pre_raw
else:
    raise SystemExit(f"Invalid board '{preset}': 'pre' must be a list or null.")

global_post_raw = config.get("global_post", [])
if global_post_raw is None:
    global_post = []
elif isinstance(global_post_raw, list):
    global_post = global_post_raw
else:
    raise SystemExit("Invalid config: 'global_post' must be a list or null.")

board_post_raw = board.get("post", [])
if board_post_raw is None:
    board_post = []
elif isinstance(board_post_raw, list):
    board_post = board_post_raw
else:
    raise SystemExit(f"Invalid board '{preset}': 'post' must be a list or null.")

pre_commands = []
for cmd in [*global_pre, *board_pre]:
    if not isinstance(cmd, str):
        raise SystemExit(f"Invalid pre command in board '{preset}': expected string.")
    command = cmd.strip()
    if command:
        pre_commands.append(command)

post_commands = []
for cmd in [*global_post, *board_post]:
    if not isinstance(cmd, str):
        raise SystemExit(f"Invalid post command in board '{preset}': expected string.")
    command = cmd.strip()
    if command:
        post_commands.append(command)

with open(env_path, "w", encoding="utf-8") as envf:
    def put(key: str, value: str) -> None:
        envf.write(f"{key}={shlex.quote(str(value))}\n")

    put("BOARD_PRESET", preset)
    put("BOARD_DESC", desc)
    put("TOOLCHAIN_URL", str(toolchain.get("url", "")).strip())
    put("TOOLCHAIN_EXTRACT_TO", str(toolchain.get("extract_to", "/opt")).strip() or "/opt")
    put("TOOLCHAIN_BIN_PATH", str(toolchain.get("bin_path", "")).strip())

with open(pre_path, "w", encoding="utf-8") as pref:
    for cmd in pre_commands:
        pref.write(cmd + "\n")

with open(post_path, "w", encoding="utf-8") as postf:
    for cmd in post_commands:
        postf.write(cmd + "\n")
PY

# shellcheck disable=SC1090
source "$TMP_ENV"
export BOARD_PRESET BOARD_DESC TOOLCHAIN_URL TOOLCHAIN_EXTRACT_TO TOOLCHAIN_BIN_PATH

LOG_SLUG="$(printf '%s' "$BOARD_PRESET" | tr -cs 'A-Za-z0-9._-' '_')"
LOG_FILE="build/artifacts/${BOARD_INDEX}_${LOG_SLUG}.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== Build board #$BOARD_INDEX: $BOARD_DESC ($BOARD_PRESET) ==="

# GitLab CI may checkout with a narrow refspec; widen it so later git fetch
# (inside pre-steps like upboard kernel switch) can see non-default branches.
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git config --local remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
fi

if [ -s "$TMP_PRE_CMDS" ]; then
  while IFS= read -r cmd || [ -n "$cmd" ]; do
    [ -z "$cmd" ] && continue
    echo "[pre] $cmd"
    bash -lc "$cmd"
  done < "$TMP_PRE_CMDS"
fi

if [ -n "$TOOLCHAIN_URL" ]; then
  download_and_extract_toolchain "$TOOLCHAIN_URL" "$TOOLCHAIN_EXTRACT_TO"
fi

if [ -n "$TOOLCHAIN_BIN_PATH" ]; then
  export PATH="$TOOLCHAIN_BIN_PATH:$PATH"
  echo "[toolchain] PATH += $TOOLCHAIN_BIN_PATH"
fi

cmake --preset "$BOARD_PRESET"
cmake --build --preset "$BOARD_PRESET"

if [ -s "$TMP_POST_CMDS" ]; then
  while IFS= read -r cmd || [ -n "$cmd" ]; do
    [ -z "$cmd" ] && continue
    echo "[post] $cmd"
    bash -lc "$cmd"
  done < "$TMP_POST_CMDS"
fi

if [ "${RUN_QEMU_TEST:-}" = "true" ]; then
  echo "[test] preparing rootfs via CMake target: rootfs"
  cmake --build --preset "$BOARD_PRESET" --target rootfs

  ROOTFS_BIN="$(find build -type f -path "*/${BOARD_PRESET}/rootfs.bin" | head -n 1)"
  if [ -z "${ROOTFS_BIN}" ] || [ ! -f "${ROOTFS_BIN}" ]; then
    echo "[test] rootfs.bin not found for preset: ${BOARD_PRESET}" >&2
    exit 1
  fi

  mkdir -p "out/${BOARD_PRESET}"
  cp -f "${ROOTFS_BIN}" "out/${BOARD_PRESET}/rootfs.bin"
  echo "[test] exported rootfs: out/${BOARD_PRESET}/rootfs.bin"
fi

echo "=== Board build finished: $BOARD_PRESET ==="
