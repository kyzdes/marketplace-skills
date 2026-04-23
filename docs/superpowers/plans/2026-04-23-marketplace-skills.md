# Marketplace for Personal Skills — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a personal skill marketplace where one command gives a friend access to all 5 skills (`vps-ninja`, `3x-ui`, `stitch-skill`, `creds-app-skill`, `context-map-skill`), skills update automatically via `main`, and each skill works on Claude Code, Codex CLI, and Gemini CLI.

**Architecture:** Two-tier: (1) 5 standalone skill-repos, each with `.claude-plugin/plugin.json` + `skills/<name>/SKILL.md` + `AGENTS.md`/`GEMINI.md` mirrors + `gemini-extension.json`; (2) marketplace-repo with `.claude-plugin/marketplace.json` catalog, a single `install.sh` for Codex/Gemini, and CI validation. Rolling `main` for updates.

**Tech Stack:** Bash (install script), PowerShell (Windows mirror), JSON (manifests), GitHub Actions (CI), `bats` + `shellcheck` (tests), `jq` / `ajv` (JSON validation).

**Reference:** `github.com/obra/superpowers` and `github.com/obra/superpowers-marketplace`.

**Spec:** `docs/superpowers/specs/2026-04-23-marketplace-skills-design.md`

---

## Preconditions

Before Task 1, the engineer MUST have:

- Local working copy at `C:\Users\kyzde\Desktop\Projects\marketplase-skills\` (the marketplace-repo root; NOT yet a git repo).
- GitHub account `kyzde` with push access.
- 5 existing skill-repos on GitHub: `kyzde/vps-ninja`, `kyzde/3x-ui`, `kyzde/stitch-skill`, `kyzde/creds-app-skill`, `kyzde/context-map-skill`. They are currently proper Claude skills with `SKILL.md` + frontmatter (possibly at repo root, possibly elsewhere — to be confirmed during Task 4).
- Git, bash (git-bash on Windows is fine), `jq`, `shellcheck`, `bats-core`, `npx`, Claude Code CLI, Codex CLI, Gemini CLI installed and working.
- Working directory for the plan throughout is `C:\Users\kyzde\Desktop\Projects\marketplase-skills\` unless otherwise noted.

---

## File Structure Overview

### Marketplace repo (`marketplase-skills/`)

| File | Purpose |
|---|---|
| `.claude-plugin/marketplace.json` | Catalog for Claude Code `/plugin marketplace add` |
| `install.sh` | Unified installer for Codex/Gemini with subcommands |
| `install.ps1` | Functional mirror of `install.sh` for Windows PowerShell |
| `README.md` | One-page user instructions per agent |
| `.github/workflows/validate.yml` | CI: JSON schema, reachability, shellcheck, bats |
| `tests/install.bats` | Smoke tests for `install.sh` (dry-run mode) |
| `scripts/validate-marketplace.sh` | Invoked by CI; also runnable locally |

### Each skill-repo (example `vps-ninja/`)

| File | Purpose |
|---|---|
| `.claude-plugin/plugin.json` | Claude plugin manifest |
| `skills/vps-ninja/SKILL.md` | Single source of truth (Claude convention) |
| `AGENTS.md` | Symlink → `skills/vps-ninja/SKILL.md` (Codex/Cursor/OpenCode) |
| `GEMINI.md` | Symlink → `skills/vps-ninja/SKILL.md` (Gemini) |
| `gemini-extension.json` | Thin Gemini extension manifest |
| `README.md` | Standalone-install instructions per agent |
| `.github/workflows/validate.yml` | CI: lint + mirror-parity check |
| `scripts/sync-mirrors.sh` | Windows fallback: copies SKILL.md into AGENTS.md/GEMINI.md when symlinks aren't available |

---

## Part A — Marketplace Repo Bootstrap

Work happens in `C:\Users\kyzde\Desktop\Projects\marketplase-skills\`.

### Task 1: Initialize marketplace repo with `.gitignore` and baseline README

**Files:**
- Create: `.gitignore`
- Create: `README.md`
- Init: git repo

- [ ] **Step 1: Verify directory state**

Run: `ls -la`
Expected: spec/plan dirs under `docs/`, nothing else. Working tree is NOT a git repo yet.

- [ ] **Step 2: Initialize git**

```bash
git init
git branch -m main
```

- [ ] **Step 3: Create `.gitignore`**

```
# OS / editor
.DS_Store
Thumbs.db
*.swp
.idea/
.vscode/

# Local install destinations used when testing install.sh
/.test-install-dirs/
```

- [ ] **Step 4: Create `README.md` skeleton**

```markdown
# kyzde-skills — personal skills marketplace

Personal collection of skills shared across Claude Code, Codex CLI, and Gemini CLI.

## Install

### Claude Code

    /plugin marketplace add kyzde/marketplace-skills
    /plugin install vps-ninja@kyzde-skills

### Codex CLI

    curl -sSL https://raw.githubusercontent.com/kyzde/marketplace-skills/main/install.sh | bash -s codex vps-ninja

### Gemini CLI

    curl -sSL https://raw.githubusercontent.com/kyzde/marketplace-skills/main/install.sh | bash -s gemini vps-ninja

## Available skills

