# kyzdes-skills — personal skills marketplace

Personal collection of skills shared across Claude Code, Codex CLI, and Gemini CLI.

## Install

### Claude Code

    /plugin marketplace add kyzdes/marketplace-skills
    /plugin install vps-ninja@kyzdes-skills

### Codex CLI

    curl -sSL https://raw.githubusercontent.com/kyzdes/marketplace-skills/main/install.sh | bash -s codex vps-ninja

### Gemini CLI

    curl -sSL https://raw.githubusercontent.com/kyzdes/marketplace-skills/main/install.sh | bash -s gemini vps-ninja

## Available skills

| Skill | What it does |
|---|---|
| vps-ninja | (TBD — filled during Task 18 from real skill README) |
| creds-app-skill | (TBD) |

More skills will be added later (e.g., `3x-ui`, `stitch-skill`, `context-map-skill`).

## Updates

Claude: `/plugin update <skill>`
Codex/Gemini: `install.sh update <agent>`

See `docs/superpowers/specs/2026-04-23-marketplace-skills-design.md` for design.
