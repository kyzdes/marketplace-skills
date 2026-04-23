#!/usr/bin/env bats

@test "marketplace.json is valid JSON" {
  run jq empty .claude-plugin/marketplace.json
  [ "$status" -eq 0 ]
}

@test "marketplace.json has required top-level fields" {
  run jq -e '.name and .owner and .plugins' .claude-plugin/marketplace.json
  [ "$status" -eq 0 ]
}

@test "marketplace.json validates with claude plugin validate" {
  run claude plugin validate "$BATS_TEST_DIRNAME/.."
  [ "$status" -eq 0 ]
}

@test "owner has name field" {
  run jq -e '.owner.name' .claude-plugin/marketplace.json
  [ "$status" -eq 0 ]
}

@test "every plugin entry has name and source.repo" {
  run jq -e 'all(.plugins[]; .name and .source.repo)' .claude-plugin/marketplace.json
  [ "$status" -eq 0 ]
}

@test "vps-ninja entry points to github kyzdes/vps-ninja" {
  run jq -e '.plugins[] | select(.name == "vps-ninja") | select(.source.source == "github" and .source.repo == "kyzdes/vps-ninja")' .claude-plugin/marketplace.json
  [ "$status" -eq 0 ]
}
