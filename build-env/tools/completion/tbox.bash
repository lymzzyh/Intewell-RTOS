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

_tbox_complete_board_names() {
    local idx_dir
    idx_dir="boards-prj/index"
    if [[ -d "$idx_dir" ]]; then
        local f
        for f in "$idx_dir"/*.yaml; do
            [[ -f "$f" ]] || continue
            basename "$f" .yaml
        done
    fi
}

_tbox_complete_yaml_files() {
    local f
    for f in boards-iprj/yaml/*.yaml boards-prj/*/yaml/*.yaml; do
        [[ -f "$f" ]] || continue
        printf '%s\n' "$(basename "$f")"
        printf '%s\n' "$f"
    done
}

_tbox_complete_toolchains() {
    local cfg
    cfg="ci_boards.json"
    if [[ -f "$cfg" ]]; then
        python3 - "$cfg" 2>/dev/null <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    data = json.load(f)
for k in sorted((data.get("toolchains") or {}).keys()):
    print(k)
PY
    fi
}

_tbox() {
    local cur prev first
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    first="${COMP_WORDS[1]}"

    # 一级命令补全
    if [[ ${COMP_CWORD} -eq 1 ]]; then
        COMPREPLY=( $(compgen -W "vscode --ext completion toolchain -h --help ?" -- "$cur") )
        return 0
    fi

    # 二级命令：completion
    if [[ "$first" == "completion" ]]; then
        if [[ ${COMP_CWORD} -eq 2 ]]; then
            COMPREPLY=( $(compgen -W "bash" -- "$cur") )
            return 0
        fi
        return 0
    fi

    # 二级命令：toolchain
    if [[ "$first" == "toolchain" ]]; then
        case "$prev" in
            --config)
                COMPREPLY=( $(compgen -f -- "$cur") )
                return 0
                ;;
        esac

        if [[ "$cur" == -* ]]; then
            COMPREPLY=( $(compgen -W "--list --config -h --help ?" -- "$cur") )
            return 0
        fi

        COMPREPLY=( $(compgen -W "$(_tbox_complete_toolchains)" -- "$cur") )
        return 0
    fi

    # 二级命令：--ext
    if [[ "$first" == "--ext" ]]; then
        case "$prev" in
            --board)
                COMPREPLY=( $(compgen -W "$(_tbox_complete_board_names)" -- "$cur") )
                return 0
                ;;
            --index|--offline-export|--offline-import)
                COMPREPLY=( $(compgen -f -- "$cur") )
                return 0
                ;;
        esac

        COMPREPLY=( $(compgen -W "--list --board --index --force-board --offline-export --offline-import --force-import -h --help" -- "$cur") )
        return 0
    fi

    # normal 模式参数透传给 gen_presets，给常用参数补全
    case "$prev" in
        -f|--file)
            COMPREPLY=( $(compgen -W "$(_tbox_complete_yaml_files)" -- "$cur") )
            return 0
            ;;
    esac
    COMPREPLY=( $(compgen -W "-f --file -h --help" -- "$cur") )
}

complete -F _tbox tbox ./tbox