| Skill | What it does |
|---|---|
| vps-ninja | (TBD — filled during Task 4 from real skill README) |
| 3x-ui | (TBD) |
| stitch-skill | (TBD) |
| creds-app-skill | (TBD) |
| context-map-skill | (TBD) |

## Updates

Claude: `/plugin update <skill>`
Codex/Gemini: `install.sh update <agent>`

See `docs/superpowers/specs/2026-04-23-marketplace-skills-design.md` for design.
```

- [ ] **Step 5: Commit**

```bash
git add .gitignore README.md docs/
git commit -m "chore: bootstrap marketplace repo"
```

### Task 2: Create `marketplace.json` with empty plugins list

**Files:**
- Create: `.claude-plugin/marketplace.json`
- Create: `tests/marketplace.bats`

- [ ] **Step 1: Write failing test for `marketplace.json` schema**

Create `tests/marketplace.bats`:

```bash
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
```

- [ ] **Step 2: Run test — expect FAIL**

Run: `bats tests/marketplace.bats`
Expected: all tests fail because `.claude-plugin/marketplace.json` does not exist.

- [ ] **Step 3: Create `.claude-plugin/marketplace.json` with empty plugin list**

```json
{
  "name": "kyzde-skills",
  "description": "Personal skills marketplace",
  "owner": {
    "name": "kyzde"
  },
  "plugins": []
}
```

- [ ] **Step 4: Run tests — expect PASS**

Run: `bats tests/marketplace.bats`
Expected: 4/4 pass.

- [ ] **Step 5: Commit**

```bash
git add .claude-plugin/marketplace.json tests/marketplace.bats
git commit -m "feat: add empty marketplace.json + schema tests"
```

---

## Part B — Pilot Skill Repo (`vps-ninja`)

Work happens in a **separate clone** outside the marketplace repo. Pick `C:\Users\kyzde\Desktop\Projects\skills-work\vps-ninja\` as a scratch working directory.

### Task 3: Clone `kyzde/vps-ninja` and inspect current structure

**Files:**
- None yet — reconnaissance only

- [ ] **Step 1: Create scratch dir and clone**

```bash
mkdir -p /c/Users/kyzde/Desktop/Projects/skills-work
cd /c/Users/kyzde/Desktop/Projects/skills-work
git clone https://github.com/kyzde/vps-ninja.git
cd vps-ninja
```

- [ ] **Step 2: Inspect current layout**

Run: `ls -la && find . -name 'SKILL.md' -o -name 'plugin.json' -o -name '*.md' | head -30`
Record: where the current `SKILL.md` lives (root vs `skills/`), whether `.claude-plugin/` already exists, frontmatter content.

- [ ] **Step 3: Create working branch**

```bash
git checkout -b migrate-to-marketplace-layout
```

- [ ] **Step 4: Do NOT commit anything yet**

Proceed to Task 4.

### Task 4: Restructure `vps-ninja` into marketplace-compatible layout

**Files** (all inside the `vps-ninja` clone):
- Create: `.claude-plugin/plugin.json`
- Move: existing `SKILL.md` → `skills/vps-ninja/SKILL.md`
- Create: `AGENTS.md`, `GEMINI.md` (symlinks)
- Create: `gemini-extension.json`
- Create: `scripts/sync-mirrors.sh`
- Create: `.github/workflows/validate.yml`
- Update: `README.md`

- [ ] **Step 1: Create `.claude-plugin/plugin.json`**

Use the existing skill's name/description from current `SKILL.md` frontmatter. Example:

```json
{
  "name": "vps-ninja",
  "version": "0.1.0",
  "description": "<copy first-line description from SKILL.md frontmatter>",
  "author": {
    "name": "kyzde"
  },
  "homepage": "https://github.com/kyzde/vps-ninja",
  "repository": "https://github.com/kyzde/vps-ninja",
  "license": "MIT"
}
```

- [ ] **Step 2: Move `SKILL.md` to new location**

```bash
mkdir -p skills/vps-ninja
git mv SKILL.md skills/vps-ninja/SKILL.md
```

If additional helper files accompany the skill (scripts, templates), move them alongside: `git mv <file> skills/vps-ninja/<file>`.

- [ ] **Step 3: Create symlink mirrors**

```bash
ln -s skills/vps-ninja/SKILL.md AGENTS.md
ln -s skills/vps-ninja/SKILL.md GEMINI.md
```

On Windows without developer mode, `ln -s` falls back to a hardlink or copy — that's fine as long as content stays in sync. Proceed; the sync script in Step 5 protects against drift.

- [ ] **Step 4: Create `gemini-extension.json`**

```json
{
  "name": "vps-ninja",
  "version": "0.1.0",
  "description": "<same description as plugin.json>",
  "contextFileName": "GEMINI.md"
}
```

- [ ] **Step 5: Create `scripts/sync-mirrors.sh`**

```bash
#!/usr/bin/env bash
# Windows fallback: if AGENTS.md / GEMINI.md are not symlinks, overwrite them
# with the current SKILL.md content so CI mirror-parity passes.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/skills/vps-ninja/SKILL.md"

for MIRROR in "$ROOT/AGENTS.md" "$ROOT/GEMINI.md"; do
  if [ -L "$MIRROR" ]; then
    continue  # real symlink, nothing to do
  fi
  cp "$SRC" "$MIRROR"
  echo "Synced $MIRROR from SKILL.md"
