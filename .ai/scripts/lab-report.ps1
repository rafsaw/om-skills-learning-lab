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

# Summary notes, appended by the readers. Present in the report only when
# something is off: a permanently present "Notes: none" trains the reader to
# skip the section that matters.
$script:Notes = New-Object System.Collections.Generic.List[string]

function Add-Note {
    param([Parameter(Mandatory = $true)][string] $Message)
    $script:Notes.Add($Message)
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

# A commit subject, a spec title, or a finding heading is free text lifted out of
# the repository, and a single '|' in it ends a table cell early - breaking the
# table for every downstream reader. Everything entering a cell goes through here.
function ConvertTo-CellText {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string] $Text)
    return ($Text -replace '\|', '\|')
}

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
        Repository = (Get-RepositoryInfo -RepoRoot $RepoRoot)
        Skills     = (Get-SkillsInfo -RepoRoot $RepoRoot)
        Specs      = $null
        Log        = $null
    }
}

# Run git against the anchored root rather than the caller's directory, and hand
# back success plus output instead of letting a non-zero exit escape as an error.
function Invoke-Git {
    param(
        [Parameter(Mandatory = $true)][string] $RepoRoot,
        [Parameter(Mandatory = $true)][string[]] $GitArgs
    )

    $global:LASTEXITCODE = 0
    $output = & git '-C' $RepoRoot @GitArgs 2>$null
    return [pscustomobject]@{
        Ok    = ($global:LASTEXITCODE -eq 0)
        Lines = @($output | Where-Object { $null -ne $_ })
    }
}

function Get-RepositoryInfo {
    param([Parameter(Mandatory = $true)][string] $RepoRoot)

    $info = [pscustomobject]@{
        Available = $false
        Branch    = 'unavailable'
        Sha       = 'unavailable'
        Subject   = ''
        Date      = 'unavailable'
        Dirty     = $null
    }

    if (-not (Get-Command 'git' -CommandType Application -ErrorAction SilentlyContinue)) {
        Add-Note 'git is not on PATH, so the repository section could not be filled in. Every other section is unaffected.'
        return $info
    }

    $inside = Invoke-Git -RepoRoot $RepoRoot -GitArgs @('rev-parse', '--is-inside-work-tree')
    if (-not $inside.Ok -or ($inside.Lines -join '') -ne 'true') {
        Add-Note 'The repository root is not a git work tree, so the repository section could not be filled in. Every other section is unaffected.'
        return $info
    }

    $info.Available = $true

    # symbolic-ref answers on a branch, including an unborn one; it fails on a
    # detached HEAD, which is what the short-sha fallback is for.
    $symbolic = Invoke-Git -RepoRoot $RepoRoot -GitArgs @('symbolic-ref', '--quiet', '--short', 'HEAD')
    if ($symbolic.Ok -and $symbolic.Lines.Count -gt 0) {
        $info.Branch = [string]$symbolic.Lines[0]
    } else {
        $head = Invoke-Git -RepoRoot $RepoRoot -GitArgs @('rev-parse', '--short', 'HEAD')
        if ($head.Ok -and $head.Lines.Count -gt 0) {
            $info.Branch = '(detached at ' + [string]$head.Lines[0] + ')'
        }
    }

    # Subject goes last and the split is capped at three fields: a commit subject
    # is free text and may well contain the delimiter, while a short SHA and an
    # ISO date cannot.
    $log = Invoke-Git -RepoRoot $RepoRoot -GitArgs @('log', '-1', '--format=%h|%ad|%s', '--date=short')
    if ($log.Ok -and $log.Lines.Count -gt 0) {
        $parts = ([string]$log.Lines[0]) -split '\|', 3
        if ($parts.Count -ge 1) { $info.Sha = $parts[0] }
        if ($parts.Count -ge 2) { $info.Date = $parts[1] }
        if ($parts.Count -ge 3) { $info.Subject = $parts[2] }
    } else {
        Add-Note 'The repository has no commits yet, so the HEAD commit could not be reported.'
    }

    $status = Invoke-Git -RepoRoot $RepoRoot -GitArgs @('status', '--porcelain')
    if ($status.Ok) {
        $entries = @($status.Lines | Where-Object { $_.ToString().Trim() -ne '' })
        $info.Dirty = $entries.Count
        if ($entries.Count -gt 0) {
            Add-Note ('The working tree has uncommitted changes (' +
                (Format-Count $entries.Count 'entry' 'entries') +
                '), so this report describes a state that is not committed anywhere.')
        }
    } else {
        Add-Note 'git status failed, so the working-tree state could not be reported.'
    }

    return $info
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

# Drive-letter casing, a trailing separator, and '.'/'..' segments must not be
# able to produce a false "does not resolve", so both sides of every comparison
# are normalized through here first. This behavior is copied deliberately from
# lab-status.ps1 and must not diverge from it.
function Get-NormalizedPath {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string] $Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return '' }
    try {
        return [System.IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
    } catch {
        return $Path.TrimEnd('\', '/')
    }
}

# The entries in this checkout are NTFS junctions, not symbolic links: Git Bash
# on Windows without the privilege to create symlinks produces junctions, even
# though every repository document calls them symlinks. Both types are accepted -
# demanding SymbolicLink would report a perfectly healthy lab as entirely broken.
# Copied deliberately from lab-status.ps1; must not diverge.
function Get-EntryLinkTarget {
    param(
        [Parameter(Mandatory = $true)] $Item,
        [Parameter(Mandatory = $true)][string] $ParentDir
    )

    $linkType = [string](Get-PropertyOrNull -InputObject $Item -Name 'LinkType')
    if ($linkType -ne 'Junction' -and $linkType -ne 'SymbolicLink') { return '' }

    $raw = Get-PropertyOrNull -InputObject $Item -Name 'Target'
    $first = @($raw) | Where-Object { $null -ne $_ -and [string]$_ -ne '' } | Select-Object -First 1
    if ($null -eq $first) { return '' }

    $targetText = [string]$first
    # A symbolic link may record a relative target; resolve it against the
    # directory the link itself lives in, never the caller's cwd.
    if (-not [System.IO.Path]::IsPathRooted($targetText)) {
        $targetText = Join-Path $ParentDir $targetText
    }
    return (Get-NormalizedPath $targetText)
}

# Compare only the set of names. Recomputing the skills CLI's content hash would
# report drift on every local edit, which a learning lab expects to have.
function Read-LockfileSkillNames {
    param([Parameter(Mandatory = $true)][string] $LockPath)

    try {
        if (-not (Test-Path -LiteralPath $LockPath -PathType Leaf)) { throw 'not found' }
        # -Encoding UTF8 explicitly: Windows PowerShell 5.1 otherwise decodes with
        # the host's ANSI code page, and this repository's files are UTF-8 without
        # a BOM, so the default is only correct on a host whose code page happens
        # to be 65001.
        $raw = Get-Content -LiteralPath $LockPath -Raw -Encoding UTF8 -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($raw)) { throw 'empty' }
        $json = ConvertFrom-Json -InputObject $raw -ErrorAction Stop
        $skills = Get-PropertyOrNull -InputObject $json -Name 'skills'
        if ($null -eq $skills) { throw 'no skills object' }
        return @($skills.PSObject.Properties | ForEach-Object { $_.Name })
    } catch {
        # The lockfile is never allowed to abort the report.
        return $null
    }
}

