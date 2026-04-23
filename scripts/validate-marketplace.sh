#!/usr/bin/env bash
# Validate the marketplace repo:
#   - marketplace.json structure
#   - every listed plugin repo is reachable on GitHub
#   - install.sh passes shellcheck and bats tests
#   - marketplace.bats tests pass
set -euo pipefail

cd "$(dirname "$0")/.."

echo "== marketplace.json structural check"
jq -e '.name and .owner.name and (.plugins | type == "array")' \
  .claude-plugin/marketplace.json >/dev/null
echo "   ok"

echo "== plugin entries shape + remote reachability"
while read -r name repo; do
  [ -n "$name" ] && [ -n "$repo" ] || {
    echo "   missing name/repo for entry: name='$name' repo='$repo'" >&2
    exit 1
  }
  if ! git ls-remote "https://github.com/$repo" HEAD >/dev/null 2>&1; then
    echo "   unreachable: $repo" >&2
    exit 1
  fi
  echo "   ok: $name -> $repo"
done < <(jq -r '.plugins[] | "\(.name) \(.source.repo)"' .claude-plugin/marketplace.json | tr -d '\r')

echo "== shellcheck install.sh"
shellcheck install.sh
echo "   ok"

echo "== bats install.bats"
bats tests/install.bats
echo "   ok"

echo "== bats marketplace.bats"
bats tests/marketplace.bats
echo "   ok"

echo "OK"
