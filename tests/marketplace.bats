#!/usr/bin/env bats

@test "marketplace.json is valid JSON" {
  run jq empty .claude-plugin/marketplace.json
  [ "$status" -eq 0 ]
}

@test "marketplace.json has required top-level fields" {
  run jq -e '.name and .description and .owner and .plugins' .claude-plugin/marketplace.json
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
