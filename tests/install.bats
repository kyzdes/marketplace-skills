#!/usr/bin/env bats

SCRIPT="$BATS_TEST_DIRNAME/../install.sh"

@test "install.sh with no args prints usage and exits non-zero" {
  run bash "$SCRIPT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"usage"* ]]
}

@test "install.sh list prints vps-ninja and creds-app-skill" {
  run bash "$SCRIPT" list
  [ "$status" -eq 0 ]
  [[ "$output" == *"vps-ninja"* ]]
  [[ "$output" == *"creds-app-skill"* ]]
}

@test "install.sh claude prints Claude marketplace instruction" {
  run bash "$SCRIPT" claude
  [ "$status" -eq 0 ]
  [[ "$output" == *"/plugin marketplace add kyzdes/marketplace-skills"* ]]
}

@test "install.sh unknown-agent exits non-zero" {
  run bash "$SCRIPT" floob vps-ninja
  [ "$status" -ne 0 ]
}

@test "install.sh codex requires at least one skill" {
  run bash "$SCRIPT" codex
  [ "$status" -ne 0 ]
}

@test "install.sh codex with unknown skill exits non-zero" {
  run bash "$SCRIPT" codex not-a-real-skill
  [ "$status" -ne 0 ]
}

@test "install.sh codex vps-ninja in dry-run prints clone command" {
  INSTALL_DIR="$BATS_TMPDIR/codex" DRY_RUN=1 run bash "$SCRIPT" codex vps-ninja
  [ "$status" -eq 0 ]
  [[ "$output" == *"git clone"* ]]
  [[ "$output" == *"kyzdes/vps-ninja"* ]]
  [[ "$output" == *"$BATS_TMPDIR/codex"* ]]
}

@test "install.sh gemini creds-app-skill in dry-run prints clone command" {
  INSTALL_DIR="$BATS_TMPDIR/gemini" DRY_RUN=1 run bash "$SCRIPT" gemini creds-app-skill
  [ "$status" -eq 0 ]
  [[ "$output" == *"git clone"* ]]
  [[ "$output" == *"kyzdes/creds-app-skill"* ]]
}

@test "install.sh codex without INSTALL_DIR and no default path exits with clear error" {
  INSTALL_DIR="" run bash "$SCRIPT" codex vps-ninja
  [ "$status" -ne 0 ]
  [[ "$output" == *"INSTALL_DIR"* ]]
}

@test "install.sh update without agent exits non-zero" {
  run bash "$SCRIPT" update
  [ "$status" -ne 0 ]
}

@test "install.sh update codex in dry-run runs git pull for each installed skill" {
  tmp="$BATS_TMPDIR/upd"
  rm -rf "$tmp"
  mkdir -p "$tmp/vps-ninja/.git"
  INSTALL_DIR="$tmp" DRY_RUN=1 run bash "$SCRIPT" update codex
  [ "$status" -eq 0 ]
  [[ "$output" == *"git -C $tmp/vps-ninja pull"* ]]
}

@test "install.sh update codex with specific skill only pulls that one" {
  tmp="$BATS_TMPDIR/upd-single"
  rm -rf "$tmp"
  mkdir -p "$tmp/vps-ninja/.git" "$tmp/creds-app-skill/.git"
  INSTALL_DIR="$tmp" DRY_RUN=1 run bash "$SCRIPT" update codex creds-app-skill
  [ "$status" -eq 0 ]
  [[ "$output" == *"creds-app-skill pull"* ]]
  [[ "$output" != *"vps-ninja pull"* ]]
}

@test "install.sh update without INSTALL_DIR fails" {
  INSTALL_DIR="" run bash "$SCRIPT" update codex
  [ "$status" -ne 0 ]
}