function Get-SkillsInfo {
    param([Parameter(Mandatory = $true)][string] $RepoRoot)

    $vendoredRoot  = Join-Path $RepoRoot '.agents\skills'
    $discoveryRoot = Join-Path $RepoRoot '.claude\skills'

    $vendored = @(Get-ChildItem -LiteralPath $vendoredRoot -Directory -Force -ErrorAction SilentlyContinue | Sort-Object Name)
    $vendoredNames = @($vendored | ForEach-Object { $_.Name })

    # Enumerate the discovery directory once. A listing includes a link whose
    # target no longer exists, which a Test-Path probe on the entry would not.
    $entries = @{}
    if (Test-Path -LiteralPath $discoveryRoot -PathType Container) {
        foreach ($entry in @(Get-ChildItem -LiteralPath $discoveryRoot -Force -ErrorAction SilentlyContinue)) {
            $entries[$entry.Name] = $entry
        }
    }

    $lockNames = Read-LockfileSkillNames -LockPath (Join-Path $RepoRoot 'skills-lock.json')
    $lockReadable = ($null -ne $lockNames)
    if (-not $lockReadable) { $lockNames = @() }

    # The union, so a name that exists only in the lockfile or only under
    # .claude\skills\ still gets a row rather than being silently dropped.
    $allNames = @($vendoredNames + $lockNames + @($entries.Keys)) | Sort-Object -Unique

    $rows = New-Object System.Collections.Generic.List[object]
    $resolved = 0
    $unresolved = 0

    foreach ($name in $allNames) {
        $isVendored = ($vendoredNames -contains $name)

        $hasSkillMd = '-'
        if ($isVendored) {
            $skillMd = Join-Path (Join-Path $vendoredRoot $name) 'SKILL.md'
            if (Test-Path -LiteralPath $skillMd -PathType Leaf) { $hasSkillMd = 'yes' } else { $hasSkillMd = 'no' }
        }

        $inLock = '-'
        if ($lockReadable) { if ($lockNames -contains $name) { $inLock = 'yes' } else { $inLock = 'no' } }

        # One bit, not a classification. lab-status.ps1 owns the five-way
        # diagnosis (missing / not-a-link / broken / foreign) because each class
        # implies a different repair; this report only says whether the skill
        # dispatches from this checkout, and points at that script for the rest.
        $discovery = 'does not resolve'
        if ($isVendored -and $entries.ContainsKey($name)) {
            $expected = Get-NormalizedPath (Join-Path $vendoredRoot $name)
            $target = Get-EntryLinkTarget -Item $entries[$name] -ParentDir $discoveryRoot
            if ($target -ne '' -and (Test-Path -LiteralPath $target) -and $target -eq $expected) {
                $discovery = 'resolves'
            }
        } elseif (-not $isVendored) {
            $discovery = '-'
        }

        if ($isVendored) {
            if ($discovery -eq 'resolves') { $resolved++ } else { $unresolved++ }
        }

        $rows.Add([pscustomobject]@{
            Name       = $name
            SkillMd    = $hasSkillMd
            InLock     = $inLock
            Discovery  = $discovery
        })
    }

    if ($unresolved -gt 0) {
        Add-Note ((Format-Count $unresolved 'discovery entry' 'discovery entries') +
            ' under `.claude/skills/` do not resolve into this checkout, so those skills dispatch nothing or dispatch another checkout''s copy. Run `.ai/scripts/lab-status.ps1` for the per-entry diagnosis.')
    }

    $onlyInLock = @()
    $onlyVendored = @()
    if ($lockReadable) {
        $onlyInLock   = @($lockNames | Where-Object { $vendoredNames -notcontains $_ })
        $onlyVendored = @($vendoredNames | Where-Object { $lockNames -notcontains $_ })
        if ($onlyInLock.Count -gt 0 -or $onlyVendored.Count -gt 0) {
            Add-Note ('`skills-lock.json` and `.agents/skills/` disagree on ' +
                (Format-Count ($onlyInLock.Count + $onlyVendored.Count) 'entry' 'entries') +
                ', so the next reproducible install would not match this tree.')
        }
    } else {
        Add-Note '`skills-lock.json` is missing or could not be parsed, so the installed set could not be compared against `.agents/skills/`.'
    }

    return [pscustomobject]@{
        Rows          = $rows.ToArray()
        VendoredCount = $vendored.Count
        LockCount     = $lockNames.Count
        LockReadable  = $lockReadable
        Resolved      = $resolved
        SetsMatch     = ($lockReadable -and $onlyInLock.Count -eq 0 -and $onlyVendored.Count -eq 0)
    }
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
        switch ($section) {
            'Repository'       { Add-RepositorySection -Lines $lines -Repository $Data.Repository }
            'Installed skills' { Add-SkillsSection -Lines $lines -Skills $Data.Skills }
        }
    }

    return $lines.ToArray()
}

