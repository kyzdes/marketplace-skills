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
