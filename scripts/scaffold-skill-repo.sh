#!/usr/bin/env bash
# Apply marketplace-compatible layout to an existing skill repo.
# Usage: scaffold-skill-repo.sh <repo-path> <internal-skill-name> <plugin-name> <description>
set -euo pipefail

if [ "$#" -lt 4 ]; then
  echo "usage: $0 <repo-path> <internal-skill-name> <plugin-name> <description>" >&2
  exit 2
fi

ROOT=$1
SKILL=$2
PLUGIN=$3
DESC=$4

[ -d "$ROOT" ] || { echo "error: $ROOT is not a directory" >&2; exit 2; }
[ -d "$ROOT/.git" ] || { echo "error: $ROOT is not a git repo" >&2; exit 2; }

cd "$ROOT"

# 1. Move SKILL.md
if [ -f SKILL.md ]; then
  mkdir -p "skills/$SKILL"
  git mv SKILL.md "skills/$SKILL/SKILL.md"
elif [ ! -f "skills/$SKILL/SKILL.md" ]; then
  echo "error: no SKILL.md at repo root or skills/$SKILL/SKILL.md" >&2
  exit 2
fi

# 2. Move runtime resource dirs into skills/<name>/
for dir in scripts references config templates; do
  # Only move if the root dir exists AND the target skill dir does not already have it
  if [ -d "$dir" ] && [ ! -d "skills/$SKILL/$dir" ]; then
    git mv "$dir" "skills/$SKILL/$dir"
  fi
done

# 3. plugin.json
mkdir -p .claude-plugin
cat > .claude-plugin/plugin.json <<EOF
{
  "name": "$PLUGIN",
  "version": "0.1.0",
  "description": "$DESC",
  "author": {"name": "kyzdes"},
  "homepage": "https://github.com/kyzdes/$PLUGIN",
  "repository": "https://github.com/kyzdes/$PLUGIN",
  "license": "MIT"
}
EOF

# 4. gemini-extension.json
cat > gemini-extension.json <<EOF
{
  "name": "$PLUGIN",
  "version": "0.1.0",
  "description": "$DESC",
  "contextFileName": "GEMINI.md"
}
EOF

# 5. Mirrors
rm -f AGENTS.md GEMINI.md
ln -s "skills/$SKILL/SKILL.md" AGENTS.md 2>/dev/null || cp "skills/$SKILL/SKILL.md" AGENTS.md
ln -s "skills/$SKILL/SKILL.md" GEMINI.md 2>/dev/null || cp "skills/$SKILL/SKILL.md" GEMINI.md

# 6. sync-mirrors.sh
mkdir -p scripts
cat > scripts/sync-mirrors.sh <<EOF
#!/usr/bin/env bash
set -euo pipefail
ROOT="\$(cd "\$(dirname "\$0")/.." && pwd)"
SRC="\$ROOT/skills/$SKILL/SKILL.md"
for MIRROR in "\$ROOT/AGENTS.md" "\$ROOT/GEMINI.md"; do
  [ -L "\$MIRROR" ] && continue
  cp "\$SRC" "\$MIRROR"
done
EOF
chmod +x scripts/sync-mirrors.sh

# 7. CI workflow — generate resource-dirs check only for dirs that exist in skills/<name>/
present_dirs=()
for dir in scripts references config templates; do
  [ -d "skills/$SKILL/$dir" ] && present_dirs+=("$dir")
done

resource_check=""
if [ "${#present_dirs[@]}" -gt 0 ]; then
  resource_check="      - name: Check skill resource dirs present"$'\n'
  resource_check+="        run: |"$'\n'
  for d in "${present_dirs[@]}"; do
    resource_check+="          test -d skills/$SKILL/$d"$'\n'
  done
fi

mkdir -p .github/workflows
cat > .github/workflows/validate.yml <<EOF
name: validate
on: [push, pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Check SKILL.md exists
        run: test -f skills/$SKILL/SKILL.md

${resource_check}      - name: Validate plugin.json
        run: jq -e '.name and .version and .description' .claude-plugin/plugin.json

      - name: Validate gemini-extension.json
        run: |
          jq -e '.name and .version and .contextFileName' gemini-extension.json
          test "\$(jq -r .contextFileName gemini-extension.json)" = "GEMINI.md"

      - name: Check mirror parity
        run: |
          diff skills/$SKILL/SKILL.md AGENTS.md
          diff skills/$SKILL/SKILL.md GEMINI.md

      - name: Check SKILL.md frontmatter parses
        run: |
          head -30 skills/$SKILL/SKILL.md | grep -q '^---$'
          head -30 skills/$SKILL/SKILL.md | grep -q '^name:'
          head -30 skills/$SKILL/SKILL.md | grep -q '^description:'
EOF

echo "Scaffolded $PLUGIN (internal skill: $SKILL) at $ROOT"