done
```

```bash
chmod +x scripts/sync-mirrors.sh
```

- [ ] **Step 6: Create `.github/workflows/validate.yml`**

```yaml
name: validate
on: [push, pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Check SKILL.md exists
        run: test -f skills/vps-ninja/SKILL.md

      - name: Validate plugin.json
        run: |
          jq -e '.name and .version and .description' .claude-plugin/plugin.json

      - name: Validate gemini-extension.json
        run: |
          jq -e '.name and .version and .contextFileName' gemini-extension.json
          test "$(jq -r .contextFileName gemini-extension.json)" = "GEMINI.md"

      - name: Check mirror parity (AGENTS.md, GEMINI.md == SKILL.md)
        run: |
          diff skills/vps-ninja/SKILL.md AGENTS.md
          diff skills/vps-ninja/SKILL.md GEMINI.md

      - name: Check SKILL.md frontmatter parses
        run: |
          head -20 skills/vps-ninja/SKILL.md | grep -q '^---$'
          head -20 skills/vps-ninja/SKILL.md | grep -q '^name:'
          head -20 skills/vps-ninja/SKILL.md | grep -q '^description:'
```

- [ ] **Step 7: Update `README.md` with install instructions for each agent**

```markdown
# vps-ninja

<description from SKILL.md>

## Install

### Claude Code (standalone, without marketplace)

    /plugin install https://github.com/kyzde/vps-ninja

### Claude Code (via kyzde marketplace)

    /plugin marketplace add kyzde/marketplace-skills
    /plugin install vps-ninja@kyzde-skills

### Codex CLI / Gemini CLI

    curl -sSL https://raw.githubusercontent.com/kyzde/marketplace-skills/main/install.sh \
      | bash -s <codex|gemini> vps-ninja

## Updates

Claude: `/plugin update vps-ninja`
Codex/Gemini: `install.sh update <agent>`
```

- [ ] **Step 8: Run local validation**

```bash
jq empty .claude-plugin/plugin.json
jq empty gemini-extension.json
diff skills/vps-ninja/SKILL.md AGENTS.md
diff skills/vps-ninja/SKILL.md GEMINI.md
```

Expected: all commands exit 0.

- [ ] **Step 9: Commit and push**

```bash
git add .
git commit -m "refactor: migrate to marketplace-compatible layout"
git push -u origin migrate-to-marketplace-layout
```

- [ ] **Step 10: Wait for CI to pass, then merge to `main`**

Open PR, wait for `validate` workflow green, merge. After merge:

```bash
git checkout main && git pull
```

### Task 5: Verify pilot installs standalone on all three agents

**Files:** none — verification only.

- [ ] **Step 1: Claude Code — install direct from GitHub**

Run in a Claude Code session:

    /plugin install https://github.com/kyzde/vps-ninja

Expected: plugin installed, `/plugin list` shows `vps-ninja`, the skill is discoverable (triggers on relevant prompts).

- [ ] **Step 2: Codex CLI — clone into plugins dir**

First confirm the current Codex CLI plugins dir from its docs. Then:

```bash
cd <codex plugins dir>
git clone --depth=1 https://github.com/kyzde/vps-ninja
```

Expected: `codex` picks up `vps-ninja` as an installed plugin on next session start. If the exact dir is unclear from docs, record what you find and set `INSTALL_DIR` as a documented override path in the README; do not block this task waiting for perfect confirmation.

- [ ] **Step 3: Gemini CLI — clone into extensions dir**

Same as Step 2 but against Gemini's extensions dir. `gemini-extension.json` tells Gemini to load `GEMINI.md` as context.

- [ ] **Step 4: Record findings**

Append to `docs/superpowers/specs/2026-04-23-marketplace-skills-design.md` under "Риски и открытые вопросы" the concrete install paths you verified. Commit in the marketplace repo:

```bash
git add docs/superpowers/specs/2026-04-23-marketplace-skills-design.md
git commit -m "docs: record verified Codex/Gemini install paths"
```

---

## Part C — Connect Pilot to Marketplace

Back in `C:\Users\kyzde\Desktop\Projects\marketplase-skills\`.

### Task 6: Add pilot to `marketplace.json`

**Files:**
- Modify: `.claude-plugin/marketplace.json`

- [ ] **Step 1: Write failing test for pilot entry**

Append to `tests/marketplace.bats`:

```bash
@test "vps-ninja entry points to github kyzde/vps-ninja" {
  run jq -e '.plugins[] | select(.name == "vps-ninja") | select(.source.source == "github" and .source.repo == "kyzde/vps-ninja")' .claude-plugin/marketplace.json
  [ "$status" -eq 0 ]
}
```

- [ ] **Step 2: Run test — expect FAIL**

Run: `bats tests/marketplace.bats`
Expected: new test fails (plugin list empty).

- [ ] **Step 3: Add pilot entry**

```json
{
  "name": "kyzde-skills",
  "description": "Personal skills marketplace",
  "owner": {"name": "kyzde"},
  "plugins": [
    {
      "name": "vps-ninja",
      "description": "<copy from plugin.json in vps-ninja repo>",
      "source": {"source": "github", "repo": "kyzde/vps-ninja"}
    }
  ]
}
```

- [ ] **Step 4: Run tests — expect PASS**

Run: `bats tests/marketplace.bats`
Expected: 5/5 pass.

- [ ] **Step 5: Commit and push marketplace**

```bash
git add .claude-plugin/marketplace.json tests/marketplace.bats
git commit -m "feat: add vps-ninja to marketplace"
```

### Task 7: End-to-end test — install pilot via marketplace

**Files:** none — verification only.

- [ ] **Step 1: Push marketplace repo to GitHub**

First ensure `kyzde/marketplace-skills` exists as a GitHub repo. If not, create it via `gh repo create kyzde/marketplace-skills --public --source=. --remote=origin`, then:

```bash
git push -u origin main
```

- [ ] **Step 2: Install via Claude Code marketplace path**

In a Claude Code session:

    /plugin marketplace add kyzde/marketplace-skills
    /plugin install vps-ninja@kyzde-skills

Expected: same outcome as Task 5 Step 1. Skill appears in `/plugin list`.

- [ ] **Step 3: Simulate a remote update**

In the `vps-ninja` repo, make a trivial edit (e.g., tweak a word in `SKILL.md`), commit, push to `main`.

In the same Claude Code session:

    /plugin update vps-ninja

Expected: the change is reflected locally. This validates the rolling-main update channel.

- [ ] **Step 4: Revert trivial edit**

```bash
git revert HEAD && git push
```

---

## Part D — Install Script for Codex/Gemini

### Task 8: Skeleton `install.sh` with dispatch + `list` + `claude` subcommands

**Files:**
- Create: `install.sh`
- Create: `tests/install.bats`

- [ ] **Step 1: Write failing tests**

Create `tests/install.bats`:

```bash
#!/usr/bin/env bats

SCRIPT="$BATS_TEST_DIRNAME/../install.sh"

@test "install.sh with no args prints usage and exits non-zero" {
  run bash "$SCRIPT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"usage"* ]]
}

@test "install.sh list prints all 5 skills" {
  run bash "$SCRIPT" list
  [ "$status" -eq 0 ]
  [[ "$output" == *"vps-ninja"* ]]
  [[ "$output" == *"3x-ui"* ]]
  [[ "$output" == *"stitch-skill"* ]]
  [[ "$output" == *"creds-app-skill"* ]]
  [[ "$output" == *"context-map-skill"* ]]
}

@test "install.sh claude prints Claude marketplace instruction" {
  run bash "$SCRIPT" claude
  [ "$status" -eq 0 ]
  [[ "$output" == *"/plugin marketplace add kyzde/marketplace-skills"* ]]
}

@test "install.sh unknown-agent exits non-zero" {
  run bash "$SCRIPT" floob vps-ninja
  [ "$status" -ne 0 ]
}
```

- [ ] **Step 2: Run tests — expect FAIL**

Run: `bats tests/install.bats`
Expected: all fail (install.sh does not exist).

- [ ] **Step 3: Write `install.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

SKILLS=(vps-ninja 3x-ui stitch-skill creds-app-skill context-map-skill)
OWNER="kyzde"
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

cmd_list() {
  printf '%s\n' "${SKILLS[@]}"
}

cmd_claude() {
  cat <<EOF
Claude Code install:

  /plugin marketplace add $OWNER/marketplace-skills
  /plugin install <skill>@kyzde-skills

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
```

```bash
chmod +x install.sh
```

- [ ] **Step 4: Run tests — expect PASS**

Run: `bats tests/install.bats`
Expected: 4/4 pass.

- [ ] **Step 5: Commit**

```bash
git add install.sh tests/install.bats
git commit -m "feat: install.sh skeleton with list/claude subcommands"
```

### Task 9: `codex` and `gemini` subcommands

**Files:**
- Modify: `install.sh`
- Modify: `tests/install.bats`

- [ ] **Step 1: Write failing tests (use dry-run mode)**

Append to `tests/install.bats`:

```bash
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
  [[ "$output" == *"kyzde/vps-ninja"* ]]
  [[ "$output" == *"$BATS_TMPDIR/codex"* ]]
}

@test "install.sh gemini vps-ninja in dry-run prints clone command" {
  INSTALL_DIR="$BATS_TMPDIR/gemini" DRY_RUN=1 run bash "$SCRIPT" gemini vps-ninja
  [ "$status" -eq 0 ]
  [[ "$output" == *"git clone"* ]]
}

@test "install.sh codex without INSTALL_DIR and no default path exits with clear error" {
  INSTALL_DIR="" run bash "$SCRIPT" codex vps-ninja
  [ "$status" -ne 0 ]
  [[ "$output" == *"INSTALL_DIR"* ]]
}
```

- [ ] **Step 2: Run — expect FAIL**

Run: `bats tests/install.bats`
Expected: new tests fail.

- [ ] **Step 3: Implement `codex`/`gemini` in `install.sh`**

Replace the `codex` and `gemini` stubs with:

```bash
default_install_dir() {
  case "$1" in
    codex)  [ -n "${CODEX_DEFAULT_DIR:-}" ] && echo "$CODEX_DEFAULT_DIR" || echo "" ;;
    gemini) [ -n "${GEMINI_DEFAULT_DIR:-}" ] && echo "$GEMINI_DEFAULT_DIR" || echo "" ;;
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

  for skill in "$@"; do
    is_known_skill "$skill" || { echo "unknown skill: $skill" >&2; exit 2; }
    local dest="$target/$skill"
    local cmd="git clone --depth=1 $GIT_HOST/$OWNER/$skill.git $dest"
    if [ "${DRY_RUN:-0}" = "1" ]; then
      echo "$cmd"
    else
      mkdir -p "$target"
      eval "$cmd"
    fi
  done
}
```

Update dispatch:

```bash
    codex)   install_for_agent codex  "$@" ;;
    gemini)  install_for_agent gemini "$@" ;;
