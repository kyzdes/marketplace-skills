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
