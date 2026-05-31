# Installs Pillbox skills, agents and commands into each detected provider on Windows.
# PowerShell counterpart of install.sh — pure PowerShell, no jq dependency.
# Usage: ./install.ps1 [-Yes]

#Requires -Version 5.1

[CmdletBinding()]
param(
    [switch]$Yes
)

$ErrorActionPreference = "Stop"

# ─── Paths ────────────────────────────────────────────────────────────────────

$ScriptDir   = $PSScriptRoot
$AgentsDir   = Join-Path $ScriptDir "agents"
$SkillsDir   = Join-Path $ScriptDir "skills"
$CommandsDir = Join-Path $ScriptDir "commands"
$ConfigFile  = Join-Path $ScriptDir "providers\configurations.json"

# ─── Helpers ──────────────────────────────────────────────────────────────────

function Expand-HomePath($p) {
    # Mirror install.sh expand_path: leading ~ → user home.
    if ($p -like "~*") { return ($HOME + $p.Substring(1)) }
    return $p
}

# Renders one agent's frontmatter (without the surrounding --- fences) from the
# JSON object, matching install.sh yaml_from_json:
#   - top-level scalars: `key: <json-quoted value>`  (keeps ':' in descriptions safe)
#   - nested objects (opencode `tools`): `key:` then `  "subkey": <value>`
#     where booleans render bare (true/false) and the key is always quoted.
function Format-Frontmatter($agent) {
    $lines = @()
    foreach ($prop in $agent.PSObject.Properties) {
        $val = $prop.Value
        if ($val -is [System.Management.Automation.PSCustomObject]) {
            $sub = @($val.PSObject.Properties)
            if ($sub.Count -eq 0) { continue }
            $lines += "$($prop.Name):"
            foreach ($s in $sub) {
                $sv = $s.Value
                if ($sv -is [bool]) {
                    $rendered = if ($sv) { "true" } else { "false" }
                } else {
                    $rendered = [string]$sv
                }
                $key = ($s.Name | ConvertTo-Json -Compress)
                $lines += "  ${key}: ${rendered}"
            }
        } else {
            $json = ($val | ConvertTo-Json -Compress)
            $lines += "$($prop.Name): $json"
        }
    }
    return $lines
}

# ─── Load config ──────────────────────────────────────────────────────────────

if (-not (Test-Path $ConfigFile)) {
    Write-Host "Config not found: $ConfigFile" -ForegroundColor Red
    exit 1
}
$Config = Get-Content $ConfigFile -Raw | ConvertFrom-Json

# ─── Detect providers ─────────────────────────────────────────────────────────

$AllProviders = @($Config.PSObject.Properties.Name)
$Detected = @()
foreach ($provider in $AllProviders) {
    $detectPath = Expand-HomePath $Config.$provider.detect
    if (Test-Path $detectPath -PathType Container) {
        $Detected += $provider
    }
}

if ($Detected.Count -eq 0) {
    Write-Host "No supported providers detected. Exiting."
    exit 0
}

# ─── Select providers ─────────────────────────────────────────────────────────

Write-Host "Detected providers:"
for ($i = 0; $i -lt $Detected.Count; $i++) {
    Write-Host "  [$($i + 1)] $($Detected[$i])"
}
Write-Host "  [a] All"
Write-Host ""

if ($Yes) {
    $selection = "a"
    Write-Host "Install to which providers? (e.g. 1 2 or a): a (auto)"
} else {
    $selection = Read-Host "Install to which providers? (e.g. 1 2 or a)"
}

$Selected = @()
if ($selection -eq "a") {
    $Selected = $Detected
} else {
    foreach ($s in ($selection -split '\s+')) {
        $idx = 0
        if ([int]::TryParse($s, [ref]$idx)) {
            if ($idx -ge 1 -and $idx -le $Detected.Count) {
                $Selected += $Detected[$idx - 1]
            }
        }
    }
}

if ($Selected.Count -eq 0) {
    Write-Host "No valid selection. Exiting."
    exit 1
}

# ─── Ask which skills ─────────────────────────────────────────────────────────

Write-Host ""
Write-Host "Install the 'pillbox' skill? (recommended — persistent per-project memory for AI agents)"
if ($Yes) {
    $installPillbox = "y"
    Write-Host "  [Y/n]: y (auto)"
} else {
    $installPillbox = Read-Host "  [Y/n]"
    if ([string]::IsNullOrWhiteSpace($installPillbox)) { $installPillbox = "y" }
    $installPillbox = $installPillbox.ToLower()
}

