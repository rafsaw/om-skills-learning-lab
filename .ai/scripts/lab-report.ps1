#Requires -Version 5.1
<#
.SYNOPSIS
    Renders the current state of om-skills-learning-lab as a Markdown report.

.DESCRIPTION
    Walks the repository and emits one Markdown document: repository status,
    installed skills, available specs, the FINDINGS.md / EXPERIMENTS.md learning
    artifacts, and a short generated summary.

    This is a description, not a gate. It renders no readiness verdict and never
    exits non-zero because the lab is in a bad state - that is lab-status.ps1's
    job, and this report points at it rather than restating its diagnosis.

    Read-only by default: it writes nothing unless -OutFile is given, makes no
    network call, and needs nothing beyond Windows PowerShell 5.1 and
    (optionally) git on PATH.

.PARAMETER OutFile
    Write the report to this path as UTF-8 without a BOM. Without it the report
    goes to stdout.

.PARAMETER Help
    Print usage and exit 0.

.EXAMPLE
    .\.ai\scripts\lab-report.ps1

.EXAMPLE
    .\.ai\scripts\lab-report.ps1 -OutFile .ai\analysis\lab-report.md

.NOTES
    Do NOT redirect stdout with '>' to produce the file. Windows PowerShell 5.1
    writes UTF-16LE that way, which git treats as binary and most Markdown
    renderers refuse. Use -OutFile, which writes UTF-8 without a BOM.
#>
[CmdletBinding()]
param(
    [string] $OutFile,
    [switch] $Help
)

Set-StrictMode -Version Latest

# No single failed read may abort the report: every check that can fail is
# wrapped locally with -ErrorAction Stop inside a try, and the section degrades.
$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

# The verdict travels in a script-scope variable rather than a return value:
# report lines are written to the success stream, so a function that also
# returned its exit code would hand back the whole report along with it.
$script:ExitCode = 0

# Section headings, in fixed order. The spec declares these an informal contract
# - stable enough to grep for, not promoted to a protected surface.
$script:SectionOrder = @('Repository', 'Installed skills', 'Specs', 'Learning artifacts', 'Summary')

function Show-Usage {
    Write-Output 'lab-report.ps1 - what does this repository currently contain?'
    Write-Output ''
    Write-Output 'Usage:'
    Write-Output '  .\.ai\scripts\lab-report.ps1 [-OutFile <path>] [-Help]'
    Write-Output '  powershell -NoProfile -ExecutionPolicy Bypass -File .ai\scripts\lab-report.ps1'
    Write-Output ''
    Write-Output 'Renders repository status, installed skills, available specs, the learning'
    Write-Output 'artifacts, and a short summary as one Markdown document. Read-only: it writes'
    Write-Output 'nothing unless -OutFile is given and never uses the network.'
    Write-Output ''
    Write-Output 'This is a description, not a gate. For a readiness verdict and an exit code'
    Write-Output 'that gates on it, run lab-status.ps1 instead.'
    Write-Output ''
    Write-Output 'Output encoding:'
    Write-Output '  -OutFile writes UTF-8 without a BOM. Do NOT use ">" to make the file -'
    Write-Output '  PowerShell 5.1 redirection writes UTF-16LE, which git treats as binary.'
    Write-Output ''
    Write-Output 'Exit codes:'
    Write-Output '  0  A report was produced. Says nothing about whether the lab is healthy.'
    Write-Output '  2  No report could be produced (wrong context, or -OutFile unwritable).'
}

# ---------------------------------------------------------------------------
# Collect. Every reader returns data; nothing here renders a line of Markdown.
# Keeping the split honest is what makes the escaping rules enforceable in one
# place, and what would make a future -Json mode a new renderer rather than a
# rewrite.
# ---------------------------------------------------------------------------

function Get-LabReportData {
    param([Parameter(Mandatory = $true)][string] $RepoRoot)

    return [pscustomobject]@{
        RepoRoot   = $RepoRoot
        SpecsDir   = (Resolve-SpecsDir -RepoRoot $RepoRoot)
        Repository = $null
        Skills     = $null
        Specs      = $null
        Log        = $null
        Notes      = @()
    }
}

