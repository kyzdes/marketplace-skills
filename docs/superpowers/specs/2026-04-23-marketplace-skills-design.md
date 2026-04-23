# Marketplace for Personal Skills — Design

**Date:** 2026-04-23
**Owner:** kyzde
**Status:** Draft, awaiting user review

## Цель

Упаковать 5 личных скиллов (`vps-ninja`, `3x-ui`, `stitch-skill`, `creds-app-skill`, `context-map-skill`) в маркетплейс со следующими свойствами:

1. **Одна ссылка для друзей** — друг вводит одну команду и получает доступ ко всем 5 скиллам.
2. **Удалённые обновления** — правка в репо скилла автоматически доходит до всех установок при `/plugin update` (Claude) или `install.sh update` (Codex/Gemini).
3. **Мульти-агентность** — каждый скилл работает в Claude Code, Codex CLI и Gemini CLI.

Референс: `github.com/obra/superpowers` + `github.com/obra/superpowers-marketplace`.

## Ключевые решения

| Вопрос | Решение |
|---|---|
| Топология репо | 5 независимых skill-репо + 1 marketplace-репо, ссылающийся на них через `marketplace.json` |
| Зависимости между скиллами | Все скиллы независимы |
| Мульти-агентность | `SKILL.md` — источник правды; `AGENTS.md` и `GEMINI.md` — симлинки на него; `gemini-extension.json` — тонкий манифест-указатель |
| Политика обновлений | Rolling на `main`; дешёвый CI-гейт (lint + schema) защищает от случайной поломки |
| Sharing UX | Claude — нативный `/plugin marketplace add`; Codex/Gemini — один `install.sh` с подкомандами |

## Архитектура

Двухконтурная схема:

**Внутренний контур — 5 skill-репо.** Каждое самодостаточно: ставится напрямую (мимо marketplace), работает на всех трёх агентах.

**Внешний контур — marketplace-репо.** Не хранит содержимого скиллов, только каталогизирует:
- `marketplace.json` — для Claude Code.
- `install.sh` / `install.ps1` — для Codex/Gemini.
- README с инструкциями для каждого агента.

### Структура skill-репо

Пример для `kyzde/vps-ninja`:

```
kyzde/vps-ninja/
├── .claude-plugin/
│   └── plugin.json                ← {name, version, description, author}
├── skills/
│   └── vps-ninja/
│       └── SKILL.md               ← ЕДИНСТВЕННЫЙ источник правды
├── AGENTS.md                      ← симлинк → skills/vps-ninja/SKILL.md
├── GEMINI.md                      ← симлинк → skills/vps-ninja/SKILL.md
├── gemini-extension.json          ← {name, version, contextFileName: "GEMINI.md"}
├── README.md                      ← инструкции standalone-установки для каждого агента
└── .github/workflows/validate.yml ← CI-гейт
```

**Почему SKILL.md под `skills/<name>/`:** обязательная конвенция Claude Code — плагин содержит скиллы в подкаталоге `skills/`.

**Почему AGENTS.md/GEMINI.md — симлинки, а не копии:** один источник правды, исключён дрейф содержимого. Fallback для Windows без dev-mode: `scripts/sync-mirrors.sh` + pre-commit хук копирует SKILL.md в AGENTS.md/GEMINI.md как обычные файлы; CI всё равно проверяет что содержимое идентично.

**Почему `gemini-extension.json` тонкий:** реальное содержимое живёт в GEMINI.md (= SKILL.md); JSON только регистрирует extension с указанием `contextFileName`.

### Структура marketplace-репо

```
kyzde/marketplace-skills/
├── .claude-plugin/
│   └── marketplace.json
├── install.sh                      ← подкоманды: claude, codex, gemini, update, list
├── install.ps1                     ← функциональное зеркало для Windows
├── README.md
└── .github/workflows/validate.yml  ← проверка что все github:kyzde/<name> доступны
```

**`marketplace.json`:**

```json
{
  "name": "kyzde-skills",
  "description": "Personal skills marketplace",
  "owner": {"name": "kyzde"},
  "plugins": [
    {"name": "vps-ninja",         "source": {"source": "github", "repo": "kyzde/vps-ninja"}},
    {"name": "3x-ui",             "source": {"source": "github", "repo": "kyzde/3x-ui"}},
    {"name": "stitch-skill",      "source": {"source": "github", "repo": "kyzde/stitch-skill"}},
    {"name": "creds-app-skill",   "source": {"source": "github", "repo": "kyzde/creds-app-skill"}},
    {"name": "context-map-skill", "source": {"source": "github", "repo": "kyzde/context-map-skill"}}
  ]
}
```

Без version-pin → Claude тянет `main` при `/plugin install` и `/plugin update`. Это и есть канал удалённых обновлений.

## Пользовательские сценарии

### Claude Code

```
/plugin marketplace add kyzde/marketplace-skills
/plugin install vps-ninja@kyzde-skills
# ... позже
/plugin update vps-ninja
```

Механика: Claude клонит `kyzde/vps-ninja`, читает `.claude-plugin/plugin.json`, подцепляет `skills/vps-ninja/SKILL.md`. На update — `git pull` из того же клона.