Write-Host ""
Write-Host "Install the 'sdd' skill, its agents and commands? (recommended)"
Write-Host ""
Write-Host "  SDD (Spec-Driven Development) is Pillbox's official workflow:"
Write-Host "  proposal -> specs -> design -> implementation -> verification."
Write-Host "  Includes the 'sdd' skill and the specialized agents (sdd-explorer, sdd-implementer, etc.)"
Write-Host ""
Write-Host "  Advanced option: if you prefer your own development workflows, answer 'n'."
Write-Host "  Keep in mind that Pillbox is designed and tested on top of SDD, so adapting"
Write-Host "  your own workflows requires knowing its capabilities well — a minimum quality"
Write-Host "  of operation is not guaranteed without that knowledge."
if ($Yes) {
    $installSdd = "y"
    Write-Host "  [Y/n]: y (auto)"
} else {
    $installSdd = Read-Host "  [Y/n]"
    if ([string]::IsNullOrWhiteSpace($installSdd)) { $installSdd = "y" }
    $installSdd = $installSdd.ToLower()
}

$InstallSkills   = @()
$InstallAgents   = @()
$InstallCommands = @()
if ($installPillbox -ne "n") { $InstallSkills += "pillbox" }
if ($installSdd -ne "n") {
    $InstallSkills   += "sdd"
    $InstallAgents   += "sdd"
    $InstallCommands += "sdd"
}

if ($InstallSkills.Count -eq 0 -and $InstallAgents.Count -eq 0 -and $InstallCommands.Count -eq 0) {
    Write-Host ""
    Write-Host "No skill, agent or command selected. Exiting."
    exit 0
}

# ─── Install ──────────────────────────────────────────────────────────────────

foreach ($provider in $Selected) {
    $paths         = $Config.$provider.paths
    $agentsPath    = Expand-HomePath $paths.agents
    $skillsPath    = Expand-HomePath $paths.skills
    $commandsPath  = Expand-HomePath $paths.commands
    $skillsPathRaw = $paths.skills   # keeps ~ for command-body substitution

    Write-Host ""
    Write-Host "Installing $provider"

    # Agents
    if ($InstallAgents.Count -gt 0) {
        New-Item -ItemType Directory -Force -Path $agentsPath | Out-Null
        foreach ($agentProp in $Config.$provider.agents.PSObject.Properties) {
            $agentName = $agentProp.Name
            $shouldInstall = $false
            foreach ($prefix in $InstallAgents) {
                if ($agentName.StartsWith($prefix)) { $shouldInstall = $true; break }
            }
            if (-not $shouldInstall) { continue }

            $contentFile = Join-Path $AgentsDir "$agentName.md"
            if (-not (Test-Path $contentFile)) {
                Write-Host "  Warning: agents/$agentName.md not found, skipping" -ForegroundColor Yellow
                continue
            }
            $body = Get-Content $contentFile -Raw
            $front = Format-Frontmatter $agentProp.Value
            $out = @("---") + $front + @("---", "") + @($body)
            Set-Content -Path (Join-Path $agentsPath "$agentName.md") -Value ($out -join "`n") -NoNewline
            Write-Host "  OK agents/$agentName.md -> $agentsPath" -ForegroundColor Green
        }
    }

    # Skills
    if ($InstallSkills.Count -gt 0) {
        foreach ($skillDir in (Get-ChildItem -Path $SkillsDir -Directory)) {
            $skillName = $skillDir.Name
            $skillFile = Join-Path $skillDir.FullName "SKILL.md"
            if (-not (Test-Path $skillFile)) { continue }
            if ($InstallSkills -notcontains $skillName) { continue }

            $dest = Join-Path $skillsPath $skillName
            New-Item -ItemType Directory -Force -Path $dest | Out-Null
            Copy-Item -Path $skillFile -Destination (Join-Path $dest "SKILL.md") -Force
            Write-Host "  OK skills/$skillName/SKILL.md -> $dest" -ForegroundColor Green
        }
    }

    # Commands
    if ($InstallCommands.Count -gt 0) {
        foreach ($cmdDir in (Get-ChildItem -Path $CommandsDir -Directory)) {
            $cmdName = $cmdDir.Name
            if ($InstallCommands -notcontains $cmdName) { continue }

            $dest = Join-Path $commandsPath $cmdName
            New-Item -ItemType Directory -Force -Path $dest | Out-Null
            # Substitute the per-provider skills path into command bodies so each
            # command points at the right SKILL.md location for its provider.
            foreach ($cmdFile in (Get-ChildItem -Path $cmdDir.FullName -Filter *.md)) {
                $content = (Get-Content $cmdFile.FullName -Raw) -replace '__SKILL_DIR__', $skillsPathRaw
                Set-Content -Path (Join-Path $dest $cmdFile.Name) -Value $content -NoNewline
            }
            Write-Host "  OK commands/$cmdName/ -> $dest" -ForegroundColor Green
        }
    }
}

Write-Host ""
Write-Host "Done."