```

- [ ] **Step 4: Run tests — expect PASS**

Run: `bats tests/install.bats`
Expected: all pass.

- [ ] **Step 5: Manual smoke — real install of pilot to a throwaway dir**

```bash
INSTALL_DIR=/tmp/smoke-codex ./install.sh codex vps-ninja
ls /tmp/smoke-codex/vps-ninja/
```

Expected: repo is cloned, `.claude-plugin/plugin.json` present.

- [ ] **Step 6: Commit**

```bash
git add install.sh tests/install.bats
git commit -m "feat: install.sh codex/gemini subcommands"
```

### Task 10: `update` subcommand

**Files:**
- Modify: `install.sh`
- Modify: `tests/install.bats`

- [ ] **Step 1: Write failing tests**

Append to `tests/install.bats`:

```bash
@test "install.sh update without agent exits non-zero" {
  run bash "$SCRIPT" update
  [ "$status" -ne 0 ]
}

@test "install.sh update codex in dry-run runs git pull for each installed skill" {
  tmp="$BATS_TMPDIR/upd"
  mkdir -p "$tmp/vps-ninja/.git"
  INSTALL_DIR="$tmp" DRY_RUN=1 run bash "$SCRIPT" update codex
  [ "$status" -eq 0 ]
  [[ "$output" == *"git -C $tmp/vps-ninja pull"* ]]
}
```

- [ ] **Step 2: Run — expect FAIL**

Run: `bats tests/install.bats`

- [ ] **Step 3: Implement `update`**

Add to `install.sh`:

```bash
cmd_update() {
  local agent=${1:-}
  [ -z "$agent" ] && { echo "error: agent required" >&2; exit 2; }
  shift || true
  local only_skill=${1:-}

  local target=${INSTALL_DIR:-$(default_install_dir "$agent")}
  [ -z "$target" ] && { echo "error: INSTALL_DIR not set" >&2; exit 2; }

  local targets=()
  if [ -n "$only_skill" ]; then
    targets=("$only_skill")
  else
    for skill in "${SKILLS[@]}"; do
      [ -d "$target/$skill/.git" ] && targets+=("$skill")
    done
  fi

  for skill in "${targets[@]}"; do
    local cmd="git -C $target/$skill pull --ff-only"
    if [ "${DRY_RUN:-0}" = "1" ]; then echo "$cmd"; else eval "$cmd"; fi
  done
}
```

Dispatch:

```bash
    update)  cmd_update "$@" ;;