# paths.specs is the repository's contract for where specs live, so the value
# comes from the config rather than a second hardcoded copy. Any read failure
# degrades to the documented default instead of breaking the section - the same
# read-with-default pattern every om-* skill uses.
function Resolve-SpecsDir {
    param([Parameter(Mandatory = $true)][string] $RepoRoot)

    $fallback = '.ai/specs'
    try {
        $configPath = Join-Path $RepoRoot '.ai\agentic.config.json'
        $raw = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 -ErrorAction Stop
        $json = ConvertFrom-Json -InputObject $raw -ErrorAction Stop
        $paths = Get-PropertyOrNull -InputObject $json -Name 'paths'
        $specs = Get-PropertyOrNull -InputObject $paths -Name 'specs'
        if ([string]::IsNullOrWhiteSpace($specs)) { return $fallback }
        return ([string]$specs).Replace('\', '/').TrimEnd('/')
    } catch {
        return $fallback
    }
}

# Strict mode turns a reference to an absent property into an error, and the
# properties this script reads are provider- or JSON-supplied rather than
# guaranteed, so every one of them goes through here.
function Get-PropertyOrNull {
    param(
        [Parameter(Mandatory = $true)][AllowNull()] $InputObject,
        [Parameter(Mandatory = $true)][string] $Name
    )
    if ($null -eq $InputObject) { return $null }
    if ($InputObject.PSObject.Properties.Match($Name).Count -eq 0) { return $null }
    return $InputObject.PSObject.Properties[$Name].Value
}

# ---------------------------------------------------------------------------
# Render. Data in, Markdown lines out. No I/O.
# ---------------------------------------------------------------------------

function Format-LabReport {
    param([Parameter(Mandatory = $true)] $Data)

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('# om-skills-learning-lab - lab report')
    $lines.Add('')
    $lines.Add('Generated ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss K') + ' by `.ai/scripts/lab-report.ps1`.')

    foreach ($section in $script:SectionOrder) {
        $lines.Add('')
        $lines.Add('## ' + $section)
    }

    return $lines.ToArray()
}

# ---------------------------------------------------------------------------
# Emit.
# ---------------------------------------------------------------------------

# File output only. This function must never write a report line to the success
# stream: its caller tests the returned boolean, and `if (-not (Save-Report ...))`
# captures *everything* the function emits, so a stray Write-Output here would be
# swallowed into the condition instead of reaching the console. stdout emission
# therefore happens inline in Invoke-Main, where nothing captures it.
function Save-Report {
    param(
        # Blank lines are load-bearing in Markdown, so the array is full of empty
        # strings; without AllowEmptyString the binder rejects every one of them.
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][AllowEmptyString()][string[]] $Lines,
        [Parameter(Mandatory = $true)][string] $Path
    )

    # Never Set-Content -Encoding UTF8 here: in Windows PowerShell 5.1 that
    # emits a BOM. WriteAllText with UTF8Encoding($false) does not, which is
    # what every other file in this repository looks like.
    try {
        $full = [System.IO.Path]::GetFullPath($Path)
        $parent = Split-Path -Parent $full
        # Creating a directory tree from a typo'd path silently is worse than
        # failing, so a missing parent is an error rather than a mkdir.
        if (-not [string]::IsNullOrEmpty($parent) -and -not (Test-Path -LiteralPath $parent -PathType Container)) {
            [Console]::Error.WriteLine("lab-report: output directory does not exist: $parent")
            return $false
        }
        $text = ($Lines -join [Environment]::NewLine) + [Environment]::NewLine
        $encoding = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($full, $text, $encoding)
        return $true
    } catch {
        [Console]::Error.WriteLine("lab-report: could not write '$Path': $($_.Exception.Message)")
        return $false
    }
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
        [Console]::Error.WriteLine('lab-report: cannot determine the script location, so the repository root cannot be anchored.')
        $script:ExitCode = 2
        return
    }
    $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

    $anchorSkills = Join-Path $repoRoot '.agents\skills'
    $anchorConfig = Join-Path $repoRoot '.ai\agentic.config.json'
    if (-not (Test-Path -LiteralPath $anchorSkills -PathType Container) -or
        -not (Test-Path -LiteralPath $anchorConfig -PathType Leaf)) {
        [Console]::Error.WriteLine("lab-report: '$repoRoot' is not om-skills-learning-lab.")
        [Console]::Error.WriteLine('lab-report: expected both .agents\skills\ and .ai\agentic.config.json two levels above this script.')
        $script:ExitCode = 2
        return
    }

    $data = Get-LabReportData -RepoRoot $repoRoot
    $lines = Format-LabReport -Data $data

    if ([string]::IsNullOrWhiteSpace($OutFile)) {
        foreach ($line in $lines) { Write-Output $line }
    } elseif (-not (Save-Report -Lines $lines -Path $OutFile)) {
        $script:ExitCode = 2
        return
    }

    $script:ExitCode = 0
}

Invoke-Main
exit $script:ExitCode
