#Requires -Version 5.1
<#
.SYNOPSIS
    Reports whether om-skills-learning-lab is ready for the next learning session.

.DESCRIPTION
    Prints the repository's branch and working-tree state, the health of the
    .claude\skills discovery entries, and the latest recorded experiment and
    finding, then a READY / NOT READY verdict backed by the exit code.

    Strictly read-only: it never writes to the repository, never makes a network
    call, and never repairs anything it finds. Needs nothing beyond Windows
    PowerShell 5.1, and degrades rather than failing when git is absent.

.PARAMETER Help
    Print usage and exit 0.

.EXAMPLE
    .\.ai\scripts\lab-status.ps1

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .ai\scripts\lab-status.ps1
#>
[CmdletBinding()]
param(
    [switch] $Help
)

Set-StrictMode -Version Latest

# Never let a single failed read abort the report: every check that can fail is
# wrapped locally with -ErrorAction Stop inside a try, and everything else is
# expected to continue.
$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

# ---------------------------------------------------------------------------
# Layout constants. See the UI/UX section of the spec: a fixed label column with
# values left-aligned after it, detail lines indented into the value column, and
# plain ASCII only - no color, no box drawing, no emoji.
# ---------------------------------------------------------------------------
$script:BodyIndent = '  '
$script:LabelWidth = 18
$script:DetailWidth = 10
$script:TitleMaxLength = 60
$script:FindingWidth = 78

# ---------------------------------------------------------------------------
# Collected findings. No check exits early: a repository with three problems
# reports three problems in one run.
# ---------------------------------------------------------------------------
$script:Blockers = @()
$script:Warnings = @()
$script:DiscoveryFindings = 0

# The verdict travels in a script-scope variable rather than a return value:
# every report line is written to the success stream, so a function that also
# returned its exit code would hand back the whole report along with it.
$script:ExitCode = 0

function Add-Blocker {
    param(
        [Parameter(Mandatory = $true)][string] $Message,
        [switch] $Discovery
    )
    $script:Blockers += $Message
    if ($Discovery) { $script:DiscoveryFindings++ }
}

function Add-Warning {
    param(
        [Parameter(Mandatory = $true)][string] $Message,
        [switch] $Discovery
    )
    $script:Warnings += $Message
    if ($Discovery) { $script:DiscoveryFindings++ }
}

# ---------------------------------------------------------------------------
# Output helpers.
# ---------------------------------------------------------------------------

function Write-Blank {
    Write-Output ''
}

function Write-Section {
    param([Parameter(Mandatory = $true)][string] $Title)
    Write-Output $Title
}

function Write-Row {
    param(
        [Parameter(Mandatory = $true)][string] $Label,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string] $Value
    )
    Write-Output ($script:BodyIndent + $Label.PadRight($script:LabelWidth) + $Value)
}

# A detail line hangs under the row it belongs to, starting in the value column.
function Write-Detail {
    param(
        [Parameter(Mandatory = $true)][string] $Kind,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string] $Value
    )
    $label = "${Kind}:"
    if ($label.Length -lt $script:DetailWidth) {
        $label = $label.PadRight($script:DetailWidth)
    } else {
        $label = $label + ' '
    }
    $pad = ' ' * ($script:BodyIndent.Length + $script:LabelWidth)
    Write-Output ($pad + $label + $Value)
}

# The Windows console default code page mangles non-ASCII, and this output ends
# up in log captures and agent transcripts, so text lifted out of repository
# documents is folded down to ASCII before it is printed.
function ConvertTo-AsciiText {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string] $Text)

    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $Text.ToCharArray()) {
        switch ([int]$ch) {
            0x2013 { [void]$sb.Append('-');  break }   # en dash
            0x2014 { [void]$sb.Append('-');  break }   # em dash
            0x2018 { [void]$sb.Append("'");  break }   # left single quote
            0x2019 { [void]$sb.Append("'");  break }   # right single quote
            0x201C { [void]$sb.Append('"');  break }   # left double quote
            0x201D { [void]$sb.Append('"');  break }   # right double quote
            0x2026 { [void]$sb.Append('...'); break }  # ellipsis
            0x00A0 { [void]$sb.Append(' ');  break }   # non-breaking space
            default {
                if ([int]$ch -ge 32 -and [int]$ch -le 126) {
                    [void]$sb.Append($ch)
                } else {
                    [void]$sb.Append('?')
                }
            }
        }
    }
    return $sb.ToString()
}

# Findings wrap with a hanging indent so a two-line message stays readable:
#
#   [blocker] om-root-cause resolves outside this repository, so dispatching it
#             executes a different checkout's copy of the skill.
function Write-Finding {
    param(
        [Parameter(Mandatory = $true)][string] $Severity,
        [Parameter(Mandatory = $true)][string] $Message
    )
    $prefix = "[$Severity] "
    $hang = ' ' * $prefix.Length
    $width = $script:FindingWidth
    $line = ''
    $first = $true

    foreach ($word in ($Message -split '\s+' | Where-Object { $_ -ne '' })) {
        if ($line -eq '') {
            $line = $word
        } elseif (($line.Length + 1 + $word.Length) -le $width) {
            $line = $line + ' ' + $word
        } else {
            if ($first) { Write-Output ($script:BodyIndent + $prefix + $line); $first = $false }
            else        { Write-Output ($script:BodyIndent + $hang + $line) }
            $line = $word
        }
    }
    if ($line -ne '') {
        if ($first) { Write-Output ($script:BodyIndent + $prefix + $line) }
        else        { Write-Output ($script:BodyIndent + $hang + $line) }
    }
}

