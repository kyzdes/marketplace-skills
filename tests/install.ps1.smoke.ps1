#!/usr/bin/env pwsh
# Smoke test for install.ps1 — runs each subcommand, asserts exit codes and output.
# Usage: pwsh tests/install.ps1.smoke.ps1
# Exits 0 if all checks pass, non-zero on any failure.

$ErrorActionPreference = 'Stop'
$script:Failures = 0
$script:Checks = 0
$Script = Join-Path $PSScriptRoot '..\install.ps1'

function Assert-True { param([string]$Name, [bool]$Condition)
    $script:Checks++
    if ($Condition) { Write-Host "  PASS $Name" -ForegroundColor Green }
    else { Write-Host "  FAIL $Name" -ForegroundColor Red; $script:Failures++ }
}

function Run-Script { param([string[]]$CommandArgs)
    # Build argument list for passing to script
    $argList = @()
    foreach ($arg in $CommandArgs) {
        # Escape single quotes for PowerShell
        $argList += "'{0}'" -f $arg.Replace("'", "''")
    }

    # Build the full command with properly formatted arguments
    if ($argList.Count -eq 0) {
        $cmd = "& `"$Script`" 2>&1"
    } else {
        $cmd = "& `"$Script`" $($argList -join ' ') 2>&1"
    }

    # Run the command and capture both output and exit code
    $output = @(& powershell.exe -NoProfile -Command $cmd)
    $exitCode = $LASTEXITCODE

    return @{ Output = ($output -join "`n"); ExitCode = $exitCode }
}

Write-Host "`n== install.ps1 smoke test =="

# list
Write-Host "`n[list]"
$r = Run-Script @('list')
Assert-True "exit 0" ($r.ExitCode -eq 0)
Assert-True "contains vps-ninja" ($r.Output -match 'vps-ninja')
Assert-True "contains creds-app-skill" ($r.Output -match 'creds-app-skill')

# claude
Write-Host "`n[claude]"
$r = Run-Script @('claude')
Assert-True "exit 0" ($r.ExitCode -eq 0)
Assert-True "mentions kyzdes/marketplace-skills" ($r.Output -match 'kyzdes/marketplace-skills')

# no args
Write-Host "`n[no-args]"
$r = Run-Script @()
Assert-True "exit != 0" ($r.ExitCode -ne 0)
Assert-True "usage printed" ($r.Output -match 'usage:')

# unknown command
Write-Host "`n[unknown command]"
$r = Run-Script @('floob', 'vps-ninja')
Assert-True "exit != 0" ($r.ExitCode -ne 0)

# codex dry-run
Write-Host "`n[codex dry-run]"
$env:INSTALL_DIR = Join-Path $env:TEMP 'ps-smoke-codex'
$env:DRY_RUN = '1'
$r = Run-Script @('codex', 'vps-ninja')
Assert-True "exit 0" ($r.ExitCode -eq 0)
Assert-True "git clone printed" ($r.Output -match 'git clone')
Assert-True "kyzdes/vps-ninja url" ($r.Output -match 'kyzdes/vps-ninja')
Remove-Item Env:INSTALL_DIR, Env:DRY_RUN

# codex missing skill
Write-Host "`n[codex missing skill]"
$r = Run-Script @('codex')
Assert-True "exit != 0" ($r.ExitCode -ne 0)

# codex no INSTALL_DIR
Write-Host "`n[codex no INSTALL_DIR]"
$r = Run-Script @('codex', 'vps-ninja')
Assert-True "exit != 0" ($r.ExitCode -ne 0)

# update no agent
Write-Host "`n[update no agent]"
$r = Run-Script @('update')
Assert-True "exit != 0" ($r.ExitCode -ne 0)

# summary
Write-Host "`n== Summary =="
Write-Host "Checks: $script:Checks, Failures: $script:Failures"
if ($script:Failures -gt 0) { exit 1 } else { exit 0 }