```

- [ ] **Step 4: Run tests — expect PASS**

Run: `bats tests/install.bats`

- [ ] **Step 5: Commit**

```bash
git add install.sh tests/install.bats
git commit -m "feat: install.sh update subcommand"
```

### Task 11: PowerShell mirror `install.ps1`

**Files:**
- Create: `install.ps1`
- Create: `tests/install.ps1.tests.ps1`

- [ ] **Step 1: Write failing Pester tests**

Create `tests/install.ps1.tests.ps1`:

```powershell
Describe 'install.ps1' {
  BeforeAll { $script:Script = Join-Path $PSScriptRoot '..\install.ps1' }

  It 'list prints all 5 skills' {
    $out = & $script:Script list
    $out | Should -Contain 'vps-ninja'
    $out | Should -Contain '3x-ui'
    $out | Should -Contain 'stitch-skill'
    $out | Should -Contain 'creds-app-skill'
    $out | Should -Contain 'context-map-skill'
  }

  It 'claude prints marketplace add instruction' {
    $out = (& $script:Script claude) -join "`n"
    $out | Should -Match '/plugin marketplace add kyzde/marketplace-skills'
  }

  It 'codex dry-run prints git clone command' {
    $env:INSTALL_DIR = Join-Path $env:TEMP 'pstest'
    $env:DRY_RUN = '1'
    $out = (& $script:Script codex vps-ninja) -join "`n"
    $out | Should -Match 'git clone'
    $out | Should -Match 'kyzde/vps-ninja'
    Remove-Item Env:INSTALL_DIR, Env:DRY_RUN
  }
}
```

- [ ] **Step 2: Run — expect FAIL**

Run (PowerShell):

```powershell
Invoke-Pester tests/install.ps1.tests.ps1
```

- [ ] **Step 3: Create `install.ps1`**

```powershell
#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

$Skills = @('vps-ninja','3x-ui','stitch-skill','creds-app-skill','context-map-skill')
$Owner = 'kyzde'
$GitHost = 'https://github.com'