### Codex CLI

```bash
# одноразовая установка
curl -sSL https://raw.githubusercontent.com/kyzde/marketplace-skills/main/install.sh \
  | bash -s codex vps-ninja 3x-ui

# обновление позже
curl -sSL .../install.sh | bash -s update codex
```

Альтернативно: склонить marketplace-репо локально и запускать `./install.sh ...`.

### Gemini CLI

```bash
curl -sSL .../install.sh | bash -s gemini vps-ninja
```

Gemini подхватывает extension через `gemini-extension.json`; контекст читается из `GEMINI.md`.

## Install-скрипт — дизайн

Единый `install.sh` с подкомандами:

| Команда | Действие |
|---|---|
| `install.sh claude` | Печатает инструкцию (Claude использует нативный marketplace, инсталлер не нужен) |
| `install.sh codex <skill>...` | `git clone --depth=1` каждого скилла в Codex plugins dir |
| `install.sh gemini <skill>...` | То же в Gemini extensions dir |
| `install.sh update <agent> [skill]` | `git pull --ff-only` в установленных; без `[skill]` обновляет все |
| `install.sh list` | Печатает 5 доступных скиллов |

**Принципы:**
- Скрипт **read-only относительно содержимого скиллов** — никакой пост-обработки. Это сохраняет "одна ссылка" UX: правки в skill-репо доходят до друга без обновления инсталлера.
- `INSTALL_DIR` env var переопределяет путь установки для пользователей с нестандартной раскладкой.
- `.ps1` — функциональное зеркало, не порт один-в-один.

**Открытый вопрос (TBD, разрешить перед релизом):** точные дефолтные пути установки для Codex CLI plugins и Gemini CLI extensions. Нужно подтвердить из официальной документации каждого CLI на момент имплементации. До подтверждения скрипт требует явный `INSTALL_DIR` для этих агентов.

## CI / валидация

### В каждом skill-репо (`.github/workflows/validate.yml`)

- Fail если отсутствует `skills/<name>/SKILL.md`.
- Fail если `plugin.json` — невалидный JSON или нет обязательных полей (`name`, `version`, `description`).
- Fail если frontmatter `SKILL.md` не парсится (обязательны `name`, `description`).
- Fail если содержимое `AGENTS.md` и `GEMINI.md` (или их target) не совпадает с `SKILL.md`.
- Markdown lint на `SKILL.md`.

### В marketplace-репо

- JSON-schema валидация `marketplace.json`.
- `git ls-remote` каждого `kyzde/<name>` — существует и `main` доступен.
- `shellcheck install.sh` + `bats` smoke-тест в dry-run режиме.

## Миграция существующих скиллов

Одноразовая работа в каждом из 5 репо:

1. Переложить содержимое в `skills/<name>/SKILL.md`.
2. Добавить `.claude-plugin/plugin.json`.
3. Создать симлинки `AGENTS.md` и `GEMINI.md` на `skills/<name>/SKILL.md`; добавить fallback-скрипт для Windows.
4. Добавить `gemini-extension.json`.
5. Добавить CI workflow.
6. Обновить README: инструкции установки для каждого агента.

**Порядок:** один пилот (`vps-ninja`) → end-to-end проверка на всех трёх агентах → прогон остальных 4 по тому же шаблону. Пилот валидирует, что схема работает целиком, до того как тиражировать.

## Тестирование

Три уровня:

1. **Unit / lint** — CI-гейты выше.
2. **End-to-end на пилоте (`vps-ninja`):**
   - Claude: `/plugin marketplace add` → `/plugin install` → скилл триггерится по своему описанию.
   - Codex: `install.sh codex vps-ninja` → скилл виден Codex CLI.
   - Gemini: `install.sh gemini vps-ninja` → `GEMINI.md` загружается как контекст.
3. **Regression после миграции остальных 4** — повторить e2e на каждом из оставшихся.

## Что НЕ входит в scope

- Автоматические pre-release каналы / semver / теги версий. Rolling `main`, если захочется stability-канал — отдельный проект.
- Public discoverability (размещение в официальных каталогах Claude/Codex). Сейчас цель — "одна ссылка для друзей".
- UI для управления скиллами помимо нативных CLI-команд агентов.
- Межскилловые зависимости (скиллы независимы по решению пользователя).
- Метрики использования / телеметрия.

## Риски и открытые вопросы

| Риск | Митигация |
|---|---|
| Пути установки Codex/Gemini подтверждены не из доков | `INSTALL_DIR` override + TBD-пометка; подтвердить перед релизом |
| Windows без dev-mode ломает симлинки | Fallback: pre-commit копирует SKILL.md в AGENTS.md/GEMINI.md как обычные файлы; CI верифицирует идентичность |
| Push сломанного `main` в skill-репо ломает всех пользователей | CI-гейт в skill-репо; rolling-политика принимается осознанно как "быстро → важнее чем идеальная стабильность" для личного использования |
| Формат `marketplace.json` может измениться в Claude Code | Следим за release notes; структура валидируется в CI, схема централизована |
