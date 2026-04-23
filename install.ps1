#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

$Skills = @('vps-ninja', 'creds-app-skill')
$Owner = 'kyzdes'
$Marketplace = 'kyzdes-skills'
$GitHost = 'https://github.com'

function Show-Usage {
    @'
usage: install.ps1 <command> [args]

commands:
  claude                       print Claude Code install instructions
  codex <skill>...             install skills into Codex plugins dir
  gemini <skill>...            install skills into Gemini extensions dir
  update <agent> [skill]       git pull installed skills
  list                         list available skills

env vars:
  INSTALL_DIR                  override destination dir for codex/gemini
'@
}

function Test-KnownSkill { param([string]$Name) $Skills -contains $Name }

function Get-DefaultInstallDir {
    param([string]$Agent)
    switch ($Agent) {
        'codex'  { if ($env:CODEX_DEFAULT_DIR)  { return $env:CODEX_DEFAULT_DIR  } else { return '' } }
        'gemini' { if ($env:GEMINI_DEFAULT_DIR) { return $env:GEMINI_DEFAULT_DIR } else { return '' } }
        default  { return '' }
    }
}

function Invoke-ListCommand { $Skills | ForEach-Object { $_ } }

function Invoke-ClaudeCommand {
    @"
Claude Code install:

  /plugin marketplace add $Owner/marketplace-skills
  /plugin install <skill>@$Marketplace

Available skills:
"@
    Invoke-ListCommand
}

function Invoke-InstallForAgent {
    param([string]$Agent, [string[]]$SkillsToInstall)
    if (-not $SkillsToInstall -or $SkillsToInstall.Count -eq 0) {
        [Console]::Error.WriteLine('error: no skills specified')
        exit 2
    }

    $target = if ($env:INSTALL_DIR) { $env:INSTALL_DIR } else { Get-DefaultInstallDir $Agent }
    if (-not $target) {
        [Console]::Error.WriteLine(@"
error: INSTALL_DIR not set and no default path known for $Agent.

Set INSTALL_DIR to the path where $Agent looks for plugins/extensions, e.g.:
  `$env:INSTALL_DIR = 'C:\path\to\$Agent\plugins'; .\install.ps1 $Agent <skill>...
"@)
        exit 2
    }

    foreach ($skill in $SkillsToInstall) {
        if (-not (Test-KnownSkill $skill)) {
            [Console]::Error.WriteLine("unknown skill: $skill")
            exit 2
        }
        $dest = Join-Path $target $skill
        $cmd = "git clone --depth=1 $GitHost/$Owner/$skill.git $dest"
        if ($env:DRY_RUN -eq '1') {
            Write-Output $cmd
        } else {
            New-Item -ItemType Directory -Force -Path $target | Out-Null
            Invoke-Expression $cmd
        }
    }
}

function Invoke-UpdateCommand {
    param([string]$Agent, [string]$OnlySkill)
    if (-not $Agent) {
        [Console]::Error.WriteLine('error: agent required')
        exit 2
    }

    $target = if ($env:INSTALL_DIR) { $env:INSTALL_DIR } else { Get-DefaultInstallDir $Agent }
    if (-not $target) {
        [Console]::Error.WriteLine('error: INSTALL_DIR not set')
        exit 2
    }

    $targets = @()
    if ($OnlySkill) {
        if (-not (Test-KnownSkill $OnlySkill)) {
            [Console]::Error.WriteLine("unknown skill: $OnlySkill")
            exit 2
        }
        $targets = @($OnlySkill)
    } else {
        foreach ($skill in $Skills) {
            if (Test-Path (Join-Path $target "$skill/.git")) {
                $targets += $skill
            }
        }
    }

    foreach ($skill in $targets) {
        $cmd = "git -C $target/$skill pull --ff-only"
        if ($env:DRY_RUN -eq '1') {
            Write-Output $cmd
        } else {
            Invoke-Expression $cmd
        }
    }
}

if ($args.Count -lt 1) {
    Show-Usage
    exit 2
}

$cmd = $args[0]
$rest = @($args | Select-Object -Skip 1)

switch ($cmd) {
    'list'   { Invoke-ListCommand }
    'claude' { Invoke-ClaudeCommand }
    'codex'  { Invoke-InstallForAgent 'codex'  $rest }
    'gemini' { Invoke-InstallForAgent 'gemini' $rest }
    'update' { Invoke-UpdateCommand $rest[0] $rest[1] }
    default  {
        [Console]::Error.WriteLine("unknown command: $cmd")
        Show-Usage
        exit 2
    }
}