function Add-RepositorySection {
    param(
        [Parameter(Mandatory = $true)] $Lines,
        [Parameter(Mandatory = $true)] $Repository
    )

    $head = 'unavailable'
    if ($Repository.Available -and $Repository.Sha -ne 'unavailable') {
        $head = '`' + $Repository.Sha + '`'
        if ($Repository.Subject -ne '') {
            $head = $head + ' - ' + (ConvertTo-CellText $Repository.Subject)
        }
    }

    $tree = 'unavailable'
    if ($null -ne $Repository.Dirty) {
        if ($Repository.Dirty -eq 0) {
            $tree = 'clean'
        } else {
            $tree = 'dirty (' + (Format-Count $Repository.Dirty 'entry' 'entries') + ')'
        }
    }

    $branch = $Repository.Branch
    if ($Repository.Available -and $branch -ne 'unavailable') { $branch = '`' + $branch + '`' }

    $Lines.Add('')
    $Lines.Add('| Field | Value |')
    $Lines.Add('|---|---|')
    $Lines.Add('| Branch | ' + $branch + ' |')
    $Lines.Add('| HEAD | ' + $head + ' |')
    $Lines.Add('| Committed | ' + $Repository.Date + ' |')
    $Lines.Add('| Working tree | ' + $tree + ' |')
}

function Add-SkillsSection {
    param(
        [Parameter(Mandatory = $true)] $Lines,
        [Parameter(Mandatory = $true)] $Skills
    )

    $Lines.Add('')

    if ($Skills.VendoredCount -eq 0) {
        $Lines.Add('No skills vendored under `.agents/skills/`.')
        return
    }

    $lockPhrase = '`skills-lock.json` is unreadable'
    if ($Skills.LockReadable) {
        $lockPhrase = '' + $Skills.LockCount + ' recorded in `skills-lock.json`'
        if ($Skills.SetsMatch) { $lockPhrase = $lockPhrase + ', sets match' } else { $lockPhrase = $lockPhrase + ', sets differ' }
    }
    $Lines.Add('' + $Skills.VendoredCount + ' vendored under `.agents/skills/`, ' + $lockPhrase + '.')
    $Lines.Add('' + $Skills.Resolved + ' of ' + $Skills.VendoredCount + ' discovery entries under `.claude/skills/` resolve into this checkout.')

    $Lines.Add('')
    $Lines.Add('| Skill | SKILL.md | Lockfile | Discovery |')
    $Lines.Add('|---|---|---|---|')
    foreach ($row in $Skills.Rows) {
        $Lines.Add('| `' + (ConvertTo-CellText $row.Name) + '` | ' + $row.SkillMd + ' | ' + $row.InLock + ' | ' + $row.Discovery + ' |')
    }
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
