#!/usr/bin/env bash
set -euo pipefail

SKILLS=(vps-ninja creds-app-skill)
OWNER="kyzdes"
MARKETPLACE="kyzdes-skills"
# shellcheck disable=SC2034
# GIT_HOST is defined for future tasks (codex/gemini git clone install)
GIT_HOST="https://github.com"

usage() {
  cat <<EOF
usage: install.sh <command> [args]

commands:
  claude                       print Claude Code install instructions
  codex <skill>...             install skills into Codex plugins dir
  gemini <skill>...            install skills into Gemini extensions dir
  update <agent> [skill]       git pull installed skills (all if skill omitted)
  list                         list available skills

env vars:
  INSTALL_DIR                  override destination dir for codex/gemini
EOF
}

# shellcheck disable=SC2034
# is_known_skill is defined for future tasks (codex/gemini skill validation)
is_known_skill() {
  local s=$1
  for k in "${SKILLS[@]}"; do [ "$k" = "$s" ] && return 0; done
  return 1
}

cmd_list() {
  printf '%s\n' "${SKILLS[@]}"
}

cmd_claude() {
  cat <<EOF
Claude Code install:

  /plugin marketplace add $OWNER/marketplace-skills
  /plugin install <skill>@$MARKETPLACE

Available skills:
EOF
  cmd_list
}

main() {
  local cmd=${1:-}
  [ -z "$cmd" ] && { usage; exit 2; }
  shift

  case "$cmd" in
    list)    cmd_list ;;
    claude)  cmd_claude ;;
    codex)   echo "codex: not implemented yet" >&2; exit 3 ;;
    gemini)  echo "gemini: not implemented yet" >&2; exit 3 ;;
    update)  echo "update: not implemented yet" >&2; exit 3 ;;
    *)       echo "unknown command: $cmd" >&2; usage; exit 2 ;;
  esac
}

main "$@"