function Format-Count {
    param(
        [Parameter(Mandatory = $true)][int] $Count,
        [Parameter(Mandatory = $true)][string] $Singular,
        [Parameter(Mandatory = $true)][string] $Plural
    )
    if ($Count -eq 1) { return "$Count $Singular" }
    return "$Count $Plural"
}

function Show-Usage {
    Write-Output 'lab-status.ps1 - is this repository ready for the next learning session?'
    Write-Output ''
    Write-Output 'Usage:'
    Write-Output '  .\.ai\scripts\lab-status.ps1 [-Help]'
    Write-Output '  powershell -NoProfile -ExecutionPolicy Bypass -File .ai\scripts\lab-status.ps1'
    Write-Output ''
    Write-Output 'Reports the branch and working-tree state, the health of the .claude\skills'
    Write-Output 'discovery entries, and the latest recorded experiment and finding. Read-only:'
    Write-Output 'it never writes to the repository, never uses the network, and never repairs'
    Write-Output 'what it finds.'
    Write-Output ''
    Write-Output 'Exit codes:'
    Write-Output '  0  READY - no blockers found. Warnings may still have been printed.'
    Write-Output '  1  NOT READY - at least one blocker was found.'
    Write-Output '  2  Wrong context - the script is not anchored inside this lab.'
}

# ---------------------------------------------------------------------------
# Sections.
# ---------------------------------------------------------------------------

function Show-RepositorySection {
    param([Parameter(Mandatory = $true)][string] $RepoRoot)

    Write-Section 'Repository'
}

function Show-SkillsSection {
    param([Parameter(Mandatory = $true)][string] $RepoRoot)

    Write-Section 'Skills'
}

function Show-LearningLogSection {
    param([Parameter(Mandatory = $true)][string] $RepoRoot)

    Write-Section 'Learning log'
}

function Show-Verdict {
    $blockerCount = @($script:Blockers).Count
    $warningCount = @($script:Warnings).Count

    Write-Blank

    if ($blockerCount -eq 0) {
        if ($warningCount -eq 0) {
            Write-Output 'READY - no blockers found.'
        } else {
            Write-Output ('READY - no blockers found, ' + (Format-Count $warningCount 'warning' 'warnings') + '.')
        }
    } else {
        $verdict = 'NOT READY - ' + (Format-Count $blockerCount 'blocker' 'blockers')
        if ($warningCount -gt 0) {
            $verdict = $verdict + ', ' + (Format-Count $warningCount 'warning' 'warnings')
        }
        Write-Output ($verdict + '.')
    }

    if (($blockerCount + $warningCount) -gt 0) {
        Write-Blank
        foreach ($message in $script:Blockers) { Write-Finding 'blocker' $message }
        foreach ($message in $script:Warnings) { Write-Finding 'warning' $message }
    }

    if ($script:DiscoveryFindings -gt 0) {
        Write-Blank
        Write-Output ($script:BodyIndent + 'Discovery entries are recreated by the snippet in README.md, "Start here".')
    }

    if ($blockerCount -gt 0) { $script:ExitCode = 1 } else { $script:ExitCode = 0 }
}

# ---------------------------------------------------------------------------
# Entry point.
# ---------------------------------------------------------------------------

function Invoke-Main {
    if ($Help) {
        Show-Usage
        $script:ExitCode = 0
        return
    }

    # The root is derived from the script's own location, never from the current
    # directory: running this by absolute path from inside an unrelated
    # repository must not produce a confident report about that repository.
    if ([string]::IsNullOrEmpty($PSScriptRoot)) {
        [Console]::Error.WriteLine('lab-status: cannot determine the script location, so the repository root cannot be anchored.')
        $script:ExitCode = 2
        return
    }
    $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

    $anchorSkills = Join-Path $repoRoot '.agents\skills'
    $anchorConfig = Join-Path $repoRoot '.ai\agentic.config.json'
    if (-not (Test-Path -LiteralPath $anchorSkills -PathType Container) -or
        -not (Test-Path -LiteralPath $anchorConfig -PathType Leaf)) {
        [Console]::Error.WriteLine("lab-status: '$repoRoot' is not om-skills-learning-lab.")
        [Console]::Error.WriteLine('lab-status: expected both .agents\skills\ and .ai\agentic.config.json two levels above this script.')
        $script:ExitCode = 2
        return
    }

    Write-Output 'om-skills-learning-lab - status'
    Write-Blank

    Show-RepositorySection -RepoRoot $repoRoot
    Write-Blank
    Show-SkillsSection -RepoRoot $repoRoot
    Write-Blank
    Show-LearningLogSection -RepoRoot $repoRoot

    Show-Verdict
}

Invoke-Main
exit $script:ExitCode