function Show-Usage {
@"
usage: install.ps1 <command> [args]

commands:
  claude                       print Claude Code install instructions
  codex <skill>...             install skills into Codex plugins dir
  gemini <skill>...            install skills into Gemini extensions dir
  update <agent> [skill]       git pull installed skills
  list                         list available skills

env vars:
  INSTALL_DIR                  override destination dir
"@
}

function Is-KnownSkill($s) { $Skills -contains $s }

function Cmd-List { $Skills | ForEach-Object { $_ } }

function Cmd-Claude {
@"
Claude Code install:

  /plugin marketplace add $Owner/marketplace-skills
  /plugin install <skill>@kyzde-skills

Available skills:
"@
  Cmd-List
}

function Install-ForAgent($agent, $skillsToInstall) {
  if (-not $skillsToInstall) { Write-Error 'no skills specified'; exit 2 }
  $target = $env:INSTALL_DIR
  if (-not $target) { Write-Error 'INSTALL_DIR not set'; exit 2 }

  foreach ($s in $skillsToInstall) {
    if (-not (Is-KnownSkill $s)) { Write-Error "unknown skill: $s"; exit 2 }
    $dest = Join-Path $target $s
    $cmd = "git clone --depth=1 $GitHost/$Owner/$s.git $dest"
    if ($env:DRY_RUN -eq '1') { Write-Output $cmd }
    else {
      New-Item -ItemType Directory -Force -Path $target | Out-Null
      Invoke-Expression $cmd
    }
  }
}

function Cmd-Update($agent, $onlySkill) {
  $target = $env:INSTALL_DIR
  if (-not $target) { Write-Error 'INSTALL_DIR not set'; exit 2 }
  $targets = if ($onlySkill) { @($onlySkill) }
             else { $Skills | Where-Object { Test-Path (Join-Path $target "$_/.git") } }
  foreach ($s in $targets) {
    $cmd = "git -C $target/$s pull --ff-only"
    if ($env:DRY_RUN -eq '1') { Write-Output $cmd } else { Invoke-Expression $cmd }
  }
}

$cmd, $rest = $args[0], @($args | Select-Object -Skip 1)
if (-not $cmd) { Show-Usage; exit 2 }

switch ($cmd) {
  'list'   { Cmd-List }
  'claude' { Cmd-Claude }
  'codex'  { Install-ForAgent 'codex'  $rest }
  'gemini' { Install-ForAgent 'gemini' $rest }
  'update' { Cmd-Update $rest[0] $rest[1] }
  default  { Write-Error "unknown command: $cmd"; Show-Usage; exit 2 }
}
```

- [ ] **Step 4: Run Pester — expect PASS**

Run: `Invoke-Pester tests/install.ps1.tests.ps1`
Expected: 3/3 pass.

- [ ] **Step 5: Commit**

```bash
git add install.ps1 tests/install.ps1.tests.ps1
git commit -m "feat: install.ps1 PowerShell mirror"
```

---

## Part E — Marketplace CI

### Task 12: CI workflow for marketplace repo

**Files:**
- Create: `.github/workflows/validate.yml`
- Create: `scripts/validate-marketplace.sh`

- [ ] **Step 1: Write `scripts/validate-marketplace.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

# 1. marketplace.json structure
jq -e '.name and .description and .owner.name and (.plugins | type == "array")' \
  .claude-plugin/marketplace.json >/dev/null

# 2. every plugin entry shape + remote reachability
jq -r '.plugins[] | "\(.name) \(.source.repo)"' .claude-plugin/marketplace.json | \
while read -r name repo; do
  [ -n "$name" ] && [ -n "$repo" ] || { echo "missing name/repo for $name"; exit 1; }
  git ls-remote "https://github.com/$repo" HEAD >/dev/null \
    || { echo "unreachable: $repo"; exit 1; }
done

# 3. install.sh
shellcheck install.sh
bats tests/install.bats
bats tests/marketplace.bats

