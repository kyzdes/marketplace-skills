#!/usr/bin/env bash
set -euo pipefail

SKILLS=(vps-ninja creds-app-skill)
OWNER="kyzdes"
MARKETPLACE="kyzdes-skills"
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

is_known_skill() {
  local s=$1
  for k in "${SKILLS[@]}"; do [ "$k" = "$s" ] && return 0; done
  return 1
}

default_install_dir() {
  case "$1" in
    codex)  [ -n "${CODEX_DEFAULT_DIR:-}" ] && printf '%s' "$CODEX_DEFAULT_DIR" ;;
    gemini) [ -n "${GEMINI_DEFAULT_DIR:-}" ] && printf '%s' "$GEMINI_DEFAULT_DIR" ;;
  esac
}

install_for_agent() {
  local agent=$1; shift
  [ "$#" -eq 0 ] && { echo "error: no skills specified" >&2; exit 2; }

  local target=${INSTALL_DIR:-$(default_install_dir "$agent")}
  if [ -z "$target" ]; then
    cat >&2 <<EOF
error: INSTALL_DIR not set and no default path known for $agent.

Set INSTALL_DIR to the path where $agent looks for plugins/extensions, e.g.:
  INSTALL_DIR=/path/to/${agent}/plugins install.sh $agent <skill>...
EOF
    exit 2
  fi

  local skill dest cmd
  for skill in "$@"; do
    is_known_skill "$skill" || { echo "unknown skill: $skill" >&2; exit 2; }
    dest="$target/$skill"
    cmd="git clone --depth=1 $GIT_HOST/$OWNER/$skill.git $dest"
    if [ "${DRY_RUN:-0}" = "1" ]; then
      echo "$cmd"
    else
      mkdir -p "$target"
      eval "$cmd"
    fi
  done
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
    codex)   install_for_agent codex  "$@" ;;
    gemini)  install_for_agent gemini "$@" ;;
    update)  echo "update: not implemented yet" >&2; exit 3 ;;
    *)       echo "unknown command: $cmd" >&2; usage; exit 2 ;;
  esac
}

main "$@"