echo "OK"
```

```bash
chmod +x scripts/validate-marketplace.sh
```

- [ ] **Step 2: Run locally — expect PASS**

Run: `./scripts/validate-marketplace.sh`
Expected: "OK" printed.

- [ ] **Step 3: Create `.github/workflows/validate.yml`**

```yaml
name: validate
on: [push, pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install bats + shellcheck
        run: sudo apt-get update && sudo apt-get install -y bats shellcheck jq
      - name: Run validation
        run: ./scripts/validate-marketplace.sh
```

- [ ] **Step 4: Commit and push, verify green**

```bash
git add scripts/validate-marketplace.sh .github/workflows/validate.yml
git commit -m "ci: validate marketplace on push"
git push
```

Wait for GitHub Actions to go green on the push.

---

## Part F — Migrate Remaining 4 Skills

Each of these skills follows the same pattern as Task 4. The pattern is mechanical: substitute the skill name. To reduce error, follow the checklist below for EACH of the four skills.

### Task 13: Extract migration template

**Files:**
- Create (in marketplace repo): `scripts/scaffold-skill-repo.sh`

- [ ] **Step 1: Write `scripts/scaffold-skill-repo.sh`**

This script takes a skill-repo that's already cloned locally and on a working branch, and applies the structural migration. It does NOT push. It does NOT touch SKILL.md content beyond moving the file.

```bash
#!/usr/bin/env bash
# Usage: scaffold-skill-repo.sh <repo-path> <skill-name> <description>
# Applies marketplace-compatible layout to an existing skill repo.
set -euo pipefail

ROOT=${1:?repo path required}
NAME=${2:?skill name required}
DESC=${3:?description required}

cd "$ROOT"

# 1. Move SKILL.md
if [ -f SKILL.md ] && [ ! -f "skills/$NAME/SKILL.md" ]; then
  mkdir -p "skills/$NAME"
  git mv SKILL.md "skills/$NAME/SKILL.md"
fi

# 2. plugin.json
mkdir -p .claude-plugin
cat > .claude-plugin/plugin.json <<EOF
{
  "name": "$NAME",
  "version": "0.1.0",
  "description": "$DESC",
  "author": {"name": "kyzde"},
  "homepage": "https://github.com/kyzde/$NAME",
  "repository": "https://github.com/kyzde/$NAME",
  "license": "MIT"
}
EOF

# 3. gemini-extension.json
cat > gemini-extension.json <<EOF
{
  "name": "$NAME",
  "version": "0.1.0",
  "description": "$DESC",
  "contextFileName": "GEMINI.md"
}
EOF

# 4. Symlinks (best-effort)
rm -f AGENTS.md GEMINI.md
ln -s "skills/$NAME/SKILL.md" AGENTS.md 2>/dev/null || cp "skills/$NAME/SKILL.md" AGENTS.md
ln -s "skills/$NAME/SKILL.md" GEMINI.md 2>/dev/null || cp "skills/$NAME/SKILL.md" GEMINI.md

# 5. sync-mirrors.sh
mkdir -p scripts
cat > scripts/sync-mirrors.sh <<EOF
#!/usr/bin/env bash
set -euo pipefail
ROOT="\$(cd "\$(dirname "\$0")/.." && pwd)"
SRC="\$ROOT/skills/$NAME/SKILL.md"
for MIRROR in "\$ROOT/AGENTS.md" "\$ROOT/GEMINI.md"; do
  [ -L "\$MIRROR" ] && continue
  cp "\$SRC" "\$MIRROR"
done
EOF
chmod +x scripts/sync-mirrors.sh

# 6. CI workflow
mkdir -p .github/workflows
cat > .github/workflows/validate.yml <<EOF
name: validate
on: [push, pull_request]
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: test -f skills/$NAME/SKILL.md
      - run: jq -e '.name and .version and .description' .claude-plugin/plugin.json
      - run: jq -e '.name and .version and .contextFileName' gemini-extension.json
      - run: diff skills/$NAME/SKILL.md AGENTS.md
      - run: diff skills/$NAME/SKILL.md GEMINI.md
      - run: head -20 skills/$NAME/SKILL.md | grep -q '^---$'
      - run: head -20 skills/$NAME/SKILL.md | grep -q '^name:'
      - run: head -20 skills/$NAME/SKILL.md | grep -q '^description:'
EOF

echo "Scaffolded $NAME at $ROOT"
```

```bash
chmod +x scripts/scaffold-skill-repo.sh
```

- [ ] **Step 2: Verify script by re-running on pilot in a scratch clone**

```bash
mkdir -p /tmp/scaffold-check && cd /tmp/scaffold-check
git clone https://github.com/kyzde/vps-ninja && cd vps-ninja
# Should already be migrated; the script should be idempotent and exit 0.
/c/Users/kyzde/Desktop/Projects/marketplase-skills/scripts/scaffold-skill-repo.sh . vps-ninja "<desc>"
git status  # expect: no changes (idempotent)
```

If the script shows unintended diffs, fix before proceeding to Step 3.

- [ ] **Step 3: Commit**

```bash
cd /c/Users/kyzde/Desktop/Projects/marketplase-skills
git add scripts/scaffold-skill-repo.sh
git commit -m "feat: scaffold-skill-repo.sh migration helper"
```

### Tasks 14–17: Migrate `3x-ui`, `stitch-skill`, `creds-app-skill`, `context-map-skill`

For each skill in `[3x-ui, stitch-skill, creds-app-skill, context-map-skill]`, run the exact same checklist. Complete one before starting the next.

- [ ] **Step 1: Clone and branch**

```bash
cd /c/Users/kyzde/Desktop/Projects/skills-work
git clone https://github.com/kyzde/<skill>
cd <skill>
git checkout -b migrate-to-marketplace-layout
```

- [ ] **Step 2: Record description**

Read the skill's current `SKILL.md` frontmatter and note the `description:` value. You'll pass it to the scaffold script.

- [ ] **Step 3: Run scaffold script**

```bash
/c/Users/kyzde/Desktop/Projects/marketplase-skills/scripts/scaffold-skill-repo.sh . <skill> "<description from step 2>"
```

- [ ] **Step 4: Update README**

Replace with (substituting `<skill>` and `<description>`):

```markdown
# <skill>

<description>

## Install

### Claude Code

    /plugin install https://github.com/kyzde/<skill>
    # or via marketplace:
    /plugin marketplace add kyzde/marketplace-skills
    /plugin install <skill>@kyzde-skills

### Codex CLI / Gemini CLI

    curl -sSL https://raw.githubusercontent.com/kyzde/marketplace-skills/main/install.sh \
      | bash -s <codex|gemini> <skill>

## Updates

Claude: `/plugin update <skill>`
Codex/Gemini: `install.sh update <agent>`
```

- [ ] **Step 5: Local validation**

```bash
jq empty .claude-plugin/plugin.json
jq empty gemini-extension.json
diff skills/<skill>/SKILL.md AGENTS.md
diff skills/<skill>/SKILL.md GEMINI.md
```

Expected: all exit 0.

- [ ] **Step 6: Commit and push**

```bash
git add .
git commit -m "refactor: migrate to marketplace-compatible layout"
git push -u origin migrate-to-marketplace-layout
```

- [ ] **Step 7: Wait for CI, merge, pull main**

```bash
# ... merge PR on GitHub ...
git checkout main && git pull
```

- [ ] **Step 8: Add entry to marketplace.json**

Back in `/c/Users/kyzde/Desktop/Projects/marketplase-skills/`, append to `.claude-plugin/marketplace.json`:

```json
{
  "name": "<skill>",
  "description": "<description>",
  "source": {"source": "github", "repo": "kyzde/<skill>"}
}
```

- [ ] **Step 9: Run marketplace tests**

```bash
bats tests/marketplace.bats
./scripts/validate-marketplace.sh
```

Expected: all pass.

- [ ] **Step 10: Commit**

```bash
git add .claude-plugin/marketplace.json
git commit -m "feat: add <skill> to marketplace"
```

Repeat Steps 1-10 for each remaining skill. After all 4 are done:

- [ ] **Step 11: Push marketplace**

```bash
git push
```

Confirm CI is green.

---

## Part G — Final Regression

### Task 18: End-to-end regression across all 5 skills on all 3 agents

**Files:** none — verification only.

- [ ] **Step 1: Claude Code e2e**

Fresh Claude Code session:

    /plugin marketplace add kyzde/marketplace-skills
    /plugin install vps-ninja@kyzde-skills
    /plugin install 3x-ui@kyzde-skills
    /plugin install stitch-skill@kyzde-skills
    /plugin install creds-app-skill@kyzde-skills
    /plugin install context-map-skill@kyzde-skills
    /plugin list

Expected: all 5 show as installed.

- [ ] **Step 2: Codex CLI e2e**

```bash
INSTALL_DIR=<codex plugins dir> ./install.sh codex \
  vps-ninja 3x-ui stitch-skill creds-app-skill context-map-skill
```

Expected: all 5 cloned. Start Codex; verify skills are discovered.

- [ ] **Step 3: Gemini CLI e2e**

```bash
INSTALL_DIR=<gemini extensions dir> ./install.sh gemini \
  vps-ninja 3x-ui stitch-skill creds-app-skill context-map-skill
```

Expected: all 5 cloned. Start Gemini; verify extensions load.

- [ ] **Step 4: Remote update propagation spot-check**

Pick one skill. Push a trivial change to `main`. In each agent:

- Claude: `/plugin update <skill>` — expect change appears.
- Codex: `INSTALL_DIR=... ./install.sh update codex <skill>` — expect `git pull` updates the working copy.
- Gemini: same as Codex with `gemini`.

Revert the trivial change.

- [ ] **Step 5: Update marketplace README's "Available skills" table**

Fill in the real descriptions (they were TBD in Task 1). Commit:

```bash
git add README.md
git commit -m "docs: complete skill descriptions in README"
git push
```

- [ ] **Step 6: Final tag**

```bash
git tag -a v0.1.0 -m "First marketplace release"
git push --tags
```

---

## Self-Review

**1. Spec coverage.**
- "Одна ссылка для друзей" → Task 7 (Claude), Task 18 Steps 2/3 (Codex/Gemini via install.sh) ✓
- "Удалённые обновления" → Task 7 Step 3, Task 18 Step 4 ✓
- "Мульти-агентность" → Tasks 4, 5, 14–17 (each skill ships plugin.json + gemini-extension.json + AGENTS.md/GEMINI.md) ✓
- Rolling main policy → marketplace.json without version pin (Task 6) ✓
- CI gate in each skill-repo → Task 4 Step 6 + template in Task 13 ✓
- CI gate in marketplace → Task 12 ✓
- Install script with subcommands `claude`/`codex`/`gemini`/`update`/`list` → Tasks 8–10 ✓
- PowerShell mirror → Task 11 ✓
- Windows symlink fallback via `sync-mirrors.sh` → Task 4 Step 5, template in Task 13 ✓
- Migration of 4 remaining skills → Tasks 14–17 ✓
- Final regression → Task 18 ✓

**2. Placeholder scan.** The only intentional "TBD" is the "Available skills" table in the marketplace README (Task 1), resolved in Task 18 Step 5 once real descriptions exist. No other placeholders.

**3. Type consistency.** Skill name list `[vps-ninja, 3x-ui, stitch-skill, creds-app-skill, context-map-skill]` identical across `install.sh`, `install.ps1`, and Task 18. `contextFileName: "GEMINI.md"` is the same in every skill's `gemini-extension.json`. Marketplace name `kyzde-skills` is the same in `marketplace.json`, `install.sh` `claude` output, and `install.ps1`. Repo owner `kyzde` same everywhere.
